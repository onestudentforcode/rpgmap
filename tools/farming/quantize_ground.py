# -*- coding: utf-8 -*-
"""地面纹理源图重着色（出图机源图预备，Phase 3 v2.1）。

背景：Qwen-Image 对"离散平涂色阶"的文字约束不敏感（v1/v2 两轮实测成品
σ≈1~2、亮度 4 阶割 90%+ 同阶 = 纯色块）。本工具用确定性图像处理把 AI 出图
的微弱明暗变化放大成真实色阶结构：

  亮度分位拉伸（plo/phi → 锚点色亮度域）→ 3×3 中值去噪（可选）→ 最近锚点色吸附

产物特性：仅含 palette.json 对应地物的锚点色；簇形状继承自 AI 出图的
中频变化（有机，非手工盖章）；参数按资产逐个可调（--params JSON）。

用法：
  python tools/farming/quantize_ground.py --input <128源图目录> --output <输出目录>
      [--terrain-map '{"ground_grass.png":"grass",...}']
      [--params '{"grass":[0.15,0.95,false], "dirt":[0.05,0.85,true]}']
  参数三元组 = [下分位, 上分位, 中值滤波]；缺省用扫描优选值（见 DEFAULTS）。
"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent.parent


def load_palette() -> dict:
    p = json.loads((ROOT / "tools/farming/palette.json").read_text(encoding="utf-8"))
    return {t: [tuple(int(h.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)) for h in cs]
            for t, cs in p["ground"].items()}


# 2026-10-09 扫描优选（目标 base 60-75 / secondary 20-30 / accent≥3）
DEFAULTS = {
    "grass": [0.15, 0.95, False],
    "dirt": [0.05, 0.85, True],
    "stone": [0.10, 0.90, True],
    "tilled": [0.10, 0.90, True],
}


def requant(img: Image.Image, anchors: list, plo: float, phi: float, med: bool) -> Image.Image:
    im = img.convert("RGB")
    px = list(im.getdata())
    lum = sorted(0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2] for p in px)
    lo = lum[int(len(lum) * plo)]
    hi = lum[min(len(lum) - 1, int(len(lum) * phi))]
    al = sorted(0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2] for c in anchors)
    out = im.copy()
    po, pi = out.load(), im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b = pi[x, y]
            lum_px = 0.3 * r + 0.59 * g + 0.11 * b
            s = al[0] + (min(hi, max(lo, lum_px)) - lo) / (hi - lo + 1e-6) * (al[-1] - al[0])
            k = s / (lum_px + 1e-6)
            po[x, y] = (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)))
    if med:
        out = out.filter(ImageFilter.MedianFilter(3))
    po = out.load()
    for y in range(out.height):
        for x in range(out.width):
            c = po[x, y]
            po[x, y] = min(anchors, key=lambda a: sum((a[i] - c[i]) ** 2 for i in range(3)))
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, help="128 源图根目录（含 assets/farming/ground/...）")
    ap.add_argument("--output", required=True, help="requant 后源图输出根目录")
    ap.add_argument("--params", default="{}", help="逐地物参数覆盖 JSON")
    args = ap.parse_args()
    params = {**DEFAULTS, **json.loads(args.params)}
    palette = load_palette()
    src_root = Path(args.input)
    out_root = Path(args.output)
    for png in sorted((src_root / "assets/farming/ground").glob("ground_*.png")):
        terrain = png.stem.removeprefix("ground_")
        if terrain not in palette:
            continue
        plo, phi, med = params[terrain]
        q = requant(Image.open(png), palette[terrain], plo, phi, med)
        dest = out_root / png.relative_to(src_root)
        dest.parent.mkdir(parents=True, exist_ok=True)
        q.save(dest)
        from collections import Counter
        cc = Counter(list(q.getdata()))
        n = q.width * q.height
        share = [k * 100 // n for _, k in cc.most_common(4)]
        print(f"[requant] {terrain}: {len(cc)} 色 占比 {share} 参数({plo},{phi},med={med})")


if __name__ == "__main__":
    main()
