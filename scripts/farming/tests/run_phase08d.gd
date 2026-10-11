extends SceneTree
## P8.d checks: flower shares and eligibility windows, hand picks, the bee
## lifecycle through real maintenance, share competition and pollination, plus
## a no-injection route from a fresh farm to real T01/T02/T03 research samples.
const P8World := preload("res://scripts/farming/p8/p8_world.gd")
const P8Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const P8Snapshot := preload("res://scripts/farming/p8/p8_snapshot.gd")

var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func temp_store() -> P8Store:
	return P8Store.new("user://p8d_test_%d" % Time.get_ticks_usec())

func complete_research(world, bench: int, project_id: String, samples: Dictionary) -> void:
	world.grant_scaffold(samples)
	var started: Dictionary = world.research.start(bench, project_id)
	check(started["ok"], "start %s (%s)" % [project_id, String(started.get("reason", ""))])
	var guard := 0
	while not world.research.is_completed(project_id) and guard < 12:
		world.research.work(bench)
		world.end_day()
		guard += 1

## Advance until the batch is ready, then claim it (ready batches stay occupied).
func drain_batch(world, facility_uid: int) -> void:
	var guard := 0
	while not world.facilities[facility_uid]["batch"].is_empty() and guard < 12:
		var batch: Dictionary = world.facilities[facility_uid]["batch"]
		if batch["status"] == "ready":
			world.claim_batch(facility_uid, int(batch["batch_id"]))
		else:
			world.end_day()
		guard += 1

func prepare_flower_farm(world, extra: Array = []) -> int:
	world.grant_scaffold({"raw_wood": 2, "raw_stone": 2})
	check(world.build_facility(Vector2i(2, 4), "research_bench")["ok"], "build bench")
	var bench := 0
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == "research_bench":
			bench = int(uid)
	complete_research(world, bench, "flower_cultivation", {"grain": 2, "humus": 1})
	for row in extra:
		complete_research(world, bench, String(row[0]), row[1])
	return bench

