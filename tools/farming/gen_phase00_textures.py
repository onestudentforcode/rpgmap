#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen_phase00_textures.py — Phase 0.4 占位美术生成器（程序化；AI 素材 Phase 3 起接管）

产出（固定种子，确定性：重跑逐字节一致）：
  assets/farming/ground/ground_grass.png              64×64 无缝草地（wrap 值噪声）
  assets/farming/ground/ground_dirt.png               64×64 无缝泥土
  assets/farming/transitions/trans_grass_dirt.png     1024×1024 过渡 atlas（256 配置 × 64px）
  assets/farming/transitions/trans_grass_dirt.json    位序说明 + atlas 公式
  assets/farming/crops/_placeholder/stage_0.png       64×64 占位作物（幼苗，底部中心触地）
  assets/farming/crops/_placeholder/tall_stone.png    64×128 占位高物体（验遮挡）
  assets/farming/crops/_placeholder/shadow_ellipse.png 48×16 接触阴影贴片（独立，不进 Sprite）

QC（生成与 --verify 共用，对应 phase-00 §4 美术规范）：
  尺寸/模式、Sprite alpha 二值、2px 全透明安全边、
  无缝统计检验（边界梯度不得远超内部均值）。

用法：
  python tools/farming/gen_phase00_textures.py            生成 + QC
  python tools/farming/gen_phase00_textures.py --verify   只校验现有文件

