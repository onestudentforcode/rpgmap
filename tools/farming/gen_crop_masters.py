# -*- coding: utf-8 -*-
"""crop_masters 批次出图（Phase 3 作物母版先行；本机 ComfyUI 出图机角色）。

按 .art-work/handoff/crop_masters/prompts.json 生成两种作物 mature 母版各 2 候选：
  Qwen-Image 1024²（提示词=包内 prompt + 纯洋红底子句——扩散无 alpha 通道，
  纯色键是管线协议认可路径）→ BOX→128² → 近洋红像素吸附回纯 #FF00FF
  （防边缘混合产生键控脏边）→ candidate_{cma,cmb}/<manifest 原路径>

后处理在本机 postprocess_assets --background '#ff00ff'（精确键去除）。
用法：python tools/farming/gen_crop_masters.py
"""
import json
import sys
import time
import urllib.request
import uuid
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "tools" / "farming"))
from gen_ground_batch import gen  # 复用自包含 ComfyUI 客户端（同栈同参）

WORK = ROOT / ".art-work"
PROMPTS = WORK / "handoff" / "crop_masters" / "prompts.json"
SEEDS = {"dew_grass_a": 202610111, "dew_grass_b": 202610112,
         "scarlet_berry_a": 202610113, "scarlet_berry_b": 202610114}
MAGENTA_CLAUSE = (", rendered on a solid flat pure magenta background "
                  "color #FF00FF filling every pixel of empty space around "
                  "the single subject, no drop shadow on the background")
GEN_SIZE, RAW_SIZE = 1024, 128


def snap_magenta(im: Image.Image) -> Image.Image:
    """BOX 降采样后边缘混色→吸附回纯洋红，保证 --background 精确键控干净。"""
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b = px[x, y]
            if r > 170 and b > 170 and g < min(r, b) - 60:
                px[x, y] = (255, 0, 255)
    return im


def main() -> None:
    items = json.loads(PROMPTS.read_text(encoding="utf-8"))
    meta = {"workflow": "same stack as gen_ground_batch (qwen_image_2.1 int8)",
            "prompt_mod": "出图机追加纯洋红底子句（管线协议：纯色键回传）",
            "candidates": {}}
    cache = WORK / "raw" / "_gen1024_cm"
    cache.mkdir(parents=True, exist_ok=True)
    for it in items:
        crop = Path(it["path"]).parent.name  # dew_grass / scarlet_berry
        for cand in ("a", "b"):
            seed = SEEDS[f"{crop}_{cand}"]
            big = cache / f"{crop}_mature_{cand}.png"
            if not big.exists():
                print(f"[gen] {crop} 母版候选{cand} seed={seed}", flush=True)
                gen(it["prompt"] + MAGENTA_CLAUSE, it["negative"], seed, big)
            img = Image.open(big).convert("RGB").resize((RAW_SIZE, RAW_SIZE), Image.BOX)
            img = snap_magenta(img)
            out = WORK / "raw" / f"candidate_cm{cand}" / it["path"]
            out.parent.mkdir(parents=True, exist_ok=True)
            img.save(out)
            meta["candidates"][f"{crop}_{cand}"] = {"seed": seed,
                    "raw": str(out.relative_to(ROOT))}
            print(f"[ok] {out.relative_to(ROOT)}", flush=True)
    (WORK / "raw" / "gen_meta_cm.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    print("gen_meta_cm.json written")


if __name__ == "__main__":
    main()
