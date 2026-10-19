extends SceneTree
## P10.5 model checks: six new species, the three adult uses and their
## exclusivity, intensive rounds with opening-day efficiency, station capacity,
## the per-facility work registry, silkworm sterility, mulberry limited taps
## and the schema-23 save contract. Rule checks on fixed fixtures, never a
## business claim.
const World := preload("res://scripts/farming/p8/p8_world.gd")
const Codec := preload("res://scripts/farming/p8/p8_snapshot.gd")
const CropFixture := preload("res://scripts/farming/tests/p8_crop_fixture.gd")
var checks := 0
var failures := []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr(label)

func fixture() -> World:
	var w := World.new()
	w.grant_scaffold({"raw_wood": 300, "raw_stone": 300, "wood_plank": 100, "twig": 200,
		"mushroom": 300, "fodder_grass": 300, "grain": 200, "clean_water": 900,
		"land_feed": 200, "iron_ore": 200, "mineral_feed": 100, "algae_feed": 100,
		"mulberry_leaf": 300, "mulberry_seed": 5, "silk": 10, "wood_chip": 50,
		"charcoal": 50, "straw": 50, "stone_powder": 50, "sludge": 50, "oil_cake": 10})
	w.primeval_stones = 9000
	w.research.state["completed"] = w.research.project_defs().keys()
	return w

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var w := _fixture()
	_registry(w)
	_three_uses(w)
	_intensive_rounds(w)
	_station_capacity(w)
	_work_registry(w)
	_mulberry(w)
	_materials(w)
	_codec_forgery(w)
	print("P105 MODEL %s (%d)" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

## Layout on ordinary floor (y=6 stone wall; x15..17 y8..10 sources):
##   nursery   x4..7,  y1..5   pen + 4 troughs + small/medium bed groups
##   enclosure x8..10, y1..5   pen + trough + small bed + care table
##   intensive x12..18, y1..5  pen + trough + beds + all four stations
##   work      x4..6,  y7..10  dispatch + rock-breaking yard + carbonization nest
##   maintain  x7..9,  y7..8   2 troughs + small bed
##   pasture   x7..11, y9..10  toy station
func _fixture() -> World:
	var w := fixture()
	for y in range(1, 6):
		for x in range(4, 19):
			check(w.rooms.set_floor(Vector2i(x, y), "ordinary")["ok"], "pave %d,%d" % [x, y])
	for y in range(7, 11):
		for x in range(4, 12):
			check(w.rooms.set_floor(Vector2i(x, y), "ordinary")["ok"], "pave %d,%d" % [x, y])
	for spec in [["pen", 4, 1], ["feed_trough", 6, 1], ["feed_trough", 6, 2], ["feed_trough", 6, 3], ["feed_trough", 6, 4], ["small_bed", 7, 1], ["medium_bed", 7, 2]]:
		check(w.build_facility(Vector2i(spec[1], spec[2]), String(spec[0]))["ok"], "nursery " + String(spec[0]))
	var nursery_cells := []
	for y in range(1, 6):
		for x in range(4, 8):
			nursery_cells.append("%d,%d" % [x, y])
	check(w.ranch.create_zone("nursery", nursery_cells, "育幼一区")["ok"], "nursery created")
	for spec in [["pen", 8, 1], ["feed_trough", 10, 1], ["small_bed", 10, 2], ["medium_bed", 10, 4], ["care_table", 10, 3]]:
		check(w.build_facility(Vector2i(spec[1], spec[2]), String(spec[0]))["ok"], "enclosure " + String(spec[0]))
	var enclosure_cells := []
	for y in range(1, 6):
		for x in range(8, 11):
			enclosure_cells.append("%d,%d" % [x, y])
	check(w.ranch.create_zone("enclosure", enclosure_cells, "繁殖一区")["ok"], "enclosure created")
	for spec in [["pen", 13, 1], ["feed_trough", 12, 4], ["feed_trough", 12, 2], ["feed_trough", 12, 3], ["feed_trough", 15, 1], ["feed_trough", 16, 1],
			["small_bed", 17, 1], ["small_bed", 18, 1], ["medium_bed", 17, 2],
			["wool_station", 12, 5], ["silkworm_rack", 13, 5], ["scale_station", 14, 5], ["spirit_liquid_collector", 15, 5]]:
		check(w.build_facility(Vector2i(spec[1], spec[2]), String(spec[0]))["ok"], "intensive " + String(spec[0]))
	var intensive_cells := []
	for y in range(1, 6):
		for x in range(12, 19):
			intensive_cells.append("%d,%d" % [x, y])
	var intensive_preview: Dictionary = w.ranch.preview_zone("intensive", intensive_cells)
	check(intensive_preview["ok"] and intensive_preview["enough"], "intensive preview complete")
	check(w.ranch.create_zone("intensive", intensive_cells, "精养一区")["ok"], "intensive created")
	for spec in [["dispatch_station", 4, 7], ["rock_breaking_yard", 5, 7], ["carbonization_nest", 4, 9],
			["feed_trough", 7, 7], ["feed_trough", 9, 7], ["small_bed", 8, 7]]:
		check(w.build_facility(Vector2i(spec[1], spec[2]), String(spec[0]))["ok"], "work module " + String(spec[0]))
	var work_cells := []
	for y in range(7, 11):
		for x in range(4, 7):
			work_cells.append("%d,%d" % [x, y])
	check(w.ranch.create_zone("work", work_cells, "工作一区")["ok"], "work created")
	var maintenance_cells := []
	for y in range(7, 9):
		for x in range(7, 10):
			maintenance_cells.append("%d,%d" % [x, y])
	check(w.ranch.create_zone("maintenance", maintenance_cells, "维持一区")["ok"], "maintenance created")
	var pasture_cells := []
	for y in range(9, 11):
		for x in range(7, 12):
			pasture_cells.append("%d,%d" % [x, y])
	check(w.ranch.create_zone("pasture", pasture_cells, "放牧一区")["ok"], "pasture created")
	check(w.build_facility(Vector2i(11, 9), "toy_station")["ok"], "toy station built")
	var dispatch_uid: int = w.facility_at(Vector2i(4, 7))["uid"]
	var links := {_zone_uid(w, "maintenance"): dispatch_uid, _zone_uid(w, "pasture"): dispatch_uid}
	check(w.ranch.submit({"links": links})["ok"], "zones linked to dispatch")
	check(w.ranch.zone_structural(w.ranch.zone(_zone_uid(w, "intensive"))), "intensive structural")
	return w

func _zone_uid(w: World, type_id: String) -> int:
	for row in w.ranch.state["zones"]:
		if String(row["type"]) == type_id:
			return int(row["uid"])
	return 0

func _facility_uid(w: World, cell: Vector2i) -> int:
	return int(w.facility_at(cell)["uid"])

func _grow_adults(w: World, species_id: String, count: int, days: int) -> Array:
	var nursery_uid := _zone_uid(w, "nursery")
	var first_uid := int(w.ranch.state["next_animal_uid"])
	check(w.ranch.purchase(nursery_uid, species_id, count)["ok"], "buy %s x%d" % [species_id, count])
	for _day in range(days):
		w.end_day()
	var adults: Array = w.ranch.state["animals"].filter(
		func(a): return String(a["species_id"]) == species_id and int(a["uid"]) >= first_uid and String(a["stage"]) == "adult")
	check(adults.size() == count, "%s adults ready" % species_id)
	return adults

func _assign(w: World, row: Dictionary, mode: String, zone_uid: int, bed_type := "") -> void:
	var request := {"mode": mode, "zone_uid": zone_uid}
	if not bed_type.is_empty():
		var beds: Array = w.ranch.free_bed_slots(w.ranch.zone(zone_uid), bed_type)
		check(not beds.is_empty(), "bed available for " + mode)
		request["bed_uid"] = int(beds[0]["uid"])
		request["bed_slot"] = int(beds[0]["slot"])
	check(w.ranch.submit({"assign": {int(row["uid"]): request}})["ok"], "assign %d to %s" % [int(row["uid"]), mode])
	w.end_day()

func _registry(w: World) -> void:
	check(w.ranch.SPECIES.size() == 15, "nine land plus six aquatic species on the roster")
	for sid in ["steel_sheep", "rock_mole", "rock_belly_beast", "carbon_belly_bug", "leaf_silkworm",
			"dew_shell_snail", "mineral_scale_lizard", "compost_mouse", "gravel_shell_snail"]:
		check(w.ranch.species_medium(sid) == "land", sid + " stays a land species")
	for sid in ["carbon_belly_bug", "leaf_silkworm", "dew_shell_snail", "mineral_scale_lizard", "compost_mouse", "gravel_shell_snail"]:
		check(not w.ranch.species_config(sid).is_empty(), "config carries " + sid)
	check(w.ranch.can_breed("leaf_silkworm") == false, "silkworm cannot breed")
	for sid in ["steel_sheep", "rock_mole", "dew_shell_snail", "compost_mouse", "gravel_shell_snail", "carbon_belly_bug", "mineral_scale_lizard"]:
		check(w.ranch.can_breed(sid), "breeder " + sid)
	check(not w.ranch.quote_purchase(_zone_uid(w, "nursery"), "filter_algae_carp", 1)["ok"], "fish stay out of the ranch roster")
	check(not w.ranch.quote_purchase(_zone_uid(w, "nursery"), "bell_bee", 1)["ok"], "bees stay out of the ranch roster")
	check(w.ranch.is_work_facility("carbonization_nest") and not w.ranch.is_work_facility("wool_station"), "work facility registry")
	check(w.ranch.is_station("wool_station") and not w.ranch.is_station("carbonization_nest"), "station registry")
	check(w.ranch.is_structural("pen") and w.ranch.is_structural("silkworm_rack") and not w.ranch.is_structural("care_table"), "structural registry")
	# Group species register as one feeding unit: one purchase, one bed slot.
	var silkworms: Array = _grow_adults(w, "leaf_silkworm", 1, 3)
	check(silkworms.size() == 1, "one silkworm group registers as one unit")

func _three_uses(w: World) -> void:
	var intensive_uid := _zone_uid(w, "intensive")
	var enclosure_uid := _zone_uid(w, "enclosure")
	var sheep: Array = _grow_adults(w, "steel_sheep", 2, 6)
	# Baseline before any intensive day: the second assign's own boundary day
	# already runs one full intensive day for the earlier animal.
	var iron := w.inventory.count("iron_ore")
	_assign(w, sheep[0], "intensive", intensive_uid, "medium")
	_assign(w, sheep[1], "enclosure", enclosure_uid, "medium")
	var breeder: Dictionary = sheep[1]
	var producer: Dictionary = sheep[0]
	check(String(producer["mode"]) == "intensive" and String(breeder["mode"]) == "enclosure", "both uses entered")
	w.end_day()
	check(w.inventory.count("iron_ore") == iron - 1, "round feed paid exactly once")
	producer = w.ranch.animal(int(producer["uid"]))
	check(int(producer["natural"]["units"]) == 1200 and bool(producer["natural"]["paid"]), "producer advances 6 wool units per day")
	breeder = w.ranch.animal(int(breeder["uid"]))
	check(int(breeder["natural"]["units"]) == 0, "breeder accumulates no body material in the enclosure")
	check(int(breeder["breed"]["units"]) == 600, "breeder breed progress counts care units")
	check(int(producer["breed"]["units"]) == 0, "intensive animal accumulates no breed progress")
	# Wool completes on the third effective day and is claimed via the station.
	w.end_day()
	w.end_day()
	check(bool(producer["natural"]["pending"]), "wool round pending after 18 units")
	var wool: int = w.facility_at(Vector2i(12, 5))["uid"]
	var claim: Dictionary = w.ranch.claim_natural(wool)
	check(claim["ok"] and w.inventory.count("steel_wool") == 1 and w.inventory.count("sheep_manure") == 1, "wool claimed through the station")
	check(not w.ranch.claim_natural(wool)["ok"], "no second claim for the same round")
	check(int(w.ranch.animal(int(producer["uid"]))["natural"]["round"]) == 1, "round advanced after claim")
	# A silkworm cannot enter the breeding zone at all.
	var silkworm: Dictionary = w.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == "leaf_silkworm")[0]
	check(not w.ranch.submit({"assign": {int(silkworm["uid"]): {"mode": "enclosure", "zone_uid": enclosure_uid}}})["ok"], "silkworm refused in the breeding zone")
	check(Codec.normalize(w.to_snapshot())["ok"], "three-uses snapshot valid")

