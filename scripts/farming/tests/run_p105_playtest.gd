extends SceneTree
## P10.5 module replay: six short rule scenarios on real ledgers, none longer
## than thirty days. Fixed scaffolds are declared per scenario; this is rule
## evidence, not a profitability claim (costs live in the standard-cost tables).
const World := preload("res://scripts/farming/p8/p8_world.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")

var audit_root := "res://.art-work/p105-playtest"
var receipts: FileAccess
var days_file: FileAccess
var route := ""
var routes_run := {}
var checks := 0
var failures := []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(route + " " + label)
		printerr(route + " " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(audit_root))
	_scenario("mode-migration", _mode_migration)
	_scenario("intensive-fatigue", _intensive_fatigue)
	_scenario("silkworm-chain", _silkworm_chain)
	_scenario("liquid-outlet", _liquid_outlet)
	_scenario("carbon-compost", _carbon_compost)
	_scenario("mineral-shell", _mineral_shell)
	var summary := FileAccess.open(audit_root.path_join("summary.json"), FileAccess.WRITE)
	summary.store_string(JSON.stringify({"routes": routes_run, "failures": failures, "checks": checks}, "\t"))
	summary.close()
	for failure in failures:
		printerr(failure)
	print("P105 PLAYTEST %s · %d checks" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _scenario(name: String, script: Callable) -> void:
	route = name
	routes_run[name] = {"kind": "scenario"}
	_open_files(name)
	var world := fixture()
	script.call(world)
	_close_files()
	write_json("%s-final.json" % name, world.to_snapshot())

func fixture() -> World:
	var world := World.new(Store.new(audit_root.path_join("%s-slots-%d" % [route, Time.get_ticks_usec()])))
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 300, "raw_stone": 300, "wood_plank": 60, "twig": 120,
		"mushroom": 300, "fodder_grass": 400, "grain": 100, "clean_water": 900,
		"iron_ore": 120, "mineral_feed": 100, "algae_feed": 60, "straw": 60,
		"wood_chip": 60, "sludge": 40, "oil_cake": 20, "stone_powder": 40,
		"gravel": 40, "mulberry_leaf": 60, "charcoal": 20, "humus": 60})
	world.primeval_stones += 4000
	world._cash("sales_revenue", 4000)
	world.research.state["completed"] = world.research.project_defs().keys()
	world.operation_recorded.connect(func(entry: Dictionary):
		receipts.store_line(JSON.stringify(entry)))
	return world

## Shared module (fresh per scenario; sources x15..17 y8..10, wall y=6):
##   nursery   x0..3, y10..12  pen + 2 troughs + small/medium bed
##   intensive x0..7, y7..8    pen + trough + small/medium bed (+ per-run station)
##   work      x8..12, y10..11 dispatch + one 2x2 yard slot at (9,10)
##   maintain  x4..7,  y9      2 troughs + small bed
##   pasture   x8..12, y12..13 toy station
var RANCH_PAVE := {
	"north": [], "nursery": [], "intensive": [], "work": [], "maintenance": [], "pasture": [],
}

func _static_cells() -> void:
	for y in range(7, 9):
		for x in range(0, 8):
			RANCH_PAVE["intensive"].append(Vector2i(x, y))
	for y in range(9, 10):
		for x in range(4, 10):
			RANCH_PAVE["maintenance"].append(Vector2i(x, y))
	for y in range(10, 13):
		for x in range(0, 5):
			RANCH_PAVE["nursery"].append(Vector2i(x, y))
	for y in range(10, 12):
		for x in range(8, 13):
			RANCH_PAVE["work"].append(Vector2i(x, y))
	for y in range(12, 14):
		for x in range(8, 13):
			RANCH_PAVE["pasture"].append(Vector2i(x, y))

