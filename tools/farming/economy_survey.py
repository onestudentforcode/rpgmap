# -*- coding: utf-8 -*-
"""P10.7 pre-investigation: one-shot economy health survey over the P8 catalog.

Reads the baked standard costs (the same numbers the game and the supply
orders use) plus the source definitions and prints six sections:
  A  per-resource ledger (standard cost vs buy vs sell vs supply value)
  B  recipe margins and parallel-route dominance
  C  species round economics (incl. capture vs buy-and-raise)
  D  raw buy->sell flips and buy-input->sell-output arbitrage
  E  research/unlock timeline (cumulative stones/days, content per node)
  F  capital and recurring fixed costs (facilities, gu, water module)

Nothing here changes game data; this is discussion material for P10.7.
"""
import json
from fractions import Fraction
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = json.loads((ROOT / 'content/farming/p8/production.json').read_text(encoding='utf-8'))
BAK = json.loads((ROOT / 'content/farming/baked/p8/production.json').read_text(encoding='utf-8'))

RES = {r['id']: r for r in BAK['resources']}
SRC_RES = {r['id']: r for r in SRC['resources']}
RECIPES = {r['id']: r for r in SRC['recipes']}
FACILITIES = {r['id']: r for r in SRC['facilities']}
CROPS = {r['id']: r for r in SRC['crops']}
LIVESTOCK = {r['id']: r for r in SRC['livestock']}
RESEARCH = {r['id']: r for r in SRC['research']}
MODELS = {m['id']: m for m in SRC['cost_models']}
ORDERS = SRC['orders']


def scost(item):
    row = RES[item]
    frac = Fraction(row['standard_cost']['numerator'], row['standard_cost']['denominator'])
    return frac


def scostf(item):
    return float(scost(item))


def val_of(outputs):
    """Market sale value of an output map."""
    return sum(RES[k]['sell_price'] * v for k, v in outputs.items())


def cost_of(inputs):
    return sum(scost(k) * v for k, v in inputs.items())


def cash(n):
    return float(n)


print('=' * 78)
print('A  PER-RESOURCE LEDGER  (84 resources)')
print('=' * 78)
flags = []
for rid in sorted(RES):
    r = RES[rid]
    sc = scostf(rid)
    buy, sell, supply = r['buy_price'], r['sell_price'], r['supply_value']
    tag = []
    if sell > 0 and sc > 0 and sell > sc * 2:
        tag.append('SELL>2x_COST')
    if sell > 0 and sc > 0 and sell < sc * 0.4:
        tag.append('SELL<0.4xCOST')
    if buy > 0 and sc > 0 and buy > sc * 3:
        tag.append('BUY>3x_COST')
    if r['supply_allowed'] and supply > 0 and sell > 0 and supply > sell * 1.5:
        tag.append('SUPPLY>>SELL')
    if tag:
        flags.append((rid, sc, buy, sell, supply, tag))
print(f'flagged {len(flags)} of {len(RES)}:')
for rid, sc, buy, sell, supply, tag in flags:
    print(f'  {rid:28s} cost={sc:8.2f} buy={buy:3d} sell={sell:3d} supply={supply:3d} {" ".join(tag)}')

print()
print('=' * 78)
print('B  RECIPE MARGINS  (input standard cost vs output sale value)')
print('=' * 78)
rows = []
for rid, r in RECIPES.items():
    in_cost = cost_of(r['inputs'])
    out_val = val_of(r['outputs'])
    ap = r.get('start_ap', 0) + r.get('claim_ap', 0)
    margin = out_val - cash(in_cost)
    ratio = (out_val / float(in_cost)) if in_cost else None
    rows.append((rid, r['facility'], float(in_cost), out_val, margin, ratio, ap, r.get('days', 0)))
rows.sort(key=lambda x: x[4])
print('lowest margins (candidates for dead content):')
for rid, fac, ic, ov, m, ratio, ap, days in rows[:12]:
    print(f'  {rid:26s} {fac:20s} in={ic:7.2f} out={ov:5.1f} margin={m:+8.2f} ratio={ratio:.2f} ap={ap} days={days}')
print('highest margins (candidates for money printers):')
for rid, fac, ic, ov, m, ratio, ap, days in rows[-10:]:
    print(f'  {rid:26s} {fac:20s} in={ic:7.2f} out={ov:5.1f} margin={m:+8.2f} ratio={ratio:.2f} ap={ap} days={days}')

print()
print('parallel routes (same primary output):')
groups = {}
for rid, r in RECIPES.items():
    for out in r['outputs']:
        groups.setdefault(out, []).append(rid)
for out, rids in sorted(groups.items()):
    if len(rids) > 1:
        print(f'  {out}:')
        for rid in sorted(rids):
            r = RECIPES[rid]
            ic, ov = cost_of(r['inputs']), val_of(r['outputs'])
            print(f'    {rid:26s} in={float(ic):7.2f} out={ov:5.1f} margin={ov-float(ic):+8.2f} on {r["facility"]}')

