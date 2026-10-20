# -*- coding: utf-8 -*-
"""P10.6 static cost comparison (freeze §16.2.13): five comparison groups
built from the standard-cost tables and facility definitions. No scaffold
inventory or pending production counts as profit; unbuyable inputs use the
traced standard cost.
"""
import argparse
import hashlib
import json
from fractions import Fraction
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def report():
    source = ROOT / 'content/farming/p8/production.json'
    config = json.loads(source.read_text(encoding='utf-8'))
    baked = json.loads((ROOT / 'content/farming/baked/p8/production.json').read_text(encoding='utf-8'))
    resources = {r['id']: r for r in config['resources']}
    standards = {r['id']: Fraction(r['standard_cost']['numerator'], r['standard_cost']['denominator'])
                 for r in baked['resources']}
    facilities = {r['id']: r for r in config['facilities']}
    recipes = {r['id']: r for r in config['recipes']}

    def standard(items):
        return round(float(sum(standards[k] * v for k, v in items.items())), 4)

    def facility_cost(ident):
        row = facilities[ident]
        return {'cash': row['cash'], 'materials': row['materials'],
                'material_standard_cost': standard(row['materials']),
                'cash_plus_materials': row['cash'] + standard(row['materials'])}

    def model(model_id):
        row = next(m for m in config['cost_models'] if m['id'] == model_id)
        outputs = {k: int(v['quantity']) for k, v in row['outputs'].items()}
        return {'inputs': row['inputs'], 'input_standard_cost': standard(row['inputs']),
                'days': row['days'], 'ap': row['ap'], 'cash': row['cash'], 'outputs': outputs}

    water_capital = {}
    for ident in ['carp_harvest_station', 'oilfish_harvest_station', 'pearl_station', 'gel_station',
                  'coral_station', 'silt_processing_station', 'aquatic_crop_station', 'water_change_station',
                  'soothing_station']:
        water_capital[ident] = facility_cost(ident)
    fence = config['p106']['fence']
    water_capital['fish_fence_per_cell'] = {'cash': fence['cash'], 'materials': fence['inputs'],
                                            'ap_per_cell': fence['ap']}

    groups = {
        # ① Oil route: plant pressing versus the oilfin capture round, both
        # feeding the same refinery.
        'oil': {
            'press_oilseed_per_batch': model('press_oilseed'),
            'oilfin_round_per_4_animals': model('oilfin_round'),
            'refine_oil_per_batch': {'inputs': recipes['refine_oil']['inputs'],
                                     'input_standard_cost': standard(recipes['refine_oil']['inputs']),
                                     'outputs': recipes['refine_oil']['outputs'], 'days': recipes['refine_oil']['days']},
            'note': '油鳍鱼路线含育幼5日与捕捞消耗成体；种植路线按每批压榨。两条产出的粗油都走同一精炼。',
        },
        # ② Feed route: grass meal versus duckweed meal; plain versus
        # fish-meal blends.
        'feeds': {
            'mill_grass': {'inputs': recipes['mill_grass']['inputs'],
                           'input_standard_cost': standard(recipes['mill_grass']['inputs']),
                           'outputs': recipes['mill_grass']['outputs']},
            'mill_duckweed': {'inputs': recipes['mill_duckweed']['inputs'],
                              'input_standard_cost': standard(recipes['mill_duckweed']['inputs']),
                              'outputs': recipes['mill_duckweed']['outputs'],
                              'duckweed_standard_cost': float(standards['duckweed'])},
            'blend_water_feed_plain': {'inputs': recipes['blend_water_feed']['inputs'],
                                       'input_standard_cost': standard(recipes['blend_water_feed']['inputs']),
                                       'outputs': recipes['blend_water_feed']['outputs']},
            'blend_fish_water_feed': {'inputs': recipes['blend_fish_water_feed']['inputs'],
                                      'input_standard_cost': standard(recipes['blend_fish_water_feed']['inputs']),
                                      'outputs': recipes['blend_fish_water_feed']['outputs']},
            'blend_fish_land_feed': {'inputs': recipes['blend_fish_land_feed']['inputs'],
                                     'input_standard_cost': standard(recipes['blend_fish_land_feed']['inputs']),
                                     'outputs': recipes['blend_fish_land_feed']['outputs']},
        },
        # ③ Filter and mineral fillers: charcoal-sand versus coral, gravel
        # panels versus coral panels.
        'filters_minerals': {
            'make_filter_media': {'inputs': recipes['make_filter_media']['inputs'],
                                  'input_standard_cost': standard(recipes['make_filter_media']['inputs']),
                                  'outputs': recipes['make_filter_media']['outputs']},
            'make_coral_filter_media': {'inputs': recipes['make_coral_filter_media']['inputs'],
                                        'input_standard_cost': standard(recipes['make_coral_filter_media']['inputs']),
                                        'outputs': recipes['make_coral_filter_media']['outputs'],
                                        'coral_stone_standard_cost': float(standards['coral_stone'])},
            'assemble_stone_panel': {'inputs': recipes['assemble_stone_panel']['inputs'],
                                     'input_standard_cost': standard(recipes['assemble_stone_panel']['inputs']),
                                     'outputs': recipes['assemble_stone_panel']['outputs']},
            'assemble_coral_panel': {'inputs': recipes['assemble_coral_panel']['inputs'],
                                     'input_standard_cost': standard(recipes['assemble_coral_panel']['inputs']),
                                     'outputs': recipes['assemble_coral_panel']['outputs']},
            'grind_shell': {'inputs': recipes['grind_shell']['inputs'],
                            'input_standard_cost': standard(recipes['grind_shell']['inputs']),
                            'outputs': recipes['grind_shell']['outputs'],
                            'mussel_shell_standard_cost': float(standards['mussel_shell'])},
            'grind_coral': {'inputs': recipes['grind_coral']['inputs'],
                            'input_standard_cost': standard(recipes['grind_coral']['inputs']),
                            'outputs': recipes['grind_coral']['outputs']},
            'mineral_loop_note': '珊瑚石2制石粉2而一轮采礁消耗石粉3：基础转换有损，无外部投入不能无限增发。',
        },
        # ④ Compost: straw versus reed versus the loach batch.
        'compost': {
            'compost_straw': {'inputs': recipes['compost_straw']['inputs'],
                              'input_standard_cost': standard(recipes['compost_straw']['inputs']),
                              'outputs': recipes['compost_straw']['outputs']},
            'compost_reed': {'inputs': recipes['compost_reed']['inputs'],
                             'input_standard_cost': standard(recipes['compost_reed']['inputs']),
                             'outputs': recipes['compost_reed']['outputs'],
                             'reed_stalk_standard_cost': float(standards['reed_stalk'])},
            'loach_batch': {'inputs': recipes['silt_process']['inputs'],
                            'input_standard_cost': standard(recipes['silt_process']['inputs']),
                            'outputs': recipes['silt_process']['outputs'],
                            'plus': '每完成批次一次至多8格×8点水质改善；单条泥鳅无法抵消16格水体衰减（见回放）',
                            'humus_standard_cost': float(standards['humus'])},
        },
        # ⑤ Species rounds and the spirit opportunity cost.
        'rounds_and_spirit': {
            'carp': model('fish'), 'oilfin': model('oilfin_round'), 'pearl': model('pearl_round'),
            'gel': model('gel_round'), 'coral': model('coral_round'), 'mussel_shell': model('mussel_shell'),
            'spirit_pearl_variant': {
                'extra_inputs': {'stone_powder': 1, 'spirit_liquid': 1},
                'extra_standard_cost': standard({'stone_powder': 1, 'spirit_liquid': 1}),
                'extra_output': 1, 'spirit_liquid_sell': resources['spirit_liquid']['sell_price'],
                'opportunity_note': '灵液变体每轮多产1珠；直接出售灵液的机会成本按灵液售价计。'},
            'spirit_gel_variant': {
                'extra_inputs': {'clean_water': 1, 'spirit_liquid': 1},
                'extra_standard_cost': standard({'clean_water': 1, 'spirit_liquid': 1}),
                'extra_output': 1, 'water_gel_sell': resources['water_gel']['sell_price']},
        },
        # Shared gu economics.
        'shared_gu': {
            'product_yield_gu': {'market_price': 32, 'daily_fee': 1, 'effect': '主产物期望+25%',
                                 'break_even_note': '按物种主产物标准成本折算回本批次；小规模高维护不一定合算。'},
            'feed_saving_gu': {'market_price': 32, 'daily_fee': 1, 'effect': '基础食物−25%',
                               'break_even_note': '每4份基础粮省1份；省下的是最便宜的一档，回本依赖大存栏。'},
            'voucher': {'best_case': '完整育幼贡献10%首轮进度', 'cost': '目标区需持续运行丰养蛊（1元石/日）'},
        },
    }
    return {
        'kind': 'p106-cost-comparison',
        'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'water_capital': water_capital,
        'groups': groups,
        'standard_cost_reference': {k: str(v) for k, v in
                                    (('crude_oil', standards['crude_oil']), ('fish_meat', standards['fish_meat']),
                                     ('pearl', standards['pearl']), ('water_gel', standards['water_gel']),
                                     ('coral_stone', standards['coral_stone']), ('duckweed', standards['duckweed']),
                                     ('reed_stalk', standards['reed_stalk']), ('fish_meal', standards['fish_meal']),
                                     ('water_retaining_matrix', standards['water_retaining_matrix']),
                                     ('mussel_shell', standards['mussel_shell']))},
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', default=str(ROOT / 'docs/farming/phase106-costs.json'))
    args = parser.parse_args()
    data = report()
    Path(args.out).write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'P106 COST REPORT OK -> {args.out}')


if __name__ == '__main__':
    main()
