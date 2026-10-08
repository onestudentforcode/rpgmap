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


def main():
    check_only = "--check" in sys.argv
    msgs = []

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
        print("[bake] 校验通过（%d 地形，%d 地图），--check 未写产物" % (len(reg), len(maps)))
        return

    for path, blob in out_files.items():
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(blob)
        print("[bake] %s" % os.path.relpath(path, ROOT))
    print("[bake] OK（%d 地形，%d 地图）" % (len(reg), len(maps)))


if __name__ == "__main__":
    main()
