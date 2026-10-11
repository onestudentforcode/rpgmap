extends SceneTree
## P8.b checks: multi-facility ownership, the unified quota/budget, production
## strategies with effective stock, reserves, priority rotation with backlog
## and the P8 roster/snapshot contracts.
const P8World := preload("res://scripts/farming/p8/p8_world.gd")
const P8Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const P8Snapshot := preload("res://scripts/farming/p8/p8_snapshot.gd")

var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func temp_store() -> P8Store:
	return P8Store.new("user://p8b_test_%d" % Time.get_ticks_usec())

func fresh_world() -> Array:
	var world := P8World.new(temp_store())
	world.start_new(1)
	return [world, 0]

func uid_of(world, facility_id: String) -> int:
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == facility_id:
			return int(uid)
	return 0

func report_row(world, worker_id: int) -> Dictionary:
	for row in world.workforce.state["report"]["workers"]:
		if int(row["worker_id"]) == worker_id:
			return row
	return {}

func _initialize() -> void:
	_ownership_and_quota()
	_production_and_reserves()
	_priority_rotation_backlog()
	_manual_service_and_water()
	_snapshot_contracts()
	for failure in failures: printerr(failure)
	print("PHASE08B TEST %s · %d checks" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

# --- 1. Ownership registry and the unified quota -----------------------------

func _ownership_and_quota() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 12, "raw_stone": 12, "fodder_grass": 30, "clean_water": 30})
	world.primeval_stones += 60
	check(world.build_facility(Vector2i(7, 1), "pen")["ok"], "build pen A")
	check(world.build_facility(Vector2i(9, 1), "pen")["ok"], "build pen B")
	var pen_a := uid_of(world, "pen")
	var pen_b := 0
	for uid in world.facilities:
		if int(uid) != pen_a and String(world.facilities[uid]["facility_id"]) == "pen":
			pen_b = int(uid)
	check(world.husbandry.purchase(pen_a, 2)["ok"], "stock pen A")
	check(world.husbandry.purchase(pen_b, 2)["ok"], "stock pen B")
	check(world.workforce.hire("多面手")["ok"], "hire the multi-facility worker")
	var worker_id := int(world.workforce.state["workers"][0]["id"])
	world.workforce.configure(worker_id, 12, false, world.workforce.state["workers"][0]["priorities"], [[0, 4, 10, 2]])
	check(world.operations.assign_owner(pen_a, worker_id)["ok"], "bind facility A")
	check(world.operations.assign_owner(pen_b, worker_id)["ok"], "bind facility B")
	check(world.operations.owner_of(pen_a) == worker_id and world.operations.owner_of(pen_b) == worker_id, "one worker owns two facilities")
	check(world.operations.facilities_of(worker_id) == [pen_a, pen_b], "derived roster list")
	check(world.operations.set_priority(pen_b, "high")["ok"], "priority change")
	check(world.operations.assign_owner(pen_a, 0)["ok"], "unassign keeps the other binding")
	check(world.operations.owner_of(pen_a) == 0 and world.operations.owner_of(pen_b) == worker_id, "per-facility unassign")
	check(world.operations.assign_owner(pen_a, worker_id)["ok"], "rebind facility A")
	# Farm duty with 20 till marks on tillable rows: quota caps at 12.
	for index in range(20):
		var cell := Vector2i(index % 10, 1 if index < 10 else 4)
		world.workforce.mark(Rect2i(cell.x, cell.y, 1, 1), "till")
	check(world.workforce.set_farm_duty(worker_id, true, "normal")["ok"], "enable farm duty")
	check(world.workforce.state["workers"][0]["farm_duty"]["enabled"], "farm duty persisted on the roster")
	check(world.end_day()["ok"], "settle the mixed day")
	var row := report_row(world, worker_id)
	check(int(row["success"]) == 12 and int(row["fee"]) == 12, "unified quota caps at 12 (%d/%d)" % [int(row["success"]), int(row["fee"])])
	check(String(row["reason"]) == "达到每日工作上限", "cap reason surfaced")
	var facility_steps := 0
	for entry in row["facilities"]:
		for step in entry["steps"]:
			facility_steps += int(entry["steps"][step])
	check(facility_steps >= 1, "facility maintenance executed within the shared quota")
	check(world.primeval_stones >= 0, "no negative balance")
	# Budget below the workload: successes match the budget, not the work.
	var world2 := P8World.new(temp_store())
	world2.start_new(1)
	world2.grant_scaffold({"fodder_grass": 30, "clean_water": 30})
	check(world2.workforce.hire("预算工")["ok"], "hire budget worker")
	world2.workforce.configure(1, 3, false, world2.workforce.state["workers"][0]["priorities"], [[0, 1, 10, 1]])
	for index in range(10):
		world2.workforce.mark(Rect2i(index, 1, 1, 1), "till")
	world2.workforce.set_farm_duty(1, true, "normal")
	check(world2.end_day()["ok"], "settle the budget day")
	var row2 := report_row(world2, 1)
	check(int(row2["success"]) == 3 and int(row2["fee"]) == 3, "personal budget caps successes")
	check(String(row2["reason"]) == "预算或元石不足", "budget reason surfaced")
	# Wage precheck: exactly one stone left pays one success, then stops clean.
	var world3 := P8World.new(temp_store())
	world3.start_new(1)
	world3.primeval_stones = 1
	check(world3.workforce.hire("拮据工")["ok"], "hire the broke worker")
	world3.workforce.configure(1, 12, false, world3.workforce.state["workers"][0]["priorities"], [[0, 1, 10, 1]])
	for index in range(4):
		world3.workforce.mark(Rect2i(index, 1, 1, 1), "till")
	world3.workforce.set_farm_duty(1, true, "normal")
	check(world3.end_day()["ok"], "settle the broke day")
	var row3 := report_row(world3, 1)
	check(int(row3["success"]) == 1 and world3.primeval_stones == 0, "wage precheck keeps the balance at zero, never negative")

