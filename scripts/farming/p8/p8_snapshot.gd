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
const P8Devices := preload("res://scripts/farming/p8/p8_devices.gd")
const Land := preload("res://scripts/farming/p8/p8_land.gd")
const Logistics := preload("res://scripts/farming/p8/p10_logistics.gd")
const Rooms := preload("res://scripts/farming/p8/p102_rooms.gd")
const Ranch := preload("res://scripts/farming/p8/p103_ranch.gd")
const SCHEMA := 22

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
	snapshot["world"]["land"] = {"purchased": []}
	snapshot["world"]["p8"] = {"facilities": [], "production": [], "reserves": [], "waiting": []}
	snapshot["world"]["research"] = {"projects": [], "completed": [], "bench_days": []}
	snapshot["world"]["flowers"] = {"shares": [], "pollinated": []}
	snapshot["world"]["devices"] = {"devices": [], "active_day": -1, "active_lamps": []}
	snapshot["world"]["logistics"] = Logistics.fresh()
	snapshot["world"]["agriculture"] = Logistics.fresh_agriculture()
	snapshot["world"]["rooms"] = Rooms.fresh()
	snapshot["world"]["rooms"]["random_seed"] = randi_range(1,2147483647)
	snapshot["world"]["ranch"] = Ranch.fresh()
	var workers := []
	for worker in snapshot["workforce"]["workers"]:
		worker["farm_duty"] = {"enabled": false, "priority": "normal"}
		workers.append(worker)
	snapshot["workforce"]["workers"] = workers
	return snapshot

static func fail(reason: String) -> Dictionary:
	return Common.fail(reason)

