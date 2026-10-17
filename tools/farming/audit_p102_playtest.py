"""Independent P10.2 room contribution/reward audit, with exact ledger proofs.

Replays plant identities and rounds; recomputes four-neighbor regions, paid
directed coverage, whole-footprint qualification, capped growth, fixed random
draws and stochastic rounding. Does not import the runtime or trust its flags.
--prefix checks a live short prefix only; it is never acceptance evidence.
"""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from fractions import Fraction
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
TAGS={'growth_speed':'plant_growth_speed','water_saving':'plant_water_saving','fertility_saving':'plant_fertility_saving'}
ROOM_IN={'育种奖励','丰产奖励'}
ROOM_OUT={'铺设材料'}
MODULE_CELLS={(x,y) for y in range(10,13) for x in range(9,12)}
MODULE_HOSTS={(8,11),(12,11),(10,9)}

def read_json(path): return json.loads(path.read_text(encoding='utf-8-sig'))

def lines(path, prefix=False):
    raw=path.read_bytes()
    # A live writer can stop between bytes of one Chinese character. Trim the
    # unfinished record before decoding; complete acceptance books stay strict.
    if prefix and raw and not raw.endswith(b'\n'): raw=raw[:raw.rfind(b'\n')+1]
    text=raw.decode('utf-8-sig')
    return [json.loads(line) for line in text.splitlines() if line]

def integer(n,low=0,high=2**53):
    return type(n) in (int,float) and n==int(n) and low<=n<=high

def draw(seed,identity,round_index,channel):
    return int(hashlib.sha256(f'{int(seed)}|{identity}|{int(round_index)}|{channel}'.encode()).hexdigest()[:8],16)%1_000_000

def award(base,qualified,total,roll):
    if total==0: return 0
    whole,remainder=divmod(int(base)*25*int(qualified),int(total)*100)
    return whole+int(roll*int(total)*100<remainder*1_000_000)

def cells(origin,shape):
    x,y=map(int,origin);w,h=map(int,shape)
    return {(a,b) for b in range(y,y+h) for a in range(x,x+w)}

def inside(cell,rect):
    x,y,w,h=rect
    return x<=cell[0]<x+w and y<=cell[1]<y+h

def zone(origin,facing):
    x,y=map(int,origin)
    dx,dy={'east':(1,-1),'south':(-1,1),'west':(-3,-1),'north':(-1,-3)}[facing]
    return cells((x+dx,y+dy),(3,3))

def fresh_round(target,index=0):
    return dict(round=index,target=target,growth=0,seed_work=0,material_work=0,frozen=False,
                seed_checked=False,seed_award=0,seed_claimed=False,seed_total=0,seed_eligible=0)

def coverage(context,source,paid):
    day=int(context['day']);fac={int(f['uid']):f for f in context['facilities']}
    defs={g['id']:g for g in source['logistics']['definitions']}
    source_rows={tag:[] for tag in TAGS.values()}
    assert context['agriculture']['legacy_until']==-1,'legacy geometry in new business route'
    seen=set()
    for instance in context['logistics']['instances']:
        ident=instance['instance_id']
        assert ident not in seen and ident.startswith('trial-'),'unknown or duplicate source identity'
        seen.add(ident)
        index=int(ident.removeprefix('trial-'))
        assert 1<=index<=len(source['logistics']['provision']) and ident==f'trial-{index:03d}'
        assert instance['definition_id']==source['logistics']['provision'][index-1],'source definition differs from its paid template'
        assert integer(instance['rank'],1,5),'invalid gu rank'
        definition=defs[instance['definition_id']]
        tag=TAGS.get(definition['effect'])
        if tag is None or not instance['enabled'] or instance['effective_day']>day or instance['paid_day']!=day: continue
        uid=int(instance['host_uid'])
        if not uid: continue
        assert (day,instance['instance_id']) in paid,'coverage without a paid service receipt'
        assert uid in fac and fac[uid]['facility_id']=='field_service_station','invalid agriculture host'
        facing=context['agriculture']['facings'][str(uid)]['active']
        source_rows[tag].append({'zone':zone(fac[uid]['origin'],facing),'rank':int(instance['rank']),
                                 'value':int(definition['value']),'id':instance['instance_id']})
    field={tuple(map(int,c)) for c in context['farmland']}
    occupied=set()
    facilities={f['id']:f for f in source['facilities']}
    for f in fac.values(): occupied|=cells(f['origin'],facilities[f['facility_id']]['footprint'])
    assert field=={tuple(map(int,c)) for c in context['tilled']}-occupied,'farmland differs from actual tilled occupancy'
    assert len(field)==len(context['farmland']),'duplicate field cells'
    pending=set(field);by_cell={}
    while pending:
        todo=[pending.pop()];component=set(todo)
        for x,y in todo:
            for c in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if c in pending: pending.remove(c);component.add(c);todo.append(c)
        covered={tag:all(any(c in g['zone'] for g in groups) for c in component) for tag,groups in source_rows.items()}
        for c in component: by_cell[c]=(component,covered)
    return source_rows,by_cell

