# Phase 00 — 技术基线与重构准备

> **上游：** [master-plan.md](master-plan.md) §三（Phase 0 任务）、§十四（当前执行任务）、§十五（执行纪律）、附录 A（仓库适配）
> **状态：** **已完成（2026-10-08 关闭，验收见 §7/§8）**
> **纪律：** 本阶段只做规范冻结与最小验证，**不开发任何种植玩法逻辑**；
> 美术标准与坐标规范必须在本阶段定死（执行纪律 1）。
> **出阶段条件：** §7 验收清单全部勾选。✅ 已满足

---

## 1. 任务总览

| # | 任务 | 产出 | 状态 |
|---|------|------|------|
| 0.1 | 旧方案隔离 | `archive/old-farming/` 归档 + 无引用复核 + 基线自测 | **✅ 完成（@58aa96d）** |
| 0.2 | 目录落位 | `scripts/farming/`、`scenes/farming/`、`tools/farming/`、`assets/farming/` 随文件落地 | **✅ 完成（@60948cf/61dbfcb）** |
| 0.3 | 美术规范冻结 | 本文 §4（**已冻结 2026-10-08**） | **✅ 完成** |
| 0.4 | 最小拼接验证 | `scenes/farming/phase00_check.tscn` + 生成器 + farmtest（14 项全过） | **✅ 完成（@60948cf/61dbfcb）** |
| — | 决策冻结 | D1=64×64 已冻结；D2 采用自研 bitmask 管线；D3 保持草案 | **✅ 完成（§6）** |

---

## 2. 任务 0.1：旧方案隔离（已完成）

处置对象 = master-plan 附录 A.3 清单（此前经营地基：Blender 建模→渲染精灵路线）。

执行方式：**归档而非删除**（保留参考价值；git 历史完整，立项阶段如需彻底删除随时可 `git rm`）。

```
archive/old-farming/
├── README.md                     ← 处置说明（为什么归档、归属哪个决策）
├── lotus_flower.py               ←（原仓库根目录）
├── tools/
│   ├── apple_tree.py             ← Blender 程序化建模脚本
│   ├── glaze_lily.py
│   ├── gen_farmland_sprite.py    ← 旧美术管线（白模渲染底图 → 像素精灵）
│   └── farmland_palette.json
└── assets/
    ├── models/                   ← Blender 白模（.blend/.blend1）与渲染产物 renders/
    └── sprites/farmland/         ← 旧耕地占位图（dry/wet/preview）
```

复核要求（已执行，记录见 §8）：

1. 游戏侧代码（`scripts/`、`scenes/`、`content/`、`project.godot`、`play.bat`、
   demo 工具 `tools/bake_maps.py` / `gen_placeholder_assets.py`）对上述文件**零引用**。
2. 归档后 `play.bat --selftest` 仍全过（demo 基线不受影响）。
3. 本地 `__pycache__/` 一并清理（gitignore 已覆盖，不入库）。

**约束：** `archive/` 下的任何实现不再作为新模块依赖或规范来源；
新模块需要类似能力时按 master-plan §2.4 重新选型（Blender 仅在复杂建筑时作可选结构辅助）。

---

## 3. 任务 0.2：目录落位

按 master-plan 附录 A.2 的映射，目录**随首个文件落地时创建**（git 不追踪空目录，
不预建空壳 + `.gitkeep`）。Phase 0 期间预期落地的最小集合：

```
scenes/farming/phase00_check.tscn        ← 0.4 验证场景
scripts/farming/rendering/…              ← 场景构建/相机/点击拾取脚本
tools/farming/gen_phase00_textures.py    ← 占位无缝纹理生成
assets/farming/ground/                   ← grass / dirt 占位纹理
assets/farming/crops/_placeholder/       ← 占位作物 Sprite
docs/farming/                            ← 本文档与 master-plan
```

启动入口：`play.bat farm`（脚本加一个分支，直接以 `scenes/farming/phase00_check.tscn`
启动，不经过 demo 的 main.tscn 状态机）。