func _intensive_rounds(w: World) -> void:
	var intensive_uid := _zone_uid(w, "intensive")
	# Fatigue 16 at opening: E=50, six care units add 300 of 1200 target.
	var silkworms: Array = w.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == "leaf_silkworm" and String(a["stage"]) == "adult")
	var worm: Dictionary = silkworms[0]
	_assign(w, worm, "intensive", intensive_uid, "small")
	var leaves := w.inventory.count("mulberry_leaf")
	w.ranch.animal(int(worm["uid"]))["fatigue"] = 16
	w.end_day()
	worm = w.ranch.animal(int(worm["uid"]))
	check(int(worm["natural"]["units"]) == 300, "tired opening advances half rate")
	check(w.inventory.count("mulberry_leaf") == leaves - 2 - 2, "round diet paid once plus two base meals")
	check(int(worm["fatigue"]) == 4, "care rest recovered the fatigue")
	# Tired round keeps partial progress across days; no soothing multiplier.
	w.end_day()
	worm = w.ranch.animal(int(worm["uid"]))
	check(int(worm["natural"]["units"]) == 900, "recovered day advances full rate")
	w.end_day()
	worm = w.ranch.animal(int(worm["uid"]))
	check(bool(worm["natural"]["pending"]), "silk round completes and waits at the rack")
	var rack_claim: int = w.facility_at(Vector2i(13, 5))["uid"]
	check(w.ranch.claim_natural(rack_claim)["ok"] and w.inventory.count("silk") == 14, "silk claimed through the rack")
	# E=0: no progress, no second round payment while the first is pending-free.
	var sheep: Array = w.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == "steel_sheep" and String(a["mode"]) == "intensive")
	var ram: Dictionary = sheep[0]
	if bool(ram["natural"]["pending"]):
		check(w.ranch.claim_natural(int(w.facility_at(Vector2i(12, 5))["uid"]))["ok"], "second wool round claimed")
		ram = w.ranch.animal(int(ram["uid"]))
	w.ranch.animal(int(ram["uid"]))["fatigue"] = 40
	var units_before := int(ram["natural"]["units"])
	var paid_before := bool(ram["natural"]["paid"])
	w.end_day()
	ram = w.ranch.animal(int(ram["uid"]))
	check(int(ram["natural"]["units"]) == units_before and bool(ram["natural"]["paid"]) == paid_before, "strike opening neither advances nor recharges")
	# Progress follows the animal: leaving to waiting and back keeps units and paid.
	w.ranch.animal(int(ram["uid"]))["natural"]["units"] = 1500
	w.ranch.animal(int(ram["uid"]))["natural"]["paid"] = true
	check(w.ranch.submit({"assign": {int(ram["uid"]): {"mode": "waiting"}}})["ok"], "stage waiting")
	w.end_day()
	check(String(w.ranch.animal(int(ram["uid"]))["mode"]) == "waiting", "waiting applied")
	_assign(w, ram, "intensive", intensive_uid, "medium")
	ram = w.ranch.animal(int(ram["uid"]))
	check(int(ram["natural"]["units"]) == 1500 and bool(ram["natural"]["paid"]), "round state survives the trip")
	check(Codec.normalize(w.to_snapshot())["ok"], "intensive snapshot valid")

