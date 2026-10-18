# -*- coding: utf-8 -*-
"""P9.b encyclopedia content layer compiler.

Reads the live P8 registries (source + baked), the expansion/map data, this
layer's curated source (categories, rule descriptions, display notes) and the
UI name fallback tables out of v1_scene.gd, then bakes the formal encyclopedia
content: entities with display fields, the canonical process model, per-resource
source/use indexes (pre-resolved for the reading UI), categories and rules.

Static fields are always regenerated from the current registries — the audit
snapshot numbers are never copied here. Rule text lives only in the curated
source. Validation fails the bake on: registry coverage gaps, duplicate or
dangling ids, reverse-index mismatches, living-recipe mapping mismatches,
unclassified no-use/no-source items (content-staleness trigger), recipe
quantity drift, or nondeterministic output.

Usage:
    python tools/farming/bake_encyclopedia.py            # bake
    python tools/farming/bake_encyclopedia.py --check    # staleness check
    python tools/farming/bake_encyclopedia.py --sample crop:golden_wheat resource:straw
"""
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC_PATH = ROOT / 'content/farming/p8/production.json'
BAK_PATH = ROOT / 'content/farming/baked/p8/production.json'
EXP_PATH = ROOT / 'content/farming/p8/expansion.json'
MAP_PATH = ROOT / 'content/farming/maps/farm_02.json'
CURATED_PATH = ROOT / 'content/farming/encyclopedia/encyclopedia.json'
SCENE_PATH = ROOT / 'scripts/farming/v1/v1_scene.gd'
TARGET = ROOT / 'content/farming/baked/encyclopedia/encyclopedia.json'

INPUT_PATHS = [SRC_PATH, BAK_PATH, EXP_PATH, MAP_PATH, CURATED_PATH, SCENE_PATH]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def load(path):
    return json.loads(path.read_text(encoding='utf-8'))


# --- curated + registries ----------------------------------------------------
CURATED = load(CURATED_PATH)
SRC = load(SRC_PATH)
BAK = load(BAK_PATH)
EXP = load(EXP_PATH)
MAP = load(MAP_PATH)


def scene_fallbacks():
    """The UI name fallback tables are maintained in v1_scene.gd; read them so
    the encyclopedia never keeps a second drifting copy."""
    text = SCENE_PATH.read_text(encoding='utf-8')
    out = {}
    for key in ('CROPS', 'RECIPES'):
        match = re.search(r'var %s := (\{.*?\})' % key, text)
        require(match is not None, f'v1_scene.gd name table {key} not found')
        try:
            out[key] = json.loads(match.group(1))
        except json.JSONDecodeError as error:
            raise ValueError(f'v1_scene.gd {key} table no longer parses as JSON: {error}')
    return out


FALLBACK = scene_fallbacks()
CROP_NAMES = {cid: row.get('name', FALLBACK['CROPS'].get(cid, cid)) for cid, row in
              {r['id']: r for r in SRC['crops']}.items()}
RECIPE_NAMES = {rid: row.get('name', FALLBACK['RECIPES'].get(rid, rid)) for rid, row in
                {r['id']: r for r in SRC['recipes']}.items()}

RES = {r['id']: r for r in SRC['resources']}
BAK_RES = {r['id']: r for r in BAK['resources']}
CROPS = {r['id']: r for r in SRC['crops']}
SOURCES = {r['id']: r for r in SRC['sources']}
FAC = {r['id']: r for r in SRC['facilities']}
RECIPES = {r['id']: r for r in SRC['recipes']}
LIVESTOCK = {r['id']: r for r in SRC['livestock']}
RESEARCH = {r['id']: r for r in SRC['research']}
CFG = SRC['config']
ENV = CFG['environment']
HUSB = SRC['husbandry']
FLOWERS = SRC['flowers']
DEVICES = SRC['devices']
DISPLAY = CURATED['display']

UNIT_DEFAULT = {'steel_sheep': '只', 'filter_algae_carp': '尾', 'bell_bee': '群', 'purifying_mat': '培养单位', 'rock_mole': '只', 'rock_belly_beast': '只'}
SOURCE_NAMES = {'stone_source': '采石点', 'ore_source': '采矿点', 'spring_source': '泉水点'}
MODE_NAMES = DISPLAY['crop_mode_names']

entities = []
processes = []
ENT = {}
PROC = {}
SRC_OF = {}
USE_OF = {}


def produces(item, pid):
    SRC_OF.setdefault(item, set()).add(pid)


def consumes(item, pid):
    USE_OF.setdefault(item, set()).add(pid)


def entity_name(eid):
    if eid in ENT:
        return ENT[eid]['name']
    if eid == 'currency:primeval_stone':
        return '元石'
    if eid.startswith('resource:'):
        return RES[eid[9:]]['name']
    return eid


def rname(rid):
    return RES[rid]['name']


def quantities_text(mapping):
    return '＋'.join(f'{rname(k)}×{v}' for k, v in mapping.items()) if mapping else '无'


def add_entity(eid, kind, source_id, name, category, tags, summary, fields, related_rules, locks=None, icon=None, extra=None):
    require(eid not in ENT, f'duplicate entity id {eid}')
    row = {'id': eid, 'kind': kind, 'source_id': source_id, 'name': name, 'category': category,
           'tags': tags, 'summary': summary, 'fields': fields, 'related_rules': sorted(related_rules),
           'locks': locks or None, 'icon': icon or source_id}
    if extra:
        row.update(extra)
    ENT[eid] = row
    entities.append(row)
    return row


def field(key, label, text):
    return {'key': key, 'label': label, 'text': text}


def lock_of(research_id):
    return {'research': f'research:{research_id}', 'research_name': RESEARCH[research_id]['name']} if research_id else None


def io(eid, quantity, basis, timing, conditions=None):
    row = {'entity': eid, 'name': entity_name(eid), 'quantity': quantity, 'basis': basis, 'timing': timing}
    if conditions:
        row['conditions'] = conditions
    return row


def proc(pid, ptype, name, inputs, outputs, ap=0, fee=0, stones=0, ap_detail=None,
         facility=None, species=None, crop=None, research=None, duration=None,
         conditions=None, effects=None, note=None, category_hint=None):
    require(pid not in PROC, f'duplicate process id {pid}')
    row = {'id': pid, 'type': ptype, 'category_hint': category_hint or ptype, 'name': name,
           'inputs': inputs, 'outputs': outputs,
           'ap': ap, 'ap_detail': ap_detail or (f'{ap}AP' if ap else '0AP'),
           'worker_fee': fee, 'primeval_stones': stones,
           'facility': facility, 'facility_name': ENT[facility]['name'] if facility else None,
           'species': species, 'species_name': ENT[species]['name'] if species else None,
           'crop': crop, 'crop_name': ENT[crop]['name'] if crop else None,
           'research': research, 'research_name': ENT[research]['name'] if research else None,
           'duration': duration or '即时', 'conditions': conditions or [], 'effects': effects or []}
    if note:
        row['note'] = note
    PROC[pid] = row
    processes.append(row)
    return pid


def instant(n=0):
    return '即时'


def days_text(n):
    return f'{n}自然日' if n else '即时'


