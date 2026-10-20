"""Deterministic current-config economic report; never changes game values.

Uses steady/capture runtime providers and audited external replay receipts.
Standard-cost comparisons and actual cash accounts are kept separate.
"""
import argparse
from collections import Counter
from fractions import Fraction
import hashlib
import json
import math
from pathlib import Path

from audit_p107_playtest import CASES, ROOT, audit_case
from bake_p8 import providers
from validate_p107 import validate

ROLES = {
    'steel_sheep': ('经济＋材料', '钢绒用于出售/供货，副产粪肥回流；提高主产物而不改房间倍率。'),
    'leaf_silkworm': ('经济＋滤材', '蚕丝直售、丝质滤材或特色交换；桑叶种植路线支持持续投入，本期不繁殖。'),
    'dew_shell_snail': ('材料＋交易', '灵液供水产变体，黏液供建材；允许低价副产物回收，灵液可换松脂。'),
    'mineral_scale_lizard': ('材料＋特色交换', '鳞片/蜕皮供鳞甲板；直售偏弱，阶段2以2鳞片换4松脂提供可用的材料/现金出口。'),
    'filter_algae_carp': ('食材＋交易', '捕捞鱼肉接供货、鱼粉与陆地饲料替代；每轮重补动物。'),
    'oilfin_fish': ('油料＋食材', '谷粒默认投料取粗油并附鱼肉；捕捞重计育幼和购幼。与植物油路线共享精炼终点。'),
    'pearl_mussel': ('经济＋功能材料', '留栏取珠可直售/交换；珍珠用于研究、精滤，取壳是单独消耗成体的选择。'),
    'gel_jellyfish': ('功能材料＋交易', '凝水胶做保水基质或交换；已有正向留栏产出，不另改能力。'),
    'reef_coral': ('滤材/建材＋特色交换', '珊瑚供制粉、多孔滤材和石板；直售偏弱，2珊瑚石换3松脂，3日轮减少生产等待。'),
}
DECISIONS = {
    'water_retaining_matrix': '保留：浮萍/芦苇每轮替代腐殖土；当前单位标准成本低于腐殖土。无额外保水倍率。',
    'filter_media': '基础炭砂为通用路线；丝质与珊瑚路线每批3件，适合已有对应副产物的基地；比较等量产物和各自前置。',
    'composite_stone_panel': '保留补光灯及1:1建造替代。壳板等支路利用动物副产物；普通石板前置原料普遍、但配方耗时2日。',
    'pollen': '保留蜂群协作一次性研究用途和低价回收。少量副产物无需强加高频盈利出口；交换花源样本可支持专精。',
    'reclaimed_fill': '保留已有2:1替代建造用原石；不是无用途终点，也不是P10.7新增功能。按尾砂/炉渣回收场景评价。',
    'coral_stone': '保留专属滤材/制粉/板材与特色交换；不要求直接出售覆盖全部成本。',
    'mineral_scale': '保留材料、合法金行供货资格及特色交换；不伪造新的工业订单或提高供养值充当加价。',
    'pearl': '保留直售/交换、研究、精滤；取珠和取壳成本分开，不把贝壳算成每轮副产物。',
    'crude_oil': '动物取油提供高吞吐及鱼肉，植物榨油附油饼、可服务饲料链；同一精炼配方共用，捕捞另计补幼。',
}


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def report(evidence):
    source = read(ROOT / 'content/farming/p8/production.json')
    baked = read(ROOT / 'content/farming/baked/p8/production.json')
    encycl = read(ROOT / 'content/farming/baked/encyclopedia/encyclopedia.json')
    resources = {r['id']: r for r in baked['resources']}
    animals = {r['id']: r for r in source['livestock']}
    facilities = {r['id']: r for r in source['facilities']}
    costs = {k: Fraction(r['standard_cost']['numerator'], r['standard_cost']['denominator']) for k, r in resources.items()}
    settings = source['p103']
    runtime = providers(source)
    certified = validate(source)
    capture_path = ROOT / '.art-work/p107-tests/capture-costs.json'
    capture_observations = read(capture_path)
    assert {r['species'] for r in capture_observations} == {'filter_algae_carp', 'oilfin_fish'}
    for observation in capture_observations:
        provider = runtime[observation['species'] + '_provider']
        assert observation['inputs'] == provider['inputs'] and observation['days'] == provider['days']
        assert observation['cash'] == provider['cash'] and observation['assignment_ap'] == provider['start_ap'] and observation['claim_ap'] == provider['claim_ap']
    quote_path = ROOT / '.art-work/p107-tests/contract-quotes.json'
    quotes = read(quote_path)
    expected_vectors = {(r['id'], p, rank, demand) for r in resources.values() if r['supply_allowed']
                        for p in source['orders']['paths'] for rank in range(1, 6)
                        for demand in (1, source['orders']['base_demand'] * rank)}
    assert len(quotes) == len(expected_vectors)
    assert {(r['item'], r['path'], r['rank'], r['demand']) for r in quotes} == expected_vectors
    for row in quotes:
        item, quote = resources[row['item']], row['quote']
        allowed = item['element'] == row['path']
        assert quote['ok'] == allowed
        if not allowed: continue
        quantity = (row['demand'] + item['supply_value'] - 1) // item['supply_value']
        base = quantity * item['sell_price']
        expected = {'quantity': quantity, 'provided': quantity * item['supply_value'], 'base': base,
                    'premium': base * source['orders']['premium_percent'] // 100,
                    'payout': base + base * source['orders']['premium_percent'] // 100}
        assert all(quote[key] == value for key, value in expected.items()), row

    def value(items): return sum(resources[k]['sell_price'] * v for k, v in items.items())
    def cost(items): return sum((costs[k] * v for k, v in items.items()), Fraction())
    def purchase(items):
        return sum(resources[k]['buy_price'] * v for k, v in items.items()) if all(resources[k]['buy_price'] > 0 for k in items) else None
    def timing(row): return row['days'] * source['config']['day_weight'] + (row['start_ap'] + row['claim_ap']) * source['config']['ap_weight']
    def resin_out(items):
        remaining = dict(items)
        resin = 0
        trades = []
        for offer in source['p107']['offers']:
            if set(offer['receive']) != {'resin'} or len(offer['give']) != 1: continue
            item, count = next(iter(offer['give'].items()))
            batches = remaining.get(item, 0) // count
            if batches:
                remaining[item] -= batches * count
                resin += batches * offer['receive']['resin']
                trades.append({'offer': offer['id'], 'batches': batches})
        return resin, remaining, trades

    rows = []
    for sid, (role, purpose) in ROLES.items():
        animal = animals[sid]
        species = settings['species'][sid]
        natural = species['natural']
        provider = runtime[sid if sid == 'steel_sheep' else sid + '_provider']
        growing = math.ceil(species['growth_units'] / 600)
        production = math.ceil(natural['units'] / 600)
        base = next(d for d in animal['base_diets'] if d['id'] == animal['default_base_diet'])
        establishment = {k: v * (growing + 1) * 4 for k, v in base['inputs'].items()}
        capture = natural.get('capture', False)
        std = cost(provider['inputs']) + provider['cash'] + timing(provider)
        extra = Fraction(0) if capture else cost(establishment) + animal['juvenile_price'] * 4 + growing + 1 + settings['ap']['submit']
        resin, leftover, trades = resin_out(provider['outputs'])
        exchange_revenue = resin * resources['resin']['sell_price'] + value(leftover)
        space = 4 * species['space']
        station_count = math.ceil(space / settings['stations'][natural['station']]['capacity'])
        rows.append({'species': sid, 'name': animal['name'], 'role': role, 'purpose': purpose,
                     'mode': 'capture-repeat' if capture else 'retained-steady', 'population': 4,
                     'growth_days': growing, 'production_days': production, 'provider': provider,
                     'first_transfer_days': 1, 'first_assignment_ap': settings['ap']['submit'],
                     'total_space': space, 'station_count': station_count,
                     'initial_extra_inputs': establishment, 'initial_extra_cash': animal['juvenile_price'] * 4,
                     'standard_round_cost': float(std), 'first_round_standard_cost': float(std + extra),
                     'sale_revenue': value(provider['outputs']), 'direct_screening_margin': float(value(provider['outputs']) - std),
                     'exchange_resin': resin, 'exchange_remainder': leftover, 'exchange_transactions': trades,
                     'exchange_sale_revenue': exchange_revenue, 'exchange_screening_margin': float(exchange_revenue - std),
                     'direct_purchase_inputs_cash': purchase(provider['inputs'])})

    comparisons = []
    ids = ('make_filter_media', 'make_silk_filter_media', 'make_coral_filter_media',
           'assemble_stone_panel', 'assemble_mucus_panel', 'assemble_scale_panel', 'assemble_shell_panel', 'assemble_coral_panel',
           'grind_coral', 'grind_shell', 'make_water_retaining_matrix', 'recover_fill', 'smelt_charcoal', 'smelt_resin', 'smelt_concentrate')
    for recipe in source['recipes']:
        if recipe['id'] not in ids: continue
        recipe_cost = cost(recipe['inputs']) + recipe['start_ap'] + recipe['claim_ap'] + recipe['days']
        total_output = sum(recipe['outputs'].values())
        comparisons.append({'id': recipe['id'], 'inputs': recipe['inputs'], 'outputs': recipe['outputs'],
                            'ap': recipe['start_ap'] + recipe['claim_ap'], 'days': recipe['days'],
                            'total_standard_cost': float(recipe_cost), 'per_output_standard_cost': float(recipe_cost / total_output),
                            'note': '多产物按整批看待，不用混合产物的平均单价证明套利。'})
    consumers = {}
    for ident, decision in DECISIONS.items():
        consumers[ident] = {'decision': decision, 'uses': [p['id'] for p in encycl['processes'] if any(i['entity'] == 'resource:' + ident for i in p['inputs'])]}
        assert consumers[ident]['uses'], ident + ': no actual consumers'

    normal = []
    for r in source['recipes']:
        if r['id'] in settings['work']['recipes']: continue
        buy = purchase(r['inputs'])
        if buy is not None:
            normal.append({'id': r['id'], 'cash_inputs': buy, 'sale_outputs': value(r['outputs']),
                           'cash_difference': value(r['outputs']) - buy,
                           'ap': r['start_ap'] + r['claim_ap'], 'days': r['days']})
    assert all(r['start_ap'] + r['claim_ap'] > 0 and r['days'] > 0 for r in source['recipes']), 'zero-time processing needs separate cycle certification'

    audited = [audit_case(evidence / name) for name in CASES]
    growth_rows = [json.loads(line) for line in (evidence / 'growth-budget/commands.jsonl').read_text(encoding='utf-8').splitlines()]
    initial = read(evidence / 'growth-budget/initial.json')
    final = read(evidence / 'growth-budget/final.json')
    bought, sold, paid = Counter(), Counter(), Counter()
    harvest_days = []
    for r in growth_rows:
        if not r['result']['ok']: continue
        command, args = r['command'], r['args']
        if command == 'buy': bought[args[0]] += args[1]
        if command == 'sell': sold[args[0]] += args[1]
        if command == 'build': paid[args[2]] += facilities[args[2]]['cash']
        if command == 'start_research': paid['research:' + args[1]] += next(p['fee'] for p in source['research'] if p['id'] == args[1])
        if command == 'buy_gu': paid['gu:' + args[0]] += next(g['market_price'] for g in source['logistics']['definitions'] if g['id'] == args[0])
        if command == 'harvest': harvest_days.append(r['before']['day'])
    unique_round_days = sorted(set(harvest_days))
    assert len(unique_round_days) == 6 and bought['resin_tree_seed'] == 2
    assert sum(r['command'] == 'till' for r in growth_rows) == 12
    assert final['inventory']['resin'] == 7  # 72 produced, 12 sold, 1 smelted, 52 submitted via swaps
    budget = {'kind': 'declared-stage2-reference-module-not-a-fresh-run',
              'start_cash': initial['economy']['primeval_stones'], 'end_cash': final['economy']['primeval_stones'],
              'start_inventory': initial['inventory'], 'preexisting_knowledge': initial['world']['research']['completed'],
              'ordinary_expansion_count': 2, 'expansion_seed_cash': bought['resin_tree_seed'] * resources['resin_tree_seed']['buy_price'],
              'expansion_ap': 10, 'total_three_tree_tiles': 12, 'round_days': unique_round_days,
              'startup_resin_sold': 12, 'steady_rounds_collected': 5, 'steady_resin': 60,
              'event_resin_cost': 52, 'smelting_resin_cost': 1, 'remaining_resin': 7,
              'bought_inputs': dict(bought), 'construction_research_gu_cash': dict(paid),
              'all_cash_spent': sum(bought[k] * resources[k]['buy_price'] for k in bought) + sum(paid.values()),
              'cash_sales': sum(sold[k] * resources[k]['sell_price'] for k in sold),
              'target_package': '产业进阶交付＋田间自动维护研究＋研究台/田间维护站建造＋催生蛊购买；支撑工坊与全部原料、AP已实付'}
    assert budget['start_cash'] + budget['cash_sales'] - budget['all_cash_spent'] == budget['end_cash']

    pearl = next(r for r in rows if r['species'] == 'pearl_mussel')
    overhead = cost({'clean_water': 16}) + 8  # deliberately conservative: two bodies changed daily for four days
    assert pearl['sale_revenue'] - pearl['standard_round_cost'] - float(overhead) > 0
    pearl_capital = {'pen': 2, 'feed_trough': 4, 'small_bed': 2, 'pearl_station': 1,
                     'algae_tank': 3, 'compost_bin': 1, 'woodshop': 1}
    # Four feed slots per two-unit maintenance window require two troughs per room.
    assert set(pearl_capital) <= set(facilities), 'capital module references unknown facility'
    capital_cash = 32 + sum(facilities[k]['cash'] * n for k, n in pearl_capital.items())
    capital_materials = Counter({'twig': 32})
    for k, n in pearl_capital.items(): capital_materials.update({i: q * n for i, q in facilities[k]['materials'].items()})
    water_chain = {'population': 4, 'production_days': 4, 'inputs': pearl['provider']['inputs'],
                   'outputs': pearl['provider']['outputs'], 'upstream': '金穗麦秸秆＋清水→基础藻料；碎岩/贝壳制粉→石粉；留栏珍珠直售/交换',
                   'standard_round_cost': pearl['standard_round_cost'], 'conservative_water_extra': float(overhead),
                   'direct_margin_after_water_screening': pearl['sale_revenue'] - pearl['standard_round_cost'] - float(overhead),
                   'capital_facilities': pearl_capital, 'capital_cash': capital_cash, 'capital_materials': dict(capital_materials),
                   'capital_note': '育幼/生产各16格鱼栅＋圈舍/2供食槽/小床，生产池另有采珠台；床不扣活动空间，圈舍/食槽/台体会扣，需保证净活动空间合格。清单含3藻槽、木工台与堆肥箱；作物种苗/开垦、研究和育幼另计，不伪称完整现金回本。'}
    # One complete steady supply plan, with no rock-animal facility assumed:
    # 6 wheat plots provide straw for 3 algae tanks; 3 retained resin trees
    # trade for powder (and gravel). Rates close exactly over 12 days.
    # This is a capacity/cash calculation, separate from the recorded replay.
    crops = {r['id']: r for r in source['crops']}
    steady_outputs = {'grain': 6 * crops['golden_wheat']['outputs']['grain'], 'pearl': 12, 'gravel': 12}
    water_units = Fraction(12 + 18 + 16) + Fraction(3 * 4 * crops['resin_tree']['water_use'] * 4, source['config']['environment']['irrigate_gain'])
    spring_actions = math.ceil(water_units / 5)
    irrigation_actions = Fraction(12) + Fraction(3 * 4 * crops['resin_tree']['water_use'] * 4, source['config']['environment']['irrigate_gain'])
    fertilizer_points = 4 * (6 * crops['golden_wheat']['fertility_use'] + 12 * crops['resin_tree']['fertility_use'])
    fertilizer = math.ceil(Fraction(fertilizer_points, source['config']['environment']['fertilize_gain']))
    compost_batches = math.ceil(Fraction(fertilizer, 2))
    support_feed = compost_batches * 2
    support_cash = support_feed * resources['fodder_grass']['buy_price']
    total_ap = Fraction(6 * 2 + 4 + 12 + 8 + 1 + spring_actions + fertilizer + compost_batches * 2) + irrigation_actions
    seed_cash = 6 * resources['golden_wheat_seed']['buy_price']
    steady_revenue = value(steady_outputs)
    assert 3 * 6 * 2 >= 32 and water_units <= 4 * 30 and total_ap <= 4 * 24
    assert compost_batches <= 2 and steady_revenue > seed_cash + support_cash
    water_chain['complete_steady_plan'] = {'kind': 'analytic-capacity-plan-not-full-runtime-replay',
        'per_four_days': {'wheat_plots': 6, 'resin_trees': 3, 'algae_tanks': 3, 'algae_batches': 6,
                         'algae_produced': 36, 'algae_used': 32, 'resin_used_for_powder': 16, 'powder_received': 4,
                         'cash_outputs': steady_outputs, 'sale_revenue': steady_revenue, 'seed_cash': seed_cash,
                         'fertility_points_used': fertilizer_points, 'humus_used_ceiling': fertilizer,
                         'compost_batches': compost_batches, 'fodder_grass_bought': support_feed, 'support_cash': support_cash,
                         'cash_surplus_before_initial_capital': steady_revenue - seed_cash - support_cash,
                         'water_units': float(water_units), 'gather_ap': spring_actions, 'total_ap': float(total_ap)},
        'footprint': {'wheat_land': 6, 'resin_land': 12, 'algae_tank_land': 12, 'compost_land': 1, 'woodshop_land': 4, 'fenced_water': 32},
        'constraints': ['先准备幼体/成长食料与石粉缓冲，研究和资本已完成；不把这些首次投入当作免费。',
                        '错峰种植、培藻与采脂，维护水肥/水质；12日内3个取珠轮和4个留株采脂轮闭合，不为凑轮数缩短生物周期。',
                        '这里按实物整链算销售减购种现金，不能与分摊标准成本余量相加，也不等于已回收初建资本。']}
    boosts = {
        'agriculture_three_trees': {'ordinary_cycle_days': 3, 'growth_gu_cycle_days': 2, 'output_per_round': 12,
            'ordinary_sale_per_day': 24, 'gu_sale_per_day': 36, 'gu_fee_per_day': 3,
            'net_sale_less_gu_fee_per_day': 33, 'gu_purchase_cash': 72,
            'assumption': '三个宿主各完整覆盖一株2×2树，150%原能力；满水肥光，及时收获，另付站体与维护物料，不是全程实测利润。'},
        'pearl_four_adults': {'ordinary_pearl_per_round': 12, 'yield_gu_expected_pearl': 15,
            'yield_gu_fee_per_round': 4, 'direct_extra_sale_less_fee': 14,
            'feed_gu_expected_algae_saved': 8, 'feed_gu_fee_per_round': 4,
            'feed_gu_standard_saving_less_fee': float(cost({'algae_feed': 8}) - 4),
            'assumption': '单采珠台可服务4空间；节粮需足够供食槽覆盖，维持窗口每槽2名额；两槽各入驻时费用为8，见容量说明，期望不是保底。'}
    }
    # There are two trough hosts, each services two animals in the window.
    boosts['pearl_four_adults']['feed_gu_fee_per_round'] = 8
    boosts['pearl_four_adults']['feed_gu_standard_saving_less_fee'] = float(cost({'algae_feed': 8}) - 8)

    paths = ['content/farming/p8/production.json', 'content/farming/baked/p8/production.json',
             'tools/farming/bake_p8.py', 'tools/farming/report_p107_economy.py', 'scripts/farming/p8/p103_ranch.gd',
             'scripts/farming/p8/p107_economy.gd', 'scripts/farming/tests/run_p107_playtest.gd']
    return {'kind': 'standard-cost-comparison-plus-separately-audited-cash', 'population': 4,
            'assumptions': ['满额食料、及时领取、陆地疲劳不积累、水质达标、无蛊基线；每个有效照料日6单位。',
                            '标准成本含明示AP/日权重与上游分摊；它不是实际扣款或市场售价。空间、建造、首次育幼另列。',
                            '捕鱼每轮重补；留栏购幼/初长只计首次；多产物看整批，不用分摊值证明增发环。'],
            'source_sha256': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths},
            'routes': rows, 'alternatives': comparisons, 'resource_decisions': consumers,
            'real_engine_quote_matrix': {'vectors': len(quotes), 'sha256': hashlib.sha256(quote_path.read_bytes()).hexdigest(),
                                         'scope': 'all supply resources, five paths, ranks1-5, demand1 and normal tier demand'},
            'actual_capture_lifetimes': capture_observations,
            'normal_processing': normal, 'growth_budget': budget, 'water_chain': water_chain,
            'boost_comparison': boosts, 'audited_cases': audited, 'cycle_certificate': certified}


