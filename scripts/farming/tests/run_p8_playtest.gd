extends SceneTree
## P8.h no-injection dual configurable routes via real world interfaces only.
## Route A leads with flowers and later delegation; B researches water/rock
## first and delegates earlier. Separate full-run books never extend the frozen
## player recap. Failed/deferred actions and every actual closed day are saved.
const P8World := preload("res://scripts/farming/p8/p8_world.gd")
const P8Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const Journal := preload("res://scripts/farming/v1/v1_journal.gd")

var failures: Array[String] = []
var checks := 0
var active_day := -1
var active_route := ""
var audit: FileAccess
var daily: FileAccess
var totals := {}
var frozen_recap := {}
var daily_count := 0
var route_summaries := {}
var audit_root := "res://.art-work/p8-playtest"
var horizon := 120
var selected_routes := ["A", "B"]
var with_expansion := false
var receipts: FileAccess
var claimed := {}
var claimed_days := {}
var receipt_index := 0
const WHEAT := [Vector2i(6, 8), Vector2i(7, 8), Vector2i(8, 8), Vector2i(9, 8)]
const MUSHROOMS := [Vector2i(0, 10), Vector2i(1, 10), Vector2i(2, 10), Vector2i(3, 10)]
const LAMP_FLOWERS := [Vector2i(6, 11), Vector2i(7, 11), Vector2i(6, 12), Vector2i(7, 12)]

func record_operation(entry: Dictionary) -> void:
	receipt_index += 1
	var row: Dictionary = entry.duplicate(true)
	row["sequence"] = receipt_index
	receipts.store_line(JSON.stringify(row))
	if row["kind"] in ["batch", "cycle"] and row["stage"] == "claim" and int(row["day"]) < horizon:
		var recipe := String(row["recipe"])
		claimed[recipe] = int(claimed.get(recipe, 0)) + 1
		if not claimed_days.has(recipe): claimed_days[recipe] = int(row["day"]) + 1
	# Ranch work-post claims aggregate several finished batches per receipt;
	# count each claimed batch under its recipe so the summary matches the
	# auditor's receipt-based tally.
	if row["kind"] == "ranch:workyard" and row["stage"] == "claim" and int(row["day"]) < horizon:
		var ranch_recipe := String(row.get("recipe", ""))
		if not ranch_recipe.is_empty():
			claimed[ranch_recipe] = int(claimed.get(ranch_recipe, 0)) + int(row.get("posts", 0))
			if not claimed_days.has(ranch_recipe): claimed_days[ranch_recipe] = int(row["day"]) + 1


func validate_layout(world, plan: Array) -> void:
	var occupied := {}
	for entry in plan:
		var definition: Dictionary = world.facility_defs[String(entry[0])]
		var origin := Vector2i(int(entry[1]), int(entry[2]))
		var size: Array = definition["footprint"]
		var terrain := "water" if definition.get("terrain") == "water" else ""
		check(world.grid.can_reserve(origin, int(size[0]), int(size[1]), "layout", 3, terrain)["ok"], active_route + " buildable footprint " + str(entry))
		for y in range(int(size[1])):
			for x in range(int(size[0])):
				var cell := origin + Vector2i(x, y)
				check(not occupied.has(cell) and world.source_at(cell).is_empty(), active_route + " no facility overlap " + str(cell))
				occupied[cell] = true
	var fields := []
	fields.append_array(WHEAT)
	for y in [4, 5]:
		for x in [11, 12]: fields.append(Vector2i(x, y))
	fields.append_array(MUSHROOMS)
	fields.append_array(LAMP_FLOWERS)
	fields.append_array([Vector2i(0, 7), Vector2i(1, 7), Vector2i(0, 8), Vector2i(1, 8), Vector2i(2, 7), Vector2i(3, 7), Vector2i(2, 8), Vector2i(3, 8)])
	fields.append_array([Vector2i(9, 2), Vector2i(10, 2), Vector2i(9, 3), Vector2i(10, 3), Vector2i(11, 2), Vector2i(12, 2)])
	for cell in fields:
		check(not occupied.has(cell) and world.source_at(cell).is_empty() and world.grid.can_till(cell)["ok"], active_route + " usable crop cell " + str(cell))

func act(world, label: String, action: Callable) -> Dictionary:
	if world.clock.total_days != active_day or not world.daily_save_error.is_empty():
		return {"ok": false, "reason": "本日已结算，留待次日"}
	var before_ap: int = world.clock.ap
	var recipes := {}
	for facility in world.facilities.values():
		var batch: Dictionary = facility["batch"]
		if not batch.is_empty(): recipes[int(batch["batch_id"])] = String(batch["recipe_id"])
	var result: Dictionary = action.call()
	audit.store_line(JSON.stringify({"day": active_day, "action": label, "ap_before": before_ap,
		"ap_after": world.clock.ap, "result": result,
		"claimed_recipe": recipes.get(int(result.get("batch_id", 0)), "") if label.begins_with("world.claim_batch") and result.get("ok") else ""}))
	return result

func _expand_business(world) -> void:
	# A late reinvestment window, not a new forced objective or free stock.
	if active_day < 100: return
	for id in world.land.parcels:
		if id not in world.land.purchased and world.primeval_stones >= int(world.land.parcels[id]["price"]) + 200:
			if world.land.quote(id)["ok"]:
				act(world,"land.buy:" + id,func(): return world.land.buy(id))
	if "east_near" in world.land.purchased:
		var cell := Vector2i(20,0)
		if world.instance_at(cell).get("state") == "mature": act(world,"expansion wheat harvest",func(): return world.harvest(cell))
		if world.grid.state_at(cell) == 0: act(world,"expansion till",func(): return world.till(cell))
		if world.grid.state_at(cell) == 1 and world.inventory.count("golden_wheat_seed") > 0:
			act(world,"expansion wheat plant",func(): return world.plant(cell,"golden_wheat"))
	if "west_water" in world.land.purchased and world.facility_at(Vector2i(-4,14)).is_empty():
		for item in world.facility_defs["fish_pond"]["materials"]:
			var gap: int = int(world.facility_defs["fish_pond"]["materials"][item]) - world.inventory.count(item)
			if gap > 0 and world.primeval_stones > 200:
				act(world,"expansion water materials",func(): return world.buy(item,gap))
		if world.can_build_facility(Vector2i(-4,14),"fish_pond")["ok"]:
			act(world,"expansion west water build",func(): return world.build_facility(Vector2i(-4,14),"fish_pond"))
	var west: Dictionary = world.facility_at(Vector2i(-4,14))
	if not west.is_empty() and world.husbandry.habitat_of(int(west["uid"]))["individuals"].is_empty() and world.primeval_stones > 200:
		act(world,"expansion west fry purchase",func(): return world.husbandry.purchase(int(west["uid"]),2))
	if not west.is_empty():
		var uid := int(west["uid"])
		for item in ["algae_feed", "grain"]:
			if world.inventory.count(item) < 2 and world.primeval_stones > 200:
				act(world,"expansion west food purchase",func(): return world.buy(item,2-world.inventory.count(item)))
		act(world,"expansion west base diet",func(): return world.husbandry.set_base_diet(uid,"algae_meal"))
		if world.husbandry.quote_claim(uid)["ok"]:
			act(world,"expansion west fish claim",func(): return world.husbandry.claim(uid))
		if world.husbandry.quote_water(uid)["ok"]:
			act(world,"expansion west water maintenance",func(): return world.husbandry.maintain_water(uid))
		if world.husbandry.quote_maintenance(uid)["ok"]:
			act(world,"expansion west fish maintenance",func(): return world.husbandry.maintain(uid))

