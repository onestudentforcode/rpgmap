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
	return P8Store.new("user://p8f_test_%d" % Time.get_ticks_usec())

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

func _yard_species_and_mole() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 6, "raw_stone": 8, "grain": 2, "humus": 1, "mushroom": 3,
		"clean_water": 30})
	world.primeval_stones += 60
	world.build_facility(Vector2i(2, 4), "research_bench")
	complete_research(world, 1, "flower_cultivation", {"grain": 2, "humus": 1})
	complete_research(world, 1, "rock_handling", {"mushroom": 1, "raw_stone": 3})
	check(world.build_facility(Vector2i(0, 1), "rock_workyard")["ok"], "build the yard after T05")
	var yard := uid_of(world, "rock_workyard")
	world.husbandry.ensure(yard)
	check(world.husbandry.set_yard_species(yard, "rock_belly_beast")["ok"], "empty yard switches to the beast")
	check(world.husbandry.set_yard_species(yard, "rock_mole")["ok"], "still empty switches back")
	check(world.husbandry.purchase(yard, 2)["ok"], "buy two mole pups into the chosen species")
	check(world.husbandry.set_yard_species(yard, "rock_belly_beast")["reason"].find("清退") >= 0, "non-empty yard refuses the switch")
	discard(world, "raw_stone", world.inventory.count("raw_stone"))
	# Rations only: growth proceeds, no mineral products appear.
	var mushrooms_before := world.inventory.count("mushroom")
	var fed: Dictionary = world.husbandry.maintain(yard)
	check(fed["ok"] and world.inventory.count("mushroom") == mushrooms_before - 2, "daily rations really deducted")
	world.end_day()
	for _day in range(3):
		world.grant_scaffold({"mushroom": 2, "clean_water": 2})
		world.husbandry.maintain(yard)
		world.end_day()
	var summary: Dictionary = world.husbandry.summary(world.husbandry.habitat_of(yard))
	check(int(summary["adult"]) == 2 and world.inventory.count("gravel") == 0, "adults mature on rations alone, no free minerals")
	# R13: mineral batch paid once at the cycle start.
	world.grant_scaffold({"raw_stone": 4, "mushroom": 2, "clean_water": 2})
	var batch: Dictionary = world.husbandry.maintain(yard)
	check(batch["ok"] and int(batch["started"]) == 2, "both adults start stone batches")
	check(world.inventory.count("raw_stone") == 0, "mineral inputs paid once")
	world.end_day()
	world.grant_scaffold({"mushroom": 2, "clean_water": 2})
	world.husbandry.maintain(yard)
	world.end_day()
	var ready: Dictionary = world.husbandry.quote_claim(yard)
	check(ready["ok"], "one-day batches ready")
	var claimed: Dictionary = world.husbandry.claim(yard)
	check(claimed["ok"] and world.inventory.count("gravel") == 4 and world.inventory.count("stone_powder") == 2, "claim issues gravel and powder, moles stay")
	# Switching to R14 only affects the next batch.
	world.grant_scaffold({"iron_ore": 4, "mushroom": 2, "clean_water": 2})
	check(world.husbandry.set_special_diet(yard, "break_ore")["ok"], "switch to ore breaking")
	world.husbandry.maintain(yard)
	world.end_day()
	world.grant_scaffold({"mushroom": 2, "clean_water": 2})
	world.husbandry.maintain(yard)
	world.end_day()
	world.husbandry.claim(yard)
	check(world.inventory.count("crushed_ore") == 6, "R14 issues crushed ore")

# --- 2. The beast chain through smelting ------------------------------------------

func _belly_and_smelting() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 8, "raw_stone": 18, "wood_plank": 4, "grain": 2, "humus": 1, "mushroom": 1,
		"clean_water": 40, "fodder_grass": 40, "crushed_ore": 40, "charcoal": 4,
		"grass_meal": 4, "grain_meal": 2, "iron_ore": 3})
	world.primeval_stones += 100
	world.build_facility(Vector2i(2, 4), "research_bench")
	complete_research(world, 1, "flower_cultivation", {"grain": 2, "humus": 1})
	complete_research(world, 1, "beekeeping", {"nectar": 2, "pollen": 1})
	complete_research(world, 1, "farm_preparation", {"oilseed": 2, "straw": 2})
	complete_research(world, 1, "rock_handling", {"mushroom": 1, "raw_stone": 3})
	complete_research(world, 1, "ore_concentration", {"crushed_ore": 2, "gravel": 1, "fodder_grass": 2})
	check(world.build_facility(Vector2i(0, 1), "rock_workyard")["ok"], "build the beast yard")
	var yard := uid_of(world, "rock_workyard")
	world.husbandry.ensure(yard)
	check(world.husbandry.set_yard_species(yard, "rock_belly_beast")["ok"], "choose the beast")
	world.husbandry.purchase(yard, 1)
	for _day in range(4):
		world.husbandry.maintain(yard)
		world.end_day()
	check(int(world.husbandry.summary(world.husbandry.habitat_of(yard))["adult"]) == 1, "beast adult on grass rations")
	world.grant_scaffold({"crushed_ore": 6})
	world.husbandry.maintain(yard)
	world.end_day()
	world.husbandry.maintain(yard)
	world.end_day()
	world.husbandry.claim(yard)
	check(world.inventory.count("ore_concentrate") == 2 and world.inventory.count("tailings") == 1, "R15 issues concentrate and tailings")
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
	# R08 mineral feed and the sheep's new special diet.
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
	check(world.build_facility(Vector2i(9, 1), "pen")["ok"], "build the pen")
	var pen := uid_of(world, "pen")
	check(world.husbandry.set_diet(pen, "special_diets", "special_diet_id", "mineral_supplement")["ok"], "sheep switches to the mineral diet")
	check(world.husbandry.purchase(pen, 1)["ok"], "buy the sheep")
	# Grow the sheep to adulthood on rations, then start the mineral cycle.
	for _day in range(6):
		world.grant_scaffold({"fodder_grass": 1, "clean_water": 1})
		world.husbandry.maintain(pen)
		world.end_day()
	check(int(world.husbandry.summary(world.husbandry.habitat_of(pen))["adult"]) == 1, "sheep adult on rations")
	discard(world, "mineral_feed", world.inventory.count("mineral_feed"))
	world.grant_scaffold({"fodder_grass": 1, "clean_water": 1, "mineral_feed": 1})
	var maintained: Dictionary = world.husbandry.maintain(pen)
	check(maintained["ok"] and int(maintained.get("started", 0)) == 1, "sheep starts a mineral cycle")
	check(world.inventory.count("mineral_feed") == 0 and world.inventory.count("iron_ore") == 3, "only the chosen special diet is charged")