# =============================================================================
# entities: crops / species / facilities / recipes / research / sources /
# parcels / map (built first so process rows can resolve names)
# =============================================================================
for cid, row in CROPS.items():
    seed = row['seed']
    plant_inputs = dict(row.get('inputs', {}))
    plant_inputs[seed] = plant_inputs.get(seed, 0) + 1
    mode = row['mode']
    fields = [
        field('seed', '种子/菌种', f'{rname(seed)}×1（播种时消耗；市集{"可购" if RES[seed]["buy_price"] > 0 else "不可购"}{RES[seed]["buy_price"] or ""}元石/份）'.replace('不可购0', '不可购')),
        field('footprint', '占地', f'{row["footprint"][0]}×{row["footprint"][1]}格（全部开垦且空闲才能播种）'),
        field('plant_inputs', '播种投入', quantities_text(plant_inputs) + '，1AP'),
        field('mode', '采收模式', MODE_NAMES[mode]),
        field('days', '首次成熟', f'{row["days"]}自然日（全适宜条件；实际时长按生长公式，见规则「作物生长速率公式」）'),
        field('light', '光照偏好', f'{row["light"]}（与占格平均有效光照相差≤{ENV["light_tolerance"]}为满速，否则光效{ENV["low_light_efficiency"]}%）'),
        field('drain', '每日环境扣减', f'每格水分−{row["water_use"]}、肥力−{row["fertility_use"]}（成熟待收期间照扣）'),
        field('outputs', '收获产物', quantities_text(row['outputs']) + '，1AP'),
    ]
    if row.get('fell_outputs'):
        fields.append(field('fell_outputs', '砍伐产物', quantities_text(row['fell_outputs']) + '，1AP（砍伐移除植株）'))
    if mode == 'tap_or_fell':
        fields.append(field('cycle', '采后再生', f'留株采收后{row["cycle_days"]}日恢复可采'))
    if row.get('flower_days'):
        window = FLOWERS['oilseed_window']
        fields.append(field('flower', '花期/花源', '成熟期间每日可产1份额' if cid == 'honeybell_bush' else f'生长进度{window[0]}~{window[1] - 1}期间为花期（{row["flower_days"]}日），每日期1份额'))
    if mode == 'culture_each_cycle':
        fields.append(field('culture', '培养水润床', '播种投入中的清水每份+30水分直接润床，不另算浇水'))
    if SRC.get('rooms'):
        primary=SRC['rooms']['primary'][cid]
        fields.append(field('room_primary','丰产主产物','；'.join(('砍伐' if m=='fell' else '采收')+'：'+rname(item) for m,item in primary.items())+'。仅本轮合格生长贡献参与25%增产，副产物不增加'))
        fields.append(field('room_seed','育种回流',f'首次成熟仅判定一次；完整合格25%概率得{rname(seed)}×1，随首次成熟收取/成熟清理领取，留株不重抽'))
    summary = f'{MODE_NAMES[mode].split("，")[0]}；首熟{row["days"]}日；{quantities_text(row["outputs"])}'
    add_entity(f'crop:{cid}', 'crop', cid, CROP_NAMES[cid], 'crops', [], summary, fields,
               ['rule:crop_growth', 'rule:environment', 'rule:day_settle']+(['rule:rooms'] if SRC.get('rooms') else []), lock_of(row.get('research')))

for sid, row in LIVESTOCK.items():
    unit = row.get('unit', UNIT_DEFAULT[sid])
    fac = FAC[row['facility']]
    fields = [
        field('price', '购入价格', f'{row["juvenile_price"]}元石/{unit}（0AP；购入即占容量，不可退回）'),
        field('unit', '计量单位', unit),
        field('facility', '适配设施', f'{fac["name"]}（容量{fac.get("capacity", 4)}{unit}；每场单物种）'),
        field('growth', '幼体成长', f'{row["growth_days"]}有效服务日（当日有基础服务才推进）'),
        field('cycle', '生产周期', f'{row["cycle_days"]}有效服务日/轮（特殊食谱启动）'),
    ]
    if row['outputs']:
        fields.append(field('outputs', '周期产物', f'{quantities_text(row["outputs"])}/轮/{unit}（收取时入仓）'))
    fields.append(field('claim', '收取后去留', '移除个体，需重新购入' if row['claim_removes'] else '保留个体（回到空闲成体）'))
    if sid == 'filter_algae_carp':
        fields.append(field('water', '水体依赖', '水场水体日降5；≤30全场暂停成长与周期，维护水体或换水恢复'))
    if sid == 'bell_bee':
        fields.append(field('flower', '花源依赖', '每群每日基础服务消耗1份额（与手采共享）＋清水×1；份额来自覆盖外扩2格内的当日合格花株'))
        fields.append(field('pollination', '授粉增益', '蜂群使用油籽花份额后，该株本周期待收+1油籽；多箱/多次不叠加'))
    if sid == 'purifying_mat':
        fields.append(field('culture', '培养规则', '仅幼体每日耗培养清水×1；在制成体靠盖章服务日推进、不再耗基础料；空闲成体启动批次时一次付清处理投入'))
    summary = f'{fac["name"]}养殖；{row["juvenile_price"]}元石/{unit}；周期{row["cycle_days"]}日'
    add_entity(f'species:{sid}', 'species', sid, row['name'], 'husbandry', [], summary, fields,
               ['rule:husbandry_service', 'rule:day_settle', 'rule:worker_scheduler'], lock_of(row.get('research')))

LIVING_MAP = []
for sid, row in LIVESTOCK.items():
    for kind in ('base_diets', 'special_diets'):
        for diet in row[kind]:
            did = f'diet:{sid}/{kind}/{diet["id"]}'
            tagline = '基础食谱（维持成长与有效日；每日服务时扣投入）' if kind == 'base_diets' else '特殊食谱（成体生产；周期启动时一次付清投入）'
            fields = [field('species', '所属物种', row['name']), field('kind', '类型', tagline),
                      field('inputs', '投入', (quantities_text(diet['inputs']) + f'/单位/{"日" if kind == "base_diets" else "轮"}') if diet['inputs'] else '无实物投入')]
            if diet.get('juvenile_only'):
                fields.append(field('stage', '适用阶段', '仅幼体'))
            if diet.get('flower_source'):
                fields.append(field('flower', '花源条件', '额外消耗1份当日花源份额（非库存物品）'))
            if diet.get('outputs'):
                fields.append(field('outputs', '周期产物', quantities_text(diet['outputs']) + '/轮/单位'))
            add_entity(did, 'diet', f'{sid}/{kind}/{diet["id"]}', f'{row["name"]}·{diet["name"]}', 'recipes',
                       [f'species:{sid}'], tagline.split('（')[0], fields, ['rule:husbandry_service'], lock_of(diet.get('research')))
            for rid, rec in RECIPES.items():
                if rec.get('living') is True and rid == diet['id'] and rec['facility'] == row['facility']:
                    LIVING_MAP.append({'recipe': rid, 'species': sid, 'diet': f'{kind}/{diet["id"]}'})

KIND_LABEL = {'habitat': '养殖栖息设施', 'research': '研究设施'}
for fid, row in FAC.items():
    kind = row.get('kind', 'processing')
    fields = [
        field('cost', '建造费用', f'{row["cash"]}元石＋材料 {quantities_text(row["materials"])}＋1AP'),
        field('footprint', '占地/地形', f'{row["footprint"][0]}×{row["footprint"][1]}格；地形：{"水面" if row.get("terrain") == "water" else "陆地"}'),
        field('type', '设施类型', KIND_LABEL.get(kind, '加工设施')),
        field('demolish', '拆除', '1AP；需设施空闲；不返还材料与元石'),
    ]
    if row.get('capacity'):
        fields.append(field('capacity', '容量', f'{row["capacity"]}单位/场（每场单物种）'))
    if row.get('species'):
        fields.append(field('species', '接纳物种', '、'.join(LIVESTOCK[s]['name'] for s in row['species'])))
    recipes_here = [r for r, rec in RECIPES.items() if rec['facility'] == fid]
    if recipes_here and kind not in ('habitat', 'research'):
        fields.append(field('recipes', '支持配方', '、'.join(RECIPE_NAMES[r] for r in recipes_here) + '（一次一批次）'))
    if fid in ('field_service_station', 'growth_lamp'):
        fields.append(field('strategy', '持续生产策略', '不适用（装置不使用持续生产策略）'))
    if 'raw_stone' in row['materials']:
        fields.append(field('substitute', '建材替代', f'普通岩石部分可用复合石板1:1或再生填料2:1整体替代（{row["materials"]["raw_stone"]}份石）'))
    summary = f'{KIND_LABEL.get(kind, "加工设施")}；{row["cash"]}元石'
    add_entity(f'facility:{fid}', 'facility', fid, row['name'], 'facilities', [], summary, fields,
               ['rule:build_substitute'] if 'raw_stone' in row['materials'] else [], lock_of(row.get('research')))