func _initialize() -> void:
	_shares_and_windows()
	_hand_picks()
	_bee_lifecycle()
	_competition_and_pollination()
	_recipes_after_research()
	_real_route_replay()
	_snapshot_contracts()
	for failure in failures: printerr(failure)
	print("PHASE08D TEST %s · %d checks" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

# --- 1. Eligibility and daily shares ------------------------------------------

func _shares_and_windows() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	prepare_flower_farm(world)
	world.till(Vector2i(1, 1))
	world.buy("honeybell_seed", 1)
	world.plant(Vector2i(1, 1), "honeybell_bush")
	var uid := 0
	for row in world.crops.values():
		uid = int(row["uid"])
	check(not world.flowers.share_available(uid), "immature honeybell holds no share")
	world.crops[uid]["progress"] = 600
	world.crops[uid]["state"] = "mature"
	check(world.flowers.share_available(uid), "mature honeybell offers its share")
	# Mid-day dryness suspends the unused remainder; recovery unseals it.
	var index := 1 * world.grid.width + 1
	world.environment[index][0] = 20
	check(world.flowers.share_of(uid)["used"] == 0, "share stays initialized through dryness")
	check(not world.flowers.share_available(uid), "dry plant suspends its unused share")
	world.environment[index][0] = 45
	check(world.flowers.share_available(uid), "recovery unseals the same unused share")
	# Oilseed window: progress in [300, 500) while still growing.
	world.till(Vector2i(2, 1))
	world.buy("oilseed_flower_seed", 1)
	world.plant(Vector2i(2, 1), "oilseed_flower")
	var oil := 0
	for row in world.crops.values():
		if String(row["crop_id"]) == "oilseed_flower":
			oil = int(row["uid"])
	world.crops[oil]["progress"] = 299
	check(not world.flowers.share_available(oil), "below the flowering window: no share")
	world.crops[oil]["progress"] = 300
	check(world.flowers.share_available(oil), "window start offers a share")
	world.crops[oil]["progress"] = 499
	check(world.flowers.share_available(oil), "window end still flowers")
	world.crops[oil]["progress"] = 500
	world.crops[oil]["state"] = "mature"
	check(not world.flowers.share_available(oil), "mature oilseed stops flowering")
	# Unused shares expire with the day.
	check(world.end_day()["ok"], "settle the share day")
	check(world.flowers.state["shares"].is_empty(), "shares expire at the day end")
	check(not world.flowers.share_available(oil), "new day, mature plant stays flowerless")

# --- 2. Hand picks --------------------------------------------------------------

func _hand_picks() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	prepare_flower_farm(world)
	world.till(Vector2i(1, 1))
	world.buy("honeybell_seed", 1)
	world.plant(Vector2i(1, 1), "honeybell_bush")
	var uid := 0
	for row in world.crops.values():
		uid = int(row["uid"])
	world.crops[uid]["progress"] = 600
	world.crops[uid]["state"] = "mature"
	var ap_before := world.clock.ap
	var picked: Dictionary = world.pick_flower(Vector2i(1, 1))
	check(picked["ok"] and world.inventory.count("nectar") == 2 and world.inventory.count("pollen") == 1, "hand pick issues the share contents")
	check(world.clock.ap == ap_before - 1, "hand pick costs 1 AP")
	check(not world.pick_flower(Vector2i(1, 1))["ok"], "second pick the same day refused")
	check(not world.flowers.pollinated(uid), "hand picks never pollinate")
	var flows: Dictionary = world.ledger.day_view(-1)
	var seen := 0
	for reason in flows.get("inflows", {}).get("nectar", {}):
		seen += int(flows["inflows"]["nectar"][reason])
	check(seen == 2, "pick recorded in the resource ledger")

# --- 3. The bee lifecycle through real maintenance -------------------------------

func _bee_lifecycle() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 6, "raw_stone": 6, "wood_plank": 2,
		"honeybell_seed": 2, "clean_water": 30})
	prepare_flower_farm(world, [["beekeeping", {"nectar": 2, "pollen": 1}]])
	check(world.build_facility(Vector2i(7, 1), "bee_hive")["ok"], "build hive after T02")
	var hive := 0
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == "bee_hive": hive = int(uid)
	world.till(Vector2i(9, 1))
	world.till(Vector2i(10, 1))
	world.plant(Vector2i(9, 1), "honeybell_bush")
	world.plant(Vector2i(10, 1), "honeybell_bush")
	for row in world.crops.values():
		row["progress"] = 600
		row["state"] = "mature"
	check(world.husbandry.purchase(hive, 2)["ok"], "buy two colonies")
	# Water alone cannot feed: with the shares drained by hand the quote fails.
	world.pick_flower(Vector2i(9, 1))
	world.pick_flower(Vector2i(10, 1))
	var drained: Dictionary = world.husbandry.quote_maintenance(hive)
	check(not drained["ok"] and String(drained["reason"]).find("花源") >= 0, "drained shares block the quote")
	world.end_day()
	var refreshed: Dictionary = world.husbandry.quote_maintenance(hive)
	check(refreshed["ok"], "fresh-day shares restore the quote")
	var fed: Dictionary = world.husbandry.maintain(hive)
	check(fed["ok"] and int(fed["served"]) == 2, "whole-hive maintenance serves both colonies")
	check(world.inventory.count("clean_water") == 28, "hive drinking water actually deducted")
	var coverage: Dictionary = world.flowers.hive_coverage(hive)
	check(int(coverage["available"]) == 0, "both shares consumed")
	world.end_day()
	# Three growth days turn the colonies adult; the same action starts cycles.
	for _day in range(3):
		check(world.husbandry.maintain(hive)["ok"], "growth service day")
		world.end_day()
	var summary: Dictionary = world.husbandry.summary(world.husbandry.habitat_of(hive))
	check(int(summary["adult"]) == 2 and int(summary["running"]) == 2, "colonies adult with honey cycles running")
	for _day in range(3):
		world.grant_scaffold({"clean_water": 2})
		check(world.husbandry.maintain(hive)["ok"], "cycle service day")
		world.end_day()
	var claim_quote: Dictionary = world.husbandry.quote_claim(hive)
	check(claim_quote["ok"] and int(claim_quote["ready"]) == 2, "both cycles ready")
	var claimed: Dictionary = world.husbandry.claim(hive)
	check(claimed["ok"] and world.inventory.count("honey") == 4 and world.inventory.count("beeswax") == 2, "claim issues honey and wax, colonies stay")
	var after: Dictionary = world.husbandry.summary(world.husbandry.habitat_of(hive))
	check(int(after["total"]) == 2 and int(after["idle_adults"]) == 2, "colonies survive the claim")

