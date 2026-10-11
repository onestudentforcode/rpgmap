extends RefCounted
## Schema 10 adds exclusive facility caretakers; schemas 9 and older are not migrated.
const Common := preload("res://scripts/farming/v1/v1_snapshot.gd")
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")
const Data := preload("res://scripts/farming/v2/v2_data.gd")
const Husbandry := preload("res://scripts/farming/v2/v2_husbandry.gd")
const Ledger := preload("res://scripts/farming/v2/v2_resource_ledger.gd")
const SCHEMA := 10

static func fresh() -> Dictionary:
	var snapshot: Dictionary = Common.fresh(Data, SCHEMA)
	var config: Dictionary = Data.load_data()["config"]
	var opening := {}
	for item in config["start_inventory"]:
		if int(config["start_inventory"][item]) > 0:
			opening[item] = int(config["start_inventory"][item])
	snapshot["ledger"] = {"pending": {"day": 0, "opening": opening, "inflows": {}, "outflows": {}}, "history": []}
	snapshot["world"]["husbandry"] = {"habitats": [], "next_animal_uid": 1, "next_cycle_uid": 1}
	return snapshot

static func fail(reason: String) -> Dictionary:
	return Common.fail(reason)

static func normalize(value) -> Dictionary:
	if not value is Dictionary or value.get("product") != Data.load_data()["product"] or not Scalars.whole(value.get("schema"), SCHEMA, SCHEMA):
		return fail("不支持的V2快照版本，请重新开档")
	# Strip the V2-only sections, validate the shared body, then validate the extras
	# against the checked world, clock and inventory.
	var body: Dictionary = value.duplicate(true)
	var raw_ledger = body.get("ledger", null)
	var raw_husbandry = body.get("world", {}).get("husbandry", null) if body.get("world") is Dictionary else null
	if body.has("ledger"):
		body.erase("ledger")
	if body["world"] is Dictionary and body["world"].has("husbandry"):
		body["world"].erase("husbandry")
	var checked := Common.normalize(body, Data, SCHEMA, false)
	if not checked["ok"]:
		return checked
	if raw_ledger == null or raw_husbandry == null:
		return fail("V2快照缺少养殖或资源账字段")
	var day := int(checked["snapshot"]["clock"]["total_days"])
	var husbandry := Husbandry.normalize(raw_husbandry, day, checked["snapshot"]["world"], Data, Data.load_data()["husbandry"])
	if not husbandry["ok"]:
		return husbandry
	var ledger := Ledger.normalize(raw_ledger, day, checked["snapshot"]["inventory"], Data)
	if not ledger["ok"]:
		return ledger
	var bindings := Husbandry.validate_caretakers(checked["snapshot"]["workforce"], checked["snapshot"]["world"], Data)
	if not bindings["ok"]:
		return bindings
	checked["snapshot"]["world"]["husbandry"] = husbandry["husbandry"]
	checked["snapshot"]["ledger"] = ledger["ledger"]
	return checked
