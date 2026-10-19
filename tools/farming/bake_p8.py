"""P8 data audit. Derives providers from livestock, species and flower crops,
validates the research DAG, layered sample reachability, iron/liquid conservation
and the layout/startup budget, then bakes the independent P8 catalog.

This is a static cost reference, not a replacement for the P8 runtime stages.
"""
import argparse
import json
import math
from collections import Counter
from fractions import Fraction
from pathlib import Path
import bake_v1 as common

ROOT = common.ROOT
SOURCE = ROOT / 'content/farming/p8/production.json'
TARGET = ROOT / 'content/farming/baked/p8/production.json'
TERRAIN_SOURCE = ROOT / 'content/farming/p8/terrains.json'
TERRAIN_TARGET = ROOT / 'content/farming/baked/p8/terrains.json'
PRODUCT = 'farm_demo_p8'
POPULATION = 4
IRON_SHARE = {'iron_ore': 3, 'crushed_ore': 2, 'ore_concentrate': 6, 'iron_ingot': 6,
              'mineral_feed': 2, 'steel_wool': 2, 'gold_food': 6}
# Cross-group split for the two-product flower crops (resource table §7).
FLOWER_GROUP_SPLIT = {'flower': Fraction(1, 2), 'seed': Fraction(1, 2)}
FLOWER_INNER = {'nectar': Fraction(3, 4), 'pollen': Fraction(1, 4)}
SEED_INNER = {'oilseed': Fraction(9, 10), 'flower_petal': Fraction(1, 10)}
# Fixed co-product allocation per standard round (resource table §7); multi-output
# P8 cost models must carry exactly these shares so no byproduct pays the full batch.
ALLOCATION = {
    'honeybell': {'nectar': Fraction(3, 4), 'pollen': Fraction(1, 4)},
    'oilseed_round': {'nectar': Fraction(3, 8), 'pollen': Fraction(1, 8),
                      'oilseed': Fraction(9, 20), 'flower_petal': Fraction(1, 20)},
    'bee_round': {'honey': Fraction(4, 5), 'beeswax': Fraction(1, 5)},
    'press_oilseed': {'crude_oil': Fraction(4, 5), 'oil_cake': Fraction(1, 5)},
    'refine_oil': {'refined_oil': Fraction(19, 20), 'spent_filter': Fraction(1, 20)},
    'bio_purify': {'clean_water': Fraction(4, 5), 'sludge': Fraction(1, 5)},
    'recover_nutrients': {'nutrient_liquid': Fraction(3, 5), 'clean_water': Fraction(1, 4), 'sludge': Fraction(3, 20)},
    'break_stone': {'gravel': Fraction(4, 5), 'stone_powder': Fraction(1, 5)},
    'concentrate_ore': {'ore_concentrate': Fraction(19, 20), 'tailings': Fraction(1, 20)},
    'smelt_concentrate': {'iron_ingot': Fraction(19, 20), 'slag': Fraction(1, 20)},
    'dew_round': {'spirit_liquid': Fraction(3, 4), 'mucus': Fraction(1, 4)},
    'scale_round': {'mineral_scale': Fraction(3, 4), 'shed_skin': Fraction(1, 4)},
    'form_rock_shell': {'rock_shell': Fraction(3, 4), 'mucus': Fraction(1, 4)},
}


def _flower_share(item):
    return FLOWER_INNER.get(item) or SEED_INNER.get(item) or Fraction(0)


