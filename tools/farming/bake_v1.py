"""Validate and bake the independent V1 resource graph; no V0 content writes."""
import argparse
import copy
import json
import math
from fractions import Fraction
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'content/farming/v1/production.json'
TARGET = ROOT / 'content/farming/baked/v1/production.json'
ELEMENTS = {'wood', 'gold', 'water', 'fire', 'earth'}

def require(condition, message):
    if not condition:
        raise ValueError(message)

def integer(value, low=0, high=1000000):
    return type(value) is int and low <= value <= high

def positive(value):
    return type(value) in (int, float) and math.isfinite(value) and 0 < value <= 1000000

def registry(rows, name):
    require(isinstance(rows, list) and bool(rows), f'{name}: expected nonempty list')
    result = {}
    for row in rows:
        require(isinstance(row, dict), f'{name}: expected object')
        ident = row.get('id')
        require(isinstance(ident, str) and ident.isascii() and ident.replace('_', '').isalnum() and ident not in result, f'{name}: duplicate/invalid id')
        result[ident] = row
    return result

def quantities(value, resources, name, allow_empty=False):
    require(isinstance(value, dict) and (allow_empty or bool(value)), f'{name}: expected quantities')
    for ident, count in value.items():
        require(ident in resources and integer(count, 1), f'{name}: unknown item or invalid quantity: {ident}')

def pair(value):
    return isinstance(value, list) and len(value) == 2 and all(integer(v, 1, 20) for v in value)

def fraction(value):
    return Fraction(str(value))

def pack(value):
    return {'numerator': value.numerator, 'denominator': value.denominator}

def compile_config(source):
    try:
        return _compile(source)
    except (KeyError, TypeError, AttributeError, ZeroDivisionError, OverflowError) as exc:
        raise ValueError(f'invalid V1 field: {exc}') from exc

