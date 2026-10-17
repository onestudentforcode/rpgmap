"""Reject drift between P10.2 data and the implemented room contract."""
from bake_v1 import require, registry

PRIMARY={
    'golden_wheat':{'harvest':'grain'},'fast_fir':{'fell':'raw_wood'},
    'resin_tree':{'harvest':'resin','fell':'raw_wood'},
    'wood_decay_mushroom':{'harvest':'mushroom'},'pasture_grass':{'harvest':'fodder_grass'},
    'honeybell_bush':{'harvest':'nectar','fell':'twig'},'oilseed_flower':{'harvest':'oilseed'},
    'rice_bag_gu':{'claim':'rice'}}

def validate(source):
    c=source['rooms']; facilities=registry(source['facilities'],'facilities')
    require(set(c)=={'version','seed_percent','material_percent','floor','primary','requirements'},'unknown room fields')
    require(facilities['field_service_station']['footprint']==[1,1],'P102 station must occupy one cell')
    require(c['version']==1 and c['seed_percent']==25 and c['material_percent']==25,'unknown room reward contract')
    require(c['requirements']=={'seed':['plant_growth_speed','plant_water_saving'],'material':['plant_growth_speed','plant_fertility_saving']},'invalid room requirements')
    require(c['floor']=={'inputs':{'raw_wood':1},'place_ap':1,'remove_ap':1,'refund':False},'invalid floor cost')
    crops=registry(source['crops'],'crops')
    require(set(c['primary'])==set(crops)|{'rice_bag_gu'},'primary registry incomplete')
    require(c['primary']==PRIMARY,'main product registry drift; byproducts must not receive bonuses')
    for ident,modes in c['primary'].items():
        require(isinstance(modes,dict) and modes,'invalid primary modes')
        for mode,item in modes.items():
            if ident=='rice_bag_gu':
                require(mode=='claim' and item=='rice','invalid gu reward')
                continue
            row=crops[ident]
            expected={'fell'} if row['mode']=='fell_replant' else {'harvest','fell'} if row['mode']=='tap_or_fell' else {'harvest'}
            require(set(modes)==expected,'invalid crop reward modes')
            outputs=row['fell_outputs'] if mode=='fell' and row['mode']=='tap_or_fell' else row['outputs']
            require(item in outputs,'primary absent from base output')