for rid, row in RECIPES.items():
    is_living = row.get('living') is True
    fac_name = FAC[row['facility']]['name']
    fields = [
        field('facility', '执行设施', f'{fac_name}（须已建成；一次一批次；可由负责人按持续生产策略自动启动）'),
        field('inputs', '投入', f'{quantities_text(row["inputs"])}（启动时一次性扣除）'),
        field('outputs', '产出', f'{quantities_text(row["outputs"])}（收取时入仓；完工≠入仓）'),
        field('duration', '批时', f'{row["days"]}自然日（日结推进，无需每日点击）'),
        field('ap', 'AP', f'启动{row["start_ap"]}＋收取{row["claim_ap"]}'),
    ]
    if is_living:
        match = next((m for m in LIVING_MAP if m['recipe'] == rid), None)
        fields.append(field('mode', '执行方式', f'活体工艺：由{LIVESTOCK[match["species"]]["name"]}的特殊食谱执行（整体维护/自动计划），本条目与该食谱同源，勿重复计数' if match else '活体工艺'))
    add_entity(f'recipe:{rid}', 'recipe', rid, RECIPE_NAMES[rid], 'recipes', [],
               f'{fac_name}；{quantities_text(row["outputs"])}；{row["days"]}日', fields,
               ['rule:auto_production'] + (['rule:living_mapping'] if is_living else []), lock_of(row.get('research')))

UNLOCK_LABEL = {'purchases': '采购', 'crops': '种植', 'facilities': '设施', 'recipes': '配方', 'species': '物种', 'diets': '食谱'}
NAME_RESOLVER = {'purchases': lambda t: rname(t), 'crops': lambda t: CROP_NAMES[t], 'facilities': lambda t: FAC[t]['name'],
                 'recipes': lambda t: RECIPE_NAMES[t], 'species': lambda t: LIVESTOCK[t]['name'], 'diets': lambda t: t}
for rid, row in RESEARCH.items():
    unlocks = []
    for section, label in UNLOCK_LABEL.items():
        unlocks += [f'{label}·{NAME_RESOLVER[section](t)}' for t in row['unlocks'][section]]
    fields = [
        field('layer', '层级与前置', f'第{row["layer"]}层；前置：{"、".join(RESEARCH[p]["name"] for p in row["prerequisites"]) or "无"}'),
        field('samples', '样本', f'{quantities_text(row["samples"])}（启动时一次性消耗）'),
        field('fee', '启动费', f'{row["fee"]}元石（一次性；暂停不退款）'),
        field('days', '有效研究日', f'{row["days"]}个（每台每日最多登记1次研究工作：手动1AP或负责人1元石；只等日子不推进）'),
        field('bench', '研究台', '每台同时1个项目；完成知识全农场共享'),
        field('unlocks', '解锁内容', '、'.join(unlocks) if unlocks else '能力标记'),
    ]
    add_entity(f'research:{rid}', 'research', rid, row['name'], 'research', [],
               f'第{row["layer"]}层研究；{row["fee"]}元石＋{row["days"]}有效日；解锁{len(unlocks)}项', fields,
               ['rule:research'], None)

for sid, row in SOURCES.items():
    fields = [
        field('position', '位置', f'({row["position"][0]},{row["position"][1]})，不可开垦、不可被设施覆盖'),
        field('yield', '每批产出', f'{rname(row["item"])}×{row["quantity"]}，手动1AP'),
        field('limit', '每日上限', f'{row["daily_limit"]}{rname(row["item"])}份/日（按物品计；日结重置；手动与雇工共享）'),
        field('worker', '雇工采集', '可指派1名雇工日结执行（成功1次1元石；需农务兼任启用）'),
    ]
    add_entity(f'source:{sid}', 'source', sid, SOURCE_NAMES[sid], 'environment', [],
               f'{rname(row["item"])}×{row["quantity"]}/次；日上限{row["daily_limit"]}', fields, ['rule:day_settle'], None)

for p in EXP['parcels']:
    area = p['rect'][2] * p['rect'][3]
    fields = [
        field('rect', '范围', f'左上({p["rect"][0]},{p["rect"][1]})，{p["rect"][2]}×{p["rect"][3]}共{area}格（连续坐标；原有坐标不变）'),
        field('terrain', '地形', '水面（仅可建水场）' if p['terrain'] == 'water' else '草地（开垦后可耕种）'),
        field('price', '价格', f'{p["price"]}元石（0AP；计入建设支出；重复购买不扣款）'),
        field('requires', '前置', '、'.join(next(x['name'] for x in EXP['parcels'] if x['id'] == r) for r in p['requires']) or '无'),
    ]
    add_entity(f'parcel:{p["id"]}', 'parcel', p['id'], p['name'], 'environment', [],
               f'{"水面" if p["terrain"] == "water" else "草地"}{area}格；{p["price"]}元石', fields, ['rule:expansion'], None)

region = CFG['light']['regions'][0]
add_entity('map:farm_02', 'map', 'farm_02', MAP.get('name', '灵田·水库'), 'environment', [],
           '初始20×22农场＋下方水库；扩地后外接32×22',
           [field('base', '初始范围', '20列×22行；下方[0,14]~[19,21]共20×8为水库'),
            field('expanded', '扩地后范围', f'外接{EXP["size"][0]}×{EXP["size"][1]}（含负列号）；未购地块不可开垦/建造/标记'),
            field('light', '光照区域', f'默认{CFG["light"]["default"]}；左下阴影区{region["level"]}（rect {region["rect"]}）适合喜阴菌菇')],
           ['rule:environment', 'rule:expansion'], None)

# =============================================================================
# processes (canonical model, names resolved for the reading UI)
# =============================================================================
pid = proc('proc:initial', 'initial_grant', '新档初始物资', [], [io(f'resource:{k}', v, '每新档一次性', '新档创建') for k, v in CFG['start_inventory'].items()],
           category_hint='lifecycle')
for k in CFG['start_inventory']:
    produces(k, pid)

for rid, row in RES.items():
    if row['buy_price'] > 0 and rid != 'purifying_mat_culture':
        pid = proc(f'proc:buy:{rid}', 'market_buy', f'市集采购·{row["name"]}',
                   [io('currency:primeval_stone', row['buy_price'], '每份', '交易时')],
                   [io(f'resource:{rid}', None, '每份', '交易时')],
                   research=lock_of(row.get('research'))['research'] if row.get('research') else None,
                   conditions=([f'需先完成研究「{RESEARCH[row["research"]]["name"]}」'] if row.get('research') else []),
                   category_hint='trade')
        produces(rid, pid)
    if row['sell_price'] > 0:
        pid = proc(f'proc:sell:{rid}', 'market_sell', f'市集出售·{row["name"]}',
                   [io(f'resource:{rid}', None, '每份', '交易时')],
                   [io('currency:primeval_stone', row['sell_price'], '每份', '交易时')],
                   conditions=['计入销售收入'], category_hint='trade')
        consumes(rid, pid)
    if row['supply_allowed']:
        pid = proc(f'proc:supply:{rid}', 'order_supply', f'五行供货·{row["name"]}',
                   [io(f'resource:{rid}', None, '数量=ceil(订单需求/供养值)', '交付时')],
                   [io('currency:primeval_stone', None, '回款=数量×卖价＋10%溢价(向下取整)', '交付时')],
                   conditions=['物品元素须等于订单路径；每日3单；需求=12×转数；转数由累计营业收入解锁'], category_hint='trade')
        consumes(rid, pid)

for sid, row in SOURCES.items():
    pid = proc(f'proc:collect:{sid}', 'source_collect', f'{SOURCE_NAMES[sid]}采集',
               [], [io(f'resource:{row["item"]}', row['quantity'], '每次', '采集时')],
               ap=row['ap'], facility=None, conditions=[f'当日配额剩余≥{row["quantity"]}（上限{row["daily_limit"]}）'],
               category_hint='production')
    produces(row['item'], pid)

