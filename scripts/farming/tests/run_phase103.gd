extends SceneTree
## P10.3 model checks: schema, zones, mixed housing, bed groups, purchase,
## the eight-unit clock, maintenance windows, fixed bans, day-opening fatigue,
## work posts, growth, enclosure products and asexual breeding.
const World := preload("res://scripts/farming/p8/p8_world.gd")
const Codec := preload("res://scripts/farming/p8/p8_snapshot.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
var checks := 0
var failures := []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr(label)

func fixture() -> World:
	var w := World.new()
	preload("res://scripts/farming/tests/p107_fixture.gd").unlock(w)
	w.grant_scaffold({"raw_wood": 200, "raw_stone": 200, "wood_plank": 50,
		"mushroom": 200, "fodder_grass": 200, "grain": 200, "clean_water": 400,
		"land_feed": 100, "iron_ore": 100})
	w.primeval_stones = 5000
	w.research.state["completed"] = w.research.project_defs().keys()
	return w

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	_schema()
	var w := _zone_fixture()
	_roster_and_purchase(w)
	_mixed_space_and_beds(w)
	_clock_and_maintenance()
	_ban_and_death()
	_work_posts()
	_growth_enclosure_breeding()
	print("P103 MODEL %s (%d)" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _schema() -> void:
	var w := fixture()
	check(Codec.SCHEMA == 25, "schema is 25")
	check(Codec.normalize(w.to_snapshot())["ok"], "schema25 rule fixture snapshot valid")
	for old in [17, 18, 19, 20, 21, 22, 23, 24]:
		var bad: Dictionary = w.to_snapshot()
		bad["schema"] = old
		check(not Codec.normalize(bad)["ok"], "old schema rejected " + str(old))

## Layout on ordinary floor (the y=6 stone wall splits the farm):
##   nursery     x4..7, y1..4  (16 cells; pen 2x2 + 2 troughs, small+medium bed)
##   enclosure   x8..10, y1..5 (15 cells; pen 2x2 + trough + small bed + care table)
##   work        x4..6,  y7..8 (dispatch + full 2x2 rock-breaking yard)
##   maintenance x7..9,  y7..8 (2 troughs + small bed group)
##   pasture     x4..11, y9..10
func _zone_fixture() -> World:
	var w := fixture()
	for y in range(1, 6):
		for x in range(4, 12):
			check(w.rooms.set_floor(Vector2i(x, y), "ordinary")["ok"], "pave %d,%d" % [x, y])
	for y in range(7, 11):
		for x in range(4, 12):
			check(w.rooms.set_floor(Vector2i(x, y), "ordinary")["ok"], "pave %d,%d" % [x, y])
	for spec in [["pen", 4, 1], ["feed_trough", 6, 1], ["feed_trough", 6, 2], ["small_bed", 7, 1], ["medium_bed", 7, 2]]:
		check(w.build_facility(Vector2i(spec[1], spec[2]), String(spec[0]))["ok"], "build nursery " + String(spec[0]))
	var nursery_cells := []
	for y in range(1, 5):
		for x in range(4, 8):
			nursery_cells.append("%d,%d" % [x, y])
	check(w.ranch.create_zone("nursery", nursery_cells, "育幼一区")["ok"], "nursery zone created")
	for spec in [["pen", 8, 1], ["feed_trough", 10, 1], ["small_bed", 10, 2], ["care_table", 10, 3]]:
		check(w.build_facility(Vector2i(spec[1], spec[2]), String(spec[0]))["ok"], "build enclosure " + String(spec[0]))
	var enclosure_cells := []
	for y in range(1, 6):
		for x in range(8, 11):
			enclosure_cells.append("%d,%d" % [x, y])
	check(w.ranch.create_zone("enclosure", enclosure_cells, "圈养一区")["ok"], "enclosure zone created")
	for spec in [["dispatch_station", 4, 7], ["rock_breaking_yard", 5, 7], ["feed_trough", 7, 7], ["feed_trough", 9, 7], ["small_bed", 8, 7]]:
		check(w.build_facility(Vector2i(spec[1], spec[2]), String(spec[0]))["ok"], "build work module " + String(spec[0]))
	var work_cells := []
	for y in range(7, 9):
		for x in range(4, 7):
			work_cells.append("%d,%d" % [x, y])
	check(w.ranch.create_zone("work", work_cells, "工作一区")["ok"], "work zone created")
	var maintenance_cells := []
	for y in range(7, 9):
		for x in range(7, 10):
			maintenance_cells.append("%d,%d" % [x, y])
	check(w.ranch.create_zone("maintenance", maintenance_cells, "维持一区")["ok"], "maintenance zone created")
	var pasture_cells := []
	for y in range(9, 11):
		for x in range(4, 12):
			pasture_cells.append("%d,%d" % [x, y])
	check(w.ranch.create_zone("pasture", pasture_cells, "放牧一区")["ok"], "pasture zone created")
	check(w.build_facility(Vector2i(4,9),"toy_station")["ok"],"empty toy station provides base pasture service")
	var dispatch_uid: int = w.facility_at(Vector2i(4, 7))["uid"]
	var links := { _zone_uid(w, "maintenance"): dispatch_uid, _zone_uid(w, "pasture"): dispatch_uid }
	check(w.ranch.submit({"links": links})["ok"], "link zones to dispatch")
	return w

func _zone_uid(w: World, type_id: String) -> int:
	for row in w.ranch.state["zones"]:
		if String(row["type"]) == type_id:
			return int(row["uid"])
	return 0

func _roster_and_purchase(w: World) -> void:
	check(Codec.normalize(w.to_snapshot())["ok"], "zone fixture snapshot valid")
	var nursery_uid := _zone_uid(w, "nursery")
	var nursery: Dictionary = w.ranch.zone(nursery_uid)
	check(w.ranch.structure_missing(nursery).is_empty(), "nursery complete structure")
	check(w.ranch.available_space(nursery) == 16 - 4 - 2, "pen and troughs subtract space, beds do not")
	check(not w.ranch.purchase(nursery_uid, "rock_mole", 5)["ok"], "fifth mole exceeds the four-slot bed group")
	var stones := w.primeval_stones
	check(w.ranch.purchase(nursery_uid, "steel_sheep", 2)["ok"], "two sheep juveniles on one medium bed group")
	check(w.ranch.purchase(nursery_uid, "rock_mole", 4)["ok"], "four mole juveniles on one small bed group")
	check(w.ranch.state["animals"].size() == 6, "roster holds purchased animals")
	var sheep: Array = w.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == "steel_sheep")
	check(int(sheep[0]["bed_uid"]) == int(sheep[1]["bed_uid"]) and int(sheep[0]["bed_slot"]) != int(sheep[1]["bed_slot"]), "sheep share one group on different slots")
	check(not w.ranch.purchase(nursery_uid, "rock_mole", 1)["ok"], "small bed group has no fifth slot")
	check(w.primeval_stones == stones - 12 * 2 - 8 * 4, "purchase spent real stones")
	check(w.ranch._zone_usage(nursery) == 2 * 2 + 4, "mixed species share one space pool")

func _mixed_space_and_beds(w: World) -> void:
	var nursery_uid := _zone_uid(w, "nursery")
	check(w.ranch.erase_cell(nursery_uid, Vector2i(4, 3))["ok"], "empty cell leaves the zone")
	check(w.ranch.erase_cell(nursery_uid, Vector2i(5, 3))["ok"], "space still fits the herd")
	check(not w.ranch.erase_cell(nursery_uid, Vector2i(4, 4))["ok"], "cannot shrink below usage")
	check(not w.ranch.paint_cell(nursery_uid, Vector2i(20, 20))["ok"], "paint outside owned land refused")
	check(not w.ranch.create_zone("work", ["10,10"], "second work")["ok"], "overlapping zone cells refused")
	check(not w.ranch.create_zone("pasture", ["3,3"], "far pasture")["ok"], "natural ground refused")
	check(not w.ranch.create_zone("pasture", ["10,3", "10,6"], "split")["ok"], "disconnected cells refused")
	check(not w.ranch.set_diet(int(w.ranch.state["animals"][0]["uid"]), "algae_meal")["ok"], "foreign species diet refused")
	w.ranch.set_diet(int(w.ranch.state["animals"][0]["uid"]), "grain_meal")
	check(String(w.ranch.state["animals"][0]["diet_id"]) == "grain_meal", "diet switch free and immediate")
	var sheep: Array = w.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == "steel_sheep")
	check(not w.ranch.set_bed(int(sheep[0]["uid"]), int(sheep[1]["bed_uid"]), int(sheep[1]["bed_slot"]))["ok"], "occupied slot refused")
	check(Codec.normalize(w.to_snapshot())["ok"], "roster snapshot valid")

