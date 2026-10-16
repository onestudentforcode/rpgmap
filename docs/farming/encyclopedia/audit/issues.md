# Phase 9.a — 调查问题清单（issues.md）

生成日期：2026-10-16。每项含稳定问题ID、严重程度（P1阻断/P2影响玩家理解或操作/P3轻微或仅显示层）、受影响对象、双方证据、玩家影响、已知范围与建议核查方向。**本清单只登记事实，不修改玩法**；严重程度按“对百科内容正确性与玩家理解的影响”评定，与是否为代码缺陷无关。即使修复也须另行授权，不在本调查范围内。

## I-01 baked消费索引把污水记为“换水”的消费者【P3·索引/显示层】

- 受影响：`resource:wastewater` 的 `consumers` 索引（baked）。
- 现象：`content/farming/baked/p8/production.json` 中污水 consumers 含 `water_change`，但换水是污水的**产出**过程；其真实消费者是菌毯特殊食谱（bio_purify/recover_nutrients，另有配方注册面）。
- 证据：`tools/farming/bake_p8.py` `compile_config` L474-475（`items['wastewater']['consumers'] |= {'water_change'}`，与对换水输入（清水）的处理对称书写）；运行时消耗见 `scripts/farming/p8/p8_husbandry.gd` `_mat_quote` L281-339。
- 玩家影响：仅显示层（研究页获取路线、资源标注不读此字段做逻辑判断）；不影响任何扣料或结算。
- 范围：已确认；coverage.json `baked_consumers_crosscheck` 唯一剩余差异即此项。
- 建议：百科内容层按规范过程（proc:water_change 产出 / proc:maintain:purifying_mat 消耗）生成索引，不复用baked consumers；如需修正bake索引另行授权。

## I-02 研究页“获取路线”对活体/换水来源显示“暂无来源”【P2·UI指引缺口】

- 受影响：研究面板样本获取路线（`p8_scene.gd::_sample_route` L731-745）对仅由provider或换水路径产出的样本显示“暂无来源”。
- 涉及样本：花蜜、花粉（蜂群协作样本；实际=手采合格蜜铃灌木/油籽花份额）；污水（菌毯净化样本；实际=水场真实换水）；污泥（水与藻料回流样本）；碎铁矿（生物选矿样本；实际=啮岩鼹破矿轮收取）；另蜂蜜/蜂蜡/砂砾/石粉/富集矿砂/尾砂/营养液在市集无售时同样无路线提示。
- 证据：`_sample_route` 只识别 `market/recipes/crops/sources(资源点)/species(注册物种)` 五类标签；baked sources 中的 `honeybell_bush_provider`、`water_change_provider`、`break_ore_provider` 等派生provider标签不匹配任何分支（`scripts/farming/p8/p8_scene.gd` L731-745；provider生成见 `tools/farming/bake_p8.py::providers`）。
- 玩家影响：恰好在玩家最需要路线指引的研究页面上，活体/换水类样本显示“暂无来源”，需自行翻新手手册（手册第3章有正确路线描述）。
- 范围：静态核对确认；未逐项目视复现（未运行游戏）。
- 建议：P9.c百科条目为这些样本给出真实路径；研究页路线可引用同一内容层。

## I-03 完成菌毯净化研究后，市集“净水菌毯培养单位”按钮可点但必被拦截【P3·UX】

- 受影响：`resource:purifying_mat_culture` 市集购买入口。
- 现象：该物品 `buy_price=6` 且带 `research:biofiltration`。研究完成前锁定提示正常；**完成后**购买按钮按价格启用，但点击必然返回“培养单位请在净水菌床面板直接购入：扣款即占位，不入仓库”。
- 证据：按钮禁用条件只看锁与余额（`scripts/farming/v1/v1_scene.gd::_update_trade` L1353）；拦截在 `scripts/farming/p8/p8_world.gd::buy` L246-248。
- 玩家影响：轻微困惑；实际购入路径（菌床面板，同价6元石/单位）功能正常。
- 范围：静态核对确认。
- 建议：百科按“购买代理实体”处理（目录已如此建模）；UI上把该物品按钮常置禁用属于玩法侧修改，另行授权。

## I-04 食谱ID跨物种重复与“配方ID=食谱ID”共用【P3·命名/建模注意】

