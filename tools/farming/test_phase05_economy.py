import copy
import json
import unittest
from pathlib import Path
from bake_farm import validate_economy


class EconomyContractTests(unittest.TestCase):
    def setUp(self):
        root = Path(__file__).resolve().parents[2] / 'content/farming'
        self.config, self.items, self.crops = [json.loads((root / (name + '.json')).read_text(encoding='utf-8'))
                                               for name in ('config', 'items', 'crops')]

    def errors(self):
        errors = []
        validate_economy(self.config, self.items, self.crops, errors)
        return errors

    def test_actual_content(self):
        self.assertEqual(self.errors(), [])

    def test_invalid_prices_elements_and_medium_reference(self):
        original = copy.deepcopy(self.items)
        for changes in ({'buy_price': -1}, {'sell_price': 1.5}, {'path_ids': ['metal']}, {'kind': 'invalid'}):
            self.items = copy.deepcopy(original)
            self.items['items'][0].update(changes)
            self.assertTrue(self.errors())
        self.items = original
        self.config['economy']['medium_materials']['fungal_bed'] = 'dew_leaf'
        self.assertTrue(self.errors())

    def test_cost_weights_and_crop_contract(self):
        self.config['economy']['ap_weight'] = -1
        self.assertTrue(self.errors())
        self.config['economy']['ap_weight'] = 1
        self.crops['crops'][0]['path_id'] = 'fire'
        self.assertTrue(self.errors())


if __name__ == '__main__':
    unittest.main()
