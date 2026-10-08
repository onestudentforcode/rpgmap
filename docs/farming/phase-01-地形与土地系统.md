# Phase 01 — 地形与土地系统

> **上游：** [master-plan.md](master-plan.md) §四（Phase 1 任务）；基线继承
> [phase-00](phase-00-技术基线与重构准备.md)（tile 64×64、美术规范 §4、自研 bitmask 管线）。
> **状态：** 已展开，进行中（2026-10-08）
> **边界：** 本阶段交付「可开垦、可交互、可存档的经营地图」；播种/生长属 Phase 2，
> 本阶段只把 `PLANTED` 作为状态枚举值与占用模型预埋，不做种植行为。
> **出阶段条件：** §8 验收清单全部勾选。

---

## 1. 任务总览

| # | 任务 | 产出 | 状态 |
|---|------|------|------|
| 1.1 | 地形类型 | `content/farming/terrains.json` 注册表（数据驱动） | 待执行 |
| 1.2 | 地形自动拼接 | 分层栈 + `trans_upper_*` atlas（Phase 0 管线泛化） | 待执行 |
| 1.3 | 土地状态 | `LandGrid`：静态地形与动态农业状态分离 + 占用模型 | 待执行 |
| 1.4 | 土地交互 | hover 信息、开垦/恢复、不可种植提示、占用防冲突 | 待执行 |
| 1.5 | 存档数据 | 逻辑数据 JSON 存读档（接缝：Phase 5 换主游戏存档） | 待执行 |

---

## 2. 设计规范

### 2.1 地形分层栈（任务 1.1 / 1.2）

静态地形按**层栈**组织，层号小者在底；每个非底层地形一套「纹理 × 掩码」过渡 atlas：

```
layer 0  grass   草地（基底，满铺，无过渡 atlas）
layer 1  dirt    泥土地（trans_upper_dirt.png）
layer 2  stone   石板地（trans_upper_stone.png）
layer 3  tilled  耕地（动态：开垦产生、恢复消失；trans_upper_tilled.png）
```

- 掩码算法与位序完全复用 Phase 0（8 邻域 bitmask，256 配置，`atlas_of(bm)=(bm&15, bm>>4)`）；
  **掩码与下层是什么地形无关**——上层 tile = 上层纹理 × 掩码，垫在任意下层之上。
- 动态层（tilled）的 bitmask 按当前农业状态实时计算；某格状态变化时，
  只重算该格与 8 邻格的 tile（增量 `set_cell`，禁止整图重建）。
- 已知简化（继承 Phase 0 D2 结论）：无内角 overlap，内角呈直角；Phase 4 前统一评估。
- 新增地形 = terrains.json 加一行 + 生成器产出两张图（纹理 + 过渡 atlas）+ 层号，
  **不改核心代码**（master-plan 分类扩展约束的地形版）。

### 2.2 数据源与烘焙（沿用 demo R1/R2 纪律）

```
content/farming/terrains.json        地形注册表（唯一事实源）
content/farming/maps/farm_01.json    农场地图文（ASCII 布局 + 图例）
        │  python tools/farming/bake_farm.py（校验 + 规范化）
        ▼
content/farming/baked/               烘焙产物（进 git，运行时唯一读取物）
```

- bake 校验：图例覆盖所有字符、行宽一致、地形 id 存在于注册表、层号唯一递增、
  纹理文件存在；两次烘焙产物逐字节一致（确定性）。
- 纪律照搬 demo：**改源 JSON 后必须重 bake**；运行时禁止读源文件；禁止手改 baked/。

### 2.3 土地状态模型（任务 1.3）

静态地形（`terrain_id`，来自地图数据，存档不重复保存）与动态农业状态（`state`）分离：

```
UNAVAILABLE  不可种植（石板地等 tillable=false 地形的固有状态）
WILD         未开垦（可开垦地形的默认状态）
TILLED       已开垦
PLANTED      已播种（Phase 2 启用；本阶段仅枚举预埋）
OCCUPIED     已被设施/障碍占用（记录 prev_state，释放后恢复）
```

- 状态迁移（本阶段实现）：`WILD → TILLED`（开垦）、`TILLED → WILD`（恢复）、
  `任意可开垦状态 → OCCUPIED`（占用，原子多格）、`OCCUPIED → prev_state`（释放）。
- 占用模型：`reserve(origin, footprint, holder) → bool`——脚印内全部格子合法且
  非 OCCUPIED 才整体生效（原子性：任一格失败则全部不变）；`release(holder)`。
  多格脚印是 Phase 4 树木的地基，本阶段以 API + 自测覆盖。
