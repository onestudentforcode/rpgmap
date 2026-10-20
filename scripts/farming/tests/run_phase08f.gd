extends SceneTree
## P8.f checks: single-species yards, rock mole and rock belly lifecycles with
## paid-once mineral batches, the R16-R18/R08 chain, construction substitutes
## and the P8.e joint validation running on real gravel from the breaker.
const P8World := preload("res://scripts/farming/p8/p8_world.gd")
const P8Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const P8Snapshot := preload("res://scripts/farming/p8/p8_snapshot.gd")

var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func temp_store() -> P8Store:
	return P8Store.new("res://.art-work/p107-legacy/p8f_test_%d" % Time.get_ticks_usec())

func complete_research(world, bench: int, project_id: String, samples: Dictionary) -> void:
	world.grant_scaffold(samples)
	var started: Dictionary = world.research.start(bench, project_id)
	check(started["ok"], "start %s (%s)" % [project_id, String(started.get("reason", ""))])
	var guard := 0
	while not world.research.is_completed(project_id) and guard < 12:
		world.research.work(bench)
		world.end_day()
		guard += 1

## Test-only discard that keeps the resource ledger conservative.
func discard(world, item: String, quantity: int) -> void:
	if quantity <= 0:
		return
	world.inventory.remove(item, quantity)
	world._record_flow({}, {item: quantity}, "测试弃置")

func uid_of_pen_in(world, zone_uid: int) -> int:
	var zone_row: Dictionary = world.ranch.zone(zone_uid)
	for facility in world.ranch._facilities_in_zone(zone_row):
		if String(facility["facility_id"]) == "pen":
			return int(facility["uid"])
	return 0

func uid_of(world, facility_id: String, index: int = 0) -> int:
	var found := []
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == facility_id:
			found.append(int(uid))
	found.sort()
	return found[mini(index, found.size() - 1)] if not found.is_empty() else 0

