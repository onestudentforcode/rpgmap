> P8.5.a source archive, copied 2026-10-14. Links below resolve in the original art workspace; runtime uses the game manifest.

# 灵田 P8 植物资产交接与接入说明

日期：2026-10-14。面向上游游戏仓库 `rpgmap` 的开发者与接入代理。

**七种 P8 植物的四阶段资产已经完成，可进入游戏场景接入。** 本次交付为离线 Blender 建模、PNG 渲染和验收资料；尚未修改 `rpgmap` 的运行时绘制、生产规则、存档或导出配置。

源工作区：`C:/Users/88445/Desktop/blender_assest`。
目标仓库：`C:/Users/88445/Desktop/code/rpgmap`。
上游建议将本说明放入 `docs/farming/art/plant-assets-handoff.md`，并将运行时映射改为游戏自己的资产清单。

## 1. 先看这四项

- [六物种四阶段总览](C:/Users/88445/Desktop/blender_assest/plants/植物四阶段总览.png)：金穗麦、木腐菇、青牧草、蜜铃灌木、油籽花、新版速生杉。
- [松脂树四阶段对照](C:/Users/88445/Desktop/blender_assest/松脂树_resin_tree_contact.png)：此前已完成的第七个家族。
- [机器可读交接索引](C:/Users/88445/Desktop/blender_assest/UPSTREAM_PLANT_ASSETS.json)：逐文件来源、建议目标路径、画布、精确根点、显示尺寸建议与 SHA256。
- [全阶段总工程](C:/Users/88445/Desktop/blender_assest/plants/植物全阶段总工程.blend) 与 [物种文件索引](C:/Users/88445/Desktop/blender_assest/plants/README.md)：编辑、复现和逐物种核查入口。

上述链接相对于美术工作区根目录；把本说明复制到上游后，来源文件路径仍应按美术仓库根目录解析。JSON 的 `suggested_upstream_*` 为接入建议，当前上游并未创建这些目标文件。

## 2. 范围、状态与版本

| 游戏名称 | P8 数据 id | 玩法占地 | 成长家族 | 主要识别器官 |
|---|---|---|---|---|
| 金穗麦 | `golden_wheat` | 1×1 | `stage_0..3` | 弯秆、双列肥谷粒、长芒；0～2没有麦穗 |
| 速生杉 | `fast_fir` | 2×2 | 新版 `stage_0..3` | 弯脊干、轮生枝、破裙针叶冠 |
| 松脂树 | `resin_tree` | 2×2 | `stage_0..3` | 偏心腹瘤、三簇刷冠、琥珀脂滴 |
| 木腐菇 | `wood_decay_mushroom` | 1×1 | `stage_0..3` | 菌丝→菇蕾→初展耳盖→厚褶耳盖 |
| 青牧草 | `pasture_grass` | 1×1 | 直立抗倒伏版 `stage_0..3` | 密集分蘖、短节间、包茎叶鞘、窄V形折脊叶 |
| 蜜铃灌木 | `honeybell_bush` | 1×1 | `stage_0..3` | 对生叶、枝网、闭合花芽、下垂中空花囊 |
| 油籽花 | `oilseed_flower` | 1×1 | `stage_0..3` + `flowering` | 铲形叶、花芽、独立花期器官、成熟肥籽盘 |

交付合计：28张阶段主图、28张阶段小尺寸图，油籽花另有花期主图和小尺寸图。用于第一轮接入的是 **28张小尺寸阶段PNG＋1张花期PNG**。

成熟体已由用户验收通过；其余成长阶段已完成单株、四阶段连续性和机器检查。游戏同屏拼装、P8运行时及发布包验收仍由上游完成。

版本取舍：

- 速生杉使用 `plants/fast_fir/` 的新版；工作区根目录 `速生杉_fir*.png/.blend` 是保留的旧版，不应混入新版阶段。
- 青牧草使用当前直立窄叶版；“卷舌草”的宽回卷叶方案已被用户否定，不再使用。
- 松脂树文件目前在工作区根目录，接入时统一映射到 `resin_tree/`。
- 阔叶树/扇叶灵树是早前验证物种，没有 P8 作物 id；不能替代松脂树。
- 不扩展候选库、设施内藻类/净水菌毯或V0旧作物；本说明覆盖P8现有七作物。

