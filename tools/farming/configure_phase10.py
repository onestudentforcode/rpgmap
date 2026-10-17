"""Install the P10 source definitions. Idempotent; never edits baked files."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / 'content/farming/p8/production.json'
data = json.loads(path.read_text(encoding='utf-8'))

def upsert(section, row):
    data[section] = [r for r in data[section] if r['id'] != row['id']] + [row]

upsert('resources', dict(id='rice', name='稻米', element='wood', form='solid', stage='primary',
    tags=['food', 'grain'], supply_allowed=True, buy_price=0, sell_price=3, cost_source='rice_round'))
upsert('recipes', dict(id='mill_rice', name='稻米磨粉', facility='farm_processor',
    inputs={'rice': 3}, outputs={'grain_meal': 2}, days=1, start_ap=1, claim_ap=1,
    research='farm_preparation', optional_logistics=True))
unlock = next(r for r in data['research'] if r['id']=='farm_preparation')['unlocks']['recipes']
if 'mill_rice' not in unlock:
    unlock.append('mill_rice')
upsert('cost_models', dict(id='rice_round', inputs={'clean_water': 1}, outputs={'rice': {'quantity': 4, 'share': 1}},
    ap=2, days=3, cash=3, basis={'kind': 'animal', 'id': 'rice_gu_provider'}))

# Hosts use explicit facility kinds + slot tags; neither school nor name alone
# decides compatibility. A field station can assist its existing maintenance.
for f in data['facilities']:
    slot = {'research_bench': 'research_assist', 'growth_lamp': 'light_source',
            'field_service_station': 'growth_assist'}.get(f['id'])
    if slot:
        f['gu_slot'] = slot

data['logistics'] = {
    'version': 1, 'deploy_ap': 1, 'claim_ap': 1, 'range_metric': 'rect_expand_anchor',
    'provision': ['rice_bag_gu', 'rice_bag_gu', 'bright_gu', 'growth_gu', 'wisdom_gu', 'time_gu'],
    'definitions': [
        dict(id='rice_bag_gu', name='饭袋草蛊', role='logistics', rank=1, deployment='independent',
             tags=['rice_production'], target_tags=['biological_production', 'logistics_gu'],
             fee=1, food={}, host_kinds=[], slot='', scope='SELF', effect='production',
             range=0, value=100, production=dict(days=3, inputs={}, outputs={'rice': 4},
                 min_water=30, min_light=60, water_use=8, footprint=[1, 1])),
        dict(id='bright_gu', name='明光蛊', role='logistics', rank=1, deployment='host',
             tags=['light_source'], target_tags=['light_consumer'], fee=1, food={},
             host_kinds=['facility'], slot='light_source', scope='AREA', effect='light', range=2, value=80),
        dict(id='growth_gu', name='催生蛊', role='logistics', rank=1, deployment='host',
             tags=['growth_assist'], target_tags=['biological_production'], fee=1, food={},
             host_kinds=['facility'], slot='growth_assist', scope='AREA', effect='growth_speed', range=2, value=120),
        dict(id='wisdom_gu', name='智道研究蛊', role='logistics', rank=1, deployment='host',
             tags=['research_assist', 'research_time_flat'], target_tags=['research_facility'], fee=1, food={},
             host_kinds=['research'], slot='research_assist', scope='HOST', effect='research_flat', range=0, value=1),
        dict(id='time_gu', name='宙道研究蛊', role='logistics', rank=1, deployment='host',
             tags=['research_assist', 'research_speed_multiplier'], target_tags=['research_facility'], fee=2,
             food={'time_feed': 1}, host_kinds=['research'], slot='research_assist', scope='HOST',
             effect='research_speed', range=0, value=200, material_percent=150),
    ]
}
upsert('resources', dict(id='time_feed', name='宙道食料', element='water', form='solid', stage='intermediate',
    tags=['special_feed'], supply_allowed=False, buy_price=2, sell_price=0, cost_source='purchase'))
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
icons = ROOT / 'assets/farming/ui'
shapes = {
    'rice_bag_gu': '<path d="M25 31Q8 18 13 8Q30 8 32 30Q34 10 51 9Q58 22 39 34" fill="#8ab58c"/><path d="M25 29Q10 33 14 48Q16 59 33 59Q52 59 52 44Q50 29 39 29Z" fill="#e7d5a0"/><path d="M22 31Q30 37 43 31M20 48Q32 54 46 46" fill="none"/><circle cx="27" cy="42" r="2" fill="#456953"/><circle cx="39" cy="42" r="2" fill="#456953"/>',
    'rice': '<path d="M10 33Q12 57 32 57Q52 57 54 33Z" fill="#8ab9ac"/><ellipse cx="32" cy="32" rx="22" ry="9" fill="#f4ebca"/><path d="M20 29l4 3m6-6l4 3m6 2l3 3m-14 0l3 3"/>',
    'bright_gu': '<path d="M22 35Q8 16 25 10Q47 4 50 24Q51 34 40 40L39 51H24Z" fill="#f2d998"/><path d="M25 52h14M28 58h8M32 1v5M7 14l5 4M55 39l5 4"/><circle cx="28" cy="29" r="2"/><circle cx="39" cy="28" r="2"/>',
    'growth_gu': '<path d="M32 58V26M32 37Q8 35 10 14Q31 12 32 37M32 27Q33 7 54 9Q57 27 32 27" fill="#94be91"/><circle cx="32" cy="48" r="10" fill="#e5d397"/><path d="M27 49l4 4l7-9" fill="none"/>',
    'wisdom_gu': '<path d="M9 17Q19 10 31 17Q44 10 55 17V51Q43 45 32 52Q21 45 9 51Z" fill="#9dbfc6"/><path d="M32 18v34M16 25l9 1m-9 7l9 1m14-9l9-1m-9 9l9-1"/><circle cx="32" cy="10" r="6" fill="#e7d49a"/>',
    'time_gu': '<path d="M18 6h28M18 58h28M21 7Q17 21 32 31Q47 22 43 7M21 57Q17 43 32 33Q47 43 43 57" fill="#c1b4d4"/><path d="M24 52l8-11l8 11Z" fill="#e7d49a"/><circle cx="32" cy="22" r="3" fill="#f3e4bb"/>',
    'time_feed': '<path d="M12 24L25 8h17l12 16l-9 30H21Z" fill="#bcc7d9"/><path d="M12 24h42M25 8l-4 46m21-46l3 46M21 54l11-30l13 30" fill="none"/><circle cx="32" cy="20" r="4" fill="#ead59d"/>',
}
for ident, shape in shapes.items():
    (icons / (ident+'.svg')).write_text('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><g stroke="#527166" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round">'+shape+'</g></svg>\n', encoding='utf-8')
manifest_path = icons / 'manifest.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
manifest['icons'] = sorted({p.stem for p in icons.glob('*.svg')})
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('P10 source definitions configured')
curated_path = ROOT / 'content/farming/encyclopedia/encyclopedia.json'
curated = json.loads(curated_path.read_text(encoding='utf-8'))
if not any(c['id']=='logistics' for c in curated['categories']):
    curated['categories'].insert(3,dict(id='logistics',title='后勤蛊与协同',kinds=['gu']))
rule = dict(id='rule:logistics',name='后勤蛊部署、维护与生产协同',statements=[
    '后勤蛊与战斗蛊分开；获取、炼制和升转归上游。独立Demo每档可领取一次六只试用实例，未部署不产生效果也不收费。',
    '同实例只占一处，同种不同实例可以并行；研究台只有一个辅助槽。部署/撤回各1AP；次日启用，休眠立即停止未来效果，已付维护不退。',
    '开日按稳定实例顺序检查元石与特殊食料，两者同时足额才原子扣费；闲置启用仍收费；元石不足自动休眠，玩家可申请次日恢复。读档与保存重试不重复扣费。',
    '饭袋草需光照≥60、水分≥30；每推进日扣水分8，不扣肥力、不需农田；3有效日收稻米4、无秸秆。受阻保留在制工作量，待收权益不等于库存。',
    '明光入驻补光灯替代燃油模式；有效光照取自然光、油灯及蛊光最大值。催生覆盖普通作物与独立生产蛊，同类速度取最强，不递归增强效果源。',
    '智道减少研究工作量1（至少1）；宙道每张工作收据推进2工作量、样本逐项×1.5向上取整。每天仍最多一次玩家/雇工研究工作；任务锁定入驻实例和启动方案。',
    '运行中的任务与待收产物锁定实例；取消在制任务不退投入，待收产物须收取。已登记当日研究工作后不能休眠/取消，避免已付工作失效。'],refs=[dict(path='scripts/farming/p8/p10_logistics.gd',symbol='run_opening'),dict(path='scripts/farming/p8/p8_research.gd',symbol='settle')])
curated['rules'] = [r for r in curated['rules'] if r['id'] != rule['id']] + [rule]
for r in curated['rules']:
    if r['id']=='rule:crop_growth':
        r['statements'][0]='每日进度增量 = max(1, floor(水效×肥效×光效/10000×催生倍率))，单位“点”；无催生倍率为1；首季目标=标称天数×100，留株再生目标=再生天数×100'
    if r['id']=='rule:environment':
        r['statements'][2]='有效光照=max(自然光、当日有效油灯光照、当日有效明光蛊光照)；生长、花源资格与界面显示共用此值'
    if r['id']=='rule:day_settle':
        r['statements'][0]=r['statements'][0].replace('研究结算（收据推进）','后勤蛊独立生产（按当日资格）→ 研究结算（收据工作量推进）').replace('次日开日装置（灯→田间站）','次日开日（蛊维护→灯→田间站）')
curated_path.write_text(json.dumps(curated,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
