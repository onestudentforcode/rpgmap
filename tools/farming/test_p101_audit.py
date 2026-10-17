"""Corruption probes for the P10.1 agriculture books.

Every probe corrupts a copy of the real assembled route books in a temporary
directory and asserts the strict auditor rejects it. Requires a completed
agriculture120 run under .art-work/p101-tests (see test_p101.ps1).
"""
import copy
import json
import shutil
import tempfile
import unittest
from pathlib import Path

from audit_p101_playtest import audit

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'.art-work/p101-tests/agriculture120'

def load(route,name):
    return [json.loads(s) for s in (SOURCE/f'{route}-{name}.jsonl').read_text(encoding='utf-8-sig').splitlines() if s]

def write(path,rows):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text('\n'.join(json.dumps(r,ensure_ascii=False) for r in rows)+'\n',encoding='utf-8')

class AgricultureTamper(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not SOURCE.exists():
            raise unittest.SkipTest('agriculture120 books absent; run test-p10-1.bat for the full phase suite')

    def probe(self, name, corrupt):
        with tempfile.TemporaryDirectory() as tmp:
            work=Path(tmp)
            for path in SOURCE.iterdir():
                if path.is_file(): shutil.copyfile(path,work/path.name)
            corrupt(work)
            try:
                audit(work, True)
            except AssertionError:
                return
            raise AssertionError(f'corruption {name} was accepted')

    def test_remainder_reset_washes_savings(self):
        def corrupt(work):
            rows=load('A','agri')
            for row in rows:
                row['agriculture']['remainders']['fertility']={}
            write(work/'A-agri.jsonl',rows)
        self.probe('remainder-reset',corrupt)

    def test_invented_remainder_outside_any_zone(self):
        def corrupt(work):
            rows=load('A','agri')
            rows[40]['agriculture']['remainders']['fertility']['0,0']=42
            write(work/'A-agri.jsonl',rows)
        self.probe('invented-remainder',corrupt)

    def test_extra_pending_facing(self):
        def corrupt(work):
            rows=load('A','agri')
            for uid in rows[60]['agriculture']['facings']:
                rows[60]['agriculture']['facings'][uid]['next']='west'
            write(work/'A-agri.jsonl',rows)
        self.probe('double-turn',corrupt)

    def test_fee_shifted_into_prior_day(self):
        def corrupt(work):
            rows=load('A','days')
            for row in rows:
                if row['day']==50:
                    row['opening_cash']['purchase_spend']=int(row['opening_cash']['purchase_spend'])+1
                    break
            write(work/'A-days.jsonl',rows)
        self.probe('fee-shift',corrupt)

    def test_fabricated_saving_income(self):
        def corrupt(work):
            rows=load('A','days')
            for row in rows:
                if row['day']==30:
                    row['ledger']['inflows'].setdefault('clean_water',{})['节水利得']=5
                    break
            write(work/'A-days.jsonl',rows)
        self.probe('fake-income',corrupt)

    def test_duplicate_maintenance_receipt(self):
        def corrupt(work):
            rows=load('A','receipts')
            for row in rows:
                if row.get('kind')=='logistics' and row.get('stage')=='maintenance':
                    clone=copy.deepcopy(row)
                    rows.append(clone)
                    break
            write(work/'A-receipts.jsonl',rows)
        self.probe('duplicate-maintenance',corrupt)

    def test_environment_delta_inflated(self):
        def corrupt(work):
            rows=load('A','agri')
            # A mid-run drain edit breaks the reconstructed deduction exactly.
            rows[100]['modules']['M3']['3,11']['fertility']=max(0,int(rows[100]['modules']['M3']['3,11']['fertility'])-4)
            write(work/'A-agri.jsonl',rows)
        self.probe('env-drained',corrupt)

    def test_agri_summary_inflated(self):
        def corrupt(work):
            path=work/'A-agri-summary.json'
            data=json.loads(path.read_text(encoding='utf-8'))
            data['module_harvests']=data['module_harvests']+5
            path.write_text(json.dumps(data,ensure_ascii=False),encoding='utf-8')
        self.probe('summary-inflated',corrupt)

if __name__=='__main__':
    unittest.main()
