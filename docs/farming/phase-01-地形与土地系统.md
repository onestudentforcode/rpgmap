# Phase 01 — 地形与土地系统

> **上游：** [master-plan.md](master-plan.md) §四（Phase 1 任务）；基线继承
> [phase-00](phase-00-技术基线与重构准备.md)（tile 64×64、美术规范 §4、自研 bitmask 管线）。
> **状态：** **已完成（2026-10-08 关闭，验收见 §8/§9）**
> **边界：** 本阶段交付「可开垦、可交互、可存档的经营地图」；播种/生长属 Phase 2，
> 本阶段只把 `PLANTED` 作为状态枚举值与占用模型预埋，不做种植行为。
> **出阶段条件：** §8 验收清单全部勾选。✅ 已满足

---

## 1. 任务总览

| # | 任务 | 产出 | 状态 |
|---|------|------|------|
| 1.1 | 地形类型 | `content/farming/terrains.json` 注册表（数据驱动） | **✅ 完成（@6ad8237）** |
| 1.2 | 地形自动拼接 | 分层栈 + `trans_upper_*` atlas（Phase 0 管线泛化） | **✅ 完成（@6ad8237）** |
| 1.3 | 土地状态 | `LandGrid`：静态地形与动态农业状态分离 + 占用模型 | **✅ 完成（@1c8a31b）** |
| 1.4 | 土地交互 | hover 信息、开垦/恢复、不可种植提示、占用防冲突 | **✅ 完成（@1c8a31b）** |
| 1.5 | 存档数据 | 逻辑数据 JSON 存读档（接缝：Phase 5 换主游戏存档） | **✅ 完成（@1c8a31b）** |

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
| P1-C | 过渡边缘观感（1px 抖动边、圆角切角观感、描边对比度）优化 | **挂起**：拼接结构正确（无裂缝/无错位，farmtest 位掩码断言 + Phase 0 同源掩码像素取证）；观感类问题统一在 **AI 素材替换时处理**（届时可直接调 mask 风格/描边参数甚至换算法），不在占位图上打磨（用户决定 2026-10-08） | ⏸ 挂起至 Phase 3 素材替换 |

## 7. 素材清单（占位，待 AI 替换）

| 文件 | 规格 | 状态 |
|---|---|---|
| `assets/farming/ground/ground_grass.png` | 64×64 无缝 RGB | ✅ Phase 0 已有 |
| `assets/farming/ground/ground_dirt.png` | 64×64 无缝 RGB | ✅ Phase 0 已有 |
| `assets/farming/ground/ground_stone.png` | 64×64 无缝 RGB（石板拼缝纹） | ✅ 已产出（@6ad8237） |
| `assets/farming/ground/ground_tilled.png` | 64×64 无缝 RGB（垄沟纹） | ✅ 已产出（@6ad8237） |
| `assets/farming/transitions/trans_upper_{dirt,stone,tilled}.png(+json)` | 1024×1024 RGBA | ✅ 已产出（@6ad8237） |

## 8. 验收清单（对照 master-plan §四验收标准）

> 全部勾选，**Phase 1 于 2026-10-08 关闭**，进入 Phase 2。

- [x] 玩家能够在地图中开垦连续区域（左键交互 + farmtest 迁移断言 + 截图 5×3 耕地）
- [x] 耕地边缘能够正确拼接（动态 bitmask 断言：单格=bm0、邻接=bmE/bmW；结构无裂缝；边缘观感挂起 §6 P1-C）
- [x] 多格占用不发生数据冲突（原子 reserve/release、重叠拒绝、跨地形拒绝、prev 恢复，断言 9–13）
- [x] 土地状态保存和恢复后保持一致（磁盘 roundtrip 断言 16，含占用与 prev）
- [x] 更新一块土地不会错误重建整张地图（cells_changed 信号=自身∪8邻；静态层格数全程不变，断言 4/15）
- [x] 石板地等不可开垦地形有明确提示（reason 映射 HUD 红色提示，断言 7）
- [x] 数据/烘焙纪律落地（bake_farm 校验 + 确定性；改 JSON → bake → 验证流程可用）
- [x] `--farmtest` 全过（19 项，0 脚本错误）；截图留档 5 张并审核（全景通过；特写标记项裁定见 §9）
- [x] demo selftest 与 phase00 farmtest 回归通过
- [x] 执行记录回写（§9）+ 分小阶段提交（@6ad8237 / @1c8a31b / 文档收尾）

## 9. 执行记录（追加式）

### 2026-10-08 展开

- 本文档展开；命名定稿 `trans_upper_<id>`；素材替换契约立规（§2.6）。

### 2026-10-08 实施与关闭

- **P1.a（@6ad8237）**：terrains.json（4 地形分层栈）+ farm_01.json（20×14：
  草基底/泥地块×32/石板路+石院×29）+ `bake_farm.py`（校验/确定性/`--check`）
  + `gen_farm_terrains.py`（石板 32px 拼缝纹、耕地 16px 垄沟、3 套 `trans_upper_*`
  atlas；复用 Phase 0 噪声/掩码函数）。
  - QC 基准升级：无缝检验内部梯度基准从均值 → **最大值**（结构化纹理的石板缝/垄沟
    是合法周期线条，边界缝与内部缝同量级；均值基准误报，已回归验证 grass/dirt 仍过）。
- **P1.b（@1c8a31b）**：`LandGrid`（状态/原子占用/prev/存档纯逻辑数据/增量信号）、
  `FarmData`（烘焙产物唯一入口）、`FarmTerrainRenderer`（四层 TileMap + 增量 set_cell）、
  `FarmCamera`（Phase 0 相机行为组件化）、`farm_main.tscn`（hover 信息/开垦交互/
  F5/F9 存读档/占用红框/HUD）、`play.bat farm`（当前主场景）+ `farm0`（Phase 0 历史回归）
  + 缺烘焙自动补 bake。
- **实施中修复的三处缺陷**（都有通用教训，已固化在代码注释/本记录）：
  1. `class_name` 依赖全局类缓存（`.godot/` 需编辑器/import 重建），headless 直接跑
     解析失败 → 改为消费方显式 `preload`（与 phase00 一致，CLI 免 import）。
  2. GDScript lambda 捕获是**值拷贝**，信号槽里对外部变量赋值无效 → 改用成员方法接收。
  3. 渲染器 `_src_of` 拼出的键名（`_trans`）与构建时存的不一致（`_src_trans`），
     null→0 巧合落到错误 source 仍"能跑" → 改为构建时缓存 `_dynamic_src`。
- **验证**：`--farmtest` 19 项全过（0 脚本错误）；回归 phase00 FARMTEST OK、
  demo SELFTEST OK、`gen_phase00_textures --verify` OK。
- **视觉审核与裁定**：全景图通过（三地形过渡/石板平铺/红框 2×2 对齐）；特写图
  审图标记的「点状抖动边/角部绿色切角」与 Phase 0 同源掩码取证结论一致，属**设计行为**；
  「描边对比度/边缘观感」类问题按 **P1-C 挂起**至 AI 素材替换时统一处理。
  截图脚本取景修正（hover 预设 + 占用框完整入镜）后重拍 5 张；红框像素取证
  364px ≈ 2×2 格期望 358px（含描边），黄框高亮确认可见。
- **Phase 1 关闭**。下一步：展开 `phase-02-核心种植系统.md`（播种/生长/收获最小闭环）。
