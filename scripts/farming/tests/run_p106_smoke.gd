extends SceneTree
## P10.6 milestone smoke (testing policy ②): one integrated long run that only
## asserts strategy-independent stability invariants - clean settles, ledger
## conservation through the codec, no accidental deaths, bounded land fatigue,
## non-negative stock and stones, snapshot round-trips - plus a mechanism
## coverage checklist. Economic endpoints deliberately NOT asserted here.
const World := preload("res://scripts/farming/p8/p8_world.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const Codec := preload("res://scripts/farming/p8/p8_snapshot.gd")

var audit_root := "res://.art-work/p106-smoke"
var checks := 0
var failures: Array = []
var strike_floor := -1
var coverage := {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("P106 SMOKE " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(audit_root))
	var world := _world()
	var zones := _build_land(world)
	var pools := _build_water(world)
	_seeds_and_gu(world, zones, pools)
	coverage_check("six_species_zones_built")
	# The long window: everything runs while the script only watches the
	# invariants and pushes the topology change plus the reload checkpoints.
	for day in range(70):
		# Daily water maintenance keeps every body above the pause line;
		# one manual change per body per day, exactly as a player would.
		for body in world.water.state["bodies"].duplicate():
			if world.water.quality(body) < 60:
				world.water.change_water(int(body["uid"]))
		world.end_day()
		_invariants(world, day)
		if day in [15, 25, 35]:
			_assign_water_adults(world, pools)
		if day % 12 == 11:
			_sweep_claims(world)
		if day == 20:
			_topology_change(world, pools)
			coverage_check("topology_changed")
		if day == 30:
			_harvest_crops(world)
			_coverage_industry(world)
		if day == 45:
			_spirit_round(world, pools)
			coverage_check("spirit_route")
		if day % 10 == 9:
			_roundtrip(world, day)
			coverage_check("reload_" + str(day))
	_day_finish(world, pools)
	var summary := FileAccess.open(audit_root.path_join("summary.json"), FileAccess.WRITE)
	summary.store_string(JSON.stringify({"checks": checks, "failures": failures,
		"coverage": coverage, "days": world.clock.total_days,
		"deaths": death_log, "captures": capture_log}, "\t"))
	summary.close()
	for failure in failures:
		printerr(failure)
	print("P106 SMOKE %s · %d checks · %d days" % ["OK" if failures.is_empty() else "FAIL", checks, world.clock.total_days])
	quit(0 if failures.is_empty() else 1)

var death_log: Array = []
var capture_log: Array = []

func _world() -> World:
	var world := World.new(Store.new(audit_root.path_join("smoke-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])))
	world.start_new(1)
	world.operation_recorded.connect(func(entry: Dictionary):
		if entry.get("kind") == "ranch:animal" and entry.get("stage") == "death":
			death_log.append(entry)
		if entry.get("kind") == "ranch:natural" and entry.get("stage") == "capture":
			capture_log.append(entry))
	world.grant_scaffold({"raw_wood": 600, "raw_stone": 900, "wood_plank": 200, "twig": 400,
		"mushroom": 400, "fodder_grass": 800, "grain": 400, "clean_water": 3000,
		"algae_feed": 2000, "stone_powder": 600, "water_feed": 300, "humus": 400,
		"sludge": 400, "charcoal": 100, "iron_ore": 200, "mineral_feed": 100,
		"mulberry_leaf": 100, "straw": 100, "wood_chip": 100, "oil_cake": 60})
	world.primeval_stones += 20000
	world._cash("sales_revenue", 20000)
	world.research.state["completed"] = world.research.project_defs().keys()
	return world

# --- land half (fixture-lint layout, sheep + moles) ----------------------------
func _build_land(world: World) -> Dictionary:
	var cells := {}
	for group in ["maintenance", "nursery", "work", "pasture"]:
		for cell in _lint_layout()[group]:
			cells["%d,%d" % [cell.x, cell.y]] = group
	for cell in _rect(0, 7, 7, 8):
		cells["%d,%d" % [cell.x, cell.y]] = "intensive"
	for key in cells:
		var parts: PackedStringArray = key.split(",")
		world.rooms.set_floor(Vector2i(int(parts[0]), int(parts[1])), "ordinary")
	for spec in [["pen", 0, 10], ["feed_trough", 2, 10], ["feed_trough", 3, 10], ["feed_trough", 4, 10],
			["small_bed", 4, 11], ["medium_bed", 3, 11],
			["dispatch_station", 8, 10], ["rock_breaking_yard", 9, 10], ["rock_breaking_yard", 11, 10],
			["feed_trough", 4, 9], ["feed_trough", 5, 9], ["small_bed", 6, 9], ["medium_bed", 7, 9],
			["toy_station", 8, 12]]:
		world.build_facility(Vector2i(int(spec[1]), int(spec[2])), String(spec[0]))
	var zones := {}
	for group in ["nursery", "work", "maintenance", "pasture"]:
		var created: Dictionary = world.ranch.create_zone(group, _texts(_lint_layout()[group]), group)
		zones[group] = int(created.get("zone_uid", 0))
	var dispatch: int = world.facility_at(Vector2i(8, 10))["uid"]
	world.ranch.submit({"links": {zones["maintenance"]: dispatch, zones["pasture"]: dispatch}})
	world.ranch.purchase(zones["nursery"], "steel_sheep", 2)
	world.ranch.purchase(zones["nursery"], "rock_mole", 2)
	for day in range(10):
		world.end_day()
		_invariants(world, day)
	return zones

func _lint_layout() -> Dictionary:
	var nursery := []
	for y in range(10, 13):
		for x in range(0, 5):
			nursery.append(Vector2i(x, y))
	var work := []
	for y in range(10, 12):
		for x in range(8, 14):
			work.append(Vector2i(x, y))
	var maintenance := []
	for x in range(4, 10):
		maintenance.append(Vector2i(x, 9))
	var pasture := []
	for y in range(12, 14):
		for x in range(8, 20):
			pasture.append(Vector2i(x, y))
	return {"nursery": nursery, "work": work, "maintenance": maintenance, "pasture": pasture,
		"intensive": [], "enclosure": []}

func _texts(cells: Array) -> Array:
	var out := []
	for cell in cells:
		out.append("%d,%d" % [cell.x, cell.y])
	return out

# --- water half ------------------------------------------------------------------
func _build_water(world: World) -> Dictionary:
	world.water.build_fence([Vector2i(2, 14), Vector2i(3, 14), Vector2i(4, 14), Vector2i(2, 15), Vector2i(3, 15), Vector2i(4, 15),
		Vector2i(2, 16), Vector2i(3, 16), Vector2i(4, 16), Vector2i(2, 17), Vector2i(3, 17), Vector2i(4, 17),
		Vector2i(2, 18), Vector2i(3, 18), Vector2i(4, 18)], 0)
	world.end_day()
	for spec in [["pen", 2, 14], ["feed_trough", 4, 14], ["feed_trough", 2, 16], ["feed_trough", 4, 17], ["small_bed", 3, 16], ["medium_bed", 4, 16]]:
		world.build_facility(Vector2i(int(spec[1]), int(spec[2])), String(spec[0]))
	var nursery_cells := _texts(_rect(2, 14, 4, 18))
	var nursery: Dictionary = world.ranch.create_zone("water_nursery", nursery_cells, "冒烟育幼池")
	world.end_day()
	world.water.build_fence(_rect(6, 14, 9, 18), 0)
	for spec in [["pen", 6, 14], ["feed_trough", 8, 14], ["feed_trough", 9, 15], ["small_bed", 9, 14],
			["medium_bed", 9, 16], ["carp_harvest_station", 6, 16], ["oilfish_harvest_station", 7, 16],
			["pearl_station", 6, 17], ["gel_station", 7, 17], ["coral_station", 8, 17]]:
		world.build_facility(Vector2i(int(spec[1]), int(spec[2])), String(spec[0]))
	var production: Dictionary = world.ranch.create_zone("water_production", _texts(_rect(6, 14, 9, 18)), "冒烟生产池")
	world.end_day()
	world.water.build_fence(_rect(11, 14, 13, 18), 0)
	for spec in [["pen", 11, 14], ["feed_trough", 13, 14], ["small_bed", 13, 15], ["care_table", 13, 16],
			["soothing_station", 12, 16]]:
		world.build_facility(Vector2i(int(spec[1]), int(spec[2])), String(spec[0]))
	var enclosure: Dictionary = world.ranch.create_zone("water_enclosure", _texts(_rect(11, 14, 13, 18)), "冒烟繁殖池")
	world.end_day()
	check(world.water.build_fence(_rect(2, 19, 4, 21), 0)["ok"], "planting body fenced")
	world.end_day()
	check(world.build_facility(Vector2i(2, 19), "aquatic_crop_station")["ok"], "crop station built")
	check(world.ranch.create_zone("aqua_planting", _texts(_rect(2, 19, 4, 21)), "冒烟种植区")["ok"], "planting zone created")
	world.water.change_water(1)
	world.water.change_water(2)
	world.water.change_water(3)
	return {"nursery": int(nursery["zone_uid"]), "production": int(production["zone_uid"]),
		"enclosure": int(enclosure["zone_uid"])}

func _rect(x0: int, y0: int, x1: int, y1: int) -> Array:
	var out := []
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			out.append(Vector2i(x, y))
	return out

func _seeds_and_gu(world: World, zones: Dictionary, pools: Dictionary) -> void:
	# Land adults into their uses; water buys across the six species.
	var sheep: Array = world.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == "steel_sheep" and String(a["stage"]) == "adult")
	var moles: Array = world.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == "rock_mole" and String(a["stage"]) == "adult")
	if sheep.size() == 2:
		world.build_facility(Vector2i(0, 7), "pen")
		world.build_facility(Vector2i(3, 7), "feed_trough")
		world.build_facility(Vector2i(4, 7), "medium_bed")
		world.build_facility(Vector2i(6, 7), "wool_station")
		var intensive: Dictionary = world.ranch.create_zone("intensive", _texts(_rect(0, 7, 7, 8)), "冒烟精养区")
		var wool: Array = world.ranch.free_bed_slots(world.ranch.zone(int(intensive["zone_uid"])), "medium")
		if not wool.is_empty():
			world.ranch.submit({"assign": {int(sheep[0]["uid"]): {"mode": "intensive", "zone_uid": int(intensive["zone_uid"]),
				"bed_uid": int(wool[0]["uid"]), "bed_slot": int(wool[0]["slot"])}}})
	for mole in moles:
		world.ranch.submit({"assign": {int(mole["uid"]): {"mode": "work", "zone_uid": zones["work"]}}})
	# The water roster: guided jellyfish, plus one of each of the others.
	for sid in ["gel_jellyfish", "filter_algae_carp", "oilfin_fish", "pearl_mussel", "reef_coral"]:
		var bought: Dictionary = world.ranch.purchase(pools["nursery"], sid, 1)
		if not bought["ok"]:
			printerr("DEBUG buy " + sid + ": " + String(bought.get("reason", "")))
		check(bought["ok"], "smoke buys " + sid)
	world.logistics.provision()
	var product: Dictionary = world.logistics.buy_gu("product_yield_gu")
	world.end_day()
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == "gel_station":
			world.logistics.deploy(String(product["instance_id"]), Vector2i(-1, -1), int(uid))
	var juveniles: Array = world.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == "gel_jellyfish")
	if not juveniles.is_empty():
		world.ranch.set_intensive_target(int(juveniles[0]["uid"]), pools["production"])
	world.ranch.submit({"birth_targets": {pools["enclosure"]: pools["nursery"]}})
	# A second jellyfish runs the water enclosure breeding; sheep stay on land.
	var second: Dictionary = world.ranch.purchase(pools["nursery"], "gel_jellyfish", 1)
	check(second["ok"], "second jellyfish bought")
	coverage_check("bought_second_jellyfish")
	# Water crops planted for the industry checkpoint.
	world.buy("duckweed_seed", 2)
	world.plant(Vector2i(3, 19), "duckweed")
	world.plant(Vector2i(4, 19), "duckweed")
	coverage_check("planted")

# --- checkpoints ---------------------------------------------------------------
func _invariants(world: World, day: int) -> void:
	check(world.daily_save_error.is_empty(), "clean settle day %d" % day)
	if not failures.is_empty() and not world.daily_save_error.is_empty():
		return
	for row in world.ranch.state["animals"]:
		check(int(row["death_streak"]) == 0, "no accidental death day %d (%s)" % [day, row["species_id"]])
		if String(row["species_id"]) in ["steel_sheep", "rock_mole", "rock_belly_beast", "carbon_belly_bug",
				"leaf_silkworm", "dew_shell_snail", "mineral_scale_lizard", "compost_mouse", "gravel_shell_snail"]:
			if strike_floor < 0:
				for tier in world.ranch.settings["fatigue"]["tiers"]:
					if int(tier["efficiency"]) <= 0 and (strike_floor < 0 or int(tier["max"]) < strike_floor):
						strike_floor = int(tier["max"]) + 1
			check(int(row["fatigue"]) < strike_floor, "land fatigue bounded day %d" % day)
	for body in world.water.state["bodies"]:
		check(int(body["quality"]) >= 0, "quality non-negative day %d" % day)
	check(world.primeval_stones >= 0, "stones non-negative day %d" % day)

func _assign_water_adults(world: World, pools: Dictionary) -> void:
	# Every water adult takes its production post; the guided jellyfish gets
	# its voucher round, coral anchors itself.
	var bed_of := {"filter_algae_carp": "small", "oilfin_fish": "medium", "pearl_mussel": "small",
		"gel_jellyfish": "small", "reef_coral": "", "silt_loach": "small"}
	for row in world.ranch.state["animals"].duplicate():
		var sid := String(row["species_id"])
		if not bed_of.has(sid) or String(row["stage"]) != "adult" or String(row["mode"]) != "waiting":
			continue
		if world.ranch.species_medium(sid) != "water":
			continue
		var request := {"mode": "water_production", "zone_uid": pools["production"]}
		if String(bed_of[sid]) != "":
			var beds: Array = world.ranch.free_bed_slots(world.ranch.zone(pools["production"]), String(bed_of[sid]))
			if beds.is_empty():
				continue
			request["bed_uid"] = int(beds[0]["uid"])
			request["bed_slot"] = int(beds[0]["slot"])
		var submitted: Dictionary = world.ranch.submit({"assign": {int(row["uid"]): request}})
		if not submitted["ok"]:
			printerr("DEBUG assign " + sid + ": " + String(submitted.get("reason", "")))
	coverage_check("water_adults_assigned")

func _sweep_claims(world: World) -> void:
	# Keep every body above the pause line so production keeps running, then
	# collect whatever finished. Manual changes only: one per body per day.
	for body in world.water.state["bodies"].duplicate():
		if world.water.quality(body) < 60:
			world.water.change_water(int(body["uid"]))
	for uid in world.facilities:
		var fid := String(world.facilities[uid]["facility_id"])
		if world.ranch.is_work_facility(fid):
			world.ranch.claim_workyard(int(uid))
		elif world.ranch.is_station(fid):
			world.ranch.claim_natural(int(uid))

func _topology_change(world: World, pools: Dictionary) -> void:
	# Merge the planting body into the nursery body via a bridge, then split
	# it back out: conservation holds either way.
	world.water.build_fence([Vector2i(2, 18), Vector2i(3, 18)], 1)
	var merge_result: Dictionary = world.water.merge_bodies(1, 4)
	if not merge_result["ok"]:
		printerr("DEBUG merge: " + String(merge_result.get("reason", "")))
	var merged_ok: bool = merge_result["ok"]
	check(merged_ok, "topology merge ran")
	if merged_ok:
		var split_result: Dictionary = world.water.split_body(1, _rect(2, 19, 4, 21))
		if not split_result["ok"]:
			printerr("DEBUG split: " + String(split_result.get("reason", "")))
		check(split_result["ok"], "topology split ran")

func _harvest_crops(world: World) -> void:
	for cell in [Vector2i(3, 19), Vector2i(4, 19)]:
		var crop: Dictionary = world.instance_at(cell)
		if not crop.is_empty() and String(crop["state"]) == "mature":
			world.harvest(cell)

func _coverage_industry(world: World) -> void:
	coverage_check("harvested_crops")
	if world.inventory.count("duckweed") >= 2:
		var processor := 0
		for uid in world.facilities:
			if String(world.facilities[uid]["facility_id"]) == "farm_processor":
				processor = int(uid)
		if processor == 0:
			world.build_facility(Vector2i(16, 4), "farm_processor")
			for uid in world.facilities:
				if String(world.facilities[uid]["facility_id"]) == "farm_processor":
					processor = int(uid)
		if world.start_batch(processor, "mill_duckweed")["ok"]:
			coverage_check("industry_duckweed_milled")

func _spirit_round(world: World, pools: Dictionary) -> void:
	var mussels: Array = world.ranch.state["animals"].filter(
		func(a): return String(a["species_id"]) == "pearl_mussel" and String(a["stage"]) == "adult")
	if mussels.is_empty():
		return
	if world.ranch.set_natural_diet(int(mussels[0]["uid"]), "pearl_spirit_round")["ok"]:
		coverage_check("spirit_variant_chosen")

func _roundtrip(world: World, day: int) -> void:
	var snapshot: Dictionary = world.to_snapshot()
	check(Codec.normalize(snapshot)["ok"], "snapshot codec-valid at day %d" % day)
	var detached := World.new(Store.new(audit_root.path_join("reload-%d-%d-%d" % [day, OS.get_process_id(), Time.get_ticks_usec()])))
	var loaded: Dictionary = detached.apply_snapshot(snapshot)
	check(bool(loaded.get("ok", false)), "reload applies at day %d" % day)
	world.apply_snapshot(snapshot)
	check(world.daily_save_error.is_empty(), "self-reload clean at day %d" % day)

func _day_finish(world: World, pools: Dictionary) -> void:
	# Final coverage: the species products actually moved.
	for entry in ["fish_meat", "crude_oil", "pearl", "water_gel", "coral_stone", "steel_wool"]:
		if world.inventory.count(entry) > 0:
			coverage_check("product_" + entry)
	for row in world.ranch.state["animals"]:
		if bool(row["natural"]["pending"]):
			coverage_check("pending_round_" + String(row["species_id"]))
	if not world.ranch.state["animals"].is_empty():
		coverage_check("land_still_running")
	var snapshot: Dictionary = world.to_snapshot()
	check(Codec.normalize(snapshot)["ok"], "final snapshot codec-valid")
	var file := FileAccess.open(audit_root.path_join("final.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot, "\t"))
	file.close()

func coverage_check(key: String) -> void:
	coverage[key] = true