---

## 4. 任务 0.3：美术规范（**已冻结 @2026-10-08**，依据：0.4 验证通过）

> 冻结后所有素材（含占位）必须遵守，违反即 QC 拒收；变更须走决策记录（§6）。
> 生效实现参照：`tools/farming/gen_phase00_textures.py`（QC 即本表的执行体）。

| # | 项 | 规范（草案） |
|---|---|------|
| 1 | 观察视角 | 地面纹理：正交俯视。植物/建筑/设施：固定斜俯视独立 Sprite（侧后 45° 观感的 2.5D 绘制，**非等距投影**） |
| 2 | 光源方向 | 主光来自画面**左上**（约 10~11 点方向）；受光面朝左上，阴影统一向**右下**投影；地面接触阴影为独立阴影贴片，**不烘焙进 Sprite** |
| 3 | 色彩范围 | 种植场景主色域延续 wilds 主题的草绿/暖棕族；统一色板文件 Phase 3 建立（`tools/farming/palette.json`），AI 生成必须挂同一风格约束模板 |
| 4 | 细节密度 | 地面纹理以中低频噪声为主（单 tile 内 2~4 个色阶层次），避免高频噪点导致平铺显脏；作物 Sprite 细节密度以 64×64 画布内可辨认为上限 |
| 5 | 网格尺寸 | **决策点 D1**（§6）：草案 64×64 像素/格，逻辑网格单位与素材画布分离 |
| 6 | Sprite 锚点 | 底部中心。Godot 实现：Sprite2D 纹理底边中点对齐**格子底边中点**；多格作物锚定于占地区域**底边总宽的中心**（如 2×2 作物锚在 2 格宽底边中点）；跨格显示允许超出占地，逻辑占用不变 |
| 7 | 透明区域 | PNG RGBA；**alpha 只允许 0 或 255**（二值，防半透明糊边）；主体与画布四边留 ≥2px 全透明安全边（防裁切/渗色）；同一 Sprite 内不允许出现 disconnected 孤岛像素簇（QC 检查） |
| 8 | 输出格式 | PNG 无损。Godot 导入统一 preset（`farming_pixel`）：Filter=Off（NEAREST）、Mipmap=Off、Compress=Lossless |
| 9 | 命名规范 | 地面：`ground_<type>.png`（grass/dirt/stone/…）；过渡 mask：`trans_<lower>_<upper>_bm<idx>.png`（Phase 1 定稿）；作物：`assets/farming/crops/<crop_id>/stage_<n>.png`（可重复结果作物加 `stage_harvested.png`）；建筑/装饰：`<id>_<variant>.png`。全小写蛇形命名，禁中文与空格 |
| 10 | 缩放与过滤 | 素材按 1:1 设计分辨率导入，**运行时相机缩放不得重采样素材**（NEAREST 像素风）；禁止 AI 出图后双线性二次缩放——需要不同尺寸时重新生成或整倍 NEAREST |

沿用既有 QC 铁律（handoff §8）：alpha 二值、NEAREST、逐行不透明度防空帧——
0.4 的占位纹理生成器即按此强度内建 QC，Phase 3 任务 3.4 检查脚本在其上扩展。

---

## 5. 任务 0.4：最小拼接验证（技术方案）

### 5.1 场景

`scenes/farming/phase00_check.tscn`，10×10 逻辑网格，内容：

- 草地满铺 + 中心 4×4 泥土区（直边过渡）+ 一个**不规则泥土边界区**（验证内角/外角）。
- 六层结构落 Godot（master-plan §2.2 的映射）：
  `TileMapLayer`（Ground）→ `TileMapLayer`（TerrainTransition）→ `TileMapLayer`（Farmland，预留空层）
  → `Node2D{y_sort_enabled}`（Crop/Object 合并排序层）→ `CanvasLayer`（Overlay：高亮框/提示）。
- 占位作物 Sprite ×1（64×64 幼苗形）+ 占位高物体 ×1（64×128），同列摆放验证遮挡。

### 5.2 占位纹理生成

