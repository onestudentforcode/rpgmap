"""P10.7 stage and physical barter contracts; independent of market sell values."""
from fractions import Fraction

from bake_v1 import integer, quantities, registry, require


def market_exchange_certificate(resources, offers):
    """Positive rational potential for cash, buy/sell and all free exchanges.

    Cash has weight 1. Selling cannot raise potential; purchasable resources
    cannot cost more potential than their purchase price. Repeated swaps are
    checked together, rather than pricing each swap by its market sale value.
    Production still consumes AP/time and is intentionally outside this graph.
    """
    weights = {k: Fraction(max(1, row['sell_price'])) for k, row in resources.items()}
    require(all(len(o['give']) == 1 for o in offers), 'certificate needs one specialty per offer')
    for _ in range(1000):
        changed = False
        for row in offers:
            item, count = next(iter(row['give'].items()))
            needed = sum(weights[k] * n for k, n in row['receive'].items()) / count
            if needed > weights[item]:
                weights[item] = needed
                changed = True
        require(all(not r['buy_price'] or weights[k] <= r['buy_price'] for k, r in resources.items()),
                'zero-AP market/exchange amplification risk')
        if not changed:
            return {k: str(v) for k, v in weights.items()}
    raise ValueError('zero-AP exchange potential did not converge; inspect multi-step cycle')


def validate(source):
    cfg = source['p107']
    resources = registry(source['resources'], 'resources')
    research = registry(source['research'], 'research')
    facilities = registry(source['facilities'], 'facilities')
    gu = registry(source['logistics']['definitions'], 'gu')
    require(cfg['version'] == 1 and len(cfg['stage_names']) == 4, 'P107 four global stages')
    events = registry(cfg['events'], 'stage events')
    require(len(events) == 3, 'P107 three transitions')
    previous = 0
    for index, event in enumerate(events.values()):
        quantities(event['inputs'], resources, event['id'], True)
        require(integer(event['orders']), 'stage order threshold')
        if index < 2:
            require(event['orders'] > previous and not event['inputs'], 'early cumulative supply milestones')
            previous = event['orders']
        else:
            require(event['inputs'] and event['orders'] == 0, 'advanced physical resource milestone')
    for kind, known in [('research', research), ('facility', facilities), ('gu', gu)]:
        require(set(cfg['gates'][kind]) <= set(known), f'unknown {kind} stage gate')
        require(all(integer(v, 0, 3) for v in cfg['gates'][kind].values()), 'stage gate range')
    require(set(cfg['gates']['research']) == set(research), 'all research needs an explicit stage')
    for row in research.values():
        require(all(cfg['gates']['research'][p] <= cfg['gates']['research'][row['id']]
                    for p in row['prerequisites']), 'research requires a later-stage prerequisite')
    # Positive potential is a certificate that arbitrary repetitions of the
    # zero-AP exchanges alone cannot manufacture resources. It is NOT a price,
    # payment currency, market valuation or automatic quotation rule.
    offers = registry(cfg['offers'], 'barter offers')
    require(offers, 'barter list is empty')
    for row in offers.values():
        require(integer(row['stage'], 0, 3), 'barter stage')
        quantities(row['give'], resources, row['id'])
        quantities(row['receive'], resources, row['id'])
        require(set(row['give']).isdisjoint(row['receive']), 'barter gives and receives same resource')
        require(all(resources[i]['buy_price'] == 0 for i in row['give']), 'barter tokens must be produced specialties')
    weights = {i: Fraction(1, 10) for i in resources}
    weights['resin'] = Fraction(1)
    for row in cfg['offers']:
        if set(row['receive']) == {'resin'} and len(row['give']) == 1:
            item, amount = next(iter(row['give'].items()))
            weights[item] = max(weights[item], Fraction(row['receive']['resin'], amount))
    for row in offers.values():
        before = sum(weights[i] * n for i, n in row['give'].items())
        after = sum(weights[i] * n for i, n in row['receive'].items())
        require(after <= before, f'{row["id"]}: exchange-only amplification cycle risk')
    for item in cfg['events'][2]['inputs']:
        require(any(item in row['receive'] and row['stage'] <= 2 for row in offers.values()),
                f'{item}: specialization route locked behind its own event')
    market_certificate = market_exchange_certificate(resources, list(offers.values()))
    return {'events': len(events), 'offers': len(offers),
            'market_exchange_potential': market_certificate,
            'exchange_potential': {i: str(weights[i]) for i in sorted({i for o in offers.values() for i in [*o['give'], *o['receive']]})}}