已提交的美术来源版本：

| 提交 | 内容 |
|---|---|
| `ce36afc` | 松脂树四阶段、器官脚本、渲染和验收记录 |
| `c4965fe` | 共用植物套件与六物种成熟体建模/渲染管线 |
| `4f9ba5d` | 六种已审成熟体、花期对照与提示词修订 |
| `1122705` | 18个新增成长阶段、家族工程、总览与完整验收记录 |

以上是本地Git提交。本交接文档及JSON由已交付资产/QC记录生成，是否已同步远程需接入者另核对。

## 3. 文件搬运映射

建议上游目录沿用 `res://assets/farming/crops/<crop_id>/`，但使用P8真实 id，与旧V0四作物目录并存。

| 来源（相对美术仓库根目录，i＝0～3） | 建议上游运行时文件 |
|---|---|
| `plants/golden_wheat/stage_i_64.png` | `assets/farming/crops/golden_wheat/stage_i.png` |
| `plants/wood_decay_mushroom/stage_i_64.png` | `assets/farming/crops/wood_decay_mushroom/stage_i.png` |
| `plants/pasture_grass/stage_i_64.png` | `assets/farming/crops/pasture_grass/stage_i.png` |
| `plants/honeybell_bush/stage_i_64.png` | `assets/farming/crops/honeybell_bush/stage_i.png` |
| `plants/oilseed_flower/stage_i_64.png` | `assets/farming/crops/oilseed_flower/stage_i.png` |
| `plants/fast_fir/stage_i_128.png` | `assets/farming/crops/fast_fir/stage_i.png` |
| `松脂树_resin_tree_stage_i_128.png` | `assets/farming/crops/resin_tree/stage_i.png` |
| `plants/oilseed_flower/flowering_64.png` | `assets/farming/crops/oilseed_flower/flowering.png` |

直接读取JSON即可获得所有29个运行时源路径和校验值，不必解析本表的 `i`。

各目录无尺寸后缀的 `stage_i.png` 是1280像素主图；不要误当作已检查的64/128像素版本。需要更高分辨率时可从主图派生，但必须保持同族画布、归一化根点和等比缩放；中间分辨率版本目前未另交付。

`.blend`、构建脚本、对照图、预览图和QC记录归美术/开发资料；游戏资源只需要接入选定的PNG和渲染元数据。不要将带标签的 `contact.png` 或总览当作 SpriteSheet。

## 4. 画布、根点与比例：不能按图片底边统一贴地

共同规范：35°斜俯视正交、固定朝向、画面左上主光、柔和明暗、真实连续alpha。每个物种四阶段共享同一相机和世界原点 `(0,0,0)`；不同物种取景横宽不同。

根点是**世界原点在画布中的投影**，不是alpha包围盒的底部中心。以下为左上角起算的像素坐标，精确值见JSON：

| id | 小尺寸画布 | 根点 px（约） | 根点 UV（约） | 主图画布 | 正交横宽（Blender单位） |
|---|---|---|---|---|---|
| golden_wheat | 64×64 | (32,59.370269) | (0.5,0.927660) | 1280×1280 | 2.35 |
| wood_decay_mushroom | 64×64 | (32,58.181890) | (0.5,0.909092) | 1280×1280 | 2.20 |
| pasture_grass | 64×64 | (32,51.809586) | (0.5,0.809525) | 1280×1280 | 2.10 |
| honeybell_bush | 64×64 | (32,58.880059) | (0.5,0.920001) | 1280×1280 | 2.25 |
| oilseed_flower | 64×64 | (32,59.097922) | (0.5,0.923405) | 1280×1280 | 2.35 |
| fast_fir | 128×192 | (64,168.062422) | (0.5,0.875325) | 1280×1920 | 3.85 |
| resin_tree | 128×192 | (64,176.711184) | (0.5,0.920371) | 1280×1920 | 3.60 |

