"""Reject broken production graphs and verify independently computed cost totals."""
import copy
import hashlib
import json
import unittest
from fractions import Fraction

import bake_v1 as bake


class V1FoundationTests(unittest.TestCase):
    def setUp(self):
        self.source = json.loads(bake.SOURCE.read_text(encoding='utf-8'))

    def row(self, section, ident):
        return next(row for row in self.source[section] if row['id'] == ident)

    def invalid(self):
        with self.assertRaises(ValueError):
            bake.compile_config(self.source)

    def test_bake_is_current_deterministic_and_leaves_v0_untouched(self):
        paths = list((bake.ROOT / 'content/farming/baked').glob('*.json'))
        before = {p: hashlib.sha256(p.read_bytes()).digest() for p in paths}
        frozen = copy.deepcopy(self.source)
        first = bake.dump(bake.compile_config(self.source))
        self.assertEqual(first, bake.dump(bake.compile_config(self.source)))
        self.assertEqual(first, bake.TARGET.read_bytes())
        self.assertEqual(self.source, frozen)
        self.assertEqual(before, {p: hashlib.sha256(p.read_bytes()).digest() for p in paths})

    def test_exact_shared_cost_and_canonical_multi_source_value(self):
        compiled = bake.compile_config(self.source)
        items = {r['id']: r for r in compiled['resources']}
        def value(packed):
            return Fraction(packed['numerator'], packed['denominator'])
        self.assertEqual(value(items['grain']['standard_cost']), Fraction(31, 10))
        self.assertEqual(value(items['straw']['standard_cost']), Fraction(31, 20))
        self.assertEqual(value(items['humus']['standard_cost']), Fraction(71, 20))
        self.assertEqual(items['humus']['supply_value'], 4)
        self.assertIn('wood_decay_mushroom', items['humus']['sources'])
        for model in self.source['cost_models']:
            audit = compiled['cost_audit'][model['id']]
            allocated = sum(value(audit['outputs'][iid]) * output['quantity']
                            for iid, output in model['outputs'].items())
            self.assertEqual(allocated, value(audit['total']))

    def test_eligibility_is_independent_from_element(self):
        items = {r['id']: r for r in bake.compile_config(self.source)['resources']}
        self.assertEqual(items['raw_wood']['element'], 'wood')
        self.assertFalse(items['raw_wood']['supply_allowed'])
        self.assertEqual(items['raw_wood']['supply_value'], 0)
        self.assertEqual(items['iron_ingot']['supply_value'], 10)

    def test_arbitrage_is_rejected(self):
        self.row('resources', 'grain')['buy_price'] = 4
        self.invalid()

    def test_double_allocation_is_rejected(self):
        self.row('cost_models', 'wheat')['outputs']['straw']['share'] = 1
        self.invalid()

    def test_cost_cycle_is_rejected(self):
        # Keep the real recipe and its basis consistent while making costs cyclic.
        self.row('cost_models', 'compost')['inputs'] = {'humus': 1}
        self.row('recipes', 'compost_straw')['inputs'] = {'humus': 1}
        self.invalid()

    def test_recipe_and_cost_basis_cannot_drift(self):
        self.row('recipes', 'smelt_charcoal')['outputs']['iron_ingot'] = 100
        self.invalid()

    def test_fixed_cash_is_allocated_once(self):
        self.row('cost_models', 'wheat')['cash'] = 2
        compiled = bake.compile_config(self.source)
        total = compiled['cost_audit']['wheat']['total']
        self.assertEqual(Fraction(total['numerator'], total['denominator']), Fraction(72, 5))

    def test_irrigation_actions_are_included_in_standard_ap(self):
        self.row('cost_models', 'wheat')['ap'] = 3
        self.invalid()

    def test_missing_canonical_output_is_rejected(self):
        self.row('resources', 'grain')['cost_source'] = 'fir'
        self.invalid()

    def test_facility_cannot_require_its_only_product(self):
        self.row('facilities', 'smelter')['materials']['iron_ingot'] = 1
        self.invalid()

    def test_missing_gold_route_is_rejected(self):
        self.source['recipes'] = [r for r in self.source['recipes']
                                  if 'iron_ingot' not in r['outputs']]
        self.invalid()

    def test_infinite_fungus_substrate_is_rejected(self):
        self.row('crops', 'wood_decay_mushroom')['inputs'].pop('wood_chip')
        self.invalid()

    def test_duplicate_sources_are_rejected(self):
        self.source['sources'][1]['position'] = self.source['sources'][0]['position']
        self.invalid()

    def test_invalid_shapes_and_boolean_numbers_are_rejected(self):
        for change in [lambda s: s.update(schema=True),
                       lambda s: s['config'].update(environment=[]),
                       lambda s: s['resources'][0].update(buy_price=True),
                       lambda s: s['sources'][0].update(quantity=0),
                       lambda s: s['orders'].update(rank_unlock_revenue={})]:
            self.setUp()
            change(self.source)
            self.invalid()

    def test_fixed_light_config_requires_bounded_nonoverlapping_regions(self):
        for region in [{'rect': [19, 13, 2, 2], 'level': 30},
                       {'rect': [0, 9, 1, 1], 'level': 30},
                       {'rect': [0, 0, 0, 2], 'level': 30},
                       {'rect': [0, 0, 1, 1], 'level': True}]:
            self.setUp()
            self.source['config']['light']['regions'].append(region)
            self.invalid()

    def test_environment_parameters_are_complete_and_positive(self):
        for mutation in [lambda s: s['config']['environment'].pop('optimal_water'),
                         lambda s: s['config']['environment'].update(low_water_efficiency=0),
                         lambda s: s['config']['environment'].update(low_light_efficiency=101)]:
            self.setUp()
            mutation(self.source)
            self.invalid()

    def test_construction_policy_has_no_refund_loophole(self):
        for mutation in [lambda s: s['config']['construction'].update(refund_percent=100),
                         lambda s: s['config']['construction'].update(build_ap=0),
                         lambda s: s['config']['construction'].update(demolish_ap=True),
                         lambda s: s['config']['construction'].pop('demolish_ap')]:
            self.setUp()
            mutation(self.source)
            self.invalid()


if __name__ == '__main__':
    unittest.main()
