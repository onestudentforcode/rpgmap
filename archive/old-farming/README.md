# archive/old-farming — 旧经营模块地基（已归档，仅作参考）

> 归档日期：2026-10-08　·　处置依据：[docs/farming/master-plan.md](../../docs/farming/master-plan.md)
> 任务 0.1「旧方案隔离」+ 附录 A.3 清单
> （执行记录：[docs/farming/phase-00-技术基线与重构准备.md](../../docs/farming/phase-00-技术基线与重构准备.md) §8）

## 这是什么

灵植经营模块立项（2026-10-08）之前的经营地基实验：**Blender 程序化建模 → 白模多视角渲染
→ 像素化后处理 → 精灵** 的美术管线尝试。总规划采用方案 A（AI 无缝纹理 + 程序化
Autotile + AI 独立 Sprite），此路线整体放弃；文件按原相对路径归档于此，保留参考价值。

## 内容清单

- `lotus_flower.py`：Blender 荷花建模脚本（方法论源头）
- `tools/apple_tree.py` / `tools/glaze_lily.py`：Blender 程序化建模（苹果树/琉璃百合）
- `tools/gen_farmland_sprite.py` + `tools/farmland_palette.json`：白模渲染底图 → 耕地精灵
- `assets/models/`：Blender 白模（`.blend`/`.blend1`）与多视角渲染产物（`renders/`）
- `assets/sprites/farmland/`：旧耕地占位图（dry / wet / preview）

## 使用边界（重要）

1. **禁止作为新模块的运行依赖、导入目标或规范来源**——新模块素材规范见
   master-plan §2.4 与 phase-00 §4（美术规范）。
2. Blender 在新规划中仅作为**复杂建筑的可选结构辅助**，不承担完整建模生产任务。
3. 本目录内容不删除（git 历史完整）；立项阶段若确认彻底废弃，可直接 `git rm`。