func archive_day(world, day: int) -> void:
	if not world.daily_save_error.is_empty(): return
	var bucket: Dictionary = world.journal["history"][-1]["totals"]
	Journal.merge(totals, bucket)
	var fees := 0
	var successes := 0
	for worker in world.workforce.state["report"]["workers"]:
		fees += int(worker["fee"])
		successes += int(worker["success"])
	check(fees == successes and fees == int(bucket["labour_spend"]), active_route + " day %d wages match real work" % day)
	check(world.primeval_stones == int(world.config["initial_primeval_stones"]) + Journal.income(totals) - Journal.expense(totals) + Journal.income(world.journal["pending"]) - Journal.expense(world.journal["pending"]), active_route + " day %d cash balances including next-day opening" % day)
	daily_count += 1
	daily.store_line(JSON.stringify({"day": day, "cash": world.primeval_stones, "journal": bucket,
		"ledger": world.ledger.day_view(day - 1), "workers": world.workforce.state["report"],
		"research": world.research.to_save(), "facilities": world.to_snapshot()["world"]["facilities"],
		"husbandry": world.husbandry.to_save(), "devices": world.devices.to_save(), "report": world.reports.to_save(),
		"opening": world.ledger.day_view(-1), "opening_cash":world.journal["pending"].duplicate(true), "crops": world.to_snapshot()["world"]["crops"], "operations": world.operations.to_save(), "land": world.land.to_save()}))
	if day == 45:
		frozen_recap = world.reports.state["recap"].duplicate(true)
		write_json(active_route + "-recap45.json", frozen_recap)
	if day >= 45: check(world.reports.state["recap"] == frozen_recap, active_route + " day %d recap frozen" % day)

func write_json(name: String, value) -> void:
	var file := FileAccess.open(audit_root.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "\t"))
	file.close()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func uid_of(world, facility_id: String, index: int = 0) -> int:
	var found := []
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == facility_id:
			found.append(int(uid))
	found.sort()
	return found[index] if index >= 0 and index < found.size() else 0

func count_of(world, facility_id: String) -> int:
	var total := 0
	for f in world.facilities.values():
		if String(f["facility_id"]) == facility_id:
			total += 1
	return total

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--audit-root="): audit_root = argument.trim_prefix("--audit-root=")
		if argument.begins_with("--days="): horizon = int(argument.trim_prefix("--days="))
		if argument.begins_with("--route="): selected_routes = [argument.trim_prefix("--route=")]
		if argument == "--with-expansion": with_expansion = true
	check(horizon >= 90 and horizon <= 180, "经营跨度在90至180日内")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(audit_root))
	var manifest := {}
	for name in ["content/farming/p8/production.json", "content/farming/baked/p8/production.json",
			"scripts/farming/p8/p10_logistics.gd", "scripts/farming/p8/p10_ui.gd",
			"content/farming/p8/expansion.json", "content/farming/baked/p8/expansion.json", "scripts/farming/p8/p8_land.gd", "scripts/farming/p8/p8_data.gd", "scripts/farming/core/grid/land_grid.gd", "scripts/farming/v1/v1_world_state.gd",
			"content/farming/baked/maps/farm_02.json", "scripts/farming/tests/run_p8_playtest.gd",
			"scripts/farming/p8/p8_flowers.gd", "scripts/farming/p8/p8_world.gd",
			"scripts/farming/p8/p8_operations.gd", "scripts/farming/p8/p8_husbandry.gd", "scripts/farming/p8/p8_devices.gd", "scripts/farming/p8/p8_snapshot.gd", "scripts/farming/p8/p8_scene.gd", "scripts/farming/p8/p8_workforce.gd", "scripts/farming/p8/p8_research.gd",
			"scripts/farming/v1/v1_world.gd", "scripts/farming/v2/v2_husbandry.gd", "scripts/farming/v2/v2_resource_ledger.gd"]:
		manifest[name] = FileAccess.get_sha256("res://" + name)
	write_json("manifest.json", manifest)
	for route in selected_routes: _run_route(String(route))
	if selected_routes.size() == 2:
		check(route_summaries["A"]["research_order"] != route_summaries["B"]["research_order"], "routes have different research histories")
	var summary := FileAccess.open(audit_root.path_join("summary.json"), FileAccess.WRITE)
	summary.store_string(JSON.stringify({"settings": {"days": horizon, "expansion": with_expansion, "initial_currency": int(P8World.P8Data.load_data()["config"]["initial_primeval_stones"])}, "routes": route_summaries, "failures": failures, "checks": checks}, "\t"))
	for failure in failures: printerr(failure)
	print("P8 OPERATIONS PLAYTEST %s · %d days · %d checks" % ["OK" if failures.is_empty() else "FAIL", horizon, checks])
	quit(0 if failures.is_empty() else 1)

# --- Research -----------------------------------------------------------------------

func _research_day(world) -> void:
	for uid in world.facilities.keys().duplicate():
		if String(world.facilities[uid]["facility_id"]) == "research_bench" and world.research.work_quote(int(uid))["ok"]:
			if world.operations.owner_of(int(uid)) != 0: continue
			act(world, "world.research.work(int(uid))", func(): return world.research.work(int(uid)))

func _start_research(world) -> void:
	var benches := []
	for uid in world.facilities.keys().duplicate():
		if String(world.facilities[uid]["facility_id"]) == "research_bench" and world.research.active_project(int(uid)).is_empty():
			benches.append(int(uid))
	if benches.is_empty():
		return
	var projects := ["flower_cultivation", "beekeeping", "farm_preparation", "biofiltration",
			"rock_handling", "advanced_feed_oil_wax", "ore_concentration", "water_recirculation",
			"basic_spirit_cooking", "mineral_materials", "field_maintenance", "composite_spirit_food"]
	if active_route == "B":
		projects.erase("biofiltration")
		projects.erase("rock_handling")
		projects.push_front("biofiltration")
		projects.push_front("rock_handling")
	for project_id in projects:
		if world.research.is_completed(project_id) or not world.research.project_of(project_id).is_empty():
			continue
		if world.research.quote_start(benches[0], project_id)["ok"]:
			act(world, "world.research.start(benches[0], project_id)", func(): return world.research.start(benches[0], project_id))
			benches.pop_front()
			if benches.is_empty():
				return

# --- Habitat upkeep -------------------------------------------------------------------

func _configure_habitats(world) -> void:
	for uid in world.facilities:
		if with_expansion and world.facilities[uid]["origin"] == [-4,14]: continue
		var habitat: Dictionary = world.husbandry.habitat_of(int(uid))
		if habitat.is_empty(): continue
		var species := String(habitat["species_id"])
		var recipe := String(habitat["special_diet_id"])
		var target := ""
		var quantity := 8
		match species:
			"bell_bee":
				recipe = "honey_cycle"; target = "honey"; quantity = 14
			"rock_mole":
				recipe = "break_stone" if world.inventory.count("gravel") < 8 else "break_ore"
				target = "gravel" if recipe == "break_stone" else "crushed_ore"; quantity = 8 if recipe == "break_stone" else 20
			"rock_belly_beast":
				recipe = "concentrate_ore"; target = "ore_concentrate"
				if world.inventory.count("land_feed") > 0:
					act(world, "beast compound base feed", func(): return world.husbandry.set_base_diet(int(uid), "land_meal"))
				else:
					act(world, "beast grass base feed", func(): return world.husbandry.set_base_diet(int(uid), "grass_water_meal"))
			"purifying_mat":
				recipe = "recover_nutrients" if world.research.is_completed("water_recirculation") and world.inventory.count("filter_media") > 0 and world.inventory.count("nutrient_liquid") < 6 and active_day < horizon - 12 else "bio_purify"
				target = "nutrient_liquid" if recipe == "recover_nutrients" else "sludge"; quantity = 6
			"filter_algae_carp":
				recipe = "grain_fatten"; target = "fish_meat"; quantity = 8
				var diet := "water_meal" if world.inventory.count("water_feed") >= 2 else ("dense_meal" if world.inventory.count("dense_algae") >= 4 else "algae_meal")
				act(world, "fish base feed", func(): return world.husbandry.set_base_diet(int(uid), diet))
			"steel_sheep":
				recipe = "mineral_supplement" if world.inventory.count("mineral_feed") > 0 else "iron_supplement"
				target = "steel_wool"; quantity = 4
		if target.is_empty(): continue
		var current: Dictionary = world.operations.state["production"].get(int(uid), {})
		if current.get("recipe_id") != recipe or current.get("target_qty") != quantity or not current.get("enabled", false):
			act(world, "habitat target " + recipe, func(): return world.operations.set_production(int(uid), true, recipe, target, quantity))

