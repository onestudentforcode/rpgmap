# -*- coding: utf-8 -*-
"""Install the frozen P10.6 source definitions; safe to run repeatedly.

Freeze source: docs/farming/phase-10.6 §16.2 (commit adda766).

Stage b slice: the p106 water section (fence cost, quality totals, water
change), dual-medium shared structures, the aquatic facility set (six species
stations, the crop station, the shore change station), the five water zone
types and the fish_pond retirement flag. Species, recipes, research and
materials land with stages c/d in this same script.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / 'content/farming/p8/production.json'
data = json.loads(path.read_text(encoding='utf-8'))

# --- shared structures become dual-medium (§16.2.5) ---------------------------
# The pen, trough, beds and care table keep their land algorithms; on water
# they render as float constructions. `terrain` stays as the display default,
# the build path honours the `terrains` list first.
DUAL_MEDIUM = ['pen', 'feed_trough', 'small_bed', 'medium_bed', 'care_table']
for facility in data['facilities']:
    if facility['id'] in DUAL_MEDIUM:
        facility['terrains'] = ['land', 'water']
    if facility['id'] == 'fish_pond':
        facility['retired'] = True


def install(section, row):
    data[section] = [r for r in data[section] if r['id'] != row['id']] + [row]


def install_all(section, rows):
    for row in rows:
        install(section, row)


# --- aquatic facilities (§16.2.6) ---------------------------------------------
# Research gates follow §8.4: oilfin reuses farm_preparation, mussel/jellyfish
# reuse water_recirculation, the loach station reuses biofiltration and the
# coral station reuses mineral_materials; the carp station is open. Species
# lists land with stage c, together with the livestock definitions.
install_all('facilities', [
    dict(id='carp_harvest_station', name='捕鲤台', cash=12, materials={'wood_plank': 2, 'raw_stone': 2},
        terrain='water', footprint=[1, 1], kind=None),
    dict(id='oilfish_harvest_station', name='取油台', cash=16, materials={'wood_plank': 2, 'raw_stone': 3},
        terrain='water', footprint=[1, 1], kind=None, research='farm_preparation'),
    dict(id='pearl_station', name='采珠台', cash=16, materials={'wood_plank': 2, 'raw_stone': 3},
        terrain='water', footprint=[1, 1], kind=None, research='water_recirculation'),
    dict(id='gel_station', name='采胶台', cash=16, materials={'wood_plank': 2, 'raw_stone': 3},
        terrain='water', footprint=[1, 1], kind=None, research='water_recirculation'),
    dict(id='coral_station', name='采礁台', cash=20, materials={'wood_plank': 2, 'raw_stone': 4},
        terrain='water', footprint=[1, 1], kind=None, research='mineral_materials'),
    dict(id='silt_processing_station', name='泥料处理台', cash=14, materials={'wood_plank': 2, 'raw_stone': 2},
        terrain='water', footprint=[1, 1], kind=None, research='biofiltration'),
    dict(id='aquatic_crop_station', name='水生种植台', cash=8, materials={'wood_plank': 1, 'raw_stone': 2},
        terrain='water', footprint=[1, 1], kind=None),
    dict(id='water_change_station', name='换水站', cash=16, materials={'wood_plank': 2, 'raw_stone': 4},
        terrain='land', footprint=[1, 1], kind=None),
])

# --- p103 water zone types (§16.2.5) ------------------------------------------
data['p103']['zones'].update({
    'water_nursery': dict(min_space=4, medium='water', structures=['pen', 'feed_trough', 'bed']),
    'water_enclosure': dict(min_space=8, medium='water',
        structures=['pen', 'feed_trough', 'bed', 'care_table']),
    'water_production': dict(min_space=8, medium='water', structures=['pen', 'feed_trough', 'bed'],
        any_of=[dict(id='water_station', members=['carp_harvest_station', 'oilfish_harvest_station',
            'pearl_station', 'gel_station', 'coral_station'])]),
    'water_loach': dict(min_space=4, medium='water',
        structures=['pen', 'feed_trough', 'bed', 'silt_processing_station']),
    'aqua_planting': dict(min_space=1, medium='water', structures=['aquatic_crop_station']),
})

# --- research unlock registry (facility gates must be cross-registered) ------
UNLOCKS = {
    'farm_preparation': ['oilfish_harvest_station'],
    'water_recirculation': ['pearl_station', 'gel_station'],
    'mineral_materials': ['coral_station'],
    'biofiltration': ['silt_processing_station'],
}
for row in data['research']:
    extra = UNLOCKS.get(row['id'], [])
    row['unlocks']['facilities'] = sorted(set(row['unlocks']['facilities']) | set(extra))

# --- p106 water section (§16.2.4/§16.2.7) -------------------------------------
data['p106'] = dict(
    version=1,
    fence=dict(cash=1, inputs={'twig': 1}, ap=1),
    quality=dict(initial=100, cap=100, points_per_cell=10000, pause_threshold=30,
                 base_decay=2, load_factor=6),
    change=dict(inputs={'clean_water': 2}, wastewater=2, gain=40, max_cells=8, ap=1),
    facilities=dict(change_station='water_change_station', crop_station='aquatic_crop_station'),
    station_change_cells=8,
)

# --- stage c: materials, species, stations, meals, cost rows (§16.2.6) ------
# Materials land as sell-only items now: the species natural outputs need them
# for bake validation; their recipes and consumers arrive with stage d.
def resource(row):
    row.setdefault('form', 'solid')
    row.setdefault('stage', 'intermediate')
    row.setdefault('supply_allowed', False)
    row.setdefault('buy_price', 0)
    install('resources', row)


resource(dict(id='pearl', name='珍珠', element='gold', tags=['animal_product'], sell_price=6, cost_source='pearl_round'))
resource(dict(id='mussel_shell', name='贝壳', element='earth', tags=['animal_product'], sell_price=1, cost_source='mussel_shell'))
resource(dict(id='water_gel', name='凝水胶', element='water', tags=['animal_product'], sell_price=4, cost_source='gel_round'))
resource(dict(id='coral_stone', name='珊瑚石', element='earth', tags=['animal_product'], sell_price=2, cost_source='coral_round'))
for row in data['resources']:
    if row['id'] == 'crude_oil':
        row['name'] = '粗油'

STATION_OF = {
    'filter_algae_carp': 'carp_harvest_station',
    'oilfin_fish': 'oilfish_harvest_station',
    'pearl_mussel': 'pearl_station',
    'gel_jellyfish': 'gel_station',
    'reef_coral': 'coral_station',
}
for facility in data['facilities']:
    if facility['id'] in STATION_OF.values():
        facility['species'] = [sid for sid, station in STATION_OF.items() if station == facility['id']]
    if facility['id'] == 'silt_processing_station':
        facility['species'] = ['silt_loach']

# filter_algae_carp joins the ranch roster: its livestock def becomes the diet
# and price source behind the carp station instead of the retired fish_pond.
for row in data['livestock']:
    if row['id'] == 'filter_algae_carp':
        row['facility'] = 'carp_harvest_station'

ALGAE = [dict(id='algae_meal', name='藻料餐', inputs={'algae_feed': 1})]
install_all('livestock', [
    dict(id='oilfin_fish', name='油鳍鱼', facility='oilfish_harvest_station', unit='尾',
        juvenile_price=10, growth_days=5, cycle_days=3,
        base_diets=ALGAE + [dict(id='water_meal', name='水养复合餐', inputs={'water_feed': 1}, research='advanced_feed_oil_wax')],
        default_base_diet='algae_meal',
        special_diets=[dict(id='oilfin_oil_round', name='取油轮投料', inputs={'water_feed': 1}, outputs={'crude_oil': 2, 'fish_meat': 1})],
        default_special_diet='oilfin_oil_round', outputs={'crude_oil': 2, 'fish_meat': 1},
        claim_removes=True, research='farm_preparation'),
    dict(id='pearl_mussel', name='珍珠蚌', facility='pearl_station', unit='只',
        juvenile_price=12, growth_days=6, cycle_days=4,
        base_diets=[dict(id='algae_meal', name='藻料餐', inputs={'algae_feed': 1})],
        default_base_diet='algae_meal',
        special_diets=[dict(id='pearl_powder_round', name='育珠轮投料', inputs={'stone_powder': 1}, outputs={'pearl': 2})],
        default_special_diet='pearl_powder_round', outputs={'pearl': 2},
        claim_removes=False, research='water_recirculation'),
    dict(id='gel_jellyfish', name='凝胶水母', facility='gel_station', unit='群',
        juvenile_price=12, growth_days=4, cycle_days=2,
        base_diets=ALGAE + [dict(id='dense_meal', name='高密度藻餐', inputs={'dense_algae': 1}, research='water_recirculation')],
        default_base_diet='algae_meal',
        special_diets=[dict(id='gel_water_round', name='采胶轮投料', inputs={'clean_water': 1}, outputs={'water_gel': 2})],
        default_special_diet='gel_water_round', outputs={'water_gel': 2},
        claim_removes=False, research='water_recirculation'),
    dict(id='silt_loach', name='净泥鳅', facility='silt_processing_station', unit='尾',
        juvenile_price=8, growth_days=3, cycle_days=1,
        base_diets=[dict(id='algae_meal', name='藻料餐', inputs={'algae_feed': 1})],
        default_base_diet='algae_meal',
        special_diets=[], default_special_diet='',
        outputs={'humus': 3},
        claim_removes=False, research='biofiltration'),
    dict(id='reef_coral', name='礁骨珊瑚', facility='coral_station', unit='群',
        juvenile_price=14, growth_days=6, cycle_days=6,
        base_diets=[dict(id='algae_meal', name='藻料餐', inputs={'algae_feed': 1})],
        default_base_diet='algae_meal',
        special_diets=[dict(id='coral_mineral_round', name='采礁轮投料', inputs={'stone_powder': 3, 'clean_water': 1}, outputs={'coral_stone': 2})],
        default_special_diet='coral_mineral_round', outputs={'coral_stone': 2},
        claim_removes=False, research='mineral_materials'),
])

# p103 roster entries: ×100 stored progress; coral is a fixed-anchor species
# with no bed (the anchor cell is its rest place).
NATURAL = {
    'filter_algae_carp': dict(station='carp_harvest_station', units=1200, capture=True,
        outputs={'fish_meat': 3, 'fish_manure': 1}, default_diet='grain_fatten'),
    'oilfin_fish': dict(station='oilfish_harvest_station', units=1800, capture=True,
        outputs={'crude_oil': 2, 'fish_meat': 1}, default_diet='oilfin_oil_round'),
    'pearl_mussel': dict(station='pearl_station', units=2400, capture=False, shell=True,
        outputs={'pearl': 2}, default_diet='pearl_powder_round'),
    'gel_jellyfish': dict(station='gel_station', units=1200, capture=False,
        outputs={'water_gel': 2}, default_diet='gel_water_round'),
    'reef_coral': dict(station='coral_station', units=3600, capture=False,
        outputs={'coral_stone': 2}, default_diet='coral_mineral_round'),
}
data['p103']['species'].update({
    'filter_algae_carp': dict(medium='water', space=1, bed='small', growth_units=2400, breed_units=7200,
        natural=NATURAL['filter_algae_carp']),
    'oilfin_fish': dict(medium='water', space=2, bed='medium', growth_units=3000, breed_units=8400,
        natural=NATURAL['oilfin_fish']),
    'pearl_mussel': dict(medium='water', space=1, bed='small', growth_units=3600, breed_units=9600,
        natural=NATURAL['pearl_mussel']),
    'gel_jellyfish': dict(medium='water', space=1, bed='small', growth_units=2400, breed_units=7200,
        natural=NATURAL['gel_jellyfish']),
    'silt_loach': dict(medium='water', space=1, bed='small', growth_units=1800, breed_units=6000),
    'reef_coral': dict(medium='water', space=1, bed='', fixed=True, growth_units=3600, breed_units=10800,
        natural=NATURAL['reef_coral']),
})
for species, station in STATION_OF.items():
    data['p103']['stations'][station] = {'species': species, 'capacity': 4}
data['p103']['meals'].update({'water_nursery': 1, 'water_enclosure': 2, 'water_production': 2, 'water_loach': 2})
data['p103']['work']['facilities']['silt_processing_station'] = []

# Stage d restores the loach duckweed diet variant together with the crop.
# Research unlock registry: species gates cross-registered.
SPECIES_UNLOCKS = {
    'farm_preparation': ['oilfin_fish'],
    'water_recirculation': ['pearl_mussel', 'gel_jellyfish'],
    'mineral_materials': ['reef_coral'],
    'biofiltration': ['silt_loach'],
}
for row in data['research']:
    extra = SPECIES_UNLOCKS.get(row['id'], [])
    row['unlocks']['species'] = sorted(set(row['unlocks']['species']) | set(extra))

# Cost rows (§16.2.6 economics): nursery days carry one base meal per animal,
# production days two, and the round feed is paid once — ×4 population.
install('cost_models', dict(id='fish', basis={'kind': 'animal', 'id': 'filter_algae_carp_provider'},
    inputs={'algae_feed': 32, 'grain': 4}, ap=8, days=6, cash=20,
    outputs={'fish_meat': {'quantity': 12, 'share': 0.85}, 'fish_manure': {'quantity': 4, 'share': 0.15}}))
install('cost_models', dict(id='mussel_shell', basis={'kind': 'animal', 'id': 'mussel_shell_provider'},
    inputs={'algae_feed': 24}, ap=8, days=6, cash=48,
    outputs={'mussel_shell': {'quantity': 8, 'share': 1}}))
install('cost_models', dict(id='oilfin_round', basis={'kind': 'animal', 'id': 'oilfin_fish_provider'},
    inputs={'algae_feed': 44, 'water_feed': 4}, ap=10, days=8, cash=40,
    outputs={'crude_oil': {'quantity': 8, 'share': 0.75}, 'fish_meat': {'quantity': 4, 'share': 0.25}}))
install('cost_models', dict(id='pearl_round', basis={'kind': 'animal', 'id': 'pearl_mussel_provider'},
    inputs={'algae_feed': 56, 'stone_powder': 4}, ap=12, days=10, cash=48,
    outputs={'pearl': {'quantity': 8, 'share': 1}}))
install('cost_models', dict(id='gel_round', basis={'kind': 'animal', 'id': 'gel_jellyfish_provider'},
    inputs={'algae_feed': 32, 'clean_water': 4}, ap=8, days=6, cash=48,
    outputs={'water_gel': {'quantity': 8, 'share': 1}}))
install('cost_models', dict(id='coral_round', basis={'kind': 'animal', 'id': 'reef_coral_provider'},
    inputs={'algae_feed': 72, 'stone_powder': 12, 'clean_water': 4}, ap=14, days=12, cash=56,
    outputs={'coral_stone': {'quantity': 8, 'share': 1}}))

# --- stage d: water crops, recipes, research and trade (§16.2.8/§16.2.9) ----
def resource(row):
    row.setdefault('form', 'solid')
    row.setdefault('stage', 'intermediate')
    row.setdefault('supply_allowed', False)
    row.setdefault('buy_price', 0)
    install('resources', row)


resource(dict(id='duckweed', name='浮萍', element='water', tags=['plant_product'], sell_price=1, cost_source='duckweed'))
resource(dict(id='duckweed_seed', name='浮萍种苗', element='water', tags=['seed'], buy_price=2, sell_price=0, cost_source='purchase'))
resource(dict(id='reed_stalk', name='苇秆', element='wood', tags=['plant_product'], sell_price=1, cost_source='reed'))
resource(dict(id='reed_seed', name='芦苇种苗', element='wood', tags=['seed'], buy_price=3, sell_price=0, cost_source='purchase'))
resource(dict(id='fish_meal', name='鱼粉', element='wood', tags=['processing'], sell_price=2, cost_source='dry_fish_meal'))
resource(dict(id='water_retaining_matrix', name='保水基质', element='earth', tags=['processing'], sell_price=2, cost_source='make_water_retaining_matrix'))

# Water crops reuse the mulberry tap-or-fell lifecycle with a water medium:
# growth gates on light and shared body quality, every round pays its
# nutrition inputs, and the round variant unlocked by the aquatic research
# swaps humus for the matrix.
install_all('crops', [
    dict(id='duckweed', name='浮萍', seed='duckweed_seed', footprint=[1, 1], days=3, cycle_days=1,
        mode='tap_or_fell', medium='water', inputs={}, fell_outputs={}, target_tags=[],
        outputs={'duckweed': 4}, water_use=0, fertility_use=0, light=60, max_taps=6,
        round_inputs=[dict(id='humus_round', inputs={'humus': 1}),
                      dict(id='matrix_round', inputs={'water_retaining_matrix': 1}, research='aquatic_intensive_care')]),
    dict(id='reed', name='芦苇', seed='reed_seed', footprint=[1, 1], days=5, cycle_days=2,
        mode='tap_or_fell', medium='water', inputs={}, fell_outputs={}, target_tags=[],
        outputs={'reed_stalk': 6}, water_use=0, fertility_use=0, light=60, max_taps=4,
        round_inputs=[dict(id='humus_round', inputs={'humus': 1}),
                      dict(id='matrix_round', inputs={'water_retaining_matrix': 1}, research='aquatic_intensive_care')]),
])

# The mushroom substrate variant: same 4-day culture round, reed replaces the
# wood chips; spawn and growth conditions unchanged.
for crop in data['crops']:
    if crop['id'] == 'wood_decay_mushroom':
        crop['input_variants'] = [dict(id='reed_substrate', inputs={'reed_stalk': 3, 'clean_water': 2},
            research='aquatic_intensive_care')]

install_all('recipes', [
    dict(id='mill_duckweed', name='浮萍制粉', facility='farm_processor', days=1, start_ap=1, claim_ap=1,
        inputs={'duckweed': 2}, outputs={'grass_meal': 2}, research='farm_preparation'),
    dict(id='dry_fish_meal', name='鱼肉制粉', facility='farm_processor', days=1, start_ap=1, claim_ap=1,
        inputs={'fish_meat': 2}, outputs={'fish_meal': 3}, research='advanced_feed_oil_wax'),
    dict(id='blend_fish_land_feed', name='鱼粉陆养料', facility='farm_processor', days=1, start_ap=1, claim_ap=1,
        inputs={'fish_meal': 1, 'grass_meal': 2, 'oil_cake': 1}, outputs={'land_feed': 3}, research='advanced_feed_oil_wax'),
    dict(id='blend_fish_water_feed', name='鱼粉水养料', facility='farm_processor', days=1, start_ap=1, claim_ap=1,
        inputs={'algae_feed': 3, 'grain_meal': 1, 'fish_meal': 1}, outputs={'water_feed': 4}, research='advanced_feed_oil_wax'),
    dict(id='grind_shell', name='壳石制粉', facility='farm_processor', days=1, start_ap=1, claim_ap=1,
        inputs={'mussel_shell': 2}, outputs={'stone_powder': 2}, research='mineral_materials'),
    dict(id='grind_coral', name='珊瑚制粉', facility='farm_processor', days=1, start_ap=1, claim_ap=1,
        inputs={'coral_stone': 2}, outputs={'stone_powder': 2}, research='mineral_materials'),
    dict(id='make_water_retaining_matrix', name='保水基质', facility='farm_processor', days=1, start_ap=1, claim_ap=1,
        inputs={'water_gel': 1, 'humus': 1, 'reed_stalk': 1}, outputs={'water_retaining_matrix': 4}, research='aquatic_intensive_care'),
    dict(id='make_coral_filter_media', name='多孔滤材', facility='woodshop', days=1, start_ap=1, claim_ap=1,
        inputs={'coral_stone': 1, 'charcoal': 1}, outputs={'filter_media': 3}, research='water_recirculation'),
    dict(id='assemble_coral_panel', name='珊瑚复合石板', facility='woodshop', days=1, start_ap=1, claim_ap=1,
        inputs={'coral_stone': 2, 'stone_powder': 1, 'mucus': 1}, outputs={'composite_stone_panel': 3}, research='mineral_materials'),
    dict(id='compost_reed', name='苇秆堆肥', facility='compost_bin', days=1, start_ap=1, claim_ap=1,
        inputs={'reed_stalk': 2}, outputs={'humus': 2}),
    dict(id='char_reed', name='苇秆炭化', facility='char_kiln', days=1, start_ap=1, claim_ap=1,
        inputs={'reed_stalk': 3}, outputs={'charcoal': 2}),
    dict(id='pearl_polish_water', name='珍珠精滤', facility='purifying_bed', days=1, start_ap=1, claim_ap=1,
        inputs={'wastewater': 6, 'filter_media': 1, 'pearl': 1}, outputs={'clean_water': 4, 'sludge': 2}, research='aquatic_intensive_care'),
    dict(id='silt_process', name='泥料处理', facility='silt_processing_station', days=1, start_ap=1, claim_ap=1,
        inputs={'sludge': 2, 'duckweed': 1}, outputs={'humus': 3}),
])

# The loach batch joins the work registry; its feed variant returns now that
# duckweed exists.
data['p103']['work']['recipes']['silt_process'] = {'species': 'silt_loach', 'target': 1200}
data['p103']['work']['facilities']['silt_processing_station'] = ['silt_process']
for row in data['livestock']:
    if row['id'] == 'silt_loach':
        row['base_diets'].append(dict(id='duckweed_meal', name='浮萍替代餐', inputs={'duckweed': 1}))
        row['default_special_diet'] = ''

# Spirit-liquid round variants for pearl and gel (§16.2.9): the higher payout
# rides on the diet, locked at round payment.
for row in data['livestock']:
    if row['id'] == 'pearl_mussel':
        row['special_diets'].append(dict(id='pearl_spirit_round', name='灵液育珠轮', inputs={'stone_powder': 1, 'spirit_liquid': 1},
            research='aquatic_intensive_care'))
    if row['id'] == 'gel_jellyfish':
        row['special_diets'].append(dict(id='gel_spirit_round', name='灵液凝胶轮', inputs={'clean_water': 1, 'spirit_liquid': 1},
            research='aquatic_intensive_care'))
data['p103']['species']['pearl_mussel']['natural']['variants'] = {'pearl_spirit_round': {'outputs': {'pearl': 3}}}
data['p103']['species']['gel_jellyfish']['natural']['variants'] = {'gel_spirit_round': {'outputs': {'water_gel': 3}}}

# The advanced aquatic research node: layer 2, 4 days, on water recycling.
install('research', dict(id='aquatic_intensive_care', name='水产精养', layer=2, fee=10, days=4,
    prerequisites=['water_recirculation'], samples={'pearl': 2, 'water_gel': 2},
    unlocks={'purchases': [], 'crops': [], 'facilities': [], 'species': [],
             'recipes': ['make_water_retaining_matrix', 'pearl_polish_water'],
             'diets': ['matrix_round', 'reed_substrate', 'pearl_spirit_round', 'gel_spirit_round']}))
# Existing rows cross-register the shared gates.
for row in data['research']:
    if row['id'] == 'advanced_feed_oil_wax':
        row['unlocks']['recipes'] = sorted(set(row['unlocks']['recipes']) | {'dry_fish_meal', 'blend_fish_land_feed', 'blend_fish_water_feed'})
    if row['id'] == 'farm_preparation':
        row['unlocks']['recipes'] = sorted(set(row['unlocks']['recipes']) | {'mill_duckweed'})
    if row['id'] == 'mineral_materials':
        row['unlocks']['recipes'] = sorted(set(row['unlocks']['recipes']) | {'grind_shell', 'grind_coral', 'assemble_coral_panel'})
    if row['id'] == 'water_recirculation':
        row['unlocks']['recipes'] = sorted(set(row['unlocks']['recipes']) | {'make_coral_filter_media'})

# Cost rows for the new economy leaves.
install('cost_models', dict(id='duckweed', basis={'kind': 'crop', 'id': 'duckweed'},
    inputs={'duckweed_seed': 1, 'humus': 1}, ap=2, days=3, cash=0,
    operations={'till': 0, 'plant': 1, 'harvest': 1, 'irrigate': 0},
    outputs={'duckweed': {'quantity': 4, 'share': 1}}))
install('cost_models', dict(id='reed', basis={'kind': 'crop', 'id': 'reed'},
    inputs={'reed_seed': 1, 'humus': 1}, ap=2, days=5, cash=0,
    operations={'till': 0, 'plant': 1, 'harvest': 1, 'irrigate': 0},
    outputs={'reed_stalk': {'quantity': 6, 'share': 1}}))
install('cost_models', dict(id='dry_fish_meal', basis={'kind': 'recipe', 'id': 'dry_fish_meal'},
    inputs={'fish_meat': 2}, ap=2, days=1, cash=0,
    outputs={'fish_meal': {'quantity': 3, 'share': 1}}))
install('cost_models', dict(id='make_water_retaining_matrix', basis={'kind': 'recipe', 'id': 'make_water_retaining_matrix'},
    inputs={'water_gel': 1, 'humus': 1, 'reed_stalk': 1}, ap=2, days=1, cash=0,
    outputs={'water_retaining_matrix': {'quantity': 4, 'share': 1}}))
install('cost_models', dict(id='pearl_polish_water', basis={'kind': 'recipe', 'id': 'pearl_polish_water'},
    inputs={'wastewater': 6, 'filter_media': 1, 'pearl': 1}, ap=2, days=1, cash=0,
    outputs={'clean_water': {'quantity': 4, 'share': 0.67}, 'sludge': {'quantity': 2, 'share': 0.33}}))

# --- stage e: shared gu, main products, dual-medium soothing (§16.2.10) -----
# Capability tags replace the old land hard-code: soothing and command serve
# any breed-capable / work-capable animal regardless of medium.
for definition in data['logistics']['definitions']:
    if definition['id'] == 'soothe_gu':
        definition['target_tags'] = ['breed_capable_animal']
    if definition['id'] == 'command_gu':
        definition['target_tags'] = ['work_capable_animal']

# The two shared gu: one rank, one stone a day, no food, market only (never
# provisioned). Effects match the service resolution keys.
data['logistics']['definitions'] = [d for d in data['logistics']['definitions'] if d['id'] not in ('product_yield_gu', 'feed_saving_gu')]
data['logistics']['definitions'] += [
    dict(id='product_yield_gu', name='丰养蛊', path='生道', role='logistics', rank=1,
        deployment='host', tags=['animal_product_assist', 'product_yield'],
        target_tags=['production_animal'], fee=1, food={}, host_kinds=['facility', None],
        slot='animal_product_assist', scope='HOST', effect='product_yield', range=0,
        value=125, market_price=32),
    dict(id='feed_saving_gu', name='节粮蛊', path='食道', role='logistics', rank=1,
        deployment='host', tags=['animal_feeding_assist', 'feed_saving'],
        target_tags=['fed_animal'], fee=1, food={}, host_kinds=['facility', None],
        slot='animal_feeding_assist', scope='HOST', effect='feed_saving', range=0,
        value=25, market_price=32),
]

# Host slots: the intensive stations (land and water, never the loach yard)
# carry one product-assist slot; every trough carries one feeding slot; the
# soothing station becomes dual-medium so water enclosures can host it too.
PRODUCT_HOSTS = ['wool_station', 'silkworm_rack', 'spirit_liquid_collector', 'scale_station',
                 'carp_harvest_station', 'oilfish_harvest_station', 'pearl_station', 'gel_station', 'coral_station']
for facility in data['facilities']:
    if facility['id'] in PRODUCT_HOSTS:
        facility['gu_slot'] = 'animal_product_assist'
    if facility['id'] == 'feed_trough':
        facility['gu_slot'] = 'animal_feeding_assist'
    if facility['id'] == 'soothing_station':
        facility['terrains'] = ['land', 'water']

# Main-product designation for the yield boost (byproducts never boost).
MAIN_OF = {
    'steel_sheep': 'steel_wool', 'leaf_silkworm': 'silk', 'dew_shell_snail': 'spirit_liquid',
    'mineral_scale_lizard': 'mineral_scale',
    'filter_algae_carp': 'fish_meat', 'oilfin_fish': 'crude_oil', 'pearl_mussel': 'pearl',
    'gel_jellyfish': 'water_gel', 'reef_coral': 'coral_stone',
}
for species_id, main_item in MAIN_OF.items():
    if 'natural' in data['p103']['species'][species_id]:
        data['p103']['species'][species_id]['natural']['main'] = main_item

path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('P10.6 source installed: %d resources, %d crops, %d recipes, %d research, %d livestock, %d cost models, %d gu'
      % (len(data['resources']), len(data['crops']), len(data['recipes']), len(data['research']), len(data['livestock']), len(data['cost_models']), len(data['logistics']['definitions'])))
