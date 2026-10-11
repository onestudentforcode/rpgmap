extends RefCounted
const Economy := preload("res://scripts/farming/core/economy/farm_economy.gd")
const Inventory := preload("res://scripts/farming/core/inventory/farm_inventory.gd")
const Data := preload("res://scripts/farming/core/farm_data.gd")


static func check(ok: bool, label: String, fails: Array[String]) -> void:
	if ok:
		print("[ok] P5: " + label)
	else:
		fails.append("P5: " + label)


static func run() -> Array[String]:
	var fails: Array[String] = []
	var config := Data.load_config()
	var items := Data.items_by_id(Data.load_items())
	var crops := {}
	for crop in Data.load_crops()["crops"]:
		crops[crop["crop_id"]] = crop
	var inv := Inventory.new()
	inv.setup({})
	var economy := Economy.new()
	economy.setup(config, items, crops, inv)
	check(economy.primeval_stones == 60 and economy.gu["satiety"] == 6, "初始60元石/6饱食度", fails)
	check(economy.nutrition == {"dew_leaf": 8, "scarlet_berry_fruit": 3, "jade_fruit": 4, "moon_cap_flesh": 11},
		"生命周期成本包含占地、再生、介质并向上取整", fails)
	var before := economy.to_save()
	check(not economy.trade("dew_grass_seed", -1, true)["ok"] and not economy.trade("dew_grass_seed", 0, true)["ok"]
		and not economy.trade("unknown", 1, true)["ok"] and not economy.trade("dew_leaf", 1, true)["ok"]
		and not economy.trade("jade_fruit_tree_seed", 100, true)["ok"] and economy.to_save() == before and inv.entries().is_empty(),
		"非法交易/余额不足零变更", fails)
	check(economy.trade("dew_grass_seed", 2, true)["ok"] and economy.primeval_stones == 50 and inv.count("dew_grass_seed") == 2,
		"购买种子正确扣款入库", fails)
	before = economy.to_save()
	check(not economy.trade("dew_leaf", 1, false)["ok"] and economy.to_save() == before
		and not inv.remove("dew_grass_seed", -3) and not inv.remove("dew_grass_seed", 0) and inv.count("dew_grass_seed") == 2,
		"库存不足和非法移除不增库存/元石", fails)
	inv.add("dew_leaf", 2)
	check(economy.trade("dew_leaf", 1, false)["ok"] and economy.primeval_stones == 58 and inv.count("dew_leaf") == 1,
		"出售材料正确扣库存增元石", fails)
	check(not economy.record_use("plant", true)["ok"] and not economy.record_use("battle", false)["ok"] and economy.gu["satiety"] == 6,
		"普通操作/失败行为不扣饱食度", fails)
	economy.record_use("battle", true)
	economy.on_day_changed()
	check(economy.gu["satiety"] == 4, "指定成功行为和每日衰减叠加", fails)
	before = economy.to_save()
	check(not economy.feed("dew_leaf")["ok"] and economy.to_save() == before and inv.count("dew_leaf") == 1, "未饿不可喂养", fails)
	for day in range(8):
		economy.on_day_changed()
	check(economy.gu["satiety"] == 0 and not economy.can_use() and not economy.record_use("battle", true)["ok"],
		"归零钳制并禁止使用", fails)
	items["dew_leaf"]["path_ids"] = ["fire"]
	check(not economy.feed("dew_leaf")["ok"] and inv.count("dew_leaf") == 1, "五行不符拒绝且不扣食材", fails)
	items["dew_leaf"]["path_ids"] = ["wood"]
	check(not economy.feed("scarlet_berry_fruit")["ok"] and economy.gu["satiety"] == 0, "食材不足不改变状态", fails)
	check(economy.feed("dew_leaf")["ok"] and economy.gu["satiety"] == 6 and inv.count("dew_leaf") == 0
		and economy.gu["feeding_count"] == 1 and economy.gu["materials_consumed"] == {"dew_leaf": 1}, "喂后恢复6并记录消耗", fails)
	inv.add("scarlet_berry_fruit", 2)
	check(not economy.feed("scarlet_berry_fruit")["ok"] and inv.count("scarlet_berry_fruit") == 2, "重复喂养不扣除", fails)
	for day in range(6):
		economy.on_day_changed()
	check(economy.feed_quantity("scarlet_berry_fruit") == 2 and economy.feed("scarlet_berry_fruit")["ok"]
		and inv.count("scarlet_berry_fruit") == 0, "一餐数量按营养值向上取整", fails)
	var saved := economy.to_save()
	var restored := Economy.new()
	restored.setup(config, items, crops, inv)
	check(restored.apply_save(JSON.parse_string(JSON.stringify(saved))) and restored.to_save() == saved, "经济JSON存档完整往返", fails)
	var corrupt := saved.duplicate(true)
	corrupt["gu"]["satiety"] = 7
	check(not restored.apply_save(corrupt) and restored.to_save() == saved, "错误经济存档拒绝且零变更", fails)
	check(economy.trade("fungal_bed_material", 1, true)["ok"] and economy.medium_material("fungal_bed") == "fungal_bed_material"
		and economy.medium_material("rotten_log") == "rotten_log", "生产资源商品和介质映射", fails)
	inv.add("moon_cap_flesh", 3)
	check(economy.export_materials() == {"moon_cap_flesh": 3}, "上游材料适配仅导出收获物", fails)
	return fails