func _maintain_habitats(world) -> void:
	for uid in world.facilities.keys().duplicate():
		var facility: Dictionary = world.facilities[int(uid)]
		if world.facility_defs[String(facility["facility_id"])].get("kind") != "habitat":
			continue
		var habitat: Dictionary = world.husbandry.habitat_of(int(uid))
		if habitat.is_empty():
			continue
		if world.operations.owner_of(int(uid)) != 0: continue
		if world.husbandry.quote_claim(int(uid))["ok"]:
			act(world, "world.husbandry.claim(int(uid))", func(): return world.husbandry.claim(int(uid)))
		if String(habitat["species_id"]) == "filter_algae_carp" and world.husbandry.quote_water(int(uid))["ok"]:
			act(world, "world.husbandry.maintain_water(int(uid))", func(): return world.husbandry.maintain_water(int(uid)))
		var quote: Dictionary = world.husbandry.quote_maintenance(int(uid))
		if quote["ok"]:
			act(world, "world.husbandry.maintain(int(uid))", func(): return world.husbandry.maintain(int(uid)))

# --- Farming ---------------------------------------------------------------------------

func _farm_wheat(world) -> void:
	for crop in world.crops.values().duplicate(true):
		if String(crop["crop_id"]) == "golden_wheat" and String(crop["state"]) == "mature":
			act(world, "world.harvest(Vector2i(int(crop[\"origin\"][0]), int(crop[\"origin\"][1])), \"harvest\")", func(): return world.harvest(Vector2i(int(crop["origin"][0]), int(crop["origin"][1])), "harvest"))
	for cell in WHEAT:
		if world.grid.state_at(cell) == 0 and world.source_at(cell).is_empty() and world.facility_at(cell).is_empty():
			act(world, "world.till(cell)", func(): return world.till(cell))
	for cell in WHEAT:
		if world.grid.state_at(cell) == 1 and world.inventory.count("golden_wheat_seed") > 0:
			act(world, "world.plant(cell, \"golden_wheat\")", func(): return world.plant(cell, "golden_wheat"))
	for crop in world.crops.values().duplicate(true):
		if String(crop["crop_id"]) != "golden_wheat" or String(crop["state"]) == "mature":
			continue
		var origin := Vector2i(int(crop["origin"][0]), int(crop["origin"][1]))
		if int(world.environment_at(origin)["water"]) < 35 and world.inventory.count("clean_water") >= 1:
			act(world, "world.irrigate(origin)", func(): return world.irrigate(origin))

func _farm_feed(world) -> void:
	for crop in world.crops.values().duplicate(true):
		if String(crop["crop_id"]) == "pasture_grass" and String(crop["state"]) == "mature":
			act(world, "world.harvest(Vector2i(int(crop[\"origin\"][0]), int(crop[\"origin\"][1])), \"harvest\")", func(): return world.harvest(Vector2i(int(crop["origin"][0]), int(crop["origin"][1])), "harvest"))
	for y in [4, 5]:
		for x in [11, 12]:
			var cell := Vector2i(x, y)
			if world.grid.state_at(cell) == 0 and world.source_at(cell).is_empty() and world.facility_at(cell).is_empty():
				act(world, "world.till(cell)", func(): return world.till(cell))
	if world.inventory.count("fodder_grass") < 10 and world.inventory.count("grass_seed") > 0:
		for y in [4, 5]:
			for x in [11, 12]:
				var cell := Vector2i(x, y)
				if world.grid.state_at(cell) == 1 and world.inventory.count("grass_seed") > 0:
					act(world, "world.plant(cell, \"pasture_grass\")", func(): return world.plant(cell, "pasture_grass"))
	for crop in world.crops.values().duplicate(true):
		if String(crop["crop_id"]) == "wood_decay_mushroom" and String(crop["state"]) == "mature":
			act(world, "world.harvest(Vector2i(int(crop[\"origin\"][0]), int(crop[\"origin\"][1])), \"harvest\")", func(): return world.harvest(Vector2i(int(crop["origin"][0]), int(crop["origin"][1])), "harvest"))
	if world.inventory.count("mushroom") < 30 and world.inventory.count("wood_decay_spawn") > 0 and world.inventory.count("wood_chip") >= 3:
		for cell in MUSHROOMS:
			if world.grid.state_at(cell) == 0 and world.source_at(cell).is_empty() and world.facility_at(cell).is_empty():
				act(world, "world.till(cell)", func(): return world.till(cell))
			if world.grid.state_at(cell) == 1 and world.inventory.count("wood_chip") >= 3 and world.inventory.count("wood_decay_spawn") > 0:
				act(world, "world.plant(cell, \"wood_decay_mushroom\")", func(): return world.plant(cell, "wood_decay_mushroom"))

func _farm_flowers(world) -> void:
	for crop in world.crops.values().duplicate(true):
		if String(crop["crop_id"]) != "honeybell_bush" and String(crop["crop_id"]) != "oilseed_flower":
			continue
		var origin := Vector2i(int(crop["origin"][0]), int(crop["origin"][1]))
		if not (origin in LAMP_FLOWERS) and int(world.environment_at(origin)["water"]) < 45 and world.inventory.count("clean_water") >= 1:
			act(world, "world.irrigate(origin)", func(): return world.irrigate(origin))
		if not (origin in LAMP_FLOWERS) and int(world.environment_at(origin)["fertility"]) < 45 and world.inventory.count("humus") >= 1:
			act(world, "world.fertilize(origin)", func(): return world.fertilize(origin))
	for crop in world.crops.values().duplicate(true):
		if String(crop["crop_id"]) == "honeybell_bush" and String(crop["state"]) == "mature":
			if not world.research.is_completed("beekeeping") and world.inventory.count("nectar") < 2:
				act(world, "world.pick_flower(Vector2i(int(crop[\"origin\"][0]), int(crop[\"origin\"][1])))", func(): return world.pick_flower(Vector2i(int(crop["origin"][0]), int(crop["origin"][1]))))
	for crop in world.crops.values().duplicate(true):
		if String(crop["crop_id"]) == "oilseed_flower" and String(crop["state"]) == "mature":
			act(world, "world.harvest(Vector2i(int(crop[\"origin\"][0]), int(crop[\"origin\"][1])), \"harvest\")", func(): return world.harvest(Vector2i(int(crop["origin"][0]), int(crop["origin"][1])), "harvest"))
	if not world.research.is_completed("flower_cultivation"):
		return
	var flower_cells := [Vector2i(9, 2), Vector2i(10, 2), Vector2i(9, 3), Vector2i(10, 3), Vector2i(11, 2), Vector2i(12, 2)]
	for cell in flower_cells:
		if world.grid.state_at(cell) == 0 and world.source_at(cell).is_empty() and world.facility_at(cell).is_empty():
			act(world, "world.till(cell)", func(): return world.till(cell))
	var honeybells := 0
	for crop in world.crops.values():
		if String(crop["crop_id"]) == "honeybell_bush":
			honeybells += 1
	if honeybells < 3 and world.inventory.count("honeybell_seed") == 0:
		act(world, "world.buy(\"honeybell_seed\", 1)", func(): return world.buy("honeybell_seed", 1))
	if world.inventory.count("honeybell_seed") > 0 and honeybells < 3:
		for cell in flower_cells:
			if world.grid.state_at(cell) == 1:
				act(world, "world.plant(cell, \"honeybell_bush\")", func(): return world.plant(cell, "honeybell_bush"))
				break
	if world.inventory.count("oilseed_flower_seed") < 2:
		act(world, "world.buy(\"oilseed_flower_seed\", 2)", func(): return world.buy("oilseed_flower_seed", 2))
	if world.inventory.count("oilseed_flower_seed") > 0:
		for cell in flower_cells:
			if world.grid.state_at(cell) == 1:
				act(world, "world.plant(cell, \"oilseed_flower\")", func(): return world.plant(cell, "oilseed_flower"))
				break

