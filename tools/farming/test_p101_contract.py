"""Static contract between the P10.1 operator, its books and the auditor.

None of these checks need Godot or generated books: they parse the operator
source and the data sources directly, so a drifted cell list, an unsampled
footprint, a mislabeled action or an untiltable station zone fails here in
seconds instead of after a 2x120-day replay.
"""
import json
import re
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OPERATOR=(ROOT/'scripts/farming/tests/run_p101_playtest.gd').read_text(encoding='utf-8')
AUDIT=(ROOT/'tools/farming/audit_p101_playtest.py').read_text(encoding='utf-8')

def cells(name):
    found=re.search(r'const %s := \[(.*?)\]' % name, OPERATOR, re.S).group(1)
    return {tuple(int(v) for v in m) for m in re.findall(r'Vector2i\((-?\d+),\s*(-?\d+)\)', found)}

def station_cells(name):
    found=re.search(r'const %s := \{(.*?)\n\}' % name, OPERATOR, re.S).group(1)
    out={}
    for m in re.finditer(r'"(M[0-9T]+)".*?Vector2i\((-?\d+),\s*(-?\d+)\).*?"facing": "(\w+)".*?"gu": "([\w-]+)".*?"kind": "(\w+)"', found):
        out[m.group(1)]={'cell':(int(m.group(2)),int(m.group(3))),'facing':m.group(4),'gu':m.group(5),'kind':m.group(6)}
    return out

FIR_FOOTPRINT={(3,11),(4,11),(3,12),(4,12)}

def zone(origin, facing, host=(2,2), size=3):
    x,y=origin
    xs={'east':(x+host[0],x+host[0]+size),'south':(x-1,x-1+size),'west':(x-size,x-size+size),'north':(x,x+size)}[facing]
    ys={'east':(y,y+size),'south':(y+host[1],y+host[1]+size),'west':(y-1,y-1+size),'north':(y-size,y-size+size)}[facing]
    return {(xx,yy) for xx in range(*xs) for yy in range(*ys)}

def expanded_terrain():
    expansion=json.loads((ROOT/'content/farming/baked/p8/expansion.json').read_text(encoding='utf-8'))
    grid=json.loads((ROOT/'content/farming/baked/maps/farm_02.json').read_text(encoding='utf-8'))['grid']
    def terrain(x,y):
        base=[int(v) for v in expansion['base']]
        if base[0]<=x<base[0]+base[2] and base[1]<=y<base[1]+base[3]:
            return grid[y][x-base[0]]
        for parcel in expansion['parcels']:
            r=parcel['rect']
            if r[0]<=x<r[0]+r[2] and r[1]<=y<r[1]+r[3]: return parcel['terrain']
        return None
    return terrain, int(expansion['origin_x']), expansion['size']

PLOTS={'M1':cells('M1_WHEAT'),
       'M2':cells('M2_PASTURE')|cells('M2_WHEAT'),
       'M3':cells('M3_WHEAT')|FIR_FOOTPRINT,
       'M4':cells('M4_WHEAT'),
       'M4T':cells('M4_TURNED_WHEAT')}

class OperatorContract(unittest.TestCase):
    def test_books_sample_every_farmed_cell(self):
        assert 'm2_cells.append_array(M2_WHEAT)' in OPERATOR and 'M2_PASTURE.duplicate()' in OPERATOR
        assert 'm3_cells.append_array([M3_FIR,Vector2i(4,11),Vector2i(3,12),Vector2i(4,12)])' in OPERATOR
        for module in PLOTS:
            assert '["%s",' % module in OPERATOR, ('module missing from the archive sampling loop',module)

    def test_farmed_cells_lie_inside_their_service_zone(self):
        stations=station_cells('AGRI_STATIONS')
        assert set(stations)=={'M2','M3','M4'}, stations
        zones={'M1':zone((7,9),'east'),'M4T':set()}
        for key,spec in stations.items():
            zones[key]=zone(spec['cell'],spec['facing'])
        for module in ('M1','M2','M3','M4'):
            assert PLOTS[module] <= zones[module], (module,sorted(PLOTS[module]-zones[module]))

    def test_zones_avoid_stations_sources_and_untillable_ground(self):
        terrain,origin_x,size=expanded_terrain()
        source=json.loads((ROOT/'content/farming/p8/production.json').read_text(encoding='utf-8'))
        sources={tuple(s['position']) for s in source['sources']}
        stations=station_cells('AGRI_STATIONS')
        footprints={k:{(spec['cell'][0]+dx,spec['cell'][1]+dy) for dx in range(2) for dy in range(2)} for k,spec in stations.items()}
        footprints['base']={(7,9),(8,9),(7,10),(8,10)}
        for key,spec in stations.items():
            assert terrain(*spec['cell']) in ('grass','dirt'), ('station on bad ground',key,spec['cell'])
        names=list(footprints)
        for i in range(len(names)):
            for j in range(i+1,len(names)):
                assert not (footprints[names[i]] & footprints[names[j]]), ('station overlap',names[i],names[j])
        for key,footprint in footprints.items():
            assert not (footprint & sources), ('station covers a resource point',key)
        for module,plot in PLOTS.items():
            for cell in plot:
                assert origin_x<=cell[0]<origin_x+size[0] and 0<=cell[1]<size[1], ('outside map',module,cell)
                assert terrain(*cell) in ('grass','dirt'), ('untiltable plot cell',module,cell,terrain(*cell))

    def test_audit_maps_match_the_operator(self):
        stations=station_cells('AGRI_STATIONS')
        compact=''.join(AUDIT.split())
        for module in PLOTS:
            assert "'%s':{'gu':" % module in compact, ('module missing from audit map',module)
        for crop in ('golden_wheat','fast_fir','pasture_grass'):
            assert "'%s':{'water'" % crop in compact, ('crop missing from audit USE map',crop)
        retention={'water':(50,100),'fert':(100,50),'growth':(100,100)}
        for key,spec in stations.items():
            marker="'%s':{'gu':'%s','water':%d,'fertility':%d}" % (key,
                {'water':'water_gu','fert':'fert_gu','growth':'growth_gu'}[spec['kind']],*retention[spec['kind']])
            assert marker in compact, ('retention attribution drifted',key,marker)

    def test_audit_action_prefixes_exist_in_the_operator(self):
        for label in ('module harvest ','module fir fell','module irrigate ','module fir irrigate',
                      'module fertilize ','module fir fertilize','rotate M4 '):
            assert '"%s' % label in OPERATOR, ('audit counts a label the operator never emits',label)

if __name__=='__main__':
    unittest.main()