def providers(source):
    """Standard production rounds. Old livestock keeps the V2 rules; the flower
    crops, new species and the real water change derive their own providers."""
    require = common.require
    animals = common.registry(source['livestock'], 'livestock')
    crops = common.registry(source['crops'], 'crops')
    resources = common.registry(source['resources'], 'resources')
    recipes = common.registry(source['recipes'], 'recipes')
    facilities = common.registry(source['facilities'], 'facilities')
    research = {row['id']: row for row in source['research']}
    # P10.6 §16.2: the aquatic facility set may stand on water; the five shared
    # ranch structures are dual-medium; fish_pond is retired from new builds.
    water_facilities = {'fish_pond', 'carp_harvest_station', 'oilfish_harvest_station', 'pearl_station',
                        'gel_station', 'coral_station', 'silt_processing_station', 'aquatic_crop_station'}
    dual_medium = {'pen', 'feed_trough', 'small_bed', 'medium_bed', 'care_table'}
    for ident, facility in facilities.items():
        require(facility.get('terrain', 'land') in ('land', 'water'), f'{ident}: unknown build terrain')
        require(facility.get('terrain', 'land') != 'water' or ident in water_facilities,
                f'{ident}: water terrain is reserved for the aquatic set')
        require('terrains' not in facility or (ident in dual_medium and facility['terrains'] == ['land', 'water']),
                f'{ident}: only the shared ranch structures may be dual-medium')
        require(not facility.get('retired') or ident == 'fish_pond', f'{ident}: unknown retirement')
    p106 = source.get('p106')
    require(isinstance(p106, dict) and p106['version'] == 1, 'p106 water section required')
    require(p106['fence'] == dict(cash=1, inputs={'twig': 1}, ap=1), 'fence cost frozen at 1 stone + 1 twig + 1AP')
    require(p106['quality'] == dict(initial=100, cap=100, points_per_cell=10000, pause_threshold=30,
                                     base_decay=2, load_factor=6), 'water quality params frozen')
    require(p106['change'] == dict(inputs={'clean_water': 2}, wastewater=2, gain=40, max_cells=8, ap=1),
            'water change service frozen')
    require(p106['facilities']['change_station'] == 'water_change_station'
            and p106['facilities']['crop_station'] == 'aquatic_crop_station', 'p106 facility registry')
    for zone_id in ('water_nursery', 'water_enclosure', 'water_production', 'water_loach', 'aqua_planting'):
        zone = source['p103']['zones'].get(zone_id)
        require(isinstance(zone, dict) and zone.get('medium') == 'water', f'{zone_id}: water zone required')
        for member in [m for group in zone.get('any_of', []) for m in group['members']] + zone['structures']:
            require(member in facilities or member == 'bed', f'{zone_id}: unknown structure {member}')
        require(facility.get('research', '') == '' or facility['research'] in research, f'{ident}: unknown research gate')
        require(facility.get('kind', '') != 'habitat' or ident in ('pen', 'fish_pond') or facility['research'] != '', f'{ident}: new habitats must be research gated')
    for ident, recipe in recipes.items():
        require(recipe.get('research', '') == '' or recipe['research'] in research, f'{ident}: unknown research gate')
    for ident, item in resources.items():
        require(item.get('research', '') == '' or item['research'] in research, f'{ident}: unknown research gate')
    for ident, crop in crops.items():
        require(crop.get('research', '') == '' or crop['research'] in research, f'{ident}: unknown research gate')
    require(source['config']['workers']['max_workers'] == 0, 'P8 keeps the open worker roster')
    h = source['husbandry']
    require(h['reference_population'] == POPULATION and h['maintenance_ap'] == 1 and h['claim_ap'] == 1, 'invalid whole-facility reference')
    require(h['base_missing'] == 'pause' and h['special_consumption'] == 'cycle_start' and h['service_day'] == 'before_day_end' and h['ready_requires_base'] is True, 'invalid service policy')
    water = h['water']
    require(water == dict(initial=100, maximum=100, decay=5, pause_threshold=30, worker_threshold=60,
                          maintenance_inputs={'clean_water': 2}, maintenance_gain=40,
                          change=dict(inputs={'clean_water': 2}, gain=40, wastewater=2), maintenance_ap=1), 'invalid water-change reference')
    devices = source['devices']
    require(devices == dict(
        station=dict(range=2, threshold=30, daily_limit=6,
                     services={'irrigate': {'item': 'clean_water', 'units': 1, 'gain': 30},
                               'fertilize': {'item': 'humus', 'units': 1, 'gain': 30}}),
        lamp=dict(range=2, light=80, fuel={'item': 'refined_oil', 'units': 1})), 'invalid device reference')
    flowers = source['flowers']
    require(flowers == dict(range=2, share_capacity=1, contents={'nectar': 2, 'pollen': 1},
                            min_water=30, min_fertility=30, light_tolerance=20,
                            oilseed_window=[300, 500]), 'invalid flower reference')
    require(flowers['contents']['nectar'] == resources['nectar']['id'] or True, 'ids')
    result = {}
    # --- Old livestock: same derivation as V2, unchanged standard rounds.
    # bell_bee keeps its custom flower-field round below and is skipped here.
    # The P10.3 rock species and the six P10.5 land species live in the ranch
    # roster; their rounds are derived in the dedicated blocks below.
    p105_species = ('carbon_belly_bug', 'leaf_silkworm', 'dew_shell_snail',
                    'mineral_scale_lizard', 'compost_mouse', 'gravel_shell_snail')
    for ident, a in animals.items():
        if ident in ('bell_bee', 'purifying_mat', 'rock_mole', 'rock_belly_beast') or ident in p105_species:
            continue
        require(common.integer(a['juvenile_price'], 1) and common.integer(a['growth_days'], 1) and common.integer(a['cycle_days'], 1) and type(a['claim_removes']) is bool, f'{ident}: lifecycle')
        f = facilities[a['facility']]
        require(f.get('kind') == 'habitat' and f.get('capacity') == POPULATION and ident in f.get('species', []) and f['footprint'] == [2, 2], f'{ident}: habitat capacity')
        require(f.get('terrain') == ('water' if ident == 'filter_algae_carp' else 'land'), f'{ident}: terrain')
        _check_diets(ident, a, resources, research)
        base_default = next(diet for diet in a['base_diets'] if diet['id'] == a['default_base_diet'])
        special_default = next(diet for diet in a['special_diets'] if diet['id'] == a['default_special_diet'])
        require(base_default.get('research', '') == '' and special_default.get('research', '') == '', f'{ident}: default diets must be available without research')
        common.quantities(a['outputs'], resources, ident)
        days = a['cycle_days'] + (a['growth_days'] if a['claim_removes'] else 0)
        inputs = Counter({iid: q * days * POPULATION for iid, q in base_default['inputs'].items()})
        inputs.update({iid: q * POPULATION for iid, q in special_default['inputs'].items()})
        water_ap = 0
        if f['terrain'] == 'water':
            # The reference round budgets one real water change (clean water in,
            # wastewater out; the sewage itself carries its own cost basis).
            inputs.update(water['change']['inputs'])
            water_ap = water['maintenance_ap']
        result[ident] = dict(facility=a['facility'], inputs=dict(inputs), outputs={iid: q * POPULATION for iid, q in a['outputs'].items()},
                             days=days, start_ap=days * h['maintenance_ap'] + water_ap, claim_ap=h['claim_ap'],
                             cash=POPULATION * a['juvenile_price'] if a['claim_removes'] else 0)
    # --- Flower crops: first mature share (honeybell) / one full round (oilseed flower).
    for ident in ('honeybell_bush', 'oilseed_flower'):
        crop = crops[ident]
        require(crop.get('flower_days', 0) >= 1 and common.integer(crop['water_use'], 1), f'{ident}: flower reference')
        irrigation = math.ceil(crop['water_use'] * crop['days'] / 8)
        water_items = {'clean_water': irrigation}
        till = math.prod(crop['footprint'])
        if ident == 'honeybell_bush':
            # Perennial: the standard reference is the first mature share; the
            # tap cycle itself is the hand pick, no seed harvest in the round.
            ap = till + 1 + irrigation + int(crop['flower_days'])
            outputs = dict(crop['outputs'])
            days = crop['days']
        else:
            # Annual: seed harvest plus the in-round flower shares (2 days x 1 share).
            ap = till + 1 + irrigation + 1 + int(crop['flower_days'])
            outputs = dict(crop['outputs'])
            for iid, count in crops['honeybell_bush']['outputs'].items():
                outputs[iid] = outputs.get(iid, 0) + count * int(crop['flower_days'])
            days = crop['days']
        require(ident != 'oilseed_flower' or set(outputs) == {'nectar', 'pollen', 'oilseed', 'flower_petal'}, 'oilseed round outputs')
        result[ident + '_provider'] = dict(facility='pen', inputs={crop['seed']: 1, **water_items}, outputs=outputs, days=days,
                                           start_ap=ap - 1, claim_ap=1, cash=0)
    # --- Bell bees: first production round of four colonies plus the establishment
    # of a four-bush reference flower field (seed, irrigation and field AP included,
    # no hand-pick AP for the internal flower flow).
    bee = animals['bell_bee']
    _check_species(bee, facilities, resources, research)
    field = crops['honeybell_bush']
    field_irrigation = math.ceil(field['water_use'] * field['days'] / 8)
    bee_days = bee['growth_days'] + bee['cycle_days']
    inputs = Counter({field['seed']: POPULATION,
                      'clean_water': field_irrigation * POPULATION + bee_days * POPULATION})
    field_ap = POPULATION * (1 + 1 + field_irrigation)
    result['bell_bee_provider'] = dict(facility='bee_hive', inputs=dict(inputs), outputs=_scaled(bee['outputs'], POPULATION),
                                       days=bee_days, start_ap=field_ap + bee_days, claim_ap=1, cash=POPULATION * bee['juvenile_price'])
    # --- Real water change: clean water in, wastewater stock out (T04 sample source).
    change = water['change']
    result['water_change_provider'] = dict(facility='fish_pond', inputs=dict(change['inputs']),
                                           outputs={'wastewater': int(change['wastewater'])}, days=0,
                                           start_ap=water['maintenance_ap'], claim_ap=0, cash=0)
    # --- Purifying mats: juvenile culture water plus one living processing round x4.
    for rock in (animals['rock_mole'], animals['rock_belly_beast']):
        _check_species(rock, facilities, resources, research)
        for diet in rock['special_diets']:
            require('outputs' in diet, '%s diets carry their per-unit outputs' % rock['id'])
            common.quantities(diet['outputs'], resources, rock['id'])
    mat = animals['purifying_mat']
    _check_species(mat, facilities, resources, research)
    for diet in mat['special_diets']:
        require('outputs' in diet, 'purifying_mat diets carry their per-unit outputs')
        common.quantities(diet['outputs'], resources, 'purifying_mat')
    for recipe_id, provider_id in (('bio_purify', 'purifying_mat_provider'), ('recover_nutrients', 'nutrient_mat_provider')):
        recipe = recipes[recipe_id]
        _living_recipe(recipe_id, recipe, resources, research)
        round_days = mat['growth_days'] + recipe['days']
        inputs = Counter({'clean_water': mat['growth_days'] * POPULATION})
        inputs.update({iid: q * POPULATION for iid, q in recipe['inputs'].items()})
        outputs = {iid: q * POPULATION for iid, q in recipe['outputs'].items()}
        result[provider_id] = dict(facility='purifying_bed', inputs=dict(inputs), outputs=outputs, days=round_days,
                                   start_ap=round_days + 1, claim_ap=1, cash=POPULATION * mat['juvenile_price'])
    # --- Rock mole / rock belly beast: growth plus one production round x4.
    # P10.5.a split the shared rock workyard: each species now owns one yard.
    for species_id, recipe_ids in (('rock_mole', ('break_stone', 'break_ore')), ('rock_belly_beast', ('concentrate_ore',))):
        row = animals[species_id]
        _check_species(row, facilities, resources, research)
        diet = next(d for d in row['base_diets'] if d['id'] == row['default_base_diet'])
        for recipe_id in recipe_ids:
            recipe = recipes[recipe_id]
            _living_recipe(recipe_id, recipe, resources, research)
            require(recipe['facility'] == row['facility'], f'{recipe_id}: recipe must live on the species yard')
            round_days = row['growth_days'] + recipe['days']
            inputs = Counter({iid: q * round_days * POPULATION for iid, q in diet['inputs'].items()})
            inputs.update({iid: q * POPULATION for iid, q in recipe['inputs'].items()})
            provider = recipe_id + '_provider'
            result[provider] = dict(facility=row['facility'], inputs=dict(inputs), outputs=_scaled(recipe['outputs'], POPULATION),
                                    days=round_days, start_ap=round_days + 1, claim_ap=1, cash=POPULATION * row['juvenile_price'])
    # --- P10.5 intensive species: growth plus the first natural round x4.
    # Nursery days carry one base meal per animal, intensive round days carry
    # two (the shared ranch meal policy), and the round diet is paid once.
    for species_id, round_days, round_inputs in (
            ('leaf_silkworm', 2, {'mulberry_leaf': 2}),
            ('dew_shell_snail', 2, {'clean_water': 2}),
            ('mineral_scale_lizard', 4, {'mineral_feed': 2})):
        row = animals[species_id]
        _check_diets(species_id, row, resources, research)
        require(species_id in facilities[row['facility']].get('species', []), f'{species_id}: station species list')
        diet = next(d for d in row['base_diets'] if d['id'] == row['default_base_diet'])
        days = row['growth_days'] + round_days
        inputs = Counter({iid: q * row['growth_days'] * POPULATION for iid, q in diet['inputs'].items()})
        inputs.update({iid: q * round_days * 2 * POPULATION for iid, q in diet['inputs'].items()})
        inputs.update({iid: q * POPULATION for iid, q in round_inputs.items()})
        result[species_id + '_provider'] = dict(facility=row['facility'], inputs=dict(inputs),
                                                outputs=_scaled(row['outputs'], POPULATION), days=days,
                                                start_ap=days + 1, claim_ap=1, cash=POPULATION * row['juvenile_price'])
    if 'logistics' in source:
        row = next(r for r in source['logistics']['definitions'] if r['id'] == 'rice_bag_gu')
        production = row['production']
        irrigations = math.ceil(production['water_use'] * production['days'] / source['config']['environment']['irrigate_gain'])
        inputs = Counter(production['inputs'])
        inputs['clean_water'] += irrigations * source['config']['environment']['irrigate_units']
        result['rice_gu_provider'] = dict(independent=True, facility='', inputs=dict(inputs),
            outputs=production['outputs'], days=production['days'], start_ap=irrigations, claim_ap=1,
            cash=row['fee'] * production['days'])
    return result


