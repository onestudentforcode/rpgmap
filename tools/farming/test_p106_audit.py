# -*- coding: utf-8 -*-
"""Tamper probes for the P10.6 auditor: each forged ledger must be rejected
with a named failure while the honest evidence passes (freeze §16.2.13)."""
import copy
import json
import shutil
import tempfile
import unittest
from pathlib import Path

import audit_p106_playtest as auditor

BASE = auditor.ROOT / '.art-work/p106-playtest'


def write_rows(path, rows):
    with open(path, 'w', encoding='utf-8') as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False) + '\n')


def forged_route(route, mutate_receipts=None, mutate_days=None):
    tmp = Path(tempfile.mkdtemp(prefix='p106-audit-'))
    for pattern in (f'{route}-receipts.jsonl', f'{route}-days.jsonl'):
        source = BASE / pattern
        if source.exists():
            shutil.copy(source, tmp / pattern)
    if mutate_receipts is not None:
        rows = auditor.load(tmp / f'{route}-receipts.jsonl')
        rows = mutate_receipts(rows) or rows
        write_rows(tmp / f'{route}-receipts.jsonl', rows)
    if mutate_days is not None:
        rows = auditor.load(tmp / f'{route}-days.jsonl')
        rows = mutate_days(rows) or rows
        write_rows(tmp / f'{route}-days.jsonl', rows)
    return tmp


def run_audit(directory):
    audit = auditor.Audit(directory)
    audit.check = audit.check  # keep counting
    routes = [p.stem.split('-receipts')[0] for p in directory.glob('*-receipts.jsonl')]
    for name in sorted(set(routes)):
        audit.audit_topology(name)
        audit.audit_survival(name)
        audit.audit_claims(name)
        audit.audit_water_services(name)
        audit.audit_feeding(name)
        audit.audit_yield(name)
        audit.audit_contributions(name)
    return audit


class TamperProbes(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.honest = auditor.Audit(BASE).run()
        if not (BASE / 'water-boundary-receipts.jsonl').exists():
            raise unittest.SkipTest('playtest evidence missing; run the replay first')

    def test_honest_ledger_passes(self):
        self.assertEqual(self.honest.failures, [])

    def test_double_fence_rejected(self):
        def mutate(rows):
            rows.append({'kind': 'water', 'stage': 'fence', 'body': 9, 'cells': ['2,14'],
                         'grants': {'2,14': 10000}, 'quality_after': 10000})
        audit = run_audit(forged_route('water-boundary', mutate))
        self.assertTrue(any('double-fenced' in f for f in audit.failures))

    def test_quality_over_cap_rejected(self):
        def mutate_days(rows):
            if rows:
                rows[-1]['bodies'][0]['quality'] = 10 ** 9
        audit = run_audit(forged_route('water-boundary', mutate_days=mutate_days))
        self.assertTrue(any('area cap' in f for f in audit.failures))

    def test_death_without_streak_rejected(self):
        days = auditor.load(BASE / 'survival-capacity-days.jsonl')
        def mutate(rows):
            rows.append({'kind': 'ranch:animal', 'stage': 'death', 'animal': 99,
                         'day': int(days[-1]['day']) if days else 0,
                         'reason': '连续缺维持', 'miss_streak': 1, 'bad_water_streak': 0})
        audit = run_audit(forged_route('survival-capacity', mutate))
        self.assertTrue(any('three-day streak' in f for f in audit.failures))

    def test_duplicate_roster_uid_rejected(self):
        def mutate_days(rows):
            for day in rows:
                if day['animals']:
                    day['animals'] = day['animals'] * 2
                    break
        audit = run_audit(forged_route('survival-capacity', mutate_days=mutate_days))
        self.assertTrue(any('duplicate roster uid' in f for f in audit.failures))

    def test_capture_outside_payers_rejected(self):
        def mutate(rows):
            for row in rows:
                if row.get('kind') == 'ranch:natural' and row.get('stage') == 'claim':
                    row['captures'] = [999999]
                    return
            rows.append({'kind': 'ranch:natural', 'stage': 'claim', 'animals': [1],
                         'captures': [999999], 'outputs': {}})
        audit = run_audit(forged_route('capture-oil', mutate))
        self.assertTrue(any('capture not among payers' in f for f in audit.failures))

    def test_change_conservation_rejected(self):
        def mutate(rows):
            for row in rows:
                if row.get('kind') == 'water' and row.get('stage') == 'change':
                    row['applied'] = int(row['gain']) + 5
                    return
            rows.append({'kind': 'water', 'stage': 'change', 'body': 1, 'applied': 9,
                         'gain': 8, 'wasted': 0, 'inputs': {'clean_water': 2}})
        audit = run_audit(forged_route('water-boundary', mutate))
        self.assertTrue(any('applied+wasted != gain' in f for f in audit.failures))

    def test_purify_over_capacity_rejected(self):
        def mutate(rows):
            rows.append({'kind': 'water', 'stage': 'loach_purify', 'body': 1, 'cells': 9,
                         'applied': 7200, 'quality_after': 99999, 'workyard': 1, 'batch': 1})
        audit = run_audit(forged_route('loach-coral', mutate))
        self.assertTrue(any('over eight cells' in f for f in audit.failures))

    def test_water_discount_rejected(self):
        def mutate(rows):
            rows.append({'kind': 'ranch:feed', 'stage': 'saving', 'animal': 1, 't': 1,
                         'saved': {'clean_water': 1}, 'source': {}})
        audit = run_audit(forged_route('systems-gu', mutate))
        self.assertTrue(any('drinking water' in f for f in audit.failures))

    def test_saving_remainder_overflow_rejected(self):
        def mutate_days(rows):
            for day in rows:
                for animal in day['animals']:
                    animal['saving'] = {'algae_feed': 150}
                    return
        audit = run_audit(forged_route('systems-gu', mutate_days=mutate_days))
        self.assertTrue(any('remainder out of range' in f for f in audit.failures))

    def test_second_voucher_rejected(self):
        def mutate(rows):
            vouchers = [r for r in rows if r.get('kind') == 'ranch:contribution' and r.get('stage') == 'voucher']
            if vouchers:
                clone = copy.deepcopy(vouchers[0])
                clone['credit'] = 999
                rows.append(clone)
            else:
                rows.append({'kind': 'ranch:contribution', 'stage': 'voucher', 'animal': 1,
                             'round': 7, 'credit': 120, 'eligible': 2400, 'growth_target': 2400, 'target': 1200})
                rows.append({'kind': 'ranch:contribution', 'stage': 'voucher', 'animal': 1,
                             'round': 8, 'credit': 120, 'eligible': 2400, 'growth_target': 2400, 'target': 1200})
        audit = run_audit(forged_route('systems-gu', mutate))
        self.assertTrue(any('second voucher' in f for f in audit.failures))


if __name__ == '__main__':
    unittest.main()
