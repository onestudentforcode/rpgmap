# Phase 02 — 核心种植系统

> **上游：** [master-plan.md](master-plan.md) §五（v1.1 修订后）+ [phase-01](phase-01-地形与土地系统.md)
> 已冻结基线（LandGrid 状态机/占用 API/增量渲染/数据烘焙纪律/素材替换契约）。
> **状态：** **已完成（2026-10-08 关闭，验收见 §10/§11）**
> **边界：** 最小可玩种植闭环——时间 + 播种 + 生长 + 采收（含有限次再生与枯竭清理）
> + 多素材产出 + 库存 + 存档。养殖/加工/市场/蛊虫联动属 Phase 5；四类作物扩展属 Phase 4
> （本阶段两种测试作物即 herb + shrub，天然预演）。
> **出阶段条件：** §10 验收清单全部勾选。✅ 已满足

---

## 1. 任务总览

| # | 任务 | 产出 | 状态 |
|---|------|------|------|
| 2.1 | 作物数据模型 | `content/farming/crops.json`（v1.1 字段：harvest_items / max_harvests） | **✅ 完成（@6ff9a69）** |
| 2.2 | 作物生命周期 | SEED→SPROUT→GROWING→MATURE→（REGROWING↔MATURE）→EXHAUSTED→清理 | **✅ 完成（@03ebe22）** |
| 2.3 | 游戏时间 | `FarmClock`：24 时节 × 15 天 × 24 行动点，按天离散推进 | **✅ 完成（@03ebe22）** |
| 2.4 | 播种 | 工具槽选种 → 校验（TILLED/脚印/种子数）→ 原子播种（扣种子+占格同成败） | **✅ 完成（@03ebe22）** |
| 2.5 | 收获/清理 | 多素材掷量收获；remove 移除；regrow 有限次；EXHAUSTED 清理回 TILLED | **✅ 完成（@03ebe22）** |
| 2.6 | 测试作物 | 凝露草（herb·remove·4 天）+ 赤纹果（shrub·regrow×3·再生长 2 天） | **✅ 完成（@6ff9a69）** |
| — | 库存 | `FarmInventory`（id→数量，Phase 5 换主游戏道具适配层） | **✅ 完成（@03ebe22）** |
| — | 存档 | schema v2：clock + grid + crops + inventory | **✅ 完成（@03ebe22）** |

---

## 2. 时间体系（任务 2.3，v1.1）

`scripts/farming/core/clock/farm_clock.gd`（纯逻辑）+ 常量 `content/farming/config.json`：

- **年历**：24 时节 × 15 天 = 360 天；时节名取二十四节气（立春…大寒），
  本阶段纯叙事（无季节生长限制，Phase 6 内容扩容时再挂效果）。
- **行动点**：每天 24 AP；操作消耗见 `ap_costs`（占位：开垦/恢复/播种/采收/清理各 1，
  可调）。**AP 归零自动进入次日**；也可按 R 主动休息结束今天。
- **推进模型**：`clock.spend(n)` / `clock.end_day()`；`end_day` 发 `day_changed(total_days)`
  信号 → CropManager 按「天」推进生长（离散事件制，无逐帧轮询，master-plan 任务 6.3 方向）。
- **内部只存 `total_days` 与 `ap`**；时节/天/年派生计算，存档天然简单。

HUD：`惊蛰 · 第 5 天（第 2 年） · 行动点 17/24`。

## 3. 作物数据模型（任务 2.1）

`content/farming/crops.json`（烘焙校验：stage 天数、harvest_items 引用 items.json、
harvest_type 枚举、regrow 一致性）：

```json
{
  "crop_id": "scarlet_berry",
  "name": "赤纹果",
  "category": "shrub",
  "footprint": [1, 1],
  "planting_medium": "soil",
  "growth_stages": [
    {"id": "seed", "days": 1, "sprite": "stage_0"},
    {"id": "sprout", "days": 1, "sprite": "stage_1"},
    {"id": "growing", "days": 2, "sprite": "stage_2"},
    {"id": "mature", "days": 0, "sprite": "stage_3"}
  ],
  "harvest_type": "regrow",
  "harvest_items": [
    {"item_id": "scarlet_berry_fruit", "min": 2, "max": 4},
    {"item_id": "scarlet_berry_seed", "min": 0, "max": 1}
  ],
  "max_harvests": 3,
  "regrowth_duration": 2,
  "feed_tags": ["fire"]
}
```

- 阶段数由配置决定（渲染不硬编码）；mature 段 days=0（持续至采收）。
- 凝露草 `harvest_type: "remove"`、`max_harvests: 1`、4 天成熟、双产出（叶+种子回券）。
- `items.json`：id/name/占位价格（`base_price`，Phase 5 市场用）。