- 变更通知：`cells_changed(cells: Array[Vector2i])` 信号，携带受影响格集合
  （变更格 ∪ 其 8 邻），渲染层据此增量更新。

### 2.4 交互（任务 1.4）

- hover：高亮框 + HUD 显示（地形名 / 状态 / 可否开垦及原因）。
- 左键：开垦（WILD→TILLED）；已开垦格左键=恢复（TILLED→WILD，测试用）。
  不可开垦（石板/占用/越界）→ HUD 红色提示文案，**不弹窗不打断**。
- 占用可视化：OCCUPIED 格画半透明红色覆盖框（Overlay 层 UI 绘制，非资产）。
- 键位：WASD/方向键平移、滚轮缩放（继承 Phase 0 相机规范 0.5–2.0）。

### 2.5 存档（任务 1.5）

- 存档 = **逻辑数据 only**：地图 id、每格 `{state}`（含占用的 holder/prev）、版本号；
  **不含**任何贴图/atlas/节点引用——显示由加载后按数据重建。
- 路径 `user://farm_phase01_save.json`；接缝注释：Phase 5 替换为主游戏存档适配层。
- `load()` 文件不存在 → 全图按地图默认初始化（首次进入即开垦前状态）。
- 更新一格不触发整图重建（渲染层只消费 cells_changed 增量）。

### 2.6 素材替换契约（占位 → AI 正式图）⚠️ 本阶段立规

> 现有全部贴图为程序占位图，**之后会被 AI 正式素材替换**。为保证替换零成本：

1. **逻辑零像素依赖**：代码只引用 `terrain_id` 与资产契约（文件名、尺寸 64、
   alpha 二值、锚点），绝不引用具体颜色/像素内容。
2. **同名同规格替换**：正式图按相同文件名覆盖 `assets/farming/` 即生效，
   不改代码、不重烘焙（baked 只含路径引用，纹理运行时直读）。
3. **替换后必跑**：生成器 `--verify`（或后续 QC 工具）→ `--farmtest` → 截图人工核对。
4. **命名定稿**（Phase 0 §4.9 的 `trans_<lower>_<upper>` 修订为分层栈语义）：
   - 地面：`ground_<terrain_id>.png`
   - 过渡：`trans_upper_<terrain_id>.png`（+ 同名 `.json` 位序说明）
   - 作物：`crops/<crop_id>/stage_<n>.png`（Phase 2 起）
   - Phase 0 的 `trans_grass_dirt.png` 为历史遗留名，仅 phase00 验证场景引用；
   正式管线以 `trans_upper_dirt.png` 为准，phase00 场景退役时一并清理。

---

## 3. 实现落位

| 模块 | 文件 | 职责 |
|---|---|---|
| 数据 | `content/farming/terrains.json` / `maps/farm_01.json` → `baked/` | 注册表 + 地图（见 §2.2） |
| 烘焙 | `tools/farming/bake_farm.py` | 校验 + 规范化 + 确定性 |
| 美术 | `tools/farming/gen_farm_terrains.py` | 石板/耕地占位纹理 + 3 套 `trans_upper_*` atlas + QC（复用 Phase 0 噪声/掩码函数） |
| 核心 | `scripts/farming/core/grid/land_grid.gd` | 状态/占用模型 + 信号（纯逻辑，可 headless 自测） |
| 核心 | `scripts/farming/core/farm_data.gd` | 烘焙产物加载（运行时唯一数据入口） |
| 渲染 | `scripts/farming/rendering/terrain_renderer.gd` | 四层 TileMap 构建 + 增量更新 |
| 渲染 | `scripts/farming/rendering/farm_camera.gd` | 相机平移/缩放/钳制（Phase 0 行为组件化） |
| 场景 | `scenes/farming/farm_main.tscn` + `scripts/farming/rendering/farm_main.gd` | 当前主农场场景（交互/HUD/存档/自测） |
| 入口 | `play.bat farm` → farm_main；`play.bat farm0` → phase00_check（历史回归） | — |

---

## 4. 农场地图（farm_01，20×14）