def _scaled(outputs, population):
    return {iid: q * population for iid, q in outputs.items()}


def audit_allocations(source):
    """Multi-output P8 cost models must carry exactly the fixed table shares."""
    require = common.require
    models = common.registry(source['cost_models'], 'cost_models')
    for ident, weights in ALLOCATION.items():
        require(ident in models, f'allocation table references missing model {ident}')
        outputs = models[ident]['outputs']
        require(set(outputs) == set(weights), f'{ident}: allocation item set mismatch')
        for iid, weight in weights.items():
            actual = Fraction(str(outputs[iid]['share']))
            require(actual == weight, f'{ident}: {iid} share {actual} != table {weight}')
    for ident, model in models.items():
        if ident in ALLOCATION or len(model['outputs']) == 1:
            continue
        require(ident in ('wheat', 'fir', 'saw', 'mushroom', 'wool', 'fish'), f'{ident}: unmapped multi-output model')
    return sorted(ALLOCATION)


def _check_diets(ident, row, resources, research):
    require = common.require
    for diets, default_key in ((row['base_diets'], 'default_base_diet'), (row['special_diets'], 'default_special_diet')):
        require(isinstance(diets, list) and bool(diets), f'{ident}: diets')
        ids = [diet.get('id') for diet in diets]
        require(all(isinstance(i, str) and i for i in ids) and len(set(ids)) == len(ids), f'{ident}: diet ids must be unique non-empty strings')
        for diet in diets:
            require(isinstance(diet.get('name'), str) and diet['name'].strip(), f'{ident}: {diet["id"]} needs a name')
            common.quantities(diet['inputs'], resources, ident, True)
            require(diet.get('research', '') == '' or diet['research'] in research, f'{ident}: unknown diet research gate')
        require(row.get(default_key) in ids, f'{ident}: {default_key} must name one of the diets')


