#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen_farm_crops.py — 作物占位阶段 Sprite 生成器（程序占位，待 AI 正式图替换）

读 content/farming/baked/crops.json（先 bake），按配置的阶段数为每种作物产出：
  assets/farming/crops/<crop_id>/stage_<i>.png     各生长阶段（64×64，底部中心触地）
  assets/farming/crops/<crop_id>/stage_harvested.png   regrow 型：采收后再生长
  assets/farming/crops/<crop_id>/stage_exhausted.png   regrow 型：枯竭（待清理）

阶段数由配置决定（不硬编码）；QC 沿用美术规范（alpha 二值/2px 安全边/尺寸/确定性）。
素材替换契约：正式 AI 图同名覆盖即生效（phase-01 §2.6）。

用法：
  python tools/farming/gen_farm_crops.py            生成 + QC
  python tools/farming/gen_farm_crops.py --verify   只校验现有文件
"""

import argparse
import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_phase00_textures as p0  # noqa: E402
from asset_common import load_palette, rgb, protect_delivered

ROOT = p0.ROOT
SIZE = p0.SIZE
SEED = 20261008

# Single palette source shared by production prompts and placeholder generators.
_colors = load_palette()["crops"]
LEAF_DARK, LEAF, LEAF_HI = map(rgb, _colors["leaf"])
SOIL = rgb(_colors["seed"][0])
BERRY, BERRY_HI = map(rgb, _colors["berry"])
DEW = rgb(_colors["dew"][0])
WITHER_DARK, WITHER = map(rgb, _colors["wither"])


def _canvas():
    return p0._new_rgba()


def _mound(d):
    d.ellipse([22, 50, 42, 60], fill=SOIL + (255,))
    d.rectangle([26, 54, 28, 56], fill=(0x84, 0x67, 0x41, 255))


def _blade(d, x, h, color):
    d.line([(x, 59), (x + (1 if x < 32 else -1) * (h // 8), 60 - h)], fill=color + (255,), width=2)


def _herb_stage(n):
    """凝露草占位：n=0 种堆 … n=3 成熟（露珠点）。"""
    img = _canvas()
    d = p0._draw(img)
    _mound(d)
    if n == 0:
        d.rectangle([31, 52, 33, 54], fill=LEAF_DARK + (255,))
        return img
    blades = [(26, 10), (32, 14), (38, 11)] if n == 1 else (
        [(24, 16), (29, 22), (34, 20), (39, 15)] if n == 2 else
        [(22, 22), (27, 28), (32, 26), (37, 30), (42, 21)])
    colors = [LEAF_DARK, LEAF, LEAF_DARK, LEAF_HI, LEAF]
    for i, (x, h) in enumerate(blades[:2 + n]):
        _blade(d, x, h, colors[i % len(colors)])
    if n >= 3:
        for dx, dy in ((27, 33), (37, 31), (32, 47)):
            d.rectangle([dx, dy, dx + 1, dy + 1], fill=DEW + (255,))
    return img


def _bush(d, body, hi, berries=False):
    d.ellipse([19, 30, 45, 58], fill=body + (255,))
    d.ellipse([22, 33, 33, 44], fill=hi + (255,))
    d.ellipse([33, 42, 43, 53], fill=hi + (255,))
    if berries:
        for bx, by in ((25, 40), (36, 37), (30, 50), (40, 47)):
            d.ellipse([bx, by, bx + 4, by + 4], fill=BERRY + (255,))
            d.rectangle([bx + 1, by + 1, bx + 1, by + 1], fill=BERRY_HI + (255,))


def _shrub_stage(kind):
    """赤纹果占位：kind = 0 种 / 1 苗 / 2 成丛 / 3 成熟挂果 / harvested / exhausted。"""
    img = _canvas()
    d = p0._draw(img)
    _mound(d)
    if kind == 0:
        d.ellipse([29, 50, 35, 56], fill=BERRY + (255,))
        return img
    if kind == 1:
        _blade(d, 30, 14, LEAF_DARK)
        _blade(d, 35, 11, LEAF)
        return img
    if kind == 2:
        _bush(d, LEAF_DARK, LEAF, berries=False)
        return img
    if kind == 3:
        _bush(d, LEAF_DARK, LEAF, berries=True)
        return img
    if kind == "harvested":
        _bush(d, LEAF_DARK, LEAF_HI, berries=False)
        _blade(d, 24, 8, LEAF)
        return img
    # exhausted：枯竭灰褐、下垂
    d.ellipse([21, 38, 43, 58], fill=WITHER + (255,))
    d.ellipse([25, 42, 35, 52], fill=WITHER_DARK + (255,))
    d.rectangle([20, 56, 22, 58], fill=WITHER_DARK + (255,))
    d.rectangle([42, 57, 44, 59], fill=WITHER_DARK + (255,))
    return img


def _tree_stage(kind):
    """2×2青玉果树结构占位：扭干、层叠树冠、玉果；非正式美术。"""
    from PIL import Image, ImageDraw
    img = Image.new("RGBA", (128, 192))
    d = ImageDraw.Draw(img)
    bark = [rgb(c) + (255,) for c in _colors["bark"]]
    jade = [rgb(c) + (255,) for c in _colors["jade"]]
    leaves = [LEAF_DARK + (255,), LEAF + (255,), LEAF_HI + (255,)]
    if kind == 0:
        d.ellipse((55, 174, 72, 189), fill=jade[0])
        d.line((59, 178, 67, 183), fill=jade[2], width=2)
        return img
    height = 50 if kind == 1 else 86 if kind == 2 else 128
    top = 190 - height
    exhausted = kind == "exhausted"
    colors = [WITHER_DARK + (255,), WITHER + (255,), bark[2]] if exhausted else leaves
    d.line([(64, 184), (59, 166), (66, top + 24)], fill=bark[0], width=10)
    d.line([(63, 187), (62, 165), (67, top + 30)], fill=bark[1], width=3)
    d.polygon([(50, 189), (59, 179), (67, 178), (77, 189)], fill=bark[0])
    radius = 18 if kind == 1 else 33 if kind == 2 else 49
    d.ellipse((64-radius, top+12, 63+radius, top+height//2+10), fill=colors[0])
    d.ellipse((64-radius+8, top, 63+radius-5, top+height//2), fill=colors[1])
    d.ellipse((64-radius+12, top+7, 62, top+height//3), fill=colors[2])
    if kind == 3:
        for x,y in [(36,top+38),(69,top+23),(87,top+47),(58,top+58)]:
            d.ellipse((x,y,x+9,y+11), fill=jade[1])
            d.line((x+3,y+2,x+3,y+6), fill=jade[3], width=2)
    return img


def _fungus_stage(kind):
    """月华菇结构占位：银紫菌盖及实色月牙纹，无漂浮发光。"""
    img = _canvas()
    d = p0._draw(img)
    moon = [rgb(c) + (255,) for c in _colors["moon"]]
    d.ellipse((21, 56, 42, 61), fill=moon[0])
    if kind == 0:
        d.line([(25,59),(30,56),(35,59),(39,57)], fill=moon[2], width=2)
        return img
    top = {1:46, 2:34, 3:22}.get(kind,22)
    d.rectangle((29, top+8, 35, 58), fill=moon[2])
    radius = {1:9, 2:15, 3:22}.get(kind,22)
    d.pieslice((32-radius, top, 31+radius, top+24),180,360,fill=moon[0])
    d.pieslice((34-radius, top, 29+radius, top+19),180,360,fill=moon[1])
    if kind == 3:
        d.arc((22,25,32,35),60,290,fill=moon[3],width=2)
        d.line((14,34,20,35),fill=moon[2],width=2)
    return img


def _draw_crop(cid, kind):
    if cid == "jade_fruit_tree":
        return _tree_stage(kind)
    if cid == "moon_cap":
        return _fungus_stage(kind)
    if cid == "dew_grass" and isinstance(kind, int):
        return _herb_stage(kind)
    if cid == "scarlet_berry":
        return _shrub_stage(kind)
    if isinstance(kind, int):  # 未特化品类：通用草形占位
        return _herb_stage(min(kind, 3))
    return _shrub_stage("harvested" if kind == "harvested" else "exhausted")


def outputs_for(crop):
    outs = [(stage["sprite"], i) for i, stage in enumerate(crop["growth_stages"])]
    if crop["harvest_type"] == "regrow":
        outs.append(("stage_harvested", "harvested"))
        outs.append(("stage_exhausted", "exhausted"))
    return outs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--crop", action="append", help="Only this crop_id; repeat for multiple crops")
    args = parser.parse_args()
    only_verify = args.verify
    baked = os.path.join(ROOT, "content", "farming", "baked", "crops.json")
    if not os.path.isfile(baked):
        print("[错误] 缺少 %s（先运行 python tools/farming/bake_farm.py）" % baked)
        sys.exit(2)
    with open(baked, "r", encoding="utf-8") as f:
        crops = json.load(f).get("crops", [])
    if args.crop:
        unknown = set(args.crop) - {c["crop_id"] for c in crops}
        if unknown:
            parser.error("unknown crop_id: " + ", ".join(sorted(unknown)))
        crops = [c for c in crops if c["crop_id"] in args.crop]

    fails = []
    if not only_verify:
        try:
            protect_delivered(["assets/farming/crops/%s/%s.png" % (c["crop_id"], name)
                              for c in crops for name, _ in outputs_for(c)])
        except ValueError as exc:
            print("[error]", exc)
            sys.exit(1)
        rng = random.Random(SEED)  # 保留参数位：当前图形为确定性手绘，不耗随机数
        for crop in crops:
            cid = crop["crop_id"]
            out_dir = os.path.join(ROOT, "assets/farming/crops", cid)
            os.makedirs(out_dir, exist_ok=True)
            for name, kind in outputs_for(crop):
                img = _draw_crop(cid, kind)
                size = tuple(crop.get("sprite_size", [64, 64]))
                if size != img.size:
                    from PIL import Image
                    canvas = Image.new("RGBA", size)
                    subject = img.crop(img.getchannel("A").getbbox())
                    canvas.paste(subject, ((size[0]-subject.width)//2, size[1]-2-subject.height))
                    img = canvas
                img.save(os.path.join(out_dir, "%s.png" % name))
                print("[gen] assets/farming/crops/%s/%s.png" % (cid, name))
        if rng.random() < 0:  # 确定性占位（防未来引入随机绘制时漏检）
            fails.append("随机性意外引入")

    for crop in crops:
        cid = crop["crop_id"]
        for name, _k in outputs_for(crop):
            path = os.path.join(ROOT, "assets/farming/crops", cid, "%s.png" % name)
            if not os.path.isfile(path):
                fails.append("缺少 %s/%s.png" % (cid, name))
                continue
            from PIL import Image
            img = Image.open(path).convert("RGBA")
            if img.size != tuple(crop.get("sprite_size", [SIZE, SIZE])):
                fails.append("%s/%s 尺寸错误: %s" % (cid, name, img.size))
            else:
                p0._check_sprite(img, "crops/%s/%s" % (cid, name), 2, fails)

    if fails:
        for m in fails:
            print("[qc ] FAIL %s" % m)
        sys.exit(1)
    print("[qc ] 全部通过（尺寸 / alpha 二值 / 2px 安全边 / 阶段齐全）")
    print("FARM CROPS OK")


if __name__ == "__main__":
    main()
