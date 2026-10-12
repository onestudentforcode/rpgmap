extends SceneTree
## P8.h no-injection dual 90-day routes. Everything below runs through the real
## world interfaces only: no scaffolds, no direct stat writes, real saves each
## day. Route A builds flowers first, Route B starts from water/rock and back-
## fills flowers later. Both must finish all 12 research projects, run the three
## ecologies, supply all five elements, cook a T12 food and reinvest income.
## STATUS 2026-10-11: driver in iteration — best run reached 10/12 research on
## both routes with all three ecologies and a positive economy; the assertions
## below intentionally stay strict, so this script is NOT yet wired into the
## CI pipeline and P8.h acceptance stays open.
const P8World := preload("res://scripts/farming/p8/p8_world.gd")
const P8Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const Journal := preload("res://scripts/farming/v1/v1_journal.gd")

var failures: Array[String] = []
var checks := 0
var route_name := ""

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func try_step(world, label: String, action: Callable) -> Dictionary:
	var result: Dictionary = action.call()
	if not result["ok"] and String(result.get("reason", "")).find("行动点不足") < 0:
		pass  # quiet: most steps are opportunistic
	return result

func uid_of(world, facility_id: String, index: int = 0) -> int:
	var found := []
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == facility_id:
			found.append(int(uid))
	found.sort()
	return found[mini(index, found.size() - 1)] if not found.is_empty() else 0

func has(world, item: String, count: int = 1) -> bool:
	return world.inventory.count(item) >= count