func _farm_trees(world) -> void:
	for pair in [["fast_fir", Vector2i(0, 7)], ["resin_tree", Vector2i(2, 7)]]:
		var id := String(pair[0])
		var cell: Vector2i = pair[1]
		var crop: Dictionary = world.instance_at(cell)
		if not crop.is_empty():
			if crop["state"] == "mature":
				act(world, "harvest tree " + id, func(): return world.harvest(cell, "fell" if id == "fast_fir" else "harvest"))
			elif world.environment_at(cell)["water"] < 35 and world.inventory.count("clean_water") >= 1:
				act(world, "water tree", func(): return world.irrigate(cell))
			continue
		if world.inventory.count(String(world.crop_defs[id]["seed"])) == 0 and world.primeval_stones >= 40:
			act(world, "tree seed purchase", func(): return world.buy(String(world.crop_defs[id]["seed"]), 1))
		var footprint: Array = world.crop_defs[id]["footprint"]
		for y in range(int(footprint[1])):
			for x in range(int(footprint[0])):
				var part := cell + Vector2i(x, y)
				if world.grid.state_at(part) == 0:
					act(world, "till tree footprint", func(): return world.till(part))
		if world.inventory.count(String(world.crop_defs[id]["seed"])) > 0:
			act(world, "plant tree " + id, func(): return world.plant(cell, id))

func _farm_lamp_flowers(world) -> void:
	if uid_of(world, "growth_lamp") == 0: return
	for index in range(LAMP_FLOWERS.size()):
		var cell: Vector2i = LAMP_FLOWERS[index]
		if not world.instance_at(cell).is_empty(): continue
		var id := "honeybell_bush" if index < 2 else "oilseed_flower"
		var seed := String(world.crop_defs[id]["seed"])
		if world.inventory.count(seed) == 0:
			act(world, "lamp field seed purchase", func(): return world.buy(seed, 1))
		if world.grid.state_at(cell) == 0:
			act(world, "till lamp field", func(): return world.till(cell))
		if world.grid.state_at(cell) == 1 and world.inventory.count(seed) > 0:
			act(world, "plant lamp flower", func(): return world.plant(cell, id))
	_hand_surplus(world, uid_of(world, "bee_hive", 1))

func _hand_surplus(world, hive: int) -> void:
	if hive == 0: return
	var candidates: Array = world.flowers.hive_candidates(hive)
	while candidates.size() > 2:
		var honeybell := 0
		for uid in candidates:
			if world.crops[int(uid)]["crop_id"] == "honeybell_bush":
				honeybell = int(uid)
				break
		if honeybell == 0 or world.clock.total_days != active_day: break
		var crop: Dictionary = world.crops[honeybell]
		var cell := Vector2i(int(crop["origin"][0]), int(crop["origin"][1]))
		var picked: Dictionary = act(world, "hand pick surplus shared flower", func(): return world.pick_flower(cell))
		if not picked["ok"]: break
		candidates = world.flowers.hive_candidates(hive)

func _configure_devices(world) -> void:
	var station := uid_of(world, "field_service_station")
	if station != 0 and world.devices.device_of(station).is_empty():
		act(world, "configure field services", func(): return world.devices.configure_station(station, true, true, 45))
	var lamp := uid_of(world, "growth_lamp")
	if lamp != 0:
		# Reserve working capital in oil: load shedding leaves processing room
		# for wax and spirit food instead of permanently starving those recipes.
		var lit: bool = world.inventory.count("refined_oil") >= 4
		if world.devices.device_of(lamp).get("enabled", false) != lit:
			act(world, "lamp fuel reserve switch", func(): return world.devices.configure_lamp(lamp, lit))

# --- Economy ------------------------------------------------------------------------------

func _source_topups(world) -> void:
	while world.inventory.count("clean_water") < 20 and world.source_remaining("spring_source") >= 5 \
			and world.clock.total_days == active_day and world.daily_save_error.is_empty():
		act(world, "world.collect(\"spring_source\")", func(): return world.collect("spring_source"))
	if world.inventory.count("raw_stone") < 6 and world.source_remaining("stone_source") >= 3:
		act(world, "world.collect(\"stone_source\")", func(): return world.collect("stone_source"))
	if world.inventory.count("iron_ore") < 10 and world.source_remaining("ore_source") >= 2:
		act(world, "world.collect(\"ore_source\")", func(): return world.collect("ore_source"))
	if count_of(world, "woodshop") > 0 and world.inventory.count("raw_wood") < 3:
		var wood_price := int(world._items["raw_wood"]["buy_price"])
		var wood_buy: int = mini(3 - world.inventory.count("raw_wood"), maxi(0, world.primeval_stones - 20) / maxi(1, wood_price))
		if wood_buy > 0:
			act(world, "world.buy(\"raw_wood\", wood_buy)", func(): return world.buy("raw_wood", wood_buy))
	if count_of(world, "char_kiln") > 0 and world.inventory.count("charcoal") < 6 and world.inventory.count("twig") < 4:
		var twig_price := int(world._items["twig"]["buy_price"])
		var twig_buy: int = mini(4 - world.inventory.count("twig"), maxi(0, world.primeval_stones - 20) / maxi(1, twig_price))
		if twig_buy > 0:
			act(world, "world.buy(\"twig\", twig_buy)", func(): return world.buy("twig", twig_buy))

func _buy_build_materials(world, plan: Array) -> void:
	var pending := 0
	for entry in plan:
		var already := false
		for f in world.facilities.values():
			if String(f["facility_id"]) == String(entry[0]) and int(f["origin"][0]) == int(entry[1]) and int(f["origin"][1]) == int(entry[2]):
				already = true
				break
		if already:
			continue
		if String(entry[0]) == "bee_hive" and int(entry[1]) == 5 and not world.research.is_completed("mineral_materials"): continue
		if String(entry[0]) == "farm_processor" and int(entry[1]) == 10 and not world.research.is_completed("advanced_feed_oil_wax"): continue
		var definition: Dictionary = world.facility_defs.get(String(entry[0]), {})
		if definition.is_empty():
			continue
		if not world.research_block(String(definition.get("research", ""))).is_empty():
			continue
		pending += 1
		if pending > 3:
			return
		for item in definition["materials"]:
			var short: int = int(definition["materials"][item]) - world.inventory.count(String(item))
			if short <= 0 or int(world._items[String(item)]["buy_price"]) <= 0:
				continue
			var affordable: int = mini(short, maxi(0, world.primeval_stones - 20) / maxi(1, int(world._items[String(item)]["buy_price"])))
			if affordable > 0:
				act(world, "world.buy(String(item), affordable)", func(): return world.buy(String(item), affordable))

