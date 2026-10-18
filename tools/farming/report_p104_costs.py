"""Static replacement cost and short, identical-fixture service comparisons.
No scaffold inventory or pending production is treated as cash profit.
"""
import argparse
import hashlib
import json
from fractions import Fraction
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]


def report(folder):
    source=ROOT/'content/farming/p8/production.json'
    config=json.loads(source.read_text(encoding='utf-8'))
    resources={r['id']:r for r in config['resources']}
    baked=json.loads((ROOT/'content/farming/baked/p8/production.json').read_text(encoding='utf-8'))
    standards={r['id']:Fraction(r['standard_cost']['numerator'],r['standard_cost']['denominator']) for r in baked['resources']}
    facilities={r['id']:r for r in config['facilities']}
    def materials(items):
        return sum(resources[k]['buy_price']*v for k,v in items.items()) if all(resources[k]['buy_price']>0 for k in items) else None
    def standard(items): return round(float(sum(standards[k]*v for k,v in items.items())),4)
    capital={}
    for ident in ['soothing_station','toy_station','dispatch_station','woodshop']:
        item=facilities[ident]
        capital[ident]={'cash':item['cash'],'materials':item['materials'],
                        'market_material_cost_if_all_buyable':materials(item['materials']),
                        'standard_material_cost_including_unbuyable':standard(item['materials']),
                        'cash_plus_standard_material_cost':item['cash']+standard(item['materials'])}
    ball=next(r for r in config['recipes'] if r['id']=='make_vine_ball')
    samples={}
    for name in ['breeding','breeding-base','work','work-base']:
        data=json.loads((folder/name/'scenario.json').read_text(encoding='utf-8'))
        rows=[r for r in data['receipts'] if r.get('kind')=='service']
        birth=[r for r in rows if r['stage']=='birth_bonus']
        upkeep=data['closing']['world']['logistics']['spent']-data['opening']['world']['logistics']['spent']
        work=[r for r in rows if r['stage']=='work_progress']
        samples[name]={'days':data['closing']['clock']['total_days']-data['opening']['clock']['total_days'],
                       'fixture':True,'gu_upkeep_all_instances':upkeep,
                       'first_child_after_days':min((r['day']-data['opening']['clock']['total_days'] for r in birth),default=None),
                       'initial_growth_points':[r['gift'] for r in birth],
                       'work_units':len(work),'provided_work_points':sum(r['points'] for r in work),
                       'carry_used_points':sum(r['points'] for r in rows if r['stage']=='pool_use'),
                       'raw_overflow_points':sum(r['overflow'] for r in work),
                       'confirmed_pool_points':sum(r['points'] for r in data['closing']['world']['services']['pools'].values())}
    return {'kind':'p104-cost-comparison','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
            'one_time_facilities':capital,'ordinary_floor_per_cell':materials(config['rooms']['floor']['inputs']),
            'vine_ball':{'inputs':ball['inputs'],'market_replacement_input_cost':materials(ball['inputs']),
                         'days':ball['days'],'start_claim_ap':2,'install_ap':1,'daily_item_consumption':0},
            'mole':{'purchase_juvenile':8,'ordinary_breeding_days':8,'soothed_breeding_days':6,
                    'ordinary_growth_days':3,'full_contribution_initial_growth_percent':10,
                    'ordinary_enclosure_food_daily':{'mushroom':2,'clean_water':2},
                    'daily_food_standard_cost':standard({'mushroom':2,'clean_water':2}),
                    'mushroom_is_not_buyable':True,
                    'soothe_upkeep_daily':1},
            'short_samples':samples,
            'interpretation':['Short samples are explicitly scaffolded rule fixtures, not cash profitability.',
                              'A null market material cost means an ingredient is unbuyable, never free. Standard costs include production/AP/time allocations.',
                              'The current unlimited 8-stone juvenile purchase remains cheaper than breeding food and facilities.',
                              'A durable ball has no per-service material cost; recovery clipped at zero is not profit.',
                              'Carry saves previously wasted paid labor, never the raw input cost of the next batch.',
                              'No claim of increased product throughput is inferred from work points alone.']}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('root',type=Path)
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    text=json.dumps(report(args.root),ensure_ascii=False,indent=2)+'\n'
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(text,encoding='utf-8')
    else: print(text)


if __name__=='__main__': main()