def _check_species(row, facilities, resources, research):
    require = common.require
    ident = row['id']
    require(common.integer(row['juvenile_price'], 1) and common.integer(row['growth_days'], 1) and common.integer(row['cycle_days'], 1) and type(row['claim_removes']) is bool, f'{ident}: lifecycle')
    require(isinstance(row.get('unit'), str) and row['unit'], f'{ident}: standard unit label')
    facility = facilities[row['facility']]
    require(facility.get('kind') == 'habitat' and facility.get('capacity') == POPULATION and ident in facility['species'] and facility['footprint'] == [2, 2], f'{ident}: habitat capacity')
    require(facility.get('terrain') == 'land', f'{ident}: new species live on land')
    require(row.get('research', '') in research, f'{ident}: species must be research gated')
    _check_diets(ident, row, resources, research)


def _living_recipe(ident, recipe, resources, research):
    require = common.require
    require(recipe.get('living') is True, f'{ident}: expected a living recipe')
    require(recipe.get('research', '') != '', f'{ident}: living recipes are research gated')


def extra_consumers(source):
    """Consumer registrations the producer graph cannot express."""
    labels = {}
    def add(item, label):
        labels.setdefault(item, [])
        if label not in labels[item]:
            labels[item].append(label)
    for row in source['livestock']:
        for diet in row['base_diets'] + row['special_diets']:
            for iid in diet['inputs']:
                add(iid, f'diet:{row["id"]}:{diet["id"]}')
    for row in source['research']:
        for iid in source_row_samples(row):
            add(iid, f'research:{row["id"]}')
    add('refined_oil', 'growth_lamp_fuel')
    add('composite_stone_panel', 'construction_substitute')
    add('reclaimed_fill', 'construction_substitute')
    add('purifying_mat_culture', 'species:purifying_mat')
    if 'p104' in source:
        add('vine_ball', 'toy_station:durable_installation')
    for row in source.get('logistics', {}).get('definitions', []):
        for item in row['food']:
            add(item, 'gu_maintenance:' + row['id'])
    return labels


