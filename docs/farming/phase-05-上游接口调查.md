# Phase 05（前置）— 上游 daoyan 仓库接口只读调查

> **上游：** [master-plan.md](master-plan.md)；daoyan 仓库 `C:\Users\88445\Desktop\code\daoyan`
> **状态：** **调查完成（2026-10-09），待用户评审**。本文只核实与整理接口，不含任何实现决策。
> **性质：** Phase 5 的源码依据文档。所有结论来自 `main@2a0cc36` 工作区源码，未修改上游任何文件。
> **待决策项：** 见 §7（按天扣饱食度、种植成本→喂养/收益公式等，上游均无既定事实）。

---

## 1. 调查基线

| 项 | 值 |
|---|---|
| 上游仓库绝对路径 | `C:\Users\88445\Desktop\code\daoyan` |
| 分支 | `main` |
| HEAD | `2a0cc360a0a2c85685d8f0bbad30b5d4e83539d4`（`2a0cc36` "feat: Phase 87 蛊虫管理页与详情 UI 2.0…"） |
| 工作区状态 | 干净（无未提交改动） |
| 适用 AGENTS.md | 仅仓库根 `AGENTS.md`（子目录无） |

AGENTS.md 关键裁决（影响本调查的取信顺序）：

- **Phase 84 起 Godot 是权威引擎**：`godot/scripts/engine/**` 为当前运行代码；`src/daoyan/**`（Python）仅为对拍 oracle 与开发期工具链。本文以 Godot 侧为准，Python 侧只用于交叉印证。
- **Phase 86 已关闭**：统一物品目录（只读估值索引）、存档 SQLite 化、以物换物、代步蛊已落地。
- **"不使用枚举"裁决**：统一目录与新 schema 全原生类型，取值约束落内容校验层。

---

## 2. 核心结论表

