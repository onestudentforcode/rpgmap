import copy
import hashlib
import json
import unittest
from fractions import Fraction
import bake_v2 as bake

class V2FoundationTests(unittest.TestCase):
    def setUp(self): self.source=json.loads(bake.SOURCE.read_text(encoding='utf-8'))
    def row(self,section,ident): return next(r for r in self.source[section] if r['id']==ident)
    def invalid(self):
        with self.assertRaises(ValueError): bake.compile_config(self.source)
    def test_deterministic_and_preserves_v1(self):
        before=hashlib.sha256((bake.ROOT/'content/farming/baked/v1/production.json').read_bytes()).digest()
        original=copy.deepcopy(self.source)
        a=bake.common.dump(bake.compile_config(self.source))
        self.assertEqual(a,bake.common.dump(bake.compile_config(self.source)))
        self.assertEqual(a,bake.TARGET.read_bytes())
        self.assertEqual(self.source,original)
        self.assertEqual(before,hashlib.sha256((bake.ROOT/'content/farming/baked/v1/production.json').read_bytes()).digest())
    def test_exact_costs_and_values(self):
        out=bake.compile_config(self.source)
        items={r['id']:r for r in out['resources']}
        for iid,value in dict(fodder_grass=Fraction(46,15),algae_feed=Fraction(77,60),steel_wool=Fraction(2169,200),sheep_manure=Fraction(241,200),fish_meat=Fraction(1649,300),fish_manure=Fraction(291,100)).items():
            p=items[iid]['standard_cost']; self.assertEqual(Fraction(p['numerator'],p['denominator']),value,iid)
        self.assertEqual(items['steel_wool']['supply_value'],11)
        self.assertEqual(items['fish_meat']['supply_value'],6)
        self.assertFalse(items['fodder_grass']['supply_allowed'])
    def test_basis_inputs_ap_days_yield_cash_and_shares(self):
        for key,value in [('ap',7),('days',5),('cash',0),('inputs',{'algae_feed':12}),('outputs',{'fish_meat':{'quantity':12,'share':0.84},'fish_manure':{'quantity':4,'share':0.15}})]:
            with self.subTest(field=key):
                original=copy.deepcopy(self.source)
                self.row('cost_models','fish')[key]=value
                self.invalid(); self.source=original
    def test_runtime_diet_change_requires_cost_rebake(self):
        self.row('livestock','filter_algae_carp')['base_diets'][0]['algae_feed']=2
        self.invalid()
    def test_livestock_not_inventory_and_capacity(self):
        self.assertFalse({'steel_sheep','filter_algae_carp'} & {r['id'] for r in self.source['resources']})
        self.row('facilities','fish_pond')['capacity']=5
        self.invalid()
    def test_bad_terrain_and_water(self):
        self.row('facilities','fish_pond')['terrain']='land'; self.invalid()
        self.setUp(); self.source['husbandry']['water']['pause_threshold']=100; self.invalid()
        self.setUp(); self.row('facilities','algae_tank')['terrain']='water'; self.invalid()
    def test_cost_cycle_rejected(self):
        self.row('cost_models','algae')['inputs']={'fish_meat':1}
        self.row('recipes','culture_algae')['inputs']={'fish_meat':1}
        self.invalid()
    def test_no_construction_deadlock(self):
        self.row('facilities','pen')['materials']={'steel_wool':1}
        self.invalid()
    def test_purchase_chain_reaches_raw_inputs(self):
        out=bake.compile_config(self.source)
        chain=out['purchase_audit']['fish_meat']
        self.assertEqual(chain['quantity'],12)
        self.assertEqual(chain['payout'],118) # 108 + floor(10.8)
        self.assertEqual(set(chain['buyable_leaves']),{'clean_water','straw','grain'})
        self.assertEqual(chain['buyable_leaves']['straw'],{'numerator':8,'denominator':1})
        self.assertTrue(chain['requires_production'])
    def test_buy_to_order_arbitrage_rejected(self):
        self.row('resources','fish_meat')['buy_price']=9; self.invalid()

if __name__=='__main__': unittest.main()