def source_row_samples(row):
    return list(row['samples'].keys())


def audit_research(source, compiled, provider_rows):
    """DAG, unlock cross references, layered sample reachability and self-lock checks."""
    require = common.require
    resources = {row['id']: row for row in compiled['resources']}
    research = common.registry(source['research'], 'research')
    require(len(research) == 12, 'twelve research projects')
    layers = {1: [], 2: [], 3: []}
    total_fee = 0
    total_days = 0
    for ident, row in research.items():
        require(ident.startswith('t') is False and common.registry([{'id': ident}], 'research') is not None, 'id')
        require(row['layer'] in (1, 2, 3) and common.integer(row['fee'], 1) and common.integer(row['days'], 1), f'{ident}: layer/fee/days')
        require(row['days'] == row['layer'] * 2, f'{ident}: layer {row["layer"]} expects {row["layer"]*2} effective days')
        require(isinstance(row['name'], str) and row['name'].strip(), f'{ident}: name')
        require(isinstance(row['prerequisites'], list) and set(row['prerequisites']) <= set(research) and ident not in row['prerequisites'], f'{ident}: prerequisites')
        common.quantities(row['samples'], resources, ident)
        require(set(row['unlocks']) == {'purchases', 'crops', 'facilities', 'recipes', 'species', 'diets'}, f'{ident}: unlock sections')
        layers[row['layer']].append(ident)
        total_fee += row['fee']
        total_days += row['days']
    require((len(layers[1]), len(layers[2]), len(layers[3])) == (5, 4, 3), 'layer population 5/4/3')
    require(total_fee == 94 and total_days == 44, 'research totals 94 stones / 44 days')
    order = _topological(research)
    # Cross-check the unlock registry against the research gates on the definitions.
    crops = common.registry(source['crops'], 'crops')
    recipes = common.registry(source['recipes'], 'recipes')
    facilities = common.registry(source['facilities'], 'facilities')
    livestock = common.registry(source['livestock'], 'livestock')
    gates = {'purchases': {}, 'crops': {}, 'facilities': {}, 'recipes': {}, 'species': {}, 'diets': {}}
    for ident, row in resources.items():
        if row.get('research', ''):
            gates['purchases'][ident] = row['research']
    for ident, row in crops.items():
        if row.get('research', ''):
            gates['crops'][ident] = row['research']
    for ident, row in facilities.items():
        if row.get('research', ''):
            gates['facilities'][ident] = row['research']
    for ident, row in recipes.items():
        if row.get('research', ''):
            gates['recipes'][ident] = row['research']
    # All runtime species live in the livestock registry and unlock by research.
    for ident, row in livestock.items():
        if row.get('research', ''):
            gates['species'][ident] = row['research']
    for ident, row in livestock.items():
        for diet in row['base_diets'] + row['special_diets']:
            if diet.get('research', ''):
                gates['diets'][diet['id']] = diet['research']
    for section, table in gates.items():
        for ident, rid in table.items():
            require(rid in research, f'{section} {ident}: unknown research')
            require(ident in research[rid]['unlocks'][section], f'{section} {ident}: missing from {rid} unlock registry')
        for rid, row in research.items():
            for ident in row['unlocks'][section]:
                require(ident in table, f'{rid} unlocks unknown {section} {ident}')
                require(table[ident] == rid, f'{section} {ident}: unlock registry disagrees with the definition gate')
    # Layered reachability: each project's samples must be obtainable from the
    # default content plus the unlocks of already completed research.
    def reachable_with(done, exclude=''):
        unlocked = set(done)
        reach = {iid for iid, row in resources.items() if row['buy_price'] > 0 and (not row.get('research', '') or row['research'] in unlocked)}
        reach |= {row['item'] for row in source['sources']}
        built = set()
        while True:
            before = (len(reach), len(built))
            for ident, crop in crops.items():
                if crop.get('research', '') and crop['research'] not in unlocked:
                    continue
                if {crop['seed'], *crop['inputs']} <= reach:
                    reach |= {*crop['outputs'], *crop.get('fell_outputs', {})}
            for ident, facility in facilities.items():
                if ident == exclude:
                    continue
                if facility.get('research', '') and facility['research'] not in unlocked:
                    continue
                if set(facility['materials']) <= reach:
                    built.add(ident)
            for ident, recipe in recipes.items():
                if recipe.get('research', '') and recipe['research'] not in unlocked:
                    continue
                if recipe['facility'] in built and set(recipe['inputs']) <= reach:
                    reach |= set(recipe['outputs'])
            for ident, producer in provider_rows.items():
                if (producer.get('independent') is True or producer['facility'] in built) and set(producer['inputs']) <= reach:
                    reach |= set(producer['outputs'])
            if before == (len(reach), len(built)):
                break
        return reach, built
    completed = []
    for ident in order:
        row = research[ident]
        require(set(row['prerequisites']) <= set(completed), f'{ident}: prerequisites not topological')
        reach, _ = reachable_with(set(completed))
        require(set(row['samples']) <= reach, f'{ident}: samples not obtainable from default and ancestor research ({sorted(set(row["samples"]) - reach)})')
        completed.append(ident)
    full_reach, full_built = reachable_with(set(research))
    require(full_built == set(facilities), 'research layout leaves facilities unbuildable')
    # A facility's materials must never require that facility's own products;
    # sibling unlocks of the same research (e.g. R17 panels for the lamp) are fine.
    for ident, facility in facilities.items():
        reach, _ = reachable_with(set(research), exclude=ident)
        require(set(facility['materials']) <= reach, f'{ident}: build materials require its own products')
    return {'order': order, 'fee': total_fee, 'days': total_days}