def qualification(footprint,groups,by_cell,requirements):
    first=next(iter(footprint));region=by_cell.get(first)
    if not region or not footprint<=region[0]: return {'seed':False,'material':False}
    return {channel:all(region[1][tag] and any(footprint<=g['zone'] for g in groups[tag]) for tag in required)
            for channel,required in requirements.items()}

def audit_route(directory,route,source,horizon,mode,finished=True):
    rows=lines(directory/f'{route}-rooms.jsonl',not finished)
    receipts=lines(directory/f'{route}-receipts.jsonl',not finished)
    days=lines(directory/f'{route}-days.jsonl',not finished)
    assert rows and rows[0]['stage']=='initial','room book missing initial state'
    initial=rows[0]['snapshot'];seed=initial['world']['rooms']['random_seed']
    assert initial['schema']==20 and initial['clock']['total_days']==0
    assert initial['inventory']==source['config']['start_inventory'] and initial['economy']['primeval_stones']==source['config']['initial_primeval_stones'],'injected initial resources'
    assert not initial['world']['crops'] and not initial['world']['rooms']['floors']
    assert rows[0]['mode']==mode and integer(seed,1,2147483647)
    defs={c['id']:c for c in source['crops']}
    gu_defs={g['id']:g for g in source['logistics']['definitions']}
    paid={};fees=Counter();harvests={};lamps=set()
    for r in receipts:
        if r['kind']=='logistics' and r['stage']=='maintenance':
            key=(int(r['day']),r['instance_id'])
            assert key not in paid,'duplicate gu maintenance'
            template=source['logistics']['provision'][int(r['instance_id'].removeprefix('trial-'))-1]
            d=gu_defs[template]
            assert r['fee']==d['fee'] and r['inputs']==d['food'],'maintenance cost drift'
            paid[key]=r;fees[int(r['day'])]+=r['fee']
        if r['kind']=='harvest':
            key=(int(r['day']),int(r['uid']),r['stage'])
            assert key not in harvests,'duplicate ordinary harvest receipt'
            harvests[key]=r
        if r['kind']=='device' and r['stage']=='lamp': lamps.add((int(r['day']),int(r['uid'])))
    plants={};known=set();retired=set();contexts={};context_data={};used_growth=set();claims=set();clears=set();floors={}
    proofs=defaultdict(lambda:{'inflows':defaultdict(Counter),'outflows':defaultdict(Counter)})
    stats=Counter();bank=Counter();qualified=Counter();seen_days=[]
    seed_expectation=Fraction(0);material_expectation=Fraction(0)
    def proof(day,direction,reason,items):
        for item,n in items.items():
            assert integer(n,1),'invalid room quantity'
            proofs[int(day)][direction][reason][item]+=int(n)
    for r in rows[1:]:
        stage=r['stage']
        if stage=='context':
            day=int(r['day']);assert day not in contexts,'duplicate settlement context'
            assert r['floors']==floors,'floor mutation without a construction receipt'
            assert r['logistics']['active_day']==day and r['logistics']['spent']==sum(q for d,q in fees.items() if d<=day),'service context uses unrecorded fees or wrong day'
            contexts[day]=coverage(r,source,paid);context_data[day]=r
            continue
        if stage=='floor':
            c=tuple(map(int,r['cell']));key=f'{c[0]},{c[1]}'
            assert r['floor'] in ('ordinary','farmland','natural')
            expected=source['rooms']['floor']['inputs'] if r['floor']=='ordinary' else {}
            assert r['inputs']==expected,'unpaid or refunded floor'
            if r['floor']=='ordinary': floors[key]='ordinary'
            else: floors.pop(key,None)
            proof(r['day'],'outflows','铺设材料',expected);stats['floor_actions']+=1
            continue
        if stage=='day':
            state=r['rooms'];seen_days.append(int(r['day']))
            assert state['random_seed']==seed and state['floors']==floors and not state['gu_rounds'],'room seed or paving changed outside actions'
            assert r['logistics']['spent']==sum(q for d,q in fees.items() if d<=r['day']),'saved maintenance total differs from actual charges'
            assert {f'crop:{i}':v for i,v in state['plants'].items()}=={i:p['state'] for i,p in plants.items()},('saved plant rights differ from independent replay',r['day'])
            snapshot={f"crop:{int(c['uid'])}":c for c in r['crops']}
            assert snapshot.keys()==plants.keys(),'crop identity index differs from room rights'
            for ident,p in plants.items():
                c=snapshot[ident];s=p['state']
                assert c['crop_id']==p['crop']['crop_id'] and c['origin']==p['crop']['origin']
                assert c['harvest_count']==s['round'] and c['progress']==s['growth'] and (c['state']=='mature')==s['frozen'],'saved growth/round mismatch'
            continue
        ident=r['identity']
        if stage=='plant':
            c=r['crop'];d=defs[c['crop_id']]
            assert ident==f"crop:{int(c['uid'])}" and ident not in known,'duplicate planting identity'
            assert c['progress']==0 and c['harvest_count']==0 and r['target']==d['days']*100,'injected planting progress'
            known.add(ident);plants[ident]={'crop':c,'state':fresh_round(d['days']*100)}
            if tuple(c['origin']) in MODULE_CELLS: stats['module_plantings']+=1
            use=min(1,bank[d['seed']]);bank[d['seed']]-=use;stats['reused_seeds']+=use
            stats['plantings']+=1
            continue
        if stage=='clear':
            assert ident in known and ident not in clears,'duplicate or unknown clearing'
            clears.add(ident)
            if ident in plants: plants.pop(ident);retired.add(ident)
            else: assert ident in retired,'clear lost planting identity'
            continue
        assert ident in plants,('reward/progress without a live planting',ident,stage)
        p=plants[ident];s=p['state'];d=defs[p['crop']['crop_id']]
        if stage=='growth':
            day=int(r['day']);key=(day,ident,int(r['round']))
            assert key not in used_growth and day in contexts,'duplicate growth or missing context'
            used_growth.add(key)
            assert not s['frozen'] and r['round']==s['round']
            footprint=cells(p['crop']['origin'],d['footprint'])
            groups,by_cell=contexts[day]
            flags=qualification(footprint,groups,by_cell,source['rooms']['requirements'])
            assert flags=={k:r[k+'_qualified'] for k in ('seed','material')},('invented region or whole-footprint qualification',day,ident)
            env=r['environment'];assert {tuple(e['cell']) for e in env}==footprint and len(env)==len(footprint)
            for e in env:
                assert all(integer(e[k],0,100) for k in ('water','fertility','light')),'invalid environmental points'
                light=source['config']['light'];natural=next((a['level'] for a in light['regions'] if inside(e['cell'],a['rect'])),light['default'])
                expected_light=natural
                context=context_data[day];fac={int(f['uid']):f for f in context['facilities']}
                facility_defs={f['id']:f for f in source['facilities']}
                for uid in context['devices']['active_lamps']:
                    assert (day,int(uid)) in lamps,'light without actual fuel receipt'
                    f=fac[int(uid)];x,y=f['origin'];w,h=facility_defs[f['facility_id']]['footprint'];margin=source['devices']['lamp']['range']
                    if inside(e['cell'],(x-margin,y-margin,w+2*margin,h+2*margin)): expected_light=max(expected_light,source['devices']['lamp']['light'])
                assert e['light']==expected_light,'invented effective light'
            settings=source['config']['environment'];n=len(env)
            water=100 if sum(e['water'] for e in env)>=settings['optimal_water']*n else settings['low_water_efficiency']
            fertility=100 if sum(e['fertility'] for e in env)>=settings['optimal_fertility']*n else settings['low_fertility_efficiency']
            light=100 if abs(sum(e['light'] for e in env)-d['light']*n)<=settings['light_tolerance']*n else settings['low_light_efficiency']
            growth_sources=[g for g in groups['plant_growth_speed'] if footprint<=g['zone']]
            winner=sorted(growth_sources,key=lambda g:(-g['rank'],-g['value'],g['id']))
            speed=winner[0]['value'] if winner else 100
            delta=min(s['target']-s['growth'],max(1,water*fertility*light*speed//1_000_000))
            assert r['delta']==delta,('growth overflow or environmental rate mismatch',day,ident,r['delta'],delta)
            s['growth']+=delta
            for channel in ('seed','material'):
                if flags[channel]: s[channel+'_work']+=delta;qualified[channel]+=delta
            if s['growth']==s['target']:
                s['frozen']=True
                if not s['seed_checked']:
                    s.update(seed_checked=True,seed_total=s['growth'],seed_eligible=s['seed_work'])
                    s['seed_award']=award(1,s['seed_work'],s['growth'],draw(seed,ident,0,'seed'))
                    if s['seed_work']>0:
                        stats['eligible_first_maturities']+=1
                        seed_expectation+=Fraction(int(s['seed_work']),4*int(s['growth']))
            assert r['state']==s,('contribution/frozen rights differ from independent calculation',day,ident)
            assert r['crop']['progress']==s['growth'] and r['crop']['harvest_count']==s['round'],'growth receipt does not match actual crop'
            stats['growth_events']+=1
            continue
        assert stage=='claim','unknown room event'
        key=(ident,int(r['round']));assert key not in claims and s['frozen'] and r['round']==s['round'],'duplicate or immature reward claim'
        claims.add(key);assert r['definition']==p['crop']['crop_id']
        mode_name=r['mode'];base=r['base']
        if mode_name=='clear': assert not base
        else:
            receipt=harvests[(int(r['day']),int(p['crop']['uid']),mode_name)]
            expected=dict(d['fell_outputs'] if mode_name=='fell' and d['mode']=='tap_or_fell' else d['outputs'])
            if d['id']=='oilseed_flower': expected['oilseed']+=int(receipt['pollinated'])
            assert base==expected==receipt['outputs'],'base yield differs from normal harvest'
        expected_seed={d['seed']:1} if not s['seed_claimed'] and s['seed_award'] else {}
        primary=source['rooms']['primary'][d['id']].get(mode_name)
        extra=award(base[primary],s['material_work'],s['growth'],draw(seed,ident,s['round'],'material:'+primary)) if primary else 0
        if primary: material_expectation+=Fraction(int(base[primary])*int(s['material_work']),4*int(s['growth']))
        expected_material={primary:extra} if extra else {}
        assert r['seed']==expected_seed and r['material']==expected_material,'wrong seed, byproduct, random outcome or extra yield'
        s['seed_claimed']=s['seed_checked'];assert r['state']==s,'claim rewrote frozen contribution'
        proof(r['day'],'inflows','育种奖励',expected_seed);proof(r['day'],'inflows','丰产奖励',expected_material)
        bank.update(expected_seed);stats['seed_awards']+=sum(expected_seed.values());stats['material_awards']+=sum(expected_material.values());stats['claims']+=1
        if tuple(p['crop']['origin']) in MODULE_CELLS: stats['module_harvests']+=1
        if mode_name=='harvest' and d['mode']=='tap_or_fell':
            next_round=fresh_round(d['cycle_days']*100,s['round']+1)
            for k in ('seed_checked','seed_award','seed_claimed','seed_total','seed_eligible'): next_round[k]=s[k]
            p['state']=next_round
        else: plants.pop(ident);retired.add(ident)
    for row in days:
        assert row['opening_cash']['purchase_spend']==fees[row['day']],'opening gu fee misdated or double-charged'
    if finished:
        assert seen_days==list(range(1,horizon+2)),'missing room day snapshots'
        assert stats['growth_events']>100 and stats['claims']>30,'room replay coverage too thin'
        assert (stats['seed_awards']>0)==(mode in ('seed','compound')),'missing or unexpected breeding rewards'
        assert (stats['material_awards']>0)==(mode in ('material','compound')),'missing or unexpected yield rewards'
        if mode in ('seed','compound'): assert stats['reused_seeds']>0,'returned seeds never actually replanted'
        expected_channels={'ordinary':set(),'seed':{'seed'},'material':{'material'},'compound':{'seed','material'}}[mode]
        assert {channel for channel,n in qualified.items() if n>0}==expected_channels,'observed room channels differ from configured comparison'
        summary=read_json(directory/f'{route}-room-summary.json')
        for key in ('module_plantings','module_harvests','seed_awards','material_awards'): assert summary[key]==stats[key],('operator room summary disagrees with replay',key)
        assert summary['floor_cells']==stats['floor_actions']
    actions=lines(directory/f'{route}-actions.jsonl',not finished)
    stats['wheat_seeds_bought']=sum(int(a['result'].get('quantity',0)) for a in actions if a['result'].get('ok') and a['result'].get('item_id')=='golden_wheat_seed' and a['result'].get('total',0)>0)
    stats['room_player_ap']=sum(int(a['ap_before']-a['ap_after']+(24 if a['result'].get('day_advanced') else 0)) for a in actions if a['action'].startswith('room ') and a['result'].get('ok'))
    if days:
        final=days[-1];module_hosts={int(f['uid']) for f in final['facilities'] if tuple(f['origin']) in MODULE_HOSTS}
        stats['room_host_cells']=len(module_hosts)
        if finished: assert len(module_hosts)=={'ordinary':0,'seed':2,'material':2,'compound':3}[mode],'comparison configuration lacks its paid single-cell hosts'
        for r in receipts:
            if r['kind']=='device' and r['stage'] in ('irrigate','fertilize') and int(r['uid']) in module_hosts:
                for item,n in r['inputs'].items(): stats['host_service_'+item]+=int(n)
    expectations={'seed':str(seed_expectation),'material':str(material_expectation)}
    return {'proofs':dict(proofs),'stats':dict(stats),'qualified':dict(qualified),'checked_days':len(seen_days),'maintenance':sum(fees.values()),'expected_awards':expectations}

def audit(directory,complete=True):
    summary=read_json(directory/'summary.json');assert not summary['failures'],summary['failures']
    manifest=read_json(directory/'manifest.json')
    assert {'scripts/farming/tests/run_p102_playtest.gd','scripts/farming/p8/p102_rooms.gd'}<=manifest.keys()
    for name,digest in manifest.items(): assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,('source changed',name)
    source=read_json(ROOT/'content/farming/p8/production.json')
    horizon=summary['settings']['days'];assert integer(horizon,90,180),'invalid business horizon'
    result={route:audit_route(directory,route,source,int(horizon),summary['settings']['room_mode']) for route in summary['routes']}
    if complete: assert set(result)=={'A','B'},'two independent room strategies required'
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('directory',type=Path)
    parser.add_argument('--prefix',action='store_true');parser.add_argument('--route',default='A')
    args=parser.parse_args()
    if args.prefix:
        source=read_json(ROOT/'content/farming/p8/production.json')
        first=lines(args.directory/f'{args.route}-rooms.jsonl',True)[0]
        result=audit_route(args.directory,args.route,source,0,first['mode'],False)
        print('P102 PREFIX AUDIT OK (diagnostic only):',result['stats']);return
    result=audit(args.directory)
    print('P102 ROOM AUDIT OK:',{r:v['stats'] for r,v in result.items()})

if __name__=='__main__': main()
