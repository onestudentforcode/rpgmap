"""Install the frozen P10.4 source definitions; safe to run repeatedly."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / 'content/farming/p8/production.json'
data = json.loads(path.read_text(encoding='utf-8'))

def install(section, row):
    data[section] = [r for r in data[section] if r['id'] != row['id']] + [row]

install('facilities', dict(id='soothing_station', name='安抚台', footprint=[1, 1], cash=18,
    materials={'wood_plank': 2, 'raw_stone': 2}, terrain='land', kind='facility', gu_slot='animal_breeding_assist'))
install('facilities', dict(id='toy_station', name='玩具站', footprint=[1, 1], cash=12,
    materials={'wood_plank': 2, 'raw_stone': 2}, terrain='land', kind='facility', item_slot='animal_toy'))
for row in data['facilities']:
    if row['id'] == 'dispatch_station':
        row.update(kind='facility', gu_slot='animal_work_assist')
install('resources', dict(id='vine_ball', name='藤球', element='wood', form='solid', stage='intermediate',
    tags=['animal_toy'], supply_allowed=False, buy_price=0, sell_price=0, cost_source='make_vine_ball'))
install('recipes', dict(id='make_vine_ball', facility='woodshop', inputs={'twig': 2, 'straw': 2},
    outputs={'vine_ball': 1}, days=1, start_ap=1, claim_ap=1))
install('cost_models', dict(id='make_vine_ball', inputs={'twig': 2, 'straw': 2}, ap=2, days=1,
    outputs={'vine_ball': {'quantity': 1, 'share': 1}}, basis={'kind': 'recipe', 'id': 'make_vine_ball'}, cash=0))

new_gu = []
for ident, name, path_name, slot, effect in [
    ('soothe_gu', '安抚蛊', '音道', 'animal_breeding_assist', 'breed_speed'),
    ('command_gu', '驭兽蛊', '奴道', 'animal_work_assist', 'work_speed')]:
    new_gu.append(dict(id=ident, name=name, path=path_name, role='logistics', rank=1, deployment='host',
        tags=[slot, effect], target_tags=['terrestrial_animal'], fee=1, food={}, host_kinds=['facility'],
        slot=slot, scope='HOST', effect=effect, range=0, value=150))
data['logistics']['definitions'] = [r for r in data['logistics']['definitions'] if r['id'] not in {'soothe_gu', 'command_gu'}] + new_gu
data['logistics']['provision'] = [i for i in data['logistics']['provision'] if i not in {'soothe_gu', 'command_gu'}] + ['soothe_gu'] * 2 + ['command_gu'] * 2

previous_scale = data.get('p104', {}).get('precision', 1)
factor = 100 // previous_scale
for row in data['p103']['species'].values():
    for key in ['growth_units', 'breed_units', 'natural_units']:
        if key in row: row[key] *= factor
data['p103']['work']['points_per_unit'] *= factor
for row in data['p103']['work']['recipes'].values(): row['target'] *= factor
data['p103']['zones']['pasture']['structures'] = ['toy_station']
data['p104'] = dict(version=1, precision=100, capacity=4, birth_percent=10, carry_cap=10000,
    toy_percent=10, toy_recovery=1, agriculture_min_cells=4,
    hosts={'soothing_station': 'animal_breeding_assist', 'dispatch_station': 'animal_work_assist'},
    toy_id='vine_ball', toy_station='toy_station', install_ap=1, system_ap=1)
path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('P104 SOURCE OK')
