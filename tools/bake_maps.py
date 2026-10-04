#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""地图烘焙工具（P1 工作流核心）。

输入：content/maps/*.json（地图源数据）、content/themes/*.json（主题包）
输出：content/baked/<theme>/theme.json           运行时玩家/主题配置
      content/baked/<theme>/maps/<id>.json      规范化地图（运行时唯一读取物）
      content/baked/<theme>/manifest.json       美术采购单（资产清单）
      content/baked/index.json                  主题/默认图注册表

原则：
- 确定性：同一源数据重复运行，产物逐字节一致（sort_keys + 固定遍历顺序）。
- 校验先行：任何错误以非零码退出，不产出半成品。
- 运行时永不读取源数据，只读 baked/。

用法：python tools/bake_maps.py
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"
MAPS_DIR = CONTENT / "maps"
THEMES_DIR = CONTENT / "themes"
BAKED = CONTENT / "baked"

FACES = {"up", "down", "left", "right"}


class BakeError(Exception):
    pass


def err(msg: str) -> None:
    raise BakeError(msg)


def check(cond: bool, msg: str) -> None:
    if not cond:
        err(msg)


def load_json(p: Path):
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except FileNotFoundError:
        err(f"缺少文件: {p}")
    except json.JSONDecodeError as e:
        err(f"{p.name}: JSON 语法错误: {e}")


def write_json(p: Path, data) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(
        json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def is_region4(v, what: str) -> None:
    check(isinstance(v, list) and len(v) == 4 and all(isinstance(n, int) for n in v),
          f"{what} 应为 [x, y, w, h]，实际 {v!r}")


def is_size2(v, what: str) -> None:
    check(isinstance(v, list) and len(v) == 2 and all(isinstance(n, int) for n in v),
          f"{what} 应为 [int, int]，实际 {v!r}")


# ---------------------------------------------------------------- 主题校验
def validate_theme(theme: dict) -> None:
    tid = theme.get("id")
    check(isinstance(tid, str) and tid, "主题缺 id")
    check(theme.get("schema") == 1, f"主题 {tid}: schema 应为 1")
    ts = theme.get("tile_size")
    check(isinstance(ts, int) and ts > 0, f"主题 {tid}: tile_size 非法")
    tex = theme.get("textures", {})
    for key in ("tileset", "objects", "player"):
        t = tex.get(key)
        check(isinstance(t, dict) and t.get("path"), f"主题 {tid}: textures.{key} 缺 path")
        if key != "player":
            is_size2(t.get("size"), f"主题 {tid}: textures.{key}.size")
    check(isinstance(theme.get("tiles"), dict) and theme["tiles"],
          f"主题 {tid}: tiles 为空")
    for name, t in theme["tiles"].items():
        is_size2(t.get("atlas"), f"主题 {tid}: tiles.{name}.atlas")
        tw, th = tex["tileset"]["size"]
        cx, cy = t["atlas"]
        check(0 <= (cx + 1) * ts <= tw and 0 <= (cy + 1) * ts <= th,
              f"主题 {tid}: tiles.{name}.atlas {t['atlas']} 超出 tileset 尺寸 {tw}x{th}")
    check(isinstance(theme.get("objects"), dict), f"主题 {tid}: objects 缺失")
    for name, o in theme["objects"].items():
        has_region = isinstance(o.get("region"), list)
        has_frames = isinstance(o.get("frames"), list) and bool(o["frames"])
        check(has_region != has_frames,
              f"主题 {tid}: objects.{name} 应有 region 或 frames 二选一")
        if o.get("box") is not None:
            is_size2(o["box"], f"主题 {tid}: objects.{name}.box")
        if o.get("zone_offset") is not None:
            is_size2(o["zone_offset"], f"主题 {tid}: objects.{name}.zone_offset")
    is_region4(theme.get("player", {}).get("prompt_region"),
               f"主题 {tid}: player.prompt_region")
    check(isinstance(theme["player"].get("prompt_texture"), str)
          and theme["player"]["prompt_texture"],
          f"主题 {tid}: player.prompt_texture 缺失")


# ---------------------------------------------------------------- 地图展开
def map_dims(src: dict) -> tuple:
    layout = src["layout"]
    return len(layout[0]), len(layout)


def validate_map(src: dict, theme: dict, mname: str) -> None:
    check(src.get("schema") == 1, f"{mname}: schema 应为 1")
    layout = src.get("layout")
    check(isinstance(layout, list) and layout, f"{mname}: layout 为空")
    w = len(layout[0])
    check(w > 0, f"{mname}: 行宽为 0")
    for y, row in enumerate(layout):
        check(isinstance(row, str) and len(row) == w,
              f"{mname}: 第 {y} 行宽度 {len(row)} != {w}")
    legend = src.get("legend", {})
    check(isinstance(legend, dict) and legend, f"{mname}: legend 为空")
    used = set(ch for row in layout for ch in row)
    for ch in used:
        le = legend.get(ch)
        check(isinstance(le, dict), f"{mname}: 字符 '{ch}' 不在 legend")
        tname = le.get("tile")
        check(tname in theme["tiles"], f"{mname}: legend '{ch}' 引用未定义图块 '{tname}'")
        if le.get("wall") is not None:
            check(isinstance(le["wall"], bool), f"{mname}: legend '{ch}'.wall 应为布尔")
        if le.get("object") is not None:
            check(le["object"] in theme["objects"],
                  f"{mname}: legend '{ch}' 引用未定义物件 '{le['object']}'")
    # spawn
    w, h = map_dims(src)
    spawn = src.get("spawn")
    is_size2(spawn, f"{mname}: spawn")
    sx, sy = spawn
    check(0 <= sx < w and 0 <= sy < h, f"{mname}: spawn {spawn} 越界")
    check(not cell_is_solid(src, theme, sx, sy), f"{mname}: spawn {spawn} 落在实心图块上")
    face = src.get("spawn_face")
    check(face in FACES, f"{mname}: spawn_face '{face}' 非法")
    # 交互（本图内可校验部分）
    interactions = src.get("interactions", {})
    for ch, info in interactions.items():
        check(ch in legend and legend[ch].get("object"),
              f"{mname}: 交互 '{ch}' 的 legend 项缺 object 锚点")
        check(isinstance(info.get("name"), str) and info["name"],
              f"{mname}: 交互 '{ch}' 缺 name")
        pages = info.get("pages")
        check(isinstance(pages, list) and pages and
              all(isinstance(p, str) and p for p in pages),
              f"{mname}: 交互 '{ch}' 的 pages 非法")
        check(any(ch in row for row in layout),
              f"{mname}: 交互 '{ch}' 在布局中未出现")
    # 门户（本图内可校验部分）
    w, h = map_dims(src)
    seen = set()
    for p in src.get("portals", []):
        c = p.get("cell")
        is_size2(c, f"{mname}: 门户 cell")
        cx, cy = c
        check(0 <= cx < w and 0 <= cy < h, f"{mname}: 门户 {c} 越界")
        check(tuple(c) not in seen, f"{mname}: 门户 {c} 重复")
        seen.add(tuple(c))
        check(not cell_is_solid(src, theme, cx, cy),
              f"{mname}: 门户 {c} 落在实心图块上")
        check(p.get("to") != src.get("id"), f"{mname}: 门户 {c} 指向自身")
        check(p.get("face") in FACES, f"{mname}: 门户 {c} face 非法")
        is_size2(p.get("spawn"), f"{mname}: 门户 {c} spawn")


def cell_is_solid(src: dict, theme: dict, x: int, y: int) -> bool:
    """该格是否画在墙层或使用实心图块（即可行走性判定）。"""
    ch = src["layout"][y][x]
    le = src["legend"][ch]
    if le.get("wall"):
        return True
    return bool(theme["tiles"][le["tile"]].get("solid", False))


def validate_portals_cross(all_src: dict, theme: dict, tid: str) -> None:
    """跨图校验（按主题）：目标存在、落点合法且不在对方触发格上、双向配对存在。"""
    for mid, src in all_src.items():
        for p in src.get("portals", []):
            target_id = p["to"]
            tsrc = all_src.get(target_id)
            check(tsrc is not None, f"[{tid}] {mid}: 传送目标图不存在: {target_id}")
            tw, th = map_dims(tsrc)
            sx, sy = p["spawn"]
            check(0 <= sx < tw and 0 <= sy < th,
                  f"{mid}: 门户 {p['cell']} 的落点 {p['spawn']} 在 {target_id} 越界")
            check(not cell_is_solid(tsrc, theme, sx, sy),
                  f"{mid}: 落点 {p['spawn']} 在 {target_id} 是实心格")
            t_portals = {tuple(q["cell"]) for q in tsrc.get("portals", [])}
            check((sx, sy) not in t_portals,
                  f"{mid}: 落点 {p['spawn']} 压在 {target_id} 的触发格上（会来回横跳）")
            check(any(q["to"] == mid for q in tsrc.get("portals", [])),
                  f"{mid} → {target_id} 无回程门户（双向配对缺失）")


def expand_map(src: dict, theme: dict) -> dict:
    """把源数据展开为运行时规范形（图块索引 + 逐格数组 + 具体区域）。"""
    ts = int(theme["tile_size"])
    w, h = map_dims(src)
    layout = src["layout"]
    legend = src["legend"]
    used_chars = set(ch for row in layout for ch in row)
    # 图块表：主题声明顺序，仅收录本图用到的
    used_tiles = [name for name in theme["tiles"]
                  if any(legend[ch]["tile"] == name for ch in used_chars)]
    tile_index = {name: i for i, name in enumerate(used_tiles)}
    tiles = [{"name": name,
              "atlas": theme["tiles"][name]["atlas"],
              "solid": bool(theme["tiles"][name].get("solid", False))}
             for name in used_tiles]

    ground, walls, objects = [], [], []
    for y, row in enumerate(layout):
        for x, ch in enumerate(row):
            le = legend[ch]
            idx = tile_index[le["tile"]]
            if le.get("wall"):
                walls.append(idx)
                ground.append(-1)
            else:
                ground.append(idx)
                walls.append(-1)
            if le.get("object") is not None:
                od = theme["objects"][le["object"]]
                entry = {"kind": le["object"], "cell": [x, y],
                         "zone_offset": od.get("zone_offset", [0, 0])}
                if "frames" in od:
                    entry["frames"] = od["frames"]
                else:
                    entry["region"] = od["region"]
                if od.get("box") is not None:
                    entry["box"] = od["box"]
                objects.append(entry)

    used_objects = [name for name in theme["objects"]
                    if any(o["kind"] == name for o in objects)]
    del used_objects  # 预留：主题内未用物件的告警口径，P2 换肤时再启用

    interactions = []
    for ch in sorted(src.get("interactions", {})):
        info = src["interactions"][ch]
        zone_offset = theme["objects"][legend[ch]["object"]].get("zone_offset", [0, 0])
        cells = [[x, y] for y, row in enumerate(layout)
                 for x, c in enumerate(row) if c == ch]
        interactions.append({"char": ch, "cells": cells, "name": info["name"],
                             "pages": info["pages"], "zone_offset": zone_offset})

    return {
        "schema": 1,
        "id": src["id"],
        "name": src.get("name", src["id"]),
        "theme": theme["id"],
        "tile_size": ts,
        "size": [w, h],
        "tileset_texture": theme["textures"]["tileset"]["path"],
        "objects_texture": theme["textures"]["objects"]["path"],
        "tiles": tiles,
        "ground": ground,
        "walls": walls,
        "objects": objects,
        "interactions": interactions,
        "portals": [{"cell": p["cell"], "to": p["to"], "spawn": p["spawn"],
                     "face": p["face"]} for p in src.get("portals", [])],
        "spawn": src["spawn"],
        "spawn_face": src["spawn_face"],
    }


# ---------------------------------------------------------------- 主流程
def main() -> int:
    try:
        index_src = load_json(MAPS_DIR / "index.json")
        theme_files = sorted(THEMES_DIR.glob("*.json"))
        check(theme_files, "content/themes/ 下没有主题文件")
        themes = {p.stem: load_json(p) for p in theme_files}
        for t in themes.values():
            validate_theme(t)

        map_files = sorted(p for p in MAPS_DIR.glob("*.json") if p.name != "index.json")
        check(map_files, "content/maps/ 下没有地图文件")
        all_src = {}
        for p in map_files:
            src = load_json(p)
            check(src.get("id") == p.stem, f"{p.name}: id '{src.get('id')}' 与文件名不符")
            all_src[p.stem] = src

        # 主题 × 地图 全组合：布局与皮肤解耦（R3）。
        # 主题契约 = 覆盖所有地图用到的语义图块/物件，任一缺失即烘焙失败。
        maps_by_theme: dict = {}
        for tid in sorted(themes):
            theme = themes[tid]
            for mid in sorted(all_src):
                validate_map(all_src[mid], theme, f"{mid}.json")
            validate_portals_cross(all_src, theme, tid)
            maps_by_theme[tid] = {mid: expand_map(all_src[mid], theme)
                                  for mid in sorted(all_src)}

        for tid, maps in maps_by_theme.items():
            theme = themes[tid]
            theme_out = {
                "theme": tid,
                "tile_size": theme["tile_size"],
                "player": {
                    "texture": theme["textures"]["player"]["path"],
                    "frame": theme["textures"]["player"]["frame"],
                    "prompt_region": theme["player"]["prompt_region"],
                    "prompt_texture": theme["player"]["prompt_texture"],
                },
            }
            write_json(BAKED / tid / "theme.json", theme_out)
            for mid, baked in maps.items():
                write_json(BAKED / tid / "maps" / f"{mid}.json", baked)
            manifest = {
                "schema": 1,
                "theme": tid,
                "note": "美术采购单：按下列规格出图，覆盖 assets/ 同名文件后无需重烘",
                "textures": {
                    "tileset": {**theme["textures"]["tileset"],
                                "tiles": [{"name": n, "atlas": t["atlas"],
                                           "solid": bool(t.get("solid", False))}
                                          for n, t in theme["tiles"].items()]},
                    "objects": {**theme["textures"]["objects"],
                                "objects": theme["objects"],
                                "prompt_region": theme["player"]["prompt_region"]},
                    "player": {**theme["textures"]["player"],
                               "layout": "4方向x4帧，行序 下/左/右/上，列序 待机/迈步/过渡/迈步2"},
                },
                "maps": {
                    mid: {"name": m["name"],
                          "tiles": [t["name"] for t in m["tiles"]],
                          "objects": sorted({o["kind"] for o in m["objects"]})}
                    for mid, m in sorted(maps.items())
                },
            }
            write_json(BAKED / tid / "manifest.json", manifest)

        write_json(BAKED / "index.json", {
            "default_theme": index_src.get("default_theme", next(iter(sorted(themes)))),
            "themes": sorted(themes),
            "default_map": index_src.get("default_map", sorted(all_src)[0]),
            "maps": sorted(all_src),
        })

        n_maps = len(all_src)
        n_cells = sum(map_dims(s)[0] * map_dims(s)[1] for s in all_src.values())
        n_portals = sum(len(s.get("portals", [])) for s in all_src.values())
        print(f"BAKE OK: {len(themes)} 主题 / {n_maps} 张图 / {n_cells} 格 / "
              f"{n_portals} 门户 → {BAKED.relative_to(ROOT)}")
        return 0
    except BakeError as e:
        print(f"BAKE FAILED: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
