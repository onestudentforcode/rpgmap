#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen_asset_manifest.py — 灵植模块资产清单/采购单生成（phase-03 §6）

读 content/farming/baked/（terrains + crops，数据驱动：改源数据 → bake → 重跑本工具，
新资产自动出现在清单里），对账 assets/farming/ 实际文件，产出：
  content/farming/baked/asset_manifest.json   机读清单（进 git）
  控制台人读摘要（缺什么 / 有什么 / 规格是什么）

status 语义（采购流）：
  missing      文件不存在
  placeholder  占位图在库（现行状态；同名覆盖即替换，git 可回滚）
  requested    已列入采购移交包（content/farming/art_status.json 登记）
  delivered    正式图已入库且过 QC（art_status.json 登记）
  generated    程序生成物（过渡 atlas / 阴影贴片），不外发采购，改输入后重生成

状态登记文件 content/farming/art_status.json（手工/流程维护）：
  { "assets/farming/ground/ground_grass.png": {"status": "requested", "note": "2026-10-09 移交"} }

范围说明：phase00 历史验证场景私有素材（crops/_placeholder/ 的 stage_0、tall_stone）
不在本清单；其共享的 shadow_ellipse 以 utility 身份列入。

用法：
  python tools/farming/gen_asset_manifest.py             生成清单 + 摘要
  python tools/farming/gen_asset_manifest.py --missing   仅列缺失/待办（有缺失 exit 1）