func build_base(world: World, yard_id := "", station_id := "", with_work := true) -> Dictionary:
	if RANCH_PAVE["nursery"].is_empty():
		_static_cells()
	var seen := {}
	for group in ["intensive", "maintenance", "nursery", "work", "pasture"]:
		for cell in RANCH_PAVE[group]:
			var key := "%d,%d" % [cell.x, cell.y]
			if seen.has(key):
				check(false, "layout overlap " + key)
			seen[key] = group
			check(world.rooms.set_floor(cell, "ordinary")["ok"], "pave " + key)
	for spec in [["pen", 0, 10], ["feed_trough", 2, 10], ["feed_trough", 3, 10],
			["small_bed", 4, 10], ["medium_bed", 4, 11]]:
		check(world.build_facility(Vector2i(spec[1], spec[2]), String(spec[0]))["ok"], "nursery " + String(spec[0]))
	var zones := {}
	zones["nursery"] = _zone(world, "nursery", _cells("nursery"))
	for spec in [["pen", 1, 7], ["feed_trough", 3, 7], ["feed_trough", 3, 8],
			["small_bed", 4, 7], ["medium_bed", 5, 7]]:
		check(world.build_facility(Vector2i(spec[1], spec[2]), String(spec[0]))["ok"], "intensive " + String(spec[0]))
	if not station_id.is_empty():
		check(world.build_facility(Vector2i(6, 7), station_id)["ok"], "station " + station_id)
	zones["intensive"] = _zone(world, "intensive", _cells("intensive"))
	if with_work:
		check(world.build_facility(Vector2i(8, 10), "dispatch_station")["ok"], "dispatch")
		if not yard_id.is_empty():
			check(world.build_facility(Vector2i(9, 10), yard_id)["ok"], "yard " + yard_id)
		zones["work"] = _zone(world, "work", _cells("work"))
		for spec in [["feed_trough", 4, 9], ["feed_trough", 6, 9], ["small_bed", 5, 9], ["medium_bed", 7, 9]]:
			check(world.build_facility(Vector2i(spec[1], spec[2]), String(spec[0]))["ok"], "maintenance " + String(spec[0]))
		zones["maintenance"] = _zone(world, "maintenance", _cells("maintenance"))
		check(world.build_facility(Vector2i(10, 12), "toy_station")["ok"], "toy station")
		zones["pasture"] = _zone(world, "pasture", _cells("pasture"))
		var dispatch: int = world.facility_at(Vector2i(8, 10))["uid"]
		check(world.ranch.submit({"links": {zones["maintenance"]: dispatch, zones["pasture"]: dispatch}})["ok"], "links")
	return zones

func _cells(group: String) -> Array:
	var out := []
	for cell in RANCH_PAVE[group]:
		out.append("%d,%d" % [cell.x, cell.y])
	return out

func _zone(world: World, type_id: String, cells: Array) -> int:
	var result: Dictionary = world.ranch.create_zone(type_id, cells, type_id)
	check(result["ok"], "zone " + type_id)
	return int(result.get("zone_uid", 0))

func settle(world: World, days: int) -> void:
	for _day in range(days):
		world.end_day()
		archive_day(world)

func buy_adults(world: World, zones: Dictionary, species_id: String, count: int, days: int, bed_type := "") -> Array:
	check(world.ranch.purchase(zones["nursery"], species_id, count)["ok"], "buy " + species_id)
	settle(world, days)
	var adults: Array = world.ranch.state["animals"].filter(
		func(a): return String(a["species_id"]) == species_id and String(a["stage"]) == "adult")
	check(adults.size() == count, species_id + " adults")
	if bed_type.is_empty():
		return adults
	var chosen := {}
	var index := 0
	for row in adults:
		var bed: Dictionary = {}
		for candidate in world.ranch.free_bed_slots(world.ranch.zone(zones["intensive"]), bed_type):
			var key := "%d:%d" % [int(candidate["uid"]), int(candidate["slot"])]
			if not chosen.has(key):
				bed = candidate
				chosen[key] = true
				break
		check(world.ranch.submit({"assign": {int(row["uid"]): {"mode": "intensive", "zone_uid": zones["intensive"],
			"bed_uid": int(bed["uid"]), "bed_slot": int(bed["slot"])}}})["ok"], "assign " + species_id)
		index += 1
	settle(world, 1)
	return world.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == species_id and String(a["mode"]) == "intensive")