for cid, row in CROPS.items():
    plant_inputs = dict(row.get('inputs', {}))
    plant_inputs[row['seed']] = plant_inputs.get(row['seed'], 0) + 1
    effects = []
    if row['mode'] == 'culture_each_cycle':
        effects.append('投入中的清水每份润床+30水分')
    pid = proc(f'proc:plant:{cid}', 'plant', f'播种·{CROP_NAMES[cid]}',
               [io(f'resource:{k}', v, '每次播种', '播种时') for k, v in plant_inputs.items()],
               [], ap=1, crop=f'crop:{cid}',
               research=lock_of(row.get('research'))['research'] if row.get('research') else None,
               conditions=[f'占地{row["footprint"][0]}×{row["footprint"][1]}全部已开垦且空闲；非资源点'], effects=effects,
               category_hint='lifecycle')
    for k in plant_inputs:
        consumes(k, pid)
    outputs = [io(f'resource:{k}', v, '每次收获', '收获时') for k, v in row['outputs'].items()]
    effects, note, conditions = [], None, ['植株成熟']
    if row['mode'] == 'tap_or_fell':
        for k, v in row.get('fell_outputs', {}).items():
            outputs.append(io(f'resource:{k}', v, '每次砍伐', '砍伐时', conditions='砍伐时取得并移除植株'))
        effects = [f'留株采收后regrowing，{row["cycle_days"]}日恢复可采']
        note = '收获=留株采收；砍伐=移除植株取木材'
    elif row['mode'] == 'fell_replant':
        note = '仅可砍伐（无留株采收）'
    elif row['mode'] == 'culture_each_cycle':
        note = '收获后移除；再种需重新投料'
    else:
        note = '收获后植株移除，需重新播种'
    if cid == 'oilseed_flower':
        outputs.append(io('resource:oilseed', 1, '授粉加成', '收获时', conditions='本周期被蜂群授粉（多箱不叠加）'))
        produces('oilseed', f'proc:harvest:{cid}')
    pid = proc(f'proc:harvest:{cid}', 'harvest', f'收获·{CROP_NAMES[cid]}', [], outputs,
               ap=1, crop=f'crop:{cid}', conditions=conditions, effects=effects, note=note, category_hint='production')
    for o in outputs:
        if o['entity'].startswith('resource:'):
            produces(o['entity'][9:], pid)
    proc(f'proc:clear:{cid}', 'clear', f'清理·{CROP_NAMES[cid]}', [], [], ap=1, crop=f'crop:{cid}',
         conditions=['存在植株'], effects=['移除植株；不返还投入与产物；选种计划保留'],
         note='无物品产出的合法过程', category_hint='lifecycle')

for kind, item_key, gain in (('irrigate', 'clean_water', '水分'), ('fertilize', 'humus', '肥力')):
    pid = proc(f'proc:{kind}', 'field_care', '浇水' if kind == 'irrigate' else '施肥',
               [io(f'resource:{item_key}', ENV['irrigate_units' if kind == 'irrigate' else 'fertilize_units'], '每次', '执行时')],
               [], ap=1, effects=[f'该格{gain}+{ENV["irrigate_gain" if kind == "irrigate" else "fertilize_gain"]}（上限100）'],
               conditions=['已开垦/已种植格且该值<100'], category_hint='care')
    consumes(item_key, pid)

for fid, row in FAC.items():
    inputs = [io(f'resource:{k}', v, '每次建造', '建造时') for k, v in row['materials'].items()]
    if 'raw_stone' in row['materials']:
        stones = row['materials']['raw_stone']
        inputs.append(io('resource:composite_stone_panel', stones, '每次建造（可选1:1替石）', '建造时', conditions='选择复合石板替代'))
        inputs.append(io('resource:reclaimed_fill', stones * 2, '每次建造（可选2:1替石）', '建造时', conditions='选择再生填料替代'))
    inputs.append(io('currency:primeval_stone', row['cash'], '每次建造', '建造时'))
    pid = proc(f'proc:build:{fid}', 'build', f'建造·{row["name"]}', inputs, [], ap=CFG['construction']['build_ap'],
               facility=f'facility:{fid}',
               research=lock_of(row.get('research'))['research'] if row.get('research') else None,
               conditions=[f'占地全部已购且空闲、不压资源点；地形{"水面" if row.get("terrain") == "water" else "陆地"}'],
               effects=['设施就位；养殖设施创建默认配置'], category_hint='build')
    for k in row['materials']:
        consumes(k, pid)
        if k == 'raw_stone':
            consumes('composite_stone_panel', pid)
            consumes('reclaimed_fill', pid)
    proc(f'proc:demolish:{fid}', 'demolish', f'拆除·{row["name"]}', [], [], ap=CFG['construction']['demolish_ap'],
         facility=f'facility:{fid}', conditions=['设施空闲（无批次/无动物/无在研）'],
         effects=['占地释放；不返还材料与元石'], category_hint='build')

for rid, row in RECIPES.items():
    is_living = row.get('living') is True
    match = next((m for m in LIVING_MAP if m['recipe'] == rid), None)
    pid = proc(f'proc:batch:{rid}', 'craft', f'加工·{RECIPE_NAMES[rid]}',
               [io(f'resource:{k}', v, '每批', '启动时') for k, v in row['inputs'].items()],
               [io(f'resource:{k}', v, '每批', '收取时') for k, v in row['outputs'].items()],
               ap=row['start_ap'] + row['claim_ap'], ap_detail=f'启动{row["start_ap"]}＋收取{row["claim_ap"]}',
               facility=f'facility:{row["facility"]}',
               research=lock_of(row.get('research'))['research'] if row.get('research') else None,
               duration=days_text(row['days']),
               conditions=['设施空闲一次一批；可由负责人按持续生产策略在日结自动启动（保留量只挡自动）'],
               note=('活体配方：实际由%s的特殊食谱执行，本过程与该食谱同源' % LIVESTOCK[match['species']]['name']) if is_living and match else None,
               category_hint='production')
    for k in row['inputs']:
        consumes(k, pid)
    for k in row['outputs']:
        produces(k, pid)

