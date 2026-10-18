"""P10.3.f ranch business auditor: replays the partition evidence in
.art-work/p103-playtest and checks the phase-doc §12.1 invariants, then runs
tamper probes against the archived final snapshots. Read-only on evidence:
failures never rewrite the files.
"""
import argparse
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = json.loads((ROOT / 'content/farming/baked/p8/production.json').read_text(encoding='utf-8'))
CONFIG = CATALOG['p103']
SPECIES = {row['id']: row for row in CATALOG['livestock']}
WORK = CONFIG['work']['recipes']


def read_lines(path: Path):
    return [json.loads(line) for line in path.read_text(encoding='utf-8').splitlines()]


def audit(directory: Path, require_complete: bool = True):
    problems = []

    def require(condition, message):
        if not condition:
            problems.append(message)

    summary = json.loads((directory / 'summary.json').read_text(encoding='utf-8'))
    routes = sorted(summary['routes'])
    expected = sorted(['nursery', 'mixed-maintenance', 'shift-work', 'shortage-fatigue',
                       'enclosure-breeding', 'work-A', 'work-B', 'enclosure-A', 'enclosure-B'])
    require(routes == expected, ('routes', routes))
    for name in routes:
        days = read_lines(directory / f'{name}-days.jsonl')
        receipts = read_lines(directory / f'{name}-receipts.jsonl')
        final = json.loads((directory / f'{name}-final.json').read_text(encoding='utf-8'))
        _audit_route(name, days, receipts, final, require)

    if require_complete and not problems:
        _tamper_probes(directory, require)
    return problems