func _build_plan_step(world, plan: Array) -> void:
	for entry in plan:
		var already := false
		for f in world.facilities.values():
			if String(f["facility_id"]) == String(entry[0]) and int(f["origin"][0]) == int(entry[1]) and int(f["origin"][1]) == int(entry[2]):
				already = true
				break
		if already:
			continue
		if String(entry[0]) == "bee_hive" and int(entry[1]) == 5 and not world.research.is_completed("mineral_materials"): continue
		if String(entry[0]) == "farm_processor" and int(entry[1]) == 10 and not world.research.is_completed("advanced_feed_oil_wax"): continue
		if String(entry[3]) != "":
			var gate := String(world.husbandry.species_defs[String(entry[3])].get("research", ""))
			if not world.research_block(gate).is_empty(): continue
		if not world.can_build_facility(Vector2i(int(entry[1]), int(entry[2])), String(entry[0]))["ok"]:
			continue
		var built: Dictionary = act(world, "build " + str(entry), func(): return world.build_facility(Vector2i(int(entry[1]), int(entry[2])), String(entry[0])))
		if String(entry[3]) != "" and bool(built.get("ok", false)):
			var uid := int(built.get("facility_uid", 0))
			act(world, "world.husbandry.ensure(uid)", func(): return world.husbandry.ensure(uid))
			act(world, "world.husbandry.set_yard_species(uid, String(entry[3]))", func(): return world.husbandry.set_yard_species(uid, String(entry[3])))

func _stock_plan_step(world, plan: Array) -> void:
	for entry in plan:
		var uid := uid_of(world, String(entry[0]), int(entry[1]))
		if uid == 0:
			continue
		var habitat: Dictionary = world.husbandry.habitat_of(uid)
		if habitat.is_empty():
			continue
		if habitat["individuals"].size() >= int(entry[2]):
			continue
		var quote: Dictionary = world.husbandry.quote_purchase(uid, int(entry[2]) - habitat["individuals"].size())
		if bool(quote.get("ok", false)) and world.primeval_stones >= int(quote.get("total", 999999)):
			act(world, "world.husbandry.purchase(uid, int(entry[2]) - habitat[\"individuals\"].size())", func(): return world.husbandry.purchase(uid, int(entry[2]) - habitat["individuals"].size()))

func _process_batches(world, plan: Array) -> void:
	for item in world._items:
		var keep := sample_reserve(world, String(item))
		if keep != int(world.operations.state["reserves"].get(item, 0)):
			act(world, "reserve research samples " + String(item), func(): return world.operations.set_reserve(String(item), keep))
	var handled := {}
	# Unclaimed recipes have first refusal, but only when their real inputs exist.
	plan = plan.filter(func(entry): return String(entry[0]) != "kitchen" or int(claimed.get(String(entry[1]), 0)) < 2)
	var ordered: Array = plan.filter(func(entry): return not claimed.has(String(entry[1])))
	ordered.append_array(plan.filter(func(entry): return claimed.has(String(entry[1]))))
	# Fuel is an operating input: prioritise replenishment ahead of optional meals.
	for rid in ["press_oilseed", "refine_oil", "mill_grain"]:
		if (rid == "refine_oil" and world.inventory.count("refined_oil") < 4) or (rid == "press_oilseed" and world.inventory.count("crude_oil") < 4) or (rid == "mill_grain" and world.operations.effective_stock("grain_meal") < 2):
			for entry in plan:
				if String(entry[1]) == rid:
					ordered.erase(entry)
					ordered.push_front(entry)
					break
	# A requested new product gets one production window before repeating
	# established buffer recipes; fuel shortages pause lamps safely meanwhile.
	var first_products: Array = ordered.filter(func(entry): return not claimed.has(String(entry[1])))
	first_products.append_array(ordered.filter(func(entry): return claimed.has(String(entry[1]))))
	for entry in first_products:
		var facility_uid := uid_of(world, String(entry[0]), int(entry[4]) if entry.size() > 4 else 0)
		if facility_uid == 0 or handled.has(facility_uid): continue
		var facility: Dictionary = world.facilities[facility_uid]
		if not facility["batch"].is_empty() and world.operations.owner_of(facility_uid) == 0:
			var batch: Dictionary = facility["batch"]
			if String(batch.get("status", "")) == "ready":
				act(world, "world.claim_batch", func(): return world.claim_batch(facility_uid, int(batch["batch_id"])))
			handled[facility_uid] = true
			continue
		# Configure the NEXT batch while the paid batch is still running/ready.
		# Otherwise an owner can claim and restart it in the same settlement,
		# leaving the driver no idle window in which to select another recipe.
		var recipe: Dictionary = world.recipe_defs.get(String(entry[1]), {})
		if recipe.is_empty() or not world.research_block(String(recipe.get("research", ""))).is_empty(): continue
		var ok := true
		for item in recipe["inputs"]:
			if world.operations.effective_stock(String(item)) < int(recipe["inputs"][item]) + sample_reserve(world, String(item)):
				ok = false
		var target := int(entry[3])
		if not claimed.has(String(entry[1])):
			target = maxi(target, world.operations.effective_stock(String(entry[2])) + int(recipe["outputs"][String(entry[2])]))
		if not ok or world.operations.effective_stock(String(entry[2])) >= target: continue
		if world.operations.owner_of(facility_uid) != 0:
			act(world, "configure automatic processing " + String(entry[1]), func(): return world.operations.set_production(facility_uid, true, String(entry[1]), String(entry[2]), target))
		else:
			act(world, "world.start_batch " + String(entry[1]), func(): return world.start_batch(facility_uid, String(entry[1])))
		handled[facility_uid] = true
	# An idle owner must not keep an obsolete strategy that starves the next recipe.
	for uid in world.facilities:
		if world.operations.owner_of(int(uid)) == 0 or handled.has(int(uid)): continue
		var strategy: Dictionary = world.operations.state["production"].get(int(uid), {})
		if strategy.get("enabled", false) and not world.operations.recipe_definition(int(uid), String(strategy["recipe_id"])).get("living", false):
			var kind := String(world.facility_defs[String(world.facilities[uid]["facility_id"])].get("kind", ""))
			if kind != "habitat":
				act(world, "pause idle processor", func(): return world.operations.set_production(int(uid), false, String(strategy["recipe_id"]), String(strategy["target_item"]), int(strategy["target_qty"])))


func _delegate(world) -> void:
	if world.clock.total_days != active_day: return
	if world.workforce.state["workers"].is_empty():
		if active_day < (35 if active_route == "A" else 20) or world.primeval_stones < 12: return
		act(world, "hire facility owner", func(): return world.workforce.hire("Owner " + active_route))
	if world.workforce.state["workers"].size() == 1 and active_day >= 50 and world.primeval_stones >= 80:
		act(world, "hire processing owner", func(): return world.workforce.hire("Processing " + active_route))
	for worker in world.workforce.state["workers"]:
		var ident := int(worker["id"])
		act(world, "configure shared work budget", func(): return world.workforce.configure(ident, 6 if ident == 1 else 12, false, worker["priorities"], []))
		if ident == 2:
			act(world, "explicit farm duty", func(): return world.workforce.set_farm_duty(ident, true, "normal"))
			act(world, "assign spring collection", func(): return world.workforce.assign_source("spring_source", ident))
		for uid in world.facilities:
			if with_expansion and world.facilities[uid]["origin"] == [-4,14]: continue
			var type_id := String(world.facilities[uid]["facility_id"])
			var first := type_id in ["fish_pond", "purifying_bed", "research_bench"] or (type_id == "bee_hive" and int(uid) == uid_of(world, "bee_hive"))
			if (ident == 1) != first or type_id in ["field_service_station", "growth_lamp"]: continue
			if type_id == "fish_pond" and not world.research.is_completed("water_recirculation"): continue
			if world.operations.owner_of(int(uid)) == 0:
				act(world, "assign facility owner", func(): return world.operations.assign_owner(int(uid), ident))


