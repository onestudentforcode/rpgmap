extends RefCounted
## Three slots; commit has no slot parameter and writes only the bound session.
const Snapshot := preload("res://scripts/farming/core/storage/farm_snapshot.gd")
const MAX_FILE_BYTES := 4194304
var _directory: String
var _active_slot := 0

func _init(directory: String = "user://farm_demo_slots") -> void:
	_directory = directory.trim_suffix("/")

func active_slot() -> int:
	return _active_slot

func close_session() -> void:
	_active_slot = 0

func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [_directory, slot] if slot in [1,2,3] else ""

func _error(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

func occupied(slot: int) -> bool:
	var path := slot_path(slot)
	return not path.is_empty() and (FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"))

func list_slots() -> Array:
	var out := []
	for slot in [1,2,3]:
		var loaded := read_slot(slot)
		var info := {"slot_id": slot, "status": "empty"}
		if occupied(slot):
			info["status"] = "ready" if loaded["ok"] else "corrupt"
			if loaded["ok"]:
				info["total_days"] = loaded["snapshot"]["clock"]["total_days"]
				info["primeval_stones"] = loaded["snapshot"]["economy"]["primeval_stones"]
				info["saved_at"] = loaded["saved_at"]
				info["recovered"] = loaded.get("recovered", false)
			else:
				info["reason"] = loaded["reason"]
		out.append(info)
	return out

func read_slot(slot: int) -> Dictionary:
	var path := slot_path(slot)
	if path.is_empty():
		return _error("只能选择槽1～3")
	if FileAccess.file_exists(path):
		return _read_file(path, slot)
	# A crash between the two renames leaves the last valid snapshot as backup.
	if FileAccess.file_exists(path + ".bak"):
		var backup := _read_file(path + ".bak", slot)
		if backup["ok"]:
			backup["recovered"] = true
		return backup
	return _error("存档槽为空")

func open_slot(slot: int) -> Dictionary:
	var result := read_slot(slot)
	if result["ok"]:
		_active_slot = slot
	return result

func create_slot(slot: int, snapshot: Dictionary, overwrite_confirmed: bool = false) -> Dictionary:
	if slot_path(slot).is_empty():
		return _error("只能选择槽1～3")
	if occupied(slot) and not overwrite_confirmed:
		return _error("覆盖现有存档需要明确确认")
	var result := _write(slot, snapshot)
	if result["ok"]:
		_active_slot = slot
	return result

func commit(snapshot: Dictionary) -> Dictionary:
	if _active_slot == 0:
		return _error("尚未绑定存档槽")
	return _write(_active_slot, snapshot)

func import_legacy(slot: int, legacy_path: String, overwrite_confirmed: bool = false) -> Dictionary:
	var raw := _read_json(legacy_path)
	if not raw["ok"]:
		return raw
	var checked := Snapshot.normalize(raw["data"])
	if not checked["ok"]:
		return checked
	var snapshot: Dictionary = checked["snapshot"]
	# Future statistics starts at import time; never invent past player actions.
	snapshot["demo_import"] = {"start_day": snapshot["clock"]["total_days"], "source_schema": int(raw["data"]["schema"])}
	return create_slot(slot, snapshot, overwrite_confirmed)

func delete_slot(slot: int, confirmed: bool = false) -> Dictionary:
	var path := slot_path(slot)
	if path.is_empty():
		return _error("只能选择槽1～3")
	if not confirmed:
		return _error("删除存档需要明确确认")
	# Explicit fixed filenames only; directory and other slots are untouched.
	for suffix in ["", ".bak", ".tmp"]:
		var target: String = path + suffix
		if FileAccess.file_exists(target) and DirAccess.remove_absolute(target) != OK:
			return _error("无法删除存档文件")
	if _active_slot == slot:
		close_session()
	return {"ok": true}

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error("无法读取存档文件")
	if file.get_length() > MAX_FILE_BYTES:
		return _error("存档文件过大")
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _error("存档JSON损坏")
	return {"ok": true, "data": parsed}

func _read_file(path: String, slot: int) -> Dictionary:
	var raw := _read_json(path)
	if not raw["ok"]:
		return raw
	var data: Dictionary = raw["data"]
	if data.get("schema") != 1 or data.get("slot_id") != slot or not data.get("snapshot_json") is String \
		or not Snapshot.whole(data.get("saved_at")) or not data.get("checksum") is String:
		return _error("槽位或存档封装非法")
	if data["snapshot_json"].sha256_text() != data["checksum"]:
		return _error("存档校验失败")
	var checked := Snapshot.normalize(JSON.parse_string(data["snapshot_json"]))
	if checked["ok"]:
		checked["slot_id"] = slot
		checked["saved_at"] = int(data["saved_at"])
	return checked

func _write(slot: int, snapshot: Dictionary) -> Dictionary:
	var checked := Snapshot.normalize(snapshot)
	if not checked["ok"]:
		return checked
	if snapshot.has("slot_id") and snapshot["slot_id"] != slot:
		return _error("快照不属于当前槽")
	var path := slot_path(slot)
	var content := JSON.stringify(checked["snapshot"])
	var envelope := {"schema": 1, "slot_id": slot, "saved_at": int(Time.get_unix_time_from_system()),
		"snapshot_json": content, "checksum": content.sha256_text()}
	if DirAccess.make_dir_recursive_absolute(_directory) != OK:
		return _error("无法创建存档目录")
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return _error("无法写入临时存档")
	file.store_string(JSON.stringify(envelope, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or not _read_file(path + ".tmp", slot)["ok"]:
		return _error("临时存档写入或校验失败")
	var backup := path + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup) != OK:
			return _error("无法更新存档备份")
		if _rename(path, backup) != OK:
			return _error("无法保留上一份存档")
	if _rename(path + ".tmp", path) != OK:
		if not FileAccess.file_exists(path) and FileAccess.file_exists(backup):
			_rename(backup, path)
		return _error("无法替换正式存档，上一份快照保留")
	return {"ok": true, "slot_id": slot, "snapshot": checked["snapshot"], "saved_at": envelope["saved_at"]}

func _rename(from: String, to: String) -> Error:
	return DirAccess.rename_absolute(from, to)
