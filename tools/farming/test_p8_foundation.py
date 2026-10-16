"""P8 foundation checks: registry counts, frozen costs, research DAG integrity,
iron/liquid conservation, allocation table and layout/budget audits."""
import copy
import hashlib
import json
import unittest
from fractions import Fraction
import bake_p8 as bake

class P8FoundationTests(unittest.TestCase):
    def setUp(self): self.source=json.loads(bake.SOURCE.read_text(encoding='utf-8'))
    def row(self,section,ident): return next(r for r in self.source[section] if r['id']==ident)
    def invalid(self):
        with self.assertRaises(ValueError): bake.compile_config(self.source)

    def test_deterministic_and_preserves_prior_outputs(self):
        before={p:hashlib.sha256((bake.ROOT/p).read_bytes()).digest() for p in [
            'content/farming/baked/v1/production.json','content/farming/baked/v2/production.json']}
        original=copy.deepcopy(self.source)
        a=bake.common.dump(bake.compile_config(self.source))
        self.assertEqual(a,bake.common.dump(bake.compile_config(self.source)))
        self.assertEqual(a,bake.TARGET.read_bytes())
        self.assertEqual(self.source,original)
        for p,digest in before.items():
            self.assertEqual(digest,hashlib.sha256((bake.ROOT/p).read_bytes()).digest())

    def test_registry_counts(self):
        out=bake.compile_config(self.source)
        self.assertEqual(len(out['resources']),65)
        self.assertEqual(len(out['crops']),7)
        self.assertEqual(len(out['facilities']),15)
        self.assertEqual(len(out['recipes']),41)
        self.assertEqual(len(out['livestock']),6)
        self.assertNotIn('species', self.source)
        self.assertEqual(len(out['research']),12)
        audit=out['research_audit']
        self.assertEqual(audit['fee'],94); self.assertEqual(audit['days'],44)
        self.assertEqual(len(audit['order']),12)
        self.assertEqual(out['layout_audit']['land_used']<=out['layout_audit']['land_total'],True)

    def test_old_supply_values_frozen(self):
        out=bake.compile_config(self.source)
        items={r['id']:r for r in out['resources']}
        for iid,value in dict(steel_wool=11,fish_meat=6,humus=4,iron_ingot=10,charcoal=4,mushroom=5,resin=8,grain=4,clean_water=1).items():
            self.assertEqual(items[iid]['supply_value'],value,iid)

    def test_exact_new_costs_and_values(self):
        out=bake.compile_config(self.source)
        items={r['id']:r for r in out['resources']}
        for iid,value in dict(honey=Fraction(481,50),nectar=Fraction(309,40),wastewater=Fraction(7,10),
                              gravel=Fraction(545,48),land_feed=Fraction(2624,375)).items():
            p=items[iid]['standard_cost']
            self.assertEqual(Fraction(p['numerator'],p['denominator']),value,iid)
        for iid,value in dict(honey=10,nectar=8,refined_oil=8,gold_food=27,honey_cake=13,
                              fish_spirit_meal=12,dew_soup=9,fire_paste=19,earth_pill=13).items():
            self.assertEqual(items[iid]['supply_value'],value,iid)
        self.assertFalse(items['mineral_feed']['supply_allowed'])

    def test_provider_basis_tamper_rejected(self):
        for key,value in [('ap',28),('days',7),('cash',25),('inputs',{'honeybell_seed':4,'clean_water':35})]:
            with self.subTest(field=key):
                self.row('cost_models','bee_round')[key]=value
                self.invalid(); self.setUp()
        outputs=self.row('cost_models','bee_round')['outputs']
        outputs['honey']['share']=0.7
        self.invalid(); self.setUp()
        outputs=self.row('cost_models','bee_round')['outputs']
        outputs['honey']['quantity']=9
        self.invalid()

    def test_runtime_diet_change_requires_cost_rebake(self):
        self.row('livestock','steel_sheep')['base_diets'][0]['inputs']['fodder_grass']=2
        self.invalid()

    def test_species_registration_rules(self):
        self.row('livestock','bell_bee')['research']=''
        self.invalid(); self.setUp()
        self.row('livestock','rock_mole')['growth_days']=0
        self.invalid(); self.setUp()
        self.row('livestock','purifying_mat')['facility']='pen'
        self.invalid(); self.setUp()
        self.row('livestock','purifying_mat')['special_diets'][0].pop('outputs')
        self.invalid(); self.setUp()
        self.row('livestock','rock_mole')['special_diets'][0].pop('outputs')
        self.invalid()
        self.source['flowers']['share_capacity']=2
        self.invalid()

    def test_research_cycle_and_layer_rules(self):
        self.row('research','flower_cultivation')['prerequisites']=['composite_spirit_food']
        self.invalid(); self.setUp()
        self.row('research','mineral_materials')['days']=5
        self.invalid(); self.setUp()
        self.row('research','basic_spirit_cooking')['fee']=0
        self.invalid()

    def test_self_locking_sample_rejected(self):
        self.row('research','beekeeping')['samples']={'honey':1}
        self.invalid(); self.setUp()
        self.row('research','composite_spirit_food')['samples']={'gold_food':1}
        self.invalid()

    def test_unlock_registry_cross_references(self):
        self.row('research','rock_handling')['unlocks']['recipes']=['break_stone']
        self.invalid(); self.setUp()
        self.row('facilities','kitchen')['research']=''
        self.invalid(); self.setUp()
        self.row('facilities','kitchen')['research']='beekeeping'
        self.invalid(); self.setUp()
        self.row('resources','honeybell_seed')['research']=''
        self.invalid()

    def test_iron_share_conservation(self):
        self.row('recipes','break_ore')['outputs']['crushed_ore']=4
        self.invalid(); self.setUp()
        self.row('recipes','concentrate_ore')['outputs']['tailings']=2
        self.invalid(); self.setUp()
        self.row('recipes','mineral_feed')['outputs']['mineral_feed']=3
        self.invalid()

    def test_liquid_loss_on_purification(self):
        self.row('recipes','bio_purify')['outputs']['clean_water']=4
        self.invalid(); self.setUp()
        self.row('recipes','recover_nutrients')['outputs']['clean_water']=3
        self.invalid()

    def test_allocation_table_matches_models(self):
        model=self.row('cost_models','honeybell')['outputs']
        model['nectar']['share']=0.7; model['pollen']['share']=0.3
        self.invalid(); self.setUp()
        model=self.row('cost_models','recover_nutrients')['outputs']
        model['nutrient_liquid']['share']=0.7; model['clean_water']['share']=0.15; model['sludge']['share']=0.15
        self.invalid()

    def test_water_change_reference(self):
        self.source['husbandry']['water']['change']['wastewater']=0
        self.invalid(); self.setUp()
        self.source['husbandry']['water']['change']['gain']=50
        self.invalid()

    def test_purchase_chain_reaches_raw_inputs(self):
        out=bake.compile_config(self.source)
        chain=out['purchase_audit']['gold_food']
        self.assertEqual(chain['quantity'],1)
        self.assertGreater(chain['payout'],20)
        self.assertTrue(chain['requires_production'])
        leaves=set(chain['buyable_leaves'])
        self.assertTrue({'honeybell_seed'} <= leaves or 'iron_ore' in leaves)

if __name__=='__main__': unittest.main()
