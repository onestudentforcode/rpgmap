# 批量出图操作说明

当前完成第一阶段工具建设。**2026-10-09 起本机直连 ComfyUI 出图**（Qwen-Image 2.1
int8 栈；出图脚本 `gen_ground_batch/gen_crop_masters/gen_crop_stages`），跨机器移交
模式保留为备选。工作目录 `.art-work/` 已忽略；原图、候选、报告、移交包不混入正式资产。

## 1. 构建移交包

项目根目录运行，输出目录必须为空（避免新旧文件混批）：

```powershell
python tools/farming/build_art_handoff.py --batch ground --output .art-work/handoff/ground
Compress-Archive -LiteralPath .art-work/handoff/ground -DestinationPath .art-work/handoff/ground-comfyui.zip
```

包中包含 4 项 manifest、独立色板、风格表、逐图 prompts、同名占位参考、回传说明与 SHA256。
提示词中的色值直接从 palette.json 读取，不手工维护副本。移交工具不自动改变状态。
先草地/泥土各 2 候选，审核后再石板/耕地各 2 候选。

后续批次用 `--batch crop_masters`（2 项）、`dew_grass`（3 项衍生）、`scarlet_berry`（5 项衍生）。
成熟母版单独审核入库后，才能执行对应衍生批次；将审核母版放在包中 prompts.json 的
`reference_required` 路径，并随包交付。占位参考不替代审核母版。
出图机附 workflow JSON、模型版本、seed、采样参数和参考图；本机不假设出图机模型环境。

## 2. 原图后处理

每个候选集合单独放 `.art-work/raw/candidate_a/assets/farming/...`，保持 manifest 原路径。
**地面纹理在 postprocess 前先过 `quantize_ground.py`**（亮度分位拉伸→中值→锚点
吸附；离散色阶不可依赖提示词，参数逐地物固化在工具 DEFAULTS，可 `--params` 覆盖）——
2026-10-09 实测：无此步的地面成品为纯色块（σ≈1~2、四阶割 90%+ 同阶）。
部分回传用只包含该批资产的 manifest，或补齐全部候选后再运行。

```powershell
python tools/farming/postprocess_assets.py --manifest .art-work/handoff/ground/manifest.json --input .art-work/raw/candidate_a --output .art-work/processed/run_a
```

地面和现有作物源图须为 64 整倍数方图（本轮 128）；Phase 4 大画布作物按
manifest 的 sprite_size 使用等比例整倍数矩形源图，例如 256×384 → 128×192，
具体契约见 [phase-04](phase-04-四类作物扩展.md)。工具不做任意比例缩放。作物优先透明底，
纯色底用 `--background '#ff00ff'` 指定准确色键，仅移除完全匹配的颜色，复杂脏边退回重出。
默认 alpha 阈值 128，8 连通去孤岛，只保留最大主体；报告与原图均保留，需核对是否误删叶片。
超过目标画布四边各 2px 安全区的主体报错（64px画布可用60px），不静默裁掉主体、不二次缩小。

地面 NEAREST 缩至 64 后执行 4px 对称边缘混合，产出 3×3 平铺预览。
无缝统计通过不能保证重复纹理观感；镜像/混合可能产生结构变化，必须目检。
处理输出不可与原图互相嵌套，不可写入正式 assets/，不可重复覆盖已有 run。
`qc_report.json` 记录逐图错误与色板/锚点/成熟占比告警；错误返回非零退出码。

## 3. 入库门

候选机器 QC 通过并完成平铺/母版人工审核后，只复制选中图片到同名正式路径。
地面替换后运行：

```powershell
python tools/farming/gen_farm_terrains.py --transitions-only
python tools/farming/qc_assets.py --target ground
python tools/farming/qc_assets.py --target transitions
play.bat farm --farmtest
play.bat farm --farm-shots=.shots/farm-phase03-ground
```

地面批次先用 ground/transitions QC；作物还在占位阶段时，all 会报告既有占位图差异。
作物全部替换后运行`test.bat`（QC all、资产工具与当前农场流程），截图人工审核通过，
再将该批art_status登记delivered、重建manifest、提交。历史farm0与demo测试不再属于默认入库门，
只有改动它们或共享内核时才通过显式入口单独回归，见[testing.md](testing.md)。
截图和逻辑测试分开运行。出现视觉争议时以截图可信坐标的像素取证裁定。

过渡参数默认来自 palette.json 的 transition；CLI 可覆盖 `--outer-radius`、`--diagonal-radius`、
`--dither-rows`、`--rim-width`、`--rim-dark-factor`、`--rim-deep-factor`。
抖动周期在 palette 配置中，必须整除 64。试调值写回 palette 并记录 P1-C 后才入库。
`--output-root .art-work/trans-preview` 可将 atlas 输出隔离，用于比对与哈希检查。
`--verify` 只检查、不写入。三类占位生成器会拒绝覆盖已登记 delivered 的资产；
正式替换后只使用 `--transitions-only` 重建过渡。

## 4. 工具验证与当前基线

```powershell
python -m unittest discover -s tools/farming -p test_asset_pipeline.py -v
python tools/farming/qc_assets.py --target all --report .art-work/reports/baseline.json
```

统一 QC 严格检查 RGB/RGBA 原始模式、PNG、安全边、8连通主体、阶段缺漏/多余、
蛇形命名、无缝边界≤内部最大梯度×1.3、atlas 二值 alpha/bm255/位序元数据。
成熟占比按包围盒高度/64，锚点按 bbox 底部中心；这两项与色板越界为告警，不替代目检。
阴影贴片为独立程序资产，允许棋盘分离像素，不应用作物孤岛规则。

2026-10-09 正式基线：AI 采购口径 14/14 全部 delivered（地面 4 + 作物 10），
qc all 21 项 0 失败（palette 锚点外色/成熟占比为告警项）；farmtest 40 项、
phase00 14 项、demo selftest 零回归；平铺/排图/场景截图三重目检通过。
历史占位基线（凝露草分离簇等差异）已随正式替换消除；占位图保留仅作回滚用途。
地面管线 = 模板 v2 出图 → quantize_ground → postprocess；作物管线 = 洋红底
出图（近洋红吸附）→ postprocess 精确键；衍生以审核母版参考锚定。

## 用户工作区非整倍白底图接入（2026-10-09）

128或64整倍数透明PNG仍为标准回传规格；兼容已有1254px白底图时，显式选择：

```powershell
python tools/farming/postprocess_assets.py --manifest .art-work/crop-import-20261009/manifest.json --input .art-work/crop-import-20261009/raw --output .art-work/crop-import-20261009/processed --background '#ffffff' --background-tolerance 12 --pad-to-multiple
```

`--pad-to-multiple`只补边，不拉伸主体：1254补到1280再以20倍NEAREST降64。
`--background-tolerance`默认0，色键去除仅遍历边界连通背景，保留主体内部封闭高光。
原图备份、处理报告与来源哈希留在该run目录；凝露草s0..s3另归档source-originals。
此轮阶段排图在`.art-work/review/crops_processed.png`，场景截图在`.shots/farm-crops-20261009/`。
