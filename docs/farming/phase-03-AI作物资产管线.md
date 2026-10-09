# Phase 03 — AI 作物资产管线

> **上游：** [master-plan.md](master-plan.md) §六（任务 3.1–3.5）+ §2.4（美术生产方式）；
> 基线继承 [phase-00 §4 美术规范](phase-00-技术基线与重构准备.md)（已冻结）、
> [phase-01 §2.6 素材替换契约](phase-01-地形与土地系统.md)、
> [phase-02](phase-02-核心种植系统.md)（crops 数据模型与渲染契约）。
> **状态：** 已展开，待执行（2026-10-08）
> **边界：** 建立可重复的 AI 素材生产/验收/替换管线，并用它产出**正式**作物与地形素材，
> 替换全部程序占位图。新作物类别扩展属 Phase 4；蛊虫/市场属 Phase 5。
> **执行前提：** ComfyUI 出图机可用（跨机器协作，继承 demo P5 模式）；本机不出正式图。
> **出阶段条件：** §11 验收清单全部勾选。

---

## 1. 任务总览

| # | 任务 | 产出 | 状态 |
|---|------|------|------|
| 3.1 | 统一作物 Sprite 规范细化 | 本文 §2 资产契约（phase-00 §4 的逐类细化） | ✅ 随本文档 |
| 3.2 | 阶段素材契约 | `stage_<n>` / `stage_harvested` / `stage_exhausted` 齐全性规则 | ✅ 随本文档 |
| 3.3 | AI 生成工作流 | §4 人机协作规程 + `docs/farming/art-style-sheet.md`（一页式风格约束+提示词模板） | 待执行 |
| 3.4 | 资源检查脚本 | `tools/farming/qc_assets.py`（统一 QC，覆盖 master-plan 3.4 七项） | 待执行 |
| 3.5 | 统一渲染验收 | 替换后零代码运行（渲染契约已在 Phase 2 落地，本阶段做替换演练） | 待执行 |
| 3.6 | 采购单（manifest）工具 | `tools/farming/gen_asset_manifest.py` → 资产清单/移交包 | 待执行 |
| 3.7 | 地形资产替换 + P1-C 处理 | AI 无缝地面纹理替换 ground_*；过渡 atlas 重生成；观感参数重调 | 待执行 |

---

## 2. 资产契约（全部 AI 正式图必须满足；QC 机器强制）

phase-00 §4 十项冻结规范的**逐类细化**——这是给 ComfyUI 操作者的验收口径，也是
`qc_assets.py` 的检查清单来源。

### 2.1 通用（所有图）

| 项 | 契约 |
|---|---|
| 格式 | PNG 无损，RGBA；导入 preset `farming_pixel`（Filter=Off、Mipmap=Off、Lossless） |
| alpha | **只允许 0 / 255**（二值）；机械后处理统一执行（§4.4），出图机不必手修 |
| 安全边 | 主体与四边留 ≥2px 全透明（地面图无此要求，见 2.3） |
| 缩放 | 需要非 64 尺寸时**整倍 NEAREST**；禁止双线性二次缩放 |
| 命名 | 全小写蛇形，禁中文/空格；路径与文件名即替换契约（同名覆盖生效） |
| 孤岛 | 单 Sprite 内不允许 disconnected 透明孤岛像素簇（QC 检出即拒） |

### 2.2 作物 Sprite（`assets/farming/crops/<crop_id>/`）

| 项 | 契约 |
|---|---|
| 视角 | 固定斜俯视独立 Sprite（侧后 45° 观感 2.5D，**非等距**），无环境场景/地面 |
| 光照 | 主光左上（10–11 点方向），受光朝左上、阴影向右下；接触阴影**不画入** Sprite |
| 画布 | 单格作物 64×64；**多格作物（Phase 4 树木）另立画布规格时须先扩本契约** |
| 锚点 | 植株触地点 = 画布**底边中心**（左右居中、贴底留 2px 安全边内） |
| 阶段 | `stage_0..N`（N 由 crops.json `growth_stages` 决定，QC 对账）；
  regrow 型必须有 `stage_harvested`（采后形態）与 `stage_exhausted`（枯竭态） |
| 一致性 | 同作物各阶段：同一母版衍生，保留稳定识别特征（叶形/纹路/色相）；高度单调递增 |
| 比例 | 成熟期主体占画布约 55–75%（与既有作物并排协调；新作物参照已入库作物） |

### 2.3 地面纹理（`assets/farming/ground/ground_<terrain_id>.png`）

| 项 | 契约 |
|---|---|
| 规格 | 64×64 RGB（无 alpha），**四向无缝**（QC 统计检验：边界梯度 ≤ 内部最大梯度×1.3） |
| 风格 | 中低频细节（单 tile 2–4 色阶），周期性结构线（石板缝/垄沟）周期必须整除 64 |
| 色板 | 色相族延续 wilds 主题（草=floor_a 族、泥=carpet 族、石板=corr 族、耕地=carpet 暗族）；
  具体色值锁定见 §3 style-sheet，**换色板须走决策点 P3-C** |