色源：content/themes/wilds.json palette_overrides（草=floor_a 族，泥=carpet 族）——
美术规范 §4.3「色域延续 wilds 主题」。
"""

import io
import json
import math
import os
import random
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SIZE = 64
SEED = 20261008  # 2026-10-08 立项日；换风格改种子，勿随机化

OUT = {
    "grass": "assets/farming/ground/ground_grass.png",
    "dirt": "assets/farming/ground/ground_dirt.png",
    "trans": "assets/farming/transitions/trans_grass_dirt.png",
    "trans_json": "assets/farming/transitions/trans_grass_dirt.json",
    "seedling": "assets/farming/crops/_placeholder/stage_0.png",
    "stone": "assets/farming/crops/_placeholder/tall_stone.png",
    "shadow": "assets/farming/crops/_placeholder/shadow_ellipse.png",
}

# 8 邻域位序（GDScript 侧 farm_phase00_map.gd 保持一致；置位 = 该方向邻格为泥土）
BITS = {"N": 1, "E": 2, "S": 4, "W": 8, "NE": 16, "SE": 32, "SW": 64, "NW": 128}


def _load_ramps():
    """从 wilds 主题读取色板；缺失时用同名默认值兜底。"""
    pal = {}
    path = os.path.join(ROOT, "content", "themes", "wilds.json")
    try:
        with open(path, "r", encoding="utf-8") as f:
            pal = json.load(f).get("palette_overrides", {})
    except Exception:
        pass

    def rgb(key, default):
        v = pal.get(key, default).lstrip("#")
        return tuple(int(v[i:i + 2], 16) for i in (0, 2, 4))

    grass = {
        "dark": rgb("floor_a_line", "#6a9151"),
        "base": rgb("floor_a", "#79a05c"),
        "hi": rgb("floor_a_hi", "#8cb069"),
        "dot": rgb("floor_a_dot", "#6d9454"),
    }
    dirt_dark = rgb("carpet_dark", "#846741")
    dirt = {
        "base": rgb("carpet", "#9a7a4e"),
        "dark": dirt_dark,
        "hi": rgb("carpet_pat", "#b08c5c"),
        "deep": tuple(max(0, int(c * 0.78)) for c in dirt_dark),
    }
    leaf = {
        "dark": rgb("leaf", "#39603c"),
        "base": rgb("leaf_hi", "#4e7b4e"),
    }
    return grass, dirt, leaf


# ---------------------------------------------------------------- 无缝地面

def _smooth(t):
    return t * t * (3.0 - 2.0 * t)


def _wrap_noise(size, freq, rng):
    """整周期值噪声：网格随机数按 freq 取模 → 四向平铺天然无缝。"""
    g = [[rng.random() for _ in range(freq)] for _ in range(freq)]
    out = [[0.0] * size for _ in range(size)]
    for y in range(size):
        fy = y / size * freq
        y0, y1 = int(math.floor(fy)) % freq, (int(math.floor(fy)) + 1) % freq
        ty = _smooth(fy - math.floor(fy))
        for x in range(size):
            fx = x / size * freq
            x0, x1 = int(math.floor(fx)) % freq, (int(math.floor(fx)) + 1) % freq
            tx = _smooth(fx - math.floor(fx))
            a = g[y0][x0] * (1 - tx) + g[y0][x1] * tx
            b = g[y1][x0] * (1 - tx) + g[y1][x1] * tx
            out[y][x] = a * (1 - ty) + b * ty
    return out


def _fbm(size, rng):
    layers = ((4, 1.0), (8, 0.5), ( (16), 0.25))  # 频率整除 64 → 各层均可 wrap
    total = None
    wsum = 0.0
    for freq, amp in layers:
        n = _wrap_noise(size, freq, rng)
        if total is None:
            total = [[v * amp for v in row] for row in n]
        else:
            for y in range(size):
                for x in range(size):
                    total[y][x] += n[y][x] * amp
        wsum += amp
    return [[v / wsum for v in row] for row in total]


def _make_ground(shades, dot_color, rng):
    """中低频 4 色阶量化（规范 §4.4）+ wrap 撒点。"""
    f = _fbm(SIZE, rng)
    img = _new_rgb()
    px = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            v = f[y][x]
            if v < 0.32:
                px[x, y] = shades[0]
            elif v < 0.62:
                px[x, y] = shades[1]
            elif v < 0.86:
                px[x, y] = shades[2]
            else:
                px[x, y] = shades[3]
    for _ in range(24):
        cx, cy = rng.randrange(SIZE), rng.randrange(SIZE)
        px[cx % SIZE, cy % SIZE] = dot_color
        px[(cx + 1) % SIZE, cy % SIZE] = dot_color
    return img


# ---------------------------------------------------------------- 过渡 atlas

def _make_mask(bm):
    """泥土格 alpha 掩码（255=显示泥土）。

    - 三邻皆草的外角：R=13 圆角；仅对角为泥的缠绕角：R=6 小倒角
    - 朝草边缘：外 1px 50% 棋盘抖动 + 第 2px 25%（全局坐标对齐，跨 tile 连续）
    - 已知简化（phase-00 §5.2 记录）：无内角外扩 overlap，内角呈直角——Phase 1 定稿
    """
    m = [[255] * SIZE for _ in range(SIZE)]
    specs = [  # (角x, 角y, 竖边位, 横边位, 对角位, 圆心x, 圆心y)
        (0, 0, BITS["N"], BITS["W"], BITS["NW"], -0.5, -0.5),
        (SIZE - 1, 0, BITS["N"], BITS["E"], BITS["NE"], SIZE - 0.5, -0.5),
        (SIZE - 1, SIZE - 1, BITS["S"], BITS["E"], BITS["SE"], SIZE - 0.5, SIZE - 0.5),
        (0, SIZE - 1, BITS["S"], BITS["W"], BITS["SW"], -0.5, SIZE - 0.5),
    ]
    for cx, cy, ev, eh, dg, ox, oy in specs:
        if (bm & ev) or (bm & eh):
            continue  # 任一相邻边是泥土 → 该角无外露
        r = 6 if (bm & dg) else 13
        for y in range(max(0, cy - r + 1), min(SIZE, cy + r)):
            for x in range(max(0, cx - r + 1), min(SIZE, cx + r)):
                dx, dy = x - ox, y - oy
                if dx * dx + dy * dy > r * r:
                    m[y][x] = 0
    # 朝草边缘抖动（(x+y) 奇偶即全局奇偶：tile 对齐且 64 为偶）
    if not bm & BITS["N"]:
        for x in range(SIZE):
            if x % 2 == 0:
                m[0][x] = 0
            if (x + 1) % 4 == 0:
                m[1][x] = 0
    if not bm & BITS["S"]:
        for x in range(SIZE):
            if (x + SIZE - 1) % 2 == 0:
                m[SIZE - 1][x] = 0
            if (x + SIZE - 2) % 4 == 0:
                m[SIZE - 2][x] = 0
    if not bm & BITS["W"]:
        for y in range(SIZE):
            if y % 2 == 0:
                m[y][0] = 0
            if (y + 1) % 4 == 0:
                m[y][1] = 0
    if not bm & BITS["E"]:
        for y in range(SIZE):
            if (y + SIZE - 1) % 2 == 0:
                m[y][SIZE - 1] = 0
            if (y + SIZE - 2) % 4 == 0:
                m[y][SIZE - 2] = 0
    return m


def _make_trans_tile(bm, dirt_img, dirt):
    """泥土纹理 × 掩码 + 朝草边 2px 深色描边（星露谷式边界感）。"""
    tile = dirt_img.copy().convert("RGBA")
    mask = _make_mask(bm)
    px = tile.load()

    def rim(x, y):
        if mask[y][x]:
            px[x, y] = dirt["dark"] if (x + y) % 3 else dirt["deep"]

    if not bm & BITS["N"]:
        for y in (0, 1):
            for x in range(SIZE):
                rim(x, y)
    if not bm & BITS["S"]:
        for y in (SIZE - 2, SIZE - 1):
            for x in range(SIZE):
                rim(x, y)
    if not bm & BITS["W"]:
        for x in (0, 1):
            for y in range(SIZE):
                rim(x, y)
    if not bm & BITS["E"]:
        for x in (SIZE - 2, SIZE - 1):
            for y in range(SIZE):
                rim(x, y)

    alpha = _new_l()
    alpha.putdata([v for row in mask for v in row])
    tile.putalpha(alpha)
    return tile


def _make_trans_atlas(dirt_img, dirt):
    atlas = _new_rgba(SIZE * 16, SIZE * 16)
    for bm in range(256):
        atlas.paste(_make_trans_tile(bm, dirt_img, dirt), ((bm & 15) * SIZE, (bm >> 4) * SIZE))
    return atlas


# ---------------------------------------------------------------- 占位 Sprite

def _make_seedling(leaf):
    """占位幼苗：底部中心触地（y=60，规范 2px 安全边内），接触阴影独立不烘焙。"""
    img = _new_rgba()
    d = _draw(img)
    d.rectangle([31, 38, 32, 60], fill=leaf["dark"] + (255,))       # 茎
    d.ellipse([17, 34, 33, 48], fill=leaf["base"] + (255,))         # 左叶
    d.ellipse([31, 34, 47, 48], fill=leaf["dark"] + (255,))         # 右叶
    d.ellipse([28, 25, 37, 34], fill=leaf["base"] + (255,))         # 顶芽
    return img


def _make_stone():
    """占位高物体（立石）：光从左上（规范 §4.2）——左棱受光、右侧投影。"""
    img = _new_rgba(64, 128)
    d = _draw(img)
    stone = (125, 138, 128, 255)
    hi = (150, 163, 150, 255)
    sh = (93, 106, 96, 255)
    d.ellipse([24, 12, 40, 28], fill=stone)        # 圆顶
    d.rectangle([24, 26, 40, 120], fill=stone)     # 碑身
    d.rectangle([24, 26, 28, 120], fill=hi)        # 左棱受光
    d.rectangle([36, 26, 40, 120], fill=sh)        # 右侧背光
    d.rectangle([24, 117, 40, 121], fill=sh)       # 底缘
    d.ellipse([18, 113, 46, 124], fill=(107, 85, 64, 255))   # 土堆基座（wood 族）
    for gx, gy in ((19, 111), (43, 112), (21, 117)):
        d.rectangle([gx, gy, gx + 2, gy + 3], fill=(78, 120, 78, 255))  # 草簇
    return img


def _make_shadow():
    """接触阴影贴片：纯黑 50% 棋盘抖动（alpha 二值）。"""
    img = _new_rgba(48, 16)
    d = _draw(img)
    d.ellipse([3, 4, 44, 13], fill=(0, 0, 0, 255))
    px = img.load()
    for y in range(16):
        for x in range(48):
            if px[x, y][3] and (x + y) % 2:
                px[x, y] = (0, 0, 0, 0)
    return img


# ---------------------------------------------------------------- QC

def _new_rgb(w=SIZE, h=SIZE):
    from PIL import Image
    return Image.new("RGB", (w, h))


def _new_rgba(w=SIZE, h=SIZE):
    from PIL import Image
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _new_l(w=SIZE, h=SIZE):
    from PIL import Image
    return Image.new("L", (w, h))


def _draw(img):
    from PIL import ImageDraw
    return ImageDraw.Draw(img)


def _check_seamless(img, name, fails):
    """无缝统计检验：接缝梯度不得远超内部相邻梯度均值。"""
    w, h = img.size
    px = img.load()

    def col_grad(x1, x2):
        s = sum(abs(px[x1, y][c] - px[x2, y][c]) for y in range(h) for c in range(3))
        return s / (h * 3)

    def row_grad(y1, y2):
        s = sum(abs(px[x, y1][c] - px[x, y2][c]) for x in range(w) for c in range(3))
        return s / (w * 3)

    inner_c = sum(col_grad(x, x + 1) for x in range(w - 1)) / (w - 1)
    bound_c = col_grad(w - 1, 0)
    inner_r = sum(row_grad(y, y + 1) for y in range(h - 1)) / (h - 1)
    bound_r = row_grad(h - 1, 0)
    for b, i, tag in ((bound_c, inner_c, "列"), (bound_r, inner_r, "行")):
        limit = max(1.6 * max(i, 0.35), 2.0)
        if b > limit:
            fails.append("%s 无缝检验失败：%s方向边界梯度 %.1f 超限 %.1f（内部均值 %.1f）"
                         % (name, tag, b, limit, i))


def _check_sprite(img, name, border, fails):
    w, h = img.size
    px = img.load()
    alphas = {px[x, y][3] for y in range(h) for x in range(w)}
    if alphas - {0, 255}:
        fails.append("%s alpha 非二值：%s" % (name, sorted(alphas - {0, 255})[:5]))
    if alphas == {0}:
        fails.append("%s 全透明" % name)
    for y in range(h):
        for x in range(w):
            if (x < border or y < border or x >= w - border or y >= h - border) and px[x, y][3]:
                fails.append("%s %dpx 安全边内出现不透明像素 (%d,%d)" % (name, border, x, y))
                return


def _verify_files(fails):
    from PIL import Image

    def load(key):
        return Image.open(os.path.join(ROOT, OUT[key])).convert("RGBA" if key != "grass" and key != "dirt" else "RGB")

    grass = load("grass")
    dirt = load("dirt")
    if grass.size != (SIZE, SIZE) or grass.mode != "RGB":
        fails.append("ground_grass 尺寸/模式错误: %s %s" % (grass.size, grass.mode))
    else:
        _check_seamless(grass, "ground_grass", fails)
    if dirt.size != (SIZE, SIZE) or dirt.mode != "RGB":
        fails.append("ground_dirt 尺寸/模式错误: %s %s" % (dirt.size, dirt.mode))
    else:
        _check_seamless(dirt, "ground_dirt", fails)

    trans = load("trans")
    if trans.size != (SIZE * 16, SIZE * 16):
        fails.append("trans_grass_dirt 尺寸错误: %s" % (trans.size,))
    else:
        px = trans.load()
        bad = {px[x, y][3] for y in range(trans.size[1]) for x in range(trans.size[0])} - {0, 255}
        if bad:
            fails.append("trans_grass_dirt alpha 非二值: %s" % sorted(bad)[:5])
        # 全泥配置 bm=255 → tile(15,15) 必须完全不透明（否则整块泥地出现透明洞）
        opaque = all(px[15 * SIZE + x, 15 * SIZE + y][3] == 255
                     for y in range(SIZE) for x in range(SIZE))
        if not opaque:
            fails.append("trans_grass_dirt bm=255 tile 非全不透明")

    with open(os.path.join(ROOT, OUT["trans_json"]), "r", encoding="utf-8") as f:
        meta = json.load(f)
    if meta.get("bits") != BITS:
        fails.append("trans_grass_dirt.json 位序与工具不一致")

    for key, size, border in (("seedling", (64, 64), 2), ("stone", (64, 128), 2), ("shadow", (48, 16), 1)):
        img = load(key)
        if img.size != size:
            fails.append("%s 尺寸错误: %s" % (OUT[key], img.size))
        else:
            _check_sprite(img, OUT[key], border, fails)


def _png_bytes(img):
    b = io.BytesIO()
    img.save(b, format="PNG")
    return b.getvalue()


def main():
    ap = __import__("argparse").ArgumentParser(description="Phase 0.4 占位美术生成/QC")
    ap.add_argument("--verify", action="store_true", help="只校验现有文件，不重新生成")
    ns = ap.parse_args()

    fails = []
    if not ns.verify:
        grass_r, dirt_r, leaf_r = _load_ramps()
        rng = random.Random(SEED)
        grass = _make_ground([grass_r["dark"], grass_r["base"], grass_r["base"], grass_r["hi"]],
                             grass_r["dot"], rng)
        dirt = _make_ground([dirt_r["deep"], dirt_r["base"], dirt_r["base"], dirt_r["hi"]],
                            dirt_r["dark"], rng)
        trans = _make_trans_atlas(dirt, dirt_r)
        seedling = _make_seedling(leaf_r)
        stone = _make_stone()
        shadow = _make_shadow()

        # 确定性：同参数重跑逐字节一致（沿用 demo R1 纪律）
        rng2 = random.Random(SEED)
        g2 = _make_ground([grass_r["dark"], grass_r["base"], grass_r["base"], grass_r["hi"]],
                          grass_r["dot"], rng2)
        if _png_bytes(g2) != _png_bytes(grass):
            fails.append("确定性检验失败：两次生成 grass 不一致")

        for key, img in (("grass", grass), ("dirt", dirt), ("trans", trans),
                         ("seedling", seedling), ("stone", stone), ("shadow", shadow)):
            path = os.path.join(ROOT, OUT[key])
            os.makedirs(os.path.dirname(path), exist_ok=True)
            img.save(path)
            print("[gen] %s" % OUT[key])
        meta = {
            "schema": 1,
            "tile": SIZE,
            "grid": [16, 16],
            "terrain": "dirt_over_grass",
            "bits": BITS,
            "bit_meaning": "置位 = 该方向邻格为泥土（同地形）",
            "atlas_of": "col = bitmask & 15, row = bitmask >> 4",
            "source_tool": "tools/farming/gen_phase00_textures.py",
            "seed": SEED,
        }
        with open(os.path.join(ROOT, OUT["trans_json"]), "w", encoding="utf-8") as f:
            json.dump(meta, f, ensure_ascii=False, indent=2)
        print("[gen] %s" % OUT["trans_json"])

    _verify_files(fails)
    if fails:
        for m in fails:
            print("[qc ] FAIL %s" % m)
        sys.exit(1)
    print("[qc ] 全部通过（无缝统计检验 / alpha 二值 / 安全边 / 尺寸 / 位序 / 确定性）")
    print("PHASE00 TEXTURES OK")


if __name__ == "__main__":
    main()
