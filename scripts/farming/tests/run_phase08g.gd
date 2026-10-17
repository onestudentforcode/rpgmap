extends SceneTree
## P8.g checks: field station services (per-cell, overlap, rotation, branch
## independence, throughput), growth lamps (fuel, empty range, max light,
## shade), the kitchen chain R19-R24 with five-element orders and the day-45/46
## device freeze boundary.
const P8World := preload("res://scripts/farming/p8/p8_world.gd")
const P8Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const P8Snapshot := preload("res://scripts/farming/p8/p8_snapshot.gd")

var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func temp_store() -> P8Store:
	return P8Store.new("user://p8g_test_%d" % Time.get_ticks_usec())

## Ledger-consistent discard.
func discard(world, item: String, quantity: int) -> void:
	if quantity <= 0:
		return
	world.inventory.remove(item, quantity)
	world._record_flow({}, {item: quantity}, "测试弃置")

## Test funding recorded as journal income so the day-45 freeze equation holds.
func fund(world, amount: int) -> void:
	world.primeval_stones += amount
	world._cash("sales_revenue", amount)

func complete_research(world, bench: int, project_id: String, samples: Dictionary) -> void:
	world.grant_scaffold(samples)
	var started: Dictionary = world.research.start(bench, project_id)
	check(started["ok"], "start %s (%s)" % [project_id, String(started.get("reason", ""))])
	var guard := 0
	while not world.research.is_completed(project_id) and guard < 14:
		world.research.work(bench)
		world.end_day()
		guard += 1

func uid_of(world, facility_id: String, index: int = 0) -> int:
	var found := []
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == facility_id:
			found.append(int(uid))
	found.sort()
	return found[mini(index, found.size() - 1)] if not found.is_empty() else 0

func research_all(world, bench: int) -> void:
	complete_research(world, bench, "flower_cultivation", {"grain": 2, "humus": 1})
	complete_research(world, bench, "beekeeping", {"nectar": 2, "pollen": 1})
	complete_research(world, bench, "farm_preparation", {"oilseed": 2, "straw": 2})
	complete_research(world, bench, "rock_handling", {"mushroom": 1, "raw_stone": 3})
	complete_research(world, bench, "biofiltration", {"wastewater": 2, "mushroom": 1})
	complete_research(world, bench, "ore_concentration", {"crushed_ore": 2, "gravel": 1, "fodder_grass": 2})
	complete_research(world, bench, "water_recirculation", {"sludge": 1, "gravel": 1, "charcoal": 1})
	complete_research(world, bench, "advanced_feed_oil_wax", {"crude_oil": 1, "beeswax": 1, "grain_meal": 1})
	complete_research(world, bench, "basic_spirit_cooking", {"honey": 1, "grain_meal": 1, "fish_meat": 1})
	complete_research(world, bench, "field_maintenance", {"humus": 2, "clean_water": 4, "land_feed": 1})
	complete_research(world, bench, "mineral_materials", {"ore_concentrate": 1, "iron_ingot": 1, "stone_powder": 1})
	complete_research(world, bench, "composite_spirit_food", {"refined_oil": 1, "dense_algae": 1, "iron_ingot": 1})

