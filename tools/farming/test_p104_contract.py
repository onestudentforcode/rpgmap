import copy
import json
import unittest
from pathlib import Path

from bake_p8 import compile_config
from validate_p104 import validate

SOURCE = json.loads((Path(__file__).resolve().parents[2] / 'content/farming/p8/production.json').read_text(encoding='utf-8'))


class ServicesContract(unittest.TestCase):
    def test_bakes_real_recipe_and_consumer(self):
        result = compile_config(SOURCE)
        ball = next(r for r in result['resources'] if r['id'] == 'vine_ball')
        self.assertIn('toy_station:durable_installation', ball['consumers'])
        self.assertEqual(next(r for r in result['recipes'] if r['id']=='make_vine_ball')['facility'], 'woodshop')

    def test_rejects_frozen_value_and_unlock_drift(self):
        for mutate in [lambda d: d['p104'].update(toy_percent=100),
                       lambda d: d['p104'].update(capacity=True),
                       lambda d: next(r for r in d['recipes'] if r['id']=='make_vine_ball').update(research='rock_handling'),
                       lambda d: d['p103']['zones']['pasture'].update(structures=[])]:
            data = copy.deepcopy(SOURCE)
            mutate(data)
            with self.assertRaises(ValueError):
                validate(data)


if __name__ == '__main__':
    unittest.main()
