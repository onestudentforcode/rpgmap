extends SceneTree
## P8.h no-injection dual 90-day routes via real world interfaces only.
## Route A leads with flowers and later delegation; B researches water/rock
## first and delegates earlier. Separate 90-day books never extend the frozen
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
	for x in range(4, 8): fields.append(Vector2i(x, 4))
	for y in [4, 5]:
		for x in [11, 12]: fields.append(Vector2i(x, y))
	for x in range(2, 9): fields.append(Vector2i(x, 3))
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
	check(world.primeval_stones == 60 + Journal.income(totals) - Journal.expense(totals), active_route + " day %d cash balances" % day)
	daily_count += 1
	daily.store_line(JSON.stringify({"day": day, "cash": world.primeval_stones, "journal": bucket,
		"ledger": world.ledger.day_view(day - 1), "workers": world.workforce.state["report"],
		"research": world.research.to_save(), "facilities": world.to_snapshot()["world"]["facilities"],
		"husbandry": world.husbandry.to_save(), "devices": world.devices.to_save(), "report": world.reports.to_save()}))
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(audit_root))
	var manifest := {}
	for name in ["content/farming/p8/production.json", "content/farming/baked/p8/production.json",
			"content/farming/baked/maps/farm_02.json", "scripts/farming/tests/run_p8_playtest.gd",
			"scripts/farming/p8/p8_flowers.gd", "scripts/farming/p8/p8_world.gd"]:
		manifest[name] = FileAccess.get_sha256("res://" + name)
	write_json("manifest.json", manifest)
	_run_route("A")
	_run_route("B")
	check(route_summaries["A"]["research_order"] != route_summaries["B"]["research_order"], "routes have different research histories")
	var summary := FileAccess.open(audit_root.path_join("summary.json"), FileAccess.WRITE)
	summary.store_string(JSON.stringify({"routes": route_summaries, "failures": failures, "checks": checks}, "\t"))
	for failure in failures: printerr(failure)
	print("P8 TWO90 PLAYTEST %s · %d checks" % ["OK" if failures.is_empty() else "FAIL", checks])
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
	# Mole: crushed ore for the beast chain, gravel when ore is stocked.
	var mole_yard := uid_of(world, "rock_workyard", 0)
	if mole_yard != 0 and not world.husbandry.habitat_of(mole_yard).is_empty():
		if world.inventory.count("gravel") < 8:
			act(world, "stone first for research and filters", func(): return world.husbandry.set_special_diet(mole_yard, "break_stone"))
		elif world.inventory.count("crushed_ore") < 12:
			act(world, "world.husbandry.set_special_diet(mole_yard, \"break_ore\")", func(): return world.husbandry.set_special_diet(mole_yard, "break_ore"))
	# Mats: nutrient recovery once filter media exists, purify otherwise.
	var bed := uid_of(world, "purifying_bed")
	if bed != 0 and not world.husbandry.habitat_of(bed).is_empty():
		if world.inventory.count("filter_media") >= 1 and world.inventory.count("nutrient_liquid") < 4:
			act(world, "world.husbandry.set_special_diet(bed, \"recover_nutrients\")", func(): return world.husbandry.set_special_diet(bed, "recover_nutrients"))
		else:
			act(world, "world.husbandry.set_special_diet(bed, \"bio_purify\")", func(): return world.husbandry.set_special_diet(bed, "bio_purify"))

# --- Farming ---------------------------------------------------------------------------

func _farm_wheat(world) -> void:
	for crop in world.crops.values().duplicate(true):
		if String(crop["crop_id"]) == "golden_wheat" and String(crop["state"]) == "mature":
			act(world, "world.harvest(Vector2i(int(crop[\"origin\"][0]), int(crop[\"origin\"][1])), \"harvest\")", func(): return world.harvest(Vector2i(int(crop["origin"][0]), int(crop["origin"][1])), "harvest"))
	for x in range(4, 8):
		var cell := Vector2i(x, 4)
		if world.grid.state_at(cell) == 0 and world.source_at(cell).is_empty() and world.facility_at(cell).is_empty():
			act(world, "world.till(cell)", func(): return world.till(cell))
	for x in range(4, 8):
		var cell := Vector2i(x, 4)
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
	if world.inventory.count("mushroom") < 12 and world.inventory.count("wood_decay_spawn") > 0 and world.inventory.count("wood_chip") >= 3:
		for x in range(2, 9):
			var cell := Vector2i(x, 3)
			if world.grid.state_at(cell) == 0 and world.source_at(cell).is_empty() and world.facility_at(cell).is_empty():
				act(world, "world.till(cell)", func(): return world.till(cell))
			if world.grid.state_at(cell) == 1 and world.inventory.count("wood_chip") >= 3 and world.inventory.count("wood_decay_spawn") > 0:
				act(world, "world.plant(cell, \"wood_decay_mushroom\")", func(): return world.plant(cell, "wood_decay_mushroom"))