print()
print('=' * 78)
print('C  SPECIES ROUNDS  (cost model view, x4 population)')
print('=' * 78)
for mid in ['wool', 'silk_round', 'dew_round', 'scale_round', 'fish', 'oilfin_round', 'pearl_round', 'gel_round', 'coral_round', 'mussel_shell']:
    if mid not in MODELS:
        continue
    m = MODELS[mid]
    ic = cost_of(m['inputs']) + m['cash']
    ov = sum(RES[k]['sell_price'] * int(v['quantity']) for k, v in m['outputs'].items())
    days = m['days']
    print(f'  {mid:14s} in={float(ic):8.2f} sell={ov:5.1f} margin={ov-float(ic):+8.2f} days={days} per4pop')

print()
print('=' * 78)
print('D  RAW FLIPS & ARBITRAGE')
print('=' * 78)
flips = [(rid, r['buy_price'], r['sell_price']) for rid, r in RES.items()
         if r['buy_price'] > 0 and r['sell_price'] > 0]
profitable = [f for f in flips if f[2] > f[1]]
print(f'resellable items: {len(flips)}, buy<sell flips: {len(profitable)}')
for rid, buy, sell in profitable:
    print(f'  {rid:28s} buy={buy} sell={sell} (+{sell-buy})')
arb = []
for rid, r in RECIPES.items():
    buy_in = sum(RES[k]['buy_price'] * v for k, v in r['inputs'].items())
    if buy_in == 0:
        continue
    out_val = val_of(r['outputs'])
    if out_val > buy_in:
        arb.append((rid, buy_in, out_val, out_val - buy_in))
print(f'recipes profitable from BOUGHT inputs alone: {len(arb)}')
for rid, bi, ov, m in sorted(arb, key=lambda x: -x[3])[:12]:
    print(f'  {rid:26s} bought_in={bi:4d} out_sell={ov:5.1f} margin={m:+7.1f}')

print()
print('=' * 78)
print('E  RESEARCH / UNLOCK TIMELINE')
print('=' * 78)
by_layer = {}
for rid, r in RESEARCH.items():
    by_layer.setdefault(r['layer'], []).append(rid)
cum_fee = cum_days = 0
order = []
layer_of = {rid: r['layer'] for rid, r in RESEARCH.items()}
pending = set(RESEARCH)
done = set()
while pending:
    ready = sorted(r for r in pending if set(RESEARCH[r]['prerequisites']) <= done)
    if not ready:
        break
    for rid in ready:
        r = RESEARCH[rid]
        cum_fee += r['fee']
        cum_days += r['days']
        unlocks = r['unlocks']
        content = (len(unlocks['facilities']), len(unlocks['recipes']), len(unlocks['species']), len(unlocks['diets']))
        order.append((rid, r['layer'], r['fee'], cum_fee, cum_days, content))
        done.add(rid)
    pending -= set(ready)
print(f'{"node":26s} layer fee cum_fee cum_days  fac rec spe diet')
for rid, layer, fee, cf, cd, (f, rc, s, dt) in order:
    print(f'{rid:26s} {layer:5d} {fee:3d} {cf:6d} {cd:7d}  {f:3d} {rc:3d} {s:3d} {dt:3d}')
zero_research_fac = [fid for fid, f in FACILITIES.items() if not f.get('research')]
zero_research_rec = [rid for rid, r in RECIPES.items() if not r.get('research')]
print(f'day-0 facilities (no research): {len(zero_research_fac)} -> {", ".join(sorted(zero_research_fac))}')
print(f'day-0 recipes (no research): {len(zero_research_rec)}')
locked_species = [(sid, s.get('research')) for sid, s in LIVESTOCK.items() if s.get('research')]
print(f'species gates: {locked_species}')

print()
print('=' * 78)
print('F  CAPITAL & RECURRING')
print('=' * 78)
for fid in ['pen', 'feed_trough', 'small_bed', 'carp_harvest_station', 'oilfish_harvest_station',
            'pearl_station', 'gel_station', 'coral_station', 'silt_processing_station',
            'aquatic_crop_station', 'water_change_station', 'soothing_station', 'dispatch_station',
            'farm_processor', 'woodshop', 'compost_bin', 'char_kiln', 'purifying_bed', 'algae_tank', 'kitchen']:
    f = FACILITIES[fid]
    mat = float(cost_of(f['materials']))
    print(f'  {fid:26s} cash={f["cash"]:3d} materials_std={mat:6.2f} total={f["cash"]+mat:7.2f} research={f.get("research","")}')
print(f'  fence/cell: {SRC["p106"]["fence"]["cash"]} + twig1, ap={SRC["p106"]["fence"]["ap"]}')
print(f'  gu market: product/feed 32 each, 1 stone/day; soothe/command 1/day')
print(f'  supply order: base_demand={ORDERS["base_demand"]} premium={ORDERS["premium_percent"]}% paths={ORDERS["paths"]}')
print(f'  rank unlock revenue thresholds: {ORDERS["rank_unlock_revenue"]}')