def markdown(data):
    text = ['# P10.7 经济与成长对照', '',
            '此表由当前生产配置和外部经营收据生成。标准成本筛查、实际现金收支和条件收益分别列示，旧P10.6调研值不追认为新版本证据。', '',
            '## 成长基准与实际支付', '',
            '参考模块从已进入阶段2、已掌握花源/农产初加工的声明夹具开始，不是90元石无注入新档。其初始资金含夹具供货收入；该资金不算本场景经营利润。另有独立无注入新档场景验证前两个事件。', '']
    budget = data['growth_budget']
    text += [f"- 初始元石{budget['start_cash']}，末余额{budget['end_cash']}；本场景实付{budget['all_cash_spent']}，首次松脂销售回款{budget['cash_sales']}。",
             '- 初始1树扩至3树：实际另买2株树苗、开垦8格并播种，共20元石＋10AP；全部12格、3次播种可从命令账复核。',
             f"- 实际采收日为{budget['round_days']}：首轮12松脂出售作为工坊建设周转；之后5轮实收60松脂，1份用于炼铁，52份换取事件材料，余7份。没有把首轮销售和后续交付重复计价。",
             '- 交付同时包含产业进阶、田间维护研究、研究台/田间站与催生蛊购买；木工、堆肥、炼铁及采集/灌溉也实际执行。总25日，满足短模块上限；4～6轮是参考目标，不是强制门槛。', '',
             '## 留栏、捕捞与路线定位', '',
             '四饲养单位，实际体型权重及站数另列。标准成本差额未扣初建/上游设施容量及额外换水，不能称为现金净利润。特色交换列按完整可交换批量换松脂后出售，剩余副产物按普通出售；不是把同份产物卖两次。', '',
             '| 物种 | 类型/轮日 | 空间/专属台 | 首轮标准成本 | 后续轮标准成本 | 直售回款/筛查差额 | 经交换出售回款/筛查差额 |',
             '| --- | --- | --- | ---: | ---: | --- | --- |']
    for row in data['routes']:
        text.append(f"| {row['name']} | {row['mode']}/{row['provider']['days']} | {row['total_space']}/{row['station_count']} | {row['first_round_standard_cost']:.2f} | {row['standard_round_cost']:.2f} | {row['sale_revenue']}/{row['direct_screening_margin']:.2f} | {row['exchange_sale_revenue']}/{row['exchange_screening_margin']:.2f} |")
    text += ['', '## 原料、容量与第一次投入', '',
             '| 物种 | 每轮真实投料（4单位） | 实际产物 | 首次另需购幼元石/成长日（留栏） |',
             '| --- | --- | --- | --- |']
    for row in data['routes']:
        text.append(f"| {row['name']} | {row['provider']['inputs']} | {row['provider']['outputs']} | {row['initial_extra_cash']}/{row['growth_days']}；捕捞已计入每轮 |")
    text += ['', '首次育幼后另有1日维持/用途切换等待和1AP分配：留栏只计首次，捕捞每轮重复计入；购幼本身0AP。每台每服务单位承载4空间；羊、矿鳞蜥、油鳍鱼等大体型4单位共8空间需2座专属台。床按个体/床型占位，供食槽每维持窗口2名额，4单位需2槽；幼体与成体可用不同分区，不把同一床位/台能力重复算给同时运行的两群。', '',
             '## 水产完整链对照', '',
             data['water_chain']['upstream'], '',
             f"4只留栏珍珠蚌每4日投入{data['water_chain']['inputs']}，产{data['water_chain']['outputs']}。上游标准成本＋轮AP/日计{data['water_chain']['standard_round_cost']:.2f}；另按两个16格水体每天各换水一次的保守上限，计清水16＋8AP（{data['water_chain']['conservative_water_extra']:.2f}），普通销售72后仍有{data['water_chain']['direct_margin_after_water_screening']:.2f}标准成本余量。单次最多服务8格，每水体平均加20点仍高于每日损耗；换水另产污水未计收益。",
             f"初建设施/鱼栅现金{data['water_chain']['capital_cash']}，材料{data['water_chain']['capital_materials']}；首次另付购幼和成长，见上表。" + data['water_chain']['capital_note'], '',
             '完整上游稳态容量方案（条件计算，非整链逐日实测）：6格金穗麦每4日给秸秆12，3座藻槽做6批，清水18＋秸秆12→藻料36，供4蚌消耗32、余4缓冲。3株松脂树每3日12松脂，按12日闭合为48松脂→石粉12＋砂砾36，恰供3个4日取珠轮。另每4日购牧草4、在1堆肥箱做2批→腐殖土4，覆盖18格作物96肥力点的维持；不把初始土壤肥力当作永不耗尽。这样无需假定玩家另有一套免费鼹/兽设施。',
             f"该方案每4日销售{data['water_chain']['complete_steady_plan']['per_four_days']['cash_outputs']}，回款{data['water_chain']['complete_steady_plan']['per_four_days']['sale_revenue']}，购麦种{data['water_chain']['complete_steady_plan']['per_four_days']['seed_cash']}、堆肥牧草{data['water_chain']['complete_steady_plan']['per_four_days']['support_cash']}；条件现金余量{data['water_chain']['complete_steady_plan']['per_four_days']['cash_surplus_before_initial_capital']}。清水约{data['water_chain']['complete_steady_plan']['per_four_days']['water_units']:.1f}/4日，含堆肥/施肥的全部农务、取水、培藻、换水、领取约{data['water_chain']['complete_steady_plan']['per_four_days']['total_ap']:.1f}AP/4日，均低于泉水与玩家上限。耕作18格＋藻槽12格＋堆肥1格＋木工4格陆地，另32格水面；需错峰并先支付研究、购幼、建造、种苗及启动料。此现金表走松脂交换支路，不与默认矿物原料标准成本差额相加。", '',
             '陆生/工业参考链由上述25日实际场景覆盖：普通木工→木板、牧草堆肥→腐殖土、原矿＋松脂→铁锭、研究→田间站；所有投入/副产物、批次时间、AP和实际资金均经外部重建。其目标是建设升级，不要求中间品全部出售。', '',
             '## 同终点替代工艺', '',
             '| 配方 | 投入 | 产物 | AP/日 | 整批标准成本 |', '| --- | --- | --- | --- | ---: |']
    for row in data['alternatives']:
        text.append(f"| {row['id']} | {row['inputs']} | {row['outputs']} | {row['ap']}/{row['days']} | {row['total_standard_cost']:.3f} |")
    text += ['', '鳞甲/珊瑚板和滤材供已建设相应动物模块的基地消化产物；普通岩料/黏液/壳路线可能更便宜，应按前置、等量终产物及工坊时间选择。高价专材不建议先出售再回购；其特色交换出口允许专精玩家绕过外产业动物建设。', '',
             '## 各材料裁决', '']
    for ident, row in data['resource_decisions'].items(): text.append(f"- `{ident}`：{row['decision']} 实际消费者：" + '、'.join('`' + i + '`' for i in row['uses']) + '。')
    text += ['', '## 普通加工与机会成本', '',
             '| 全投入可直接购买的普通配方 | 买料现金 | 售出全部产物 | 差额 | AP/日 |', '| --- | ---: | ---: | ---: | --- |']
    for row in data['normal_processing']:
        text.append(f"| {row['id']} | {row['cash_inputs']} | {row['sale_outputs']} | {row['cash_difference']} | {row['ap']}/{row['days']} |")
    text += ['', '买价0的原料没有按免费投入计算。正差额允许存在：泉水为5份/AP、每日30份，按普通出售即5元石/AP且有日容量；采石3份/AP、采矿2份/AP，同样有上限。加工还占设施、AP和等待，不因正差额一律封禁。', '',
             '## 原能力强化对照', '',
             '以下是满足完整覆盖/容量、足额供给且及时收取的条件期望，单独列蛊费用；不伪称完整经营实测，也不更改蛊或三级倍率。', '',
             '- 3株松脂树：普通留株3日一轮12松脂，24元石/日；三只催生蛊150%使轮次变2日，36元石/日，扣3只维护后33元石/日；另付72元石购蛊及3座站体/服务原料。',
             '- 4只珍珠蚌：基础每轮12珠；单采珠台丰养蛊期望15珠，直售额外18、4日维护4，净增加14元石，食料/水质仍须满足。',
             '- 节粮：4蚌每轮基础藻料32，25%累计节约8；2供食槽分别入驻时4日维护共8，按藻料标准成本节省约2.27（不是现金退款），饮水与生产轮补料不折。', '',
             '## 循环、保存与证据边界', '',
             '固定兑换＋市场买卖已有正有理数势函数证书：现金权重1，每条免费边不增加势能，允许任意次组合；该权重不是报价或新增货币。所有64生产配方仍有正AP/时间代价，生物工艺必须真实岗位推进，合法AP/等待换收益保留。配置探针覆盖双步增发环、买卖倒挂、未知/零投入及事件自身锁住资源。', '',
             f"真实Godot报价矩阵共{data['real_engine_quote_matrix']['vectors']}条，覆盖全部可供货资源、五行、1～5转，以及需求1和正常需求；逐条由Python重算数量、市价回款与10%整数溢价。源配额、三单轮换、过期/重复拒绝另有契约模型。", '',
             '捕捞成本另做真实四单位生命周期校验：滤藻鲤共7日、藻料36＋谷粒4、购幼20元石；油鳍鱼共9日、藻料48＋谷粒8、购幼40元石。两者均实际支付1AP分配用途、1AP领取，与成本模型逐项一致。', '',
             '六场景分别归档，独立审计逐条重建库存、现金、订单、事件、兑换、普通批次、研究和未强化松脂生长；存档故障/重试另由真实磁盘事务模型验证。19日无注入场景只采泉水、提交真实订单，阶段0→2且元石90→259，说明早期可积累；不把声明夹具的298初始资金计成新档经营收益。', '',
             '机器明细：`phase107-economy.json`；复现：`python tools/farming/report_p107_economy.py --check`。图形、完整回归和长线稳定性由各自证据负责，不能用本表代替。', '']
    return '\n'.join(text)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--evidence', type=Path, default=ROOT / '.art-work/p107-playtest')
    args = parser.parse_args()
    data = report(args.evidence)
    targets = {ROOT / 'docs/farming/phase107-economy.json': json.dumps(data, ensure_ascii=False, indent=2) + '\n',
               ROOT / 'docs/farming/phase107-economy.md': markdown(data)}
    for path, value in targets.items():
        if args.check:
            if not path.exists() or path.read_text(encoding='utf-8') != value:
                raise SystemExit('P107 ECONOMY STALE: ' + str(path))
        else:
            path.write_text(value, encoding='utf-8')
    print('P107 ECONOMY OK: first/steady/capture, nine routes, alternatives, audited growth and capital')


if __name__ == '__main__':
    main()
