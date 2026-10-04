# 回执：daoyan 侧摸底结果 + A–D 组回答

> 对应文档：[daoyan-reuse-plan.md](daoyan-reuse-plan.md)。
> 本回执基于 2026-10-04 对 daoyan 仓库（godot/ 全量、content/ 场景数据、Phase 87 文档）与
> rpgmap 仓库全部脚本的实读。E 组五接口已摸清，A–D 组给出带依据的推荐值。

---

## 0. 目标理解：确认，附两处基于 daoyan 实态的注记

五条目标全部确认成立。两点注记：

1. **「替代两条旧路线」要分清对象。** daoyan 现状里是**三套**地图形态并存：
   - **SceneStage 大图+热点**（要被替代）：`godot/scripts/app/scene_stage.gd`，AI 底图
     1536×1024 + 多边形可行走域 + AStarGrid2D + 热点圆判定 + 手动相机。六场景 manifest 在
     `content/factions/s_001/scenes/*.json`。
   - **狩猎图 64×64**（**不替代**）：`godot/scripts/engine/hunt/hunt_map.gd`，seed 确定性
     运行时生成 + 格子移动 + 预测-校正协议，承载登阶兽王**玩法**，有逐位对拍测试。它是战斗
     域，不是场景舞台，与 tile 化无关，保持现状。
   - **演出底图**（不涉及）：Phase 87 的修炼/突破/吐纳等全屏演出插画
     （`panels/performance_overlay.gd`），是过场演出不是地图。
   tile 内核替代的只有第一类。
2. **tile 城镇必须继承「热点=功能入口」角色。** daoyan 的场景热点不只是对话 NPC——它们是
   商店/差事榜/修炼/突破/整备等 15+ 个 `SceneCommand` 面板的**唯一入口**（分发中枢
   `app.gd _on_scene_command`）。新地图的交互点体系必须原样继承这一层，否则功能全断。
   这是提案 §0 没写、但落位时最重的一类交互点（见 C4 的 `menu` 型）。

---

## 1. E 组五接口摸底结果

### E1 场景管理与启动流程

- **零 autoload、零 [input] 段**。`godot/project.godot` 只有 application/display/gui/rendering
  四段；主场景 `res://scenes/app.tscn`（根 `App` Control + `scripts/app/app.gd`），其余
  **全部 UI 由代码构建**（15 个覆盖面板都是 `App` 的子 Control，靠 `visible` 切换，没有多场景切换）。
- **路由中枢**：`app.gd` 三个函数——`_on_store_changed()`（视图状态机：`actions.combat`
  非空→战斗屏独占，否则 SceneStage+侧栏）、`_on_scene_command()`（所有场景命令分发：
  `scene.enter.<id>` / `panel.*` / `shop.*` / `events.*` / `combat.drill`…）、
  `_load_current_scene()`。
- **SceneStage 挂接**：`_build_ui()` 里 `SceneStage.new()` 直接 add_child，唯一对外契约是
  `command_issued` 信号；行走是纯表现层零写请求，跨图只发 `scene.enter.<id>` 写请求。
- **分层纪律**：`scripts/engine/` = RefCounted 纯逻辑 + JSON 同构 + Python 对拍 oracle；
  `scripts/app/` = 表现层（panels/widgets/contracts/network）。新代码落位照此办理：
  地图规则/数据层进 `engine/maps/`，MapHost 表现层进 `app/`（作为 `SceneStage` 的兄弟节点，
  **不做 autoload**）。
- **相机**：SceneStage 无 Camera2D（手动 `_world.position` 缓动）；rpgmap 的 Camera2D+
  limit 方案是升级，可直接用。

### E2 对话/叙事系统 → **桥接，不替换**

- daoyan **没有**独立 DialogueUI。叙事的交互载体是 `app.gd _rebuild_pending()`（底部待决
  结算条，读引擎下发的 `actions.pending` + `actions.choices`，选项可用性/概率/代价全在引擎
  `HostViews.choice_views` 计算，UI 不复算）。
- rpgmap 的 DialogueUI（打字机+多页）是 daoyan 缺的能力，但它目前吃**静态 pages**；daoyan
  侧有状态/选项的对话必须过引擎（timeline、存档、choices 计算都在引擎侧）。
