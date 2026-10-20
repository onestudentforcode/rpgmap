"""Reproducible P10.7 evidence audit. Reads game files; writes only requested reports.

Standard-cost margins are screening indicators, not cash-flow or whole-farm ROI.
No game configuration, save slot, or historical evidence is modified.
"""

import argparse
from collections import Counter, defaultdict
from fractions import Fraction
import hashlib
import json
import math
from pathlib import Path


FILES = [
    'content/farming/p8/production.json',
    'content/farming/baked/p8/production.json',
    'scripts/farming/v1/v1_data.gd',
    'scripts/farming/v1/v1_orders.gd',
    'scripts/farming/v1/v1_world.gd',
    'scripts/farming/p8/p8_data.gd',
    'scripts/farming/p8/p8_world.gd',
    'scripts/farming/p8/p103_ranch.gd',
    'scripts/farming/p8/p106_water.gd',
    'scripts/farming/p8/p8_research.gd',
    'scripts/farming/p8/p8_devices.gd',
    'scripts/farming/p8/p8_husbandry.gd',
]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def analyze(root, probe_log=None):
    source = json.loads((root / FILES[0]).read_text(encoding='utf-8'))
    baked = json.loads((root / FILES[1]).read_text(encoding='utf-8'))
    resources = {x['id']: x for x in baked['resources']}
    recipes = {x['id']: x for x in source['recipes']}
    facilities = {x['id']: x for x in source['facilities']}
    animals = {x['id']: x for x in source['livestock']}
    research = {x['id']: x for x in source['research']}
    costs = {k: Fraction(v['standard_cost']['numerator'], v['standard_cost']['denominator'])
             for k, v in resources.items()}
    checks = []

    def check(condition, label):
        if not condition:
            raise AssertionError(label)
        checks.append(label)

    def value(items, price='sell_price'):
        return sum(resources[k][price] * v for k, v in items.items())

    def cost(items):
        return float(sum(costs[k] * v for k, v in items.items()))

    def quote(iid, rank):
        r = resources[iid]
        quantity = math.ceil(source['orders']['base_demand'] * rank / r['supply_value'])
        base = quantity * r['sell_price']
        return dict(item_id=iid, rank=rank, quantity=quantity, base=base,
                    premium=base * source['orders']['premium_percent'] // 100,
                    payout=base + base * source['orders']['premium_percent'] // 100)

    check(source['recipes'] == baked['recipes'], 'source/baked recipe definitions agree')
    check(costs['algae_feed'] != costs['duckweed'], 'algae feed is distinct from duckweed')
    quotes = [quote(iid, rank) for iid in ('mineral_scale', 'silk', 'spirit_liquid') for rank in (1, 5)]
    check(quotes[0]['payout'] == 5 and quotes[1]['payout'] == 11, 'scale orders pay 5/11, not 41 per unit')

    # All consumers, including durable construction and one-off research.
    consumers = defaultdict(list)

    def walk(obj, path):
        if isinstance(obj, list):
            for i, child in enumerate(obj):
                ident = child.get('id', i) if isinstance(child, dict) else i
                walk(child, path + [str(ident)])
        elif isinstance(obj, dict):
            for key, val in obj.items():
                if key in resources and isinstance(val, (int, float)):
                    if any(p in ('inputs', 'materials', 'samples', 'fuel') for p in path) and 'outputs' not in path:
                        consumers[key].append({'path': '/'.join(path + [key]), 'quantity': val})
                walk(val, path + [str(key)])

    for section, rows in source.items():
        if section != 'cost_models':
            walk(rows, [section])
    check(any('facilities/growth_lamp/materials' in h['path'] for h in consumers['composite_stone_panel']),
          'composite panel has growth-lamp construction consumer')
    check(any('research/beekeeping/samples' in h['path'] for h in consumers['pollen']),
          'pollen has beekeeping research consumer')
    check(not consumers['reclaimed_fill'], 'reclaimed fill has no catalog consumer')

    # Runtime-qualified ideal steady rounds: 4 animals, six care units/day,
    # enough service capacity, zero fatigue, no gu bonuses or missing meals.
    # Capture animals pay the juvenile and growth meals each replacement cycle.
    rounds = []
    precision = source['p104']['precision']
    care_per_day = source['p103']['fixed_pattern'].count('C') * precision
    for sid, cfg in source['p103']['species'].items():
        natural = cfg.get('natural')
        if not natural:
            continue
        a = animals[sid]
        base = next(x for x in a['base_diets'] if x['id'] == a['default_base_diet'])['inputs']
        special = next(x for x in a['special_diets'] if x['id'] == natural['default_diet'])['inputs']
        cycle = math.ceil(natural['units'] / care_per_day)
        growing = math.ceil(cfg['growth_units'] / care_per_day)
        capture = natural.get('capture', False)
        inputs = Counter({k: v * 4 for k, v in special.items()})
        for k, v in base.items():
            inputs[k] += v * 4 * (cycle * 2 + (growing if capture else 0))
        outputs = {k: v * 4 for k, v in natural['outputs'].items()}
        days = cycle + (growing if capture else 0)
        juvenile_cash = 4 * a['juvenile_price'] if capture else 0
        margin = value(outputs) - cost(inputs) - juvenile_cash
        capacity = source['p103']['stations'][natural['station']]['capacity']
        rounds.append(dict(species=sid, capture=capture, growing_days=growing,
            production_days=cycle, steady_days=days, inputs=dict(inputs), outputs=outputs,
            input_standard_cost=cost(inputs), recurring_juvenile_cash=juvenile_cash,
            sale_value=value(outputs), material_margin=margin,
            margin_per_animal_day=margin / (4 * days),
            margin_per_space_day=margin / (4 * cfg['space'] * days),
            stations_for_4=math.ceil(4 * cfg['space'] / capacity),
            animal_space=cfg['space'],
            claim_ap_lower_bound=source['p103']['ap']['claim_products'],
            excluded=['infrastructure', 'feed loading AP', 'water maintenance',
                      'upstream production capacity', 'startup growth for retained animals',
                      'extra initial qualification/transfer waits']))
    by_species = {x['species']: x for x in rounds}
    check(by_species['pearl_mussel']['steady_days'] == 4, 'retained pearl steady cycle excludes growth')
    check(by_species['gel_jellyfish']['material_margin'] > 0, 'gel baseline screen is positive before overhead')
    check(by_species['mineral_scale_lizard']['material_margin'] < 0, 'scale is not a positive reference under real prices')

    # Work recipes need maintenance and labor even if all explicit inputs are buyable.
    bought = []
    for rid, r in recipes.items():
        if not r['inputs'] or not all(resources[k]['buy_price'] > 0 for k in r['inputs']):
            continue
        cash_margin = value(r['outputs']) - value(r['inputs'], 'buy_price')
        if cash_margin <= 0:
            continue
        row = dict(recipe=rid, explicit_input_cash=value(r['inputs'], 'buy_price'),
                   sale_value=value(r['outputs']), gross_cash_margin=cash_margin,
                   living=r.get('living', False), nominal_days=r['days'],
                   nominal_start_claim_ap=r['start_ap'] + r['claim_ap'])
        work = source['p103']['work']['recipes'].get(rid)
        if work and work['species'] != 'silt_loach':
            a = animals[work['species']]
            diet = next(x for x in a['base_diets'] if x['id'] == a['default_base_diet'])['inputs']
            work_points_day = source['p103']['patterns']['standard'].count('W') * source['p103']['work']['points_per_unit']
            animal_days = Fraction(work['target'], work_points_day)
            row.update(species=work['species'], worker_days_per_batch=float(animal_days),
                       maintenance_standard_per_batch=cost(diet) * float(animal_days),
                       operating_margin_screen=cash_margin - cost(diet) * float(animal_days),
                       warning='fluid throughput bound; actual AP/claim cadence, upkeep and capital excluded')
        else:
            row['margin_per_nominal_ap'] = cash_margin / row['nominal_start_claim_ap']
        bought.append(row)

    # Research closure ignores samples, capital, AP scheduling and modifiers:
    # ideal parallel critical-path bound and one-bench research-work bound.
    def closure(rid):
        result = {rid}
        for parent in research[rid]['prerequisites']:
            result |= closure(parent)
        return result

    def critical(rid):
        return research[rid]['days'] + max((critical(p) for p in research[rid]['prerequisites']), default=0)

    timeline = []
    for rid, r in research.items():
        ancestors = closure(rid)
        timeline.append(dict(id=rid, prerequisites=r['prerequisites'], layer=r['layer'],
            ancestor_fee=sum(research[x]['fee'] for x in ancestors),
            one_bench_work_days=sum(research[x]['days'] for x in ancestors),
            ideal_parallel_critical_days=critical(rid), closure=sorted(ancestors),
            samples=r['samples'], unlock_counts={k: len(v) for k,v in r['unlocks'].items()}))

    # Gates where the species/station is visible before its required feed route.
    def recipe_for_output(iid):
        return [r for r in recipes.values() if iid in r['outputs']]

    blocked = []
    for sid, a in animals.items():
        known = closure(a['research']) if a.get('research') else set()
        for dtype in ('base_diets', 'special_diets'):
            for diet in a[dtype]:
                if diet['id'] != a.get('default_base_diet' if dtype == 'base_diets' else 'default_special_diet'):
                    continue
                for iid in diet['inputs']:
                    producers = recipe_for_output(iid)
                    if resources[iid]['buy_price'] == 0 and producers and all(r.get('research') and r['research'] not in known for r in producers):
                        blocked.append(dict(species=sid, diet=diet['id'], input=iid,
                            species_gate=a.get('research', ''), producer_gates=sorted({r['research'] for r in producers})))

    # Fair alternative routes: net co-product credits, per-unit AP and batch-days.
    route_groups = defaultdict(list)
    for rid,r in recipes.items():
        for iid, quantity in r['outputs'].items():
            credit = value({k:v for k,v in r['outputs'].items() if k != iid})
            maintenance = 0.0
            work = source['p103']['work']['recipes'].get(rid)
            if r.get('living') and work:
                a = animals[work['species']]
                base = next(x for x in a['base_diets'] if x['id'] == a['default_base_diet'])['inputs']
                if work['species'] == 'silt_loach':
                    days_per_batch = work['target'] / care_per_day
                    meals = source['p103']['meals']['water_loach']
                else:
                    days_per_batch = work['target'] / (source['p103']['patterns']['standard'].count('W') * source['p103']['work']['points_per_unit'])
                    meals = source['p103']['meals']['work']
                maintenance = cost(base) * days_per_batch * meals
            route_groups[iid].append(dict(recipe=rid, facility=r['facility'], output_quantity=quantity,
                total_input_standard_cost=cost(r['inputs']), co_output_sale_credit=credit,
                maintenance_standard_cost_screen=maintenance,
                net_standard_per_target=(cost(r['inputs']) + maintenance + r['start_ap'] + r['claim_ap'] + r['days'] - credit) / quantity,
                direct_ap_per_target=(r['start_ap']+r['claim_ap'])/quantity,
                nominal_batch_days=r['days'], living=r.get('living', False),
                limitation='nominal recipe AP/day weights; live post claim batching and upstream capital excluded'))

    # Cost model includes startup and virtual AP/day: this is not cash accounting.
    warnings = []
    wool_model = next(x for x in source['cost_models'] if x['id'] == 'wool')
    sheep_runtime = by_species['steel_sheep']
    if wool_model['inputs'] != sheep_runtime['inputs']:
        warnings.append(dict(id='wool', frozen_model_inputs=wool_model['inputs'],
            runtime_ideal_steady_inputs=sheep_runtime['inputs'], issue='legacy maintenance counts differ'))
    max_buy_profit_sources = [dict(id=x['id'], sale_per_ap=resources[x['item']]['sell_price']*x['quantity']/x['ap'],
        daily_sale_cap=resources[x['item']]['sell_price']*x['daily_limit']) for x in source['sources']]

    # Functional alternatives, not sale-only dead-content flags.
    matrix_recipe = recipes['make_water_retaining_matrix']
    matrix = dict(baked_cost=float(costs['water_retaining_matrix']),
        humus_baked_cost=float(costs['humus']),
        recipe_input_standard_cost=cost(matrix_recipe['inputs']),
        replacement_cost_per_unit=(cost(matrix_recipe['inputs'])+3)/matrix_recipe['outputs']['water_retaining_matrix'],
        replaces='one humus per aquatic crop round; same quantity and no standalone water-saving effect',
        consumers=consumers['water_retaining_matrix'])
    ledger = [dict(id=iid, standard_cost=float(costs[iid]), buy=r['buy_price'], sell=r['sell_price'],
                  supply_allowed=r['supply_allowed'], supply_value=r['supply_value'], consumers=consumers[iid])
              for iid,r in resources.items()]
    result = dict(method='runtime-grounded static screen; not whole-farm profitability',
        source_hashes={p:digest(root/p) for p in FILES},
        checks=checks, quotes=quotes, steady_rounds=rounds, bought_input_routes=bought,
        research_bounds=timeline, feed_gate_mismatches=blocked,
        route_comparisons={k:v for k,v in route_groups.items() if len(v)>1},
        ledger=ledger, matrix=matrix, cost_model_warnings=warnings,
        resource_source_benchmarks=max_buy_profit_sources,
        order_constraints=source['orders'], probe=None)
    if probe_log:
        lines=probe_log.read_text(encoding='utf-8', errors='replace').splitlines()
        raw=next((x.split('P107_PROBE_JSON=',1)[1] for x in lines if 'P107_PROBE_JSON=' in x), None)
        check(raw is not None, 'runtime probe output exists')
        probe=json.loads(raw)
        for q in probe['quotes']:
            expected=quote(q['item_id'], q['rank'])
            check(all(q[k]==v for k,v in expected.items()), 'runtime quote agrees: '+q['item_id']+'/'+str(q['rank']))
        bypass = probe['live_recipe_without_animals']
        check(bypass.get('animals') == 0, 'bypass fixture contains no animals')
        check(all(bypass.get(k, {}).get('ok') for k in ('built', 'start_result', 'end_day', 'claim')),
              'live recipe starts, settles and claims without animals')
        check(bypass.get('stock') == {'charcoal':4, 'humus':1}, 'bypass produces real inventory outputs')
        check(all(not bypass[k].get('saved', False) for k in ('built','start_result','end_day','claim')),
              'probe does not save player slots')
        result['probe']=probe
        result['probe_log_sha256']=digest(probe_log)
    result['checks']=checks
    return result


def markdown(data):
    lines=['# P10.7 evidence audit', '',
        '> Runtime-grounded static screening; prices and economic policy are not frozen.', '',
        '## Verified order quotes', '', '| item | rank | quantity | payout |', '|---|---:|---:|---:|']
    for r in data['quotes']:
        lines.append(f"| {r['item_id']} | {r['rank']} | {r['quantity']} | {r['payout']} |")
    lines += ['', '## Four-animal ideal steady rounds', '',
        'Standard-cost inputs versus ordinary sale; excludes water, AP, upstream capacity and capital.',
        'Retained animals exclude startup; captured animals include recurring juvenile purchase/growth.', '',
        '| species | days | input cost | juvenile cash | sales | material margin | /space-day | stations |',
        '|---|---:|---:|---:|---:|---:|---:|---:|']
    for r in data['steady_rounds']:
        lines.append(f"| {r['species']} | {r['steady_days']} | {r['input_standard_cost']:.3f} | {r['recurring_juvenile_cash']} | {r['sale_value']} | {r['material_margin']:+.3f} | {r['margin_per_space_day']:+.3f} | {r['stations_for_4']} |")
    lines += ['', '## Positive explicit bought-input routes', '',
        '| recipe | gross cash margin | living | maintenance-adjusted screen |', '|---|---:|---|---:|']
    for r in data['bought_input_routes']:
        m=r.get('operating_margin_screen')
        lines.append(f"| {r['recipe']} | {r['gross_cash_margin']} | {r['living']} | {m if m is not None else 'not applicable'} |")
    lines += ['', '## Research bounds (not player unlock dates)', '',
        '| node | prerequisite fee | one bench work days | ideal parallel critical days |', '|---|---:|---:|---:|']
    for r in data['research_bounds']:
        lines.append(f"| {r['id']} | {r['ancestor_fee']} | {r['one_bench_work_days']} | {r['ideal_parallel_critical_days']} |")
    lines += ['', '## Full evidence', '', 'See `evidence.json` for all 84 resource rows, consumers, route comparisons, feed gates, model warnings and runtime probe.', '',
        '## Snapshot hashes', '']
    lines.extend(f"- `{p}`: `{sha}`" for p,sha in data['source_hashes'].items())
    lines += ['', f"Internal checks: {len(data['checks'])}. No production source or save slots were changed.", '']
    return '\n'.join(lines)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--probe-log', type=Path)
    args=parser.parse_args()
    data=analyze(args.root.resolve(), args.probe_log)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir/'evidence.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (args.output_dir/'report.md').write_text(markdown(data),encoding='utf-8')
    print(json.dumps({'checks':len(data['checks']), 'resources':len(data['ledger']),
        'positive_explicit_buy_routes':len(data['bought_input_routes']),
        'feed_gate_mismatches':data['feed_gate_mismatches'],
        'cost_model_warnings':data['cost_model_warnings']},ensure_ascii=True,indent=2))


if __name__=='__main__':
    main()