func _intensive_world(species_id: String, count: int, station_id: String, bed_type: String, growth_days: int, extra_station := false) -> World:
	# Minimal deterministic world: one nursery and one intensive zone with
	# enough troughs and beds for the whole cohort under test.
	var w := fixture()
	for y in range(1, 6):
		for x in range(4, 19):
			check(w.rooms.set_floor(Vector2i(x, y), "ordinary")["ok"], "capacity pave %d,%d" % [x, y])
	for spec in [["pen", 4, 1], ["feed_trough", 6, 1], ["feed_trough", 6, 2], ["small_bed", 7, 1], ["medium_bed", 7, 2]]:
		check(w.build_facility(Vector2i(spec[1], spec[2]), String(spec[0]))["ok"], "capacity nursery " + String(spec[0]))
	var nursery_cells := []
	for y in range(1, 6):
		for x in range(4, 8):
			nursery_cells.append("%d,%d" % [x, y])
	check(w.ranch.create_zone("nursery", nursery_cells, "容量育幼")["ok"], "capacity nursery zone")
	for spec in [["pen", 13, 1], ["feed_trough", 12, 2], ["feed_trough", 12, 3], ["feed_trough", 12, 4], ["feed_trough", 15, 1], ["feed_trough", 16, 1],
			["small_bed", 17, 1], ["small_bed", 18, 1], ["medium_bed", 17, 2], ["medium_bed", 18, 2], [station_id, 13, 5]]:
		check(w.build_facility(Vector2i(spec[1], spec[2]), String(spec[0]))["ok"], "capacity intensive " + String(spec[0]))
	if extra_station:
		check(w.build_facility(Vector2i(14, 5), station_id)["ok"], "capacity second station")
	var intensive_cells := []
	for y in range(1, 6):
		for x in range(12, 19):
			intensive_cells.append("%d,%d" % [x, y])
	check(w.ranch.create_zone("intensive", intensive_cells, "容量精养")["ok"], "capacity intensive zone")
	var first_uid := int(w.ranch.state["next_animal_uid"])
	check(w.ranch.purchase(1, species_id, count)["ok"], "capacity buy %s x%d" % [species_id, count])
	for _day in range(growth_days):
		w.end_day()
	var zone_uid := _zone_uid(w, "intensive")
	var batch := {}
	var chosen := {}
	for row in w.ranch.state["animals"]:
		if int(row["uid"]) < first_uid:
			continue
		var bed: Dictionary = {}
		for candidate in w.ranch.free_bed_slots(w.ranch.zone(zone_uid), bed_type):
			var bed_key := "%d:%d" % [int(candidate["uid"]), int(candidate["slot"])]
			if not chosen.has(bed_key):
				bed = candidate
				chosen[bed_key] = true
				break
		batch[int(row["uid"])] = {"mode": "intensive", "zone_uid": zone_uid,
			"bed_uid": int(bed["uid"]), "bed_slot": int(bed["slot"])}
	check(w.ranch.submit({"assign": batch})["ok"], "capacity batch assign")
	w.end_day()
	return w

