# 灵田P8 · 百科全书

本手册由 `tools/farming/export_encyclopedia.gd` 从游戏内同一份百科内容层（`content/farming/baked/encyclopedia/`）导出，与游戏内“手册 → 百科目录”阅读的内容一致；百科格式版本 1。数值与条件以当前P8注册表为准，不混入历史版本内容。

使用提示：先按分类目录查找条目；材料页的“获取来源/直接用途”逐条给出数量、执行设施或物种、研究门槛、时间与AP，链接可跳到对应条目。以下易混淆口径在“基础玩法”规则中有完整说明：完工与成熟不等于入仓；成熟待收作物照常扣水肥；缺水低肥只降速不停滞（每日最低1点）；研究与养殖按“有效日”推进而非自然日；在制与待收产物不能出售；订单数量按供养值计算。

## 目录

- **作物与种植（8）**：[速生杉](#速生杉-cropfast_fir)、[金穗麦](#金穗麦-cropgolden_wheat)、[蜜铃灌木](#蜜铃灌木-crophoneybell_bush)、[果桑树](#果桑树-cropmulberry_tree)、[油籽花](#油籽花-cropoilseed_flower)、[青牧草](#青牧草-croppasture_grass)、[松脂树](#松脂树-cropresin_tree)、[木腐菇](#木腐菇-cropwood_decay_mushroom)
- **养殖与培养（17）**：[蜜盏蜂](#蜜盏蜂-speciesbell_bee)、[炭腹虫](#炭腹虫-speciescarbon_belly_bug)、[堆肥鼠](#堆肥鼠-speciescompost_mouse)、[露壳蜗牛](#露壳蜗牛-speciesdew_shell_snail)、[滤藻鲤](#滤藻鲤-speciesfilter_algae_carp)、[凝胶水母](#凝胶水母-speciesgel_jellyfish)、[砾甲蜗牛](#砾甲蜗牛-speciesgravel_shell_snail)、[叶丝蚕](#叶丝蚕-speciesleaf_silkworm)、[矿鳞蜥](#矿鳞蜥-speciesmineral_scale_lizard)、[油鳍鱼](#油鳍鱼-speciesoilfin_fish)、[珍珠蚌](#珍珠蚌-speciespearl_mussel)、[净水菌毯](#净水菌毯-speciespurifying_mat)、[礁骨珊瑚](#礁骨珊瑚-speciesreef_coral)、[岩腹兽](#岩腹兽-speciesrock_belly_beast)、[啮岩鼹](#啮岩鼹-speciesrock_mole)、[净泥鳅](#净泥鳅-speciessilt_loach)、[钢绵羊](#钢绵羊-speciessteel_sheep)
- **建筑与设施（39）**：[藻类培养槽](#藻类培养槽-facilityalgae_tank)、[水生种植台](#水生种植台-facilityaquatic_crop_station)、[蜂箱](#蜂箱-facilitybee_hive)、[炭化巢](#炭化巢-facilitycarbonization_nest)、[照料台](#照料台-facilitycare_table)、[捕鲤台](#捕鲤台-facilitycarp_harvest_station)、[炭化炉](#炭化炉-facilitychar_kiln)、[堆肥箱](#堆肥箱-facilitycompost_bin)、[翻肥窝](#翻肥窝-facilitycompost_mouse_den)、[采礁台](#采礁台-facilitycoral_station)、[调度站](#调度站-facilitydispatch_station)、[农产加工台](#农产加工台-facilityfarm_processor)、[供食槽](#供食槽-facilityfeed_trough)、[田间维护站](#田间维护站-facilityfield_service_station)、[水场](#水场-facilityfish_pond)、[采胶台](#采胶台-facilitygel_station)、[补光灯](#补光灯-facilitygrowth_lamp)、[厨房](#厨房-facilitykitchen)、[大床](#大床-facilitylarge_bed)、[中床](#中床-facilitymedium_bed)、[取油台](#取油台-facilityoilfish_harvest_station)、[选矿场](#选矿场-facilityore_sorting_yard)、[采珠台](#采珠台-facilitypearl_station)、[圈舍](#圈舍-facilitypen)、[净水菌床](#净水菌床-facilitypurifying_bed)、[研究台](#研究台-facilityresearch_bench)、[碎岩场](#碎岩场-facilityrock_breaking_yard)、[养鳞台](#养鳞台-facilityscale_station)、[岩壳成型台](#岩壳成型台-facilityshell_forming_station)、[蚕架](#蚕架-facilitysilkworm_rack)、[泥料处理台](#泥料处理台-facilitysilt_processing_station)、[小床](#小床-facilitysmall_bed)、[小型冶炼炉](#小型冶炼炉-facilitysmelter)、[安抚台](#安抚台-facilitysoothing_station)、[集露台](#集露台-facilityspirit_liquid_collector)、[玩具站](#玩具站-facilitytoy_station)、[换水站](#换水站-facilitywater_change_station)、[木工台](#木工台-facilitywoodshop)、[采毛台](#采毛台-facilitywool_station)
- **后勤蛊与协同（9）**：[明光蛊](#明光蛊-gubright_gu)、[驭兽蛊](#驭兽蛊-gucommand_gu)、[节肥蛊](#节肥蛊-gufert_gu)、[催生蛊](#催生蛊-gugrowth_gu)、[饭袋草蛊](#饭袋草蛊-gurice_bag_gu)、[安抚蛊](#安抚蛊-gusoothe_gu)、[宙道研究蛊](#宙道研究蛊-gutime_gu)、[锁水蛊](#锁水蛊-guwater_gu)、[智道研究蛊](#智道研究蛊-guwisdom_gu)
- **材料与物品（78）**：[藻料](#藻料-resourcealgae_feed)、[蜂蜡](#蜂蜡-resourcebeeswax)、[木炭](#木炭-resourcecharcoal)、[清水](#清水-resourceclean_water)、[复合石板](#复合石板-resourcecomposite_stone_panel)、[珊瑚石](#珊瑚石-resourcecoral_stone)、[粗油](#粗油-resourcecrude_oil)、[碎铁矿](#碎铁矿-resourcecrushed_ore)、[高密度藻料](#高密度藻料-resourcedense_algae)、[藻露羹](#藻露羹-resourcedew_soup)、[腐土菌丸](#腐土菌丸-resourceearth_pill)、[速生杉苗](#速生杉苗-resourcefast_fir_seed)、[炭砂滤料](#炭砂滤料-resourcefilter_media)、[蜜油火膏](#蜜油火膏-resourcefire_paste)、[鱼粪](#鱼粪-resourcefish_manure)、[鱼肉](#鱼肉-resourcefish_meat)、[菌鱼灵膳](#菌鱼灵膳-resourcefish_spirit_meal)、[花瓣](#花瓣-resourceflower_petal)、[牧草](#牧草-resourcefodder_grass)、[蜜炼金食](#蜜炼金食-resourcegold_food)、[金穗麦种子](#金穗麦种子-resourcegolden_wheat_seed)、[谷粒](#谷粒-resourcegrain)、[谷粉](#谷粉-resourcegrain_meal)、[草粉](#草粉-resourcegrass_meal)、[草籽](#草籽-resourcegrass_seed)、[砂砾](#砂砾-resourcegravel)、[蜂蜜](#蜂蜜-resourcehoney)、[蜜谷灵饼](#蜜谷灵饼-resourcehoney_cake)、[蜜铃苗](#蜜铃苗-resourcehoneybell_seed)、[腐殖土](#腐殖土-resourcehumus)、[铁锭](#铁锭-resourceiron_ingot)、[含铁矿石](#含铁矿石-resourceiron_ore)、[复合陆养料](#复合陆养料-resourceland_feed)、[矿质补料](#矿质补料-resourcemineral_feed)、[矿质鳞片](#矿质鳞片-resourcemineral_scale)、[黏液](#黏液-resourcemucus)、[桑叶](#桑叶-resourcemulberry_leaf)、[果桑种苗](#果桑种苗-resourcemulberry_seed)、[木腐菇](#木腐菇-resourcemushroom)、[贝壳](#贝壳-resourcemussel_shell)、[花蜜](#花蜜-resourcenectar)、[营养液](#营养液-resourcenutrient_liquid)、[油饼](#油饼-resourceoil_cake)、[油籽](#油籽-resourceoilseed)、[油籽花种子](#油籽花种子-resourceoilseed_flower_seed)、[富集矿砂](#富集矿砂-resourceore_concentrate)、[珍珠](#珍珠-resourcepearl)、[花粉](#花粉-resourcepollen)、[净水菌毯培养单位](#净水菌毯培养单位-resourcepurifying_mat_culture)、[普通岩石](#普通岩石-resourceraw_stone)、[原木](#原木-resourceraw_wood)、[再生填料](#再生填料-resourcereclaimed_fill)、[精炼油](#精炼油-resourcerefined_oil)、[精炼蜡](#精炼蜡-resourcerefined_wax)、[松脂](#松脂-resourceresin)、[松脂树苗](#松脂树苗-resourceresin_tree_seed)、[稻米](#稻米-resourcerice)、[岩壳片](#岩壳片-resourcerock_shell)、[蜕皮](#蜕皮-resourceshed_skin)、[羊粪肥](#羊粪肥-resourcesheep_manure)、[蚕丝](#蚕丝-resourcesilk)、[炉渣](#炉渣-resourceslag)、[污泥](#污泥-resourcesludge)、[废滤炭](#废滤炭-resourcespent_filter)、[灵液](#灵液-resourcespirit_liquid)、[钢绒](#钢绒-resourcesteel_wool)、[石粉](#石粉-resourcestone_powder)、[秸秆](#秸秆-resourcestraw)、[尾砂](#尾砂-resourcetailings)、[宙道食料](#宙道食料-resourcetime_feed)、[枝条](#枝条-resourcetwig)、[藤球](#藤球-resourcevine_ball)、[污水](#污水-resourcewastewater)、[复合水养料](#复合水养料-resourcewater_feed)、[凝水胶](#凝水胶-resourcewater_gel)、[木屑](#木屑-resourcewood_chip)、[木腐菇菌种](#木腐菇菌种-resourcewood_decay_spawn)、[木板](#木板-resourcewood_plank)
- **配方与食谱（97）**：[蜜盏蜂·花源份额＋清水](#蜜盏蜂花源份额清水-dietbell_beebase_dietsflower_share)、[蜜盏蜂·酿蜜周期](#蜜盏蜂酿蜜周期-dietbell_beespecial_dietshoney_cycle)、[炭腹虫·牧草清水餐](#炭腹虫牧草清水餐-dietcarbon_belly_bugbase_dietsgrass_water_meal)、[炭腹虫·木屑炭化轮](#炭腹虫木屑炭化轮-dietcarbon_belly_bugspecial_dietsbug_char_chips)、[炭腹虫·树枝炭化轮](#炭腹虫树枝炭化轮-dietcarbon_belly_bugspecial_dietsbug_char_twigs)、[堆肥鼠·牧草清水餐](#堆肥鼠牧草清水餐-dietcompost_mousebase_dietsgrass_water_meal)、[堆肥鼠·秸秆堆肥轮](#堆肥鼠秸秆堆肥轮-dietcompost_mousespecial_dietsmouse_compost_fiber)、[堆肥鼠·残料堆肥轮](#堆肥鼠残料堆肥轮-dietcompost_mousespecial_dietsmouse_compost_residue)、[露壳蜗牛·牧草清水餐](#露壳蜗牛牧草清水餐-dietdew_shell_snailbase_dietsgrass_water_meal)、[露壳蜗牛·灵液采集轮](#露壳蜗牛灵液采集轮-dietdew_shell_snailspecial_dietsdew_round)、[滤藻鲤·藻料餐](#滤藻鲤藻料餐-dietfilter_algae_carpbase_dietsalgae_meal)、[滤藻鲤·高密度藻餐](#滤藻鲤高密度藻餐-dietfilter_algae_carpbase_dietsdense_meal)、[滤藻鲤·水养复合餐](#滤藻鲤水养复合餐-dietfilter_algae_carpbase_dietswater_meal)、[滤藻鲤·谷粒育肥](#滤藻鲤谷粒育肥-dietfilter_algae_carpspecial_dietsgrain_fatten)、[凝胶水母·藻料餐](#凝胶水母藻料餐-dietgel_jellyfishbase_dietsalgae_meal)、[凝胶水母·高密度藻餐](#凝胶水母高密度藻餐-dietgel_jellyfishbase_dietsdense_meal)、[凝胶水母·采胶轮投料](#凝胶水母采胶轮投料-dietgel_jellyfishspecial_dietsgel_water_round)、[砾甲蜗牛·藻料清水餐](#砾甲蜗牛藻料清水餐-dietgravel_shell_snailbase_dietsalgae_water_meal)、[砾甲蜗牛·岩壳成型轮](#砾甲蜗牛岩壳成型轮-dietgravel_shell_snailspecial_dietsform_rock_shell)、[叶丝蚕·桑叶清水餐](#叶丝蚕桑叶清水餐-dietleaf_silkwormbase_dietsmulberry_meal)、[叶丝蚕·产丝轮](#叶丝蚕产丝轮-dietleaf_silkwormspecial_dietssilk_round)、[矿鳞蜥·牧草清水餐](#矿鳞蜥牧草清水餐-dietmineral_scale_lizardbase_dietsgrass_water_meal)、[矿鳞蜥·陆养复合餐](#矿鳞蜥陆养复合餐-dietmineral_scale_lizardbase_dietsland_meal)、[矿鳞蜥·养鳞轮](#矿鳞蜥养鳞轮-dietmineral_scale_lizardspecial_dietsscale_round)、[油鳍鱼·藻料餐](#油鳍鱼藻料餐-dietoilfin_fishbase_dietsalgae_meal)、[油鳍鱼·水养复合餐](#油鳍鱼水养复合餐-dietoilfin_fishbase_dietswater_meal)、[油鳍鱼·取油轮投料](#油鳍鱼取油轮投料-dietoilfin_fishspecial_dietsoilfin_oil_round)、[珍珠蚌·藻料餐](#珍珠蚌藻料餐-dietpearl_musselbase_dietsalgae_meal)、[珍珠蚌·育珠轮投料](#珍珠蚌育珠轮投料-dietpearl_musselspecial_dietspearl_powder_round)、[净水菌毯·培养清水](#净水菌毯培养清水-dietpurifying_matbase_dietsculture_water)、[净水菌毯·菌毯净水运行](#净水菌毯菌毯净水运行-dietpurifying_matspecial_dietsbio_purify)、[净水菌毯·营养液回收运行](#净水菌毯营养液回收运行-dietpurifying_matspecial_dietsrecover_nutrients)、[礁骨珊瑚·藻料餐](#礁骨珊瑚藻料餐-dietreef_coralbase_dietsalgae_meal)、[礁骨珊瑚·采礁轮投料](#礁骨珊瑚采礁轮投料-dietreef_coralspecial_dietscoral_mineral_round)、[岩腹兽·牧草清水餐](#岩腹兽牧草清水餐-dietrock_belly_beastbase_dietsgrass_water_meal)、[岩腹兽·陆养复合餐](#岩腹兽陆养复合餐-dietrock_belly_beastbase_dietsland_meal)、[岩腹兽·生物选矿轮](#岩腹兽生物选矿轮-dietrock_belly_beastspecial_dietsconcentrate_ore)、[啮岩鼹·菌菇清水餐](#啮岩鼹菌菇清水餐-dietrock_molebase_dietsfungus_meal)、[啮岩鼹·破碎矿石轮](#啮岩鼹破碎矿石轮-dietrock_molespecial_dietsbreak_ore)、[啮岩鼹·破碎石材轮](#啮岩鼹破碎石材轮-dietrock_molespecial_dietsbreak_stone)、[净泥鳅·藻料餐](#净泥鳅藻料餐-dietsilt_loachbase_dietsalgae_meal)、[钢绵羊·谷粒餐](#钢绵羊谷粒餐-dietsteel_sheepbase_dietsgrain_meal)、[钢绵羊·牧草餐](#钢绵羊牧草餐-dietsteel_sheepbase_dietsgrass_meal)、[钢绵羊·陆养复合餐](#钢绵羊陆养复合餐-dietsteel_sheepbase_dietsland_meal)、[钢绵羊·含铁补料](#钢绵羊含铁补料-dietsteel_sheepspecial_dietsiron_supplement)、[钢绵羊·矿质补料餐](#钢绵羊矿质补料餐-dietsteel_sheepspecial_dietsmineral_supplement)、[藻露羹熬制](#藻露羹熬制-recipealgae_dew_soup)、[黏液复合石板](#黏液复合石板-recipeassemble_mucus_panel)、[鳞甲复合板](#鳞甲复合板-recipeassemble_scale_panel)、[岩壳石板](#岩壳石板-recipeassemble_shell_panel)、[复合石板组装](#复合石板组装-recipeassemble_stone_panel)、[菌毯净水](#菌毯净水-recipebio_purify)、[陆养料调配](#陆养料调配-recipeblend_land_feed)、[水养料调配](#水养料调配-recipeblend_water_feed)、[破碎矿石](#破碎矿石-recipebreak_ore)、[破碎石材](#破碎石材-recipebreak_stone)、[木屑生物炭化](#木屑生物炭化-recipebug_char_chips)、[树枝生物炭化](#树枝生物炭化-recipebug_char_twigs)、[枝条炭化](#枝条炭化-recipechar_twigs)、[木屑堆肥](#木屑堆肥-recipecompost_chips)、[鱼粪堆肥](#鱼粪堆肥-recipecompost_fish_manure)、[牧草堆肥](#牧草堆肥-recipecompost_grass)、[油饼堆肥](#油饼堆肥-recipecompost_oil_cake)、[羊粪堆肥](#羊粪堆肥-recipecompost_sheep_manure)、[污泥堆肥](#污泥堆肥-recipecompost_sludge)、[废滤炭堆肥](#废滤炭堆肥-recipecompost_spent_filter)、[秸秆堆肥](#秸秆堆肥-recipecompost_straw)、[枝条堆肥](#枝条堆肥-recipecompost_twigs)、[生物选矿](#生物选矿-recipeconcentrate_ore)、[藻料培养](#藻料培养-recipeculture_algae)、[高密度藻培养](#高密度藻培养-recipedense_algae_culture)、[岩壳成型](#岩壳成型-recipeform_rock_shell)、[菌鱼灵膳烹制](#菌鱼灵膳烹制-recipefungus_fish_meal)、[蜜谷灵饼烘焙](#蜜谷灵饼烘焙-recipehoney_grain_cake)、[蜜炼金食炼制](#蜜炼金食炼制-recipehoney_mineral_food)、[炭砂滤料制作](#炭砂滤料制作-recipemake_filter_media)、[丝质滤材](#丝质滤材-recipemake_silk_filter_media)、[make_vine_ball](#make_vine_ball-recipemake_vine_ball)、[谷粉研磨](#谷粉研磨-recipemill_grain)、[草粉研磨](#草粉研磨-recipemill_grass)、[稻米磨粉](#稻米磨粉-recipemill_rice)、[矿质补料调配](#矿质补料调配-recipemineral_feed)、[秸秆翻肥](#秸秆翻肥-recipemouse_compost_fiber)、[残料翻肥](#残料翻肥-recipemouse_compost_residue)、[蜜油火膏熬制](#蜜油火膏熬制-recipeoil_honey_paste)、[油籽榨油](#油籽榨油-recipepress_oilseed)、[再生填料回收](#再生填料回收-reciperecover_fill)、[营养液回收](#营养液回收-reciperecover_nutrients)、[油脂精炼](#油脂精炼-reciperefine_oil)、[蜂蜡精炼](#蜂蜡精炼-reciperefine_wax)、[锯切木板](#锯切木板-recipesaw_planks)、[枝条粉碎](#枝条粉碎-recipeshred_twigs)、[原木粉碎](#原木粉碎-recipeshred_wood)、[木炭冶炼](#木炭冶炼-recipesmelt_charcoal)、[富集矿冶炼](#富集矿冶炼-recipesmelt_concentrate)、[松脂冶炼](#松脂冶炼-recipesmelt_resin)、[腐土菌丸炼制](#腐土菌丸炼制-recipesoil_spirit_pill)
- **研究与科技（12）**：[饲料与蜡油精制](#饲料与蜡油精制-researchadvanced_feed_oil_wax)、[灵食初制](#灵食初制-researchbasic_spirit_cooking)、[蜂群协作](#蜂群协作-researchbeekeeping)、[菌毯净化](#菌毯净化-researchbiofiltration)、[复合灵食](#复合灵食-researchcomposite_spirit_food)、[农产初加工](#农产初加工-researchfarm_preparation)、[田间自动维护](#田间自动维护-researchfield_maintenance)、[花源栽培](#花源栽培-researchflower_cultivation)、[矿质材料工艺](#矿质材料工艺-researchmineral_materials)、[生物选矿](#生物选矿-researchore_concentration)、[岩料破碎](#岩料破碎-researchrock_handling)、[水与藻料回流](#水与藻料回流-researchwater_recirculation)
- **资源点与环境（10）**：[灵田·水库](#灵田水库-mapfarm_02)、[东侧远田](#东侧远田-parceleast_far)、[东侧下田](#东侧下田-parceleast_lower)、[东侧近田](#东侧近田-parceleast_near)、[东侧远岸水库](#东侧远岸水库-parceleast_water_far)、[东侧近岸水库](#东侧近岸水库-parceleast_water_near)、[西侧水库](#西侧水库-parcelwest_water)、[采矿点](#采矿点-sourceore_source)、[泉水点](#泉水点-sourcespring_source)、[采石点](#采石点-sourcestone_source)
- **基础玩法（19）**：[农业辅助蛊：定向服务区与效果决议](#农业辅助蛊定向服务区与效果决议-ruleagriculture)、[畜牧强化：安抚、役使与耐用玩具](#畜牧强化安抚役使与耐用玩具-ruleanimal-services)、[畜牧分区：九种陆生动物、三用途与八单位日程](#畜牧分区九种陆生动物三用途与八单位日程-ruleanimal-zones)、[持续生产与保留量](#持续生产与保留量-ruleauto_production)、[建材替代](#建材替代-rulebuild_substitute)、[作物生长速率公式](#作物生长速率公式-rulecrop_growth)、[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[环境值与有效光照](#环境值与有效光照-ruleenvironment)、[购地与连续地图](#购地与连续地图-ruleexpansion)、[花源份额](#花源份额-ruleflower_share)、[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)、[活体配方的双重注册](#活体配方的双重注册-ruleliving_mapping)、[后勤蛊部署、维护与生产协同](#后勤蛊部署维护与生产协同-rulelogistics)、[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)、[研究系统](#研究系统-ruleresearch)、[露天农业区：地板、育种与丰产](#露天农业区地板育种与丰产-rulerooms)、[存档与经济](#存档与经济-rulesave)、[雇工与统一调度器](#雇工与统一调度器-ruleworker_scheduler)

---

## 作物与种植（8）

### 速生杉 `crop:fast_fir`

仅可砍伐取材；首熟8日；原木×4＋枝条×4

| 字段 | 内容 |
|---|---|
| 种子/菌种 | 速生杉苗×1（播种时消耗；市集可购8元石/份） |
| 占地 | 2×2格（全部开垦且空闲才能播种） |
| 播种投入 | 速生杉苗×1，1AP |
| 采收模式 | 仅可砍伐取材，砍伐后需重播 |
| 首次成熟 | 8自然日（全适宜条件；实际时长按生长公式，见规则「作物生长速率公式」） |
| 光照偏好 | 80（与占格平均有效光照相差≤20为满速，否则光效50%） |
| 每日环境扣减 | 每格水分−3、肥力−1（成熟待收期间照扣） |
| 收获产物 | 原木×4＋枝条×4，1AP |
| 丰产主产物 | 砍伐：原木。仅本轮合格生长贡献参与25%增产，副产物不增加 |
| 育种回流 | 首次成熟仅判定一次；完整合格25%概率得速生杉苗×1，随首次成熟收取/成熟清理领取，留株不重抽 |

关联条目：种子：[速生杉苗](#速生杉苗-resourcefast_fir_seed)

相关规则：[作物生长速率公式](#作物生长速率公式-rulecrop_growth)、[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[环境值与有效光照](#环境值与有效光照-ruleenvironment)、[露天农业区：地板、育种与丰产](#露天农业区地板育种与丰产-rulerooms)

### 金穗麦 `crop:golden_wheat`

收获后植株移除；首熟4日；谷粒×3＋秸秆×2

| 字段 | 内容 |
|---|---|
| 种子/菌种 | 金穗麦种子×1（播种时消耗；市集可购3元石/份） |
| 占地 | 1×1格（全部开垦且空闲才能播种） |
| 播种投入 | 金穗麦种子×1，1AP |
| 采收模式 | 收获后植株移除，需重播 |
| 首次成熟 | 4自然日（全适宜条件；实际时长按生长公式，见规则「作物生长速率公式」） |
| 光照偏好 | 80（与占格平均有效光照相差≤20为满速，否则光效50%） |
| 每日环境扣减 | 每格水分−4、肥力−2（成熟待收期间照扣） |
| 收获产物 | 谷粒×3＋秸秆×2，1AP |
| 丰产主产物 | 采收：谷粒。仅本轮合格生长贡献参与25%增产，副产物不增加 |
| 育种回流 | 首次成熟仅判定一次；完整合格25%概率得金穗麦种子×1，随首次成熟收取/成熟清理领取，留株不重抽 |

关联条目：种子：[金穗麦种子](#金穗麦种子-resourcegolden_wheat_seed)

相关规则：[作物生长速率公式](#作物生长速率公式-rulecrop_growth)、[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[环境值与有效光照](#环境值与有效光照-ruleenvironment)、[露天农业区：地板、育种与丰产](#露天农业区地板育种与丰产-rulerooms)

### 蜜铃灌木 `crop:honeybell_bush`

可留株采收（按再生周期）或砍伐移除；首熟6日；花蜜×2＋花粉×1

> 解锁条件：需完成研究 [花源栽培](#花源栽培-researchflower_cultivation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 种子/菌种 | 蜜铃苗×1（播种时消耗；市集可购8元石/份） |
| 占地 | 1×1格（全部开垦且空闲才能播种） |
| 播种投入 | 蜜铃苗×1，1AP |
| 采收模式 | 可留株采收（按再生周期）或砍伐移除 |
| 首次成熟 | 6自然日（全适宜条件；实际时长按生长公式，见规则「作物生长速率公式」） |
| 光照偏好 | 80（与占格平均有效光照相差≤20为满速，否则光效50%） |
| 每日环境扣减 | 每格水分−3、肥力−1（成熟待收期间照扣） |
| 收获产物 | 花蜜×2＋花粉×1，1AP |
| 砍伐产物 | 枝条×1，1AP（砍伐移除植株） |
| 采后再生 | 留株采收后1日恢复可采 |
| 花期/花源 | 成熟期间每日可产1份额 |
| 丰产主产物 | 采收：花蜜；砍伐：枝条。仅本轮合格生长贡献参与25%增产，副产物不增加 |
| 育种回流 | 首次成熟仅判定一次；完整合格25%概率得蜜铃苗×1，随首次成熟收取/成熟清理领取，留株不重抽 |

关联条目：种子：[蜜铃苗](#蜜铃苗-resourcehoneybell_seed)；解锁研究：[花源栽培](#花源栽培-researchflower_cultivation)

相关规则：[作物生长速率公式](#作物生长速率公式-rulecrop_growth)、[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[环境值与有效光照](#环境值与有效光照-ruleenvironment)、[露天农业区：地板、育种与丰产](#露天农业区地板育种与丰产-rulerooms)

### 果桑树 `crop:mulberry_tree`

可留株采收（按再生周期）或砍伐移除；首熟6日；桑叶×10

| 字段 | 内容 |
|---|---|
| 种子/菌种 | 果桑种苗×1（播种时消耗；市集可购6元石/份） |
| 占地 | 2×2格（全部开垦且空闲才能播种） |
| 播种投入 | 果桑种苗×1，1AP |
| 采收模式 | 可留株采收（按再生周期）或砍伐移除 |
| 首次成熟 | 6自然日（全适宜条件；实际时长按生长公式，见规则「作物生长速率公式」） |
| 光照偏好 | 80（与占格平均有效光照相差≤20为满速，否则光效50%） |
| 每日环境扣减 | 每格水分−3、肥力−1（成熟待收期间照扣） |
| 收获产物 | 桑叶×10，1AP |
| 砍伐产物 | 原木×2＋枝条×2，1AP（砍伐移除植株） |
| 采后再生 | 留株采收后2日恢复可采 |
| 丰产主产物 | 采收：桑叶；砍伐：原木。仅本轮合格生长贡献参与25%增产，副产物不增加 |
| 育种回流 | 首次成熟仅判定一次；完整合格25%概率得果桑种苗×1，随首次成熟收取/成熟清理领取，留株不重抽 |

关联条目：种子：[果桑种苗](#果桑种苗-resourcemulberry_seed)

相关规则：[作物生长速率公式](#作物生长速率公式-rulecrop_growth)、[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[环境值与有效光照](#环境值与有效光照-ruleenvironment)、[露天农业区：地板、育种与丰产](#露天农业区地板育种与丰产-rulerooms)

### 油籽花 `crop:oilseed_flower`

收获后植株移除；首熟5日；油籽×4＋花瓣×1

> 解锁条件：需完成研究 [花源栽培](#花源栽培-researchflower_cultivation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 种子/菌种 | 油籽花种子×1（播种时消耗；市集可购4元石/份） |
| 占地 | 1×1格（全部开垦且空闲才能播种） |
| 播种投入 | 油籽花种子×1，1AP |
| 采收模式 | 收获后植株移除，需重播 |
| 首次成熟 | 5自然日（全适宜条件；实际时长按生长公式，见规则「作物生长速率公式」） |
| 光照偏好 | 80（与占格平均有效光照相差≤20为满速，否则光效50%） |
| 每日环境扣减 | 每格水分−4、肥力−2（成熟待收期间照扣） |
| 收获产物 | 油籽×4＋花瓣×1，1AP |
| 花期/花源 | 生长进度300~499期间为花期（2日），每日期1份额 |
| 丰产主产物 | 采收：油籽。仅本轮合格生长贡献参与25%增产，副产物不增加 |
| 育种回流 | 首次成熟仅判定一次；完整合格25%概率得油籽花种子×1，随首次成熟收取/成熟清理领取，留株不重抽 |

关联条目：种子：[油籽花种子](#油籽花种子-resourceoilseed_flower_seed)；解锁研究：[花源栽培](#花源栽培-researchflower_cultivation)

相关规则：[作物生长速率公式](#作物生长速率公式-rulecrop_growth)、[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[环境值与有效光照](#环境值与有效光照-ruleenvironment)、[露天农业区：地板、育种与丰产](#露天农业区地板育种与丰产-rulerooms)

### 青牧草 `crop:pasture_grass`

收获后植株移除；首熟3日；牧草×3

| 字段 | 内容 |
|---|---|
| 种子/菌种 | 草籽×1（播种时消耗；市集可购2元石/份） |
| 占地 | 1×1格（全部开垦且空闲才能播种） |
| 播种投入 | 草籽×1，1AP |
| 采收模式 | 收获后植株移除，需重播 |
| 首次成熟 | 3自然日（全适宜条件；实际时长按生长公式，见规则「作物生长速率公式」） |
| 光照偏好 | 80（与占格平均有效光照相差≤20为满速，否则光效50%） |
| 每日环境扣减 | 每格水分−3、肥力−1（成熟待收期间照扣） |
| 收获产物 | 牧草×3，1AP |
| 丰产主产物 | 采收：牧草。仅本轮合格生长贡献参与25%增产，副产物不增加 |
| 育种回流 | 首次成熟仅判定一次；完整合格25%概率得草籽×1，随首次成熟收取/成熟清理领取，留株不重抽 |

关联条目：种子：[草籽](#草籽-resourcegrass_seed)

相关规则：[作物生长速率公式](#作物生长速率公式-rulecrop_growth)、[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[环境值与有效光照](#环境值与有效光照-ruleenvironment)、[露天农业区：地板、育种与丰产](#露天农业区地板育种与丰产-rulerooms)

### 松脂树 `crop:resin_tree`

可留株采收（按再生周期）或砍伐移除；首熟8日；松脂×4

| 字段 | 内容 |
|---|---|
| 种子/菌种 | 松脂树苗×1（播种时消耗；市集可购10元石/份） |
| 占地 | 2×2格（全部开垦且空闲才能播种） |
| 播种投入 | 松脂树苗×1，1AP |
| 采收模式 | 可留株采收（按再生周期）或砍伐移除 |
| 首次成熟 | 8自然日（全适宜条件；实际时长按生长公式，见规则「作物生长速率公式」） |
| 光照偏好 | 80（与占格平均有效光照相差≤20为满速，否则光效50%） |
| 每日环境扣减 | 每格水分−3、肥力−1（成熟待收期间照扣） |
| 收获产物 | 松脂×4，1AP |
| 砍伐产物 | 原木×4＋枝条×3，1AP（砍伐移除植株） |
| 采后再生 | 留株采收后3日恢复可采 |
| 丰产主产物 | 采收：松脂；砍伐：原木。仅本轮合格生长贡献参与25%增产，副产物不增加 |
| 育种回流 | 首次成熟仅判定一次；完整合格25%概率得松脂树苗×1，随首次成熟收取/成熟清理领取，留株不重抽 |

关联条目：种子：[松脂树苗](#松脂树苗-resourceresin_tree_seed)

相关规则：[作物生长速率公式](#作物生长速率公式-rulecrop_growth)、[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[环境值与有效光照](#环境值与有效光照-ruleenvironment)、[露天农业区：地板、育种与丰产](#露天农业区地板育种与丰产-rulerooms)

### 木腐菇 `crop:wood_decay_mushroom`

每轮培养：收获后移除；首熟4日；木腐菇×3＋腐殖土×1

| 字段 | 内容 |
|---|---|
| 种子/菌种 | 木腐菇菌种×1（播种时消耗；市集可购3元石/份） |
| 占地 | 1×1格（全部开垦且空闲才能播种） |
| 播种投入 | 木屑×3＋清水×2＋木腐菇菌种×1，1AP |
| 采收模式 | 每轮培养：收获后移除，再种需重新投料 |
| 首次成熟 | 4自然日（全适宜条件；实际时长按生长公式，见规则「作物生长速率公式」） |
| 光照偏好 | 30（与占格平均有效光照相差≤20为满速，否则光效50%） |
| 每日环境扣减 | 每格水分−2、肥力−0（成熟待收期间照扣） |
| 收获产物 | 木腐菇×3＋腐殖土×1，1AP |
| 培养水润床 | 播种投入中的清水每份+30水分直接润床，不另算浇水 |
| 丰产主产物 | 采收：木腐菇。仅本轮合格生长贡献参与25%增产，副产物不增加 |
| 育种回流 | 首次成熟仅判定一次；完整合格25%概率得木腐菇菌种×1，随首次成熟收取/成熟清理领取，留株不重抽 |

关联条目：种子：[木腐菇菌种](#木腐菇菌种-resourcewood_decay_spawn)

相关规则：[作物生长速率公式](#作物生长速率公式-rulecrop_growth)、[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[环境值与有效光照](#环境值与有效光照-ruleenvironment)、[露天农业区：地板、育种与丰产](#露天农业区地板育种与丰产-rulerooms)


## 养殖与培养（17）

### 蜜盏蜂 `species:bell_bee`

蜂箱养殖；6元石/群；周期3日

> 解锁条件：需完成研究 [蜂群协作](#蜂群协作-researchbeekeeping)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 购入价格 | 6元石/群（0AP；购入即占容量，不可退回） |
| 计量单位 | 群 |
| 适配设施 | 蜂箱（容量4群；每场单物种） |
| 幼体成长 | 3有效服务日（当日有基础服务才推进） |
| 生产周期 | 3有效服务日/轮（特殊食谱启动） |
| 周期产物 | 蜂蜜×2＋蜂蜡×1/轮/群（收取时入仓） |
| 收取后去留 | 保留个体（回到空闲成体） |
| 花源依赖 | 每群每日基础服务消耗1份额（与手采共享）＋清水×1；份额来自覆盖外扩2格内的当日合格花株 |
| 授粉增益 | 蜂群使用油籽花份额后，该株本周期待收+1油籽；多箱/多次不叠加 |

关联条目：适配设施：[蜂箱](#蜂箱-facilitybee_hive)；解锁研究：[蜂群协作](#蜂群协作-researchbeekeeping)

相关规则：[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)、[雇工与统一调度器](#雇工与统一调度器-ruleworker_scheduler)

### 炭腹虫 `species:carbon_belly_bug`

炭化巢养殖；10元石/群；周期1日

> 解锁条件：需完成研究 [农产初加工](#农产初加工-researchfarm_preparation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 购入价格 | 10元石/群（0AP；购入即占容量，不可退回） |
| 计量单位 | 群 |
| 适配设施 | 炭化巢（容量4群；每场单物种） |
| 幼体成长 | 3有效服务日（当日有基础服务才推进） |
| 生产周期 | 1有效服务日/轮（特殊食谱启动） |
| 周期产物 | 木炭×4＋腐殖土×1/轮/群（收取时入仓） |
| 收取后去留 | 保留个体（回到空闲成体） |

关联条目：适配设施：[炭化巢](#炭化巢-facilitycarbonization_nest)；解锁研究：[农产初加工](#农产初加工-researchfarm_preparation)

相关规则：[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)、[雇工与统一调度器](#雇工与统一调度器-ruleworker_scheduler)

### 堆肥鼠 `species:compost_mouse`

翻肥窝养殖；8元石/只；周期1日

| 字段 | 内容 |
|---|---|
| 购入价格 | 8元石/只（0AP；购入即占容量，不可退回） |
| 计量单位 | 只 |
| 适配设施 | 翻肥窝（容量4只；每场单物种） |
| 幼体成长 | 3有效服务日（当日有基础服务才推进） |
| 生产周期 | 1有效服务日/轮（特殊食谱启动） |
| 周期产物 | 腐殖土×4/轮/只（收取时入仓） |
| 收取后去留 | 保留个体（回到空闲成体） |

关联条目：适配设施：[翻肥窝](#翻肥窝-facilitycompost_mouse_den)

相关规则：[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)、[雇工与统一调度器](#雇工与统一调度器-ruleworker_scheduler)

### 露壳蜗牛 `species:dew_shell_snail`

集露台养殖；10元石/只；周期2日

| 字段 | 内容 |
|---|---|
| 购入价格 | 10元石/只（0AP；购入即占容量，不可退回） |
| 计量单位 | 只 |
| 适配设施 | 集露台（容量4只；每场单物种） |
| 幼体成长 | 4有效服务日（当日有基础服务才推进） |
| 生产周期 | 2有效服务日/轮（特殊食谱启动） |
| 周期产物 | 灵液×2＋黏液×1/轮/只（收取时入仓） |
| 收取后去留 | 保留个体（回到空闲成体） |

关联条目：适配设施：[集露台](#集露台-facilityspirit_liquid_collector)

相关规则：[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)、[雇工与统一调度器](#雇工与统一调度器-ruleworker_scheduler)

### 滤藻鲤 `species:filter_algae_carp`

捕鲤台养殖；5元石/尾；周期2日

| 字段 | 内容 |
|---|---|
| 购入价格 | 5元石/尾（0AP；购入即占容量，不可退回） |
| 计量单位 | 尾 |
| 适配设施 | 捕鲤台（容量4尾；每场单物种） |
| 幼体成长 | 4有效服务日（当日有基础服务才推进） |
| 生产周期 | 2有效服务日/轮（特殊食谱启动） |
| 周期产物 | 鱼肉×3＋鱼粪×1/轮/尾（收取时入仓） |
| 收取后去留 | 移除个体，需重新购入 |
| 水体依赖 | 所属水体共享水质日降；低于30暂停成长与生产，换水或净化配套恢复 |

关联条目：适配设施：[捕鲤台](#捕鲤台-facilitycarp_harvest_station)

相关规则：[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)、[雇工与统一调度器](#雇工与统一调度器-ruleworker_scheduler)

### 凝胶水母 `species:gel_jellyfish`

采胶台养殖；12元石/群；周期2日

> 解锁条件：需完成研究 [水与藻料回流](#水与藻料回流-researchwater_recirculation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 购入价格 | 12元石/群（0AP；购入即占容量，不可退回） |
| 计量单位 | 群 |
| 适配设施 | 采胶台（容量4群；每场单物种） |
| 幼体成长 | 4有效服务日（当日有基础服务才推进） |
| 生产周期 | 2有效服务日/轮（特殊食谱启动） |
| 周期产物 | 凝水胶×2/轮/群（收取时入仓） |
| 收取后去留 | 保留个体（回到空闲成体） |

关联条目：适配设施：[采胶台](#采胶台-facilitygel_station)；解锁研究：[水与藻料回流](#水与藻料回流-researchwater_recirculation)

相关规则：[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)、[雇工与统一调度器](#雇工与统一调度器-ruleworker_scheduler)

### 砾甲蜗牛 `species:gravel_shell_snail`

岩壳成型台养殖；14元石/只；周期1日

> 解锁条件：需完成研究 [矿质材料工艺](#矿质材料工艺-researchmineral_materials)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 购入价格 | 14元石/只（0AP；购入即占容量，不可退回） |
| 计量单位 | 只 |
| 适配设施 | 岩壳成型台（容量4只；每场单物种） |
| 幼体成长 | 5有效服务日（当日有基础服务才推进） |
| 生产周期 | 1有效服务日/轮（特殊食谱启动） |
| 周期产物 | 岩壳片×2＋黏液×1/轮/只（收取时入仓） |
| 收取后去留 | 保留个体（回到空闲成体） |

关联条目：适配设施：[岩壳成型台](#岩壳成型台-facilityshell_forming_station)；解锁研究：[矿质材料工艺](#矿质材料工艺-researchmineral_materials)

相关规则：[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)、[雇工与统一调度器](#雇工与统一调度器-ruleworker_scheduler)

### 叶丝蚕 `species:leaf_silkworm`

蚕架养殖；8元石/群；周期2日

| 字段 | 内容 |
|---|---|
| 购入价格 | 8元石/群（0AP；购入即占容量，不可退回） |
| 计量单位 | 群 |
| 适配设施 | 蚕架（容量4群；每场单物种） |
| 幼体成长 | 3有效服务日（当日有基础服务才推进） |
| 生产周期 | 2有效服务日/轮（特殊食谱启动） |
| 周期产物 | 蚕丝×4/轮/群（收取时入仓） |
| 收取后去留 | 保留个体（回到空闲成体） |

关联条目：适配设施：[蚕架](#蚕架-facilitysilkworm_rack)

相关规则：[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)、[雇工与统一调度器](#雇工与统一调度器-ruleworker_scheduler)

### 矿鳞蜥 `species:mineral_scale_lizard`

养鳞台养殖；18元石/只；周期4日

> 解锁条件：需完成研究 [矿质材料工艺](#矿质材料工艺-researchmineral_materials)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 购入价格 | 18元石/只（0AP；购入即占容量，不可退回） |
| 计量单位 | 只 |
| 适配设施 | 养鳞台（容量4只；每场单物种） |
| 幼体成长 | 6有效服务日（当日有基础服务才推进） |
| 生产周期 | 4有效服务日/轮（特殊食谱启动） |
| 周期产物 | 矿质鳞片×2＋蜕皮×1/轮/只（收取时入仓） |
| 收取后去留 | 保留个体（回到空闲成体） |

关联条目：适配设施：[养鳞台](#养鳞台-facilityscale_station)；解锁研究：[矿质材料工艺](#矿质材料工艺-researchmineral_materials)

相关规则：[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)、[雇工与统一调度器](#雇工与统一调度器-ruleworker_scheduler)

### 油鳍鱼 `species:oilfin_fish`

取油台养殖；10元石/尾；周期3日

> 解锁条件：需完成研究 [农产初加工](#农产初加工-researchfarm_preparation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 购入价格 | 10元石/尾（0AP；购入即占容量，不可退回） |
| 计量单位 | 尾 |
| 适配设施 | 取油台（容量4尾；每场单物种） |
| 幼体成长 | 5有效服务日（当日有基础服务才推进） |
| 生产周期 | 3有效服务日/轮（特殊食谱启动） |
| 周期产物 | 粗油×2＋鱼肉×1/轮/尾（收取时入仓） |
| 收取后去留 | 移除个体，需重新购入 |

关联条目：适配设施：[取油台](#取油台-facilityoilfish_harvest_station)；解锁研究：[农产初加工](#农产初加工-researchfarm_preparation)

相关规则：[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)、[雇工与统一调度器](#雇工与统一调度器-ruleworker_scheduler)

### 珍珠蚌 `species:pearl_mussel`

采珠台养殖；12元石/只；周期4日

> 解锁条件：需完成研究 [水与藻料回流](#水与藻料回流-researchwater_recirculation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 购入价格 | 12元石/只（0AP；购入即占容量，不可退回） |
| 计量单位 | 只 |
| 适配设施 | 采珠台（容量4只；每场单物种） |
| 幼体成长 | 6有效服务日（当日有基础服务才推进） |
| 生产周期 | 4有效服务日/轮（特殊食谱启动） |
| 周期产物 | 珍珠×2/轮/只（收取时入仓） |
| 收取后去留 | 保留个体（回到空闲成体） |

关联条目：适配设施：[采珠台](#采珠台-facilitypearl_station)；解锁研究：[水与藻料回流](#水与藻料回流-researchwater_recirculation)

相关规则：[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)、[雇工与统一调度器](#雇工与统一调度器-ruleworker_scheduler)

### 净水菌毯 `species:purifying_mat`

净水菌床养殖；6元石/培养单位；周期2日

> 解锁条件：需完成研究 [菌毯净化](#菌毯净化-researchbiofiltration)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 购入价格 | 6元石/培养单位（0AP；购入即占容量，不可退回） |
| 计量单位 | 培养单位 |
| 适配设施 | 净水菌床（容量4培养单位；每场单物种） |
| 幼体成长 | 2有效服务日（当日有基础服务才推进） |
| 生产周期 | 2有效服务日/轮（特殊食谱启动） |
| 收取后去留 | 保留个体（回到空闲成体） |
| 培养规则 | 仅幼体每日耗培养清水×1；在制成体靠盖章服务日推进、不再耗基础料；空闲成体启动批次时一次付清处理投入 |

关联条目：适配设施：[净水菌床](#净水菌床-facilitypurifying_bed)；解锁研究：[菌毯净化](#菌毯净化-researchbiofiltration)

相关规则：[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)、[雇工与统一调度器](#雇工与统一调度器-ruleworker_scheduler)

### 礁骨珊瑚 `species:reef_coral`

采礁台养殖；14元石/群；周期6日

> 解锁条件：需完成研究 [矿质材料工艺](#矿质材料工艺-researchmineral_materials)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 购入价格 | 14元石/群（0AP；购入即占容量，不可退回） |
| 计量单位 | 群 |
| 适配设施 | 采礁台（容量4群；每场单物种） |
| 幼体成长 | 6有效服务日（当日有基础服务才推进） |
| 生产周期 | 6有效服务日/轮（特殊食谱启动） |
| 周期产物 | 珊瑚石×2/轮/群（收取时入仓） |
| 收取后去留 | 保留个体（回到空闲成体） |

关联条目：适配设施：[采礁台](#采礁台-facilitycoral_station)；解锁研究：[矿质材料工艺](#矿质材料工艺-researchmineral_materials)

相关规则：[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)、[雇工与统一调度器](#雇工与统一调度器-ruleworker_scheduler)

### 岩腹兽 `species:rock_belly_beast`

选矿场养殖；12元石/只；周期2日

> 解锁条件：需完成研究 [生物选矿](#生物选矿-researchore_concentration)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 购入价格 | 12元石/只（0AP；购入即占容量，不可退回） |
| 计量单位 | 只 |
| 适配设施 | 选矿场（容量4只；每场单物种） |
| 幼体成长 | 4有效服务日（当日有基础服务才推进） |
| 生产周期 | 2有效服务日/轮（特殊食谱启动） |
| 周期产物 | 富集矿砂×2＋尾砂×1/轮/只（收取时入仓） |
| 收取后去留 | 保留个体（回到空闲成体） |

关联条目：适配设施：[选矿场](#选矿场-facilityore_sorting_yard)；解锁研究：[生物选矿](#生物选矿-researchore_concentration)

相关规则：[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)、[雇工与统一调度器](#雇工与统一调度器-ruleworker_scheduler)

### 啮岩鼹 `species:rock_mole`

碎岩场养殖；8元石/只；周期1日

> 解锁条件：需完成研究 [岩料破碎](#岩料破碎-researchrock_handling)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 购入价格 | 8元石/只（0AP；购入即占容量，不可退回） |
| 计量单位 | 只 |
| 适配设施 | 碎岩场（容量4只；每场单物种） |
| 幼体成长 | 3有效服务日（当日有基础服务才推进） |
| 生产周期 | 1有效服务日/轮（特殊食谱启动） |
| 周期产物 | 砂砾×2＋石粉×1/轮/只（收取时入仓） |
| 收取后去留 | 保留个体（回到空闲成体） |

关联条目：适配设施：[碎岩场](#碎岩场-facilityrock_breaking_yard)；解锁研究：[岩料破碎](#岩料破碎-researchrock_handling)

相关规则：[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)、[雇工与统一调度器](#雇工与统一调度器-ruleworker_scheduler)

### 净泥鳅 `species:silt_loach`

泥料处理台养殖；8元石/尾；周期1日

> 解锁条件：需完成研究 [菌毯净化](#菌毯净化-researchbiofiltration)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 购入价格 | 8元石/尾（0AP；购入即占容量，不可退回） |
| 计量单位 | 尾 |
| 适配设施 | 泥料处理台（容量4尾；每场单物种） |
| 幼体成长 | 3有效服务日（当日有基础服务才推进） |
| 生产周期 | 1有效服务日/轮（特殊食谱启动） |
| 周期产物 | 腐殖土×3/轮/尾（收取时入仓） |
| 收取后去留 | 保留个体（回到空闲成体） |

关联条目：适配设施：[泥料处理台](#泥料处理台-facilitysilt_processing_station)；解锁研究：[菌毯净化](#菌毯净化-researchbiofiltration)

相关规则：[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)、[雇工与统一调度器](#雇工与统一调度器-ruleworker_scheduler)

### 钢绵羊 `species:steel_sheep`

圈舍养殖；12元石/只；周期3日

| 字段 | 内容 |
|---|---|
| 购入价格 | 12元石/只（0AP；购入即占容量，不可退回） |
| 计量单位 | 只 |
| 适配设施 | 圈舍（容量4只；每场单物种） |
| 幼体成长 | 6有效服务日（当日有基础服务才推进） |
| 生产周期 | 3有效服务日/轮（特殊食谱启动） |
| 周期产物 | 钢绒×1＋羊粪肥×1/轮/只（收取时入仓） |
| 收取后去留 | 保留个体（回到空闲成体） |

关联条目：适配设施：[圈舍](#圈舍-facilitypen)

相关规则：[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)、[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)、[雇工与统一调度器](#雇工与统一调度器-ruleworker_scheduler)


## 建筑与设施（39）

### 藻类培养槽 `facility:algae_tank`

加工设施；6元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 6元石＋材料 原木×1＋普通岩石×1＋1AP |
| 占地/地形 | 1×1格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 支持配方 | 藻料培养、高密度藻培养（一次一批次） |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（1份石） |

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 水生种植台 `facility:aquatic_crop_station`

加工设施；8元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 8元石＋材料 木板×1＋普通岩石×2＋1AP |
| 占地/地形 | 1×1格；地形：水面 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（2份石） |

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 蜂箱 `facility:bee_hive`

养殖栖息设施；10元石

> 解锁条件：需完成研究 [蜂群协作](#蜂群协作-researchbeekeeping)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 建造费用 | 10元石＋材料 木板×2＋原木×2＋1AP |
| 占地/地形 | 2×2格；地形：陆地 |
| 设施类型 | 养殖栖息设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 容量 | 4单位/场（每场单物种） |
| 接纳物种 | 蜜盏蜂 |

关联条目：接纳物种：[蜜盏蜂](#蜜盏蜂-speciesbell_bee)；解锁研究：[蜂群协作](#蜂群协作-researchbeekeeping)

### 炭化巢 `facility:carbonization_nest`

加工设施；18元石

> 解锁条件：需完成研究 [农产初加工](#农产初加工-researchfarm_preparation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 建造费用 | 18元石＋材料 木板×2＋普通岩石×4＋1AP |
| 占地/地形 | 2×2格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 容量 | 4单位/场（每场单物种） |
| 接纳物种 | 炭腹虫 |
| 支持配方 | 树枝生物炭化、木屑生物炭化（一次一批次） |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（4份石） |

关联条目：接纳物种：[炭腹虫](#炭腹虫-speciescarbon_belly_bug)；解锁研究：[农产初加工](#农产初加工-researchfarm_preparation)

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 照料台 `facility:care_table`

加工设施；24元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 24元石＋材料 木板×2＋普通岩石×2＋1AP |
| 占地/地形 | 1×1格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（2份石） |

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 捕鲤台 `facility:carp_harvest_station`

加工设施；12元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 12元石＋材料 木板×2＋普通岩石×2＋1AP |
| 占地/地形 | 1×1格；地形：水面 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 接纳物种 | 滤藻鲤 |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（2份石） |

关联条目：接纳物种：[滤藻鲤](#滤藻鲤-speciesfilter_algae_carp)

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 炭化炉 `facility:char_kiln`

加工设施；12元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 12元石＋材料 原木×2＋普通岩石×3＋1AP |
| 占地/地形 | 2×2格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 支持配方 | 枝条炭化（一次一批次） |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（3份石） |

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 堆肥箱 `facility:compost_bin`

加工设施；6元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 6元石＋材料 原木×1＋普通岩石×1＋1AP |
| 占地/地形 | 1×1格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 支持配方 | 秸秆堆肥、枝条堆肥、木屑堆肥、羊粪堆肥、鱼粪堆肥、牧草堆肥、油饼堆肥、污泥堆肥、废滤炭堆肥（一次一批次） |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（1份石） |

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 翻肥窝 `facility:compost_mouse_den`

加工设施；12元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 12元石＋材料 原木×2＋普通岩石×2＋1AP |
| 占地/地形 | 2×2格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 容量 | 4单位/场（每场单物种） |
| 接纳物种 | 堆肥鼠 |
| 支持配方 | 秸秆翻肥、残料翻肥（一次一批次） |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（2份石） |

关联条目：接纳物种：[堆肥鼠](#堆肥鼠-speciescompost_mouse)

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 采礁台 `facility:coral_station`

加工设施；20元石

> 解锁条件：需完成研究 [矿质材料工艺](#矿质材料工艺-researchmineral_materials)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 建造费用 | 20元石＋材料 木板×2＋普通岩石×4＋1AP |
| 占地/地形 | 1×1格；地形：水面 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 接纳物种 | 礁骨珊瑚 |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（4份石） |

关联条目：接纳物种：[礁骨珊瑚](#礁骨珊瑚-speciesreef_coral)；解锁研究：[矿质材料工艺](#矿质材料工艺-researchmineral_materials)

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 调度站 `facility:dispatch_station`

加工设施；18元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 18元石＋材料 原木×2＋普通岩石×2＋1AP |
| 占地/地形 | 1×1格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（2份石） |

关联条目：可入驻后勤蛊：[驭兽蛊](#驭兽蛊-gucommand_gu)

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 农产加工台 `facility:farm_processor`

加工设施；12元石

> 解锁条件：需完成研究 [农产初加工](#农产初加工-researchfarm_preparation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 建造费用 | 12元石＋材料 木板×2＋普通岩石×2＋1AP |
| 占地/地形 | 2×2格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 支持配方 | 谷粉研磨、草粉研磨、油籽榨油、油脂精炼、陆养料调配、水养料调配、蜂蜡精炼、矿质补料调配、稻米磨粉（一次一批次） |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（2份石） |

关联条目：解锁研究：[农产初加工](#农产初加工-researchfarm_preparation)

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 供食槽 `facility:feed_trough`

加工设施；6元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 6元石＋材料 原木×2＋1AP |
| 占地/地形 | 1×1格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |

### 田间维护站 `facility:field_service_station`

加工设施；18元石

> 解锁条件：需完成研究 [田间自动维护](#田间自动维护-researchfield_maintenance)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 建造费用 | 18元石＋材料 木板×3＋铁锭×1＋1AP |
| 占地/地形 | 1×1格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 持续生产策略 | 不适用（装置不使用持续生产策略） |

关联条目：可入驻后勤蛊：[催生蛊](#催生蛊-gugrowth_gu)；可入驻后勤蛊：[锁水蛊](#锁水蛊-guwater_gu)；可入驻后勤蛊：[节肥蛊](#节肥蛊-gufert_gu)；解锁研究：[田间自动维护](#田间自动维护-researchfield_maintenance)

### 水场 `facility:fish_pond`

养殖栖息设施；12元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 12元石＋材料 普通岩石×4＋原木×1＋1AP |
| 占地/地形 | 2×2格；地形：水面 |
| 设施类型 | 养殖栖息设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 容量 | 4单位/场（每场单物种） |
| 接纳物种 | 滤藻鲤 |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（4份石） |

关联条目：接纳物种：[滤藻鲤](#滤藻鲤-speciesfilter_algae_carp)

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 采胶台 `facility:gel_station`

加工设施；16元石

> 解锁条件：需完成研究 [水与藻料回流](#水与藻料回流-researchwater_recirculation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 建造费用 | 16元石＋材料 木板×2＋普通岩石×3＋1AP |
| 占地/地形 | 1×1格；地形：水面 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 接纳物种 | 凝胶水母 |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（3份石） |

关联条目：接纳物种：[凝胶水母](#凝胶水母-speciesgel_jellyfish)；解锁研究：[水与藻料回流](#水与藻料回流-researchwater_recirculation)

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 补光灯 `facility:growth_lamp`

加工设施；12元石

> 解锁条件：需完成研究 [矿质材料工艺](#矿质材料工艺-researchmineral_materials)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 建造费用 | 12元石＋材料 复合石板×1＋铁锭×1＋1AP |
| 占地/地形 | 1×1格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 持续生产策略 | 不适用（装置不使用持续生产策略） |

关联条目：可入驻后勤蛊：[明光蛊](#明光蛊-gubright_gu)；解锁研究：[矿质材料工艺](#矿质材料工艺-researchmineral_materials)

### 厨房 `facility:kitchen`

加工设施；12元石

> 解锁条件：需完成研究 [灵食初制](#灵食初制-researchbasic_spirit_cooking)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 建造费用 | 12元石＋材料 木板×2＋普通岩石×3＋1AP |
| 占地/地形 | 2×2格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 支持配方 | 蜜谷灵饼烘焙、菌鱼灵膳烹制、藻露羹熬制、蜜油火膏熬制、腐土菌丸炼制、蜜炼金食炼制（一次一批次） |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（3份石） |

关联条目：解锁研究：[灵食初制](#灵食初制-researchbasic_spirit_cooking)

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 大床 `facility:large_bed`

加工设施；14元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 14元石＋材料 原木×4＋1AP |
| 占地/地形 | 1×1格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |

### 中床 `facility:medium_bed`

加工设施；10元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 10元石＋材料 原木×3＋1AP |
| 占地/地形 | 1×1格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |

### 取油台 `facility:oilfish_harvest_station`

加工设施；16元石

> 解锁条件：需完成研究 [农产初加工](#农产初加工-researchfarm_preparation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 建造费用 | 16元石＋材料 木板×2＋普通岩石×3＋1AP |
| 占地/地形 | 1×1格；地形：水面 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 接纳物种 | 油鳍鱼 |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（3份石） |

关联条目：接纳物种：[油鳍鱼](#油鳍鱼-speciesoilfin_fish)；解锁研究：[农产初加工](#农产初加工-researchfarm_preparation)

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 选矿场 `facility:ore_sorting_yard`

养殖栖息设施；12元石

> 解锁条件：需完成研究 [生物选矿](#生物选矿-researchore_concentration)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 建造费用 | 12元石＋材料 原木×2＋普通岩石×3＋1AP |
| 占地/地形 | 2×2格；地形：陆地 |
| 设施类型 | 养殖栖息设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 容量 | 4单位/场（每场单物种） |
| 接纳物种 | 岩腹兽 |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（3份石） |

关联条目：接纳物种：[岩腹兽](#岩腹兽-speciesrock_belly_beast)；解锁研究：[生物选矿](#生物选矿-researchore_concentration)

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 采珠台 `facility:pearl_station`

加工设施；16元石

> 解锁条件：需完成研究 [水与藻料回流](#水与藻料回流-researchwater_recirculation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 建造费用 | 16元石＋材料 木板×2＋普通岩石×3＋1AP |
| 占地/地形 | 1×1格；地形：水面 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 接纳物种 | 珍珠蚌 |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（3份石） |

关联条目：接纳物种：[珍珠蚌](#珍珠蚌-speciespearl_mussel)；解锁研究：[水与藻料回流](#水与藻料回流-researchwater_recirculation)

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 圈舍 `facility:pen`

养殖栖息设施；16元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 16元石＋材料 原木×2＋普通岩石×3＋1AP |
| 占地/地形 | 2×2格；地形：陆地 |
| 设施类型 | 养殖栖息设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 容量 | 4单位/场（每场单物种） |
| 接纳物种 | 钢绵羊 |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（3份石） |

关联条目：接纳物种：[钢绵羊](#钢绵羊-speciessteel_sheep)

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 净水菌床 `facility:purifying_bed`

养殖栖息设施；10元石

> 解锁条件：需完成研究 [菌毯净化](#菌毯净化-researchbiofiltration)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 建造费用 | 10元石＋材料 原木×2＋普通岩石×2＋1AP |
| 占地/地形 | 2×2格；地形：陆地 |
| 设施类型 | 养殖栖息设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 容量 | 4单位/场（每场单物种） |
| 接纳物种 | 净水菌毯 |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（2份石） |

关联条目：接纳物种：[净水菌毯](#净水菌毯-speciespurifying_mat)；解锁研究：[菌毯净化](#菌毯净化-researchbiofiltration)

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 研究台 `facility:research_bench`

研究设施；8元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 8元石＋材料 原木×2＋普通岩石×2＋1AP |
| 占地/地形 | 1×1格；地形：陆地 |
| 设施类型 | 研究设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（2份石） |

关联条目：可入驻后勤蛊：[智道研究蛊](#智道研究蛊-guwisdom_gu)；可入驻后勤蛊：[宙道研究蛊](#宙道研究蛊-gutime_gu)

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 碎岩场 `facility:rock_breaking_yard`

养殖栖息设施；12元石

> 解锁条件：需完成研究 [岩料破碎](#岩料破碎-researchrock_handling)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 建造费用 | 12元石＋材料 原木×2＋普通岩石×3＋1AP |
| 占地/地形 | 2×2格；地形：陆地 |
| 设施类型 | 养殖栖息设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 容量 | 4单位/场（每场单物种） |
| 接纳物种 | 啮岩鼹 |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（3份石） |

关联条目：接纳物种：[啮岩鼹](#啮岩鼹-speciesrock_mole)；解锁研究：[岩料破碎](#岩料破碎-researchrock_handling)

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 养鳞台 `facility:scale_station`

加工设施；18元石

> 解锁条件：需完成研究 [矿质材料工艺](#矿质材料工艺-researchmineral_materials)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 建造费用 | 18元石＋材料 木板×2＋普通岩石×4＋1AP |
| 占地/地形 | 1×1格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 接纳物种 | 矿鳞蜥 |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（4份石） |

关联条目：接纳物种：[矿鳞蜥](#矿鳞蜥-speciesmineral_scale_lizard)；解锁研究：[矿质材料工艺](#矿质材料工艺-researchmineral_materials)

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 岩壳成型台 `facility:shell_forming_station`

加工设施；18元石

> 解锁条件：需完成研究 [矿质材料工艺](#矿质材料工艺-researchmineral_materials)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 建造费用 | 18元石＋材料 木板×2＋普通岩石×4＋1AP |
| 占地/地形 | 2×2格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 容量 | 4单位/场（每场单物种） |
| 接纳物种 | 砾甲蜗牛 |
| 支持配方 | 岩壳成型（一次一批次） |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（4份石） |

关联条目：接纳物种：[砾甲蜗牛](#砾甲蜗牛-speciesgravel_shell_snail)；解锁研究：[矿质材料工艺](#矿质材料工艺-researchmineral_materials)

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 蚕架 `facility:silkworm_rack`

加工设施；10元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 10元石＋材料 木板×2＋枝条×2＋1AP |
| 占地/地形 | 1×1格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 接纳物种 | 叶丝蚕 |

关联条目：接纳物种：[叶丝蚕](#叶丝蚕-speciesleaf_silkworm)

### 泥料处理台 `facility:silt_processing_station`

加工设施；14元石

> 解锁条件：需完成研究 [菌毯净化](#菌毯净化-researchbiofiltration)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 建造费用 | 14元石＋材料 木板×2＋普通岩石×2＋1AP |
| 占地/地形 | 1×1格；地形：水面 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 接纳物种 | 净泥鳅 |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（2份石） |

关联条目：接纳物种：[净泥鳅](#净泥鳅-speciessilt_loach)；解锁研究：[菌毯净化](#菌毯净化-researchbiofiltration)

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 小床 `facility:small_bed`

加工设施；6元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 6元石＋材料 原木×2＋1AP |
| 占地/地形 | 1×1格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |

### 小型冶炼炉 `facility:smelter`

加工设施；20元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 20元石＋材料 木板×2＋普通岩石×6＋1AP |
| 占地/地形 | 2×2格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 支持配方 | 木炭冶炼、松脂冶炼、富集矿冶炼（一次一批次） |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（6份石） |

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 安抚台 `facility:soothing_station`

加工设施；18元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 18元石＋材料 木板×2＋普通岩石×2＋1AP |
| 占地/地形 | 1×1格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（2份石） |

关联条目：可入驻后勤蛊：[安抚蛊](#安抚蛊-gusoothe_gu)

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 集露台 `facility:spirit_liquid_collector`

加工设施；12元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 12元石＋材料 木板×1＋普通岩石×3＋1AP |
| 占地/地形 | 1×1格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 接纳物种 | 露壳蜗牛 |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（3份石） |

关联条目：接纳物种：[露壳蜗牛](#露壳蜗牛-speciesdew_shell_snail)

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 玩具站 `facility:toy_station`

加工设施；12元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 12元石＋材料 木板×2＋普通岩石×2＋1AP |
| 占地/地形 | 1×1格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（2份石） |

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 换水站 `facility:water_change_station`

加工设施；16元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 16元石＋材料 木板×2＋普通岩石×4＋1AP |
| 占地/地形 | 1×1格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（4份石） |

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 木工台 `facility:woodshop`

加工设施；8元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 8元石＋材料 原木×2＋普通岩石×2＋1AP |
| 占地/地形 | 2×2格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 支持配方 | 锯切木板、原木粉碎、枝条粉碎、炭砂滤料制作、复合石板组装、再生填料回收、make_vine_ball、丝质滤材、黏液复合石板、鳞甲复合板、岩壳石板（一次一批次） |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（2份石） |

相关规则：[建材替代](#建材替代-rulebuild_substitute)

### 采毛台 `facility:wool_station`

加工设施；12元石

| 字段 | 内容 |
|---|---|
| 建造费用 | 12元石＋材料 木板×2＋普通岩石×2＋1AP |
| 占地/地形 | 1×1格；地形：陆地 |
| 设施类型 | 加工设施 |
| 拆除 | 1AP；需设施空闲；不返还材料与元石 |
| 接纳物种 | 钢绵羊 |
| 建材替代 | 普通岩石部分可用复合石板1:1或再生填料2:1整体替代（2份石） |

关联条目：接纳物种：[钢绵羊](#钢绵羊-speciessteel_sheep)

相关规则：[建材替代](#建材替代-rulebuild_substitute)


## 后勤蛊与协同（9）

### 明光蛊 `gu:bright_gu`

环境光照

| 字段 | 内容 |
|---|---|
| 转数 | 1转原型；实例支持一至五转，升转由上游负责 |
| 获取 | 每档一次试用配给共15只：饭袋草/催生/锁水/节肥/安抚/驭兽各2只，明光/智道研究/宙道研究各1只；尚未连接上游获取与成长 |
| 部署 | 入驻兼容设施：补光灯 |
| 能力 | 范围外扩2格，提供光照80，同格光照取最大 |
| 维护 | 启用时1元石/游戏日；闲置仍收费，休眠/未部署免维护 |
| 特殊食料 | 无（每个成功付费服务日；与元石原子扣除） |
| 时点 | 部署/撤回各1AP；启用次日生效；停用立即取消后续效果，已付不退；运行/待收任务锁定实例 |
| 灯光模式 | 入驻补光灯后替代精炼油供能；休眠不自动回退燃油；自然光/灯/蛊取最大值，喜阴作物可能降效 |

关联条目：兼容设施：[补光灯](#补光灯-facilitygrowth_lamp)

相关规则：[后勤蛊部署、维护与生产协同](#后勤蛊部署维护与生产协同-rulelogistics)

### 驭兽蛊 `gu:command_gu`

实际动物劳动倍率

| 字段 | 内容 |
|---|---|
| 转数 | 1转原型；实例支持一至五转，升转由上游负责 |
| 获取 | 每档一次试用配给共15只：饭袋草/催生/锁水/节肥/安抚/驭兽各2只，明光/智道研究/宙道研究各1只；尚未连接上游获取与成长 |
| 部署 | 入驻兼容设施：调度站 |
| 能力 | 实际获岗劳动点×1.5，每单位服务4空间 |
| 维护 | 启用时1元石/游戏日；闲置仍收费，休眠/未部署免维护 |
| 特殊食料 | 无（每个成功付费服务日；与元石原子扣除） |
| 时点 | 部署/撤回各1AP；启用次日生效；停用立即取消后续效果，已付不退；运行/待收任务锁定实例 |

关联条目：兼容设施：[调度站](#调度站-facilitydispatch_station)

相关规则：[后勤蛊部署、维护与生产协同](#后勤蛊部署维护与生产协同-rulelogistics)

### 节肥蛊 `gu:fert_gu`

定向肥力减耗

| 字段 | 内容 |
|---|---|
| 转数 | 1转原型；实例支持一至五转，升转由上游负责 |
| 获取 | 每档一次试用配给共15只：饭袋草/催生/锁水/节肥/安抚/驭兽各2只，明光/智道研究/宙道研究各1只；尚未连接上游获取与成长 |
| 部署 | 入驻兼容设施：田间维护站 |
| 能力 | 宿主四向3×3服务区，完整覆盖目标的肥力扣耗保留50%（每格百分之一余量跨日累计） |
| 维护 | 启用时1元石/游戏日；闲置仍收费，休眠/未部署免维护 |
| 特殊食料 | 无（每个成功付费服务日；与元石原子扣除） |
| 时点 | 部署/撤回各1AP；启用次日生效；停用立即取消后续效果，已付不退；运行/待收任务锁定实例 |

关联条目：兼容设施：[田间维护站](#田间维护站-facilityfield_service_station)

相关规则：[后勤蛊部署、维护与生产协同](#后勤蛊部署维护与生产协同-rulelogistics)

### 催生蛊 `gu:growth_gu`

定向生长速度

| 字段 | 内容 |
|---|---|
| 转数 | 1转原型；实例支持一至五转，升转由上游负责 |
| 获取 | 每档一次试用配给共15只：饭袋草/催生/锁水/节肥/安抚/驭兽各2只，明光/智道研究/宙道研究各1只；尚未连接上游获取与成长 |
| 部署 | 入驻兼容设施：田间维护站 |
| 能力 | 宿主四向3×3服务区，完整覆盖的植物目标生产速度×1.5；同tag最高转优先 |
| 维护 | 启用时1元石/游戏日；闲置仍收费，休眠/未部署免维护 |
| 特殊食料 | 无（每个成功付费服务日；与元石原子扣除） |
| 时点 | 部署/撤回各1AP；启用次日生效；停用立即取消后续效果，已付不退；运行/待收任务锁定实例 |

关联条目：兼容设施：[田间维护站](#田间维护站-facilityfield_service_station)

相关规则：[后勤蛊部署、维护与生产协同](#后勤蛊部署维护与生产协同-rulelogistics)

### 饭袋草蛊 `gu:rice_bag_gu`

独立生产

| 字段 | 内容 |
|---|---|
| 转数 | 1转原型；实例支持一至五转，升转由上游负责 |
| 获取 | 每档一次试用配给共15只：饭袋草/催生/锁水/节肥/安抚/驭兽各2只，明光/智道研究/宙道研究各1只；尚未连接上游获取与成长 |
| 部署 | 独立占用1格陆地，不需开垦/农田 |
| 能力 | 自身进行生产，条件与产物见下方 |
| 维护 | 启用时1元石/游戏日；闲置仍收费，休眠/未部署免维护 |
| 特殊食料 | 无（每个成功付费服务日；与元石原子扣除） |
| 时点 | 部署/撤回各1AP；启用次日生效；停用立即取消后续效果，已付不退；运行/待收任务锁定实例 |
| 生产 | 3有效日；启动投入无；收取稻米×4，1AP |
| 环境 | 光照≥60、水分≥30，不足暂停保留进度；每推进日扣水分8，不扣肥力；清水浇水或田间站可补水 |

关联条目：产物：[稻米](#稻米-resourcerice)

相关规则：[后勤蛊部署、维护与生产协同](#后勤蛊部署维护与生产协同-rulelogistics)

### 安抚蛊 `gu:soothe_gu`

实际繁殖进度倍率

| 字段 | 内容 |
|---|---|
| 转数 | 1转原型；实例支持一至五转，升转由上游负责 |
| 获取 | 每档一次试用配给共15只：饭袋草/催生/锁水/节肥/安抚/驭兽各2只，明光/智道研究/宙道研究各1只；尚未连接上游获取与成长 |
| 部署 | 入驻兼容设施：安抚台 |
| 能力 | 实际合格繁殖进度×1.5，每单位服务4空间 |
| 维护 | 启用时1元石/游戏日；闲置仍收费，休眠/未部署免维护 |
| 特殊食料 | 无（每个成功付费服务日；与元石原子扣除） |
| 时点 | 部署/撤回各1AP；启用次日生效；停用立即取消后续效果，已付不退；运行/待收任务锁定实例 |

关联条目：兼容设施：[安抚台](#安抚台-facilitysoothing_station)

相关规则：[后勤蛊部署、维护与生产协同](#后勤蛊部署维护与生产协同-rulelogistics)

### 宙道研究蛊 `gu:time_gu`

研究速度倍率

| 字段 | 内容 |
|---|---|
| 转数 | 1转原型；实例支持一至五转，升转由上游负责 |
| 获取 | 每档一次试用配给共15只：饭袋草/催生/锁水/节肥/安抚/驭兽各2只，明光/智道研究/宙道研究各1只；尚未连接上游获取与成长 |
| 部署 | 入驻兼容设施：研究台 |
| 能力 | 每个有效研究日推进2工作量 |
| 维护 | 启用时2元石/游戏日；闲置仍收费，休眠/未部署免维护 |
| 特殊食料 | 宙道食料×1（每个成功付费服务日；与元石原子扣除） |
| 时点 | 部署/撤回各1AP；启用次日生效；停用立即取消后续效果，已付不退；运行/待收任务锁定实例 |
| 研究样本 | 基础样本逐项×1.5向上取整；一次性启动费不变 |

关联条目：兼容设施：[研究台](#研究台-facilityresearch_bench)；特殊食料：[宙道食料](#宙道食料-resourcetime_feed)

相关规则：[后勤蛊部署、维护与生产协同](#后勤蛊部署维护与生产协同-rulelogistics)

### 锁水蛊 `gu:water_gu`

定向水分减耗

| 字段 | 内容 |
|---|---|
| 转数 | 1转原型；实例支持一至五转，升转由上游负责 |
| 获取 | 每档一次试用配给共15只：饭袋草/催生/锁水/节肥/安抚/驭兽各2只，明光/智道研究/宙道研究各1只；尚未连接上游获取与成长 |
| 部署 | 入驻兼容设施：田间维护站 |
| 能力 | 宿主四向3×3服务区，完整覆盖目标的水分扣耗保留50%（每格百分之一余量跨日累计） |
| 维护 | 启用时1元石/游戏日；闲置仍收费，休眠/未部署免维护 |
| 特殊食料 | 无（每个成功付费服务日；与元石原子扣除） |
| 时点 | 部署/撤回各1AP；启用次日生效；停用立即取消后续效果，已付不退；运行/待收任务锁定实例 |

关联条目：兼容设施：[田间维护站](#田间维护站-facilityfield_service_station)

相关规则：[后勤蛊部署、维护与生产协同](#后勤蛊部署维护与生产协同-rulelogistics)

### 智道研究蛊 `gu:wisdom_gu`

固定研究工作量减免

| 字段 | 内容 |
|---|---|
| 转数 | 1转原型；实例支持一至五转，升转由上游负责 |
| 获取 | 每档一次试用配给共15只：饭袋草/催生/锁水/节肥/安抚/驭兽各2只，明光/智道研究/宙道研究各1只；尚未连接上游获取与成长 |
| 部署 | 入驻兼容设施：研究台 |
| 能力 | 研究工作量固定减少1，至少保留1 |
| 维护 | 启用时1元石/游戏日；闲置仍收费，休眠/未部署免维护 |
| 特殊食料 | 无（每个成功付费服务日；与元石原子扣除） |
| 时点 | 部署/撤回各1AP；启用次日生效；停用立即取消后续效果，已付不退；运行/待收任务锁定实例 |

关联条目：兼容设施：[研究台](#研究台-facilityresearch_bench)

相关规则：[后勤蛊部署、维护与生产协同](#后勤蛊部署维护与生产协同-rulelogistics)


## 材料与物品（78）

### 藻料 `resource:algae_feed`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：animal_feed |
| 市集采购 | 不可采购 |
| 市集出售 | 2元石/份（计入销售收入） |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·藻料培养 | ×6 | 加工·藻料培养：藻料×6（每批）｜藻类培养槽｜2自然日｜启动1＋收取1 | 清水×3；秸秆×2 |

**直接用途（9条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·水养料调配 | ×3 | 加工·水养料调配：藻料×3（每批）｜农产加工台｜需研究「饲料与蜡油精制」｜1自然日｜启动1＋收取1 | 谷粉×1；油饼×1；复合水养料×4 |
| 整体维护·滤藻鲤 | ×1 | 整体维护·滤藻鲤：藻料×1（每尾·每日）｜捕鲤台｜滤藻鲤｜1AP | 复合水养料×1；高密度藻料×1；谷粒×1 |
| 整体维护·凝胶水母 | ×1 | 整体维护·凝胶水母：藻料×1（每群·每日）｜采胶台｜凝胶水母｜1AP | 高密度藻料×1；清水×1 |
| 整体维护·砾甲蜗牛 | ×1 | 整体维护·砾甲蜗牛：藻料×1（每只·每日）｜岩壳成型台｜砾甲蜗牛｜1AP | 清水×1；石粉×3；清水×1 |
| 整体维护·油鳍鱼 | ×1 | 整体维护·油鳍鱼：藻料×1（每尾·每日）｜取油台｜油鳍鱼｜1AP | 复合水养料×1；复合水养料×1 |
| 整体维护·珍珠蚌 | ×1 | 整体维护·珍珠蚌：藻料×1（每只·每日）｜采珠台｜珍珠蚌｜1AP | 石粉×1 |
| 整体维护·礁骨珊瑚 | ×1 | 整体维护·礁骨珊瑚：藻料×1（每群·每日）｜采礁台｜礁骨珊瑚｜1AP | 石粉×3；清水×1 |
| 整体维护·净泥鳅 | ×1 | 整体维护·净泥鳅：藻料×1（每尾·每日）｜泥料处理台｜净泥鳅｜1AP | — |
| 市集出售·藻料 | ×按订单/库存 | 市集出售·藻料：藻料×按订单/库存（每份） | 元石×2 |

相关规则：[市集交易](#市集交易-rulemarket)

### 蜂蜡 `resource:beeswax`

火行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 火行·固体·初级；标签：processing、animal_product |
| 市集采购 | 不可采购 |
| 市集出售 | 3元石/份（计入销售收入） |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 收取·蜜盏蜂 | ×1 | 收取·蜜盏蜂：蜂蜡×1（每群·每轮）｜蜂箱｜蜜盏蜂｜1AP | 蜂蜜×2 |

**直接用途（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·蜂蜡精炼 | ×2 | 加工·蜂蜡精炼：蜂蜡×2（每批）｜农产加工台｜需研究「饲料与蜡油精制」｜1自然日｜启动1＋收取1 | 精炼蜡×1 |
| 启动研究·饲料与蜡油精制 | ×1 | 启动研究·饲料与蜡油精制：蜂蜡×1（一次性）｜研究台 | 粗油×1；谷粉×1；元石×8 |
| 市集出售·蜂蜡 | ×按订单/库存 | 市集出售·蜂蜡：蜂蜡×按订单/库存（每份） | 元石×3 |

相关规则：[市集交易](#市集交易-rulemarket)

### 木炭 `resource:charcoal`

火行固体；可供货（供养值4）

| 字段 | 内容 |
|---|---|
| 分类 | 火行·固体·加工品；标签：food、fuel |
| 市集采购 | 不可采购 |
| 市集出售 | 5元石/份（计入销售收入） |
| 五行供货 | 可供货（火行）；供养值4：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |

**获取来源（5条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·木屑生物炭化 | ×2 | 加工·木屑生物炭化：木炭×2（每批）｜炭化巢｜需研究「农产初加工」｜1自然日｜启动1＋收取1 | 木屑×4；腐殖土×1 |
| 加工·树枝生物炭化 | ×4 | 加工·树枝生物炭化：木炭×4（每批）｜炭化巢｜需研究「农产初加工」｜1自然日｜启动1＋收取1 | 枝条×4；腐殖土×1 |
| 加工·枝条炭化 | ×3 | 加工·枝条炭化：木炭×3（每批）｜炭化炉｜2自然日｜启动1＋收取1 | 枝条×4 |
| 收取·炭腹虫 | ×4 | 收取·炭腹虫：木炭×4（每群·每轮）｜炭化巢｜炭腹虫｜1AP | 腐殖土×1；腐殖土×1 |
| 收取·炭腹虫 | ×2 | 收取·炭腹虫：木炭×2（每群·每轮）｜炭化巢｜炭腹虫｜1AP | 腐殖土×1；腐殖土×1 |

**直接用途（14条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·藻露羹熬制 | ×1 | 加工·藻露羹熬制：木炭×1（每批）｜厨房｜需研究「复合灵食」｜2自然日｜启动1＋收取1 | 高密度藻料×1；清水×3；花瓣×1；藻露羹×2 |
| 加工·菌鱼灵膳烹制 | ×1 | 加工·菌鱼灵膳烹制：木炭×1（每批）｜厨房｜需研究「灵食初制」｜1自然日｜启动1＋收取1 | 木腐菇×1；鱼肉×1；精炼油×1；菌鱼灵膳×2 |
| 加工·蜜谷灵饼烘焙 | ×1 | 加工·蜜谷灵饼烘焙：木炭×1（每批）｜厨房｜需研究「灵食初制」｜1自然日｜启动1＋收取1 | 谷粉×2；蜂蜜×1；清水×1；蜜谷灵饼×2 |
| 加工·蜜炼金食炼制 | ×1 | 加工·蜜炼金食炼制：木炭×1（每批）｜厨房｜需研究「复合灵食」｜2自然日｜启动1＋收取1 | 铁锭×1；蜂蜜×1；蜜炼金食×1 |
| 加工·炭砂滤料制作 | ×1 | 加工·炭砂滤料制作：木炭×1（每批）｜木工台｜需研究「水与藻料回流」｜1自然日｜启动1＋收取1 | 砂砾×2；炭砂滤料×2 |
| 加工·丝质滤材 | ×1 | 加工·丝质滤材：木炭×1（每批）｜木工台｜需研究「水与藻料回流」｜1自然日｜启动1＋收取1 | 蚕丝×1；木屑×1；炭砂滤料×3 |
| 加工·蜜油火膏熬制 | ×1 | 加工·蜜油火膏熬制：木炭×1（每批）｜厨房｜需研究「复合灵食」｜2自然日｜启动1＋收取1 | 精炼油×1；蜂蜜×1；精炼蜡×1；蜜油火膏×2 |
| 加工·油脂精炼 | ×1 | 加工·油脂精炼：木炭×1（每批）｜农产加工台｜需研究「饲料与蜡油精制」｜1自然日｜启动1＋收取1 | 粗油×2；精炼油×2；废滤炭×1 |
| 加工·木炭冶炼 | ×1 | 加工·木炭冶炼：木炭×1（每批）｜小型冶炼炉｜2自然日｜启动1＋收取1 | 含铁矿石×3；铁锭×1 |
| 加工·富集矿冶炼 | ×1 | 加工·富集矿冶炼：木炭×1（每批）｜小型冶炼炉｜需研究「矿质材料工艺」｜2自然日｜启动1＋收取1 | 富集矿砂×1；铁锭×1；炉渣×1 |
| 加工·腐土菌丸炼制 | ×1 | 加工·腐土菌丸炼制：木炭×1（每批）｜厨房｜需研究「复合灵食」｜2自然日｜启动1＋收取1 | 腐殖土×2；木腐菇×1；草粉×1；腐土菌丸×2 |
| 启动研究·水与藻料回流 | ×1 | 启动研究·水与藻料回流：木炭×1（一次性）｜研究台 | 污泥×1；砂砾×1；元石×8 |
| 市集出售·木炭 | ×按订单/库存 | 市集出售·木炭：木炭×按订单/库存（每份） | 元石×5 |
| 五行供货·木炭 | ×按订单/库存 | 五行供货·木炭：木炭×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 清水 `resource:clean_water`

水行液体；可供货（供养值1）

| 字段 | 内容 |
|---|---|
| 分类 | 水行·液体·初级；标签：food、medium |
| 市集采购 | 2元石/份 |
| 市集出售 | 1元石/份（计入销售收入） |
| 五行供货 | 可供货（水行）；供养值1：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |

**获取来源（6条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·菌毯净水 | ×2 | 加工·菌毯净水：清水×2（每批）｜净水菌床｜需研究「菌毯净化」｜2自然日｜启动1＋收取1 | 污水×4；木屑×1；污泥×1 |
| 加工·营养液回收 | ×1 | 加工·营养液回收：清水×1（每批）｜净水菌床｜需研究「水与藻料回流」｜2自然日｜启动1＋收取1 | 污水×4；炭砂滤料×1；营养液×2；污泥×1 |
| 市集采购·清水 | ×按订单/库存 | 市集采购·清水：清水×按订单/库存（每份） | 元石×2 |
| 收取·净水菌毯 | ×2 | 收取·净水菌毯：清水×2（每培养单位·每轮）｜净水菌床｜净水菌毯｜1AP | 污泥×1；营养液×2；污泥×1 |
| 收取·净水菌毯 | ×1 | 收取·净水菌毯：清水×1（每培养单位·每轮）｜净水菌床｜净水菌毯｜1AP | 污泥×1；营养液×2；污泥×1 |
| 泉水点采集 | ×5 | 泉水点采集：清水×5（每次）｜1AP | — |

**直接用途（32条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·藻露羹熬制 | ×3 | 加工·藻露羹熬制：清水×3（每批）｜厨房｜需研究「复合灵食」｜2自然日｜启动1＋收取1 | 高密度藻料×1；花瓣×1；木炭×1；藻露羹×2 |
| 加工·藻料培养 | ×3 | 加工·藻料培养：清水×3（每批）｜藻类培养槽｜2自然日｜启动1＋收取1 | 秸秆×2；藻料×6 |
| 加工·高密度藻培养 | ×1 | 加工·高密度藻培养：清水×1（每批）｜藻类培养槽｜需研究「水与藻料回流」｜2自然日｜启动1＋收取1 | 营养液×2；秸秆×1；高密度藻料×3 |
| 加工·岩壳成型 | ×1 | 加工·岩壳成型：清水×1（每批）｜岩壳成型台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 石粉×3；岩壳片×2；黏液×1 |
| 加工·蜜谷灵饼烘焙 | ×1 | 加工·蜜谷灵饼烘焙：清水×1（每批）｜厨房｜需研究「灵食初制」｜1自然日｜启动1＋收取1 | 谷粉×2；蜂蜜×1；木炭×1；蜜谷灵饼×2 |
| 饭袋草蛊·浇水 | ×1 | 饭袋草蛊·浇水：清水×1（每次）｜饭袋草蛊｜1AP | — |
| 浇水 | ×1 | 浇水：清水×1（每次）｜1AP | — |
| 整体维护·蜜盏蜂 | ×1 | 整体维护·蜜盏蜂：清水×1（每群·每日）｜蜂箱｜蜜盏蜂｜1AP | — |
| 整体维护·炭腹虫 | ×1 | 整体维护·炭腹虫：清水×1（每群·每日）｜炭化巢｜炭腹虫｜1AP | 牧草×1；枝条×4；木屑×4 |
| 整体维护·堆肥鼠 | ×1 | 整体维护·堆肥鼠：清水×1（每只·每日）｜翻肥窝｜堆肥鼠｜1AP | 牧草×1；秸秆×2；木屑×1；污泥×2；油饼×1 |
| 整体维护·露壳蜗牛 | ×1 | 整体维护·露壳蜗牛：清水×1（每只·每日）｜集露台｜露壳蜗牛｜1AP | 牧草×1 |
| 整体维护·露壳蜗牛 | ×2 | 整体维护·露壳蜗牛：清水×2（每只·每轮）｜集露台｜露壳蜗牛｜1AP | 牧草×1 |
| 整体维护·凝胶水母 | ×1 | 整体维护·凝胶水母：清水×1（每群·每轮）｜采胶台｜凝胶水母｜1AP | 藻料×1；高密度藻料×1 |
| 整体维护·砾甲蜗牛 | ×1 | 整体维护·砾甲蜗牛：清水×1（每只·每日）｜岩壳成型台｜砾甲蜗牛｜1AP | 藻料×1；石粉×3 |
| 整体维护·砾甲蜗牛 | ×1 | 整体维护·砾甲蜗牛：清水×1（每只·每轮）｜岩壳成型台｜砾甲蜗牛｜1AP | 藻料×1；石粉×3 |
| 整体维护·叶丝蚕 | ×1 | 整体维护·叶丝蚕：清水×1（每群·每日）｜蚕架｜叶丝蚕｜1AP | 桑叶×1；桑叶×2 |
| 整体维护·矿鳞蜥 | ×1 | 整体维护·矿鳞蜥：清水×1（每只·每日）｜养鳞台｜矿鳞蜥｜1AP | 牧草×1；复合陆养料×1；矿质补料×2 |
| 整体维护·矿鳞蜥 | ×1 | 整体维护·矿鳞蜥：清水×1（每只·每日）｜养鳞台｜矿鳞蜥｜1AP | 牧草×1；复合陆养料×1；矿质补料×2 |
| 整体维护·净水菌毯 | ×1 | 整体维护·净水菌毯：清水×1（每培养单位·每日）｜净水菌床｜净水菌毯｜1AP | 污水×4；木屑×1；污水×4；炭砂滤料×1 |
| 整体维护·礁骨珊瑚 | ×1 | 整体维护·礁骨珊瑚：清水×1（每群·每轮）｜采礁台｜礁骨珊瑚｜1AP | 藻料×1；石粉×3 |
| 整体维护·岩腹兽 | ×1 | 整体维护·岩腹兽：清水×1（每只·每日）｜选矿场｜岩腹兽｜1AP | 牧草×1；复合陆养料×1；碎铁矿×6 |
| 整体维护·岩腹兽 | ×1 | 整体维护·岩腹兽：清水×1（每只·每日）｜选矿场｜岩腹兽｜1AP | 牧草×1；复合陆养料×1；碎铁矿×6 |
| 整体维护·啮岩鼹 | ×1 | 整体维护·啮岩鼹：清水×1（每只·每日）｜碎岩场｜啮岩鼹｜1AP | 木腐菇×1；普通岩石×2；含铁矿石×2 |
| 整体维护·钢绵羊 | ×1 | 整体维护·钢绵羊：清水×1（每只·每日）｜圈舍｜钢绵羊｜1AP | 牧草×1；谷粒×1；复合陆养料×1；含铁矿石×1；矿质补料×1 |
| 整体维护·钢绵羊 | ×1 | 整体维护·钢绵羊：清水×1（每只·每日）｜圈舍｜钢绵羊｜1AP | 牧草×1；谷粒×1；复合陆养料×1；含铁矿石×1；矿质补料×1 |
| 整体维护·钢绵羊 | ×1 | 整体维护·钢绵羊：清水×1（每只·每日）｜圈舍｜钢绵羊｜1AP | 牧草×1；谷粒×1；复合陆养料×1；含铁矿石×1；矿质补料×1 |
| 播种·木腐菇 | ×2 | 播种·木腐菇：清水×2（每次播种）｜1AP | 木屑×3；木腐菇菌种×1 |
| 启动研究·田间自动维护 | ×4 | 启动研究·田间自动维护：清水×4（一次性）｜研究台 | 腐殖土×2；复合陆养料×1；元石×12 |
| 市集出售·清水 | ×按订单/库存 | 市集出售·清水：清水×按订单/库存（每份） | 元石×1 |
| 田间站自动浇水 | ×1 | 田间站自动浇水：清水×1（每格·每次）｜田间维护站 | — |
| 五行供货·清水 | ×按订单/库存 | 五行供货·清水：清水×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |
| 水场换水（真实） | ×2 | 水场换水（真实）：清水×2（每次）｜1AP | 污水×2 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 复合石板 `resource:composite_stone_panel`

土行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 土行·固体·加工品；标签：building |
| 市集采购 | 不可采购 |
| 市集出售 | 4元石/份（计入销售收入） |

**获取来源（4条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·黏液复合石板 | ×2 | 加工·黏液复合石板：复合石板×2（每批）｜木工台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 砂砾×2；石粉×1；黏液×1 |
| 加工·鳞甲复合板 | ×3 | 加工·鳞甲复合板：复合石板×3（每批）｜木工台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 矿质鳞片×2；蜕皮×1；砂砾×1 |
| 加工·岩壳石板 | ×3 | 加工·岩壳石板：复合石板×3（每批）｜木工台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 岩壳片×2；黏液×1 |
| 加工·复合石板组装 | ×2 | 加工·复合石板组装：复合石板×2（每批）｜木工台｜需研究「矿质材料工艺」｜2自然日｜启动1＋收取1 | 砂砾×2；石粉×1；松脂×1 |

**直接用途（33条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 建造·藻类培养槽 | ×1 | 建造·藻类培养槽：复合石板×1（每次建造（可选1:1替石））｜藻类培养槽｜1AP | 原木×1；普通岩石×1；再生填料×2；元石×6 |
| 建造·水生种植台 | ×2 | 建造·水生种植台：复合石板×2（每次建造（可选1:1替石））｜水生种植台｜1AP | 木板×1；普通岩石×2；再生填料×4；元石×8 |
| 建造·炭化巢 | ×4 | 建造·炭化巢：复合石板×4（每次建造（可选1:1替石））｜炭化巢｜需研究「农产初加工」｜1AP | 木板×2；普通岩石×4；再生填料×8；元石×18 |
| 建造·照料台 | ×2 | 建造·照料台：复合石板×2（每次建造（可选1:1替石））｜照料台｜1AP | 木板×2；普通岩石×2；再生填料×4；元石×24 |
| 建造·捕鲤台 | ×2 | 建造·捕鲤台：复合石板×2（每次建造（可选1:1替石））｜捕鲤台｜1AP | 木板×2；普通岩石×2；再生填料×4；元石×12 |
| 建造·炭化炉 | ×3 | 建造·炭化炉：复合石板×3（每次建造（可选1:1替石））｜炭化炉｜1AP | 原木×2；普通岩石×3；再生填料×6；元石×12 |
| 建造·堆肥箱 | ×1 | 建造·堆肥箱：复合石板×1（每次建造（可选1:1替石））｜堆肥箱｜1AP | 原木×1；普通岩石×1；再生填料×2；元石×6 |
| 建造·翻肥窝 | ×2 | 建造·翻肥窝：复合石板×2（每次建造（可选1:1替石））｜翻肥窝｜1AP | 原木×2；普通岩石×2；再生填料×4；元石×12 |
| 建造·采礁台 | ×4 | 建造·采礁台：复合石板×4（每次建造（可选1:1替石））｜采礁台｜需研究「矿质材料工艺」｜1AP | 木板×2；普通岩石×4；再生填料×8；元石×20 |
| 建造·调度站 | ×2 | 建造·调度站：复合石板×2（每次建造（可选1:1替石））｜调度站｜1AP | 原木×2；普通岩石×2；再生填料×4；元石×18 |
| 建造·农产加工台 | ×2 | 建造·农产加工台：复合石板×2（每次建造（可选1:1替石））｜农产加工台｜需研究「农产初加工」｜1AP | 木板×2；普通岩石×2；再生填料×4；元石×12 |
| 建造·水场 | ×4 | 建造·水场：复合石板×4（每次建造（可选1:1替石））｜水场｜1AP | 普通岩石×4；原木×1；再生填料×8；元石×12 |
| 建造·采胶台 | ×3 | 建造·采胶台：复合石板×3（每次建造（可选1:1替石））｜采胶台｜需研究「水与藻料回流」｜1AP | 木板×2；普通岩石×3；再生填料×6；元石×16 |
| 建造·补光灯 | ×1 | 建造·补光灯：复合石板×1（每次建造）｜补光灯｜需研究「矿质材料工艺」｜1AP | 铁锭×1；元石×12 |
| 建造·厨房 | ×3 | 建造·厨房：复合石板×3（每次建造（可选1:1替石））｜厨房｜需研究「灵食初制」｜1AP | 木板×2；普通岩石×3；再生填料×6；元石×12 |
| 建造·取油台 | ×3 | 建造·取油台：复合石板×3（每次建造（可选1:1替石））｜取油台｜需研究「农产初加工」｜1AP | 木板×2；普通岩石×3；再生填料×6；元石×16 |
| 建造·选矿场 | ×3 | 建造·选矿场：复合石板×3（每次建造（可选1:1替石））｜选矿场｜需研究「生物选矿」｜1AP | 原木×2；普通岩石×3；再生填料×6；元石×12 |
| 建造·采珠台 | ×3 | 建造·采珠台：复合石板×3（每次建造（可选1:1替石））｜采珠台｜需研究「水与藻料回流」｜1AP | 木板×2；普通岩石×3；再生填料×6；元石×16 |
| 建造·圈舍 | ×3 | 建造·圈舍：复合石板×3（每次建造（可选1:1替石））｜圈舍｜1AP | 原木×2；普通岩石×3；再生填料×6；元石×16 |
| 建造·净水菌床 | ×2 | 建造·净水菌床：复合石板×2（每次建造（可选1:1替石））｜净水菌床｜需研究「菌毯净化」｜1AP | 原木×2；普通岩石×2；再生填料×4；元石×10 |
| 建造·研究台 | ×2 | 建造·研究台：复合石板×2（每次建造（可选1:1替石））｜研究台｜1AP | 原木×2；普通岩石×2；再生填料×4；元石×8 |
| 建造·碎岩场 | ×3 | 建造·碎岩场：复合石板×3（每次建造（可选1:1替石））｜碎岩场｜需研究「岩料破碎」｜1AP | 原木×2；普通岩石×3；再生填料×6；元石×12 |
| 建造·养鳞台 | ×4 | 建造·养鳞台：复合石板×4（每次建造（可选1:1替石））｜养鳞台｜需研究「矿质材料工艺」｜1AP | 木板×2；普通岩石×4；再生填料×8；元石×18 |
| 建造·岩壳成型台 | ×4 | 建造·岩壳成型台：复合石板×4（每次建造（可选1:1替石））｜岩壳成型台｜需研究「矿质材料工艺」｜1AP | 木板×2；普通岩石×4；再生填料×8；元石×18 |
| 建造·泥料处理台 | ×2 | 建造·泥料处理台：复合石板×2（每次建造（可选1:1替石））｜泥料处理台｜需研究「菌毯净化」｜1AP | 木板×2；普通岩石×2；再生填料×4；元石×14 |
| 建造·小型冶炼炉 | ×6 | 建造·小型冶炼炉：复合石板×6（每次建造（可选1:1替石））｜小型冶炼炉｜1AP | 木板×2；普通岩石×6；再生填料×12；元石×20 |
| 建造·安抚台 | ×2 | 建造·安抚台：复合石板×2（每次建造（可选1:1替石））｜安抚台｜1AP | 木板×2；普通岩石×2；再生填料×4；元石×18 |
| 建造·集露台 | ×3 | 建造·集露台：复合石板×3（每次建造（可选1:1替石））｜集露台｜1AP | 木板×1；普通岩石×3；再生填料×6；元石×12 |
| 建造·玩具站 | ×2 | 建造·玩具站：复合石板×2（每次建造（可选1:1替石））｜玩具站｜1AP | 木板×2；普通岩石×2；再生填料×4；元石×12 |
| 建造·换水站 | ×4 | 建造·换水站：复合石板×4（每次建造（可选1:1替石））｜换水站｜1AP | 木板×2；普通岩石×4；再生填料×8；元石×16 |
| 建造·木工台 | ×2 | 建造·木工台：复合石板×2（每次建造（可选1:1替石））｜木工台｜1AP | 原木×2；普通岩石×2；再生填料×4；元石×8 |
| 建造·采毛台 | ×2 | 建造·采毛台：复合石板×2（每次建造（可选1:1替石））｜采毛台｜1AP | 木板×2；普通岩石×2；再生填料×4；元石×12 |
| 市集出售·复合石板 | ×按订单/库存 | 市集出售·复合石板：复合石板×按订单/库存（每份） | 元石×4 |

相关规则：[市集交易](#市集交易-rulemarket)

### 珊瑚石 `resource:coral_stone`

土行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 土行·固体·加工品；标签：animal_product |
| 市集采购 | 不可采购 |
| 市集出售 | 2元石/份（计入销售收入） |
| 下游用途 | 无下游配方：出售与供货是该物品的设计出口 |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 收取·礁骨珊瑚 | ×2 | 收取·礁骨珊瑚：珊瑚石×2（每群·每轮）｜采礁台｜礁骨珊瑚｜1AP | — |

**直接用途（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集出售·珊瑚石 | ×按订单/库存 | 市集出售·珊瑚石：珊瑚石×按订单/库存（每份） | 元石×2 |

相关规则：[市集交易](#市集交易-rulemarket)

### 粗油 `resource:crude_oil`

火行液体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 火行·液体·加工品；标签：processing |
| 市集采购 | 不可采购 |
| 市集出售 | 4元石/份（计入销售收入） |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·油籽榨油 | ×2 | 加工·油籽榨油：粗油×2（每批）｜农产加工台｜需研究「农产初加工」｜2自然日｜启动1＋收取1 | 油籽×4；油饼×2 |
| 收取·油鳍鱼 | ×2 | 收取·油鳍鱼：粗油×2（每尾·每轮）｜取油台｜油鳍鱼｜1AP | 鱼肉×1 |

**直接用途（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·油脂精炼 | ×2 | 加工·油脂精炼：粗油×2（每批）｜农产加工台｜需研究「饲料与蜡油精制」｜1自然日｜启动1＋收取1 | 木炭×1；精炼油×2；废滤炭×1 |
| 启动研究·饲料与蜡油精制 | ×1 | 启动研究·饲料与蜡油精制：粗油×1（一次性）｜研究台 | 蜂蜡×1；谷粉×1；元石×8 |
| 市集出售·粗油 | ×按订单/库存 | 市集出售·粗油：粗油×按订单/库存（每份） | 元石×4 |

相关规则：[市集交易](#市集交易-rulemarket)

### 碎铁矿 `resource:crushed_ore`

土行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 土行·固体·加工品；标签：processing |
| 市集采购 | 不可采购 |
| 市集出售 | 2元石/份（计入销售收入） |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·破碎矿石 | ×3 | 加工·破碎矿石：碎铁矿×3（每批）｜碎岩场｜需研究「岩料破碎」｜1自然日｜启动1＋收取1 | 含铁矿石×2 |
| 收取·啮岩鼹 | ×3 | 收取·啮岩鼹：碎铁矿×3（每只·每轮）｜碎岩场｜啮岩鼹｜1AP | 砂砾×2；石粉×1 |

**直接用途（5条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·生物选矿 | ×6 | 加工·生物选矿：碎铁矿×6（每批）｜选矿场｜需研究「生物选矿」｜2自然日｜启动1＋收取1 | 富集矿砂×2；尾砂×1 |
| 加工·矿质补料调配 | ×2 | 加工·矿质补料调配：碎铁矿×2（每批）｜农产加工台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 草粉×2；谷粉×1；矿质补料×2 |
| 整体维护·岩腹兽 | ×6 | 整体维护·岩腹兽：碎铁矿×6（每只·每轮）｜选矿场｜岩腹兽｜1AP | 牧草×1；清水×1；复合陆养料×1；清水×1 |
| 启动研究·生物选矿 | ×2 | 启动研究·生物选矿：碎铁矿×2（一次性）｜研究台 | 砂砾×1；牧草×2；元石×8 |
| 市集出售·碎铁矿 | ×按订单/库存 | 市集出售·碎铁矿：碎铁矿×按订单/库存（每份） | 元石×2 |

相关规则：[市集交易](#市集交易-rulemarket)

### 高密度藻料 `resource:dense_algae`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·加工品；标签：animal_feed |
| 市集采购 | 不可采购 |
| 市集出售 | 4元石/份（计入销售收入） |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·高密度藻培养 | ×3 | 加工·高密度藻培养：高密度藻料×3（每批）｜藻类培养槽｜需研究「水与藻料回流」｜2自然日｜启动1＋收取1 | 营养液×2；清水×1；秸秆×1 |

**直接用途（5条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·藻露羹熬制 | ×1 | 加工·藻露羹熬制：高密度藻料×1（每批）｜厨房｜需研究「复合灵食」｜2自然日｜启动1＋收取1 | 清水×3；花瓣×1；木炭×1；藻露羹×2 |
| 整体维护·滤藻鲤 | ×1 | 整体维护·滤藻鲤：高密度藻料×1（每尾·每日）｜捕鲤台｜滤藻鲤｜1AP | 藻料×1；复合水养料×1；谷粒×1 |
| 整体维护·凝胶水母 | ×1 | 整体维护·凝胶水母：高密度藻料×1（每群·每日）｜采胶台｜凝胶水母｜1AP | 藻料×1；清水×1 |
| 启动研究·复合灵食 | ×1 | 启动研究·复合灵食：高密度藻料×1（一次性）｜研究台 | 精炼油×1；铁锭×1；元石×12 |
| 市集出售·高密度藻料 | ×按订单/库存 | 市集出售·高密度藻料：高密度藻料×按订单/库存（每份） | 元石×4 |

相关规则：[市集交易](#市集交易-rulemarket)

### 藻露羹 `resource:dew_soup`

水行液体；可供货（供养值9）

| 字段 | 内容 |
|---|---|
| 分类 | 水行·液体·加工品；标签：food |
| 市集采购 | 不可采购 |
| 市集出售 | 7元石/份（计入销售收入） |
| 五行供货 | 可供货（水行）；供养值9：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |
| 下游用途 | 无下游配方：出售与供货是该物品的设计出口 |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·藻露羹熬制 | ×2 | 加工·藻露羹熬制：藻露羹×2（每批）｜厨房｜需研究「复合灵食」｜2自然日｜启动1＋收取1 | 高密度藻料×1；清水×3；花瓣×1；木炭×1 |

**直接用途（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集出售·藻露羹 | ×按订单/库存 | 市集出售·藻露羹：藻露羹×按订单/库存（每份） | 元石×7 |
| 五行供货·藻露羹 | ×按订单/库存 | 五行供货·藻露羹：藻露羹×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 腐土菌丸 `resource:earth_pill`

土行固体；可供货（供养值13）

| 字段 | 内容 |
|---|---|
| 分类 | 土行·固体·加工品；标签：food |
| 市集采购 | 不可采购 |
| 市集出售 | 8元石/份（计入销售收入） |
| 五行供货 | 可供货（土行）；供养值13：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |
| 下游用途 | 无下游配方：出售与供货是该物品的设计出口 |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·腐土菌丸炼制 | ×2 | 加工·腐土菌丸炼制：腐土菌丸×2（每批）｜厨房｜需研究「复合灵食」｜2自然日｜启动1＋收取1 | 腐殖土×2；木腐菇×1；草粉×1；木炭×1 |

**直接用途（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集出售·腐土菌丸 | ×按订单/库存 | 市集出售·腐土菌丸：腐土菌丸×按订单/库存（每份） | 元石×8 |
| 五行供货·腐土菌丸 | ×按订单/库存 | 五行供货·腐土菌丸：腐土菌丸×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 速生杉苗 `resource:fast_fir_seed`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：seed、cultivation |
| 市集采购 | 8元石/份 |
| 市集出售 | 不可出售 |

**获取来源（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集采购·速生杉苗 | ×按订单/库存 | 市集采购·速生杉苗：速生杉苗×按订单/库存（每份） | 元石×8 |
| 新档初始物资 | ×2 | 新档初始物资：速生杉苗×2（每新档一次性） | 金穗麦种子×8；松脂树苗×1；木腐菇菌种×4 |
| 育种奖励·速生杉 | ×1 | 育种奖励·速生杉：速生杉苗×1（每株首次成熟；成功时） | — |

**直接用途（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 播种·速生杉 | ×1 | 播种·速生杉：速生杉苗×1（每次播种）｜1AP | — |

相关规则：[市集交易](#市集交易-rulemarket)

### 炭砂滤料 `resource:filter_media`

土行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 土行·固体·加工品；标签：processing |
| 市集采购 | 不可采购 |
| 市集出售 | 2元石/份（计入销售收入） |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·炭砂滤料制作 | ×2 | 加工·炭砂滤料制作：炭砂滤料×2（每批）｜木工台｜需研究「水与藻料回流」｜1自然日｜启动1＋收取1 | 木炭×1；砂砾×2 |
| 加工·丝质滤材 | ×3 | 加工·丝质滤材：炭砂滤料×3（每批）｜木工台｜需研究「水与藻料回流」｜1自然日｜启动1＋收取1 | 蚕丝×1；木屑×1；木炭×1 |

**直接用途（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·营养液回收 | ×1 | 加工·营养液回收：炭砂滤料×1（每批）｜净水菌床｜需研究「水与藻料回流」｜2自然日｜启动1＋收取1 | 污水×4；营养液×2；清水×1；污泥×1 |
| 整体维护·净水菌毯 | ×1 | 整体维护·净水菌毯：炭砂滤料×1（每培养单位·每轮）｜净水菌床｜净水菌毯｜1AP | 清水×1；污水×4；木屑×1；污水×4 |
| 市集出售·炭砂滤料 | ×按订单/库存 | 市集出售·炭砂滤料：炭砂滤料×按订单/库存（每份） | 元石×2 |

相关规则：[市集交易](#市集交易-rulemarket)

### 蜜油火膏 `resource:fire_paste`

火行固体；可供货（供养值19）

| 字段 | 内容 |
|---|---|
| 分类 | 火行·固体·加工品；标签：food |
| 市集采购 | 不可采购 |
| 市集出售 | 12元石/份（计入销售收入） |
| 五行供货 | 可供货（火行）；供养值19：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |
| 下游用途 | 无下游配方：出售与供货是该物品的设计出口 |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·蜜油火膏熬制 | ×2 | 加工·蜜油火膏熬制：蜜油火膏×2（每批）｜厨房｜需研究「复合灵食」｜2自然日｜启动1＋收取1 | 精炼油×1；蜂蜜×1；精炼蜡×1；木炭×1 |

**直接用途（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集出售·蜜油火膏 | ×按订单/库存 | 市集出售·蜜油火膏：蜜油火膏×按订单/库存（每份） | 元石×12 |
| 五行供货·蜜油火膏 | ×按订单/库存 | 五行供货·蜜油火膏：蜜油火膏×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 鱼粪 `resource:fish_manure`

土行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 土行·固体·初级；标签：organic、processing |
| 市集采购 | 不可采购 |
| 市集出售 | 1元石/份（计入销售收入） |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 收取·滤藻鲤 | ×1 | 收取·滤藻鲤：鱼粪×1（每尾·每轮）｜捕鲤台｜滤藻鲤｜1AP | 鱼肉×3 |

**直接用途（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·鱼粪堆肥 | ×2 | 加工·鱼粪堆肥：鱼粪×2（每批）｜堆肥箱｜2自然日｜启动1＋收取1 | 腐殖土×2 |
| 市集出售·鱼粪 | ×按订单/库存 | 市集出售·鱼粪：鱼粪×按订单/库存（每份） | 元石×1 |

相关规则：[市集交易](#市集交易-rulemarket)

### 鱼肉 `resource:fish_meat`

木行固体；可供货（供养值7）

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：food、animal_product |
| 市集采购 | 不可采购 |
| 市集出售 | 9元石/份（计入销售收入） |
| 五行供货 | 可供货（木行）；供养值7：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 收取·滤藻鲤 | ×3 | 收取·滤藻鲤：鱼肉×3（每尾·每轮）｜捕鲤台｜滤藻鲤｜1AP | 鱼粪×1 |
| 收取·油鳍鱼 | ×1 | 收取·油鳍鱼：鱼肉×1（每尾·每轮）｜取油台｜油鳍鱼｜1AP | 粗油×2 |

**直接用途（4条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·菌鱼灵膳烹制 | ×1 | 加工·菌鱼灵膳烹制：鱼肉×1（每批）｜厨房｜需研究「灵食初制」｜1自然日｜启动1＋收取1 | 木腐菇×1；精炼油×1；木炭×1；菌鱼灵膳×2 |
| 启动研究·灵食初制 | ×1 | 启动研究·灵食初制：鱼肉×1（一次性）｜研究台 | 蜂蜜×1；谷粉×1；元石×8 |
| 市集出售·鱼肉 | ×按订单/库存 | 市集出售·鱼肉：鱼肉×按订单/库存（每份） | 元石×9 |
| 五行供货·鱼肉 | ×按订单/库存 | 五行供货·鱼肉：鱼肉×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 菌鱼灵膳 `resource:fish_spirit_meal`

木行固体；可供货（供养值13）

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·加工品；标签：food |
| 市集采购 | 不可采购 |
| 市集出售 | 12元石/份（计入销售收入） |
| 五行供货 | 可供货（木行）；供养值13：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |
| 下游用途 | 无下游配方：出售与供货是该物品的设计出口 |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·菌鱼灵膳烹制 | ×2 | 加工·菌鱼灵膳烹制：菌鱼灵膳×2（每批）｜厨房｜需研究「灵食初制」｜1自然日｜启动1＋收取1 | 木腐菇×1；鱼肉×1；精炼油×1；木炭×1 |

**直接用途（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集出售·菌鱼灵膳 | ×按订单/库存 | 市集出售·菌鱼灵膳：菌鱼灵膳×按订单/库存（每份） | 元石×12 |
| 五行供货·菌鱼灵膳 | ×按订单/库存 | 五行供货·菌鱼灵膳：菌鱼灵膳×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 花瓣 `resource:flower_petal`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：food |
| 市集采购 | 不可采购 |
| 市集出售 | 1元石/份（计入销售收入） |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 收获·油籽花 | ×1 | 收获·油籽花：花瓣×1（每次收获）｜1AP | 油籽×4；油籽×1 |

**直接用途（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·藻露羹熬制 | ×1 | 加工·藻露羹熬制：花瓣×1（每批）｜厨房｜需研究「复合灵食」｜2自然日｜启动1＋收取1 | 高密度藻料×1；清水×3；木炭×1；藻露羹×2 |
| 市集出售·花瓣 | ×按订单/库存 | 市集出售·花瓣：花瓣×按订单/库存（每份） | 元石×1 |

相关规则：[市集交易](#市集交易-rulemarket)

### 牧草 `resource:fodder_grass`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：animal_feed、organic |
| 市集采购 | 2元石/份 |
| 市集出售 | 1元石/份（计入销售收入） |

**获取来源（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集采购·牧草 | ×按订单/库存 | 市集采购·牧草：牧草×按订单/库存（每份） | 元石×2 |
| 收获·青牧草 | ×3 | 收获·青牧草：牧草×3（每次收获）｜1AP | — |
| 丰产奖励·青牧草·收取 | ×按订单/库存 | 丰产奖励·青牧草·收取：牧草×按订单/库存（每轮额外份数） | — |

**直接用途（10条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·牧草堆肥 | ×2 | 加工·牧草堆肥：牧草×2（每批）｜堆肥箱｜2自然日｜启动1＋收取1 | 腐殖土×2 |
| 加工·草粉研磨 | ×3 | 加工·草粉研磨：牧草×3（每批）｜农产加工台｜需研究「农产初加工」｜1自然日｜启动1＋收取1 | 草粉×2 |
| 整体维护·炭腹虫 | ×1 | 整体维护·炭腹虫：牧草×1（每群·每日）｜炭化巢｜炭腹虫｜1AP | 清水×1；枝条×4；木屑×4 |
| 整体维护·堆肥鼠 | ×1 | 整体维护·堆肥鼠：牧草×1（每只·每日）｜翻肥窝｜堆肥鼠｜1AP | 清水×1；秸秆×2；木屑×1；污泥×2；油饼×1 |
| 整体维护·露壳蜗牛 | ×1 | 整体维护·露壳蜗牛：牧草×1（每只·每日）｜集露台｜露壳蜗牛｜1AP | 清水×1；清水×2 |
| 整体维护·矿鳞蜥 | ×1 | 整体维护·矿鳞蜥：牧草×1（每只·每日）｜养鳞台｜矿鳞蜥｜1AP | 清水×1；复合陆养料×1；清水×1；矿质补料×2 |
| 整体维护·岩腹兽 | ×1 | 整体维护·岩腹兽：牧草×1（每只·每日）｜选矿场｜岩腹兽｜1AP | 清水×1；复合陆养料×1；清水×1；碎铁矿×6 |
| 整体维护·钢绵羊 | ×1 | 整体维护·钢绵羊：牧草×1（每只·每日）｜圈舍｜钢绵羊｜1AP | 清水×1；谷粒×1；清水×1；复合陆养料×1；清水×1；含铁矿石×1 |
| 启动研究·生物选矿 | ×2 | 启动研究·生物选矿：牧草×2（一次性）｜研究台 | 碎铁矿×2；砂砾×1；元石×8 |
| 市集出售·牧草 | ×按订单/库存 | 市集出售·牧草：牧草×按订单/库存（每份） | 元石×1 |

相关规则：[市集交易](#市集交易-rulemarket)

### 蜜炼金食 `resource:gold_food`

金行固体；可供货（供养值27）

| 字段 | 内容 |
|---|---|
| 分类 | 金行·固体·加工品；标签：food |
| 市集采购 | 不可采购 |
| 市集出售 | 20元石/份（计入销售收入） |
| 五行供货 | 可供货（金行）；供养值27：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |
| 下游用途 | 无下游配方：出售与供货是该物品的设计出口 |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·蜜炼金食炼制 | ×1 | 加工·蜜炼金食炼制：蜜炼金食×1（每批）｜厨房｜需研究「复合灵食」｜2自然日｜启动1＋收取1 | 铁锭×1；蜂蜜×1；木炭×1 |

**直接用途（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集出售·蜜炼金食 | ×按订单/库存 | 市集出售·蜜炼金食：蜜炼金食×按订单/库存（每份） | 元石×20 |
| 五行供货·蜜炼金食 | ×按订单/库存 | 五行供货·蜜炼金食：蜜炼金食×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 金穗麦种子 `resource:golden_wheat_seed`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：seed、cultivation |
| 市集采购 | 3元石/份 |
| 市集出售 | 不可出售 |

**获取来源（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集采购·金穗麦种子 | ×按订单/库存 | 市集采购·金穗麦种子：金穗麦种子×按订单/库存（每份） | 元石×3 |
| 新档初始物资 | ×8 | 新档初始物资：金穗麦种子×8（每新档一次性） | 速生杉苗×2；松脂树苗×1；木腐菇菌种×4 |
| 育种奖励·金穗麦 | ×1 | 育种奖励·金穗麦：金穗麦种子×1（每株首次成熟；成功时） | — |

**直接用途（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 播种·金穗麦 | ×1 | 播种·金穗麦：金穗麦种子×1（每次播种）｜1AP | — |

相关规则：[市集交易](#市集交易-rulemarket)

### 谷粒 `resource:grain`

木行固体；可供货（供养值4）

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：food |
| 市集采购 | 6元石/份 |
| 市集出售 | 4元石/份（计入销售收入） |
| 五行供货 | 可供货（木行）；供养值4：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |

**获取来源（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集采购·谷粒 | ×按订单/库存 | 市集采购·谷粒：谷粒×按订单/库存（每份） | 元石×6 |
| 收获·金穗麦 | ×3 | 收获·金穗麦：谷粒×3（每次收获）｜1AP | 秸秆×2 |
| 丰产奖励·金穗麦·收取 | ×按订单/库存 | 丰产奖励·金穗麦·收取：谷粒×按订单/库存（每轮额外份数） | — |

**直接用途（6条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·谷粉研磨 | ×2 | 加工·谷粉研磨：谷粒×2（每批）｜农产加工台｜需研究「农产初加工」｜1自然日｜启动1＋收取1 | 谷粉×2 |
| 整体维护·滤藻鲤 | ×1 | 整体维护·滤藻鲤：谷粒×1（每尾·每轮）｜捕鲤台｜滤藻鲤｜1AP | 藻料×1；复合水养料×1；高密度藻料×1 |
| 整体维护·钢绵羊 | ×1 | 整体维护·钢绵羊：谷粒×1（每只·每日）｜圈舍｜钢绵羊｜1AP | 牧草×1；清水×1；清水×1；复合陆养料×1；清水×1；含铁矿石×1 |
| 启动研究·花源栽培 | ×2 | 启动研究·花源栽培：谷粒×2（一次性）｜研究台 | 腐殖土×1；元石×4 |
| 市集出售·谷粒 | ×按订单/库存 | 市集出售·谷粒：谷粒×按订单/库存（每份） | 元石×4 |
| 五行供货·谷粒 | ×按订单/库存 | 五行供货·谷粒：谷粒×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 谷粉 `resource:grain_meal`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·加工品；标签：food、animal_feed |
| 市集采购 | 不可采购 |
| 市集出售 | 3元石/份（计入销售收入） |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·谷粉研磨 | ×2 | 加工·谷粉研磨：谷粉×2（每批）｜农产加工台｜需研究「农产初加工」｜1自然日｜启动1＋收取1 | 谷粒×2 |
| 加工·稻米磨粉 | ×2 | 加工·稻米磨粉：谷粉×2（每批）｜农产加工台｜需研究「农产初加工」｜1自然日｜启动1＋收取1 | 稻米×3 |

**直接用途（7条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·陆养料调配 | ×1 | 加工·陆养料调配：谷粉×1（每批）｜农产加工台｜需研究「饲料与蜡油精制」｜1自然日｜启动1＋收取1 | 草粉×2；油饼×1；复合陆养料×3 |
| 加工·水养料调配 | ×1 | 加工·水养料调配：谷粉×1（每批）｜农产加工台｜需研究「饲料与蜡油精制」｜1自然日｜启动1＋收取1 | 藻料×3；油饼×1；复合水养料×4 |
| 加工·蜜谷灵饼烘焙 | ×2 | 加工·蜜谷灵饼烘焙：谷粉×2（每批）｜厨房｜需研究「灵食初制」｜1自然日｜启动1＋收取1 | 蜂蜜×1；清水×1；木炭×1；蜜谷灵饼×2 |
| 加工·矿质补料调配 | ×1 | 加工·矿质补料调配：谷粉×1（每批）｜农产加工台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 碎铁矿×2；草粉×2；矿质补料×2 |
| 启动研究·饲料与蜡油精制 | ×1 | 启动研究·饲料与蜡油精制：谷粉×1（一次性）｜研究台 | 粗油×1；蜂蜡×1；元石×8 |
| 启动研究·灵食初制 | ×1 | 启动研究·灵食初制：谷粉×1（一次性）｜研究台 | 蜂蜜×1；鱼肉×1；元石×8 |
| 市集出售·谷粉 | ×按订单/库存 | 市集出售·谷粉：谷粉×按订单/库存（每份） | 元石×3 |

相关规则：[市集交易](#市集交易-rulemarket)

### 草粉 `resource:grass_meal`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·加工品；标签：animal_feed |
| 市集采购 | 不可采购 |
| 市集出售 | 1元石/份（计入销售收入） |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·草粉研磨 | ×2 | 加工·草粉研磨：草粉×2（每批）｜农产加工台｜需研究「农产初加工」｜1自然日｜启动1＋收取1 | 牧草×3 |

**直接用途（4条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·陆养料调配 | ×2 | 加工·陆养料调配：草粉×2（每批）｜农产加工台｜需研究「饲料与蜡油精制」｜1自然日｜启动1＋收取1 | 谷粉×1；油饼×1；复合陆养料×3 |
| 加工·矿质补料调配 | ×2 | 加工·矿质补料调配：草粉×2（每批）｜农产加工台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 碎铁矿×2；谷粉×1；矿质补料×2 |
| 加工·腐土菌丸炼制 | ×1 | 加工·腐土菌丸炼制：草粉×1（每批）｜厨房｜需研究「复合灵食」｜2自然日｜启动1＋收取1 | 腐殖土×2；木腐菇×1；木炭×1；腐土菌丸×2 |
| 市集出售·草粉 | ×按订单/库存 | 市集出售·草粉：草粉×按订单/库存（每份） | 元石×1 |

相关规则：[市集交易](#市集交易-rulemarket)

### 草籽 `resource:grass_seed`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：seed、cultivation |
| 市集采购 | 2元石/份 |
| 市集出售 | 不可出售 |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集采购·草籽 | ×按订单/库存 | 市集采购·草籽：草籽×按订单/库存（每份） | 元石×2 |
| 育种奖励·青牧草 | ×1 | 育种奖励·青牧草：草籽×1（每株首次成熟；成功时） | — |

**直接用途（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 播种·青牧草 | ×1 | 播种·青牧草：草籽×1（每次播种）｜1AP | — |

相关规则：[市集交易](#市集交易-rulemarket)

### 砂砾 `resource:gravel`

土行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 土行·固体·初级；标签：building、processing |
| 市集采购 | 不可采购 |
| 市集出售 | 1元石/份（计入销售收入） |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·破碎石材 | ×2 | 加工·破碎石材：砂砾×2（每批）｜碎岩场｜需研究「岩料破碎」｜1自然日｜启动1＋收取1 | 普通岩石×2；石粉×1 |
| 收取·啮岩鼹 | ×2 | 收取·啮岩鼹：砂砾×2（每只·每轮）｜碎岩场｜啮岩鼹｜1AP | 石粉×1；碎铁矿×3 |

**直接用途（7条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·黏液复合石板 | ×2 | 加工·黏液复合石板：砂砾×2（每批）｜木工台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 石粉×1；黏液×1；复合石板×2 |
| 加工·鳞甲复合板 | ×1 | 加工·鳞甲复合板：砂砾×1（每批）｜木工台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 矿质鳞片×2；蜕皮×1；复合石板×3 |
| 加工·复合石板组装 | ×2 | 加工·复合石板组装：砂砾×2（每批）｜木工台｜需研究「矿质材料工艺」｜2自然日｜启动1＋收取1 | 石粉×1；松脂×1；复合石板×2 |
| 加工·炭砂滤料制作 | ×2 | 加工·炭砂滤料制作：砂砾×2（每批）｜木工台｜需研究「水与藻料回流」｜1自然日｜启动1＋收取1 | 木炭×1；炭砂滤料×2 |
| 启动研究·生物选矿 | ×1 | 启动研究·生物选矿：砂砾×1（一次性）｜研究台 | 碎铁矿×2；牧草×2；元石×8 |
| 启动研究·水与藻料回流 | ×1 | 启动研究·水与藻料回流：砂砾×1（一次性）｜研究台 | 污泥×1；木炭×1；元石×8 |
| 市集出售·砂砾 | ×按订单/库存 | 市集出售·砂砾：砂砾×按订单/库存（每份） | 元石×1 |

相关规则：[市集交易](#市集交易-rulemarket)

### 蜂蜜 `resource:honey`

木行固体；可供货（供养值10）

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：food、animal_product |
| 市集采购 | 不可采购 |
| 市集出售 | 6元石/份（计入销售收入） |
| 五行供货 | 可供货（木行）；供养值10：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 收取·蜜盏蜂 | ×2 | 收取·蜜盏蜂：蜂蜜×2（每群·每轮）｜蜂箱｜蜜盏蜂｜1AP | 蜂蜡×1 |

**直接用途（6条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·蜜谷灵饼烘焙 | ×1 | 加工·蜜谷灵饼烘焙：蜂蜜×1（每批）｜厨房｜需研究「灵食初制」｜1自然日｜启动1＋收取1 | 谷粉×2；清水×1；木炭×1；蜜谷灵饼×2 |
| 加工·蜜炼金食炼制 | ×1 | 加工·蜜炼金食炼制：蜂蜜×1（每批）｜厨房｜需研究「复合灵食」｜2自然日｜启动1＋收取1 | 铁锭×1；木炭×1；蜜炼金食×1 |
| 加工·蜜油火膏熬制 | ×1 | 加工·蜜油火膏熬制：蜂蜜×1（每批）｜厨房｜需研究「复合灵食」｜2自然日｜启动1＋收取1 | 精炼油×1；精炼蜡×1；木炭×1；蜜油火膏×2 |
| 启动研究·灵食初制 | ×1 | 启动研究·灵食初制：蜂蜜×1（一次性）｜研究台 | 谷粉×1；鱼肉×1；元石×8 |
| 市集出售·蜂蜜 | ×按订单/库存 | 市集出售·蜂蜜：蜂蜜×按订单/库存（每份） | 元石×6 |
| 五行供货·蜂蜜 | ×按订单/库存 | 五行供货·蜂蜜：蜂蜜×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 蜜谷灵饼 `resource:honey_cake`

木行固体；可供货（供养值13）

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·加工品；标签：food |
| 市集采购 | 不可采购 |
| 市集出售 | 8元石/份（计入销售收入） |
| 五行供货 | 可供货（木行）；供养值13：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |
| 下游用途 | 无下游配方：出售与供货是该物品的设计出口 |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·蜜谷灵饼烘焙 | ×2 | 加工·蜜谷灵饼烘焙：蜜谷灵饼×2（每批）｜厨房｜需研究「灵食初制」｜1自然日｜启动1＋收取1 | 谷粉×2；蜂蜜×1；清水×1；木炭×1 |

**直接用途（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集出售·蜜谷灵饼 | ×按订单/库存 | 市集出售·蜜谷灵饼：蜜谷灵饼×按订单/库存（每份） | 元石×8 |
| 五行供货·蜜谷灵饼 | ×按订单/库存 | 五行供货·蜜谷灵饼：蜜谷灵饼×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 蜜铃苗 `resource:honeybell_seed`

木行固体；生产材料

> 解锁条件：需完成研究 [花源栽培](#花源栽培-researchflower_cultivation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：seed、cultivation |
| 市集采购 | 8元石/份 |
| 市集出售 | 不可出售 |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集采购·蜜铃苗 | ×按订单/库存 | 市集采购·蜜铃苗：蜜铃苗×按订单/库存（每份）｜需研究「花源栽培」 | 元石×8 |
| 育种奖励·蜜铃灌木 | ×1 | 育种奖励·蜜铃灌木：蜜铃苗×1（每株首次成熟；成功时） | — |

**直接用途（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 播种·蜜铃灌木 | ×1 | 播种·蜜铃灌木：蜜铃苗×1（每次播种）｜需研究「花源栽培」｜1AP | — |

关联条目：解锁研究：[花源栽培](#花源栽培-researchflower_cultivation)

相关规则：[市集交易](#市集交易-rulemarket)

### 腐殖土 `resource:humus`

土行固体；可供货（供养值4）

| 字段 | 内容 |
|---|---|
| 分类 | 土行·固体·加工品；标签：food、fertilizer |
| 市集采购 | 不可采购 |
| 市集出售 | 4元石/份（计入销售收入） |
| 五行供货 | 可供货（土行）；供养值4：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |

**获取来源（19条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·木屑生物炭化 | ×1 | 加工·木屑生物炭化：腐殖土×1（每批）｜炭化巢｜需研究「农产初加工」｜1自然日｜启动1＋收取1 | 木屑×4；木炭×2 |
| 加工·树枝生物炭化 | ×1 | 加工·树枝生物炭化：腐殖土×1（每批）｜炭化巢｜需研究「农产初加工」｜1自然日｜启动1＋收取1 | 枝条×4；木炭×4 |
| 加工·木屑堆肥 | ×2 | 加工·木屑堆肥：腐殖土×2（每批）｜堆肥箱｜2自然日｜启动1＋收取1 | 木屑×3 |
| 加工·鱼粪堆肥 | ×2 | 加工·鱼粪堆肥：腐殖土×2（每批）｜堆肥箱｜2自然日｜启动1＋收取1 | 鱼粪×2 |
| 加工·牧草堆肥 | ×2 | 加工·牧草堆肥：腐殖土×2（每批）｜堆肥箱｜2自然日｜启动1＋收取1 | 牧草×2 |
| 加工·油饼堆肥 | ×2 | 加工·油饼堆肥：腐殖土×2（每批）｜堆肥箱｜需研究「农产初加工」｜2自然日｜启动1＋收取1 | 油饼×2 |
| 加工·羊粪堆肥 | ×2 | 加工·羊粪堆肥：腐殖土×2（每批）｜堆肥箱｜2自然日｜启动1＋收取1 | 羊粪肥×2 |
| 加工·污泥堆肥 | ×2 | 加工·污泥堆肥：腐殖土×2（每批）｜堆肥箱｜需研究「菌毯净化」｜2自然日｜启动1＋收取1 | 污泥×2 |
| 加工·废滤炭堆肥 | ×1 | 加工·废滤炭堆肥：腐殖土×1（每批）｜堆肥箱｜需研究「饲料与蜡油精制」｜2自然日｜启动1＋收取1 | 废滤炭×2 |
| 加工·秸秆堆肥 | ×2 | 加工·秸秆堆肥：腐殖土×2（每批）｜堆肥箱｜2自然日｜启动1＋收取1 | 秸秆×2 |
| 加工·枝条堆肥 | ×2 | 加工·枝条堆肥：腐殖土×2（每批）｜堆肥箱｜2自然日｜启动1＋收取1 | 枝条×3 |
| 加工·秸秆翻肥 | ×4 | 加工·秸秆翻肥：腐殖土×4（每批）｜翻肥窝｜1自然日｜启动1＋收取1 | 秸秆×2；木屑×1 |
| 加工·残料翻肥 | ×3 | 加工·残料翻肥：腐殖土×3（每批）｜翻肥窝｜需研究「菌毯净化」｜1自然日｜启动1＋收取1 | 污泥×2；油饼×1 |
| 收取·炭腹虫 | ×1 | 收取·炭腹虫：腐殖土×1（每群·每轮）｜炭化巢｜炭腹虫｜1AP | 木炭×4；木炭×2 |
| 收取·炭腹虫 | ×1 | 收取·炭腹虫：腐殖土×1（每群·每轮）｜炭化巢｜炭腹虫｜1AP | 木炭×4；木炭×2 |
| 收取·堆肥鼠 | ×4 | 收取·堆肥鼠：腐殖土×4（每只·每轮）｜翻肥窝｜堆肥鼠｜1AP | — |
| 收取·堆肥鼠 | ×3 | 收取·堆肥鼠：腐殖土×3（每只·每轮）｜翻肥窝｜堆肥鼠｜1AP | — |
| 收取·净泥鳅 | ×3 | 收取·净泥鳅：腐殖土×3（每尾·每轮）｜泥料处理台｜净泥鳅｜1AP | — |
| 收获·木腐菇 | ×1 | 收获·木腐菇：腐殖土×1（每次收获）｜1AP | 木腐菇×3 |

**直接用途（7条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·腐土菌丸炼制 | ×2 | 加工·腐土菌丸炼制：腐殖土×2（每批）｜厨房｜需研究「复合灵食」｜2自然日｜启动1＋收取1 | 木腐菇×1；草粉×1；木炭×1；腐土菌丸×2 |
| 施肥 | ×1 | 施肥：腐殖土×1（每次）｜1AP | — |
| 启动研究·田间自动维护 | ×2 | 启动研究·田间自动维护：腐殖土×2（一次性）｜研究台 | 清水×4；复合陆养料×1；元石×12 |
| 启动研究·花源栽培 | ×1 | 启动研究·花源栽培：腐殖土×1（一次性）｜研究台 | 谷粒×2；元石×4 |
| 市集出售·腐殖土 | ×按订单/库存 | 市集出售·腐殖土：腐殖土×按订单/库存（每份） | 元石×4 |
| 田间站自动施肥 | ×1 | 田间站自动施肥：腐殖土×1（每格·每次）｜田间维护站 | — |
| 五行供货·腐殖土 | ×按订单/库存 | 五行供货·腐殖土：腐殖土×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 铁锭 `resource:iron_ingot`

金行固体；可供货（供养值10）

| 字段 | 内容 |
|---|---|
| 分类 | 金行·固体·加工品；标签：food、building |
| 市集采购 | 不可采购 |
| 市集出售 | 12元石/份（计入销售收入） |
| 五行供货 | 可供货（金行）；供养值10：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |

**获取来源（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·木炭冶炼 | ×1 | 加工·木炭冶炼：铁锭×1（每批）｜小型冶炼炉｜2自然日｜启动1＋收取1 | 含铁矿石×3；木炭×1 |
| 加工·富集矿冶炼 | ×1 | 加工·富集矿冶炼：铁锭×1（每批）｜小型冶炼炉｜需研究「矿质材料工艺」｜2自然日｜启动1＋收取1 | 富集矿砂×1；木炭×1；炉渣×1 |
| 加工·松脂冶炼 | ×1 | 加工·松脂冶炼：铁锭×1（每批）｜小型冶炼炉｜2自然日｜启动1＋收取1 | 含铁矿石×3；松脂×1 |

**直接用途（7条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·蜜炼金食炼制 | ×1 | 加工·蜜炼金食炼制：铁锭×1（每批）｜厨房｜需研究「复合灵食」｜2自然日｜启动1＋收取1 | 蜂蜜×1；木炭×1；蜜炼金食×1 |
| 建造·田间维护站 | ×1 | 建造·田间维护站：铁锭×1（每次建造）｜田间维护站｜需研究「田间自动维护」｜1AP | 木板×3；元石×18 |
| 建造·补光灯 | ×1 | 建造·补光灯：铁锭×1（每次建造）｜补光灯｜需研究「矿质材料工艺」｜1AP | 复合石板×1；元石×12 |
| 启动研究·复合灵食 | ×1 | 启动研究·复合灵食：铁锭×1（一次性）｜研究台 | 精炼油×1；高密度藻料×1；元石×12 |
| 启动研究·矿质材料工艺 | ×1 | 启动研究·矿质材料工艺：铁锭×1（一次性）｜研究台 | 富集矿砂×1；石粉×1；元石×12 |
| 市集出售·铁锭 | ×按订单/库存 | 市集出售·铁锭：铁锭×按订单/库存（每份） | 元石×12 |
| 五行供货·铁锭 | ×按订单/库存 | 五行供货·铁锭：铁锭×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 含铁矿石 `resource:iron_ore`

土行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 土行·固体·初级；标签：processing |
| 市集采购 | 4元石/份 |
| 市集出售 | 2元石/份（计入销售收入） |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集采购·含铁矿石 | ×按订单/库存 | 市集采购·含铁矿石：含铁矿石×按订单/库存（每份） | 元石×4 |
| 采矿点采集 | ×2 | 采矿点采集：含铁矿石×2（每次）｜1AP | — |

**直接用途（6条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·破碎矿石 | ×2 | 加工·破碎矿石：含铁矿石×2（每批）｜碎岩场｜需研究「岩料破碎」｜1自然日｜启动1＋收取1 | 碎铁矿×3 |
| 加工·木炭冶炼 | ×3 | 加工·木炭冶炼：含铁矿石×3（每批）｜小型冶炼炉｜2自然日｜启动1＋收取1 | 木炭×1；铁锭×1 |
| 加工·松脂冶炼 | ×3 | 加工·松脂冶炼：含铁矿石×3（每批）｜小型冶炼炉｜2自然日｜启动1＋收取1 | 松脂×1；铁锭×1 |
| 整体维护·啮岩鼹 | ×2 | 整体维护·啮岩鼹：含铁矿石×2（每只·每轮）｜碎岩场｜啮岩鼹｜1AP | 木腐菇×1；清水×1；普通岩石×2 |
| 整体维护·钢绵羊 | ×1 | 整体维护·钢绵羊：含铁矿石×1（每只·每轮）｜圈舍｜钢绵羊｜1AP | 牧草×1；清水×1；谷粒×1；清水×1；复合陆养料×1；清水×1 |
| 市集出售·含铁矿石 | ×按订单/库存 | 市集出售·含铁矿石：含铁矿石×按订单/库存（每份） | 元石×2 |

相关规则：[市集交易](#市集交易-rulemarket)

### 复合陆养料 `resource:land_feed`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·加工品；标签：animal_feed |
| 市集采购 | 不可采购 |
| 市集出售 | 3元石/份（计入销售收入） |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·陆养料调配 | ×3 | 加工·陆养料调配：复合陆养料×3（每批）｜农产加工台｜需研究「饲料与蜡油精制」｜1自然日｜启动1＋收取1 | 谷粉×1；草粉×2；油饼×1 |

**直接用途（5条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 整体维护·矿鳞蜥 | ×1 | 整体维护·矿鳞蜥：复合陆养料×1（每只·每日）｜养鳞台｜矿鳞蜥｜1AP | 牧草×1；清水×1；清水×1；矿质补料×2 |
| 整体维护·岩腹兽 | ×1 | 整体维护·岩腹兽：复合陆养料×1（每只·每日）｜选矿场｜岩腹兽｜1AP | 牧草×1；清水×1；清水×1；碎铁矿×6 |
| 整体维护·钢绵羊 | ×1 | 整体维护·钢绵羊：复合陆养料×1（每只·每日）｜圈舍｜钢绵羊｜1AP | 牧草×1；清水×1；谷粒×1；清水×1；清水×1；含铁矿石×1 |
| 启动研究·田间自动维护 | ×1 | 启动研究·田间自动维护：复合陆养料×1（一次性）｜研究台 | 腐殖土×2；清水×4；元石×12 |
| 市集出售·复合陆养料 | ×按订单/库存 | 市集出售·复合陆养料：复合陆养料×按订单/库存（每份） | 元石×3 |

相关规则：[市集交易](#市集交易-rulemarket)

### 矿质补料 `resource:mineral_feed`

土行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 土行·固体·加工品；标签：animal_feed |
| 市集采购 | 不可采购 |
| 市集出售 | 4元石/份（计入销售收入） |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·矿质补料调配 | ×2 | 加工·矿质补料调配：矿质补料×2（每批）｜农产加工台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 碎铁矿×2；草粉×2；谷粉×1 |

**直接用途（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 整体维护·矿鳞蜥 | ×2 | 整体维护·矿鳞蜥：矿质补料×2（每只·每轮）｜养鳞台｜矿鳞蜥｜1AP | 牧草×1；清水×1；复合陆养料×1；清水×1 |
| 整体维护·钢绵羊 | ×1 | 整体维护·钢绵羊：矿质补料×1（每只·每轮）｜圈舍｜钢绵羊｜1AP | 牧草×1；清水×1；谷粒×1；清水×1；复合陆养料×1；清水×1 |
| 市集出售·矿质补料 | ×按订单/库存 | 市集出售·矿质补料：矿质补料×按订单/库存（每份） | 元石×4 |

相关规则：[市集交易](#市集交易-rulemarket)

### 矿质鳞片 `resource:mineral_scale`

金行固体；可供货（供养值41）

| 字段 | 内容 |
|---|---|
| 分类 | 金行·固体·加工品；标签：food、animal_product |
| 市集采购 | 不可采购 |
| 市集出售 | 5元石/份（计入销售收入） |
| 五行供货 | 可供货（金行）；供养值41：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 收取·矿鳞蜥 | ×2 | 收取·矿鳞蜥：矿质鳞片×2（每只·每轮）｜养鳞台｜矿鳞蜥｜1AP | 蜕皮×1 |

**直接用途（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·鳞甲复合板 | ×2 | 加工·鳞甲复合板：矿质鳞片×2（每批）｜木工台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 蜕皮×1；砂砾×1；复合石板×3 |
| 市集出售·矿质鳞片 | ×按订单/库存 | 市集出售·矿质鳞片：矿质鳞片×按订单/库存（每份） | 元石×5 |
| 五行供货·矿质鳞片 | ×按订单/库存 | 五行供货·矿质鳞片：矿质鳞片×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 黏液 `resource:mucus`

水行固体；可供货（供养值11）

| 字段 | 内容 |
|---|---|
| 分类 | 水行·固体·加工品；标签：food、animal_product |
| 市集采购 | 不可采购 |
| 市集出售 | 2元石/份（计入销售收入） |
| 五行供货 | 可供货（水行）；供养值11：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |

**获取来源（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·岩壳成型 | ×1 | 加工·岩壳成型：黏液×1（每批）｜岩壳成型台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 石粉×3；清水×1；岩壳片×2 |
| 收取·露壳蜗牛 | ×1 | 收取·露壳蜗牛：黏液×1（每只·每轮）｜集露台｜露壳蜗牛｜1AP | 灵液×2 |
| 收取·砾甲蜗牛 | ×1 | 收取·砾甲蜗牛：黏液×1（每只·每轮）｜岩壳成型台｜砾甲蜗牛｜1AP | 岩壳片×2 |

**直接用途（4条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·黏液复合石板 | ×1 | 加工·黏液复合石板：黏液×1（每批）｜木工台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 砂砾×2；石粉×1；复合石板×2 |
| 加工·岩壳石板 | ×1 | 加工·岩壳石板：黏液×1（每批）｜木工台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 岩壳片×2；复合石板×3 |
| 市集出售·黏液 | ×按订单/库存 | 市集出售·黏液：黏液×按订单/库存（每份） | 元石×2 |
| 五行供货·黏液 | ×按订单/库存 | 五行供货·黏液：黏液×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 桑叶 `resource:mulberry_leaf`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：animal_feed、organic |
| 市集采购 | 2元石/份 |
| 市集出售 | 1元石/份（计入销售收入） |

**获取来源（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集采购·桑叶 | ×按订单/库存 | 市集采购·桑叶：桑叶×按订单/库存（每份） | 元石×2 |
| 收获·果桑树 | ×10 | 收获·果桑树：桑叶×10（每次收获）｜1AP | 原木×2；枝条×2 |
| 丰产奖励·果桑树·收取 | ×按订单/库存 | 丰产奖励·果桑树·收取：桑叶×按订单/库存（每轮额外份数） | — |

**直接用途（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 整体维护·叶丝蚕 | ×1 | 整体维护·叶丝蚕：桑叶×1（每群·每日）｜蚕架｜叶丝蚕｜1AP | 清水×1 |
| 整体维护·叶丝蚕 | ×2 | 整体维护·叶丝蚕：桑叶×2（每群·每轮）｜蚕架｜叶丝蚕｜1AP | 清水×1 |
| 市集出售·桑叶 | ×按订单/库存 | 市集出售·桑叶：桑叶×按订单/库存（每份） | 元石×1 |

相关规则：[市集交易](#市集交易-rulemarket)

### 果桑种苗 `resource:mulberry_seed`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：seed、cultivation |
| 市集采购 | 6元石/份 |
| 市集出售 | 不可出售 |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集采购·果桑种苗 | ×按订单/库存 | 市集采购·果桑种苗：果桑种苗×按订单/库存（每份） | 元石×6 |
| 育种奖励·果桑树 | ×1 | 育种奖励·果桑树：果桑种苗×1（每株首次成熟；成功时） | — |

**直接用途（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 播种·果桑树 | ×1 | 播种·果桑树：果桑种苗×1（每次播种）｜1AP | — |

相关规则：[市集交易](#市集交易-rulemarket)

### 木腐菇 `resource:mushroom`

木行固体；可供货（供养值5）

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：food |
| 市集采购 | 不可采购 |
| 市集出售 | 6元石/份（计入销售收入） |
| 五行供货 | 可供货（木行）；供养值5：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 收获·木腐菇 | ×3 | 收获·木腐菇：木腐菇×3（每次收获）｜1AP | 腐殖土×1 |
| 丰产奖励·木腐菇·收取 | ×按订单/库存 | 丰产奖励·木腐菇·收取：木腐菇×按订单/库存（每轮额外份数） | — |

**直接用途（7条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·菌鱼灵膳烹制 | ×1 | 加工·菌鱼灵膳烹制：木腐菇×1（每批）｜厨房｜需研究「灵食初制」｜1自然日｜启动1＋收取1 | 鱼肉×1；精炼油×1；木炭×1；菌鱼灵膳×2 |
| 加工·腐土菌丸炼制 | ×1 | 加工·腐土菌丸炼制：木腐菇×1（每批）｜厨房｜需研究「复合灵食」｜2自然日｜启动1＋收取1 | 腐殖土×2；草粉×1；木炭×1；腐土菌丸×2 |
| 整体维护·啮岩鼹 | ×1 | 整体维护·啮岩鼹：木腐菇×1（每只·每日）｜碎岩场｜啮岩鼹｜1AP | 清水×1；普通岩石×2；含铁矿石×2 |
| 启动研究·菌毯净化 | ×1 | 启动研究·菌毯净化：木腐菇×1（一次性）｜研究台 | 污水×2；元石×4 |
| 启动研究·岩料破碎 | ×1 | 启动研究·岩料破碎：木腐菇×1（一次性）｜研究台 | 普通岩石×3；元石×6 |
| 市集出售·木腐菇 | ×按订单/库存 | 市集出售·木腐菇：木腐菇×按订单/库存（每份） | 元石×6 |
| 五行供货·木腐菇 | ×按订单/库存 | 五行供货·木腐菇：木腐菇×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 贝壳 `resource:mussel_shell`

土行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 土行·固体·加工品；标签：animal_product |
| 市集采购 | 不可采购 |
| 市集出售 | 1元石/份（计入销售收入） |
| 下游用途 | 无下游配方：出售与供货是该物品的设计出口 |

**直接用途（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集出售·贝壳 | ×按订单/库存 | 市集出售·贝壳：贝壳×按订单/库存（每份） | 元石×1 |

相关规则：[市集交易](#市集交易-rulemarket)

### 花蜜 `resource:nectar`

水行液体；可供货（供养值8）

| 字段 | 内容 |
|---|---|
| 分类 | 水行·液体·初级；标签：food |
| 市集采购 | 不可采购 |
| 市集出售 | 2元石/份（计入销售收入） |
| 五行供货 | 可供货（水行）；供养值8：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |

**获取来源（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 收获·蜜铃灌木 | ×2 | 收获·蜜铃灌木：花蜜×2（每次收获）｜1AP | 花粉×1；枝条×1 |
| 手采花源 | ×2 | 手采花源：花蜜×2（每次（每株每日1份额））｜1AP | 花粉×1 |
| 丰产奖励·蜜铃灌木·收取 | ×按订单/库存 | 丰产奖励·蜜铃灌木·收取：花蜜×按订单/库存（每轮额外份数） | — |

**直接用途（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 启动研究·蜂群协作 | ×2 | 启动研究·蜂群协作：花蜜×2（一次性）｜研究台 | 花粉×1；元石×6 |
| 市集出售·花蜜 | ×按订单/库存 | 市集出售·花蜜：花蜜×按订单/库存（每份） | 元石×2 |
| 五行供货·花蜜 | ×按订单/库存 | 五行供货·花蜜：花蜜×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 营养液 `resource:nutrient_liquid`

水行液体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 水行·液体·加工品；标签：medium |
| 市集采购 | 不可采购 |
| 市集出售 | 2元石/份（计入销售收入） |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·营养液回收 | ×2 | 加工·营养液回收：营养液×2（每批）｜净水菌床｜需研究「水与藻料回流」｜2自然日｜启动1＋收取1 | 污水×4；炭砂滤料×1；清水×1；污泥×1 |
| 收取·净水菌毯 | ×2 | 收取·净水菌毯：营养液×2（每培养单位·每轮）｜净水菌床｜净水菌毯｜1AP | 清水×2；污泥×1；清水×1；污泥×1 |

**直接用途（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·高密度藻培养 | ×2 | 加工·高密度藻培养：营养液×2（每批）｜藻类培养槽｜需研究「水与藻料回流」｜2自然日｜启动1＋收取1 | 清水×1；秸秆×1；高密度藻料×3 |
| 市集出售·营养液 | ×按订单/库存 | 市集出售·营养液：营养液×按订单/库存（每份） | 元石×2 |

相关规则：[市集交易](#市集交易-rulemarket)

### 油饼 `resource:oil_cake`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·加工品；标签：animal_feed、organic |
| 市集采购 | 不可采购 |
| 市集出售 | 1元石/份（计入销售收入） |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·油籽榨油 | ×2 | 加工·油籽榨油：油饼×2（每批）｜农产加工台｜需研究「农产初加工」｜2自然日｜启动1＋收取1 | 油籽×4；粗油×2 |

**直接用途（6条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·陆养料调配 | ×1 | 加工·陆养料调配：油饼×1（每批）｜农产加工台｜需研究「饲料与蜡油精制」｜1自然日｜启动1＋收取1 | 谷粉×1；草粉×2；复合陆养料×3 |
| 加工·水养料调配 | ×1 | 加工·水养料调配：油饼×1（每批）｜农产加工台｜需研究「饲料与蜡油精制」｜1自然日｜启动1＋收取1 | 藻料×3；谷粉×1；复合水养料×4 |
| 加工·油饼堆肥 | ×2 | 加工·油饼堆肥：油饼×2（每批）｜堆肥箱｜需研究「农产初加工」｜2自然日｜启动1＋收取1 | 腐殖土×2 |
| 加工·残料翻肥 | ×1 | 加工·残料翻肥：油饼×1（每批）｜翻肥窝｜需研究「菌毯净化」｜1自然日｜启动1＋收取1 | 污泥×2；腐殖土×3 |
| 整体维护·堆肥鼠 | ×1 | 整体维护·堆肥鼠：油饼×1（每只·每轮）｜翻肥窝｜堆肥鼠｜1AP | 牧草×1；清水×1；秸秆×2；木屑×1；污泥×2 |
| 市集出售·油饼 | ×按订单/库存 | 市集出售·油饼：油饼×按订单/库存（每份） | 元石×1 |

相关规则：[市集交易](#市集交易-rulemarket)

### 油籽 `resource:oilseed`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：food |
| 市集采购 | 不可采购 |
| 市集出售 | 2元石/份（计入销售收入） |

**获取来源（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 收获·油籽花 | ×4 | 收获·油籽花：油籽×4（每次收获）｜1AP | 花瓣×1 |
| 收获·油籽花 | ×1 | 收获·油籽花：油籽×1（授粉加成）｜1AP | 花瓣×1 |
| 丰产奖励·油籽花·收取 | ×按订单/库存 | 丰产奖励·油籽花·收取：油籽×按订单/库存（每轮额外份数） | — |

**直接用途（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·油籽榨油 | ×4 | 加工·油籽榨油：油籽×4（每批）｜农产加工台｜需研究「农产初加工」｜2自然日｜启动1＋收取1 | 粗油×2；油饼×2 |
| 启动研究·农产初加工 | ×2 | 启动研究·农产初加工：油籽×2（一次性）｜研究台 | 秸秆×2；元石×6 |
| 市集出售·油籽 | ×按订单/库存 | 市集出售·油籽：油籽×按订单/库存（每份） | 元石×2 |

相关规则：[市集交易](#市集交易-rulemarket)

### 油籽花种子 `resource:oilseed_flower_seed`

木行固体；生产材料

> 解锁条件：需完成研究 [花源栽培](#花源栽培-researchflower_cultivation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：seed、cultivation |
| 市集采购 | 4元石/份 |
| 市集出售 | 不可出售 |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集采购·油籽花种子 | ×按订单/库存 | 市集采购·油籽花种子：油籽花种子×按订单/库存（每份）｜需研究「花源栽培」 | 元石×4 |
| 育种奖励·油籽花 | ×1 | 育种奖励·油籽花：油籽花种子×1（每株首次成熟；成功时） | — |

**直接用途（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 播种·油籽花 | ×1 | 播种·油籽花：油籽花种子×1（每次播种）｜需研究「花源栽培」｜1AP | — |

关联条目：解锁研究：[花源栽培](#花源栽培-researchflower_cultivation)

相关规则：[市集交易](#市集交易-rulemarket)

### 富集矿砂 `resource:ore_concentrate`

土行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 土行·固体·加工品；标签：processing |
| 市集采购 | 不可采购 |
| 市集出售 | 5元石/份（计入销售收入） |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·生物选矿 | ×2 | 加工·生物选矿：富集矿砂×2（每批）｜选矿场｜需研究「生物选矿」｜2自然日｜启动1＋收取1 | 碎铁矿×6；尾砂×1 |
| 收取·岩腹兽 | ×2 | 收取·岩腹兽：富集矿砂×2（每只·每轮）｜选矿场｜岩腹兽｜1AP | 尾砂×1 |

**直接用途（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·富集矿冶炼 | ×1 | 加工·富集矿冶炼：富集矿砂×1（每批）｜小型冶炼炉｜需研究「矿质材料工艺」｜2自然日｜启动1＋收取1 | 木炭×1；铁锭×1；炉渣×1 |
| 启动研究·矿质材料工艺 | ×1 | 启动研究·矿质材料工艺：富集矿砂×1（一次性）｜研究台 | 铁锭×1；石粉×1；元石×12 |
| 市集出售·富集矿砂 | ×按订单/库存 | 市集出售·富集矿砂：富集矿砂×按订单/库存（每份） | 元石×5 |

相关规则：[市集交易](#市集交易-rulemarket)

### 珍珠 `resource:pearl`

金行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 金行·固体·加工品；标签：animal_product |
| 市集采购 | 不可采购 |
| 市集出售 | 6元石/份（计入销售收入） |
| 下游用途 | 无下游配方：出售与供货是该物品的设计出口 |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 收取·珍珠蚌 | ×2 | 收取·珍珠蚌：珍珠×2（每只·每轮）｜采珠台｜珍珠蚌｜1AP | — |

**直接用途（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集出售·珍珠 | ×按订单/库存 | 市集出售·珍珠：珍珠×按订单/库存（每份） | 元石×6 |

相关规则：[市集交易](#市集交易-rulemarket)

### 花粉 `resource:pollen`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：food |
| 市集采购 | 不可采购 |
| 市集出售 | 1元石/份（计入销售收入） |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 收获·蜜铃灌木 | ×1 | 收获·蜜铃灌木：花粉×1（每次收获）｜1AP | 花蜜×2；枝条×1 |
| 手采花源 | ×1 | 手采花源：花粉×1（每次（每株每日1份额））｜1AP | 花蜜×2 |

**直接用途（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 启动研究·蜂群协作 | ×1 | 启动研究·蜂群协作：花粉×1（一次性）｜研究台 | 花蜜×2；元石×6 |
| 市集出售·花粉 | ×按订单/库存 | 市集出售·花粉：花粉×按订单/库存（每份） | 元石×1 |

相关规则：[市集交易](#市集交易-rulemarket)

### 净水菌毯培养单位 `resource:purifying_mat_culture`

木行固体；生产材料

> 解锁条件：需完成研究 [菌毯净化](#菌毯净化-researchbiofiltration)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：cultivation |
| 市集采购 | 6元石/份 |
| 市集出售 | 不可出售 |
| 购买方式 | 购买代理实体：市集不可直接购入，请在净水菌床面板购入培养单位（同价6元石/单位，扣款即占位、不入仓库）。 |
| 下游用途 | 无任何用途（见购买代理说明） |

关联条目：解锁研究：[菌毯净化](#菌毯净化-researchbiofiltration)

相关规则：[市集交易](#市集交易-rulemarket)

### 普通岩石 `resource:raw_stone`

土行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 土行·固体·初级；标签：building |
| 市集采购 | 3元石/份 |
| 市集出售 | 1元石/份（计入销售收入） |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集采购·普通岩石 | ×按订单/库存 | 市集采购·普通岩石：普通岩石×按订单/库存（每份） | 元石×3 |
| 采石点采集 | ×3 | 采石点采集：普通岩石×3（每次）｜1AP | — |

**直接用途（35条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·破碎石材 | ×2 | 加工·破碎石材：普通岩石×2（每批）｜碎岩场｜需研究「岩料破碎」｜1自然日｜启动1＋收取1 | 砂砾×2；石粉×1 |
| 建造·藻类培养槽 | ×1 | 建造·藻类培养槽：普通岩石×1（每次建造）｜藻类培养槽｜1AP | 原木×1；复合石板×1；再生填料×2；元石×6 |
| 建造·水生种植台 | ×2 | 建造·水生种植台：普通岩石×2（每次建造）｜水生种植台｜1AP | 木板×1；复合石板×2；再生填料×4；元石×8 |
| 建造·炭化巢 | ×4 | 建造·炭化巢：普通岩石×4（每次建造）｜炭化巢｜需研究「农产初加工」｜1AP | 木板×2；复合石板×4；再生填料×8；元石×18 |
| 建造·照料台 | ×2 | 建造·照料台：普通岩石×2（每次建造）｜照料台｜1AP | 木板×2；复合石板×2；再生填料×4；元石×24 |
| 建造·捕鲤台 | ×2 | 建造·捕鲤台：普通岩石×2（每次建造）｜捕鲤台｜1AP | 木板×2；复合石板×2；再生填料×4；元石×12 |
| 建造·炭化炉 | ×3 | 建造·炭化炉：普通岩石×3（每次建造）｜炭化炉｜1AP | 原木×2；复合石板×3；再生填料×6；元石×12 |
| 建造·堆肥箱 | ×1 | 建造·堆肥箱：普通岩石×1（每次建造）｜堆肥箱｜1AP | 原木×1；复合石板×1；再生填料×2；元石×6 |
| 建造·翻肥窝 | ×2 | 建造·翻肥窝：普通岩石×2（每次建造）｜翻肥窝｜1AP | 原木×2；复合石板×2；再生填料×4；元石×12 |
| 建造·采礁台 | ×4 | 建造·采礁台：普通岩石×4（每次建造）｜采礁台｜需研究「矿质材料工艺」｜1AP | 木板×2；复合石板×4；再生填料×8；元石×20 |
| 建造·调度站 | ×2 | 建造·调度站：普通岩石×2（每次建造）｜调度站｜1AP | 原木×2；复合石板×2；再生填料×4；元石×18 |
| 建造·农产加工台 | ×2 | 建造·农产加工台：普通岩石×2（每次建造）｜农产加工台｜需研究「农产初加工」｜1AP | 木板×2；复合石板×2；再生填料×4；元石×12 |
| 建造·水场 | ×4 | 建造·水场：普通岩石×4（每次建造）｜水场｜1AP | 原木×1；复合石板×4；再生填料×8；元石×12 |
| 建造·采胶台 | ×3 | 建造·采胶台：普通岩石×3（每次建造）｜采胶台｜需研究「水与藻料回流」｜1AP | 木板×2；复合石板×3；再生填料×6；元石×16 |
| 建造·厨房 | ×3 | 建造·厨房：普通岩石×3（每次建造）｜厨房｜需研究「灵食初制」｜1AP | 木板×2；复合石板×3；再生填料×6；元石×12 |
| 建造·取油台 | ×3 | 建造·取油台：普通岩石×3（每次建造）｜取油台｜需研究「农产初加工」｜1AP | 木板×2；复合石板×3；再生填料×6；元石×16 |
| 建造·选矿场 | ×3 | 建造·选矿场：普通岩石×3（每次建造）｜选矿场｜需研究「生物选矿」｜1AP | 原木×2；复合石板×3；再生填料×6；元石×12 |
| 建造·采珠台 | ×3 | 建造·采珠台：普通岩石×3（每次建造）｜采珠台｜需研究「水与藻料回流」｜1AP | 木板×2；复合石板×3；再生填料×6；元石×16 |
| 建造·圈舍 | ×3 | 建造·圈舍：普通岩石×3（每次建造）｜圈舍｜1AP | 原木×2；复合石板×3；再生填料×6；元石×16 |
| 建造·净水菌床 | ×2 | 建造·净水菌床：普通岩石×2（每次建造）｜净水菌床｜需研究「菌毯净化」｜1AP | 原木×2；复合石板×2；再生填料×4；元石×10 |
| 建造·研究台 | ×2 | 建造·研究台：普通岩石×2（每次建造）｜研究台｜1AP | 原木×2；复合石板×2；再生填料×4；元石×8 |
| 建造·碎岩场 | ×3 | 建造·碎岩场：普通岩石×3（每次建造）｜碎岩场｜需研究「岩料破碎」｜1AP | 原木×2；复合石板×3；再生填料×6；元石×12 |
| 建造·养鳞台 | ×4 | 建造·养鳞台：普通岩石×4（每次建造）｜养鳞台｜需研究「矿质材料工艺」｜1AP | 木板×2；复合石板×4；再生填料×8；元石×18 |
| 建造·岩壳成型台 | ×4 | 建造·岩壳成型台：普通岩石×4（每次建造）｜岩壳成型台｜需研究「矿质材料工艺」｜1AP | 木板×2；复合石板×4；再生填料×8；元石×18 |
| 建造·泥料处理台 | ×2 | 建造·泥料处理台：普通岩石×2（每次建造）｜泥料处理台｜需研究「菌毯净化」｜1AP | 木板×2；复合石板×2；再生填料×4；元石×14 |
| 建造·小型冶炼炉 | ×6 | 建造·小型冶炼炉：普通岩石×6（每次建造）｜小型冶炼炉｜1AP | 木板×2；复合石板×6；再生填料×12；元石×20 |
| 建造·安抚台 | ×2 | 建造·安抚台：普通岩石×2（每次建造）｜安抚台｜1AP | 木板×2；复合石板×2；再生填料×4；元石×18 |
| 建造·集露台 | ×3 | 建造·集露台：普通岩石×3（每次建造）｜集露台｜1AP | 木板×1；复合石板×3；再生填料×6；元石×12 |
| 建造·玩具站 | ×2 | 建造·玩具站：普通岩石×2（每次建造）｜玩具站｜1AP | 木板×2；复合石板×2；再生填料×4；元石×12 |
| 建造·换水站 | ×4 | 建造·换水站：普通岩石×4（每次建造）｜换水站｜1AP | 木板×2；复合石板×4；再生填料×8；元石×16 |
| 建造·木工台 | ×2 | 建造·木工台：普通岩石×2（每次建造）｜木工台｜1AP | 原木×2；复合石板×2；再生填料×4；元石×8 |
| 建造·采毛台 | ×2 | 建造·采毛台：普通岩石×2（每次建造）｜采毛台｜1AP | 木板×2；复合石板×2；再生填料×4；元石×12 |
| 整体维护·啮岩鼹 | ×2 | 整体维护·啮岩鼹：普通岩石×2（每只·每轮）｜碎岩场｜啮岩鼹｜1AP | 木腐菇×1；清水×1；含铁矿石×2 |
| 启动研究·岩料破碎 | ×3 | 启动研究·岩料破碎：普通岩石×3（一次性）｜研究台 | 木腐菇×1；元石×6 |
| 市集出售·普通岩石 | ×按订单/库存 | 市集出售·普通岩石：普通岩石×按订单/库存（每份） | 元石×1 |

相关规则：[市集交易](#市集交易-rulemarket)

### 原木 `resource:raw_wood`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：building、processing |
| 市集采购 | 6元石/份 |
| 市集出售 | 4元石/份（计入销售收入） |

**获取来源（7条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集采购·原木 | ×按订单/库存 | 市集采购·原木：原木×按订单/库存（每份） | 元石×6 |
| 收获·速生杉 | ×4 | 收获·速生杉：原木×4（每次收获）｜1AP | 枝条×4 |
| 收获·果桑树 | ×2 | 收获·果桑树：原木×2（每次砍伐）｜1AP | 桑叶×10；枝条×2 |
| 收获·松脂树 | ×4 | 收获·松脂树：原木×4（每次砍伐）｜1AP | 松脂×4；枝条×3 |
| 丰产奖励·速生杉·砍伐 | ×按订单/库存 | 丰产奖励·速生杉·砍伐：原木×按订单/库存（每轮额外份数） | — |
| 丰产奖励·果桑树·砍伐 | ×按订单/库存 | 丰产奖励·果桑树·砍伐：原木×按订单/库存（每轮额外份数） | — |
| 丰产奖励·松脂树·砍伐 | ×按订单/库存 | 丰产奖励·松脂树·砍伐：原木×按订单/库存（每轮额外份数） | — |

**直接用途（21条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·锯切木板 | ×2 | 加工·锯切木板：原木×2（每批）｜木工台｜1自然日｜启动1＋收取1 | 木板×2；木屑×1 |
| 加工·原木粉碎 | ×1 | 加工·原木粉碎：原木×1（每批）｜木工台｜1自然日｜启动1＋收取1 | 木屑×4 |
| 建造·藻类培养槽 | ×1 | 建造·藻类培养槽：原木×1（每次建造）｜藻类培养槽｜1AP | 普通岩石×1；复合石板×1；再生填料×2；元石×6 |
| 建造·蜂箱 | ×2 | 建造·蜂箱：原木×2（每次建造）｜蜂箱｜需研究「蜂群协作」｜1AP | 木板×2；元石×10 |
| 建造·炭化炉 | ×2 | 建造·炭化炉：原木×2（每次建造）｜炭化炉｜1AP | 普通岩石×3；复合石板×3；再生填料×6；元石×12 |
| 建造·堆肥箱 | ×1 | 建造·堆肥箱：原木×1（每次建造）｜堆肥箱｜1AP | 普通岩石×1；复合石板×1；再生填料×2；元石×6 |
| 建造·翻肥窝 | ×2 | 建造·翻肥窝：原木×2（每次建造）｜翻肥窝｜1AP | 普通岩石×2；复合石板×2；再生填料×4；元石×12 |
| 建造·调度站 | ×2 | 建造·调度站：原木×2（每次建造）｜调度站｜1AP | 普通岩石×2；复合石板×2；再生填料×4；元石×18 |
| 建造·供食槽 | ×2 | 建造·供食槽：原木×2（每次建造）｜供食槽｜1AP | 元石×6 |
| 建造·水场 | ×1 | 建造·水场：原木×1（每次建造）｜水场｜1AP | 普通岩石×4；复合石板×4；再生填料×8；元石×12 |
| 建造·大床 | ×4 | 建造·大床：原木×4（每次建造）｜大床｜1AP | 元石×14 |
| 建造·中床 | ×3 | 建造·中床：原木×3（每次建造）｜中床｜1AP | 元石×10 |
| 建造·选矿场 | ×2 | 建造·选矿场：原木×2（每次建造）｜选矿场｜需研究「生物选矿」｜1AP | 普通岩石×3；复合石板×3；再生填料×6；元石×12 |
| 建造·圈舍 | ×2 | 建造·圈舍：原木×2（每次建造）｜圈舍｜1AP | 普通岩石×3；复合石板×3；再生填料×6；元石×16 |
| 建造·净水菌床 | ×2 | 建造·净水菌床：原木×2（每次建造）｜净水菌床｜需研究「菌毯净化」｜1AP | 普通岩石×2；复合石板×2；再生填料×4；元石×10 |
| 建造·研究台 | ×2 | 建造·研究台：原木×2（每次建造）｜研究台｜1AP | 普通岩石×2；复合石板×2；再生填料×4；元石×8 |
| 建造·碎岩场 | ×2 | 建造·碎岩场：原木×2（每次建造）｜碎岩场｜需研究「岩料破碎」｜1AP | 普通岩石×3；复合石板×3；再生填料×6；元石×12 |
| 建造·小床 | ×2 | 建造·小床：原木×2（每次建造）｜小床｜1AP | 元石×6 |
| 建造·木工台 | ×2 | 建造·木工台：原木×2（每次建造）｜木工台｜1AP | 普通岩石×2；复合石板×2；再生填料×4；元石×8 |
| 铺设普通地板 | ×1 | 铺设普通地板：原木×1（每格）｜1AP | — |
| 市集出售·原木 | ×按订单/库存 | 市集出售·原木：原木×按订单/库存（每份） | 元石×4 |

相关规则：[市集交易](#市集交易-rulemarket)

### 再生填料 `resource:reclaimed_fill`

土行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 土行·固体·加工品；标签：building |
| 市集采购 | 不可采购 |
| 市集出售 | 1元石/份（计入销售收入） |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·再生填料回收 | ×2 | 加工·再生填料回收：再生填料×2（每批）｜木工台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 尾砂×1；炉渣×1；石粉×1 |

**直接用途（32条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 建造·藻类培养槽 | ×2 | 建造·藻类培养槽：再生填料×2（每次建造（可选2:1替石））｜藻类培养槽｜1AP | 原木×1；普通岩石×1；复合石板×1；元石×6 |
| 建造·水生种植台 | ×4 | 建造·水生种植台：再生填料×4（每次建造（可选2:1替石））｜水生种植台｜1AP | 木板×1；普通岩石×2；复合石板×2；元石×8 |
| 建造·炭化巢 | ×8 | 建造·炭化巢：再生填料×8（每次建造（可选2:1替石））｜炭化巢｜需研究「农产初加工」｜1AP | 木板×2；普通岩石×4；复合石板×4；元石×18 |
| 建造·照料台 | ×4 | 建造·照料台：再生填料×4（每次建造（可选2:1替石））｜照料台｜1AP | 木板×2；普通岩石×2；复合石板×2；元石×24 |
| 建造·捕鲤台 | ×4 | 建造·捕鲤台：再生填料×4（每次建造（可选2:1替石））｜捕鲤台｜1AP | 木板×2；普通岩石×2；复合石板×2；元石×12 |
| 建造·炭化炉 | ×6 | 建造·炭化炉：再生填料×6（每次建造（可选2:1替石））｜炭化炉｜1AP | 原木×2；普通岩石×3；复合石板×3；元石×12 |
| 建造·堆肥箱 | ×2 | 建造·堆肥箱：再生填料×2（每次建造（可选2:1替石））｜堆肥箱｜1AP | 原木×1；普通岩石×1；复合石板×1；元石×6 |
| 建造·翻肥窝 | ×4 | 建造·翻肥窝：再生填料×4（每次建造（可选2:1替石））｜翻肥窝｜1AP | 原木×2；普通岩石×2；复合石板×2；元石×12 |
| 建造·采礁台 | ×8 | 建造·采礁台：再生填料×8（每次建造（可选2:1替石））｜采礁台｜需研究「矿质材料工艺」｜1AP | 木板×2；普通岩石×4；复合石板×4；元石×20 |
| 建造·调度站 | ×4 | 建造·调度站：再生填料×4（每次建造（可选2:1替石））｜调度站｜1AP | 原木×2；普通岩石×2；复合石板×2；元石×18 |
| 建造·农产加工台 | ×4 | 建造·农产加工台：再生填料×4（每次建造（可选2:1替石））｜农产加工台｜需研究「农产初加工」｜1AP | 木板×2；普通岩石×2；复合石板×2；元石×12 |
| 建造·水场 | ×8 | 建造·水场：再生填料×8（每次建造（可选2:1替石））｜水场｜1AP | 普通岩石×4；原木×1；复合石板×4；元石×12 |
| 建造·采胶台 | ×6 | 建造·采胶台：再生填料×6（每次建造（可选2:1替石））｜采胶台｜需研究「水与藻料回流」｜1AP | 木板×2；普通岩石×3；复合石板×3；元石×16 |
| 建造·厨房 | ×6 | 建造·厨房：再生填料×6（每次建造（可选2:1替石））｜厨房｜需研究「灵食初制」｜1AP | 木板×2；普通岩石×3；复合石板×3；元石×12 |
| 建造·取油台 | ×6 | 建造·取油台：再生填料×6（每次建造（可选2:1替石））｜取油台｜需研究「农产初加工」｜1AP | 木板×2；普通岩石×3；复合石板×3；元石×16 |
| 建造·选矿场 | ×6 | 建造·选矿场：再生填料×6（每次建造（可选2:1替石））｜选矿场｜需研究「生物选矿」｜1AP | 原木×2；普通岩石×3；复合石板×3；元石×12 |
| 建造·采珠台 | ×6 | 建造·采珠台：再生填料×6（每次建造（可选2:1替石））｜采珠台｜需研究「水与藻料回流」｜1AP | 木板×2；普通岩石×3；复合石板×3；元石×16 |
| 建造·圈舍 | ×6 | 建造·圈舍：再生填料×6（每次建造（可选2:1替石））｜圈舍｜1AP | 原木×2；普通岩石×3；复合石板×3；元石×16 |
| 建造·净水菌床 | ×4 | 建造·净水菌床：再生填料×4（每次建造（可选2:1替石））｜净水菌床｜需研究「菌毯净化」｜1AP | 原木×2；普通岩石×2；复合石板×2；元石×10 |
| 建造·研究台 | ×4 | 建造·研究台：再生填料×4（每次建造（可选2:1替石））｜研究台｜1AP | 原木×2；普通岩石×2；复合石板×2；元石×8 |
| 建造·碎岩场 | ×6 | 建造·碎岩场：再生填料×6（每次建造（可选2:1替石））｜碎岩场｜需研究「岩料破碎」｜1AP | 原木×2；普通岩石×3；复合石板×3；元石×12 |
| 建造·养鳞台 | ×8 | 建造·养鳞台：再生填料×8（每次建造（可选2:1替石））｜养鳞台｜需研究「矿质材料工艺」｜1AP | 木板×2；普通岩石×4；复合石板×4；元石×18 |
| 建造·岩壳成型台 | ×8 | 建造·岩壳成型台：再生填料×8（每次建造（可选2:1替石））｜岩壳成型台｜需研究「矿质材料工艺」｜1AP | 木板×2；普通岩石×4；复合石板×4；元石×18 |
| 建造·泥料处理台 | ×4 | 建造·泥料处理台：再生填料×4（每次建造（可选2:1替石））｜泥料处理台｜需研究「菌毯净化」｜1AP | 木板×2；普通岩石×2；复合石板×2；元石×14 |
| 建造·小型冶炼炉 | ×12 | 建造·小型冶炼炉：再生填料×12（每次建造（可选2:1替石））｜小型冶炼炉｜1AP | 木板×2；普通岩石×6；复合石板×6；元石×20 |
| 建造·安抚台 | ×4 | 建造·安抚台：再生填料×4（每次建造（可选2:1替石））｜安抚台｜1AP | 木板×2；普通岩石×2；复合石板×2；元石×18 |
| 建造·集露台 | ×6 | 建造·集露台：再生填料×6（每次建造（可选2:1替石））｜集露台｜1AP | 木板×1；普通岩石×3；复合石板×3；元石×12 |
| 建造·玩具站 | ×4 | 建造·玩具站：再生填料×4（每次建造（可选2:1替石））｜玩具站｜1AP | 木板×2；普通岩石×2；复合石板×2；元石×12 |
| 建造·换水站 | ×8 | 建造·换水站：再生填料×8（每次建造（可选2:1替石））｜换水站｜1AP | 木板×2；普通岩石×4；复合石板×4；元石×16 |
| 建造·木工台 | ×4 | 建造·木工台：再生填料×4（每次建造（可选2:1替石））｜木工台｜1AP | 原木×2；普通岩石×2；复合石板×2；元石×8 |
| 建造·采毛台 | ×4 | 建造·采毛台：再生填料×4（每次建造（可选2:1替石））｜采毛台｜1AP | 木板×2；普通岩石×2；复合石板×2；元石×12 |
| 市集出售·再生填料 | ×按订单/库存 | 市集出售·再生填料：再生填料×按订单/库存（每份） | 元石×1 |

相关规则：[市集交易](#市集交易-rulemarket)

### 精炼油 `resource:refined_oil`

火行液体；可供货（供养值8）

| 字段 | 内容 |
|---|---|
| 分类 | 火行·液体·加工品；标签：food、fuel |
| 市集采购 | 不可采购 |
| 市集出售 | 7元石/份（计入销售收入） |
| 五行供货 | 可供货（火行）；供养值8：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·油脂精炼 | ×2 | 加工·油脂精炼：精炼油×2（每批）｜农产加工台｜需研究「饲料与蜡油精制」｜1自然日｜启动1＋收取1 | 粗油×2；木炭×1；废滤炭×1 |

**直接用途（6条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·菌鱼灵膳烹制 | ×1 | 加工·菌鱼灵膳烹制：精炼油×1（每批）｜厨房｜需研究「灵食初制」｜1自然日｜启动1＋收取1 | 木腐菇×1；鱼肉×1；木炭×1；菌鱼灵膳×2 |
| 加工·蜜油火膏熬制 | ×1 | 加工·蜜油火膏熬制：精炼油×1（每批）｜厨房｜需研究「复合灵食」｜2自然日｜启动1＋收取1 | 蜂蜜×1；精炼蜡×1；木炭×1；蜜油火膏×2 |
| 补光灯开日耗油 | ×1 | 补光灯开日耗油：精炼油×1（每灯·每个开日）｜补光灯 | — |
| 启动研究·复合灵食 | ×1 | 启动研究·复合灵食：精炼油×1（一次性）｜研究台 | 高密度藻料×1；铁锭×1；元石×12 |
| 市集出售·精炼油 | ×按订单/库存 | 市集出售·精炼油：精炼油×按订单/库存（每份） | 元石×7 |
| 五行供货·精炼油 | ×按订单/库存 | 五行供货·精炼油：精炼油×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 精炼蜡 `resource:refined_wax`

火行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 火行·固体·加工品；标签：processing |
| 市集采购 | 不可采购 |
| 市集出售 | 6元石/份（计入销售收入） |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·蜂蜡精炼 | ×1 | 加工·蜂蜡精炼：精炼蜡×1（每批）｜农产加工台｜需研究「饲料与蜡油精制」｜1自然日｜启动1＋收取1 | 蜂蜡×2 |

**直接用途（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·蜜油火膏熬制 | ×1 | 加工·蜜油火膏熬制：精炼蜡×1（每批）｜厨房｜需研究「复合灵食」｜2自然日｜启动1＋收取1 | 精炼油×1；蜂蜜×1；木炭×1；蜜油火膏×2 |
| 市集出售·精炼蜡 | ×按订单/库存 | 市集出售·精炼蜡：精炼蜡×按订单/库存（每份） | 元石×6 |

相关规则：[市集交易](#市集交易-rulemarket)

### 松脂 `resource:resin`

火行固体；可供货（供养值8）

| 字段 | 内容 |
|---|---|
| 分类 | 火行·固体·初级；标签：food、fuel |
| 市集采购 | 不可采购 |
| 市集出售 | 6元石/份（计入销售收入） |
| 五行供货 | 可供货（火行）；供养值8：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 收获·松脂树 | ×4 | 收获·松脂树：松脂×4（每次收获）｜1AP | 原木×4；枝条×3 |
| 丰产奖励·松脂树·收取 | ×按订单/库存 | 丰产奖励·松脂树·收取：松脂×按订单/库存（每轮额外份数） | — |

**直接用途（4条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·复合石板组装 | ×1 | 加工·复合石板组装：松脂×1（每批）｜木工台｜需研究「矿质材料工艺」｜2自然日｜启动1＋收取1 | 砂砾×2；石粉×1；复合石板×2 |
| 加工·松脂冶炼 | ×1 | 加工·松脂冶炼：松脂×1（每批）｜小型冶炼炉｜2自然日｜启动1＋收取1 | 含铁矿石×3；铁锭×1 |
| 市集出售·松脂 | ×按订单/库存 | 市集出售·松脂：松脂×按订单/库存（每份） | 元石×6 |
| 五行供货·松脂 | ×按订单/库存 | 五行供货·松脂：松脂×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 松脂树苗 `resource:resin_tree_seed`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：seed、cultivation |
| 市集采购 | 10元石/份 |
| 市集出售 | 不可出售 |

**获取来源（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集采购·松脂树苗 | ×按订单/库存 | 市集采购·松脂树苗：松脂树苗×按订单/库存（每份） | 元石×10 |
| 新档初始物资 | ×1 | 新档初始物资：松脂树苗×1（每新档一次性） | 金穗麦种子×8；速生杉苗×2；木腐菇菌种×4 |
| 育种奖励·松脂树 | ×1 | 育种奖励·松脂树：松脂树苗×1（每株首次成熟；成功时） | — |

**直接用途（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 播种·松脂树 | ×1 | 播种·松脂树：松脂树苗×1（每次播种）｜1AP | — |

相关规则：[市集交易](#市集交易-rulemarket)

### 稻米 `resource:rice`

木行固体；可供货（供养值3）

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：food、grain |
| 市集采购 | 不可采购 |
| 市集出售 | 3元石/份（计入销售收入） |
| 五行供货 | 可供货（木行）；供养值3：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 饭袋草蛊·生产收取 | ×4 | 饭袋草蛊·生产收取：稻米×4（每批）｜饭袋草蛊｜3有效生产日（可受催生加速）｜1AP | — |
| 丰产奖励·饭袋草蛊·收取 | ×按订单/库存 | 丰产奖励·饭袋草蛊·收取：稻米×按订单/库存（每轮额外份数）｜饭袋草蛊 | — |

**直接用途（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·稻米磨粉 | ×3 | 加工·稻米磨粉：稻米×3（每批）｜农产加工台｜需研究「农产初加工」｜1自然日｜启动1＋收取1 | 谷粉×2 |
| 市集出售·稻米 | ×按订单/库存 | 市集出售·稻米：稻米×按订单/库存（每份） | 元石×3 |
| 五行供货·稻米 | ×按订单/库存 | 五行供货·稻米：稻米×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 岩壳片 `resource:rock_shell`

土行固体；可供货（供养值8）

| 字段 | 内容 |
|---|---|
| 分类 | 土行·固体·加工品；标签：food、animal_product |
| 市集采购 | 不可采购 |
| 市集出售 | 3元石/份（计入销售收入） |
| 五行供货 | 可供货（土行）；供养值8：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·岩壳成型 | ×2 | 加工·岩壳成型：岩壳片×2（每批）｜岩壳成型台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 石粉×3；清水×1；黏液×1 |
| 收取·砾甲蜗牛 | ×2 | 收取·砾甲蜗牛：岩壳片×2（每只·每轮）｜岩壳成型台｜砾甲蜗牛｜1AP | 黏液×1 |

**直接用途（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·岩壳石板 | ×2 | 加工·岩壳石板：岩壳片×2（每批）｜木工台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 黏液×1；复合石板×3 |
| 市集出售·岩壳片 | ×按订单/库存 | 市集出售·岩壳片：岩壳片×按订单/库存（每份） | 元石×3 |
| 五行供货·岩壳片 | ×按订单/库存 | 五行供货·岩壳片：岩壳片×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 蜕皮 `resource:shed_skin`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·加工品；标签：food、animal_product |
| 市集采购 | 不可采购 |
| 市集出售 | 1元石/份（计入销售收入） |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 收取·矿鳞蜥 | ×1 | 收取·矿鳞蜥：蜕皮×1（每只·每轮）｜养鳞台｜矿鳞蜥｜1AP | 矿质鳞片×2 |

**直接用途（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·鳞甲复合板 | ×1 | 加工·鳞甲复合板：蜕皮×1（每批）｜木工台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 矿质鳞片×2；砂砾×1；复合石板×3 |
| 市集出售·蜕皮 | ×按订单/库存 | 市集出售·蜕皮：蜕皮×按订单/库存（每份） | 元石×1 |

相关规则：[市集交易](#市集交易-rulemarket)

### 羊粪肥 `resource:sheep_manure`

土行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 土行·固体·初级；标签：organic、processing |
| 市集采购 | 不可采购 |
| 市集出售 | 1元石/份（计入销售收入） |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 收取·钢绵羊 | ×1 | 收取·钢绵羊：羊粪肥×1（每只·每轮）｜圈舍｜钢绵羊｜1AP | 钢绒×1 |

**直接用途（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·羊粪堆肥 | ×2 | 加工·羊粪堆肥：羊粪肥×2（每批）｜堆肥箱｜2自然日｜启动1＋收取1 | 腐殖土×2 |
| 市集出售·羊粪肥 | ×按订单/库存 | 市集出售·羊粪肥：羊粪肥×按订单/库存（每份） | 元石×1 |

相关规则：[市集交易](#市集交易-rulemarket)

### 蚕丝 `resource:silk`

木行固体；可供货（供养值9）

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·加工品；标签：food、animal_product |
| 市集采购 | 不可采购 |
| 市集出售 | 4元石/份（计入销售收入） |
| 五行供货 | 可供货（木行）；供养值9：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 收取·叶丝蚕 | ×4 | 收取·叶丝蚕：蚕丝×4（每群·每轮）｜蚕架｜叶丝蚕｜1AP | — |

**直接用途（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·丝质滤材 | ×1 | 加工·丝质滤材：蚕丝×1（每批）｜木工台｜需研究「水与藻料回流」｜1自然日｜启动1＋收取1 | 木屑×1；木炭×1；炭砂滤料×3 |
| 市集出售·蚕丝 | ×按订单/库存 | 市集出售·蚕丝：蚕丝×按订单/库存（每份） | 元石×4 |
| 五行供货·蚕丝 | ×按订单/库存 | 五行供货·蚕丝：蚕丝×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 炉渣 `resource:slag`

土行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 土行·固体·加工品；标签：waste、building |
| 市集采购 | 不可采购 |
| 市集出售 | 不可出售 |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·富集矿冶炼 | ×1 | 加工·富集矿冶炼：炉渣×1（每批）｜小型冶炼炉｜需研究「矿质材料工艺」｜2自然日｜启动1＋收取1 | 富集矿砂×1；木炭×1；铁锭×1 |

**直接用途（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·再生填料回收 | ×1 | 加工·再生填料回收：炉渣×1（每批）｜木工台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 尾砂×1；石粉×1；再生填料×2 |

相关规则：[市集交易](#市集交易-rulemarket)

### 污泥 `resource:sludge`

土行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 土行·固体·初级；标签：organic、waste |
| 市集采购 | 不可采购 |
| 市集出售 | 不可出售 |

**获取来源（4条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·菌毯净水 | ×1 | 加工·菌毯净水：污泥×1（每批）｜净水菌床｜需研究「菌毯净化」｜2自然日｜启动1＋收取1 | 污水×4；木屑×1；清水×2 |
| 加工·营养液回收 | ×1 | 加工·营养液回收：污泥×1（每批）｜净水菌床｜需研究「水与藻料回流」｜2自然日｜启动1＋收取1 | 污水×4；炭砂滤料×1；营养液×2；清水×1 |
| 收取·净水菌毯 | ×1 | 收取·净水菌毯：污泥×1（每培养单位·每轮）｜净水菌床｜净水菌毯｜1AP | 清水×2；营养液×2；清水×1 |
| 收取·净水菌毯 | ×1 | 收取·净水菌毯：污泥×1（每培养单位·每轮）｜净水菌床｜净水菌毯｜1AP | 清水×2；营养液×2；清水×1 |

**直接用途（4条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·污泥堆肥 | ×2 | 加工·污泥堆肥：污泥×2（每批）｜堆肥箱｜需研究「菌毯净化」｜2自然日｜启动1＋收取1 | 腐殖土×2 |
| 加工·残料翻肥 | ×2 | 加工·残料翻肥：污泥×2（每批）｜翻肥窝｜需研究「菌毯净化」｜1自然日｜启动1＋收取1 | 油饼×1；腐殖土×3 |
| 整体维护·堆肥鼠 | ×2 | 整体维护·堆肥鼠：污泥×2（每只·每轮）｜翻肥窝｜堆肥鼠｜1AP | 牧草×1；清水×1；秸秆×2；木屑×1；油饼×1 |
| 启动研究·水与藻料回流 | ×1 | 启动研究·水与藻料回流：污泥×1（一次性）｜研究台 | 砂砾×1；木炭×1；元石×8 |

相关规则：[市集交易](#市集交易-rulemarket)

### 废滤炭 `resource:spent_filter`

土行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 土行·固体·加工品；标签：organic |
| 市集采购 | 不可采购 |
| 市集出售 | 不可出售 |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·油脂精炼 | ×1 | 加工·油脂精炼：废滤炭×1（每批）｜农产加工台｜需研究「饲料与蜡油精制」｜1自然日｜启动1＋收取1 | 粗油×2；木炭×1；精炼油×2 |

**直接用途（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·废滤炭堆肥 | ×2 | 加工·废滤炭堆肥：废滤炭×2（每批）｜堆肥箱｜需研究「饲料与蜡油精制」｜2自然日｜启动1＋收取1 | 腐殖土×1 |

相关规则：[市集交易](#市集交易-rulemarket)

### 灵液 `resource:spirit_liquid`

水行液体；可供货（供养值16）

| 字段 | 内容 |
|---|---|
| 分类 | 水行·液体·加工品；标签：food、animal_product |
| 市集采购 | 不可采购 |
| 市集出售 | 6元石/份（计入销售收入） |
| 五行供货 | 可供货（水行）；供养值16：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |
| 下游用途 | 交易出口＋水产用途预留：本期仅可出售或水行供货，水产加工配方尚未实装，百科不显示任何可用配方入口。 |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 收取·露壳蜗牛 | ×2 | 收取·露壳蜗牛：灵液×2（每只·每轮）｜集露台｜露壳蜗牛｜1AP | 黏液×1 |

**直接用途（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集出售·灵液 | ×按订单/库存 | 市集出售·灵液：灵液×按订单/库存（每份） | 元石×6 |
| 五行供货·灵液 | ×按订单/库存 | 五行供货·灵液：灵液×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 钢绒 `resource:steel_wool`

金行固体；可供货（供养值11）

| 字段 | 内容 |
|---|---|
| 分类 | 金行·固体·加工品；标签：food、animal_product |
| 市集采购 | 不可采购 |
| 市集出售 | 12元石/份（计入销售收入） |
| 五行供货 | 可供货（金行）；供养值11：订单数量=ceil(需求/供养值)，回款=数量×卖价＋10%溢价 |
| 下游用途 | 无下游配方：出售与供货是该物品的设计出口 |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 收取·钢绵羊 | ×1 | 收取·钢绵羊：钢绒×1（每只·每轮）｜圈舍｜钢绵羊｜1AP | 羊粪肥×1 |

**直接用途（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集出售·钢绒 | ×按订单/库存 | 市集出售·钢绒：钢绒×按订单/库存（每份） | 元石×12 |
| 五行供货·钢绒 | ×按订单/库存 | 五行供货·钢绒：钢绒×按订单/库存（数量=ceil(订单需求/供养值)） | 元石×按公式 |

相关规则：[市集交易](#市集交易-rulemarket)、[五行供货与转数](#五行供货与转数-ruleorders)

### 石粉 `resource:stone_powder`

土行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 土行·固体·初级；标签：building |
| 市集采购 | 不可采购 |
| 市集出售 | 1元石/份（计入销售收入） |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·破碎石材 | ×1 | 加工·破碎石材：石粉×1（每批）｜碎岩场｜需研究「岩料破碎」｜1自然日｜启动1＋收取1 | 普通岩石×2；砂砾×2 |
| 收取·啮岩鼹 | ×1 | 收取·啮岩鼹：石粉×1（每只·每轮）｜碎岩场｜啮岩鼹｜1AP | 砂砾×2；碎铁矿×3 |

**直接用途（9条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·黏液复合石板 | ×1 | 加工·黏液复合石板：石粉×1（每批）｜木工台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 砂砾×2；黏液×1；复合石板×2 |
| 加工·复合石板组装 | ×1 | 加工·复合石板组装：石粉×1（每批）｜木工台｜需研究「矿质材料工艺」｜2自然日｜启动1＋收取1 | 砂砾×2；松脂×1；复合石板×2 |
| 加工·岩壳成型 | ×3 | 加工·岩壳成型：石粉×3（每批）｜岩壳成型台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 清水×1；岩壳片×2；黏液×1 |
| 加工·再生填料回收 | ×1 | 加工·再生填料回收：石粉×1（每批）｜木工台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 尾砂×1；炉渣×1；再生填料×2 |
| 整体维护·砾甲蜗牛 | ×3 | 整体维护·砾甲蜗牛：石粉×3（每只·每轮）｜岩壳成型台｜砾甲蜗牛｜1AP | 藻料×1；清水×1；清水×1 |
| 整体维护·珍珠蚌 | ×1 | 整体维护·珍珠蚌：石粉×1（每只·每轮）｜采珠台｜珍珠蚌｜1AP | 藻料×1 |
| 整体维护·礁骨珊瑚 | ×3 | 整体维护·礁骨珊瑚：石粉×3（每群·每轮）｜采礁台｜礁骨珊瑚｜1AP | 藻料×1；清水×1 |
| 启动研究·矿质材料工艺 | ×1 | 启动研究·矿质材料工艺：石粉×1（一次性）｜研究台 | 富集矿砂×1；铁锭×1；元石×12 |
| 市集出售·石粉 | ×按订单/库存 | 市集出售·石粉：石粉×按订单/库存（每份） | 元石×1 |

相关规则：[市集交易](#市集交易-rulemarket)

### 秸秆 `resource:straw`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：organic、processing |
| 市集采购 | 3元石/份 |
| 市集出售 | 1元石/份（计入销售收入） |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集采购·秸秆 | ×按订单/库存 | 市集采购·秸秆：秸秆×按订单/库存（每份） | 元石×3 |
| 收获·金穗麦 | ×2 | 收获·金穗麦：秸秆×2（每次收获）｜1AP | 谷粒×3 |

**直接用途（8条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·秸秆堆肥 | ×2 | 加工·秸秆堆肥：秸秆×2（每批）｜堆肥箱｜2自然日｜启动1＋收取1 | 腐殖土×2 |
| 加工·藻料培养 | ×2 | 加工·藻料培养：秸秆×2（每批）｜藻类培养槽｜2自然日｜启动1＋收取1 | 清水×3；藻料×6 |
| 加工·高密度藻培养 | ×1 | 加工·高密度藻培养：秸秆×1（每批）｜藻类培养槽｜需研究「水与藻料回流」｜2自然日｜启动1＋收取1 | 营养液×2；清水×1；高密度藻料×3 |
| 加工·make_vine_ball | ×2 | 加工·make_vine_ball：秸秆×2（每批）｜木工台｜1自然日｜启动1＋收取1 | 枝条×2；藤球×1 |
| 加工·秸秆翻肥 | ×2 | 加工·秸秆翻肥：秸秆×2（每批）｜翻肥窝｜1自然日｜启动1＋收取1 | 木屑×1；腐殖土×4 |
| 整体维护·堆肥鼠 | ×2 | 整体维护·堆肥鼠：秸秆×2（每只·每轮）｜翻肥窝｜堆肥鼠｜1AP | 牧草×1；清水×1；木屑×1；污泥×2；油饼×1 |
| 启动研究·农产初加工 | ×2 | 启动研究·农产初加工：秸秆×2（一次性）｜研究台 | 油籽×2；元石×6 |
| 市集出售·秸秆 | ×按订单/库存 | 市集出售·秸秆：秸秆×按订单/库存（每份） | 元石×1 |

相关规则：[市集交易](#市集交易-rulemarket)

### 尾砂 `resource:tailings`

土行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 土行·固体·加工品；标签：waste、building |
| 市集采购 | 不可采购 |
| 市集出售 | 不可出售 |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·生物选矿 | ×1 | 加工·生物选矿：尾砂×1（每批）｜选矿场｜需研究「生物选矿」｜2自然日｜启动1＋收取1 | 碎铁矿×6；富集矿砂×2 |
| 收取·岩腹兽 | ×1 | 收取·岩腹兽：尾砂×1（每只·每轮）｜选矿场｜岩腹兽｜1AP | 富集矿砂×2 |

**直接用途（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·再生填料回收 | ×1 | 加工·再生填料回收：尾砂×1（每批）｜木工台｜需研究「矿质材料工艺」｜1自然日｜启动1＋收取1 | 炉渣×1；石粉×1；再生填料×2 |

相关规则：[市集交易](#市集交易-rulemarket)

### 宙道食料 `resource:time_feed`

水行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 水行·固体·加工品；标签：special_feed |
| 市集采购 | 2元石/份 |
| 市集出售 | 不可出售 |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集采购·宙道食料 | ×按订单/库存 | 市集采购·宙道食料：宙道食料×按订单/库存（每份） | 元石×2 |

**直接用途（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 宙道研究蛊·每日维护 | ×1 | 宙道研究蛊·每日维护：宙道食料×1（每只·每日）｜宙道研究蛊 | 元石×2 |

相关规则：[市集交易](#市集交易-rulemarket)

### 枝条 `resource:twig`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：organic、processing |
| 市集采购 | 3元石/份 |
| 市集出售 | 2元石/份（计入销售收入） |

**获取来源（6条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集采购·枝条 | ×按订单/库存 | 市集采购·枝条：枝条×按订单/库存（每份） | 元石×3 |
| 收获·速生杉 | ×4 | 收获·速生杉：枝条×4（每次收获）｜1AP | 原木×4 |
| 收获·蜜铃灌木 | ×1 | 收获·蜜铃灌木：枝条×1（每次砍伐）｜1AP | 花蜜×2；花粉×1 |
| 收获·果桑树 | ×2 | 收获·果桑树：枝条×2（每次砍伐）｜1AP | 桑叶×10；原木×2 |
| 收获·松脂树 | ×3 | 收获·松脂树：枝条×3（每次砍伐）｜1AP | 松脂×4；原木×4 |
| 丰产奖励·蜜铃灌木·砍伐 | ×按订单/库存 | 丰产奖励·蜜铃灌木·砍伐：枝条×按订单/库存（每轮额外份数） | — |

**直接用途（8条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·树枝生物炭化 | ×4 | 加工·树枝生物炭化：枝条×4（每批）｜炭化巢｜需研究「农产初加工」｜1自然日｜启动1＋收取1 | 木炭×4；腐殖土×1 |
| 加工·枝条炭化 | ×4 | 加工·枝条炭化：枝条×4（每批）｜炭化炉｜2自然日｜启动1＋收取1 | 木炭×3 |
| 加工·枝条堆肥 | ×3 | 加工·枝条堆肥：枝条×3（每批）｜堆肥箱｜2自然日｜启动1＋收取1 | 腐殖土×2 |
| 加工·make_vine_ball | ×2 | 加工·make_vine_ball：枝条×2（每批）｜木工台｜1自然日｜启动1＋收取1 | 秸秆×2；藤球×1 |
| 加工·枝条粉碎 | ×2 | 加工·枝条粉碎：枝条×2（每批）｜木工台｜1自然日｜启动1＋收取1 | 木屑×3 |
| 建造·蚕架 | ×2 | 建造·蚕架：枝条×2（每次建造）｜蚕架｜1AP | 木板×2；元石×10 |
| 整体维护·炭腹虫 | ×4 | 整体维护·炭腹虫：枝条×4（每群·每轮）｜炭化巢｜炭腹虫｜1AP | 牧草×1；清水×1；木屑×4 |
| 市集出售·枝条 | ×按订单/库存 | 市集出售·枝条：枝条×按订单/库存（每份） | 元石×2 |

相关规则：[市集交易](#市集交易-rulemarket)

### 藤球 `resource:vine_ball`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·加工品；标签：animal_toy |
| 市集采购 | 不可采购 |
| 市集出售 | 不可出售 |

**获取来源（2条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·make_vine_ball | ×1 | 加工·make_vine_ball：藤球×1（每批）｜木工台｜1自然日｜启动1＋收取1 | 枝条×2；秸秆×2 |
| 卸下耐用藤球 | ×1 | 卸下耐用藤球：藤球×1（每个玩具站）｜玩具站｜1AP | — |

**直接用途（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 装入耐用藤球 | ×1 | 装入耐用藤球：藤球×1（每个玩具站）｜玩具站｜1AP | — |

相关规则：[市集交易](#市集交易-rulemarket)

### 污水 `resource:wastewater`

水行液体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 水行·液体·初级；标签：waste |
| 市集采购 | 不可采购 |
| 市集出售 | 不可出售 |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 水场换水（真实） | ×2 | 水场换水（真实）：污水×2（每次）｜1AP | 清水×2 |

**直接用途（5条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·菌毯净水 | ×4 | 加工·菌毯净水：污水×4（每批）｜净水菌床｜需研究「菌毯净化」｜2自然日｜启动1＋收取1 | 木屑×1；清水×2；污泥×1 |
| 加工·营养液回收 | ×4 | 加工·营养液回收：污水×4（每批）｜净水菌床｜需研究「水与藻料回流」｜2自然日｜启动1＋收取1 | 炭砂滤料×1；营养液×2；清水×1；污泥×1 |
| 整体维护·净水菌毯 | ×4 | 整体维护·净水菌毯：污水×4（每培养单位·每轮）｜净水菌床｜净水菌毯｜1AP | 清水×1；木屑×1；炭砂滤料×1 |
| 整体维护·净水菌毯 | ×4 | 整体维护·净水菌毯：污水×4（每培养单位·每轮）｜净水菌床｜净水菌毯｜1AP | 清水×1；木屑×1；炭砂滤料×1 |
| 启动研究·菌毯净化 | ×2 | 启动研究·菌毯净化：污水×2（一次性）｜研究台 | 木腐菇×1；元石×4 |

相关规则：[市集交易](#市集交易-rulemarket)

### 复合水养料 `resource:water_feed`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·加工品；标签：animal_feed |
| 市集采购 | 不可采购 |
| 市集出售 | 3元石/份（计入销售收入） |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·水养料调配 | ×4 | 加工·水养料调配：复合水养料×4（每批）｜农产加工台｜需研究「饲料与蜡油精制」｜1自然日｜启动1＋收取1 | 藻料×3；谷粉×1；油饼×1 |

**直接用途（4条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 整体维护·滤藻鲤 | ×1 | 整体维护·滤藻鲤：复合水养料×1（每尾·每日）｜捕鲤台｜滤藻鲤｜1AP | 藻料×1；高密度藻料×1；谷粒×1 |
| 整体维护·油鳍鱼 | ×1 | 整体维护·油鳍鱼：复合水养料×1（每尾·每日）｜取油台｜油鳍鱼｜1AP | 藻料×1 |
| 整体维护·油鳍鱼 | ×1 | 整体维护·油鳍鱼：复合水养料×1（每尾·每轮）｜取油台｜油鳍鱼｜1AP | 藻料×1 |
| 市集出售·复合水养料 | ×按订单/库存 | 市集出售·复合水养料：复合水养料×按订单/库存（每份） | 元石×3 |

相关规则：[市集交易](#市集交易-rulemarket)

### 凝水胶 `resource:water_gel`

水行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 水行·固体·加工品；标签：animal_product |
| 市集采购 | 不可采购 |
| 市集出售 | 4元石/份（计入销售收入） |
| 下游用途 | 无下游配方：出售与供货是该物品的设计出口 |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 收取·凝胶水母 | ×2 | 收取·凝胶水母：凝水胶×2（每群·每轮）｜采胶台｜凝胶水母｜1AP | — |

**直接用途（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集出售·凝水胶 | ×按订单/库存 | 市集出售·凝水胶：凝水胶×按订单/库存（每份） | 元石×4 |

相关规则：[市集交易](#市集交易-rulemarket)

### 木屑 `resource:wood_chip`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·加工品；标签：organic、cultivation |
| 市集采购 | 4元石/份 |
| 市集出售 | 2元石/份（计入销售收入） |

**获取来源（4条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·锯切木板 | ×1 | 加工·锯切木板：木屑×1（每批）｜木工台｜1自然日｜启动1＋收取1 | 原木×2；木板×2 |
| 加工·枝条粉碎 | ×3 | 加工·枝条粉碎：木屑×3（每批）｜木工台｜1自然日｜启动1＋收取1 | 枝条×2 |
| 加工·原木粉碎 | ×4 | 加工·原木粉碎：木屑×4（每批）｜木工台｜1自然日｜启动1＋收取1 | 原木×1 |
| 市集采购·木屑 | ×按订单/库存 | 市集采购·木屑：木屑×按订单/库存（每份） | 元石×4 |

**直接用途（10条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·菌毯净水 | ×1 | 加工·菌毯净水：木屑×1（每批）｜净水菌床｜需研究「菌毯净化」｜2自然日｜启动1＋收取1 | 污水×4；清水×2；污泥×1 |
| 加工·木屑生物炭化 | ×4 | 加工·木屑生物炭化：木屑×4（每批）｜炭化巢｜需研究「农产初加工」｜1自然日｜启动1＋收取1 | 木炭×2；腐殖土×1 |
| 加工·木屑堆肥 | ×3 | 加工·木屑堆肥：木屑×3（每批）｜堆肥箱｜2自然日｜启动1＋收取1 | 腐殖土×2 |
| 加工·丝质滤材 | ×1 | 加工·丝质滤材：木屑×1（每批）｜木工台｜需研究「水与藻料回流」｜1自然日｜启动1＋收取1 | 蚕丝×1；木炭×1；炭砂滤料×3 |
| 加工·秸秆翻肥 | ×1 | 加工·秸秆翻肥：木屑×1（每批）｜翻肥窝｜1自然日｜启动1＋收取1 | 秸秆×2；腐殖土×4 |
| 整体维护·炭腹虫 | ×4 | 整体维护·炭腹虫：木屑×4（每群·每轮）｜炭化巢｜炭腹虫｜1AP | 牧草×1；清水×1；枝条×4 |
| 整体维护·堆肥鼠 | ×1 | 整体维护·堆肥鼠：木屑×1（每只·每轮）｜翻肥窝｜堆肥鼠｜1AP | 牧草×1；清水×1；秸秆×2；污泥×2；油饼×1 |
| 整体维护·净水菌毯 | ×1 | 整体维护·净水菌毯：木屑×1（每培养单位·每轮）｜净水菌床｜净水菌毯｜1AP | 清水×1；污水×4；污水×4；炭砂滤料×1 |
| 播种·木腐菇 | ×3 | 播种·木腐菇：木屑×3（每次播种）｜1AP | 清水×2；木腐菇菌种×1 |
| 市集出售·木屑 | ×按订单/库存 | 市集出售·木屑：木屑×按订单/库存（每份） | 元石×2 |

相关规则：[市集交易](#市集交易-rulemarket)

### 木腐菇菌种 `resource:wood_decay_spawn`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·初级；标签：seed、cultivation |
| 市集采购 | 3元石/份 |
| 市集出售 | 不可出售 |

**获取来源（3条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 市集采购·木腐菇菌种 | ×按订单/库存 | 市集采购·木腐菇菌种：木腐菇菌种×按订单/库存（每份） | 元石×3 |
| 新档初始物资 | ×4 | 新档初始物资：木腐菇菌种×4（每新档一次性） | 金穗麦种子×8；速生杉苗×2；松脂树苗×1 |
| 育种奖励·木腐菇 | ×1 | 育种奖励·木腐菇：木腐菇菌种×1（每株首次成熟；成功时） | — |

**直接用途（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 播种·木腐菇 | ×1 | 播种·木腐菇：木腐菇菌种×1（每次播种）｜1AP | 木屑×3；清水×2 |

相关规则：[市集交易](#市集交易-rulemarket)

### 木板 `resource:wood_plank`

木行固体；生产材料

| 字段 | 内容 |
|---|---|
| 分类 | 木行·固体·加工品；标签：building |
| 市集采购 | 不可采购 |
| 市集出售 | 8元石/份（计入销售收入） |

**获取来源（1条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 加工·锯切木板 | ×2 | 加工·锯切木板：木板×2（每批）｜木工台｜1自然日｜启动1＋收取1 | 原木×2；木屑×1 |

**直接用途（23条）**

| 过程 | 本条目数量 | 说明 | 同批 |
|---|---|---|---|
| 建造·水生种植台 | ×1 | 建造·水生种植台：木板×1（每次建造）｜水生种植台｜1AP | 普通岩石×2；复合石板×2；再生填料×4；元石×8 |
| 建造·蜂箱 | ×2 | 建造·蜂箱：木板×2（每次建造）｜蜂箱｜需研究「蜂群协作」｜1AP | 原木×2；元石×10 |
| 建造·炭化巢 | ×2 | 建造·炭化巢：木板×2（每次建造）｜炭化巢｜需研究「农产初加工」｜1AP | 普通岩石×4；复合石板×4；再生填料×8；元石×18 |
| 建造·照料台 | ×2 | 建造·照料台：木板×2（每次建造）｜照料台｜1AP | 普通岩石×2；复合石板×2；再生填料×4；元石×24 |
| 建造·捕鲤台 | ×2 | 建造·捕鲤台：木板×2（每次建造）｜捕鲤台｜1AP | 普通岩石×2；复合石板×2；再生填料×4；元石×12 |
| 建造·采礁台 | ×2 | 建造·采礁台：木板×2（每次建造）｜采礁台｜需研究「矿质材料工艺」｜1AP | 普通岩石×4；复合石板×4；再生填料×8；元石×20 |
| 建造·农产加工台 | ×2 | 建造·农产加工台：木板×2（每次建造）｜农产加工台｜需研究「农产初加工」｜1AP | 普通岩石×2；复合石板×2；再生填料×4；元石×12 |
| 建造·田间维护站 | ×3 | 建造·田间维护站：木板×3（每次建造）｜田间维护站｜需研究「田间自动维护」｜1AP | 铁锭×1；元石×18 |
| 建造·采胶台 | ×2 | 建造·采胶台：木板×2（每次建造）｜采胶台｜需研究「水与藻料回流」｜1AP | 普通岩石×3；复合石板×3；再生填料×6；元石×16 |
| 建造·厨房 | ×2 | 建造·厨房：木板×2（每次建造）｜厨房｜需研究「灵食初制」｜1AP | 普通岩石×3；复合石板×3；再生填料×6；元石×12 |
| 建造·取油台 | ×2 | 建造·取油台：木板×2（每次建造）｜取油台｜需研究「农产初加工」｜1AP | 普通岩石×3；复合石板×3；再生填料×6；元石×16 |
| 建造·采珠台 | ×2 | 建造·采珠台：木板×2（每次建造）｜采珠台｜需研究「水与藻料回流」｜1AP | 普通岩石×3；复合石板×3；再生填料×6；元石×16 |
| 建造·养鳞台 | ×2 | 建造·养鳞台：木板×2（每次建造）｜养鳞台｜需研究「矿质材料工艺」｜1AP | 普通岩石×4；复合石板×4；再生填料×8；元石×18 |
| 建造·岩壳成型台 | ×2 | 建造·岩壳成型台：木板×2（每次建造）｜岩壳成型台｜需研究「矿质材料工艺」｜1AP | 普通岩石×4；复合石板×4；再生填料×8；元石×18 |
| 建造·蚕架 | ×2 | 建造·蚕架：木板×2（每次建造）｜蚕架｜1AP | 枝条×2；元石×10 |
| 建造·泥料处理台 | ×2 | 建造·泥料处理台：木板×2（每次建造）｜泥料处理台｜需研究「菌毯净化」｜1AP | 普通岩石×2；复合石板×2；再生填料×4；元石×14 |
| 建造·小型冶炼炉 | ×2 | 建造·小型冶炼炉：木板×2（每次建造）｜小型冶炼炉｜1AP | 普通岩石×6；复合石板×6；再生填料×12；元石×20 |
| 建造·安抚台 | ×2 | 建造·安抚台：木板×2（每次建造）｜安抚台｜1AP | 普通岩石×2；复合石板×2；再生填料×4；元石×18 |
| 建造·集露台 | ×1 | 建造·集露台：木板×1（每次建造）｜集露台｜1AP | 普通岩石×3；复合石板×3；再生填料×6；元石×12 |
| 建造·玩具站 | ×2 | 建造·玩具站：木板×2（每次建造）｜玩具站｜1AP | 普通岩石×2；复合石板×2；再生填料×4；元石×12 |
| 建造·换水站 | ×2 | 建造·换水站：木板×2（每次建造）｜换水站｜1AP | 普通岩石×4；复合石板×4；再生填料×8；元石×16 |
| 建造·采毛台 | ×2 | 建造·采毛台：木板×2（每次建造）｜采毛台｜1AP | 普通岩石×2；复合石板×2；再生填料×4；元石×12 |
| 市集出售·木板 | ×按订单/库存 | 市集出售·木板：木板×按订单/库存（每份） | 元石×8 |

相关规则：[市集交易](#市集交易-rulemarket)


## 配方与食谱（97）

### 蜜盏蜂·花源份额＋清水 `diet:bell_bee/base_diets/flower_share`

基础食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 蜜盏蜂 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 清水×1/单位/日 |
| 花源条件 | 额外消耗1份当日花源份额（非库存物品） |

关联条目：所属物种：[蜜盏蜂](#蜜盏蜂-speciesbell_bee)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 蜜盏蜂·酿蜜周期 `diet:bell_bee/special_diets/honey_cycle`

特殊食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 蜜盏蜂 |
| 类型 | 特殊食谱（成体生产；周期启动时一次付清投入） |
| 投入 | 无实物投入 |
| 花源条件 | 额外消耗1份当日花源份额（非库存物品） |

关联条目：所属物种：[蜜盏蜂](#蜜盏蜂-speciesbell_bee)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 炭腹虫·牧草清水餐 `diet:carbon_belly_bug/base_diets/grass_water_meal`

基础食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 炭腹虫 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 牧草×1＋清水×1/单位/日 |

关联条目：所属物种：[炭腹虫](#炭腹虫-speciescarbon_belly_bug)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 炭腹虫·木屑炭化轮 `diet:carbon_belly_bug/special_diets/bug_char_chips`

特殊食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 炭腹虫 |
| 类型 | 特殊食谱（成体生产；周期启动时一次付清投入） |
| 投入 | 木屑×4/单位/轮 |
| 周期产物 | 木炭×2＋腐殖土×1/轮/单位 |

关联条目：所属物种：[炭腹虫](#炭腹虫-speciescarbon_belly_bug)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 炭腹虫·树枝炭化轮 `diet:carbon_belly_bug/special_diets/bug_char_twigs`

特殊食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 炭腹虫 |
| 类型 | 特殊食谱（成体生产；周期启动时一次付清投入） |
| 投入 | 枝条×4/单位/轮 |
| 周期产物 | 木炭×4＋腐殖土×1/轮/单位 |

关联条目：所属物种：[炭腹虫](#炭腹虫-speciescarbon_belly_bug)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 堆肥鼠·牧草清水餐 `diet:compost_mouse/base_diets/grass_water_meal`

基础食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 堆肥鼠 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 牧草×1＋清水×1/单位/日 |

关联条目：所属物种：[堆肥鼠](#堆肥鼠-speciescompost_mouse)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 堆肥鼠·秸秆堆肥轮 `diet:compost_mouse/special_diets/mouse_compost_fiber`

特殊食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 堆肥鼠 |
| 类型 | 特殊食谱（成体生产；周期启动时一次付清投入） |
| 投入 | 秸秆×2＋木屑×1/单位/轮 |
| 周期产物 | 腐殖土×4/轮/单位 |

关联条目：所属物种：[堆肥鼠](#堆肥鼠-speciescompost_mouse)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 堆肥鼠·残料堆肥轮 `diet:compost_mouse/special_diets/mouse_compost_residue`

特殊食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 堆肥鼠 |
| 类型 | 特殊食谱（成体生产；周期启动时一次付清投入） |
| 投入 | 污泥×2＋油饼×1/单位/轮 |
| 周期产物 | 腐殖土×3/轮/单位 |

关联条目：所属物种：[堆肥鼠](#堆肥鼠-speciescompost_mouse)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 露壳蜗牛·牧草清水餐 `diet:dew_shell_snail/base_diets/grass_water_meal`

基础食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 露壳蜗牛 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 牧草×1＋清水×1/单位/日 |

关联条目：所属物种：[露壳蜗牛](#露壳蜗牛-speciesdew_shell_snail)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 露壳蜗牛·灵液采集轮 `diet:dew_shell_snail/special_diets/dew_round`

特殊食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 露壳蜗牛 |
| 类型 | 特殊食谱（成体生产；周期启动时一次付清投入） |
| 投入 | 清水×2/单位/轮 |

关联条目：所属物种：[露壳蜗牛](#露壳蜗牛-speciesdew_shell_snail)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 滤藻鲤·藻料餐 `diet:filter_algae_carp/base_diets/algae_meal`

基础食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 滤藻鲤 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 藻料×1/单位/日 |

关联条目：所属物种：[滤藻鲤](#滤藻鲤-speciesfilter_algae_carp)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 滤藻鲤·高密度藻餐 `diet:filter_algae_carp/base_diets/dense_meal`

基础食谱

> 解锁条件：需完成研究 [水与藻料回流](#水与藻料回流-researchwater_recirculation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 所属物种 | 滤藻鲤 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 高密度藻料×1/单位/日 |

关联条目：所属物种：[滤藻鲤](#滤藻鲤-speciesfilter_algae_carp)；解锁研究：[水与藻料回流](#水与藻料回流-researchwater_recirculation)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 滤藻鲤·水养复合餐 `diet:filter_algae_carp/base_diets/water_meal`

基础食谱

> 解锁条件：需完成研究 [饲料与蜡油精制](#饲料与蜡油精制-researchadvanced_feed_oil_wax)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 所属物种 | 滤藻鲤 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 复合水养料×1/单位/日 |

关联条目：所属物种：[滤藻鲤](#滤藻鲤-speciesfilter_algae_carp)；解锁研究：[饲料与蜡油精制](#饲料与蜡油精制-researchadvanced_feed_oil_wax)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 滤藻鲤·谷粒育肥 `diet:filter_algae_carp/special_diets/grain_fatten`

特殊食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 滤藻鲤 |
| 类型 | 特殊食谱（成体生产；周期启动时一次付清投入） |
| 投入 | 谷粒×1/单位/轮 |

关联条目：所属物种：[滤藻鲤](#滤藻鲤-speciesfilter_algae_carp)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 凝胶水母·藻料餐 `diet:gel_jellyfish/base_diets/algae_meal`

基础食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 凝胶水母 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 藻料×1/单位/日 |

关联条目：所属物种：[凝胶水母](#凝胶水母-speciesgel_jellyfish)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 凝胶水母·高密度藻餐 `diet:gel_jellyfish/base_diets/dense_meal`

基础食谱

> 解锁条件：需完成研究 [水与藻料回流](#水与藻料回流-researchwater_recirculation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 所属物种 | 凝胶水母 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 高密度藻料×1/单位/日 |

关联条目：所属物种：[凝胶水母](#凝胶水母-speciesgel_jellyfish)；解锁研究：[水与藻料回流](#水与藻料回流-researchwater_recirculation)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 凝胶水母·采胶轮投料 `diet:gel_jellyfish/special_diets/gel_water_round`

特殊食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 凝胶水母 |
| 类型 | 特殊食谱（成体生产；周期启动时一次付清投入） |
| 投入 | 清水×1/单位/轮 |
| 周期产物 | 凝水胶×2/轮/单位 |

关联条目：所属物种：[凝胶水母](#凝胶水母-speciesgel_jellyfish)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 砾甲蜗牛·藻料清水餐 `diet:gravel_shell_snail/base_diets/algae_water_meal`

基础食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 砾甲蜗牛 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 藻料×1＋清水×1/单位/日 |

关联条目：所属物种：[砾甲蜗牛](#砾甲蜗牛-speciesgravel_shell_snail)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 砾甲蜗牛·岩壳成型轮 `diet:gravel_shell_snail/special_diets/form_rock_shell`

特殊食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 砾甲蜗牛 |
| 类型 | 特殊食谱（成体生产；周期启动时一次付清投入） |
| 投入 | 石粉×3＋清水×1/单位/轮 |
| 周期产物 | 岩壳片×2＋黏液×1/轮/单位 |

关联条目：所属物种：[砾甲蜗牛](#砾甲蜗牛-speciesgravel_shell_snail)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 叶丝蚕·桑叶清水餐 `diet:leaf_silkworm/base_diets/mulberry_meal`

基础食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 叶丝蚕 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 桑叶×1＋清水×1/单位/日 |

关联条目：所属物种：[叶丝蚕](#叶丝蚕-speciesleaf_silkworm)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 叶丝蚕·产丝轮 `diet:leaf_silkworm/special_diets/silk_round`

特殊食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 叶丝蚕 |
| 类型 | 特殊食谱（成体生产；周期启动时一次付清投入） |
| 投入 | 桑叶×2/单位/轮 |

关联条目：所属物种：[叶丝蚕](#叶丝蚕-speciesleaf_silkworm)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 矿鳞蜥·牧草清水餐 `diet:mineral_scale_lizard/base_diets/grass_water_meal`

基础食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 矿鳞蜥 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 牧草×1＋清水×1/单位/日 |

关联条目：所属物种：[矿鳞蜥](#矿鳞蜥-speciesmineral_scale_lizard)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 矿鳞蜥·陆养复合餐 `diet:mineral_scale_lizard/base_diets/land_meal`

基础食谱

> 解锁条件：需完成研究 [饲料与蜡油精制](#饲料与蜡油精制-researchadvanced_feed_oil_wax)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 所属物种 | 矿鳞蜥 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 复合陆养料×1＋清水×1/单位/日 |

关联条目：所属物种：[矿鳞蜥](#矿鳞蜥-speciesmineral_scale_lizard)；解锁研究：[饲料与蜡油精制](#饲料与蜡油精制-researchadvanced_feed_oil_wax)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 矿鳞蜥·养鳞轮 `diet:mineral_scale_lizard/special_diets/scale_round`

特殊食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 矿鳞蜥 |
| 类型 | 特殊食谱（成体生产；周期启动时一次付清投入） |
| 投入 | 矿质补料×2/单位/轮 |

关联条目：所属物种：[矿鳞蜥](#矿鳞蜥-speciesmineral_scale_lizard)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 油鳍鱼·藻料餐 `diet:oilfin_fish/base_diets/algae_meal`

基础食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 油鳍鱼 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 藻料×1/单位/日 |

关联条目：所属物种：[油鳍鱼](#油鳍鱼-speciesoilfin_fish)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 油鳍鱼·水养复合餐 `diet:oilfin_fish/base_diets/water_meal`

基础食谱

> 解锁条件：需完成研究 [饲料与蜡油精制](#饲料与蜡油精制-researchadvanced_feed_oil_wax)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 所属物种 | 油鳍鱼 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 复合水养料×1/单位/日 |

关联条目：所属物种：[油鳍鱼](#油鳍鱼-speciesoilfin_fish)；解锁研究：[饲料与蜡油精制](#饲料与蜡油精制-researchadvanced_feed_oil_wax)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 油鳍鱼·取油轮投料 `diet:oilfin_fish/special_diets/oilfin_oil_round`

特殊食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 油鳍鱼 |
| 类型 | 特殊食谱（成体生产；周期启动时一次付清投入） |
| 投入 | 复合水养料×1/单位/轮 |
| 周期产物 | 粗油×2＋鱼肉×1/轮/单位 |

关联条目：所属物种：[油鳍鱼](#油鳍鱼-speciesoilfin_fish)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 珍珠蚌·藻料餐 `diet:pearl_mussel/base_diets/algae_meal`

基础食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 珍珠蚌 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 藻料×1/单位/日 |

关联条目：所属物种：[珍珠蚌](#珍珠蚌-speciespearl_mussel)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 珍珠蚌·育珠轮投料 `diet:pearl_mussel/special_diets/pearl_powder_round`

特殊食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 珍珠蚌 |
| 类型 | 特殊食谱（成体生产；周期启动时一次付清投入） |
| 投入 | 石粉×1/单位/轮 |
| 周期产物 | 珍珠×2/轮/单位 |

关联条目：所属物种：[珍珠蚌](#珍珠蚌-speciespearl_mussel)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 净水菌毯·培养清水 `diet:purifying_mat/base_diets/culture_water`

基础食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 净水菌毯 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 清水×1/单位/日 |
| 适用阶段 | 仅幼体 |

关联条目：所属物种：[净水菌毯](#净水菌毯-speciespurifying_mat)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 净水菌毯·菌毯净水运行 `diet:purifying_mat/special_diets/bio_purify`

特殊食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 净水菌毯 |
| 类型 | 特殊食谱（成体生产；周期启动时一次付清投入） |
| 投入 | 污水×4＋木屑×1/单位/轮 |
| 周期产物 | 清水×2＋污泥×1/轮/单位 |

关联条目：所属物种：[净水菌毯](#净水菌毯-speciespurifying_mat)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 净水菌毯·营养液回收运行 `diet:purifying_mat/special_diets/recover_nutrients`

特殊食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 净水菌毯 |
| 类型 | 特殊食谱（成体生产；周期启动时一次付清投入） |
| 投入 | 污水×4＋炭砂滤料×1/单位/轮 |
| 周期产物 | 营养液×2＋清水×1＋污泥×1/轮/单位 |

关联条目：所属物种：[净水菌毯](#净水菌毯-speciespurifying_mat)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 礁骨珊瑚·藻料餐 `diet:reef_coral/base_diets/algae_meal`

基础食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 礁骨珊瑚 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 藻料×1/单位/日 |

关联条目：所属物种：[礁骨珊瑚](#礁骨珊瑚-speciesreef_coral)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 礁骨珊瑚·采礁轮投料 `diet:reef_coral/special_diets/coral_mineral_round`

特殊食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 礁骨珊瑚 |
| 类型 | 特殊食谱（成体生产；周期启动时一次付清投入） |
| 投入 | 石粉×3＋清水×1/单位/轮 |
| 周期产物 | 珊瑚石×2/轮/单位 |

关联条目：所属物种：[礁骨珊瑚](#礁骨珊瑚-speciesreef_coral)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 岩腹兽·牧草清水餐 `diet:rock_belly_beast/base_diets/grass_water_meal`

基础食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 岩腹兽 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 牧草×1＋清水×1/单位/日 |

关联条目：所属物种：[岩腹兽](#岩腹兽-speciesrock_belly_beast)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 岩腹兽·陆养复合餐 `diet:rock_belly_beast/base_diets/land_meal`

基础食谱

> 解锁条件：需完成研究 [饲料与蜡油精制](#饲料与蜡油精制-researchadvanced_feed_oil_wax)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 所属物种 | 岩腹兽 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 复合陆养料×1＋清水×1/单位/日 |

关联条目：所属物种：[岩腹兽](#岩腹兽-speciesrock_belly_beast)；解锁研究：[饲料与蜡油精制](#饲料与蜡油精制-researchadvanced_feed_oil_wax)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 岩腹兽·生物选矿轮 `diet:rock_belly_beast/special_diets/concentrate_ore`

特殊食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 岩腹兽 |
| 类型 | 特殊食谱（成体生产；周期启动时一次付清投入） |
| 投入 | 碎铁矿×6/单位/轮 |
| 周期产物 | 富集矿砂×2＋尾砂×1/轮/单位 |

关联条目：所属物种：[岩腹兽](#岩腹兽-speciesrock_belly_beast)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 啮岩鼹·菌菇清水餐 `diet:rock_mole/base_diets/fungus_meal`

基础食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 啮岩鼹 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 木腐菇×1＋清水×1/单位/日 |

关联条目：所属物种：[啮岩鼹](#啮岩鼹-speciesrock_mole)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 啮岩鼹·破碎矿石轮 `diet:rock_mole/special_diets/break_ore`

特殊食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 啮岩鼹 |
| 类型 | 特殊食谱（成体生产；周期启动时一次付清投入） |
| 投入 | 含铁矿石×2/单位/轮 |
| 周期产物 | 碎铁矿×3/轮/单位 |

关联条目：所属物种：[啮岩鼹](#啮岩鼹-speciesrock_mole)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 啮岩鼹·破碎石材轮 `diet:rock_mole/special_diets/break_stone`

特殊食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 啮岩鼹 |
| 类型 | 特殊食谱（成体生产；周期启动时一次付清投入） |
| 投入 | 普通岩石×2/单位/轮 |
| 周期产物 | 砂砾×2＋石粉×1/轮/单位 |

关联条目：所属物种：[啮岩鼹](#啮岩鼹-speciesrock_mole)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 净泥鳅·藻料餐 `diet:silt_loach/base_diets/algae_meal`

基础食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 净泥鳅 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 藻料×1/单位/日 |

关联条目：所属物种：[净泥鳅](#净泥鳅-speciessilt_loach)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 钢绵羊·谷粒餐 `diet:steel_sheep/base_diets/grain_meal`

基础食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 钢绵羊 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 谷粒×1＋清水×1/单位/日 |

关联条目：所属物种：[钢绵羊](#钢绵羊-speciessteel_sheep)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 钢绵羊·牧草餐 `diet:steel_sheep/base_diets/grass_meal`

基础食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 钢绵羊 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 牧草×1＋清水×1/单位/日 |

关联条目：所属物种：[钢绵羊](#钢绵羊-speciessteel_sheep)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 钢绵羊·陆养复合餐 `diet:steel_sheep/base_diets/land_meal`

基础食谱

> 解锁条件：需完成研究 [饲料与蜡油精制](#饲料与蜡油精制-researchadvanced_feed_oil_wax)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 所属物种 | 钢绵羊 |
| 类型 | 基础食谱（维持成长与有效日；每日服务时扣投入） |
| 投入 | 复合陆养料×1＋清水×1/单位/日 |

关联条目：所属物种：[钢绵羊](#钢绵羊-speciessteel_sheep)；解锁研究：[饲料与蜡油精制](#饲料与蜡油精制-researchadvanced_feed_oil_wax)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 钢绵羊·含铁补料 `diet:steel_sheep/special_diets/iron_supplement`

特殊食谱

| 字段 | 内容 |
|---|---|
| 所属物种 | 钢绵羊 |
| 类型 | 特殊食谱（成体生产；周期启动时一次付清投入） |
| 投入 | 含铁矿石×1/单位/轮 |

关联条目：所属物种：[钢绵羊](#钢绵羊-speciessteel_sheep)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 钢绵羊·矿质补料餐 `diet:steel_sheep/special_diets/mineral_supplement`

特殊食谱

> 解锁条件：需完成研究 [矿质材料工艺](#矿质材料工艺-researchmineral_materials)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 所属物种 | 钢绵羊 |
| 类型 | 特殊食谱（成体生产；周期启动时一次付清投入） |
| 投入 | 矿质补料×1/单位/轮 |

关联条目：所属物种：[钢绵羊](#钢绵羊-speciessteel_sheep)；解锁研究：[矿质材料工艺](#矿质材料工艺-researchmineral_materials)

相关规则：[养殖服务与周期口径](#养殖服务与周期口径-rulehusbandry_service)

### 藻露羹熬制 `recipe:algae_dew_soup`

厨房；藻露羹×2；2日

> 解锁条件：需完成研究 [复合灵食](#复合灵食-researchcomposite_spirit_food)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 厨房（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 高密度藻料×1＋清水×3＋花瓣×1＋木炭×1（启动时一次性扣除） |
| 产出 | 藻露羹×2（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[厨房](#厨房-facilitykitchen)；解锁研究：[复合灵食](#复合灵食-researchcomposite_spirit_food)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 黏液复合石板 `recipe:assemble_mucus_panel`

木工台；复合石板×2；1日

> 解锁条件：需完成研究 [矿质材料工艺](#矿质材料工艺-researchmineral_materials)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 木工台（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 砂砾×2＋石粉×1＋黏液×1（启动时一次性扣除） |
| 产出 | 复合石板×2（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[木工台](#木工台-facilitywoodshop)；解锁研究：[矿质材料工艺](#矿质材料工艺-researchmineral_materials)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 鳞甲复合板 `recipe:assemble_scale_panel`

木工台；复合石板×3；1日

> 解锁条件：需完成研究 [矿质材料工艺](#矿质材料工艺-researchmineral_materials)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 木工台（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 矿质鳞片×2＋蜕皮×1＋砂砾×1（启动时一次性扣除） |
| 产出 | 复合石板×3（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[木工台](#木工台-facilitywoodshop)；解锁研究：[矿质材料工艺](#矿质材料工艺-researchmineral_materials)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 岩壳石板 `recipe:assemble_shell_panel`

木工台；复合石板×3；1日

> 解锁条件：需完成研究 [矿质材料工艺](#矿质材料工艺-researchmineral_materials)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 木工台（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 岩壳片×2＋黏液×1（启动时一次性扣除） |
| 产出 | 复合石板×3（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[木工台](#木工台-facilitywoodshop)；解锁研究：[矿质材料工艺](#矿质材料工艺-researchmineral_materials)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 复合石板组装 `recipe:assemble_stone_panel`

木工台；复合石板×2；2日

> 解锁条件：需完成研究 [矿质材料工艺](#矿质材料工艺-researchmineral_materials)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 木工台（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 砂砾×2＋石粉×1＋松脂×1（启动时一次性扣除） |
| 产出 | 复合石板×2（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[木工台](#木工台-facilitywoodshop)；解锁研究：[矿质材料工艺](#矿质材料工艺-researchmineral_materials)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 菌毯净水 `recipe:bio_purify`

净水菌床；清水×2＋污泥×1；2日

> 解锁条件：需完成研究 [菌毯净化](#菌毯净化-researchbiofiltration)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 净水菌床（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 污水×4＋木屑×1（启动时一次性扣除） |
| 产出 | 清水×2＋污泥×1（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |
| 执行方式 | 活体工艺：由净水菌毯的特殊食谱执行（整体维护/自动计划），本条目与该食谱同源，勿重复计数 |

关联条目：执行设施：[净水菌床](#净水菌床-facilitypurifying_bed)；解锁研究：[菌毯净化](#菌毯净化-researchbiofiltration)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)、[活体配方的双重注册](#活体配方的双重注册-ruleliving_mapping)

### 陆养料调配 `recipe:blend_land_feed`

农产加工台；复合陆养料×3；1日

> 解锁条件：需完成研究 [饲料与蜡油精制](#饲料与蜡油精制-researchadvanced_feed_oil_wax)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 农产加工台（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 谷粉×1＋草粉×2＋油饼×1（启动时一次性扣除） |
| 产出 | 复合陆养料×3（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[农产加工台](#农产加工台-facilityfarm_processor)；解锁研究：[饲料与蜡油精制](#饲料与蜡油精制-researchadvanced_feed_oil_wax)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 水养料调配 `recipe:blend_water_feed`

农产加工台；复合水养料×4；1日

> 解锁条件：需完成研究 [饲料与蜡油精制](#饲料与蜡油精制-researchadvanced_feed_oil_wax)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 农产加工台（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 藻料×3＋谷粉×1＋油饼×1（启动时一次性扣除） |
| 产出 | 复合水养料×4（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[农产加工台](#农产加工台-facilityfarm_processor)；解锁研究：[饲料与蜡油精制](#饲料与蜡油精制-researchadvanced_feed_oil_wax)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 破碎矿石 `recipe:break_ore`

碎岩场；碎铁矿×3；1日

> 解锁条件：需完成研究 [岩料破碎](#岩料破碎-researchrock_handling)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 碎岩场（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 含铁矿石×2（启动时一次性扣除） |
| 产出 | 碎铁矿×3（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |
| 执行方式 | 活体工艺：由啮岩鼹的特殊食谱执行（整体维护/自动计划），本条目与该食谱同源，勿重复计数 |

关联条目：执行设施：[碎岩场](#碎岩场-facilityrock_breaking_yard)；解锁研究：[岩料破碎](#岩料破碎-researchrock_handling)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)、[活体配方的双重注册](#活体配方的双重注册-ruleliving_mapping)

### 破碎石材 `recipe:break_stone`

碎岩场；砂砾×2＋石粉×1；1日

> 解锁条件：需完成研究 [岩料破碎](#岩料破碎-researchrock_handling)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 碎岩场（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 普通岩石×2（启动时一次性扣除） |
| 产出 | 砂砾×2＋石粉×1（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |
| 执行方式 | 活体工艺：由啮岩鼹的特殊食谱执行（整体维护/自动计划），本条目与该食谱同源，勿重复计数 |

关联条目：执行设施：[碎岩场](#碎岩场-facilityrock_breaking_yard)；解锁研究：[岩料破碎](#岩料破碎-researchrock_handling)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)、[活体配方的双重注册](#活体配方的双重注册-ruleliving_mapping)

### 木屑生物炭化 `recipe:bug_char_chips`

炭化巢；木炭×2＋腐殖土×1；1日

> 解锁条件：需完成研究 [农产初加工](#农产初加工-researchfarm_preparation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 炭化巢（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 木屑×4（启动时一次性扣除） |
| 产出 | 木炭×2＋腐殖土×1（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |
| 执行方式 | 活体工艺：由炭腹虫的特殊食谱执行（整体维护/自动计划），本条目与该食谱同源，勿重复计数 |

关联条目：执行设施：[炭化巢](#炭化巢-facilitycarbonization_nest)；解锁研究：[农产初加工](#农产初加工-researchfarm_preparation)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)、[活体配方的双重注册](#活体配方的双重注册-ruleliving_mapping)

### 树枝生物炭化 `recipe:bug_char_twigs`

炭化巢；木炭×4＋腐殖土×1；1日

> 解锁条件：需完成研究 [农产初加工](#农产初加工-researchfarm_preparation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 炭化巢（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 枝条×4（启动时一次性扣除） |
| 产出 | 木炭×4＋腐殖土×1（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |
| 执行方式 | 活体工艺：由炭腹虫的特殊食谱执行（整体维护/自动计划），本条目与该食谱同源，勿重复计数 |

关联条目：执行设施：[炭化巢](#炭化巢-facilitycarbonization_nest)；解锁研究：[农产初加工](#农产初加工-researchfarm_preparation)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)、[活体配方的双重注册](#活体配方的双重注册-ruleliving_mapping)

### 枝条炭化 `recipe:char_twigs`

炭化炉；木炭×3；2日

| 字段 | 内容 |
|---|---|
| 执行设施 | 炭化炉（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 枝条×4（启动时一次性扣除） |
| 产出 | 木炭×3（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[炭化炉](#炭化炉-facilitychar_kiln)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 木屑堆肥 `recipe:compost_chips`

堆肥箱；腐殖土×2；2日

| 字段 | 内容 |
|---|---|
| 执行设施 | 堆肥箱（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 木屑×3（启动时一次性扣除） |
| 产出 | 腐殖土×2（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[堆肥箱](#堆肥箱-facilitycompost_bin)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 鱼粪堆肥 `recipe:compost_fish_manure`

堆肥箱；腐殖土×2；2日

| 字段 | 内容 |
|---|---|
| 执行设施 | 堆肥箱（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 鱼粪×2（启动时一次性扣除） |
| 产出 | 腐殖土×2（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[堆肥箱](#堆肥箱-facilitycompost_bin)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 牧草堆肥 `recipe:compost_grass`

堆肥箱；腐殖土×2；2日

| 字段 | 内容 |
|---|---|
| 执行设施 | 堆肥箱（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 牧草×2（启动时一次性扣除） |
| 产出 | 腐殖土×2（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[堆肥箱](#堆肥箱-facilitycompost_bin)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 油饼堆肥 `recipe:compost_oil_cake`

堆肥箱；腐殖土×2；2日

> 解锁条件：需完成研究 [农产初加工](#农产初加工-researchfarm_preparation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 堆肥箱（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 油饼×2（启动时一次性扣除） |
| 产出 | 腐殖土×2（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[堆肥箱](#堆肥箱-facilitycompost_bin)；解锁研究：[农产初加工](#农产初加工-researchfarm_preparation)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 羊粪堆肥 `recipe:compost_sheep_manure`

堆肥箱；腐殖土×2；2日

| 字段 | 内容 |
|---|---|
| 执行设施 | 堆肥箱（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 羊粪肥×2（启动时一次性扣除） |
| 产出 | 腐殖土×2（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[堆肥箱](#堆肥箱-facilitycompost_bin)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 污泥堆肥 `recipe:compost_sludge`

堆肥箱；腐殖土×2；2日

> 解锁条件：需完成研究 [菌毯净化](#菌毯净化-researchbiofiltration)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 堆肥箱（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 污泥×2（启动时一次性扣除） |
| 产出 | 腐殖土×2（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[堆肥箱](#堆肥箱-facilitycompost_bin)；解锁研究：[菌毯净化](#菌毯净化-researchbiofiltration)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 废滤炭堆肥 `recipe:compost_spent_filter`

堆肥箱；腐殖土×1；2日

> 解锁条件：需完成研究 [饲料与蜡油精制](#饲料与蜡油精制-researchadvanced_feed_oil_wax)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 堆肥箱（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 废滤炭×2（启动时一次性扣除） |
| 产出 | 腐殖土×1（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[堆肥箱](#堆肥箱-facilitycompost_bin)；解锁研究：[饲料与蜡油精制](#饲料与蜡油精制-researchadvanced_feed_oil_wax)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 秸秆堆肥 `recipe:compost_straw`

堆肥箱；腐殖土×2；2日

| 字段 | 内容 |
|---|---|
| 执行设施 | 堆肥箱（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 秸秆×2（启动时一次性扣除） |
| 产出 | 腐殖土×2（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[堆肥箱](#堆肥箱-facilitycompost_bin)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 枝条堆肥 `recipe:compost_twigs`

堆肥箱；腐殖土×2；2日

| 字段 | 内容 |
|---|---|
| 执行设施 | 堆肥箱（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 枝条×3（启动时一次性扣除） |
| 产出 | 腐殖土×2（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[堆肥箱](#堆肥箱-facilitycompost_bin)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 生物选矿 `recipe:concentrate_ore`

选矿场；富集矿砂×2＋尾砂×1；2日

> 解锁条件：需完成研究 [生物选矿](#生物选矿-researchore_concentration)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 选矿场（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 碎铁矿×6（启动时一次性扣除） |
| 产出 | 富集矿砂×2＋尾砂×1（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |
| 执行方式 | 活体工艺：由岩腹兽的特殊食谱执行（整体维护/自动计划），本条目与该食谱同源，勿重复计数 |

关联条目：执行设施：[选矿场](#选矿场-facilityore_sorting_yard)；解锁研究：[生物选矿](#生物选矿-researchore_concentration)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)、[活体配方的双重注册](#活体配方的双重注册-ruleliving_mapping)

### 藻料培养 `recipe:culture_algae`

藻类培养槽；藻料×6；2日

| 字段 | 内容 |
|---|---|
| 执行设施 | 藻类培养槽（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 清水×3＋秸秆×2（启动时一次性扣除） |
| 产出 | 藻料×6（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[藻类培养槽](#藻类培养槽-facilityalgae_tank)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 高密度藻培养 `recipe:dense_algae_culture`

藻类培养槽；高密度藻料×3；2日

> 解锁条件：需完成研究 [水与藻料回流](#水与藻料回流-researchwater_recirculation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 藻类培养槽（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 营养液×2＋清水×1＋秸秆×1（启动时一次性扣除） |
| 产出 | 高密度藻料×3（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[藻类培养槽](#藻类培养槽-facilityalgae_tank)；解锁研究：[水与藻料回流](#水与藻料回流-researchwater_recirculation)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 岩壳成型 `recipe:form_rock_shell`

岩壳成型台；岩壳片×2＋黏液×1；1日

> 解锁条件：需完成研究 [矿质材料工艺](#矿质材料工艺-researchmineral_materials)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 岩壳成型台（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 石粉×3＋清水×1（启动时一次性扣除） |
| 产出 | 岩壳片×2＋黏液×1（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |
| 执行方式 | 活体工艺：由砾甲蜗牛的特殊食谱执行（整体维护/自动计划），本条目与该食谱同源，勿重复计数 |

关联条目：执行设施：[岩壳成型台](#岩壳成型台-facilityshell_forming_station)；解锁研究：[矿质材料工艺](#矿质材料工艺-researchmineral_materials)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)、[活体配方的双重注册](#活体配方的双重注册-ruleliving_mapping)

### 菌鱼灵膳烹制 `recipe:fungus_fish_meal`

厨房；菌鱼灵膳×2；1日

> 解锁条件：需完成研究 [灵食初制](#灵食初制-researchbasic_spirit_cooking)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 厨房（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 木腐菇×1＋鱼肉×1＋精炼油×1＋木炭×1（启动时一次性扣除） |
| 产出 | 菌鱼灵膳×2（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[厨房](#厨房-facilitykitchen)；解锁研究：[灵食初制](#灵食初制-researchbasic_spirit_cooking)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 蜜谷灵饼烘焙 `recipe:honey_grain_cake`

厨房；蜜谷灵饼×2；1日

> 解锁条件：需完成研究 [灵食初制](#灵食初制-researchbasic_spirit_cooking)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 厨房（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 谷粉×2＋蜂蜜×1＋清水×1＋木炭×1（启动时一次性扣除） |
| 产出 | 蜜谷灵饼×2（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[厨房](#厨房-facilitykitchen)；解锁研究：[灵食初制](#灵食初制-researchbasic_spirit_cooking)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 蜜炼金食炼制 `recipe:honey_mineral_food`

厨房；蜜炼金食×1；2日

> 解锁条件：需完成研究 [复合灵食](#复合灵食-researchcomposite_spirit_food)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 厨房（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 铁锭×1＋蜂蜜×1＋木炭×1（启动时一次性扣除） |
| 产出 | 蜜炼金食×1（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[厨房](#厨房-facilitykitchen)；解锁研究：[复合灵食](#复合灵食-researchcomposite_spirit_food)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 炭砂滤料制作 `recipe:make_filter_media`

木工台；炭砂滤料×2；1日

> 解锁条件：需完成研究 [水与藻料回流](#水与藻料回流-researchwater_recirculation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 木工台（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 木炭×1＋砂砾×2（启动时一次性扣除） |
| 产出 | 炭砂滤料×2（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[木工台](#木工台-facilitywoodshop)；解锁研究：[水与藻料回流](#水与藻料回流-researchwater_recirculation)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 丝质滤材 `recipe:make_silk_filter_media`

木工台；炭砂滤料×3；1日

> 解锁条件：需完成研究 [水与藻料回流](#水与藻料回流-researchwater_recirculation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 木工台（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 蚕丝×1＋木屑×1＋木炭×1（启动时一次性扣除） |
| 产出 | 炭砂滤料×3（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[木工台](#木工台-facilitywoodshop)；解锁研究：[水与藻料回流](#水与藻料回流-researchwater_recirculation)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### make_vine_ball `recipe:make_vine_ball`

木工台；藤球×1；1日

| 字段 | 内容 |
|---|---|
| 执行设施 | 木工台（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 枝条×2＋秸秆×2（启动时一次性扣除） |
| 产出 | 藤球×1（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[木工台](#木工台-facilitywoodshop)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 谷粉研磨 `recipe:mill_grain`

农产加工台；谷粉×2；1日

> 解锁条件：需完成研究 [农产初加工](#农产初加工-researchfarm_preparation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 农产加工台（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 谷粒×2（启动时一次性扣除） |
| 产出 | 谷粉×2（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[农产加工台](#农产加工台-facilityfarm_processor)；解锁研究：[农产初加工](#农产初加工-researchfarm_preparation)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 草粉研磨 `recipe:mill_grass`

农产加工台；草粉×2；1日

> 解锁条件：需完成研究 [农产初加工](#农产初加工-researchfarm_preparation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 农产加工台（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 牧草×3（启动时一次性扣除） |
| 产出 | 草粉×2（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[农产加工台](#农产加工台-facilityfarm_processor)；解锁研究：[农产初加工](#农产初加工-researchfarm_preparation)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 稻米磨粉 `recipe:mill_rice`

农产加工台；谷粉×2；1日

> 解锁条件：需完成研究 [农产初加工](#农产初加工-researchfarm_preparation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 农产加工台（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 稻米×3（启动时一次性扣除） |
| 产出 | 谷粉×2（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[农产加工台](#农产加工台-facilityfarm_processor)；解锁研究：[农产初加工](#农产初加工-researchfarm_preparation)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 矿质补料调配 `recipe:mineral_feed`

农产加工台；矿质补料×2；1日

> 解锁条件：需完成研究 [矿质材料工艺](#矿质材料工艺-researchmineral_materials)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 农产加工台（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 碎铁矿×2＋草粉×2＋谷粉×1（启动时一次性扣除） |
| 产出 | 矿质补料×2（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[农产加工台](#农产加工台-facilityfarm_processor)；解锁研究：[矿质材料工艺](#矿质材料工艺-researchmineral_materials)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 秸秆翻肥 `recipe:mouse_compost_fiber`

翻肥窝；腐殖土×4；1日

| 字段 | 内容 |
|---|---|
| 执行设施 | 翻肥窝（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 秸秆×2＋木屑×1（启动时一次性扣除） |
| 产出 | 腐殖土×4（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |
| 执行方式 | 活体工艺：由堆肥鼠的特殊食谱执行（整体维护/自动计划），本条目与该食谱同源，勿重复计数 |

关联条目：执行设施：[翻肥窝](#翻肥窝-facilitycompost_mouse_den)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)、[活体配方的双重注册](#活体配方的双重注册-ruleliving_mapping)

### 残料翻肥 `recipe:mouse_compost_residue`

翻肥窝；腐殖土×3；1日

> 解锁条件：需完成研究 [菌毯净化](#菌毯净化-researchbiofiltration)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 翻肥窝（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 污泥×2＋油饼×1（启动时一次性扣除） |
| 产出 | 腐殖土×3（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |
| 执行方式 | 活体工艺：由堆肥鼠的特殊食谱执行（整体维护/自动计划），本条目与该食谱同源，勿重复计数 |

关联条目：执行设施：[翻肥窝](#翻肥窝-facilitycompost_mouse_den)；解锁研究：[菌毯净化](#菌毯净化-researchbiofiltration)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)、[活体配方的双重注册](#活体配方的双重注册-ruleliving_mapping)

### 蜜油火膏熬制 `recipe:oil_honey_paste`

厨房；蜜油火膏×2；2日

> 解锁条件：需完成研究 [复合灵食](#复合灵食-researchcomposite_spirit_food)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 厨房（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 精炼油×1＋蜂蜜×1＋精炼蜡×1＋木炭×1（启动时一次性扣除） |
| 产出 | 蜜油火膏×2（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[厨房](#厨房-facilitykitchen)；解锁研究：[复合灵食](#复合灵食-researchcomposite_spirit_food)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 油籽榨油 `recipe:press_oilseed`

农产加工台；粗油×2＋油饼×2；2日

> 解锁条件：需完成研究 [农产初加工](#农产初加工-researchfarm_preparation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 农产加工台（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 油籽×4（启动时一次性扣除） |
| 产出 | 粗油×2＋油饼×2（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[农产加工台](#农产加工台-facilityfarm_processor)；解锁研究：[农产初加工](#农产初加工-researchfarm_preparation)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 再生填料回收 `recipe:recover_fill`

木工台；再生填料×2；1日

> 解锁条件：需完成研究 [矿质材料工艺](#矿质材料工艺-researchmineral_materials)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 木工台（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 尾砂×1＋炉渣×1＋石粉×1（启动时一次性扣除） |
| 产出 | 再生填料×2（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[木工台](#木工台-facilitywoodshop)；解锁研究：[矿质材料工艺](#矿质材料工艺-researchmineral_materials)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 营养液回收 `recipe:recover_nutrients`

净水菌床；营养液×2＋清水×1＋污泥×1；2日

> 解锁条件：需完成研究 [水与藻料回流](#水与藻料回流-researchwater_recirculation)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 净水菌床（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 污水×4＋炭砂滤料×1（启动时一次性扣除） |
| 产出 | 营养液×2＋清水×1＋污泥×1（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |
| 执行方式 | 活体工艺：由净水菌毯的特殊食谱执行（整体维护/自动计划），本条目与该食谱同源，勿重复计数 |

关联条目：执行设施：[净水菌床](#净水菌床-facilitypurifying_bed)；解锁研究：[水与藻料回流](#水与藻料回流-researchwater_recirculation)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)、[活体配方的双重注册](#活体配方的双重注册-ruleliving_mapping)

### 油脂精炼 `recipe:refine_oil`

农产加工台；精炼油×2＋废滤炭×1；1日

> 解锁条件：需完成研究 [饲料与蜡油精制](#饲料与蜡油精制-researchadvanced_feed_oil_wax)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 农产加工台（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 粗油×2＋木炭×1（启动时一次性扣除） |
| 产出 | 精炼油×2＋废滤炭×1（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[农产加工台](#农产加工台-facilityfarm_processor)；解锁研究：[饲料与蜡油精制](#饲料与蜡油精制-researchadvanced_feed_oil_wax)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 蜂蜡精炼 `recipe:refine_wax`

农产加工台；精炼蜡×1；1日

> 解锁条件：需完成研究 [饲料与蜡油精制](#饲料与蜡油精制-researchadvanced_feed_oil_wax)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 农产加工台（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 蜂蜡×2（启动时一次性扣除） |
| 产出 | 精炼蜡×1（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[农产加工台](#农产加工台-facilityfarm_processor)；解锁研究：[饲料与蜡油精制](#饲料与蜡油精制-researchadvanced_feed_oil_wax)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 锯切木板 `recipe:saw_planks`

木工台；木板×2＋木屑×1；1日

| 字段 | 内容 |
|---|---|
| 执行设施 | 木工台（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 原木×2（启动时一次性扣除） |
| 产出 | 木板×2＋木屑×1（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[木工台](#木工台-facilitywoodshop)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 枝条粉碎 `recipe:shred_twigs`

木工台；木屑×3；1日

| 字段 | 内容 |
|---|---|
| 执行设施 | 木工台（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 枝条×2（启动时一次性扣除） |
| 产出 | 木屑×3（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[木工台](#木工台-facilitywoodshop)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 原木粉碎 `recipe:shred_wood`

木工台；木屑×4；1日

| 字段 | 内容 |
|---|---|
| 执行设施 | 木工台（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 原木×1（启动时一次性扣除） |
| 产出 | 木屑×4（收取时入仓；完工≠入仓） |
| 批时 | 1自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[木工台](#木工台-facilitywoodshop)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 木炭冶炼 `recipe:smelt_charcoal`

小型冶炼炉；铁锭×1；2日

| 字段 | 内容 |
|---|---|
| 执行设施 | 小型冶炼炉（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 含铁矿石×3＋木炭×1（启动时一次性扣除） |
| 产出 | 铁锭×1（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[小型冶炼炉](#小型冶炼炉-facilitysmelter)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 富集矿冶炼 `recipe:smelt_concentrate`

小型冶炼炉；铁锭×1＋炉渣×1；2日

> 解锁条件：需完成研究 [矿质材料工艺](#矿质材料工艺-researchmineral_materials)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 小型冶炼炉（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 富集矿砂×1＋木炭×1（启动时一次性扣除） |
| 产出 | 铁锭×1＋炉渣×1（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[小型冶炼炉](#小型冶炼炉-facilitysmelter)；解锁研究：[矿质材料工艺](#矿质材料工艺-researchmineral_materials)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 松脂冶炼 `recipe:smelt_resin`

小型冶炼炉；铁锭×1；2日

| 字段 | 内容 |
|---|---|
| 执行设施 | 小型冶炼炉（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 含铁矿石×3＋松脂×1（启动时一次性扣除） |
| 产出 | 铁锭×1（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[小型冶炼炉](#小型冶炼炉-facilitysmelter)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)

### 腐土菌丸炼制 `recipe:soil_spirit_pill`

厨房；腐土菌丸×2；2日

> 解锁条件：需完成研究 [复合灵食](#复合灵食-researchcomposite_spirit_food)；未解锁时仍可阅读本条目，阅读不解锁玩法。

| 字段 | 内容 |
|---|---|
| 执行设施 | 厨房（须已建成；一次一批次；可由负责人按持续生产策略自动启动） |
| 投入 | 腐殖土×2＋木腐菇×1＋草粉×1＋木炭×1（启动时一次性扣除） |
| 产出 | 腐土菌丸×2（收取时入仓；完工≠入仓） |
| 批时 | 2自然日（日结推进，无需每日点击） |
| AP | 启动1＋收取1 |

关联条目：执行设施：[厨房](#厨房-facilitykitchen)；解锁研究：[复合灵食](#复合灵食-researchcomposite_spirit_food)

相关规则：[持续生产与保留量](#持续生产与保留量-ruleauto_production)


## 研究与科技（12）

### 饲料与蜡油精制 `research:advanced_feed_oil_wax`

第2层研究；8元石＋4有效日；解锁7项

| 字段 | 内容 |
|---|---|
| 层级与前置 | 第2层；前置：蜂群协作、农产初加工 |
| 样本 | 粗油×1＋蜂蜡×1＋谷粉×1（启动时一次性消耗） |
| 启动费 | 8元石（一次性；暂停不退款） |
| 有效研究日 | 4个（每台每日最多登记1次研究工作：手动1AP或负责人1元石；只等日子不推进） |
| 研究台 | 每台同时1个项目；完成知识全农场共享 |
| 解锁内容 | 配方·油脂精炼、配方·陆养料调配、配方·水养料调配、配方·蜂蜡精炼、配方·废滤炭堆肥、食谱·land_meal、食谱·water_meal |

关联条目：解锁配方：[油脂精炼](#油脂精炼-reciperefine_oil)；解锁配方：[陆养料调配](#陆养料调配-recipeblend_land_feed)；解锁配方：[水养料调配](#水养料调配-recipeblend_water_feed)；解锁配方：[蜂蜡精炼](#蜂蜡精炼-reciperefine_wax)；解锁配方：[废滤炭堆肥](#废滤炭堆肥-recipecompost_spent_filter)；解锁食谱：[钢绵羊·陆养复合餐](#钢绵羊陆养复合餐-dietsteel_sheepbase_dietsland_meal)；解锁食谱：[岩腹兽·陆养复合餐](#岩腹兽陆养复合餐-dietrock_belly_beastbase_dietsland_meal)；解锁食谱：[矿鳞蜥·陆养复合餐](#矿鳞蜥陆养复合餐-dietmineral_scale_lizardbase_dietsland_meal)；解锁食谱：[滤藻鲤·水养复合餐](#滤藻鲤水养复合餐-dietfilter_algae_carpbase_dietswater_meal)；解锁食谱：[油鳍鱼·水养复合餐](#油鳍鱼水养复合餐-dietoilfin_fishbase_dietswater_meal)

相关规则：[研究系统](#研究系统-ruleresearch)

### 灵食初制 `research:basic_spirit_cooking`

第2层研究；8元石＋4有效日；解锁3项

| 字段 | 内容 |
|---|---|
| 层级与前置 | 第2层；前置：饲料与蜡油精制 |
| 样本 | 蜂蜜×1＋谷粉×1＋鱼肉×1（启动时一次性消耗） |
| 启动费 | 8元石（一次性；暂停不退款） |
| 有效研究日 | 4个（每台每日最多登记1次研究工作：手动1AP或负责人1元石；只等日子不推进） |
| 研究台 | 每台同时1个项目；完成知识全农场共享 |
| 解锁内容 | 设施·厨房、配方·蜜谷灵饼烘焙、配方·菌鱼灵膳烹制 |

关联条目：解锁设施：[厨房](#厨房-facilitykitchen)；解锁配方：[蜜谷灵饼烘焙](#蜜谷灵饼烘焙-recipehoney_grain_cake)；解锁配方：[菌鱼灵膳烹制](#菌鱼灵膳烹制-recipefungus_fish_meal)

相关规则：[研究系统](#研究系统-ruleresearch)

### 蜂群协作 `research:beekeeping`

第1层研究；6元石＋2有效日；解锁2项

| 字段 | 内容 |
|---|---|
| 层级与前置 | 第1层；前置：花源栽培 |
| 样本 | 花蜜×2＋花粉×1（启动时一次性消耗） |
| 启动费 | 6元石（一次性；暂停不退款） |
| 有效研究日 | 2个（每台每日最多登记1次研究工作：手动1AP或负责人1元石；只等日子不推进） |
| 研究台 | 每台同时1个项目；完成知识全农场共享 |
| 解锁内容 | 设施·蜂箱、物种·蜜盏蜂 |

关联条目：解锁设施：[蜂箱](#蜂箱-facilitybee_hive)；解锁物种：[蜜盏蜂](#蜜盏蜂-speciesbell_bee)

相关规则：[研究系统](#研究系统-ruleresearch)

### 菌毯净化 `research:biofiltration`

第1层研究；4元石＋2有效日；解锁8项

| 字段 | 内容 |
|---|---|
| 层级与前置 | 第1层；前置：无 |
| 样本 | 污水×2＋木腐菇×1（启动时一次性消耗） |
| 启动费 | 4元石（一次性；暂停不退款） |
| 有效研究日 | 2个（每台每日最多登记1次研究工作：手动1AP或负责人1元石；只等日子不推进） |
| 研究台 | 每台同时1个项目；完成知识全农场共享 |
| 解锁内容 | 采购·净水菌毯培养单位、设施·净水菌床、设施·泥料处理台、配方·菌毯净水、配方·污泥堆肥、配方·残料翻肥、物种·净水菌毯、物种·净泥鳅 |

关联条目：解锁采购：[净水菌毯培养单位](#净水菌毯培养单位-resourcepurifying_mat_culture)；解锁设施：[净水菌床](#净水菌床-facilitypurifying_bed)；解锁设施：[泥料处理台](#泥料处理台-facilitysilt_processing_station)；解锁配方：[菌毯净水](#菌毯净水-recipebio_purify)；解锁配方：[污泥堆肥](#污泥堆肥-recipecompost_sludge)；解锁配方：[残料翻肥](#残料翻肥-recipemouse_compost_residue)；解锁物种：[净水菌毯](#净水菌毯-speciespurifying_mat)；解锁物种：[净泥鳅](#净泥鳅-speciessilt_loach)

相关规则：[研究系统](#研究系统-ruleresearch)

### 复合灵食 `research:composite_spirit_food`

第3层研究；12元石＋6有效日；解锁4项

| 字段 | 内容 |
|---|---|
| 层级与前置 | 第3层；前置：灵食初制、水与藻料回流、矿质材料工艺 |
| 样本 | 精炼油×1＋高密度藻料×1＋铁锭×1（启动时一次性消耗） |
| 启动费 | 12元石（一次性；暂停不退款） |
| 有效研究日 | 6个（每台每日最多登记1次研究工作：手动1AP或负责人1元石；只等日子不推进） |
| 研究台 | 每台同时1个项目；完成知识全农场共享 |
| 解锁内容 | 配方·藻露羹熬制、配方·蜜油火膏熬制、配方·腐土菌丸炼制、配方·蜜炼金食炼制 |

关联条目：解锁配方：[藻露羹熬制](#藻露羹熬制-recipealgae_dew_soup)；解锁配方：[蜜油火膏熬制](#蜜油火膏熬制-recipeoil_honey_paste)；解锁配方：[腐土菌丸炼制](#腐土菌丸炼制-recipesoil_spirit_pill)；解锁配方：[蜜炼金食炼制](#蜜炼金食炼制-recipehoney_mineral_food)

相关规则：[研究系统](#研究系统-ruleresearch)

### 农产初加工 `research:farm_preparation`

第1层研究；6元石＋2有效日；解锁12项

| 字段 | 内容 |
|---|---|
| 层级与前置 | 第1层；前置：花源栽培 |
| 样本 | 油籽×2＋秸秆×2（启动时一次性消耗） |
| 启动费 | 6元石（一次性；暂停不退款） |
| 有效研究日 | 2个（每台每日最多登记1次研究工作：手动1AP或负责人1元石；只等日子不推进） |
| 研究台 | 每台同时1个项目；完成知识全农场共享 |
| 解锁内容 | 设施·炭化巢、设施·农产加工台、设施·取油台、配方·木屑生物炭化、配方·树枝生物炭化、配方·油饼堆肥、配方·谷粉研磨、配方·草粉研磨、配方·稻米磨粉、配方·油籽榨油、物种·炭腹虫、物种·油鳍鱼 |

关联条目：解锁设施：[炭化巢](#炭化巢-facilitycarbonization_nest)；解锁设施：[农产加工台](#农产加工台-facilityfarm_processor)；解锁设施：[取油台](#取油台-facilityoilfish_harvest_station)；解锁配方：[木屑生物炭化](#木屑生物炭化-recipebug_char_chips)；解锁配方：[树枝生物炭化](#树枝生物炭化-recipebug_char_twigs)；解锁配方：[油饼堆肥](#油饼堆肥-recipecompost_oil_cake)；解锁配方：[谷粉研磨](#谷粉研磨-recipemill_grain)；解锁配方：[草粉研磨](#草粉研磨-recipemill_grass)；解锁配方：[稻米磨粉](#稻米磨粉-recipemill_rice)；解锁配方：[油籽榨油](#油籽榨油-recipepress_oilseed)；解锁物种：[炭腹虫](#炭腹虫-speciescarbon_belly_bug)；解锁物种：[油鳍鱼](#油鳍鱼-speciesoilfin_fish)

相关规则：[研究系统](#研究系统-ruleresearch)

### 田间自动维护 `research:field_maintenance`

第3层研究；12元石＋6有效日；解锁1项

| 字段 | 内容 |
|---|---|
| 层级与前置 | 第3层；前置：饲料与蜡油精制、水与藻料回流 |
| 样本 | 腐殖土×2＋清水×4＋复合陆养料×1（启动时一次性消耗） |
| 启动费 | 12元石（一次性；暂停不退款） |
| 有效研究日 | 6个（每台每日最多登记1次研究工作：手动1AP或负责人1元石；只等日子不推进） |
| 研究台 | 每台同时1个项目；完成知识全农场共享 |
| 解锁内容 | 设施·田间维护站 |

关联条目：解锁设施：[田间维护站](#田间维护站-facilityfield_service_station)

相关规则：[研究系统](#研究系统-ruleresearch)

### 花源栽培 `research:flower_cultivation`

第1层研究；4元石＋2有效日；解锁4项

| 字段 | 内容 |
|---|---|
| 层级与前置 | 第1层；前置：无 |
| 样本 | 谷粒×2＋腐殖土×1（启动时一次性消耗） |
| 启动费 | 4元石（一次性；暂停不退款） |
| 有效研究日 | 2个（每台每日最多登记1次研究工作：手动1AP或负责人1元石；只等日子不推进） |
| 研究台 | 每台同时1个项目；完成知识全农场共享 |
| 解锁内容 | 采购·蜜铃苗、采购·油籽花种子、种植·蜜铃灌木、种植·油籽花 |

关联条目：解锁采购：[蜜铃苗](#蜜铃苗-resourcehoneybell_seed)；解锁采购：[油籽花种子](#油籽花种子-resourceoilseed_flower_seed)；解锁种植：[蜜铃灌木](#蜜铃灌木-crophoneybell_bush)；解锁种植：[油籽花](#油籽花-cropoilseed_flower)

相关规则：[研究系统](#研究系统-ruleresearch)

### 矿质材料工艺 `research:mineral_materials`

第3层研究；12元石＋6有效日；解锁16项

| 字段 | 内容 |
|---|---|
| 层级与前置 | 第3层；前置：饲料与蜡油精制、生物选矿 |
| 样本 | 富集矿砂×1＋铁锭×1＋石粉×1（启动时一次性消耗） |
| 启动费 | 12元石（一次性；暂停不退款） |
| 有效研究日 | 6个（每台每日最多登记1次研究工作：手动1AP或负责人1元石；只等日子不推进） |
| 研究台 | 每台同时1个项目；完成知识全农场共享 |
| 解锁内容 | 设施·采礁台、设施·补光灯、设施·养鳞台、设施·岩壳成型台、配方·黏液复合石板、配方·鳞甲复合板、配方·岩壳石板、配方·复合石板组装、配方·岩壳成型、配方·矿质补料调配、配方·再生填料回收、配方·富集矿冶炼、物种·砾甲蜗牛、物种·矿鳞蜥、物种·礁骨珊瑚、食谱·mineral_supplement |

关联条目：解锁设施：[采礁台](#采礁台-facilitycoral_station)；解锁设施：[补光灯](#补光灯-facilitygrowth_lamp)；解锁设施：[养鳞台](#养鳞台-facilityscale_station)；解锁设施：[岩壳成型台](#岩壳成型台-facilityshell_forming_station)；解锁配方：[黏液复合石板](#黏液复合石板-recipeassemble_mucus_panel)；解锁配方：[鳞甲复合板](#鳞甲复合板-recipeassemble_scale_panel)；解锁配方：[岩壳石板](#岩壳石板-recipeassemble_shell_panel)；解锁配方：[复合石板组装](#复合石板组装-recipeassemble_stone_panel)；解锁配方：[岩壳成型](#岩壳成型-recipeform_rock_shell)；解锁配方：[矿质补料调配](#矿质补料调配-recipemineral_feed)；解锁配方：[再生填料回收](#再生填料回收-reciperecover_fill)；解锁配方：[富集矿冶炼](#富集矿冶炼-recipesmelt_concentrate)；解锁物种：[砾甲蜗牛](#砾甲蜗牛-speciesgravel_shell_snail)；解锁物种：[矿鳞蜥](#矿鳞蜥-speciesmineral_scale_lizard)；解锁物种：[礁骨珊瑚](#礁骨珊瑚-speciesreef_coral)；解锁食谱：[钢绵羊·矿质补料餐](#钢绵羊矿质补料餐-dietsteel_sheepspecial_dietsmineral_supplement)

相关规则：[研究系统](#研究系统-ruleresearch)

### 生物选矿 `research:ore_concentration`

第2层研究；8元石＋4有效日；解锁3项

| 字段 | 内容 |
|---|---|
| 层级与前置 | 第2层；前置：岩料破碎 |
| 样本 | 碎铁矿×2＋砂砾×1＋牧草×2（启动时一次性消耗） |
| 启动费 | 8元石（一次性；暂停不退款） |
| 有效研究日 | 4个（每台每日最多登记1次研究工作：手动1AP或负责人1元石；只等日子不推进） |
| 研究台 | 每台同时1个项目；完成知识全农场共享 |
| 解锁内容 | 设施·选矿场、配方·生物选矿、物种·岩腹兽 |

关联条目：解锁设施：[选矿场](#选矿场-facilityore_sorting_yard)；解锁配方：[生物选矿](#生物选矿-recipeconcentrate_ore)；解锁物种：[岩腹兽](#岩腹兽-speciesrock_belly_beast)

相关规则：[研究系统](#研究系统-ruleresearch)

### 岩料破碎 `research:rock_handling`

第1层研究；6元石＋2有效日；解锁4项

| 字段 | 内容 |
|---|---|
| 层级与前置 | 第1层；前置：无 |
| 样本 | 木腐菇×1＋普通岩石×3（启动时一次性消耗） |
| 启动费 | 6元石（一次性；暂停不退款） |
| 有效研究日 | 2个（每台每日最多登记1次研究工作：手动1AP或负责人1元石；只等日子不推进） |
| 研究台 | 每台同时1个项目；完成知识全农场共享 |
| 解锁内容 | 设施·碎岩场、配方·破碎石材、配方·破碎矿石、物种·啮岩鼹 |

关联条目：解锁设施：[碎岩场](#碎岩场-facilityrock_breaking_yard)；解锁配方：[破碎石材](#破碎石材-recipebreak_stone)；解锁配方：[破碎矿石](#破碎矿石-recipebreak_ore)；解锁物种：[啮岩鼹](#啮岩鼹-speciesrock_mole)

相关规则：[研究系统](#研究系统-ruleresearch)

### 水与藻料回流 `research:water_recirculation`

第2层研究；8元石＋4有效日；解锁9项

| 字段 | 内容 |
|---|---|
| 层级与前置 | 第2层；前置：菌毯净化、岩料破碎 |
| 样本 | 污泥×1＋砂砾×1＋木炭×1（启动时一次性消耗） |
| 启动费 | 8元石（一次性；暂停不退款） |
| 有效研究日 | 4个（每台每日最多登记1次研究工作：手动1AP或负责人1元石；只等日子不推进） |
| 研究台 | 每台同时1个项目；完成知识全农场共享 |
| 解锁内容 | 设施·采胶台、设施·采珠台、配方·高密度藻培养、配方·炭砂滤料制作、配方·丝质滤材、配方·营养液回收、物种·凝胶水母、物种·珍珠蚌、食谱·dense_meal |

关联条目：解锁设施：[采胶台](#采胶台-facilitygel_station)；解锁设施：[采珠台](#采珠台-facilitypearl_station)；解锁配方：[高密度藻培养](#高密度藻培养-recipedense_algae_culture)；解锁配方：[炭砂滤料制作](#炭砂滤料制作-recipemake_filter_media)；解锁配方：[丝质滤材](#丝质滤材-recipemake_silk_filter_media)；解锁配方：[营养液回收](#营养液回收-reciperecover_nutrients)；解锁物种：[凝胶水母](#凝胶水母-speciesgel_jellyfish)；解锁物种：[珍珠蚌](#珍珠蚌-speciespearl_mussel)；解锁食谱：[滤藻鲤·高密度藻餐](#滤藻鲤高密度藻餐-dietfilter_algae_carpbase_dietsdense_meal)；解锁食谱：[凝胶水母·高密度藻餐](#凝胶水母高密度藻餐-dietgel_jellyfishbase_dietsdense_meal)

相关规则：[研究系统](#研究系统-ruleresearch)


## 资源点与环境（10）

### 灵田·水库 `map:farm_02`

初始20×22农场＋下方水库；扩地后外接32×22

| 字段 | 内容 |
|---|---|
| 初始范围 | 20列×22行；下方[0,14]~[19,21]共20×8为水库 |
| 扩地后范围 | 外接32×22（含负列号）；未购地块不可开垦/建造/标记 |
| 光照区域 | 默认80；左下阴影区30（rect [0, 9, 8, 5]）适合喜阴菌菇 |

相关规则：[环境值与有效光照](#环境值与有效光照-ruleenvironment)、[购地与连续地图](#购地与连续地图-ruleexpansion)

### 东侧远田 `parcel:east_far`

草地32格；120元石

| 字段 | 内容 |
|---|---|
| 范围 | 左上(24,0)，4×8共32格（连续坐标；原有坐标不变） |
| 地形 | 草地（开垦后可耕种） |
| 价格 | 120元石（0AP；计入建设支出；重复购买不扣款） |
| 前置 | 东侧近田 |

相关规则：[购地与连续地图](#购地与连续地图-ruleexpansion)

### 东侧下田 `parcel:east_lower`

草地48格；180元石

| 字段 | 内容 |
|---|---|
| 范围 | 左上(20,8)，8×6共48格（连续坐标；原有坐标不变） |
| 地形 | 草地（开垦后可耕种） |
| 价格 | 180元石（0AP；计入建设支出；重复购买不扣款） |
| 前置 | 东侧近田、东侧远田 |

相关规则：[购地与连续地图](#购地与连续地图-ruleexpansion)

### 东侧近田 `parcel:east_near`

草地32格；80元石

| 字段 | 内容 |
|---|---|
| 范围 | 左上(20,0)，4×8共32格（连续坐标；原有坐标不变） |
| 地形 | 草地（开垦后可耕种） |
| 价格 | 80元石（0AP；计入建设支出；重复购买不扣款） |
| 前置 | 无 |

相关规则：[购地与连续地图](#购地与连续地图-ruleexpansion)

### 东侧远岸水库 `parcel:east_water_far`

水面32格；120元石

| 字段 | 内容 |
|---|---|
| 范围 | 左上(24,14)，4×8共32格（连续坐标；原有坐标不变） |
| 地形 | 水面（仅可建水场） |
| 价格 | 120元石（0AP；计入建设支出；重复购买不扣款） |
| 前置 | 东侧近岸水库 |

相关规则：[购地与连续地图](#购地与连续地图-ruleexpansion)

### 东侧近岸水库 `parcel:east_water_near`

水面32格；80元石

| 字段 | 内容 |
|---|---|
| 范围 | 左上(20,14)，4×8共32格（连续坐标；原有坐标不变） |
| 地形 | 水面（仅可建水场） |
| 价格 | 80元石（0AP；计入建设支出；重复购买不扣款） |
| 前置 | 无 |

相关规则：[购地与连续地图](#购地与连续地图-ruleexpansion)

### 西侧水库 `parcel:west_water`

水面32格；80元石

| 字段 | 内容 |
|---|---|
| 范围 | 左上(-4,14)，4×8共32格（连续坐标；原有坐标不变） |
| 地形 | 水面（仅可建水场） |
| 价格 | 80元石（0AP；计入建设支出；重复购买不扣款） |
| 前置 | 无 |

相关规则：[购地与连续地图](#购地与连续地图-ruleexpansion)

### 采矿点 `source:ore_source`

含铁矿石×2/次；日上限12

| 字段 | 内容 |
|---|---|
| 位置 | (16,8)，不可开垦、不可被设施覆盖 |
| 每批产出 | 含铁矿石×2，手动1AP |
| 每日上限 | 12含铁矿石份/日（按物品计；日结重置；手动与雇工共享） |
| 雇工采集 | 可指派1名雇工日结执行（成功1次1元石；需农务兼任启用） |

相关规则：[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)

### 泉水点 `source:spring_source`

清水×5/次；日上限30

| 字段 | 内容 |
|---|---|
| 位置 | (17,8)，不可开垦、不可被设施覆盖 |
| 每批产出 | 清水×5，手动1AP |
| 每日上限 | 30清水份/日（按物品计；日结重置；手动与雇工共享） |
| 雇工采集 | 可指派1名雇工日结执行（成功1次1元石；需农务兼任启用） |

相关规则：[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)

### 采石点 `source:stone_source`

普通岩石×3/次；日上限18

| 字段 | 内容 |
|---|---|
| 位置 | (15,8)，不可开垦、不可被设施覆盖 |
| 每批产出 | 普通岩石×3，手动1AP |
| 每日上限 | 18普通岩石份/日（按物品计；日结重置；手动与雇工共享） |
| 雇工采集 | 可指派1名雇工日结执行（成功1次1元石；需农务兼任启用） |

相关规则：[日结顺序与自动推进](#日结顺序与自动推进-ruleday_settle)


## 基础玩法（19）

### 农业辅助蛊：定向服务区与效果决议 `rule:agriculture`

1. 催生、锁水、节肥三种农业辅助蛊共用田间维护站的单一蛊槽（兼容标签agriculture_assist）；每座维护站同时只能入驻一只，建筑自身补水/施肥是独立来源，不因蛊停摆而停止。
2. 田间维护站占1×1，普通补水/施肥范围由占地外扩2格为5×5；蛊服务区独立按朝向计算3×3。右为+x、下为+y，东/南/西/北服务区左上相对宿主分别为(1,-1)/(-1,1)/(-3,-1)/(-1,-3)。出图裁剪但不授予地权；转向1AP、次日开日生效，当日已付不退，不能轮转复用。
3. 作物全部占地格都在单个有效服务区内才获得效果，不拼接多来源局部覆盖；承载即9格种植面积（1×1计1格、2×2计4格），空格无预占收益。
4. 效果按tag互斥分组（plant_growth_speed/plant_water_saving/plant_fertility_saving）：同tag只采用最高转有效来源，同转比实际收益（催生倍率高者强、水肥保留比例低者强），平局以稳定实例ID；异类效果共同生效且不互相增强。
5. 催生只提高当日生长点推进（首轮×1.5），不改成熟目标、不按视觉阶段减天；待收对象不再推进。锁水/节肥分别按保留比例减少目标环境水/肥扣耗（首轮各保留50%），以每格百分之一余量跨日累计，不产生实物、不返还物品、不抬高环境值。
6. 饭袋草蛊属于植物目标但无肥力消耗，节肥对其无效。余量归属地格：收获、重种、取消、换蛊、休眠、转向、拆建与读档都不清除。
7. 未采用的启用来源只要满足扣费条件仍支付维护；缺元石或食料时不授予当日运行资格，普通生产回退基础效率，环境不足的原降效规则保留。

### 畜牧强化：安抚、役使与耐用玩具 `rule:animal-services`

1. 一级房间的配套允许基础运行；设施入驻适配蛊虫或特殊道具成为二级，缺维护时退回基础服务。三级系统由玩家明确关联多个房间，地格仍各有唯一归属。每个房间最多属于一个系统，编辑提交1AP，无变化不收费。
2. 圈养区安抚台入驻安抚蛊，只将实际合格的繁殖进度提高至150%；工作区调度站入驻奴道驭兽蛊，将实际获岗劳动点提高至150%。各1元石/日，无新增食料；岗位满、原料不足、禁工或结构不合格不产生强化工作。
3. 安抚台、调度站、玩具站每个单位各服务4空间；钢绵羊占2，岩腹兽和啮岩鼹占1。同类不叠加，优先最高转，同转稳定选择宿主；不同宿主可分担容量。育幼和维持放牧本期没有二级效果。
4. 藤球在木工台用树枝2＋秸秆2制作1个，耗时1日，无研究要求。玩具站外观为抓娃娃机，装入与卸下各1AP；长期使用，不消耗耐久，卸下返回原物，装球时不能直接拆站。
5. 每个实际有效的额外放牧单位，获得玩具服务的动物独立以10%概率额外恢复1疲劳；基础恢复不变，次日开日统一结算。查看、预览、读档和失败重试不重抽，同一动物同一单位不会重复领取。
6. 繁育场：二级圈养与一级育幼明确关联且有预留空间和合适床位，才为本轮实际繁殖进度积累目标专属贡献。出生按贡献比例最多获得成长目标10%的初始成长；中途换目标不挪用旧贡献，不追补或重复发放。
7. 协同役使场：二级工作＋一级维持＋二级额外放牧。当天成功维持且实际获得玩具服务的劳动者，真实批次溢出点可在日界确认，限原岗位同配方，上限正常1单位劳动。下批实际开工并支付原料后才使用，三级失效时封存，换配方或拆除前须明确放弃。
8. 综合牧场将上述两种配置放入同一系统，分别结算两条收益，没有第三层全局倍增。育幼目标的预留床位和空间跨圈养区共享，不能重复占用。

### 畜牧分区：九种陆生动物、三用途与八单位日程 `rule:animal-zones`

1. 九种陆生动物走名册制：钢绵羊、啮岩鼹、岩腹兽、炭腹虫、叶丝蚕、露壳蜗牛、矿鳞蜥、堆肥鼠、砾甲蜗牛。购入即幼体（群生物种按一个饲养单位登记），占用育幼区全时空间与床位；鱼、蜂、菌毯不变。
2. 成体在次日日界选择唯一用途：繁殖（繁殖区）、精养（精养区产出本体原料）或役使（工作区），同一时间只能推进一种；叶丝蚕本期不能繁殖。用途/分区/床位变更1AP次日生效，进行中的维持窗口仍按整段预约结算。
3. 六类功能区都在普通地板上明确划定四邻接成员：育幼区（圈舍＋供食槽＋床，最小空间4）、繁殖区（另加照料台，最小空间8）、精养区（另加至少一座专属精养台，最小空间8）、工作区（调度站＋至少一座专属役使设施）、维持放牧区（食槽＋床，最小空间4）、额外放牧区（玩具站，最小空间8）。非床设施占地计入扣减，床不占可用空间。
4. 床采用格内密度：一格普通地板放4张小床或4张中床，以4张一组建造；大床占满一格仅1张。体型严格匹配；同一床位可错时共用不重叠的两单位窗口。
5. 每天按八个内部逻辑单位结算：标准班维持2＋工作4＋额外放牧2，晚班为其平移4格；育幼/繁殖/精养固定维持2＋照料6。维持窗口必须连续两单位整段成功，窗口结束统一扣基础餐（育幼/役使1份、繁殖/精养2份）。
6. 维持失败自窗口结束点固定禁工八单位；疲劳只在日界更新：下一开日＝clamp(当前＋工作单位－2×有效恢复＋12×失败窗口数, 0, 100)。0-7正常100%、8-15疲倦75%、16-23过劳50%、24-39罢工、40以上濒危；连续第三个开日≥40死亡。
7. 役使设施按物种专用：碎岩场（啮岩鼹碎石/碎矿）、选矿场（岩腹兽富集）、炭化巢（炭腹虫树枝/木屑炭化）、翻肥窝（堆肥鼠秸秆/残料翻肥）、岩壳成型台（砾甲蜗牛岩壳成型）。每设施四个并行岗位，批次归设施：实际获岗才开批并扣一次原料，换班保留进度；400/600/800工作点达标1AP按场领取。正常/疲倦/过劳每劳动单位100/75/50整数点。
8. 精养产出归动物本体：钢绵羊（采毛台，18照料单位，含铁/矿质补料开轮各扣一次）、叶丝蚕（蚕架，12单位，桑叶2）、露壳蜗牛（集露台，12单位，清水2）、矿鳞蜥（养鳞台，24单位，矿质补料2）。每台每照料单位服务4空间，同动物同单位不叠台；进度按开日效率100/75/50推进、罢工停产且不扣新轮补料，安抚蛊不作用于精养；完成待收1AP经专属台批量领取，换台保留进度。
9. 繁殖只在繁殖区推进且开日疲劳0：绵羊72/鼹48/岩腹兽96/炭腹虫60/露壳72/蜥96/堆肥鼠48/砾甲84照料单位后产同种幼体1只（叶丝蚕除外），待安置1AP批量领取并检查目标育幼区容量；繁育场贡献最多10%初始成长。

### 持续生产与保留量 `rule:auto_production`

1. 策略=配方+目标产物+目标数量（0AP保存，不立即投料）；养殖设施策略同步设置特殊食谱；装置与研究台不能用策略
2. 有效库存=仓库+全部在制/待收批次产物+待收活体产物（与可用库存区分；在制不能拿去出售）
3. 目标按“单位批”推进：缺口=目标−有效库存，启动单位数=ceil(缺口/单位产出)；活体整单位启动可略超目标
4. 保留量只挡自动投料与活体自动启动；手动操作、交易、建造、研究、基础照料、装置耗料不受限

### 建材替代 `rule:build_substitute`

1. 建造材料的普通岩石部分可整体替换：复合石板1:1 或 再生填料2:1；非石料部分不可替换
2. 替代在营建界面选择，替换校验与建造共用流程

### 作物生长速率公式 `rule:crop_growth`

1. 每日进度增量 = max(1, floor(水效×肥效×光效/10000×催生倍率))，单位“点”；无催生倍率为1；首季目标=标称天数×100，留株再生目标=再生天数×100
2. 水效：占地平均水分≥30→100，否则50%；肥效：平均肥力≥30→100，否则75%；光效：|平均有效光照−偏好|≤20→100，否则50%
3. 全适宜=100点/日（即标称天数）；仅缺水或仅光照偏离=50点/日（2倍时长）；仅低肥=75点/日（4/3倍）；缺水+低肥=37点/日；三短板=18点/日
4. 多格作物按占地格平均判速；每格每日各扣该作物的水分与肥力（成熟待收期间照扣）
5. 环境不足只降速，不会死亡；生长不暂停（下限1点/日）

### 日结顺序与自动推进 `rule:day_settle`

1. AP耗尽或点“结束当天”进入日结；顺序：统一调度器（设施收取→必要换水→整体维护→研究→自动投料→农务）→ 养殖结算（水体衰减/暂停→成长与周期推进）→ 后勤蛊独立生产（按当日资格）→ 研究结算（收据工作量推进）→ 花源份额过期 → 作物生长与水肥扣减 → 资源点配额重置 → 批次完工 → 新订单 → 台账/日志 → 次日开日（蛊维护→灯→田间站）→ 日存档
2. 日存档失败回滚到当日操作前快照；重试只重写候选快照，不重复劳动或收费
3. 日结推进的各种“有效日”：研究=有收据的日子；养殖=当日有基础服务；作物=环境速率（下限1/日）

### 环境值与有效光照 `rule:environment`

1. 水分/肥力为地格环境值（0-100）：浇水耗清水×1回复+30；施肥耗腐殖土×1回复+30；≥100不可再提升
2. 自然光照：默认80，左下阴影区30（rect [0,9,8,5]）适合喜阴菌菇
3. 有效光照=max(自然光、当日有效油灯光照、当日有效明光蛊光照)；生长、花源资格与界面显示共用此值
4. 环境值与库存物品严格分离：扣水分≠耗清水物品

### 购地与连续地图 `rule:expansion`

1. 连续坐标系：基础区20×22始终可用；扩地后外接32×22（含负列号）；未购地块不可开垦/建造/标记/选种
2. 6地块：陆地112格共380元石（东侧近80/远120/下180），水面96格共280元石（西80/东近80/东远120）
3. 水场2×2占地须全部为已购水面；跨购买边界建造允许但占地须全已购
4. 购地0AP；重复购买不扣款；泉水日产量不随扩水增加；各水场水体独立

### 花源份额 `rule:flower_share`

1. 每株花作物每日1份额，当日首次合格时初始化；日结清空未用份额
2. 份额内容物=花蜜2+花粉1；手采1AP取得实物；蜂群饲喂消耗份额但不产出该内容物
3. 合格条件：蜜铃灌木=成熟期；油籽花=生长进度300~499；每格水≥30、肥≥30、光照与偏好差≤20
4. 蜂箱覆盖=占地外扩2格；手采与蜂群共享份额；蜂群用油籽花份额→该株本周期授粉（收获+1油籽，不叠加）

### 养殖服务与周期口径 `rule:husbandry_service`

1. 整体维护1AP整批执行：基础食谱喂今日未服务个体（每单位每日扣基础投入）；特殊食谱只对“当日已喂的空闲成体”启动周期，投入在周期启动一次付清
2. 收取1AP收全部待收；物种属性决定收取后移除（鱼）或保留（羊/蜂等）
3. 当日未服务：成长与周期均暂停（不死亡）；水场有鱼时水体日降5，≤30全场暂停
4. 默认食谱无需研究即可选；带研究门槛的食谱须解锁；切换特殊食谱会停用自动策略但不改写在制周期
5. 满容量参考为4单位；成本表中的“养殖参考轮”按4单位汇总，不是单只消耗

### 活体配方的双重注册 `rule:living_mapping`

1. living=true的配方（菌毯净水、营养液回收、破碎石材、破碎矿石、生物选矿）与对应物种特殊食谱是同一执行过程
2. 实际执行走物种特殊食谱（整体维护/自动计划）；配方注册面用于设施面板、研究解锁校验与自动策略选择
3. 查阅来源/用途时不重复计算两条注册

### 后勤蛊部署、维护与生产协同 `rule:logistics`

1. 后勤蛊与战斗蛊分开；获取、炼制和升转归上游。独立Demo每档可领取一次11只试用实例（饭袋草/催生/锁水/节肥各2只，明光/智道研究/宙道研究各1只），未部署不产生效果也不收费。
2. 同实例只占一处，同种不同实例可以并行；研究台只有一个辅助槽。部署/撤回各1AP；次日启用，休眠立即停止未来效果，已付维护不退。
3. 开日按稳定实例顺序检查元石与特殊食料，两者同时足额才原子扣费；闲置启用仍收费；元石不足自动休眠，玩家可申请次日恢复。读档与保存重试不重复扣费。
4. 饭袋草需光照≥60、水分≥30；每推进日扣水分8，不扣肥力、不需农田；3有效日收稻米4、无秸秆。受阻保留在制工作量，待收权益不等于库存。
5. 明光入驻补光灯替代燃油模式；有效光照取自然光、油灯及蛊光最大值。催生、锁水、节肥共用田间维护站单一蛊槽，按农业辅助规则决议（见农业辅助蛊条目），不递归增强效果源。
6. 智道减少研究工作量1（至少1）；宙道每张工作收据推进2工作量、样本逐项×1.5向上取整。每天仍最多一次玩家/雇工研究工作；任务锁定入驻实例和启动方案。
7. 运行中的任务与待收产物锁定实例；取消在制任务不退投入，待收产物须收取。已登记当日研究工作后不能休眠/取消，避免已付工作失效。

### 市集交易 `rule:market`

1. 固定价格：买价>0才可买、卖价>0才可卖；交易0AP；卖出计入销售收入
2. 买入校验“买价×100>卖价×110”防套利；买价≥卖价
3. 研究门槛：带研究要求的物品完成研究前在市集显示锁定（可见不可买）

### 五行供货与转数 `rule:orders`

1. 每日3单，路径按日轮转（木火土水金）；首单固定1转，其余按公式轮转且不超过当前解锁转数
2. 需求=基数12×转数；转数由累计营业收入解锁：0/120/300/650/1200元石对应1~5转
3. 交付：物品须可供货+元素=订单路径+供养值>0；数量=ceil(需求/供养值)；回款=数量×卖价+溢价（=基数×10%向下取整）；0AP；未完成不罚款
4. 供养值=烘焙派生的定价参考（标准成本向上取整、最低1），不是生产成本

### 研究系统 `rule:research`

1. 启动：一次性样本+费用（0AP）；前置须完成；每台一项目；全场未完成过
2. 推进：每台每日最多1次研究工作（手动1AP / 负责人1元石）；有效日=有收据的日子；第1/2/3层对应2/4/6有效日
3. 完成：知识全农场共享，解锁采购/种植/设施/配方/物种/食谱；解锁表与实体自身研究门槛双向核对一致
4. 暂停保留进度与投入，不退款；在研研究台不能拆除

### 露天农业区：地板、育种与丰产 `rule:rooms`

1. 田块由玩家明确登记地格，成员内部须上下左右连通，斜角不连。相邻田块不会自动合并，新开垦耕地不会自动加入；不要求墙、门、屋顶或中心建筑。缺地板保留归属并暂停资格。
2. 普通地板每格原木1、铺设/改铺/拆除每次1AP，不返材料；耕地沿用开垦1AP，不得覆盖作物、资源点或宿主。地权与自然地形仍限制铺设；换铺面不清空水肥与扣耗余量。
3. 农业维护站脚下普通地板，明确关联相邻且至少4格的完好田块，形成一级农业区，允许基础自动补水施肥；入驻适配蛊虫后为二级强化。全区催生＋锁水形成三级育种田，催生＋节肥为三级丰产田，三类齐全为三级复合农业区，同时打开两个奖励通道，不另叠倍。每类可由多站覆盖不同地格，但2×2植物仍需每类各有单源完整覆盖，且不得跨田块边界。
4. 每轮只累计真实推进的生长点，最后一天按剩余目标封顶；育种与丰产分别累计合格点。中途补齐、缺供、拆分、扩田与降级只影响未来贡献，成熟空等不增加资格。
5. 完整合格时首次成熟产同种种子1份的概率为25%；实际概率＝25%×首次合格生长点/首次总生长点。成熟时固定结果，随首次成熟收获、砍伐或成熟清理领取，不另耗AP；失败也用掉机会，留株再生不重抽。
6. 每轮额外主产物期望＝本次基础主产物数量×25%×本轮丰产合格点/总生长点；整数必得，小数作为再得1份概率。只增登记主产物，不增副产物、花源份额或蛊本体；饭袋草在合格耕地可增稻米，不产种子。
7. 成熟冻结贡献与随机依据，种子和材料分开判定；查阅、换向、读档、保存失败与重试不重抽或重复发放。基础收成、育种奖励、丰产奖励分别记账，未领取权益不是库存。
8. 当前P8使用schema22，早期P8开发档需新开档，不迁移、不删除旧文件。硬质地板的漏斗、管道与传动后续另案。

### 存档与经济 `rule:save`

1. 三槽日存档（user://farm_demo_p8_slots）；存档schema17；日结事务提交，失败可重试/放弃当天
2. 初始90元石、每天24AP、15日一时节；开局物资金穗麦种8、速生杉苗2、松脂树苗1、木腐菇菌种4
3. 收入=出售+订单；支出=采购+建设（设施/土地/幼体/研究费）+人工

### 雇工与统一调度器 `rule:worker_scheduler`

1. 雇工人数不限，雇佣0AP免费；每人每日12次成功工作、预算默认12元石、成功1次1元石；不扣玩家AP
2. 设施归属：一人可负责多座设施（高/普通/低优先级，同级轮转）；步骤类序：收取→水体维护→整体维护→研究→投料→农务
3. 农务兼任默认关闭；开启后8类工作按个人偏好(0~5)与标记优先级执行；浇水施肥仅当环境低于30
4. 设施负责人步序：待收收取→水体≤60时换水→整体维护（按自动计划过滤个体）
5. 无负责人/未启用/额度或预算不足时设施任务积压并显示等待天数