- 受影响：百科与任何按ID索引的内容层。
- 现象：`land_meal` 同时是钢绵羊与岩腹兽的基础食谱ID；`bio_purify/recover_nutrients/break_stone/break_ore/concentrate_ore` 既是配方ID又是物种特殊食谱ID（活体双重注册）。
- 证据：`content/farming/p8/production.json` `/livestock`；bake的diets门控按ID单表登记（`tools/farming/bake_p8.py` L317-328），当前同名食谱research一致（land_meal两处均为advanced_feed_oil_wax），无实际冲突。
- 玩家影响：当前无；若未来新增同名不同研究的食谱，解锁表单表登记会互相覆盖（潜在风险）。
- 范围：已确认当前一致；风险为推断。
- 建议：百科统一使用 `diet:物种/类型/食谱ID` 限定ID（目录已采用）；P9.b编译器可加同名食谱一致性校验。

## I-05 成本模型/供应商轮是定价参考，不是生产路径【P3·口径声明】

- 受影响：44条 `cost_models` 与派生 `standard_cost/supply_value`、baked `sources/consumers` 中的provider标签。
- 现象：`bake_p8.py` 文件头自述"This is a static cost reference, not a replacement for the P8 runtime stages"；供应商轮按满容量4单位×(成长+周期)汇总投入产出（如bee_round含36清水/27AP/24元石），玩家实际按单位逐日执行。
- 证据：`tools/farming/bake_p8.py::providers` L49-191；任务书§三.2亦明确。
- 玩家影响：若百科/手册把标准成本或参考轮当真实路径展示会误导（例如把27AP当作酿蜜一次的成本）。
- 范围：已确认；catalog已将cost_models标记为派生来源（source_mappings），未注册为过程。
- 建议：百科把supply_value标注为“订单计量参考值”，不展示为成本。

## I-06 成熟待收作物仍每日扣水肥【P3·设计行为，需明示】

- 受影响：全部作物（多格树按每格扣）。
- 证据：`scripts/farming/v1/v1_world.gd::_on_day_changed` L595-598——扣减循环在 `if state != "mature"` 判断之外。
- 玩家影响：留株成熟不收会持续消耗地力；与“成熟即停止消耗”的直觉相反，易被当作bug报告。
- 范围：已确认（静态）；规则页R2已收录。
- 建议：作物条目明示“成熟待收期间照常扣减”。

## I-07 生长速率有下限1点/日，“缺水不生长”表述不成立【P3·口径修正】

- 受影响：作物生长解释文本。
- 证据：`v1_world.gd` L588 `maxi(1, floori(水效×肥效×光效/10000))`——三短板时18点/日（floor(18.75)），标称4天的金穗麦实际约23天，**不会完全停滞**。
- 玩家影响：手册“缺水、低肥或光照不合适会变慢”正确；任何“不会生长”的表述都不准确。
- 范围：已确认；连乘取整口径见规则R2（37.5%档=37点而非38点）。
- 建议：百科统一使用公式+worked example（报告§3）。

## I-08 生长公式连乘后取整造成非平滑档位【P3·数值口径】

- 受影响：缺水+低肥组合（50×75×100/10000=37.5→37）等非整数连乘场景。
- 证据：同I-07代码行；每日按当日环境重算，跨日环境变化会改变当日档位。
- 玩家影响：按“每日37.5点”心算会偏差1点/日；百科示例需用整数档位表。
- 范围：已确认；报告§3给出全档位worked example。
- 建议：百科展示档位表（100/75/50/37/18点）而非连续公式。

## 检查范围与结论（无问题的部分）

以下已专项检查且未发现问题：研究解锁表与实体research门槛双向一致（bake强制+本次复核）；40配方投入/产出/批时与过程模型逐项对拍一致；5组活体配方与物种特殊食谱投入/产出一致；63资源正反索引与242过程双向一致（audit_entities.py 50项检查0问题）；订单数量/溢价公式与供货资格核对一致（溢价=基数×10%向下取整为既定实现）；花源份额/授粉/换水/装置燃料的扣料时点与运行代码一致；扩地6地块价格/前置/地形与bake校验一致；市集套利校验（买×100>卖×110）全部资源通过。归属差异（baked provider标签 vs 运行时路径）18组已逐条解释于 `coverage.json → baked_attribution_differences`，不视为缺陷。