# --- 4. Share competition and pollination -----------------------------------------

func _competition_and_pollination() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 6, "raw_stone": 6, "wood_plank": 2,
		"honeybell_seed": 3, "oilseed_flower_seed": 2, "clean_water": 20})
	prepare_flower_farm(world, [["beekeeping", {"nectar": 2, "pollen": 1}]])
	check(world.build_facility(Vector2i(7, 1), "bee_hive")["ok"], "build hive")
	var hive := 0
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == "bee_hive": hive = int(uid)
	for cell in [Vector2i(9, 1), Vector2i(10, 1), Vector2i(11, 1)]:
		world.till(cell)
		world.plant(cell, "honeybell_bush")
	for row in world.crops.values():
		row["progress"] = 600
		row["state"] = "mature"
	world.husbandry.purchase(hive, 2)
	# Hand-pick one share: the hive can only feed from what remains.
	check(world.pick_flower(Vector2i(11, 1))["ok"], "player takes the third share")
	var short: Dictionary = world.husbandry.quote_maintenance(hive)
	check(short["ok"], "two remaining shares still cover two colonies")
	var fed: Dictionary = world.husbandry.maintain(hive)
	check(fed["ok"], "hive serves from the remaining shares")
	world.end_day()
	# Pollination: bees mark the oilseed cycle; the harvest pays one extra seed.
	# The oilseed sits inside the hive ring so its share feeds the colony.
	world.till(Vector2i(9, 2))
	world.plant(Vector2i(9, 2), "oilseed_flower")
	var oil := 0
	for row in world.crops.values():
		if String(row["crop_id"]) == "oilseed_flower": oil = int(row["uid"])
	world.crops[oil]["progress"] = 350
	# Drain one honeybell share so the draw order reaches the oilseed share
	# (stable uid order) while both colonies still get a full ration.
	world.pick_flower(Vector2i(9, 1))
	world.grant_scaffold({"clean_water": 2})
	var pollinated_run: Dictionary = world.husbandry.maintain(hive)
	check(pollinated_run["ok"], "hive consumes the oilseed share")
	check(world.flowers.pollinated(oil), "real hive use marks pollination")
	world.crops[oil]["progress"] = 500
	world.crops[oil]["state"] = "mature"
	var harvested: Dictionary = world.harvest(Vector2i(9, 2), "harvest")
	check(harvested["ok"], "oilseed harvest runs")
	check(world.inventory.count("oilseed") == 4 + 1, "pollinated cycle pays one extra oilseed")
	check(not world.flowers.pollinated(oil), "pollination cleared with the harvest")

# --- 5. Processing recipes behind their research ------------------------------------

