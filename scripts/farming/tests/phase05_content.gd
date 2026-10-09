extends RefCounted
const Tests := preload("res://scripts/farming/tests/phase05_economy.gd")


static func run(farm) -> Array[String]:
	var fails: Array[String] = []
	farm.grid.reset()
	farm.crop_mgr.reset_all()
	farm.clock.setup(farm._config)
	farm.inventory.setup({})
	farm.economy.setup(farm._config, farm._items_by_id, farm._crops_by_id, farm.inventory)
	farm.economy_panel._quantity.value = 2
	var ap: int = farm.clock.ap
	farm.economy_panel._trade("dew_grass_seed", true)
	Tests.check(farm.economy.primeval_stones == 50 and farm.inventory.count("dew_grass_seed") == 2 and farm.clock.ap == ap,
		"面板购买种子无AP消耗", fails)
	farm._tool = farm._tool_crop_ids.find("dew_grass") + 1
	for cell in [Vector2i(1,1), Vector2i(2,1)]:
		farm._do_till(cell)
		farm._act_on(cell)
	for day in range(4):
		farm.clock.end_day()
	Tests.check(farm.economy.gu["satiety"] == 2 and farm.crop_mgr.can_harvest(Vector2i(1,1))["ok"],
		"实际跨天同时推进生长和饱食度", fails)
	farm._act_on(Vector2i(1,1))
	farm._act_on(Vector2i(2,1))
	Tests.check(farm.inventory.count("dew_leaf") >= 2 and farm.crop_mgr.crops.is_empty(), "实际收获材料进入统一库存", fails)
	farm.record_gu_use("battle", true)
	farm.record_gu_use("battle", true)
	ap = farm.clock.ap
	var food: int = farm.inventory.count("dew_leaf")
	farm.economy_panel._feed("dew_leaf")
	Tests.check(farm.economy.gu["satiety"] == 6 and farm.inventory.count("dew_leaf") == food - 1 and farm.clock.ap == ap,
		"面板喂养消费真实收获物并恢复6，无AP消耗", fails)
	farm.economy_panel._quantity.value = 1
	farm.economy_panel._trade("dew_leaf", false)
	farm.economy_panel._trade("dew_grass_seed", true)
	Tests.check(farm.economy.primeval_stones == 53 and farm.inventory.count("dew_grass_seed") >= 1 and farm.clock.ap == ap,
		"卖出收获物再买种子形成经济闭环，无每日限制", fails)
	var medium := Vector2i(4,1)
	farm._do_till(medium)
	ap = farm.clock.ap
	farm._cycle_medium(medium)
	Tests.check(farm.grid.medium_at(medium) == "soil" and farm.clock.ap == ap, "缺生产材料准备被拒且不扣AP", fails)
	farm.economy_panel._trade("fungal_bed_material", true)
	farm._cycle_medium(medium)
	Tests.check(farm.grid.medium_at(medium) == "fungal_bed" and farm.inventory.count("fungal_bed_material") == 0
		and farm.clock.ap == ap - farm.clock.cost_of("prepare_medium"), "购入菌床材料后准备扣一份及AP", fails)
	farm.economy_panel._trade("rotten_log", true)
	farm._cycle_medium(medium)
	Tests.check(farm.grid.medium_at(medium) == "rotten_log" and farm.inventory.count("rotten_log") == 0, "朽木商品准备消耗正确", fails)
	farm._save()
	var economy: Dictionary = farm.economy.to_save()
	var inventory: Dictionary = farm.inventory.to_save()
	farm.economy.primeval_stones = 0
	farm.inventory.setup({})
	Tests.check(farm._load(true) and farm.economy.to_save() == economy and farm.inventory.to_save() == inventory,
		"真实复合磁盘存档恢复钱包/蛊虫/喂养记录/库存", fails)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(farm._save_path))
	data["schema"] = 2
	data.erase("economy")
	var file := FileAccess.open(farm._save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	Tests.check(farm._load(true) and farm.economy.primeval_stones == 60 and farm.economy.gu["satiety"] == 6
		and farm.inventory.to_save() == inventory and farm._load(true) and farm.inventory.to_save() == inventory,
		"旧schema2补经济默认值且重复读档不重复赠物", fails)
	farm._save()
	data = JSON.parse_string(FileAccess.get_file_as_string(farm._save_path))
	data["economy"]["primeval_stones"] = -1
	file = FileAccess.open(farm._save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	economy = farm.economy.to_save()
	Tests.check(not farm._load(true) and farm.economy.to_save() == economy and farm.inventory.to_save() == inventory,
		"损坏经济存档拒绝且不覆盖正常状态", fails)
	farm._save()
	return fails
