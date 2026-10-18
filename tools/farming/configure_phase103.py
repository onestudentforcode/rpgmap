"""P10.3 source installation, safe to repeat; baked output is compiler-owned."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'content/farming/p8/production.json'
data=json.loads(path.read_text(encoding='utf-8'))

# New structural facilities for animal zones. Beds use cell density: one
# ordinary floor cell holds a group of four small or medium beds and counts as
# one usable space; only the large bed fills a whole cell with a single bed.
# Group prices keep the original single-cell cost; the large-bed price is a
# first-round draft value (no species sleeps in it this phase).
data['facilities']=[f for f in data['facilities'] if f['id']!='medium_bed_v']
new_facilities=[
    dict(id='dispatch_station',name='调度站',cash=18,materials={'raw_wood':2,'raw_stone':2},
         terrain='land',footprint=[1,1],kind=None),
    dict(id='feed_trough',name='供食槽',cash=6,materials={'raw_wood':2},
         terrain='land',footprint=[1,1],kind=None),
    dict(id='small_bed',name='小床',cash=6,materials={'raw_wood':2},
         terrain='land',footprint=[1,1],kind=None),
    dict(id='medium_bed',name='中床',cash=10,materials={'raw_wood':3},
         terrain='land',footprint=[1,1],kind=None),
    dict(id='large_bed',name='大床',cash=14,materials={'raw_wood':4},
         terrain='land',footprint=[1,1],kind=None),
    dict(id='care_table',name='照料台',cash=24,materials={'wood_plank':2,'raw_stone':2},
         terrain='land',footprint=[1,1],kind=None),
]
for facility in new_facilities:
    data['facilities']=[f for f in data['facilities'] if f['id']!=facility['id']]
    data['facilities'].append(facility)

data['p103']={
    'version':1,
    'species':{
        'steel_sheep':{'space':2,'bed':'medium','growth_units':36,'breed_units':72,
            'natural_units':18,'natural_outputs':{'steel_wool':1,'sheep_manure':1},
            'natural_diet':'iron_supplement'},
        'rock_mole':{'space':1,'bed':'small','growth_units':18,'breed_units':48},
        'rock_belly_beast':{'space':1,'bed':'small','growth_units':24,'breed_units':96}},
    'zones':{
        'nursery':{'min_space':4,'structures':['pen','feed_trough','bed']},
        'enclosure':{'min_space':8,'structures':['pen','feed_trough','bed','care_table']},
        'work':{'min_space':0,'structures':['dispatch_station','rock_workyard']},
        'maintenance':{'min_space':4,'structures':['feed_trough','bed']},
        'pasture':{'min_space':8,'structures':[]}},
    'fatigue':{'work_debt':1,'rest_credit':2,'fail_penalty':12,'cap':100,'enclosure_rest_cap':6,
        'tiers':[{'max':7,'efficiency':100,'label':'正常'},{'max':15,'efficiency':75,'label':'疲倦'},
                 {'max':23,'efficiency':50,'label':'过劳'},{'max':39,'efficiency':0,'label':'罢工'},
                 {'max':100,'efficiency':0,'label':'濒危'}],
        'death_threshold':40,'death_streak':3},
    'work':{'posts_per_yard':4,'points_per_unit':100,
        'recipes':{'break_stone':{'species':'rock_mole','target':400},
                   'break_ore':{'species':'rock_mole','target':400},
                   'concentrate_ore':{'species':'rock_belly_beast','target':800}},
        'default_recipe':'break_stone'},
    'meals':{'nursery':1,'work':1,'enclosure':2},
    'trough_slots':2,
    'bed_facilities':{'small_bed':{'type':'small','slots':4},
                      'medium_bed':{'type':'medium','slots':4},
                      'large_bed':{'type':'large','slots':1}},
    'patterns':{'standard':['M','M','W','W','W','W','R','R'],
                'late':['W','W','R','R','M','M','W','W']},
    'fixed_pattern':['M','M','C','C','C','C','C','C'],
    'ap':{'submit':1,'claim_workyard':1,'claim_products':1,'claim_births':1}}
path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

curated_path=ROOT/'content/farming/encyclopedia/encyclopedia.json'
curated=json.loads(curated_path.read_text(encoding='utf-8'))
rule=dict(id='rule:animal-zones',name='畜牧分区：陆生动物名册与八单位日程',statements=[
    '钢绵羊、啮岩鼹、岩腹兽走名册制：购入即幼体，占用育幼区全时空间与床位；成体在次日日界由玩家选择圈养或役使，未安置则维持等待。三种动物退出旧的每日手动/雇工维护路径，鱼、蜂、菌毯不变。',
    '五类功能区都在普通地板上四邻接划定：育幼区（圈舍＋供食槽＋床，最小空间4）、圈养区（另加照料台，最小空间8）、工作区（调度站＋岩兽工作场）、维持放牧区（食槽＋床，最小空间4）、额外放牧区（最小空间8）。圈舍与食槽等占地不计可用空间，床占地计入；划区、命名、调整0AP。',
    '床采用格内密度：一格普通地板放4张小床或4张中床，以4张一组建造、组价按单格价；大床占满一格仅1张。小床收1空间体型，中床收2空间，严格匹配；同一床位可错时共用不重叠的两单位窗口，跨午夜预约不重置。',
    '每天按八个内部逻辑单位结算（不换算AP）：标准班维持2＋工作4＋额外放牧2，晚班为其平移4格；育幼/圈养固定维持2＋照料6。维持窗口必须连续两单位整段成功：开窗时预约床位、食槽服务位（每槽2只）与窗口空间，窗口结束统一扣一次基础餐（育幼/役使1份、圈养2份）。',
    '维持失败（缺食缺水、床位/空间/结构失效）自窗口结束点固定禁工八单位，可跨天；补食或再次成功都不提前解除。禁工结束且重新取得维持资格后才恢复劳动。',
    '疲劳只在日界更新：下一开日＝clamp(当前＋工作单位－2×有效恢复＋12×失败窗口数, 0, 100)。0-7正常100%、8-15疲倦75%、16-23过劳50%、24-39罢工、40以上濒危；连续第三个开日≥40死亡。圈养照料单位也按恢复计，每日上限12。',
    '岩兽工作场为四个并行岗位，批次归设施：有合格动物实际获岗才开批并扣一次原料，换班保留进度；碎石400/碎矿400/富集800工作点达标待领取，1AP按场领取。正常/疲倦/过劳每劳动单位提供100/75/50整数点。',
    '圈养与育幼按照料单位积累：长成需36/18/24单位；钢绵羊每轮18照料单位产钢绵1＋羊粪1（开轮扣含铁补料1份）。成体圈养且开日疲劳0才累计无性繁殖，72/48/96单位后产同种幼体1只，待安置状态1AP批量领取并检查目标育幼区容量。'],
    refs=[dict(path='scripts/farming/p8/p103_ranch.gd',symbol='_plan_day'),
          dict(path='scripts/farming/p8/p103_ranch.gd',symbol='normalize')])
curated['rules']=[r for r in curated['rules'] if r['id']!=rule['id']]+[rule]
curated_path.write_text(json.dumps(curated,ensure_ascii=False,indent=2)+chr(10),encoding='utf-8')

handbook_path=ROOT/'scripts/farming/p8/p8_handbook.gd'
handbook=handbook_path.read_text(encoding='utf-8')
handbook=handbook.replace('for id in ["rule:agriculture","rule:rooms"]:',
                          'for id in ["rule:agriculture","rule:rooms","rule:animal-zones"]:')
handbook_path.write_text(handbook,encoding='utf-8')
print('P103 SOURCE OK: ranch config and %d structural facilities' % len(new_facilities))
