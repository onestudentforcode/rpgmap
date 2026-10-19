"""P10/P10.1 data contract validation shared by baking and negative probes."""
from bake_v1 import require, integer, quantities, registry

# P10.1.a freeze: directed 3x3 service zone and the P10 baseline provision.
DIRECTED_ZONE = 3
P10_PROVISION = ['rice_bag_gu', 'rice_bag_gu', 'bright_gu', 'growth_gu', 'wisdom_gu', 'time_gu']
AGRI_SLOT = 'agriculture_assist'
AGRI_TAG = {'growth_speed': 'plant_growth_speed', 'water_saving': 'plant_water_saving',
            'fertility_saving': 'plant_fertility_saving'}
# P10.1.a first-round frozen numbers for rank-1 agriculture definitions.
AGRI_RANK1_VALUE = {'growth_speed': 150, 'water_saving': 50, 'fertility_saving': 50}
PLANT_GROW_TARGETS = {'golden_wheat', 'fast_fir', 'resin_tree', 'wood_decay_mushroom',
                      'pasture_grass', 'honeybell_bush', 'oilseed_flower', 'mulberry_tree', 'rice_bag_gu'}

def validate(source):
    cfg = source['logistics']
    require(cfg['version'] == 1 and cfg['range_metric'] == 'rect_expand_anchor', 'unknown logistics schema/range')
    require(integer(cfg['deploy_ap'], 1, 24) and integer(cfg['claim_ap'], 1, 24)
            and integer(cfg.get('rotate_ap', 0), 1, 24), 'invalid logistics AP')
    rows = registry(cfg['definitions'], 'logistics definitions')
    resources = registry(source['resources'], 'resources')
    facilities = registry(source['facilities'], 'facilities')
    require(isinstance(cfg['provision'], list) and cfg['provision'] and all(i in rows for i in cfg['provision']), 'invalid logistics provision')
    extra = ['soothe_gu']*2 + ['command_gu']*2 if 'p104' in source else []
    require(len(cfg['provision']) == 11+len(extra) and cfg['provision'][:6] == P10_PROVISION and (not extra or cfg['provision'][-4:]==extra), 'provision must preserve P10/P101 and the P104 supplement')
    for row in rows.values():
        require(row['role'] == 'logistics' and integer(row['rank'], 1, 5), 'invalid logistics role/rank')
        require(row['deployment'] in ('host', 'independent') and row['scope'] in ('SELF','HOST','AREA','DIRECTED_AREA'), 'invalid deployment/scope')
        require(integer(row['fee'], 1) and integer(row['value'], 1, 1000) and integer(row['range'], 0, 20), 'invalid effect/maintenance')
        quantities(row['food'], resources, row['id'] + ':food', True)
        for key in ('tags','target_tags'):
            require(isinstance(row[key],list) and row[key] and len(set(row[key]))==len(row[key]) and all(isinstance(t,str) and t for t in row[key]), 'invalid effect tags')
        require(row['effect'] in ('production','light','growth_speed','water_saving','fertility_saving','research_flat','research_speed','breed_speed','work_speed','product_yield','feed_saving'), 'unknown logistics effect')
        directed = row['effect'] in AGRI_TAG
        expected_scope = {'production':'SELF','light':'AREA','growth_speed':'DIRECTED_AREA','water_saving':'DIRECTED_AREA',
                          'fertility_saving':'DIRECTED_AREA','research_flat':'HOST','research_speed':'HOST','breed_speed':'HOST','work_speed':'HOST',
                          'product_yield':'HOST','feed_saving':'HOST'}[row['effect']]
        require(row['scope']==expected_scope, 'effect scope does not match supported evaluator')
        if row['effect']=='growth_speed': require(row['value']>=100,'growth ability must be a positive bonus')
        if row['effect'] in ('water_saving','fertility_saving'): require(integer(row['value'],1,99),'retention must cut consumption strictly')
        if row['effect']=='research_flat': require(row['value']==1,'P10 fixed research reduction is one work unit')
        if row['effect']=='research_speed': require(row['value'] in (100,200),'unsupported fractional research speed')
        if directed:
            require(row['range'] == DIRECTED_ZONE and row['slot'] == AGRI_SLOT and row['deployment'] == 'host',
                    'agriculture effects use the frozen directed 3x3 zone on the shared slot')
            require(AGRI_TAG[row['effect']] in row['tags'] and row['tags'] == [AGRI_SLOT, AGRI_TAG[row['effect']]],
                    'agriculture tags are the shared slot plus exactly one effect group tag')
            if row['rank'] == 1:
                require(row['value'] == AGRI_RANK1_VALUE[row['effect']],
                        'rank-1 agriculture values are frozen until an explicit rebalance')
        else:
            require(row['slot'] != AGRI_SLOT, 'non-agriculture gu must not claim the agriculture slot')
        if row['deployment'] == 'host':
            require(row['slot'] in row['tags'] and any(f.get('gu_slot') == row['slot'] and f.get('kind','facility') in row['host_kinds'] for f in facilities.values()), 'no compatible logistics host')
        else:
            p = row['production']
            require(row['scope']=='SELF' and row['effect']=='production' and p['footprint']==[1,1] and integer(p['days'],1), 'invalid independent production')
            quantities(p['inputs'], resources, 'production inputs', True)
            quantities(p['outputs'], resources, 'production outputs')
            require(all(integer(p[k],1,100) for k in ('min_water','min_light','water_use')), 'invalid production environment')
        require(integer(row.get('material_percent',100),100,1000), 'invalid material multiplier')
        if row['effect'].startswith('research_'):
            require(row.get('material_percent',100)<=150,'unsupported research material percentage')
    # Same-group ranks must never get weaker: growth multipliers rise with rank,
    # retention percentages fall with rank.
    by_tag = {}
    for row in rows.values():
        tag = AGRI_TAG.get(row['effect'])
        if tag:
            by_tag.setdefault(tag, []).append(row)
    for tag, group in by_tag.items():
        group.sort(key=lambda r: r['rank'])
        for weaker, stronger in zip(group, group[1:]):
            require(stronger['rank'] > weaker['rank'] or stronger['value'] == weaker['value'], f'{tag}: rank ordering must be strict')
            if stronger['rank'] > weaker['rank']:
                if tag == 'plant_growth_speed':
                    require(stronger['value'] >= weaker['value'], f'{tag}: higher rank must not weaken growth')
                else:
                    require(stronger['value'] <= weaker['value'], f'{tag}: higher rank must not weaken saving')
    # Target qualification registry: plant_grow marks exactly the ordinary crops
    # plus the plant-shaped independent producer; nothing else may claim it. On
    # the agriculture gu the same field declares what they serve, not carry.
    carriers = {row['id'] for row in source['crops'] if 'plant_grow' in row.get('target_tags', [])}
    for row in rows.values():
        if AGRI_TAG.get(row['effect']):
            require(row['target_tags'] == ['plant_grow'], f"{row['id']}: agriculture gu serve exactly plant_grow")
        elif 'plant_grow' in row.get('target_tags', []):
            carriers.add(row['id'])
    require(carriers == PLANT_GROW_TARGETS, 'plant_grow qualification registry mismatch')
    for row in source['crops']:
        # P10.6 §16.2.8: water crops sit outside agriculture gu service, so
        # only land crops carry the plant_grow qualification.
        wanted = [] if row.get('medium', 'land') == 'water' else ['plant_grow']
        require(row.get('target_tags', []) == wanted, f"{row['id']}: crops carry exactly the plant_grow qualification")
