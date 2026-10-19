"""Independent short-module receipt audit; time horizon is not a gate."""
import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path


def require(ok, message):
    if not ok:
        raise ValueError(message)


def audit(path):
    data = json.loads(Path(path).read_text(encoding='utf-8'))
    smoke=data['kind']=='p104-integration-smoke'
    require(data['kind'] in ('p104-module','p104-integration-smoke') and not data['failures'], 'scenario failed or wrong kind')
    opening, closing = data['opening'], data['closing']
    first, last = opening['clock']['total_days'], closing['clock']['total_days']
    require(last-first==60 if smoke else 0 < last-first <= 30, 'scenario duration')
    if smoke:
        require(data['days']==60 and all(data['coverage'].values()) and len(closing['world']['ranch']['births'])>=2, 'integration coverage')
    before, after = opening['world']['services'], closing['world']['services']
    new = [r for r in data['receipts'] if r.get('kind')=='service']
    require(after['history']==before['history']+new, 'receipt stream does not match committed service history')

    net = Counter()
    def flows(row, sign=1):
        for field, direction in [('inflows',1),('outflows',-1)]:
            for item, reasons in row[field].items():
                net[item] += sign*direction*sum(reasons.values())
    rows = closing['ledger']['history']+[closing['ledger']['pending']]
    stock_opening=opening['inventory']
    inventory_start=first
    if smoke:
        # Saves deliberately retain only 15 resource-ledger days. Validate the
        # entire surviving stock chain independently; service history is full.
        # Earlier days were reconciled by the runtime and strict daily codec.
        inventory_start=rows[0]['day']
        stock_opening=rows[0]['opening']
        expected=Counter(stock_opening)
        for row in rows:
            require(Counter(row['opening'])==expected,'inventory day discontinuity')
            for item,reasons in row['inflows'].items(): expected[item]+=sum(reasons.values())
            for item,reasons in row['outflows'].items(): expected[item]-=sum(reasons.values())
            require(all(v>=0 for v in expected.values()),'negative inventory')
            if 'closing' in row: require(Counter(row['closing'])==expected,'inventory day close')
    for row in rows:
        if row['day']>=inventory_start: flows(row)
    if not smoke: flows(opening['ledger']['pending'], -1)
    for item in set(net)|set(stock_opening)|set(closing['inventory']):
        require(closing['inventory'].get(item,0)-stock_opening.get(item,0)==net[item], 'warehouse delta: '+item)

    installed = {}
    capacity = Counter()
    activity = Counter()
    work_units = Counter()
    failed = Counter()
    extra = Counter()
    live = {r['uid']:r for r in closing['world']['ranch']['animals']}
    contributions = defaultdict(Counter)
    growth = {}
    progress = {}
    gifts = {}
    pool = Counter()
    works = {}
    candidates = {}
    credited = set()
    used = set()
    toy_seen = set()
    last_fatigue = {}
    seed = after['random_seed']
    import hashlib
    def draw(uid, t):
        text = f'{seed}|animal:{uid}|{t}|toy'
        return (int(hashlib.sha256(text.encode()).hexdigest()[:8],16)%1000000)%100
    for e in after['history']:
        stage = e['stage']
        day = e['day']
        if stage=='toy_install':
            require(str(e['host']) not in installed and e['count']==1, 'duplicate installation')
            installed[str(e['host'])]='vine_ball'
        elif stage=='toy_remove':
            require(str(e['host']) in installed and e['count']==1, 'duplicate removal')
            del installed[str(e['host'])]
        elif stage in ('gu_service','toy_service'):
            capacity[e['host'],e['t']] += e['space']
            require(capacity[e['host'],e['t']]<=4, 'host capacity oversold')
            if stage=='toy_service':
                identity=(e['animal'],e['t'])
                require(identity not in toy_seen and str(e['host']) in installed, 'invalid toy service')
                toy_seen.add(identity)
                require(e['roll']==draw(*identity) and e['extra']==int(e['roll']<10), 'toy random result changed')
                extra[e['animal'],day] += e['extra']
        elif stage=='activity': activity[e['animal'],day]+=1
        elif stage=='maintenance_fail': failed[e['animal'],day]+=1
        elif stage=='growth':
            require(e['before']==growth.get(e['animal'],gifts.get(e['animal'],0)) and e['after']==min(e['target'],e['before']+100), 'juvenile growth recurrence')
            growth[e['animal']]=e['after']
        elif stage=='breed_progress':
            if e['identity'] in progress:
                require(progress[e['identity']]['after']==e['before'], 'breeding recurrence')
            rate=e['source'].get('value',100)
            require(e['points']==min(rate,e['target']-e['before']) and e['after']==e['before']+e['points'], 'breeding increment')
            progress[e['identity']]=e
        elif stage=='breed_contribution':
            source=progress[e['identity']]
            require(source['source'] and e['t']==source['t'] and e['points']==source['points'], 'unearned contribution')
            contributions[e['identity']][str(e['target'])]+=e['points']
            require(e['total']==contributions[e['identity']][str(e['target'])] and sum(contributions[e['identity']].values())<=source['target'], 'contribution overdraw')
        elif stage=='contribution_drop': contributions.pop(e['identity'],None)
        elif stage=='birth_bonus':
            require(e['child'] not in gifts, 'duplicate child reward')
            eligible=contributions.pop(e['identity'],Counter()).get(str(e['target']),0)
            require(e['eligible']==eligible and e['gift']==e['growth_target']*eligible//(10*e['breed_target']), 'initial growth award')
            gifts[e['child']]=e['gift']
        elif stage=='work_progress':
            identity=f"{e['yard']}:{e['post']}:{e['batch']}:{e['t']}"
            require(identity not in works, 'duplicate work unit')
            require(e['points']==e['base']*e['source'].get('value',100)//100, 'work multiplier')
            raw=e['before']+e['points']+e['carry']
            require(e['after']==min(raw,e['target']) and e['overflow']==max(0,raw-e['target']), 'work point conservation')
            if e['carry']: require(identity in used, 'unearned carry use')
            works[identity]=e
            work_units[e['animal'],day]+=1
        elif stage=='pool_candidate':
            identity=f"{e['key']}:{e['batch']}:{e['t']}"
            # The corresponding work receipt follows this candidate.
            require(identity not in candidates, 'duplicate overflow candidate')
            candidates[identity]=e
        elif stage=='pool_credit':
            identity=f"{e['key']}:{e['batch']}:{e['t']}"
            require(identity in works and identity in candidates and identity not in credited, 'credit without actual work')
            require(works[identity]['overflow']==e['points'] and e['credited']==min(e['points'],10000-pool[e['key']]) and e['discarded']==e['points']-e['credited'], 'overflow credit conservation')
            credited.add(identity)
            pool[e['key']]+=e['credited']
        elif stage in ('pool_use','pool_drop'):
            require(e['points']==pool[e['key']], 'pool spend mismatch')
            pool[e['key']]=0
            if stage=='pool_use': used.add(f"{e['key']}:{e['batch']}:{e['t']}")
        elif stage=='fatigue':
            key=(e['animal'],day)
            require(e['w']==work_units[key] and e['r']==activity[key] and e['fails']==failed[key], 'virtual labor or recovery')
            require(e['toy_extra']==extra[key] and e['next']==max(0,min(100,e['open']+e['w']-2*e['r']+12*e['fails']-e['toy_extra'])), 'fatigue recurrence')
            last_fatigue[e['animal']]=e['next']
    require(installed==after['toys'], 'installed toy count changed')
    require(dict(contributions)==after['contributions'], 'contribution index changed')
    for key in set(pool)|set(after['pools']):
        require(pool[key]==after['pools'].get(key,{}).get('points',0), 'pool balance changed')
    for uid, row in live.items():
        if uid in last_fatigue: require(row['fatigue']==last_fatigue[uid], 'fatigue reset')
        if uid in growth or uid in gifts: require(row['growth']==growth.get(uid,gifts.get(uid,0)), 'growth index changed')
    actual=[r for r in data['receipts'] if r.get('kind')=='ranch:work' and r.get('stage')=='unit']
    declared=[r for r in new if r['stage']=='work_progress']
    require({(r['animal'],r['t'],r['workyard'],r['post'],r['points']) for r in actual}=={(r['animal'],r['t'],r['yard'],r['post'],r['points']) for r in declared}, 'labor stream mismatch')
    return dict(ok=True,route=data.get('route','integration-smoke'),days=last-first,checks=data['checks'],services=len(new),
                toy_services=len(toy_seen),births=len(gifts),work_units=sum(work_units.values()),
                carry_used=len(used),fixture=data['fixture'],independent_inventory_days=last-inventory_start,
                service_history_days=last-first)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('root',type=Path)
    args=parser.parse_args()
    cases={'structure','hosts','toy','breeding','work','compound','breeding-base','work-base'}
    paths=[args.root] if args.root.is_file() else sorted(path for path in args.root.glob('*/scenario.json') if path.parent.name in cases)
    require(bool(paths),'no module evidence')
    print(json.dumps([audit(path) for path in paths],ensure_ascii=False,indent=2))


if __name__=='__main__':
    main()
