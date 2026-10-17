"""P10.2 source installation, safe to repeat; baked output is compiler-owned."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'content/farming/p8/production.json'
data=json.loads(path.read_text(encoding='utf-8'))
next(f for f in data['facilities'] if f['id']=='field_service_station')['footprint']=[1,1]
data['rooms']={
    'version':1,'seed_percent':25,'material_percent':25,
    'floor':{'inputs':{'raw_wood':1},'place_ap':1,'remove_ap':1,'refund':False},
    'primary':{
        'golden_wheat':{'harvest':'grain'},'fast_fir':{'fell':'raw_wood'},
        'resin_tree':{'harvest':'resin','fell':'raw_wood'},
        'wood_decay_mushroom':{'harvest':'mushroom'},'pasture_grass':{'harvest':'fodder_grass'},
        'honeybell_bush':{'harvest':'nectar','fell':'twig'},'oilseed_flower':{'harvest':'oilseed'},
        'rice_bag_gu':{'claim':'rice'}},
    'requirements':{'seed':['plant_growth_speed','plant_water_saving'],
                    'material':['plant_growth_speed','plant_fertility_saving']}}
path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
# Reuse the high-resolution body at a uniform half display scale. This changes
# scene placement metadata, never resamples or edits the original PNG.
manifest_path=ROOT/'assets/farming/facilities/facility_manifest.json'
manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
station=manifest['facilities']['field_service_station']
station['footprint']=[1,1]
station['scale_multiplier']=0.5
station['shadow']={'size':[55.5,21.5],'offset':[0,3],'opacity':0.2}
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
ground_path=ROOT/'content/farming/p8/grounding.json'
ground=json.loads(ground_path.read_text(encoding='utf-8'))
ground['facilities']['field_service_station'].update(size=[55.5,21.5],offset=[0,3])
ground_path.write_text(json.dumps(ground,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

curated_path=ROOT/'content/farming/encyclopedia/encyclopedia.json'
curated=json.loads(curated_path.read_text(encoding='utf-8'))
agriculture=next(r for r in curated['rules'] if r['id']=='rule:agriculture')
agriculture['statements'][1]=('田间维护站占1×1，普通补水/施肥范围由占地外扩2格为5×5；蛊服务区独立按朝向计算3×3。'
    '右为+x、下为+y，东/南/西/北服务区左上相对宿主分别为(1,-1)/(-1,1)/(-3,-1)/(-1,-3)。'
    '出图裁剪但不授予地权；转向1AP、次日开日生效，当日已付不退，不能轮转复用。')
rule=dict(id='rule:rooms',name='露天农业区：地板、育种与丰产',statements=[
    '耕地按上下左右连通形成田块，空耕地参加，斜角不连；普通地板、自然地面与设施隔开田块。不要求墙、门、屋顶或中心建筑。',
    '普通地板每格原木1、铺设/改铺/拆除每次1AP，不返材料；耕地沿用开垦1AP，不得覆盖作物、资源点或宿主。地权与自然地形仍限制铺设；换铺面不清空水肥与扣耗余量。',
    '全区催生＋锁水为一级育种田，全区催生＋节肥为一级丰产田，三类齐全为二级复合农业区，同时打开两个奖励通道，不另叠倍。每类可由多站覆盖不同地格，但2×2植物仍需每类各有单源完整覆盖。',
    '每轮只累计真实推进的生长点，最后一天按剩余目标封顶；育种与丰产分别累计合格点。中途补齐、缺供、拆分、扩田与降级只影响未来贡献，成熟空等不增加资格。',
    '完整合格时首次成熟产同种种子1份的概率为25%；实际概率＝25%×首次合格生长点/首次总生长点。成熟时固定结果，随首次成熟收获、砍伐或成熟清理领取，不另耗AP；失败也用掉机会，留株再生不重抽。',
    '每轮额外主产物期望＝本次基础主产物数量×25%×本轮丰产合格点/总生长点；整数必得，小数作为再得1份概率。只增登记主产物，不增副产物、花源份额或蛊本体；饭袋草在合格耕地可增稻米，不产种子。',
    '成熟冻结贡献与随机依据，种子和材料分开判定；查阅、换向、读档、保存失败与重试不重抽或重复发放。基础收成、育种奖励、丰产奖励分别记账，未领取权益不是库存。',
    '当前P8使用schema20，早期P8开发档需新开档，不迁移、不删除旧文件。硬质地板的漏斗、管道与传动后续另案。'],
    refs=[dict(path='scripts/farming/p8/p102_rooms.gd',symbol='advance'),
          dict(path='scripts/farming/p8/p102_rooms.gd',symbol='rewards')])
curated['rules']=[r for r in curated['rules'] if r['id']!=rule['id']]+[rule]
curated_path.write_text(json.dumps(curated,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('P102 SOURCE OK: 1x1 station, floor, room recipes and primary rewards')