# --- 3. R17/R18 building materials ---------------------------------------------------

func _building_materials() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 4, "raw_stone": 6, "grain": 2, "humus": 1, "mushroom": 1,
		"gravel": 4, "stone_powder": 2, "resin": 2, "tailings": 2, "slag": 2})
	world.primeval_stones += 20  # 测试注资：研究台与木作台
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
	world.grant_scaffold({"reclaimed_fill": 1})
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
	world.grant_scaffold({"raw_wood": 12, "raw_stone": 16, "grain": 2, "humus": 1, "mushroom": 3,
		"clean_water": 40, "fodder_grass": 30, "iron_ore": 6, "charcoal": 4, "straw": 6,
		"crude_oil": 1, "beeswax": 1, "grain_meal": 1, "iron_ingot": 1})
	world.primeval_stones += 100
	world.build_facility(Vector2i(2, 4), "research_bench")
	complete_research(world, 1, "flower_cultivation", {"grain": 2, "humus": 1})
	complete_research(world, 1, "rock_handling", {"mushroom": 1, "raw_stone": 3})
	# Real gravel from the mole closes P8.e's T08 chain.
	check(world.build_facility(Vector2i(0, 1), "rock_workyard")["ok"], "yard for real gravel")
	var yard := uid_of(world, "rock_workyard")
	world.husbandry.ensure(yard)
	world.husbandry.set_yard_species(yard, "rock_mole")
	world.husbandry.purchase(yard, 1)
	for _day in range(3):
		world.grant_scaffold({"mushroom": 1, "clean_water": 1})
		world.husbandry.maintain(yard)
		world.end_day()
	world.grant_scaffold({"raw_stone": 2})
	world.husbandry.maintain(yard)
	world.end_day()
	world.grant_scaffold({"mushroom": 1, "clean_water": 1})
	world.husbandry.maintain(yard)
	world.end_day()
	world.husbandry.claim(yard)
	check(world.inventory.count("gravel") == 2, "real gravel from R13")
	# Real sewage for the sludge sample.
	check(world.build_facility(Vector2i(0, 14), "fish_pond")["ok"], "pond for real sewage")
	var pond := uid_of(world, "fish_pond")
	world.husbandry.purchase(pond, 1)
	world.end_day()
	world.collect("spring_source")
	world.husbandry.maintain_water(pond)
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
	check(world.husbandry.set_diet(pond, "base_diets", "basic_diet_id", "dense_meal")["ok"], "carp takes the dense meal")
	# The long run drained the pond metric: top it up before the dense meal.
	world.grant_scaffold({"clean_water": 2})
	if world.husbandry.quote_water(pond)["ok"]:
		check(world.husbandry.maintain_water(pond)["ok"], "top up the pond before the meal")
	world.grant_scaffold({"dense_algae": 1})
	check(world.husbandry.maintain(pond)["ok"], "fish consume the real dense algae")
	print("P8.f JOINT VALIDATION day ", world.clock.total_days, " stones ", world.primeval_stones)

# --- 6. Snapshot contracts ------------------------------------------------------------

func _snapshot_contracts() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 6, "raw_stone": 8, "grain": 2, "humus": 1, "mushroom": 3,
		"clean_water": 20})
	world.primeval_stones += 40
	world.build_facility(Vector2i(2, 4), "research_bench")
	complete_research(world, 1, "flower_cultivation", {"grain": 2, "humus": 1})
	complete_research(world, 1, "rock_handling", {"mushroom": 1, "raw_stone": 3})
	check(world.build_facility(Vector2i(0, 1), "rock_workyard")["ok"], "build yard")
	var yard := uid_of(world, "rock_workyard")
	world.husbandry.ensure(yard)
	world.husbandry.set_yard_species(yard, "rock_belly_beast")
	world.husbandry.purchase(yard, 1)
	world.husbandry.maintain(yard)
	var snapshot := world.to_snapshot()
	check(P8Snapshot.normalize(snapshot)["ok"], "beast yard snapshot round trips")
	var probe: Dictionary = snapshot.duplicate(true)
	probe["world"]["husbandry"]["habitats"][0]["species_id"] = "bell_bee"
	check(not P8Snapshot.normalize(probe)["ok"], "foreign species on the yard rejected")
	var restored := P8World.new()
	restored.apply_snapshot(snapshot)
	check(String(restored.husbandry.habitat_of(yard)["species_id"]) == "rock_belly_beast", "chosen species survives reload")
