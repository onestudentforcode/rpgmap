#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""bake_farm.py — 种植模块数据烘焙（沿用 demo R1/R2 纪律）

  content/farming/terrains.json + content/farming/maps/*.json   ← 源数据（手工维护，进 git）
          │  校验 + 规范化
          ▼
  content/farming/baked/                                        ← 烘焙产物（进 git，运行时唯一读取物）

校验项：
  - 注册表：id 唯一；layer 唯一且从 0 连续；恰一个 dynamic 地形；layer 0 无 trans、
    非 0 层必须有 trans；纹理文件存在；tillable 为布尔
  - 地图：rows 数量/行宽与 size 一致；字符全部在 legend 内；legend 值存在于注册表；
    dynamic 地形不得出现在 legend（耕地由开垦产生，不是静态布局）
确定性：同源两次烘焙产物逐字节一致（进程内自校验）。

用法：
  python tools/farming/bake_farm.py            烘焙全部
  python tools/farming/bake_farm.py --check    只校验不写产物
"""

import io
import json
import os
import sys
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SRC = os.path.join(ROOT, "content", "farming")
BAKED = os.path.join(SRC, "baked")


def _fail(msgs, msg):
    msgs.append(msg)


def _load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _dump_bytes(obj):
    b = io.BytesIO()
    b.write(json.dumps(obj, ensure_ascii=False, indent=2, sort_keys=False).encode("utf-8"))
    b.write(b"\n")
    return b.getvalue()


def validate_terrains(data, msgs):
    if data.get("schema") != 1:
        _fail(msgs, "terrains.schema 必须为 1")
    terrains = data.get("terrains")
    if not isinstance(terrains, list) or not terrains:
        _fail(msgs, "terrains.terrains 必须为非空数组")
        return {}
    ids, layers, dynamic_n = set(), set(), 0
    for t in terrains:
        tid = t.get("id")
        if not tid or tid in ids:
            _fail(msgs, "地形 id 缺失或重复: %r" % tid)
        ids.add(tid)
        layer = t.get("layer")
        if not isinstance(layer, int) or layer in layers:
            _fail(msgs, "地形 %s layer 缺失/重复: %r" % (tid, layer))
        layers.add(layer)
        if not isinstance(t.get("tillable"), bool):
            _fail(msgs, "地形 %s tillable 必须为布尔" % tid)
        if not isinstance(t.get("dynamic"), bool):
            _fail(msgs, "地形 %s dynamic 必须为布尔" % tid)
        if t["dynamic"]:
            dynamic_n += 1
        tex = t.get("textures", {})
        for key in ("ground",):
            p = tex.get(key)
            if not p or not os.path.isfile(os.path.join(ROOT, p)):
                _fail(msgs, "地形 %s 缺少纹理文件 %s:%r" % (tid, key, p))
        if layer != 0:
            p = tex.get("trans")
            if not p or not os.path.isfile(os.path.join(ROOT, p)):
                _fail(msgs, "地形 %s（非 0 层）缺少过渡 atlas %r" % (tid, p))
        else:
            if tex.get("trans"):
                _fail(msgs, "地形 %s（0 层/基底）不应有 trans" % tid)
    if layers and sorted(layers) != list(range(len(layers))):
        _fail(msgs, "layer 必须从 0 连续编号，当前: %s" % sorted(layers))
    if dynamic_n != 1:
        _fail(msgs, "必须恰有一个 dynamic 地形（耕地层），当前 %d 个" % dynamic_n)
    return {t["id"]: t for t in terrains}


def validate_config(data, items_ids, msgs):
    if data.get("schema") != 1:
        _fail(msgs, "config.schema 必须为 1")
        return
    tools = data.get("advanced_tools", {})
    if not isinstance(tools, dict) or set(tools) != {"hoe", "sower", "harvester"}:
        _fail(msgs, "config.advanced_tools requires exactly three tool prices")
    else:
        for kind, price in tools.items():
            if type(price) is not int or not 0 < price <= 1000000:
                _fail(msgs, "advanced tool price must be a positive integer: %s" % kind)
    t = data.get("time", {})
    for key in ("terms_per_year", "days_per_term", "ap_per_day"):
        v = t.get(key)
        if not isinstance(v, int) or v <= 0:
            _fail(msgs, "config.time.%s 必须为正整数: %r" % (key, v))
    names = data.get("term_names", [])
    if len(names) != t.get("terms_per_year"):
        _fail(msgs, "config.term_names 数量 %d ≠ terms_per_year %s" % (len(names), t.get("terms_per_year")))
    costs = data.get("ap_costs", {})
    for key in ("till", "untill", "plant", "harvest", "clear"):
        v = costs.get(key)
        if not isinstance(v, int) or v < 0:
            _fail(msgs, "config.ap_costs.%s 必须为非负整数: %r" % (key, v))
    for iid in data.get("start_inventory", {}):
        if iid not in items_ids:
            _fail(msgs, "config.start_inventory 引用未注册物品 %r" % iid)
    media = data.get("planting_media", [{"id": "soil", "name": "土壤"}])
    if not isinstance(media, list):
        _fail(msgs, "config.planting_media 必须为数组")
        media = []
    medium_ids = set()
    for medium in media:
        if not isinstance(medium, dict):
            _fail(msgs, "config.planting_media 每项必须为对象")
            continue
        mid = medium.get("id", "")
        if not isinstance(mid, str) or not re.fullmatch(r"[a-z][a-z0-9_]*", mid) or mid in medium_ids or not medium.get("name"):
            _fail(msgs, "config.planting_media id/name 非法或重复: %r" % medium)
        if isinstance(mid, str):
            medium_ids.add(mid)
    if "soil" not in medium_ids:
        _fail(msgs, "config.planting_media 必须保留 soil（旧存档默认介质）")
    if "prepare_medium" in costs and (not isinstance(costs["prepare_medium"], int) or costs["prepare_medium"] < 0):
        _fail(msgs, "config.ap_costs.prepare_medium 必须非负整数")


def validate_items(data, msgs):
    if data.get("schema") != 1:
        _fail(msgs, "items.schema 必须为 1")
        return set()
    ids = set()
    for it in data.get("items", []):
        iid = it.get("item_id")
        if not iid or iid in ids:
            _fail(msgs, "物品 id 缺失或重复: %r" % iid)
        ids.add(iid)
        if not isinstance(it.get("base_price"), (int, float)) or it["base_price"] < 0:
            _fail(msgs, "物品 %s base_price 非法" % iid)
    return ids


def validate_crops(data, items_ids, msgs, medium_ids=None):
    if data.get("schema") != 1:
        _fail(msgs, "crops.schema 必须为 1")
        return
    ids = set()
    medium_ids = medium_ids if medium_ids is not None else {"soil"}
    for c in data.get("crops", []):
        cid = c.get("crop_id")
        if not cid or cid in ids:
            _fail(msgs, "作物 id 缺失或重复: %r" % cid)
        ids.add(cid)
        if c.get("category") not in ("herb", "shrub", "tree", "fungus"):
            _fail(msgs, "作物 %s category 须为 herb/shrub/tree/fungus" % cid)
        size = c.get("sprite_size", [64, 64])
        if not (isinstance(size, list) and len(size) == 2 and
                all(isinstance(v, int) and v >= 64 and v % 64 == 0 for v in size)):
            _fail(msgs, "作物 %s sprite_size 须为两个64整倍数" % cid)
        fp = c.get("footprint")
        if not (isinstance(fp, list) and len(fp) == 2 and all(isinstance(v, int) and v > 0 for v in fp)):
            _fail(msgs, "作物 %s footprint 非法: %r" % (cid, fp))
        stages = c.get("growth_stages")
        if not isinstance(stages, list) or len(stages) < 2:
            _fail(msgs, "作物 %s growth_stages 至少 2 段" % cid)
            continue
        for s in stages:
            if not isinstance(s.get("days"), int) or s["days"] < 0:
                _fail(msgs, "作物 %s 阶段 %s days 非法" % (cid, s.get("id")))
        sprites = [s.get("sprite", "") for s in stages]
        if any(not isinstance(s, str) or not re.fullmatch(r"stage_[0-9]+", s) for s in sprites) or len(set(sprites)) != len(sprites):
            _fail(msgs, "作物 %s 阶段sprite须唯一且形如stage_<n>" % cid)
        if stages[-1].get("days") != 0:
            _fail(msgs, "作物 %s 末段（成熟期）days 必须为 0" % cid)
        htype = c.get("harvest_type")
        if htype not in ("remove", "regrow"):
            _fail(msgs, "作物 %s harvest_type 非法: %r" % (cid, htype))
        items = c.get("harvest_items")
        if not isinstance(items, list) or not items:
            _fail(msgs, "作物 %s harvest_items 不能为空" % cid)
        for e in items:
            if e.get("item_id") not in items_ids:
                _fail(msgs, "作物 %s 产出引用未注册物品 %r" % (cid, e.get("item_id")))
            if not (isinstance(e.get("min"), int) and isinstance(e.get("max"), int)
                    and 0 <= e["min"] <= e["max"]):
                _fail(msgs, "作物 %s 产出数量区间非法: %r" % (cid, e))
        mh = c.get("max_harvests")
        if not isinstance(mh, int) or mh < 1:
            _fail(msgs, "作物 %s max_harvests 必须为 ≥1 整数" % cid)
        rd = c.get("regrowth_duration")
        if htype == "remove" and (mh != 1 or rd != 0):
            _fail(msgs, "作物 %s remove 型须 max_harvests=1 且 regrowth_duration=0" % cid)
        if htype == "regrow" and (not isinstance(rd, int) or rd < 1):
            _fail(msgs, "作物 %s regrow 型须 regrowth_duration ≥1" % cid)
        if c.get("planting_medium") not in medium_ids:
            _fail(msgs, "作物 %s 引用未注册 planting_medium: %r" % (cid, c.get("planting_medium")))


def validate_map(data, reg, msgs):
    for key in ("id", "name", "size", "legend", "rows"):
        if key not in data:
            _fail(msgs, "地图缺字段 %s" % key)
            return None
    w, h = data["size"]
    rows = data["rows"]
    if len(rows) != h:
        _fail(msgs, "地图 %s rows 数 %d ≠ size[1] %d" % (data["id"], len(rows), h))
    for i, row in enumerate(rows):
        if len(row) != w:
            _fail(msgs, "地图 %s 第 %d 行宽 %d ≠ %d" % (data["id"], i, len(row), w))
    for ch, tid in data["legend"].items():
        if tid not in reg:
            _fail(msgs, "地图 %s 图例 %r→%r 不在注册表" % (data["id"], ch, tid))
        if tid in reg and reg[tid]["dynamic"]:
            _fail(msgs, "地图 %s 图例引用了 dynamic 地形 %r（耕地由开垦产生）" % (data["id"], tid))
    used = set(ch for row in rows for ch in row)
    for ch in used:
        if ch not in data["legend"]:
            _fail(msgs, "地图 %s 出现未声明字符 %r" % (data["id"], ch))
    return data


def normalize_terrains(data):
    out = {"schema": 1, "terrains": []}
    for t in sorted(data["terrains"], key=lambda t: t["layer"]):
        out["terrains"].append({
            "id": t["id"], "name": t["name"], "layer": t["layer"],
            "tillable": t["tillable"], "dynamic": t["dynamic"], "medium": t["medium"],
            "textures": {
                "ground": t["textures"]["ground"],
                **({"trans": t["textures"]["trans"]} if "trans" in t["textures"] else {}),
            },
        })
    return out


def normalize_map(data, reg):
    legend = data["legend"]
    grid = [[legend[ch] for ch in row] for row in data["rows"]]
    return {"schema": 1, "id": data["id"], "name": data["name"], "size": data["size"], "grid": grid}


def validate_economy(config, items, crops, msgs):
    """Validate the new contract independently of Phase 0-4 content fixtures."""
    economy = config.get('economy')
    if economy is None:
        return
    if not isinstance(economy, dict):
        _fail(msgs, 'economy 必须为对象')
        return
    for key in ('initial_primeval_stones', 'ap_weight', 'day_weight'):
        if type(economy.get(key)) is not int or economy[key] < 0:
            _fail(msgs, 'economy.%s 必须为非负整数' % key)
    behaviors = economy.get('use_behaviors')
    if not isinstance(behaviors, list) or not behaviors or any(not isinstance(v, str) or not v for v in behaviors):
        _fail(msgs, 'economy.use_behaviors 必须为非空行为名称数组')
    paths = {'wood', 'fire', 'earth', 'gold', 'water'}
    by_id = {i['item_id']: i for i in items['items']}
    for item in items['items']:
        if item.get('kind') not in {'food', 'seed', 'production'}:
            _fail(msgs, '物品kind非法: %s' % item['item_id'])
        elements = item.get('path_ids')
        if not isinstance(elements, list) or not elements or any(v not in paths for v in elements):
            _fail(msgs, '物品path_ids非法: %s' % item['item_id'])
        for key in ('buy_price', 'sell_price'):
            if type(item.get(key)) is not int or not 0 <= item[key] <= 1000000:
                _fail(msgs, '物品%s非法: %s' % (key, item['item_id']))
    media = {m['id'] for m in config['planting_media']}
    materials = economy.get('medium_materials', {})
    if not isinstance(materials, dict):
        _fail(msgs, 'economy.medium_materials 必须为对象')
        materials = {}
    for medium, iid in materials.items():
        if medium not in media or medium == 'soil' or by_id.get(iid, {}).get('kind') != 'production':
            _fail(msgs, '介质消耗物映射非法: %s' % medium)
    for crop in crops['crops']:
        if crop.get('path_id') not in paths:
            _fail(msgs, '作物path_id非法: %s' % crop['crop_id'])
        seed = by_id.get(crop['crop_id'] + '_seed', {})
        if seed.get('kind') != 'seed' or seed.get('buy_price', 0) <= 0:
            _fail(msgs, '作物必须有可购买种子: %s' % crop['crop_id'])
        for product in crop['harvest_items']:
            item = by_id.get(product['item_id'], {})
            if item.get('kind') == 'food' and crop.get('path_id') not in item.get('path_ids', []):
                _fail(msgs, '作物与食材五行不一致: %s' % crop['crop_id'])


def main():
    check_only = "--check" in sys.argv
    msgs = []

    items_src = _load_json(os.path.join(SRC, "items.json"))
    items_ids = validate_items(items_src, msgs)
    config_src = _load_json(os.path.join(SRC, "config.json"))
    validate_config(config_src, items_ids, msgs)
    crops_src = _load_json(os.path.join(SRC, "crops.json"))
    validate_economy(config_src, items_src, crops_src, msgs)
    validate_crops(crops_src, items_ids, msgs,
                   {m.get("id") for m in config_src.get("planting_media", [{"id": "soil"}])
                    if isinstance(m, dict) and isinstance(m.get("id"), str)}
                   if isinstance(config_src.get("planting_media", []), list) else set())

    terrains_src = _load_json(os.path.join(SRC, "terrains.json"))
    reg = validate_terrains(terrains_src, msgs)

    maps = []
    maps_dir = os.path.join(SRC, "maps")
    for fn in sorted(os.listdir(maps_dir)):
        if not fn.endswith(".json"):
            continue
        data = _load_json(os.path.join(maps_dir, fn))
        if validate_map(data, reg, msgs) is not None:
            maps.append(data)

    if msgs:
        for m in msgs:
            print("[bake] FAIL %s" % m)
        sys.exit(1)

    def build_outputs():
        files = {
            os.path.join(BAKED, "terrains.json"): _dump_bytes(normalize_terrains(terrains_src)),
            os.path.join(BAKED, "index.json"): _dump_bytes(
                {"schema": 1, "maps": [m["id"] for m in maps]}),
            os.path.join(BAKED, "config.json"): _dump_bytes(config_src),
            os.path.join(BAKED, "items.json"): _dump_bytes(items_src),
            os.path.join(BAKED, "crops.json"): _dump_bytes(crops_src),
        }
        for m in maps:
            files[os.path.join(BAKED, "maps", "%s.json" % m["id"])] = \
                _dump_bytes(normalize_map(m, reg))
        return files

    out_files = build_outputs()
    if build_outputs() != out_files:  # 确定性：二次构建逐字节一致
        print("[bake] FAIL 确定性校验失败")
        sys.exit(1)

    if check_only:
        print("[bake] 校验通过（%d 地形，%d 地图，%d 作物，%d 物品），--check 未写产物" % (
            len(reg), len(maps), len(crops_src.get("crops", [])), len(items_ids)))
        return

    for path, blob in out_files.items():
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(blob)
        print("[bake] %s" % os.path.relpath(path, ROOT))
    print("[bake] OK（%d 地形，%d 地图，%d 作物，%d 物品）" % (
        len(reg), len(maps), len(crops_src.get("crops", [])), len(items_ids)))


if __name__ == "__main__":
    main()
