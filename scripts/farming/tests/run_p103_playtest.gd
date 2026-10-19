extends SceneTree
## P10.3.f business replay: five short rule scenarios plus work/enclosure A/B
## pairs over 120 days. Ranch-only economies keep every run fast; evidence
## goes to .art-work/p103-playtest for the python auditor.
const World := preload("res://scripts/farming/p8/p8_world.gd")
const Codec := preload("res://scripts/farming/p8/p8_snapshot.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")

var checks := 0
var failures: Array = []
var audit_root := "res://.art-work/p103-playtest"
var receipts: FileAccess
var days_file: FileAccess
var route := ""
var routes_run := {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(route + " " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(audit_root))
	_scenario("nursery", _nursery)
	_scenario("mixed-maintenance", _mixed_maintenance)
	_scenario("shift-work", _shift_work)
	_scenario("shortage-fatigue", _shortage_fatigue)
	_scenario("enclosure-breeding", _enclosure_breeding)
	_route_ab("work-A", "work-B")
	_route_ab("enclosure-A", "enclosure-B")
	var summary := FileAccess.open(audit_root.path_join("summary.json"), FileAccess.WRITE)
	summary.store_string(JSON.stringify({"routes": routes_run, "failures": failures, "checks": checks}, "\t"))
	for failure in failures:
		printerr(failure)
	print("P103 PLAYTEST %s · %d checks" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _scenario(name: String, script: Callable) -> void:
	route = name
	routes_run[name] = {"kind": "scenario"}
	_open_files(name)
	var world := fixture({})
	script.call(world)
	_close_files()
	write_json("%s-final.json" % name, world.to_snapshot())

func _route_ab(a: String, b: String) -> void:
	_scenario(a, func(world): _business(world, a))
	_scenario(b, func(world): _business(world, b))

func fixture(extra: Dictionary) -> World:
	var world := World.new(Store.new(audit_root.path_join("%s-slots-%d-%d" % [route, OS.get_process_id(), Time.get_ticks_usec()])))
	world.start_new(1)
	var grant := {"raw_wood": 300, "raw_stone": 300, "wood_plank": 40,
		"mushroom": 400, "fodder_grass": 400, "grain": 200, "clean_water": 900,
		"land_feed": 100, "iron_ore": 120}
	for key in extra:
		grant[key] = extra[key]
	world.grant_scaffold(grant)
	world.primeval_stones += 3000
	world._cash("sales_revenue", 3000)
	world.research.state["completed"] = world.research.project_defs().keys()
	world.operation_recorded.connect(func(entry: Dictionary):
		receipts.store_line(JSON.stringify(entry)))
	return world

## Module layout (sources block x15..17 y8..10):
##   nursery     x0..4,  y10..12 (15 cells; pen + 3 troughs, small+medium beds)
##   work        x8..13, y10..11 (dispatch + two full 2x2 workyards)
##   maintenance x4..9,  y9      (2 troughs + small bed group)
##   pasture     x8..19, y12..13
##   enclosure   x10..14, y7..9  (pen + trough + beds + care table)
func build_module(world: World, with_enclosure: bool) -> Dictionary:
	for y in range(7, 14):
		for x in range(0, 20):
			var cell := Vector2i(x, y)
			if not world.source_at(cell).is_empty():
				continue
			var in_module: bool = (y in [7, 8, 9] and x >= 10 and x <= 14) or (y == 9 and x >= 4 and x <= 9) 				or (y in [10, 11, 12] and x <= 14) or (y in [12, 13] and x >= 8)
			if in_module:
				var result: Dictionary = world.rooms.set_floor(cell, "ordinary")
				check(result["ok"], "pave %d,%d" % [x, y])
	for spec in [["pen", 0, 10], ["feed_trough", 2, 10], ["feed_trough", 3, 10], ["feed_trough", 4, 10],
			["small_bed", 4, 11], ["medium_bed", 3, 11],
			["dispatch_station", 8, 10], ["rock_breaking_yard", 9, 10], ["rock_breaking_yard", 11, 10],
			["feed_trough", 4, 9], ["feed_trough", 5, 9], ["small_bed", 6, 9], ["medium_bed", 7, 9],
			["toy_station", 8, 12]]:
		check(world.build_facility(Vector2i(spec[1], spec[2]), String(spec[0]))["ok"], "build " + String(spec[0]))
	var zones := {}
	for group in ["nursery", "work", "maintenance", "pasture"]:
		var created: Dictionary = world.ranch.create_zone(group, _cells(world, group), group)
		check(created["ok"], "zone " + group)
		zones[group] = int(created.get("zone_uid", 0))
	if with_enclosure:
		for spec in [["pen", 10, 7], ["feed_trough", 12, 7], ["medium_bed", 13, 7], ["small_bed", 14, 7], ["care_table", 14, 8]]:
			check(world.build_facility(Vector2i(spec[1], spec[2]), String(spec[0]))["ok"], "build enclosure " + String(spec[0]))
		var created: Dictionary = world.ranch.create_zone("enclosure", _cells(world, "enclosure"), "enclosure")
		check(created["ok"], "enclosure zone")
		zones["enclosure"] = int(created.get("zone_uid", 0))
	var dispatch: int = world.facility_at(Vector2i(8, 10))["uid"]
	check(world.ranch.submit({"links": {zones["maintenance"]: dispatch, zones["pasture"]: dispatch}})["ok"], "links")
	if zones.has("enclosure"):
		check(world.ranch.submit({"birth_targets": {zones["enclosure"]: zones["nursery"]}})["ok"], "birth target")
	return zones

func _cells(world: World, group: String) -> Array:
	var layout := {
		"nursery": [Vector2i(0, 10), Vector2i(1, 10), Vector2i(2, 10), Vector2i(3, 10), Vector2i(4, 10),
			Vector2i(0, 11), Vector2i(1, 11), Vector2i(2, 11), Vector2i(3, 11), Vector2i(4, 11),
			Vector2i(0, 12), Vector2i(1, 12), Vector2i(2, 12), Vector2i(3, 12), Vector2i(4, 12)],
		"work": [Vector2i(8, 10), Vector2i(9, 10), Vector2i(10, 10), Vector2i(11, 10), Vector2i(12, 10), Vector2i(13, 10),
			Vector2i(8, 11), Vector2i(9, 11), Vector2i(10, 11), Vector2i(11, 11), Vector2i(12, 11), Vector2i(13, 11)],
		"maintenance": [Vector2i(4, 9), Vector2i(5, 9), Vector2i(6, 9), Vector2i(7, 9), Vector2i(8, 9), Vector2i(9, 9)],
		"pasture": [], "enclosure": [],
	}
	for x in range(8, 20):
		layout["pasture"].append(Vector2i(x, 12))
		layout["pasture"].append(Vector2i(x, 13))
	for y in range(7, 10):
		for x in range(10, 15):
			layout["enclosure"].append(Vector2i(x, y))
	var out := []
	for cell in layout[group]:
		out.append("%d,%d" % [cell.x, cell.y])
	return out

func settle_days(world: World, count: int) -> void:
	for _index in range(count):
		world.end_day()
		archive_day(world)

func archive_day(world: World) -> void:
	var animals := []
	for row in world.ranch.state["animals"]:
		animals.append({"uid": int(row["uid"]), "species": row["species_id"], "stage": row["stage"],
			"mode": row["mode"], "fatigue": int(row["fatigue"]), "ban_until": int(row["ban_until"]),
			"qualified_until": int(row["qualified_until"]), "growth": int(row["growth"]),
			"account": row["account"].duplicate(), "natural": row["natural"].duplicate(),
			"breed": row["breed"].duplicate(), "death_streak": int(row["death_streak"]),
			"pattern": row["pattern"], "zone_uid": int(row["zone_uid"])})
	var yards := {}
	for key in world.ranch.state["workyards"]:
		yards[key] = world.ranch.state["workyards"][key].duplicate(true)
	var stock := {}
	for item in ["mushroom", "fodder_grass", "clean_water", "iron_ore", "raw_stone", "gravel", "crushed_ore", "ore_concentrate", "steel_wool", "sheep_manure", "stone_powder", "tailings"]:
		stock[item] = world.inventory.count(item)
	days_file.store_line(JSON.stringify({"day": world.clock.total_days - 1, "animals": animals,
		"workyards": yards, "stock": stock, "deaths": 0}))

func claim_yards(world: World) -> void:
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == "rock_breaking_yard":
			world.ranch.claim_workyard(int(uid))

# --- short scenarios ---------------------------------------------------------

func _nursery(world: World) -> void:
	var zones := build_module(world, false)
	check(world.ranch.purchase(zones["nursery"], "rock_mole", 2)["ok"], "buy moles")
	check(world.ranch.purchase(zones["nursery"], "steel_sheep", 1)["ok"], "buy sheep")
	settle_days(world, 3)
	var adults: Array = world.ranch.state["animals"].filter(func(a): return String(a["stage"]) == "adult")
	check(adults.size() == 2, "moles adult after three care days")
	check(world.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == "steel_sheep")[0]["stage"] == "juvenile", "sheep still juvenile on day three")
	settle_days(world, 3)
	check(world.ranch.state["animals"].filter(func(a): return String(a["stage"]) == "adult").size() == 3, "sheep adult on day six")
	for row in world.ranch.state["animals"].duplicate():
		if String(row["stage"]) == "adult":
			check(world.ranch.submit({"assign": {int(row["uid"]): {"mode": "work", "zone_uid": zones["work"]}}})["ok"], "assign")
	settle_days(world, 2)
	check(world.ranch.state["animals"].filter(func(a): return String(a["mode"]) == "work").size() == 3, "assignments applied")
	check(world.ranch.state["animals"].all(func(a): return int(a["fatigue"]) <= 8), "fed animals stay below tired")

func _mixed_maintenance(world: World) -> void:
	var zones := build_module(world, false)
	check(world.ranch.purchase(zones["nursery"], "rock_mole", 4)["ok"], "four moles share one pool")
	check(world.ranch.purchase(zones["nursery"], "steel_sheep", 2)["ok"], "two sheep share the medium group")
	check(int(world.ranch._zone_usage(world.ranch.zone(zones["nursery"]))) == 4 + 4, "mixed usage counts one pool")
	settle_days(world, 5)
	var alive: Array = world.ranch.state["animals"]
	check(alive.size() == 6, "all six survive with four trough slots")
	for row in alive:
		check(int(row["account"]["fails"]) == 0, "no window fails with four slots for six animals")

func _shift_work(world: World) -> void:
	var zones := build_module(world, false)
	check(world.ranch.purchase(zones["nursery"], "rock_mole", 4)["ok"], "two shifts of moles")
	settle_days(world, 3)
	var index := 0
	for row in world.ranch.state["animals"].duplicate():
		var entry := {"mode": "work", "zone_uid": zones["work"]}
		if index >= 2:
			entry["pattern"] = "late"
		check(world.ranch.submit({"assign": {int(row["uid"]): entry}})["ok"], "assign with entry shift")
		index += 1
	# Switching an already-working animal standard->late must stay refused:
	# it would skip a due maintenance window.
	var first_worker: Dictionary = world.ranch.state["animals"][0]
	check(not world.ranch.submit({"patterns": {int(first_worker["uid"]): "late"}})["ok"], "standard to late refused for a working animal")
	for _day in range(4):
		settle_days(world, 1)
		claim_yards(world)
	for row in world.ranch.state["animals"]:
		check(int(row["account"]["w"]) == 4, "each shift still works four units a day")
		check(int(row["fatigue"]) <= 8, "staggered shifts keep fatigue low")
	check(world.inventory.count("gravel") + world.inventory.count("crushed_ore") >= 12, "staggered posts keep producing")

func _shortage_fatigue(world: World) -> void:
	var zones := build_module(world, false)
	check(world.ranch.purchase(zones["nursery"], "rock_mole", 2)["ok"], "buy moles")
	settle_days(world, 3)
	for row in world.ranch.state["animals"].duplicate():
		world.ranch.submit({"assign": {int(row["uid"]): {"mode": "work", "zone_uid": zones["work"]}}})
	settle_days(world, 2)
	var starve_day: int = world.clock.total_days
	var mushrooms: int = world.inventory.count("mushroom")
	world.inventory.remove("mushroom", mushrooms)
	world._record_flow({}, {"mushroom": mushrooms}, "断粮")
	settle_days(world, 1)
	for row in world.ranch.state["animals"]:
		check(int(row["account"]["fails"]) == 1 and int(row["ban_until"]) == starve_day * 8 + 2 + 8, "fixed eight-unit ban from the window end")
		check(int(row["fatigue"]) == 12, "failed window adds twelve fatigue")
	world.grant_scaffold({"mushroom": 60})
	settle_days(world, 2)
	for row in world.ranch.state["animals"]:
		check(int(row["ban_until"]) <= world.clock.total_days * 8, "ban expired after the fixed length")
		check(bool(row["served_once"]), "recovered window serves again")

func _enclosure_breeding(world: World) -> void:
	var zones := build_module(world, true)
	check(world.ranch.purchase(zones["nursery"], "steel_sheep", 2)["ok"], "breeder sheep")
	settle_days(world, 6)
	var beds: Array = world.ranch.free_bed_slots(world.ranch.zone(zones["enclosure"]), "medium")
	check(beds.size() >= 2, "enclosure beds free")
	var index := 0
	for row in world.ranch.state["animals"].duplicate():
		var bed: Dictionary = beds[index]
		check(world.ranch.submit({"assign": {int(row["uid"]): {"mode": "enclosure", "zone_uid": zones["enclosure"],
			"bed_uid": int(bed["uid"]), "bed_slot": int(bed["slot"])}}})["ok"], "assign enclosure")
		index += 1
	settle_days(world, 1)
	var iron: int = world.inventory.count("iron_ore")
	settle_days(world, 12)
	check(world.inventory.count("iron_ore") == iron, "enclosure breeders pay no body-material feed")
	var producing: Array = world.ranch.state["animals"].filter(func(a): return int(a["natural"]["units"]) > 0)
	check(producing.is_empty(), "no wool progress outside the intensive zone")
	var births: Array = world.ranch.state["animals"].filter(func(a): return bool(a["breed"]["pending"]))
	check(births.size() == 2, "breeding pending after seventy-two care units")
	var children: int = world.ranch.state["animals"].size()
	check(world.ranch.claim_births(zones["enclosure"])["ok"] and world.ranch.state["animals"].size() == children + 2, "births claimed into the nursery")
	check(world.ranch.state["births"].size() == 2, "one voucher per parent round")

# --- long A/B routes ---------------------------------------------------------

func _business(world: World, name: String) -> void:
	var enclosure_mode := name.begins_with("enclosure")
	var zones := build_module(world, enclosure_mode)
	if enclosure_mode:
		var species := "steel_sheep" if name == "enclosure-A" else "rock_mole"
		check(world.ranch.purchase(zones["nursery"], species, 2)["ok"], "buy breeders")
		settle_days(world, 7)
		var bed_type := "medium" if species == "steel_sheep" else "small"
		var beds: Array = world.ranch.free_bed_slots(world.ranch.zone(zones["enclosure"]), bed_type)
		var index := 0
		for row in world.ranch.state["animals"].duplicate():
			if String(row["stage"]) != "adult":
				continue
			var bed: Dictionary = beds[index % beds.size()]
			check(world.ranch.submit({"assign": {int(row["uid"]): {"mode": "enclosure", "zone_uid": zones["enclosure"],
				"bed_uid": int(bed["uid"]), "bed_slot": int(bed["slot"])}}})["ok"], "assign breeder")
			index += 1
	else:
		check(world.ranch.purchase(zones["nursery"], "rock_mole", 4)["ok"], "buy workers")
		settle_days(world, 3)
		var index := 0
		for row in world.ranch.state["animals"].duplicate():
			check(world.ranch.submit({"assign": {int(row["uid"]): {"mode": "work", "zone_uid": zones["work"]}}})["ok"], "assign worker")
			if name == "work-B" and index >= 2:
				world.ranch.submit({"patterns": {int(row["uid"]): "late"}})
			index += 1
	var day := 0
	while world.clock.total_days < 120:
		day = world.clock.total_days
		world.grant_scaffold({"mushroom": 10, "fodder_grass": 10, "clean_water": 30})
		if not enclosure_mode and day % 3 == 0:
			var yard: int = world.facility_at(Vector2i(9, 10))["uid"]
			var recipe := "break_stone" if world.inventory.count("gravel") < 20 else "break_ore"
			if String(world.ranch.workyard_state(yard)["recipe_id"]) != recipe:
				world.ranch.claim_workyard(yard)
				world.ranch.set_recipe(yard, recipe)
			world.ranch.claim_workyard(world.facility_at(Vector2i(11, 10))["uid"])
		if enclosure_mode and day % 5 == 0:
			if world.ranch.state["animals"].any(func(a): return bool(a["breed"]["pending"])):
				world.ranch.claim_births(zones["enclosure"])
		world.end_day()
		archive_day(world)
	# Route acceptance: no deaths, real output, bounded fatigue.
	check(world.ranch.state["animals"].size() >= (2 if enclosure_mode else 4), "route keeps its animals alive")
	for row in world.ranch.state["animals"]:
		check(int(row["death_streak"]) == 0, "no death streak at the horizon")
		check(int(row["fatigue"]) <= 23, "fatigue stays below strike")
	if enclosure_mode:
		check(world.ranch.state["births"].size() >= 3, "breeding route delivered births")
	else:
		check(world.inventory.count("gravel") + world.inventory.count("crushed_ore") >= 100, "work route produced minerals")
	routes_run[name]["animals"] = world.ranch.state["animals"].size()
	routes_run[name]["births"] = world.ranch.state["births"].size()
	routes_run[name]["gravel"] = world.inventory.count("gravel")
	routes_run[name]["crushed_ore"] = world.inventory.count("crushed_ore")

# --- evidence plumbing -------------------------------------------------------

func _open_files(name: String) -> void:
	receipts = FileAccess.open(audit_root.path_join(name + "-receipts.jsonl"), FileAccess.WRITE)
	days_file = FileAccess.open(audit_root.path_join(name + "-days.jsonl"), FileAccess.WRITE)

func _close_files() -> void:
	receipts.close()
	days_file.close()

func write_json(name: String, value) -> void:
	var file := FileAccess.open(audit_root.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "\t"))
	file.close()