func _natural_units(w: World, species_id: String) -> Array:
	var out := []
	for row in w.ranch.state["animals"]:
		if String(row["species_id"]) == species_id and String(row["mode"]) == "intensive":
			out.append(int(row["natural"]["units"]))
	out.sort()
	return out

func _station_capacity(_w: World) -> void:
	# One rack serves four space per care unit: four silk groups fill it exactly.
	var worms_world := _intensive_world("leaf_silkworm", 4, "silkworm_rack", "small", 3)
	worms_world.end_day()
	var units := _natural_units(worms_world, "leaf_silkworm")
	check(units == [600, 600, 600, 600], "four silk groups share one rack per unit")
	check(Codec.normalize(worms_world.to_snapshot())["ok"], "worm capacity snapshot valid")
	# Heavier lizards: two of them already fill a station's four space.
	var lizard_world := _intensive_world("mineral_scale_lizard", 3, "scale_station", "medium", 6)
	lizard_world.end_day()
	units = _natural_units(lizard_world, "mineral_scale_lizard")
	check(units == [0, 600, 600], "third lizard waits: station capacity is four space")
	# A second station of the same type lifts the cap without double-serving.
	check(lizard_world.build_facility(Vector2i(14, 5), "scale_station")["ok"], "second scale station")
	lizard_world.end_day()
	units = _natural_units(lizard_world, "mineral_scale_lizard")
	check(units == [600, 1200, 1200], "each lizard advances exactly once per day")
	# Claims stay species-scoped: the scale station owns no silk rounds and the
	# rack owns no lizard rounds.
	var scale_uid: int = lizard_world.facility_at(Vector2i(13, 5))["uid"]
	check(not lizard_world.ranch.claim_natural(scale_uid)["ok"], "no pending lizard rounds yet")
	check(Codec.normalize(lizard_world.to_snapshot())["ok"], "lizard capacity snapshot valid")
	# A station outside an intensive zone has no claim entry.
	var stray: Dictionary = _w.build_facility(Vector2i(9, 5), "spirit_liquid_collector")
	check(stray["ok"] and not _w.ranch.claim_natural(int(_w.facility_at(Vector2i(9, 5))["uid"]))["ok"], "stray station refuses claims")