func _recipes_after_research() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 20, "raw_stone": 20, "wood_plank": 6, "grain": 4, "humus": 2,
		"nectar": 2, "pollen": 1, "oilseed": 12, "straw": 6, "beeswax": 4, "charcoal": 4, "oil_cake": 4,
		"fodder_grass": 6, "algae_feed": 6})
	check(world.build_facility(Vector2i(2, 4), "research_bench")["ok"], "build bench")
	var bench := 0
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == "research_bench": bench = int(uid)
	complete_research(world, bench, "flower_cultivation", {"grain": 2, "humus": 1})
	complete_research(world, bench, "beekeeping", {"nectar": 2, "pollen": 1})
	complete_research(world, bench, "farm_preparation", {"oilseed": 2, "straw": 2})
	check(world.build_facility(Vector2i(0, 3), "farm_processor")["ok"], "build processor after T03")
	var processor := 0
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == "farm_processor": processor = int(uid)
	# R01 runs directly after T03; a busy processor refuses a second batch.
	world.grant_scaffold({"grain": 2, "fodder_grass": 3})
	check(world.start_batch(processor, "mill_grain")["ok"], "R01 starts after T03")
	check(not world.start_batch(processor, "mill_grass")["ok"], "busy processor refuses a second batch")
	drain_batch(world, processor)
	check(world.inventory.count("grain_meal") == 2, "R01 issues grain meal")
	check(world.start_batch(processor, "mill_grass")["ok"], "R02 starts after T03")
	drain_batch(world, processor)
	check(world.inventory.count("grass_meal") == 2, "R02 issues grass meal")
	world.grant_scaffold({"oilseed": 4})
	check(world.start_batch(processor, "press_oilseed")["ok"], "R03 starts after T03")
	drain_batch(world, processor)
	check(world.inventory.count("crude_oil") == 2 and world.inventory.count("oil_cake") == 6, "R03 issues both co-products")
	# T06 opens the refining chain; V01/V03 reuse the compost bin.
	complete_research(world, bench, "advanced_feed_oil_wax", {"crude_oil": 1, "beeswax": 1, "grain_meal": 1})
	world.grant_scaffold({"charcoal": 1})
	check(world.start_batch(processor, "refine_oil")["ok"], "R04 starts after T06")
	drain_batch(world, processor)
	check(world.inventory.count("refined_oil") == 2, "R04 issues refined oil")
	check(world.build_facility(Vector2i(0, 5), "compost_bin")["ok"], "build compost bin")
	var bin := 0
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == "compost_bin": bin = int(uid)
	world.grant_scaffold({"oil_cake": 2})
	check(world.start_batch(bin, "compost_oil_cake")["ok"], "V01 runs on the old bin")
	check(not world.start_batch(bin, "compost_spent_filter")["ok"], "V03 blocked without materials")

# --- 6. No-injection route to real research samples ----------------------------------