def _compile(source):
    require(isinstance(source, dict) and integer(source.get('schema'), 1, 1) and source.get('product') == 'farm_demo_v1', 'V1 schema/product required')
    out = copy.deepcopy(source)
    resources = registry(out['resources'], 'resources')
    models = registry(out['cost_models'], 'cost_models')
    crops = registry(out['crops'], 'crops')
    sources = registry(out['sources'], 'sources')
    facilities = registry(out['facilities'], 'facilities')
    recipes = registry(out['recipes'], 'recipes')
    config = out['config']
    require(integer(config['initial_primeval_stones']) and integer(config['ap_per_day'], 1) and config['days_per_term'] == 15, 'invalid economy/time')
    for key in ['ap_weight', 'day_weight']:
        require(positive(config[key]), 'invalid cost weight')
    require(integer(config['standard_action_ap'], 1), 'invalid standard action AP')
    quantities(config['start_inventory'], resources, 'start_inventory')
    for value in config['environment'].values():
        require(integer(value, 1, 100), 'invalid environment parameter')
    for value in config['workers'].values():
        require(integer(value, 1), 'invalid worker parameter')
    for ident, item in resources.items():
        require(item['element'] in ELEMENTS and item['form'] in ['solid', 'liquid', 'gas', 'energy'] and item['stage'] in ['primary', 'intermediate', 'refined'], f'{ident}: classification')
        require(isinstance(item['name'], str) and bool(item['name']) and isinstance(item['tags'], list) and item['tags'] and len(set(item['tags'])) == len(item['tags']) and all(isinstance(t, str) and t for t in item['tags']), f'{ident}: labels')
        require(type(item['supply_allowed']) is bool and integer(item['buy_price']) and integer(item['sell_price']), f'{ident}: prices/eligibility')
        require(not item['supply_allowed'] or 'food' in item['tags'] and item['sell_price'] > 0, f'{ident}: eligible food needs price/tag')
        require(item['cost_source'] == 'purchase' or item['cost_source'] in models, f'{ident}: cost source')
        if item['cost_source'] == 'purchase':
            require(item['buy_price'] > 0, f'{ident}: purchase cost unavailable')
    for ident, model in models.items():
        quantities(model['inputs'], resources, ident, True)
        require(integer(model['ap']) and integer(model['days']) and integer(model['cash']), f'{ident}: cost cash/AP/time')
        require(isinstance(model['outputs'], dict) and bool(model['outputs']), f'{ident}: outputs')
        shares = Fraction(0)
        for iid, output in model['outputs'].items():
            require(iid in resources and integer(output['quantity'], 1) and positive(output['share']), f'{ident}: output share/quantity')
            shares += fraction(output['share'])
        require(shares == 1, f'{ident}: output shares must sum to one')
    known_sources = {iid: [] for iid in resources}
    consumers = {iid: [] for iid in resources}
    for iid, item in resources.items():
        if item['buy_price'] > 0: known_sources[iid].append('market')
        if item['sell_price'] > 0: consumers[iid].append('sale')
        if item['supply_allowed']: consumers[iid].append('orders')
    consumers['clean_water'].append('irrigation')
    consumers['humus'].append('fertilizer')
    for ident, crop in crops.items():
        require(crop['seed'] in resources and 'seed' in resources[crop['seed']]['tags'] and pair(crop['footprint']) and integer(crop['days'], 1), f'{ident}: crop definition')
        require(crop['mode'] in ['harvest_replant', 'fell_replant', 'tap_or_fell', 'culture_each_cycle'], f'{ident}: lifecycle')
        for key in ['water_use', 'fertility_use', 'light']: require(integer(crop[key], 0, 100), f'{ident}: environment')
        if crop['mode'] == 'tap_or_fell': require(integer(crop['cycle_days'], 1) and bool(crop.get('fell_outputs')), f'{ident}: tree cycle')
        if crop['mode'] == 'culture_each_cycle': require(crop['inputs'].get('wood_chip', 0) > 0, f'{ident}: recurring substrate')
        quantities(crop['inputs'], resources, ident, True)
        quantities(crop['outputs'], resources, ident)
        quantities(crop.get('fell_outputs', {}), resources, ident, True)
        for iid in [crop['seed'], *crop['inputs']]: consumers[iid].append(ident)
        for iid in {*crop['outputs'], *crop.get('fell_outputs', {})}: known_sources[iid].append(ident)
    positions = set()
    for ident, entry in sources.items():
        position = entry['position']
        require(isinstance(position, list) and len(position) == 2 and all(integer(v, 0, bound) for v, bound in zip(position, [19, 13])) and tuple(position) not in positions, f'{ident}: source position')
        positions.add(tuple(position))
        require(entry['item'] in resources and integer(entry['quantity'], 1) and integer(entry['daily_limit'], entry['quantity']) and entry['daily_limit'] % entry['quantity'] == 0 and integer(entry['ap'], 1, config['ap_per_day']), f'{ident}: daily capacity')
        known_sources[entry['item']].append(ident)
    for ident, facility in facilities.items():
        require(pair(facility['footprint']) and integer(facility['cash']), f'{ident}: facility')
        quantities(facility['materials'], resources, ident)
        for iid in facility['materials']: consumers[iid].append('build:' + ident)
    for ident, recipe in recipes.items():
        require(recipe['facility'] in facilities and integer(recipe['days'], 1), f'{ident}: facility/time')
        for key in ['start_ap', 'claim_ap']: require(integer(recipe[key], 1, config['ap_per_day']), f'{ident}: AP')
        quantities(recipe['inputs'], resources, ident)
        quantities(recipe['outputs'], resources, ident)
        for iid in recipe['inputs']: consumers[iid].append(ident)
        for iid in recipe['outputs']: known_sources[iid].append(ident)
    # A canonical cost basis must describe a real production batch, not a parallel
    # independently edited recipe with a different yield or processing duration.
    for ident, model in models.items():
        basis = model['basis']
        kind, producer_id = basis['kind'], basis['id']
        groups = {'recipe': recipes, 'crop': crops, 'source': sources}
        require(kind in groups and producer_id in groups[kind], f'{ident}: missing production basis')
        producer = groups[kind][producer_id]
        expected = ({producer['item']: producer['quantity']} if kind == 'source' else producer['outputs'])
        require({iid: row['quantity'] for iid, row in model['outputs'].items()} == expected, f'{ident}: basis yield mismatch')
        if kind == 'recipe':
            require(model['inputs'] == producer['inputs'] and model['days'] == producer['days'] and model['ap'] == producer['start_ap'] + producer['claim_ap'], f'{ident}: recipe cost mismatch')
        elif kind == 'source':
            require(not model['inputs'] and model['days'] == 0 and model['ap'] == producer['ap'], f'{ident}: collection cost mismatch')
        else:
            required = {producer['seed']: 1, **producer['inputs']}
            require(all(model['inputs'].get(iid) == count for iid, count in required.items()) and set(model['inputs']) <= set(required) | {'clean_water'} and model['days'] == producer['days'], f'{ident}: crop baseline mismatch')
            operations = model['operations']
            require(isinstance(operations, dict) and set(operations) == {'till', 'plant', 'harvest', 'irrigate'} and all(integer(v) for v in operations.values()), f'{ident}: standard operations')
            expected_irrigation = 0 if producer['mode'] == 'culture_each_cycle' else math.ceil(model['inputs'].get('clean_water', 0) / config['environment']['irrigate_units'])
            require(operations['till'] == math.prod(producer['footprint']) and operations['plant'] == 1 and operations['harvest'] == 1 and operations['irrigate'] == expected_irrigation and model['ap'] == sum(operations.values()) * config['standard_action_ap'], f'{ident}: standard AP mismatch')
    # Reachability includes construction prerequisites: a facility cannot require its own only output.
    reachable = {iid for iid, item in resources.items() if item['buy_price'] > 0} | {entry['item'] for entry in sources.values()}
    built = set()
    while True:
        before = (len(reachable), len(built))
        for ident, crop in crops.items():
            if {crop['seed'], *crop['inputs']} <= reachable: reachable.update({*crop['outputs'], *crop.get('fell_outputs', {})})
        for ident, facility in facilities.items():
            if set(facility['materials']) <= reachable: built.add(ident)
        for recipe in recipes.values():
            if recipe['facility'] in built and set(recipe['inputs']) <= reachable: reachable.update(recipe['outputs'])
        if before == (len(reachable), len(built)): break
    require(reachable == set(resources) and built == set(facilities), 'unreachable resource/facility construction dependency')
    for iid in resources: require(known_sources[iid] and consumers[iid], f'{iid}: orphan source/consumer')
    orders = out['orders']
    require(integer(orders['base_demand'], 1) and integer(orders['daily_limit'], 1, 20) and orders['premium_percent'] == 10, 'invalid orders')
    require(set(orders['paths']) == ELEMENTS and len(orders['paths']) == 5, 'five order paths required')
    unlocks = orders['rank_unlock_revenue']
    require(set(unlocks) == {'1','2','3','4','5'} and all(integer(v) for v in unlocks.values()) and unlocks['1'] == 0 and all(unlocks[str(r)] < unlocks[str(r+1)] for r in range(1,5)), 'rank thresholds')
    for element in ELEMENTS:
        require(any(item['element'] == element and item['supply_allowed'] and item['cost_source'] != 'purchase' and any(s != 'market' for s in known_sources[iid]) for iid, item in resources.items()), f'{element}: no produced food')
    costs, visiting, audit = {}, set(), {}
    def cost(iid):
        if iid in costs: return costs[iid]
        require(iid not in visiting, f'cyclic standard cost: {iid}')
        visiting.add(iid)
        item = resources[iid]
        if item['cost_source'] == 'purchase': value = Fraction(item['buy_price'])
        else:
            model = models[item['cost_source']]
            require(iid in model['outputs'], f'{iid}: absent from cost source outputs')
            total = Fraction(model['cash']) + sum((cost(key)*count for key, count in model['inputs'].items()), Fraction(0)) + model['ap']*fraction(config['ap_weight']) + model['days']*fraction(config['day_weight'])
            require(total > 0, f'{iid}: free standard production')
            output = model['outputs'][iid]
            value = total*fraction(output['share'])/output['quantity']
            audit[model['id']] = {'total': pack(total), 'outputs': {key: pack(total*fraction(row['share'])/row['quantity']) for key,row in model['outputs'].items()}}
        visiting.remove(iid)
        costs[iid] = value
        return value
    for iid, item in resources.items():
        value = cost(iid)
        item['standard_cost'] = pack(value)
        item['supply_value'] = max(1, math.ceil(value)) if item['supply_allowed'] else 0
        item['path_ids'] = [item['element']]
        item['sources'], item['consumers'] = sorted(set(known_sources[iid])), sorted(set(consumers[iid]))
        if item['supply_allowed'] and item['buy_price'] > 0:
            require(item['buy_price']*100 > item['sell_price']*(100+orders['premium_percent']), f'{iid}: buy-to-order arbitrage')
        require(item['buy_price'] == 0 or item['buy_price'] >= item['sell_price'], f'{iid}: direct trade arbitrage')
    out['cost_audit'] = audit
    return out

def dump(data):
    return (json.dumps(data, ensure_ascii=False, sort_keys=True, indent=2) + '\n').encode('utf-8')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    compiled = compile_config(json.loads(SOURCE.read_text(encoding='utf-8')))
    result = dump(compiled)
    require(result == dump(compile_config(json.loads(SOURCE.read_text(encoding='utf-8')))), 'nondeterministic bake')
    if args.check:
        require(TARGET.exists() and TARGET.read_bytes() == result, 'baked V1 output stale; run bake_v1.py')
    else:
        TARGET.parent.mkdir(parents=True, exist_ok=True)
        TARGET.write_bytes(result)
    print(f'V1 BAKE OK: {len(compiled["resources"])} resources, {len(compiled["recipes"])} recipes, five supply paths')

if __name__ == '__main__':
    try: main()
    except ValueError as error: raise SystemExit(f'V1 BAKE FAILED: {error}')