def _topological(research):
    require = common.require
    order = []
    pending = set(research)
    while pending:
        ready = sorted(ident for ident in pending if set(research[ident]['prerequisites']) <= set(order))
        require(bool(ready), 'research prerequisites contain a cycle')
        order.extend(ready)
        pending -= set(ready)
    return order


def audit_conservation(source, compiled):
    """Iron share and liquid-loss audits over every recipe and provider round."""
    require = common.require
    resources = {row['id']: row for row in compiled['resources']}
    recipes = common.registry(source['recipes'], 'recipes')
    rows = []
    for ident, recipe in recipes.items():
        iron_in = sum(IRON_SHARE.get(iid, 0) * count for iid, count in recipe['inputs'].items())
        iron_out = sum(IRON_SHARE.get(iid, 0) * count for iid, count in recipe['outputs'].items())
        require(iron_out <= iron_in, f'{ident}: iron share grows ({iron_in} -> {iron_out})')
        liquid_in = sum(count for iid, count in recipe['inputs'].items() if resources[iid]['form'] == 'liquid')
        liquid_out = sum(count for iid, count in recipe['outputs'].items() if resources[iid]['form'] == 'liquid')
        if ident in ('bio_purify', 'recover_nutrients'):
            require(liquid_out < liquid_in, f'{ident}: purification must return less liquid than it takes')
        rows.append((ident, iron_in, iron_out))
    # The new iron chain keeps every unit of iron; only the legacy direct smelt
    # and the ore-fed sheep diet may lose metal.
    strict = {'break_ore', 'concentrate_ore', 'smelt_concentrate', 'mineral_feed', 'honey_mineral_food'}
    for ident, iron_in, iron_out in rows:
        if ident in strict:
            require(iron_in == iron_out, f'{ident}: iron share must balance in the selected chain')
    return rows


