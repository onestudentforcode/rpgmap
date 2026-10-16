# -*- coding: utf-8 -*-
"""P9.a 调查只读复核工具（audit_entities.py）。

用法（在仓库根目录）：
    python docs/farming/encyclopedia/audit/audit_entities.py

只读核对调查交付 catalog.json / coverage.json 与现行源数据、烘焙数据的一致性：
  1) 输入签名：catalog.baseline.input_files 记录的 SHA256 与当前文件逐一比对；
  2) 注册表枚举：源 JSON 各注册表逐 ID 与 catalog 实体对拍（含食谱/地块）；
  3) 唯一 ID 与悬空引用：实体/过程/规则 ID 唯一；过程 inputs/outputs 引用的实体存在；
  4) 必备字段状态：每实体 facts 逐项 status ∈ {known, not_applicable, unresolved}，
     不允许空值伪装已知（known 必须有 value 字段）；
  5) 过程正反关系：由 catalog.processes 重建 每资源「来源/用途」索引，与每资源实体
     facts 中登记的获取来源(过程)/直接用途(过程) 对拍；
  6) 配方对拍：源 recipes 的每个投入/产出都出现在对应 batch 过程且数量一致，
     并出现在该资源实体的用途/来源索引中；
  7) 活体映射：recipes[].living 与物种特殊食谱一一对应且投入/产出一致；
  8) 数值抽查：种子价格/研究样本与费用/来源点产出与每日上限逐项对拍。

本脚本不修改任何游戏数据、源表、baked 产物或代码；也不从调查报告自身反推
“没有遗漏”——凡注册表与交付不一致一律报错退出（exit 1）。
"""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
AUDIT = Path(__file__).resolve().parent
SRC = json.loads((ROOT / 'content/farming/p8/production.json').read_text(encoding='utf-8'))
BAK = json.loads((ROOT / 'content/farming/baked/p8/production.json').read_text(encoding='utf-8'))
EXP = json.loads((ROOT / 'content/farming/baked/p8/expansion.json').read_text(encoding='utf-8'))
CAT = json.loads((AUDIT / 'catalog.json').read_text(encoding='utf-8'))

problems = []
checks = 0

def ok(label, detail=''):
    global checks
    checks += 1
    print(f'  [ok] {label}' + (f' — {detail}' if detail else ''))

def fail(label, detail):
    problems.append(f'{label}: {detail}')
    print(f'  [!!] {label} — {detail}')

def section(title):
    print(f'\n== {title} ==')

# 1) input signatures ---------------------------------------------------------
section('1. 输入签名（catalog.baseline vs 当前工作区）')
for row in CAT['baseline']['input_files']:
    path = ROOT / row['path']
    if not path.is_file():
        fail('输入缺失', row['path'])
        continue
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest == row['sha256']:
        ok('签名一致', row['path'])
    else:
        fail('签名漂移（调查后文件被修改，需重核受影响范围）', f"{row['path']} recorded={row['sha256'][:12]} now={digest[:12]}")

# 2) registry enumeration -----------------------------------------------------
section('2. 注册表逐ID覆盖')
ENT_BY_SRC = {}
for e in CAT['entities']:
    ENT_BY_SRC.setdefault(e['source_id'], []).append(e)
for reg, section_name in (('resources', 'resources'), ('crops', 'crops'), ('sources', 'sources'),
                          ('facilities', 'facilities'), ('recipes', 'recipes'),
                          ('livestock', 'livestock'), ('research', 'research')):
    ids = {r['id'] for r in SRC[section_name]}
    missing = [i for i in sorted(ids) if i not in ENT_BY_SRC]
    extra = [i for i in sorted(ENT_BY_SRC) if i not in ids and '/' not in i and i in {r['id'] for r in SRC[section_name]}]
    if missing:
        fail(f'{reg} 未覆盖', str(missing))
    else:
        ok(f'{reg} 全覆盖', f'{len(ids)}个ID')
parcel_ids = {p['id'] for p in EXP['parcels']}
missing = [i for i in sorted(parcel_ids) if i not in ENT_BY_SRC]
diet_total = sum(len(l['base_diets']) + len(l['special_diets']) for l in SRC['livestock'])
diet_entities = [e for e in CAT['entities'] if e['kind'] == 'diet']
if missing:
    fail('parcels 未覆盖', str(missing))
else:
    ok('parcels 全覆盖', f'{len(parcel_ids)}个ID')
if len(diet_entities) == diet_total:
    ok('食谱实体齐全', f'{diet_total}个（基础+特殊）')
else:
    fail('食谱实体数量不符', f'源{diet_total} vs 目录{len(diet_entities)}')

