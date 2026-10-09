# -*- coding: utf-8 -*-
"""ground 批次出图（dev 分支 farm 线 Phase 3，本机 ComfyUI 出图机角色）。

按 .art-work/handoff/ground/prompts.json 生成草地/泥土各 2 候选：
  ComfyUI Qwen-Image 2.1 1024² 出图 → BOX 面积平均降采样 128²（源图=64 整倍数）
  → 落盘 .art-work/raw/candidate_{a,b}/assets/farming/ground/<name>.png（manifest 原路径）

自包含最小 ComfyUI 客户端（不依赖旧线归档工具）；出图参数记录进 raw/gen_meta.json。
用法：python tools/farming/gen_ground_batch.py
"""
import json
import sys
import time
import urllib.request
import uuid
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent.parent
WORK = ROOT / ".art-work"
PROMPTS = WORK / "handoff" / "ground" / "prompts.json"
API = "http://127.0.0.1:8188"
BATCH = ["ground_grass", "ground_dirt"]          # 首批：草地/泥土（审核后再石板/耕地）
SEEDS = {("ground_grass", "a"): 202610091, ("ground_grass", "b"): 202610092,
         ("ground_dirt", "a"): 202610093, ("ground_dirt", "b"): 202610094}
STEPS, CFG, SAMPLER, SCHED = 25, 1.0, "euler", "simple"
GEN_SIZE = 1024                                   # 出图尺寸（降采样前）
RAW_SIZE = 128                                    # 契约源图尺寸（64 整倍数，本轮 128）


def gen(prompt: str, negative: str, seed: int, path: Path) -> None:
    """Qwen-Image 2.1 int8 文生图（本机 ComfyUI 栈），落盘 path。"""
    wf = {
        "unet": {"class_type": "UNETLoader", "inputs": {
            "unet_name": "qwen_image_2.1_int8_convrot.safetensors",
            "weight_dtype": "default"}},
        "clip": {"class_type": "CLIPLoader", "inputs": {
            "clip_name": "qwen3vl_8b_int8_convrot.safetensors",
            "type": "qwen_image", "device": "default"}},
        "vae": {"class_type": "VAELoader", "inputs": {
            "vae_name": "qwen_image_2.1_vae_bf16.safetensors"}},
        "enc": {"class_type": "TextEncodeQwenImage21", "inputs": {
            "clip": ["clip", 0], "prompt": prompt,
            "negative_prompt": negative, "resolution": 1024}},
        "lat": {"class_type": "EmptyLatentImage", "inputs": {
            "width": GEN_SIZE, "height": GEN_SIZE, "batch_size": 1}},
        "ks": {"class_type": "KSampler", "inputs": {
            "model": ["unet", 0], "positive": ["enc", 0], "negative": ["enc", 1],
            "latent_image": ["lat", 0], "seed": seed, "steps": STEPS, "cfg": CFG,
            "sampler_name": SAMPLER, "scheduler": SCHED, "denoise": 1.0}},
        "dec": {"class_type": "VAEDecode", "inputs": {
            "samples": ["ks", 0], "vae": ["vae", 0]}},
        "save": {"class_type": "SaveImage", "inputs": {
            "images": ["dec", 0], "filename_prefix": "rpgmap-farm"}},
    }
    data = json.dumps({"prompt": wf, "client_id": str(uuid.uuid4())}).encode()
    req = urllib.request.Request(API + "/prompt", data=data,
                                 headers={"Content-Type": "application/json"})
    resp = json.load(urllib.request.urlopen(req, timeout=180))
    if resp.get("node_errors"):
        raise RuntimeError(json.dumps(resp["node_errors"])[:400])
    pid = resp["prompt_id"]
    t0 = time.time()
    while True:
        time.sleep(2.5)
        with urllib.request.urlopen(API + f"/history/{pid}", timeout=60) as r:
            h = json.load(r)
        if pid not in h:
            if time.time() - t0 > 900:
                raise TimeoutError(f"{path.name} 生成超时(15min)")
            continue
        st = h[pid].get("status", {})
        if st.get("status_str") == "error":
            raise RuntimeError(json.dumps(st, ensure_ascii=False)[:400])
        if not st.get("completed"):
            continue
        for o in h[pid].get("outputs", {}).values():
            for img in o.get("images", []):
                u = (f"{API}/view?filename={img['filename']}"
                     f"&subfolder={img.get('subfolder', '')}&type={img.get('type', 'output')}")
                path.write_bytes(urllib.request.urlopen(u, timeout=120).read())
                return
        raise RuntimeError("完成但无输出图")


def main() -> None:
    items = [p for p in json.loads(PROMPTS.read_text(encoding="utf-8"))
             if Path(p["path"]).stem in BATCH]
    meta = {"workflow": "text2img UNET=qwen_image_2.1_int8_convrot "
                        "CLIP=qwen3vl_8b_int8_convrot VAE=qwen_image_2.1_vae_bf16",
            "steps": STEPS, "cfg": CFG, "sampler": f"{SAMPLER}/{SCHED}",
            "gen_size": GEN_SIZE, "downscale": "BOX area average -> 128",
            "candidates": {}}
    cache = WORK / "raw" / "_gen1024"
    cache.mkdir(parents=True, exist_ok=True)
    for it in items:
        stem = Path(it["path"]).stem
        for cand in ("a", "b"):
            seed = SEEDS[(stem, cand)]
            big = cache / f"{stem}_{cand}.png"
            if not big.exists():
                print(f"[gen] {stem} 候选{cand} seed={seed}", flush=True)
                gen(it["prompt"], it["negative"], seed, big)
            img = Image.open(big).convert("RGB").resize((RAW_SIZE, RAW_SIZE), Image.BOX)
            out = WORK / "raw" / f"candidate_{cand}" / it["path"]
            out.parent.mkdir(parents=True, exist_ok=True)
            img.save(out)
            meta["candidates"][f"{stem}_{cand}"] = {"seed": seed,
                    "raw": str(out.relative_to(ROOT))}
            print(f"[ok] {out.relative_to(ROOT)}", flush=True)
    (WORK / "raw" / "gen_meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    print("gen_meta.json written")


if __name__ == "__main__":
    main()