# --- 2. Production strategy, effective stock and reserves --------------------

func _production_and_reserves() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 3, "raw_stone": 3, "clean_water": 3, "straw": 2})
	check(world.build_facility(Vector2i(10, 4), "algae_tank")["ok"], "build tank A")
	check(world.build_facility(Vector2i(12, 4), "algae_tank")["ok"], "build tank B")
	var tank_a := 0
	var tank_b := 0
	for uid in world.facilities:
		if tank_a == 0: tank_a = int(uid)
		else: tank_b = int(uid)
	check(world.workforce.hire("调度工")["ok"], "hire scheduler")
	var worker_id := int(world.workforce.state["workers"][0]["id"])
	check(world.operations.assign_owner(tank_a, worker_id)["ok"], "bind tank A")
	check(world.operations.assign_owner(tank_b, worker_id)["ok"], "bind tank B")
	check(world.operations.set_production(tank_a, true, "culture_algae", "algae_feed", 6)["ok"], "strategy on tank A")
	check(world.operations.set_production(tank_b, true, "culture_algae", "algae_feed", 6)["ok"], "strategy on tank B")
	check(not world.operations.set_production(tank_a, true, "saw_planks", "wood_plank", 2)["ok"], "strategy rejects foreign recipe")
	check(not world.operations.set_production(tank_a, true, "culture_algae", "grain", 2)["ok"], "strategy rejects non-output target")
	check(not world.operations.set_production(tank_a, true, "make_filter_media", "filter_media", 2)["ok"], "strategy rejects locked recipe")
	# Exactly one batch of inputs: the second tank must see the in-progress batch.
	check(world.end_day()["ok"], "settle the start day")
	var started := 0
	for uid in [tank_a, tank_b]:
		if not world.facilities[uid]["batch"].is_empty(): started += 1
	check(started == 1, "effective stock stops the second auto start (%d)" % started)
	check(world.inventory.count("clean_water") == 0 and world.inventory.count("straw") == 0, "inputs consumed once")
	check(world.operations.effective_stock("algae_feed") == 6, "in-progress outputs count as stock")
	# Reserves block the next auto batch but never the manual one.
	world.grant_scaffold({"clean_water": 3, "straw": 4})
	var idle_probe := tank_a if world.facilities[tank_a]["batch"].is_empty() else tank_b
	check(world.operations.set_production(idle_probe, true, "culture_algae", "algae_feed", 12)["ok"], "raise the idle target")
	check(world.operations.set_production(tank_a if idle_probe == tank_b else tank_b, true, "culture_algae", "algae_feed", 12)["ok"], "raise the busy target")
	check(world.operations.set_reserve("clean_water", 3)["ok"], "set reserve")
	check(world.operations.auto_start_block(tank_a if world.facilities[tank_a]["batch"].is_empty() else tank_b) == "原料保留量阻挡：清水", "reserve blocks the auto start")
	# The batch turns ready after a settle flip, so the owner claims it on the
	# next day-end run (same "no same-day claim" rule as habitat cycles).
	check(world.end_day()["ok"], "settle processing day 1")
	check(world.end_day()["ok"], "settle the ready flip")
	check(world.end_day()["ok"], "settle the auto-claim day")
	var any_batch := false
	for uid in [tank_a, tank_b]:
		if not world.facilities[uid]["batch"].is_empty(): any_batch = true
	check(not any_batch and world.inventory.count("algae_feed") == 6, "ready batch auto-claimed into stock")
	# Manual start ignores the reserve entirely.
	var idle := tank_a if world.facilities[tank_a]["batch"].is_empty() else tank_b
	check(world.start_batch(idle, "culture_algae")["ok"], "manual start bypasses the reserve")
	check(world.inventory.count("clean_water") == 0, "manual start still pays real inputs")
	check(world.end_day()["ok"] and world.end_day()["ok"] and world.end_day()["ok"], "drain the calendar")

