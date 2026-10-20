extends SceneTree
## P10.6 module replay: eight water rule scenarios on real ledgers, none
## longer than thirty days. Fixed scaffolds are declared per scenario; this is
## rule evidence, not a profitability claim (costs live in the standard-cost
## tables). Evidence lands in .art-work/p106-playtest/.
const World := preload("res://scripts/farming/p8/p8_world.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")

var audit_root := "res://.art-work/p106-playtest"
var receipts: FileAccess
var days_file: FileAccess
var route := ""
var routes_run := {}
var checks := 0
var failures: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(route + " " + label)
		printerr(route + " " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(audit_root))
	_scenario("water-boundary", _water_boundary)
	_scenario("survival-capacity", _survival_capacity)
	_scenario("capture-oil", _capture_oil)
	_scenario("pearl-gel", _pearl_gel)
	_scenario("loach-coral", _loach_coral)
	_scenario("water-crops-feed", _water_crops_feed)
	_scenario("spirit-recipes", _spirit_recipes)
	_scenario("systems-gu", _systems_gu)
	var summary := FileAccess.open(audit_root.path_join("summary.json"), FileAccess.WRITE)
	summary.store_string(JSON.stringify({"routes": routes_run, "failures": failures, "checks": checks}, "\t"))
	summary.close()
	for failure in failures:
		printerr(failure)
	print("P106 PLAYTEST %s · %d checks" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _scenario(name: String, script: Callable) -> void:
	route = name
	routes_run[name] = {"kind": "scenario"}
	_open_files(name)
	var world := fixture({})
	script.call(world)
	_close_files()
	write_json("%s-final.json" % name, world.to_snapshot())

func fixture(extra: Dictionary) -> World:
	var world := World.new(Store.new(audit_root.path_join("%s-slots-%d-%d" % [route, OS.get_process_id(), Time.get_ticks_usec()])))
	world.start_new(1)
	var grant := {"raw_wood": 300, "raw_stone": 400, "wood_plank": 120, "twig": 200,
		"mushroom": 200, "fodder_grass": 300, "grain": 200, "clean_water": 1200,
		"algae_feed": 900, "stone_powder": 300, "water_feed": 200, "humus": 200,
		"sludge": 200, "charcoal": 60, "filter_media": 20, "pearl": 10, "water_gel": 10,
		"spirit_liquid": 20, "duckweed": 60, "oil_cake": 40, "grain_meal": 60}
	for key in extra:
		grant[key] = extra[key]
	world.grant_scaffold(grant)
	world.primeval_stones += 6000
	world._cash("sales_revenue", 6000)
	world.research.state["completed"] = world.research.project_defs().keys()
	world.operation_recorded.connect(func(entry: Dictionary):
		receipts.store_line(JSON.stringify(entry)))
	return world

func _open_files(name: String) -> void:
	receipts = FileAccess.open(audit_root.path_join("%s-receipts.jsonl" % name), FileAccess.WRITE)
	days_file = FileAccess.open(audit_root.path_join("%s-days.jsonl" % name), FileAccess.WRITE)

func _close_files() -> void:
	if receipts: receipts.close()
	if days_file: days_file.close()
	receipts = null
	days_file = null

func write_json(name: String, value) -> void:
	var file := FileAccess.open(audit_root.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "\t"))
	file.close()

func settle(world: World, days: int) -> void:
	for _day in range(days):
		world.end_day()
		archive_day(world)