| 调查项 | 实际行为/数值 | 文件路径:行号 | 类/函数/配置键 | 下游影响 |
|---|---|---|---|---|
| **元石内部 ID** | 资源计数器键 `resources["primeval_stones"]`，非物品目录条目；int；界面单位"枚"，蛊材单位"份" | `godot/scripts/engine/academy/host_state_defaults.gd:44-48`；`src/daoyan/models.py:765-771` | `GameState.resources: dict[str,int]` | 下游"元石"若要对齐语义，就是一个非负 int 计数器，不是物品 |
| **元石初始值** | **不是固定值**：新档 = 出身 `starting_resources.primeval_stones` + 学堂月例 `stipend_primeval_stones`。s_001：出身 1/2/3/4（随 seed 随机四选一）+ 月例 60 ⇒ **61~64** | `godot/scripts/engine/academy/host.gd:130-140`（`_starting_resources`）；`src/daoyan/academy.py:856-859`（Python 同构）；`content/factions/s_001/origins.json:6,19,32,45`；`content/factions/s_001/academy.json:9` | `Host.create` → `_starting_resources`；配置键 `origins[].starting_resources`、`academy.stipend_primeval_stones` | pydantic/GDScript 默认表里的 `10`（`host_state_defaults.gd:45`）只是 schema 回退，`create()` 恒显式传 resources，**新档实际拿不到 10**。下游不要引用 10 作"上游初始值" |
| **元石初始是否随角色/难度变** | 随"出身"（origin，seed 随机）与势力包配置（月例）变；无难度系统 | 同上 | — | 下游若要"与上游语义一致"的初始元石，需自定义出身/月例结构，或直接采用固定值并声明为下游自定 |
| **元石查询/增减** | 无统一钱包服务。查询=直读 `snapshot.game.resources.primeval_stones`；增减=各业务函数直接写 dict。事件奖励走 `plan_effects`，**正向元石 × REWARD_STONE_SCALE**（1~5 转 = 6/8/10/14/18），负向与直改不放大；钳制 `maxi(0,…)` 永不为负 | `godot/scripts/engine/rules/effects.gd:10,56-62`；各交易函数（见 §5） | `REWARD_STONE_SCALE`；`ResourceEffect(target="primeval_stones")` | 下游买卖若复用"事件效果"通道会被放大倍率影响；自建买卖直接写计数器即可 |
| **钱包归属** | 每会话单钱包，挂在 `GameState.resources`（角色级，非账号/非多角色） | `host_state.gd:30-48` | `GameState` | 下游单角色存档同构即可 |
| **背包数据结构** | **上游没有通用背包**。玩家持有 = ①`resources`（primeval_stones/gu_materials/information 三个 int 计数器）②`special_materials: dict[str,int]`（具名特殊蛊材）③`gu_items: Array[Dictionary]`（蛊虫实例，含动态合炼产物）④`material_gu_items`（素材蛊） | `host_state_defaults.gd:44-52`；`faction_models.py:772-775` | `GameState` 字段 | 下游 Phase 5 的"库存"需自行定义；上游可参考的是 `special_materials` 的 dict 计数形态 |
| **堆叠/容量** | 计数器无上限；特殊材无上限；蛊实例无数量上限（"空窍 thoughts"限制的是同时上阵蛊，不是持有）。仅"负载"概念：三类资源总和，基础 250，超载每 150 增加自行旅行 1 行动 | `godot/scripts/engine/academy/host_storage.gd:14-17`（`BASE_CARRY_CAPACITY:=250`、`OVERLOAD_STEP:=150`） | `carry_load`/`carry_summary` | 下游背包若要上限需自定；上游没有"背包满"失败路径 |
| **物品目录（Phase 86）** | `item_catalog` 为**只读内存估值索引**（不存玩家持有、不进快照）：键 `item_id`，值含 kind(gu/material)、role、base_price、origin_location、rarity、rank；价格归一链 base_price > primeval_price > shop_price_primeval_stones > trade_price_primeval_stones | `godot/scripts/engine/gu/item_catalog.gd:9-14,17-44,98-104` | `ItemCatalog.build` / `base_price_of` | 下游若做"出售估值"，此文件的归一链+目录形态可直接借鉴 |
| **五行编码** | **`path_id`（自由小写字符串，非枚举）**。当前内容五值：`earth` / `wood` / `gold` / `water` / `fire`。**金是 `gold` 不是 `metal`**（文件名/函数名用 metal，数据用 gold）。四新流派 Tag family = `{wood, gold, water, fire}`（earth 为主流隐含） | `faction_models.py:3987`（`path_id: str Field(pattern=...)`）、`:1270`（`DAO_TAG_FAMILIES`）；`content/gu/s_001.json`（132 earth / 8 fire / 7 gold / 8 water / 8 wood） | `GuDefinition.path_id` | 下游"木"= `"wood"`。若对齐上游取值，金写 `gold` |
| **五行归属层级** | 蛊模板 `GuDefinition.path_id`（单值）+ `tags.affinity`（数组，**不统一**：土系写 `"stone"`、木系写 `"wood"`）；材料模板 `GuMaterialDefinition.path_ids`（**集合**，如 `["beast","earth"]`、`["fire"]`）；蛊实例快照带 `path_id`。物品目录条目**无五行字段** | `faction_models.py:4166`（材料 path_ids）；`content/gu/s_001.json:6721,6727-6734`；`item_catalog.gd:62-71` | — | 下游判"食材五行资格"若读上游数据，材料用 `path_ids` 集合、蛊用 `path_id`；`tags.affinity` 不可靠 |
| **种子/食材/材料分类** | **不存在种子、食材类目**。物品分三类：gu（蛊）、material（特殊蛊材）、通用资源计数器。材料无喂养值/营养值/消耗数量字段 | `faction_models.py:4159-4183`（GuMaterialDefinition 全字段：material_id/name/description/rarity/path_ids/acquisition_channels/intelligence_shop_cost/merit_shop_cost/base_price/tags/source_ids/review_status） | — | 下游"种子/收获材料/食材资格"全部是**新增概念**，上游无对应字段可复用 |
| **饱食度模型（重点）** | **上游没有 0-4 数值饱食度**。实际是"使用计数 + 三态"：新蛊 `uses_since_feed=0, feeding_state="fed"`；每次成功催动 `uses_since_feed+1`，达到模板 `feeding_interval`（2~8，**模型默认 4**，s_001 主流显式 4）→ `hungry` 且 `starvation_actions_left=3`；每次玩家行动后 hungry 蛊倒计时 -1，归 0 → **`dead`（蛊真死）**；`feed_gu` 仅 hungry 可喂，消耗 `feeding_cost_gu_materials` 份通用蛊材（1~5）+ 可选 `feeding_cost_primeval_stones` 元石（0/2/4/6），喂后 `uses_since_feed=0` 恢复 fed | `host_actions.gd:894-904`（`record_gu_use`）、`:337-368`（`tick_starvation`）、`host_sustain.gd:26-82`（`feed_gu`）、`:907-946`（`add_gu_item` 实例字段）、`faction_models.py:3993-3994,4027` | `GuItem.uses_since_feed / feeding_state / starvation_actions_left / feeding_interval / feeding_cost_*` | 见 §2.1 逐条对照 |
| **交易/喂养是否耗行动点、每日限次** | **均不耗行动点、无每日限次**。`feed_gu`/`sell_gu`/`buy_caravan_gu`/`exchange_with_caravan`/`barter_with_caravan` 均不调 `after_action`。限次仅：商队兑换每资源每次到访 9 单位、商队蛊每次到访每只售一只、情报店辅助蛊每阶段一只 | `host_sustain.gd:26-82`；`host_caravan.gd:387-401,427-428`；`content/common/manifest.json:7-13` | — | 与下游 Phase 5 需求"交易和喂养不消耗行动点、不限制每日次数"一致，可放心声明为上游语义 |
| **存档位置** | 钱包/背包/蛊虫全部在整快照 JSON 内：`user://sessions/daoyan.sqlite3` 单库单表 `sessions`，快照存 `snapshot` TEXT 列（JSON.stringify），meta.schema_version="1"；引擎内存字典为权威，落库在 app 层 | `godot/scripts/engine/storage/save_store.gd:9-27,71-100,103-112`；`local_engine_client.gd:139-142`（`_persist`） | `SaveStore.save_session / load_snapshot` | 依赖 godot-sqlite GDExtension 插件（`godot/addons/godot-sqlite/`） |

