#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen_farm_terrains.py — Phase 1 地形占位纹理生成器（程序占位，待 AI 正式图替换）

产出（固定种子，确定性）：
  assets/farming/ground/ground_stone.png     64×64 无缝石板地（2×2 板块拼缝纹）
  assets/farming/ground/ground_tilled.png    64×64 无缝耕地（水平垄沟）
  assets/farming/transitions/trans_upper_dirt.png    1024×1024 过渡 atlas（命名定稿见 phase-01 §2.6）
  assets/farming/transitions/trans_upper_stone.png   同上
  assets/farming/transitions/trans_upper_tilled.png  同上
  各 atlas 配同名 .json（位序说明）

复用 gen_phase00_textures 的噪声/掩码/QC 函数，保证 grass/dirt 视觉一致；
掩码与下层地形无关（上层纹理 × 统一掩码），故三套 atlas 仅纹理与描边色不同。

素材替换契约（phase-01 §2.6）：正式 AI 图按同名同规格覆盖即生效；
替换后必跑 --verify → farmtest → 截图人工核对。

用法：
  python tools/farming/gen_farm_terrains.py            生成 + QC
  python tools/farming/gen_farm_terrains.py --verify   只校验现有文件
  python tools/farming/gen_farm_terrains.py --transitions-only  正式纹理仅重建过渡（不覆盖 ground）