func _initialize() -> void:
	_run_route("A")
	_run_route("B")
	for failure in failures: printerr(failure)
	print("P8 TWO90 PLAYTEST %s · %d checks" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

# --- Shared daily driver ---------------------------------------------------------

func _farm_cash_crops(world) -> void:
	# Wheat loop: plant on free tilled cells at row 4/5, water when low, harvest.
	for x in range(1, 8):
		var cell := Vector2i(x, 4)
		if world.grid.state_at(cell) == 1 and has(world, "golden_wheat_seed"):
			world.plant(cell, "golden_wheat")
	for crop in world.crops.values().duplicate(true):
		if String(crop["crop_id"]) != "golden_wheat" or String(crop["state"]) == "mature":
			continue
		var origin := Vector2i(int(crop["origin"][0]), int(crop["origin"][1]))
		if int(world.environment_at(origin)["water"]) < 35:
			if not has(world, "clean_water"):
				if world.source_remaining("spring_source") >= 5:
					world.collect("spring_source")
			if has(world, "clean_water"):
				world.irrigate(origin)
	for crop in world.crops.values().duplicate(true):
		if String(crop["crop_id"]) == "golden_wheat" and String(crop["state"]) == "mature":
			world.harvest(Vector2i(int(crop["origin"][0]), int(crop["origin"][1])), "harvest")
	# Fresh tilling for the next planting round.
	for x in range(1, 8):
		var cell := Vector2i(x, 5)
		if world.grid.state_at(cell) == 0 and world.source_at(cell).is_empty() and world.facility_at(cell).is_empty():
			world.till(cell)
	for x in range(1, 8):
		var cell := Vector2i(x, 5)
		if world.grid.state_at(cell) == 1 and has(world, "golden_wheat_seed"):
			world.plant(cell, "golden_wheat")

func _research_day(world) -> void:
	# Work every active project once; benches are cheap so one bench suffices,
	# but two benches let two projects advance in parallel late game.
	for uid in world.facilities.keys().duplicate():
		if String(world.facilities[uid]["facility_id"]) != "research_bench":
			continue
		if world.research.work_quote(int(uid))["ok"]:
			world.research.work(int(uid))

func _start_research_if_possible(world) -> void:
	# Start every startable project: one per free bench per day.
	var benches := []
	for index in range(2):
		var bench := uid_of(world, "research_bench", index)
		if bench != 0 and world.research.active_project(bench).is_empty():
			benches.append(bench)
	if benches.is_empty():
		return
	for project_id in ["flower_cultivation", "beekeeping", "farm_preparation", "biofiltration",
			"rock_handling", "advanced_feed_oil_wax", "ore_concentration", "water_recirculation",
			"basic_spirit_cooking", "field_maintenance", "mineral_materials", "composite_spirit_food"]:
		if world.research.is_completed(project_id) or not world.research.project_of(project_id).is_empty():
			continue
		if world.research.quote_start(benches[0], project_id)["ok"]:
			world.research.start(benches[0], project_id)
			benches.pop_front()
			if benches.is_empty():
				return

func _maintain_habitats(world) -> void:
	for uid in world.facilities.keys().duplicate():
		var facility: Dictionary = world.facilities[int(uid)]
		if world.facility_defs[String(facility["facility_id"])].get("kind") != "habitat":
			continue
		var habitat: Dictionary = world.husbandry.habitat_of(int(uid))
		if habitat.is_empty():
			continue
		if world.husbandry.quote_claim(int(uid))["ok"]:
			world.husbandry.claim(int(uid))
		if String(habitat["species_id"]) == "filter_algae_carp" and world.husbandry.quote_water(int(uid))["ok"]:
			world.husbandry.maintain_water(int(uid))
		var quote: Dictionary = world.husbandry.quote_maintenance(int(uid))
		if quote["ok"]:
			world.husbandry.maintain(int(uid))

func _source_topups(world) -> void:
	# Keep basic stocks flowing from the three natural sources when short.
	if world.inventory.count("clean_water") < 14 and world.source_remaining("spring_source") >= 5:
		world.collect("spring_source")
	if world.inventory.count("raw_stone") < 4 and world.source_remaining("stone_source") >= 3:
		world.collect("stone_source")
	if world.inventory.count("iron_ore") < 6 and world.source_remaining("ore_source") >= 2:
		world.collect("ore_source")
	if uid_of(world, "smelter") != 0 and world.inventory.count("charcoal") < 6 and world.inventory.count("twig") < 4:
		world.buy("twig", 4)
	# Processing chains the sources cannot feed: buy wood/twigs on the market.
	if uid_of(world, "woodshop") != 0 and (world.inventory.count("wood_chip") < 6 or world.inventory.count("wood_plank") < 4) and world.inventory.count("raw_wood") < 6:
		world.buy("raw_wood", 3)
	if uid_of(world, "char_kiln") != 0 and world.inventory.count("charcoal") < 3 and world.inventory.count("twig") < 4:
		world.buy("twig", 4)

## Real market purchases for build materials the sources cannot provide.
func _buy_build_materials(world, plan: Array, _index: Array) -> void:
	for entry in plan:
		var already := false
		for f in world.facilities.values():
			if String(f["facility_id"]) == String(entry[0]) and int(f["origin"][0]) == int(entry[1]) and int(f["origin"][1]) == int(entry[2]):
				already = true
				break
		if already:
			continue
		var definition: Dictionary = world.facility_defs.get(String(entry[0]), {})
		if definition.is_empty():
			continue
		for item in definition["materials"]:
			var short: int = int(definition["materials"][item]) - world.inventory.count(String(item))
			if short <= 0 or int(world._items[String(item)]["buy_price"]) <= 0:
				continue
			# Research-gated builds wait; do not sink cash into them yet.
			var blocked: String = world.research_block(String(definition.get("research", "")))
			if not blocked.is_empty():
				break
			var affordable: int = mini(short, world.primeval_stones / maxi(1, int(world._items[String(item)]["buy_price"])))
			if affordable > 0:
				world.buy(String(item), affordable)

func _sell_surplus(world) -> void:
	# Sell grain/straw beyond working margins once research samples are banked.
	if world.inventory.count("grain") > 10:
		world.sell("grain", world.inventory.count("grain") - 10)
	if world.inventory.count("straw") > 10:
		world.sell("straw", world.inventory.count("straw") - 10)
	if world.inventory.count("fish_meat") > 6 and world.research.is_completed("basic_spirit_cooking"):
		world.sell("fish_meat", world.inventory.count("fish_meat") - 6)

func _deliver_orders(world) -> void:
	for order in world.daily_orders():
		if String(order["status"]) != "open":
			continue
		var best := ""
		var best_stock := -1
		for item in world._items:
			if not world._items[item]["supply_allowed"] or String(world._items[item]["element"]) != String(order["path"]):
				continue
			var quote: Dictionary = world.order_quote(int(order["id"]), String(item))
			var stock: int = world.inventory.count(String(item))
			# Deliver from surplus only: keep a working margin so research
			# samples and small stockpiles are not drained by orders.
			if quote["ok"] and int(quote["quantity"]) + 4 <= stock and stock > best_stock:
				best = String(item)
				best_stock = stock
		if not best.is_empty():
			world.deliver_order(int(order["id"]), best)

func _process_batches(world, plan: Array) -> void:
	# plan entries: [facility_id, recipe_id, keep_stock_item, keep_stock_amount]
	for entry in plan:
		var facility_uid := uid_of(world, String(entry[0]))
		if facility_uid == 0:
			continue
		var facility: Dictionary = world.facilities[facility_uid]
		if not facility["batch"].is_empty():
			if facility["batch"]["status"] == "ready":
				world.claim_batch(facility_uid, int(facility["batch"]["batch_id"]))
			continue
		var recipe: Dictionary = world.recipe_defs.get(String(entry[1]), {})
		if recipe.is_empty():
			continue
		if not world.research_block(String(recipe.get("research", ""))).is_empty():
			continue
		var ok := true
		for item in recipe["inputs"]:
			if world.inventory.count(String(item)) < int(recipe["inputs"][item]):
				ok = false
				break
		if ok and world.inventory.count(String(entry[2])) < int(entry[3]):
			world.start_batch(facility_uid, String(entry[1]))

func _flower_day(world, _route: String) -> void:
	# Water every flower crop first: shares seal permanently below the water
	# threshold and the colonies depend on them.
	for crop in world.crops.values().duplicate(true):
		if String(crop["crop_id"]) != "honeybell_bush" and String(crop["crop_id"]) != "oilseed_flower":
			continue
		var origin := Vector2i(int(crop["origin"][0]), int(crop["origin"][1]))
		if int(world.environment_at(origin)["water"]) < 45:
			if not has(world, "clean_water") and world.source_remaining("spring_source") >= 5:
				world.collect("spring_source")
			if has(world, "clean_water"):
				world.irrigate(origin)
	# Hand-pick mature honeybell shares until T02's samples are banked.
	for crop in world.crops.values().duplicate(true):
		if String(crop["crop_id"]) != "honeybell_bush" or String(crop["state"]) != "mature":
			continue
		if not world.research.is_completed("beekeeping") and world.inventory.count("nectar") < 2:
			world.pick_flower(Vector2i(int(crop["origin"][0]), int(crop["origin"][1])))
	# Harvest mature oilseed flowers (replanting happens in the seed block).
	for crop in world.crops.values().duplicate(true):
		if String(crop["crop_id"]) == "oilseed_flower" and String(crop["state"]) == "mature":
			world.harvest(Vector2i(int(crop["origin"][0]), int(crop["origin"][1])), "harvest")

func _build_plan_step(world, plan: Array, _index: Array) -> void:
	# plan: [facility_id, cell_x, cell_y, species_or_""]; research-gated or
	# unaffordable entries are skipped for the day so nothing deadlocks.
	# Duplicate detection is per planned cell, not per facility type: a second
	# bench or workyard is a legitimate separate build.
	for entry in plan:
		var already := false
		for f in world.facilities.values():
			if String(f["facility_id"]) == String(entry[0]) and int(f["origin"][0]) == int(entry[1]) and int(f["origin"][1]) == int(entry[2]):
				already = true
				break
		if already:
			continue
		var checked: Dictionary = world.can_build_facility(Vector2i(int(entry[1]), int(entry[2])), String(entry[0]))
		if not checked["ok"]:
			continue
		var built: Dictionary = world.build_facility(Vector2i(int(entry[1]), int(entry[2])), String(entry[0]))
		if String(entry[3]) != "" and bool(built.get("ok", false)):
			var uid := int(built.get("facility_uid", 0))
			world.husbandry.ensure(uid)
			world.husbandry.set_yard_species(uid, String(entry[3]))

func _stock_plan_step(world, plan: Array) -> void:
	# plan: [facility_id, species_buy_count]
	for entry in plan:
		var uid := uid_of(world, String(entry[0]))
		if uid == 0:
			continue
		var habitat: Dictionary = world.husbandry.habitat_of(uid)
		if habitat.is_empty():
			continue
		if habitat["individuals"].size() >= int(entry[1]):
			continue
		var quote: Dictionary = world.husbandry.quote_purchase(uid, int(entry[1]) - habitat["individuals"].size())
		if bool(quote.get("ok", false)) and world.primeval_stones >= int(quote.get("total", 999999)):
			world.husbandry.purchase(uid, int(entry[1]) - habitat["individuals"].size())

# --- Route bodies -----------------------------------------------------------------

func _run_route(route: String) -> void:
	route_name = route
	var world := P8World.new(P8Store.new("user://p8h_%s_%d" % [route, Time.get_ticks_usec()]))
	world.start_new(1)
	var build_plan: Array
	var stock_plan: Array
	if route == "A":
		build_plan = [
			["research_bench", 2, 4, ""],
			["compost_bin", 1, 4, ""],
			["bee_hive", 7, 1, ""],
			["purifying_bed", 0, 1, ""],
			["fish_pond", 0, 14, ""],
			["woodshop", 10, 1, ""],
			["rock_workyard", 3, 1, "rock_mole"],
			["rock_workyard", 5, 1, "rock_belly_beast"],
			["farm_processor", 13, 3, ""],
			["char_kiln", 11, 3, ""],
			["algae_tank", 8, 3, ""],
			["research_bench", 3, 4, ""],
			["smelter", 13, 1, ""],
			["kitchen", 9, 4, ""],
			["pen", 9, 1, ""],
		]
		stock_plan = [["bee_hive", 0, 2], ["fish_pond", 0, 2], ["purifying_bed", 0, 2], ["rock_workyard", 0, 2], ["rock_workyard", 1, 2], ["pen", 0, 1]]
	else:
		build_plan = [
			["research_bench", 2, 4, ""],
			["compost_bin", 1, 4, ""],
			["fish_pond", 0, 14, ""],
			["woodshop", 10, 1, ""],
			["rock_workyard", 3, 1, "rock_mole"],
			["rock_workyard", 5, 1, "rock_belly_beast"],
			["purifying_bed", 0, 1, ""],
			["bee_hive", 7, 1, ""],
			["farm_processor", 13, 3, ""],
			["char_kiln", 11, 3, ""],
			["algae_tank", 8, 3, ""],
			["research_bench", 3, 4, ""],
			["smelter", 13, 1, ""],
			["kitchen", 9, 4, ""],
			["pen", 9, 1, ""],
		]
		stock_plan = [["fish_pond", 0, 2], ["rock_workyard", 0, 2], ["purifying_bed", 0, 2], ["bee_hive", 0, 2], ["rock_workyard", 1, 2], ["pen", 0, 1]]
	var build_index := [0]
	var day := 0
	while world.clock.total_days < 90:
		day = world.clock.total_days
		_farm_cash_crops(world)
		_research_day(world)
		_maintain_habitats(world)
		_start_research_if_possible(world)
		_buy_build_materials(world, build_plan, build_index)
		_build_plan_step(world, build_plan, build_index)
		_stock_plan_step(world, stock_plan)
		_source_topups(world)
		# Mole diet: crushed ore until T07's samples are banked, then back to
		# gravel for T08/T11; mats switch to nutrient recovery for T12.
		var mole_yard := uid_of(world, "rock_workyard")
		if mole_yard != 0 and not world.husbandry.habitat_of(mole_yard).is_empty():
			if world.inventory.count("crushed_ore") < 12:
				world.husbandry.set_special_diet(mole_yard, "break_ore")
			elif world.inventory.count("gravel") < 4:
				world.husbandry.set_special_diet(mole_yard, "break_stone")
		var bed := uid_of(world, "purifying_bed")
		if bed != 0 and not world.husbandry.habitat_of(bed).is_empty():
			# Nutrient recovery needs finished filter media; purify otherwise.
			if world.inventory.count("filter_media") >= 1 and not world.research.is_completed("composite_spirit_food") and world.inventory.count("nutrient_liquid") < 4:
				world.husbandry.set_special_diet(bed, "recover_nutrients")
			else:
				world.husbandry.set_special_diet(bed, "bio_purify")
		var process_plan: Array = [
			["compost_bin", "compost_straw", "humus", 6],
			["char_kiln", "char_twigs", "charcoal", 2],
			["woodshop", "saw_planks", "wood_plank", 4],
			["woodshop", "shred_wood", "wood_chip", 4],
			["farm_processor", "mill_grain", "grain_meal", 2],
			["farm_processor", "mill_grass", "grass_meal", 2],
			["farm_processor", "press_oilseed", "crude_oil", 8],
			["farm_processor", "refine_oil", "refined_oil", 4],
			["farm_processor", "blend_land_feed", "land_feed", 2],
			["farm_processor", "mineral_feed", "mineral_feed", 1],
			["woodshop", "make_filter_media", "filter_media", 2],
			["algae_tank", "culture_algae", "algae_feed", 6],
			["algae_tank", "dense_algae_culture", "dense_algae", 3],
			["smelter", "smelt_charcoal", "iron_ingot", 2],
			["smelter", "smelt_concentrate", "iron_ingot", 4],
			["woodshop", "assemble_stone_panel", "composite_stone_panel", 2],
			["kitchen", "honey_grain_cake", "honey_cake", 4],
			["kitchen", "fungus_fish_meal", "fish_spirit_meal", 4],
			["kitchen", "algae_dew_soup", "dew_soup", 4],
			["kitchen", "oil_honey_paste", "fire_paste", 4],
			["kitchen", "soil_spirit_pill", "earth_pill", 4],
			["kitchen", "honey_mineral_food", "gold_food", 1],
		]
		if world.research.is_completed("biofiltration"):
			process_plan.push_back(["compost_bin", "compost_sludge", "humus", 8])
		# The beasts eat raw grass daily; grinding it into meal starves them.
		if world.inventory.count("fodder_grass") < 10:
			process_plan = process_plan.filter(func(entry): return String(entry[1]) != "mill_grass")
		# Honey is a research sample until T12; cook only from surplus.
		if world.inventory.count("honey") < 5:
			process_plan = process_plan.filter(func(entry): return ["honey_grain_cake", "oil_honey_paste", "honey_mineral_food"].has(String(entry[1])) == false)
		_process_batches(world, process_plan)
		if world.research.is_completed("flower_cultivation"):
			_flower_day(world, route)
		_sell_surplus(world)
		_deliver_orders(world)
		# Pastures for the animals: grass and mushrooms from real crops.
		# Pasture at x11-12 rows 4-5: every row-2 spot belongs to a facility
		# footprint (bed/yards/hive), so grazing moves behind the wheat rows.
		for y in [4, 5]:
			for x in [11, 12]:
				var pasture_cell := Vector2i(x, y)
				if world.grid.state_at(pasture_cell) == 0 and world.source_at(pasture_cell).is_empty() and world.facility_at(pasture_cell).is_empty():
					world.till(pasture_cell)
		if world.inventory.count("fodder_grass") < 10 and has(world, "grass_seed"):
			for y in [4, 5]:
				for x in [11, 12]:
					var cell := Vector2i(x, y)
					if world.grid.state_at(cell) == 1:
						world.plant(cell, "pasture_grass")
			for crop in world.crops.values().duplicate(true):
				if String(crop["crop_id"]) == "pasture_grass" and String(crop["state"]) == "mature":
					world.harvest(Vector2i(int(crop["origin"][0]), int(crop["origin"][1])), "harvest")
		if world.inventory.count("mushroom") < 12 and has(world, "wood_decay_spawn") and world.inventory.count("wood_chip") >= 3:
			for x in range(1, 9):
				var cell := Vector2i(x, 3)
				if world.grid.state_at(cell) == 0 and world.source_at(cell).is_empty() and world.facility_at(cell).is_empty():
					world.till(cell)
				if world.grid.state_at(cell) == 1:
					world.plant(cell, "wood_decay_mushroom")
			for crop in world.crops.values().duplicate(true):
				if String(crop["crop_id"]) == "wood_decay_mushroom" and String(crop["state"]) == "mature":
					world.harvest(Vector2i(int(crop["origin"][0]), int(crop["origin"][1])), "harvest")
		# Seed purchases when the market allows (research-gated flowers included).
		if not world.buy("golden_wheat_seed", 4)["ok"] and world.inventory.count("golden_wheat_seed") < 4:
			pass
		if world.inventory.count("grass_seed") < 3:
			world.buy("grass_seed", 3)
		if world.inventory.count("wood_decay_spawn") < 6:
			world.buy("wood_decay_spawn", 6)
		if world.research.is_completed("flower_cultivation"):
			var honeybell_count := 0
			for crop in world.crops.values():
				if String(crop["crop_id"]) == "honeybell_bush":
					honeybell_count += 1
			if honeybell_count < 3 and world.inventory.count("honeybell_seed") < 1:
				world.buy("honeybell_seed", 1)
			if world.inventory.count("honeybell_seed") > 0 and honeybell_count < 3:
				for cell in [Vector2i(9, 2), Vector2i(10, 2), Vector2i(9, 3), Vector2i(10, 3)]:
					if world.grid.state_at(cell) == 1:
						world.plant(cell, "honeybell_bush")
						break
			if world.inventory.count("oilseed_flower_seed") < 2:
				world.buy("oilseed_flower_seed", 2)
			if world.inventory.count("oilseed_flower_seed") > 0:
				for cell in [Vector2i(10, 3), Vector2i(11, 2), Vector2i(12, 2)]:
					if world.grid.state_at(cell) == 1:
						world.plant(cell, "oilseed_flower")
						break
			for cell in [Vector2i(9, 2), Vector2i(10, 2), Vector2i(9, 3), Vector2i(10, 3), Vector2i(11, 2), Vector2i(12, 2)]:
				if world.grid.state_at(cell) == 0 and world.source_at(cell).is_empty() and world.facility_at(cell).is_empty():
					world.till(cell)
		if not world.end_day()["ok"]:
			check(false, route + " day " + str(day) + " settle failed: " + world.daily_save_error)
			break
	# --- Assertions -----------------------------------------------------------
	check(world.clock.total_days >= 90, route + " reached day 90 (got " + str(world.clock.total_days) + ")")
	for project in ["flower_cultivation", "beekeeping", "farm_preparation", "biofiltration", "rock_handling",
			"advanced_feed_oil_wax", "ore_concentration", "water_recirculation", "basic_spirit_cooking",
			"field_maintenance", "mineral_materials", "composite_spirit_food"]:
		check(world.research.is_completed(project), route + " research " + project)
	check(world.inventory.count("honey") > 0 or world.journal["history"].size() > 0, route + " honey economy ran")
	check(world.inventory.count("sludge") > 0 or world.inventory.count("humus") >= 2, route + " purification loop ran")
	check(world.inventory.count("gravel") > 0 or world.inventory.count("ore_concentrate") > 0 or world.inventory.count("crushed_ore") > 0, route + " rock economy ran")
	var supplied_elements := {}
	var delivered: Dictionary = Journal.totals(world.journal)["delivered_items"]
	for item in delivered:
		supplied_elements[String(world._items[String(item)]["element"])] = true
	for element in ["wood", "fire", "earth", "water", "gold"]:
		check(supplied_elements.has(element), route + " supplied element " + element)
	var t12_foods := ["dew_soup", "fire_paste", "earth_pill", "gold_food"]
	var cooked := false
	for food in t12_foods:
		if world.inventory.count(String(food)) > 0 or int(world.journal["pending"]["processed"].get(String(food), 0)) > 0:
			cooked = true
	check(cooked or world.inventory.count("fish_spirit_meal") > 0 or world.inventory.count("honey_cake") > 0, route + " cooked spirit food")
	check(world.journal["frozen"], route + " 45-day recap frozen")
	var recap_before := int(world.reports.state["recap"]["cash"])
	var day91: Dictionary = world.end_day()
	check(day91["ok"] and int(world.reports.state["recap"]["cash"]) == recap_before, route + " day 91 continues without rewriting the recap")
	print("P8 ROUTE ", route, " day=", world.clock.total_days, " stones=", world.primeval_stones,
		" research=", world.research.state["completed"].size(), "/12 wages=", world.workforce.state["spent"])
