extends RefCounted
const Slots := preload("res://scripts/farming/core/storage/farm_slot_store.gd")
const Snapshot := preload("res://scripts/farming/core/storage/farm_snapshot.gd")

class FailingStore:
	extends "res://scripts/farming/core/storage/farm_slot_store.gd"
	var fail_writes := false
	func commit(snapshot: Dictionary) -> Dictionary:
		if fail_writes: return {"ok": false, "reason": "模拟写入失败"}
		return super.commit(snapshot)

static func check(ok: bool, message: String, fails: Array[String]) -> void:
	if ok: print("[ok] P6.c: " + message)
	else: fails.append("P6.c: " + message)

static func run(tree: SceneTree) -> Array[String]:
	var fails: Array[String] = []
	var directory := "user://farm_phase06_records_tests_%d" % Time.get_ticks_usec()
	var store := FailingStore.new(directory)
	var shell = load("res://scripts/farming/rendering/farm_demo.gd").new()
	shell.store = store
	shell.legacy_path = directory + "/legacy.json"
	tree.root.add_child(shell)
	shell._start_slot("new",1,false)
	await tree.process_frame
	var farm = shell.farm
	var records = farm.records
	check(records.data["revenue"] == 0 and records.data["spending"]["seed"] == 0, "初始资源不计收入与支出", fails)
	farm.economy.trade("dew_grass_seed",2,true)
	farm.economy.trade("fungal_bed_material",1,true)
	check(records.data["spending"]["seed"] == 10 and records.data["spending"]["production"] == 6, "成功买入按种子和材料分类记实际支出", fails)
	var before: Dictionary = records.data.duplicate(true)
	farm.economy.trade("jade_fruit_tree_seed",100,true)
	farm.economy.trade("dew_leaf",1,false)
	farm.economy.feed("dew_leaf")
	farm._tool = 1
	farm._act_on(Vector2i(1,1))
	check(records.data == before, "失败交易、喂养与播种零统计", fails)
	farm.grid.till(Vector2i(1,1))
	farm._act_on(Vector2i(1,1))
	check(records.data["planted"].get("dew_grass") == 1, "真实播种只记一株", fails)
	for day in range(4): farm.clock.end_day()
	var inventory: Dictionary = farm.inventory.to_save()
	farm._act_on(Vector2i(1,1))
	var products: Dictionary = records.data["yield"]
	var yield_matches := true
	for id in products:
		if products[id] != farm.inventory.count(id) - int(inventory.get(id,0)): yield_matches = false
	check(records.data["harvests"].get("dew_grass") == 1 and yield_matches, "成功收获次数与实际食材、返种入库一致", fails)
	farm.economy.trade("dew_leaf",1,false)
	farm.economy.gu["satiety"] = 0
	farm.inventory.add("dew_leaf",1)
	farm.economy.feed("dew_leaf")
	check(records.data["revenue"] == 8 and records.data["feeding"].get("dew_leaf") == 1, "出售实际收入与喂养实际消耗计入", fails)
	# Multicell planting and regrowth are domain events, independent of UI clicks.
	for cell in [Vector2i(5,11),Vector2i(6,11),Vector2i(5,12),Vector2i(6,12)]: farm.grid.till(cell)
	farm.inventory.add("jade_fruit_tree_seed",1)
	farm._tool = 3
	farm._act_on(Vector2i(5,11))
	for day in range(10): farm.clock.end_day()
	farm._act_on(Vector2i(6,12))
	for day in range(3): farm.clock.end_day()
	farm._act_on(Vector2i(5,12))
	check(records.data["planted"].get("jade_fruit_tree") == 1 and records.data["harvests"].get("jade_fruit_tree") == 2, "2×2树不按格重复计数、再生收获每次计入", fails)
	while farm.clock.total_days < 43: farm.clock.end_day()
	check(records.data["report"].is_empty(), "第44天尚未生成回顾", fails)
	farm.clock.end_day()
	check(records.data["report"].is_empty() and farm.clock.total_days == 44, "第45天日初仍可经营", fails)
	farm.grid.till(Vector2i(2,1))
	farm._tool = 1
	farm.clock.ap = 1
	farm._act_on(Vector2i(2,1))
	var saved: Dictionary = store.read_slot(1)["snapshot"]
	var report: Dictionary = records.data["report"].duplicate(true)
	check(farm.clock.total_days == 45 and report["planted"]["dew_grass"] == 2 and saved["records"]["report"] == report,
		"第45天最后1AP操作计入回顾并随完整快照保存", fails)
	check(report["balance"] == farm.economy.primeval_stones and report["net"] == -8 and report["end_day"] == 45,
		"净收入与余额独立、期末日期正确", fails)
	check(shell._screen == "records" and shell.is_modal() and not farm._cam_ctrl.is_processing(), "保存成功后展示回顾并锁定地图", fails)
	shell._set_modal(false)
	farm.economy.trade("dew_grass_seed",1,true)
	farm.clock.end_day()
	check(records.data["report"] == report and records.data["spending"]["seed"] == 10 and not shell.is_modal(), "第46天之后统计冻结且不再自动弹出", fails)
	shell.show_records()
	shell._leave("menu")
	shell._start_slot("continue",1,false)
	await tree.process_frame
	farm = shell.farm
	check(farm.records.data["report"] == report and not shell.is_modal(), "读档保留冻结报告且不重复自动展示", fails)
	shell.show_records()
	check(shell._screen == "records", "已保存回顾可以重看", fails)
	shell._leave("menu")
	shell._start_slot("new",2,false)
	await tree.process_frame
	farm = shell.farm
	farm.economy.trade("dew_grass_seed",1,true)
	shell.request_exit("menu")
	shell.choose_exit("discard")
	shell._start_slot("continue",2,false)
	await tree.process_frame
	farm = shell.farm
	check(farm.records.data["spending"]["seed"] == 0 and farm.economy.primeval_stones == 60, "放弃当天进度同时回退统计与钱包", fails)
	while farm.clock.total_days < 44: farm.clock.end_day()
	store.fail_writes = true
	shell.request_exit("menu")
	shell.choose_exit("save")
	check(shell.farm != null and shell._screen == "save_error" and store.read_slot(2)["snapshot"]["clock"]["total_days"] == 44,
		"保存退出跨45天边界失败时不离开且旧档保留", fails)
	store.fail_writes = false
	shell.retry_save()
	check(shell.farm == null and store.read_slot(2)["snapshot"]["clock"]["total_days"] == 45 and not store.read_slot(2)["snapshot"]["records"]["report"].is_empty(),
		"保存退出重试同一回顾、不额外推进日期", fails)
	shell._start_slot("new",3,false)
	await tree.process_frame
	farm = shell.farm
	while farm.clock.total_days < 44: farm.clock.end_day()
	store.fail_writes = true
	farm.clock.end_day()
	check(shell._screen == "save_error" and not farm.records.data["report"].is_empty(), "正常过日跨边界失败时优先提示保存错误", fails)
	store.fail_writes = false
	shell.retry_save()
	check(shell._screen == "records" and shell.is_modal() and farm.clock.total_days == 45, "正常保存重试成功展示回顾且不额外过日", fails)
	shell._leave("menu")
	var legacy := Snapshot.fresh()
	legacy["clock"]["total_days"] = 70
	var file := FileAccess.open(shell.legacy_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	shell._start_slot("import",3,true)
	await tree.process_frame
	farm = shell.farm
	check(farm.records.data["start_day"] == 70 and farm.records.data["report"].is_empty(), "无历史旧档从导入日开始统计", fails)
	for day in range(44): farm.clock.end_day()
	check(farm.records.data["report"].is_empty(), "旧档不按绝对第45天提前冻结", fails)
	farm.clock.end_day()
	check(farm.records.data["report"]["end_day"] == 115, "旧档接入后完整45天才生成报告", fails)
	var bad: Dictionary = farm.capture_snapshot()
	bad["records"]["report"]["net"] = 999
	var unchanged: Dictionary = farm.capture_snapshot()
	check(not farm.apply_snapshot(bad) and farm.capture_snapshot() == unchanged, "损坏回顾在修改活模型前被拒绝", fails)
	bad = unchanged.duplicate(true)
	bad["records"]["feeding"]["dew_leaf"] = -1
	check(not Snapshot.normalize(bad)["ok"], "非法负数统计拒绝存档", fails)
	shell._leave("menu")
	for slot in [1,2,3]: store.delete_slot(slot,true)
	DirAccess.remove_absolute(shell.legacy_path)
	DirAccess.remove_absolute(directory)
	shell.queue_free()
	await tree.process_frame
	return fails
