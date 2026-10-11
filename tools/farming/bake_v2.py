"""V2 data audit. Reuses the V1 compiler, derives animal batches from real diets.

This is a static cost reference, not a replacement for P7.b/c animal runtime.
"""
import argparse
import json
from collections import Counter
from fractions import Fraction
from pathlib import Path
import bake_v1 as common

ROOT = common.ROOT
SOURCE = ROOT / 'content/farming/v2/production.json'
TARGET = ROOT / 'content/farming/baked/v2/production.json'

def providers(source):
    require = common.require
    animals = common.registry(source['livestock'], 'livestock')
    resources = common.registry(source['resources'], 'resources')
    facilities = common.registry(source['facilities'], 'facilities')
    for ident, facility in facilities.items():
        require(facility.get('terrain','land') in ('land','water'), f'{ident}: unknown build terrain')
        require(facility.get('terrain','land') != 'water' or ident == 'fish_pond', f'{ident}: only water farms use water terrain')
    h = source['husbandry']
    require(h['reference_population'] == 4 and h['maintenance_ap'] == 1 and h['claim_ap'] == 1, 'invalid whole-facility reference')
    require(h['base_missing'] == 'pause' and h['special_consumption'] == 'cycle_start' and h['service_day'] == 'before_day_end' and h['ready_requires_base'] is True, 'invalid service policy')
    water = h['water']
    require(water == dict(initial=100,maximum=100,decay=5,pause_threshold=30,worker_threshold=60,maintenance_inputs={'clean_water':2},maintenance_gain=40,maintenance_ap=1), 'invalid water reference')
    result = {}
    for ident,a in animals.items():
        require(common.integer(a['juvenile_price'],1) and common.integer(a['growth_days'],1) and common.integer(a['cycle_days'],1) and type(a['claim_removes']) is bool, f'{ident}: lifecycle')
        f=facilities[a['facility']]
        require(f.get('kind') == 'habitat' and f.get('capacity') == 4 and f.get('species') == [ident] and f['footprint'] == [2,2], f'{ident}: habitat capacity')
        require(f.get('terrain') == ('water' if ident == 'filter_algae_carp' else 'land'), f'{ident}: terrain')
        for diets in [a['base_diets'],a['special_diets']]:
            require(isinstance(diets,list) and bool(diets), f'{ident}: diets')
            for diet in diets: common.quantities(diet,resources,ident)
        common.quantities(a['outputs'],resources,ident)
        # Fish are consumed each round; recurring wool excludes establishing the flock.
        days=a['cycle_days'] + (a['growth_days'] if a['claim_removes'] else 0)
        inputs=Counter({iid:q*days*4 for iid,q in a['base_diets'][0].items()})
        inputs.update({iid:q*4 for iid,q in a['special_diets'][0].items()})
        water_ap=0
        if f['terrain'] == 'water':
            inputs.update(water['maintenance_inputs']); water_ap=water['maintenance_ap']
        result[ident]=dict(facility=a['facility'],inputs=dict(inputs),outputs={iid:q*4 for iid,q in a['outputs'].items()},days=days,start_ap=days*h['maintenance_ap']+water_ap,claim_ap=h['claim_ap'],cash=4*a['juvenile_price'] if a['claim_removes'] else 0)
    # Alternative diets and upkeep remain consumers even outside the canonical diet.
    return result

def compile_config(source, map_data=None):
    try:
        out=common.compile_config(source,'farm_demo_v2',providers(source),map_data)
        items={i['id']:i for i in out['resources']}
        for a in out['livestock']:
            for diet in a['base_diets']+a['special_diets']:
                for iid in diet: items[iid]['consumers']=sorted(set(items[iid]['consumers'])|{a['id']})
        for iid in out['husbandry']['water']['maintenance_inputs']:
            items[iid]['consumers']=sorted(set(items[iid]['consumers'])|{'water_maintenance'})
        out['purchase_audit']=purchase_audit(out)
        return out
    except (KeyError,TypeError,AttributeError) as error:
        raise ValueError(f'invalid V2 field: {error}') from error