static func normalize(value) -> Dictionary:
	# P10.2 deliberately starts a fresh schema: no old-save migration.
	if not value is Dictionary or value.get("product") != Data.load_data()["product"] or not Scalars.whole(value.get("schema"), SCHEMA, SCHEMA):
		return fail("不支持的P8快照版本，请重新开档")
	# Strip the derived sections, validate the shared body, then validate the
	# extras against the checked world, clock and inventory.
	var body: Dictionary = value.duplicate(true)
	var raw_ledger = body.get("ledger", null)
	var raw_reports = body.get("reports", null)
	var raw_preferences = body.get("preferences", null)
	var world_section = body.get("world") if body.get("world") is Dictionary else {}
	var raw_land = world_section.get("land", null)
	var raw_husbandry = world_section.get("husbandry", null) if world_section is Dictionary else null
	var raw_operations = world_section.get("p8", null) if world_section is Dictionary else null
	var raw_research = world_section.get("research", null) if world_section is Dictionary else null
	var raw_flowers = world_section.get("flowers", null) if world_section is Dictionary else null
	var raw_devices = world_section.get("devices", null) if world_section is Dictionary else null
	var raw_logistics = world_section.get("logistics",null)
	var raw_agriculture = world_section.get("agriculture",null)
	var raw_rooms = world_section.get("rooms",null)
	var raw_ranch = world_section.get("ranch",null) if world_section is Dictionary else null
	if body.has("ledger"):
		body.erase("ledger")
	if body.has("reports"):
		body.erase("reports")
	if body.has("preferences"):
		body.erase("preferences")
	if world_section is Dictionary:
		world_section.erase("land")
		world_section.erase("logistics")
		world_section.erase("agriculture")
		world_section.erase("rooms")
		world_section.erase("ranch")
		if world_section.has("husbandry"):
			world_section.erase("husbandry")
		if world_section.has("p8"):
			world_section.erase("p8")
		if world_section.has("research"):
			world_section.erase("research")
		if world_section.has("flowers"):
			world_section.erase("flowers")
		if world_section.has("devices"):
			world_section.erase("devices")
		body["world"] = world_section
	var checked := Common.normalize(body, Data, SCHEMA, false, P8Workforce)
	if not checked["ok"]:
		return checked
	if raw_ledger == null or raw_husbandry == null or raw_reports == null or raw_preferences == null or raw_operations == null or raw_research == null or raw_flowers == null or raw_devices == null or raw_ranch == null:
		return fail("P8快照缺少养殖、运营、研究、花源、资源账、报表、偏好或畜牧分区字段")
	var ownership := Land.normalize(raw_land, checked["snapshot"]["world"], checked["snapshot"]["workforce"], Data)
	if not ownership["ok"]: return ownership
	checked["snapshot"]["world"]["land"] = ownership["land"]
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
	var species_defs := Data.definitions("livestock")
	for habitat in husbandry["husbandry"]["habitats"]:
		var gate := String(species_defs[String(habitat["species_id"])].get("research", ""))
		if not habitat["individuals"].is_empty() and not gate.is_empty() and not research["research"]["completed"].has(gate):
			return fail("已购入物种缺少前置研究：" + gate)
	var flower_sources := P8Flowers.normalize(raw_flowers, day, checked["snapshot"]["world"], Data)
	if not flower_sources["ok"]:
		return flower_sources
	var device_state := P8Devices.normalize(raw_devices, day, checked["snapshot"]["world"], Data)
	if not device_state["ok"]:
		return device_state
	var operations := P8Operations.normalize(raw_operations, day, checked["snapshot"]["world"], workforce, Data, research["research"]["completed"], husbandry["husbandry"])
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
	checked["snapshot"]["world"]["devices"] = device_state["devices"]
	var logistics_value = raw_logistics
	var agriculture_value = raw_agriculture
	if not agriculture_value is Dictionary or agriculture_value.get("legacy_until")!=-1: return fail("新版本不接受旧农业切换状态")
	var logistics := Logistics.normalize(logistics_value,day,checked["snapshot"],Data)
	if not logistics["ok"]: return logistics
	checked["snapshot"]["world"]["logistics"] = logistics["logistics"]
	var agriculture := Logistics.normalize_agriculture(agriculture_value, day, int(logistics["logistics"]["active_day"]), checked["snapshot"]["world"], Data)
	if not agriculture["ok"]: return agriculture
	checked["snapshot"]["world"]["agriculture"] = agriculture["agriculture"]
	var rooms := Rooms.normalize(raw_rooms,checked["snapshot"],Data)
	if not rooms["ok"]: return rooms
	checked["snapshot"]["world"]["rooms"] = rooms["rooms"]
	var ranch := Ranch.normalize(raw_ranch,checked["snapshot"],Data)
	if not ranch["ok"]: return ranch
	checked["snapshot"]["world"]["ranch"] = ranch["ranch"]
	var farm_cells := {}
	for field in rooms["rooms"]["fields"]:
		for text in field["cells"]: farm_cells[text] = true
	for zone in ranch["ranch"]["zones"]:
		for text in zone["cells"]:
			if farm_cells.has(text): return fail("农业与畜牧房间地格重叠")
	# A locked research plan must still point at its one original host instance.
	for project in research["research"]["projects"]:
		var id := String(project["gu"]["instance_id"])
		if id.is_empty(): continue
		var found := false
		for row in logistics["logistics"]["instances"]:
			if row["instance_id"] == id and int(row["host_uid"]) == int(project["bench_uid"]):
				for d in Data.load_data()["logistics"]["definitions"]:
					if d["id"] != row["definition_id"]: continue
					var expected := {"instance_id":id,"flat":int(d["value"]) if d["effect"] == "research_flat" else 0,"speed":int(d["value"])/100 if d["effect"] == "research_speed" else 1,"materials":int(d.get("material_percent",100))}
					found = project["gu"] == expected
		if not found: return fail("研究方案与锁定蛊实例不符")
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
	# Pen and rock workyard are P10.3 structural ranch facilities: no habitat
	# record is created or required for them any more.
	var filtered_world := world.duplicate(true)
	filtered_world["facilities"] = filtered_world["facilities"].filter(
		func(row): return not String(row["facility_id"]) in ["pen", "rock_workyard"])
	var checked: Dictionary = Husbandry.normalize(value, day, filtered_world, Data, Data.load_data()["husbandry"])
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