- **结论：桥接**。地图交互点 → `command_issued` → `_on_scene_command` → 引擎把事件塞进
  `pending/choices` → 待决条呈现。这条路**零新 UI 就能跑**。rpgmap DialogueUI 保留为纯展示
  组件作二步升级（数据源从静态 pages 换成引擎 pending 投影）。
- **提案需修正**：阶段 A「城镇=主题包含对话内容」要分层——地图源数据只放**纯氛围文本**
  （读告示牌）；凡有选项/改状态的交互一律走引擎（SceneCommand/事件卡），不得内嵌玩法对话，
  否则绕过叙事/存档体系。

### E3 战斗系统进入/退出接口

- **六个入口全部汇聚**到 `HostCombat.begin_combat(host, enemy_id, opts)` → `BattleRuntime`
  → 写 `academy.active_combat` 进快照。UI 侧**没有**专门的「发起战斗」API——切屏机制就是
  `app._on_store_changed` 检测 `store.actions.combat` 非空 → 显示懒建常驻的 `CombatScreen`
  （内嵌 `battlefield.tscn`，Node3D 3D 棋盘），同时隐藏 SceneStage/侧栏/覆盖层。
- **新地图触发战斗 = 只需让引擎产生 active_combat**：加一个 SessionStore 写方法 +
  `LocalEngineClient` 端点 + Host 静态函数（照抄 `begin_wild_combat` 的形），切屏自动发生。
- `begin_combat` opts：`enemy_id`（必填）+ 归属标记（`event_card_id`/`bounty_id`/`beast_id`/
  `wild_encounter_id`，互斥）+ `encounter_type` + `map_spec` + `followup_phases`（连战）+
  `test_battle`。**最小传参 = enemy_id + 一个归属标记**。
- **退出**：`CombatScreen.exited` 信号 → `app._on_combat_exited` → `_on_store_changed` 恢复
  主界面（SceneStage 重新 visible，不重建）。MapHost 接入 = 注册进同一个恢复分支。
- **结算**：`HostCombat.settle_combat` 按归属标记发奖/记伤/写 timeline，最后清
  `active_combat`。战后标记（已清怪）仿此记录。

### E4 存档/状态系统

- SQLite 两表（`meta`/`sessions`），**整个快照 JSON.stringify 整存**于 `snapshot` 列；
  引擎内存字典是唯一权威，**每个写端点成功后立即 `_persist` 落库**（写即存，无定时/手动存档）。
  `godot/scripts/engine/storage/save_store.gd` + `local_engine_client.gd`。
- **一次性状态先例丰富**：`game.flags`、`claimed_bounty_ids`、`duty_chain_rewarded`，以及最
  贴近的 `academy.hunt_maps[region].map_events`（**消费即从数组 erase** =「已开宝箱即消失」
  的现成模板）。
- **结论（C6）**：接存档成本≈0（快照加一个字段 + 消费时 erase），**直接接引擎存档，不做
  内存级**——内存级反而要写两遍切换逻辑。

### E5 输入 / UI 主题 / 分辨率 / 资产

- **输入**：daoyan 无任何自定义 action（WASD 实际不生效，移动靠内置 `ui_*` 方向键；Esc 是
  裸 keycode）。rpgmap 的 `move_up/down/left/right` + `interact`（WASD/E/空格/左键）**需要
  作为 [input] 段移植进 daoyan 的 project.godot**，命名可直接沿用。
- **分辨率**：daoyan 1280×720 viewport、stretch `canvas_items`+`expand`；rpgmap 逻辑
  640×360（window override 1280×720）、`keep`、nearest 过滤。两者**窗口一致、逻辑基线 2×
  关系**（详见 C2 答案）。
- **主题**：无 .theme 资源；Design Token 单一来源 `scripts/app/ui_theme_tokens.gd`
  （Phase 87 UI 2.0），纪律是「新 UI 一律引用本表」。MapHost 的 UI（对话框/交互提示）应吃
  这套 token。
- **玩家资产**：daoyan 已有四向行走化身（`assets/avatar_placeholder.png`，240×450=4帧×3行，
  AtlasTexture 切帧）+ 源图 `walkassets.png` 与抠帧脚本 `scripts/build_avatar_sheet.py`；
  rpgmap 是 `player.png` 32×48×4向 SpriteFrames。两套并存，美术回填按 manifest 出即可。
- **贴图过滤**：daoyan 未设 `default_texture_filter=0`（插画风格不需要）；tile 层需逐资产设
  nearest 导入，勿全局改（避免影响现有 UI）。

