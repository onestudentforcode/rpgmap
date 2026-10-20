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
        self.assertEqual(len(cfg['definitions']),11)
        self.assertEqual(len(cfg['provision']),15)
        self.assertEqual(cfg['provision'][:6],
            ['rice_bag_gu','rice_bag_gu','bright_gu','growth_gu','wisdom_gu','time_gu'])
        self.assertEqual(cfg['provision'].count('growth_gu'),2)
        self.assertEqual(cfg['provision'].count('water_gu'),2)
        self.assertEqual(cfg['provision'].count('fert_gu'),2)
        validate(self.source)
    def test_p101_shared_slot_and_frozen_zone(self):
        cfg=self.source['logistics']
        station=next(f for f in self.source['facilities'] if f['id']=='field_service_station')
        self.assertEqual(station['gu_slot'],'agriculture_assist')
        for row in cfg['definitions']:
            if row['id'] in ('growth_gu','water_gu','fert_gu'):
                self.assertEqual((row['slot'],row['scope'],row['range']),('agriculture_assist','DIRECTED_AREA',3))
                self.assertEqual(row['tags'],['agriculture_assist',row['tags'][1]])
                self.assertEqual((row['fee'],row['food']),(1,{}))
        growth=next(r for r in cfg['definitions'] if r['id']=='growth_gu')
        self.assertEqual((growth['value'],growth['effect']),(150,'growth_speed'))
        for ident in ('water_gu','fert_gu'):
            self.assertEqual(next(r for r in cfg['definitions'] if r['id']==ident)['value'],50)
        self.assertEqual(cfg['rotate_ap'],1)
    def test_agriculture_contracts_reject_drift(self):
        def swap(def_id, **changes):
            row=next(r for r in self.source['logistics']['definitions'] if r['id']==def_id)
            row.update(changes)
        self.reject(lambda c: swap('growth_gu',value=120))
        self.reject(lambda c: swap('water_gu',value=100))
        self.reject(lambda c: swap('fert_gu',range=2))
        self.reject(lambda c: swap('water_gu',tags=['agriculture_assist']))
        self.reject(lambda c: swap('bright_gu',slot='agriculture_assist',tags=['agriculture_assist','light_source']))
        self.reject(lambda c: swap('growth_gu',scope='AREA'))
        self.reject(lambda c: c.__setitem__('provision',
            ['rice_bag_gu','bright_gu','growth_gu','wisdom_gu','time_gu','water_gu','water_gu','fert_gu','fert_gu','growth_gu']))
    def test_higher_rank_never_weakens_group(self):
        base=copy.deepcopy(self.source)
        stronger=copy.deepcopy(next(r for r in base['logistics']['definitions'] if r['id']=='growth_gu'))
        stronger.update(id='growth_gu_2',rank=2,value=140)
        base['logistics']['definitions'].append(stronger)
        with self.assertRaises(ValueError): validate(base)
        stronger['value']=150
        validate(base)
    def test_plant_grow_registry_is_exact(self):
        crop=next(c for c in self.source['crops'] if c['id']=='golden_wheat')
        saved=crop['target_tags']
        for bad in ([], ['plant_grow','something_else']):
            with self.subTest(bad=bad):
                crop['target_tags']=bad
                try:
                    with self.assertRaises(ValueError): validate(self.source)
                finally:
                    crop['target_tags']=saved
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
        time_gu=lambda c: next(d for d in c['definitions'] if d['id']=='time_gu')
        self.reject(lambda c:time_gu(c).update(value=150))
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
        time_gu=next(d for d in self.source['logistics']['definitions'] if d['id']=='time_gu')
        self.assertEqual(time_gu['food'],{'time_feed':1})
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
        self.assertEqual(out['research_audit']['days'],48)
        self.assertEqual(out['research_audit']['fee'],104)
        project=next(r for r in out['research'] if r['id']=='farm_preparation')
        self.assertIn('mill_rice',project['unlocks']['recipes'])

if __name__=='__main__': unittest.main()