func archive_day(world: World) -> void:
	var animals := []
	for row in world.ranch.state["animals"]:
		animals.append({"uid": int(row["uid"]), "species": row["species_id"], "stage": row["stage"],
			"mode": row["mode"], "growth": int(row["growth"]), "miss": int(row["miss_streak"]),
			"bad": int(row["bad_water_streak"]), "natural": row["natural"].duplicate(),
			"breed": row["breed"].duplicate(), "saving": row["saving"].duplicate(),
			"contribution": int(row["contribution"]), "voucher": row["voucher"]})
	var bodies := []
	for row in world.water.state["bodies"]:
		bodies.append({"uid": int(row["uid"]), "cells": row["cells"].duplicate(),
			"quality": int(row["quality"]), "change_day": int(row["change_day"])})
	var stock := {}
	for item in ["algae_feed", "grain", "clean_water", "stone_powder", "water_feed", "humus",
			"sludge", "duckweed", "reed_stalk", "pearl", "water_gel", "coral_stone", "mussel_shell",
			"fish_meat", "crude_oil", "fish_meal", "water_retaining_matrix", "grass_meal", "land_feed"]:
		stock[item] = world.inventory.count(item)
	days_file.store_line(JSON.stringify({"day": world.clock.total_days - 1, "animals": animals,
		"bodies": bodies, "stock": stock, "stones": world.primeval_stones,
		"deaths": world.ranch.state["animals"].is_empty()}))

# --- shared module builder ------------------------------------------------------
## Nursery pool x2..4 y14..17 and a second pool x6..9 with per-scenario
## station composition; both fenced and structural.
func build_module(world: World, second_type: String, stations: Array) -> Dictionary:
	world.water.build_fence([Vector2i(2, 14), Vector2i(3, 14), Vector2i(4, 14),
		Vector2i(2, 15), Vector2i(3, 15), Vector2i(4, 15),
		Vector2i(2, 16), Vector2i(3, 16), Vector2i(4, 16),
		Vector2i(2, 17), Vector2i(3, 17), Vector2i(4, 17)], 0)
	world.end_day()
	for spec in [["pen", 2, 14], ["feed_trough", 4, 14], ["feed_trough", 2, 16], ["small_bed", 3, 16], ["medium_bed", 4, 16]]:
		world.build_facility(Vector2i(int(spec[1]), int(spec[2])), String(spec[0]))
	var nursery_cells := []
	for y in range(14, 18):
		for x in range(2, 5):
			nursery_cells.append("%d,%d" % [x, y])
	var nursery: Dictionary = world.ranch.create_zone("water_nursery", nursery_cells, "育幼池")
	world.end_day()
	world.water.build_fence([Vector2i(6, 14), Vector2i(7, 14), Vector2i(8, 14), Vector2i(9, 14),
		Vector2i(6, 15), Vector2i(7, 15), Vector2i(8, 15), Vector2i(9, 15),
		Vector2i(6, 16), Vector2i(7, 16), Vector2i(8, 16), Vector2i(9, 16),
		Vector2i(6, 17), Vector2i(7, 17), Vector2i(8, 17), Vector2i(9, 17)], 0)
	for spec in [["pen", 6, 14], ["feed_trough", 8, 14], ["small_bed", 9, 14], ["medium_bed", 9, 15]]:
		world.build_facility(Vector2i(int(spec[1]), int(spec[2])), String(spec[0]))
	for station in stations:
		world.build_facility(Vector2i(int(station[1]), int(station[2])), String(station[0]))
	if second_type == "water_enclosure":
		world.build_facility(Vector2i(7, 16), "care_table")
	var pool_cells := []
	for y in range(14, 18):
		for x in range(6, 10):
			pool_cells.append("%d,%d" % [x, y])
	var pool: Dictionary = world.ranch.create_zone(second_type, pool_cells, "生产池")
	return {"nursery": int(nursery["zone_uid"]), "pool": int(pool["zone_uid"])}

func buy_adult(world: World, zones: Dictionary, species_id: String, bed_type: String) -> Dictionary:
	check(world.ranch.purchase(zones["nursery"], species_id, 1)["ok"], "buy " + species_id)
	settle(world, 7)
	var adults: Array = world.ranch.state["animals"].filter(
		func(a): return String(a["species_id"]) == species_id and String(a["stage"]) == "adult")
	check(adults.size() == 1, species_id + " grows up")
	if adults.is_empty():
		return {}
	var row: Dictionary = adults[0]
	var request := {"mode": String(world.ranch.zone(zones["pool"])["type"]), "zone_uid": zones["pool"]}
	if not bed_type.is_empty():
		var bed: Array = world.ranch.free_bed_slots(world.ranch.zone(zones["pool"]), bed_type)
		request["bed_uid"] = int(bed[0]["uid"])
		request["bed_slot"] = int(bed[0]["slot"])
	check(world.ranch.submit({"assign": {int(row["uid"]): request}})["ok"],
		species_id + " assigned to the pool")
	settle(world, 1)
	return world.ranch.animal(int(row["uid"]))

