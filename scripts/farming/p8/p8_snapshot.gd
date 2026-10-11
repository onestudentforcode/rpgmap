extends RefCounted
## Schema 13 adds the P8 operations section (facility ownership, production
## strategies, reserves, backlog) and the P8 roster shape with farm duty.
## No migration from V2, schema-12 development or earlier saves.
const Common := preload("res://scripts/farming/v1/v1_snapshot.gd")
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")
const Data := preload("res://scripts/farming/p8/p8_data.gd")
const Husbandry := preload("res://scripts/farming/v2/v2_husbandry.gd")
const Ledger := preload("res://scripts/farming/v2/v2_resource_ledger.gd")
const Reports := preload("res://scripts/farming/v2/v2_reports.gd")
const Journal := preload("res://scripts/farming/v1/v1_journal.gd")
const P8Workforce := preload("res://scripts/farming/p8/p8_workforce.gd")
const P8Operations := preload("res://scripts/farming/p8/p8_operations.gd")
const P8Research := preload("res://scripts/farming/p8/p8_research.gd")
const P8Flowers := preload("res://scripts/farming/p8/p8_flowers.gd")
const SCHEMA := 15

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
	snapshot["world"]["p8"] = {"facilities": [], "production": [], "reserves": [], "waiting": []}
	snapshot["world"]["research"] = {"projects": [], "completed": [], "bench_days": []}
	snapshot["world"]["flowers"] = {"shares": [], "pollinated": []}
	var workers := []
	for worker in snapshot["workforce"]["workers"]:
		worker["farm_duty"] = {"enabled": false, "priority": "normal"}
		workers.append(worker)
	snapshot["workforce"]["workers"] = workers
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
	var world_section = body.get("world") if body.get("world") is Dictionary else {}
	var raw_husbandry = world_section.get("husbandry", null) if world_section is Dictionary else null
	var raw_operations = world_section.get("p8", null) if world_section is Dictionary else null
	var raw_research = world_section.get("research", null) if world_section is Dictionary else null
	var raw_flowers = world_section.get("flowers", null) if world_section is Dictionary else null
	if body.has("ledger"):
		body.erase("ledger")
	if body.has("reports"):
		body.erase("reports")
	if body.has("preferences"):
		body.erase("preferences")
	if world_section is Dictionary:
		if world_section.has("husbandry"):
			world_section.erase("husbandry")
		if world_section.has("p8"):
			world_section.erase("p8")
		if world_section.has("research"):
			world_section.erase("research")
		if world_section.has("flowers"):
			world_section.erase("flowers")
		body["world"] = world_section
	var checked := Common.normalize(body, Data, SCHEMA, false, P8Workforce)
	if not checked["ok"]:
		return checked
	if raw_ledger == null or raw_husbandry == null or raw_reports == null or raw_preferences == null or raw_operations == null or raw_research == null or raw_flowers == null:
		return fail("P8快照缺少养殖、运营、研究、花源、资源账、报表或偏好字段")
	var day := int(checked["snapshot"]["clock"]["total_days"])
	var workforce: Dictionary = checked["snapshot"]["workforce"]
	var husbandry := _normalize_husbandry(raw_husbandry, day, checked["snapshot"]["world"])
	if not husbandry["ok"]:
		return husbandry
	var ledger := Ledger.normalize(raw_ledger, day, checked["snapshot"]["inventory"], Data)
	if not ledger["ok"]:
		return ledger
	var research := P8Research.normalize(raw_research, day, checked["snapshot"]["world"], Data)
	if not research["ok"]:
		return research
	var flower_sources := P8Flowers.normalize(raw_flowers, day, checked["snapshot"]["world"], Data)
	if not flower_sources["ok"]:
		return flower_sources
	var operations := P8Operations.normalize(raw_operations, day, checked["snapshot"]["world"], workforce, Data, research["research"]["completed"])
	if not operations["ok"]:
		return operations
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
	checked["snapshot"]["world"]["p8"] = operations["operations"]
	checked["snapshot"]["world"]["research"] = research["research"]
	checked["snapshot"]["world"]["flowers"] = flower_sources["flowers"]
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