for sid, row in LIVESTOCK.items():
    unit = row.get('unit', UNIT_DEFAULT[sid])
    fac = f'facility:{row["facility"]}'
    research = lock_of(row.get('research'))['research'] if row.get('research') else None
    pid = proc(f'proc:buy_juvenile:{sid}', 'buy_juvenile', f'购入·{row["name"]}幼体',
               [io('currency:primeval_stone', row['juvenile_price'], f'每{unit}', '购入时')], [], ap=0,
               facility=fac, species=f'species:{sid}', research=research,
               conditions=['剩余容量' + ('；市集菌种被拦截，实际走本购入流程' if sid == 'purifying_mat' else '')],
               effects=[f'{unit}占用容量，成长0'], category_hint='lifecycle')
    base_default = next(d for d in row['base_diets'] if d['id'] == row['default_base_diet'])
    inputs = [io(f'resource:{k}', v, f'每{unit}·每日', '整体维护时') for k, v in base_default['inputs'].items()]
    if sid == 'bell_bee':
        inputs = [io('resource:clean_water', 1, f'每{unit}·每日', '整体维护时')]
    for d in row['base_diets']:
        if d['id'] == row['default_base_diet']:
            continue
        for k, v in d['inputs'].items():
            inputs.append(io(f'resource:{k}', v, f'每{unit}·每日', '整体维护时', conditions=f'基础食谱选用「{d["name"]}」时'))
    for d in row['special_diets']:
        for k, v in d['inputs'].items():
            inputs.append(io(f'resource:{k}', v, f'每{unit}·每轮', '周期启动时一次付清', conditions=f'空闲成体启动「{d["name"]}」周期时'))
    effects = ['登记当日基础服务；幼体+1有效日']
    if sid == 'bell_bee':
        effects = ['登记当日基础服务', f'每{unit}额外消耗1份当日花源份额（非库存）']
    if sid == 'purifying_mat':
        effects = ['幼体培养清水；在制批次靠盖章服务日推进']
    pid = proc(f'proc:maintain:{sid}', 'maintain', f'整体维护·{row["name"]}', inputs, [], ap=HUSB['maintenance_ap'],
               facility=fac, species=f'species:{sid}',
               conditions=['今日未服务个体；水场投喂要求水体预测>30；整批执行，缺料不部分投'],
               effects=effects, category_hint='care')
    for d in row['base_diets'] + row['special_diets']:
        for k in d['inputs']:
            consumes(k, pid)
    claim_outputs = [io(f'resource:{k}', v, f'每{unit}·每轮', '收取时') for k, v in row['outputs'].items()]
    for d in row['special_diets']:
        d_out = d.get('outputs', row['outputs'])
        if row['outputs'] and d_out == row['outputs']:
            continue
        for k, v in d_out.items():
            claim_outputs.append(io(f'resource:{k}', v, f'每{unit}·每轮', '收取时', conditions=f'周期使用「{d["name"]}」时按该食谱产物收取'))
    proc(f'proc:claim:{sid}', 'claim', f'收取·{row["name"]}', [], claim_outputs, ap=HUSB['claim_ap'],
         facility=fac, species=f'species:{sid}',
         conditions=['有待收周期（不受当日投喂/水体限制）'],
         effects=['移除个体（需重新购入）' if row['claim_removes'] else '保留个体（回到空闲成体）'], category_hint='production')
    for k in row['outputs']:
        produces(k, f'proc:claim:{sid}')
    for d in row['special_diets']:
        for k in d.get('outputs', row['outputs']):
            produces(k, f'proc:claim:{sid}')
    proc(f'proc:cull:{sid}', 'cull', f'清退·{row["name"]}', [], [], ap=HUSB['maintenance_ap'],
         facility=fac, species=f'species:{sid}', conditions=['场内有个体'],
         effects=['移除全部个体；放弃待收与在制；不退款'], category_hint='lifecycle')

wc = HUSB['water']['change']
pid = proc('proc:water_change', 'water_change', '水场换水（真实）',
           [io('resource:clean_water', sum(wc['inputs'].values()), '每次', '执行时')],
           [io('resource:wastewater', wc['wastewater'], '每次', '执行时')],
           ap=HUSB['water']['maintenance_ap'],
           conditions=['场内有鱼；水体<100；每场每日最多1次'],
           effects=[f'水体+{wc["gain"]}（上限100）'], category_hint='care')
consumes('clean_water', pid)
produces('wastewater', pid)

pid = proc('proc:pick_flower', 'flower_pick', '手采花源',
           [], [io(f'resource:{k}', v, '每次（每株每日1份额）', '采集时') for k, v in FLOWERS['contents'].items()],
           ap=1,
           conditions=[f'花株当日合格：蜜铃须成熟；油籽花进度{FLOWERS["oilseed_window"][0]}~{FLOWERS["oilseed_window"][1] - 1}；每格水≥{FLOWERS["min_water"]}、肥≥{FLOWERS["min_fertility"]}、光照差≤{FLOWERS["light_tolerance"]}；份额未被蜂群用掉'],
           category_hint='production')
for k in FLOWERS['contents']:
    produces(k, pid)

proc('proc:hive_share', 'flower_share', '蜂群基础服务的花源份额', [], [], ap=0,
     conditions=['与手采共享同一份额池；蜂箱外扩2格覆盖；按稳定顺序分配'],
     effects=['每群每日消耗1份额（份额内容物不落入仓库）；油籽花被用则该株授粉+1'], category_hint='care')

for rid, row in RESEARCH.items():
    pid = proc(f'proc:research_start:{rid}', 'research_start', f'启动研究·{row["name"]}',
               [io(f'resource:{k}', v, '一次性', '启动时') for k, v in row['samples'].items()]
               + [io('currency:primeval_stone', row['fee'], '一次性', '启动时')], [], ap=0,
               facility='facility:research_bench',
               conditions=['研究台空闲', f'前置研究：{"、".join(RESEARCH[pr]["name"] for pr in row["prerequisites"]) or "无"}', '全场未完成该项目'],
               category_hint='research')
    for k in row['samples']:
        consumes(k, pid)
    proc(f'proc:research_work:{rid}', 'research_work', f'研究工作·{row["name"]}', [], [], ap=1,
         facility='facility:research_bench',
         duration=f'{row["days"]}有效研究日', conditions=['每台每日1次；手动1AP或负责人1元石'],
         effects=['每登记1次+1有效日；完成即全农场解锁'], category_hint='research')

lamp = DEVICES['lamp']
pid = proc('proc:lamp_fuel', 'device_fuel', '补光灯开日耗油',
           [io(f'resource:{lamp["fuel"]["item"]}', lamp['fuel']['units'], '每灯·每个开日', '开日（次日开日事务内）')],
           [], ap=0, facility='facility:growth_lamp',
           conditions=['灯已启用；覆盖（外扩2格）内有作物才耗油；无作物不耗；缺油当日不亮'],
           effects=['覆盖格有效光照=max(自然光,80)，持续到下一次日结'], category_hint='device')
consumes(lamp['fuel']['item'], pid)
for service, srow in DEVICES['station']['services'].items():
    label = '浇水' if service == 'irrigate' else '施肥'
    pid = proc(f'proc:station:{service}', 'device_service', f'田间站自动{label}',
               [io(f'resource:{srow["item"]}', srow['units'], '每格·每次', '开日逐格执行')], [], ap=0,
               facility='facility:field_service_station',
               conditions=[f'该服务已开启；仅覆盖内低于阈值（默认{DEVICES["station"]["threshold"]}，可调1~99）的已开垦/种植格；每项每日最多{DEVICES["station"]["daily_limit"]}次，按格轮转'],
               effects=[f'该格{"水分" if service == "irrigate" else "肥力"}+{srow["gain"]}（上限100）'],
               note='不占雇工次数、不扣AP、不收工资；保留量不约束设备', category_hint='device')
    consumes(srow['item'], pid)

for p in EXP['parcels']:
    proc(f'proc:land:{p["id"]}', 'land_buy', f'购地·{p["name"]}',
         [io('currency:primeval_stone', p['price'], '一次性', '购买时')], [], ap=0,
         conditions=['前置地块已购；元石足额'],
         effects=[f'开放{p["rect"][2] * p["rect"][3]}格{"水面" if p["terrain"] == "water" else "草地"}；不赠物资；泉水日产量不变'],
         category_hint='land')

proc('proc:worker_farm', 'worker_farm', '雇工农务（委托日结）', [], [], ap=0, fee=1,
     conditions=['农务兼任显式启用（默认关闭）；8类工作：采集/开垦/播种/收获/浇水/施肥/砍伐/清理；与设施任务共享每日12次与个人预算'],
     effects=['日结执行框选标记与选种计划'], category_hint='worker')

# =============================================================================
# resource entities + resolved source/use rows
# =============================================================================
def _relation_row(p, io_row, direction):
    others = [(f'{o["name"]}×{o["quantity"]}' if o['quantity'] is not None else f'{o["name"]}×按公式')
                for o in (p['inputs'] + p['outputs']) if o['entity'] != io_row['entity']]
    return {
        'process': p['id'], 'name': p['name'], 'type': p['type'], 'category_hint': p['category_hint'],
        'quantity': io_row['quantity'], 'basis': io_row['basis'], 'timing': io_row['timing'],
        'conditions': io_row.get('conditions', ''),
        'ap': p['ap_detail'], 'duration': p['duration'],
        'facility': p['facility_name'], 'species': p['species_name'], 'crop': p['crop_name'],
        'research': p['research_name'],
        'detail': f'{p["name"]}：{io_row["name"]}×{io_row["quantity"] if io_row["quantity"] is not None else "按订单/库存"}（{io_row["basis"]}）'
                  + (f'｜{p["facility_name"]}' if p['facility_name'] else '')
                  + (f'｜{p["species_name"]}' if p['species_name'] else '')
                  + (f'｜需研究「{p["research_name"]}」' if p['research_name'] else '')
                  + (f'｜{p["duration"]}' if p['duration'] != '即时' else '')
                  + (f'｜{p["ap_detail"]}' if p['ap'] else ''),
        'others': '；'.join(others[:6]),
    }