# --- P10.3 ranch business ---------------------------------------------------------------

## Ordinary-floor block for the ranch module; a few cells per day keeps the AP
## budget shared with the rest of the route.
const RANCH_PAVE := {
	"nursery": [Vector2i(0, 11), Vector2i(1, 11), Vector2i(2, 11), Vector2i(3, 11), Vector2i(4, 11),
		Vector2i(0, 12), Vector2i(1, 12), Vector2i(2, 12), Vector2i(3, 12), Vector2i(4, 12)],
	"work": [Vector2i(8, 11), Vector2i(9, 11), Vector2i(10, 11), Vector2i(11, 11), Vector2i(12, 11), Vector2i(13, 11),
		Vector2i(8, 12), Vector2i(9, 12), Vector2i(10, 12), Vector2i(11, 12), Vector2i(12, 12), Vector2i(13, 12)],
	"maintenance": [Vector2i(4, 10), Vector2i(5, 10), Vector2i(6, 10), Vector2i(7, 10), Vector2i(8, 10), Vector2i(9, 10)],
	"pasture": [Vector2i(8, 13), Vector2i(9, 13), Vector2i(10, 13), Vector2i(11, 13), Vector2i(12, 13),
		Vector2i(13, 13), Vector2i(14, 13), Vector2i(15, 13), Vector2i(16, 13), Vector2i(17, 13), Vector2i(18, 13), Vector2i(19, 13)],
}

func _ranch_pave(world) -> void:
	var want := 0
	for group in RANCH_PAVE.values():
		want += group.size()
	var paved := 0
	for group in RANCH_PAVE.values():
		for cell in group:
			if world.rooms.floor_kind(cell) == "ordinary":
				paved += 1
	if paved >= want:
		return
	if world.inventory.count("raw_wood") < 6 and world.primeval_stones >= 240:
		act(world, "ranch paving wood purchase", func(): return world.buy("raw_wood", mini(40 - world.inventory.count("raw_wood"), int(world.primeval_stones / 8))))
	var budget := 8
	for group in RANCH_PAVE.values():
		for cell in group:
			if budget <= 0:
				return
			if world.rooms.floor_kind(cell) != "ordinary":
				var result: Dictionary = act(world, "ranch pave " + str(cell), func(): return world.rooms.set_floor(cell, "ordinary"))
				if result.get("ok", false):
					budget -= 1

func _ranch_zone_of(world, type_id: String) -> int:
	for row in world.ranch.state["zones"]:
		if String(row["type"]) == type_id:
			return int(row["uid"])
	return 0

func _ranch_module_ready(world) -> bool:
	# The sorting yard joins later through its own research gate; the mineral
	# economy only needs the breaking yard to start.
	for spec in [["pen", 0, 11], ["feed_trough", 2, 11], ["feed_trough", 3, 11], ["small_bed", 4, 11],
			["dispatch_station", 8, 11], ["rock_breaking_yard", 9, 11],
			["feed_trough", 4, 10], ["feed_trough", 7, 10], ["small_bed", 8, 10]]:
		if world.facility_at(Vector2i(int(spec[1]), int(spec[2]))).is_empty():
			return false
	return true

func _ranch_business(world) -> void:
	if not world.research.is_completed("rock_handling") or not _ranch_module_ready(world):
		return
	var cells_of := func(group: String) -> Array:
		var out := []
		for cell in RANCH_PAVE[group]:
			out.append("%d,%d" % [cell.x, cell.y])
		return out
	if _ranch_zone_of(world, "nursery") == 0:
		act(world, "ranch nursery zone", func(): return world.ranch.create_zone("nursery", cells_of.call("nursery"), "route" + active_route + "育幼"))
	if _ranch_zone_of(world, "work") == 0:
		act(world, "ranch work zone", func(): return world.ranch.create_zone("work", cells_of.call("work"), "route" + active_route + "工作"))
	if _ranch_zone_of(world, "maintenance") == 0:
		act(world, "ranch maintenance zone", func(): return world.ranch.create_zone("maintenance", cells_of.call("maintenance"), "route" + active_route + "维持"))
	if _ranch_zone_of(world, "pasture") == 0:
		act(world, "ranch pasture zone", func(): return world.ranch.create_zone("pasture", cells_of.call("pasture"), "route" + active_route + "放牧"))
	var dispatch: int = world.facility_at(Vector2i(8, 11))["uid"]
	var links := {_ranch_zone_of(world, "maintenance"): dispatch, _ranch_zone_of(world, "pasture"): dispatch}
	act(world, "ranch zone links", func(): return world.ranch.submit({"links": links}))
	var nursery := _ranch_zone_of(world, "nursery")
	# Workers: two moles carry the mineral economy; one beast joins after T07.
	var moles: Array = world.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == "rock_mole")
	if moles.size() < 1 and world.primeval_stones >= 300:
		act(world, "ranch mole purchase", func(): return world.ranch.purchase(nursery, "rock_mole", 1 - moles.size()))
	if world.research.is_completed("ore_concentration"):
		var beasts: Array = world.ranch.state["animals"].filter(func(a): return String(a["species_id"]) == "rock_belly_beast")
		if beasts.size() < 1 and world.primeval_stones >= 300:
			act(world, "ranch beast purchase", func(): return world.ranch.purchase(nursery, "rock_belly_beast", 1))
	# Keep mineral inputs above the research sample reserves.
	for item in ["raw_stone", "iron_ore"]:
		if world.inventory.count(item) < 10 and world.primeval_stones >= 400:
			act(world, "ranch " + item + " purchase", func(): return world.buy(item, 12 - world.inventory.count(item)))
	# Assign grown adults to the work zone.
	var work := _ranch_zone_of(world, "work")
	for row in world.ranch.state["animals"]:
		if String(row["stage"]) == "adult" and String(row["mode"]) == "waiting":
			var uid := int(row["uid"])
			act(world, "ranch assign worker " + str(uid), func(): return world.ranch.submit({"assign": {uid: {"mode": "work", "zone_uid": work}}}))
	# Claim ready posts first: a recipe switch needs every post idle.
	var yard_mole: int = world.facility_at(Vector2i(9, 11))["uid"]
	var yard_beast := 0
	if not world.facility_at(Vector2i(11, 11)).is_empty():
		yard_beast = int(world.facility_at(Vector2i(11, 11))["uid"])
	for yard in [yard_mole, yard_beast]:
		if yard == 0:
			continue
		if world.ranch.workyard_busy(yard):
			var ready := false
			for post in world.ranch.workyard_state(yard)["posts"]:
				if String(post["status"]) == "ready":
					ready = true
			if ready:
				act(world, "ranch yard claim " + str(yard), func(): return world.ranch.claim_workyard(yard))
	# Adaptive recipes keep both minerals above their consumption.
	var mole_recipe := "break_stone" if world.inventory.count("gravel") < 4 else ("break_ore" if world.inventory.count("crushed_ore") < 8 else "break_stone")
	if String(world.ranch.workyard_state(yard_mole)["recipe_id"]) != mole_recipe:
		act(world, "ranch yard recipe " + mole_recipe, func(): return world.ranch.set_recipe(yard_mole, mole_recipe))
	if yard_beast != 0 and world.research.is_completed("ore_concentration") and String(world.ranch.workyard_state(yard_beast)["recipe_id"]) != "concentrate_ore":
		act(world, "ranch yard recipe concentrate", func(): return world.ranch.set_recipe(yard_beast, "concentrate_ore"))