func assign_work(world: World, zones: Dictionary, species_id: String) -> Array:
	for row in world.ranch.state["animals"]:
		if String(row["species_id"]) == species_id and String(row["stage"]) == "adult" and String(row["mode"]) == "waiting":
			var uid := int(row["uid"])
			check(world.ranch.submit({"assign": {uid: {"mode": "work", "zone_uid": zones["work"]}}})["ok"], "assign worker")
	settle(world, 1)
	return world.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == species_id and String(a["mode"]) == "work")

func claim_station(world: World, station_id: String) -> Dictionary:
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == station_id:
			return world.ranch.claim_natural(int(uid))
	return {"ok": false, "reason": "no station"}

func claim_yards(world: World) -> void:
	for uid in world.facilities:
		if world.ranch.is_work_facility(String(world.facilities[uid]["facility_id"])):
			world.ranch.claim_workyard(int(uid))

# --- scenarios ----------------------------------------------------------------

func _mode_migration(world: World) -> void:
	var zones := build_base(world, "", "wool_station", false)
	check(world.ranch.purchase(zones["nursery"], "steel_sheep", 2)["ok"], "buy sheep")
	settle(world, 6)
	var pair: Array = world.ranch.state["animals"].filter(func(a): return String(a["stage"]) == "adult")
	check(pair.size() == 2, "both adults")
	# Breeding leg: with no workers in this scenario the southern strip is free.
	var enclosure_cells := []
	for y in range(10, 14):
		for x in range(8, 13):
			enclosure_cells.append("%d,%d" % [x, y])
	var enclosure: Dictionary = world.ranch.create_zone("enclosure", enclosure_cells, "migration")
	check(enclosure["ok"], "enclosure zone")
	for spec in [["pen", 8, 10], ["feed_trough", 10, 10], ["care_table", 11, 10], ["small_bed", 8, 12], ["medium_bed", 9, 12]]:
		check(world.build_facility(Vector2i(spec[1], spec[2]), String(spec[0]))["ok"], "enclosure " + String(spec[0]))
	var medium: Array = world.ranch.free_bed_slots(world.ranch.zone(int(enclosure["zone_uid"])), "medium")
	check(medium.size() >= 1, "enclosure medium bed")
	check(world.ranch.submit({"assign": {int(pair[0]["uid"]): {"mode": "enclosure", "zone_uid": int(enclosure["zone_uid"]),
		"bed_uid": int(medium[0]["uid"]), "bed_slot": int(medium[0]["slot"])}}})["ok"], "breeder assigned")
	settle(world, 4)
	var breeder: Dictionary = world.ranch.animal(int(pair[0]["uid"]))
	check(int(breeder["breed"]["units"]) == 1800 and int(breeder["natural"]["units"]) == 0, "breeder breeds only, no wool in the enclosure")
	# Intensive leg: the same species produces wool through the station.
	var producer: Dictionary = pair[1]
	var wool_bed: Array = world.ranch.free_bed_slots(world.ranch.zone(zones["intensive"]), "medium")
	check(world.ranch.submit({"assign": {int(producer["uid"]): {"mode": "intensive", "zone_uid": zones["intensive"],
		"bed_uid": int(wool_bed[0]["uid"]), "bed_slot": int(wool_bed[0]["slot"])}}})["ok"], "producer assigned")
	settle(world, 4)
	producer = world.ranch.animal(int(producer["uid"]))
	check(bool(producer["natural"]["pending"]) and int(producer["breed"]["units"]) == 0, "producer woonly, no breed progress")
	var wool: Dictionary = claim_station(world, "wool_station")
	check(wool["ok"] and int(wool["animals"]) == 1, "wool claimed through the station")
	# Switch back: the wool rights are gone with the claim, the breed clock resumes.
	var back_beds: Array = world.ranch.free_bed_slots(world.ranch.zone(int(enclosure["zone_uid"])), "medium")
	var back: Dictionary = back_beds[0] if not back_beds.is_empty() else medium[0]
	check(world.ranch.submit({"assign": {int(producer["uid"]): {"mode": "enclosure", "zone_uid": int(enclosure["zone_uid"]),
		"bed_uid": int(back["uid"]), "bed_slot": int(back["slot"])}}})["ok"], "producer back to breeding")
	settle(world, 4)
	producer = world.ranch.animal(int(producer["uid"]))
	check(int(producer["natural"]["units"]) == 600 and int(producer["breed"]["units"]) == 1800, "switch keeps the open wool round and resumes breeding")
	check(world.ranch.state["animals"].all(func(a): return int(a["death_streak"]) == 0), "no deaths")
	routes_run[route]["wool"] = world.inventory.count("steel_wool")