GU = {r['id']: r for r in SRC.get('logistics', {}).get('definitions', [])}
for gid, row in GU.items():
    hosts = [f for f in FAC.values() if f.get('gu_slot') == row['slot'] and f.get('kind','facility') in row['host_kinds']]
    effect = {'production': '独立生产', 'light': '环境光照', 'growth_speed': '定向生长速度',
              'water_saving': '定向水分减耗', 'fertility_saving': '定向肥力减耗',
              'research_flat': '固定研究工作量减免', 'research_speed': '研究速度倍率',
              'breed_speed': '实际繁殖进度倍率', 'work_speed': '实际动物劳动倍率'}[row['effect']]
    fields = [field('rank','转数',f'{row["rank"]}转原型；实例支持一至五转，升转由上游负责'),
        field('obtain','获取','每档一次试用配给共15只：饭袋草/催生/锁水/节肥/安抚/驭兽各2只，明光/智道研究/宙道研究各1只；尚未连接上游获取与成长'),
        field('deploy','部署','独立占用1格陆地，不需开垦/农田' if row['deployment']=='independent' else '入驻兼容设施：'+'、'.join(f['name'] for f in hosts)),
        field('effect','能力',{
            'production':'自身进行生产，条件与产物见下方',
            'light':f'范围外扩{row["range"]}格，提供光照{row["value"]}，同格光照取最大',
            'growth_speed':f'宿主四向3×3服务区，完整覆盖的植物目标生产速度×{row["value"]/100:g}；同tag最高转优先',
            'water_saving':f'宿主四向3×3服务区，完整覆盖目标的水分扣耗保留{row["value"]}%（每格百分之一余量跨日累计）',
            'fertility_saving':f'宿主四向3×3服务区，完整覆盖目标的肥力扣耗保留{row["value"]}%（每格百分之一余量跨日累计）',
            'research_flat':f'研究工作量固定减少{row["value"]}，至少保留1',
            'research_speed':f'每个有效研究日推进{row["value"]/100:g}工作量',
            'breed_speed':f'实际合格繁殖进度×{row["value"]/100:g}，每单位服务4空间',
            'work_speed':f'实际获岗劳动点×{row["value"]/100:g}，每单位服务4空间'}[row['effect']]),
        field('fee','维护',f'启用时{row["fee"]}元石/游戏日；闲置仍收费，休眠/未部署免维护'),
        field('food','特殊食料',quantities_text(row['food'])+'（每个成功付费服务日；与元石原子扣除）'),
        field('timing','时点','部署/撤回各1AP；启用次日生效；停用立即取消后续效果，已付不退；运行/待收任务锁定实例')]
    if row.get('production'):
        p = row['production']
        fields += [field('production','生产',f'{p["days"]}有效日；启动投入{quantities_text(p["inputs"])}；收取{quantities_text(p["outputs"])}，1AP'),
            field('environment','环境',f'光照≥{p["min_light"]}、水分≥{p["min_water"]}，不足暂停保留进度；每推进日扣水分{p["water_use"]}，不扣肥力；清水浇水或田间站可补水')]
    if row['effect']=='research_speed': fields.append(field('materials','研究样本',f'基础样本逐项×{row.get("material_percent",100)/100:g}向上取整；一次性启动费不变'))
    if row['effect']=='light': fields.append(field('fuel','灯光模式','入驻补光灯后替代精炼油供能；休眠不自动回退燃油；自然光/灯/蛊取最大值，喜阴作物可能降效'))
    add_entity('gu:'+gid,'gu',gid,row['name'],'logistics',row['tags'],effect,fields,['rule:logistics'])
    pid = proc('proc:gu-maintenance:'+gid,'gu_maintenance',row['name']+'·每日维护',
        [io('currency:primeval_stone',row['fee'],'每只·每日','开日')] + [io('resource:'+k,v,'每只·每日','开日') for k,v in row['food'].items()],
        [], species='gu:'+gid, conditions=['已部署且启用；元石与食料同时足额；同服务日只结算一次'],effects=['激活当日能力'], category_hint='logistics')
    for k in row['food']: consumes(k,pid)
    if row.get('production'):
        p=row['production']
        pid=proc('proc:gu-produce:'+gid,'gu_production',row['name']+'·生产收取',
            [io('resource:'+k,v,'每批','启动') for k,v in p['inputs'].items()],
            [io('resource:'+k,v,'每批','完成后收取') for k,v in p['outputs'].items()],ap=1,species='gu:'+gid,
            duration=f'{p["days"]}有效生产日（可受催生加速）',conditions=['光照/水分达标、已付当日维护；完成待收不继续耗水'],category_hint='logistics')
        for k in p['inputs']: consumes(k,pid)
        for k in p['outputs']: produces(k,pid)
        pid=proc('proc:gu-water:'+gid,'gu_water',row['name']+'·浇水',
            [io('resource:clean_water',ENV['irrigate_units'],'每次','手动补水')],[],ap=1,species='gu:'+gid,
            effects=[f'占地水分+{ENV["irrigate_gain"]}，上限100，不改变肥力'],category_hint='logistics')
        consumes('clean_water',pid)

# Room rewards are separate conditional sources, never folded into base yield.
if SRC.get('rooms'):
    rooms=SRC['rooms']
    pid=proc('proc:floor:ordinary','floor','铺设普通地板',
        [io('resource:'+k,v,'每格','铺设') for k,v in rooms['floor']['inputs'].items()],[],
        ap=rooms['floor']['place_ap'],conditions=['已购合法空闲陆地；普通地板分隔耕地，拆除不返料'],category_hint='construction')
    for k in rooms['floor']['inputs']: consumes(k,pid)
    for cid,row in CROPS.items():
        seed=row['seed']
        pid=proc('proc:room-seed:'+cid,'room_seed','育种奖励·'+CROP_NAMES[cid],[],
            [io('resource:'+seed,1,'每株首次成熟；成功时','首次成熟收取或成熟清理',conditions=f'{rooms["seed_percent"]}%×首次育种合格生长比例；每株仅判定一次')],
            crop='crop:'+cid,ap_detail='随首次成熟收取，不另耗AP',
            conditions=['育种田或复合农业区；逐株各必需效果单源完整覆盖；成熟已冻结结果'],category_hint='production')
        produces(seed,pid)
    for ident,modes in rooms['primary'].items():
        for mode,item in modes.items():
            name=CROP_NAMES.get(ident,GU.get(ident,{}).get('name',ident))
            pid=proc(f'proc:room-material:{ident}:{mode}','room_material','丰产奖励·'+name+('·砍伐' if mode=='fell' else '·收取'),[],
                [io('resource:'+item,None,'每轮额外份数','合法成熟主产物收取',conditions=f'基础主产物量×{rooms["material_percent"]}%×本轮合格生长比例，整数必得、小数概率再得1份')],
                crop='crop:'+ident if ident in CROPS else None,species='gu:'+ident if ident in GU else None,
                ap_detail='随本轮收取，不另耗AP',conditions=['丰产田或复合农业区；只增主产物；成熟冻结，单轮只领取一次'],category_hint='production')
            produces(item,pid)