### 2.4 过渡 atlas（`assets/farming/transitions/trans_upper_<id>.png`）

- **不出图、不手做**：由 `gen_farm_terrains.py` 以「上层地面纹理 × 程序掩码」重生成
  （基础纹理与边缘 Mask 分开维护——master-plan 任务 1.2 原则）。
- AI 替换 ground 后**必跑** `python tools/farming/gen_farm_terrains.py` 重出全部
  `trans_upper_*`（描边色自动取新纹理色板派生值）。
- 掩码观感参数（抖动/圆角 R/描边宽）在真实纹理上重调 = **P1-C 处理落点**（§7）。

---

## 3. 风格约束与提示词模板（任务 3.3 交付物之一）

`docs/farming/art-style-sheet.md`（一页式，出图机的唯一风格依据）：

1. 风格基调：像素风、低饱和、东方仙侠灵植气质；参照已入库图（占位图仅示意结构）。
2. 固定约束模板（每条 prompt 必须携带）：视角词、光照词（左上）、背景词（纯色便于抠图
   或透明）、画布与主体占比、色板锚点（§2.3 色相族 + style-sheet 具体色值）。
3. 逐资产提示词模板：`<作物母版>`、`<作物阶段衍生（附母版图）>`、`<地面无缝纹理>`。
4. 负面清单：等距投影、环境场景、接触阴影、画面文字、高光泛光、半透明边缘。

## 4. AI 生成工作流（任务 3.3；人机协作规程）

master-plan 3.3 九步流程的工程化落法——**核心纪律：不依赖 AI 一次生成完美 SpriteSheet**。

### 4.1 母版先行

每种作物先只出**成熟期母版**（stage_3）→ 人工审查门：轮廓可读性 / 视角正确 /
光照方向 / 色相在族内 / 细节密度与已入库作物一致。**母版不过审不出其余阶段。**

### 4.2 阶段衍生

以母版为视觉参考（img2img/参考图）生成 `stage_0..N-1`、`stage_harvested`、
`stage_exhausted`；衍生图必须同视角同光照，只缩放形体/去留果实。

### 4.3 地面纹理

出图（≥128px 方图）→ 无缝化后处理（§4.4 工具：wrap 混合/镜像缝合）→ 整倍 NEAREST
降到 64 → QC 无缝统计检验 → 重生成过渡 atlas。

### 4.4 机械后处理（回传后本机统一执行，出图机不做）

`tools/farming/postprocess_assets.py`：alpha 二值化（阈值+去孤岛）、安全边裁切/校验、
整倍 NEAREST 缩放、底部中心锚点对齐（按主体 bbox 底边中点平移）、色板越界告警。

### 4.5 入库门（顺序不可换）

```
qc_assets.py 全过（机器门）
  → play.bat farm --farmtest 全过（逻辑门：替换零代码）
  → play.bat farm --farm-shots=DIR 截图人工核对（视觉门）
  → 争议项像素取证裁定（沿用 P1/P2 纪律：审图坐标需可信，误报以取证为准）
  → git 提交入库
```

## 5. 资源检查脚本（任务 3.4）

`tools/farming/qc_assets.py`（统一入口，逐步吸收 gen_* 的 `--verify`，后者保留为
生成器自检）：

| # | 检查（master-plan 3.4 七项全覆盖） | 对象 |
|---|---|---|
| 1 | PNG 格式/模式 | 全部 |
| 2 | alpha 通道存在且二值 | Sprite/atlas |
| 3 | 非透明区域边界（安全边 2px、孤岛簇） | Sprite |
| 4 | 画布尺寸 == 契约值 | 全部（契约来源：baked/ 注册表对账） |
| 5 | 文件命名合规（蛇形/无中文） | 全部 |
| 6 | 必要阶段无缺失（对 baked/crops.json 对账；regrow 双态） | 作物 |
| 7 | 主体不超画布/不贴边（bbox ≤ 画布-2×安全边） | Sprite |
| + | 无缝统计检验（边界梯度 vs 内部最大梯度） | 地面纹理 |
| + | atlas bm=255 全不透明、位序 JSON 一致 | 过渡 atlas |
| + | 主体占比区间（55–75%）与锚点居中偏差 | 作物成熟图（告警级） |

用法：`python tools/farming/qc_assets.py [--target crops|ground|transitions|all]`。
**自动检查不能代替视觉审核**（§4.5 视觉门照走）。

## 6. 采购单协议与跨机器协作（任务 3.6）

### 6.1 manifest（采购单）

`tools/farming/gen_asset_manifest.py` 读 `content/farming/baked/`（terrains+crops，
**数据驱动：新增作物后重跑即得新清单**）+ 现有资产状态 → 产出：

```
content/farming/baked/asset_manifest.json   # 机读：每资产 {path,type,size,constraints,refs,status}
+ 控制台人读摘要（缺什么/已有什么/规格是什么）
```

status 语义：`placeholder`（当前占位）/ `requested`（已列入采购）/ `delivered`（正式图已入库 QC 过）。

