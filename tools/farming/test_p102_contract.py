"""P10.2 source/knowledge contracts. Model and transaction tests run in Godot."""
import copy
import json
import unittest
from pathlib import Path

from validate_rooms import validate

ROOT=Path(__file__).resolve().parents[2]
SOURCE=json.loads((ROOT/'content/farming/p8/production.json').read_text(encoding='utf-8'))
WIKI=json.loads((ROOT/'content/farming/baked/encyclopedia/encyclopedia.json').read_text(encoding='utf-8'))


class RoomContract(unittest.TestCase):
    def test_current_contract(self):
        validate(SOURCE)

    def test_reject_drift(self):
        mutations=[
            lambda d:d['rooms'].update(seed_percent=100),
            lambda d:d['rooms']['floor'].update(refund=True),
            lambda d:d['rooms']['floor'].update(place_ap=0),
            lambda d:d['rooms']['primary']['golden_wheat'].update(harvest='straw'),
            lambda d:d['rooms']['primary']['rice_bag_gu'].update(claim='rice_bag_gu'),
            lambda d:d['rooms']['primary'].pop('resin_tree'),
            lambda d:d['rooms']['primary']['resin_tree'].pop('fell'),
            lambda d:d['rooms']['requirements'].update(seed=['plant_growth_speed']),
            lambda d:next(f for f in d['facilities'] if f['id']=='field_service_station').update(footprint=[2,2]),
        ]
        for mutation in mutations:
            d=copy.deepcopy(SOURCE)
            mutation(d)
            with self.subTest(mutation=mutation),self.assertRaises(ValueError): validate(d)

    def test_seed_reverse_sources(self):
        entities={e['id']:e for e in WIKI['entities']}
        for crop in SOURCE['crops']:
            seed=entities['resource:'+crop['seed']]
            self.assertIn('proc:room-seed:'+crop['id'],{p['process'] for p in seed['sources']})
            self.assertIn('rule:rooms',entities['crop:'+crop['id']]['related_rules'])

    def test_material_reverse_sources(self):
        entities={e['id']:e for e in WIKI['entities']}
        processes={p['id']:p for p in WIKI['processes']}
        for ident,modes in SOURCE['rooms']['primary'].items():
            for mode,item in modes.items():
                pid=f'proc:room-material:{ident}:{mode}'
                self.assertIn(pid,{p['process'] for p in entities['resource:'+item]['sources']})
                self.assertEqual([o['entity'] for o in processes[pid]['outputs']],['resource:'+item])
                self.assertIsNone(processes[pid]['outputs'][0]['quantity'])

    def test_asset_contract(self):
        manifest=json.loads((ROOT/'assets/farming/facilities/facility_manifest.json').read_text(encoding='utf-8'))
        station=manifest['facilities']['field_service_station']
        self.assertEqual(station['footprint'],[1,1])
        self.assertEqual(station['scale_multiplier'],0.5)
        grounding=json.loads((ROOT/'content/farming/p8/grounding.json').read_text(encoding='utf-8'))
        self.assertEqual(station['shadow']['size'],grounding['facilities']['field_service_station']['size'])
        self.assertEqual(station['shadow']['offset'],grounding['facilities']['field_service_station']['offset'])

    def test_live_rules_replace_old_geometry(self):
        rules={e['id']:e for e in WIKI['entities'] if e['kind']=='rule'}
        text=json.dumps(rules['rule:agriculture'],ensure_ascii=False)
        self.assertIn('1×1',text)
        self.assertIn('5×5',text)
        self.assertNotIn('宿主2×2',text)
        self.assertIn('rule:rooms',rules)


if __name__=='__main__': unittest.main()