"""

import json
import os
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
BAKED = os.path.join(ROOT, "content", "farming", "baked")
ASSETS = os.path.join(ROOT, "assets", "farming")
STATUS_FILE = os.path.join(ROOT, "content", "farming", "art_status.json")

# 地形→色相族（phase-03 §2.3 / style-sheet 锚点；色值锁定在 tools/farming/palette.json，P3-C）
FAMILY = {
    "grass": "草绿族（wilds floor_a 系）",
    "dirt": "暖棕族（wilds carpet 系）",
    "stone": "灰绿碎石族（wilds corr 系）",
    "tilled": "暖棕暗族（carpet 暗系 + 垄沟）",
}

GROUND_CONSTRAINTS = ["64×64 RGB 无 alpha", "四向无缝（边界梯度≤内部最大×1.3）",
                      "周期结构线整除 64", "中低频细节 2–4 色阶"]
SPRITE_CONSTRAINTS = ["64×64 RGBA 透明底", "alpha 二值（0/255）", "2px 全透明安全边",
                      "底部中心锚点（贴地）", "斜俯视 2.5D、光从左上", "无孤岛像素簇"]
MATURE_EXTRA = ["成熟期主体占画布 55–75%"]


def _load(name):
    with open(os.path.join(BAKED, name), "r", encoding="utf-8") as f:
        return json.load(f)


def _rel(path):
    return os.path.relpath(path, ROOT).replace("\\", "/")


def _status_for(rel_path, overrides):
    if not os.path.isfile(os.path.join(ROOT, rel_path)):
        return "missing", overrides.get(rel_path, {}).get("note", "")
    if rel_path in overrides:
        return overrides[rel_path].get("status", "placeholder"), overrides[rel_path].get("note", "")
    return "placeholder", ""


def build_manifest():
    terrains = _load("terrains.json")
    crops = _load("crops.json")
    overrides = {}
    if os.path.isfile(STATUS_FILE):
        with open(STATUS_FILE, "r", encoding="utf-8") as f:
            overrides = json.load(f)

    entries = []
    # —— 地面纹理（AI 采购项）+ 过渡 atlas（程序生成项）——
    for t in terrains["terrains"]:
        tid = t["id"]
        rel = "assets/farming/ground/ground_%s.png" % tid
        st, note = _status_for(rel, overrides)
        entries.append({
            "path": rel, "type": "ground", "status": st, "note": note,
            "size": [64, 64],
            "constraints": GROUND_CONSTRAINTS + ["色相族：" + FAMILY.get(tid, "待定")],
            "refs": ["terrain:%s（%s）" % (tid, t["name"])],
        })
        if int(t["layer"]) > 0 or t["dynamic"]:
            for suffix, kind in ((".png", "atlas"), (".json", "atlas_meta")):
                rel_t = "assets/farming/transitions/trans_upper_%s%s" % (tid, suffix)
                exists = os.path.isfile(os.path.join(ROOT, rel_t))
                entries.append({
                    "path": rel_t, "type": kind, "status": "generated" if exists else "missing",
                    "note": "改 ground 后运行 gen_farm_terrains.py --transitions-only 重生成（保留 ground）",
                    "size": [1024, 1024] if kind == "atlas" else None,
                    "constraints": ["程序生成：上层纹理 × 统一掩码（不外发采购）",
                                    "alpha 二值；bm=255 tile 全不透明"],
                    "refs": ["terrain:%s" % tid],
                })

    # —— 作物阶段 Sprite（AI 采购项）——
    for c in crops["crops"]:
        cid = c["crop_id"]
        stages = c["growth_stages"]
        size = c.get("sprite_size", [64, 64])
        sprite_constraints = list(SPRITE_CONSTRAINTS)
        sprite_constraints[0] = "%d×%d RGBA 透明底" % tuple(size)
        for i, s in enumerate(stages):
            rel = "assets/farming/crops/%s/%s.png" % (cid, s["sprite"])
            st, note = _status_for(rel, overrides)
            cons = list(sprite_constraints)
            if i == len(stages) - 1:
                cons += MATURE_EXTRA
            entries.append({
                "path": rel, "type": "crop_stage", "status": st, "note": note,
                "size": size, "stage": s["id"], "constraints": cons,
                "refs": ["crop:%s（%s/%s，%s）" % (cid, c["name"], c["category"], c["harvest_type"])],
            })
        if c["harvest_type"] == "regrow":
            for sprite, stage_name, desc in (
                    ("stage_harvested", "harvested", "采收后再生长形态（无果）"),
                    ("stage_exhausted", "exhausted", "枯竭形态（灰褐下垂，待清理）")):
                rel = "assets/farming/crops/%s/%s.png" % (cid, sprite)
                st, note = _status_for(rel, overrides)
                entries.append({
                    "path": rel, "type": "crop_stage", "status": st, "note": note,
                    "size": size, "stage": stage_name,
                    "constraints": sprite_constraints + ["同母版衍生：" + desc],
                    "refs": ["crop:%s（regrow ×%d，再生长 %d 天）" % (cid, c["max_harvests"], c["regrowth_duration"])],
                })

    # —— 共享工具贴片（程序占位，暂不采购）——
    rel_shadow = "assets/farming/crops/_placeholder/shadow_ellipse.png"
    entries.append({
        "path": rel_shadow, "type": "utility", "status": "generated", "note": "接触阴影独立贴片",
        "size": [48, 16],
        "constraints": ["RGBA 二值黑、50% 棋盘抖动", "不烘焙进作物 Sprite（规范 §4.2）"],
        "refs": ["crop_renderer / phase00_check"],
    })
    return {"schema": 1, "generator": "tools/farming/gen_asset_manifest.py",
            "source_of_truth": "content/farming/baked/{terrains,crops}.json",
            "assets": entries}


def print_summary(manifest, only_missing=False):
    entries = manifest["assets"]
    by_status = {}
    for e in entries:
        by_status.setdefault(e["status"], []).append(e)
    print("=" * 64)
    print("灵植模块资产清单（采购单）  共 %d 项" % len(entries))
    print("=" * 64)
    order = [("missing", "缺失"), ("requested", "已发采购"), ("delivered", "已交付"),
             ("placeholder", "占位在库（待正式图替换）"), ("generated", "程序生成")]
    for key, label in order:
        group = by_status.get(key, [])
        if not group:
            continue
        print("\n[%s] %d 项" % (label, len(group)))
        for e in group:
            if only_missing and key != "missing":
                continue
            size = "×".join(str(v) for v in e["size"]) if e.get("size") else "-"
            line = "  %-58s %-12s %s" % (e["path"], e["type"], size)
            print(line)
            if key == "missing" or only_missing:
                print("       需满足：%s" % "；".join(e["constraints"][:4]))
                if e.get("refs"):
                    print("       用途：%s" % "；".join(e["refs"]))
    need = sum(len(by_status.get(k, [])) for k in ("missing", "placeholder", "requested"))
    delivered_n = len(by_status.get("delivered", []))
    print("\n汇总：AI 采购口径（作物 Sprite + 地面纹理）未交付 %d 项（已交付 %d）；程序生成项 %d 项。" % (
        need, delivered_n, len(by_status.get("generated", []))))
    return len(by_status.get("missing", []))


def main():
    only_missing = "--missing" in sys.argv
    manifest = build_manifest()
    out = os.path.join(BAKED, "asset_manifest.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("[manifest] %s" % _rel(out))
    missing = print_summary(manifest, only_missing)
    if "--missing" in sys.argv and missing > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
