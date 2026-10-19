extends SceneTree
## P10.6 stage-b model suite: fish fences, explicit water bodies with one
## integer quality total, the source-inheritance ledger, topology edits with
## conservation (expand / merge / split / release), water services (manual and
## shore stations), day-end decay and the five water zone types with
## dual-medium shared structures. Schema 24 codec checks close the suite.
const World := preload("res://scripts/farming/p8/p8_world.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const Codec := preload("res://scripts/farming/p8/p8_snapshot.gd")

var checks := 0
var failures: Array = []
var receipts: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("P106 MODEL " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var w := _world()
	_fences_and_bodies(w)
	_quality_services(w)
	_topology(w)
	_water_zones(w)
	_codec(w)
	print("P106 MODEL %s (%d)" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _world() -> World:
	var world := World.new(Store.new("res://.art-work/p106-tests/slots-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]))
	world.start_new(1)
	world.grant_scaffold({"twig": 200, "wood_plank": 60, "raw_stone": 120, "raw_wood": 60, "clean_water": 300})
	world.primeval_stones += 3000
	world._cash("sales_revenue", 3000)
	world.research.state["completed"] = world.research.project_defs().keys()
	world.operation_recorded.connect(func(entry: Dictionary): receipts.append(entry))
	return world

# --- fences and bodies --------------------------------------------------------

func _fences_and_bodies(w: World) -> void:
	# Fences only lay on owned natural water.
	check(not w.water.quote_fence([Vector2i(2, 10)], 0)["ok"], "fence refuses land")
	check(not w.water.quote_fence([Vector2i(-2, 15)], 0)["ok"], "fence refuses unowned parcel")
	var stones := w.primeval_stones
	var twigs := w.inventory.count("twig")
	var first: Dictionary = w.water.build_fence([Vector2i(2, 14), Vector2i(3, 14), Vector2i(2, 15), Vector2i(3, 15)], 0)
	check(first["ok"], "first body fenced")
	var body_a: Dictionary = w.water.body(int(first["body"]))
	check(body_a["cells"].size() == 4 and int(body_a["quality"]) == 40000, "initial grant is 10000 per cell")
	check(w.primeval_stones == stones - 4 and w.inventory.count("twig") == twigs - 4, "fence costs 1 stone + 1 twig per cell")
	check(w.water.quality(body_a) == 100, "fresh body displays 100")
	check(not w.water.build_fence([Vector2i(2, 14)], 0)["ok"], "no double fencing")
	check(not w.water.build_fence([Vector2i(2, 14), Vector2i(2, 14)], 0)["ok"], "no duplicate cells in one batch")
	check(not w.water.build_fence([Vector2i(8, 19)], int(first["body"]))["ok"], "joining must stay connected")
	# A second body in the same water stays separate even when later adjacency
	# closes the gap; nothing ever merges by touching.
	var second: Dictionary = w.water.build_fence([Vector2i(5, 14), Vector2i(5, 15)], 0)
	check(second["ok"] and int(second["body"]) != int(first["body"]), "second body separate")
	var join: Dictionary = w.water.build_fence([Vector2i(4, 15)], int(first["body"]))
	check(join["ok"], "gap cell joins body A")
	check(w.water.body(int(first["body"]))["cells"].size() == 5, "body A grew to five cells")
	check(w.water.body(int(second["body"]))["cells"].size() == 2, "body B untouched")
	check(int(w.water.state["fences"]["5,14"]) == int(second["body"]), "adjacent cells keep their body")

# --- quality and services -----------------------------------------------------

func _quality_services(w: World) -> void:
	var body_b: Dictionary = w.water.body(2)
	var water_stock := w.inventory.count("clean_water")
	var waste := w.inventory.count("wastewater")
	# A two-cell body: gain is capped at 40 x min(A,8) points per cell and the
	# ceiling turns the rest into recorded treatment waste.
	check(w.water.change_water(2)["ok"], "manual change runs")
	check(w.inventory.count("clean_water") == water_stock - 2 and w.inventory.count("wastewater") == waste + 2,
		"change consumes 2 clean water and produces 2 wastewater")
	check(int(body_b["quality"]) == 20000, "capped at area x 10000")
	var wasted := 0
	for entry in receipts:
		if entry.get("kind") == "water" and entry.get("stage") == "change" and int(entry.get("body", 0)) == 2:
			wasted = int(entry["wasted"])
	check(wasted == 2 * 40 * 100, "excess recorded as waste on a full body")
	check(not w.water.change_water(2)["ok"], "one manual change per body per day")
	# Shore stations: adjacency-checked, single-body links, one service a day.
	var shore_a: Dictionary = w.build_facility(Vector2i(2, 13), "water_change_station")
	check(shore_a["ok"], "shore station builds on land")
	var far: Dictionary = w.build_facility(Vector2i(10, 13), "water_change_station")
	check(far["ok"], "second shore station builds")
	check(not w.water.link_station(int(far["facility_uid"]), 1)["ok"], "station must sit on the body's shore")
	check(w.water.link_station(int(shore_a["facility_uid"]), 1)["ok"], "station links to its adjacent body")
	check(not w.water.link_station(int(shore_a["facility_uid"]), 2)["ok"], "one body per station")
	var clean := w.inventory.count("clean_water")
	w.end_day()
	# Body A has five cells: 5 x 40 x 100 = 20000 auto gain, then the day decay.
	check(int(w.water.body(1)["quality"]) == mini(50000 + 5 * 40 * 100, 50000) - 2 * 5 * 100,
		"auto change applies then decay subtracts")
	check(w.inventory.count("clean_water") == clean - 2, "auto station consumed its inputs")
	var auto_runs := 0
	for entry in receipts:
		if entry.get("kind") == "water" and entry.get("stage") == "change" and entry.get("operator") == "station":
			auto_runs += 1
	check(auto_runs == 1, "one auto service per station per day")
	# The day advance re-arms the manual change; a starved station waits and
	# records it instead of spending anything.
	check(w.water.change_water(2)["ok"], "manual change re-arms next day")
	# Drain through the scaffold so the day ledger stays consistent; one unit
	# left cannot pay the two-unit change recipe.
	var stock := w.inventory.count("clean_water")
	w.inventory.remove("clean_water", stock - 1)
	w._record_flow({}, {"clean_water": stock - 1}, "测试排空清水")
	check(w.inventory.count("clean_water") == 1, "stock drained to a single unit")
	var b_quality := int(w.water.body(2)["quality"])
	w.end_day()
	check(int(w.water.body(2)["quality"]) == maxi(0, b_quality - 2 * 2 * 100), "starved day only decays")
	var waits := 0
	for entry in receipts:
		if entry.get("kind") == "water" and entry.get("stage") == "auto_wait":
			waits += 1
	check(waits >= 1, "starved station records a wait")

# --- topology -----------------------------------------------------------------

func _topology(w: World) -> void:
	w.grant_scaffold({"clean_water": 200})
	var body_a: Dictionary = w.water.body(1)
	var body_b: Dictionary = w.water.body(2)
	var total := int(body_a["quality"]) + int(body_b["quality"])
	check(w.water.merge_bodies(1, 2)["ok"], "adjacent bodies merge")
	var merged: Dictionary = w.water.body(1)
	check(w.water.body(2).is_empty(), "merged body disappears")
	check(merged["cells"].size() == 7 and int(merged["quality"]) == total, "merge conserves area and total")
	check(not w.water.merge_bodies(1, 1)["ok"], "cannot merge a body with itself")
	# While the bridge cell still connects the two halves, releasing it would
	# cut the remainder, so the release is refused.
	check(not w.water.release_fence([Vector2i(4, 15)])["ok"], "bridge cell cannot cut the body")
	# A far body cannot merge without adjacency.
	var lone: Dictionary = w.water.build_fence([Vector2i(10, 18), Vector2i(11, 18)], 0)
	check(lone["ok"], "far body fences")
	check(not w.water.merge_bodies(1, int(lone["body"]))["ok"], "disjoint bodies cannot merge")
	# Split: conservation plus the remainder walk; zones fully inside follow.
	var zone_result: Dictionary = w.ranch.create_zone("aqua_planting", ["2,14", "3,14"], "planting")
	check(zone_result["ok"], "planting zone on body A")
	var before_split := int(merged["quality"])
	var split: Dictionary = w.water.split_body(1, [Vector2i(5, 14), Vector2i(5, 15)])
	check(split["ok"], "split runs")
	var child: Dictionary = w.water.body(int(split["body"]))
	var parent: Dictionary = w.water.body(1)
	check(int(child["quality"]) + int(parent["quality"]) == before_split, "split conserves the total")
	check(child["cells"].size() == 2 and parent["cells"].size() == 5, "split areas add up")
	check(int(w.water.state["fences"]["5,14"]) == int(child["uid"]), "fences repointed to the child")
	check(int(w.ranch.zone(int(zone_result["zone_uid"]))["body_uid"]) == 1, "zone kept its body")
	check(not w.water.split_body(1, [Vector2i(2, 14), Vector2i(3, 15)])["ok"], "straddling zone blocks the split")
	# Release banks the per-cell share; rebuilding takes the bank back instead
	# of minting a fresh 10000.
	var drained: Dictionary = w.water.body(1)
	var share: int = int(drained["quality"]) / int(drained["cells"].size())
	check(share < 10000, "body has decayed below full")
	check(not w.water.release_fence([Vector2i(2, 14)])["ok"], "zone cells cannot be released")
	var banked := int(drained["quality"])
	check(w.water.release_fence([Vector2i(2, 15)])["ok"], "plain cell released")
	check(int(w.water.state["sources"]["2,15"]) == share, "release banks the share")
	check(int(w.water.body(1)["quality"]) == banked - share, "release subtracts the share")
	check(w.water.build_fence([Vector2i(2, 15)], 1)["ok"], "fence rebuilt on the released cell")
	check(int(w.water.body(1)["quality"]) == banked, "rebuild takes back the banked value, never 10000")
	check(not w.water.state["sources"].has("2,15"), "bank entry spent")

# --- water zones and dual-medium structures -----------------------------------

func _water_zones(w: World) -> void:
	# A dedicated 4x4 body for structural zone work (16 cells, 16 AP).
	var cells: Array = []
	for y in range(16, 20):
		for x in range(12, 16):
			cells.append("%d,%d" % [x, y])
	var penned: Dictionary = w.water.build_fence([Vector2i(12, 16), Vector2i(13, 16), Vector2i(14, 16), Vector2i(15, 16),
		Vector2i(12, 17), Vector2i(13, 17), Vector2i(14, 17), Vector2i(15, 17),
		Vector2i(12, 18), Vector2i(13, 18), Vector2i(14, 18), Vector2i(15, 18),
		Vector2i(12, 19), Vector2i(13, 19), Vector2i(14, 19), Vector2i(15, 19)], 0)
	check(penned["ok"], "zone body fenced")
	var body_uid := int(penned["body"])
	check(not w.ranch.create_zone("water_nursery", ["19,20"], "bad")["ok"], "zone needs fenced cells")
	check(not w.ranch.create_zone("water_nursery", ["12,16", "10,19"], "cross")["ok"], "zone cannot cross bodies")
	var created: Dictionary = w.ranch.create_zone("water_nursery", cells, "pools")
	check(created["ok"], "water nursery created")
	var zone_row: Dictionary = w.ranch.zone(int(created["zone_uid"]))
	check(int(zone_row["body_uid"]) == body_uid, "zone records its body")
	check(not w.ranch.zone_structural(zone_row), "zone without structures is not qualified")
	# A fresh day: sixteen fence cells already spent the daily AP budget.
	w.end_day()
	# Dual-medium shared structures: pen, trough and bed all stand on water.
	var pen: Dictionary = w.build_facility(Vector2i(12, 16), "pen")
	check(pen["ok"], "pen builds on the water surface")
	var mixed: Dictionary = w.can_build_facility(Vector2i(11, 13), "pen")
	check(not mixed["ok"], "footprint cannot straddle water and land")
	check(w.build_facility(Vector2i(14, 16), "feed_trough")["ok"], "trough builds on water")
	check(w.build_facility(Vector2i(15, 16), "small_bed")["ok"], "small bed builds on water")
	check(w.ranch.zone_structural(w.ranch.zone(int(created["zone_uid"]))), "water nursery becomes structural")
	# Space accounting: pen (4) + trough (1) blocked, the bed never blocks.
	check(w.ranch.available_space(w.ranch.zone(int(created["zone_uid"]))) == 11, "water space accounting")
	# The same shared structures still build on land unchanged, and the
	# fish_pond is gone from the build path.
	check(w.rooms.set_floor(Vector2i(16, 13), "ordinary")["ok"], "land floor paved")
	check(w.build_facility(Vector2i(16, 13), "feed_trough")["ok"], "trough still builds on land")
	check(not w.can_build_facility(Vector2i(17, 13), "fish_pond")["ok"], "fish_pond retired from new builds")
	check(not w.ranch.create_zone("nursery", ["12,16"], "landzone")["ok"], "land zone refuses water cells")
	w.end_day()
	check(w.ranch.zone_structural(w.ranch.zone(int(created["zone_uid"]))), "zone stays structural across days")
	# Production zones need one of the species stations; the shared pen does
	# not satisfy that group, the carp station does.
	check(w.ranch.erase_zone(int(created["zone_uid"]))["ok"], "nursery zone erased")
	var production: Dictionary = w.ranch.create_zone("water_production", cells, "prod")
	check(production["ok"], "production zone created")
	check(w.ranch.structure_missing(w.ranch.zone(int(production["zone_uid"]))).has("water_station"),
		"production zone misses its station group")
	check(w.build_facility(Vector2i(15, 17), "carp_harvest_station")["ok"], "carp station builds on water")
	check(not w.ranch.structure_missing(w.ranch.zone(int(production["zone_uid"]))).has("water_station"),
		"station satisfies the group")
	check(w.ranch.zone_structural(w.ranch.zone(int(production["zone_uid"]))), "production zone structural")
	# Zone membership protects its cells from release until the zone is gone.
	check(not w.water.release_fence([Vector2i(12, 19)])["ok"], "zone cell protected from release")
	check(w.ranch.erase_zone(int(production["zone_uid"]))["ok"], "production zone erased")
	var freed: Dictionary = w.water.release_fence([Vector2i(12, 19)])
	check(freed["ok"], "cells release after the zone is gone")

# --- codec --------------------------------------------------------------------

func _codec(w: World) -> void:
	var snapshot: Dictionary = w.to_snapshot()
	check(Codec.normalize(snapshot)["ok"], "live snapshot codec-valid")
	var detached := World.new(Store.new("res://.art-work/p106-tests/roundtrip-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]))
	var loaded: Dictionary = detached.apply_snapshot(snapshot)
	check(bool(loaded.get("ok", false)), "snapshot applies")
	check(detached.water.state["bodies"].size() == w.water.state["bodies"].size(), "bodies survive the trip")
	check(detached.water.quality(detached.water.body(1)) == w.water.quality(w.water.body(1)), "quality survives the trip")
	var stale := snapshot.duplicate(true)
	stale["schema"] = 23
	check(not Codec.normalize(stale)["ok"], "schema 23 snapshots are rejected")
	# Forgery: two bodies sharing one cell.
	var forged := snapshot.duplicate(true)
	var first_body: Dictionary = forged["world"]["water"]["bodies"][0]
	var victim: String = first_body["cells"][0]
	forged["world"]["water"]["bodies"][1]["cells"].append(victim)
	check(not Codec.normalize(forged)["ok"], "overlapping bodies rejected")
	# Forgery: quality above the area cap.
	var forged2 := snapshot.duplicate(true)
	forged2["world"]["water"]["bodies"][0]["quality"] = 1000000
	check(not Codec.normalize(forged2)["ok"], "quality above cap rejected")
	# Forgery: fence map disagreeing with body membership.
	var forged3 := snapshot.duplicate(true)
	forged3["world"]["water"]["fences"][victim] = 999
	check(not Codec.normalize(forged3)["ok"], "fence map mismatch rejected")
	# Forgery: source ledger on a fenced cell.
	var forged4 := snapshot.duplicate(true)
	forged4["world"]["water"]["sources"][victim] = 500
	check(not Codec.normalize(forged4)["ok"], "source ledger on a live fence rejected")
	# Forgery: a land zone claiming a body.
	var forged5 := snapshot.duplicate(true)
	for zone in forged5["world"]["ranch"]["zones"]:
		if int(zone["body_uid"]) > 0:
			zone["type"] = "intensive"
	check(not Codec.normalize(forged5)["ok"], "land zone with a body rejected")
	# Forgery: a water zone pointing at a missing body.
	var forged6 := snapshot.duplicate(true)
	for zone in forged6["world"]["ranch"]["zones"]:
		if int(zone["body_uid"]) > 0:
			zone["body_uid"] = 4242
	check(not Codec.normalize(forged6)["ok"], "water zone with a missing body rejected")
	# Forgery: a link row pointing at an unknown facility.
	var forged7 := snapshot.duplicate(true)
	var any_link: String = ""
	for key in forged7["world"]["water"]["links"]:
		any_link = String(key)
		break
	if not any_link.is_empty():
		forged7["world"]["water"]["links"]["424242"] = {"body": 1, "day": -1}
		check(not Codec.normalize(forged7)["ok"], "link to an unknown facility rejected")
	else:
		check(false, "no link row to forge against")
