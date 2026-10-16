"""P10 rejects malformed ability contracts and keeps the old economy intact."""
import copy
import json
import unittest
import bake_p8
from validate_logistics import validate

class LogisticsFoundation(unittest.TestCase):
    def setUp(self):
        self.source=json.loads(bake_p8.SOURCE.read_text(encoding='utf-8'))
    def reject(self, change):
        change(self.source['logistics'])
        with self.assertRaises(ValueError): validate(self.source)
    def test_template_instance_boundary(self):
        cfg=self.source['logistics']
        self.assertEqual(len(cfg['definitions']),5)
        self.assertEqual(len(cfg['provision']),6)
        self.assertEqual(cfg['provision'].count('rice_bag_gu'),2)
        validate(self.source)
    def test_combat_cannot_become_producer(self):
        self.reject(lambda c:c['definitions'][0].update(role='combat'))
    def test_unknown_template_in_provision(self):
        self.reject(lambda c:c['provision'].append('unregistered'))
    def test_no_incompatible_facility_slot(self):
        self.reject(lambda c:c['definitions'][1].update(slot='research_assist'))
    def test_scope_and_evaluator_cannot_drift(self):
        self.reject(lambda c:c['definitions'][1].update(scope='SELF'))
    def test_unsupported_fractional_research_speed_rejected(self):
        self.reject(lambda c:c['definitions'][-1].update(value=150))
    def test_invalid_environment_and_fractional_fee(self):
        for field in ('min_water','min_light','water_use'):
            with self.subTest(field=field):
                bad=copy.deepcopy(self.source)
                bad['logistics']['definitions'][0]['production'][field]=-1
                with self.assertRaises(ValueError): validate(bad)
        self.reject(lambda c:c['definitions'][0].update(fee=0.5))
    def test_maintenance_special_food_has_actual_market_source(self):
        out=bake_p8.compile_config(self.source)
        food=next(r for r in out['resources'] if r['id']=='time_feed')
        self.assertEqual(food['buy_price'],2)
        self.assertIn('gu_maintenance:time_gu',food['consumers'])
        self.assertEqual(self.source['logistics']['definitions'][-1]['food'],{'time_feed':1})
    def test_rice_production_cost_and_downstream_are_real(self):
        out=bake_p8.compile_config(self.source)
        rice=next(r for r in out['resources'] if r['id']=='rice')
        self.assertIn('rice_gu_provider',rice['sources'])
        self.assertIn('mill_rice',rice['consumers'])
        self.assertEqual(rice['supply_value'],3)
        self.assertTrue(rice['supply_allowed'])
        model=next(r for r in self.source['cost_models'] if r['id']=='rice_round')
        self.assertEqual(model['cash'],3)
        self.assertEqual(model['inputs'],{'clean_water':1})
    def test_new_recipe_reachable_without_extra_research(self):
        out=bake_p8.compile_config(self.source)
        self.assertEqual(out['research_audit']['days'],44)
        self.assertEqual(out['research_audit']['fee'],94)
        project=next(r for r in out['research'] if r['id']=='farm_preparation')
        self.assertIn('mill_rice',project['unlocks']['recipes'])

if __name__=='__main__': unittest.main()