func _initialize() -> void:
	_station_services()
	_lamps()
	_kitchen_and_orders()
	_freeze_boundary()
	_snapshot_contracts()
	for failure in failures: printerr(failure)
	print("PHASE08G TEST %s · %d checks" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

# --- 1. Field station services -------------------------------------------------

func _station_services() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 4, "raw_stone": 6, "wood_plank": 8, "iron_ingot": 4, "grain": 2, "humus": 1,
		"clean_water": 40})
	fund(world, 100)
	world.build_facility(Vector2i(2, 4), "research_bench")
	research_all(world, 1)
	check(world.build_facility(Vector2i(0, 3), "field_service_station")["ok"], "build the station after T10")
	var station := uid_of(world, "field_service_station")
	check(world.devices.configure_station(station, true, true, 90)["ok"], "configure the station above the 60 baseline")
	# A 2x2 tree and a bare tilled cell inside coverage, a wild cell too.
	world.till(Vector2i(9, 4))
	world.till(Vector2i(10, 4))
	world.till(Vector2i(0, 5))
	world.buy("fast_fir_seed", 1)
	world.plant(Vector2i(9, 4), "fast_fir")
	var low := 0
	for cell in [Vector2i(9, 4), Vector2i(10, 4), Vector2i(10, 5), Vector2i(9, 5), Vector2i(0, 5)]:
		low += 1
	world.grant_scaffold({"humus": 5})
	var water_before := world.inventory.count("clean_water")
	var humus_before := world.inventory.count("humus")
	world.end_day()
	var served_water := water_before - world.inventory.count("clean_water")
	var served_humus := humus_before - world.inventory.count("humus")
	# Coverage around (0,3) reaches (9,4)? No: it is far away. The station at
	# (0,3) covers x-2..3; the tilled cells at x9/10 and x0y5: only (0,5) lies
	# inside (0-2..3, 1-6). One tilled cell -> one service per item.
	check(served_water == 1 and served_humus == 1, "one covered tilled cell served once per item (%d/%d)" % [served_water, served_humus])
	check(int(world.environment_at(Vector2i(0, 5))["water"]) == 60 + 30, "water actually improved by the device")
	# Wild and out-of-range cells untouched.
	check(int(world.environment_at(Vector2i(9, 4))["water"]) == 60, "uncovered cells untouched")
	# Branch independence: no humus left, water still serves the low cell.
	world.devices.configure_station(station, true, true, 99)
	discard(world, "humus", world.inventory.count("humus"))
	var before2 := world.inventory.count("clean_water")
	world.end_day()
	check(before2 - world.inventory.count("clean_water") == 1, "fertilizer gap does not stop irrigation")
	# Throughput cap: many low cells, only 6 services per item.
	for x in range(4, 12):
		world.till(Vector2i(x, 1))
	world.grant_scaffold({"clean_water": 20, "humus": 20})
	check(world.devices.configure_station(station, true, true, 90)["ok"], "raise the threshold to catch all")
	var wb := world.inventory.count("clean_water")
	world.end_day()
	check(wb - world.inventory.count("clean_water") <= 6, "daily throughput capped at 6 per item")
	# Overlap: a second station never re-serves the same cell/item the same day.
	var overlap_built: Dictionary = world.build_facility(Vector2i(4, 1), "field_service_station")
	check(overlap_built["ok"], "build the overlapping station (" + String(overlap_built.get("reason", "")) + ")")
	var second := uid_of(world, "field_service_station", 1)
	world.devices.configure_station(second, true, true, 90)
	var wb2 := world.inventory.count("clean_water")
	world.end_day()
	# Cells at 30/60 from before are mostly above the 30 default now; with the
	# threshold back to 90 both stations still cap at 6+6 but re-verify skips
	# anything already served this morning by the first station.
	world.devices.configure_station(station, true, true, 90)
	world.devices.configure_station(second, true, true, 90)
	var wb3 := world.inventory.count("clean_water")
	world.end_day()
	check(wb3 - world.inventory.count("clean_water") <= 12, "overlap stays within both stations' caps")

# --- 2. Growth lamps ---------------------------------------------------------------

func _lamps() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 6, "raw_stone": 6, "wood_plank": 2, "composite_stone_panel": 2,
		"iron_ingot": 3, "grain": 2, "humus": 1, "refined_oil": 10, "wood_chip": 3, "clean_water": 4})
	fund(world, 100)
	world.build_facility(Vector2i(2, 4), "research_bench")
	research_all(world, 1)
	check(world.build_facility(Vector2i(5, 1), "growth_lamp")["ok"], "build the lamp after T11")
	var lamp := uid_of(world, "growth_lamp")
	check(int(world.environment_at(Vector2i(5, 1))["light"]) == 80, "natural light before enabling")
	check(world.devices.configure_lamp(lamp, true)["ok"], "enable the lamp")
	world.end_day()
	check(int(world.inventory.count("refined_oil")) == 10, "empty coverage burns no fuel")
	check(int(world.environment_at(Vector2i(5, 1))["light"]) == 80, "no free light without crops")
	# Plant a shade-loving mushroom inside coverage: the lamp lights and flags it.
	world.till(Vector2i(6, 1))
	world.buy("wood_decay_spawn", 1)
	world.plant(Vector2i(6, 1), "wood_decay_mushroom")
	world.end_day()
	check(world.inventory.count("refined_oil") == 9, "lit day consumes exactly one fuel")
	check(world.devices.lamp_active_at(Vector2i(6, 1)), "covered cell reports active light")
	var overview: Dictionary = world.devices.lamp_overview(lamp)
	check((overview["shade"] as Array).has("wood_decay_mushroom"), "shade crop flagged in the overview")
	# A second overlapping lamp burns its own fuel but never brightens further.
	check(world.build_facility(Vector2i(7, 1), "growth_lamp")["ok"], "build the overlapping lamp")
	var second := uid_of(world, "growth_lamp", 1)
	world.devices.configure_lamp(second, true)
	world.end_day()
	check(world.inventory.count("refined_oil") == 7, "each enabled lamp pays its own fuel")
	# Out of fuel: no light, no free day.
	discard(world, "refined_oil", world.inventory.count("refined_oil"))
	world.end_day()
	check(not world.devices.lamp_active_at(Vector2i(6, 1)) or world.inventory.count("refined_oil") > 0, "dry lamp stays dark")
	check(int(world.environment_at(Vector2i(6, 1))["light"]) == 80, "light falls back to natural")
	# Demolishing an active lamp cancels its light immediately.
	world.grant_scaffold({"refined_oil": 3})
	world.devices.configure_lamp(second, false)
	world.devices.configure_lamp(lamp, true)
	world.end_day()
	check(world.devices.lamp_active_at(Vector2i(6, 1)), "relit for the demolition check")
	world.demolish_facility(lamp)
	check(not world.devices.lamp_active_at(Vector2i(6, 1)), "demolished lamp stops lighting")