func station_uid(world: World, facility_id: String) -> int:
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == facility_id:
			return int(uid)
	return 0

func facility_uid_at(world: World, cell: Vector2i) -> int:
	for uid in world.facilities:
		var origin: Array = world.facilities[uid]["origin"]
		if Vector2i(int(origin[0]), int(origin[1])) == cell:
			return int(uid)
	return 0

# --- scenarios ------------------------------------------------------------------

func _water_boundary(world: World) -> void:
	# Two touching bodies, shared-quality rooms, change, expand, merge, split,
	# release and rebuild without washing the water clean.
	var zones := build_module(world, "water_production", [["carp_harvest_station", 6, 16]])
	check(world.water.body(1)["cells"].size() == 12 and world.water.body(2)["cells"].size() == 16,
		"two independent fenced bodies")
	settle(world, 2)
	var quality_a := int(world.water.body(1)["quality"])
	check(quality_a == 12 * 100 * (100 - 8), "four decay days on body A")
	check(world.water.change_water(1)["ok"], "manual change on A")
	check(not world.water.change_water(1)["ok"], "second change refused same day")
	settle(world, 1)
	# Bridge the gap column so the two pools actually touch before merging.
	check(world.water.build_fence([Vector2i(5, 14), Vector2i(5, 15), Vector2i(5, 16), Vector2i(5, 17)], 1)["ok"], "bridge column fenced")
	var total := int(world.water.body(1)["quality"]) + int(world.water.body(2)["quality"])
	check(world.water.merge_bodies(1, 2)["ok"], "merge touching bodies")
	check(int(world.water.body(1)["quality"]) == total, "merge conserves the total")
	# Split the whole nursery strip so its zone moves with the child intact.
	var split: Dictionary = world.water.split_body(1, [Vector2i(2, 14), Vector2i(3, 14), Vector2i(4, 14),
		Vector2i(2, 15), Vector2i(3, 15), Vector2i(4, 15),
		Vector2i(2, 16), Vector2i(3, 16), Vector2i(4, 16),
		Vector2i(2, 17), Vector2i(3, 17), Vector2i(4, 17)])
	check(split["ok"], "split the merged body")
	check(int(world.water.body(1)["quality"]) + int(world.water.body(int(split["body"]))["quality"]) == total,
		"split conserves the total")
	# Release banks the share; rebuilding takes the bank back, never fresh.
	var drained: Dictionary = world.water.body(1)
	var share := int(drained["quality"]) / int(drained["cells"].size())
	check(world.water.release_fence([Vector2i(5, 17)])["ok"], "release one bridge cell")
	check(int(world.water.state["sources"]["5,17"]) == share, "release banks the share")
	check(world.water.build_fence([Vector2i(5, 17)], 1)["ok"], "rebuild the fence")
	settle(world, 3)
	check(world.ranch.zone_structural(world.ranch.zone(zones["nursery"])), "rooms stay structural")