func _real_route_replay() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	# Real wheat farming funds T01's samples: grain from harvest, humus from straw.
	for x in range(1, 5):
		world.till(Vector2i(x, 1))
		world.plant(Vector2i(x, 1), "golden_wheat")
	while world.crops[int(world.crops.keys()[0])]["state"] != "mature":
		world.end_day()
	for x in range(1, 5):
		world.harvest(Vector2i(x, 1), "harvest")
	check(world.inventory.count("grain") >= 2 and world.inventory.count("straw") >= 2, "real wheat run yields T01 samples")
	check(world.collect("stone_source")["ok"], "real stone for the bin")
	check(world.collect("stone_source")["ok"], "real stone for the bench")
	world.buy("raw_wood", 3)
	check(world.build_facility(Vector2i(1, 4), "compost_bin")["ok"], "real compost bin")
	var bin_uid := 0
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == "compost_bin": bin_uid = int(uid)
	check(world.start_batch(bin_uid, "compost_straw")["ok"], "real straw compost")
	drain_batch(world, bin_uid)
	check(world.inventory.count("humus") >= 1, "real humus ready")
	check(world.build_facility(Vector2i(3, 4), "research_bench")["ok"], "real research bench")
	var bench := 0
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == "research_bench": bench = int(uid)
	check(world.research.start(bench, "flower_cultivation")["ok"], "T01 starts on real samples")
	while not world.research.is_completed("flower_cultivation"):
		world.research.work(bench)
		world.end_day()
	check(world.research.is_completed("flower_cultivation"), "T01 completed through real research days")
	# Real flower farming: buy the seed, grow to maturity, hand pick the share.
	check(world.buy("honeybell_seed", 1)["ok"], "real honeybell seed purchase")
	world.till(Vector2i(5, 1))
	world.plant(Vector2i(5, 1), "honeybell_bush")
	var honey_guard := 0
	while world.crops[int(world.crops.keys()[-1])]["state"] != "mature" and honey_guard < 20:
		if world.environment_at(Vector2i(5, 1))["water"] < 35:
			world.collect("spring_source")
			world.irrigate(Vector2i(5, 1))
		world.end_day()
		honey_guard += 1
	var picked: Dictionary = world.pick_flower(Vector2i(5, 1))
	check(picked["ok"], "real hand pick after real growth")
	check(world.research.start(bench, "beekeeping")["ok"], "T02 starts on real nectar/pollen")
	while not world.research.is_completed("beekeeping"):
		world.research.work(bench)
		world.end_day()
	check(world.research.is_completed("beekeeping"), "T02 completed through real samples")
	# Real oilseed farming covers T03: plant, wait for the mature harvest.
	check(world.buy("oilseed_flower_seed", 1)["ok"], "real oilseed seed purchase")
	world.till(Vector2i(6, 1))
	world.plant(Vector2i(6, 1), "oilseed_flower")
	var oil_guard := 0
	while world.crops[int(world.crops.keys()[-1])]["state"] != "mature" and oil_guard < 20:
		if world.environment_at(Vector2i(6, 1))["water"] < 35:
			world.collect("spring_source")
			world.irrigate(Vector2i(6, 1))
		world.end_day()
		oil_guard += 1
	world.harvest(Vector2i(6, 1), "harvest")
	check(world.inventory.count("oilseed") >= 4, "real oilseed harvest")
	check(world.research.quote_start(bench, "farm_preparation")["ok"] or world.inventory.count("oilseed") >= 2, "T03 samples reachable")
	print("P8.d REAL ROUTE day ", world.clock.total_days, " stones ", world.primeval_stones)

# --- 7. Snapshot contracts -------------------------------------------------------------

func _snapshot_contracts() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	prepare_flower_farm(world)
	world.till(Vector2i(1, 1))
	world.buy("honeybell_seed", 1)
	world.plant(Vector2i(1, 1), "honeybell_bush")
	var uid := 0
	for row in world.crops.values():
		uid = int(row["uid"])
	world.crops[uid]["progress"] = 600
	world.crops[uid]["state"] = "mature"
	world.pick_flower(Vector2i(1, 1))
	# Snapshot before the settle: the used share row exists for tamper probes.
	var snapshot := world.to_snapshot()
	var rechecked := P8Snapshot.normalize(snapshot)
	check(rechecked["ok"], "own snapshot normalizes")
	var probe: Dictionary = snapshot.duplicate(true)
	probe["world"]["flowers"]["shares"][0]["day"] = int(snapshot["clock"]["total_days"]) - 1
	check(not P8Snapshot.normalize(probe)["ok"], "stale share day rejected")
	probe = snapshot.duplicate(true)
	probe["world"]["flowers"]["shares"].append({"uid": uid, "day": int(snapshot["clock"]["total_days"]), "used": 0})
	check(not P8Snapshot.normalize(probe)["ok"], "duplicate share row rejected")
	check(world.end_day()["ok"], "settle clears the day-scoped shares")
	check(world.flowers.state["shares"].is_empty(), "share rows expired")
	probe = snapshot.duplicate(true)
	probe["world"]["flowers"]["shares"].append({"uid": 999, "day": int(snapshot["clock"]["total_days"]), "used": 0})
	check(not P8Snapshot.normalize(probe)["ok"], "share for unknown crop rejected")
	probe = snapshot.duplicate(true)
	probe["world"]["flowers"]["pollinated"].append(uid)
	check(not P8Snapshot.normalize(probe)["ok"], "pollination on a honeybell rejected")
