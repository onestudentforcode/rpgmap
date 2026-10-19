extends SceneTree
## Seconds-level reference fixture lint (testing policy ①-layer extension,
## landed as the first P10.6 task). Each milestone leaves its standard module
## layout here as a static checklist; the lint asserts the CURRENT config still
## qualifies every structure and the maintain -> post -> recover cycle runs for
## a handful of days without strikes, so cross-module drift (a missing toy
## station, a renamed facility) surfaces in seconds instead of a 20-minute
## replay. This is structural drift evidence only, never a business claim.
const World := preload("res://scripts/farming/p8/p8_world.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")

var checks := 0
var failures: Array = []
var receipts := {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FIXTURE LINT " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	_land_ranch()
	var summary := {"checks": checks, "failures": failures}
	print("FIXTURE LINT %s (%d)" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _world(tag: String) -> World:
	var world := World.new(Store.new("res://.art-work/fixture-lint/%s-%d-%d" % [tag, OS.get_process_id(), Time.get_ticks_usec()]))
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 300, "raw_stone": 300, "wood_plank": 60, "twig": 120,
		"mushroom": 400, "fodder_grass": 400, "grain": 200, "clean_water": 900,
		"land_feed": 100, "iron_ore": 120, "mineral_feed": 100, "algae_feed": 60, "straw": 60,
		"wood_chip": 60, "sludge": 40, "oil_cake": 20, "stone_powder": 40,
		"gravel": 40, "mulberry_leaf": 60, "charcoal": 20, "humus": 60})
	world.primeval_stones += 3000
	world._cash("sales_revenue", 3000)
	world.research.state["completed"] = world.research.project_defs().keys()
	world.operation_recorded.connect(func(entry: Dictionary):
		var key := String(entry.get("kind", ""))
		receipts[key] = int(receipts.get(key, 0)) + 1)
	return world

# --- reference fixture: the combined land ranch module (P10.3 + P10.5) --------
## Static checklist — keep in sync with the shipped module layouts, not with
## any playtest strategy. Sources block x15..17 y8..10 stays unpaved.
##   nursery     x0..4,  y10..12  pen + 3 troughs + small/medium beds
##   work        x8..13, y10..11  dispatch + two breaking yards
##   maintenance x4..9,  y9       2 troughs + small/medium beds
##   pasture     x8..19, y12..13  toy station
##   enclosure   x10..14, y7..9   pen + trough + beds + care table
##   intensive   x0..7,  y7..8    pen + troughs + beds + wool station
const LAYOUT := {
	"nursery": [Vector2i(0, 10), Vector2i(1, 10), Vector2i(2, 10), Vector2i(3, 10), Vector2i(4, 10),
		Vector2i(0, 11), Vector2i(1, 11), Vector2i(2, 11), Vector2i(3, 11), Vector2i(4, 11),
		Vector2i(0, 12), Vector2i(1, 12), Vector2i(2, 12), Vector2i(3, 12), Vector2i(4, 12)],
	"work": [Vector2i(8, 10), Vector2i(9, 10), Vector2i(10, 10), Vector2i(11, 10), Vector2i(12, 10), Vector2i(13, 10),
		Vector2i(8, 11), Vector2i(9, 11), Vector2i(10, 11), Vector2i(11, 11), Vector2i(12, 11), Vector2i(13, 11)],
	"maintenance": [Vector2i(4, 9), Vector2i(5, 9), Vector2i(6, 9), Vector2i(7, 9), Vector2i(8, 9), Vector2i(9, 9)],
	"pasture": [Vector2i(8, 12), Vector2i(9, 12), Vector2i(10, 12), Vector2i(11, 12), Vector2i(12, 12), Vector2i(13, 12), Vector2i(14, 12), Vector2i(15, 12), Vector2i(16, 12), Vector2i(17, 12), Vector2i(18, 12), Vector2i(19, 12),
		Vector2i(8, 13), Vector2i(9, 13), Vector2i(10, 13), Vector2i(11, 13), Vector2i(12, 13), Vector2i(13, 13), Vector2i(14, 13), Vector2i(15, 13), Vector2i(16, 13), Vector2i(17, 13), Vector2i(18, 13), Vector2i(19, 13)],
	"enclosure": [Vector2i(10, 7), Vector2i(11, 7), Vector2i(12, 7), Vector2i(13, 7), Vector2i(14, 7),
		Vector2i(10, 8), Vector2i(11, 8), Vector2i(12, 8), Vector2i(13, 8), Vector2i(14, 8),
		Vector2i(10, 9), Vector2i(11, 9), Vector2i(12, 9), Vector2i(13, 9), Vector2i(14, 9)],
	"intensive": [Vector2i(0, 7), Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7),
		Vector2i(0, 8), Vector2i(1, 8), Vector2i(2, 8), Vector2i(3, 8), Vector2i(4, 8), Vector2i(5, 8), Vector2i(6, 8), Vector2i(7, 8)],
}
const FACILITIES := [["pen", 0, 10], ["feed_trough", 2, 10], ["feed_trough", 3, 10], ["feed_trough", 4, 10],
	["small_bed", 4, 11], ["medium_bed", 3, 11],
	["dispatch_station", 8, 10], ["rock_breaking_yard", 9, 10], ["rock_breaking_yard", 11, 10],
	["feed_trough", 4, 9], ["feed_trough", 5, 9], ["small_bed", 6, 9], ["medium_bed", 7, 9],
	["toy_station", 8, 12],
	["pen", 10, 7], ["feed_trough", 12, 7], ["medium_bed", 13, 7], ["small_bed", 14, 7], ["care_table", 14, 8],
	["pen", 1, 7], ["feed_trough", 3, 7], ["small_bed", 4, 7], ["medium_bed", 5, 7], ["wool_station", 6, 7]]