func _work_registry(w: World) -> void:
	var work_uid := _zone_uid(w, "work")
	var breaking: int = _facility_uid(w, Vector2i(5, 7))
	var nest: int = _facility_uid(w, Vector2i(4, 9))
	check(not w.ranch.set_recipe(breaking, "bug_char_twigs")["ok"], "breaking yard refuses foreign recipe")
	check(w.ranch.set_recipe(nest, "bug_char_chips")["ok"], "nest accepts its own recipe")
	check(w.ranch.set_recipe(nest, "bug_char_twigs")["ok"], "nest switches while empty")
	var bugs: Array = _grow_adults(w, "carbon_belly_bug", 1, 3)
	_assign(w, bugs[0], "work", work_uid)
	var twigs := w.inventory.count("twig")
	w.end_day()
	var nest_state: Dictionary = w.ranch.workyard_state(nest)
	var progress := 0
	for post in nest_state["posts"]:
		progress += int(post["progress"])
	check(progress == 40000 and w.inventory.count("twig") == twigs - 4, "bug char batch opens and advances 4 units")
	w.end_day()
	nest_state = w.ranch.workyard_state(nest)
	var ready := 0
	var outputs := {}
	for post in nest_state["posts"]:
		if String(post["status"]) == "ready":
			ready += 1
			for item in post["outputs"]:
				outputs[String(item)] = int(outputs.get(String(item), 0)) + int(post["outputs"][item])
	check(ready == 1 and int(outputs.get("charcoal", 0)) == 4 and int(outputs.get("humus", 0)) == 1, "twig char batch ready")
	var charcoal := w.inventory.count("charcoal")
	check(w.ranch.claim_workyard(nest)["ok"] and w.inventory.count("charcoal") == charcoal + 4, "nest claim pays charcoal")
	# Moles and bugs share one work zone without borrowing each other's yards.
	var moles: Array = _grow_adults(w, "rock_mole", 1, 3)
	_assign(w, moles[0], "work", work_uid)
	w.end_day()
	var break_state: Dictionary = w.ranch.workyard_state(breaking)
	var mole_progress := 0
	for post in break_state["posts"]:
		mole_progress += int(post["progress"])
	check(mole_progress == 40000, "mole still fills the breaking yard beside the nest")
	check(Codec.normalize(w.to_snapshot())["ok"], "work registry snapshot valid")