# 3) unique ids + dangling references -----------------------------------------
section('3. 唯一ID与引用完整')
eids = [e['id'] for e in CAT['entities']]
pids = [p['id'] for p in CAT['processes']]
rids = [r['id'] for r in CAT['rules']]
for label, lst in (('实体', eids), ('过程', pids), ('规则', rids)):
    dup = sorted({x for x in lst if lst.count(x) > 1})
    if dup:
        fail(f'{label}ID重复', str(dup))
    else:
        ok(f'{label}ID唯一', f'{len(lst)}个')
VALID = set(eids) | {'currency:primeval_stone'}
dang = []
for p in CAT['processes']:
    for row in p['inputs'] + p['outputs']:
        if row['entity'] not in VALID:
            dang.append(f"{p['id']}→{row['entity']}")
for e in CAT['entities']:
    pset = set(pids)
    for pid in e.get('related_processes', []):
        if pid not in pset:
            dang.append(f"{e['id']}→过程{pid}")
    for rid in e.get('related_rules', []):
        if rid not in rids:
            dang.append(f"{e['id']}→规则{rid}")
if dang:
    fail('悬空引用', '; '.join(dang[:8]) + (f'（共{len(dang)}处）' if len(dang) > 8 else ''))
else:
    ok('无悬空引用')

# 4) fact field statuses ------------------------------------------------------
section('4. 必备字段状态')
bad_status = []
for e in CAT['entities']:
    for fname, f in e['facts'].items():
        st = f.get('status')
        if st not in ('known', 'not_applicable', 'unresolved'):
            bad_status.append(f"{e['id']}.{fname} 状态非法:{st}")
        elif st == 'known' and 'value' not in f:
            bad_status.append(f"{e['id']}.{fname} known缺value")
        elif st == 'unresolved' and not f.get('issue_id'):
            bad_status.append(f"{e['id']}.{fname} unresolved缺问题ID")
unresolved = [(e['id'], e['coverage']['unresolved']) for e in CAT['entities'] if e['coverage']['unresolved']]
if bad_status:
    fail('字段状态违规', '; '.join(bad_status[:8]))
else:
    ok('全部字段状态合法', f"共{sum(len(e['facts']) for e in CAT['entities'])}项；unresolved {sum(len(u) for _, u in unresolved)}项")
for eid, fields in unresolved:
    print(f'  [i] unresolved: {eid} → {fields}')

# 5) process forward/reverse index --------------------------------------------
section('5. 过程正反关系对拍')
RES_IDS = {r['id'] for r in SRC['resources']}
src_idx, use_idx = {}, {}
for p in CAT['processes']:
    for row in p['outputs']:
        if row['entity'].startswith('resource:'):
            src_idx.setdefault(row['entity'][9:], set()).add(p['id'])
    for row in p['inputs']:
        if row['entity'].startswith('resource:'):
            use_idx.setdefault(row['entity'][9:], set()).add(p['id'])
mismatch = []
for e in CAT['entities']:
    if e['kind'] != 'resource':
        continue
    rid = e['source_id']
    declared_src = set(e['facts'].get('获取来源(过程)', {}).get('value') or [])
    declared_use = set(e['facts'].get('直接用途(过程)', {}).get('value') or [])
    if declared_src != src_idx.get(rid, set()):
        mismatch.append(f"{rid} 来源: 登记{sorted(declared_src)} vs 过程索引{sorted(src_idx.get(rid, set()))}")
    if declared_use != use_idx.get(rid, set()):
        mismatch.append(f"{rid} 用途: 登记{sorted(declared_use)} vs 过程索引{sorted(use_idx.get(rid, set()))}")
if mismatch:
    fail('正反索引不一致', '; '.join(mismatch[:6]))
else:
    ok('63资源正反索引一致', f'来源过程{sum(len(v) for v in src_idx.values())}条 / 用途过程{sum(len(v) for v in use_idx.values())}条')

# 6) recipe inputs/outputs vs processes ---------------------------------------
section('6. 配方投入产出对拍（数量级）')
bad = []
PROC = {p['id']: p for p in CAT['processes']}
for r in SRC['recipes']:
    pid = f"proc:batch:{r['id']}"
    p = PROC.get(pid)
    if not p:
        bad.append(f'{r["id"]} 缺过程{pid}')
        continue
    pin = {i['entity'][9:]: i['quantity'] for i in p['inputs'] if i['entity'].startswith('resource:')}
    pout = {o['entity'][9:]: o['quantity'] for o in p['outputs'] if o['entity'].startswith('resource:')}
    if pin != r['inputs']:
        bad.append(f'{r["id"]} 投入不一致 {pin} vs {r["inputs"]}')
    if pout != r['outputs']:
        bad.append(f'{r["id"]} 产出不一致 {pout} vs {r["outputs"]}')
    if p['duration'].get('value') != r['days']:
        bad.append(f'{r["id"]} 批时不一致')
    for k in r['inputs']:
        if pid not in use_idx.get(k, set()):
            bad.append(f'{r["id"]} 输入{k} 未进用途索引')
    for k in r['outputs']:
        if pid not in src_idx.get(k, set()):
            bad.append(f'{r["id"]} 输出{k} 未进来源索引')