def purchase_audit(out):
    """Trace recipes to buyable leaves; no shortcut through an unbuyable product.

    This graph uses standard batches; proceeds are the integer order quote for
    that batch. Margins from paid production are informational, not arbitrage.
    """
    items={i['id']:i for i in out['resources']}
    models={i['id']:i for i in out['cost_models']}
    def trace(iid,trail=()):
        common.require(iid not in trail, f'cyclic purchase chain: {iid}')
        item=items[iid]
        if item['buy_price']>0: return {iid:Fraction(1)}
        model=models[item['cost_source']]
        # Zero-input resource points are manual collection, not market purchases.
        if not model['inputs']: return {}
        leaves=Counter()
        quantity=model['outputs'][iid]['quantity']
        for key,count in model['inputs'].items():
            for leaf,units in trace(key,trail+(iid,)).items(): leaves[leaf]+=units*count/quantity
        return dict(leaves)
    audit={}
    for iid,item in items.items():
        if not item['supply_allowed']: continue
        leaves=trace(iid)
        q=1 if item['buy_price']>0 else models[item['cost_source']]['outputs'][iid]['quantity']
        base=q*item['sell_price']; premium=base*out['orders']['premium_percent']//100
        audit[iid]={'quantity':q,'payout':base+premium,'buyable_leaves':{k:common.pack(v*q) for k,v in sorted(leaves.items())},'raw_purchase_cost':common.pack(sum((items[k]['buy_price']*v*q for k,v in leaves.items()),Fraction())),'requires_production':item['buy_price']==0}
    return audit

def outputs():
    m=json.loads((ROOT/'content/farming/maps/farm_02.json').read_text(encoding='utf-8'))
    t=json.loads((ROOT/'content/farming/v2/terrains.json').read_text(encoding='utf-8'))
    common.require(m['size']==[20,22] and m['reservoir']==[0,14,20,8], 'invalid reservoir')
    common.require(len(m['rows'])==22 and all(len(row)==20 for row in m['rows']), 'invalid map dimensions')
    grid=[[m['legend'][c] for c in row] for row in m['rows']]
    for y,row in enumerate(grid):
        common.require(all((c=='water') == (y>=14) for c in row), 'invalid reservoir footprint')
        common.require(set(row) <= {entry['id'] for entry in t['terrains']}, 'unknown map terrain')
    common.require({row['id'] for row in t['terrains']}=={'grass','dirt','stone','tilled','water'} and next(row for row in t['terrains'] if row['id']=='water')['tillable'] is False, 'invalid water terrain')
    for terrain in t['terrains']:
        for path in terrain['textures'].values(): common.require((ROOT/path).is_file(), 'missing terrain texture')
    base=json.loads((ROOT/'content/farming/baked/maps/farm_01.json').read_text(encoding='utf-8'))
    common.require(grid[:14]==base['grid'],'V2 must preserve existing land')
    map_out=dict(schema=1,id=m['id'],name=m['name'],size=m['size'],grid=grid,reservoir=m['reservoir'])
    path=ROOT/'content/farming/baked/maps/farm_02.json'
    compiled=compile_config(json.loads(SOURCE.read_text(encoding='utf-8')),map_out)
    return {TARGET:common.dump(compiled),ROOT/'content/farming/baked/v2/terrains.json':common.dump(t),path:common.dump(map_out)}

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--check',action='store_true'); args=parser.parse_args()
    files=outputs()
    common.require(files==outputs(),'nondeterministic V2 bake')
    for path,data in files.items():
        if args.check: common.require(path.exists() and path.read_bytes()==data,f'stale output: {path.name}')
        else: path.parent.mkdir(parents=True,exist_ok=True); path.write_bytes(data)
    print('V2 BAKE OK: 25 resources / 5 crops / 7 facilities / 13 recipes; static animal cost reference')

if __name__=='__main__':
    try: main()
    except ValueError as error: raise SystemExit(f'V2 BAKE FAILED: {error}')