func _mulberry(w: World) -> void:
	var tree_cells := [Vector2i(8, 3), Vector2i(9, 3), Vector2i(8, 4), Vector2i(9, 4)]
	for cell in tree_cells:
		check(w.rooms.set_floor(cell, "farmland")["ok"], "farmland " + str(cell))
	check(w.plant(Vector2i(8, 3), "mulberry_tree")["ok"], "mulberry planted 2x2")
	var crop_uid: int = int(w.instance_at(Vector2i(8, 3))["uid"])
	CropFixture.progress(w, crop_uid, 600)
	var leaves := w.inventory.count("mulberry_leaf")
	check(w.harvest(Vector2i(8, 3))["ok"] and w.inventory.count("mulberry_leaf") == leaves + 10, "first tap pays ten leaves")
	var row: Dictionary = w.crops[crop_uid]
	check(int(row["harvest_count"]) == 1 and String(row["state"]) == "regrowing", "tree regrows after the tap")
	CropFixture.progress(w, crop_uid, 200)
	check(w.harvest(Vector2i(8, 3))["ok"], "second tap after two regrow days")
	for tap in range(5):
		CropFixture.progress(w, crop_uid, 200)
		var result: Dictionary = w.harvest(Vector2i(8, 3))
		check(result["ok"] == (tap < 4), "tap limit at six: tap %d" % (tap + 3))
		if not result["ok"]:
			check(String(result["reason"]).contains("砍伐"), "limit message points to felling")
	check(int(w.crops[crop_uid]["harvest_count"]) == 6, "six taps recorded")
	var wood := w.inventory.count("raw_wood")
	check(w.harvest(Vector2i(8, 3), "fell")["ok"] and w.inventory.count("raw_wood") == wood + 2, "felling pays wood plus twigs")
	check(not w.crops.has(crop_uid), "felled tree clears the field")
	for cell in tree_cells:
		check(w.rooms.set_floor(cell, "ordinary")["ok"], "restore ordinary " + str(cell))
	check(Codec.normalize(w.to_snapshot())["ok"], "mulberry snapshot valid")