"""

import json
import os
import random
import sys
import argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_phase00_textures as p0  # noqa: E402  (复用 Phase 0 管线)
from asset_common import load_palette, rgb, protect_delivered
from transition_assets import make_atlas, validate_config

ROOT = p0.ROOT
SIZE = p0.SIZE
SEED = 20261008

OUT_STONE = "assets/farming/ground/ground_stone.png"
OUT_TILLED = "assets/farming/ground/ground_tilled.png"
UPPERS = ["dirt", "stone", "tilled"]  # 过渡 atlas 所属上层地形


def _stone_ramp():
    """石板：wilds corr 族（灰绿碎石）+ 派生亮色。"""
    colors = [rgb(c) for c in load_palette()["ground"]["stone"]]
    return {"base": colors[2], "line": colors[0], "dot": colors[1], "hi": colors[3],
            "dark": colors[0], "deep": tuple(int(c * .78) for c in colors[0])}


def _make_stone(ramp, rng):
    """石板地：32px 板块 2×2 拼缝（64%32=0 → 天然 wrap）+ 噪声明暗 + 点蚀。"""
    img = p0._new_rgb()
    px = img.load()
    f = p0._fbm(SIZE, rng)
    for y in range(SIZE):
        for x in range(SIZE):
            v = f[y][x]
            c = ramp["base"]
            if v < 0.34:
                c = ramp["dot"]
            elif v >= 0.82:
                c = ramp["hi"]
            # 板块边缘 1px 拼缝线（每 32px，wrap 对齐）
            if x % 32 in (0,) or y % 32 in (0,):
                c = ramp["line"]
            px[x, y] = c
    # 板块角上的点蚀（wrap 坐标）
    for _ in range(18):
        cx, cy = rng.randrange(SIZE), rng.randrange(SIZE)
        px[cx % SIZE, cy % SIZE] = ramp["line"]
    return img


def _make_tilled(ramp, rng):
    """耕地：暗棕底 + 每 16px 一条水平垄沟（64%16=0 → wrap）+ 亮色土块。"""
    img = p0._new_rgb()
    px = img.load()
    f = p0._fbm(SIZE, rng)
    for y in range(SIZE):
        groove = (y % 16) in (2, 3, 4)  # 垄沟凹槽（更深）
        for x in range(SIZE):
            v = f[y][x]
            if groove:
                c = ramp["deep"] if v < 0.6 else ramp["dark"]
            else:
                c = ramp["dark"] if v < 0.45 else (ramp["base"] if v < 0.85 else ramp["hi"])
            px[x, y] = c
    # 稀疏亮土块（翻耕痕迹）
    for _ in range(14):
        cx, cy = rng.randrange(SIZE), rng.randrange(SIZE)
        if (cy % 16) not in (2, 3, 4):
            px[cx % SIZE, cy % SIZE] = ramp["hi"]
    return img


def _upper_rims():
    _, dirt_r, _ = p0._load_ramps()
    stone = _stone_ramp()
    return {
        "dirt": {"img": None, "rim": {"dark": dirt_r["dark"], "deep": dirt_r["deep"]}},
        "stone": {"img": None, "rim": {"dark": stone["line"], "deep": stone["deep"]}},
        "tilled": {"img": None, "rim": {"dark": dirt_r["deep"], "deep": tuple(int(c * 0.8) for c in dirt_r["deep"])}},
    }


def build_all():
    rng = random.Random(SEED + 1)
    stone_ramp = _stone_ramp()
    stone = _make_stone(stone_ramp, rng)
    _, dirt_r, _ = p0._load_ramps()
    tilled_ramp = {"base": dirt_r["hi"], "dark": dirt_r["dark"], "deep": dirt_r["deep"], "hi": dirt_r["hi"]}
    tilled = _make_tilled(tilled_ramp, rng)

    uppers = _upper_rims()
    uppers["dirt"]["img"] = os.path.join(ROOT, "assets/farming/ground/ground_dirt.png")
    uppers["stone"]["img"] = stone
    uppers["tilled"]["img"] = tilled
    return {"stone": stone, "tilled": tilled, "uppers": uppers}


def _check_atlas(path, fails):
    from PIL import Image
    img = Image.open(path).convert("RGBA")
    if img.size != (SIZE * 16, SIZE * 16):
        fails.append("%s 尺寸错误: %s" % (os.path.relpath(path, ROOT), img.size))
        return
    px = img.load()
    bad = {px[x, y][3] for y in range(img.size[1]) for x in range(img.size[0])} - {0, 255}
    if bad:
        fails.append("%s alpha 非二值: %s" % (os.path.relpath(path, ROOT), sorted(bad)[:5]))
    if not all(px[15 * SIZE + x, 15 * SIZE + y][3] == 255
               for y in range(SIZE) for x in range(SIZE)):
        fails.append("%s bm=255 tile 非全不透明" % os.path.relpath(path, ROOT))


def verify(fails):
    for rel in (OUT_STONE, OUT_TILLED):
        from PIL import Image
        img = Image.open(os.path.join(ROOT, rel)).convert("RGB")
        if img.size != (SIZE, SIZE):
            fails.append("%s 尺寸/模式错误" % rel)
        else:
            p0._check_seamless(img, rel, fails)
    for up in UPPERS:
        png = os.path.join(ROOT, "assets/farming/transitions/trans_upper_%s.png" % up)
        js = os.path.join(ROOT, "assets/farming/transitions/trans_upper_%s.json" % up)
        _check_atlas(png, fails)
        with open(js, "r", encoding="utf-8") as f:
            meta = json.load(f)
        if meta.get("bits") != p0.BITS:
            fails.append("%s 位序与工具不一致" % os.path.relpath(js, ROOT))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--verify", action="store_true")
    mode.add_argument("--transitions-only", action="store_true", help="read existing ground; never write ground")
    parser.add_argument("--output-root", default=ROOT, help="output root (temporary root for regeneration checks)")
    for key in ("outer_radius", "diagonal_radius", "dither_rows", "rim_width"):
        parser.add_argument("--" + key.replace("_", "-"), type=int)
    for key in ("rim_dark_factor", "rim_deep_factor"):
        parser.add_argument("--" + key.replace("_", "-"), type=float)
    args = parser.parse_args()
    only_verify = args.verify
    config = load_palette()["transition"].copy()
    for key in config:
        if hasattr(args, key) and getattr(args, key) is not None:
            config[key] = getattr(args, key)
    try:
        validate_config(config)
    except ValueError as exc:
        parser.error(str(exc))
    output_root = os.path.abspath(args.output_root)
    if not args.transitions_only and output_root != ROOT:
        parser.error("--output-root requires --transitions-only")
    fails = []
    if args.transitions_only:
        from PIL import Image
        inputs = {}
        # Preflight all inputs before writing any output.
        for up in UPPERS:
            path = os.path.join(ROOT, "assets/farming/ground/ground_%s.png" % up)
            try:
                with Image.open(path) as img:
                    if img.mode != "RGB" or img.size != (SIZE, SIZE):
                        parser.error("%s must be 64x64 RGB" % path)
                    inputs[up] = img.copy()
            except OSError as exc:
                parser.error(str(exc))
        for up, texture in inputs.items():
            png = os.path.join(output_root, "assets/farming/transitions/trans_upper_%s.png" % up)
            os.makedirs(os.path.dirname(png), exist_ok=True)
            make_atlas(texture, config).save(png)
            meta = {"schema": 1, "tile": SIZE, "grid": [16, 16], "upper": up,
                    "over": "any_lower", "bits": p0.BITS,
                    "bit_meaning": "置位 = 该方向邻格同属本上层地形",
                    "atlas_of": "col = bitmask & 15, row = bitmask >> 4",
                    "source_tool": "tools/farming/gen_farm_terrains.py", "mask_config": config}
            with open(png.replace(".png", ".json"), "w", encoding="utf-8") as f:
                json.dump(meta, f, ensure_ascii=False, indent=2)
            _check_atlas(png, fails)
            print("[gen] %s (ground preserved)" % png)
    elif not only_verify:
        try:
            protect_delivered([OUT_STONE, OUT_TILLED])
        except ValueError as exc:
            parser.error(str(exc))
        built = build_all()
        # dirt 过渡 atlas 需要泥土纹理：优先读现有 Phase 0 产物（视觉一致），缺失则现生成
        dirt_path = os.path.join(ROOT, "assets/farming/ground/ground_dirt.png")
        if os.path.isfile(dirt_path):
            from PIL import Image
            built["uppers"]["dirt"]["img"] = Image.open(dirt_path).convert("RGB")
        else:
            grass_r, dirt_r, leaf_r = p0._load_ramps()
            r2 = random.Random(p0.SEED)
            built["uppers"]["dirt"]["img"] = p0._make_ground(
                [dirt_r["deep"], dirt_r["base"], dirt_r["base"], dirt_r["hi"]], dirt_r["dark"], r2)

        for key, rel in (("stone", OUT_STONE), ("tilled", OUT_TILLED)):
            path = os.path.join(ROOT, rel)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            built[key].save(path)
            print("[gen] %s" % rel)
        for up in UPPERS:
            atlas = p0._make_trans_atlas(built["uppers"][up]["img"], built["uppers"][up]["rim"])
            png = os.path.join(ROOT, "assets/farming/transitions/trans_upper_%s.png" % up)
            os.makedirs(os.path.dirname(png), exist_ok=True)
            atlas.save(png)
            meta = {
                "schema": 1, "tile": SIZE, "grid": [16, 16],
                "upper": up, "over": "any_lower",
                "bits": p0.BITS, "bit_meaning": "置位 = 该方向邻格同属本上层地形",
                "atlas_of": "col = bitmask & 15, row = bitmask >> 4",
                "source_tool": "tools/farming/gen_farm_terrains.py",
            }
            with open(png.replace(".png", ".json"), "w", encoding="utf-8") as f:
                json.dump(meta, f, ensure_ascii=False, indent=2)
            print("[gen] assets/farming/transitions/trans_upper_%s.png(+json)" % up)

    if not args.transitions_only:
        verify(fails)
    if fails:
        for m in fails:
            print("[qc ] FAIL %s" % m)
        sys.exit(1)
    print("[qc ] 全部通过（无缝统计检验 / alpha 二值 / 尺寸 / 位序）")
    print("FARM TERRAINS OK")


if __name__ == "__main__":
    main()