func _sell_surplus(world) -> void:
	for item in ["honey_cake", "fish_spirit_meal", "dew_soup", "fire_paste", "earth_pill", "gold_food", "reclaimed_fill"]:
		if world.inventory.count(item) > sample_reserve(world, item):
			act(world, "world.sell " + item, func(): return world.sell(item, 1))
	if world.inventory.count("grain") > 10:
		act(world, "world.sell(\"grain\", world.inventory.count(\"grain\") - 10)", func(): return world.sell("grain", world.inventory.count("grain") - 10))
	if world.inventory.count("straw") > 10:
		act(world, "world.sell(\"straw\", world.inventory.count(\"straw\") - 10)", func(): return world.sell("straw", world.inventory.count("straw") - 10))
	if world.inventory.count("fish_meat") > 6 and world.research.is_completed("basic_spirit_cooking"):
		act(world, "world.sell(\"fish_meat\", world.inventory.count(\"fish_meat\") - 6)", func(): return world.sell("fish_meat", world.inventory.count("fish_meat") - 6))

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
			var keep := maxi(2, sample_reserve(world, String(item)))
			if item in ["clean_water", "refined_oil"]: keep = maxi(8, keep)
			if item == "honey": keep = maxi(6, keep)
			if quote["ok"] and int(quote["quantity"]) + keep <= stock and stock > best_stock:
				best = String(item)
				best_stock = stock
		if not best.is_empty():
			act(world, "world.deliver_order(int(order[\"id\"]), best)", func(): return world.deliver_order(int(order["id"]), best))

func sample_reserve(world, item: String) -> int:
	var needed := 0
	for project in world.data_source.load_data()["research"]:
		var id := String(project["id"])
		if not world.research.is_completed(id) and world.research.project_of(id).is_empty():
			needed = maxi(needed, int(project["samples"].get(item, 0)))
	return needed

# --- Route body -----------------------------------------------------------------------------