func _intensive_fatigue(world: World) -> void:
	var zones := build_base(world, "", "silkworm_rack")
	var worms: Array = buy_adults(world, zones, "leaf_silkworm", 3, 3, "small")
	check(worms.size() == 3, "three silk groups")
	world.ranch.animal(int(worms[0]["uid"]))["fatigue"] = 16
	var leaves: int = world.inventory.count("mulberry_leaf")
	settle(world, 1)
	worms = world.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == "leaf_silkworm")
	var rates := []
	for row in worms:
		rates.append(int(row["natural"]["units"]))
	rates.sort()
	check(rates == [300, 600, 600], "tired group advances half rate, others full")
	check(world.inventory.count("mulberry_leaf") == leaves - 3 * 2 - 3 * 2, "two meals per group plus round feeds")
	settle(world, 2)
	var claim: Dictionary = claim_station(world, "silkworm_rack")
	check(claim["ok"] and int(claim["animals"]) == 3, "three rounds claimed together")
	check(world.inventory.count("silk") == 12, "silk batch paid")
	# Strike opening: a spent group neither advances nor pays a new round.
	var spent: Dictionary = world.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == "leaf_silkworm")[0]
	world.ranch.animal(int(spent["uid"]))["fatigue"] = 40
	var leaves_before: int = world.inventory.count("mulberry_leaf")
	settle(world, 1)
	spent = world.ranch.animal(int(spent["uid"]))
	check(int(spent["natural"]["units"]) == 0 and not bool(spent["natural"]["paid"]), "strike opening pauses production")
	check(world.inventory.count("mulberry_leaf") == leaves_before - 3 * 2 - 2 * 2, "strike day keeps base meals and other rounds only")
	routes_run[route]["silk"] = world.inventory.count("silk")