# --- 3. Priority tiers, same-tier rotation and backlog ------------------------

func _priority_rotation_backlog() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 4, "raw_stone": 4, "clean_water": 9, "straw": 6})
	var tanks := []
	for index in range(3):
		check(world.build_facility(Vector2i(9 + index, 1), "algae_tank")["ok"], "build tank %d" % index)
		tanks.append(uid_of_late(world, index))
	# Start three batches manually so they all become ready together.
	for uid in tanks:
		check(world.start_batch(uid, "culture_algae")["ok"], "manual batch on tank %d" % uid)
	check(world.end_day()["ok"] and world.end_day()["ok"], "advance to ready")
	var ready := 0
	for uid in tanks:
		if world.facilities[uid]["batch"]["status"] == "ready": ready += 1
	check(ready == 3, "three ready batches")
	check(world.workforce.hire("轮转工")["ok"], "hire rotation worker")
	var worker_id := int(world.workforce.state["workers"][0]["id"])
	world.workforce.configure(worker_id, 2, false, world.workforce.state["workers"][0]["priorities"], [])
	for uid in tanks:
		world.operations.assign_owner(uid, worker_id)
	# Same tier, same class: budget 2 claims two distinct tanks (rotation), one waits.
	check(world.end_day()["ok"], "settle the rotation day")
	var row := report_row(world, worker_id)
	check(int(row["success"]) == 2, "budget bounds the claims")
	var claimed_uids := []
	for entry in row["facilities"]:
		if int(entry["steps"].get("加工收取", 0)) > 0:
			claimed_uids.append(int(entry["uid"]))
	check(claimed_uids.size() == 2 and claimed_uids[0] != claimed_uids[1], "same-tier rotation picks distinct facilities")
	var waiting_uids: Array = world.operations.state["waiting"].keys()
	check(waiting_uids.size() == 1, "starved facility keeps a backlog marker")
	var waiting_uid := int(waiting_uids[0])
	check(world.operations.facility_waiting_days(waiting_uid, world.clock.total_days) >= 1, "backlog age is at least one day")
	# High priority jumps the queue on the following day.
	check(world.operations.set_priority(waiting_uid, "high")["ok"], "raise the starved facility")
	world.grant_scaffold({"clean_water": 3, "straw": 2})
	check(world.end_day()["ok"], "settle the priority day")
	var row2 := report_row(world, worker_id)
	var first_claim := 0
	for entry in row2["facilities"]:
		if int(entry["steps"].get("加工收取", 0)) > 0:
			first_claim = int(entry["uid"])
			break
	check(first_claim == waiting_uid, "high priority facility claimed first")
	check(not world.operations.state["waiting"].has(waiting_uid), "served facility clears its backlog marker")

func uid_of_late(world, index: int) -> int:
	var tanks := []
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == "algae_tank":
			tanks.append(int(uid))
	tanks.sort()
	return tanks[index]

# --- 4. Manual service, reassignment and the day-end water change -------------

