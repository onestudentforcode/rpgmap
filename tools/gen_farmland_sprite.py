"""gen_farmland_sprite.py — 耕地白模顶视渲染底图 → 星露谷风像素精灵（干/湿两版）

管线：Blender 白模（2x2m，6 条垄）正交俯视渲染 512x512（洋红背景）
  → 背景就近填充为不透明亮度图 → 旋转 90°（垄线竖转横、受光面朝上）
  → 面积平均降到 64x64 像素网格（= 2x2 瓦片，行距与星露谷密度一致）
  → 2%~98% 对比度拉伸 + 5 级坡道量化（4x4 Bayer 微抖动）
  → 按 tools/farmland_palette.json 坡道着色，输出 dry / wet 两版 + 草地背景预览

用法：
    python tools/gen_farmland_sprite.py
    python tools/gen_farmland_sprite.py --size 64 --palette tools/farmland_palette.json
"""
import argparse
import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

RES = getattr(Image, "Resampling", Image)

BAYER4 = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]

BAYER_STRENGTH = 0.5  # 抖动幅度（一级色阶的比例）


def despeckle(steps, size):
    """孤立色点向四邻多数收敛：≥3 个正交邻居同色阶且自身不同时改写。"""
    sp = steps.load()
    changes = 0
    for y in range(size):
        for x in range(size):
            s = sp[x, y]
            neigh = [sp[nx, ny]
                     for nx, ny in ((x-1, y), (x+1, y), (x, y-1), (x, y+1))
                     if 0 <= nx < size and 0 <= ny < size]
            for n in set(neigh):
                if n != s and neigh.count(n) >= 3:
                    sp[x, y] = n
                    changes += 1
                    break
    return changes


def hex_rgb(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def is_bg(r, g, b):
    """渲染时的纯洋红背景判定。"""
    return r > 200 and b > 200 and g < 140


def defill_background(img):
    """洋红背景按行就近替换为相邻土壤亮度 → 整幅不透明的亮度图（返回 'L'）。"""
    w, h = img.size
    px = img.load()
    lum = Image.new("L", (w, h))
    lp = lum.load()
    for y in range(h):
        vals = [(r * 299 + g * 587 + b * 114) // 1000
                for (r, g, b) in (px[x, y] for x in range(w))]
        x = 0
        while x < w:
            if is_bg(*px[x, y]):
                x0 = x
                while x < w and is_bg(*px[x, y]):
                    x += 1
                left = vals[x0 - 1] if x0 > 0 else None
                right = vals[x] if x < w else None
                fill = left if right is None else (right if left is None else (left + right) // 2)
                for xi in range(x0, x):
                    vals[xi] = fill if fill is not None else 128
            else:
                x += 1
        for xi in range(w):
            lp[xi, y] = vals[xi]
    return lum


def quantize_steps(lum, size, levels, eq_blend=0.75):
    """映射到坡道序号（0=最暗）。

    定向光下向阳面/背阴面亮度呈双峰，纯线性拉伸会只命中坡道两端；
    用「秩次直方图均衡 + 线性拉伸」按 EQ_BLEND 混合，保证中间色阶被用上，
    同时保留明暗结构的自然权重。Bayer 4x4 微抖动软化色阶边界。
    """
    data = list(lum.getdata())
    lo, hi = min(data), max(data)
    span = max(1, hi - lo)
    order = sorted(range(len(data)), key=lambda i: data[i])
    rank = [0.0] * len(data)
    for r, i in enumerate(order):
        rank[i] = r / max(1, len(data) - 1)
    print("[INFO] 亮度十分位:", [data[int(len(data) * k / 10)] for k in range(10)], "max", hi)
    out = Image.new("L", (size, size))
    op = out.load()
    step_jitter = BAYER_STRENGTH / levels
    for y in range(size):
        for x in range(size):
            i = y * size + x
            v_lin = (data[i] - lo) / span
            v = eq_blend * rank[i] + (1 - eq_blend) * v_lin
            j = (BAYER4[y % 4][x % 4] / 16.0 - 0.5) * step_jitter
            q = int((v + j) * levels)
            op[x, y] = 0 if q < 0 else (levels - 1 if q >= levels else q)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default=os.path.join(ROOT, "assets/models/farmland_top_base.png"))
    ap.add_argument("--out", default=os.path.join(ROOT, "assets/sprites/farmland"))
    ap.add_argument("--palette", default=os.path.join(ROOT, "tools/farmland_palette.json"))
    ap.add_argument("--size", type=int, default=64, help="输出边长（像素）；64=2x2 瓦片")
    args = ap.parse_args()

    with open(args.palette, encoding="utf-8") as f:
        pal = json.load(f)
    levels = pal["levels"]
    ramps = {name: [hex_rgb(c) for c in colors] for name, colors in pal["ramps"].items()}

    img = Image.open(args.base).convert("RGB")
    lum = defill_background(img)
    lum = lum.rotate(90, expand=True)  # 垄线竖转横，受光面转到画面上方
    lum = lum.resize((args.size, args.size), RES.BOX)

    os.makedirs(args.out, exist_ok=True)
    steps = quantize_steps(lum, args.size, levels)
    print("[INFO] despeckle 收敛点:", despeckle(steps, args.size))

    outputs = {}
    for name, ramp in ramps.items():
        out_img = Image.new("RGB", (args.size, args.size))
        op = out_img.load()
        for y in range(args.size):
            for x in range(args.size):
                op[x, y] = ramp[steps.getpixel((x, y))]
        path = os.path.join(args.out, "farmland_%s_%d.png" % (name, args.size))
        out_img.save(path)
        outputs[name] = (path, out_img)

    # ---- 预览：草地背景上并排（NEAREST 放大 3x）----
    bg = hex_rgb(pal.get("preview_bg", "#79a05c"))
    scale, margin, gap = 3, 10, 12
    names = list(outputs)
    pw = margin * 2 + args.size * scale * len(names) + gap * (len(names) - 1)
    ph = margin * 2 + args.size * scale
    prev = Image.new("RGB", (pw, ph), bg)
    for i, name in enumerate(names):
        big = outputs[name][1].resize((args.size * scale, args.size * scale), RES.NEAREST)
        prev.paste(big, (margin + i * (args.size * scale + gap), margin))
    prev_path = os.path.join(args.out, "preview.png")
    prev.save(prev_path)

    # ---- QC：尺寸 / 色板封闭 / 全不透明 ----
    ok = True
    for name, (path, out_img) in outputs.items():
        ramp = set(ramps[name])
        w, h = out_img.size
        usage = {}
        bad = 0
        for c in out_img.getdata():
            if c not in ramp:
                bad += 1
            usage[c] = usage.get(c, 0) + 1
        if (w, h) != (args.size, args.size) or bad:
            ok = False
        hist = " ".join("%s:%d" % ("".join("%02x" % v for v in c), n)
                        for c, n in sorted(usage.items(), key=lambda kv: -kv[1]))
        print("[QC] %-4s %dx%d 离板像素=%d %s" % (name, w, h, bad, "OK" if not bad else "FAIL"))
        print("     色阶用量 %s" % hist)
    print("[QC] preview %s" % prev_path)
    print("QC %s" % ("OK" if ok else "FAIL"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