if SRC.get('p104'):
    pid=proc('proc:toy:install','installation','装入耐用藤球',
        [io('resource:vine_ball',1,'每个玩具站','装入槽位')],[],ap=1,
        facility='facility:toy_station',conditions=['空槽；长期使用，不消耗耐久'],
        effects=['开启玩具服务'],category_hint='construction')
    consumes('vine_ball',pid)
    pid=proc('proc:toy:remove','installation','卸下耐用藤球',[],
        [io('resource:vine_ball',1,'每个玩具站','卸下槽位')],ap=1,
        facility='facility:toy_station',conditions=['槽内已装入藤球'],category_hint='construction')
    produces('vine_ball',pid)

# All entities exist now; resolve display names that were built during process
# construction before the resource entities were registered.
for _p in processes:
    for _row in _p['inputs'] + _p['outputs']:
        _row['name'] = entity_name(_row['entity'])

# --- icon resolution: prefer the entity's own SVG, fall back by kind ---------
ICON_ROOT = ROOT / 'assets/farming/ui'
ELEMENT_ICON = {'wood': 'wood', 'fire': 'fire', 'earth': 'earth', 'water': 'water', 'gold': 'gold'}


def icon_id_for(e):
    kind, sid = e['kind'], e['source_id']
    if kind == 'resource':
        candidates = [sid, ELEMENT_ICON[RES[sid]['element']]]
    elif kind == 'crop':
        candidates = [sid, 'plant']
    elif kind == 'facility':
        candidates = [sid, 'build']
    elif kind == 'species':
        candidates = [sid, LIVESTOCK[sid]['facility'], 'workers']
    elif kind == 'diet':
        owner = sid.split('/')[0]
        candidates = [sid, owner, LIVESTOCK[owner]['facility'], 'fodder_grass']
    elif kind == 'recipe':
        candidates = [sid, RECIPES[sid]['facility'], 'build']
    elif kind == 'research':
        candidates = [sid, 'research_bench']
    elif kind == 'source':
        candidates = [SOURCES[sid]['item'], 'claim']
    elif kind == 'parcel':
        candidates = [sid, 'area']
    elif kind == 'map':
        candidates = ['fit']
    else:
        candidates = [sid, 'help']
    for candidate in candidates:
        if (ICON_ROOT / (candidate + '.svg')).is_file():
            return candidate
    return 'inspect'



TERMINAL_NOTE = DISPLAY['terminal_products_note']
for rid, row in RES.items():
    b = BAK_RES[rid]
    fields = [
        field('class', '分类', f'{DISPLAY["element_names"][row["element"]]}行·{DISPLAY["form_names"][row["form"]]}·{DISPLAY["stage_names"][row["stage"]]}；标签：{"、".join(row["tags"])}'),
        field('buy', '市集采购', f'{row["buy_price"]}元石/份' if row['buy_price'] > 0 else '不可采购'),
        field('sell', '市集出售', f'{row["sell_price"]}元石/份（计入销售收入）' if row['sell_price'] > 0 else '不可出售'),
    ]
    if row['supply_allowed']:
        fields.append(field('supply', '五行供货', f'可供货（{DISPLAY["element_names"][row["element"]]}行）；供养值{b["supply_value"]}：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价'))
    proxy = next((p for p in DISPLAY['purchase_proxies'] if p['resource'] == rid), None)
    if proxy:
        fields.append(field('purchase', '购买方式', proxy['text']))
    src_rows, use_rows = [], []
    for process_id in sorted(SRC_OF.get(rid, [])):
        p = PROC[process_id]
        for o in p['outputs']:
            if o['entity'] == f'resource:{rid}':
                src_rows.append(_relation_row(p, o, 'source'))
    for process_id in sorted(USE_OF.get(rid, [])):
        p = PROC[process_id]
        for i in p['inputs']:
            if i['entity'] == f'resource:{rid}':
                use_rows.append(_relation_row(p, i, 'use'))
    if not any(r['type'] not in ('market_sell', 'order_supply') for r in use_rows):
        fields.append(field('terminal', '下游用途', '无下游配方：出售与供货是该物品的设计出口' if use_rows else '无任何用途（见购买代理说明）'))
    add_entity(f'resource:{rid}', 'resource', rid, row['name'], 'items', list(row['tags']),
               f'{DISPLAY["element_names"][row["element"]]}行{DISPLAY["form_names"][row["form"]]}；' + (f'可供货（供养值{b["supply_value"]}）' if row['supply_allowed'] else '生产材料'),
               fields, ['rule:market'] + (['rule:orders'] if row['supply_allowed'] else []),
               lock_of(row.get('research')),
               extra={'sources': src_rows, 'uses': use_rows})


# --- structured cross-entry links (pre-resolved for the reading UI) ---------
UNLOCK_ENTITY = {
    'purchases': lambda t: f'resource:{t}',
    'crops': lambda t: f'crop:{t}',
    'facilities': lambda t: f'facility:{t}',
    'recipes': lambda t: f'recipe:{t}',
    'species': lambda t: f'species:{t}',
}


def diet_entities_of(diet_id):
    return [e['id'] for e in entities if e['kind'] == 'diet' and e['source_id'].endswith('/' + diet_id)]


for _e in entities:
    links = []
    kind, sid = _e['kind'], _e['source_id']
    if kind == 'crop':
        links.append(('种子', f'resource:{CROPS[sid]["seed"]}'))
    elif kind == 'species':
        links.append(('适配设施', f'facility:{LIVESTOCK[sid]["facility"]}'))
    elif kind == 'diet':
        links.append(('所属物种', f'species:{sid.split("/")[0]}'))
    elif kind == 'facility':
        for target in FAC[sid].get('species', []):
            links.append(('接纳物种', f'species:{target}'))
        for gid, row in GU.items():
            if FAC[sid].get('gu_slot') == row['slot'] and FAC[sid].get('kind','facility') in row['host_kinds']: links.append(('可入驻后勤蛊','gu:'+gid))
    elif kind == 'gu':
        row = GU[sid]
        for fid,f in FAC.items():
            if f.get('gu_slot') == row['slot'] and f.get('kind','facility') in row['host_kinds']: links.append(('兼容设施','facility:'+fid))
        for rid in row['food']: links.append(('特殊食料','resource:'+rid))
        for rid in row.get('production',{}).get('outputs',{}): links.append(('产物','resource:'+rid))
    elif kind == 'recipe':
        links.append(('执行设施', f'facility:{RECIPES[sid]["facility"]}'))
    elif kind == 'research':
        row = RESEARCH[sid]
        for section, label in UNLOCK_LABEL.items():
            for target in row['unlocks'][section]:
                if section == 'diets':
                    for diet_eid in diet_entities_of(target):
                        links.append(('解锁食谱', diet_eid))
                else:
                    links.append(('解锁' + label, UNLOCK_ENTITY[section](target)))
    if _e.get('locks'):
        links.append(('解锁研究', _e['locks']['research']))
    _e['links'] = [{'label': label, 'entity': eid, 'name': entity_name(eid)}
                   for label, eid in links if eid in ENT or eid == 'currency:primeval_stone']

# rules entities
for rule in CURATED['rules']:
    add_entity(rule['id'], 'rule', rule['id'], rule['name'], 'rules', [],
               rule['statements'][0][:40] + '…',
               [field('statements', '规则说明', '\n'.join(f'{i + 1}. {s}' for i, s in enumerate(rule['statements']))),
                field('refs', '实现依据', '；'.join(f'{r["path"]}::{r["symbol"]}' for r in rule['refs']))],
               [])

# Icon resolution runs once every entity (rules included) exists.
for _e in entities:
    _e['icon'] = icon_id_for(_e)

# =============================================================================
# validation
# =============================================================================
problems = []


def check(condition, message):
    if not condition:
        problems.append(message)


# category coverage
kind_category = {k: c['id'] for c in CURATED['categories'] for k in c['kinds']}
for e in entities:
    check(e['kind'] in kind_category, f'entity kind without category: {e["id"]}')