func _clock_and_maintenance() -> void:
	var w := _zone_fixture()
	var nursery_uid := _zone_uid(w, "nursery")
	check(w.ranch.purchase(nursery_uid, "rock_mole", 1)["ok"], "one mole bought")
	var water := w.inventory.count("clean_water")
	var mushroom := w.inventory.count("mushroom")
	var d0 := w.clock.total_days
	w.end_day()
	check(w.inventory.count("clean_water") == water - 1 and w.inventory.count("mushroom") == mushroom - 1, "window deducts one base meal at window end")
	var mole: Dictionary = w.ranch.state["animals"][0]
	check(bool(mole["served_once"]) and int(mole["qualified_until"]) == 8 * d0 + 2 + 8, "success qualifies until the next window end")
	check(int(mole["growth"]) == 600, "six care units grew the juvenile")
	w.end_day()
	mole = w.ranch.state["animals"][0]
	check(int(mole["growth"]) == 1200, "growth continues while qualified")
	var drained := w.inventory.count("mushroom")
	w.inventory.remove("mushroom", drained)
	w._record_flow({}, {"mushroom": drained}, "清空菌菇")
	var d2 := w.clock.total_days
	w.end_day()
	mole = w.ranch.state["animals"][0]
	check(int(mole["account"]["fails"]) == 1 and int(mole["ban_until"]) == 8 * d2 + 2 + 8 and int(mole["qualified_until"]) == 8 * d2 + 2, "failure bans eight units and expires qualification")
	check(int(mole["fatigue"]) == 12, "one failed window adds twelve fatigue at the day boundary")
	check(int(mole["growth"]) == 1200, "unqualified care does not grow")
	w.inventory.add("mushroom", 50)
	w._record_flow({"mushroom": 50}, {}, "补回菌菇")
	var d3 := w.clock.total_days
	w.end_day()
	mole = w.ranch.state["animals"][0]
	check(bool(mole["served_once"]) and int(mole["qualified_until"]) == 8 * d3 + 2 + 8, "recovered window qualifies again")
	check(int(mole["fatigue"]) == 0, "care rest clears the failure fatigue")
	check(Codec.normalize(w.to_snapshot())["ok"], "clock snapshot valid")