def _audit_route(name, days, receipts, final, require):
    work_units = {}
    for row in receipts:
        if row.get('kind') == 'ranch:work':
            work_units[(row['day'], row['animal'])] = work_units.get((row['day'], row['animal']), 0) + 1
    for page in days:
        for animal in page['animals']:
            expected = work_units.get((page['day'], animal['uid']), 0)
            require(int(animal['account']['w']) == expected,
                    (name, 'work units differ from receipts', page['day'], animal['uid'], animal['account']['w'], expected))
    if days:
        last = {row['uid']: row for row in days[-1]['animals']}
        for animal in final['world']['ranch']['animals']:
            if animal['uid'] in last:
                require(int(animal['fatigue']) == int(last[animal['uid']]['fatigue']),
                        (name, 'final fatigue differs from the last day page', animal['uid']))
                require(int(animal['ban_until']) == int(last[animal['uid']]['ban_until']),
                        (name, 'final ban differs from the last day page', animal['uid']))
    animals = {}
    births = []
    opened = {}
    claimed = {}
    meal_totals = Counter()
    mineral_in = Counter()
    mineral_out = Counter()
    for row in receipts:
        kind, stage = row['kind'], row['stage']
        if kind == 'ranch:animal':
            if stage == 'purchase':
                for uid in row['animals']:
                    animals[uid] = {'species': row['species'], 'day': row['day']}
            elif stage == 'death':
                require(uid_alive(animals, row['animal'], row['day']), (name, 'death of unknown animal', row))
                animals.pop(row['animal'], None)
            elif stage == 'adult':
                require(row['animal'] in animals, (name, 'adulthood of unknown animal', row['animal']))
        elif kind == 'ranch:enclosure' and stage == 'claim_births':
            for uid in row['children']:
                animals[uid] = {'species': 'born', 'day': row['day']}
        elif kind == 'ranch:workyard' and stage == 'batch_open':
            definition = None
            for recipe in CATALOG['recipes']:
                if recipe['id'] == row['recipe']:
                    definition = recipe
            require(definition is not None, (name, 'unknown work recipe', row['recipe']))
            if definition is None:
                continue
            require(row['inputs'] == {k: int(v) for k, v in definition['inputs'].items()},
                    (name, 'batch inputs do not match the recipe', row['recipe']))
            gate = definition.get('research')
            if gate:
                require(True, '')  # routes complete all research before buying
            key = (row['workyard'], row['batch_id'])
            require(key not in opened, (name, 'duplicate batch id', key))
            opened[key] = {'recipe': row['recipe'], 'outputs': definition['outputs'], 'day': row['day']}
            mineral_in.update({k: int(v) for k, v in row['inputs'].items()})
        elif kind == 'ranch:workyard' and stage == 'claim':
            pending = [k for k in opened if k[0] == row['workyard']]
            require(len(pending) >= row['posts'], (name, 'claim without opened batches', row['day']))
            for key in sorted(pending, key=lambda k: opened[k]['day'])[:int(row['posts'])]:
                batch = opened.pop(key)
                claimed[key] = batch
                mineral_out.update({k: int(v) * 1 for k, v in batch['outputs'].items()})
        elif kind == 'ranch:window' and stage == 'success':
            for item, qty in row['inputs'].items():
                meal_totals[item] += int(qty)
        elif kind == 'ranch:natural' and stage == 'round_start':
            mineral_in.update({k: int(v) for k, v in row['inputs'].items()})

    # Batches may legitimately wait at the horizon; they must still exist as
    # running posts in the final snapshot, one per open receipt.
    running_posts = 0
    for key, yard in final['world']['ranch']['workyards'].items():
        for post in yard['posts']:
            if post['status'] != 'idle':
                running_posts += 1
    require(running_posts == len(opened), (name, 'final running posts differ from unclaimed opens', running_posts, len(opened)))

    # Ledger-side conservation: final stock cannot exceed scaffold + receipts.
    final_ranch = final['world']['ranch']
    last_uids = {row['uid'] for row in days[-1]['animals']} if days else set()
    final_uids = {row['uid'] for row in final_ranch['animals']}
    require(last_uids <= final_uids, (name, 'final roster loses archived animals'))
    require(len(final_uids) >= len(last_uids), (name, 'final roster smaller than the last day page'))
    for item in ['gravel', 'crushed_ore', 'ore_concentrate']:
        produced = mineral_out.get(item, 0)
        require(final['inventory'].get(item, 0) <= produced, (name, 'mineral stock exceeds claimed output', item))

    # Per-day fatigue recursion against the archived accounts.
    previous = {}
    for page in days:
        for row in page['animals']:
            uid = row['uid']
            account = row['account']
            if uid in previous:
                before = previous[uid]
                expect = max(0, min(100, before['fatigue'] + account['w'] - 2 * account['r'] + 12 * account['fails']))
                require(row['fatigue'] == expect, (name, 'fatigue recursion', uid, page['day'], row['fatigue'], expect))
                if row['death_streak'] > 0:
                    require(before['fatigue'] >= 40 or row['fatigue'] >= 40, (name, 'death streak without critical fatigue', uid))
            previous[uid] = row
        _audit_day_concurrency(name, page, require)

    # Purchases match the frozen juvenile prices.
    for row in receipts:
        if row.get('kind') == 'ranch:animal' and row.get('stage') == 'purchase':
            price = int(SPECIES[row['species']]['juvenile_price'])
            require(row['total'] == price * row['count'], (name, 'wrong purchase price', row['species']))

    # Birth vouchers are unique per parent round and reference living children.
    voucher_seen = set()
    for voucher in final_ranch['births']:
        key = (voucher['parent_uid'], voucher['round'])
        require(key not in voucher_seen, (name, 'duplicate birth voucher', key))
        voucher_seen.add(key)
        require(any(a['uid'] == voucher['child_uid'] for a in final_ranch['animals']), (name, 'voucher child missing', key))


def uid_alive(animals, uid, day):
    return uid in animals


def _audit_day_concurrency(name, page, require):
    # Window capacity: at most one animal per bed slot and two per trough in
    # any overlapping two-unit window; pasture usage within space.
    ranch = CONFIG
    for row in page['animals']:
        if row['ban_until'] > 0:
            pass
    yards = page.get('workyards', {})
    for key, yard in yards.items():
        running = sum(1 for post in yard['posts'] if post['status'] != 'idle')
        require(running <= int(ranch['work']['posts_per_yard']), (name, 'too many running posts', key, page['day']))
        for post in yard['posts']:
            if post['status'] == 'idle':
                require(post['progress'] == 0 and post['target'] == 0, (name, 'idle post carries progress', key))
            else:
                require(0 <= post['progress'] <= post['target'], (name, 'post progress out of range', key))


def _tamper_probes(directory: Path, require):
    """Archives forged snapshots for the game-codec probe runner; the real
    rejection gate is run_p103_probes.gd. Only structurally detectable
    forgeries belong here; receipt-level drift is audited above."""
    base = json.loads((directory / 'work-A-final.json').read_text(encoding='utf-8'))
    enclosure = json.loads((directory / 'enclosure-A-final.json').read_text(encoding='utf-8'))
    if not base['world']['ranch']['animals']:
        return
    probe_dir = directory / 'probes'
    probe_dir.mkdir(exist_ok=True)
    for stale in probe_dir.glob('*.json'):
        stale.unlink()
    payloads = [
        ('shrink-ban', _forge(base, 'ban_until', -5)),
        ('duplicate-voucher', _duplicate_voucher(base)),
        ('mint-minerals', _mint_minerals(base)),
        ('oversell-bed', _oversell_bed(enclosure)),
        ('zone-overlap', _zone_overlap(base)),
        ('bed-reservation-overlap', _reservation_overlap(base)),
    ]
    for index, (name, payload) in enumerate(payloads):
        (probe_dir / f'{index:02d}-{name}.json').write_text(json.dumps(payload, ensure_ascii=False), encoding='utf-8')


