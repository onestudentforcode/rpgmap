"""Reject corrupted copies of real P10 books without changing the baseline."""
import argparse
import copy
import json
from pathlib import Path
import shutil
import tempfile

from audit_p10_playtest import audit, lines


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


def write_lines(path, rows):
    path.write_text(''.join(json.dumps(row, ensure_ascii=False)+'\n' for row in rows), encoding='utf-8')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory',type=Path)
    parser.add_argument('--probe-root',type=Path,default=Path('.art-work/p10-tests/logistics-negative'))
    args=parser.parse_args()
    audit(args.directory)
    args.probe_root.mkdir(parents=True,exist_ok=True)
    results={}
    for name in ('duplicate_maintenance','fee_drift','missing_food','unpaid_work',
                 'duplicate_work','premature_claim','duplicate_claim','extra_rice',
                 'food_outflow','opening_fee_date','summary_rice','source_drift'):
        with tempfile.TemporaryDirectory(prefix='probe-',dir=args.probe_root) as temporary:
            folder=Path(temporary)
            for file in args.directory.iterdir():
                if file.is_file(): shutil.copy2(file,folder/file.name)
            receipts=lines(folder/'A-receipts.jsonl')
            days=lines(folder/'A-days.jsonl')
            gu=[r for r in receipts if r['kind']=='logistics']
            maintenance=next(r for r in gu if r['stage']=='maintenance')
            work=next(r for r in gu if r['stage']=='progress')
            claim=next(r for r in gu if r['stage']=='claim')
            if name=='duplicate_maintenance': receipts.append(copy.deepcopy(maintenance))
            elif name=='fee_drift': maintenance['fee']+=1
            elif name=='missing_food': next(r for r in gu if r['stage']=='maintenance' and r['inputs'])['inputs']={}
            elif name=='unpaid_work':
                receipts=[r for r in receipts if not (r['kind']=='logistics' and r['stage']=='maintenance' and r['day']==work['day'] and r['instance_id']==work['instance_id'])]
            elif name=='duplicate_work': receipts.insert(receipts.index(work)+1,copy.deepcopy(work))
            elif name=='premature_claim':
                prior=next(r for r in reversed(receipts[:receipts.index(claim)]) if r['kind']=='logistics' and r['stage']=='progress' and r['instance_id']==claim['instance_id'])
                prior['progress']-=1
                prior['ready']=False
            elif name=='duplicate_claim': receipts.insert(receipts.index(claim)+1,copy.deepcopy(claim))
            elif name=='extra_rice':
                next(row['ledger']['inflows']['rice'] for row in days if 'rice' in row['ledger']['inflows'])['后勤蛊产物收取']+=1
            elif name=='food_outflow':
                next(row['ledger']['outflows']['time_feed'] for row in days if 'time_feed' in row['ledger']['outflows'])['后勤蛊特殊食料']+=1
            elif name=='opening_fee_date':
                next(row for row in days if row['opening_cash']['purchase_spend'])['opening_cash']['purchase_spend']+=1
            elif name=='summary_rice':
                stats=json.loads((folder/'A-logistics-summary.json').read_text(encoding='utf-8'))
                stats['rice']+=1
                write(folder/'A-logistics-summary.json',stats)
            elif name=='source_drift':
                manifest=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
                manifest['scripts/farming/p8/p10_logistics.gd']='0'*64
                write(folder/'manifest.json',manifest)
            write_lines(folder/'A-receipts.jsonl',receipts)
            write_lines(folder/'A-days.jsonl',days)
            try: audit(folder)
            except (AssertionError,KeyError,ValueError,StopIteration) as exc:
                results[name]={'rejected':True,'reason':str(exc)}
            else: raise SystemExit('P10 AUDIT NEGATIVE PROBE FAIL: '+name)
    write(args.probe_root/'expected-rejections.json',results)
    print('P10 AUDIT NEGATIVE PROBES OK:',len(results),'corruptions rejected')


if __name__=='__main__': main()
