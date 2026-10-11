extends RefCounted
const Slots := preload("res://scripts/farming/core/storage/farm_slot_store.gd")
const Snapshot := preload("res://scripts/farming/core/storage/farm_snapshot.gd")
const Data := preload("res://scripts/farming/core/farm_data.gd")
const Grid := preload("res://scripts/farming/core/grid/land_grid.gd")
const Crops := preload("res://scripts/farming/core/crops/crop_manager.gd")

class FailingRename:
	extends "res://scripts/farming/core/storage/farm_slot_store.gd"
	var fail_destination := ""
	func _rename(from: String, to: String) -> Error:
		if to == fail_destination and from.ends_with(".tmp"):
			return ERR_CANT_CREATE
		return super._rename(from, to)

static func check(ok: bool, message: String, fails: Array[String]) -> void:
	if ok:
		print("[ok] P6.a: " + message)
	else:
		fails.append("P6.a: " + message)

static func populated() -> Dictionary:
	var map := Data.load_map("farm_01")
	var tillable := {}
	for terrain in Data.load_terrains()["terrains"]:
		tillable[terrain["id"]] = terrain["tillable"]
	var grid := Grid.new()
	grid.setup(int(map["size"][0]), int(map["size"][1]), map["grid"], tillable, ["soil", "fungal_bed", "rotten_log"])
	var crops := Crops.new()
	crops.setup(grid, Data.load_crops())
	for cell in [Vector2i(1,1), Vector2i(1,2), Vector2i(2,1), Vector2i(2,2), Vector2i(4,1)]:
		grid.till(cell)
	grid.prepare_medium(Vector2i(4,1), "fungal_bed")
	crops.plant(Vector2i(1,1), "jade_fruit_tree")
	crops.plant(Vector2i(4,1), "moon_cap")
	for day in range(10):
		crops.on_day_changed()
	var out := Snapshot.fresh()
	out["grid"] = grid.to_save()
	out["crops"] = crops.to_save()
	out["clock"] = {"total_days": 10, "ap": 12}
	out["inventory"]["moon_cap_flesh"] = 3
	out["economy"]["primeval_stones"] = 87
	out["economy"]["gu"]["satiety"] = 2
	out["economy"]["gu"]["feeding_count"] = 1
	out["economy"]["gu"]["materials_consumed"] = {"dew_leaf": 1}
	return out