func _initialize() -> void:
	_yard_species_and_mole()
	_belly_and_smelting()
	_building_materials()
	_construction_substitutes()
	_e_joint_validation()
	_snapshot_contracts()
	for failure in failures: printerr(failure)
	print("PHASE08F TEST %s · %d checks" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

# --- 1. Yards and the rock mole ------------------------------------------------

## Paves and builds one standard ranch module below the y=6 wall and returns
## the zone uids: nursery (pen+trough+small bed), work (dispatch+workyard) and
## a linked maintenance zone (trough+small bed). No pasture: short fixtures
## tolerate a few fatigue points instead of roaming.
func ranch_module(world) -> Dictionary:
	for y in range(7, 12):
		for x in range(0, 10):
			var paved: Dictionary = world.rooms.set_floor(Vector2i(x, y), "ordinary")
			check(paved["ok"], "pave ranch floor %d,%d" % [x, y])
	var specs := [["pen", 0, 7], ["feed_trough", 2, 7], ["small_bed", 3, 7],
			["dispatch_station", 4, 7], ["rock_breaking_yard", 5, 7],
			["feed_trough", 0, 10], ["small_bed", 1, 10]]
	if world.research.is_completed("ore_concentration"):
		specs.append(["ore_sorting_yard", 7, 8])
	for spec in specs:
		var built: Dictionary = world.build_facility(Vector2i(spec[1], spec[2]), String(spec[0]))
		check(built["ok"], "build " + String(spec[0]) + " (" + String(built.get("reason", "")) + ")")
	var nursery_cells := []
	for y in range(7, 10):
		for x in range(0, 4): nursery_cells.append("%d,%d" % [x, y])
	var nursery: Dictionary = world.ranch.create_zone("nursery", nursery_cells, "n")
	check(nursery["ok"], "nursery zone created")
	var work_cells := []
	for y in range(7, 10):
		for x in range(4, 10): work_cells.append("%d,%d" % [x, y])
	var work: Dictionary = world.ranch.create_zone("work", work_cells, "w")
	check(work["ok"], "work zone created")
	var maintenance_cells := []
	for y in range(10, 12):
		for x in range(0, 3): maintenance_cells.append("%d,%d" % [x, y])
	var maintenance: Dictionary = world.ranch.create_zone("maintenance", maintenance_cells, "m")
	check(maintenance["ok"], "maintenance zone created")
	var dispatch: int = uid_of(world, "dispatch_station")
	check(world.ranch.submit({"links": {int(maintenance["zone_uid"]): dispatch}})["ok"], "link maintenance to dispatch")
	return {"nursery": int(nursery["zone_uid"]), "work": int(work["zone_uid"])}

func _yard_species_and_mole() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	preload("res://scripts/farming/tests/p107_fixture.gd").unlock(world)
	world.grant_scaffold({"raw_wood": 90, "raw_stone": 40, "grain": 2, "humus": 1, "mushroom": 40,
		"clean_water": 60})
	world.primeval_stones += 120
	world._cash("sales_revenue", 120) # Declared fixture funding, not business evidence.
	world.build_facility(Vector2i(2, 4), "research_bench")
	complete_research(world, 1, "flower_cultivation", {"grain": 2, "humus": 1})
	complete_research(world, 1, "rock_handling", {"mushroom": 1, "raw_stone": 3})
	check(world.build_facility(Vector2i(5, 7), "rock_breaking_yard")["reason"].find("普通地板") >= 0, "yard needs ordinary floor before research is even considered")
	var zones := ranch_module(world)
	var yard := uid_of(world, "rock_breaking_yard")
	# The beast stays locked behind T07: quote and purchase refuse without cost.
	check(not world.ranch.purchase(zones["nursery"], "rock_belly_beast", 1)["ok"], "locked beast purchase refused")
	check(world.ranch.state["animals"].is_empty(), "locked purchase creates no individual")
	complete_research(world, 1, "ore_concentration", {"crushed_ore": 2, "gravel": 1, "fodder_grass": 2})
	var stones_before := world.primeval_stones
	check(world.ranch.purchase(zones["nursery"], "rock_mole", 2)["ok"], "buy two mole pups through the nursery")
	check(world.primeval_stones == stones_before - 16, "purchases charged the juvenile price")
	var water_before := world.inventory.count("clean_water")
	var mushrooms_before := world.inventory.count("mushroom")
	world.end_day()
	check(world.inventory.count("mushroom") == mushrooms_before - 2 and world.inventory.count("clean_water") == water_before - 2, "daily rations really deducted")
	for _day in range(2):
		world.end_day()
	var adults: Array = world.ranch.state["animals"].filter(func(a): return String(a["stage"]) == "adult")
	check(adults.size() == 2 and world.inventory.count("gravel") == 0, "adults mature on rations alone, no free minerals")
	# Rations only while waiting; the mineral batches are paid once per post.
	for row in adults:
		check(world.ranch.submit({"assign": {int(row["uid"]): {"mode": "work", "zone_uid": zones["work"]}}})["ok"], "assign mole worker")
	world.end_day()
	world.grant_scaffold({"raw_stone": 4})
	var stone_before_work := world.inventory.count("raw_stone")
	world.end_day()
	var yard_state: Dictionary = world.ranch.workyard_state(yard)
	var ready := 0
	for post in yard_state["posts"]:
		if String(post["status"]) == "ready": ready += 1
	check(ready == 2, "both posts hold finished batches")
	check(world.inventory.count("raw_stone") == stone_before_work - 4, "mineral inputs paid once per batch")
	var claimed: Dictionary = world.ranch.claim_workyard(yard)
	check(claimed["ok"] and world.inventory.count("gravel") == 4 and world.inventory.count("stone_powder") == 2, "claim issues gravel and powder, moles stay")
	# Switching to R14 only affects the next batch.
	world.grant_scaffold({"iron_ore": 4})
	check(world.ranch.set_recipe(yard, "break_ore")["ok"], "switch to ore breaking")
	world.end_day()
	var claimed2: Dictionary = world.ranch.claim_workyard(yard)
	check(claimed2["ok"] and world.inventory.count("crushed_ore") == 6, "R14 issues crushed ore")

# --- 2. The beast chain through smelting ------------------------------------------

func _belly_and_smelting() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	preload("res://scripts/farming/tests/p107_fixture.gd").unlock(world)
	world.grant_scaffold({"raw_wood": 90, "raw_stone": 40, "wood_plank": 10, "grain": 2, "humus": 1, "mushroom": 60,
		"clean_water": 120, "fodder_grass": 60, "crushed_ore": 60, "charcoal": 4,
		"grass_meal": 4, "grain_meal": 2, "iron_ore": 3})
	world.primeval_stones += 200
	world._cash("sales_revenue", 200) # The stage bootstrap now crosses the day-45 recap.
	world.build_facility(Vector2i(2, 4), "research_bench")
	complete_research(world, 1, "flower_cultivation", {"grain": 2, "humus": 1})
	complete_research(world, 1, "beekeeping", {"nectar": 2, "pollen": 1})
	complete_research(world, 1, "farm_preparation", {"oilseed": 2, "straw": 2})
	complete_research(world, 1, "rock_handling", {"mushroom": 1, "raw_stone": 3})
	complete_research(world, 1, "ore_concentration", {"crushed_ore": 2, "gravel": 1, "fodder_grass": 2})
	var zones := ranch_module(world)
	var yard := uid_of(world, "ore_sorting_yard")
	check(world.ranch.purchase(zones["nursery"], "rock_belly_beast", 1)["ok"], "buy the beast through the nursery")
	for _day in range(4):
		world.end_day()
	var beast: Array = world.ranch.state["animals"].filter(func(a): return String(a["stage"]) == "adult")
	check(beast.size() == 1, "beast adult on grass rations")
	check(world.ranch.submit({"assign": {int(beast[0]["uid"]): {"mode": "work", "zone_uid": zones["work"]}}})["ok"], "assign the beast")
	world.end_day()
	check(world.ranch.set_recipe(yard, "concentrate_ore")["ok"], "switch the yard to R15")
	world.grant_scaffold({"crushed_ore": 6})
	var ore_before := world.inventory.count("crushed_ore")
	world.end_day()
	world.end_day()
	var claimed: Dictionary = world.ranch.claim_workyard(yard)
	check(claimed["ok"] and world.inventory.count("ore_concentrate") == 2 and world.inventory.count("tailings") == 1, "R15 issues concentrate and tailings")
	check(world.inventory.count("crushed_ore") == ore_before - 6, "beast consumed the full batch inputs")
	# R16 on the old smelter; R08 needs the processor behind T11.
	var smelter_built: Dictionary = world.build_facility(Vector2i(7, 1), "smelter")
	check(smelter_built["ok"], "build the smelter (" + String(smelter_built.get("reason", "")) + " stones " + str(world.primeval_stones) + ")")
	var smelter := uid_of(world, "smelter")
	world.grant_scaffold({"ore_concentrate": 1})
	check(world.start_batch(smelter, "smelt_concentrate")["ok"] or world.research.is_completed("mineral_materials") == false, "R16 gated behind T11")
	check(not world.start_batch(smelter, "smelt_concentrate")["ok"], "R16 locked before T11")
	complete_research(world, 1, "advanced_feed_oil_wax", {"crude_oil": 1, "beeswax": 1, "grain_meal": 1})
	complete_research(world, 1, "mineral_materials", {"ore_concentrate": 1, "iron_ingot": 1, "stone_powder": 1})
	world.grant_scaffold({"ore_concentrate": 1, "charcoal": 1})
	check(world.start_batch(smelter, "smelt_concentrate")["ok"], "R16 starts after T11")
	var guard := 0
	while not world.facilities[smelter]["batch"].is_empty() and guard < 10:
		var b: Dictionary = world.facilities[smelter]["batch"]
		if b["status"] == "ready": world.claim_batch(smelter, int(b["batch_id"]))
		else: world.end_day()
		guard += 1
	check(world.inventory.count("iron_ingot") == 1 and world.inventory.count("slag") == 1, "R16 issues ingot and slag")
	# R08 mineral feed stays a plain recipe batch.
	check(world.build_facility(Vector2i(0, 3), "farm_processor")["ok"], "build the processor")
	var processor := uid_of(world, "farm_processor")
	world.grant_scaffold({"crushed_ore": 2, "grass_meal": 2, "grain_meal": 1})
	check(world.start_batch(processor, "mineral_feed")["ok"], "R08 starts after T11")
	guard = 0
	while not world.facilities[processor]["batch"].is_empty() and guard < 10:
		var b2: Dictionary = world.facilities[processor]["batch"]
		if b2["status"] == "ready": world.claim_batch(processor, int(b2["batch_id"]))
		else: world.end_day()
		guard += 1
	check(world.inventory.count("mineral_feed") == 2, "R08 issues mineral feed")
	# The sheep lives in an intensive zone: the wool round pays its iron supplement.
	for y in range(12, 14):
		for x in range(4, 8):
			check(world.rooms.set_floor(Vector2i(x, y), "ordinary")["ok"], "pave intensive floor %d,%d" % [x, y])
	for spec in [["pen", 4, 10], ["feed_trough", 6, 10], ["medium_bed", 7, 10], ["wool_station", 7, 11]]:
		check(world.build_facility(Vector2i(spec[1], spec[2]), String(spec[0]))["ok"], "build intensive " + String(spec[0]))
	var intensive_cells := []
	for y in range(10, 14):
		for x in range(4, 8): intensive_cells.append("%d,%d" % [x, y])
	var intensive: Dictionary = world.ranch.create_zone("intensive", intensive_cells, "i")
	check(intensive["ok"], "intensive zone created")
	check(world.ranch.purchase(zones["nursery"], "steel_sheep", 1)["reason"].find("床位") >= 0, "nursery without a medium bed refuses sheep")
	check(world.build_facility(Vector2i(3, 8), "medium_bed")["ok"], "add a medium bed to the nursery")
	check(world.ranch.purchase(zones["nursery"], "steel_sheep", 1)["ok"], "buy the sheep once a medium bed exists")
	for _day in range(6):
		world.end_day()
	var sheep: Array = world.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == "steel_sheep")
	check(sheep.size() == 1 and String(sheep[0]["stage"]) == "adult", "sheep adult on rations")
	var medium: Array = world.ranch.free_bed_slots(world.ranch.zone(int(intensive["zone_uid"])), "medium")
	check(world.ranch.submit({"assign": {int(sheep[0]["uid"]): {"mode": "intensive", "zone_uid": int(intensive["zone_uid"]),
		"bed_uid": int(medium[0]["uid"]), "bed_slot": int(medium[0]["slot"])}}})["ok"], "assign the sheep to the intensive zone")
	world.end_day()
	var iron_before := world.inventory.count("iron_ore")
	world.end_day()
	check(world.inventory.count("iron_ore") == iron_before - 1, "the natural round pays the iron supplement once")
	check(bool(world.ranch.animal(int(sheep[0]["uid"]))["natural"]["paid"]), "round marked paid")
	world.end_day()
	world.end_day()
	check(bool(world.ranch.animal(int(sheep[0]["uid"]))["natural"]["pending"]), "three care days finish the wool round")
	check(world.ranch.claim_natural(uid_of(world, "wool_station"))["ok"] and world.inventory.count("steel_wool") == 2 and world.inventory.count("sheep_manure") == 1, "claim issues current wool and manure through the station")

