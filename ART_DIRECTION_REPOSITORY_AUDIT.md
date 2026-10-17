# ART_DIRECTION_REPOSITORY_AUDIT — 灵田（rpgmap）美术风格重构前期仓库审计

> 生成日期：2026-10-13。调查对象：`dev` 分支（commit `2051917`）工作区全量 + git 全历史（181 提交）。
> 用途：交给美术总监与 AI 美术顾问的项目分析报告。本报告只陈述事实与风险，**不预设审美方向**。
>
> **证据标记约定**：
> - 【代码】＝读到实际代码/数据并确认（附 `文件:行号`）
> - 【文档】＝策划/阶段文档明确描述（附文档与章节）
> - 【推断】＝基于证据的分析推断
> - 【待确认】＝仓库无法回答、需负责人决策
>
> 资产联系表（本报告生成，可直接查看）：
> [docs/art-audit/contact-ground-transitions.png](docs/art-audit/contact-ground-transitions.png) ｜
> [docs/art-audit/contact-crops.png](docs/art-audit/contact-crops.png) ｜
> [docs/art-audit/contact-archive-blender.png](docs/art-audit/contact-archive-blender.png) ｜
> [docs/art-audit/contact-themes.png](docs/art-audit/contact-themes.png)

---

## A. 项目概况

### A.1 基本身份

| 项 | 事实 | 证据 |
|---|---|---|
| 产品名 | **灵田**（窗口标题"灵田 Demo P8 · 生态经营"） | 【代码】`scripts/farming/p8/p8_scene.gd:16`；发行包名 `LingTianDemoV1`（`handoff.md:162`） |
| 引擎工程名 | `Sisyphus Mall MVP`（旧 demo 占位文案，**未改**） | 【代码】`project.godot:9`；【文档】`docs/daoyan-reuse-plan.md` §0 第5条"属占位文案" |
| 引擎 | Godot 4.7.2（标准版），2D | 【文档】`handoff.md:23`；【代码】`project.godot:11` features=4.7 |
| 题材 | **东方仙侠 · 灵植经营**（农场模拟），玩法参考星露谷物语 | 【文档】`docs/farming/master-plan.md:1,8` |
| 当前阶段 | P8"生态产业网络与工艺研究"已关闭；正式美术/音乐**另批未做**——即本次重构的空位 | 【文档】`handoff.md:5` |
| 上游关系 | 本仓库是实验沙盒，地图内核与农场模块将来移植进宿主项目 daoyan（蛊虫培养修行的仙侠主游戏）；农场产出经接口供给上游蛊虫喂养 | 【文档】`docs/daoyan-reuse-plan.md` §6、`docs/farming/phase-05-喂养与经济闭环.md:57-60` |

### A.2 世界观关键词（美术基调素材）

- **灵植/灵食、元石（货币）、五行（金木水火土，只是材料分类标签，不含相生相克视觉修辞）、二十四节气（时节名纯叙事）、蛊虫（上游消费端，本仓库不出现）**。【文档】`docs/farming/production-system.md` §1、`master-plan.md:33-45`
- 地图名"灵田·壹号"。【代码】`content/farming/baked/maps/farm_01.json:4`

### A.3 玩家角色与目标

- 玩家是**灵植农场经营者**：俯视点击、**无人物化身**、无 NPC。【文档】`docs/farming/phase-08-生态产业网络与工艺研究.md:127`；【代码】`scripts/farming/` 全目录无 dialogue/NPC 实现
- 目标：经营获利 → 再投资扩大产业（购地、设施、雇工、研究）。无强制胜负。【文档】`docs/farming/design-outline.md:8`、`demo-p8-新手手册.md:12`

### A.4 核心循环（已实现，P8）

1. 每天 24 AP（行动点）；开垦/播种/浇水/施肥/采收/砍伐/清理各 1 AP。【代码】`content/farming/config.json`
2. 手动模式逐格点击；或委托模式框选地格留待办，雇工日结执行。【文档】`demo-p8-新手手册.md:36-39`
3. 作物按天离散生长（`day_changed`），成熟收取入共享仓库。【文档】`phase-02-核心种植系统.md:36-38`
4. 加工设施投料 → 过游戏日 → 收取；研究台付样本+元石按有效研究日推进解锁。【文档】`phase-08-生态产业网络与工艺研究.md:83-88`
5. 订单/市集出售换元石 → 再投资。AP 归零自动次日，日结顺序固定（装置→雇工→生物/加工→账册→自动存档）。【文档】同上 `:114-121`
6. 首个 45 天（3 时节）生成冻结经营回顾。【文档】`demo-p8-新手手册.md:254-257`

**时间体系**：24 时节（二十四节气名）× 15 天 × 24 AP；**无昼夜、无季节视觉**（文档明确排除，`phase-06-Demo体验与三槽存档.md:28`）；光照是每区域稳定数值（阴影区 30 / 默认 80），非动态。【代码】`content/farming/p8/production.json` light 段

### A.5 玩法比重与边界

| 维度 | 比重 | 说明 |
|---|---|---|
| 种植/采集/建设/生产/经营/贸易 | **全部为核心且已实现** | P8 数据：7 植物、15 设施、40 配方、12 研究、6 活体、3 资源点、63 资源。【代码】`content/farming/p8/production.json` |
| 战斗 | **零** | 仅保留 `record_gu_use("battle")` 接口字符串；battle 桩只属旧 demo 内核实验。【代码】`scripts/farming/core/economy/farm_economy.gd:104` |
| 探索 | 几乎零 | 单农场地图+付费购地扩张，无野外/NPC 村镇。【文档】`master-plan.md:80` |
| 叙事/任务/事件/对话 | **零** | 唯一"叙事"是节气名与 45 天回顾账册 |

**独特机制**（区别于普通农场游戏，美术需服务的差异点）：多格作物 footprint（2×2 果树）；介质系统（菌床/朽木）；REGROWING/EXHAUSTED 有限再生与枯竭；一人多设施+农务兼任的工人调度；三层 12 项研究 DAG；活体生产（蜂群/菌毯/岩兽按"有效维护日"推进）；三组生态守恒网络（花源份额/真实换水污水/岩兽只转化实际投入的矿物）；五行灵食；田间维护站与补光灯自动化装置。【文档】`phase-08-生态产业网络与工艺研究.md` 全篇

### A.6 体验特征（对美术反馈设计的输入）

