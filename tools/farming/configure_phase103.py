"""P10.3 source installation, safe to repeat; baked output is compiler-owned."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'content/farming/p8/production.json'
data=json.loads(path.read_text(encoding='utf-8'))

# New structural facilities for animal zones. Beds use cell density: one
# ordinary floor cell holds a group of four small or medium beds and counts as
# one usable space; only the large bed fills a whole cell with a single bed.
# Group prices keep the original single-cell cost; the large-bed price is a
# first-round draft value (no species sleeps in it this phase).
data['facilities']=[f for f in data['facilities'] if f['id']!='medium_bed_v']
new_facilities=[
    dict(id='dispatch_station',name='调度站',cash=18,materials={'raw_wood':2,'raw_stone':2},
         terrain='land',footprint=[1,1],kind=None),
    dict(id='feed_trough',name='供食槽',cash=6,materials={'raw_wood':2},
         terrain='land',footprint=[1,1],kind=None),
    dict(id='small_bed',name='小床',cash=6,materials={'raw_wood':2},
         terrain='land',footprint=[1,1],kind=None),
    dict(id='medium_bed',name='中床',cash=10,materials={'raw_wood':3},
         terrain='land',footprint=[1,1],kind=None),
    dict(id='large_bed',name='大床',cash=14,materials={'raw_wood':4},
         terrain='land',footprint=[1,1],kind=None),
    dict(id='care_table',name='照料台',cash=24,materials={'wood_plank':2,'raw_stone':2},
         terrain='land',footprint=[1,1],kind=None),
]
for facility in new_facilities:
    data['facilities']=[f for f in data['facilities'] if f['id']!=facility['id']]
    data['facilities'].append(facility)

data['p103']={
    'version':1,
    'species':{
        'steel_sheep':{'space':2,'bed':'medium','growth_units':36,'breed_units':72,
            'natural_units':18,'natural_outputs':{'steel_wool':1,'sheep_manure':1},
            'natural_diet':'iron_supplement'},
        'rock_mole':{'space':1,'bed':'small','growth_units':18,'breed_units':48},
        'rock_belly_beast':{'space':1,'bed':'small','growth_units':24,'breed_units':96}},
    'zones':{
        'nursery':{'min_space':4,'structures':['pen','feed_trough','bed']},
        'enclosure':{'min_space':8,'structures':['pen','feed_trough','bed','care_table']},
        'work':{'min_space':0,'structures':['dispatch_station','rock_workyard']},
        'maintenance':{'min_space':4,'structures':['feed_trough','bed']},
        'pasture':{'min_space':8,'structures':[]}},
    'fatigue':{'work_debt':1,'rest_credit':2,'fail_penalty':12,'cap':100,'enclosure_rest_cap':6,
        'tiers':[{'max':7,'efficiency':100,'label':'正常'},{'max':15,'efficiency':75,'label':'疲倦'},
                 {'max':23,'efficiency':50,'label':'过劳'},{'max':39,'efficiency':0,'label':'罢工'},
                 {'max':100,'efficiency':0,'label':'濒危'}],
        'death_threshold':40,'death_streak':3},
    'work':{'posts_per_yard':4,'points_per_unit':100,
        'recipes':{'break_stone':{'species':'rock_mole','target':400},
                   'break_ore':{'species':'rock_mole','target':400},
                   'concentrate_ore':{'species':'rock_belly_beast','target':800}},
        'default_recipe':'break_stone'},
    'meals':{'nursery':1,'work':1,'enclosure':2},
    'trough_slots':2,
    'bed_facilities':{'small_bed':{'type':'small','slots':4},
                      'medium_bed':{'type':'medium','slots':4},
                      'large_bed':{'type':'large','slots':1}},
    'patterns':{'standard':['M','M','W','W','W','W','R','R'],
                'late':['W','W','R','R','M','M','W','W']},
    'fixed_pattern':['M','M','C','C','C','C','C','C'],
    'ap':{'submit':1,'claim_workyard':1,'claim_products':1,'claim_births':1}}
path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('P103 SOURCE OK: ranch config and %d structural facilities' % len(new_facilities))
