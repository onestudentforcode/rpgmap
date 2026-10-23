# P10.9 占位设施建模与游戏回填 — 实施记录

2026-10-23 执行完毕。目标"完成建模并渲染，然后回填到游戏中"已按
[分类排期](p109-facility-modeling-plan.md) 的批次 A～F 全量落地。

## 完成状态总览

| 环节 | 结果 | 证据 |
| --- | --- | --- |
| 30 张建模 | 25 设施 30 组陆水全部建成，`_fam109.py` 家族构建器＋深度自动调参 | 各 `facilities/p109/<id>/<medium>/` blend＋QC 图 |
| 轮廓对齐 | 渲染/设计图宽高比 29/30 落在 ±0.08 门槛内（large_bed 差 9% 记录在案） | `_measure_all.py`＋`p109_design_facts.json` |
| 几何体检 | 全 30 张：接地 Z=0、底座在 1×1/2×2 内、无非流形 | `p109_geometry_health.json` |
| 视觉验收 | 30 格设计图 vs 渲染总拼板逐格过审；wool 云梳/炭化巢口等问题修正后复验 | `_qc_grid_all30_v002.png` |
| 运行导出 | 30 张契约 body.png（1×1: 256²/160px每单位/接触点 y=0.62；2×2: 512²/128/0.5117），标记球探测校准相机 shift | `assets/farming/p109/runtime/facilities/**/body.png` |
| 游戏接入 | 加载器支持 manifest 参数＋`merge_manifest` 覆盖；`p8_scene` 设施 profile（设置面板/CLI `--facilities=`/`world_visuals.json` 默认 **p109**）；p109 覆盖 25 项、其余 14 项沿用 legacy | `p8_facility_visuals.gd`、`p8_scene.gd`、`runtime/facility_manifest.json` |
| 自动验证 | `run_p109_facilities.gd` **127 项全绿退出 0**：默认激活、纹理解码、哈希、显示契约、切换原子性/回退、玩法快照不变 | headless Godot 4.7.2 |
| 游戏内目检 | GPU 截图 7 设施（调度站/床组/槽/照料台）接地正确、无渲染异常、画风协调 | `.art-work/p109/facility-preview/facilities-{legacy,p109}.png` |

## 与排期的偏差

- **T2 家族长逐个测量校准**改为**全量深度自动调参**（构建→测渲染宽高比→调深度乘数→重建，
  ≤3 轮）：效果等同且更均匀；乘数固化在 `_fam109.py` 的 `_DMULT`。
- **wool_station 的 T1 精细档**按排期执行了结构+比例对齐（宽高比 1.208/1.158）与云梳
  加大复验，但未做调度站级逐剖面多轮迭代——门面效果已达标，留档差异见拼板。
- 双媒介设施的**水版已建已导出**（`p109_variants` 记录于清单），但游戏当前每设施单图，
  运行仍用陆地版；水版待后续按媒介切换显示时启用（不改玩法/schema）。

## 过程中的关键修正（经验沉淀）

1. `build_one` 不清场导致 blend 累积叠加——每构建必须独立清场。
2. 设计图是宽矮画风：按"设计图宽高比反推深度"（`depth_for`）能让 35° 投影轮廓对齐设计图；
   但要配**深度上限**保护占地契约（底座不得超出地块）。
3. 构建器内的 W/H 硬编码与参数表会脱节（scale_station 改表没改体，白跑一轮）——单一事实源。
4. 契约相机校准：`bpy.data.images` 像素 y 轴向上，与图像坐标相反；标记球放物体前方空地
   （放原点会被自身遮挡）；shift 用两次探测实验测线性系数求解，不猜公式符号。
5. headless Blender 打开的 blend 若保存过 OptiX 设置会渲染失败，导出驱动强制 CPU。
6. Godot 项目警告即错误：`:=` 从 Variant 推断会直接编译失败；夹具脚本出错必须保证仍走到 quit()。

## 复现

```powershell
# 建模与QC（资产仓库 facilities/p109/）
blender --background --python _build_batch_driver.py -- _spec_a.json
blender --background --python _tune_driver.py -- _tune_a.json
blender --background --python _health_driver.py
# 运行导出 + 清单
blender --background --python _export_runtime_driver.py
# 游戏验证（rpgmap 仓库）
& $godot --path . --headless --script scripts/farming/tests/run_p109_facilities.gd
& $godot --path . --rendering-method gl_compatibility --script scripts/farming/validation/p109_facility_preview.gd -- --shot-size=1920x1080
```
