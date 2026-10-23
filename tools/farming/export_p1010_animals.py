# -*- coding: utf-8 -*-
"""P10.10 动物视野叠层：运行缩略图导出。

从 p109 source 两个清单读取 17 种养殖条目的成体/幼体图，产出：
- assets/farming/p109/runtime/animals/<species>/{adult,juvenile}.png
  （96px 方形画布、alpha 裁剪、保持原比例、底边中心锚点）
- assets/farming/p109/runtime/animal_manifest.json（路径/sha256/画布/锚点/显示尺寸）

仅做尺寸与画布整理，不修内容（沿用 P10.9 接入规则）。可重复运行，幂等覆盖。
"""
import hashlib
import json
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "farming", "p109", "source")
OUT_DIR = os.path.join(ROOT, "assets", "farming", "p109", "runtime", "animals")
OUT_MANIFEST = os.path.join(ROOT, "assets", "farming", "p109", "runtime", "animal_manifest.json")
CANVAS = 96
HABITAT = {"bell_bee", "purifying_mat"}  # 关联设施的群体条目，同表处理


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 16), b""):
            h.update(block)
    return h.hexdigest()


ANIMAL_CATEGORIES = {"animals", "aquatic", "living"}  # 陆生/水生/设施关联群体


def collect():
    stages = {}
    adult = json.load(open(os.path.join(SRC, "manifest.json"), encoding="utf-8"))
    for row in adult["assets"]:
        if row.get("category") not in ANIMAL_CATEGORIES:
            continue
        stages.setdefault(row["id"], {})["adult"] = os.path.join(SRC, row["file"])
    states = json.load(open(os.path.join(SRC, "states_manifest.json"), encoding="utf-8"))
    for row in states["assets"]:
        if row.get("category") not in ANIMAL_CATEGORIES or row.get("state") != "juvenile":
            continue
        stages.setdefault(row["id"], {})["juvenile"] = os.path.join(SRC, row["file"])
    return stages


def export_one(src, dst):
    im = Image.open(src).convert("RGBA")
    alpha = im.getchannel("A")
    box = alpha.getbbox()
    if box:
        im = im.crop(box)
    w, h = im.size
    scale = min((CANVAS - 8) / w, (CANVAS - 8) / h)
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    im = im.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.paste(im, ((CANVAS - nw) // 2, CANVAS - 4 - nh), im)
    canvas.save(dst)
    return {"canvas_px": [CANVAS, CANVAS], "anchor_uv": [0.5, (CANVAS - 4) / CANVAS],
            "aspect": round(nh / nw, 3)}


def main():
    stages = collect()
    manifest = {"schema_version": 1, "profile": "p109", "texture_filter": "linear",
                "note": "P10.10 animal view thumbnails; display-only, no gameplay semantics",
                "species": {}}
    names = {}
    for row in json.load(open(os.path.join(SRC, "manifest.json"), encoding="utf-8"))["assets"]:
        names[row["id"]] = row.get("name", row["id"])
    for species, arts in sorted(stages.items()):
        entry = {"name": names.get(species, species), "habitat_facility": species in HABITAT,
                 "stages": {}}
        for stage, src in sorted(arts.items()):
            out_dir = os.path.join(OUT_DIR, species)
            os.makedirs(out_dir, exist_ok=True)
            dst = os.path.join(out_dir, "%s.png" % stage)
            meta = export_one(src, dst)
            meta["path"] = "res://assets/farming/p109/runtime/animals/%s/%s.png" % (species, stage)
            meta["sha256"] = sha256(dst)
            entry["stages"][stage] = meta
        manifest["species"][species] = entry
        print("EXPORT %s: %s" % (species, " ".join(sorted(arts))))
    json.dump(manifest, open(OUT_MANIFEST, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    total = sum(len(e["stages"]) for e in manifest["species"].values())
    print("MANIFEST %s species=%d images=%d -> %s" % (
        len(manifest["species"]), len(manifest["species"]), total, OUT_MANIFEST))


if __name__ == "__main__":
    main()