### 2.1 用户描述的上游饱食度现状逐条核实

| 用户描述 | 源码事实 | 结论 |
|---|---|---|
| "默认饱食度为 4" | 对应 `GuDefinition.feeding_interval` 默认 4（`faction_models.py:3993`），s_001 大多数蛊显式 4（也有 5/6/7/8）。新蛊实例"剩余可用次数"= interval | **部分相符**：4 是模板字段常见值，不是全局常量；每蛊可不同 |
| "蛊虫使用后降低 1 点" | `record_gu_use` 使 `uses_since_feed +1`（等价于剩余 -1），仅在成功催动时计数（判定细节见 §5.1） | **相符**（方向相反的同一计数） |
| "只有饱食度为 0 时才能喂养" | `feed_gu` 要求 `feeding_state == "hungry"`（即计数用尽）；fed 状态喂养报"该蛊虫当前无需喂养" | **相符** |
| "喂养后恢复到 4 点" | 喂后 `uses_since_feed=0`（恢复到该蛊模板 interval） | **相符**（恢复到模板值而非硬编码 4） |
| "上游原先没有按天降低饱食度的机制" | 无按天/实时衰减（搜索范围见 §6）；但存在**按行动的饿死倒计时**：hungry 后每次玩家行动 `starvation_actions_left` -1（初值 3），归 0 蛊死亡（`host_actions.gd:337-368`，UI 显示"饥饿 · N 行动后死亡"） | **基本相符，但有重要补充**：不喂不只是"卡住"，会死。下游若引入"0 点可喂"，需决定是否也引入死亡惩罚 |

**另外三处用户未提但会影响下游设计的差异**：

