import copy
import json
import unittest
from pathlib import Path
import bake_farm

ROOT = Path(__file__).resolve().parents[2]

class ToolContractTests(unittest.TestCase):
    def setUp(self):
        self.config = json.loads((ROOT / 'content/farming/config.json').read_text(encoding='utf-8'))
        self.items = {item['item_id'] for item in json.loads((ROOT / 'content/farming/items.json').read_text(encoding='utf-8'))['items']}

    def test_real_tool_prices_and_baked_content(self):
        errors = []
        bake_farm.validate_config(self.config, self.items, errors)
        self.assertEqual(errors, [])
        baked = json.loads((ROOT / 'content/farming/baked/config.json').read_text(encoding='utf-8'))
        self.assertEqual(self.config['advanced_tools'], baked['advanced_tools'])

    def test_invalid_tool_prices_and_registry_are_rejected(self):
        for prices in [None, {}, {'hoe': 30}, {'hoe': 30, 'sower': 40, 'harvester': 40, 'extra': 1}]:
            config = copy.deepcopy(self.config)
            config['advanced_tools'] = prices
            errors = []
            bake_farm.validate_config(config, self.items, errors)
            self.assertTrue(errors)
        for price in [0, -1, True, 1.5, '30', 1000001]:
            config = copy.deepcopy(self.config)
            config['advanced_tools']['hoe'] = price
            errors = []
            bake_farm.validate_config(config, self.items, errors)
            self.assertTrue(errors)
