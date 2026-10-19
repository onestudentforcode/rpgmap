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
	_roster_lifecycle(_world())
	_mussel_shell(_world())
	_coral_anchor(_world())
	_survival(_world())
	_water_birth(_world())
	_water_crops(_world())
	_industry(_world())
	_spirit_variants(_world())
	_loach_chain(_world())
	_shared_gu(_world())
	_soothe_water(_world())
	print("P106 MODEL %s (%d)" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _world() -> World:
	var world := World.new(Store.new("res://.art-work/p106-tests/slots-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]))
	world.start_new(1)
	world.grant_scaffold({"twig": 200, "wood_plank": 60, "raw_stone": 120, "raw_wood": 60, "clean_water": 300,
		"algae_feed": 400, "grain": 100, "stone_powder": 200, "water_feed": 100, "humus": 60,
		"water_retaining_matrix": 20, "spirit_liquid": 20, "sludge": 40, "duckweed": 20})
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

# --- stage c: the aquatic roster ----------------------------------------------

## Shared water module builder: one fenced nursery pool plus one fenced
## production/enclosure pool, structural on demand. Layout sits in the owned
## southern water strip (y>=14).
func _water_module(w: World, second_type: String, station_id := "") -> Dictionary:
	w.water.build_fence([Vector2i(2, 14), Vector2i(3, 14), Vector2i(4, 14),
		Vector2i(2, 15), Vector2i(3, 15), Vector2i(4, 15),
		Vector2i(2, 16), Vector2i(3, 16), Vector2i(4, 16),
		Vector2i(2, 17), Vector2i(3, 17), Vector2i(4, 17)], 0)
	w.end_day()
	w.build_facility(Vector2i(2, 14), "pen")
	w.build_facility(Vector2i(2, 16), "feed_trough")
	w.build_facility(Vector2i(3, 16), "small_bed")
	w.build_facility(Vector2i(4, 16), "medium_bed")
	var nursery_cells := []
	for y in range(14, 18):
		for x in range(2, 5):
			nursery_cells.append("%d,%d" % [x, y])
	var nursery: Dictionary = w.ranch.create_zone("water_nursery", nursery_cells, "pool")
	check(nursery["ok"], "water nursery created")
	w.end_day()
	# The second pool: production (with a species station) or an enclosure.
	w.water.build_fence([Vector2i(6, 14), Vector2i(7, 14), Vector2i(8, 14), Vector2i(9, 14),
		Vector2i(6, 15), Vector2i(7, 15), Vector2i(8, 15), Vector2i(9, 15),
		Vector2i(6, 16), Vector2i(7, 16), Vector2i(8, 16), Vector2i(9, 16),
		Vector2i(6, 17), Vector2i(7, 17), Vector2i(8, 17), Vector2i(9, 17)], 0)
	w.build_facility(Vector2i(6, 14), "pen")
	w.build_facility(Vector2i(8, 14), "feed_trough")
	w.build_facility(Vector2i(9, 14), "small_bed")
	w.build_facility(Vector2i(9, 15), "medium_bed")
	if not station_id.is_empty():
		w.build_facility(Vector2i(6, 16), station_id)
	if second_type == "water_enclosure":
		w.build_facility(Vector2i(7, 16), "care_table")
	var pool_cells := []
	for y in range(14, 18):
		for x in range(6, 10):
			pool_cells.append("%d,%d" % [x, y])
	var pool: Dictionary = w.ranch.create_zone(second_type, pool_cells, "pool2")
	check(pool["ok"], "second water zone created")
	return {"nursery": int(nursery["zone_uid"]), "pool": int(pool["zone_uid"])}

func _buy_and_assign(w: World, zones: Dictionary, species_id: String, bed_type: String, count := 1) -> Array:
	check(w.ranch.purchase(zones["nursery"], species_id, count)["ok"], "buy " + species_id)
	for _day in range(8):
		w.end_day()
	var adults: Array = w.ranch.state["animals"].filter(
		func(a): return String(a["species_id"]) == species_id and String(a["stage"]) == "adult")
	check(adults.size() == count, species_id + " adults")
	var assigned := []
	for row in adults:
		var bed: Array = w.ranch.free_bed_slots(w.ranch.zone(zones["pool"]), bed_type)
		check(bed.size() >= 1, "pool bed free for " + species_id)
		var mode := String(w.ranch.zone(zones["pool"])["type"])
		var request := {"mode": mode, "zone_uid": zones["pool"]}
		if not bed_type.is_empty():
			request["bed_uid"] = int(bed[0]["uid"])
			request["bed_slot"] = int(bed[0]["slot"])
		check(w.ranch.submit({"assign": {int(row["uid"]): request}})["ok"], "assign " + species_id)
		w.end_day()
		assigned.append(w.ranch.animal(int(row["uid"])))
	return assigned

func _land_nursery(w: World) -> int:
	for zone_row in w.ranch.state["zones"]:
		if String(zone_row["type"]) == "nursery":
			return int(zone_row["uid"])
	for y in range(11, 14):
		for x in range(16, 20):
			w.rooms.set_floor(Vector2i(x, y), "ordinary")
	w.build_facility(Vector2i(16, 11), "pen")
	w.build_facility(Vector2i(18, 11), "feed_trough")
	w.build_facility(Vector2i(19, 11), "small_bed")
	var cells := []
	for y in range(11, 14):
		for x in range(16, 20):
			cells.append("%d,%d" % [x, y])
	var created: Dictionary = w.ranch.create_zone("nursery", cells, "landref")
	check(created["ok"], "reference land nursery")
	return int(created["zone_uid"])

func _roster_lifecycle(w: World) -> void:
	var zones := _water_module(w, "water_production", "carp_harvest_station")
	# Medium mismatch: the land nursery refuses water species.
	check(not w.ranch.purchase(_land_nursery(w), "filter_algae_carp", 1)["ok"], "land nursery refuses carp")
	var carps := _buy_and_assign(w, zones, "filter_algae_carp", "small")
	check(carps.size() == 1 and String(carps[0]["mode"]) == "water_production", "carp in the production pool")
	# The round runs on the carp station feed and finishes in two care days.
	var carp: Dictionary = carps[0]
	var grain_before := w.inventory.count("grain")
	for _day in range(3):
		w.end_day()
	carp = w.ranch.animal(int(carp["uid"]))
	check(bool(carp["natural"]["pending"]), "carp round completes")
	check(w.inventory.count("grain") == grain_before - 1, "round feed paid once")
	var station_uid := 0
	for uid in w.facilities:
		if String(w.facilities[uid]["facility_id"]) == "carp_harvest_station":
			station_uid = int(uid)
	var meat := w.inventory.count("fish_meat")
	var claim: Dictionary = w.ranch.claim_natural(station_uid)
	check(claim["ok"] and int(claim["captures"]) == 1, "capture claim removes the carp")
	check(w.ranch.animal(int(carp["uid"])).is_empty(), "carp removed from the roster")
	check(w.inventory.count("fish_meat") == meat + 3, "capture pays fish meat")
	# Oilfin: two-space species on a medium bed; its round also removes.
	var oilfins := _buy_and_assign(w, zones, "oilfin_fish", "medium")
	check(oilfins.size() == 1, "oilfin adult")
	w.build_facility(Vector2i(7, 16), "oilfish_harvest_station")
	w.end_day()
	var oilfin: Dictionary = oilfins[0]
	for _day in range(4):
		w.end_day()
	oilfin = w.ranch.animal(int(oilfin["uid"]))
	check(bool(oilfin["natural"]["pending"]), "oilfin round completes")
	var oil_station := 0
	for uid in w.facilities:
		if String(w.facilities[uid]["facility_id"]) == "oilfish_harvest_station":
			oil_station = int(uid)
	var oil := w.inventory.count("crude_oil")
	var oil_claim: Dictionary = w.ranch.claim_natural(oil_station)
	check(oil_claim["ok"] and int(oil_claim["captures"]) == 1, "oilfin capture claim")
	check(w.inventory.count("crude_oil") == oil + 2, "capture pays crude oil")
	# Capture is one-shot: no second claim for the same uid.
	check(not w.ranch.claim_natural(station_uid)["ok"], "no second claim after capture")

func _mussel_shell(w: World) -> void:
	var zones := _water_module(w, "water_production", "pearl_station")
	var mussels := _buy_and_assign(w, zones, "pearl_mussel", "small")
	var mussel: Dictionary = mussels[0]
	for _day in range(5):
		w.end_day()
	mussel = w.ranch.animal(int(mussel["uid"]))
	check(bool(mussel["natural"]["pending"]), "pearl round completes")
	var station_uid := 0
	for uid in w.facilities:
		if String(w.facilities[uid]["facility_id"]) == "pearl_station":
			station_uid = int(uid)
	var pearls := w.inventory.count("pearl")
	var claim: Dictionary = w.ranch.claim_natural(station_uid)
	check(claim["ok"] and int(claim.get("captures", 0)) == 0, "pearl claim keeps the mussel")
	check(w.inventory.count("pearl") == pearls + 2, "pearl claim pays pearls")
	check(not w.ranch.animal(int(mussel["uid"])).is_empty(), "mussel survives the claim")
	# A fresh in-progress round is voided by the shell harvest, no refund.
	for _day in range(2):
		w.end_day()
	var shells := w.inventory.count("mussel_shell")
	var harvest: Dictionary = w.ranch.harvest_shell(int(mussel["uid"]))
	check(harvest["ok"], "shell harvest runs")
	check(w.inventory.count("mussel_shell") == shells + 2, "shell harvest pays shells")
	check(w.ranch.animal(int(mussel["uid"])).is_empty(), "shell harvest removes the mussel")
	check(int(harvest["items"].get("pearl", 0)) == 0, "mid-round harvest carries no pearls")

func _coral_anchor(w: World) -> void:
	var zones := _water_module(w, "water_production", "coral_station")
	var bought: Dictionary = w.ranch.purchase(zones["nursery"], "reef_coral", 2)
	check(bought["ok"], "buy two coral colonies")
	var corals: Array = w.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == "reef_coral")
	check(corals.size() == 2, "two colonies on the roster")
	check(String(corals[0]["anchor"]) != String(corals[1]["anchor"]) and not String(corals[0]["anchor"]).is_empty(),
		"colonies anchor on distinct cells")
	check(int(corals[0]["bed_uid"]) == 0, "coral holds no bed")
	for _day in range(8):
		w.end_day()
	var adults: Array = w.ranch.state["animals"].filter(
		func(a): return String(a["species_id"]) == "reef_coral" and String(a["stage"]) == "adult")
	check(adults.size() == 2, "coral adults")
	var anchor_before := String(adults[0]["anchor"])
	check(w.ranch.submit({"assign": {int(adults[0]["uid"]): {"mode": "water_production", "zone_uid": zones["pool"]}}})["ok"],
		"coral transplants to the production pool")
	w.end_day()
	var moved: Dictionary = w.ranch.animal(int(adults[0]["uid"]))
	check(not moved.is_empty() and String(moved["anchor"]) != anchor_before and not String(moved["anchor"]).is_empty(),
		"transplant picks a fresh anchor in the target pool")
	for _day in range(7):
		w.end_day()
	moved = w.ranch.animal(int(adults[0]["uid"]))
	check(bool(moved["natural"]["pending"]), "coral round completes on its anchor")
	var station_uid := 0
	for uid in w.facilities:
		if String(w.facilities[uid]["facility_id"]) == "coral_station":
			station_uid = int(uid)
	var stones := w.inventory.count("coral_stone")
	var claim: Dictionary = w.ranch.claim_natural(station_uid)
	check(claim["ok"] and w.inventory.count("coral_stone") == stones + 2, "coral claim pays coral stone")
	check(not w.ranch.animal(int(adults[0]["uid"])).is_empty(), "coral survives its claim")

func _survival(w: World) -> void:
	var zones := _water_module(w, "water_production", "gel_station")
	var jellies := _buy_and_assign(w, zones, "gel_jellyfish", "small")
	var jelly: Dictionary = jellies[0]
	var jelly_uid := int(jelly["uid"])
	check(int(jelly["miss_streak"]) == 0 and int(jelly["bad_water_streak"]) == 0, "fresh jellyfish healthy")
	# Starvation: drain the base feed through the flow ledger; three failed
	# maintenance days kill the animal while the water stays clean.
	var algae := w.inventory.count("algae_feed")
	w.inventory.remove("algae_feed", algae)
	w._record_flow({}, {"algae_feed": algae}, "测试排空藻料")
	for _day in range(3):
		w.end_day()
	jelly = w.ranch.animal(jelly_uid)
	if not jelly.is_empty():
		check(int(jelly["miss_streak"]) >= 2, "miss streak climbs while starving")
	for _day in range(2):
		w.end_day()
	check(w.ranch.animal(jelly_uid).is_empty(), "three missed maintenance days kill")
	var deaths := 0
	for entry in receipts:
		if entry.get("kind") == "ranch:animal" and entry.get("stage") == "death":
			deaths += 1
	check(deaths >= 1, "death recorded once with a reason")
	# Recovery: a second jellyfish fed after two missed days resets the streak.
	w.grant_scaffold({"algae_feed": 100})
	check(w.ranch.purchase(zones["nursery"], "gel_jellyfish", 1)["ok"], "buy the recovery jellyfish")
	for _day in range(9):
		w.end_day()
	var adults: Array = w.ranch.state["animals"].filter(
		func(a): return String(a["species_id"]) == "gel_jellyfish" and String(a["stage"]) == "adult")
	check(adults.size() == 1, "recovery jellyfish alive and adult")
	var uid := int(adults[0]["uid"])
	check(w.ranch.submit({"assign": {uid: {"mode": "water_production", "zone_uid": zones["pool"],
		"bed_uid": int(w.ranch.free_bed_slots(w.ranch.zone(zones["pool"]), "small")[0]["uid"]),
		"bed_slot": int(w.ranch.free_bed_slots(w.ranch.zone(zones["pool"]), "small")[0]["slot"])}}})["ok"],
		"recovery jellyfish to the pool")
	w.end_day()
	var drained := w.inventory.count("algae_feed")
	w.inventory.remove("algae_feed", drained)
	w._record_flow({}, {"algae_feed": drained}, "测试再次排空藻料")
	w.end_day()
	w.end_day()
	var row: Dictionary = w.ranch.animal(uid)
	check(not row.is_empty() and int(row["miss_streak"]) == 2, "two missed days climb without killing")
	w.grant_scaffold({"algae_feed": 100})
	w.end_day()
	row = w.ranch.animal(uid)
	check(not row.is_empty() and int(row["miss_streak"]) == 0, "a fed day resets the miss streak")

func _water_birth(w: World) -> void:
	var zones := _water_module(w, "water_enclosure")
	# Water enclosure breeding needs the birth target water nursery.
	check(w.ranch.submit({"birth_targets": {zones["pool"]: zones["nursery"]}})["ok"], "water birth target")
	var jellies := _buy_and_assign(w, zones, "gel_jellyfish", "small")
	check(jellies.size() == 1 and String(w.ranch.animal(int(jellies[0]["uid"]))["mode"]) == "water_enclosure",
		"jellyfish breeding in the enclosure")
	for _day in range(12):
		w.end_day()
	var breeder: Dictionary = w.ranch.animal(int(jellies[0]["uid"]))
	check(bool(breeder["breed"]["pending"]), "breed round completes in the water enclosure")
	var before: int = w.ranch.state["animals"].size()
	check(w.ranch.claim_births(zones["pool"])["ok"], "water births claimed")
	check(w.ranch.state["animals"].size() == before + 1, "one jellyfish child born")
	var children: Array = w.ranch.state["animals"].filter(
		func(a): return int(a["uid"]) != int(jellies[0]["uid"]) and String(a["species_id"]) == "gel_jellyfish")
	check(children.size() == 1 and String(children[0]["mode"]) == "water_nursery"
		and int(children[0]["zone_uid"]) == zones["nursery"], "child lands in the water nursery")

# --- stage d: water crops, industry, spirit variants, loach batches ----------

func _crop_zone(w: World) -> Dictionary:
	w.water.build_fence([Vector2i(2, 14), Vector2i(3, 14), Vector2i(4, 14), Vector2i(5, 14),
		Vector2i(2, 15), Vector2i(3, 15), Vector2i(4, 15), Vector2i(5, 15),
		Vector2i(2, 16), Vector2i(3, 16), Vector2i(4, 16), Vector2i(5, 16)], 0)
	w.end_day()
	w.build_facility(Vector2i(2, 14), "aquatic_crop_station")
	var cells := []
	for y in range(14, 17):
		for x in range(2, 6):
			cells.append("%d,%d" % [x, y])
	var zone: Dictionary = w.ranch.create_zone("aqua_planting", cells, "plants")
	check(zone["ok"] and w.ranch.zone_structural(w.ranch.zone(int(zone["zone_uid"]))), "planting zone structural")
	return zone

func _water_crops(w: World) -> void:
	var zone := _crop_zone(w)
	check(not w.plant(Vector2i(4, 14), "duckweed")["ok"], "planting needs the seed")
	check(w.buy("duckweed_seed", 1)["ok"], "duckweed seed buyable at 2 stones")
	var planted: Dictionary = w.plant(Vector2i(4, 14), "duckweed")
	check(planted["ok"], "duckweed plants on the fence")
	check(not w.plant(Vector2i(4, 14), "reed")["ok"], "one crop per water cell")
	check(not w.plant(Vector2i(4, 13), "duckweed")["ok"], "water crops refuse land")
	var humus_before := w.inventory.count("humus")
	w.end_day()
	var crop: Dictionary = w.instance_at(Vector2i(4, 14))
	check(int(crop["progress"]) == 100 and w.inventory.count("humus") == humus_before - 1, "first day grows and pays the humus round")
	for _day in range(2):
		w.end_day()
	crop = w.instance_at(Vector2i(4, 14))
	check(String(crop["state"]) == "mature", "duckweed matures on day three")
	var duckweed_before := w.inventory.count("duckweed")
	check(w.harvest(Vector2i(4, 14))["ok"], "duckweed harvest runs")
	check(w.inventory.count("duckweed") == duckweed_before + 4, "duckweed pays four per tap")
	crop = w.instance_at(Vector2i(4, 14))
	check(String(crop["state"]) == "regrowing", "duckweed regrows after the tap")
	var matrix_before := w.inventory.count("water_retaining_matrix")
	var humus_at_round := w.inventory.count("humus")
	check(w.set_water_round_input(Vector2i(4, 14), "matrix_round")["ok"], "round input switches to the matrix")
	w.end_day()
	crop = w.instance_at(Vector2i(4, 14))
	check(String(crop["state"]) == "mature", "one regrow day with the matrix")
	check(w.inventory.count("humus") == humus_at_round, "matrix round skips the humus")
	# Taps run out at six, then the plot clears for replanting.
	for tap in range(5):
		if String(w.instance_at(Vector2i(4, 14))["state"]) == "mature":
			check(w.harvest(Vector2i(4, 14))["ok"], "duckweed tap %d" % tap)
		w.end_day()
	check(not w.harvest(Vector2i(4, 14))["ok"], "sixth round refuses further taps")
	check(w.clear_crop(Vector2i(4, 14))["ok"], "exhausted duckweed clears")
	check(w.instance_at(Vector2i(4, 14)).is_empty(), "cleared cell replants")

func _industry(w: World) -> void:
	w.grant_scaffold({"fish_meat": 10, "mussel_shell": 4, "coral_stone": 4, "charcoal": 2,
		"wastewater": 12, "filter_media": 2, "pearl": 2, "water_gel": 2, "humus": 4, "reed_stalk": 4})
	var processor := 0
	var woodshop_uid := 0
	var bed := 0
	check(w.build_facility(Vector2i(2, 4), "farm_processor")["ok"], "processor builds")
	check(w.build_facility(Vector2i(5, 4), "woodshop")["ok"], "woodshop builds")
	check(w.build_facility(Vector2i(8, 4), "purifying_bed")["ok"], "purifying bed builds")
	for uid in w.facilities:
		var fid := String(w.facilities[uid]["facility_id"])
		if fid == "farm_processor":
			processor = int(uid)
		elif fid == "woodshop":
			woodshop_uid = int(uid)
		elif fid == "purifying_bed":
			bed = int(uid)
	for spec in [["dry_fish_meal", processor], ["grind_shell", processor], ["make_water_retaining_matrix", processor],
			["make_coral_filter_media", woodshop_uid], ["pearl_polish_water", bed]]:
		var recipe_id := String(spec[0])
		var carrier := int(spec[1])
		var started: Dictionary = w.start_batch(carrier, recipe_id)
		check(started["ok"], recipe_id + " starts")
		for _day in range(2):
			w.end_day()
		var batch: Dictionary = w.facilities[carrier]["batch"]
		if String(batch.get("status", "")) == "ready":
			check(w.claim_batch(carrier, int(batch["batch_id"]))["ok"], recipe_id + " claims")
		else:
			check(false, recipe_id + " completes")
	check(w.inventory.count("fish_meal") >= 3, "fish meal produced")
	check(w.inventory.count("stone_powder") >= 2, "shell grinding pays powder")
	check(w.inventory.count("water_retaining_matrix") >= 4, "matrix produced")
	check(w.inventory.count("filter_media") >= 4, "coral filter media produced")
	check(w.inventory.count("clean_water") > 0, "pearl polish pays clean water")

func _spirit_variants(w: World) -> void:
	var zones := _water_module(w, "water_production", "pearl_station")
	var mussels := _buy_and_assign(w, zones, "pearl_mussel", "small")
	var mussel: Dictionary = mussels[0]
	check(w.ranch.set_natural_diet(int(mussel["uid"]), "pearl_spirit_round")["ok"], "spirit round diet chosen")
	for _day in range(5):
		w.end_day()
	mussel = w.ranch.animal(int(mussel["uid"]))
	check(bool(mussel["natural"]["pending"]), "spirit round completes")
	check(String(mussel["natural"]["paid_diet"]) == "pearl_spirit_round", "paid diet locked on the round")
	var station_uid := 0
	for uid in w.facilities:
		if String(w.facilities[uid]["facility_id"]) == "pearl_station":
			station_uid = int(uid)
	var pearls := w.inventory.count("pearl")
	var claim: Dictionary = w.ranch.claim_natural(station_uid)
	check(claim["ok"], "spirit claim runs")
	check(w.inventory.count("pearl") == pearls + 3, "spirit round pays three pearls")
	check(String(w.ranch.animal(int(mussel["uid"]))["natural"]["paid_diet"]) == "", "paid diet resets with the round")

func _loach_chain(w: World) -> void:
	var zones := _water_module(w, "water_loach", "silt_processing_station")
	check(w.ranch.purchase(zones["nursery"], "silt_loach", 1)["ok"], "buy the loach")
	for _day in range(8):
		w.end_day()
	var adults: Array = w.ranch.state["animals"].filter(func(a): return String(a["stage"]) == "adult")
	check(adults.size() == 1, "loach adult")
	var yard := 0
	for uid in w.facilities:
		if String(w.facilities[uid]["facility_id"]) == "silt_processing_station":
			yard = int(uid)
	check(w.ranch.set_recipe(yard, "silt_process")["ok"], "silt recipe set")
	var beds: Array = w.ranch.free_bed_slots(w.ranch.zone(zones["pool"]), "small")
	check(w.ranch.submit({"assign": {int(adults[0]["uid"]): {"mode": "water_loach", "zone_uid": zones["pool"],
		"bed_uid": int(beds[0]["uid"]), "bed_slot": int(beds[0]["slot"])}}})["ok"], "loach assigned")
	w.end_day()
	w.grant_scaffold({"sludge": 10, "duckweed": 5})
	var body: Dictionary = w.water.body_of(Vector2i(6, 14))
	var quality_before := int(body["quality"])
	var sludge_before := w.inventory.count("sludge")
	for _day in range(3):
		w.end_day()
	check(sludge_before - w.inventory.count("sludge") >= 2, "batch paid its sludge and duckweed")
	var claimed: Dictionary = w.ranch.claim_workyard(yard)
	check(claimed["ok"], "loach batch claims")
	check(w.inventory.count("humus") >= 3, "loach batch pays humus")
	var purified := 0
	for entry in receipts:
		if entry.get("kind") == "water" and entry.get("stage") == "loach_purify":
			purified += 1
	check(purified == 1, "one purification per finished batch")
	check(int(body["quality"]) > quality_before or purified == 1, "body improved by the batch")


# --- stage e: the shared gu -----------------------------------------------------

func _instance_of(w: World, definition_id: String) -> String:
	for row in w.logistics.state["instances"]:
		if String(row["definition_id"]) == definition_id and int(row["host_uid"]) == 0:
			return String(row["instance_id"])
	return ""

func _shared_gu(w: World) -> void:
	var zones := _water_module(w, "water_production", "carp_harvest_station")
	# The market path: both new gu cost 32 stones and never ride the provision.
	var stones := w.primeval_stones
	var bought: Dictionary = w.logistics.buy_gu("product_yield_gu")
	check(bought["ok"] and w.primeval_stones == stones - 32, "product gu bought at 32 stones")
	var feed_bought: Dictionary = w.logistics.buy_gu("feed_saving_gu")
	check(feed_bought["ok"], "feed gu bought")
	check(w.logistics.provision()["ok"], "trial provision still grants")
	var soothe_id := _instance_of(w, "soothe_gu")
	check(not soothe_id.is_empty(), "provision carries a soothe trial")
	# Feed saving on the nursery trough: four one-unit meals pay 1,1,1,0.
	var trough := 0
	for uid in w.facilities:
		if String(w.facilities[uid]["facility_id"]) == "feed_trough" and Vector2i(int(w.facilities[uid]["origin"][0]), int(w.facilities[uid]["origin"][1])) == Vector2i(2, 16):
			trough = int(uid)
	check(w.logistics.deploy(String(feed_bought["instance_id"]), Vector2i(-1, -1), trough)["ok"], "feed gu deployed on the trough")
	# deploy() enables the instance effective next day.
	w.end_day()
	check(w.ranch.purchase(zones["nursery"], "filter_algae_carp", 1)["ok"], "buy the saving carp")
	for _day in range(2):
		w.end_day()
	var algae := w.inventory.count("algae_feed")
	for _day in range(4):
		w.end_day()
	check(w.inventory.count("algae_feed") == algae - 3, "four meals pay three with the feed gu")
	var saving_events := 0
	for entry in receipts:
		if entry.get("kind") == "ranch:feed" and entry.get("stage") == "saving":
			saving_events += 1
	check(saving_events >= 1, "feed saving receipts recorded")
	# Yield boost: the product gu on the carp station boosts only the main
	# product, with the remainder drawn once at the claim.
	var adults: Array = w.ranch.state["animals"].filter(func(a): return String(a["stage"]) == "adult")
	check(adults.size() == 1, "saving carp adult")
	var station_uid := 0
	for uid in w.facilities:
		if String(w.facilities[uid]["facility_id"]) == "carp_harvest_station":
			station_uid = int(uid)
	check(w.logistics.deploy(String(bought["instance_id"]), Vector2i(-1, -1), station_uid)["ok"], "product gu deployed on the station")
	var bed: Array = w.ranch.free_bed_slots(w.ranch.zone(zones["pool"]), "small")
	check(w.ranch.submit({"assign": {int(adults[0]["uid"]): {"mode": "water_production", "zone_uid": zones["pool"],
		"bed_uid": int(bed[0]["uid"]), "bed_slot": int(bed[0]["slot"])}}})["ok"], "saving carp to the pool")
	for _day in range(4):
		w.end_day()
	var carp: Dictionary = w.ranch.animal(int(adults[0]["uid"]))
	check(bool(carp["natural"]["pending"]) and int(carp["natural"]["boost"]) == 1200 * 25, "full coverage banks the boost")
	var manure := w.inventory.count("fish_manure")
	var claim: Dictionary = w.ranch.claim_natural(station_uid)
	check(claim["ok"] and int(claim["captures"]) == 1, "boosted capture claim")
	check(w.inventory.count("fish_manure") == manure + 1, "the byproduct never boosts")
	var draw := preload("res://scripts/farming/p8/p102_rooms.gd").draw(int(w.services.state["random_seed"]),
		"yield:%d" % int(adults[0]["uid"]), 0, "main") % (100 * 1200)
	var expected_extra := 1 if draw < 3 * 1200 * 25 % (100 * 1200) else 0
	if 3 * 1200 * 25 < 100 * 1200:
		expected_extra = (3 * 1200 * 25 / (100 * 1200)) + (1 if draw < 3 * 1200 * 25 % (100 * 1200) else 0)
	check(int(claim["items"].get("fish_meat", 0)) == 3 + expected_extra, "main product pays base plus the drawn boost")
	# Capability tags: the provisioned soothe gu serves a WATER enclosure from
	# a soothing station built on the fence itself.
	check(w.build_facility(Vector2i(8, 16), "soothing_station")["ok"], "soothing station builds on water")
	var soothe_host := 0
	for uid in w.facilities:
		if String(w.facilities[uid]["facility_id"]) == "soothing_station":
			soothe_host = int(uid)
	check(w.logistics.deploy(soothe_id, Vector2i(-1, -1), soothe_host)["ok"], "soothe gu deployed on the water host")
	w.end_day()

func _soothe_water(w: World) -> void:
	# Capability tags (§16.2.10): the same soothe gu instance serves a water
	# enclosure from a soothing station standing on the fence.
	var zones := _water_module(w, "water_enclosure")
	check(w.build_facility(Vector2i(8, 16), "soothing_station")["ok"], "soothing station builds on the fence")
	check(w.logistics.provision()["ok"], "trial provision")
	var soothe_id := _instance_of(w, "soothe_gu")
	var host := 0
	for uid in w.facilities:
		if String(w.facilities[uid]["facility_id"]) == "soothing_station":
			host = int(uid)
	check(w.logistics.deploy(soothe_id, Vector2i(-1, -1), host)["ok"], "soothe deployed on the water host")
	var jellies := _buy_and_assign(w, zones, "gel_jellyfish", "small")
	check(jellies.size() == 1, "soothed jellyfish adult")
	for _day in range(3):
		w.end_day()
	var boosted := 0
	for entry in receipts:
		if entry.get("kind") == "service" and entry.get("stage") == "gu_service" and entry.get("effect") == "breed_speed":
			if int(entry.get("animal", 0)) == int(jellies[0]["uid"]):
				boosted += 1
	check(boosted > 0, "the soothe gu serves the water jellyfish")
	var breeder: Dictionary = w.ranch.animal(int(jellies[0]["uid"]))
	check(int(breeder["breed"]["units"]) > 6 * 3 * 100, "water breeding advances at the boosted pace")