func _materials(w: World) -> void:
	var fresh := World.new()
	fresh.grant_scaffold({"silk": 5, "wood_chip": 5, "charcoal": 5})
	check(String(fresh.recipe_defs["make_silk_filter_media"]["research"]) == "water_recirculation", "silk filter research gate")
	check(not String(fresh.research_block("water_recirculation")).is_empty(), "gate closed before research")
	check(String(fresh.recipe_defs["assemble_shell_panel"]["research"]) == "mineral_materials", "panel research gate")
	for item in ["silk", "spirit_liquid", "mucus", "mineral_scale", "shed_skin", "rock_shell"]:
		check(fresh._items.has(item), "material registered " + item)
	check(int(fresh._items["spirit_liquid"]["sell_price"]) == 6 and int(fresh._items["spirit_liquid"]["buy_price"]) == 0, "spirit liquid trades but cannot be bought")
	var consumes_liquid := false
	for recipe_id in fresh.recipe_defs:
		if fresh.recipe_defs[recipe_id]["inputs"].has("spirit_liquid"):
			consumes_liquid = true
	check(not consumes_liquid, "spirit liquid has no crafting consumer this phase")
	check(int(fresh._items["mulberry_seed"]["buy_price"]) == 6 and int(fresh._items["mulberry_leaf"]["buy_price"]) == 2, "mulberry starter purchases")
	check(w.ranch.natural_config("mineral_scale_lizard")["units"] == 2400, "lizard round target frozen")
	check(w.ranch.settings["work"]["facilities"]["shell_forming_station"] == ["form_rock_shell"], "gravel snail owns the forming station")

func _codec_forgery(w: World) -> void:
	var snapshot: Dictionary = w.to_snapshot()
	check(Codec.normalize(snapshot)["ok"], "full fixture snapshot valid")
	var bad: Dictionary = w.to_snapshot()
	var forged_pending := false
	for row in bad["world"]["ranch"]["animals"]:
		if bool(row["natural"]["pending"]):
			row["natural"]["pending"] = false
			forged_pending = true
	check(forged_pending, "a pending round exists for the pending forge")
	check(not Codec.normalize(bad)["ok"], "pending lie rejected")
	bad = w.to_snapshot()
	for row in bad["world"]["ranch"]["animals"]:
		if String(row["species_id"]) == "leaf_silkworm":
			row["breed"]["units"] = 100
	check(not Codec.normalize(bad)["ok"], "silkworm breed progress rejected")
	bad = w.to_snapshot()
	var parent := 0
	var child := 0
	for row in bad["world"]["ranch"]["animals"]:
		if String(row["species_id"]) == "leaf_silkworm":
			parent = int(row["uid"])
		if child == 0 and int(row["uid"]) != parent:
			child = int(row["uid"])
	bad["world"]["ranch"]["births"].append({"parent_uid": parent, "round": 0, "child_uid": child})
	check(not Codec.normalize(bad)["ok"], "silkworm birth voucher rejected")
	bad = w.to_snapshot()
	var breaking_key := str(_facility_uid(w, Vector2i(5, 7)))
	if bad["world"]["ranch"]["workyards"].has(breaking_key):
		bad["world"]["ranch"]["workyards"][breaking_key]["recipe_id"] = "bug_char_twigs"
		check(not Codec.normalize(bad)["ok"], "foreign yard recipe rejected")
	else:
		check(false, "breaking yard state exists for the forge")
	bad = w.to_snapshot()
	for row in bad["world"]["ranch"]["animals"]:
		if String(row["species_id"]) == "steel_sheep":
			row["natural"]["diet_id"] = "grain_meal"
			break
	check(not Codec.normalize(bad)["ok"], "foreign round diet rejected")
	for cell in [Vector2i(8, 3), Vector2i(9, 3), Vector2i(8, 4), Vector2i(9, 4)]:
		check(w.rooms.set_floor(cell, "farmland")["ok"], "refarmland " + str(cell))
	check(w.plant(Vector2i(8, 3), "mulberry_tree")["ok"], "codec mulberry planted")
	bad = w.to_snapshot()
	for row in bad["world"]["crops"]:
		if String(row["crop_id"]) == "mulberry_tree":
			row["harvest_count"] = 7
	check(not Codec.normalize(bad)["ok"], "seventh tap rejected by the codec")
	check(w.clear_crop(Vector2i(8, 3))["ok"], "codec mulberry cleared")
	for cell in [Vector2i(8, 3), Vector2i(9, 3), Vector2i(8, 4), Vector2i(9, 4)]:
		check(w.rooms.set_floor(cell, "ordinary")["ok"], "reconvert " + str(cell))
	bad = w.to_snapshot()
	bad["schema"] = 22
	check(not Codec.normalize(bad)["ok"], "schema 22 rejected")
	var before: Dictionary = w.to_snapshot()
	w.ranch.preview_next_day()
	check(w.to_snapshot() == before, "preview leaves the world untouched")