func _manual_service_and_water() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_stone": 7, "raw_wood": 3, "fodder_grass": 12, "clean_water": 12, "algae_feed": 8})
	check(world.build_facility(Vector2i(7, 1), "pen")["ok"], "build the pen")
	check(world.build_facility(Vector2i(0, 14), "fish_pond")["ok"], "build the pond")
	var pen := uid_of(world, "pen")
	var pond := uid_of(world, "fish_pond")
	check(world.husbandry.purchase(pen, 1)["ok"], "stock the pen")
	check(world.husbandry.purchase(pond, 2)["ok"], "stock the pond")
	# Player feeds the pen manually; the assigned worker must not re-feed it.
	check(world.husbandry.maintain(pen)["ok"], "manual pen service")
	check(world.workforce.hire("接班工")["ok"], "hire the reliever")
	var worker_id := int(world.workforce.state["workers"][0]["id"])
	world.operations.assign_owner(pen, worker_id)
	world.operations.assign_owner(pond, worker_id)
	var stones_before := world.primeval_stones
	check(world.end_day()["ok"], "settle the handoff day")
	var row := report_row(world, worker_id)
	var fed_again := 0
	for entry in row["facilities"]:
		if int(entry["uid"]) == pen and int(entry["steps"].get("整体维护", 0)) > 0:
			fed_again = int(entry["steps"]["整体维护"])
	check(fed_again == 0, "manual service is not repeated or charged")
	for individual in world.husbandry.habitat_of(pen)["individuals"]:
		check(String(individual["base_service"]["operator"]) == "player", "original service record preserved")
		break
	# Let the pond decay to the worker threshold: the day-end run performs the
	# real water change inside the completed day and feeds afterwards.
	world.primeval_stones += 40  # 测试注资：覆盖衰减期间负责人每日维护费
	var decay_days := 0
	while int(world.husbandry.habitat_of(pond)["water"]) > 60 and decay_days < 12:
		var decay: Dictionary = world.end_day()
		if not decay["ok"] or not world.daily_save_error.is_empty():
			check(false, "decay day failed: " + String(decay.get("save_error", world.daily_save_error)))
			break
		decay_days += 1
	var water_before := int(world.husbandry.habitat_of(pond)["water"])
	var sewage_before := world.inventory.count("wastewater")
	check(world.end_day()["ok"], "settle the water-change day")
	check(world.inventory.count("wastewater") == sewage_before + 2, "worker water change produced sewage")
	check(int(world.husbandry.habitat_of(pond)["water"]) == mini(100, water_before - 5 + 40), "water changed then decayed")
	check(int(world.husbandry.habitat_of(pond)["water_change_day"]) == world.clock.total_days - 1, "change marker stamped on the completed day")

# --- 5. Snapshot contracts -----------------------------------------------------

func _snapshot_contracts() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 2, "raw_stone": 2})
	check(world.build_facility(Vector2i(10, 8), "algae_tank")["ok"], "build a tank")
	var tank := uid_of(world, "algae_tank")
	check(world.workforce.hire("存档工")["ok"], "hire for the snapshot")
	world.operations.assign_owner(tank, 1)
	world.operations.set_production(tank, true, "culture_algae", "algae_feed", 24)
	world.operations.set_reserve("straw", 2)
	world.workforce.set_farm_duty(1, true, "low")
	check(world.end_day()["ok"], "one settle for report rows")
	var snapshot := world.to_snapshot()
	var restored := P8World.new()
	restored.apply_snapshot(snapshot)
	check(restored.operations.owner_of(tank) == 1, "binding round trip")
	check(restored.operations.strategy_of(tank)["target_qty"] == 24, "strategy round trip")
	check(restored.operations.state["reserves"]["straw"] == 2, "reserve round trip")
	check(bool(restored.workforce._worker(1)["farm_duty"]["enabled"]) and String(restored.workforce._worker(1)["farm_duty"]["priority"]) == "low", "farm duty round trip")
	var rechecked := P8Snapshot.normalize(snapshot)
	check(rechecked["ok"], "own snapshot normalizes")
	# Tamper probes: each corruption must be rejected before it touches a world.
	var probe: Dictionary = snapshot.duplicate(true)
	probe["world"]["p8"]["facilities"][0]["priority"] = "urgent"
	check(not P8Snapshot.normalize(probe)["ok"], "bad priority rejected")
	probe = snapshot.duplicate(true)
	probe["world"]["p8"]["facilities"][0]["owner"] = 99
	check(not P8Snapshot.normalize(probe)["ok"], "unknown owner rejected")
	probe = snapshot.duplicate(true)
	probe["world"]["p8"]["facilities"].append({"uid": tank, "owner": 1, "priority": "normal"})
	check(not P8Snapshot.normalize(probe)["ok"], "duplicate binding rejected")
	probe = snapshot.duplicate(true)
	probe["world"]["p8"]["production"][0]["target_qty"] = -1
	check(not P8Snapshot.normalize(probe)["ok"], "negative target rejected")
	probe = snapshot.duplicate(true)
	probe["world"]["p8"]["reserves"][0]["item"] = "dragon_scale"
	check(not P8Snapshot.normalize(probe)["ok"], "unknown reserve item rejected")
	probe = snapshot.duplicate(true)
	probe["workforce"]["workers"][0]["farm_duty"]["priority"] = "urgent"
	check(not P8Snapshot.normalize(probe)["ok"], "bad farm-duty priority rejected")
	probe = snapshot.duplicate(true)
	probe["workforce"]["report"]["workers"][0]["facilities"].append({"uid": tank, "steps": {"收取": 1}, "skipped": []})
	probe["workforce"]["report"]["workers"][0]["success"] = 2
	probe["workforce"]["report"]["workers"][0]["fee"] = 2
	check(not P8Snapshot.normalize(probe)["ok"], "report steps must match success totals")
