# 全游戏美术资产清点

> **日期：** 2026-10-21（P10.6 收口后）。
> **范围：** 农场模拟（P8/P10 线，`assets/farming/`）与 RPG 地图侧（`assets/themes/`）全部需要美术的呈现层；依据资产目录、三份资产清单（设施/作物/图标）、烘焙内容（84资源/39设施/64配方/17作物/11蛊）与场景代码逐一核对。
> **口径：** 「正式」= Blender 建模→离线渲染 PNG（P8.5/P8.6 批次，源工程在外部工作区，定版图已入库，无需外部依赖即可运行）；「矢量」= P6.5 原生 SVG 图标批次；「占位」= Python 脚本程序化生成、明确不作正式验收对象；「缺失」= 无任何素材或仅代码回退。三类不混称。

## 0. 总览

| 类别 | 正式/矢量 | 占位（程序生成） | 缺失或仅代码绘制 | 遗留未接入/孤儿 |
|---|---:|---:|---:|---:|
| 设施主体（39在用） | 14 | 25 | 0 | 1退役（rock_workyard有图无定义） |
| 作物生长图（10在用） | 7 | 3 | 0 | 4套（dew_grass等） |
| 地形与过渡 | 4地面+4过渡+水面SVG | — | — | — |
| 资源点 | 3 | — | — | — |
| UI图标 | 156 SVG | — | **20个实体无图标**（五行回退） | 1孤儿（rock_workyard.svg）+若干.action同义 |
| 牧场动物形象 | — | — | **全部缺失**（陆生9+水产6无地图形象） | — |
| 鱼栅/水体地图绘制 | — | — | **全部缺失**，且水房间绘制有接线缺陷 | — |
| RPG主题（tileset/objects/player） | — | 3主题×3图（模板级） | — | — |
| 3D源模型 | — | — | — | 44个 .glb.import 孤儿（模型不在库） |

## 1. 设施主体（`assets/farming/facilities/`，清单 `facility_manifest.json`，39个全部有图）

每个设施一个 `body.png` + 清单登记（尺寸/锚点/阴影/SHA256），由 `p8_facility_visuals`/`p8_scene` 按 35° 投影挂接（P8.7 统一）。

**正式（Blender 渲染，14个在用 + 1退役）：**
woodshop（木工台）、char_kiln（炭窑）、compost_bin（堆肥箱）、smelter（熔炉）、pen（圈舍）、algae_tank（藻类培养槽）、research_bench（研究台）、bee_hive（蜂箱）、farm_processor（农产加工台）、purifying_bed（净水菌床）、kitchen（厨房）、field_service_station（田间维护站）、growth_lamp（明光灯）、fish_pond（水场；P10.6 起退役不再可建，图保留可读档）。
另 rock_workyard 有正式图但设施已在 P10.5 拆分退役，清单条目已清。

**占位（Python 等距块生成，颜色区分工艺，不做正式验收）：**

| 批次 | 生成器 | 设施 |
|---|---|---|
| P10.3 | `gen_p103_facility_art.py` | dispatch_station（调度站）、feed_trough（供食槽）、small_bed/medium_bed/large_bed（床组）、care_table（照料台）——6个 |
| P10.4 | `gen_p104_facility_art.py` | soothing_station（安抚台）、toy_station（玩具站）——2个 |
| P10.5 | `gen_p105_facility_art.py` | wool_station（采毛台）、silkworm_rack（蚕架）、spirit_liquid_collector（集露台）、scale_station（养鳞台）、rock_breaking_yard（碎岩场）、ore_sorting_yard（选矿场）、carbonization_nest（炭化巢）、compost_mouse_den（翻肥窝）、shell_forming_station（岩壳成型台）——9个 |
| P10.6 | `gen_p106_facility_art.py` | carp_harvest_station（捕鲤台）、oilfish_harvest_station（取油台）、pearl_station（采珠台）、gel_station（采胶台）、coral_station（采礁台）、silt_processing_station（泥料处理台）、aquatic_crop_station（水生种植台）、water_change_station（换水站）——8个 |

占位设施合计 25 个：**占在用设施的 64%**。畜牧/水产两代玩法的主要设施全部是占位。

## 2. 作物生长图（`assets/farming/crops/<id>/stage_N.png`，清单 `plant_manifest.json`）

每作物 4 阶段（个别 6），512×768 画布，P8.6 幼苗规范 + P8.7 投影/柔影。

