# P10.9 动植物与水生生物：成体源图交付记录

> **日期：** 2026-10-22。用户已确认前批画风，并要求按同一标准继续完成动物、植物、水生生物；建筑继续推迟，其他状态等成体验收通过后再做；未要求不生成候选，也不反复改图。
> **本轮工具：** 内置image_gen；逐对象一次生成，完整实际请求见[生产提示词](p109-production-prompts.md)及源图目录`prompts.json`。

## 数量和范围

- 内容覆盖：10种植物＋17个生活体注册项＝27项；生活体包括9种陆生动物、6种水产、蜜盏蜂和净水菌毯。
- 本轮新增23张＋直接沿用3张＋用户提供的钢绵羊原图1张＝27张已归档PNG。钢绵羊直接从用户给定路径复制原文件，不重新生成。
- 无新增幼苗、幼体、采后、工作/缺供状态、动画或替代候选。叶丝蚕为成熟可产丝蚕体，不改成蛾；菌毯与珊瑚为成熟群体。
- 本轮是成体源图交付，不替换现有运行纹理，不等同于完整P10.9、全部建模、根点/机位/游戏内验收已完成。

## 查看与保存

[打开成体素材总览](../../../assets/farming/p109/source/index.html)。总览支持浅草/深色/水色底与显示大小切换，点击看原始PNG；显示框大小不代表实际地图尺度。

正式源图目录：`assets/farming/p109/source/`，按`animals/aquatic/plants/living`分类；命名`<id>_<adult|mature>_view35_v001.png`。目录内`.gdignore`暂时避免源图重复进入Godot导入，待后续接入按运行清单处理。

## 逐项清单

