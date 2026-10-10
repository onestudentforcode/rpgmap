extends SceneTree
const Data := preload("res://scripts/farming/v1/v1_data.gd")
const Snapshot := preload("res://scripts/farming/v1/v1_snapshot.gd")
const Store := preload("res://scripts/farming/v1/v1_slot_store.gd")
const OldSnapshot := preload("res://scripts/farming/core/storage/farm_snapshot.gd")
var failures: Array[String] = []
var checks := 0

class FailedRenameStore extends "res://scripts/farming/v1/v1_slot_store.gd":
	func _rename(from: String, to: String) -> Error:
		if from.ends_with(".tmp"):
			return ERR_CANT_CREATE
		return super._rename(from, to)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _initialize() -> void:
	var fresh := Snapshot.fresh()
	check(fresh["economy"] == {"primeval_stones": 60}, "initial currency, no test Gu")
	check(fresh["inventory"].size() == 4 and fresh["inventory"].get("golden_wheat_seed") == 8, "four V1 seeds")
	check(Snapshot.normalize(fresh)["ok"], "fresh snapshot valid")
	check(not Snapshot.normalize(OldSnapshot.fresh())["ok"], "reject V0 snapshot")
	check(not OldSnapshot.normalize(fresh)["ok"], "V0 rejects V1 snapshot")
	check(Store.new().slot_path(1) == "user://farm_demo_v1_slots/slot_1.json", "independent directory")
	var items := Data.resources(Data.load_data())
	var foods := {"wood": "grain", "fire": "resin", "earth": "humus", "water": "clean_water", "gold": "iron_ingot"}
	# Independently expected necessary quantities at ranks 1, 3, 5.
	var quantities := {"wood": [3,9,15], "fire": [2,5,8], "earth": [3,9,15], "water": [12,36,60], "gold": [2,4,6]}
	for path in foods:
		for idx in range(3):
			var rank: int = [1,3,5][idx]
			var quote := Data.supply_quote(path, rank, foods[path])
			check(quote["ok"] and quote["quantity"] == quantities[path][idx], "necessary quantity %s rank%d" % [path, rank])
			check(quote["provided"] >= 12 * rank and quote["provided"] - int(items[foods[path]]["supply_value"]) < 12 * rank, "minimal quantity %s rank%d" % [path, rank])
	var rounding := Data.supply_quote("earth", 1, "humus")
	check(rounding["base"] == 12 and rounding["premium"] == 1 and rounding["payout"] == 13, "integer premium")
	for request in [["wood", 1, "raw_wood"], ["fire", 1, "grain"], ["wood", 0, "grain"], ["wood", 6, "grain"], ["unknown", 1, "grain"]]:
		check(not Data.supply_quote(request[0], request[1], request[2])["ok"], "reject bad food/path/rank")
	check(Data.unlocked_rank(299) == 2 and Data.unlocked_rank(300) == 3 and Data.unlocked_rank(1200) == 5, "gross revenue thresholds")
	for iid in ["grain", "clean_water"]:
		for rank in range(1,6):
			var quote := Data.supply_quote(items[iid]["element"], rank, iid)
			check(quote["quantity"] * items[iid]["buy_price"] > quote["payout"], "no buy/deliver profit")
	for invalid in [true, -1, 1.5, "2"]:
		var bad := fresh.duplicate(true)
		bad["economy"]["primeval_stones"] = invalid
		check(not Snapshot.normalize(bad)["ok"], "invalid money rejected")
	var bad := fresh.duplicate(true)
	bad["inventory"]["legacy_seed"] = 1
	check(not Snapshot.normalize(bad)["ok"], "unknown inventory rejected")
	bad = fresh.duplicate(true)
	bad["orders"] = []
	check(not Snapshot.normalize(bad)["ok"], "unsupported future fields rejected instead of discarded")
	var normalized := Snapshot.normalize(JSON.parse_string(JSON.stringify(fresh)))
	check(normalized["ok"] and normalized["snapshot"]["economy"]["primeval_stones"] is int, "JSON numbers normalized")
	var directory := "user://test_v1_foundation_%d" % Time.get_ticks_usec()
	var store := Store.new(directory)
	check(store.list_slots().size() == 3 and not store.occupied(1), "three empty slots")
	check(not store.commit(fresh)["ok"], "unbound commit rejected")
	for slot in [1,2,3]:
		check(store.create_slot(slot, fresh)["ok"], "create slot%d" % slot)
	var prior := FileAccess.get_file_as_bytes(store.slot_path(3))
	check(not store.create_slot(3, fresh)["ok"] and FileAccess.get_file_as_bytes(store.slot_path(3)) == prior, "no accidental overwrite")
	store.open_slot(1)
	var changed := fresh.duplicate(true)
	changed["economy"]["primeval_stones"] = 77
	check(store.commit(changed)["ok"], "bound commit")
	check(store.read_slot(1)["snapshot"]["economy"]["primeval_stones"] == 77 and store.read_slot(2)["snapshot"] == normalized["snapshot"], "slot isolation")
	changed["slot_id"] = 2
	check(not store.commit(changed)["ok"], "cross slot commit rejected")
	check(not store.create_slot(1, OldSnapshot.fresh(), true)["ok"] and store.read_slot(1)["snapshot"]["economy"]["primeval_stones"] == 77, "V0 cannot replace V1")
	check(not store.import_legacy(1, "user://missing_legacy.json", true)["ok"], "no legacy migration")
	var failing := FailedRenameStore.new(directory)
	failing.open_slot(1)
	check(not failing.commit(fresh)["ok"] and store.read_slot(1)["snapshot"]["economy"]["primeval_stones"] == 77, "failed rename preserves last snapshot")
	DirAccess.rename_absolute(store.slot_path(1), store.slot_path(1) + ".bak")
	check(store.read_slot(1).get("recovered", false), "crash backup recovery")
	var envelope = JSON.parse_string(FileAccess.get_file_as_string(store.slot_path(2)))
	envelope["snapshot_json"] += " "
	var file := FileAccess.open(store.slot_path(2), FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()
	check(not store.read_slot(2)["ok"], "checksum tamper rejected")
	for slot in [1,2,3]:
		check(store.delete_slot(slot, true)["ok"], "cleanup owned slot%d" % slot)
	DirAccess.remove_absolute(directory)
	for failure in failures:
		printerr(failure)
	print("V1 FOUNDATION TEST %s: %d checks" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