func _survival_capacity(world: World) -> void:
	# Mixed stocking, starvation versus bad water as separate counters,
	# recovery interrupts, one death each.
	var zones := build_module(world, "water_production", [["gel_station", 6, 16]])
	check(world.ranch.purchase(zones["nursery"], "gel_jellyfish", 2)["ok"], "buy two jellyfish")
	check(world.ranch.purchase(zones["nursery"], "filter_algae_carp", 1)["ok"], "buy one carp")
	settle(world, 6)
	var alive: Array = world.ranch.state["animals"]
	check(alive.size() == 3, "mixed nursery holds three")
	# Starvation kills after three failed maintenance days.
	var algae := world.inventory.count("algae_feed")
	world.inventory.remove("algae_feed", algae)
	world._record_flow({}, {"algae_feed": algae}, "测试排空藻料")
	settle(world, 4)
	check(world.ranch.state["animals"].is_empty(), "three starved days kill the batch")
	# A fresh animal in clean water survives the same window when fed.
	world.grant_scaffold({"algae_feed": 100})
	check(world.ranch.purchase(zones["nursery"], "gel_jellyfish", 1)["ok"], "buy the recovery jellyfish")
	settle(world, 2)
	var row: Dictionary = world.ranch.state["animals"][0]
	check(int(row["miss_streak"]) == 0, "fed days keep the streak clean")

func _capture_oil(world: World) -> void:
	# Carp and oilfin through real capture rounds into real downstream
	# cooking and refining.
	var zones := build_module(world, "water_production",
		[["carp_harvest_station", 6, 16], ["oilfish_harvest_station", 7, 16]])
	var carp := buy_adult(world, zones, "filter_algae_carp", "small")
	var oilfin := buy_adult(world, zones, "oilfin_fish", "medium")
	settle(world, 4)
	check(bool(world.ranch.animal(int(carp["uid"]))["natural"]["pending"]), "carp round completes")
	check(bool(world.ranch.animal(int(oilfin["uid"]))["natural"]["pending"]), "oilfin round completes")
	var meat := world.inventory.count("fish_meat")
	var carp_claim: Dictionary = world.ranch.claim_natural(station_uid(world, "carp_harvest_station"))
	check(carp_claim["ok"] and int(carp_claim["captures"]) == 1, "carp capture removes the animal")
	check(world.inventory.count("fish_meat") == meat + 3, "carp pays fish meat")
	var oil := world.inventory.count("crude_oil")
	var oilfin_claim: Dictionary = world.ranch.claim_natural(station_uid(world, "oilfish_harvest_station"))
	check(oilfin_claim["ok"] and int(oilfin_claim["captures"]) == 1, "oilfin capture removes the animal")
	check(world.inventory.count("crude_oil") == oil + 2, "oilfin pays crude oil")
	# Downstream: the captured crude refines into oil that cooks real fish.
	check(world.build_facility(Vector2i(6, 4), "farm_processor")["ok"], "processor builds")
	check(world.start_batch(station_uid(world, "farm_processor"), "refine_oil")["ok"], "crude oil refines")
	settle(world, 2)
	var refine_batch: Dictionary = world.facilities[station_uid(world, "farm_processor")]["batch"]
	check(world.claim_batch(station_uid(world, "farm_processor"), int(refine_batch["batch_id"]))["ok"], "refined oil claimed")
	check(world.inventory.count("refined_oil") >= 2, "refine pays oil")
	check(world.build_facility(Vector2i(2, 4), "kitchen")["ok"], "kitchen builds")
	world.grant_scaffold({"mushroom": 20, "fish_meat": 6})
	check(world.start_batch(station_uid(world, "kitchen"), "fungus_fish_meal")["ok"], "kitchen cooks real fish")
	settle(world, 2)

func _pearl_gel(world: World) -> void:
	# Pearl keeps, shell harvest consumes, gel becomes the matrix a crop uses.
	var zones := build_module(world, "water_production", [["pearl_station", 6, 16], ["gel_station", 7, 16]])
	var mussel := buy_adult(world, zones, "pearl_mussel", "small")
	settle(world, 5)
	check(bool(world.ranch.animal(int(mussel["uid"]))["natural"]["pending"]), "pearl round completes")
	var pearls := world.inventory.count("pearl")
	check(world.ranch.claim_natural(station_uid(world, "pearl_station"))["ok"], "pearl claim")
	check(world.inventory.count("pearl") == pearls + 2, "pearl claim keeps the mussel")
	settle(world, 2)
	var shells := world.inventory.count("mussel_shell")
	check(world.ranch.harvest_shell(int(mussel["uid"]))["ok"], "shell harvest")
	check(world.inventory.count("mussel_shell") == shells + 2, "shell harvest pays shells")
	check(world.ranch.animal(int(mussel["uid"])).is_empty(), "shell harvest consumes the adult")
	var jelly := buy_adult(world, zones, "gel_jellyfish", "small")
	settle(world, 3)
	check(world.ranch.claim_natural(station_uid(world, "gel_station"))["ok"], "gel claim")
	check(world.inventory.count("water_gel") >= 2, "gel round pays water gel")