## 4. 生命周期与状态机（任务 2.2）

`scripts/farming/core/crops/crop_manager.gd`（纯逻辑，实例字段：uid/crop_id/origin/
footprint/growth_days/regrow_days/harvest_count/state）：

```
SEED ──天──▶ SPROUT ──天──▶ GROWING ──天──▶ MATURE
MATURE ──采收──┬─ remove 型 ─────────────▶ 实例销毁，地格回 TILLED
              └─ regrow 型：count+1
                   ├─ count < max_harvests ▶ REGROWING ──regrowth_duration 天──▶ MATURE …
                   └─ count = max_harvests ▶ EXHAUSTED（不再产出）
EXHAUSTED ──清理(锄头)──▶ 实例销毁，地格回 TILLED
```

- 生长只按 `day_changed` 推进（growth_days++ 至成熟阈值封顶）；跨天/读档恢复一致。
- 地格联动：播种 = LandGrid 原子占格置 `PLANTED`（holder=uid，prev=TILLED）；
  移除/清理 = release 回 TILLED。多格脚印（Phase 4 树木）同 API 天然支持。
- 采收掷量：逐项 `randi_range(min,max)`，RNG 以 `(uid, harvest_count)` 播种——
  同存档重放结果一致（确定性），自测可断言。

## 5. 交互（任务 2.4/2.5）

工具槽（数字键 1-9 选择，H 环切）：`0 锄头` / `1 凝露草种` / `2 赤纹果种`。

| 点击目标 | 行为（AP 检查先行） |
|---|---|
| MATURE 植株（任意工具） | 采收 → 多素材入库，toast 列出获得 |
| EXHAUSTED 植株 + 锄头 | 清理 → 地格回 TILLED |
| WILD + 锄头 | 开垦（Phase 1 行为） |
| TILLED + 锄头 | 恢复未开垦（Phase 1 行为） |
| TILLED + 种子 X | 播种：扣种子与占格**同一原子操作**（任一失败全部不变） |
| 其他组合 | 红色 toast 说明原因（未开垦/占用中/种子不足/AP 不足/非成熟期…） |

种子来源：开局赠送（config `start_inventory`）+ 采收返还种子（harvest_items 含 seed 项）。

## 6. 渲染与占位素材

`scripts/farming/rendering/crop_renderer.gd`：每个作物实例一个 Sprite2D（YSort 层），
底部中心锚点 = 脚印底边总宽中心（Phase 0 冻结规范），独立接触阴影贴片；
状态→贴图：SEED/SPROUT/GROWING→`stage_<i>`、MATURE→`stage_<last>`、
REGROWING→`stage_harvested`、EXHAUSTED→`stage_exhausted`（缺失时回退兜底图）。
Overlay：MATURE 格画金色小标、EXHAUSTED 画灰褐叉号（UI 绘制，非资产）。

`tools/farming/gen_farm_crops.py` 读 `baked/crops.json` 生成占位阶段图（QC 同前）：
`assets/farming/crops/<crop_id>/stage_<n>.png`（64×64）+ regrow 型的
`stage_harvested.png` / `stage_exhausted.png`。

## 7. 存档（schema v2）

`user://farm_phase02_save.json`：

```json
{"schema": 2,
 "clock": {"total_days": 12, "ap": 17},
 "grid": {...phase-01 结构...},
 "crops": [{"uid": 3, "crop_id": "dew_grass", "origin": [4, 9],
            "growth_days": 2, "regrow_days": 0, "harvest_count": 0, "state": "GROWING"}],
 "inventory": {"dew_leaf": 3, "dew_grass_seed": 7},
 "next_uid": 4}
```

纯逻辑数据（无贴图/节点引用）；读档后跨天生长继续正确（断言覆盖）。

## 8. 自测断言（--farmtest，在 Phase 1 的 19 项之上新增，目标 ≥ 33）

1. config：24/15/24 常量 + 24 时节名 + AP 消耗表
2. 时钟：初始立春·第 1 天·AP24；spend 至 0 自动次日；第 16 天进第 2 时节；
   第 361 天回立春·第 2 年；day_changed 信号次数
3. 播种校验：WILD 拒（未开垦）/石板拒/种子不足拒且**种子数与地格状态都不变**（原子）
4. 播种成功：扣 1 种子、地格 PLANTED、实例 SEED/stage_0
5. 生长按天推进：凝露草第 1/2/4 天的 SPROUT/GROWING/MATURE 与配置天数一致；
   阶段数取自配置（不硬编码 4）
6. remove 采收：双产出入库且都在 min–max 内、植株移除、地格回 TILLED、AP 消耗
7. regrow 采收：MATURE→REGROWING→2 天→MATURE→再采；第 3 次后 EXHAUSTED、
   地格仍 PLANTED；EXHAUSTED 采收拒绝；清理回 TILLED