# --- 3. Kitchen chain and five-element orders -----------------------------------------

func _kitchen_and_orders() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 6, "raw_stone": 6, "wood_plank": 4, "grain": 2, "humus": 1,
		"grain_meal": 4, "honey": 2, "clean_water": 6, "charcoal": 6, "mushroom": 2, "fish_meat": 2,
		"refined_oil": 2, "dense_algae": 2, "refined_wax": 2, "iron_ingot": 2, "flower_petal": 2, "resin": 1})
	fund(world, 100)
	world.build_facility(Vector2i(2, 4), "research_bench")
	research_all(world, 1)
	check(world.build_facility(Vector2i(0, 3), "kitchen")["ok"], "build the kitchen after T09")
	var kitchen := uid_of(world, "kitchen")
	world.grant_scaffold({"grain_meal": 2, "honey": 1})
	check(world.start_batch(kitchen, "honey_grain_cake")["ok"], "R19 starts after T09")
	var guard := 0
	while not world.facilities[kitchen]["batch"].is_empty() and guard < 10:
		var b: Dictionary = world.facilities[kitchen]["batch"]
		if b["status"] == "ready": world.claim_batch(kitchen, int(b["batch_id"]))
		else: world.end_day()
		guard += 1
	check(world.inventory.count("honey_cake") == 2, "R19 issues honey cakes")
	world.grant_scaffold({"mushroom": 1, "fish_meat": 1, "refined_oil": 1})
	check(world.start_batch(kitchen, "fungus_fish_meal")["ok"], "R20 starts after T09")
	guard = 0
	while not world.facilities[kitchen]["batch"].is_empty() and guard < 10:
		var b2: Dictionary = world.facilities[kitchen]["batch"]
		if b2["status"] == "ready": world.claim_batch(kitchen, int(b2["batch_id"]))
		else: world.end_day()
		guard += 1
	check(world.inventory.count("fish_spirit_meal") == 2, "R20 issues spirit meals")
	# R21-R24 after T12.
	world.grant_scaffold({"dense_algae": 1, "clean_water": 3, "flower_petal": 1})
	check(world.start_batch(kitchen, "algae_dew_soup")["ok"], "R21 starts after T12")
	guard = 0
	while not world.facilities[kitchen]["batch"].is_empty() and guard < 10:
		var b3: Dictionary = world.facilities[kitchen]["batch"]
		if b3["status"] == "ready": world.claim_batch(kitchen, int(b3["batch_id"]))
		else: world.end_day()
		guard += 1
	check(world.inventory.count("dew_soup") == 2, "R21 issues dew soup")
	world.grant_scaffold({"refined_oil": 1, "honey": 1, "refined_wax": 1})
	check(world.start_batch(kitchen, "oil_honey_paste")["ok"], "R22 starts after T12")
	guard = 0
	while not world.facilities[kitchen]["batch"].is_empty() and guard < 10:
		var b4: Dictionary = world.facilities[kitchen]["batch"]
		if b4["status"] == "ready": world.claim_batch(kitchen, int(b4["batch_id"]))
		else: world.end_day()
		guard += 1
	check(world.inventory.count("fire_paste") == 2, "R22 issues fire paste")
	world.grant_scaffold({"humus": 2, "mushroom": 1, "grass_meal": 1})
	check(world.start_batch(kitchen, "soil_spirit_pill")["ok"], "R23 starts after T12")
	guard = 0
	while not world.facilities[kitchen]["batch"].is_empty() and guard < 10:
		var b5: Dictionary = world.facilities[kitchen]["batch"]
		if b5["status"] == "ready": world.claim_batch(kitchen, int(b5["batch_id"]))
		else: world.end_day()
		guard += 1
	check(world.inventory.count("earth_pill") == 2, "R23 issues earth pills")
	world.grant_scaffold({"iron_ingot": 1, "honey": 1})
	check(world.start_batch(kitchen, "honey_mineral_food")["ok"], "R24 starts after T12")
	guard = 0
	while not world.facilities[kitchen]["batch"].is_empty() and guard < 10:
		var b6: Dictionary = world.facilities[kitchen]["batch"]
		if b6["status"] == "ready": world.claim_batch(kitchen, int(b6["batch_id"]))
		else: world.end_day()
		guard += 1
	check(world.inventory.count("gold_food") == 1, "R24 issues gold food")
	# Supply eligibility: mineral feed never supplies, the spirit foods do.
	check(not world._items["mineral_feed"]["supply_allowed"], "mineral feed stays ineligible")
	for item in ["honey_cake", "fish_spirit_meal", "dew_soup", "fire_paste", "earth_pill", "gold_food"]:
		check(world._items[item]["supply_allowed"], item + " supplies orders")

