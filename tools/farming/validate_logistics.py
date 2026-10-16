"""P10 data contract validation shared by baking and negative probes."""
from bake_v1 import require, integer, quantities, registry

def validate(source):
    cfg = source['logistics']
    require(cfg['version'] == 1 and cfg['range_metric'] == 'rect_expand_anchor', 'unknown logistics schema/range')
    require(integer(cfg['deploy_ap'], 1, 24) and integer(cfg['claim_ap'], 1, 24), 'invalid logistics AP')
    rows = registry(cfg['definitions'], 'logistics definitions')
    resources = registry(source['resources'], 'resources')
    facilities = registry(source['facilities'], 'facilities')
    require(isinstance(cfg['provision'], list) and cfg['provision'] and all(i in rows for i in cfg['provision']), 'invalid logistics provision')
    for row in rows.values():
        require(row['role'] == 'logistics' and integer(row['rank'], 1, 5), 'invalid logistics role/rank')
        require(row['deployment'] in ('host', 'independent') and row['scope'] in ('SELF','HOST','AREA'), 'invalid deployment/scope')
        require(integer(row['fee'], 1) and integer(row['value'], 1, 1000) and integer(row['range'], 0, 20), 'invalid effect/maintenance')
        quantities(row['food'], resources, row['id'] + ':food', True)
        for key in ('tags','target_tags'):
            require(isinstance(row[key],list) and row[key] and len(set(row[key]))==len(row[key]) and all(isinstance(t,str) and t for t in row[key]), 'invalid effect tags')
        require(row['effect'] in ('production','light','growth_speed','research_flat','research_speed'), 'unknown logistics effect')
        expected_scope = {'production':'SELF','light':'AREA','growth_speed':'AREA',
                          'research_flat':'HOST','research_speed':'HOST'}[row['effect']]
        require(row['scope']==expected_scope, 'effect scope does not match supported evaluator')
        if row['effect']=='growth_speed': require(row['value']>=100,'growth ability must be a positive bonus')
        if row['effect']=='research_flat': require(row['value']==1,'P10 fixed research reduction is one work unit')
        if row['effect']=='research_speed': require(row['value'] in (100,200),'unsupported fractional research speed')
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