func _farm_flowers(world) -> void:
	for crop in world.crops.values().duplicate(true):
		if String(crop["crop_id"]) != "honeybell_bush" and String(crop["crop_id"]) != "oilseed_flower":
			continue
		var origin := Vector2i(int(crop["origin"][0]), int(crop["origin"][1]))
		if int(world.environment_at(origin)["water"]) < 45 and world.inventory.count("clean_water") >= 1:
			act(world, "world.irrigate(origin)", func(): return world.irrigate(origin))
		if int(world.environment_at(origin)["fertility"]) < 45 and world.inventory.count("humus") >= 1:
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
	for entry in plan:
		var facility_uid := uid_of(world, String(entry[0]))
		if facility_uid == 0:
			continue
		var facility: Dictionary = world.facilities[facility_uid]
		if not facility["batch"].is_empty():
			var batch: Dictionary = facility["batch"]
			if String(batch.get("status", "")) == "ready" and batch.has("batch_id"):
				act(world, "world.claim_batch(facility_uid, int(batch[\"batch_id\"]))", func(): return world.claim_batch(facility_uid, int(batch["batch_id"])))
			continue
		var recipe: Dictionary = world.recipe_defs.get(String(entry[1]), {})
		if recipe.is_empty():
			continue
		if not world.research_block(String(recipe.get("research", ""))).is_empty():
			continue
		var ok := true
		for item in recipe["inputs"]:
			if world.inventory.count(String(item)) < int(recipe["inputs"][item]) + sample_reserve(world, String(item)):
				ok = false
				break
		if ok and world.inventory.count(String(entry[2])) < int(entry[3]):
			act(world, "world.start_batch(facility_uid, String(entry[1]))", func(): return world.start_batch(facility_uid, String(entry[1])))

func _delegate(world) -> void:
	if world.clock.total_days != active_day: return
	if world.workforce.state["workers"].is_empty():
		if active_day < (35 if active_route == "A" else 20) or world.primeval_stones < 12: return
		var hired: Dictionary = act(world, "hire facility owner", func(): return world.workforce.hire("产业负责人" + active_route))
		if not hired["ok"]: return
	var worker: Dictionary = world.workforce.state["workers"][0]
	# One person explicitly owns several facilities, using one shared budget.
	act(world, "world.workforce.configure(int(worker[\"id\"]), 4, false, worker[\"priorities\"], [])", func(): return world.workforce.configure(int(worker["id"]), 4, false, worker["priorities"], []))
	for type_id in ["bee_hive", "fish_pond", "purifying_bed"]:
		# Keep real manual water changes until the recycling samples exist;
		# the owner later changes water only at the configured threshold.
		if type_id == "fish_pond" and not world.research.is_completed("water_recirculation"): continue
		var uid := uid_of(world, type_id)
		if uid != 0 and world.operations.owner_of(uid) == 0:
			act(world, "world.operations.assign_owner(uid, int(worker[\"id\"]))", func(): return world.operations.assign_owner(uid, int(worker["id"])))
	var hive := uid_of(world, "bee_hive")
	if hive != 0 and world.operations.owner_of(hive) != 0:
		act(world, "world.operations.set_priority(hive, \"high\")", func(): return world.operations.set_priority(hive, "high"))
	var bench := uid_of(world, "research_bench")
	if bench != 0 and world.operations.owner_of(bench) == 0:
		act(world, "assign research owner", func(): return world.operations.assign_owner(bench, int(worker["id"])))

