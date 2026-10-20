"""Tamper probes against archived external evidence, never the game's verifier."""
import copy
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from audit_p107_playtest import AuditError, CASES, ROOT, audit_case

EVIDENCE = ROOT / '.art-work/p107-playtest'


class ReceiptTampering(unittest.TestCase):
    def rows(self, case):
        return [json.loads(line) for line in (EVIDENCE / case / 'commands.jsonl').read_text(encoding='utf-8').splitlines()]

    def reject(self, case, rows):
        with self.assertRaises(AuditError):
            audit_case(EVIDENCE / case, rows=rows)

    def test_honest_cases(self):
        for case in CASES:
            with self.subTest(case=case):
                self.assertGreater(audit_case(EVIDENCE / case)['checks'], 0)

    def test_forged_successful_supply_count(self):
        rows = self.rows('stage-orders')
        rows[0]['after']['orders'] += 1
        self.reject('stage-orders', rows)

    def test_repeated_order_cannot_count_again(self):
        rows = self.rows('stage-orders')
        orders = [r for r in rows if r['command'] == 'order']
        orders[1]['args'][0] = orders[0]['args'][0]
        self.reject('stage-orders', rows)

    def test_forged_order_premium(self):
        rows = self.rows('stage-orders')
        order = next(r for r in rows if r['command'] == 'order')
        order['result']['quote']['payout'] *= 5
        self.reject('stage-orders', rows)

    def test_missing_transaction(self):
        rows = self.rows('stage-resources')
        rows.pop(next(i for i, r in enumerate(rows) if r['command'] == 'exchange' and r['result']['ok']))
        for i, row in enumerate(rows, 1): row['n'] = i
        self.reject('stage-resources', rows)

    def test_duplicate_event_success(self):
        rows = self.rows('stage-resources')
        rows[-2]['result']['ok'] = True  # second final-event invocation
        self.reject('stage-resources', rows)

    def test_exchange_cannot_brush_orders(self):
        rows = self.rows('barter')
        next(r for r in rows if r['command'] == 'exchange' and r['result']['ok'])['after']['orders'] += 1
        self.reject('barter', rows)

    def test_missing_stock_exchange(self):
        rows = self.rows('barter')
        trade = next(r for r in rows if r['command'] == 'exchange' and r['result']['ok'])
        trade['args'][1] = 1000000
        self.reject('barter', rows)

    def test_unknown_exchange_receipt(self):
        rows = self.rows('barter')
        trade = next(r for r in rows if r['command'] == 'exchange' and r['result']['ok'])
        trade['args'][0] = 'unregistered-offer'
        self.reject('barter', rows)

    def test_wrong_exchange_output(self):
        rows = self.rows('stage-resources')
        trade = next(r for r in rows if r['command'] == 'exchange' and r['result']['ok'])
        trade['operations'][0]['receive']['composite_stone_panel'] += 1
        self.reject('stage-resources', rows)

    def test_missing_unique_transaction_identity(self):
        rows = self.rows('stage-resources')
        trade = next(r for r in rows if r['command'] == 'exchange' and r['result']['ok'])
        trade['operations'][0]['seq'] = 1
        self.reject('stage-resources', rows)

    def test_stage_skip_research(self):
        rows = self.rows('research-access')
        next(r for r in rows if r['command'] == 'start_research')['result']['ok'] = True
        self.reject('research-access', rows)

    def test_unsourced_inventory(self):
        rows = self.rows('growth-budget')
        rows[0]['after']['inventory']['resin'] = 100
        self.reject('growth-budget', rows)

    def test_duplicate_harvest_round(self):
        rows = self.rows('growth-budget')
        harvests = [r for r in rows if r['command'] == 'harvest']
        harvests[1]['args'] = copy.deepcopy(harvests[0]['args'])
        self.reject('growth-budget', rows)

    def test_final_cash_tamper_and_stale_configuration(self):
        with tempfile.TemporaryDirectory(prefix='audit-probe-', dir=ROOT / '.art-work/p107-tests') as directory:
            target = Path(directory) / 'case'
            shutil.copytree(EVIDENCE / 'growth-budget', target)
            final_path = target / 'final.json'
            final = json.loads(final_path.read_text(encoding='utf-8'))
            final['economy']['primeval_stones'] += 1
            final_path.write_text(json.dumps(final), encoding='utf-8')
            with self.assertRaisesRegex(AuditError, 'final external'):
                audit_case(target)
            final['economy']['primeval_stones'] -= 1
            final['world']['economy_progress']['exchanges'][0]['offer'] = 'forged-final-receipt'
            final_path.write_text(json.dumps(final), encoding='utf-8')
            with self.assertRaisesRegex(AuditError, 'receipt history'):
                audit_case(target)
            meta_path = target / 'case.json'
            meta = json.loads(meta_path.read_text(encoding='utf-8'))
            meta['production_sha256'] = '0' * 64
            meta_path.write_text(json.dumps(meta), encoding='utf-8')
            with self.assertRaisesRegex(AuditError, 'configuration changed'):
                audit_case(target)


if __name__ == '__main__':
    unittest.main()
