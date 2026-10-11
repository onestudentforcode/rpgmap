extends RefCounted
## Schema 11 adds husbandry reports and per-slot watch preferences; no migration.
const Common := preload("res://scripts/farming/v1/v1_snapshot.gd")
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")
const Data := preload("res://scripts/farming/v2/v2_data.gd")
const Husbandry := preload("res://scripts/farming/v2/v2_husbandry.gd")
const Ledger := preload("res://scripts/farming/v2/v2_resource_ledger.gd")
const Reports := preload("res://scripts/farming/v2/v2_reports.gd")
const Journal := preload("res://scripts/farming/v1/v1_journal.gd")
const SCHEMA := 11

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
		return fail("不支持的V2快照版本，请重新开档")
	# Strip the V2-only sections, validate the shared body, then validate the extras
	# against the checked world, clock and inventory.
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
		return fail("V2快照缺少养殖、资源账、报表或偏好字段")
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
	var reports := Reports.normalize(raw_reports, day, Data)
	if not reports["ok"]:
		return reports
	if day >= 45:
		var recap: Dictionary = reports["reports"]["recap"]
		var journal: Dictionary = checked["snapshot"]["journal"]
		if recap["terms"] != reports["reports"]["terms"] or recap["cash"] != journal["end_cash"] or recap["inventory"] != journal["end_inventory"]:
			return fail("养殖回顾与首次45天冻结账不一致")
		var adults := 0
		for species in recap["animals"]: adults += int(recap["animals"][species]["adult"])
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
