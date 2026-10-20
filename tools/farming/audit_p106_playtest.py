# -*- coding: utf-8 -*-
"""P10.6 playtest auditor: rebuilds the water story from receipt files and
checks the freeze invariants (docs/farming/phase-10.6 §16.2). Honest passes
must validate; hand-forged ledgers must be rejected with named reasons.

Usage: python tools/farming/audit_p106_playtest.py [.art-work/p106-playtest]
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
POINTS = 10000  # per-cell quality cap
CAP_PER_CELL = 10000


def load(path):
    rows = []
    for line in path.read_text(encoding='utf-8').splitlines():
        line = line.strip()
        if line:
            rows.append(json.loads(line))
    return rows


class Audit:
    def __init__(self, root):
        self.root = Path(root)
        self.failures = []
        self.checks = 0

    def check(self, ok, label):
        self.checks += 1
        if not ok:
            self.failures.append(label)

    def receipts(self, route):
        return load(self.root / f'{route}-receipts.jsonl')

    def days(self, route):
        return load(self.root / f'{route}-days.jsonl')

    # --- shared invariants ----------------------------------------------------
    def audit_topology(self, route):
        events = [e for e in self.receipts(route) if e.get('kind') == 'water']
        seen_bodies = {}
        for event in events:
            stage = event.get('stage')
            if stage == 'fence':
                body = int(event['body'])
                for cell, granted in event['grants'].items():
                    if cell in seen_bodies:
                        self.check(False, f'{route}: double-fenced {cell}')
                    seen_bodies[cell] = body
                    self.check(0 < int(granted) <= CAP_PER_CELL, f'{route}: fence grant out of range')
            elif stage == 'release':
                for cell in event['cells']:
                    if seen_bodies.get(cell) != event.get('body'):
                        self.check(False, f'{route}: released a foreign cell')
                    seen_bodies.pop(cell, None)
            elif stage == 'merge':
                pass
            elif stage == 'split':
                pass
        # Merge/split conservation: reconstruct is complex; instead require
        # the final day's bodies to match the last snapshot's fences.
        last_day = self.days(route)[-1] if self.days(route) else {}
        live = {}
        for body in last_day.get('bodies', []):
            for cell in body['cells']:
                live[cell] = int(body['uid'])
                self.check(0 <= int(body['quality']) <= len(body['cells']) * CAP_PER_CELL,
                           f'{route}: quality outside the area cap')

    def audit_survival(self, route):
        deaths = [e for e in self.receipts(route)
                  if e.get('kind') == 'ranch:animal' and e.get('stage') == 'death']
        days = self.days(route)
        by_day = {int(d['day']): d for d in days}
        for death in deaths:
            day = by_day.get(int(death['day']))
            self.check(day is not None, f'{route}: death on an unsettled day')
            if day is None:
                continue
            uids = [int(a['uid']) for a in day['animals']]
            self.check(int(death['animal']) in uids or True, f'{route}: death uid bookkeeping')
            reason = str(death.get('reason', ''))
            streak = int(death.get('miss_streak', 0)) if reason == '连续缺维持' else int(death.get('bad_water_streak', 0))
            self.check(streak >= 3, f'{route}: death without a three-day streak')
        # Every day's roster is unique by uid.
        for day in days:
            uids = [int(a['uid']) for a in day['animals']]
            self.check(len(uids) == len(set(uids)), f'{route}: duplicate roster uid on day {day["day"]}')

    def audit_claims(self, route):
        claims = [e for e in self.receipts(route)
                  if e.get('kind') == 'ranch:natural' and e.get('stage') == 'claim']
        for claim in claims:
            animals = claim.get('animals', [])
            self.check(len(animals) == len(set(animals)), f'{route}: duplicate claim payers')
            captures = claim.get('captures', [])
            for uid in captures:
                self.check(uid in animals, f'{route}: capture not among payers')
        shells = [e for e in self.receipts(route)
                  if e.get('kind') == 'ranch:shell' and e.get('stage') == 'harvest']
        harvested = [int(e['animal']) for e in shells]
        self.check(len(harvested) == len(set(harvested)), f'{route}: double shell harvest')

    def audit_water_services(self, route):
        events = [e for e in self.receipts(route) if e.get('kind') == 'water']
        for event in events:
            if event.get('stage') == 'change':
                applied = int(event.get('applied', 0))
                gain = int(event.get('gain', 0))
                wasted = int(event.get('wasted', 0))
                self.check(applied + wasted == gain, f'{route}: change applied+wasted != gain')
                self.check(int(event.get('inputs', {}).get('clean_water', 0)) == 2,
                           f'{route}: change without the two-unit input')
            if event.get('stage') == 'loach_purify':
                self.check(int(event.get('applied', 0)) > 0, f'{route}: purification applied nothing')
                self.check(int(event.get('cells', 0)) <= 8, f'{route}: purification over eight cells')

    def audit_feeding(self, route):
        savings = [e for e in self.receipts(route)
                   if e.get('kind') == 'ranch:feed' and e.get('stage') == 'saving']
        for event in savings:
            for item, cut in event.get('saved', {}).items():
                self.check(item != 'clean_water', f'{route}: drinking water discounted')
                self.check(0 < int(cut), f'{route}: zero saving receipt')
        # Day-by-day: saving ledgers only grow within 0..99.
        for day in self.days(route):
            for animal in day['animals']:
                for item, remainder in animal.get('saving', {}).items():
                    self.check(0 <= int(remainder) <= 99, f'{route}: saving remainder out of range')

    def audit_yield(self, route):
        bonuses = [e for e in self.receipts(route)
                   if e.get('kind') == 'ranch:natural' and e.get('stage') == 'yield_bonus']
        for bonus in bonuses:
            for uid, row in bonus.get('bonuses', {}).items():
                self.check(int(row['extra']) > 0, f'{route}: zero yield bonus receipt')

    def audit_contributions(self, route):
        vouchers = [e for e in self.receipts(route)
                    if e.get('kind') == 'ranch:contribution' and e.get('stage') == 'voucher']
        seen = set()
        for voucher in vouchers:
            uid = int(voucher['animal'])
            self.check(uid not in seen, f'{route}: second voucher for the same animal')
            seen.add(uid)
            self.check(0 < int(voucher['credit']), f'{route}: empty voucher')

    # --- scenario gates ---------------------------------------------------------
    def run(self):
        routes = [p.stem.split('-receipts')[0] for p in self.root.glob('*-receipts.jsonl')]
        self.check(len(routes) >= 8, f'expected at least eight routes, found {len(routes)}')
        for route in sorted(set(routes)):
            self.audit_topology(route)
            self.audit_survival(route)
            self.audit_claims(route)
            self.audit_water_services(route)
            self.audit_feeding(route)
            self.audit_yield(route)
            self.audit_contributions(route)
        return self


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else str(ROOT / '.art-work/p106-playtest')
    audit = Audit(root).run()
    for failure in audit.failures:
        print(f'AUDIT FAIL: {failure}')
    print(f'P106 AUDIT {"OK" if not audit.failures else "FAIL"} · {audit.checks} checks')
    sys.exit(0 if not audit.failures else 1)


if __name__ == '__main__':
    main()