**不能逐阶段自动裁掉透明边、按bbox填满格子、重新居中或套统一底边offset。** 初生期在固定画布内很小是预期行为；单独放大会让成长切换跳动。尤其青牧草与两种树的根点不同。

上游逻辑地格为64单位，建模标定为1格＝2 Blender单位。若需严格统一世界物件比例，按32 Godot逻辑单位/Blender单位计算完整画布的绘制尺寸：

`绘制宽 = camera_ortho_width × 32`

`绘制高 = 绘制宽 × PNG高/PNG宽`

| id | 建议标定画布绘制尺寸（Godot逻辑单位） |
|---|---|
| golden_wheat / oilseed_flower | 75.2×75.2 |
| wood_decay_mushroom | 70.4×70.4 |
| pasture_grass | 67.2×67.2 |
| honeybell_bush | 72×72 |
| fast_fir | 123.2×184.8 |
| resin_tree | 115.2×172.8 |

这些是由已交付相机参数推导的**接入起点**，尚未在Godot拼装验收；必要的视觉尺寸调整只可按物种统一乘同一系数，不能分别缩放四阶段。若先按小尺寸画布原大小绘制，也须记录该物种的显示尺度并保持同族一致。

建议根点放在玩法占地矩形的底边中心，点击/选中仍使用原64格和真实 `footprint`。若项目后来采用格内其他根点约定，统一改变地面定位即可，保留图像内的根点数据。

下面是放置公式示意，不是已经接入的代码：

```gdscript
var footprint: Array = definition["footprint"]
var origin: Array = crop["origin"]
var ground_root := Vector2(
    (float(origin[0]) + float(footprint[0]) * 0.5) * 64.0,
    (float(origin[1]) + float(footprint[1])) * 64.0
)
var uv := Vector2(float(visual["anchor_uv"][0]), float(visual["anchor_uv"][1]))
var draw_size := Vector2(
    float(visual["suggested_world_calibrated_canvas_godot"][0]),
    float(visual["suggested_world_calibrated_canvas_godot"][1])
)
var top_left := ground_root - draw_size * uv
target.draw_texture_rect(texture, Rect2(top_left, draw_size), false)
```

上式保留购买扩展地块中的负数 `origin.x`，不要把农场绘制限制为从x＝0起始。纹理不应塞进 `rect.grow(-7)` 再分别拉伸树和小作物。

