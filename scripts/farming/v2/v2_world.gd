extends "res://scripts/farming/v1/v1_world.gd"
## V2 production world: shared V1 model plus husbandry habitats and the resource ledger.
const V2Data := preload("res://scripts/farming/v2/v2_data.gd")
const V2Snapshot := preload("res://scripts/farming/v2/v2_snapshot.gd")
const Husbandry := preload("res://scripts/farming/v2/v2_husbandry.gd")
const ResourceLedger := preload("res://scripts/farming/v2/v2_resource_ledger.gd")
const Reports := preload("res://scripts/farming/v2/v2_reports.gd")

var husbandry
var ledger
var reports
## Per-slot UI preference state; persisted only by the daily autosave.
var preferences := {"watched": []}

func _init(slot_store = null) -> void:
	# Built before super: the base constructor applies a fresh snapshot through the
	# overrides below, and the modules only read shared members after that.
	husbandry = _make_husbandry()
	ledger = _make_ledger()
	reports = _make_reports()
	super(slot_store, _catalog(), _codec())

## Product seams so derived worlds can swap the namespace without copying _init.
func _catalog():
	return V2Data

func _codec():
	return V2Snapshot

func _make_husbandry():
	return Husbandry.new(self, V2Data.load_data())

func _make_ledger():
	return ResourceLedger.new(self)

func _make_reports():
	return Reports.new(self)

func _report_event(entry: Dictionary) -> void:
	reports.record(entry)

## Watching is a preference, not a game action: 0AP, 0 stones, order kept.
func toggle_watch(item_id: String) -> Dictionary:
	var checked := _can_act(0)
	if not checked["ok"]:
		return checked
	if not _items.has(item_id):
		return _error("未知资源")
	var watched: Array = preferences["watched"]
	if item_id in watched:
		watched.erase(item_id)
	else:
		watched.append(item_id)
	changed.emit()
	return {"ok": true}

func _facility_built(uid: int) -> void:
	# Complete derived state before the final AP can settle and save the day.
	if facility_defs[facilities[uid]["facility_id"]].get("kind") == "habitat":
		husbandry.ensure(uid)

func _facility_removed(uid: int) -> void:
	husbandry.forget(uid)
	for worker in workforce.state["workers"]:
		if int(worker.get("caretaker_facility", 0)) == uid:
			worker.erase("caretaker_facility")

func demolish_facility(uid: int) -> Dictionary:
	if facilities.has(uid) and facility_defs[facilities[uid]["facility_id"]].get("kind") == "habitat":
		var habitat: Dictionary = husbandry.habitat_of(uid)
		if not habitat.is_empty() and not habitat["individuals"].is_empty():
			return _error("非空设施需先清退全部动物才能拆除")
	return super.demolish_facility(uid)

func _record_flow(inflows: Dictionary, outflows: Dictionary, reason: String) -> void:
	ledger.record(inflows, outflows, reason)

## Test/preview scaffolding only: grants stock as an explicitly labelled inflow so
## the books stay balanced and day-to-day continuity holds. Gameplay code, workers
## and panels must never call this; no-injection replays never use it.
func grant_scaffold(items: Dictionary) -> void:
	for item in items:
		inventory.add(item, int(items[item]))
	ledger.record(items, {}, "脚手架注入")

func _settle_workforce(completed_day: int) -> void:
	workforce.settle(completed_day, husbandry)

func _settle_husbandry(completed_day: int) -> void:
	# Caretaker patrols run inside the completed service day, before growth and
	# cycles settle; a cycle finished by this settle waits for the next day.
	husbandry.settle(completed_day)
	reports.settle(completed_day)

func _settle_ledger(completed_day: int) -> String:
	return ledger.settle(completed_day, inventory.to_save())

func to_snapshot() -> Dictionary:
	var snapshot := super.to_snapshot()
	snapshot["ledger"] = ledger.to_save()
	snapshot["reports"] = reports.to_save()
	snapshot["preferences"] = preferences.duplicate(true)
	snapshot["world"]["husbandry"] = husbandry.to_save()
	return snapshot

func _snapshot_applied(snapshot: Dictionary) -> void:
	# Observers see the fully restored product, including watch preferences.
	husbandry.apply_save(snapshot["world"]["husbandry"])
	ledger.apply_save(snapshot["ledger"])
	reports.apply_save(snapshot["reports"])
	preferences = snapshot["preferences"].duplicate(true)
