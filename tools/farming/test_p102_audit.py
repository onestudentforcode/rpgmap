"""Room audit unit boundaries and corruption probes on copied real evidence."""
import argparse
import copy
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from audit_p8_playtest import balance, reconcile
from audit_p102_playtest import audit, lines


class AuthorizationBoundary(unittest.TestCase):
    def test_live_prefix_trims_partial_utf8_but_terminal_book_is_strict(self):
        with tempfile.TemporaryDirectory() as temporary:
            path=Path(temporary)/'book.jsonl'
            path.write_bytes(b'{"day":1}\n'+ '{"name":"种'.encode('utf-8')[:-1])
            self.assertEqual(lines(path,True),[{'day':1}])
            with self.assertRaises(UnicodeDecodeError): lines(path)

    def ledger(self):
        return dict(day=0,opening={},inflows={'grain':{'丰产奖励':1}},outflows={},closing={'grain':1})

    def test_reward_reason_alone_is_not_authorization(self):
        with self.assertRaises(AssertionError): balance(self.ledger())

    def test_unauthenticated_extra_quantity_rejected(self):
        with self.assertRaises(AssertionError): balance(self.ledger(),{})
        with self.assertRaises(AssertionError): balance(self.ledger(),{'inflows':{'丰产奖励':{'grain':2}}})

    def test_missing_credited_reward_rejected(self):
        empty=dict(day=0,opening={},inflows={},outflows={},closing={})
        with self.assertRaises(AssertionError): balance(empty,{'inflows':{'育种奖励':{'golden_wheat_seed':1}}})

    def test_exact_independent_proof_authorizes_flow(self):
        self.assertEqual(dict(balance(self.ledger(),{'inflows':{'丰产奖励':{'grain':1}}})),{'grain':1})


def write_lines(path,rows): path.write_text(''.join(json.dumps(r,ensure_ascii=False)+'\n' for r in rows),encoding='utf-8')

def probes(directory):
    baseline=reconcile(directory)
    results={}
    names=('duplicate_plant','duplicate_growth','unpaid_source','forged_coverage','contribution_overflow',
           'seed_reroll','byproduct_bonus','extra_seed','duplicate_claim','wrong_round','extra_ledger',
           'missing_ledger','free_floor','seed_replacement','future_fee','progress_overflow')
    probe_root=directory.parent/'room-negative'
    probe_root.mkdir(parents=True,exist_ok=True)
    for name in names:
        with tempfile.TemporaryDirectory(prefix=name+'-',dir=probe_root) as temporary:
            folder=Path(temporary)
            for path in directory.iterdir():
                if path.is_file(): shutil.copy2(path,folder/path.name)
            rows=lines(folder/'A-rooms.jsonl');receipts=lines(folder/'A-receipts.jsonl');days=lines(folder/'A-days.jsonl')
            growth=next(r for r in rows if r['stage']=='growth' and r['material_qualified'])
            claim=next(r for r in rows if r['stage']=='claim' and r['seed'])
            if name=='duplicate_plant':
                plant=next(r for r in rows if r['stage']=='plant');rows.insert(rows.index(plant)+1,copy.deepcopy(plant))
            elif name=='duplicate_growth': rows.insert(rows.index(growth)+1,copy.deepcopy(growth))
            elif name=='unpaid_source':
                paid=next(r for r in receipts if r['kind']=='logistics' and r['stage']=='maintenance' and r['day']==growth['day'])
                receipts.remove(paid)
            elif name=='forged_coverage':
                context=next(r for r in rows if r['stage']=='context' and r['day']==growth['day'])
                context['farmland'].append([27,0])
            elif name=='contribution_overflow': growth['state']['material_work']+=1
            elif name=='seed_reroll':
                matured=next(r for r in rows if r['stage']=='growth' and r['state']['frozen'])
                matured['state']['seed_award']=1-int(matured['state']['seed_award'])
            elif name=='byproduct_bonus': claim['material']['straw']=1
            elif name=='extra_seed': claim['seed'][next(iter(claim['seed']))]+=1
            elif name=='duplicate_claim': rows.insert(rows.index(claim)+1,copy.deepcopy(claim))
            elif name=='wrong_round': claim['round']+=1
            elif name in ('extra_ledger','missing_ledger'):
                ledger=next(r['ledger'] for r in days if any('育种奖励' in reasons for reasons in r['ledger']['inflows'].values()))
                reasons=next(v for v in ledger['inflows'].values() if '育种奖励' in v)
                if name=='extra_ledger': reasons['育种奖励']+=1
                else: reasons.pop('育种奖励')
            elif name=='free_floor': next(r for r in rows if r['stage']=='floor')['inputs']={}
            elif name=='seed_replacement': next(r for r in rows if r['stage']=='day')['rooms']['random_seed']+=1
            elif name=='future_fee': days[-1]['opening_cash']['purchase_spend']+=1
            elif name=='progress_overflow': growth['delta']+=1
            write_lines(folder/'A-rooms.jsonl',rows);write_lines(folder/'A-receipts.jsonl',receipts);write_lines(folder/'A-days.jsonl',days)
            try: reconcile(folder)
            except AssertionError as error: results[name]=str(error)
            else: raise AssertionError('corruption accepted: '+name)
    report={'baseline_room_stats':baseline['rooms'],
            'baseline_evidence_sha256':baseline['evidence_sha256'],
            'rejected':results,'count':len(results)}
    (probe_root/'results.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('P102 AUDIT TAMPER OK:',len(results),'copied-evidence probes rejected')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--evidence',type=Path)
    args=parser.parse_args()
    if args.evidence: probes(args.evidence)
    else: unittest.main(argv=[__file__])