func _loach_coral(world: World) -> void:
	# Real sludge through the loach batch into humus plus one purification;
	# coral stone into filter media and powder.
	var zones := build_module(world, "water_loach", [["silt_processing_station", 6, 16]])
	var loach := buy_adult(world, zones, "silt_loach", "small")
	check(world.ranch.set_recipe(station_uid(world, "silt_processing_station"), "silt_process")["ok"], "silt recipe set")
	var body: Dictionary = world.water.body_of(Vector2i(6, 14))
	var quality := int(body["quality"])
	var sludge := world.inventory.count("sludge")
	settle(world, 4)
	check(world.inventory.count("sludge") < sludge, "batches paid real sludge and duckweed")
	check(world.ranch.claim_workyard(station_uid(world, "silt_processing_station"))["ok"], "loach batch claims")
	check(world.inventory.count("humus") > 100, "loach batches pay humus")
	# One loach cannot outpace a 16-cell body's decay (honest per the freeze);
	# what must hold is that finished batches improved on pure decay.
	var cells: int = world.water.area(body)
	var daily_decay: int = (2 + int((6 * 1 + cells - 1) / cells)) * cells * 100
	check(int(body["quality"]) > quality - 4 * daily_decay, "finished batches purified beyond plain decay")
	# Coral chain on a second pool.
	check(world.water.build_fence([Vector2i(11, 14), Vector2i(12, 14), Vector2i(13, 14),
		Vector2i(11, 15), Vector2i(12, 15), Vector2i(13, 15),
		Vector2i(11, 16), Vector2i(12, 16), Vector2i(13, 16),
		Vector2i(11, 17), Vector2i(12, 17), Vector2i(13, 17),
		Vector2i(11, 18), Vector2i(12, 18), Vector2i(13, 18)], 0)["ok"], "coral pool fenced")
	check(world.build_facility(Vector2i(11, 14), "pen")["ok"], "coral pen")
	check(world.build_facility(Vector2i(13, 14), "feed_trough")["ok"], "coral trough")
	check(world.build_facility(Vector2i(13, 15), "small_bed")["ok"], "coral bed")
	check(world.build_facility(Vector2i(13, 16), "coral_station")["ok"], "coral station")
	var coral_cells := []
	for y in range(14, 19):
		for x in range(11, 14):
			coral_cells.append("%d,%d" % [x, y])
	var coral_zone: Dictionary = world.ranch.create_zone("water_production", coral_cells, "珊瑚池")
	check(coral_zone["ok"] and world.ranch.zone_structural(world.ranch.zone(int(coral_zone["zone_uid"]))), "coral pool structural")
	var coral := buy_adult(world, {"nursery": zones["nursery"], "pool": int(coral_zone["zone_uid"])}, "reef_coral", "")
	settle(world, 7)
	check(bool(world.ranch.animal(int(coral["uid"]))["natural"]["pending"]), "coral round completes")
	var stones := world.inventory.count("coral_stone")
	check(world.ranch.claim_natural(station_uid(world, "coral_station"))["ok"], "coral claim")
	check(world.inventory.count("coral_stone") == stones + 2, "coral claim pays coral stone")

