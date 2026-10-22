# P10.9 幼体形态修正交付

日期：2026-10-22。用户要求先提交当前更改，再按钢绵羊幼体v002规格生成其他动物幼体。已先创建本地提交`1458194`，随后使用内置image_gen逐物种生成16张正式源图。

[打开成体／幼体对照页](../../../assets/farming/p109/source/juveniles.html)。页面包含17对图片，支持浅草、深色、水色底和小图查看；可展开各物种实际幼体提示词。对照框用于检查头身与器官形态，尺寸不代表游戏内真实比例。

## 本轮范围

- 8种其余陆生动物、6种水生生物、蜜盏蜂与净水菌毯，共16张新图；加上此前钢绵羊v002，17种养殖条目均有幼体图。
- 已有旧幼体的10种使用v002保存；原先缺图的6种使用v001。旧文件和原提示词都保留在版本记录中。
- 不依赖“成体60%缩放”表现年龄，改用大头短吻、角芽/鳞芽、未矿化幼壳、鱼苗短鳍、昆虫幼虫和初生培养群体等具体形态。
- 本轮每项生成一次，无额外候选。完整实际请求、引用成体图、输出路径及SHA256见[请求记录](../../../assets/farming/p109/source/juvenile_revision_requests.json)；钢绵羊单独记录见[规格提示词](../../../assets/farming/p109/source/animals/steel_sheep/steel_sheep_juvenile_v002_prompt.json)。

## 逐项对照

| 对象 | 当前幼体 | 年龄差异与复核点 |
| --- | --- | --- |
| 钢绵羊 `steel_sheep` | [v002](../../../assets/farming/p109/source/animals/steel_sheep/steel_sheep_juvenile_view35_v002.png) | 短角芽、大头短吻、较轻的身架；作为本轮幼体规格参考。 |
| 啮岩鼹 `rock_mole` | [v002](../../../assets/farming/p109/source/animals/rock_mole/rock_mole_juvenile_view35_v002.png) | 较圆的头与短吻、较小的矿石掘爪。 |
| 岩腹兽 `rock_belly_beast` | [v002](../../../assets/farming/p109/source/animals/rock_belly_beast/rock_belly_beast_juvenile_view35_v002.png) | 较大的圆头与眼，胸腹岩片减少。 |
| 矿鳞蜥 `mineral_scale_lizard` | [v002](../../../assets/farming/p109/source/animals/mineral_scale_lizard/mineral_scale_lizard_juvenile_view35_v002.png) | 大头大眼、短吻，成年背部大片鳞减少；头部鳞片仍偏密，需重点复核。 |
| 堆肥鼠 `compost_mouse` | [v002](../../../assets/farming/p109/source/animals/compost_mouse/compost_mouse_juvenile_view35_v002.png) | 较大头眼、细嫩小脚，背部叶形毛簇减少。 |
| 露壳蜗牛 `dew_shell_snail` | [v002](../../../assets/farming/p109/source/animals/dew_shell_snail/dew_shell_snail_juvenile_view35_v002.png) | 短触角、较轻薄的壳，露珠减少；并排检查壳体成熟度。 |
| 砾甲蜗牛 `gravel_shell_snail` | [v002](../../../assets/farming/p109/source/animals/gravel_shell_snail/gravel_shell_snail_juvenile_view35_v002.png) | 大部分幼壳未矿化，仅保留少量砂砾。 |
| 炭腹虫 `carbon_belly_bug` | [v002](../../../assets/farming/p109/source/animals/carbon_belly_bug/carbon_belly_bug_juvenile_view35_v002.png) | 采用C形分节幼虫轮廓，取消成虫完整鞘翅。 |
| 叶丝蚕 `leaf_silkworm` | [v002](../../../assets/farming/p109/source/animals/leaf_silkworm/leaf_silkworm_juvenile_view35_v002.png) | 单只幼蚕、减少叶状背饰；游戏成熟生产形态仍为蚕体。 |
| 滤藻鲤 `filter_algae_carp` | [v002](../../../assets/farming/p109/source/aquatic/filter_algae_carp/filter_algae_carp_juvenile_view35_v002.png) | 较大眼、纤细鱼苗体态、无成年长须，鳍尾缩短。 |
| 油鳍鱼 `oilfin_fish` | [v002](../../../assets/farming/p109/source/aquatic/oilfin_fish/oilfin_fish_juvenile_view35_v002.png) | 鱼苗体态与较短鳍，保留局部细金色油脂带。 |
| 净泥鳅 `silt_loach` | [v001](../../../assets/farming/p109/source/aquatic/silt_loach/silt_loach_juvenile_view35_v001.png) | 较细的幼苗躯干与较大眼，须和鳍较短。 |
| 珍珠蚌 `pearl_mussel` | [v001](../../../assets/farming/p109/source/aquatic/pearl_mussel/pearl_mussel_juvenile_view35_v001.png) | 薄幼壳与稀疏生长纹，未出现成熟珍珠。 |
| 凝胶水母 `gel_jellyfish` | [v001](../../../assets/farming/p109/source/aquatic/gel_jellyfish/gel_jellyfish_juvenile_view35_v001.png) | 浅碟状幼水母，伞体较薄，触腕较短。 |
| 礁骨珊瑚 `reef_coral` | [v001](../../../assets/farming/p109/source/aquatic/reef_coral/reef_coral_juvenile_view35_v001.png) | 初生骨芽群体，分枝数量和高度减少。 |
| 蜜盏蜂 `bell_bee` | [v001](../../../assets/farming/p109/source/living/bell_bee/bell_bee_juvenile_view35_v001.png) | 无翅、无成蜂长腿的蜂幼虫。 |
| 净水菌毯 `purifying_mat` | [v001](../../../assets/farming/p109/source/living/purifying_mat/purifying_mat_juvenile_view35_v001.png) | 薄而稀疏的菌丝斑块，留有透空间隙。 |

## 文件检查与当前状态

核对了当前生产配置中的17个养殖ID与幼体清单，完整覆盖，无重复ID。16张新图均为RGBA且含透明背景，逐一核对了文件SHA256、尺寸和主要主体边界，主要轮廓未贴住画布边缘。另以浅草底对矿鳞蜥做实际alpha合成预览，合成后主体外背景正常；原图像素未作程序修改。

新一批已出图，等待用户视觉验收。对照页明确列出器官发育复核点，尤其矿鳞蜥头部仍保留较密鳞片、露壳蜗牛需并排检查壳体成熟度，不能仅凭“幼体”文件名宣布所有形态完全通过。精确35度投影、根点与游戏显示比例仍由接入阶段校准。

所有生长源图当前共有48个状态：植物前三阶段30张、油籽花期1张和17种养殖幼体；加上已验收27项成体，当前有效源图75张，另保留11张历史幼体，共86个PNG。此统计是源图覆盖情况。植物阶段尚未集中视觉验收；本轮未新增植物阶段，建筑继续推迟，运行时纹理未替换。