---

## 2. A 组回答

- **A1 宿主方向：按推荐——移植进 daoyan/godot**，rpgmap 保留为玩法沙盒。理由：
  daoyan 是权威游戏进程（Phase 84 终态），且分层纪律/存档/战斗/内容校验全部现成。落位：
  - 规则/数据层 `scripts/engine/maps/`（RefCounted 纯函数 + JSON 同构，校验进 bake）；
  - 表现层 `scripts/app/` MapHost（App 子节点，与 SceneStage 并列，可共存）；
  - bake 工具进 `scripts/`（与 `build_avatar_sheet.py`/`build_hunt_tiles.py` 同族）；
  - 地图源数据进 `content/factions/<f>/maps/` 或 `content/common/maps/`，走
    `content_loader` + release 校验。
- **A2 旧方案去留：新旧并存逐步迁，不立即全量替换。**
  - 依据：Phase 83 六场景舞台与 Phase 87 演出底图是**受保护基座**（AGENTS.md 保护条款）；
    Phase 87 尚在实测迭代（S5 未收口），且其 §4 范围外条款**明确写「新地图归 P88+」**。
  - 第一批：只做一张**新增场景**（新 scene_id 并存，不动旧六场景）跑垂直切片；验收后逐场景
    迁移。狩猎图与演出底图**不迁**。
  - **本工作流应立项为 Phase 88**，待 Phase 87 收口后启动，不插队。
- **A3 命名：机制上确认零成本**——scene_id/label 全在场景 manifest 数据里；「西西弗百货」
  只存在于 rpgmap 仓库（`MapData.MAPS` 与 project.godot 的 config/name），不会被带进 daoyan。
  正式设定名是设计决定，留给用户拍板（现命名「道演」，s_001 为青岩寨主题）。

## 3. B 组回答