- **正式（7种，Blender 批次"七植物29图"）：** golden_wheat（金穗麦）、fast_fir（速生杉）、resin_tree（脂树）、pasture_grass（青牧草）、honeybell_bush（蜜铃灌木）、oilseed_flower（油籽花）、wood_decay_mushroom（木腐菌）。
- **占位（3种，Python 生成）：** mulberry_tree（果桑，P10.5 `gen_p105_plant_art.py`）；duckweed（浮萍）、reed（芦苇，P10.6 `gen_p106_plant_art.py`，水面线风格）。
- **遗留未接入（4套，AI 出图时代产物，当前内容不引用）：** dew_grass（凝露草，4阶段）、jade_fruit_tree（青玉果树，6阶段）、moon_cap（月华菇，4阶段）、scarlet_berry（赤纹果，6阶段）。资产在库、无内容定义；对应风格规范见 `art-style-sheet.md`（已声明为历史规范）。
- `_placeholder/` 内有通用占位件（shadow_ellipse、tall_stone 等）供接地试验用。

## 3. 地形、过渡与水面

- **正式：** grass/dirt/stone/tilled 四种地面 PNG（B 地面定版，`assets/farming/ground/`）；4 张地形过渡 PNG + JSON（`transitions/`）；`ground_water.svg`（水面地块，P8.6）；水岸柔边由 `p86_shore`/`p87_shore` 着色器 + `p8_terrain_soften` 完成（代码效果，非贴图）。
- 资源点 3 张正式图（ore/spring/stone，`p86/` + `resource_manifest.json`）；地图上另有白卡+图标的后备画法。

## 4. UI 图标（`assets/farming/ui/*.svg`，清单 `manifest.json`，P6.5 原生矢量批次）

- **正式矢量 156 个**：64×64 viewBox、本地内容安全检查、高频工具图标形状查重（`test_ui_assets.py`）。覆盖：截至 P10.5 的全部资源/设施/作物（84 资源中 74 个、39 设施中 31 个、10 作物中 8 个）+ 五行 + 约 33 个操作图标（buy/sell/till/plant/harvest/…）+ 11 只蛊中的 9 只（soothe/command/bright/growth/water/fert/wisdom/time/rice_bag）。
- **缺失 20 个（全部为 P10.6 新实体）**：资源 pearl、mussel_shell、water_gel、coral_stone、duckweed、duckweed_seed、reed_stalk、reed_seed、fish_meal、water_retaining_matrix（10）；设施 carp/oilfish/pearl/gel/coral/silt/aquatic_crop/water_change（8）；蛊 product_yield_gu、feed_saving_gu（2）；作物 duckweed、reed 亦无独立图标（与资源重名，当前共用回退）。运行回退：`v1_ui_icons.gd::get_icon` 对缺失图标回退到五行图标（水产新材料→water/wood/gold），市场/百科不会报错但视觉不可区分。
- **门禁漏洞**：`tools/farming/test_ui_assets.py` 的覆盖断言读取的是 **v1** 内容（`content/farming/v1/production.json`），P8/P10 内容不在校验范围——这是 20 个图标缺口未被发现的原因。
- 孤儿：rock_workyard.svg（设施已退役）；另有一批 `.svg.import` 残留（iron/metal/stone/ore/plank 等历史改名）。

## 5. 完全没有美术的呈现层（代码绘制或空白）

1. **牧场动物地图形象——全部缺失。** 陆生 9 种 + 水产 6 种动物在地图上没有任何形象（`p8_scene._draw_world_entities` 只画作物/设施/资源点）；动物只存在于侧栏名册（文字+图标都没有专属图）。P10.6 阶段文档 §12.3 曾把「六种生物图标」列为表现需求，未交付。
2. **鱼栅与水体地图绘制——全部缺失。** `p106_water` 模块无任何场景绘制：鱼栅外沿/围栏、水体边界、水质着色都没有；只有功能区色块（见下）。P10.6 阶段文档 §12.3 的「可辨认的鱼栅外沿/内部水面」未交付。
3. **水房间绘制接线缺陷（疑似，高置信）。** `p103_ui.gd:16` 的 `ZONE_COLORS` 只登记了 6 个陆地区型颜色；P10.6 新增的 5 个水区型（water_nursery/water_enclosure/water_production/water_loach/aqua_planting）不在表中，而 `draw_ground`（`p103_ui.gd:540`）按 `ZONE_COLORS[type]` 取色——一旦地图上存在水房间，重绘即按键缺失报错。现有测试全部无头且不跑场景绘制，因此未暴露。修复约一行（补 5 个颜色），建议随鱼栅美术一并处理。
4. **雇工/研究者等人物形象**：无（侧栏图标 workers.svg 仅 UI 用）。
5. **批次预览、功能区色块、工具悬浮框**等：有意的代码绘制（半透明矩形），属可接受的调试图层，不算缺美术。
6. **服役/动物状态角标**（疲劳/禁工/水质暂停等）：无图标，仅文字。

