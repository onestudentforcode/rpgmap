extends RefCounted
const Slots := preload("res://scripts/farming/core/storage/farm_slot_store.gd")
const Snapshot := preload("res://scripts/farming/core/storage/farm_snapshot.gd")
const SlotTests := preload("res://scripts/farming/tests/phase06_slots.gd")

class FailingCommit:
	extends "res://scripts/farming/core/storage/farm_slot_store.gd"
	var fail_writes := false
	func commit(snapshot: Dictionary) -> Dictionary:
		if fail_writes:
			return {"ok": false, "reason": "测试模拟磁盘写入失败"}
		return super.commit(snapshot)

static func run(tree: SceneTree) -> Array[String]:
	var fails: Array[String] = []
	var directory := "user://farm_phase06_demo_tests_%d" % Time.get_ticks_usec()
	var store := FailingCommit.new(directory)
	var shell = load("res://scripts/farming/rendering/farm_demo.gd").new()
	shell.store = store
	shell.legacy_path = directory + "/legacy.json"
	tree.root.add_child(shell)
	await tree.process_frame
	check(shell._screen == "main" and shell.farm == null, "Demo默认进入主菜单且不加载玩家旧档", fails)
	shell._show_slots("new")
	shell._select_slot("new",1)
	await tree.process_frame
	var farm = shell.farm
	check(farm != null and store.active_slot() == 1 and store.read_slot(1)["snapshot"]["clock"]["total_days"] == 0,
		"菜单新建槽建立第1天基线并进入农场", fails)
	var before := FileAccess.get_file_as_string(store.slot_path(1))
	farm.economy.trade("dew_grass_seed",1,true)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_F5
	farm._unhandled_input(key)
	key.keycode = KEY_F9
	farm._unhandled_input(key)
	check(FileAccess.get_file_as_string(store.slot_path(1)) == before and farm.economy.primeval_stones == 55,
		"F5/F9不保存也不回滚玩家状态", fails)
	farm.clock.end_day()
	check(store.read_slot(1)["snapshot"]["clock"]["total_days"] == 1
		and store.read_slot(1)["snapshot"]["economy"]["primeval_stones"] == 55
		and store.read_slot(1)["snapshot"]["economy"]["gu"]["satiety"] == 5, "休息自动保存完整经济与按天衰减状态", fails)
	farm.grid.till(Vector2i(1,1))
	farm.clock.ap = 1
	farm._tool = 1
	var seeds: int = farm.inventory.count("dew_grass_seed")
	farm._act_on(Vector2i(1,1))
	var saved: Dictionary = store.read_slot(1)["snapshot"]
	check(saved["clock"]["ap"] == 24 and saved["crops"]["crops"].size() == 1
		and saved["inventory"]["dew_grass_seed"] == seeds-1 and saved["crops"]["crops"][0]["growth_days"] == 1,
		"最后1AP播种自动档包含种子扣除、植株及跨天生长", fails)
	for day in range(3):
		farm.clock.end_day()
	farm.clock.ap = 1
	farm._act_on(Vector2i(1,1))
	saved = store.read_slot(1)["snapshot"]
	check(saved["crops"]["crops"].is_empty() and saved["inventory"].get("dew_leaf",0) >= 1
		and saved["clock"]["ap"] == 24, "最后1AP采收自动档包含产物且植株已移除", fails)
	farm._tool = 0
	farm.clock.ap = 1
	farm._do_till(Vector2i(3,1))
	saved = store.read_slot(1)["snapshot"]
	check(saved["grid"]["cells"].any(func(cell): return cell["x"] == 3 and cell["y"] == 1 and cell["s"] == "TILLED"),
		"最后1AP开垦自动档包含最终土地状态", fails)
	farm.inventory.add("fungal_bed_material",1)
	farm.clock.ap = 1
	farm._cycle_medium(Vector2i(3,1))
	saved = store.read_slot(1)["snapshot"]
	check(saved["grid"]["media"].any(func(cell): return cell["x"] == 3 and cell["y"] == 1 and cell["medium"] == "fungal_bed")
		and saved["inventory"].get("fungal_bed_material",0) == 0, "最后1AP准备介质自动档包含材料扣除与介质", fails)
	farm.grid.till(Vector2i(2,1))
	farm.crop_mgr.plant(Vector2i(2,1),"scarlet_berry")
	for day in range(4): farm.clock.end_day()
	for harvest in range(3):
		farm._act_on(Vector2i(2,1))
		if harvest < 2:
			for day in range(2): farm.clock.end_day()
	farm.clock.ap = 1
	farm._act_on(Vector2i(2,1))
	saved = store.read_slot(1)["snapshot"]
	check(saved["crops"]["crops"].is_empty() and saved["grid"]["holders"].is_empty(),
		"最后1AP清理自动档不存在残留实例或占地", fails)
	var world: Dictionary = farm.capture_snapshot()
	shell.request_exit("menu")
	check(shell._screen == "exit" and not farm._cam_ctrl.is_processing(), "离开提示暂停地图相机", fails)
	shell.choose_exit("cancel")
	check(not shell.is_modal() and farm._cam_ctrl.is_processing() and farm.capture_snapshot() == world,
		"取消离开恢复相机且世界零变更", fails)
	before = FileAccess.get_file_as_string(store.slot_path(1))
	farm.economy.trade("dew_grass_seed",1,true)
	shell.request_exit("menu")
	shell.choose_exit("discard")
	check(shell.farm == null and store.active_slot() == 0 and FileAccess.get_file_as_string(store.slot_path(1)) == before,
		"放弃当天进度返回菜单且不写存档", fails)
	shell._select_slot("continue",1)
	await tree.process_frame
	farm = shell.farm
	check(farm.capture_snapshot() == saved, "继续读取最近成功自动档，无当天弃置交易", fails)
	var day_before: int = farm.clock.total_days
	shell.request_exit("menu")
	shell.choose_exit("save")
	check(shell.farm == null and store.read_slot(1)["snapshot"]["clock"]["total_days"] == day_before+1,
		"保存离开只推进一天，成功后回菜单", fails)
	shell._show_slots("new")
	before = FileAccess.get_file_as_string(store.slot_path(1))
	shell._select_slot("new",1)
	check(shell._screen == "confirm" and FileAccess.get_file_as_string(store.slot_path(1)) == before,
		"占用槽新建先确认，无隐式覆盖", fails)
	shell._show_slots("new") # cancel
	check(FileAccess.get_file_as_string(store.slot_path(1)) == before, "取消覆盖保留原槽", fails)
	shell._select_slot("new",1)
	shell._accept_confirmation()
	await tree.process_frame
	farm = shell.farm
	check(farm.clock.total_days == 0 and farm.economy.primeval_stones == 60, "确认覆盖后才创建新档", fails)
	shell.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(shell._screen == "exit" and shell._exit_destination == "quit", "关闭窗口也进入统一退出选择", fails)
	shell.choose_exit("cancel")
	before = FileAccess.get_file_as_string(store.slot_path(1))
	store.fail_writes = true
	farm.clock.end_day()
	check(shell._screen == "save_error" and not farm._cam_ctrl.is_processing()
		and FileAccess.get_file_as_string(store.slot_path(1)) == before, "自动保存失败阻止操作并保留旧档", fails)
	day_before = farm.clock.total_days
	shell.retry_save()
	check(shell._screen == "save_error" and farm.clock.total_days == day_before, "失败重试不再次过日", fails)
	store.fail_writes = false
	shell.retry_save()
	check(not shell.is_modal() and store.read_slot(1)["snapshot"]["clock"]["total_days"] == day_before,
		"重试成功提交同一日完整快照并恢复经营", fails)
	store.fail_writes = true
	shell.request_exit("menu")
	shell.choose_exit("save")
	check(shell.farm == farm and shell._screen == "save_error", "保存退出失败不会离开农场", fails)
	day_before = farm.clock.total_days
	store.fail_writes = false
	shell.retry_save()
	check(shell.farm == null and store.read_slot(1)["snapshot"]["clock"]["total_days"] == day_before,
		"保存退出重试成功才离开且不多过一天", fails)
	shell._show_slots("continue")
	shell._confirm_delete(1)
	check(shell._screen == "confirm" and store.occupied(1), "菜单删除先确认", fails)
	shell._accept_confirmation()
	check(not store.occupied(1) and shell._screen == "slots", "确认删除只移除所选槽并刷新列表", fails)
	var imported := SlotTests.populated()
	var file := FileAccess.open(shell.legacy_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(imported))
	file.close()
	shell._show_slots("import")
	shell._select_slot("import",2)
	await tree.process_frame
	check(shell.farm != null and store.active_slot() == 2 and shell.farm.economy.primeval_stones == 87
		and FileAccess.file_exists(shell.legacy_path), "菜单显式导入旧档并保留源文件", fails)
	shell._leave("menu")
	for slot in [1,2,3]:
		store.delete_slot(slot,true)
	DirAccess.remove_absolute(shell.legacy_path)
	DirAccess.remove_absolute(directory)
	shell.queue_free()
	await tree.process_frame
	return fails

static func check(ok: bool, message: String, fails: Array[String]) -> void:
	if ok:
		print("[ok] P6.b: " + message)
	else:
		fails.append("P6.b: " + message)
