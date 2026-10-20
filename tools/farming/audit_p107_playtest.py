"""Independent replay of public commands from external initial inventory/cash.

Recomputes orders, trade quantities, milestones, payments, AP, ordinary batch
deadlines, research days, and the unboosted resin-tree production schedule.
Does not trust game ledger deltas or the runtime's cumulative counter as inputs.
"""
import argparse
import copy
from fractions import Fraction
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CASES = ('stage-orders', 'stage-resources', 'barter', 'research-access', 'specialist-route', 'growth-budget')


def load(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


class AuditError(ValueError):
    pass


class Replay:
    def __init__(self, initial, source):
        self.source = source
        self.cfg = source['config']
        self.economy = source['p107']
        self.items = {r['id']: r for r in source['resources']}
        self.recipes = {r['id']: r for r in source['recipes']}
        self.facdefs = {r['id']: r for r in source['facilities']}
        self.projects = {r['id']: r for r in source['research']}
        self.offers = {r['id']: r for r in self.economy['offers']}
        self.day = initial['clock']['total_days']
        self.start_day = self.day
        self.ap = initial['clock']['ap']
        self.cash = initial['economy']['primeval_stones']
        self.revenue = initial['economy']['sales_revenue'] + initial['economy']['order_revenue']
        self.stock = dict(initial['inventory'])
        self.level = len(initial['world']['economy_progress']['events'])
        self.seq = initial['world']['economy_progress']['next_seq']
        self.progress = copy.deepcopy(initial['world']['economy_progress'])
        self.count = len(initial['orders']['settlements']) + sum(r['status'] == 'completed' for r in initial['orders']['entries'])
        self.orders = {r['id']: copy.deepcopy(r) for r in initial['orders']['entries']}
        self.sources = {r['id']: r for r in source['sources']}
        self.used = dict(initial['world']['sources']['used'])
        self.completed = set(initial['world']['research']['completed'])
        self.research = {}
        self.facilities = {r['uid']: copy.deepcopy(r) for r in initial['world']['facilities']}
        self.next_facility = initial['world']['next_facility_uid']
        self.batches = {}
        self.next_batch = initial['world']['next_batch_uid']
        self.crops = {r['uid']: copy.deepcopy(r) for r in initial['world']['crops']}
        self.cropdefs = {r['id']: r for r in source['crops']}
        self.next_crop = initial['world']['next_uid']
        self.env = copy.deepcopy(initial['world']['environment'])
        self.width = 20  # the archived cases use the initial farm_02 parcel
        self.tilled = {tuple(v) for v in initial['world']['tilled']}
        self.events = 0
        self.trades = 0
        self.harvests = 0
        self.checks = 0

    def need(self, ok, reason):
        self.checks += 1
        if not ok:
            raise AuditError(reason)

    def view(self, actual, where):
        expected = {'day': self.day, 'ap': self.ap, 'cash': self.cash, 'stage': self.level,
                    'orders': self.count, 'sequence': self.seq}
        for key, value in expected.items():
            self.need(actual[key] == value, f'{where}: {key} {actual[key]} != {value}')
        self.need(actual['inventory'] == self.stock, f'{where}: external inventory mismatch')
        self.need(len(actual['crops']) == len(self.crops), f'{where}: crop count')
        for crop in actual['crops']:
            self.need(crop['uid'] in self.crops, f'{where}: unknown crop')
            for key in ['crop_id', 'origin', 'progress', 'state', 'harvest_count']:
                self.need(crop[key] == self.crops[crop['uid']][key], f'{where}: crop {key}')

    def has(self, values):
        return all(self.stock.get(k, 0) >= n for k, n in values.items())

    def flow(self, give=None, receive=None):
        for k, n in (give or {}).items():
            self.need(self.stock.get(k, 0) >= n, f'outflow without inventory {k}')
            self.stock[k] -= n
            if self.stock[k] == 0:
                del self.stock[k]
        for k, n in (receive or {}).items():
            self.stock[k] = self.stock.get(k, 0) + n

    def gate(self, kind, ident):
        return self.level >= self.economy['gates'][kind].get(ident, 0)

    def day_end(self):
        for crop in self.crops.values():
            definition = self.cropdefs[crop['crop_id']]
            self.need(crop['crop_id'] == 'resin_tree', 'case outside independently modeled crop domain')
            x, y = crop['origin']
            cells = [(x + dx, y + dy) for dy in range(2) for dx in range(2)]
            env = [self.env[cy * self.width + cx] for cx, cy in cells]
            settings = self.cfg['environment']
            water = 100 if sum(e[0] for e in env) >= 4 * settings['optimal_water'] else settings['low_water_efficiency']
            fertility = 100 if sum(e[1] for e in env) >= 4 * settings['optimal_fertility'] else settings['low_fertility_efficiency']
            # All three archived trees stand in the default-80 light region.
            self.need(x >= 4 and y < 6, 'resin case light assumption violated')
            growth = max(1, water * fertility // 100)
            target = 100 * (definition['cycle_days'] if crop['harvest_count'] else definition['days'])
            if crop['state'] != 'mature':
                crop['progress'] = min(target, crop['progress'] + growth)
                if crop['progress'] == target:
                    crop['state'] = 'mature'
            for e in env:
                e[0] = max(0, e[0] - definition['water_use'])
                e[1] = max(0, e[1] - definition['fertility_use'])
        for ident, project in list(self.research.items()):
            if self.day in project['worked']:
                project['progress'] += 1
                if project['progress'] >= self.projects[ident]['days']:
                    self.completed.add(ident)
                    del self.research[ident]
        self.day += 1
        self.ap = self.cfg['ap_per_day']
        self.used = {k: 0 for k in self.used}
        settings = self.source['orders']
        cap = max(int(k) for k, v in settings['rank_unlock_revenue'].items() if self.revenue >= v)
        self.orders = {}
        for index in range(settings['daily_limit']):
            ident = self.day * settings['daily_limit'] + index + 1
            rank = 1 if index == 0 else 1 + (self.day * (settings['daily_limit'] - 1) + index - 1 + self.day // len(settings['paths'])) % cap
            self.orders[ident] = {'id': ident, 'status': 'open', 'rank': rank,
                                  'path': settings['paths'][(self.day * settings['daily_limit'] + index) % len(settings['paths'])]}

    def step(self, row):
        self.view(row['before'], 'before')
        name, args, result = row['command'], row['args'], row['result']
        valid, give, receive, cash, ap = True, {}, {}, 0, 0
        order = None
        if name in ('buy', 'sell'):
            ident, amount = args
            item = self.items[ident]
            price = item['buy_price' if name == 'buy' else 'sell_price']
            valid = isinstance(amount, int) and amount > 0 and price > 0
            if name == 'buy':
                cash = -price * amount
                receive = {ident: amount}
            else:
                cash = price * amount
                give = {ident: amount}
        elif name == 'collect':
            source = self.sources[args[0]]
            valid = self.used[args[0]] + source['quantity'] <= source['daily_limit']
            receive = {source['item']: source['quantity']}
            ap = source['ap']
        elif name == 'order':
            ident, item_id = args
            order = self.orders.get(ident)
            item = self.items[item_id]
            valid = order is not None and order['status'] == 'open' and item['supply_allowed'] and order['path'] == item['element']
            if valid:
                quantity = -(-self.source['orders']['base_demand'] * order['rank'] // item['supply_value'])
                base = quantity * item['sell_price']
                cash = base + base * self.source['orders']['premium_percent'] // 100
                give = {item_id: quantity}
                self.need(result.get('quote', {}).get('quantity') == quantity and result['quote']['payout'] == cash, 'order quote is not independent market+integer-premium result')
        elif name == 'exchange':
            ident, amount = args
            offer = self.offers.get(ident)
            valid = offer is not None and not isinstance(amount, bool) and isinstance(amount, (int, float)) and int(amount) == amount and 1 <= amount <= 1000000 and self.level >= offer['stage']
            if valid:
                give = {k: n * amount for k, n in offer['give'].items()}
                receive = {k: n * amount for k, n in offer['receive'].items()}
        elif name == 'event':
            event = self.economy['events'][self.level] if self.level < 3 else None
            valid = event is not None and args[0] == event['id'] and self.count >= event['orders']
            if valid:
                give = event['inputs']
        elif name == 'end':
            pass
        elif name == 'till':
            valid = tuple(args) not in self.tilled
            ap = 1
        elif name == 'plant':
            definition = self.cropdefs[args[2]]
            x, y = args[:2]
            valid = all((x + dx, y + dy) in self.tilled for dy in range(2) for dx in range(2))
            give = dict(definition['inputs'])
            give[definition['seed']] = give.get(definition['seed'], 0) + 1
            ap = 1
        elif name in ('irrigate', 'fertilize'):
            key = 'water' if name == 'irrigate' else 'fertility'
            give = {'clean_water' if name == 'irrigate' else 'humus': self.cfg['environment'][name + '_units']}
            valid = tuple(args) in self.tilled and self.env[args[1] * self.width + args[0]][0 if key == 'water' else 1] < 100
            ap = 1
        elif name == 'harvest':
            crop = next((c for c in self.crops.values() if c['origin'] == args), None)
            valid = crop is not None and crop['state'] == 'mature'
            if valid:
                receive = self.cropdefs[crop['crop_id']]['outputs']
                self.need(result.get('items') == receive, 'harvest output differs from plain crop production')
            ap = 1
        elif name == 'build':
            definition = self.facdefs[args[2]]
            valid = self.gate('facility', args[2]) and (not definition.get('research') or definition['research'] in self.completed)
            give, cash, ap = definition['materials'], -definition['cash'], self.cfg['construction']['build_ap']
        elif name == 'start_batch':
            recipe = self.recipes[args[1]]
            valid = args[0] in self.facilities and args[0] not in self.batches and self.facilities[args[0]]['facility_id'] == recipe['facility']
            valid = valid and args[1] not in self.source['p103']['work']['recipes'] and (not recipe.get('research') or recipe['research'] in self.completed)
            give, ap = recipe['inputs'], recipe['start_ap']
        elif name == 'claim_batch':
            batch = self.batches.get(args[0])
            valid = batch is not None and batch['id'] == args[1] and self.day >= batch['finish']
            if valid:
                receive = self.recipes[batch['recipe']]['outputs']
            ap = 1
        elif name == 'start_research':
            ident = args[1]
            project = self.projects[ident]
            valid = self.gate('research', ident) and ident not in self.completed and ident not in self.research
            valid = valid and args[0] in self.facilities and self.facilities[args[0]]['facility_id'] == 'research_bench'
            valid = valid and set(project['prerequisites']) <= self.completed
            give, cash = project['samples'], -project['fee']
        elif name == 'research_work':
            project = next((p for p in self.research.values() if p['bench'] == args[0]), None)
            valid = project is not None and self.day not in project['worked']
            ap = 1
        elif name == 'buy_gu':
            gu = next(r for r in self.source['logistics']['definitions'] if r['id'] == args[0])
            valid = self.gate('gu', args[0])
            cash = -gu['market_price']
        else:
            raise AuditError('unmodeled command ' + name)
        valid = valid and self.has(give) and self.cash + cash >= 0 and self.ap >= ap
        self.need(bool(result['ok']) == valid, f'{name}: false or bypassed eligibility')
        if not valid:
            self.need(row['before'] == row['after'], f'{name}: failed operation mutated world')
            self.need(not row['operations'], f'{name}: failed operation emitted success receipt')
            return
        self.flow(give, receive)
        self.cash += cash
        if name in ('order', 'sell'):
            self.revenue += cash
        if name == 'order':
            order['status'] = 'completed'
            self.count += 1
        if name == 'collect':
            self.used[args[0]] += self.sources[args[0]]['quantity']
        if name in ('event', 'exchange'):
            receipts = [r for r in row['operations'] if r.get('kind') == 'economy' and r.get('stage') == name]
            self.need(len(receipts) == 1 and receipts[0]['seq'] == self.seq, f'{name}: unique operation receipt missing')
            if name == 'event':
                self.need(receipts[0]['inputs'] == give and receipts[0]['orders'] == self.count, 'event receipt materials/count')
                self.progress['events'].append({'id': args[0], 'seq': self.seq, 'day': self.day, 'orders': self.count})
                self.level += 1
                self.events += 1
            else:
                self.need(receipts[0]['give'] == give and receipts[0]['receive'] == receive, 'barter receipt quantity drift')
                self.progress['exchanges'].append({'offer': args[0], 'batches': int(args[1]), 'seq': self.seq, 'day': self.day})
                self.trades += 1
            self.seq += 1
            self.progress['next_seq'] = self.seq
        if name == 'till': self.tilled.add(tuple(args))
        if name == 'plant':
            self.need(result['uid'] == self.next_crop, 'plant instance sequence')
            self.crops[self.next_crop] = {'uid': self.next_crop, 'crop_id': args[2], 'origin': args[:2], 'progress': 0, 'state': 'growing', 'harvest_count': 0}
            self.next_crop += 1
        if name in ('irrigate', 'fertilize'):
            index = 0 if name == 'irrigate' else 1
            env = self.env[args[1] * self.width + args[0]]
            env[index] = min(100, env[index] + self.cfg['environment'][name + '_gain'])
        if name == 'harvest':
            crop['state'], crop['progress'] = 'regrowing', 0
            crop['harvest_count'] += 1
            self.harvests += 1
        if name == 'build':
            self.need(result['facility_uid'] == self.next_facility, 'facility sequence')
            self.facilities[self.next_facility] = {'facility_id': args[2]}
            self.next_facility += 1
        if name == 'start_batch':
            self.need(result['batch_id'] == self.next_batch, 'batch sequence')
            self.batches[args[0]] = {'id': self.next_batch, 'recipe': args[1], 'finish': self.day + self.recipes[args[1]]['days']}
            self.next_batch += 1
        if name == 'claim_batch': del self.batches[args[0]]
        if name == 'start_research': self.research[args[1]] = {'bench': args[0], 'worked': [], 'progress': 0}
        if name == 'research_work': project['worked'].append(self.day)
        self.ap -= ap
        if name == 'end' or self.ap == 0: self.day_end()
        self.view(row['after'], 'after ' + name)


def audit_case(folder, source=None, rows=None):
    folder = Path(folder)
    source = source or load(ROOT / 'content/farming/baked/p8/production.json')
    initial, final, meta = load(folder / 'initial.json'), load(folder / 'final.json'), load(folder / 'case.json')
    raw = (ROOT / 'content/farming/baked/p8/production.json').read_bytes()
    if meta['production_sha256'] != hashlib.sha256(raw).hexdigest():
        raise AuditError('configuration changed: rerun affected case')
    rows = rows if rows is not None else [json.loads(line) for line in (folder / 'commands.jsonl').read_text(encoding='utf-8').splitlines()]
    replay = Replay(initial, source)
    if meta['case'] == 'stage-orders':
        replay.need(meta['kind'] == 'fresh-no-injection', 'fresh route relabeled as fixture')
        replay.need(initial['inventory'] == source['config']['start_inventory'] and replay.cash == source['config']['initial_primeval_stones']
                    and replay.level == 0 and replay.count == 0 and replay.day == 0 and replay.revenue == 0
                    and replay.ap == source['config']['ap_per_day'] and not replay.crops and not replay.facilities,
                    'fresh route injects capital stock or milestones')
    for i, row in enumerate(rows, 1):
        replay.need(row['n'] == i, 'missing or reordered command')
        replay.step(row)
    replay.need(replay.day - replay.start_day <= 30, 'overlong module case')
    replay.need(final['inventory'] == replay.stock and final['economy']['primeval_stones'] == replay.cash, 'final external stock/cash does not reconcile')
    replay.need(final['clock']['total_days'] == replay.day, 'final day')
    replay.need(len(final['world']['economy_progress']['events']) == replay.level, 'final global stage')
    replay.need(final['world']['economy_progress']['next_seq'] == replay.seq, 'final economic sequence')
    replay.need(final['world']['economy_progress'] == replay.progress, 'final economic receipt history differs from independently reconstructed transactions')
    replay.need(set(final['world']['research']['completed']) == replay.completed, 'final knowledge differs from actual paid research')
    replay.need({r['uid']: r['facility_id'] for r in final['world']['facilities']} == {uid: r['facility_id'] for uid, r in replay.facilities.items()}, 'final facility registry differs from actual construction')
    final_orders = final['orders']['settlements'] + [{'entry': e} for e in final['orders']['entries'] if e['status'] == 'completed']
    replay.need(len(final_orders) == replay.count, 'final order history differs from actual successful deliveries')
    replay.view({'day': final['clock']['total_days'], 'ap': final['clock']['ap'], 'cash': final['economy']['primeval_stones'],
                 'stage': len(final['world']['economy_progress']['events']), 'orders': len(final_orders),
                 'sequence': final['world']['economy_progress']['next_seq'], 'inventory': final['inventory'],
                 'crops': final['world']['crops']}, 'final snapshot')
    name = meta['case']
    if name == 'stage-orders': replay.need(replay.count >= 12 and replay.level == 2, 'fresh order milestones missing')
    elif name == 'research-access': replay.need('biofiltration' in replay.completed and replay.level == 1, 'research unlock not exercised')
    else: replay.need(replay.level == 3, 'resource milestone missing')
    if name == 'barter': replay.need(replay.trades >= 15 and replay.day - replay.start_day == 1, 'unlimited same-day barter not exercised')
    if name == 'growth-budget':
        replay.need(replay.harvests == 18 and all(c['harvest_count'] == 6 for c in replay.crops.values()), 'startup plus five actual rounds missing')
        replay.need('field_maintenance' in replay.completed and any(f['facility_id'] == 'field_service_station' for f in replay.facilities.values()), 'cross-tier research and station construction missing')
        replay.need(any(r['command'] == 'buy_gu' and r['result']['ok'] for r in rows), 'cross-tier gu purchase missing')
    return {'case': name, 'checks': replay.checks, 'commands': len(rows), 'days': replay.day - replay.start_day, 'cash': replay.cash}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('root', nargs='?', default='.art-work/p107-playtest')
    parser.add_argument('--cases', nargs='+', choices=CASES, default=list(CASES))
    args = parser.parse_args()
    results = [audit_case(Path(args.root) / name) for name in args.cases]
    print('P107 AUDIT OK: ' + json.dumps(results))
    Path(args.root, 'audit-latest.json').write_text(json.dumps({'cases': results}, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