# --- 3. R17/R18 building materials ---------------------------------------------------

func _building_materials() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	preload("res://scripts/farming/tests/p107_fixture.gd").unlock(world)
	world.grant_scaffold({"raw_wood": 4, "raw_stone": 6, "grain": 2, "humus": 1, "mushroom": 1,
		"gravel": 4, "stone_powder": 2, "resin": 2, "tailings": 2, "slag": 2})
	world.primeval_stones += 20  # 测试注资：研究台与木作台
	world._cash("sales_revenue", 20)
	world.build_facility(Vector2i(2, 4), "research_bench")
	complete_research(world, 1, "flower_cultivation", {"grain": 2, "humus": 1})
	complete_research(world, 1, "beekeeping", {"nectar": 2, "pollen": 1})
	complete_research(world, 1, "farm_preparation", {"oilseed": 2, "straw": 2})
	complete_research(world, 1, "rock_handling", {"mushroom": 1, "raw_stone": 3})
	complete_research(world, 1, "ore_concentration", {"crushed_ore": 2, "gravel": 1, "fodder_grass": 2})
	complete_research(world, 1, "advanced_feed_oil_wax", {"crude_oil": 1, "beeswax": 1, "grain_meal": 1})
	complete_research(world, 1, "mineral_materials", {"ore_concentrate": 1, "iron_ingot": 1, "stone_powder": 1})
	var shop_built: Dictionary = world.build_facility(Vector2i(7, 1), "woodshop")
	check(shop_built["ok"], "build the woodshop (" + String(shop_built.get("reason", "")) + " stones " + str(world.primeval_stones) + ")")
	var woodshop := uid_of(world, "woodshop")
	check(world.start_batch(woodshop, "assemble_stone_panel")["ok"], "R17 starts")
	var guard := 0
	while not world.facilities[woodshop]["batch"].is_empty() and guard < 10:
		var b: Dictionary = world.facilities[woodshop]["batch"]
		if b["status"] == "ready": world.claim_batch(woodshop, int(b["batch_id"]))
		else: world.end_day()
		guard += 1
	check(world.inventory.count("composite_stone_panel") == 2, "R17 issues panels")
	world.grant_scaffold({"tailings": 1, "slag": 1, "stone_powder": 1})
	check(world.start_batch(woodshop, "recover_fill")["ok"], "R18 starts")
	guard = 0
	while not world.facilities[woodshop]["batch"].is_empty() and guard < 10:
		var b2: Dictionary = world.facilities[woodshop]["batch"]
		if b2["status"] == "ready": world.claim_batch(woodshop, int(b2["batch_id"]))
		else: world.end_day()
		guard += 1
	check(world.inventory.count("reclaimed_fill") == 2, "R18 issues fill")