- **前期高频逐格点击 → 后期低频规划**（委托/自动化接管）。【文档】`design-outline.md:355`
- 当前反馈**以数字/面板为主**（资源一览、条目日报、45 天回顾、toast）；地图视觉反馈极少：成熟玉色圆点、枯竭灰褐叉号。【代码】`scripts/farming/v1/v1_scene.gd:1430-1435`
- 无现实时间挂机：不点"结束当天"世界不动；自动化全部在日结时结算。【文档】`phase-02:36`
- **风险机制极弱（休闲定位）**：缺料只暂停不死亡，无天气灾害。【文档】`phase-08:22`、`design-outline.md:293`
- **最值得用美术增强反馈的五个行为（推断）**：① 作物成熟（当前只有色块+圆点）；② 待收取加工批次；③ 研究解锁瞬间；④ 购地边界消失/新地块融入；⑤ 日结摘要（当前纯文字）。详见 E.4。

---

## B. 地图与渲染架构

### B.1 两条渲染产品线（必须先分清）

| | A 线：farm_main（V0 Demo，`play.bat farm`） | B 线：V1/V2/**P8（当前主入口）** |
|---|---|---|
| 场景 | `scenes/farming/farm_main.tscn`（Node2D） | `scenes/farming/farm_p8.tscn`（**Control 根**）→ 继承链 `p8_scene.gd → v2_scene.gd → v1_scene.gd` |
| 地形 | TileMapLayer 图层栈 | 同一 `terrain_renderer.gd`（代码复用） |
| 作物/设施 | **Sprite2D + YSort**（`crop_renderer.gd`） | **单个 Node2D Overlay 即时绘制**：色块+UI 图标+圆点（`v1_scene.gd:1427-1483`） |
| 相机 | `farm_camera.gd`，zoom [0.5, 2.0] | 内嵌 SubViewport，zoom [0.1, 3.0]，滚轮锚定鼠标缩放 |
| 地图 | farm_01 20×14 | farm_02 扩展后有效 32×22（含水库与购地） |

【代码】`project.godot:10` 主场景为 farm_p8；`v1_scene.gd:254-264`（SubViewport 链）、`:1427-1483`（draw_map）

**关键结论**：当前默认入口（B 线）**没有 Sprite 实体层、没有 YSort**——作物/设施/活体全部是 Overlay 的 `draw_texture_rect` 调用，绘制顺序=数组顺序。这是美术改造最大的结构性事实。

### B.2 相机与坐标（含"锁定 vs 可改"判定）

- **正交（Camera2D）、严格 top-down 地面 + 2.5D 斜俯视 Sprite 的混合观感；无旋转、无跟随**。【代码】全仓无 rotation 写入；【文档】`phase-00-技术基线与重构准备.md` §4 第1条（美术规范冻结：地面正交俯视，植物/建筑固定斜俯视侧后 45° 非等距）
- 世界↔网格换算：`floor(world / 64)`；B 线先经 SubViewport canvas 变换逆变换。【代码】`farm_main.gd:507-508`、`v1_scene.gd:681-683`
- 格子逻辑尺寸 **64×64**，常量 `TILE := 64` 散布于 **9+ 个文件**（`terrain_renderer.gd:10`、`crop_renderer.gd:11`、`farm_main.gd:25`、`v1_scene.gd:258,445,1395`、`v2_scene.gd:61,66`、`p8_scene.gd:80,114` 等）。【代码】
- 视口 640×360 / 窗口 1280×720 / stretch `canvas_items`+`keep`（`project.godot:15-20`）；**B 线在运行时显式关闭 stretch**（`v1_scene.gd:98-99`），改用代码布局 + 独立 UI 缩放（100/125/150%）。主设计分辨率 2560×1440，兼容 960×540/1280×720/1920×1080。【代码+文档】`docs/farming/ui-design/phase65-interface.md:9`

**已锁定（冻结决策 D1/D2 + farmtest 断言背书，改动=违约）**【文档】`phase-00` §6、`phase-01-地形与土地系统.md` §2.6：

| 锁定项 | 内容 |
|---|---|
| tile 尺寸 | 64×64 |
| bitmask 过渡管线 | 8 邻位序 N,E,S,W,NE,SE,SW,NW → 1..128；atlas 16×16=256 配置，`atlas_of(bm)=(bm&15, bm>>4)`；transitions PNG 1024×1024 |
| 逻辑零像素依赖 | 存档纯逻辑数据；纹理运行时直读（`Image.load_png_from_buffer`），同名同规格替换即生效 |
| Sprite 锚点契约 | 底部中心锚点（多格作物锚占地底边总宽中心），允许超格显示；阴影独立贴片（`shadow_ellipse.png` 48×16，偏移 (0,-4)） |
| 土地状态机 | `WILD/TILLED/PLANTED/OCCUPIED/UNAVAILABLE` 5 态 + 原子多格占用 + `cells_changed` 增量渲染（`land_grid.gd:18,332-341`） |

**可改（常量级/数据驱动）**：zoom 上下限与步进、平移速度、图层 z 值（-10..-6/-1/5/6）、高亮/标记色、地图尺寸与布局（JSON+bake）、地形种类（注册表加行，water 即先例）、购地地块（`expansion.json` 纯数据）、作物画布高度（锚点按纹理高度动态计算，`crop_renderer.gd:63`）。

### B.3 地图结构

- 规则方格网格（`[y][x]` 数组）；**P8 坐标系支持负 x**（origin_x=-4）。【代码】`land_grid.gd:70-74`
- P8 全图：基础 20×22（含 20×8 水库条带）+ 外接 32×22 购地空间（6 地块：陆 112 格 380 元石、水 96 格 280 元石）；西侧 56 格无定义不可购。【代码】`content/farming/baked/p8/expansion.json:3-13`、`p8_land.gd:24-33`
- 未购地格：地形不渲染，由 Overlay 画购买卡（浅色填充+玉色边框+名称/价格文字，`p8_scene.gd:107-121`）；购买后 `terrain.refresh_all()` 整图重建（低频事件）。【代码】`p8_scene.gd:26-32`
- 地形层（5 层注册表）：grass(0)/dirt(1)/stone(2)/tilled(3 动态耕地层)/water(4, edge_mode="full" 整块平铺无过渡)。【代码】`content/farming/p8/terrains.json:51-62`、`terrain_renderer.gd:64-70`（层 z = -10+layer）
- 水不是状态而是静态地形；耕地层是动态层（谓词=有介质/已开垦）。【代码】`terrain_renderer.gd:152-159`

### B.4 图层栈与绘制方式

**B 线（当前主入口）世界节点树**【代码】`v1_scene.gd:242-264`：

```
FarmP8 (Control)
└─ ui_root (Control, LINEAR 过滤)
   ├─ HUD/侧栏/工具栏（纯代码 Control 树）
   └─ map_view SubViewportContainer (stretch)
      └─ map_port SubViewport (transparent)
         └─ root Node2D (NEAREST 过滤)
            ├─ Ground/T_dirt/T_stone/T_tilled/T_water  (TileMapLayer, z=-10..-6)
            ├─ Camera2D
            └─ Overlay Node2D (LINEAR; _draw() 画所有实体与标记)
```

- 地形=TileMapLayer 引擎批处理；A 线作物=Sprite2D+YSort+阴影子贴片；B 线实体=单 Overlay 顺序绘制（作物→设施→资源点→雇工区域→待办标记→选种点→选中框→建造预览→框选预览，`v1_scene.gd:1427-1483`）。
- **全仓库无 Shader、无粒子、无逐帧动画系统**（farming 模块；旧 demo 有 2 帧 idle 物件与行走帧动画）。【代码】grep 零命中
- 纹理过滤双轨：地图 root NEAREST / UI 与 Overlay LINEAR；项目默认 `default_texture_filter=0`（NEAREST）。【代码】`v1_scene.gd:210,252,263`、`project.godot:62`
- 阴影：A 线每作物一个 `shadow_ellipse.png` 子贴片 z=-1。【代码】`crop_renderer.gd:50-55`

### B.5 性能与渲染预算

- 无显式可见性剔除（依赖 TileMap 内建）；B 线 SubViewport `UPDATE_ALWAYS`（永远渲染）；Overlay 在每次鼠标移动与世界变更时全量重绘。地图小（≤704 格）可接受。【代码】`v1_scene.gd:249,720,463`
- 满种极端 A 线约 500 Sprite2D；B 线世界内 Sprite=0。地形增量更新纪律严格（只改受影响 9 格，`terrain_renderer.gd:77-88`）。【代码+自测断言】
- 无性能预算/帧率目标文档；发行方式为 Windows 独立包（`tools/farming/build_*.ps1`，内嵌 PCK 的 exe+manifest/SHA256）。【文档】`handoff.md:158`

### B.6 视角改造影响面（技术事实，非建议）

- **改正投影为等距/斜俯视地面**：需动 9+ 文件的 ×64 换算、bitmask atlas 语义与重生成、TileSet tile_size、相机钳制矩形假设；B 线还需先补"按 y 排序的 Sprite 层"（当前 Overlay 顺序绘制无深度概念）。tile 64 与 bitmask 属冻结决策，需走决策记录解冻。【代码+文档】
- **维持俯视、加多层次装饰（架空层/大树冠/悬垂物）**：A 线 YSort 架构已就绪，照 `crop_renderer` 模式加 Sprite 即可；**B 线需新增一个渲染层**（Sprite2D 层挂 root 或 Overlay 内按 y 排序）——局部新增，不动地形管线。【代码】
- 纹理重复：地面 64×64 单图平铺，3×3 目检通过，但大图+zoom-out 时重复感存在（联系表目检确认）；【推断】过渡抖动参数（圆角 R13/对角 R6/1px 棋盘抖动）可调（`palette.json` transition 段）。

---

## C. 现有美术资产调查

### C.1 资产总表（按使用状态分类）

**① 当前正在使用（正式）**——24 项 delivered（`content/farming/art_status.json`）+ 程序产物：

| 类别 | 路径 | 数量 | 规格 | 状态 |
|---|---|---|---|---|
| 地面纹理 | `assets/farming/ground/ground_{grass,dirt,stone,tilled}.png` | 4 | 64×64 RGB 无 alpha，近色板离散色（46-60 色） | **正式**（AI 出图→quantize 管线，2026-10-09） |
| 作物阶段图 | `assets/farming/crops/{dew_grass,scarlet_berry,moon_cap}/stage_0..3.png`；`{scarlet_berry,jade_fruit_tree}/+stage_harvested+exhausted.png` | 20 | 64×64（树 128×192）RGBA **alpha 二值** | **正式**（用户工作区白底导入 2 种 + image_gen 母版衍生 2 种） |
| 过渡 atlas | `assets/farming/transitions/trans_upper_{dirt,stone,tilled}.png` | 3 | 1024×1024（16×16×64px） | 程序确定性生成（`--transitions-only` 从正式 ground 重建），不占手绘量 |

**② 当前正在使用（占位/临时）**：

| 类别 | 路径 | 数量 | 现状 |
|---|---|---|---|
| 水面 | `assets/farming/ground/ground_water.svg` | 1 | 手写简单 SVG（实底+波纹线），无采购登记 |
| UI 图标 | `assets/farming/ui/*.svg` + `manifest.json` | **117** | 占位矢量（线形，64×64 viewBox）；`gen_p8_icons.py` 自述"Formal art arrives in a later dedicated batch and replaces these files by the same names"。**同时被 B 线当作地图上作物/设施的示意图标复用**（`v1_scene.gd:1434,1440,1446`） |
| 介质 | 无贴图 | — | 半透明色块（`farm_main.gd:596-605`） |
| P8 世界实体 | 无贴图 | — | 色块矩形+图标+圆点（`v1_scene.gd:1427-1461`） |
| 阴影贴片 | `assets/farming/crops/_placeholder/shadow_ellipse.png` | 1 | 48×16 程序占位，常驻使用 |

**③ 存在但仅历史场景引用**：`transitions/trans_grass_dirt.png`（1024×1024，仅 `farm_phase00_map.gd:79` farm0 验证场景）；`_placeholder/stage_0.png`、`tall_stone.png`（phase00）。【代码】

**④ 归档（明确废弃但完整保留）**：`archive/old-farming/`（29 个 git 追踪文件，详见 H 节）。【代码】git 历史从未删除过任何 png/svg/blend。

**⑤ 无法判断/残留**：15 个孤儿 `.svg.import`（gen_ui_icons.py alias 改名后残留，无危害，clone 后自动重建）；`assets/sprites/` 空目录。【数据确认】

**⑥ 旧 demo 三主题**：`assets/themes/{placeholder,dusk,wilds}/{tileset,objects,player}.png`（32px 体系），仍被 `play.bat demo` 路线数据驱动引用（`content/baked/<theme>/manifest.json` → `map_host.gd`），**未废弃**但与农场 64px 体系平行无关。【代码+数据】

### C.2 内容缺口真值表（art_status/asset_manifest 未覆盖项）

`baked/asset_manifest.json`（31 项）只覆盖 ground+crop_stage+atlas+shadow。**以下全部为 0**：【代码】`content/farming/p8/production.json` 对照

- P8 七作物生长阶段图（0 张；地图上只有 2 个视觉状态：生长中色块/成熟色块+圆点）
- 15 设施地图贴图（0；平色块+图标）
- 6 活体幼体/成体贴图（0）
- 12 研究项图标（0，复用研究台图标）
- 水面正式纹理、介质贴图（0）

### C.3 视觉一致性分析（联系表目检 + 图像分析）

见 [contact-crops.png](docs/art-audit/contact-crops.png)、[contact-ground-transitions.png](docs/art-audit/contact-ground-transitions.png)：

1. **当前正式资产内部一致性较好**：4 作物同为低饱和像素风、左上主光、底部触地；地面 4 种明度层级清晰（草最亮→耕最暗）、色温统一；草地 3×3 平铺无明显接缝。【推断（图像分析）】
2. **已知差异**：dew_grass/scarlet_berry（用户工作区白底导入）与 jade_fruit_tree/moon_cap（image_gen 母版衍生）来源不同——赤纹果饱和度偏高、月华菇极低饱和冷调；青玉果树轮廓复杂度（颜色数 5048）远高于凝露草（608）。【推断（PIL 颜色统计+图像分析）】
3. **最大的风格断层不在世界内部，而在三处**：【推断】
   - **世界（像素风、NEAREST）vs UI（非像素线形 SVG、LINEAR、明亮暖色）**——两套色板、两套过滤、两套美学；phase65 美术指导已宣布"新素材不再强制像素风"，即官方已决定与世界像素风解耦，但**尚未出现任何非像素世界素材落地**（`docs/farming/ui-design/phase65-art-direction.md:27-32`）。
   - **V0 正式资产（A 线使用）vs B 线地图（色块+UI 图标示意）**——当前主入口 P8 的地图根本不消费那 20 张作物阶段图。
   - **旧 demo 32px 三主题**（纯功能占位）与农场体系完全平行。
4. 旧 Blender 资产是"写实偏卡通渲染"，与像素风存在显著断裂，**只能作风格/机位参考，不能混用**。【推断（图像分析）】

---

## D. 内容资产规模清单

### D.1 三版数据规模增长（源 JSON 实测）【代码】

| 维度 | V1 | V2 | **P8（当前）** |
|---|---|---|---|
| resources | 18 | 25 | **63** |
| crops | 4 | 5 | **7** |
| facilities | 4 | 7 | **15** |
| recipes | 9 | 13 | **40** |
| livestock | 0 | 2 | **6** |
| research | 0 | 0 | **12**（三层 DAG） |
| 地图 | 20×14 | 20×22+水库 | 20×22+6 购地块（有效 32×22） |

v1/v2 资源是 P8 的真子集（无"仅历史使用"资源）。候选库：43 物种=24 植物+10 陆生+9 水生，当前实装 13 种，其余 30 种纯文档候选。【文档】`docs/farming/production-system.md`

### D.2 P8 七作物状态矩阵（美术需求推导）【代码】`content/farming/p8/production.json` crops 段

| 作物 | 占地 | 天数 | 模式 | 特殊视觉需求 |
|---|---|---|---|---|
| 金穗麦 | 1×1 | 4 | 收获再种 | 4 阶段 |
| 速生杉 | 2×2 | 8 | 砍伐再种 | 4 阶段（大画布） |
| 松脂树 | 2×2 | 8 | **采脂循环或砍伐** | 4 阶段 + 采脂中状态 |
| 木腐菇 | 1×1 | 4 | 菌棒式逐周期 | 4 阶段 + **喜阴**（阴影区种植） |
| 青牧草 | 1×1 | 3 | 收获再种 | 4 阶段 |
| 蜜铃灌木 | 1×1 | 6 | 采蜜或砍伐 | 4 阶段 + 花期变体（flower_days=1） |
| 油籽花 | 1×1 | 5 | 收获再种 | 4 阶段 + 花期变体（flower_days=2） |

加水/肥日耗（视觉干湿反馈可选）、光照 30/80 差异。**估算 ~32-36 张阶段图（0 已有）**。

### D.3 设施与活体【代码】

- 15 设施：11 个 2×2 + 4 个 1×1；类别=加工 8/养殖 4/研究 1/自动化装置 2。若加"生产中/待收取"状态变体则 15-30 张（当前 0）。
- 6 活体：幼体/成体两数据阶段 → 12 张（当前 0）。活体渲染在设施卡内，无独立地图实体。
- 63 资源图标：现有 117 枚占位 SVG 中 85 枚与 P8 数据 id 一一同名对应（63 资源+15 设施+7 作物），零缺失；另 32 枚=27 动作图标+5 五行。【数据确认】

### D.4 全量正式美术总量估算【推断，基于上述契约】

- **完整口径 ≈ 170-180 张**：5 地面（含水）+ 20 重绘（V0 四作物换风格）+ ~34 P8 作物 + 15-30 设施 + 12 活体 + 63 资源图标 + 可选 27 UI/12 研究。
- **最小 P8 集 ≈ 129 张**（5+34+15+12+63）。
- 过渡 atlas（3-4 张 1024²）与阴影贴片由工具确定性再生成，**不占手绘量**。

### D.5 最庞大/最频繁迭代 → 最需标准化自动化的类别【推断】

1. **资源图标（63，且随每次加内容线性增长）**——形状×五行填色的程序化占位已证明可行，正式化时应保留"数据 id=文件名"契约。
2. **作物阶段图（7×4+变体，每新增物种+4~6 张）**——母版→衍生管线已验证，是最成熟的自动化环节。
3. **设施状态变体（若做，15×2）**——建议以"底座+状态角标"分层而非整图变体（B 线 Overlay 天然支持分层绘制）。

---

## E. UI 与玩家交互分析

### E.1 界面清单（P8 现状，全部纯代码构建）【代码】`v1_scene.gd`/`v2_scene.gd`/`p8_scene.gd`

| 界面 | 入口 | 实现方式 |
|---|---|---|
| 主地图 HUD 顶栏（时节/日/AP/元石，单行文字） | 常显 | Label 文字 |
| 顶部导航条（行囊 M/订单 O/雇工 U/建设 B/记录 J/手册/研究/购地/全图 F/侧栏） | 图标按钮 | 20px SVG+tooltip |
| 引导提示行（5 步轮换） | 常显 | muted 文字 |
| 底部农务工具栏（10 工具，数字 0-9；手动/委托切换；优先级） | 常显 | 40px 图标按钮 |
| 右侧详情侧栏（地格/资源点/设施/研究台/装置，可收起） | 查看工具点击 | 面板+ProgressBar+SpinBox 混合 |
| 行囊与市集（6 类筛选/买卖/数量） | M | 图标网格卡片 |
| 五行订单（每日 3 单） | O | 卡片 |
| 雇工管理（预算/偏好矩阵/负责区域） | U | 卡片+SpinBox |
| 建设目录（研究锁/建材替代） | B | 图标卡 |
| 经营记录（15 日条目）/日结报告/45 天回顾 | J | 条目文字行 |
| 日摘要 digest（左上浮层） | 日结后 | 浮层面板 |
| V2 资源一览（7 日均值/五行筛选/关注） | 顶栏 | 表格 Label |
| V2 养殖总览 / 关注条 watch strip | 顶栏/常显 | 卡片/浮层 |
| P8 研究页 / 购地页 / 新手手册（11 章） | 顶栏 | 卡片/步骤卡 |
| 开始页三槽存档 / 菜单 / 显示设置 / 确认弹窗 | 启动/Esc | Control 树+系统 ConfirmationDialog |

### E.2 交互模式【代码】

- 鼠标为主：左键拖动=框选/放置；右键=取消；滚轮=锚定鼠标缩放（0.1~3.0）；悬停只读提示。键盘 WASD 平移、0-9 工具、M/O/U/B/J/F/R/Esc。**无触控支持**（全库无 touch 代码）。
- 批量：委托模式框选 N 格+优先级；"高级 3×3 工具"仅 V0 遗留（`farm_economy_panel.gd:107-118`）；P8 批量=持续生产策略+负责人自动化。
- 交互契约（不可动，`phase-06.5` §验收规则）：Esc/右键层级、框选判定、只读悬停不扣资源、危险操作确认、UI 缩放与地图缩放分离。

### E.3 UI 视觉约束（技术边界）【代码】

- **无 .tscn UI、无 Theme 资源、无图片字体**。主题=`v1_ui_style.gd` 75 行常量：INK `#f6f4ed`/PANEL `#fffdf8`/SURFACE `#eef2e8`/BORDER `#cfd8c6`/正文 `#334238`/JADE `#58745b`/ERROR `#9b4e42`/WATER `#446976`；StyleBoxFlat 1px 边圆角 8。
- 字体：SystemFont + MSDF，回退链 Microsoft YaHei→Noto Sans CJK SC；字号 18/16/22。**无打包 TTF**。
- 布局全部运行时计算（顶栏 44px、侧栏 min(360,×0.43)、窗口 1040×780、compact<1100px）——改字号/图标尺寸必须同步这些魔数（`v1_scene.gd:360-414`）。
- **硬编码中文，无 i18n 结构**。
- 换肤最小切入点：`v1_ui_style.gd` 色板 + `draw_map()` 硬编码色（v1 5 处+p8 2 处）+ 117 SVG。复杂皮肤（九宫格纹理/字体资源/主题变体）需引入 Theme 资源管线。

### E.4 信息密度问题（美术重构的直接动机之一）【代码+文档】

地图上同格 64px 内可并存：作物图标+底色块+成熟圆点+选种点+**堆叠最多 4 个待办标记 chip（2×2 排布）**+选中框；浮层有 hover_hint/日摘要/关注条/顶栏两行/底部 notice+工具栏。委托重度使用时地图接近"图标棋盘"（`demo-p8-新手手册.md:203` 亦要求自查多系统叠加）。文字尺寸用 `1/(zoom×ui_scale)` 反向缩放保证可读（`p8_scene.gd:110`）。侧栏养殖设施详情可达 30+ 行文字。

**应始终可见**（推断）：AP/元石/时节、成熟与待收取状态、未购边界。**可仅选中时显示**（推断）：水肥数值、待办明细、光照、选种计划。

---

## F. 美术生产流水线（现有工具与自动化程度）

### F.1 流水线全景【代码】`tools/farming/`

```
content/farming/*.json ─bake_farm.py→ baked/（运行时唯一读取）
        └→ gen_asset_manifest.py → baked/asset_manifest.json（采购单，status: missing/placeholder/
              requested/delivered/generated；--missing 缺失即 exit 1 可作 CI 门）
        └→ build_art_handoff.py --batch <批次> → .art-work/handoff/<批次>/
              （manifest+prompts+palette+style-sheet+README+checksums+占位参考；输出目录必须为空）

出图（现行）：内置 image_gen——母版 2 候选 → 人工审核选 A/B → 以审核母版为参考图逐阶段"Edit"衍生
出图（历史/备选）：ComfyUI 本机 API（Qwen-Image 2.1 int8 栈，参数固化在 gen_ground_batch.py 等脚本）

回传后处理（确定性，与出图渠道无关）：
  ground: quantize_ground.py（亮度分位拉伸→中值→锚点色吸附）→ postprocess_assets.py
          （整倍 NEAREST 缩 64 + 4px 对称边缘无缝化 + 3×3 预览）
  crop:   postprocess_assets.py（补画布→整倍缩→色键去底→alpha 二值→8 连通留最大主体
          →bbox 居中贴地（底边距 2px）→透明区 RGB 清零）

入库门：人工平铺/排图审核 → 同名复制到 assets/ → gen_farm_terrains.py --transitions-only
        → qc_assets.py --target all → play.bat farm --farmtest → 截图目检
        → art_status.json 登记 delivered → 重建 manifest → git 提交

占位生成器（protect_delivered 拒绝覆盖已交付资产）：gen_phase00_textures.py / gen_farm_terrains.py
        / gen_farm_crops.py / gen_ui_icons.py / gen_p8_icons.py / gen_placeholder_assets.py(旧demo)
```

### F.2 关键契约【代码+文档】

- **唯一色值来源** `tools/farming/palette.json`（ground 4 地物×4 色、crops 8 族、transition 8 参数）；提示词色值由工具注入，不手工维护。
- 命名：作物 `stage_<i>`/`stage_harvested`/`stage_exhausted`；地面 `ground_<id>`；过渡 `trans_upper_<id>`；UI `<数据id>.svg`；全蛇形（QC 强制）。
- 画布契约：普通作物 64×64、树 128×192、源图=目标整倍数；atlas 1024×1024。
- QC 铁律（`qc_assets.py`）：PNG/精确尺寸/alpha 二值/2px 安全边/8 连通单主体/底部中心锚点/成熟占比 0.55-0.75（告警）/ground 无缝边界梯度/蛇形命名/多余阶段报错。当前基线 31 项 0 失败。
- **历史事故铁律**：P1 右向行走整行空帧→"角色凭空消失"，自此 alpha 二值+逐行不透明度检查为强制项（`docs/demo-phases.md` P1 修复记录）。
- AI 生成记录：`docs/farming/art-generation-phase04.json`（母版 prompts/seed/SHA256/衍生关系，完整可追溯）；`.art-work/`（git-ignored，~964MB）保留原图/候选/失败报告/移交包。

### F.3 与新方向的落差【文档，重要】

- `docs/farming/art-style-sheet.md`（V0 像素风规范）头部声明：**2026-10-11 起用户取消像素风限制**，新素材以 `ui-design/phase65-art-direction.md` 的拼接/机位/光照原则为准（允许渐变/抗锯齿/平滑透明边；逻辑地格仍 64 单位）。
- **现行 QC（二值 alpha、NEAREST 降采样）与新规范冲突**：qc_assets.py 与 postprocess_assets.py 的像素风约束尚未按新规范修订——第一批非像素世界素材入库前必须先改造 QC 口径。【推断+文档】

### F.4 规模适应性判断【推断】

管线为"数据驱动采购单→移交包→确定性后处理→QC 门→同名替换"的闭环，**适合数百张素材的持续生产**（63 图标与 20 作物阶段已按此流程走通）；短板：①正式资产的验收依赖人工目检（平铺/排图/截图三重）；②QC 规则需按新美术方向重写；③无设施/活体/状态变体的 manifest 类目（现只有 ground/crop_stage/atlas/utility 四类）。

---

## G. 技术可行性与风险矩阵

| 方向 | 技术可行性 | 主要改动面 | 风险等级 |
|---|---|---|---|
| **维持正俯视 2D，仅换素材** | **高**。替换契约成熟：同名同规格覆盖即生效，逻辑零像素依赖（`phase-01` §2.6） | 0 行代码（除 QC 工具按新规范调整） | 低 |
| **俯视+多层次装饰（阴影/大树冠/架空层）** | A 线高（YSort 就绪）；**B 线需补一个 Sprite 层**（当前 Overlay 顺序绘制无深度） | B 线新增渲染层（局部新增，不动地形）；A 线零结构改动 | 中（B 线为主） |
| **B 线地图实体 Sprite 化（作物/设施用正式贴图替代色块）** | 高。`crop_renderer.gd` 模式可移植；或 Overlay 内 draw_texture_rect 换贴图+按 y 排序 | `v1_scene.gd draw_map()`（1427-1483）与 P8 侧栏/图标加载；需引入 y 排序 | 中 |
| **斜俯视/等距视角** | 理论可行但代价大：9+ 文件 ×64 换算、bitmask atlas 语义+重生成、tile_size、相机钳制、B 线补 YSort 层；**D1/D2 冻结决策需正式解冻** | 渲染层+坐标系+全部素材 | **高** |
| **Blender 渲染 2D** | 管线历史存在（archive），master-plan 为复杂建筑保留"Blender 体块辅助+AI 风格化"口子 | 复用 `apple_tree.py`/`glaze_lily.py` 方法论；需重建出图→键控→量化流程 | 中（产能与风格一致性是主风险，历史已因此放弃一次） |
| **程序化地形扩展（新地形/装饰层）** | 高。注册表加行+生成器两张图即可（water 为先例，`phase-01:42-43`） | 数据+生成器 | 低 |
| **分辨率/性能** | 当前无压力（≤704 格）；引入大画布精灵+阴影后需关注 zoom-out 时 draw 调用量 | — | 低-中 |

**其他技术约束**：魔法数 64 散布 9+ 文件（改 tile 尺寸需一次性收口）；Overlay 全量重绘在鼠标移动时触发（大图+高密度标记时需节流）；大量透明精灵对 A 线是 2×Sprite/株（本体+阴影）线性增长；不同尺寸植物/建筑对齐由"底部中心锚点+footprint 分离（sprite_size vs footprint）"契约保证，**该契约已验证可直接支持大画布**（jade_fruit_tree 128×192 即先例）。【代码】

**资源替换最易回归的模块**（按历史事故与测试覆盖推断）：① 地形过渡拼接（phase00 场景+farmtest 断言覆盖）；② 作物阶段状态机与缺图回退（`crop_renderer.gd:66` 缺图自动隐藏）；③ 释放冒烟的 art_count 断言（`farm_release_smoke.gd:38` 硬编码 27，资产数变化需同步）；④ UI 图标 manifest 一致性（`test_ui_assets.py`）。

---

## H. 适合保留的历史成果

### H.1 技术基础（直接复用，无需改动）

1. **地形分层栈+bitmask 过渡管线**（`terrain_renderer.gd` + `land_grid.gd` + `transition_assets.py`）——换任何 64×64 ground 纹理即可确定性再生成 256 配置过渡。
2. **资产采购管线五件套**：`build_art_handoff.py`/`postprocess_assets.py`/`qc_assets.py`/`gen_asset_manifest.py`+`art_status.json`（含 `protect_delivered` 防覆盖）——与出图渠道无关。
3. **母版→衍生的 AI 生成方法论**（`art-generation-phase04.json` 完整记录：身份约束+目标占比+负面列举+色值锚点的提示词模式）。
4. **QC 铁律与三重目检入库门**（平铺/排图/截图）。

### H.2 可复用资产与参考

| 资产 | 位置 | 保留价值 |
|---|---|---|
| 4 地面正式纹理+20 作物阶段图 | `assets/farming/` | 当前唯一正式世界素材；换风格时的**规格与管线基准**（也是重绘清单的一部分） |
| `tools/farming/palette.json` | 现行 | 唯一色值来源，新色板应在此扩展而非另起 |
| 旧耕地色板 `farmland_palette.json` | `archive/old-farming/tools/` | 干/湿各 5 级坡道，注释明确对齐 wilds 暖棕族——与现行"主色域延续 wilds 草绿/暖棕"直接对接 |
| Blender 多视角对照体系 | `archive/old-farming/assets/models/renders/`（top/front/right/hero45 × 白模/材质/带花，见 [contact-archive-blender.png](docs/art-audit/contact-archive-blender.png)） | **视角选型的完整实验记录**；hero45 与现行"斜俯视 2.5D 侧后 45°"规范直接呼应，可作新资产机位对照模板 |
| `apple_tree.py`/`glaze_lily.py`/`lotus_flower.py` | `archive/old-farming/tools/` | Blender 体块辅助方法论（master-plan §2.4 为复杂建筑保留此口子）；苹果树"土墩+草皮+挂果+掉落果"部件化思路对多格果树构图有参考价值 |
| `gen_farmland_sprite.py` 量化算法 | 同上 | 渲染/照片→像素风的降采样管线（秩次直方图均衡+Bayer 抖动+despeckle+色板封闭 QC） |
| 三主题占位图集 | `assets/themes/` | 旧 demo 回归基准（`play.bat demo` 仍在用），与农场体系无关，勿混 |
| phase65 美术指导+色板 | `docs/farming/ui-design/phase65-art-direction.md` + `phase65-ui-palette.json` | **现行唯一有效的视觉方向文件**（暖米白/浅茶绿/柔陶；UI 与世界色板分离原则；正交斜俯视+左上主光的母版规范） |

### H.3 旧资产与当前体系的兼容判定【推断】

- `farmland_dry/wet_64.png`：64×64 但语义是旧 2×2 瓦片（旧 32px 体系），垄密度超标 4 倍——**需改造**（2× 放大按 2×2 格用，或换色板重跑生成器）。
- Blender renders（1024²/1600×1920 不透明）：不能直接用，仅参考。
- 旧 demo 32px 图集：不兼容，独立保留。

---

## I. 尚待产品负责人确认的问题（按决策优先级）

1. **世界美术风格走向**：phase65 已定 UI 方向（明亮非像素），但世界场景（地面/作物/设施）**未定**是延续像素风还是跟随非像素新方向——两套并存已是被文档承认的断层。仓库无法回答，只有负责人能定。
2. **B 线（P8 主入口）是否 Sprite 化地图实体**：当前作物/设施=色块+图标。要"世界正式美术"就必须做，但改动集中在 `draw_map()`；做不做、何时做需排期决策。
3. **目标画面细节度与成本取舍**：最小集 129 张 vs 完整 170-180 张 vs 状态变体扩展；出图主力（内置 image_gen / ComfyUI / 人工 / 混合）。
4. **主视觉参考作品**：仓库只提过星露谷（玩法）与"东方仙侠"意象，无视觉标杆。
5. **旧 V0 像素资产处置**：保留混用 / 全部重绘 / 仅作过渡。
6. **视角是否永久锁定正俯视**（等距改造代价见 G 节；若锁定可把 bitmask/atlas 视为长期资产持续投资）。
7. **性能/平台预算**：当前仅 Windows 独立包；是否有移动端/掌机目标（影响触控 UI、纹理内存预算、atlas 策略）。
8. **品牌字体**：当前依赖系统微软雅黑/Noto，跨机器渲染不一致；是否采购/指定字体并打包。
9. **多语言**：硬编码中文，若需英文需先立 i18n 结构（影响所有 UI 素材中的文字）。
10. **project.godot 工程名" Sisyphus Mall MVP"改名时机**（对外发布前必须）。
11. **水面正式美术优先级**（当前手写 SVG，是 5 地形中唯一非正式）。
12. **不可改动范围确认**：交互契约（E.2）、tile 64/bitmask 冻结决策是否在本次重构中保持。

---

## J. 美术重构前建议的最小验证（一条可执行的试验路径）

**目标**：在不动玩法逻辑的前提下，用一个小批次同时验证"地图/植物/建筑/UI 风格统一性"与最大技术风险点。

### J.1 试验范围（1 个新地面 + 2 株作物 + 1 座设施 + 1 套状态标记）

1. **地面**：选 1 种新风格地面（建议水 `ground_water`——唯一非正式地形，替换零风险），按 64×64 无缝契约出 2 候选，走 `postprocess → --transitions-only → qc → farmtest` 全管线。验证：平铺观感、过渡 atlas 兼容、非像素纹理在 NEAREST 地图根下的表现。
2. **作物**：选 P8 一株 1×1 作物（如金穗麦）+ 一株 2×2（速生杉），按母版→衍生管线出 4 阶段+采后/枯竭，按 `crop_renderer` 契约接入 **A 线 farm_main**（该线 YSort/阴影/锚点全就绪），同时**在 B 线 Overlay 试点 draw_texture_rect 替换色块**（含按 y 排序最小实现）。验证：阶段可读性、多格对齐、阴影一致性、B 线改造的真实成本。
3. **设施**：选 1 座 2×2 设施（如研究台）出图，验证"底座贴图+状态角标"分层方案（生产中/待收取用角标而非整图变体）。
4. **UI**：用同一色系重绘 5 枚高频图标（元石/AP/成熟/待收取/研究），叠加在试验截图上目检世界与 UI 的色彩关系（phase65 已定"UI 与世界色板分离"原则，此步验证分离后的和谐度）。
5. **状态可读性专项**：在同一截图网格中对比"成熟/待收/枯竭/喜阴缺光"四种状态在新旧表现下的辨识速度（委托重度使用场景）。

### J.2 应验证的技术风险清单

| # | 风险 | 验证方式 |
|---|---|---|
| 1 | 非像素素材与现存像素资产的混搭断层 | J.1-1/2 截图并排新旧 |
| 2 | B 线 Overlay Sprite 化的排序/性能代价 | J.1-2 B 线试点，量测 zoom-out 全图重绘帧耗 |
| 3 | QC 规则与新规范冲突（二值 alpha/NEAREST） | 先改 `qc_assets.py` 口径再入库，跑 `test_asset_pipeline.py` |
| 4 | 大画布精灵（2×2 设施/树）对格对齐与遮挡 | farmtest 前后遮挡像素断言（`phase00_check.gd:311-317` 已有基准） |
| 5 | 释放冒烟 art_count 硬编码 | 同步 `farm_release_smoke.gd:38` |
| 6 | 阴影体系一致性（shadow_ellipse 48×16 是否够用） | 试验批次统一阴影后再目检 |
| 7 | 信息密度：新图标/状态与待办 chip 叠加 | J.1-5 状态辨识测试 |

### J.3 完成标准

- 一张同风格四联截图（地面/作物/设施/UI）达到"可交给美术总监判断方向"的质量；
- B 线 Sprite 化改动量与帧耗数据出炉，支撑"是否全面 Sprite 化"的决策（I.2）；
- `test.bat` 全绿（QC/工具/V0/V1/V2/P8 回归）。

---

## 附：本报告的证据复核入口

- 玩法/世界观：`docs/farming/master-plan.md`（唯一权威）、`demo-p8-新手手册.md`
- 渲染：`scripts/farming/rendering/{terrain_renderer,crop_renderer,farm_camera}.gd`、`scripts/farming/v1/v1_scene.gd:1427-1483`
- 数据：`content/farming/p8/production.json`、`content/farming/art_status.json`、`content/farming/baked/asset_manifest.json`
- 美术规范：`docs/farming/phase-00-技术基线与重构准备.md` §4、`docs/farming/ui-design/phase65-art-direction.md`、`docs/farming/art-pipeline.md`、`docs/farming/art-style-sheet.md`
- 历史考古：`archive/old-farming/README.md`、git log（第一提交 `017a09c` 2026-10-04；旧地基 `99b039b`→归档 `58aa96d` 2026-10-08）

---

## K. 本仓库检索不到 / 证据不足的条目清单（2026-10-13 补录）

> 本仓库是实验沙盒/分支，完整游戏设计在**上游 daoyan 仓库**与负责人处。以下条目在本仓库**无文档、无代码、或仅有不可验证的转述**，交给美术总监/AI 美术顾问前需另行取证。分三类：K.1＝上游持有的背景（本仓库仅有二手转述）；K.2＝任何仓库都不存在、需负责人定义；K.3＝本报告自己做的推断（不是仓库事实，决策时勿当证据用）。

### K.1 上游（daoyan）仓库持有——本仓库文档只是转述，无法在此验证

| # | 条目 | 本仓库现存"证据"及其局限 | 报告位置 |
|---|---|---|---|
| 1 | daoyan 宿主游戏的完整设计：蛊虫培养、资源获取、修行成长的具体玩法与视觉形态 | `docs/farming/master-plan.md:33-45` 一段转述；上游仓库本体不在此（handoff 明确"只读不改"，本机也无该仓库） | A.1/A.2 |
| 2 | daoyan 三套地图形态（SceneStage 大图+热点 / 狩猎图 / 演出底图）与 Phase 87/88 移植计划 | `docs/daoyan-reuse-plan.md:153-166` 为摸底笔记，自述"仅背景，勿据此实施"；上游实际结构未对照 | A.1 |
| 3 | 上游接口的真实语义：`record_gu_use` / `export_materials → special_materials`、元石同名计数器 | 本仓库只有桩实现（`farm_economy.gd:104`）；消费端行为、结算口径全在上游 | A.1 |
| 4 | 蛊虫喂养/饱食度的真实模型 | `phase-05-喂养与经济闭环.md` 的饱食度 6/每日递减是**本仓库闭环 stub**，与上游真实模型的关系未验证 | A.1 |
| 5 | "农场产出供给上游蛊虫喂养"的最终产品形态（上游如何呈现/消费这些素材） | 仅 master-plan 定位描述，无上游侧设计文档 | A.1 |

### K.2 任何仓库都没有——需负责人/上游设计文档定义

| # | 条目 | 说明 | 报告位置 |
|---|---|---|---|
| 6 | 世界观叙事设定：灵田的地理/时代/势力归属、玩家身份的叙事包装 | "灵植农场经营者"是机制角色，非叙事设定；元石的世界观含义、蛊虫与灵植的 lore 均无文档 | A.2 |
| 7 | 目标用户画像与游戏气质定义 | 无 | I.1 |
| 8 | **正式的视觉参考作品/美术标杆** | 仓库内最接近的只有两处非正式痕迹：玩法参考星露谷（`master-plan.md:8`）、归档脚本注释"参考原神外观"（`archive/old-farming/tools/glaze_lily.py:2`）——均不是视觉方向决定 | I.4 |
| 9 | "无人物化身"是永久设计还是暂缓 | 代码事实=当前无化身；master-plan 仅把"NPC 大规模农业生产"列为暂不开发，未写明永久排除角色 | A.3 |
| 10 | 后续 Phase（P9+）范围：繁殖/寿命、设施升级、人工资源点、43 物种候选库的落地节奏 | handoff 一句"后续 Phase 尚未定范围…另排"，无设计文档 | A.5/D.1 |
| 11 | 多区域/多生态环境/多文化风格的长期规划 | 本仓库证据=单农场单风格（32×22）；第十部分所问"区域、生态、文化风格数量"无任何数据 | D |
| 12 | 音频方向 | 全仓库零音频资产、零音效设计文档（handoff 仅"正式音乐另排"） | （报告未覆盖，补记） |
| 13 | 多语言与发行平台计划（移动端/Steam/掌机）、品牌字体、正式游戏定名 | 均无文档；"灵田"目前只是 Demo 窗口标题 | I.6-I.9 |
| 14 | 性能/显存/帧率预算 | 无任何性能预算文档；报告 B.5 的"无压力"是推断（见 K.3-11） | B.5 |

### K.3 本报告的分析推断/审计新产生结论——非仓库证据，仅作待验证假设

| # | 条目 | 性质 | 报告位置 |
|---|---|---|---|
| 1 | "最值得用美术增强反馈的五个行为" | 无玩家数据/问卷支撑；回放台账均为自动化/代理执行，非真实玩家样本 | A.6 |
| 2 | "应始终可见 vs 选中时显示"的信息分层 | 纯建议 | E.4 |
| 3 | 视觉一致性结论（作物饱和度差异、平铺重复感、Blender 资产"写实偏卡通"等） | 本次审计对联系表的图像分析，非仓库记录 | C.3 |
| 4 | "官方已决定与世界像素风解耦" | **表述强于原文**：phase65 只说新素材不再强制像素风，未承诺存量像素世界重绘 | C.3 |
| 5 | 资产总量估算 129 / 170-180 张 | 依赖两个未确认假设：设施需要状态变体、P8 为主产品而传统 demo 仅回归 | D.4 |
| 6 | "官方已决定与世界像素风解耦"以外的解读类结论：如"两套美学已被承认断层" | 部分有文档（UI 与世界色板分别管理），部分为解读 | C.3 |
| 7 | 旧 Blender 地基的放弃原因（"逐资产建模产能/风格一致性不符量产"） | master-plan/README 只写"整体放弃、采用方案 A"；**原因措辞是推断** | H.1/H.2 语境 |
| 8 | "多视角渲染=当时在选型视角、hero45 与现行规范呼应" | 归档考古的解读，无当事人文档 | H.2 |
| 9 | 旧资产兼容判定（"需改造""仅参考"） | 工程判断 | H.3 |
| 10 | G 节风险等级（低/中/高）与"B 线需补渲染层"的成本量级 | 基于代码阅读的判断，未做原型验证 | G |
| 11 | 性能"无压力/低-中风险"、微软雅黑"跨机器渲染不一致" | 无 profiling、无他机实测 | B.5/E.3 |
| 12 | "前期高频→后期低频"玩家行为曲线 | 回放台账间接支持，无真实玩家数据 | A.6 |
| 13 | J 节最小验证方案的完成标准与工作量预估 | 建议性内容 | J |

**使用规则建议**：K.1 需要拿到 daoyan 仓库（或其设计文档）后重新取证；K.2 必须由负责人逐条决策后回填为本报告的 I 节答案；K.3 在美术方向评审时只可作为假设提出，不得作为事实引用。
