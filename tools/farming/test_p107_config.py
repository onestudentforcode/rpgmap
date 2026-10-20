"""Negative probes for stage reachability and zero-time trade amplification."""
import copy
import json
from fractions import Fraction
from pathlib import Path
import unittest

from validate_p107 import market_exchange_certificate, validate

ROOT = Path(__file__).resolve().parents[2]


class EconomyConfiguration(unittest.TestCase):
    def setUp(self):
        self.source = json.loads((ROOT / 'content/farming/p8/production.json').read_text(encoding='utf-8'))

    def test_live_certificate_covers_each_trade_and_cash_edge(self):
        result = validate(self.source)
        weights = {k: Fraction(v) for k, v in result['market_exchange_potential'].items()}
        for r in self.source['resources']:
            self.assertGreaterEqual(weights[r['id']], max(1, r['sell_price']))
            if r['buy_price']:
                self.assertLessEqual(weights[r['id']], r['buy_price'])
        for offer in self.source['p107']['offers']:
            before = sum(weights[k] * n for k, n in offer['give'].items())
            after = sum(weights[k] * n for k, n in offer['receive'].items())
            self.assertLessEqual(after, before, offer['id'])

    def test_two_step_amplification_is_rejected(self):
        resources = {k: {'sell_price': 1, 'buy_price': 0} for k in ['x', 'y']}
        offers = [{'give': {'x': 1}, 'receive': {'y': 2}}, {'give': {'y': 1}, 'receive': {'x': 1}}]
        with self.assertRaisesRegex(ValueError, 'cycle'):
            market_exchange_certificate(resources, offers)

    def test_equal_return_cycle_is_legal(self):
        resources = {k: {'sell_price': 1, 'buy_price': 0} for k in ['x', 'y']}
        offers = [{'give': {'x': 1}, 'receive': {'y': 1}}, {'give': {'y': 1}, 'receive': {'x': 1}}]
        self.assertEqual(market_exchange_certificate(resources, offers), {'x': '1', 'y': '1'})

    def test_buy_sell_amplification_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'market'):
            market_exchange_certificate({'x': {'sell_price': 2, 'buy_price': 1}}, [])

    def test_later_stage_research_dependency_rejected(self):
        self.source['p107']['gates']['research']['flower_cultivation'] = 3
        with self.assertRaisesRegex(ValueError, 'later-stage prerequisite'):
            validate(self.source)

    def test_final_event_exchange_must_exist_before_reward(self):
        for offer in self.source['p107']['offers']:
            if 'water_retaining_matrix' in offer['receive']:
                offer['stage'] = 3
        with self.assertRaisesRegex(ValueError, 'own event'):
            validate(self.source)

    def test_directly_buyable_exchange_token_rejected(self):
        next(r for r in self.source['resources'] if r['id'] == 'resin')['buy_price'] = 20
        with self.assertRaisesRegex(ValueError, 'produced specialties'):
            validate(self.source)

    def test_duplicate_offer_and_zero_input_rejected(self):
        self.source['p107']['offers'].append(copy.deepcopy(self.source['p107']['offers'][0]))
        with self.assertRaises(ValueError):
            validate(self.source)
        self.source['p107']['offers'].pop()
        self.source['p107']['offers'][0]['give']['silk'] = 0
        with self.assertRaises(ValueError):
            validate(self.source)


if __name__ == '__main__':
    unittest.main()