1. **hungry 蛊仍可使用**：战斗上阵与事件选择只排除 `dead`（`host_battle_adapter.gd:225`、`host_choose.gd:454`）；仅"练习"要求 fed（`host_actions.gd:159`）。即上游"饱食度 0"≠ 禁止使用。
2. **喂养有真实成本**：通用蛊材计数器 + 部分蛊还要元石；**与五行/具体食材无关**——上游喂养不存在"食材五行匹配"。
3. **喂养数量差异**：上游不同蛊吃不同份数（1~5 份蛊材），不是"不同食材恢复不同量"。

---

## 3. 接口表

调用入口均为引擎静态/成员函数（组合式收 host）；app 层入口为 `godot/scripts/app/network/local_engine_client.gd` 同名方法。host 是持有 `snapshot`（Dictionary）与 `content` 的对象，`host.error` 为错误通道（非异常）。

| 用途 | 调用入口 | 参数 | 返回值 | 副作用 | 失败处理 | 依赖 |
|---|---|---|---|---|---|---|
| 创建会话（钱包+背包初始化） | `Host.create(content, seed, player_name, faction_id, seven_aptitudes)` | seed:int、名字、势力 id、七元赋性（总和必须 10） | host 或 null | 建快照、播种事件板/赐蛊 | 参数非法返回 null（push_error） | HostContent、HostState |
| 查询元石 | 直读 `host.snapshot["game"]["resources"]["primeval_stones"]` | — | int | 无 | — | — |
| 喂养蛊虫 | `HostSustain.feed_gu(host, reference)` | instance_id 或 gu_id（饥饿优先解析） | 快照 dict 或 `{"error": msg}` | 扣蛊材/元石、置 fed、写 timeline、save | 状态/余额不满足返回 error，**不改动任何状态** | HostActions |
| 查询蛊实例 | `HostActions.gu_item(host, reference)` | instance_id/gu_id | 实例 dict 或 null | 无 | null | — |
| 添加蛊实例 | `HostActions.add_gu_item(host, gu_id, opts)` | gu_id；opts: `purchase_price_primeval_stones`、`is_vital` | 实例 dict 或 null | push 入 `gu_items`、刷新 combat_coverage | 未知定义 null（host.error） | GuAttributes、HostState |
| 记录一次催动（饱食计数） | `HostActions.record_gu_use(host, gu_id)` | gu_id | void | 计数+1、可能转 hungry | 非 fed 状态：设 host.error 且**不计数** | — |
| 行动后结算（饿死计时在此） | `HostActions.after_action(host, opts)` | opts: skip 列表/recover/tick_breakthrough | void | 行动数+1、商队/榜单/伤口/冷却/饥饿推进 | — | 多模块 |
| 卖蛊（→元石） | `HostShops.sell_gu(host, reference)` | instance_id/gu_id | 快照或 error | 移除实例、加元石、timeline、save | 无可卖蛊返回 error | Economy |
| 商队买蛊（元石→蛊） | `HostCaravan.buy_caravan_gu(host, gu_id)` | gu_id | 快照或 error | 扣元石、加入实例（记购入价）、记已购、save | 货单外/修为不足/已售/元石不足返回 error | ItemCatalog |
| 资源换元石 | `HostCaravan.exchange_with_caravan(host, resource, batches)` | information/gu_materials、1~3 批 | 快照或 error | 扣资源加元石、记额度、save | 额度/余额不足返回 error | trade_rules |
| 以物换物 | `HostCaravan.barter_with_caravan(host, body)` | body: give_gu_instance_ids[]、give_material_ids{}、get_gu_ids[]、get_material_ids{}（材料 1~20 份） | 快照或 error | 移除给出→加入换入→元石 ±delta、timeline、save | 全部前置校验不过返回 error，零变更 | ItemCatalog、HostActions |
| 行情价 | `HostCaravan.market_price(host, caravan, item_id)` | item_id | int（≥1；不在目录返回 -1 并设 error） | 无 | — | item_catalog |
| 定价纯函数 | `Economy.family_shop_price(def)` / `market_price(def)` / `sell_value(purchase, market)` | 定义 dict | int | 无 | — | 无（可独立迁移） |
| 存/读档 | `SaveStore.save_session(snapshot)` / `load_snapshot(session_id)` | 快照 dict / session_id | bool / dict或null | 写 SQLite 行（save_seq 自增） | 打不开库 false；损坏档 null | godot-sqlite |
| 演练（测试战斗） | `HostRoster.start_combat_test(host, scenario_id)` | open_field/shiwandashan/chilushan | 快照或 error | 无消耗无掉落开战（is_test_battle 复原基线） | 未上阵/有战斗返回 error | HostCombat |

