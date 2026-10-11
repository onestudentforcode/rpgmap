extends RefCounted
## Schema 12: the P8 namespace on the validated V2 body plus per-habitat
## water-change day markers. No migration from V2 or early development saves.
const Common := preload("res://scripts/farming/v1/v1_snapshot.gd")
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")
const Data := preload("res://scripts/farming/p8/p8_data.gd")
const Husbandry := preload("res://scripts/farming/v2/v2_husbandry.gd")
const Ledger := preload("res://scripts/farming/v2/v2_resource_ledger.gd")
const Reports := preload("res://scripts/farming/v2/v2_reports.gd")
const Journal := preload("res://scripts/farming/v1/v1_journal.gd")
const SCHEMA := 12

static func fresh() -> Dictionary:
	var snapshot: Dictionary = Common.fresh(Data, SCHEMA)
	var config: Dictionary = Data.load_data()["config"]
	var opening := {}
	for item in config["start_inventory"]:
		if int(config["start_inventory"][item]) > 0:
			opening[item] = int(config["start_inventory"][item])
	snapshot["ledger"] = {"pending": {"day": 0, "opening": opening, "inflows": {}, "outflows": {}}, "history": []}
	snapshot["reports"] = Reports.fresh(0)
	snapshot["preferences"] = {"watched": []}
	snapshot["world"]["husbandry"] = {"habitats": [], "next_animal_uid": 1, "next_cycle_uid": 1}
	return snapshot

static func fail(reason: String) -> Dictionary:
	return Common.fail(reason)

static func normalize(value) -> Dictionary:
	if not value is Dictionary or value.get("product") != Data.load_data()["product"] or not Scalars.whole(value.get("schema"), SCHEMA, SCHEMA):
		return fail("不支持的P8快照版本，请重新开档")
	# Strip the derived sections, validate the shared body, then validate the
	# extras against the checked world, clock and inventory.
	var body: Dictionary = value.duplicate(true)
	var raw_ledger = body.get("ledger", null)
	var raw_reports = body.get("reports", null)
	var raw_preferences = body.get("preferences", null)
	var raw_husbandry = body.get("world", {}).get("husbandry", null) if body.get("world") is Dictionary else null
	if body.has("ledger"):
		body.erase("ledger")
	if body.has("reports"):
		body.erase("reports")
	if body.has("preferences"):
		body.erase("preferences")
	if body.get("world") is Dictionary and body["world"].has("husbandry"):
		body["world"].erase("husbandry")
	var checked := Common.normalize(body, Data, SCHEMA, false)
	if not checked["ok"]:
		return checked
	if raw_ledger == null or raw_husbandry == null or raw_reports == null or raw_preferences == null:
		return fail("P8快照缺少养殖、资源账、报表或偏好字段")
	var day := int(checked["snapshot"]["clock"]["total_days"])
	var husbandry := _normalize_husbandry(raw_husbandry, day, checked["snapshot"]["world"])
	if not husbandry["ok"]:
		return husbandry
	var ledger := Ledger.normalize(raw_ledger, day, checked["snapshot"]["inventory"], Data)
	if not ledger["ok"]:
		return ledger
	var bindings := Husbandry.validate_caretakers(checked["snapshot"]["workforce"], checked["snapshot"]["world"], Data)
	if not bindings["ok"]:
		return bindings
	var reports := Reports.normalize(raw_reports, day, Data)
	if not reports["ok"]:
		return reports
	if day >= 45:
		var recap: Dictionary = reports["reports"]["recap"]
		var journal: Dictionary = checked["snapshot"]["journal"]
		if recap["terms"] != reports["reports"]["terms"] or recap["cash"] != journal["end_cash"] or recap["inventory"] != journal["end_inventory"]:
			return fail("养殖回顾与首次45天冻结账不一致")
		var adults := 0
		for species in recap["animals"]:
			adults += int(recap["animals"][species]["adult"])
		if int(recap["ready"])+int(recap["running"]) > adults or recap["labour"] != Journal.totals(journal)["labour_spend"]:
			return fail("养殖期末权益或人工费与冻结账不一致")
	var items = Data.resources(Data.load_data())
	if not raw_preferences is Dictionary or not raw_preferences.get("watched") is Array or raw_preferences["watched"].size() > items.size():
		return fail("关注偏好字段非法")
	var watched := []
	for item in raw_preferences["watched"]:
		if not items.has(item) or item in watched:
			return fail("关注资源非法或重复")
		watched.append(item)
	checked["snapshot"]["world"]["husbandry"] = husbandry["husbandry"]
	checked["snapshot"]["ledger"] = ledger["ledger"]
	checked["snapshot"]["reports"] = reports["reports"]
	checked["snapshot"]["preferences"] = {"watched": watched}
	return checked

## P8 water habitats carry a per-habitat water-change day (-1 = never). Strip the
## markers, delegate the shared habitat shape to the V2 validator, then re-attach
## checked markers for water habitats only.
static func _normalize_husbandry(raw, day: int, world: Dictionary) -> Dictionary:
	var value = raw.duplicate(true) if raw is Dictionary else raw
	var markers := {}
	if value is Dictionary and value.get("habitats") is Array:
		for habitat in value["habitats"]:
			if habitat is Dictionary and habitat.has("water_change_day"):
				markers[int(habitat.get("facility_uid", 0))] = habitat["water_change_day"]
				habitat.erase("water_change_day")
	var checked: Dictionary = Husbandry.normalize(value, day, world, Data, Data.load_data()["husbandry"])
	if not checked["ok"]:
		return checked
	var facility_defs: Dictionary = Data.definitions("facilities")
	var facilities := {}
	for row in world["facilities"]:
		facilities[int(row["uid"])] = row
	for habitat in checked["husbandry"]["habitats"]:
		var uid := int(habitat["facility_uid"])
		var is_water: bool = habitat.has("water") and facilities.has(uid) and facility_defs[String(facilities[uid]["facility_id"])].get("terrain") == "water"
		if markers.has(uid):
			if not is_water or not Scalars.whole(markers[uid], -1, day):
				return fail("换水标记只能属于水场且日期合法")
			habitat["water_change_day"] = int(markers[uid])
		elif is_water:
			habitat["water_change_day"] = -1
	return {"ok": true, "husbandry": checked["husbandry"]}