8. 非成熟期采收拒绝；WILD 上播种拒绝文案正确
9. 掷量确定性：同 (uid,count) 两次采收产物一致
10. 库存 add/count/remove
11. 存档 roundtrip：四种实例状态 + 时钟 + 库存逐一恢复；读档后跨天生长正确
12. 日推进不重建静态层（格数不变）

## 9. 决策点

| # | 决策 | 结论 | 状态 |
|---|------|------|------|
| P2-A | 时节是否有生长效果 | 本阶段纯叙事（名称展示）；季节限制按 master-plan 仍不做 | ✅ 定 |
| P2-B | AP 归零是否自动次日 | **自动**（行动日节奏感）；R 可提前休息；消耗表 config 可调 | ✅ 定 |
| P2-C | 种子无限 vs 库存制 | 库存制：开局赠送 + 采收返还（经济闭环雏形，Phase 5 市场补购买） | ✅ 定 |
| P2-D | 采收对非成熟植株 | 拒绝并提示（不做误采保护性清除） | ✅ 定 |

## 10. 验收清单（对照 master-plan §五验收标准）

> 全部勾选，**Phase 2 于 2026-10-08 关闭**，进入 Phase 3。

- [x] 播种→生长→成熟→收获完整流程可玩（交互 + farmtest 26-29）
- [x] 两种收获机制（remove/regrow）正常运作；regrow 达上限枯竭、清理恢复（farmtest 29-31）
- [x] 多素材产出：单次收获 ≥1 种素材、数量在区间内、确定性可重放（farmtest 29 掷量复算）
- [x] 时间体系：24 时节×15 天×24AP；跨天/跨时节/跨年正确；AP 自动次日（farmtest 20-23）
- [x] 生长数据可存档及恢复（含读档后跨天，farmtest 33）
- [x] 作物逻辑不依赖具体图片（CropRenderer 缺图回退链 + 素材契约断言 35）
- [x] 收获物进入库存；种子扣除与占格原子（farmtest 25-26/32）
- [x] `--farmtest` 全过（40 项：P1 19 + P2 21）；截图留档 4 张审核通过（阶段区分/贴地/枯竭态/叉号）；
      phase00 farmtest 与 demo selftest 回归通过
- [x] 执行记录回写（§11）+ 分小阶段提交（@6ff9a69 / @03ebe22 / 收尾）

## 11. 执行记录（追加式）

### 2026-10-08 展开

- 本文档展开；上游 master-plan 升 v1.1（时间体系/有限采收/多产出）。

### 2026-10-08 实施与关闭

- **P2.a（@6ff9a69）**：config（24 节气名/AP 表/开局种子）+ crops（凝露草 remove×1、
  赤纹果 regrow×3 再生长 2 天，各 4 段生长/双产出）+ items（含 base_price 占位）
  + bake 扩展校验（阶段天数/引用/枚举/一致性）+ `gen_farm_crops.py` 占位阶段图
  （10 张，QC 全过）。
- **P2.b（@03ebe22）**：`FarmClock`（total_days+ap 派生制、AP 归零自动次日）、
  `CropManager`（GROWING/MATURE/REGROWING/EXHAUSTED；播种=reserve(PLANTED) 原子占格；
  有限次再生；多素材掷量 RNG 以 (uid,count) 播种可复算）、`FarmInventory`、
  `CropRenderer`（状态→贴图契约 + 回退链 + 独立阴影）、`LandGrid.reserve` 增
  target_state（PLANTED 须 TILLED）、farm_main v2（工具槽 1-9/H、收获优先分发、
  R 休息、AP 检查、HUD 时节/背包、成熟金点/枯竭叉号 Overlay、存档 schema v2）。
- **验证**：`--farmtest` **40 项全过**（P1 19 + P2 21，0 脚本错误）；截图 4 张视觉
  审核通过（阶段大小区分/贴地/枯竭灰褐态+叉号清晰）；phase00 farmtest、demo
  selftest 回归通过。
- **过程中修复**：①farm_inventory.apply_save void 用于布尔链 → 返回 bool；
  ②crop_manager 的 grid 成员补类型标注（无标注则方法调用推断失败）；
  ③重写 farm_main 时丢失 `--farm-shots` 参数分发循环（窗口空跑超时）——插桩定位后补回。
  教训入档：**大文件重写后必须回归全部运行模式（selftest/shots/交互）**。
- **Phase 2 关闭**。下一步：展开 `phase-03-AI作物资产管线.md`（美术规范细化→
  生成工作流→QC 工具→正式素材替换占位图，含 P1-C 挂起项的统一处理）。