func _run_route(route: String) -> void:
	active_route = route
	totals = Journal.bucket()
	frozen_recap = {}
	daily_count = 0
	claimed = {}
	claimed_days = {}
	receipt_index = 0
	receipts = FileAccess.open(audit_root.path_join(route + "-receipts.jsonl"), FileAccess.WRITE)
	audit = FileAccess.open(audit_root.path_join(route + "-actions.jsonl"), FileAccess.WRITE)
	daily = FileAccess.open(audit_root.path_join(route + "-days.jsonl"), FileAccess.WRITE)
	var store := P8Store.new(audit_root.path_join(route + "-slots"))
	var world := P8World.new(store)
	check(world.start_new(1, true)["ok"], route + " fresh independent slot")
	world.clock.day_changed.connect(func(day: int): archive_day(world, day))
	world.operation_recorded.connect(record_operation)
	var build_plan: Array
	if route == "A":
		build_plan = [
			["research_bench", 2, 4, ""], ["compost_bin", 1, 4, ""],
			["bee_hive", 7, 1, ""], ["purifying_bed", 0, 1, ""],
			["fish_pond", 0, 14, ""], ["woodshop", 15, 3, ""],
			["research_bench", 3, 4, ""],
			["farm_processor", 13, 3, ""], ["farm_processor", 10, 7, ""],
			["char_kiln", 17, 3, ""], ["algae_tank", 13, 5, ""],
			["smelter", 13, 1, ""], ["kitchen", 9, 4, ""],
			["field_service_station", 7, 9, ""], ["growth_lamp", 7, 13, ""], ["bee_hive", 5, 9, ""],
			["pen", 0, 11, ""], ["feed_trough", 2, 11, ""], ["feed_trough", 3, 11, ""],
			["small_bed", 4, 11, ""], ["small_bed", 4, 12, ""],
			["dispatch_station", 8, 11, ""], ["rock_breaking_yard", 9, 11, ""], ["ore_sorting_yard", 11, 11, ""],
			["feed_trough", 4, 10, ""], ["feed_trough", 7, 10, ""], ["small_bed", 8, 10, ""],
		]
	else:
		build_plan = [
			["research_bench", 2, 4, ""], ["compost_bin", 1, 4, ""],
			["fish_pond", 0, 14, ""], ["woodshop", 15, 3, ""],
			["purifying_bed", 0, 1, ""], ["bee_hive", 7, 1, ""],
			["research_bench", 3, 4, ""],
			["farm_processor", 13, 3, ""], ["farm_processor", 10, 7, ""],
			["char_kiln", 17, 3, ""], ["algae_tank", 13, 5, ""],
			["smelter", 13, 1, ""], ["kitchen", 9, 4, ""],
			["field_service_station", 7, 9, ""], ["growth_lamp", 7, 13, ""], ["bee_hive", 5, 9, ""],
			["pen", 0, 11, ""], ["feed_trough", 2, 11, ""], ["feed_trough", 3, 11, ""],
			["small_bed", 4, 11, ""], ["small_bed", 4, 12, ""],
			["dispatch_station", 8, 11, ""], ["rock_breaking_yard", 9, 11, ""], ["ore_sorting_yard", 11, 11, ""],
			["feed_trough", 4, 10, ""], ["feed_trough", 7, 10, ""], ["small_bed", 8, 10, ""],
		]
	var stock_plan: Array = [["fish_pond", 0, 2], ["bee_hive", 0, 2],
		["purifying_bed", 0, 2], ["bee_hive", 1, 2]]
	validate_layout(world, build_plan)
	var day := 0
	while world.clock.total_days < horizon:
		day = world.clock.total_days
		active_day = day
		# Sources first so clean_water exists when bees need it; research and
		# habitat maintenance next (they own the critical AP); farming last.
		_source_topups(world)
		_sell_surplus(world)
		_deliver_orders(world)
		if with_expansion: _expand_business(world)
		if world.inventory.count("golden_wheat_seed") < 4:
			act(world, "wheat seed purchase", func(): return world.buy("golden_wheat_seed", mini(4 - world.inventory.count("golden_wheat_seed"), world.primeval_stones / 3)))
		if world.inventory.count("grass_seed") < 3 and world.primeval_stones >= 26:
			act(world, "grass seed purchase", func(): return world.buy("grass_seed", 3 - world.inventory.count("grass_seed")))
		if world.inventory.count("wood_decay_spawn") < 8 and world.primeval_stones >= 29:
			act(world, "fungus spawn purchase", func(): return world.buy("wood_decay_spawn", 8 - world.inventory.count("wood_decay_spawn")))
		_ranch_pave(world)
		_research_day(world)
		_configure_habitats(world)
		_maintain_habitats(world)
		_ranch_business(world)
		_start_research(world)
		if world.research.is_completed("flower_cultivation"):
			_farm_flowers(world)
		_buy_build_materials(world, build_plan)
		_build_plan_step(world, build_plan)
		_stock_plan_step(world, stock_plan)
		_delegate(world)
		_farm_wheat(world)
		_farm_feed(world)
		_farm_trees(world)
		_farm_lamp_flowers(world)
		_hand_surplus(world, uid_of(world, "bee_hive"))
		_configure_devices(world)
		var process_plan: Array = [
			["compost_bin", "compost_straw", "humus", 6],
			["woodshop", "saw_planks", "wood_plank", 4],
			["woodshop", "shred_wood", "wood_chip", 6],
			["char_kiln", "char_twigs", "charcoal", 6],
			["farm_processor", "mill_grain", "grain_meal", 4],
			["farm_processor", "mill_grass", "grass_meal", 6, 1],
			["farm_processor", "press_oilseed", "crude_oil", 8],
			["farm_processor", "refine_oil", "refined_oil", 10],
			["farm_processor", "blend_land_feed", "land_feed", 4, 1],
			["farm_processor", "blend_water_feed", "water_feed", 8, 1],
			["farm_processor", "mineral_feed", "mineral_feed", 4, 1],
			["farm_processor", "refine_wax", "refined_wax", 2],
			["smelter", "smelt_charcoal", "iron_ingot", 2],
			["smelter", "smelt_concentrate", "iron_ingot", 4],
			["woodshop", "make_filter_media", "filter_media", 4],
			["woodshop", "assemble_stone_panel", "composite_stone_panel", 4],
			["woodshop", "recover_fill", "reclaimed_fill", 4],
			["compost_bin", "compost_oil_cake", "humus", 6],
			["compost_bin", "compost_spent_filter", "humus", 6],
			["algae_tank", "culture_algae", "algae_feed", 6],
			["algae_tank", "dense_algae_culture", "dense_algae", 4],
			["kitchen", "honey_grain_cake", "honey_cake", 4],
			["kitchen", "fungus_fish_meal", "fish_spirit_meal", 4],
			["kitchen", "algae_dew_soup", "dew_soup", 4],
			["kitchen", "oil_honey_paste", "fire_paste", 4],
			["kitchen", "soil_spirit_pill", "earth_pill", 4],
			["kitchen", "honey_mineral_food", "gold_food", 1],
		]
		if world.research.is_completed("biofiltration"):
			process_plan.push_back(["compost_bin", "compost_sludge", "humus", 10])
		if world.inventory.count("fodder_grass") < 10:
			# Normal market purchases cover the sample shortfall without taking
			# the breeding animals' rations; no resources are injected.
			if world.research.is_completed("advanced_feed_oil_wax") and not world.research.is_completed("field_maintenance") \
					and world.inventory.count("grass_meal") < 2 and world.primeval_stones >= 24:
				act(world, "world.buy(\"fodder_grass\", 10 - world.inventory.count(\"fodder_grass\"))", func(): return world.buy("fodder_grass", 10 - world.inventory.count("fodder_grass")))
		if world.inventory.count("fodder_grass") < 10:
			process_plan = process_plan.filter(func(entry): return String(entry[1]) != "mill_grass")
		if not world.research.is_completed("mineral_materials") and world.inventory.count("ore_concentrate") < 2:
			process_plan = process_plan.filter(func(entry): return String(entry[1]) != "smelt_concentrate")
		if not world.research.is_completed("composite_spirit_food") and world.inventory.count("dense_algae") < 2:
			process_plan = process_plan.filter(func(entry): return String(entry[1]) != "algae_dew_soup")
		_process_batches(world, process_plan)
		_sell_surplus(world)
		_deliver_orders(world)
		if day == 40 or day == 60 or day == 80:
			var t6: Dictionary = world.research.quote_start(uid_of(world, "research_bench"), "advanced_feed_oil_wax")
			print("DBG ", route, " d", day, " stones=", world.primeval_stones,
				" done=", world.research.state["completed"].size(),
				" crude=", world.inventory.count("crude_oil"), " wax=", world.inventory.count("beeswax"),
				" gmeal=", world.inventory.count("grain_meal"), " oilseed=", world.inventory.count("oilseed"),
				" T6block=", t6.get("blockers", []),
				" processor=", count_of(world, "farm_processor"), " hive=", count_of(world, "bee_hive"),
				" benches=", count_of(world, "research_bench"),
				" bees=", world.husbandry.habitat_of(uid_of(world, "bee_hive")).get("individuals", []).size(),
				" beeQ=", world.husbandry.quote_maintenance(uid_of(world, "bee_hive")).get("reason",
					world.husbandry.quote_maintenance(uid_of(world, "bee_hive")).get("ok", "?")),
				" honeybell_shares=", world.flowers.state["shares"].size(),
				" hive_candidates=", world.flowers.hive_candidates(uid_of(world, "bee_hive")).size())
		if world.clock.total_days == day: world.end_day()
		if not world.daily_save_error.is_empty():
			check(false, route + " day " + str(day) + " settle failed: " + world.daily_save_error)
			break
		if world.clock.total_days == 45 or world.clock.total_days == 70:
			# Flower shares are same-day session marks: they are initialized
			# lazily by the first eligibility query and expire with the
			# completed day, so the live book can legitimately sit ahead of the
			# last disk commit. Everything else must round-trip exactly.
			var before: Dictionary = world.to_snapshot()
			before["world"]["flowers"]["shares"] = []
			var opened: bool = world.open_game(1)["ok"]
			var after = JSON.parse_string(JSON.stringify(world.to_snapshot()))
			after["world"]["flowers"]["shares"] = []
			check(opened and after == JSON.parse_string(JSON.stringify(before)), route + " exit and restore day " + str(world.clock.total_days))
	# --- Assertions ---
	if with_expansion:
		check(world.land.purchased.size() == 6, route + " all six parcels bought with normal income")
		check(world.facility_at(Vector2i(-4,14)).get("facility_id") == "fish_pond", route + " west water actually used")
		check(int(totals["plantings"].get("golden_wheat",0)) > 0, route + " real cultivation continues")
	check(world.clock.total_days == horizon and daily_count == horizon, route + " exactly %d closed days" % horizon)
	for project in ["flower_cultivation", "beekeeping", "farm_preparation", "biofiltration", "rock_handling",
			"advanced_feed_oil_wax", "ore_concentration", "water_recirculation", "basic_spirit_cooking",
			"field_maintenance", "mineral_materials", "composite_spirit_food"]:
		check(world.research.is_completed(project), route + " research " + project)
	check(world.inventory.count("honey") > 0 or world.inventory.count("honey_cake") > 0, route + " honey economy ran")
	# Closing stock may be zero after legitimate farming and compost reuse.
	# Successful production receipts prove the loop ran; purchased humus does not.
	check(int(claimed.get("bio_purify", 0)) > 0 and int(claimed.get("compost_sludge", 0)) > 0, route + " purification and sludge reuse produced real batches")
	check(world.inventory.count("gravel") > 0 or world.inventory.count("ore_concentrate") > 0 or world.inventory.count("crushed_ore") > 0, route + " rock economy ran")
	var supplied_elements := {}
	var delivered: Dictionary = totals["delivered_items"]
	for item in delivered:
		supplied_elements[String(world._items[String(item)]["element"])] = true
	for element in ["wood", "fire", "earth", "water", "gold"]:
		check(supplied_elements.has(element), route + " supplied element " + element)
	var cooked := false
	for food in ["dew_soup", "fire_paste", "earth_pill", "gold_food"]:
		if int(totals["processed"].get(String(food), 0)) > 0:
			cooked = true
	check(cooked, route + " actually claimed T12 spirit food")
	check(int(world.workforce.state["spent"]) > 0 and int(totals["labour_spend"]) == int(world.workforce.state["spent"]), route + " real paid delegation")
	check(not world.workforce.state["workers"].is_empty() and world.operations.facilities_of(1).size() >= 2, route + " one owner multiple facilities")
	check(world.journal["frozen"], route + " 45-day recap frozen")
	route_summaries[route] = {"day": world.clock.total_days, "cash": world.primeval_stones, "wages": world.workforce.state["spent"], "claimed": claimed.duplicate(), "claimed_days": claimed_days.duplicate(),
		"research_order": world.research.state["completed"].duplicate(true), "totals": totals.duplicate(true)}
	write_json(route + "-day%d.json" % horizon, world.to_snapshot())
	var day91: Dictionary = world.end_day()
	write_json(route + "-day%d.json" % (horizon + 1), world.to_snapshot())
	check(day91["ok"] and world.clock.total_days == horizon + 1 and world.reports.state["recap"] == frozen_recap, route + " continues without rewriting the recap")
	print("P8 ROUTE ", route, " day=", world.clock.total_days, " stones=", world.primeval_stones,
		" research=", world.research.state["completed"].size(), "/12 wages=", world.workforce.state["spent"])
	receipts.close()
	audit.close()
	daily.close()
