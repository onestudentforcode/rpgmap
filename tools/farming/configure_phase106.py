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

path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('P10.6 source installed: %d facilities, %d livestock, %d zone types, %d cost models'
      % (len(data['facilities']), len(data['livestock']), len(data['p103']['zones']), len(data['cost_models'])))