| 对象 | 类别 | 文件/状态 |
| --- | --- | --- |
| 炭腹虫 `carbon_belly_bug` | 陆生动物 | [原始PNG](../../../assets/farming/p109/source/animals/carbon_belly_bug/carbon_belly_bug_adult_view35_v001.png) |
| 堆肥鼠 `compost_mouse` | 陆生动物 | [原始PNG](../../../assets/farming/p109/source/animals/compost_mouse/compost_mouse_adult_view35_v001.png) |
| 露壳蜗牛 `dew_shell_snail` | 陆生动物 | [原始PNG](../../../assets/farming/p109/source/animals/dew_shell_snail/dew_shell_snail_adult_view35_v001.png) |
| 砾甲蜗牛 `gravel_shell_snail` | 陆生动物 | [原始PNG](../../../assets/farming/p109/source/animals/gravel_shell_snail/gravel_shell_snail_adult_view35_v001.png) |
| 叶丝蚕 `leaf_silkworm` | 陆生动物 | [原始PNG](../../../assets/farming/p109/source/animals/leaf_silkworm/leaf_silkworm_adult_view35_v001.png) |
| 矿鳞蜥 `mineral_scale_lizard` | 陆生动物 | [原始PNG](../../../assets/farming/p109/source/animals/mineral_scale_lizard/mineral_scale_lizard_adult_view35_v001.png) |
| 岩腹兽 `rock_belly_beast` | 陆生动物 | [原始PNG](../../../assets/farming/p109/source/animals/rock_belly_beast/rock_belly_beast_adult_view35_v001.png) |
| 啮岩鼹 `rock_mole` | 陆生动物 | [原始PNG](../../../assets/farming/p109/source/animals/rock_mole/rock_mole_adult_view35_v001.png) |
| 钢绵羊 `steel_sheep` | 陆生动物 | [用户选中原始PNG](../../../assets/farming/p109/source/animals/steel_sheep/steel_sheep_adult_source_v001.png)（RGB黑底，原样归档） |
| 滤藻鲤 `filter_algae_carp` | 水生生物 | [原始PNG](../../../assets/farming/p109/source/aquatic/filter_algae_carp/filter_algae_carp_adult_view35_v001.png) |
| 凝胶水母 `gel_jellyfish` | 水生生物 | [原始PNG](../../../assets/farming/p109/source/aquatic/gel_jellyfish/gel_jellyfish_adult_view35_v001.png) |
| 油鳍鱼 `oilfin_fish` | 水生生物 | [原始PNG](../../../assets/farming/p109/source/aquatic/oilfin_fish/oilfin_fish_adult_view35_v001.png) |
| 珍珠蚌 `pearl_mussel` | 水生生物 | [原始PNG](../../../assets/farming/p109/source/aquatic/pearl_mussel/pearl_mussel_adult_view35_v001.png) |
| 礁骨珊瑚 `reef_coral` | 水生生物 | [原始PNG](../../../assets/farming/p109/source/aquatic/reef_coral/reef_coral_adult_view35_v001.png) |
| 净泥鳅 `silt_loach` | 水生生物 | [原始PNG](../../../assets/farming/p109/source/aquatic/silt_loach/silt_loach_adult_view35_v001.png) |
| 蜜盏蜂 `bell_bee` | 其他生活体 | [原始PNG](../../../assets/farming/p109/source/living/bell_bee/bell_bee_adult_view35_v001.png) |
| 净水菌毯 `purifying_mat` | 其他生活体 | [原始PNG](../../../assets/farming/p109/source/living/purifying_mat/purifying_mat_adult_view35_v001.png) |
| 浮萍 `duckweed` | 成熟植物 | [原始PNG](../../../assets/farming/p109/source/plants/duckweed/duckweed_mature_view35_v001.png) |
| 速生杉 `fast_fir` | 成熟植物 | [原始PNG](../../../assets/farming/p109/source/plants/fast_fir/fast_fir_mature_view35_v001.png) |
| 金穗麦 `golden_wheat` | 成熟植物 | [原始PNG](../../../assets/farming/p109/source/plants/golden_wheat/golden_wheat_mature_view35_v001.png) |
| 蜜铃灌木 `honeybell_bush` | 成熟植物 | [原始PNG](../../../assets/farming/p109/source/plants/honeybell_bush/honeybell_bush_mature_view35_v001.png) |
| 果桑树 `mulberry_tree` | 成熟植物 | [原始PNG](../../../assets/farming/p109/source/plants/mulberry_tree/mulberry_tree_mature_view35_v001.png) |
| 油籽花 `oilseed_flower` | 成熟植物 | [原始PNG](../../../assets/farming/p109/source/plants/oilseed_flower/oilseed_flower_mature_view35_v001.png) |
| 青牧草 `pasture_grass` | 成熟植物 | [原始PNG](../../../assets/farming/p109/source/plants/pasture_grass/pasture_grass_mature_view35_v001.png) |
| 芦苇 `reed` | 成熟植物 | [原始PNG](../../../assets/farming/p109/source/plants/reed/reed_mature_view35_v001.png) |
| 脂树 `resin_tree` | 成熟植物 | [原始PNG](../../../assets/farming/p109/source/plants/resin_tree/resin_tree_mature_view35_v001.png) |
| 木腐菌 `wood_decay_mushroom` | 成熟植物 | [原始PNG](../../../assets/farming/p109/source/plants/wood_decay_mushroom/wood_decay_mushroom_mature_view35_v001.png) |

## 文件核查与验收边界

27张文件与SHA256逐一核对，27个内容ID无漏项/重复。其中26张为RGBA且alpha包含透明背景，按alpha≥16测量的主要主体均位于画布内。钢绵羊为1254×1254 RGB黑底原图，无alpha，按用户选择保持原文件；后续接入需处理背景，不能把这张报为透明图。所有图保留原始像素，没有程序修图、自动裁切或反复重生成。其余图个别全透明像素可保留RGB或极低alpha，最终合成/导入边缘仍按运行场景检查。

`view35`仅表示本轮生成目标。真实世界尺度、根点、遮挡和精确35°投影要在接入时测量，本轮不预先授予通过。用户已认可画风；本轮各成体的集中验收尚未代签。其他状态须等待这轮明确通过后另行制作。

技术清单：[manifest.json](../../../assets/farming/p109/source/manifest.json)。实际新增请求：[prompts.json](../../../assets/farming/p109/source/prompts.json)。钢绵羊原图已收到并归档，原始文件哈希`c25c55ff8b94184503a3bd37fc540fb83bdc738f82e87b392b2065af35850ca3`。后续事项为成体集中验收、需要的背景/根点/投影处理及运行接入，其他状态仍未启动。

