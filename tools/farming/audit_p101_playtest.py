"""Strictly reconcile the P10.1 agriculture route books.

Builds on the P10 audit (all seven gu templates maintained, dated fees, rice
chain) and adds agriculture-only branches: remainder conservation per module
cell against real environment deltas, module attribution of savings, the
committed facing turning exactly once, and a rejection of invented water or
fertility income.
"""
import argparse
import json
from pathlib import Path

from audit_p10_playtest import audit as p10_audit, lines

ROOT=Path(__file__).resolve().parents[2]
# Static module map mirrors run_p101_playtest.gd; the audit fails loudly if
# the books disagree with it.
MODULES={
 'M1': {'gu':'growth_gu','water':100,'fertility':100},
 'M2': {'gu':'water_gu','water':50,'fertility':100},
 'M3': {'gu':'fert_gu','water':100,'fertility':50},
 'M4': {'gu':'growth_gu','water':100,'fertility':100},
 'M4T':{'gu':None,'water':100,'fertility':100},
}
USE={'golden_wheat':{'water':4,'fertility':2},'fast_fir':{'water':3,'fertility':1},'pasture_grass':{'water':3,'fertility':1}}

def audit(directory, complete=True):
    result=p10_audit(directory, complete)
    agriculture={}
    for route in result:
        agri=lines(directory/f'{route}-agri.jsonl')
        actions=lines(directory/f'{route}-actions.jsonl')
        assert agri and agri[0]['day']<=1,'agriculture book must start at the first settled day'
        by_day={row['day']:row for row in agri}
        paid_by_day={}
        for row in lines(directory/f'{route}-logistics.jsonl'):
            paid_by_day[row['day']]={i['definition_id'] for i in row['logistics']['instances'] if i['paid_day']==row['day']}
        manual={}
        for a in actions:
            label=a['action']
            if not a['result'].get('ok'): continue
            module=None; field=None
            if label.startswith('module irrigate '): module=label.rsplit(' ',1)[1]; field='water'
            elif label.startswith('module fertilize '): module=label.rsplit(' ',1)[1]; field='fertility'
            elif label.startswith('module fir irrigate'): module='M3'; field='water'
            elif label.startswith('module fir fertilize'): module='M3'; field='fertility'
            if module: manual[(a['day'],module,field)]=manual.get((a['day'],module,field),0)+1
        # 1) Remainder conservation per module cell.
        checked_points=0
        for row in agri[:-1]:
            day=row['day']; nxt=by_day[day+1]
            for module,cells in row['modules'].items():
                spec=MODULES[module]
                for key,cell in cells.items():
                    crop=cell['crop']
                    if crop not in USE: continue
                    for field,use in (('water',USE[crop]['water']),('fertility',USE[crop]['fertility'])):
                        if (day,module,field) in manual: continue
                        prev=int(cell[field]); now=int(nxt['modules'][module][key][field])
                        if now>=prev or prev==0: continue  # clamped or impossible delta
                        deduct=prev-now
                        retention=spec[field] if spec[field]<100 and spec['gu'] in paid_by_day.get(day,()) else 100
                        rem_prev=int(row['agriculture']['remainders'][field].get(key,0))
                        rem_now=int(nxt['agriculture']['remainders'][field].get(key,0))
                        accumulated=rem_prev+use*retention
                        assert deduct==accumulated//100 and rem_now==accumulated%100, \
                            ('remainder conservation broken',route,day,module,key,field,deduct,rem_prev,use,retention,rem_now)
                        checked_points+=1
        assert checked_points>200,('conservation coverage too thin',route,checked_points)
        # 2) Remainder keys may only exist on module cells, and the
        # unassisted turned plot never carries one.
        valid_keys=set()
        for row in agri:
            for module,cells in row['modules'].items():
                for key in cells: valid_keys.add(key)
        for row in agri:
            for field in ('water','fertility'):
                for key in row['agriculture']['remainders'][field]:
                    assert key in valid_keys,('remainder outside every module cell',route,row['day'],key)
                    assert key not in row['modules']['M4T'],('uncovered plot claims a remainder',route,row['day'],key)
        # 3) Exactly one committed turn: one facing receipt, one active flip
        # that never reverts (daily lines are written after the opening
        # promotion, so the pending state itself is never visible in them).
        facing_receipts=[r for r in lines(directory/f'{route}-receipts.jsonl')
                         if r.get('kind')=='agriculture' and r.get('stage')=='facing']
        assert len(facing_receipts)==1,('rotation must be receipted exactly once',route,len(facing_receipts))
        flips={}
        for row in agri:
            for uid,f in row['agriculture']['facings'].items():
                prev=flips.get(uid,f['active'])
                if f['active']!=prev:
                    raise AssertionError(('facing flip mid-run',route,row['day'],uid,prev,f['active']))
                flips[uid]=f['active']
        turned=[uid for uid,f in flips.items() if f=='south']
        assert len(turned)==1,('exactly one turned host expected',route,flips)
        for row in agri:
            for uid,f in row['agriculture']['facings'].items():
                assert f['next']==f['active'],('pending facing survives an opening',route,row['day'],uid,f)
        # 4) No invented water or fertilizer income anywhere in the ledgers.
        for row in lines(directory/f'{route}-days.jsonl'):
            for item in ('clean_water','humus'):
                for reason in row['ledger'].get('inflows',{}).get(item,{}):
                    assert '节' not in reason and 'saving' not in reason,('fabricated saving income',route,row['day'],item,reason)
        stats=json.loads((directory/f'{route}-agri-summary.json').read_text(encoding='utf-8'))
        assert stats['module_harvests']>0 and stats['fir_units']>0 and stats['irrigations']>0 and stats['fertilizations']>0,('agriculture summary incomplete',route)
        def count_ok(prefix):
            return sum(1 for a in actions if a['action'].startswith(prefix) and a['result'].get('ok'))
        assert stats['module_harvests']==count_ok('module harvest')+count_ok('module fir fell'),('harvest count diverges from receipts',route)
        assert stats['irrigations']==count_ok('module irrigate')+count_ok('module fir irrigate'),('irrigation count diverges from receipts',route)
        assert stats['fertilizations']==count_ok('module fertilize')+count_ok('module fir fertilize'),('fertilization count diverges from receipts',route)
        assert stats['rotations']==len(facing_receipts),('rotation count diverges from receipts',route)
        agriculture[route]={'conservation_points':checked_points,'stats':stats}
    for route in result:
        result[route]['agriculture']=agriculture[route]
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory',type=Path)
    parser.add_argument('--allow-single',action='store_true')
    args=parser.parse_args()
    result=audit(args.directory,not args.allow_single)
    (args.directory/'agriculture-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('P101 PLAYTEST AUDIT OK:',json.dumps({r:{'agriculture':v['agriculture'],'maintenance':v['maintenance'],'rice_claimed':v['rice_claimed']} for r,v in result.items()},ensure_ascii=False))