### 6.2 移交包（开发机 → 出图机）

`manifest.json` + `art-style-sheet.md` + 同名占位图目录（结构示意参考）+ 回传说明
（按原名放回 `assets/farming/` 对应路径，附出图参数记录）。

### 6.3 回传与验收

回传覆盖 → §4.4 机械后处理 → §4.5 三道门 → manifest 更新 `delivered` → git 提交。
失败退回时附 QC 输出，占位图仍在 git 中可随时回滚（**占位图目录在替换完成前不删除**，
正式图以同名覆盖方式进入，回滚 = git revert）。

## 7. 地形资产替换与 P1-C 处理（任务 3.7）

1. AI 无缝纹理替换 `ground_grass / ground_dirt / ground_stone / ground_tilled`
   （走 §4.3 全流程）。
2. `gen_farm_terrains.py` 重生成三套 `trans_upper_*`（掩码不变、纹理与描边色换新）。
3. **P1-C 落点**：在真实纹理上重调掩码观感参数（生成器常量：抖动行数/占比、圆角
   R、描边宽与取色）——目标「正常缩放下过渡自然，无裂缝不突兀」；参数变更走生成器
   配置化（提为 `gen_farm_terrains.py` 的 CLI/常量参数，不再散落代码）。
4. 若程序掩码与 AI 纹理风格冲突（如手绘边缘 vs 几何抖动），升级为决策点 P3-A 处理。

## 8. 决策点

| # | 决策 | 草案 | 状态 |
|---|------|------|------|
| P3-A | 过渡掩码风格：程序几何（现行）vs 边缘手绘化（AI 出边缘 Mask 图） | 先调参；真实纹理上架后仍冲突才升级手绘 Mask | 待 §7 执行时定 |
| P3-B | 阶段衍生方式：参考图 img2img vs 纯 prompt 复述 | 参考图优先（一致性硬指标） | ✅ 定 |
| P3-C | 色板锚定：延续 wilds 族 vs 建 farming 独立色板文件 | **建 `tools/farming/palette.json`**（初值取自 wilds，之后独立演进；生成器与 style-sheet 同源读它） | ✅ 定 |
| P3-D | 出图分辨率母版（128 出图降 64 vs 直接 64） | 128 出图 + 整倍 NEAREST 降采样（细节余量） | ✅ 定 |

## 9. 对既有实现的影响面（评估，不改行为）

- `CropRenderer` / `FarmTerrainRenderer`：零改动（契约化加载，缺图回退链已有）。
- `gen_phase00_textures.py`（phase00 历史场景自用）退役条件：phase00 场景下线时一并清理；
  其共享输出 `ground_grass/dirt` 被正式图覆盖后，phase00 场景自动使用新图（共享路径），
  回归仍应通过（其 farmtest 不校验像素内容）。
- `tools/farming/gen_farm_terrains.py` / `gen_farm_crops.py`：保留为占位图生成器与
  atlas 重生成器；占位逻辑在全部资产 `delivered` 后仅作回滚用途。

## 10. 自测断言（farmtest 增量，目标 +6 ≥ 46）

1. manifest 与 baked 对账：每作物阶段文件存在性 == manifest 声明（无缺漏/无多余）
2. qc_assets 全过后：`--farmtest` 原有 40 项不回归（替换零代码的直接证据）
3. 主体占比/锚点检查纳入 qc_assets（farmtest 不重复断言，只跑工具）
4. 占位图回滚演练：`git stash`/回退一张图 → 缺图回退链生效（场景不崩，仅隐藏+告警）
5. trans atlas 重生成确定性：同 ground 输入两次生成 md5 一致
6. P1-C 调参后过渡掩码统计检验仍过（无缝/无裂缝）

## 11. 验收清单（对照 master-plan §六验收标准）

- [ ] 能持续生成符合规范的作物素材（工作流走通 ≥2 种作物：凝露草+赤纹果正式图入库）
- [ ] 同一作物各阶段视觉连续（母版衍生 + 人工审查记录）
- [ ] 多种作物并排比例协调（截图审核，占比契约生效）
- [ ] 透明边缘无白边/脏边（二值 alpha + 安全边 QC + 截图）
- [ ] 资源更换不影响作物逻辑（farmtest 40 项零回归）
- [ ] 形成可批量复用的标准模板（manifest + style-sheet + qc + 后处理工具链）
- [ ] 地形正式纹理替换完成，过渡 atlas 重生成，P1-C 参数调定并记录
- [ ] manifest 状态机可用（placeholder/requested/delivered），新增作物 = 改 JSON →
      bake → manifest 自动出现新采购项（断言）
- [ ] 执行记录回写（§12）+ 分小阶段提交

## 12. 执行记录（追加式）

### 2026-10-08 展开

- 本文档展开；资产契约/采购单协议/QC 清单/工作流规程定稿（§2–§7）；
  决策点 P3-B/C/D 预定，P3-A 留待真实纹理上架。
- 待执行：§1 状态表（工具 3 件 + style-sheet + 正式素材替换 + P1-C）。
