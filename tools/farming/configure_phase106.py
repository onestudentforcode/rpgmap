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

path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('P10.6 stage-b source installed: %d facilities, %d zone types, p106 v%d'
      % (len(data['facilities']), len(data['p103']['zones']), data['p106']['version']))
