# -*- coding: utf-8 -*-
"""P10.5 module auditor: replays the partition evidence in
.art-work/p105-playtest and checks the phase-doc §14 invariants against the
receipts and per-day pages. Read-only on evidence: failures never rewrite the
files. Codec forgery probes live in the P105 model suite, not here.
"""
import argparse
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = json.loads((ROOT / 'content/farming/baked/p8/production.json').read_text(encoding='utf-8'))
CONFIG = CATALOG['p103']
NATURAL = {sid: row.get('natural', {}) for sid, row in CONFIG['species'].items()}
WORK = CONFIG['work']['recipes']
RECIPES = {row['id']: row for row in CATALOG['recipes']}
SCENARIOS = ['mode-migration', 'intensive-fatigue', 'silkworm-chain',
             'liquid-outlet', 'carbon-compost', 'mineral-shell']


def read_lines(path: Path):
    return [json.loads(line) for line in path.read_text(encoding='utf-8').splitlines()]


def audit(directory: Path):
    problems = []

    def require(condition, message):
        if not condition:
            problems.append(message)

    summary = json.loads((directory / 'summary.json').read_text(encoding='utf-8'))
    require(sorted(summary['routes']) == sorted(SCENARIOS), ('scenarios', sorted(summary['routes'])))
    for name in SCENARIOS:
        days = read_lines(directory / f'{name}-days.jsonl')
        receipts = read_lines(directory / f'{name}-receipts.jsonl')
        final = json.loads((directory / f'{name}-final.json').read_text(encoding='utf-8'))
        _audit_scenario(name, days, receipts, final, require)
    return problems