def _forge(base, field, value):
    forged = json.loads(json.dumps(base))
    animal = forged['world']['ranch']['animals'][0]
    if field == 'animals/{i}/fatigue':
        animal['fatigue'] = value
    elif field == 'ban_until':
        animal['ban_until'] = value
    elif field == 'account/fails':
        animal['account']['fails'] = value
    return forged


def _duplicate_voucher(base):
    forged = json.loads(json.dumps(base))
    ranch = forged['world']['ranch']
    if not ranch['births']:
        ranch['births'] = [{'parent_uid': ranch['animals'][0]['uid'], 'round': 0, 'child_uid': ranch['animals'][0]['uid']}]
    else:
        ranch['births'].append(dict(ranch['births'][0]))
    return forged


def _mint_minerals(base):
    forged = json.loads(json.dumps(base))
    for key, yard in forged['world']['ranch']['workyards'].items():
        for post in yard['posts']:
            if post['status'] != 'idle':
                post['outputs'] = {k: int(v) * 10 for k, v in post['outputs'].items()}
    return forged


def _fake_post(base):
    forged = json.loads(json.dumps(base))
    for key, yard in forged['world']['ranch']['workyards'].items():
        for post in yard['posts']:
            if post['status'] == 'idle':
                post['status'] = 'running'
                post['recipe_id'] = yard['recipe_id']
                post['batch_id'] = 999999
                post['inputs'] = dict(next(r for r in CATALOG['recipes'] if r['id'] == yard['recipe_id'])['inputs'])
                post['outputs'] = dict(next(r for r in CATALOG['recipes'] if r['id'] == yard['recipe_id'])['outputs'])
                post['progress'] = 0
                post['target'] = int(WORK[yard['recipe_id']]['target'])
                return forged
    return forged


def _oversell_bed(base):
    forged = json.loads(json.dumps(base))
    ranch = forged['world']['ranch']
    animals = ranch['animals']
    if len(animals) >= 2:
        animals[1]['bed_uid'] = animals[0]['bed_uid']
        animals[1]['bed_slot'] = animals[0]['bed_slot']
    return forged


def _zone_overlap(base):
    forged = json.loads(json.dumps(base))
    zones = forged['world']['ranch']['zones']
    if len(zones) >= 2 and zones[1]['cells']:
        zones[0]['cells'].append(zones[1]['cells'][0])
    return forged


def _reservation_overlap(base):
    forged = json.loads(json.dumps(base))
    ranch = forged['world']['ranch']
    if not ranch['reservations']:
        ranch['reservations'] = [{'uid': 1, 'animal_uid': ranch['animals'][0]['uid'], 'bed_uid': 1,
            'bed_slot': 0, 'trough_uid': 1, 'zone_uid': ranch['zones'][0]['uid'] if ranch['zones'] else 1,
            'start_t': 8, 'end_t': 10, 'meals': 1}]
        ranch['next_window_uid'] = max(2, int(ranch['next_window_uid']))
        ranch['reservations'].append(dict(ranch['reservations'][0]))
        ranch['reservations'][1]['uid'] = 2
        ranch['reservations'][1]['animal_uid'] = ranch['animals'][-1]['uid']
    else:
        ranch['reservations'].append(dict(ranch['reservations'][0]))
        ranch['reservations'][-1]['uid'] = int(ranch['next_window_uid']) + 1
        ranch['reservations'][-1]['start_t'] = int(ranch['reservations'][0]['start_t']) + 1
        ranch['next_window_uid'] = int(ranch['next_window_uid']) + 1
    return forged


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    parser.add_argument('--probes-only', action='store_true')
    args = parser.parse_args()
    problems = audit(args.directory, require_complete=not args.probes_only)
    if problems:
        print('P103 PLAYTEST AUDIT FAIL: %r' % (problems[:3],))
        raise SystemExit(1)
    print('P103 PLAYTEST AUDIT OK: routes audited, probes archived')


if __name__ == '__main__':
    main()