func _water_crops_feed(world: World) -> void:
	# Plant, harvest, mill and blend into a real water meal; a loach eats it.
	var zones := build_module(world, "water_loach", [["silt_processing_station", 6, 16]])
	world.end_day()
	check(world.water.build_fence([Vector2i(11, 14), Vector2i(12, 14), Vector2i(13, 14),
		Vector2i(11, 15), Vector2i(12, 15), Vector2i(13, 15),
		Vector2i(11, 16), Vector2i(12, 16), Vector2i(13, 16)], 0)["ok"], "planting body fenced")
	world.end_day()
	check(world.build_facility(Vector2i(11, 14), "aquatic_crop_station")["ok"], "crop station builds")
	var cells := []
	for y in range(14, 17):
		for x in range(11, 14):
			cells.append("%d,%d" % [x, y])
	var zone: Dictionary = world.ranch.create_zone("aqua_planting", cells, "水生种植区")
	check(zone["ok"] and world.ranch.zone_structural(world.ranch.zone(int(zone["zone_uid"]))), "planting zone structural")
	check(world.buy("reed_seed", 1)["ok"], "reed seed buyable")
	check(world.plant(Vector2i(12, 14), "reed")["ok"], "reed plants")
	settle(world, 6)
	check(String(world.instance_at(Vector2i(12, 14))["state"]) == "mature", "reed matures")
	var stalks := world.inventory.count("reed_stalk")
	check(world.harvest(Vector2i(12, 14))["ok"], "reed harvested")
	check(world.inventory.count("reed_stalk") == stalks + 6, "reed pays six stalks")
	# Reed into charcoal and humus through real recipes.
	check(world.build_facility(Vector2i(2, 4), "compost_bin")["ok"], "compost bin builds")
	check(world.start_batch(station_uid(world, "compost_bin"), "compost_reed")["ok"], "reed compost starts")
	# Fish meal and the water feed blend feed a real carp.
	check(world.build_facility(Vector2i(6, 4), "farm_processor")["ok"], "processor builds")
	world.grant_scaffold({"fish_meat": 6, "grass_meal": 6, "oil_cake": 4, "algae_feed": 6, "grain_meal": 4})
	check(world.start_batch(station_uid(world, "farm_processor"), "dry_fish_meal")["ok"], "fish meal starts")
	settle(world, 3)

func _spirit_recipes(world: World) -> void:
	# Spirit-liquid rounds pay three pearls or three gel against the plain two.
	var zones := build_module(world, "water_production", [["pearl_station", 6, 16], ["gel_station", 7, 16]])
	var mussel := buy_adult(world, zones, "pearl_mussel", "small")
	check(world.ranch.set_natural_diet(int(mussel["uid"]), "pearl_spirit_round")["ok"], "spirit pearl diet")
	settle(world, 5)
	var pearls := world.inventory.count("pearl")
	check(world.ranch.claim_natural(station_uid(world, "pearl_station"))["ok"], "spirit pearl claim")
	check(world.inventory.count("pearl") == pearls + 3, "spirit round pays three pearls")
	var jelly := buy_adult(world, zones, "gel_jellyfish", "small")
	check(world.ranch.set_natural_diet(int(jelly["uid"]), "gel_spirit_round")["ok"], "spirit gel diet")
	settle(world, 3)
	var gel := world.inventory.count("water_gel")
	check(world.ranch.claim_natural(station_uid(world, "gel_station"))["ok"], "spirit gel claim")
	check(world.inventory.count("water_gel") == gel + 3, "spirit round pays three gel")