```
gggggggggggggggggggggg   g 草地（可开垦）
gggggddddddgggggggggggg   d 泥土地（可开垦，视觉区隔）
ggggddddddddggggggddggg
ggggddddddddggggggddggg
gggggddddddgggggggggggg
ggggggggggggggggggggggg
sssssssssssssssssssssss   s 石板路横穿（UNAVAILABLE，练提示与分层）
ggggggggggggggggggggggg
ggggggggggggggsssgggggg   右下石板小院（不可开垦区）
gggggggggggggggsssgggggg
gggggggggggggggsssgggggg
gggggggggggggggggggggggg
gggggggggggggggggggggggg
gggggggggggggggggggggggg
```

覆盖验收形态：连续开垦区（草地/泥地）、石板整行 + 石板小院（不可开垦）、
多地形交界（草↔泥↔石三邻接）、动态耕地嵌在静态地形内。

## 5. 自测断言（--farmtest，目标 ≥ 16 项）

1. 烘焙数据加载：尺寸/图例/地形注册一致
2. 层号唯一递增；grass=layer0；tillable 标志正确（grass/dirt=true, stone=false）
3. 开垦迁移：WILD→TILLED、重复开垦拒绝、恢复 TILLED→WILD
4. 石板开垦拒绝（UNAVAILABLE 提示路径）
5. 占用：2×2 原子 reserve 成功 → 4 格 OCCUPIED；重叠 reserve 拒绝且无部分占用
6. 占用释放 → 恢复 prev_state（TILLED 上占用再释放回 TILLED）
7. 占用格开垦拒绝
8. 跨地形脚印（2×2 含石板格）reserve 拒绝
9. 动态过渡增量：开垦 (x,y) 后信号 cells = {该格∪8邻}；该格与相邻已开垦格的
   atlas 坐标变化且等于按位掩码计算的期望值
10. 增量更新不重建：开垦后 ground/静态层 used_cells 数不变
11. 存档 roundtrip：开垦+占用 → save → 清空变更 → load → 状态逐一一致
12. 存档内容纯逻辑：JSON 键内无贴图/atlas/路径字段
13. load 不存在文件 → 全 WILD 默认
14. 渲染层格数：stone 层格数 == 地图 s 数；tilled 层初始为 0
15. tile 64 基线 + 相机规范（复用 Phase 0 断言）

## 6. 决策点

| # | 决策 | 结论 | 状态 |
|---|------|------|------|
| P1-A | tilled 属动态层(栈顶) 还是替换地形纹理 | **动态层**：开垦/恢复不改静态地形数据，渲染与存档都更简单 | ✅ 本阶段定 |
| P1-B | 耕地湿润/干燥变体（Phase 0 旧地基做过 dry/wet） | 本阶段只做 dry 一版；浇水属 Phase 2 生长机制，届时加 `tilled_wet` 变体（同契约新增） | ✅ 本阶段定 |

## 7. 素材清单（占位，待 AI 替换）

| 文件 | 规格 | 状态 |
|---|---|---|
| `assets/farming/ground/ground_grass.png` | 64×64 无缝 RGB | ✅ Phase 0 已有 |
| `assets/farming/ground/ground_dirt.png` | 64×64 无缝 RGB | ✅ Phase 0 已有 |
| `assets/farming/ground/ground_stone.png` | 64×64 无缝 RGB（石板拼缝纹） | 本阶段新增 |
| `assets/farming/ground/ground_tilled.png` | 64×64 无缝 RGB（垄沟纹） | 本阶段新增 |
| `assets/farming/transitions/trans_upper_{dirt,stone,tilled}.png(+json)` | 1024×1024 RGBA | 本阶段新增 |

## 8. 验收清单（对照 master-plan §四验收标准）

- [ ] 玩家能够在地图中开垦连续区域（草地/泥地，交互可用）
- [ ] 耕地边缘能够正确拼接（动态 bitmask + 视觉核对）
- [ ] 多格占用不发生数据冲突（原子 reserve/release 自测覆盖）
- [ ] 土地状态保存和恢复后保持一致（roundtrip 自测）
- [ ] 更新一块土地不会错误重建整张地图（增量信号断言）
- [ ] 石板地等不可开垦地形有明确提示，不误导操作
- [ ] 数据/烘焙纪律落地：改 JSON → bake → 验证（确定性成立）
- [ ] `--farmtest` 全过；截图留档并视觉审核通过
- [ ] demo selftest 与 phase00 farmtest 回归通过
- [ ] 执行记录回写（§9）+ 分小阶段提交

## 9. 执行记录（追加式）

### 2026-10-08 展开

- 本文档展开；命名定稿 `trans_upper_<id>`；素材替换契约立规（§2.6）。
- 待执行：数据层/美术层/逻辑层/场景层，见 §1 状态表。