static func run() -> Array[String]:
	var fails: Array[String] = []
	# Test-owned directory only, never the player's real slots or legacy save.
	var directory := "user://farm_phase06_slot_tests_%d" % Time.get_ticks_usec()
	var store := Slots.new(directory)
	var fresh := Snapshot.fresh()
	var world := populated()
	check(Snapshot.normalize(world)["ok"], "真实多格果树/菌床/成熟阶段完整快照校验", fails)
	check(store.list_slots().size() == 3 and store.list_slots().all(func(entry): return entry["status"] == "empty"), "空目录恰有三个空槽", fails)
	check(not store.commit(fresh)["ok"] and not store.create_slot(0, fresh)["ok"] and not store.read_slot(4)["ok"], "未绑定会话和非法槽拒绝写入", fails)
	check(store.create_slot(1, world)["ok"] and store.active_slot() == 1, "新建完整快照并绑定槽1", fails)
	var restored := store.read_slot(1)
	check(restored["ok"] and restored["snapshot"] == Snapshot.normalize(world)["snapshot"], "JSON往返保留土地/作物/介质/钱包/喂养记录", fails)
	var before := FileAccess.get_file_as_string(store.slot_path(1))
	check(not store.create_slot(1, fresh)["ok"] and FileAccess.get_file_as_string(store.slot_path(1)) == before, "未确认覆盖不修改原槽", fails)
	check(store.create_slot(2, fresh)["ok"] and store.create_slot(3, fresh)["ok"] and store.list_slots().all(func(entry): return entry["status"] == "ready"), "三槽可独立创建和列出日期/元石", fails)
	store.open_slot(1)
	var updated := world.duplicate(true)
	updated["economy"]["primeval_stones"] = 123
	check(store.commit(updated)["ok"] and store.read_slot(1)["snapshot"]["economy"]["primeval_stones"] == 123
		and store.read_slot(2)["snapshot"]["economy"]["primeval_stones"] == 60 and store.read_slot(3)["snapshot"]["economy"]["primeval_stones"] == 60,
		"会话提交只覆盖所属槽，另两槽不变", fails)
	var spoofed := fresh.duplicate(true)
	spoofed["slot_id"] = 2
	check(not store.commit(spoofed)["ok"] and store.active_slot() == 1, "快照伪造目标槽被拒", fails)
	check(not store.open_slot(4)["ok"] and store.active_slot() == 1, "加载失败保留原会话绑定", fails)
	var corrupt := world.duplicate(true)
	corrupt["inventory"]["dew_leaf"] = -1
	check(not store.commit(corrupt)["ok"] and store.read_slot(1)["snapshot"]["economy"]["primeval_stones"] == 123, "非法库存拒绝且旧档保留", fails)
	corrupt = world.duplicate(true)
	corrupt["crops"]["crops"][0]["uid"] = 1.5
	check(not Snapshot.normalize(corrupt)["ok"], "小数实例ID拒绝", fails)
	corrupt = world.duplicate(true)
	corrupt["grid"]["holders"]["crop:1"]["o"] = [19,13]
	check(not Snapshot.normalize(corrupt)["ok"], "占地越界与实例不一致拒绝", fails)
	corrupt = world.duplicate(true)
	corrupt["grid"]["cells"].append(corrupt["grid"]["cells"][0].duplicate())
	check(not Snapshot.normalize(corrupt)["ok"], "重复地格拒绝", fails)
	corrupt = world.duplicate(true)
	corrupt["grid"]["media"][0]["medium"] = "rotten_log"
	check(not Snapshot.normalize(corrupt)["ok"], "作物与介质不匹配拒绝", fails)
	corrupt = world.duplicate(true)
	corrupt["crops"]["crops"] = []
	check(not Snapshot.normalize(corrupt)["ok"], "土地引用丢失作物拒绝", fails)
	var future := world.duplicate(true)
	future["demo"] = {"tools": {"hoe": "advanced"}, "tutorial": 3, "report": {"plants": {"dew_grass": 9}}}
	check(store.commit(future)["ok"] and store.read_slot(1)["snapshot"]["demo"] == JSON.parse_string(JSON.stringify(future["demo"])),
		"后续工具/教学/回顾扩展字段无损保留", fails)
	store.commit(updated)
	var legacy := world.duplicate(true)
	legacy["schema"] = 2
	legacy.erase("economy")
	var legacy_path := directory + "/legacy.json"
	var file := FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var legacy_bytes := FileAccess.get_file_as_string(legacy_path)
	check(not store.import_legacy(2, legacy_path)["ok"] and store.import_legacy(2, legacy_path, true)["ok"]
		and store.read_slot(2)["snapshot"]["economy"]["primeval_stones"] == 60
		and store.read_slot(2)["snapshot"]["inventory"] == world["inventory"]
		and store.read_slot(2)["snapshot"]["demo_import"]["start_day"] == 10 and FileAccess.get_file_as_string(legacy_path) == legacy_bytes,
		"schema2导入确认、补默认经济、不赠物且保留源文件", fails)
	var legacy3_path := directory + "/legacy3.json"
	file = FileAccess.open(legacy3_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(world))
	file.close()
	check(store.import_legacy(3, legacy3_path, true)["ok"] and store.read_slot(3)["snapshot"]["economy"]["primeval_stones"] == 87,
		"schema3导入保留既有经济与喂养记录", fails)
	store.open_slot(2)
	var old_bytes := FileAccess.get_file_as_string(store.slot_path(2))
	DirAccess.remove_absolute(store.slot_path(2) + ".tmp")
	DirAccess.make_dir_recursive_absolute(store.slot_path(2) + ".tmp")
	check(not store.commit(fresh)["ok"] and FileAccess.get_file_as_string(store.slot_path(2)) == old_bytes,
		"临时文件无法写入时原档逐字节不变", fails)
	DirAccess.remove_absolute(store.slot_path(2) + ".tmp")
	var blocked := Slots.new(legacy_path)
	check(not blocked.create_slot(1, fresh)["ok"] and FileAccess.get_file_as_string(legacy_path) == legacy_bytes,
		"目录创建失败返回错误且不破坏源文件", fails)
	store.open_slot(1)
	var failed := FailingRename.new(directory)
	failed.open_slot(1)
	failed.fail_destination = store.slot_path(1)
	check(not failed.commit(fresh)["ok"] and store.read_slot(1)["snapshot"]["economy"]["primeval_stones"] == 123,
		"替换失败回退，原完整快照可读", fails)
	check(store.commit(updated)["ok"], "失败后可正常重试提交", fails)
	DirAccess.remove_absolute(store.slot_path(1))
	check(store.read_slot(1)["ok"] and store.read_slot(1).get("recovered", false), "中断替换只剩备份时可恢复读取", fails)
	store.commit(updated)
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.slot_path(3)))
	var original_envelope := envelope.duplicate(true)
	envelope["snapshot_json"] = String(envelope["snapshot_json"]) + " "
	file = FileAccess.open(store.slot_path(3), FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()
	check(not store.read_slot(3)["ok"], "快照内容校验和损坏被拒", fails)
	envelope = original_envelope
	envelope["slot_id"] = 1
	file = FileAccess.open(store.slot_path(3), FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()
	check(not store.read_slot(3)["ok"] and store.list_slots()[2]["status"] == "corrupt", "封装槽号错位明确显示损坏", fails)
	check(not store.delete_slot(1)["ok"] and store.occupied(1), "未确认删除不改存档", fails)
	check(store.delete_slot(1, true)["ok"] and not store.occupied(1) and store.active_slot() == 0
		and store.occupied(2) and store.occupied(3), "删除所属槽解除会话且其他槽保留", fails)
	for slot in [1,2,3]:
		store.delete_slot(slot, true)
	DirAccess.remove_absolute(legacy_path)
	DirAccess.remove_absolute(legacy3_path)
	DirAccess.remove_absolute(directory)
	return fails

static func run_scene(farm) -> Array[String]:
	var fails: Array[String] = []
	var before: Dictionary = farm.capture_snapshot()
	var broken := before.duplicate(true)
	broken["grid"]["cells"] = [{"x": 999, "y": 1, "s": "TILLED"}]
	check(not farm.apply_snapshot(broken) and farm.capture_snapshot() == before,
		"真实农场加载损坏土地时所有活状态零变更", fails)
	var extended := before.duplicate(true)
	extended["demo"] = {"tutorial": 4, "tools": {"hoe": "advanced"}, "statistics": {"harvests": 7}}
	check(farm.apply_snapshot(extended) and farm.capture_snapshot()["demo"] == extended["demo"],
		"农场快照应用与再捕获保留扩展状态", fails)
	farm.apply_snapshot(before)
	return fails