# --- 4. Construction substitutes -----------------------------------------------------

func _construction_substitutes() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	preload("res://scripts/farming/tests/p107_fixture.gd").unlock(world)
	# Panels 1:1 replace the six stones of a smelter; nothing else changes.
	world.grant_scaffold({"wood_plank": 2, "composite_stone_panel": 6})
	world.build_substitute = "panel"
	var quoted: Dictionary = world.can_build_facility(Vector2i(7, 1), "smelter")
	check(quoted["ok"], "panel substitute quotes cleanly")
	var built: Dictionary = world.build_facility(Vector2i(7, 1), "smelter")
	check(built["ok"], "panel substitute builds")
	check(world.inventory.count("composite_stone_panel") == 0 and world.inventory.count("wood_plank") == 0, "panels consumed 1:1, planks untouched role")
	world.build_substitute = ""
	# Fill 2:1; an insufficient group fails atomically.
	world.grant_scaffold({"raw_wood": 2, "reclaimed_fill": 5})
	world.build_substitute = "fill"
	check(not world.can_build_facility(Vector2i(9, 1), "pen")["ok"], "5 fill cannot cover 3 stones x2")
	world.grant_scaffold({"reclaimed_fill": 1, "raw_wood": 4})
	for y in range(1, 3):
		for x in range(9, 11):
			world.rooms.set_floor(Vector2i(x, y), "ordinary")
	check(world.can_build_facility(Vector2i(9, 1), "pen")["ok"], "6 fill covers the group")
	check(world.build_facility(Vector2i(9, 1), "pen")["ok"], "fill substitute builds")
	check(world.inventory.count("reclaimed_fill") == 0 and world.inventory.count("raw_wood") == 0, "fill consumed 2:1, wood untouched role")
	world.build_substitute = ""
	# Substitutes never apply to facilities without plain stone.
	world.grant_scaffold({"composite_stone_panel": 1, "iron_ingot": 1})
	world.build_substitute = "fill"
	check(not world.can_build_facility(Vector2i(11, 1), "growth_lamp")["ok"], "lamp panel demand never becomes fill")
	world.build_substitute = ""