# registry coverage
for section, registry in (('resources', RES), ('crops', CROPS), ('sources', SOURCES), ('facilities', FAC),
                          ('recipes', RECIPES), ('livestock', LIVESTOCK), ('research', RESEARCH)):
    ids = set(registry)
    covered = {e['source_id'] for e in entities if e['kind'] ==
               {'resources': 'resource', 'crops': 'crop', 'sources': 'source', 'facilities': 'facility',
                'recipes': 'recipe', 'livestock': 'species', 'research': 'research'}[section]}
    check(covered == ids, f'{section} coverage mismatch: missing={sorted(ids - covered)} extra={sorted(covered - ids)}')
diet_ids = {f'{l["id"]}/{k}/{d["id"]}' for l in SRC['livestock'] for k in ('base_diets', 'special_diets') for d in l[k]}
check({e['source_id'] for e in entities if e['kind'] == 'diet'} == diet_ids, 'diet coverage mismatch')
check({e['source_id'] for e in entities if e['kind'] == 'parcel'} == {p['id'] for p in EXP['parcels']}, 'parcel coverage mismatch')

# unique ids
ids = [e['id'] for e in entities] + [p['id'] for p in processes]
check(len(ids) == len(set(ids)), 'duplicate entity/process ids')

# names non-empty
for e in entities:
    check(bool(e['name']), f'empty name: {e["id"]}')

# dangling references
valid = set(ENT) | {'currency:primeval_stone'}
for p in processes:
    for row in p['inputs'] + p['outputs']:
        check(row['entity'] in valid, f'dangling io ref {p["id"]}->{row["entity"]}')
    for key in ('facility', 'species', 'crop', 'research'):
        if p[key]:
            check(p[key] in ENT, f'dangling {key} ref {p["id"]}->{p[key]}')
for e in entities:
    for rid in e['related_rules']:
        check(rid in ENT, f'dangling rule ref {e["id"]}->{rid}')
    if e.get('locks'):
        check(e['locks']['research'] in ENT, f'dangling lock ref {e["id"]}')
    for link in e.get('links', []):
        check(link['entity'] in ENT, f'dangling link ref {e["id"]}->{link["entity"]}')
        check(bool(link['name']), f'link without name {e["id"]}->{link["entity"]}')
    check(bool(e.get('icon')), f'entity without icon {e["id"]}')

# reverse index two-way
for e in entities:
    if e['kind'] != 'resource':
        continue
    rid = e['source_id']
    check({r['process'] for r in e['sources']} == SRC_OF.get(rid, set()), f'reverse index mismatch (sources) {rid}')
    check({r['process'] for r in e['uses']} == USE_OF.get(rid, set()), f'reverse index mismatch (uses) {rid}')

# recipe quantity equality
for rid, row in RECIPES.items():
    p = PROC[f'proc:batch:{rid}']
    pin = {i['entity'][9:]: i['quantity'] for i in p['inputs'] if i['entity'].startswith('resource:')}
    pout = {o['entity'][9:]: o['quantity'] for o in p['outputs'] if o['entity'].startswith('resource:')}
    check(pin == row['inputs'], f'recipe inputs drift {rid}')
    check(pout == row['outputs'], f'recipe outputs drift {rid}')

# living mapping 1:1 + io equality
living = {rid for rid, r in RECIPES.items() if r.get('living') is True}
diet_pairs = {m['recipe'] for m in LIVING_MAP}
check(living == diet_pairs, f'living mapping mismatch: {sorted(living)} vs {sorted(diet_pairs)}')
for m in LIVING_MAP:
    rec = RECIPES[m['recipe']]
    diet = next(d for d in LIVESTOCK[m['species']]['special_diets'] if f"{next(k for k in ('base_diets', 'special_diets') if d in LIVESTOCK[m['species']][k])}/{d['id']}" == m['diet'])
    check(rec['inputs'] == diet['inputs'], f'living io mismatch {m["recipe"]}')
    check(rec['outputs'] == diet.get('outputs', LIVESTOCK[m['species']]['outputs']), f'living outputs mismatch {m["recipe"]}')

# no-source / no-use classification (content-staleness trigger)
whitelist = set(DISPLAY['no_use_whitelist'])
for rid in RES:
    if rid not in SRC_OF and rid not in whitelist:
        problems.append(f'no producing process and not whitelisted: {rid}')
    productive = USE_OF.get(rid, set()) - {f'proc:sell:{rid}', f'proc:supply:{rid}'}
    if not productive and rid not in whitelist and not any(r['type'] in ('market_sell', 'order_supply') for r in ENT[f'resource:{rid}']['uses']):
        problems.append(f'no use at all: {rid}')

# curated rules all present
check({r['id'] for r in CURATED['rules']} == {e['id'] for e in entities if e['kind'] == 'rule'}, 'curated rules mismatch')

# =============================================================================
# output
# =============================================================================
name_index = {}
for e in entities:
    name_index.setdefault(e['name'], []).append(e['id'])

output = {
    'encyclopedia_format': 1,
    'product': CURATED['product'],
    'generated_inputs': [{'path': str(p.relative_to(ROOT)).replace('\\', '/'), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
                         for p in INPUT_PATHS],
    'counts': {
        'entities': len(entities), 'processes': len(processes), 'rules': len(CURATED['rules']),
        'resources': len(RES), 'crops': len(CROPS), 'sources': len(SOURCES), 'facilities': len(FAC),
        'recipes': len(RECIPES), 'livestock': len(LIVESTOCK), 'diets': len(diet_ids), 'research': len(RESEARCH),
        'parcels': len(EXP['parcels']), 'living_mappings': len(LIVING_MAP),
        'logistics': len(GU),
    },
    'categories': CURATED['categories'],
    'display': DISPLAY,
    'vertical_samples': CURATED['vertical_samples'],
    'entities': sorted(entities, key=lambda e: (e['category'], e['id'])),
    'processes': sorted(processes, key=lambda p: p['id']),
}


def dump(data):
    return (json.dumps(data, ensure_ascii=False, sort_keys=True, indent=2) + '\n').encode('utf-8')


def build_bytes():
    return dump(output)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--sample', nargs='*', default=None)
    args = parser.parse_args()
    if problems:
        print('\n'.join('ENCYCLOPEDIA BAKE FAILED: ' + p for p in problems))
        raise SystemExit(1)
    data = dump(output)
    check_data = dump(json.loads(data.decode('utf-8')))
    require(data == check_data, 'nondeterministic output')
    require(data == build_bytes(), 'nondeterministic rebuild')
    if args.sample is not None:
        render_samples(args.sample)
        return
    if args.check:
        require(TARGET.exists() and TARGET.read_bytes() == data,
                'stale encyclopedia output; run bake_encyclopedia.py (inputs changed or bake not run)')
        print('ENCYCLOPEDIA CHECK OK')
        return
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_bytes(data)
    c = output['counts']
    print(f"ENCYCLOPEDIA BAKE OK: {c['entities']} entities / {c['processes']} processes / {c['rules']} rules; "
          f"{c['resources']} resources, {c['diets']} diets, {c['living_mappings']} living mappings")


def render_samples(ids):
    for eid in ids:
        e = ENT.get(eid)
        if e is None:
            print(f'unknown entity: {eid}')
            continue
        print('=' * 72)
        print(f'{e["name"]}  ({e["id"]} · {e["category"]})')
        print(f'摘要：{e["summary"]}')
        if e.get('locks'):
            print(f'解锁：需研究「{e["locks"]["research_name"]}」')
        for f in e['fields']:
            print(f'  {f["label"]}：{f["text"]}')
        for label, rows in (('获取来源', e.get('sources', [])), ('直接用途', e.get('uses', []))):
            if not rows:
                continue
            print(f'  {label}（{len(rows)}条）：')
            for r in rows:
                print(f'    - {r["detail"]}' + (f'｜同批：{r["others"]}' if r['others'] else ''))
        if e['related_rules']:
            print('  关联规则：' + '、'.join(ENT[r]['name'] for r in e['related_rules']))


if __name__ == '__main__':
    try:
        main()
    except ValueError as error:
        raise SystemExit(str(error))