若改为Sprite2D，节点原点仍落在地面根点；按同样的UV设置纹理偏移并等比缩放。Godot的居中与偏移属性见 [Sprite2D官方文档](https://docs.godotengine.org/en/stable/classes/class_sprite2d.html)。

## 5. 上游实际接入位置

本次只读检查上游代码得到以下调用链：

`scenes/farming/farm_p8.tscn` → `scripts/farming/p8/p8_scene.gd` → `scripts/farming/v2/v2_scene.gd` → `scripts/farming/v1/v1_scene.gd`。

`project.godot` 默认运行P8；项目已关闭Blender自动导入。当前作物世界绘制的主要入口是 `v1_scene.gd` 的 `draw_map(target)`：绘制占地色块，再把 `Icons.get_icon(crop_id)` 填进占地矩形。P8的 `draw_map` 调用父实现后增加土地和研究等覆盖内容。

因此建议：

1. 新建独立的植物视觉清单/纹理缓存，读取七个真实 `crop_id`；可将本JSON转成 `assets/farming/crops/plant_manifest.json`，只保留上游路径和运行时所需元数据。
2. 将世界作物的占位图绘制替换为按阶段、锚点和显示尺度绘制PNG。缺文件时保留占位fallback，并输出能定位物种/阶段的诊断。
3. `_picture()` 等UI缩略图仍由 `Icons.get_icon()` 提供；不要为了世界贴图而全局替换Icons接口，影响市场、工具与状态标记。
4. 纹理加载在初始化或首次缓存时完成，不在每帧绘制循环中反复读取PNG。
5. 阶段及花期切换、播种、收获、砍伐、读档和地块变化后触发相应重绘，保留现有操作/存档语义。

V0的 `scripts/farming/rendering/crop_renderer.gd` 面向旧作物配置，不是P8主场景目前使用的绘制入口。可复用其中合适的技术实现，但不要直接把V0的作物列表、阶段配置和旧像素QC迁移为P8规则。

## 6. 生长、花期和采后：只新增视觉映射

### 普通首次生长

P8实际使用 `crop["state"]`、`crop["progress"]`、`definition["days"]`。理想日生长100进度；环境会影响日增量。因此按进度选择阶段，不能按日历天数硬切。

首次生长可先采用下面的均分映射作为实现初值，再由上游试玩确认阈值：

```gdscript
if crop["state"] == "mature":
    stage = 3
elif crop["state"] == "regrowing" and definition["mode"] == "tap_or_fell":
    stage = 3  # established tree/bush body remains mature
else:
    var target_progress := maxi(1, int(definition["days"]) * 100)
    stage = clampi(int(float(crop["progress"]) * 3.0 / target_progress), 0, 2)
```

均分阈值仅是视觉建议，尚未在上游实现；它不修改作物生长天数、水肥消耗、产量、研究解锁或存档字段。

### 油籽花

实际依据为 `content/farming/p8/production.json` 的 `flowers.oilseed_window=[300,500]` 和 `p8_flowers.gd` 的 `eligible()`。

- 首次生长期，进度落在 **[300,500)** 时使用 `flowering.png` 展示开花形态；成熟时使用 `stage_3.png` 的肥籽盘与残瓣。
- `stage_2` 的闭合花芽不等于花源窗口；花期纹理是独立状态，不能只在成熟时画花。
- `eligible()` 还检查水分、肥力和光照，属于生产资格。不要直接把“eligible为false”解释成花朵立即消失；花的形态由进度窗口决定，环境降效用既有状态提示表达。
- 不修改蜂源份额、手采竞争或授粉逻辑。本批不提供已授粉/未授粉两套植株图。

### 松脂树、蜜铃灌木采后

`v1_world.gd::harvest()` 对 `tap_or_fell` 的采收保留实例，增加 `harvest_count`、将 `progress` 归零并置为 `regrowing`；下次成熟按 `cycle_days*100` 结算。

**不能把这次归零当成重新播种，切回stage_0。** 两者采后保留成熟木质株体，初次接入仍绘制stage_3，用状态层表示等待再产。

松脂树工程的 `RT_SCARS`、`RT_RESIN` 可以独立编辑，但当前交付PNG没有额外的无脂采后帧/伤口恢复帧。蜜铃灌木也未另交无蜜滴/闭花的采后整图；这些属于后续视觉状态层工作，不应冒充已经交付。

金穗麦、青牧草、油籽花和木腐菇按现有采收流程移除植株；砍伐也移除对应树/灌木。空地继续使用地形层，本批不增加“空地植物PNG”。

## 7. 透明、过滤、遮挡与导出

新资产不是像素风：允许抗锯齿、渐变和连续alpha，不执行V0二值alpha、固定色板量化或强制NEAREST缩小规则。建议首先使用无损PNG，禁止色键抠白底或在主体上烘焙方形土块。

上游目前全局纹理过滤配置仍为Nearest。可在植物专用CanvasItem上明确使用 `CanvasItem.TEXTURE_FILTER_LINEAR`，避免顺带改变旧地形和其他界面资源；是否开启mipmap由实际缩放与小尺寸清晰度验收决定。[CanvasItem过滤与绘制属性](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html)。

地面先画，植物和设施按地面根点共同排序，选中、成熟、缺水、任务等覆盖层最后画。若继续使用同一个 `draw_map`，需要排序统一对象列表；仅在同一个Node2D上打开Y-sort，不能代替自定义draw指令的排序。若改为独立Sprite节点，则将地面根点设为节点排序原点、植物与设施纳入同一Y-sort父节点。[CanvasItem Y-sort说明](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-property-y-sort-enabled)。

视觉越界不改变玩法占地。树冠可以遮住后排，点击、开垦、寻路和选中仍依据原网格/footprint；不要用透明画布或alpha包围盒改写地块占用。

本地 `export_presets.cfg` 目前是显式资源清单，列表以旧V0资源为主；P8发布包仍需独立核对。字符串拼接加载的新PNG、manifest及当前P8入口不能假定自动进入发布包，必须明确配置导出包含项，并运行导出包检查。资源选择行为见 [Godot项目导出说明](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html#resources)。

## 8. 已完成与上游验收项

已完成：

- 七作物四阶段、真实透明主图及小尺寸PNG；油籽花独立花期。
- 六成熟体和松脂树成熟体的用户验收；青牧草已按“更像草、抗倒伏”修订。
- 新增18阶段的非空alpha、四角透明、四边留白、接地、高度递增、根点投影一致和早期无成熟器官检查。
- 单株/四阶段对照视觉检查；24项已审文件SHA256保持一致。
- 六家族独立工程含完整场景；油籽花家族工程另含花期。

上游完成接入后，验收以下实际游戏行为：

1. 新档/读档均能显示七种植物，缺图诊断准确，工具/市场UI图标仍可用。
2. 同格切0→1→2→3根点不跳；幼苗不被放大成成熟体大小；树类保持128:192画布比例。
3. 松脂树采脂、蜜铃采集后保留成熟株体；砍伐/重种与菌菇培养循环按原玩法运行。
4. 油籽花进度299、300、499、500以及成熟状态的图片正确；水肥/光照影响产能时不误切回幼苗。
5. 密种同品种、混种、树与设施邻接、购买扩展区负x地块、镜头缩放与拖动正常；遮挡次序及状态标记清楚。
6. 实际分辨率/缩放下无透明白边、严重锯齿、误裁切或主图重复填满地块；64像素细节不足时统一派生更高清资源。
7. 独立发布包能够读取新PNG和视觉清单，加载不到资源时不静默显示空帧。

本说明没有声称这些游戏/发布包检查已经通过；美术工作区中的拼装对照不能代替上游实机验收。

## 9. 编辑与复现入口

其余六物种：`plants/<id>/family.blend`，包含 `PG_<id>_Stage0..2`、`PM_<id>_Stage3` 和 `PC_<id>_Contact`。油籽花另含花期。总工程为 `plants/植物全阶段总工程.blend`。

松脂树：`松脂树_resin_tree.blend`；成熟期独立工程为 `松脂树_resin_tree_stage_3.blend`。可编辑集合 `RT_BODY`、`RT_SCARS`、`RT_RESIN`；不混入原阔叶验证树。

构建/渲染脚本入口：

| 用途 | 脚本 |
|---|---|
| 共用材质、枝秆、厚叶、系列相机 | `_plant_kit.py` |
| 六物种成熟体 | `_build_plants_mature.py`、`_render_plants_mature.py` |
| 新增三阶段 | `_build_plant_stages.py`、`_render_plant_stages.py` |
| 家族并排与总览 | `_plant_growth_review.py`、`_render_growth_review.py` |
| 针叶器官 | `_resin_needles.py` |
| 松脂树成熟体与其余阶段 | `_build_resin_tree.py`、`_render_resin_tree.py`、`_build_resin_family.py`、`_render_resin_family.py` |
| 本交接JSON生成 | `_make_upstream_manifest.py` |

Blender脚本中的 `__file__` 必须设为实际脚本路径；六物种的成熟/成长构建与渲染器支持用 `ASSET_IDS` 选择物种，成长构建器另支持 `STAGE_IDS`。松脂树与场景汇总脚本按各自入口运行。不要为了再次导出PNG而重建已审成熟体；正常接入只需搬运资产和元数据。

源文件检查记录：`plants/mature_qc.json`、`plants/growth_qc.json`、`plants/growth_contact_qc.json`、`plants/approved_mature_hashes.json`、`松脂树_resin_tree_family_qc.json`。提交同步后优先按文件校验值核对，避免混入旧杉或青牧草旧版。