# --- 5. P8.e joint validation on real gravel -------------------------------------------

func _e_joint_validation() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	preload("res://scripts/farming/tests/p107_fixture.gd").unlock(world)
	world.grant_scaffold({"raw_wood": 90, "raw_stone": 40, "grain": 2, "humus": 1, "mushroom": 30,
		"clean_water": 60, "fodder_grass": 30, "iron_ore": 6, "charcoal": 4, "straw": 6,
		"crude_oil": 1, "beeswax": 1, "grain_meal": 1, "iron_ingot": 1})
	world.primeval_stones += 100
	world._cash("sales_revenue", 100)
	world.build_facility(Vector2i(2, 4), "research_bench")
	complete_research(world, 1, "flower_cultivation", {"grain": 2, "humus": 1})
	complete_research(world, 1, "rock_handling", {"mushroom": 1, "raw_stone": 3})
	# Real gravel from the mole closes P8.e's T08 chain.
	var zones := ranch_module(world)
	check(world.ranch.purchase(zones["nursery"], "rock_mole", 1)["ok"], "buy the gravel mole")
	var yard := uid_of(world, "rock_breaking_yard")
	for _day in range(3):
		world.end_day()
	var mole: Array = world.ranch.state["animals"].filter(func(a): return String(a["stage"]) == "adult")
	check(mole.size() == 1, "gravel mole adult")
	check(world.ranch.submit({"assign": {int(mole[0]["uid"]): {"mode": "work", "zone_uid": zones["work"]}}})["ok"], "assign the gravel mole")
	world.end_day()
	world.grant_scaffold({"raw_stone": 2})
	world.end_day()
	var claimed_yard: Dictionary = world.ranch.claim_workyard(yard)
	check(claimed_yard["ok"] and world.inventory.count("gravel") == 2, "real gravel from R13")
	# Real sewage for the sludge sample: the retired pond path is gone, the
	# body water change produces the wastewater (P10.6 §16.2.12).
	world.grant_scaffold({"twig": 4, "clean_water": 4})
	var sewage_body: Dictionary = world.water.build_fence([Vector2i(0, 14), Vector2i(1, 14)], 0)
	check(sewage_body["ok"], "fence for real sewage")
	check(world.water.change_water(int(sewage_body["body"]))["ok"], "body change for real sewage")
	# T04 on the real sewage first, then the bed it unlocks.
	check(world.build_facility(Vector2i(4, 4), "compost_bin")["ok"], "bin for sludge")
	var bin := uid_of(world, "compost_bin")
	complete_research(world, 1, "biofiltration", {"wastewater": 2, "mushroom": 1})
	check(world.build_facility(Vector2i(4, 1), "purifying_bed")["ok"], "bed for the sludge route")
	var bed := uid_of(world, "purifying_bed")
	world.husbandry.purchase(bed, 1)
	world.grant_scaffold({"clean_water": 6})
	world.husbandry.maintain(bed)
	world.end_day()
	world.husbandry.maintain(bed)
	world.end_day()
	world.grant_scaffold({"wastewater": 4, "wood_chip": 1})
	world.husbandry.maintain(bed)
	world.end_day()
	world.husbandry.maintain(bed)
	world.end_day()
	world.husbandry.claim(bed)
	check(world.inventory.count("sludge") == 1, "real sludge from R10")
	world.grant_scaffold({"sludge": 1})
	check(world.start_batch(bin, "compost_sludge")["ok"], "compost the sludge")
	var guard := 0
	while not world.facilities[bin]["batch"].is_empty() and guard < 10:
		var b: Dictionary = world.facilities[bin]["batch"]
		if b["status"] == "ready": world.claim_batch(bin, int(b["batch_id"]))
		else: world.end_day()
		guard += 1
	world.grant_scaffold({"gravel": 1})
	complete_research(world, 1, "water_recirculation", {"sludge": 1, "gravel": 1, "charcoal": 1})
	check(world.research.is_completed("water_recirculation"), "T08 done on real samples")
	# Real R09 → R11 → R12 → fish actually eat the dense meal.
	check(world.build_facility(Vector2i(7, 1), "woodshop")["ok"], "woodshop for real R09")
	var woodshop := uid_of(world, "woodshop")
	world.grant_scaffold({"charcoal": 1, "gravel": 2})
	check(world.start_batch(woodshop, "make_filter_media")["ok"], "R09 on real gravel")
	guard = 0
	while not world.facilities[woodshop]["batch"].is_empty() and guard < 10:
		var b2: Dictionary = world.facilities[woodshop]["batch"]
		if b2["status"] == "ready": world.claim_batch(woodshop, int(b2["batch_id"]))
		else: world.end_day()
		guard += 1
	world.grant_scaffold({"wastewater": 4, "filter_media": 1})
	check(world.husbandry.set_diet(bed, "special_diets", "special_diet_id", "recover_nutrients")["ok"], "bed switches to R11")
	world.husbandry.maintain(bed)
	world.end_day()
	world.husbandry.maintain(bed)
	world.end_day()
	world.husbandry.claim(bed)
	check(world.inventory.count("nutrient_liquid") == 2, "real nutrient liquid")
	check(world.build_facility(Vector2i(10, 4), "algae_tank")["ok"], "tank for real R12")
	var tank := uid_of(world, "algae_tank")
	world.grant_scaffold({"clean_water": 1, "straw": 1})
	check(world.start_batch(tank, "dense_algae_culture")["ok"], "R12 on real nutrient")
	guard = 0
	while not world.facilities[tank]["batch"].is_empty() and guard < 10:
		var b3: Dictionary = world.facilities[tank]["batch"]
		if b3["status"] == "ready": world.claim_batch(tank, int(b3["batch_id"]))
		else: world.end_day()
		guard += 1
	check(world.inventory.count("dense_algae") == 3, "real dense algae")
	# The roster carp in a fenced water nursery eats the real dense algae.
	world.grant_scaffold({"twig": 12})
	world.primeval_stones += 20
	world._cash("sales_revenue", 20)
	var nursery_fenced: Dictionary = world.water.build_fence([Vector2i(0, 15), Vector2i(1, 15), Vector2i(2, 15), Vector2i(3, 15),
		Vector2i(0, 16), Vector2i(1, 16), Vector2i(2, 16), Vector2i(3, 16),
		Vector2i(0, 17), Vector2i(1, 17), Vector2i(2, 17), Vector2i(3, 17)], 0)
	check(nursery_fenced["ok"], "fence the roster nursery")
	check(world.build_facility(Vector2i(0, 15), "pen")["ok"], "water pen builds")
	check(world.build_facility(Vector2i(2, 15), "feed_trough")["ok"], "water trough builds")
	check(world.build_facility(Vector2i(3, 15), "small_bed")["ok"], "water bed builds")
	var pool_cells := []
	for y in range(15, 18):
		for x in range(0, 4):
			pool_cells.append("%d,%d" % [x, y])
	var pool_zone: Dictionary = world.ranch.create_zone("water_nursery", pool_cells, "densepool")
	check(pool_zone["ok"], "water nursery zone")
	check(world.ranch.purchase(int(pool_zone["zone_uid"]), "filter_algae_carp", 1)["ok"], "buy the roster carp")
	var carps: Array = world.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == "filter_algae_carp")
	var carp_uid := int(carps[0]["uid"])
	check(world.ranch.set_diet(carp_uid, "dense_meal")["ok"], "carp takes the dense meal")
	world.grant_scaffold({"dense_algae": 1})
	var algae_before := world.inventory.count("dense_algae")
	world.end_day()
	check(world.inventory.count("dense_algae") == algae_before - 1, "fish consume the real dense algae")
	print("P8.f JOINT VALIDATION day ", world.clock.total_days, " stones ", world.primeval_stones)