static func _texts(cells: Array) -> Array:
	var out := []
	for cell in cells:
		out.append("%d,%d" % [cell.x, cell.y])
	return out

func _land_ranch() -> void:
	var world := _world("land-ranch")
	# Pave only cells inside the reference module, skipping resource sources.
	var module_cells := {}
	for group in LAYOUT:
		for cell in LAYOUT[group]:
			module_cells["%d,%d" % [cell.x, cell.y]] = String(group)
	for key in module_cells:
		var parts: PackedStringArray = key.split(",")
		if not world.source_at(Vector2i(int(parts[0]), int(parts[1]))).is_empty():
			continue
		check(world.rooms.set_floor(Vector2i(int(parts[0]), int(parts[1])), "ordinary")["ok"], "pave " + key)
	for spec in FACILITIES:
		check(world.build_facility(Vector2i(int(spec[1]), int(spec[2])), String(spec[0]))["ok"],
			"build %s at %d,%d" % [String(spec[0]), int(spec[1]), int(spec[2])])
	var zones := {}
	for group in ["nursery", "work", "maintenance", "pasture", "enclosure", "intensive"]:
		var created: Dictionary = world.ranch.create_zone(group, _texts(LAYOUT[group]), group)
		check(created["ok"], "zone " + group)
		zones[group] = int(created.get("zone_uid", 0))
	var dispatch: int = world.facility_at(Vector2i(8, 10))["uid"]
	check(world.ranch.submit({"links": {zones["maintenance"]: dispatch, zones["pasture"]: dispatch}})["ok"], "links")
	check(world.ranch.submit({"birth_targets": {zones["enclosure"]: zones["nursery"]}})["ok"], "birth target")
	# Structure qualification under the current config: the whole point of the
	# lint. A renamed facility or a moved structure fails right here.
	for group in zones:
		var row: Dictionary = world.ranch.zone(zones[group])
		check(world.ranch.structure_missing(row).is_empty(), group + " structures complete")
		check(world.ranch.zone_structural(row), group + " structural")
	# Standard cycle: two sheep (breeder + wool producer) and two working moles.
	check(world.ranch.purchase(zones["nursery"], "steel_sheep", 2)["ok"], "buy sheep")
	check(world.ranch.purchase(zones["nursery"], "rock_mole", 2)["ok"], "buy moles")
	var strike_floor := -1
	for tier in world.ranch.settings["fatigue"]["tiers"]:
		if int(tier["efficiency"]) <= 0 and (strike_floor < 0 or int(tier["max"]) < strike_floor):
			strike_floor = int(tier["max"]) + 1
	check(strike_floor > 0, "strike tier known")
	for day in range(16):
		world.end_day()
		check(world.daily_save_error.is_empty(), "clean settle day %d" % day)
		if day == 6:
			_assign_adults(world, zones)
		if day > 6:
			_sweep_claims(world)
		for row in world.ranch.state["animals"]:
			check(int(row["death_streak"]) == 0, "no death streak day %d (%s)" % [day, row["species_id"]])
			check(int(row["fatigue"]) < strike_floor, "no strike at next open day %d (%s, fatigue %d)" % [day, row["species_id"], int(row["fatigue"])])
			check(int(row["ban_until"]) <= world.clock.total_days * 8, "no active ban day %d" % day)
		for item in world.inventory.to_save():
			check(int(world.inventory.to_save()[item]) >= 0, "stock non-negative " + String(item))
		for group in zones:
			check(world.ranch.zone_structural(world.ranch.zone(zones[group])), group + " stays structural day %d" % day)
	# The cycle must have actually run, not merely survived.
	check(int(receipts.get("ranch:work", 0)) > 0, "work units happened")
	check(int(receipts.get("ranch:window", 0)) > 0, "maintenance windows happened")
	check(int(receipts.get("ranch:natural", 0)) > 0, "intensive rounds happened")
	var bred := 0
	for row in world.ranch.state["animals"]:
		if String(row["mode"]) == "enclosure":
			bred = maxi(bred, int(row["breed"]["units"]))
	check(bred > 0, "enclosure breeding advanced")
	var rested := 0
	for row in world.ranch.state["animals"]:
		rested = maxi(rested, int(row["account"].get("r", 0)))
	check(rested > 0, "rest units happened")
	check(int(receipts.get("ranch:products", 0)) + int(receipts.get("ranch:workyard", 0)) > 0, "claims happened")
	# Snapshot validation and semantic round-trip on the live module state.
	var codec := preload("res://scripts/farming/p8/p8_snapshot.gd")
	check(codec.normalize(world.to_snapshot())["ok"], "snapshot codec-valid")
	var snapshot: Dictionary = world.to_snapshot()
	var detached := World.new(Store.new("res://.art-work/fixture-lint/roundtrip-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]))
	var loaded: Dictionary = detached.apply_snapshot(snapshot)
	check(bool(loaded.get("ok", false)), "snapshot applies")
	check(detached.ranch.state["animals"].size() == world.ranch.state["animals"].size(), "roster survives the trip")
	check(codec.normalize(detached.to_snapshot())["ok"], "re-serialized snapshot codec-valid")
	for row in world.ranch.state["animals"]:
		var mirror: Dictionary = detached.ranch.animal(int(row["uid"]))
		check(not mirror.is_empty() and int(mirror["fatigue"]) == int(row["fatigue"])
			and int(mirror["natural"]["units"]) == int(row["natural"]["units"])
			and int(mirror["breed"]["units"]) == int(row["breed"]["units"]),
			"animal %d state survives the trip" % int(row["uid"]))

func _assign_adults(world: World, zones: Dictionary) -> void:
	var sheep: Array = world.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == "steel_sheep" and String(a["stage"]) == "adult")
	check(sheep.size() == 2, "both sheep adult")
	var moles: Array = world.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == "rock_mole" and String(a["stage"]) == "adult")
	check(moles.size() == 2, "both moles adult")
	var enclosure_medium: Array = world.ranch.free_bed_slots(world.ranch.zone(zones["enclosure"]), "medium")
	var intensive_medium: Array = world.ranch.free_bed_slots(world.ranch.zone(zones["intensive"]), "medium")
	check(enclosure_medium.size() >= 1 and intensive_medium.size() >= 1, "medium beds free")
	if sheep.size() == 2 and enclosure_medium.size() >= 1 and intensive_medium.size() >= 1:
		check(world.ranch.submit({"assign": {int(sheep[0]["uid"]): {"mode": "enclosure", "zone_uid": zones["enclosure"],
			"bed_uid": int(enclosure_medium[0]["uid"]), "bed_slot": int(enclosure_medium[0]["slot"])}}})["ok"], "breeder assigned")
		check(world.ranch.submit({"assign": {int(sheep[1]["uid"]): {"mode": "intensive", "zone_uid": zones["intensive"],
			"bed_uid": int(intensive_medium[0]["uid"]), "bed_slot": int(intensive_medium[0]["slot"])}}})["ok"], "producer assigned")
	for row in moles:
		check(world.ranch.submit({"assign": {int(row["uid"]): {"mode": "work", "zone_uid": zones["work"]}}})["ok"], "mole to work")

func _sweep_claims(world: World) -> void:
	for uid in world.facilities:
		var fid := String(world.facilities[uid]["facility_id"])
		if world.ranch.is_work_facility(fid):
			world.ranch.claim_workyard(int(uid))
		elif fid == "wool_station":
			world.ranch.claim_natural(int(uid))