func _silkworm_chain(world: World) -> void:
	var zones := build_base(world, "", "silkworm_rack")
	check(world.buy("mulberry_seed", 1)["ok"], "buy a mulberry seedling")
	for cell in [Vector2i(13, 12), Vector2i(14, 12), Vector2i(13, 13), Vector2i(14, 13)]:
		check(world.rooms.set_floor(cell, "farmland")["ok"], "farmland " + str(cell))
	check(world.plant(Vector2i(13, 12), "mulberry_tree")["ok"], "plant mulberry")
	var crop_uid: int = int(world.instance_at(Vector2i(13, 12))["uid"])
	# Real growth: tend water and fertility on the field every day.
	var guard := 0
	while String(world.crops[crop_uid]["state"]) != "mature" and guard < 10:
		_tend(world, Vector2i(13, 12))
		world.end_day()
		archive_day(world)
		guard += 1
	check(String(world.crops[crop_uid]["state"]) == "mature", "mulberry matures within ten tended days")
	var leaves: int = world.inventory.count("mulberry_leaf")
	check(world.harvest(Vector2i(13, 12))["ok"] and world.inventory.count("mulberry_leaf") == leaves + 10, "first tap pays ten leaves")
	# Silk groups on real leaves: nursery meals plus the round feed.
	var worms: Array = buy_adults(world, zones, "leaf_silkworm", 2, 3, "small")
	settle(world, 2)
	var claim: Dictionary = claim_station(world, "silkworm_rack")
	check(claim["ok"] and world.inventory.count("silk") == 8, "silk from homegrown leaves")
	check(not world.ranch.submit({"assign": {int(worms[0]["uid"]): {"mode": "enclosure", "zone_uid": zones["nursery"]}}})["ok"], "silkworm has no breeding entry")
	# Downstream: the filter media recipe consumes the silk.
	check(world.build_facility(Vector2i(13, 7), "woodshop")["ok"], "woodshop")
	var woodshop: int = world.facility_at(Vector2i(13, 7))["uid"]
	check(world.start_batch(woodshop, "make_silk_filter_media")["ok"], "silk filter batch starts")
	for _day in range(2):
		world.end_day()
		archive_day(world)
	var batch: Dictionary = world.facilities[woodshop]["batch"]
	check(String(batch["status"]) == "ready", "filter batch ready")
	check(world.claim_batch(woodshop, int(batch["batch_id"]))["ok"] and world.inventory.count("filter_media") == 3, "filter media claimed")
	routes_run[route]["silk"] = world.inventory.count("silk")
	routes_run[route]["filter_media"] = world.inventory.count("filter_media")
	routes_run[route]["leaves"] = world.inventory.count("mulberry_leaf")

func _tend(world: World, cell: Vector2i) -> void:
	var env: Dictionary = world.environment_at(cell)
	if int(env["water"]) < 70:
		world.irrigate(cell)
	if int(env["fertility"]) < 50:
		world.fertilize(cell)

func _liquid_outlet(world: World) -> void:
	var zones := build_base(world, "", "spirit_liquid_collector")
	var snails: Array = buy_adults(world, zones, "dew_shell_snail", 2, 4, "small")
	check(snails.size() == 2, "two snails")
	settle(world, 3)
	var claim: Dictionary = claim_station(world, "spirit_liquid_collector")
	check(claim["ok"] and world.inventory.count("spirit_liquid") == 4 and world.inventory.count("mucus") == 2, "liquid and mucus claimed")
	# Trade outlet only: selling is the designed exit, nothing consumes it.
	var stones: float = world.primeval_stones
	check(world.sell("spirit_liquid", 4)["ok"], "spirit liquid sells")
	check(world.primeval_stones == stones + 4 * 6.0, "sale pays the listed price")
	var consumers := 0
	for recipe_id in world.recipe_defs:
		if world.recipe_defs[recipe_id]["inputs"].has("spirit_liquid"):
			consumers += 1
	check(consumers == 0, "no recipe consumes spirit liquid this phase")
	routes_run[route]["spirit_liquid"] = world.inventory.count("spirit_liquid")
	routes_run[route]["mucus"] = world.inventory.count("mucus")

func _carbon_compost(world: World) -> void:
	var zones := build_base(world, "carbonization_nest")
	var bugs: Array = buy_adults(world, zones, "carbon_belly_bug", 2, 3)
	var workers: Array = assign_work(world, zones, "carbon_belly_bug")
	check(workers.size() == 2, "bugs on shift")
	var twigs: int = world.inventory.count("twig")
	settle(world, 2)
	claim_yards(world)
	check(world.inventory.count("twig") <= twigs, "char batches paid real twigs")
	check(world.inventory.count("charcoal") >= 4 and world.inventory.count("humus") >= 1, "charcoal and humus delivered")
	# Compost mice on the fiber recipe: straw plus chips into humus.
	check(world.build_facility(Vector2i(11, 10), "compost_mouse_den")["ok"], "second yard in the work zone")
	var mice: Array = buy_adults(world, zones, "compost_mouse", 2, 3)
	var mouse_workers: Array = assign_work(world, zones, "compost_mouse")
	check(mouse_workers.size() == 2, "mice on shift")
	settle(world, 2)
	claim_yards(world)
	check(world.inventory.count("humus") >= 5, "mouse rounds add humus")
	routes_run[route]["charcoal"] = world.inventory.count("charcoal")
	routes_run[route]["humus"] = world.inventory.count("humus")