`tools/farming/gen_phase00_textures.py`（PIL，程序化占位，AI 纹理由 Phase 3 管线替换）：

- wrap 对称噪声生成 `ground_grass.png` / `ground_dirt.png`（无缝：四向平铺接缝像素差为 0）。
- 内建 QC：尺寸、alpha 二值（地面图无透明）、四边 wrap 校验、平铺渲染自检。
- 过渡：8 邻域 bitmask 程序生成草→泥边缘 mask 集（允许等效实现，如 Godot TileSet
  terrain peering bits；**验收只看结果**：直边/内角/外角/不规则边无透明裂缝、无错误边缘）。

### 5.3 相机与交互

- `Camera2D`：WASD/方向键平移，滚轮缩放 0.5×–2.0×，限制在地图边界内。
- 点击拾取：mouse → world → `floor(world / tile_size)` 得格子坐标；
  **自测断言必须覆盖相机平移 + 非整数缩放状态下的换算正确性**（这是验收项，
  不是可选项）。
- Overlay 高亮框：跟随鼠标格；点击后在格子底边中点实例化/移除占位作物（验证锚点）。

### 5.4 验证方式

- `play.bat farm` 人工走查（平移/缩放/点击/遮挡）。
- `play.bat --farmtest`（headless 逻辑断言：无缝校验、bitmask→tile 映射、点击换算、
  锚点对齐；沿用 demo selftest 模式，随模块演进）。
- 截图留档 `.shots/farm-phase00/`。

---

## 6. 决策点

| # | 决策 | 结论与理由 | 状态 |
|---|------|-----------|------|
| D1 | tile 尺寸：64×64 还是沿用 demo 内核的 32×32 | **冻结 64×64**：拼接验证通过（视口 640×360 下 zoom 1–2 观察范围与细节合格）；demo 内核是「游戏侧」对接面不强制同尺寸；Phase 5 联动需同图时再议适配 | **✅ 已冻结** |
| D2 | 过渡实现：自研 bitmask mask 管线 vs Godot TileSet terrain peering | **采用自研管线**（生成器产出 256 配置 mask atlas + JSON 位序映射，运行时按 8 邻域位掩码选 tile）：与「基础纹理与边缘 Mask 分开维护」天然一致、可程序生成、已验证无裂缝。已知简化：无内角 overlap（内角呈直角）——**Phase 1 定稿时评估是否补 overlap 变体** | ✅ 已定（Phase 1 复核 overlap） |
| D3 | farming 场景与 demo 内核（map_host/main.gd）关系 | **草案维持：完全独立场景**（phase00 已按此实现，`play.bat farm` 独立启动）；两世界通过 `scripts/farming/integration/` 信号/适配层对接 | Phase 5 联动设计时复核 |

---

## 7. 验收清单

> 全部勾选，**Phase 0 于 2026-10-08 关闭**，进入 Phase 1（master-plan §十四）。

- [x] 旧地基已隔离：归档目录就位、游戏侧零引用、demo selftest 基线仍过（§8 记录）
- [x] 新模块与旧地基解耦确认：`scripts/farming` / `scenes/farming` / `tools/farming` 对 `archive/` 零引用（grep 复核）
- [x] D1 冻结：tile = **64×64**（§6）
- [x] 美术规范冻结（§4，2026-10-08）
- [x] grass/dirt 无缝纹理：生成器统计检验（边界梯度 ≤ 内部均值×1.6）+ z0.5/z1.0 截图目检无接缝
- [x] 地形过渡：直边/内角/外角/阶梯边/孤立泥岛无透明裂缝、无错误边缘（farmtest atlas 覆盖断言 + z2.0 像素取证：绿像素仅存在于抖动边 0–1 行、外角切角区与幼苗本体）
- [x] 网格坐标与显示一致；点击定位准确（farmtest 断言：格边界 ±1px 换算、zoom 0.75 屏幕中心↔世界、canvas 变换往返、相机边界钳制）
- [x] 占位作物 Sprite：底部中心锚点对齐、YSort 遮挡基准成立（farmtest + objects 截图目检）
- [x] `--farmtest` 自测全过（14 项）+ 截图留档 `.shots/farm-phase00/`（4 张，视觉审核通过）
- [x] 执行记录回写（§8）+ git 提交（@60948cf / @61dbfcb / 文档收尾提交）

