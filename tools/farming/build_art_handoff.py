#!/usr/bin/env python3
"""Build reproducible, offline ComfyUI handoff packages; never changes art status."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
from asset_common import ROOT, load_palette
from gen_asset_manifest import build_manifest

GROUND_DESC = {
    "grass": "muted green grass, sparse short grass clusters, no large repeated clumps",
    "dirt": "warm brown soil, restrained small soil clods, no bright stones",
    "stone": "gray green stone slabs, 64px repeating seams on this 128px canvas, no perspective",
    "tilled": "dark warm brown cultivated soil, horizontal furrows repeated every 32px on this 128px canvas",
}
STAGE_DESC = {"seed": "small planted seed, no soil mound", "sprout": "small seedling",
              "growing": "young plant smaller than mature reference", "mature": "fully mature plant",
              "harvested": "same mature plant with all fruit removed, healthy leaves",
              "exhausted": "same plant exhausted, gray brown drooping leaves, no fruit"}


def build(batch, output):
    all_entries = build_manifest()["assets"]
    def selected(e):
        if batch == "ground":
            return e["type"] == "ground"
        if e["type"] != "crop_stage":
            return False
        if batch == "crop_masters":
            return e.get("stage") == "mature"
        return e["path"].split("/")[-2] == batch and e.get("stage") != "mature"
    entries = [e for e in all_entries if selected(e)]
    if output.exists() and any(output.iterdir()):
        raise ValueError("output must be empty; use a new package directory")
    output.mkdir(parents=True, exist_ok=True)
    palette = load_palette()
    (output / "manifest.json").write_text(json.dumps({"schema": 1, "batch": batch, "assets": entries}, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    shutil.copy2(ROOT / "docs/farming/art-style-sheet.md", output / "art-style-sheet.md")
    shutil.copy2(ROOT / "tools/farming/palette.json", output / "palette.json")
    prompts = []
    for entry in entries:
        rel = entry["path"]
        source = ROOT / rel
        if source.is_file():
            dest = output / "references" / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, dest)
        if entry["type"] == "ground":
            terrain = Path(rel).stem.removeprefix("ground_")
            colors = palette["ground"][terrain]
            # v2 模板（2026-10-09）：首版 "low contrast, 2-4 tonal steps" 被模型理解为
            # 平滑弱对比晕染（成品 σ≈1.8、亮度 4 阶割 90% 同阶=纯色块）。改为强制
            # 离散平涂色阶 + 覆盖占比 + 锚点色为唯一用色；去掉 low contrast。
            prompt = ("128x128 pixel art tile, seamless in all four directions, "
                      "flat top-down surface, exactly 3 flat tonal steps with hard "
                      "pixel edges between steps: base tone about 70 percent coverage, "
                      "darker cluster tone about 25 percent, light accent tone about "
                      "5 percent, no smooth gradients between steps, low-medium "
                      "frequency detail with visible distinct clusters, "
                      + GROUND_DESC[terrain])
            prompt += ", use only these flat colors: " + ", ".join(colors)
            reference = None
        else:
            crop = Path(rel).parent.name
            identity = "slender green medicinal grass with dew drops attached to leaves" if crop == "dew_grass" else "rounded green shrub with scarlet berries"
            colors = palette["crops"]["leaf"] + palette["crops"]["dew" if crop == "dew_grass" else "berry"]
            if entry["stage"] == "exhausted":
                colors = palette["crops"]["wither"]
            prompt = "128x128 pixel art, muted oriental cultivation fantasy plant, single isolated sprite, non-isometric oblique overhead 2.5D rear-side 45 degree view, upper-left light at 10-11 o'clock, transparent background, centered ground contact with 4px bottom padding, " + identity + ", " + STAGE_DESC[entry["stage"]]
            if entry["stage"] == "mature":
                prompt += ", subject height 55-75 percent of canvas"
            else:
                prompt += ", preserve approved mature reference leaf shape, hue, view and lighting"
            reference = None if entry["stage"] == "mature" else f"approved/assets/farming/crops/{crop}/stage_3.png"
            prompt += ", palette anchors " + ", ".join(colors)
        prompts.append({"path": rel, "candidates": 2 if batch in ("ground", "crop_masters") else 1,
                        "reference_required": reference, "prompt": prompt,
                        "negative": "isometric, scene, text, watermark, bloom, glow, anti-aliasing, photorealistic, smooth gradients, sprite sheet" + (", ground, soil mound, contact shadow, translucent edges" if entry["type"] == "crop_stage" else ", perspective, directional shadow, transparent background")})
    (output / "prompts.json").write_text(json.dumps(prompts, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    readme = """# ComfyUI 回传说明

参考图目录 references/ 全部是占位图，只示意结构。风格以 art-style-sheet.md 与 palette.json 为准。
按 prompts.json 逐张出图；ground 分两轮：grass+dirt 各2候选审核后，再 stone+tilled 各2。
作物先母版，人工审核通过后才允许衍生；reference_required 指向审核后的正式母版，不能使用占位图代替。
不锁定未经验证的模型或工作流；由出图机选择可用工作流，回传必须附 workflow JSON、模型版本、seed、采样器、steps、CFG、提示词及参考图记录。

各候选放独立 raw/candidate_a/ 或 raw/candidate_b/ 根目录，内部按 manifest 中 assets/farming/... 原路径放置；128×128 PNG。
作物优先透明背景；若采用纯色背景，记录准确 hex 色键，本机用 --background 指定。地面完全不透明。
缺少出图机能力或参考母版时停止对应任务并说明原因，禁止把占位图标成正式图。

本机处理示例（项目根目录）：
```
python tools/farming/postprocess_assets.py --manifest .art-work/handoff/ground/manifest.json --input .art-work/raw/candidate_a --output .art-work/processed/run_a
```
部分回传请用只包含该批资产的 manifest；缺图会报错。处理结果包含 qc_report.json 和地面 previews/*_3x3.png。
通过 QC 和人工平铺审核后，仅将选中 PNG 同名复制到正式资产路径，然后依次运行：
```
python tools/farming/gen_farm_terrains.py --transitions-only
python tools/farming/qc_assets.py --target all --report .art-work/reports/all.json
play.bat farm --farmtest
play.bat farm --farm-shots=.shots/farm-phase03
```
截图视觉审核通过后才登记 art_status.json delivered，重跑 gen_asset_manifest.py，并分阶段提交。
已出图但未验收的文件保留 requested；禁止运行占位图生成器覆盖正式图。
"""
    (output / "README.md").write_text(readme, encoding="utf-8")
    hashes = {p.relative_to(output).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in sorted(output.rglob("*")) if p.is_file()}
    (output / "checksums.json").write_text(json.dumps(hashes, indent=2)+"\n", encoding="utf-8")
    print(f"HANDOFF OK: {batch}, {len(entries)} assets -> {output}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--batch", choices=["ground", "crop_masters", "dew_grass", "scarlet_berry"], required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        build(args.batch, args.output.resolve())
    except (OSError, ValueError) as exc:
        parser.exit(1, str(exc)+"\n")


if __name__ == "__main__":
    main()