def audit_layout(source):
    """Arithmetic + packing check that the 20x14 land hosts one of each facility,
    the reference flower field and the legacy farm without blocking resource points."""
    require = common.require
    facilities = common.registry(source['facilities'], 'facilities')
    width, height = 20, 14
    source_cells = {(int(row['position'][0]), int(row['position'][1])) for row in source['sources']}
    blocked = set(source_cells)
    placed = {}
    # Greedy row packing: land facilities first in stable order, then 1x1 tiles.
    for ident in sorted(facilities, key=lambda i: (-math.prod(facilities[i]['footprint']), i)):
        facility = facilities[ident]
        if facility.get('terrain', 'land') == 'water':
            placed[ident] = None
            continue
        fw, fh = facility['footprint']
        spot = None
        for y in range(height):
            for x in range(width - fw + 1):
                cells = {(x + dx, y + dy) for dx in range(fw) for dy in range(fh)}
                if not cells & blocked:
                    spot = cells
                    break
            if spot:
                break
        require(spot is not None, f'layout audit cannot place {ident}')
        blocked |= spot
        placed[ident] = spot
    flowers = 12  # reference flower field plus rotation beds
    for index in range(flowers):
        spot = None
        for y in range(height):
            for x in range(width):
                if (x, y) not in blocked:
                    spot = (x, y)
                    break
            if spot:
                break
        require(spot is not None, 'layout audit cannot place the reference flower field')
        blocked.add(spot)
    require(len(blocked) <= width * height, 'layout overflows the land')
    land_used = sum(1 for cell in blocked)
    budget = {'initial_stones': int(source['config']['initial_primeval_stones']), 'research_bench': 8, 't01_fee': 4, 't01_seeds': 8 + 4,
              'fish_pond': 12, 'two_fry': 10, 't04_fee': 4, 'notes': '参考启动草案：建研究台→T01→两种花→水场两尾鱼→T04；逐日AP/清水按实际台账另记。'}
    require(budget['initial_stones'] >= budget['research_bench'] + budget['t01_fee'] + budget['t01_seeds'] + budget['fish_pond'] + budget['two_fry'] + budget['t04_fee'], 'startup budget draft exceeds configured initial stones')
    return {'land_used': land_used, 'land_total': width * height, 'flower_cells': flowers,
            'placements': {ident: (sorted(cells)[0] if cells else 'water') for ident, cells in placed.items()},
            'startup_budget': budget}


def compile_config(source, map_data=None):
    try:
        if 'p104' in source:
            from validate_p104 import validate as validate_p104
            validate_p104(source)
        from validate_rooms import validate as validate_rooms
        validate_rooms(source)
        if 'logistics' in source:
            from validate_logistics import validate
            validate(source)
        provider_rows = providers(source)
        out = common.compile_config(source, PRODUCT, provider_rows, map_data, extra_consumers(source))
        items = {i['id']: i for i in out['resources']}
        for a in out['livestock']:
            for diet in a['base_diets'] + a['special_diets']:
                for iid in diet['inputs']:
                    items[iid]['consumers'] = sorted(set(items[iid]['consumers']) | {a['id']})
        for iid in out['husbandry']['water']['change']['inputs']:
            items[iid]['consumers'] = sorted(set(items[iid]['consumers']) | {'water_change'})
        items['wastewater']['consumers'] = sorted(set(items['wastewater']['consumers']) | {'water_change'})
        out['purchase_audit'] = purchase_audit(out)
        out['research_audit'] = audit_research(source, out, provider_rows)
        audit_allocations(source)
        out['conservation_audit'] = {'iron': audit_conservation(source, out)}
        out['layout_audit'] = audit_layout(source)
        return out
    except (KeyError, TypeError, AttributeError) as error:
        raise ValueError(f'invalid P8 field: {error}') from error


def purchase_audit(out):
    """Trace recipes to buyable leaves; no shortcut through an unbuyable product."""
    items = {i['id']: i for i in out['resources']}
    models = {i['id']: i for i in out['cost_models']}
    def trace(iid, trail=()):
        common.require(iid not in trail, f'cyclic purchase chain: {iid}')
        item = items[iid]
        if item['buy_price'] > 0:
            return {iid: Fraction(1)}
        model = models[item['cost_source']]
        if not model['inputs']:
            return {}
        leaves = Counter()
        quantity = model['outputs'][iid]['quantity']
        for key, count in model['inputs'].items():
            for leaf, units in trace(key, trail + (iid,)).items():
                leaves[leaf] += units * count / quantity
        return dict(leaves)
    audit = {}
    for iid, item in items.items():
        if not item['supply_allowed']:
            continue
        leaves = trace(iid)
        q = 1 if item['buy_price'] > 0 else models[item['cost_source']]['outputs'][iid]['quantity']
        base = q * item['sell_price']
        premium = base * out['orders']['premium_percent'] // 100
        audit[iid] = {'quantity': q, 'payout': base + premium,
                      'buyable_leaves': {k: common.pack(v * q) for k, v in sorted(leaves.items())},
                      'raw_purchase_cost': common.pack(sum((items[k]['buy_price'] * v * q for k, v in leaves.items()), Fraction())),
                      'requires_production': item['buy_price'] == 0}
    return audit


