"""Independently reconcile paid gu days, food, claims and downstream rice use.

The inherited strict P8 audit still checks every ordinary production route.
This additional audit closes the logistics-only branch without allowing a
no-gu control route to pretend it produced rice.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
def lines(path): return [json.loads(s) for s in path.read_text(encoding='utf-8-sig').splitlines() if s]
def audit(directory, complete=True):
    summary=json.loads((directory/'summary.json').read_text(encoding='utf-8'))
    assert not summary['failures'],summary['failures']
    manifest=json.loads((directory/'manifest.json').read_text(encoding='utf-8'))
    for name,digest in manifest.items():
        assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,('source changed',name)
    routes=summary['routes']
    if complete: assert set(routes)=={'A','B'},'two independent routes required'
    source=json.loads((ROOT/'content/farming/p8/production.json').read_text(encoding='utf-8'))
    defs={r['id']:r for r in source['logistics']['definitions']}
    result={}
    for route in routes:
        receipts=lines(directory/f'{route}-receipts.jsonl')
        gu_days=lines(directory/f'{route}-logistics.jsonl')
        days=lines(directory/f'{route}-days.jsonl')
        actions=lines(directory/f'{route}-actions.jsonl')
        by_day={r['day']:r for r in days}
        served=set(); fees=Counter(); foods={}; rice=Counter(); progress={}; seen_templates=set()
        progressed=set(); claim_count=0
        for r in receipts:
            if r['kind']!='logistics': continue
            key=(r['day'],r['instance_id'])
            definition=defs[source['logistics']['provision'][int(r['instance_id'].removeprefix('trial-'))-1]]
            if r['stage']=='maintenance':
                assert key not in served,'duplicate maintenance'
                served.add(key)
                seen_templates.add(definition['id'])
                assert r['fee']==definition['fee'] and r['inputs']==definition['food'],'maintenance cost drift'
                fees[r['day']]+=r['fee']
                foods.setdefault(r['day'],Counter()).update(r['inputs'])
            elif r['stage']=='progress':
                assert key in served,'work without maintenance'
                assert key not in progressed,'duplicate daily production work'
                progressed.add(key)
                assert 0<r['progress']<=definition['production']['days']*100,'invalid work'
                assert r['progress']>progress.get(r['instance_id'],0),'production did not advance'
                assert r['ready']==(r['progress']==definition['production']['days']*100),'ready flag drift'
                progress[r['instance_id']]=r['progress']
            elif r['stage']=='claim':
                assert progress.get(r['instance_id'])==definition['production']['days']*100,'claim without finished work'
                assert r['outputs']==definition['production']['outputs'],'claim output drift'
                progress.pop(r['instance_id'])
                rice[r['day']]+=r['outputs']['rice']
                claim_count+=1
            else: raise AssertionError('unknown logistics receipt stage')
        assert seen_templates==set(defs),'not all five gu actually maintained'
        total=0
        for row in gu_days:
            day=row['day']; total+=fees[day]
            gu=row['logistics']
            assert gu['active_day']==day and gu['spent']==sum(f for d,f in fees.items() if d<=day),'maintenance total mismatch'
            assert by_day[day]['opening_cash']['purchase_spend']==fees[day],'opening fee misdated or missing'
            for receipt in gu['history']:
                assert receipt['fees']==fees[receipt['day']]
                assert Counter(receipt['food'])==foods.get(receipt['day'],Counter())
            closed=by_day[day]['ledger']
            # Inventory books retain a reason->quantity map, not flat totals.
            # Exact equality disallows both a missing claim and extra rice.
            claimed={item:reasons['后勤蛊产物收取'] for item,reasons in closed['inflows'].items() if '后勤蛊产物收取' in reasons}
            assert Counter(claimed)==Counter({'rice':rice[day-1]}),'rice claims missing from warehouse or duplicated'
            consumed={item:reasons['后勤蛊特殊食料'] for item,reasons in closed['outflows'].items() if '后勤蛊特殊食料' in reasons}
            assert Counter(consumed)==foods.get(day-1,Counter()),'special food warehouse outflow mismatch'
            # The current prototypes have no production material inputs.
            # Reject unreceipted material costs rather than silently accepting.
            assert not any('后勤蛊生产投料' in reasons for reasons in closed['outflows'].values()),'unexpected production material input'
        assert sum(rice.values())>0,'no real rice output'
        assert routes[route]['claimed'].get('mill_rice',0)>0,'rice never milled'
        assert any(a['action']=='sell rice surplus' and a['result'].get('ok') for a in actions),'rice never sold'
        stats=json.loads((directory/f'{route}-logistics-summary.json').read_text(encoding='utf-8'))
        assert stats['wisdom_projects']>0 and stats['time_projects']>0,'research gu never used'
        assert stats['claims']==claim_count and stats['rice']==sum(rice.values()),'gu output summary mismatch'
        assert stats['maintenance']==sum(fees.values()),'gu maintenance summary mismatch'
        horizon=summary['settings']['days']
        result[route]={'days':horizon,'maintenance':sum(v for d,v in fees.items() if d<=horizon),
            'closed_maintenance':sum(v for d,v in fees.items() if d<horizon),'current_opening_maintenance':fees[horizon],
            'rice_claimed':sum(v for d,v in rice.items() if d<summary['settings']['days']), 'cash':routes[route]['cash'], 'gu':stats}
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory',type=Path)
    parser.add_argument('--allow-single',action='store_true')
    args=parser.parse_args()
    result=audit(args.directory,not args.allow_single)
    (args.directory/'logistics-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('P10 PLAYTEST AUDIT OK:',json.dumps(result,ensure_ascii=False))
