"""Expansion config tampering must fail before it reaches the runtime."""
import copy
import json
import unittest
from pathlib import Path
import bake_p8

class ExpansionConfigTests(unittest.TestCase):
    def setUp(self):
        self.config = json.loads((Path(__file__).resolve().parents[2] / 'content/farming/p8/expansion.json').read_text(encoding='utf-8'))

    def test_stable_and_independent_banks(self):
        self.assertEqual(bake_p8.expansion_output(self.config), bake_p8.expansion_output(copy.deepcopy(self.config)))
        self.assertEqual(self.config['parcels'][3]['requires'], [])
        self.assertEqual(self.config['parcels'][4]['requires'], [])
        self.assertLess(self.config['parcels'][3]['rect'][0], 0)

    def test_bad_parcels_rejected(self):
        changes = [
            ('free', lambda c: c['parcels'][0].update(price=0)),
            ('bool_price', lambda c: c['parcels'][0].update(price=True)),
            ('overlap', lambda c: c['parcels'][1].update(rect=[20,0,4,8])),
            ('base_overlap', lambda c: c['parcels'][0].update(rect=[19,0,4,8])),
            ('outside', lambda c: c['parcels'][3].update(rect=[-5,14,4,8])),
            ('wrong_terrain', lambda c: c['parcels'][3].update(terrain='grass')),
            ('cycle', lambda c: c['parcels'][0].update(requires=['east_far'])),
            ('duplicate', lambda c: c['parcels'][1].update(id='east_near')),
        ]
        for name, change in changes:
            with self.subTest(name=name):
                config=copy.deepcopy(self.config)
                change(config)
                with self.assertRaises(ValueError): bake_p8.expansion_output(config)

if __name__ == '__main__': unittest.main()