## 6. RPG 地图侧（`assets/themes/`，非农场模式）

- 3 个主题（placeholder/dusk/wilds），每主题 3 图：tileset 224×32（16px 瓦）、objects 352×96、player 128×192。规模均为模板级（原 rpgmap 工程起点素材）。
- **默认主题就是 `placeholder`**（`content/maps/index.json: default_theme`），4 张地图（lobby/corridor/storeroom/market）dusk 与 placeholder 共用布局；wilds 仅 plains 一图（`main.gd` 支持野外截图模式）。
- 结论：RPG 侧整体处于占位状态，无任何正式美术批次。

## 7. 孤儿与外部依赖

- `assets/farming/3d/`：44 个 `.glb.import`，**没有实际 .glb 文件**——Blender 源工程在外部工作区（`C:/Users/88445/Desktop/blender_assest`，见 `docs/farming/art/README.md`），仓库只保存定版渲染 PNG。重渲染需外部工作区；日常运行/发布不受影响。
- `assets/farming/textures/p9/`：3 个 `.png.import` 孤儿（arable/floor/wasteland，P9 试验遗留）。
- `assets/sprites/`：空目录。
- `archive/old-farming/`：V0 时代资产与 1 个 blend 白模（farmland_soil_whitemodel），历史归档。

## 8. QC 门禁现状

| 门禁 | 覆盖 | 现状 |
|---|---|---|
| `qc_assets.py` | 设施/作物清单↔内容一致、SVG 几何、导入设置 | 111 项通过（P10.6 后） |
| `test_ui_assets.py` | 图标覆盖 | **只对 v1 内容断言**，P8/P10 缺口不设防 |
| `qc_p85/86/87_visuals.py` | 历史 Blender 批次视觉基准 | 需 GPU 证据，按历史基线维护 |
| 占位生成器 | P10.3~P10.6 各批 | 生成时内嵌硬 alpha/bbox 断言 |

## 9. 缺口优先级建议（供排期讨论，非本页执行项）

1. **接线缺陷修复**：ZONE_COLORS 补水区颜色（一行，随任一美术批次提交）。
2. **图标补齐**：20 个 P10.6 实体 SVG（含 2 蛊 2 作物 10 资源 8 设施——设施图标与占位主体可同批做正式化）；同时把 `test_ui_assets.py` 的覆盖断言切到 P8 烘焙内容，堵门禁漏洞。
3. **动物形象（最大块）**：15 种动物的地图形象/状态表现，需先定表现形式（立绘式 sprite/等距占位/图标级），建议独立阶段立项。
4. **鱼栅与水体外沿**：围栏贴图或代码描边 + 水质着色分层。
5. **占位设施正式化**：25 个占位主体按 P8.5 Blender 管线分批替换（畜牧 17 个优先，水产 8 个次之——或水产直接进 Blender 批）。
6. **RPG 主题**：与农场模块联动前维持现状；如需正式化另立美术方向讨论（可参考 `game-art-direction` 技能流程）。
7. **清理项**：孤儿 .import（3d/44、textures/p9/3、ui 若干）、空 sprites/ 目录、4 套遗留作物素材的去留裁决（保留为风格参考或随 archive 归档）。

## 10. 追溯入口

- Blender 管线与验收：`docs/farming/art/README.md`、`docs/farming/art-pipeline.md`、`docs/farming/art/facility-inventory.json`（15设施盘点）、`plant-import-report.json`（29图导入报告）。
- 投影与接地规范：P8.6/P8.7 阶段文档与 `p87-projection-direction.md`。
- 历史像素风规范（已废止为新素材不强制）：`docs/farming/art-style-sheet.md`。
- P6.5 图标批次：`docs/farming/ui-design/`。
- 本页清点脚本依据：`assets/farming/{facilities,facility_manifest}.json`、`crops/plant_manifest.json`、`ui/manifest.json`、`content/farming/p8/production.json`、`content/maps/index.json` 及 `scripts/farming/p8/{p8_scene,p103_ui,v1_ui_icons}.gd`。
