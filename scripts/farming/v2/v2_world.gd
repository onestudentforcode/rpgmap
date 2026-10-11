extends "res://scripts/farming/v1/v1_world.gd"
## V2 production world: shared V1 model plus husbandry habitats and the resource ledger.
const V2Data := preload("res://scripts/farming/v2/v2_data.gd")
const V2Snapshot := preload("res://scripts/farming/v2/v2_snapshot.gd")
const Husbandry := preload("res://scripts/farming/v2/v2_husbandry.gd")
const ResourceLedger := preload("res://scripts/farming/v2/v2_resource_ledger.gd")

var husbandry
var ledger

func _init(slot_store = null) -> void:
	# Built before super: the base constructor applies a fresh snapshot through the
	# overrides below, and the modules only read shared members after that.
	husbandry = Husbandry.new(self, V2Data.load_data())
	ledger = ResourceLedger.new(self)
	super(slot_store, V2Data, V2Snapshot)

func build_facility(cell: Vector2i, facility_id: String) -> Dictionary:
	var result := super(cell, facility_id)
	if result.get("ok", false) and facility_defs[facility_id].get("kind") == "habitat":
		husbandry.ensure(int(result["facility_uid"]))
		changed.emit()
	return result

func demolish_facility(uid: int) -> Dictionary:
	if facilities.has(uid) and facility_defs[facilities[uid]["facility_id"]].get("kind") == "habitat":
		var habitat: Dictionary = husbandry.habitat_of(uid)
		if not habitat.is_empty() and not habitat["individuals"].is_empty():
			return _error("非空设施需先清退全部动物才能拆除")
	var result := super.demolish_facility(uid)
	if result.get("ok", false):
		husbandry.forget(uid)
	return result

func _record_flow(inflows: Dictionary, outflows: Dictionary, reason: String) -> void:
	ledger.record(inflows, outflows, reason)

## Test/preview scaffolding only: grants stock and widens today's opening balance
## so fixtures can prepare states without faking gameplay flows. Gameplay code,
## workers and panels must never call this.
func grant_scaffold(items: Dictionary) -> void:
	for item in items:
		inventory.add(item, int(items[item]))
	var pending: Dictionary = ledger.state["pending"]
	for item in items:
		var widened := int(pending["opening"].get(item, 0)) + int(items[item])
		if widened > 0:
			pending["opening"][item] = widened
		elif pending["opening"].has(item):
			pending["opening"].erase(item)

func _settle_husbandry(completed_day: int) -> void:
	husbandry.settle(completed_day)

func _settle_ledger(completed_day: int) -> String:
	return ledger.settle(completed_day, inventory.to_save())

func to_snapshot() -> Dictionary:
	var snapshot := super.to_snapshot()
	snapshot["ledger"] = ledger.to_save()
	snapshot["world"]["husbandry"] = husbandry.to_save()
	return snapshot

func apply_snapshot(value) -> Dictionary:
	var checked: Dictionary = snapshot_type.normalize(value)
	if not checked["ok"]:
		return checked
	var result := super.apply_snapshot(value)
	if not result["ok"]:
		return result
	husbandry.apply_save(checked["snapshot"]["world"]["husbandry"])
	ledger.apply_save(checked["snapshot"]["ledger"])
	return result