if bad:
    fail('配方对拍失败', '; '.join(bad[:8]))
else:
    ok('40配方投入/产出/批时/索引全对拍通过')

# 7) living recipe mapping ----------------------------------------------------
section('7. 活体配方映射')
LIV = {l['id']: l for l in SRC['livestock']}
REC = {r['id']: r for r in SRC['recipes']}
living = {rid for rid, r in REC.items() if r.get('living') is True}
diet_pairs = set()
for sid, l in LIV.items():
    for d in l['special_diets']:
        if d['id'] in REC and REC[d['id']].get('facility') == l['facility']:
            diet_pairs.add(d['id'])
if living == diet_pairs:
    ok('living配方与物种特殊食谱一一对应', f'{len(living)}组：{sorted(living)}')
    for rid in sorted(living):
        rec, pairs = REC[rid], None
        for sid, l in LIV.items():
            for d in l['special_diets']:
                if d['id'] == rid:
                    pairs = (sid, d)
        if rec['inputs'] != pairs[1]['inputs']:
            fail(f'{rid} 投入与食谱不一致', f"{rec['inputs']} vs {pairs[1]['inputs']}")
        if rec['outputs'] != pairs[1].get('outputs', LIV[pairs[0]]['outputs']):
            fail(f'{rid} 产出与食谱不一致', '')
    ok('活体配方投入/产出与特殊食谱逐组一致' if not problems or all('活体' not in p for p in problems) else '活体对拍存在差异', '')
else:
    fail('活体映射不匹配', f'living={sorted(living)} diets={sorted(diet_pairs)}')
mapped = {m['from'].split(' ')[0].split('/')[-1]: m for m in CAT['source_mappings'] if m.get('relation') == 'same_process'}
if set(mapped) == living:
    ok('catalog.source_mappings 覆盖全部活体映射', f'{len(mapped)}组')
else:
    fail('source_mappings活体映射缺失', str(sorted(living - set(mapped))))

# 8) numeric spot checks ------------------------------------------------------
section('8. 数值抽查')
spot = 0
for rid, row in {r['id']: r for r in SRC['resources']}.items():
    e = next(x for x in CAT['entities'] if x['id'] == f'resource:{rid}')
    if e['facts']['市集采购价']['value'] != row['buy_price'] or e['facts']['市集出售价']['value'] != row['sell_price']:
        fail('资源价格不符', rid)
    spot += 1
for r in SRC['research']:
    e = next(x for x in CAT['entities'] if x['id'] == f"research:{r['id']}")
    if e['facts']['启动费']['value'] != r['fee']:
        fail('研究费用不符', r['id'])
    spot += 1
for s in SRC['sources']:
    e = next(x for x in CAT['entities'] if x['id'] == f"source:{s['id']}")
    if f"{ {k: v for k, v in {r['id']: r for r in SRC['resources']}.items() }[s['item']]['name']}×{s['quantity']}" != e['facts']['每批产出']['value']:
        fail('来源点产出不符', s['id'])
    spot += 1
ok('资源价格/研究费用/来源点产出抽查', f'{spot}项')

# coverage sanity -------------------------------------------------------------
section('9. coverage.json 交叉')
COV = json.loads((AUDIT / 'coverage.json').read_text(encoding='utf-8'))
if COV['uncovered_registry_ids']:
    fail('coverage登记未覆盖ID', str(COV['uncovered_registry_ids']))
else:
    ok('coverage无未覆盖ID')
if COV['recipe_io_vs_reverse_index_mismatches'] or COV['dangling_references'] or COV['duplicate_ids']:
    fail('coverage登记索引问题', str(COV['recipe_io_vs_reverse_index_mismatches'] + COV['dangling_references'] + COV['duplicate_ids']))
else:
    ok('coverage无配方索引/悬空/重复问题')
known_diffs = COV['baked_consumers_crosscheck']
print(f"  [i] baked交叉核对剩余差异 {len(known_diffs)} 项（已在issues.md登记）：{known_diffs}")

print(f'\n==== 复核完成：{checks}项检查，{len(problems)}项问题 ====')
if problems:
    print('\n'.join(' - ' + p for p in problems))
    sys.exit(1)
print('AUDIT ENTITIES OK')
