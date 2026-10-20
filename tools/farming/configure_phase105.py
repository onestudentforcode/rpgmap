# -*- coding: utf-8 -*-
"""Install the frozen P10.5 source definitions; safe to run repeatedly.

Freeze source: docs/farming/phase-10.5 P10.5.a record (commit 12274c7).
- six land species, four intensive stations, three new work yards
- rock_workyard split into rock_breaking_yard / ore_sorting_yard
- eight work recipes, four woodshop recipes, mulberry tree and materials
- p103 config v2: species uses/natural rounds, station and yard registries
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / 'content/farming/p8/production.json'
data = json.loads(path.read_text(encoding='utf-8'))

def install(section, row):
    data[section] = [r for r in data[section] if r['id'] != row['id']] + [row]

def install_all(section, rows):
    for row in rows:
        install(section, row)

# --- facilities ---------------------------------------------------------------
# Split yards inherit the old rock workyard cost/footprint; recipes keep their
# research gates. New stations and yards are P10.5 additions from the freeze.
data['facilities'] = [f for f in data['facilities'] if f['id'] != 'rock_workyard']
install_all('facilities', [
    dict(id='rock_breaking_yard', name='碎岩场', cash=12, materials={'raw_wood': 2, 'raw_stone': 3},
        terrain='land', footprint=[2, 2], kind='habitat', capacity=4, species=['rock_mole'],
        research='rock_handling'),
    dict(id='ore_sorting_yard', name='选矿场', cash=12, materials={'raw_wood': 2, 'raw_stone': 3},
        terrain='land', footprint=[2, 2], kind='habitat', capacity=4, species=['rock_belly_beast'],
        research='ore_concentration'),
    dict(id='carbonization_nest', name='炭化巢', cash=18, materials={'wood_plank': 2, 'raw_stone': 4},
        terrain='land', footprint=[2, 2], kind=None, capacity=4, species=['carbon_belly_bug'],
        research='farm_preparation'),
    dict(id='compost_mouse_den', name='翻肥窝', cash=12, materials={'raw_wood': 2, 'raw_stone': 2},
        terrain='land', footprint=[2, 2], kind=None, capacity=4, species=['compost_mouse']),
    dict(id='shell_forming_station', name='岩壳成型台', cash=18, materials={'wood_plank': 2, 'raw_stone': 4},
        terrain='land', footprint=[2, 2], kind=None, capacity=4, species=['gravel_shell_snail'],
        research='mineral_materials'),
    dict(id='wool_station', name='采毛台', cash=12, materials={'wood_plank': 2, 'raw_stone': 2},
        terrain='land', footprint=[1, 1], kind=None, species=['steel_sheep']),
    dict(id='silkworm_rack', name='蚕架', cash=10, materials={'wood_plank': 2, 'twig': 2},
        terrain='land', footprint=[1, 1], kind=None, species=['leaf_silkworm']),
    dict(id='spirit_liquid_collector', name='集露台', cash=12, materials={'wood_plank': 1, 'raw_stone': 3},
        terrain='land', footprint=[1, 1], kind=None, species=['dew_shell_snail']),
    dict(id='scale_station', name='养鳞台', cash=18, materials={'wood_plank': 2, 'raw_stone': 4},
        terrain='land', footprint=[1, 1], kind=None, species=['mineral_scale_lizard'],
        research='mineral_materials'),
])

# --- livestock ----------------------------------------------------------------
GRASS_WATER = dict(id='grass_water_meal', name='牧草清水餐', inputs={'fodder_grass': 1, 'clean_water': 1})
install_all('livestock', [
    dict(id='carbon_belly_bug', name='炭腹虫', facility='carbonization_nest', unit='群',
        juvenile_price=10, growth_days=3, cycle_days=1,
        base_diets=[GRASS_WATER], default_base_diet='grass_water_meal',
        special_diets=[
            dict(id='bug_char_twigs', name='树枝炭化轮', inputs={'twig': 4}, outputs={'charcoal': 4, 'humus': 1}),
            dict(id='bug_char_chips', name='木屑炭化轮', inputs={'wood_chip': 4}, outputs={'charcoal': 2, 'humus': 1}),
        ],
        default_special_diet='bug_char_twigs', outputs={'charcoal': 4, 'humus': 1},
        claim_removes=False, research='farm_preparation'),
    dict(id='leaf_silkworm', name='叶丝蚕', facility='silkworm_rack', unit='群',
        juvenile_price=8, growth_days=3, cycle_days=2,
        base_diets=[dict(id='mulberry_meal', name='桑叶清水餐', inputs={'mulberry_leaf': 1, 'clean_water': 1})],
        default_base_diet='mulberry_meal',
        special_diets=[dict(id='silk_round', name='产丝轮', inputs={'mulberry_leaf': 2})],
        default_special_diet='silk_round', outputs={'silk': 4}, claim_removes=False),
    dict(id='dew_shell_snail', name='露壳蜗牛', facility='spirit_liquid_collector', unit='只',
        juvenile_price=10, growth_days=4, cycle_days=2,
        base_diets=[GRASS_WATER], default_base_diet='grass_water_meal',
        special_diets=[dict(id='dew_round', name='灵液采集轮', inputs={'clean_water': 2})],
        default_special_diet='dew_round', outputs={'spirit_liquid': 2, 'mucus': 1}, claim_removes=False),
    dict(id='mineral_scale_lizard', name='矿鳞蜥', facility='scale_station', unit='只',
        juvenile_price=18, growth_days=6, cycle_days=4,
        base_diets=[GRASS_WATER,
            dict(id='land_meal', name='陆养复合餐', inputs={'land_feed': 1, 'clean_water': 1},
                research='advanced_feed_oil_wax')],
        default_base_diet='grass_water_meal',
        special_diets=[dict(id='scale_round', name='养鳞轮', inputs={'mineral_feed': 2})],
        default_special_diet='scale_round', outputs={'mineral_scale': 2, 'shed_skin': 1},
        claim_removes=False, research='mineral_materials'),
    dict(id='compost_mouse', name='堆肥鼠', facility='compost_mouse_den', unit='只',
        juvenile_price=8, growth_days=3, cycle_days=1,
        base_diets=[GRASS_WATER], default_base_diet='grass_water_meal',
        special_diets=[
            dict(id='mouse_compost_fiber', name='秸秆堆肥轮', inputs={'straw': 2, 'wood_chip': 1}, outputs={'humus': 4}),
            dict(id='mouse_compost_residue', name='残料堆肥轮', inputs={'sludge': 2, 'oil_cake': 1}, outputs={'humus': 3}),
        ],
        default_special_diet='mouse_compost_fiber', outputs={'humus': 4}, claim_removes=False),
    dict(id='gravel_shell_snail', name='砾甲蜗牛', facility='shell_forming_station', unit='只',
        juvenile_price=14, growth_days=5, cycle_days=1,
        base_diets=[dict(id='algae_water_meal', name='藻料清水餐', inputs={'algae_feed': 1, 'clean_water': 1})],
        default_base_diet='algae_water_meal',
        special_diets=[dict(id='form_rock_shell', name='岩壳成型轮', inputs={'stone_powder': 3, 'clean_water': 1},
            outputs={'rock_shell': 2, 'mucus': 1})],
        default_special_diet='form_rock_shell', outputs={'rock_shell': 2, 'mucus': 1},
        claim_removes=False, research='mineral_materials'),
])
for row in data['livestock']:
    if row['id'] == 'rock_mole':
        row['facility'] = 'rock_breaking_yard'
    if row['id'] == 'rock_belly_beast':
        row['facility'] = 'ore_sorting_yard'

# --- resources ----------------------------------------------------------------
install_all('resources', [
    dict(id='mulberry_seed', name='果桑种苗', element='wood', form='solid', stage='primary',
        tags=['seed', 'cultivation'], supply_allowed=False, buy_price=6, sell_price=0, cost_source='purchase'),
    dict(id='mulberry_leaf', name='桑叶', element='wood', form='solid', stage='primary',
        tags=['animal_feed', 'organic'], supply_allowed=False, buy_price=2, sell_price=1, cost_source='mulberry'),
    dict(id='silk', name='蚕丝', element='wood', form='solid', stage='intermediate',
        tags=['food', 'animal_product'], supply_allowed=True, buy_price=0, sell_price=4, cost_source='silk_round'),
    dict(id='spirit_liquid', name='灵液', element='water', form='liquid', stage='intermediate',
        tags=['food', 'animal_product'], supply_allowed=True, buy_price=0, sell_price=6, cost_source='dew_round'),
    dict(id='mucus', name='黏液', element='water', form='solid', stage='intermediate',
        tags=['food', 'animal_product'], supply_allowed=True, buy_price=0, sell_price=2, cost_source='dew_round'),
    dict(id='mineral_scale', name='矿质鳞片', element='gold', form='solid', stage='intermediate',
        tags=['food', 'animal_product'], supply_allowed=True, buy_price=0, sell_price=5, cost_source='scale_round'),
    dict(id='shed_skin', name='蜕皮', element='wood', form='solid', stage='intermediate',
        tags=['food', 'animal_product'], supply_allowed=False, buy_price=0, sell_price=1, cost_source='scale_round'),
    dict(id='rock_shell', name='岩壳片', element='earth', form='solid', stage='intermediate',
        tags=['food', 'animal_product'], supply_allowed=True, buy_price=0, sell_price=3, cost_source='form_rock_shell'),
])

# --- crops --------------------------------------------------------------------
install('crops', dict(id='mulberry_tree', name='果桑树', seed='mulberry_seed', footprint=[2, 2],
    days=6, mode='tap_or_fell', cycle_days=2, inputs={}, outputs={'mulberry_leaf': 10},
    fell_outputs={'raw_wood': 2, 'twig': 2}, water_use=3, fertility_use=1, light=80,
    max_taps=6, target_tags=['plant_grow']))

# --- recipes ------------------------------------------------------------------
for row in data['recipes']:
    if row['id'] == 'break_stone' or row['id'] == 'break_ore':
        row['facility'] = 'rock_breaking_yard'
    if row['id'] == 'concentrate_ore':
        row['facility'] = 'ore_sorting_yard'
install_all('recipes', [
    dict(id='bug_char_twigs', name='树枝生物炭化', facility='carbonization_nest',
        inputs={'twig': 4}, outputs={'charcoal': 4, 'humus': 1},
        days=1, start_ap=1, claim_ap=1, living=True, research='farm_preparation'),
    dict(id='bug_char_chips', name='木屑生物炭化', facility='carbonization_nest',
        inputs={'wood_chip': 4}, outputs={'charcoal': 2, 'humus': 1},
        days=1, start_ap=1, claim_ap=1, living=True, research='farm_preparation'),
    dict(id='mouse_compost_fiber', name='秸秆翻肥', facility='compost_mouse_den',
        inputs={'straw': 2, 'wood_chip': 1}, outputs={'humus': 4},
        days=1, start_ap=1, claim_ap=1, living=True),
    dict(id='mouse_compost_residue', name='残料翻肥', facility='compost_mouse_den',
        inputs={'sludge': 2, 'oil_cake': 1}, outputs={'humus': 3},
        days=1, start_ap=1, claim_ap=1, living=True, research='biofiltration'),
    dict(id='form_rock_shell', name='岩壳成型', facility='shell_forming_station',
        inputs={'stone_powder': 3, 'clean_water': 1}, outputs={'rock_shell': 2, 'mucus': 1},
        days=1, start_ap=1, claim_ap=1, living=True, research='mineral_materials'),
    dict(id='make_silk_filter_media', name='丝质滤材', facility='woodshop',
        inputs={'silk': 1, 'wood_chip': 1, 'charcoal': 1}, outputs={'filter_media': 3},
        days=1, start_ap=1, claim_ap=1, research='water_recirculation'),
    dict(id='assemble_mucus_panel', name='黏液复合石板', facility='woodshop',
        inputs={'gravel': 2, 'stone_powder': 1, 'mucus': 1}, outputs={'composite_stone_panel': 2},
        days=1, start_ap=1, claim_ap=1, research='mineral_materials'),
    dict(id='assemble_scale_panel', name='鳞甲复合板', facility='woodshop',
        inputs={'mineral_scale': 2, 'shed_skin': 1, 'gravel': 1}, outputs={'composite_stone_panel': 3},
        days=1, start_ap=1, claim_ap=1, research='mineral_materials'),
    dict(id='assemble_shell_panel', name='岩壳石板', facility='woodshop',
        inputs={'rock_shell': 2, 'mucus': 1}, outputs={'composite_stone_panel': 3},
        days=1, start_ap=1, claim_ap=1, research='mineral_materials'),
])

# --- cost models (basis rows are derived by bake_p8 providers) ----------------
install_all('cost_models', [
    dict(id='silk_round', basis={'kind': 'animal', 'id': 'leaf_silkworm_provider'},
        inputs={'mulberry_leaf': 36, 'clean_water': 28}, ap=7, days=5, cash=32,
        outputs={'silk': {'quantity': 16, 'share': 1}}),
    dict(id='dew_round', basis={'kind': 'animal', 'id': 'dew_shell_snail_provider'},
        inputs={'fodder_grass': 32, 'clean_water': 40}, ap=8, days=6, cash=40,
        outputs={'spirit_liquid': {'quantity': 8, 'share': 0.75}, 'mucus': {'quantity': 4, 'share': 0.25}}),
    dict(id='scale_round', basis={'kind': 'animal', 'id': 'mineral_scale_lizard_provider'},
        inputs={'fodder_grass': 56, 'clean_water': 56, 'mineral_feed': 8}, ap=12, days=10, cash=72,
        outputs={'mineral_scale': {'quantity': 8, 'share': 0.75}, 'shed_skin': {'quantity': 4, 'share': 0.25}}),
    dict(id='mulberry', basis={'kind': 'crop', 'id': 'mulberry_tree'},
        inputs={'mulberry_seed': 1, 'clean_water': 4}, ap=10, days=6, cash=0,
        operations={'till': 4, 'plant': 1, 'harvest': 1, 'irrigate': 4},
        outputs={'mulberry_leaf': {'quantity': 10, 'share': 1}}),
    dict(id='form_rock_shell', basis={'kind': 'recipe', 'id': 'form_rock_shell'},
        inputs={'stone_powder': 3, 'clean_water': 1}, ap=2, days=1, cash=0,
        outputs={'rock_shell': {'quantity': 2, 'share': 3 / 4}, 'mucus': {'quantity': 1, 'share': 1 / 4}}),
])

# --- research unlock registry -------------------------------------------------
data['rooms']['primary']['mulberry_tree'] = {'harvest': 'mulberry_leaf', 'fell': 'raw_wood'}

def unlock(research_id, section, values):
    row = next(r for r in data['research'] if r['id'] == research_id)
    listed = row['unlocks'][section]
    for ident in values:
        if ident not in listed:
            listed.append(ident)
    row['unlocks'][section] = sorted(listed)

unlock('rock_handling', 'facilities', ['rock_breaking_yard'])
unlock('ore_concentration', 'facilities', ['ore_sorting_yard'])
unlock('farm_preparation', 'facilities', ['carbonization_nest'])
unlock('farm_preparation', 'species', ['carbon_belly_bug'])
unlock('farm_preparation', 'recipes', ['bug_char_twigs', 'bug_char_chips'])
unlock('biofiltration', 'recipes', ['mouse_compost_residue'])
unlock('water_recirculation', 'recipes', ['make_silk_filter_media'])
unlock('mineral_materials', 'facilities', ['scale_station', 'shell_forming_station'])
unlock('mineral_materials', 'species', ['mineral_scale_lizard', 'gravel_shell_snail'])
unlock('mineral_materials', 'recipes', ['form_rock_shell', 'assemble_mucus_panel', 'assemble_scale_panel', 'assemble_shell_panel'])
for row in data['research']:
    if row['id'] == 'rock_handling':
        row['unlocks']['facilities'] = [f for f in row['unlocks']['facilities'] if f != 'rock_workyard']

# --- p103 config v2 -----------------------------------------------------------
data['p103'] = {
    'version': 2,
    'species': {
        'steel_sheep': {
            'space': 2, 'bed': 'medium', 'growth_units': 3600, 'breed_units': 7200,
            'natural': {'station': 'wool_station', 'units': 1800,
                'outputs': {'steel_wool': 1, 'sheep_manure': 1}, 'default_diet': 'iron_supplement'},
        },
        'rock_mole': {'space': 1, 'bed': 'small', 'growth_units': 1800, 'breed_units': 4800},
        'rock_belly_beast': {'space': 1, 'bed': 'small', 'growth_units': 2400, 'breed_units': 9600},
        'carbon_belly_bug': {'space': 1, 'bed': 'small', 'growth_units': 1800, 'breed_units': 6000},
        'leaf_silkworm': {
            'space': 1, 'bed': 'small', 'growth_units': 1800, 'breedable': False,
            'natural': {'station': 'silkworm_rack', 'units': 1200,
                'outputs': {'silk': 4}, 'default_diet': 'silk_round'},
        },
        'dew_shell_snail': {
            'space': 1, 'bed': 'small', 'growth_units': 2400, 'breed_units': 7200,
            'natural': {'station': 'spirit_liquid_collector', 'units': 1200,
                'outputs': {'spirit_liquid': 2, 'mucus': 1}, 'default_diet': 'dew_round'},
        },
        'mineral_scale_lizard': {
            'space': 2, 'bed': 'medium', 'growth_units': 3600, 'breed_units': 9600,
            'natural': {'station': 'scale_station', 'units': 2400,
                'outputs': {'mineral_scale': 2, 'shed_skin': 1}, 'default_diet': 'scale_round'},
        },
        'compost_mouse': {'space': 1, 'bed': 'small', 'growth_units': 1800, 'breed_units': 4800},
        'gravel_shell_snail': {'space': 2, 'bed': 'medium', 'growth_units': 3000, 'breed_units': 8400},
    },
    'zones': {
        'nursery': {'min_space': 4, 'structures': ['pen', 'feed_trough', 'bed']},
        'enclosure': {'min_space': 8, 'structures': ['pen', 'feed_trough', 'bed', 'care_table']},
        'intensive': {'min_space': 8, 'structures': ['pen', 'feed_trough', 'bed'],
            'any_of': [{'id': 'intensive_station',
                'members': ['wool_station', 'silkworm_rack', 'spirit_liquid_collector', 'scale_station']}]},
        'work': {'min_space': 0, 'structures': ['dispatch_station'],
            'any_of': [{'id': 'work_yard',
                'members': ['rock_breaking_yard', 'ore_sorting_yard', 'carbonization_nest',
                    'compost_mouse_den', 'shell_forming_station']}]},
        'maintenance': {'min_space': 4, 'structures': ['feed_trough', 'bed']},
        'pasture': {'min_space': 8, 'structures': ['toy_station']},
    },
    'fatigue': data['p103']['fatigue'],
    'work': {
        'posts_per_yard': 4,
        'points_per_unit': 10000,
        'facilities': {
            'rock_breaking_yard': ['break_stone', 'break_ore'],
            'ore_sorting_yard': ['concentrate_ore'],
            'carbonization_nest': ['bug_char_twigs', 'bug_char_chips'],
            'compost_mouse_den': ['mouse_compost_fiber', 'mouse_compost_residue'],
            'shell_forming_station': ['form_rock_shell'],
        },
        'recipes': {
            'break_stone': {'species': 'rock_mole', 'target': 40000},
            'break_ore': {'species': 'rock_mole', 'target': 40000},
            'concentrate_ore': {'species': 'rock_belly_beast', 'target': 80000},
            'bug_char_twigs': {'species': 'carbon_belly_bug', 'target': 60000},
            'bug_char_chips': {'species': 'carbon_belly_bug', 'target': 40000},
            'mouse_compost_fiber': {'species': 'compost_mouse', 'target': 40000},
            'mouse_compost_residue': {'species': 'compost_mouse', 'target': 40000},
            'form_rock_shell': {'species': 'gravel_shell_snail', 'target': 80000},
        },
    },
    'stations': {
        'wool_station': {'species': 'steel_sheep', 'capacity': 4},
        'silkworm_rack': {'species': 'leaf_silkworm', 'capacity': 4},
        'spirit_liquid_collector': {'species': 'dew_shell_snail', 'capacity': 4},
        'scale_station': {'species': 'mineral_scale_lizard', 'capacity': 4},
    },
    'meals': {'nursery': 1, 'work': 1, 'enclosure': 2, 'intensive': 2},
    'trough_slots': 2,
    'bed_facilities': data['p103']['bed_facilities'],
    'patterns': data['p103']['patterns'],
    'fixed_pattern': data['p103']['fixed_pattern'],
    'ap': data['p103']['ap'],
}

path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('P105 SOURCE OK')