func _sell_surplus(world) -> void:
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
			if item == "clean_water": keep = maxi(8, keep)
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
	audit = FileAccess.open(audit_root.path_join(route + "-actions.jsonl"), FileAccess.WRITE)
	daily = FileAccess.open(audit_root.path_join(route + "-days.jsonl"), FileAccess.WRITE)
	var store := P8Store.new(audit_root.path_join(route + "-slots"))
	var world := P8World.new(store)
	check(world.start_new(1, true)["ok"], route + " fresh independent slot")
	world.clock.day_changed.connect(func(day: int): archive_day(world, day))
	var build_plan: Array
	if route == "A":
		build_plan = [
			["research_bench", 2, 4, ""], ["compost_bin", 1, 4, ""],
			["bee_hive", 7, 1, ""], ["purifying_bed", 0, 1, ""],
			["fish_pond", 0, 14, ""], ["woodshop", 15, 3, ""],
			["rock_workyard", 3, 1, "rock_mole"],
			["rock_workyard", 5, 1, "rock_belly_beast"],
			["research_bench", 3, 4, ""],
			["farm_processor", 13, 3, ""],
			["char_kiln", 17, 3, ""], ["algae_tank", 13, 5, ""],
			["smelter", 13, 1, ""], ["kitchen", 9, 4, ""], ["pen", 15, 1, ""],
		]
	else:
		build_plan = [
			["research_bench", 2, 4, ""], ["compost_bin", 1, 4, ""],
			["fish_pond", 0, 14, ""], ["woodshop", 15, 3, ""],
			["rock_workyard", 3, 1, "rock_mole"],
			["rock_workyard", 5, 1, "rock_belly_beast"],
			["purifying_bed", 0, 1, ""], ["bee_hive", 7, 1, ""],
			["research_bench", 3, 4, ""],
			["farm_processor", 13, 3, ""],
			["char_kiln", 17, 3, ""], ["algae_tank", 13, 5, ""],
			["smelter", 13, 1, ""], ["kitchen", 9, 4, ""], ["pen", 15, 1, ""],
		]
	var stock_plan: Array = [["fish_pond", 0, 2], ["rock_workyard", 0, 2], ["bee_hive", 0, 2],
		["purifying_bed", 0, 2], ["rock_workyard", 1, 2], ["pen", 0, 1]]
	validate_layout(world, build_plan)
	var day := 0
	while world.clock.total_days < 90:
		day = world.clock.total_days
		active_day = day
		# Sources first so clean_water exists when bees need it; research and
		# habitat maintenance next (they own the critical AP); farming last.
		_source_topups(world)
		_sell_surplus(world)
		_deliver_orders(world)
		if world.inventory.count("golden_wheat_seed") < 4:
			act(world, "wheat seed purchase", func(): return world.buy("golden_wheat_seed", mini(4 - world.inventory.count("golden_wheat_seed"), world.primeval_stones / 3)))
		if world.inventory.count("grass_seed") < 3 and world.primeval_stones >= 26:
			act(world, "grass seed purchase", func(): return world.buy("grass_seed", 3 - world.inventory.count("grass_seed")))
		if world.inventory.count("wood_decay_spawn") < 3 and world.primeval_stones >= 29:
			act(world, "fungus spawn purchase", func(): return world.buy("wood_decay_spawn", 3 - world.inventory.count("wood_decay_spawn")))
		_research_day(world)
		_maintain_habitats(world)
		_start_research(world)
		if world.research.is_completed("flower_cultivation"):
			_farm_flowers(world)
		_buy_build_materials(world, build_plan)
		_build_plan_step(world, build_plan)
		_stock_plan_step(world, stock_plan)
		_delegate(world)
		_farm_wheat(world)
		_farm_feed(world)
		var process_plan: Array = [
			["compost_bin", "compost_straw", "humus", 6],
			["woodshop", "saw_planks", "wood_plank", 4],
			["woodshop", "shred_wood", "wood_chip", 6],
			["char_kiln", "char_twigs", "charcoal", 6],
			["farm_processor", "mill_grain", "grain_meal", 4],
			["farm_processor", "mill_grass", "grass_meal", 4],
			["farm_processor", "press_oilseed", "crude_oil", 8],
			["farm_processor", "refine_oil", "refined_oil", 4],
			["farm_processor", "blend_land_feed", "land_feed", 2],
			["smelter", "smelt_charcoal", "iron_ingot", 2],
			["smelter", "smelt_concentrate", "iron_ingot", 4],
			["woodshop", "make_filter_media", "filter_media", 2],
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
		if world.inventory.count("honey") < 5:
			process_plan = process_plan.filter(func(entry): return ["honey_grain_cake", "oil_honey_paste", "honey_mineral_food"].has(String(entry[1])) == false)
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
			var before: Dictionary = world.to_snapshot()
			check(world.open_game(1)["ok"] and JSON.parse_string(JSON.stringify(world.to_snapshot())) == JSON.parse_string(JSON.stringify(before)), route + " exit and restore day " + str(world.clock.total_days))
	# --- Assertions ---
	check(world.clock.total_days == 90 and daily_count == 90, route + " exactly 90 closed days")
	for project in ["flower_cultivation", "beekeeping", "farm_preparation", "biofiltration", "rock_handling",
			"advanced_feed_oil_wax", "ore_concentration", "water_recirculation", "basic_spirit_cooking",
			"field_maintenance", "mineral_materials", "composite_spirit_food"]:
		check(world.research.is_completed(project), route + " research " + project)
	check(world.inventory.count("honey") > 0 or world.inventory.count("honey_cake") > 0, route + " honey economy ran")
	check(world.inventory.count("sludge") > 0 or world.inventory.count("humus") >= 2, route + " purification loop ran")
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
	route_summaries[route] = {"day": world.clock.total_days, "cash": world.primeval_stones, "wages": world.workforce.state["spent"],
		"research_order": world.research.state["completed"].duplicate(true), "totals": totals.duplicate(true)}
	write_json(route + "-day90.json", world.to_snapshot())
	var day91: Dictionary = world.end_day()
	write_json(route + "-day91.json", world.to_snapshot())
	check(day91["ok"] and world.clock.total_days == 91 and world.reports.state["recap"] == frozen_recap, route + " day 91 continues without rewriting the recap")
	print("P8 ROUTE ", route, " day=", world.clock.total_days, " stones=", world.primeval_stones,
		" research=", world.research.state["completed"].size(), "/12 wages=", world.workforce.state["spent"])
	audit.close()
	daily.close()
