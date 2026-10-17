"""Install the P10.1 agriculture source definitions. Idempotent; never edits
baked files. Run after configure_phase10.py when building from a fresh tree."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / 'content/farming/p8/production.json'
data = json.loads(path.read_text(encoding='utf-8'))

def upsert(section, row):
    data[section] = [r for r in data[section] if r['id'] != row['id']] + [row]

# P10.1.a freeze (docs/farming/phase-10.1-农业区与辅助蛊.md §12.1): the three
# agriculture gu share the field station's single slot, renamed to
# agriculture_assist; growth_gu keeps its id/fee/food so schema18 receipts
# re-total unchanged, only value 120->150 and the directed scope change.
SLOT = 'agriculture_assist'
for f in data['facilities']:
    if f['id'] == 'field_service_station':
        f['gu_slot'] = SLOT

logistics = data['logistics']
logistics['rotate_ap'] = 1
logistics['provision'] = ['rice_bag_gu', 'rice_bag_gu', 'bright_gu', 'growth_gu', 'wisdom_gu', 'time_gu',
                          'growth_gu', 'water_gu', 'water_gu', 'fert_gu', 'fert_gu']
by_id = {r['id']: r for r in logistics['definitions']}
by_id['rice_bag_gu']['target_tags'] = ['biological_production', 'logistics_gu', 'plant_grow']
by_id['growth_gu'].update(tags=[SLOT, 'plant_growth_speed'], target_tags=['plant_grow'], slot=SLOT,
                          scope='DIRECTED_AREA', range=3, value=150)
upsert_logistics = [
    dict(id='water_gu', name='锁水蛊', role='logistics', rank=1, deployment='host',
         tags=[SLOT, 'plant_water_saving'], target_tags=['plant_grow'], fee=1, food={},
         host_kinds=['facility'], slot=SLOT, scope='DIRECTED_AREA', effect='water_saving', range=3, value=50),
    dict(id='fert_gu', name='节肥蛊', role='logistics', rank=1, deployment='host',
         tags=[SLOT, 'plant_fertility_saving'], target_tags=['plant_grow'], fee=1, food={},
         host_kinds=['facility'], slot=SLOT, scope='DIRECTED_AREA', effect='fertility_saving', range=3, value=50),
]
for row in upsert_logistics:
    logistics['definitions'] = [r for r in logistics['definitions'] if r['id'] != row['id']] + [row]
logistics['definitions'].sort(key=lambda r: ['rice_bag_gu', 'bright_gu', 'growth_gu', 'water_gu', 'fert_gu',
                                             'wisdom_gu', 'time_gu'].index(r['id']))

# Target qualification registry: every ordinary crop plus the plant-shaped
# independent producer carries plant_grow; animals, water and facilities do not.
for row in data['crops']:
    row['target_tags'] = ['plant_grow']

path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

icons = ROOT / 'assets/farming/ui'
shapes = {
    'water_gu': '<path d="M32 4Q50 24 50 36Q50 52 32 52Q14 52 14 36Q14 24 32 4Z" fill="#9fc6d9"/><path d="M22 40Q22 48 32 48Q42 48 42 40" fill="none"/><circle cx="26" cy="36" r="2" fill="#e8f2f7"/><circle cx="36" cy="32" r="2" fill="#e8f2f7"/><path d="M32 52v6M24 58h16" fill="none"/>',
    'fert_gu': '<path d="M20 22Q32 12 44 22L46 34Q46 50 32 54Q18 50 18 34Z" fill="#c9b489"/><path d="M20 22Q32 30 44 22M18 34Q32 40 46 34" fill="none"/><circle cx="27" cy="42" r="2" fill="#7c6a4a"/><circle cx="36" cy="44" r="2" fill="#7c6a4a"/><circle cx="32" cy="38" r="2" fill="#7c6a4a"/><path d="M32 10v-4M26 8l2 4M38 8l-2 4" fill="none"/>',
}
for ident, shape in shapes.items():
    (icons / (ident + '.svg')).write_text('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><g stroke="#527166" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round">' + shape + '</g></svg>\n', encoding='utf-8')
manifest_path = icons / 'manifest.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
manifest['icons'] = sorted({p.stem for p in icons.glob('*.svg')})
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

curated_path = ROOT / 'content/farming/encyclopedia/encyclopedia.json'
curated = json.loads(curated_path.read_text(encoding='utf-8'))
for rule in curated['rules']:
    if rule['id'] == 'rule:logistics':
        rule['statements'][0] = ('后勤蛊与战斗蛊分开；获取、炼制和升转归上游。独立Demo每档可领取一次11只试用实例'
                                 '（饭袋草/催生/锁水/节肥各2只，明光/智道研究/宙道研究各1只），未部署不产生效果也不收费。')
        rule['statements'][4] = ('明光入驻补光灯替代燃油模式；有效光照取自然光、油灯及蛊光最大值。催生、锁水、节肥共用田间维护站'
                                 '单一蛊槽，按农业辅助规则决议（见农业辅助蛊条目），不递归增强效果源。')
rule = dict(id='rule:agriculture', name='农业辅助蛊：定向服务区与效果决议', statements=[
    '催生、锁水、节肥三种农业辅助蛊共用田间维护站的单一蛊槽（兼容标签agriculture_assist）；每座维护站同时只能入驻一只，建筑自身补水/施肥是独立来源，不因蛊停摆而停止。',
    '服务区为宿主四向可转的3×3矩形，按宿主2×2占地与朝向唯一计算；出图自动裁剪到地图内，不授予地权或种植能力。提交转向1AP、次日开日生效；当日已付维护不退，同日不能轮转复用。',
    '作物全部占地格都在单个有效服务区内才获得效果，不拼接多来源局部覆盖；承载即9格种植面积（1×1计1格、2×2计4格），空格无预占收益。',
    '效果按tag互斥分组（plant_growth_speed/plant_water_saving/plant_fertility_saving）：同tag只采用最高转有效来源，同转比实际收益（催生倍率高者强、水肥保留比例低者强），平局以稳定实例ID；异类效果共同生效且不互相增强。',
    '催生只提高当日生长点推进（首轮×1.5），不改成熟目标、不按视觉阶段减天；待收对象不再推进。锁水/节肥分别按保留比例减少目标环境水/肥扣耗（首轮各保留50%），以每格百分之一余量跨日累计，不产生实物、不返还物品、不抬高环境值。',
    '饭袋草蛊属于植物目标但无肥力消耗，节肥对其无效。余量归属地格：收获、重种、取消、换蛊、休眠、转向、拆建与读档都不清除。',
    '未采用的启用来源只要满足扣费条件仍支付维护；缺元石或食料时不授予当日运行资格，普通生产回退基础效率，环境不足的原降效规则保留。'],
    refs=[dict(path='scripts/farming/p8/p10_logistics.gd', symbol='resolve'),
          dict(path='scripts/farming/p8/p10_logistics.gd', symbol='consume_environment')])
curated['rules'] = [r for r in curated['rules'] if r['id'] != rule['id']] + [rule]
curated_path.write_text(json.dumps(curated, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('P10.1 agriculture source definitions configured')
