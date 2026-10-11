# -*- coding: utf-8 -*-
"""作物阶段衍生批次出图（Phase 3；本机 ComfyUI 出图机角色）。

对 dew_grass（3 项）/ scarlet_berry（5 项）衍生阶段：以**审核母版**为参考图
（参考锚定叶形/色相/视角/光照），每张独立生成（禁整表），提示词来自移交包
prompts.json + 纯洋红底子句；1024² → BOX→128² → 近洋红吸附 → 候选目录。

参考图准备：approved 母版（64 RGBA）→ NEAREST×8 平铺到 512 纯洋红底
（透明洞直接上传会变黑，必须先铺底）。
用法：python tools/farming/gen_crop_stages.py [--only dew_grass|scarlet_berry]
"""
import argparse
import json
import sys
import time
import urllib.request
import uuid
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "tools" / "farming"))
from gen_ground_batch import gen  # noqa: E402  文生图客户端（自包含）

WORK = ROOT / ".art-work"
API = "http://127.0.0.1:8188"
MAGENTA_CLAUSE = (", rendered on a solid flat pure magenta background "
                  "color #FF00FF filling every pixel of empty space around "
                  "the single subject, no drop shadow on the background")
BATCHES = ["dew_grass", "scarlet_berry"]
SEED_BASE = 202610121
GEN_SIZE, RAW_SIZE = 1024, 128


def upload(path: Path) -> str:
    boundary = uuid.uuid4().hex
    body = (f"--{boundary}\r\nContent-Disposition: form-data; "
            f'name="image"; filename="{path.name}"\r\n'
            f"Content-Type: image/png\r\n\r\n").encode() + path.read_bytes() \
        + f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request(
        API + "/upload/image?overwrite=true", data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
    return json.load(urllib.request.urlopen(req, timeout=120))["name"]


def gen_ref(prompt: str, negative: str, seed: int, path: Path, ref_png: Path) -> None:
    """参考图生成：TextEncodeQwenImage21.images 传母版，其第 3 输出作初始 latent。"""
    ref_name = upload(ref_png)
    wf = {
        "unet": {"class_type": "UNETLoader", "inputs": {
            "unet_name": "qwen_image_2.1_int8_convrot.safetensors",
            "weight_dtype": "default"}},
        "clip": {"class_type": "CLIPLoader", "inputs": {
            "clip_name": "qwen3vl_8b_int8_convrot.safetensors",
            "type": "qwen_image", "device": "default"}},
        "vae": {"class_type": "VAELoader", "inputs": {
            "vae_name": "qwen_image_2.1_vae_bf16.safetensors"}},
        "ref": {"class_type": "LoadImage", "inputs": {"image": ref_name}},
        "enc": {"class_type": "TextEncodeQwenImage21", "inputs": {
            "clip": ["clip", 0], "prompt": prompt,
            "negative_prompt": negative, "resolution": 1024,
            "images": [["ref", 0]], "vae": ["vae", 0]}},
        "ks": {"class_type": "KSampler", "inputs": {
            "model": ["unet", 0], "positive": ["enc", 0], "negative": ["enc", 1],
            "latent_image": ["enc", 2], "seed": seed, "steps": 25, "cfg": 1.0,
            "sampler_name": "euler", "scheduler": "simple", "denoise": 1.0}},
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
        try:
            with urllib.request.urlopen(API + f"/history/{pid}", timeout=60) as r:
                h = json.load(r)
        except (urllib.error.URLError, TimeoutError, OSError):
            # 轮询瞬时网络故障：退避重试，总时长仍受 15min 上限约束
            time.sleep(10)
            continue
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


def snap_magenta(im: Image.Image) -> Image.Image:
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b = px[x, y]
            if r > 170 and b > 170 and g < min(r, b) - 60:
                px[x, y] = (255, 0, 255)
    return im


def prep_reference(batch: str, cache: Path) -> Path:
    """审核母版 64 → NEAREST×8 放大到 512，平铺纯洋红底（透明洞防黑）。"""
    master = WORK / "handoff" / batch / "approved" / "assets/farming/crops" / batch / "stage_3.png"
    m = Image.open(master).convert("RGBA").resize((512, 512), Image.NEAREST)
    ref = Image.new("RGBA", (512, 512), (255, 0, 255, 255))
    ref.alpha_composite(m)
    out = cache / f"ref_{batch}.png"
    ref.save(out)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", choices=BATCHES)
    args = ap.parse_args()
    batches = [args.only] if args.only else BATCHES
    meta = {"workflow": "reference-anchored (TextEncodeQwenImage21 images)",
            "prompt_mod": MAGENTA_CLAUSE[:40] + "...", "candidates": {}}
    cache = WORK / "raw" / "_gen1024_cs"
    cache.mkdir(parents=True, exist_ok=True)
    seed = SEED_BASE
    for batch in batches:
        items = json.loads((WORK / "handoff" / batch / "prompts.json").read_text(encoding="utf-8"))
        ref_png = prep_reference(batch, cache)
        for it in items:
            stage = Path(it["path"]).stem  # stage_0/1/2/harvested/exhausted
            big = cache / f"{batch}_{stage}.png"
            if not big.exists():
                print(f"[gen] {batch}/{stage} seed={seed}", flush=True)
                gen_ref(it["prompt"] + MAGENTA_CLAUSE, it["negative"], seed, big, ref_png)
            img = Image.open(big).convert("RGB").resize((RAW_SIZE, RAW_SIZE), Image.BOX)
            img = snap_magenta(img)
            out = WORK / "raw" / f"candidate_{batch}" / it["path"]
            out.parent.mkdir(parents=True, exist_ok=True)
            img.save(out)
            meta["candidates"][f"{batch}/{stage}"] = {"seed": seed}
            seed += 1
            print(f"[ok] {out.relative_to(ROOT)}", flush=True)
    (WORK / "raw" / "gen_meta_cs.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    print("gen_meta_cs.json written")


if __name__ == "__main__":
    main()