**简短调用示例**（GDScript，语义示意）：

```gdscript
# 买→喂→卖 循环的引擎面（省略 host 获取）
var snap = HostCaravan.buy_caravan_gu(host, "wood_seed_gu")   # 扣元石，实例记购入价
# …使用若干次后 feeding_state 变 "hungry"…
snap = HostSustain.feed_gu(host, instance_id)                 # 扣 feeding_cost_gu_materials 份蛊材（+可选元石）
snap = HostShops.sell_gu(host, instance_id)                   # 按购入价原价回收为元石

# 材料计数（下游"收获材料"若对齐上游形态）
game.special_materials["my_wood_harvest"] = int(game.special_materials.get("my_wood_harvest", 0)) + 3
```

---

## 4. 最小迁移清单

上游引擎为"组合式收 host"的大单体（`host_actions.gd` 约 1200 行，preload 六个模块 + 战斗域懒加载），**逐文件整体迁移成本高**。分三层：

### 4.1 必需迁移（下游要复用语义时的核心）

| 文件 | 用途 | 直接依赖 | 绑定场景/UI |
|---|---|---|---|
| `godot/scripts/engine/academy/host_state.gd` + `host_state_defaults.gd` | 状态模型与默认表（含 resources/gu_items 字段形状） | 无（纯字典工具） | 否 |
| `godot/scripts/engine/rules/economy.gd` | 定价/回收纯函数（family_shop_price/market_value/sell_value） | 无 | 否 |
| `godot/scripts/engine/gu/item_catalog.gd` | 物品目录构建 + base_price 归一链 | 无 | 否 |
| `godot/scripts/engine/storage/save_store.gd` | SQLite 整快照存档 | **godot-sqlite GDExtension**（`godot/addons/godot-sqlite/`，含 bin/） | 否 |

### 4.2 可留在上游并适配（引用其字段语义与流程，不建议整文件搬）

| 文件 | 用途 | 直接依赖 | 绑定场景/UI |
|---|---|---|---|
| `academy/host_sustain.gd`（feed_gu） | 喂养全流程 | HostActions、GuFielding、懒加载 battle adapter | 否（引擎层） |
| `academy/host_caravan.gd`（barter/buy/exchange） | 交易全流程与行情价 | ItemCatalog、Hunting、HostActions | 否 |
| `academy/host_shops.gd`（sell_gu/换购） | 卖蛊与双币换购 | HostActions、HostViews、Economy | 否 |
| `academy/host_actions.gd`（add_gu_item/record_gu_use/tick_starvation/after_action） | 蛊实例工厂与饱食计数 | PyRandom、Resolver（战斗）、Advancement、Checks、Hunting、GuAttributes、HostState | 否，但依赖面大，建议**抄语义自建精简版** |
| `engine/content_loader.gd` | 内容包装载（gu_sources/defaults/校验镜像） | 文件系统 + 生成 schema | 否 |

### 4.3 仅作参考

| 文件 | 用途 | 说明 |
|---|---|---|
| `src/daoyan/academy.py`、`src/daoyan/models.py`、`faction_models.py` | Python 对拍 oracle 与权威 pydantic 模型 | 字段约束/默认值的**权威文档源**（如 feeding_interval 默认 4、path_id 正则），但 Python 运行时已退役 |
| `godot/scripts/app/panels/*`（gu_detail_dialog、caravan_panel、exchange_shop_panel 等） | UI 消费示例 | 展示 feeding_state 徽标（"饥饿 · N 行动后死亡"）、换物表单如何调引擎 |
| `godot/tests/test_engine_storage.gd`、`test_engine_barter.gd` | 引擎行为测试 | 迁移后对拍的行为基准 |