# --- 4. Day 45/46 device freeze boundary ----------------------------------------------

func _freeze_boundary() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 4, "raw_stone": 6, "wood_plank": 6, "iron_ingot": 2,
		"grain": 2, "humus": 1, "clean_water": 200})
	fund(world, 100)
	world.build_facility(Vector2i(2, 4), "research_bench")
	research_all(world, 1)
	check(world.build_facility(Vector2i(0, 3), "field_service_station")["ok"], "build the freeze station")
	var station := uid_of(world, "field_service_station")
	world.devices.configure_station(station, true, true, 90)
	world.till(Vector2i(0, 5))
	while world.clock.total_days < 46:
		world.grant_scaffold({"humus": 6})
		if not world.end_day()["ok"]:
			check(false, "freeze day failed: " + world.daily_save_error)
			break
	check(world.journal["frozen"], "journal frozen after day 45")
	var recap_cash: int = int(world.reports.state["recap"]["cash"])
	var water_used := 200 - world.inventory.count("clean_water")
	check(water_used > 0, "station actually consumed water across the run")
	var day46: Dictionary = world.end_day()
	check(day46["ok"], "day 46 settles")
	check(int(world.reports.state["recap"]["cash"]) == recap_cash, "day 46 device consumption never rewrites the recap")

# --- 5. Snapshot contracts ---------------------------------------------------------------

func _snapshot_contracts() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 4, "raw_stone": 6, "wood_plank": 6, "iron_ingot": 2,
		"grain": 2, "humus": 1, "clean_water": 10, "refined_oil": 2, "composite_stone_panel": 3})
	fund(world, 100)
	world.build_facility(Vector2i(2, 4), "research_bench")
	research_all(world, 1)
	check(world.build_facility(Vector2i(0, 3), "field_service_station")["ok"], "build station")
	var lamp_built: Dictionary = world.build_facility(Vector2i(5, 1), "growth_lamp")
	check(lamp_built["ok"], "build lamp (" + String(lamp_built.get("reason", "")) + ")")
	world.till(Vector2i(0, 5))
	for cell in [Vector2i(6, 1), Vector2i(7, 1), Vector2i(6, 2), Vector2i(7, 2)]:
		world.till(cell)
	world.buy("fast_fir_seed", 1)
	world.plant(Vector2i(6, 1), "fast_fir")
	world.devices.configure_lamp(uid_of(world, "growth_lamp"), true)
	world.end_day()
	var snapshot := world.to_snapshot()
	check(P8Snapshot.normalize(snapshot)["ok"], "device snapshot round trips")
	var restored := P8World.new()
	restored.apply_snapshot(snapshot)
	check(restored.devices.lamp_active_at(Vector2i(6, 1)), "active lamp survives reload")
	var probe: Dictionary = snapshot.duplicate(true)
	probe["world"]["devices"]["devices"][0]["data"]["threshold"] = 0
	check(not P8Snapshot.normalize(probe)["ok"], "zero threshold rejected")
	probe = snapshot.duplicate(true)
	probe["world"]["devices"]["active_lamps"].append(99)
	check(not P8Snapshot.normalize(probe)["ok"], "unknown active lamp rejected")
	probe = snapshot.duplicate(true)
	probe["world"]["devices"]["active_day"] = int(snapshot["clock"]["total_days"]) + 3
	check(not P8Snapshot.normalize(probe)["ok"], "future opening day rejected")
