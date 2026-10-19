"""Validate the new service contract at the same boundary as all P8 content."""
from bake_v1 import require, registry, integer

def validate(source):
    c = source.get('p104')
    require(isinstance(c, dict), 'P104 service contract missing')
    for key, expected in {'version':1, 'precision':100, 'capacity':4, 'birth_percent':10,
                          'carry_cap':10000, 'toy_percent':10, 'toy_recovery':1,
                          'agriculture_min_cells':4, 'install_ap':1, 'system_ap':1}.items():
        require(integer(c.get(key)) and c[key] == expected, 'P104 frozen value: '+key)
    resources = registry(source['resources'], 'resources')
    facilities = registry(source['facilities'], 'facilities')
    recipes = registry(source['recipes'], 'recipes')
    require(c['toy_id']=='vine_ball' and c['toy_station']=='toy_station', 'unknown toy service')
    require(resources['vine_ball']['tags']==['animal_toy'] and not resources['vine_ball']['supply_allowed'], 'toy item classification')
    require(recipes['make_vine_ball']==dict(id='make_vine_ball', facility='woodshop', inputs={'twig':2,'straw':2}, outputs={'vine_ball':1}, days=1, start_ap=1, claim_ap=1), 'vine ball recipe drift/unlock')
    require(facilities['toy_station']['footprint']==[1,1] and facilities['toy_station']['item_slot']=='animal_toy', 'toy host drift')
    for host, slot in c['hosts'].items():
        require(facilities[host]['gu_slot']==slot and facilities[host]['footprint']==[1,1], 'P104 gu host drift')
    gu = registry(source['logistics']['definitions'], 'gu')
    for ident, effect in [('soothe_gu','breed_speed'),('command_gu','work_speed')]:
        require(gu[ident]['effect']==effect and gu[ident]['value']==150 and gu[ident]['fee']==1 and gu[ident]['food']=={}, 'animal gu effect drift')
    require(source['p103']['species']['steel_sheep']['growth_units']==3600, 'growth precision drift')
    require(source['p103']['work']['recipes']['break_stone']['target']==40000, 'work precision drift')
    require(source['p103']['zones']['pasture']['structures']==['toy_station'], 'pasture structure drift')