**注意**：上游没有可独立搬走的"背包模块"——库存逻辑内嵌在各业务函数里。下游背包需自建，形态建议参考 `special_materials: dict[str,int]` + `gu_items` 实例列表的双轨制。

---

## 5. 交易与喂养流程

### 5.1 喂养 `feed_gu`（host_sustain.gd:26-82）

**成功路径（顺序执行）**：
① status==active 且无 pending 事件 →
② 解析目标实例（instance_id 优先；gu_id 时**饥饿者优先**）→
③ 校验状态：dead 拒、非 hungry 拒（"该蛊虫当前无需喂养"）→
④ 校验通用蛊材 ≥ `feeding_cost_gu_materials` →
⑤ 校验元石 ≥ `feeding_cost_primeval_stones` →
⑥ **先扣蛊材、再扣元石** →
⑦ `uses_since_feed=0`、`fed`、`starvation_actions_left=0` →
⑧ 写 timeline（kind="feeding"，changes 记负值）→
⑨ save。

**失败路径**：全部前置校验拦截，**任何失败都发生在变更之前，无部分扣除**。重复喂养被③天然拦截。

**"使用成功"的准确判定**（饱食计数何时 +1）——三个调用点，`record_gu_use` 均在**验证与扣费之后**调用：

1. **练习** `host_actions.gd:155-194`：fed 状态、无冷却/休养、真元足够并已扣 → 计数。任何失败提前 return，**不计数**。
2. **战斗结算** `host_combat.gd:243-249`：战斗结束（victory/defeat/**fled 均算**）对 `used_this_battle` 中每蛊**一次性 +1**（源码注释："每只用过蛊一次性 +1"）。
3. **事件选择** `host_choose.gd:310-330`：真元/蛊材已扣、判定掷骰**无论成败**都计数（`succeeded` 只影响奖励）。

**边界**：`record_gu_use` 自身对非 fed 状态设 host.error 并跳过计数（`host_actions.gd:898-900`）。事件路径的前置校验只排除 dead（`host_choose.gd:454`），因此 **hungry 蛊可用于事件且该次使用不再推进计数**（费用照扣）——这是上游一个已知的行为边界，不是回滚缺失。

### 5.2 交易（以最复杂的 `barter_with_caravan` 为例，host_caravan.gd:491-601）

**成功路径**：
① 全量前置校验（给出蛊须存在/非本命/非 dead；材料 1~20 份且库存足且在目录；换入蛊在货单、未售出、修为够、**不得重复**；材料在货单）→
② 双向按 `market_price` 估值 →
③ 差额为负时校验元石余额 →
④ **结算：移除给出蛊 → 扣给出材料 → 加入换入蛊（记购入价=行情价）→ 加换入材料 → `primeval_stones += delta`** →
⑤ timeline（kind="barter"）→
⑥ save。

**失败路径**：①~③ 任一不过即返回 error，**零状态变更**。

`buy_caravan_gu`（:406-437）与 `sell_gu`（host_shops.gd:442-474）同构：先验后改、单点结算。
`exchange_with_caravan`（:375-403）：3 资源 : 1 元石/批，每次到访每资源上限 9 单位（`trade_rules`）。

### 5.3 实际风险评估

- **部分扣除**：未发现。所有交易都是"全校验 → 顺序变更"，变更步骤（dict 写/数组 erase）不会失败。
- **重复扣除/连点**：引擎无请求去重，靠**状态幂等护栏**——商队蛊 `caravan_purchased_gu_ids` 每次到访每只一只；喂后 fed 再喂被拒；换入蛊查重。连点第二次会得到业务错误而非重复扣款。
- **回滚缺失**：唯一风险点是引擎写完内存态后若 app 层 `_persist` 失败（磁盘问题）会丢当次变更（下次读档回退），引擎层无重试/事务补偿——SQLite 层是整快照 REPLACE，本身原子。
- `market_price` 掷点输入不含交易次数（`host_caravan.gd:452-471` 注释明确"重开交易不重掷"），同次到访价格固定，防刷价。

---

## 6. 未找到项（含搜索范围声明）

以下均在列明范围内搜索且**未找到**：

| 未找到项 | 搜索范围 | 说明 |
|---|---|---|
| 数值型饱食度（0-4）字段 | `rg "satiety|hunger|fullness"` 于 `godot/scripts` 与 `src/daoyan` | 唯一近似是 `uses_since_feed`/`feeding_state`/`starvation_actions_left` 三字段 |
| 按天/实时降低饱食度的机制 | `rg "每日|daily|per_day|day_"` 于 `godot/scripts` 与 `src/daoyan` | 唯一时间性衰减是 hungry 后按**行动**递减的 `starvation_actions_left`（`host_actions.gd:337-368`，经 `after_action` 触发） |
| 食材五行匹配 / 食材资格判定 | `feed_gu` 全函数体（`host_sustain.gd:26-82`）+ Python 同构（`academy.py:1526-1571`） | 只读通用计数器与元石，无任何 path/element 分支 |
| 喂养恢复量按食材差异化 / 营养值 / 食材配方 | `GuMaterialDefinition` 全字段（`faction_models.py:4159-4183`） | 无此类字段 |
| 种子类目 / 种植物 | `content/` 全量（gu_materials.json、gu/*.json 等） | `wood_seed_gu` 是一只蛊名"播木蛊"，不是种子物品 |
| 统一交易服务 | `godot/scripts/engine` 全域 | 四个独立店面 + 以物换物各自实现校验与结算，无共享 TradeService |
| Godot 引擎侧"学堂/家族元石买蛊" | `godot/scripts`（engine + app）全域 `rg "buy_gu|family_shop"` | 引擎与 app 层均无 `buy_gu` 命令；仅存在于已退役的 Python HTTP 侧（`src/daoyan/academy.py:1620-1650`）。当前 Godot 玩家获得蛊的途径：免费赐蛊/免费商店、情报店、功绩店、商队购买/换物、事件、捕获。**下游"买种子"若引用上游买蛊语义，应引用 `buy_caravan_gu` 或 Python `buy_gu` 的流程形状，并注明后者非当前运行代码** |
| 资源价值↔营养/喂养数量换算规则 | 价格相关全域（economy/effects/item_catalog/content） | 仅有价格链，无任何"成本→喂养收益"公式 |

---

## 7. 待决策项（上游无既定事实，需用户裁决）

1. **是否新增"按天扣饱食度"**：上游无此机制（且上游无"天"，时间单位是行动）。若引入，需同时决定：hungry 后是否保留上游的 3 行动饿死惩罚，还是改为下游自己的软惩罚。
2. **"种植消耗"定义与"食材收益挂钩"公式**：消耗指货币（种子买价）、行动点、生长时间还是综合成本，上游均无对应换算规则；固定恢复 4 点时食材差异是否用"喂养份数"表达（上游按**蛊**的 `feeding_cost_gu_materials` 1~5 份差异化，可作形态参考，但不是食材差异），均待用户裁决。**本文不自行制定平衡公式。**
3. **下游"元石初始值"**：上游 s_001 实际为 61~64（出身 1~4 + 月例 60，随 seed 随机），是否采用需用户定（若采用出身+月例结构则随配置变）。

### 可直接复用的平衡数据 vs 不存在

- **可直接复用**：蛊材基准价带（特殊材 base_price 30~40）；商队兑换比 3 资源:1 元石（每次到访每资源上限 9 单位）；行情公式（±10% 浮动 + 产地 ±5%）；family 折价率表（common/rare 按转 0.25~0.65，premium 原价）；`sell_value` 原价回收语义（有购入价按购入价、无则按市场估值）；喂养成本分布（1~5 份蛊材 + 0/2/4/6 元石）。
- **不存在**：种子价格、收获物价格、营养值、食材配方、种植行动成本——全部需下游自定。

---

*本文全部结论来自 daoyan `main@2a0cc36` 工作区源码（2026-10-09 调查）；未修改上游任何文件、未切换分支。*