func _ban_and_death() -> void:
	var w := _zone_fixture()
	var nursery_uid := _zone_uid(w, "nursery")
	w.ranch.purchase(nursery_uid, "rock_mole", 4)
	var drained := w.inventory.count("mushroom")
	w.inventory.remove("mushroom", drained)
	w._record_flow({}, {"mushroom": drained}, "清空菌菇")
	w.end_day()
	w.end_day()
	w.end_day()
	var moles: Array = w.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == "rock_mole")
	check(moles.size() == 4, "starved juveniles survive the 36-fatigue days")
	for row in moles:
		check(int(row["fatigue"]) == 36, "three failed windows accumulate 36 fatigue")
	w.end_day()
	w.end_day()
	moles = w.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == "rock_mole")
	check(moles.size() == 4, "two critical openings are not yet fatal")
	for row in moles:
		check(int(row["death_streak"]) == 2, "critical streak counts two")
	w.end_day()
	moles = w.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == "rock_mole")
	check(moles.is_empty(), "the third consecutive critical opening kills")
	check(Codec.normalize(w.to_snapshot())["ok"], "death snapshot valid")

func _work_posts() -> void:
	var w := _zone_fixture()
	var work_uid := _zone_uid(w, "work")
	var nursery_uid := _zone_uid(w, "nursery")
	check(w.ranch.purchase(nursery_uid, "rock_mole", 4)["ok"], "four workers bought")
	w.end_day()
	w.end_day()
	w.end_day()
	var adults: Array = w.ranch.state["animals"].filter(func(a): return String(a["stage"]) == "adult")
	check(adults.size() == 4, "mole juveniles reach adulthood on day three")
	for row in adults:
		check(w.ranch.submit({"assign": {int(row["uid"]): {"mode": "work", "zone_uid": work_uid}}})["ok"], "assign worker " + str(row["uid"]))
	w.end_day()
	var workers: Array = w.ranch.state["animals"].filter(func(a): return String(a["mode"]) == "work")
	check(workers.size() == 4, "assignments applied at the day boundary")
	var stone := w.inventory.count("raw_stone")
	w.end_day()
	var yard_uid: int = w.facility_at(Vector2i(5, 7))["uid"]
	var yard: Dictionary = w.ranch.workyard_state(yard_uid)
	var progress := 0
	var ready := 0
	for post in yard["posts"]:
		progress += int(post["progress"])
		if String(post["status"]) == "ready":
			ready += 1
	check(progress == 160000 and ready == 4, "four workers fill four batches of 400 points %d/%d" % [progress, ready])
	check(stone - w.inventory.count("raw_stone") == 8, "four batch openings paid real raw stone")
	for row in workers:
		check(int(row["account"]["w"]) == 4, "each worker logged four work units")
		check(int(row["fatigue"]) == 0, "standard shift keeps fatigue stable")
	var gravel := w.inventory.count("gravel")
	var powder := w.inventory.count("stone_powder")
	var claim: Dictionary = w.ranch.claim_workyard(yard_uid)
	check(claim["ok"] and w.inventory.count("gravel") == gravel + 8 and w.inventory.count("stone_powder") == powder + 4, "claim pays the batch outputs")
	check(not w.ranch.claim_workyard(yard_uid)["ok"], "no double claim")
	check(Codec.normalize(w.to_snapshot())["ok"], "work snapshot valid")