def _audit_scenario(name, days, receipts, final, require):
    animals = {}
    rounds_opened = {}
    rounds_claimed = set()
    batches_opened = {}
    batches_claimed = set()
    meal_totals = Counter()
    claimed_outputs = {}
    opened_recipes = set()
    work_units = {}
    sales = set()

    for row in receipts:
        kind, stage = row.get('kind'), row.get('stage')
        if kind == 'ranch:animal' and stage == 'purchase':
            for uid in row['animals']:
                animals[uid] = {'species': row['species'], 'day': row['day'], 'spent': row['total']}
        elif kind == 'ranch:animal' and stage == 'death':
            require(row['animal'] in animals, (name, 'death of unknown animal', row))
            animals.pop(row['animal'], None)
        elif kind == 'ranch:natural' and stage == 'round_start':
            key = (row['animal'], int(row['round']))
            require(key not in rounds_opened, (name, 'round feed paid twice', key))
            rounds_opened[key] = row
        elif kind == 'ranch:natural' and stage == 'claim':
            for uid in row['animals']:
                key = (uid, 'claimed')
                require(key not in rounds_claimed, (name, 'double natural claim', uid))
                rounds_claimed.add(key)
            for item, qty in row['outputs'].items():
                claimed_outputs[item] = claimed_outputs.get(item, 0) + int(qty)
        elif kind == 'ranch:workyard' and stage == 'batch_open':
            key = (row['workyard'], int(row['batch_id']))
            require(key not in batches_opened, (name, 'duplicate batch id', key))
            batches_opened[key] = row
            opened_recipes.add(row['recipe'])
            definition = RECIPES.get(row['recipe'])
            require(definition is not None, (name, 'unknown work recipe', row['recipe']))
            if definition:
                require({k: int(v) for k, v in row['inputs'].items()} == {k: int(v) for k, v in definition['inputs'].items()},
                        (name, 'batch inputs rewritten', key))
        elif kind == 'ranch:workyard' and stage == 'claim':
            pending = [k for k in batches_opened if k[0] == row['workyard'] and k not in batches_claimed]
            require(len(pending) >= int(row['posts']), (name, 'claim without opened batches', row['day']))
            for key in sorted(pending, key=lambda k: batches_opened[k]['day'])[:int(row['posts'])]:
                batches_claimed.add(key)
        elif kind == 'ranch:work' :
            work_units[(row['day'], row['animal'])] = work_units.get((row['day'], row['animal']), 0) + 1
        elif kind == 'ranch:window' and stage == 'success':
            for item, qty in row['inputs'].items():
                meal_totals[item] += int(qty)

    # Work units on the day pages must match the unit receipts exactly:
    # ghost work or unbilled effort both fail.
    for page in days:
        for animal in page['animals']:
            expected = work_units.get((page['day'], animal['uid']), 0)
            require(int(animal['account']['w']) == expected,
                    (name, 'work units differ from receipts', page['day'], animal['uid']))

    # Final running posts equal the unclaimed opens.
    running = 0
    for key, yard in final['world']['ranch']['workyards'].items():
        for post in yard['posts']:
            if post['status'] != 'idle':
                running += 1
    require(running == len(batches_opened) - len(batches_claimed),
            (name, 'final running posts differ from unclaimed opens', running, len(batches_opened) - len(batches_claimed)))

    # Fatigue recursion from the service receipts: the opening value, the day
    # accounts and the toy recovery must reproduce the recorded next value,
    # and the day page must carry exactly that next value.
    fatigue_receipts = {}
    for row in receipts:
        if row.get('kind') == 'service' and row.get('stage') == 'fatigue':
            fatigue_receipts[(int(row['day']), int(row['animal']))] = row
    page_fatigue = {}
    for page in days:
        for animal in page['animals']:
            page_fatigue[(page['day'], animal['uid'])] = int(animal['fatigue'])
    for key, row in fatigue_receipts.items():
        expected = max(0, min(100, int(row['open']) + int(row['w']) - 2 * int(row['r'])
                              + 12 * int(row['fails']) - int(row['toy_extra'])))
        require(int(row['next']) == expected, (name, 'fatigue recursion broken', key, row['next'], expected))
        require(page_fatigue.get(key) == int(row['next']),
                (name, 'day page fatigue differs from the service receipt', key))

    # Final snapshot coherence with the last day page.
    if days:
        last = {row['uid']: row for row in days[-1]['animals']}
        for animal in final['world']['ranch']['animals']:
            if animal['uid'] in last:
                require(int(animal['fatigue']) == int(last[animal['uid']]['fatigue']),
                        (name, 'final fatigue differs from the last page', animal['uid']))
                require(int(animal['natural']['units']) <= int(last[animal['uid']]['natural']['units']),
                        (name, 'final round progress grew outside settle', animal['uid']))

    # Per-scenario invariants from the phase doc §14.
    roster = {row['uid']: row for row in final['world']['ranch']['animals']}
    if name == 'mode-migration':
        require(any(row['species_id'] == 'steel_sheep' and row['mode'] == 'enclosure' and int(row['natural']['units']) >= 0
                    for row in roster.values()), (name, 'migration ends with a breeding sheep'))
        require(rounds_claimed, (name, 'wool round claimed through the station'))
    if name == 'intensive-fatigue':
        require(final['inventory'].get('silk', 0) >= 12, (name, 'silk batch delivered'))
    if name == 'silkworm-chain':
        require(final['inventory'].get('filter_media', 0) >= 3, (name, 'filter media consumed the silk'))
        require(final['inventory'].get('silk', 0) >= 7, (name, 'homegrown silk delivered'))
        for row in roster.values():
            if row['species_id'] == 'leaf_silkworm':
                require(int(row['breed']['units']) == 0 and int(row['breed']['round']) == 0,
                        (name, 'silkworm never carries breed progress'))
        require(not final['world']['ranch']['births'], (name, 'silkworm scenario has no births at all'))
    if name == 'liquid-outlet':
        consumers = [rid for rid, r in RECIPES.items() if 'spirit_liquid' in r['inputs']]
        require(not consumers, (name, 'spirit liquid gained a crafting consumer', consumers))
        require(final['inventory'].get('mucus', 0) >= 2, (name, 'mucus co-product delivered'))
        # Nothing crafts with it, so any stock below the claimed amount left
        # through the market sale.
        claimed = claimed_outputs.get('spirit_liquid', 0)
        require(claimed >= 4 and final['inventory'].get('spirit_liquid', 0) < claimed,
                (name, 'spirit liquid did not leave through the market', claimed, final['inventory'].get('spirit_liquid', 0)))
    if name == 'carbon-compost':
        require(final['inventory'].get('charcoal', 0) >= 4, (name, 'biochar delivered'))
        require(final['inventory'].get('humus', 0) >= 5, (name, 'compost delivered'))
    if name == 'mineral-shell':
        require(final['inventory'].get('composite_stone_panel', 0) >= 6, (name, 'both panel variants delivered'))
        require('form_rock_shell' in opened_recipes, (name, 'shell batch opened'))

    # Ledger sanity: claimed batch outputs never exceed the opened recipe.
    for key in batches_claimed:
        definition = RECIPES.get(batches_opened[key]['recipe'])
        if definition:
            require(set(definition['outputs']) == set(batches_opened[key]['outputs']),
                    (name, 'claimed outputs rewritten', key))
    return


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', nargs='?', default='.art-work/p105-playtest')
    args = parser.parse_args()
    problems = audit(ROOT / args.directory)
    for problem in problems:
        print('AUDIT FAIL:', problem)
    if problems:
        raise SystemExit(1)
    print('P105 AUDIT OK')


if __name__ == '__main__':
    main()
