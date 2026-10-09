# 批量出图操作说明

当前完成第一阶段工具建设。正式图由另一台 ComfyUI 生成，本机不部署 ComfyUI。
工作目录 `.art-work/` 已忽略；原图、候选、报告、移交包不混入正式资产。

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
部分回传用只包含该批资产的 manifest，或补齐全部候选后再运行。

```powershell
python tools/farming/postprocess_assets.py --manifest .art-work/handoff/ground/manifest.json --input .art-work/raw/candidate_a --output .art-work/processed/run_a
```

源图须为 64 整倍数方图（本轮 128）；工具不做任意比例缩放。作物优先透明底，
纯色底用 `--background '#ff00ff'` 指定准确色键，仅移除完全匹配的颜色，复杂脏边退回重出。
默认 alpha 阈值 128，8 连通去孤岛，只保留最大主体；报告与原图均保留，需核对是否误删叶片。
超过 60px 安全区的主体报错，不静默裁掉主体、不二次缩小。

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
作物全部替换后必须 `qc_assets.py --target all` 全过，回归 `play.bat farm0 --farmtest`
和 `play.bat --selftest`，截图人工审核通过，再将该批 art_status 登记 delivered、重建 manifest、提交。
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

2026-10-09 占位基线：21 项检查中，凝露草 stage_3 存在分离簇（正式 QC 拒绝）；
成熟占比和底部锚点存在告警。第一阶段不修饰占位图来冒充正式图；新正式资产必须遵守完整契约。
原有 farmtest 40 项、phase00 14 项、demo selftest 通过。