---

## 8. 执行记录（追加式）

### 2026-10-08 文档展开与任务 0.1 执行

- 展开 `phase-00-技术基线与重构准备.md`（本文档）；命名规范
  `phase-<两位阶段号>-<阶段名>.md` 写入 master-plan 附录 A.5 与 handoff。
- **任务 0.1 完成**：A.3 清单全部 `git mv` 至 `archive/old-farming/`（保留原相对路径，
  git 历史完整），附 README 说明处置原因与使用边界；引用复核通过——游戏侧代码
  （scripts/scenes/content/project.godot/play.bat/demo 工具）对旧地基文件零引用
  （旧文件之间互引一并归档，不构成运行依赖）；根目录 `__pycache__/` 清理。
- **基线复核**：归档后 `play.bat --selftest` 全过（SELFTEST OK，35 项），demo 基线无损。

### 2026-10-08 任务 0.2–0.4 执行与 Phase 0 关闭

- **0.4a（@60948cf）**：`tools/farming/gen_phase00_textures.py`——wrap 值噪声无缝
  grass/dirt（色板读 wilds 主题）、256 配置 bitmask mask 过渡 atlas（外角 R13 圆角 /
  缠绕角 R6 倒角 / 1px 50%+25% 棋盘抖动 / 朝草边 2px 深色描边）、占位幼苗 64×64 /
  立石 64×128 / 接触阴影贴片 48×16；QC：无缝统计检验、alpha 二值、2px 安全边、
  尺寸、位序一致性、确定性（重跑 md5 一致）；`--verify` 独立校验模式。离屏合成
  预览视觉审核通过。
- **0.4b/c（@61dbfcb）**：`farm_phase00_map.gd`（10×10 地图 + 六层结构落位 + 位掩码
  计算）+ `phase00_check.gd`（相机平移/缩放钳制、网格点击、高亮框、底部中心锚点、
  独立接触阴影、farmtest/shots 模式）+ `scenes/farming/phase00_check.tscn` +
  `play.bat farm [—-farmtest|--farm-shots=DIR]` 入口（缺纹理自动跑生成器）。
- **验证**：`--farmtest` 14 项全过（FARMTEST OK）；4 张截图留档
  `.shots/farm-phase00/`，视觉审核通过；对 2× 特写中 AI 审图提出的「泥土内绿块」
  做像素取证——绿像素仅存在于抖动边（深度 0/1 行）、外角切角区（深度 4–12，
  深度 3 为 0）与初始占位幼苗本体，**掩码无缺陷**（审图坐标本身有误，超出画面范围）；
  `--verify` 通过；demo selftest 回归 SELFTEST OK；新代码对 `archive/` 零引用。
- **冻结**：D1 = 64×64；美术规范 §4 生效；D2 采用自研 bitmask 管线（内角 overlap
  留 Phase 1 评估）。**Phase 0 关闭**，下一步展开 `phase-01-地形与土地系统.md`。

#### 已知坑（后续阶段别再踩）

- `play.bat` 注释行（rem）**不得以全角字符结尾**：cmd + chcp 65001 下会误读下一行
  （已修：注释行尾改 ASCII 括号）。
- GUI 版 Godot 的 stdout 会被管道挂住：**自动化/看输出一律用 console 版**
  （`--farmtest` 已自动切换；手动跑 `--farm-shots` 建议直接用 GODOT_CONSOLE）。
- 截图实际分辨率 1280×720（窗口 override 2× + stretch canvas_items）：
  截图像素 = 世界像素 × 2×zoom，做像素取证时换算系数是 4（zoom 2 时）。
- `--farmtest` 与 `--farm-shots` 同时传会竞态退出，分开跑。