- **B1 编辑界面：按推荐——ASCII 先行。** 一处修正：rpgmap 的源数据是 **GDScript 常量**
  （`MapData.MAPS`）；进 daoyan 后唯一事实源应改为 **JSON 文件进 content/**
  （ASCII 布局仍是字符串数组内嵌在 JSON 里）。理由：贴合内容包合同与校验管线、Python 工具
  链可读可对拍、美术/策划改图不碰代码。`字符→图块` 映射表 = 提案的「主题包」，同样 JSON 化。
- **B2 烘焙产物：.tscn 可行，但推荐一个变体——烘焙产物 = 校验后的规范化 JSON + manifest
  进 git**，运行时 MapHost 轻量构建（`TileMapLayer.set_cell` 批量铺设，一图几千格毫秒级）。
  理由：贴合 daoyan 的 content JSON 流与热替换贴图读取方式（faction-assets 文件路径，非
  res://）；.tscn 文本 diff 噪声大、且会把贴图绑进 res:// 导出链。提案的四阶段结构不变，
  「生成一次、永不重算、可 diff」的性质完全保留。若坚持 .tscn（编辑器可直观打开查看），
  把 tileset 贴图放 `godot/assets/maps/` 即可，不拦。
- **B3 城镇结构：按推荐——先延续大图+门传送，边缘走出切换后续作为 portal 特例。**
  rpgmap 的 `TRANSITIONS` 双向表 + 出生格内侧 + 防回弹冷却已验证；daoyan 侧
  `enter_scene` / `location_scene_id` 是既有单写点（`host_hunt.gd`），门= `scene.enter.<id>`
  的触发格版本，顺接。单镇规模建议 **3–5 张功能图**（hub 广场/坊市/修炼堂/演武场/差事榜），
  与现有六场景语义对齐，便于逐图平迁。

## 4. C 组回答

- **C1 第一垂直切片：城镇功能图，不先做野外。** 建议切 **s_001 寨内 hub 的 tile 版**
  （新 scene_id 并存）。理由：一张图同时验证 Y-sort、交互、对话桥接、门户、面板命令全链；
  battle_trigger 只是其中一种交互点，同图放一个占位触发格（接一个固定 enemy_id 或
  `combat.drill`）即可验证战斗往返，不必单独先开野外图。
- **C2 规格：tile 32×32 维持；视口不冲突。** daoyan 1280×720 基线不动，MapHost 世界容器按
  **2× 整数缩放**呈现（逻辑相机视野 640×360 ≈ 20×11 格/屏，与 rpgmap 视觉密度一致；做法同
  SceneStage 既有的 `_apply_scale` 世界缩放思路）。UI 层（对话框/面板）仍走 1280×720 +
  UIThemeTokens。像素图导入逐资产设 nearest。
- **C3 地形清单（第一张图，直边无 autotile，按推荐）**：石板广场 / 夯土路 / 草地 / 夯土墙
  （碰撞）/ 木墙（碰撞）/ 水沟（碰撞）/ 门洞（传送）。后续若上 autotile，可复用狩猎图位掩码
  图集管线经验（`build_hunt_tiles.py`：16 形状位掩码×材质×高度档 + hash 选变体），47 变体
  blob 的美术量级问题届时再裁。
- **C4 交互点类型（第一批六种，一句话行为）**：
  | 类型 | 行为 |
  |---|---|
  | `portal` | 走进触发格 → `scene.enter.<id>`，双向传送表声明，出生格在门内+冷却防回弹 |
  | `menu` | 靠近/走进 → 弹既有热点菜单（SceneCommand 列表），复用 `_on_scene_command` 全部分发（商店/差事榜/修炼/突破…）——**城镇功能入口的主形态** |
  | `dialogue` | 靠近按 E → 纯氛围多页文本，不改任何状态 |
  | `battle_trigger` | 走进明雷标记格 → 引擎 `begin_combat(enemy_id)`，战后返回原地（详见 D2） |
  | `chest` | 按 E → 引擎结算奖励并记录 consumed id，永久消失（存档先例 `map_events` erase） |
  | `save` | 暂不做（daoyan 写即存，无手动存档概念；留位） |
- **C5 美术工序：扩工具，是；但落 daoyan 侧。** 把切图+QC 扩成 `scripts/` 下与
  `build_avatar_sheet.py`/`build_hunt_tiles.py` 同族的工具（按 assets-spec.md 规格：alpha
  二值、尺寸精确、色板≤16、脚底对齐），QC 结果用截图核对（rpgmap 已有 `--shots` 模式可搬）。
  由工具侧（AI）做，人只看截图验收。
- **C6 持久化：直接接 daoyan 存档，不做内存级。** 快照加 `consumed_interaction_ids`（或
  复用 `game.flags`），消费时 erase/置位 → 既有「写即存」自动落 SQLite。「切图不丢、重开
  不重置」一步到位，不用做两遍。

## 5. D 组回答

- **D1 触发形态：可见标记 + 走进触发，默认可重复带冷却（内容可声明一次性）。**
  依据：狩猎图事件格「?」标记 + 走进结算已是玩家习惯（`hunt_map_panel`），纯隐形区域触发
  会「莫名开战」。标记表现先复用提示气泡/地格高亮。
- **D2 战斗接口**：
  - **进**：`enemy_id` + 归属标记。建议新增 `map_encounter_id`（语义同 `wild_encounter_id`：
    结算归属/幂等入栏），或短期复用事件卡 `event_card_id` 路线。`encounter_type` 默认
    encounter，`map_spec` 可选。
  - **回**：战斗结束 `CombatScreen.exited` → 恢复分支里加 MapHost visible（与 SceneStage 同
    模式）；玩家位置/状态在进战前已随快照保存（地图状态进 `academy`，仿 `hunt_maps` 的
    per-map 字典），战后原地恢复。
  - **战后标记**：引擎侧记 encounter 已清/冷却，重复触发由内容声明。
- **D3 野外规格：与城镇共用 tile 规格 + bake 流水线，独立野外主题包**（tile 子集、调色板
  不同）。规模 40×30～64×40 屏级滚动 + 门连回城镇。**边界**：daoyan 已有 64×64 狩猎图承载
  登阶兽王玩法，野外触发图只做「明雷遭遇探索」，两套并存不合并（AGENTS.md 对狩猎图有保护
  条款与对拍纪律）。

## 6. 修订后的下一步顺序

1. 用户对 A1–A3、B1–B3 拍板（本回执已给推荐，可直接「按推荐」）；
2. 待 Phase 87 S5 收口 → **立项 Phase 88**，本回执并入计划文档；
3. 工作流骨架：bake（校验+JSON+manifest）+ MapHost + 第一张切片图端到端，再谈量产；
4. E 组五接口已全部摸清（本文档 §1），移植设计文档可直接开写。