func _mineral_shell(world: World) -> void:
	var zones := build_base(world, "shell_forming_station", "scale_station")
	var lizards: Array = buy_adults(world, zones, "mineral_scale_lizard", 2, 6, "medium")
	check(lizards.size() == 2, "two lizards")
	settle(world, 5)
	var claim: Dictionary = claim_station(world, "scale_station")
	check(claim["ok"] and world.inventory.count("mineral_scale") == 4 and world.inventory.count("shed_skin") == 2, "scale round claimed")
	# Panels: the woodshop consumes scales and shed skins.
	check(world.build_facility(Vector2i(13, 7), "woodshop")["ok"], "woodshop")
	var woodshop: int = world.facility_at(Vector2i(13, 7))["uid"]
	check(world.start_batch(woodshop, "assemble_scale_panel")["ok"], "scale panel starts")
	for _day in range(2):
		world.end_day()
		archive_day(world)
	var panel: Dictionary = world.facilities[woodshop]["batch"]
	check(world.claim_batch(woodshop, int(panel["batch_id"]))["ok"] and world.inventory.count("composite_stone_panel") >= 3, "scale panels claimed")
	# Gravel snail work: stone powder and water into shells and mucus.
	var snails: Array = buy_adults(world, zones, "gravel_shell_snail", 1, 5)
	var workers: Array = assign_work(world, zones, "gravel_shell_snail")
	check(workers.size() == 1, "snail on shift")
	settle(world, 3)
	claim_yards(world)
	check(world.inventory.count("rock_shell") >= 2 and world.inventory.count("mucus") >= 1, "shell batch claimed")
	check(world.start_batch(woodshop, "assemble_shell_panel")["ok"], "shell panel starts")
	for _day in range(2):
		world.end_day()
		archive_day(world)
	var shell_panel: Dictionary = world.facilities[woodshop]["batch"]
	check(world.claim_batch(woodshop, int(shell_panel["batch_id"]))["ok"], "shell panels claimed")
	routes_run[route]["panels"] = world.inventory.count("composite_stone_panel")
	routes_run[route]["rock_shell"] = world.inventory.count("rock_shell")

# --- evidence plumbing --------------------------------------------------------

func archive_day(world: World) -> void:
	if days_file == null:
		return
	var animals := []
	for row in world.ranch.state["animals"]:
		animals.append({"uid": int(row["uid"]), "species": row["species_id"], "mode": row["mode"],
			"fatigue": int(row["fatigue"]), "ban_until": int(row["ban_until"]),
			"qualified_until": int(row["qualified_until"]), "death_streak": int(row["death_streak"]),
			"account": {"w": int(row["account"]["w"]), "r": int(row["account"]["r"]), "fails": int(row["account"]["fails"])},
			"natural": {"round": int(row["natural"]["round"]), "units": int(row["natural"]["units"]),
				"pending": bool(row["natural"]["pending"]), "paid": bool(row["natural"]["paid"])},
			"breed": {"round": int(row["breed"]["round"]), "units": int(row["breed"]["units"]), "pending": bool(row["breed"]["pending"])}})
	var yards := {}
	for key in world.ranch.state["workyards"]:
		yards[key] = world.ranch.state["workyards"][key].duplicate(true)
	days_file.store_line(JSON.stringify({"day": world.clock.total_days - 1, "animals": animals,
		"clock": world.clock.total_days, "inventory": world.inventory.to_save(),
		"stones": world.primeval_stones, "workyards": yards}))

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