# --- 6. Snapshot contracts ------------------------------------------------------------

func _snapshot_contracts() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	preload("res://scripts/farming/tests/p107_fixture.gd").unlock(world)
	world.grant_scaffold({"raw_wood": 90, "raw_stone": 40, "grain": 2, "humus": 1, "mushroom": 20,
		"clean_water": 40})
	world.primeval_stones += 80
	world._cash("sales_revenue", 80)
	world.build_facility(Vector2i(2, 4), "research_bench")
	complete_research(world, 1, "flower_cultivation", {"grain": 2, "humus": 1})
	complete_research(world, 1, "rock_handling", {"mushroom": 1, "raw_stone": 3})
	complete_research(world, 1, "ore_concentration", {"crushed_ore": 2, "gravel": 1, "fodder_grass": 2})
	var zones := ranch_module(world)
	check(world.ranch.purchase(zones["nursery"], "rock_belly_beast", 1)["ok"], "buy the contract beast")
	var snapshot := world.to_snapshot()
	check(P8Snapshot.normalize(snapshot)["ok"], "beast ranch snapshot round trips")
	var probe: Dictionary = snapshot.duplicate(true)
	probe["world"]["research"]["completed"].erase("ore_concentration")
	check(not P8Snapshot.normalize(probe)["ok"], "purchased beast cannot load without T07")
	probe = snapshot.duplicate(true)
	probe["world"]["ranch"]["animals"][0]["species_id"] = "bell_bee"
	check(not P8Snapshot.normalize(probe)["ok"], "foreign species on the roster rejected")
	var restored := P8World.new()
	restored.apply_snapshot(snapshot)
	check(String(restored.ranch.state["animals"][0]["species_id"]) == "rock_belly_beast", "chosen species survives reload")