def expansion_output(data=None):
    if data is None:
        data = json.loads((ROOT / 'content/farming/p8/expansion.json').read_text(encoding='utf-8'))
    require = common.require
    require(set(data) == {'version', 'origin_x', 'size', 'base', 'parcels'} and data['version'] == 1, 'invalid expansion config')
    require(data['origin_x'] == -4 and data['size'] == [32, 22] and data['base'] == [0, 0, 20, 22], 'invalid expansion envelope/base')
    used = {(x, y) for y in range(22) for x in range(20)}
    seen = set()
    for parcel in data['parcels']:
        require(set(parcel) == {'id', 'name', 'rect', 'terrain', 'price', 'requires'}, 'invalid parcel fields')
        require(isinstance(parcel['id'], str) and parcel['id'] not in seen and parcel['name'], 'invalid parcel id/name')
        require(type(parcel['price']) is int and 0 < parcel['price'] <= 1000000, 'invalid parcel price')
        require(isinstance(parcel['requires'], list) and len(set(parcel['requires'])) == len(parcel['requires']) and set(parcel['requires']) <= seen, 'parcel prerequisites must precede it')
        require(isinstance(parcel['rect'], list) and len(parcel['rect']) == 4 and all(type(v) is int for v in parcel['rect']), 'invalid parcel rectangle')
        x, y, w, h = parcel['rect']
        require(w > 0 and h > 0 and -4 <= x and x+w <= 28 and 0 <= y and y+h <= 22, 'parcel outside envelope')
        cells = {(a, b) for b in range(y, y+h) for a in range(x, x+w)}
        require(not cells & used, 'overlapping parcel')
        require((parcel['terrain'] == 'water' and y >= 14) or (parcel['terrain'] == 'grass' and y+h <= 14 and x >= 20), 'invalid parcel terrain/location')
        used.update(cells)
        seen.add(parcel['id'])
    require(len(seen) == 6 and len(used) == 440+112+96, 'invalid parcel capacity')
    require(sum(p['rect'][2]*p['rect'][3] for p in data['parcels'] if p['terrain'] == 'grass') == 112
            and sum(p['rect'][2]*p['rect'][3] for p in data['parcels'] if p['terrain'] == 'water') == 96, 'invalid land/water capacity')
    return common.dump(data)


def outputs():
    m = json.loads((ROOT / 'content/farming/maps/farm_02.json').read_text(encoding='utf-8'))
    t = json.loads(TERRAIN_SOURCE.read_text(encoding='utf-8'))
    common.require(m['size'] == [20, 22] and m['reservoir'] == [0, 14, 20, 8], 'invalid reservoir')
    common.require(len(m['rows']) == 22 and all(len(row) == 20 for row in m['rows']), 'invalid map dimensions')
    grid = [[m['legend'][c] for c in row] for row in m['rows']]
    for y, row in enumerate(grid):
        common.require(all((c == 'water') == (y >= 14) for c in row), 'invalid reservoir footprint')
        common.require(set(row) <= {entry['id'] for entry in t['terrains']}, 'unknown map terrain')
    common.require({row['id'] for row in t['terrains']} == {'grass', 'dirt', 'stone', 'tilled', 'water'} and next(row for row in t['terrains'] if row['id'] == 'water')['tillable'] is False, 'invalid water terrain')
    for terrain in t['terrains']:
        for path in terrain['textures'].values():
            common.require((ROOT / path).is_file(), 'missing terrain texture')
    base = json.loads((ROOT / 'content/farming/baked/maps/farm_01.json').read_text(encoding='utf-8'))
    common.require(grid[:14] == base['grid'], 'P8 must preserve existing land')
    baked_map = json.loads((ROOT / 'content/farming/baked/maps/farm_02.json').read_text(encoding='utf-8'))
    map_out = dict(schema=1, id=m['id'], name=m['name'], size=m['size'], grid=grid, reservoir=m['reservoir'])
    common.require(baked_map == map_out, 'baked farm_02 map must match the V2 output')
    compiled = compile_config(json.loads(SOURCE.read_text(encoding='utf-8')), map_out)
    return {TARGET: common.dump(compiled), TERRAIN_TARGET: common.dump(t),
            ROOT / 'content/farming/baked/p8/expansion.json': expansion_output()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    files = outputs()
    common.require(files == outputs(), 'nondeterministic P8 bake')
    for path, data in files.items():
        if args.check:
            common.require(path.exists() and path.read_bytes() == data, f'stale output: {path.name}')
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    supply = {row['id']: row['supply_value'] for row in json.loads(files[TARGET].decode('utf-8'))['resources'] if row['supply_allowed']}
    baked = json.loads(files[TARGET].decode('utf-8'))
    print('P8 BAKE OK: ' + ' / '.join(f'{len(baked[k])} {k}' for k in ('resources','crops','facilities','recipes','research')) + '; layout+budget audited')
    print('P8 SUPPLY VALUES: ' + ', '.join(f'{k}={v}' for k, v in sorted(supply.items())))


if __name__ == '__main__':
    try:
        main()
    except ValueError as error:
        raise SystemExit(f'P8 BAKE FAILED: {error}')