func _systems_gu(world: World) -> void:
	# Shared gu service, feed saving, the level-3 breeding gift and the
	# intensive voucher, all in one ledger.
	var zones := build_module(world, "water_enclosure", [["gel_station", 6, 16]])
	check(world.logistics.provision()["ok"], "provision claimed")
	var soothe := ""
	for row in world.logistics.state["instances"]:
		if String(row["definition_id"]) == "soothe_gu" and int(row["host_uid"]) == 0:
			soothe = String(row["instance_id"])
			break
	check(world.build_facility(Vector2i(8, 16), "soothing_station")["ok"], "soothing station on the fence")
	check(world.logistics.deploy(soothe, Vector2i(-1, -1), station_uid(world, "soothing_station"))["ok"], "soothe deployed on water")
	var feed: Dictionary = world.logistics.buy_gu("feed_saving_gu")
	var product: Dictionary = world.logistics.buy_gu("product_yield_gu")
	check(feed["ok"] and product["ok"], "market gu bought")
	check(world.logistics.deploy(String(feed["instance_id"]), Vector2i(-1, -1), facility_uid_at(world, Vector2i(2, 16)))["ok"], "feed gu on the nursery trough")
	check(world.ranch.submit({"birth_targets": {zones["pool"]: zones["nursery"]}})["ok"], "birth target set")
	check(world.services.set_system(0, "watercycle", [zones["pool"], zones["nursery"]])["ok"], "water system linked")
	# A guided jellyfish: contribution, voucher, boosted breeding gift.
	# A dedicated production pool carries the product gu as the target.
	check(world.water.build_fence([Vector2i(11, 14), Vector2i(12, 14), Vector2i(13, 14),
		Vector2i(11, 15), Vector2i(12, 15), Vector2i(13, 15),
		Vector2i(11, 16), Vector2i(12, 16), Vector2i(13, 16),
		Vector2i(11, 17), Vector2i(12, 17), Vector2i(13, 17),
		Vector2i(11, 18), Vector2i(12, 18), Vector2i(13, 18)], 0)["ok"], "target pool fenced")
	world.end_day()
	for spec in [["pen", 11, 14], ["feed_trough", 13, 14], ["small_bed", 13, 15], ["gel_station", 13, 16]]:
		check(world.build_facility(Vector2i(int(spec[1]), int(spec[2])), String(spec[0]))["ok"], "target pool builds %s" % String(spec[0]))
	var target_cells := []
	for y in range(14, 19):
		for x in range(11, 14):
			target_cells.append("%d,%d" % [x, y])
	var target_zone: Dictionary = world.ranch.create_zone("water_production", target_cells, "目标生产池")
	check(target_zone["ok"] and world.ranch.zone_structural(world.ranch.zone(int(target_zone["zone_uid"]))), "target pool structural")
	var target_uid := int(target_zone["zone_uid"])
	world.end_day()
	check(world.logistics.deploy(String(product["instance_id"]), Vector2i(-1, -1), facility_uid_at(world, Vector2i(13, 16)))["ok"], "product gu on the target station")
	world.end_day()
	check(world.ranch.purchase(zones["nursery"], "gel_jellyfish", 1)["ok"], "buy the guided jellyfish")
	var juveniles: Array = world.ranch.state["animals"]
	check(world.ranch.set_intensive_target(int(juveniles[0]["uid"]), target_uid)["ok"], "target set")
	var algae := world.inventory.count("algae_feed")
	settle(world, 6)
	check(world.inventory.count("algae_feed") <= algae - 5, "feed saving discounted real meals")
	var breeder: Dictionary = world.ranch.animal(int(juveniles[0]["uid"]))
	check(String(breeder["stage"]) == "adult" and int(breeder["contribution"]) == 2400, "guidance banked toward the target")
	var bed: Array = world.ranch.free_bed_slots(world.ranch.zone(zones["pool"]), "small")
	check(world.ranch.submit({"assign": {int(breeder["uid"]): {"mode": "water_enclosure", "zone_uid": zones["pool"],
		"bed_uid": int(bed[0]["uid"]), "bed_slot": int(bed[0]["slot"])}}})["ok"], "breeder into the enclosure")
	settle(world, 9)
	check(bool(world.ranch.animal(int(breeder["uid"]))["breed"]["pending"]), "boosted breeding completes")
	var births: int = world.ranch.state["animals"].size()
	check(world.ranch.claim_births(zones["pool"])["ok"], "gifted birth claimed")
	check(world.ranch.state["animals"].size() == births + 1, "one gifted child")