func _growth_enclosure_breeding() -> void:
	var w := _zone_fixture()
	var nursery_uid := _zone_uid(w, "nursery")
	var enclosure_uid := _zone_uid(w, "enclosure")
	check(w.ranch.purchase(nursery_uid, "rock_mole", 2)["ok"], "breeder juveniles bought")
	w.end_day()
	w.end_day()
	w.end_day()
	var adults: Array = w.ranch.state["animals"].filter(func(a): return String(a["stage"]) == "adult")
	check(adults.size() == 2, "breeders adult")
	var beds: Array = w.ranch.free_bed_slots(w.ranch.zone(enclosure_uid), "small")
	check(beds.size() == 4, "enclosure bed group offers four slots")
	for index in range(adults.size()):
		var row: Dictionary = adults[index]
		check(w.ranch.submit({"assign": {int(row["uid"]): {"mode": "enclosure", "zone_uid": enclosure_uid,
			"bed_uid": int(beds[index]["uid"]), "bed_slot": int(beds[index]["slot"])}}})["ok"], "assign enclosure " + str(row["uid"]))
	w.end_day()
	var breeders: Array = w.ranch.state["animals"].filter(func(a): return String(a["mode"]) == "enclosure")
	check(breeders.size() == 2, "animals entered enclosure")
	var water := w.inventory.count("clean_water")
	var mushroom := w.inventory.count("mushroom")
	w.end_day()
	check(w.inventory.count("clean_water") == water - 4 and w.inventory.count("mushroom") == mushroom - 4, "enclosure maintenance pays two meals each")
	for row in breeders:
		check(int(row["breed"]["units"]) == 600, "breed progress counts care units")
	for i in range(7):
		w.end_day()
	var pending: Array = w.ranch.state["animals"].filter(func(a): return bool(a["breed"]["pending"]))
	check(pending.size() == 2, "both breeders hold a pending birth after eight effective days")
	check(not w.ranch.claim_births(enclosure_uid)["ok"], "claim refuses without a nursery target")
	check(w.ranch.submit({"birth_targets": {enclosure_uid: nursery_uid}})["ok"], "birth target staged")
	var roster: int = w.ranch.state["animals"].size()
	var claim: Dictionary = w.ranch.claim_births(enclosure_uid)
	check(claim["ok"] and w.ranch.state["animals"].size() == roster + 2, "two juveniles born and placed")
	check(w.ranch.state["births"].size() == 2, "one voucher per parent round")
	for child in w.ranch.state["animals"].filter(func(a): return int(a["uid"]) > roster):
		check(String(child["mode"]) == "nursery" and int(child["zone_uid"]) == nursery_uid, "child placed in the nursery")
	check(not w.ranch.claim_births(enclosure_uid)["ok"], "no second birth from the same round")
	check(Codec.normalize(w.to_snapshot())["ok"], "breeding snapshot valid")
