extends SceneTree
## P8.c checks: research state machine, receipts and settlement, farm-wide
## unlocks through the live gates, pause/resume, the candidate transaction over
## last-AP research work and the snapshot contracts.
const P8World := preload("res://scripts/farming/p8/p8_world.gd")
const P8Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const P8Snapshot := preload("res://scripts/farming/p8/p8_snapshot.gd")

var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func temp_store() -> P8Store:
	return P8Store.new("user://p8c_test_%d" % Time.get_ticks_usec())

func bench_uid(world, index: int = 0) -> int:
	var benches := []
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == "research_bench":
			benches.append(int(uid))
	benches.sort()
	return benches[mini(index, benches.size() - 1)]

func give_and_start(world, bench: int, project_id: String, extra: Dictionary = {}) -> Dictionary:
	var quote: Dictionary = world.research.quote_start(bench, project_id)
	var grant: Dictionary = quote["samples"].duplicate()
	for item in extra:
		grant[item] = int(grant.get(item, 0)) + int(extra[item])
	if not grant.is_empty():
		world.grant_scaffold(grant)
	return world.research.start(bench, project_id)

class FailingStore extends RefCounted:
	var inner
	var fail_commits := true
	func _init(real_store): inner = real_store
	func active_slot() -> int: return inner.active_slot()
	func create_slot(slot: int, snapshot: Dictionary, overwrite: bool = false) -> Dictionary:
		return inner.create_slot(slot, snapshot, overwrite)
	func open_slot(slot: int) -> Dictionary: return inner.open_slot(slot)
	func commit(_snapshot: Dictionary) -> Dictionary:
		if fail_commits: return {"ok": false, "reason": "模拟磁盘写入失败"}
		return inner.commit(_snapshot)

func _initialize() -> void:
	_start_validation()
	_manual_and_worker_work()
	_completion_unlocks()
	_pause_and_rollback()
	_demolish_and_snapshot()
	for failure in failures: printerr(failure)
	print("PHASE08C TEST %s · %d checks" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

# --- 1. Start validation ------------------------------------------------------

func _start_validation() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 4, "raw_stone": 4})
	check(world.build_facility(Vector2i(2, 4), "research_bench")["ok"], "build bench")
	check(world.build_facility(Vector2i(3, 4), "research_bench")["ok"], "build second bench")
	var bench_a := bench_uid(world, 0)
	var bench_b := bench_uid(world, 1)
	check(String(world.research.start(bench_a, "nope")["reason"]).find("未知") >= 0, "unknown project rejected")
	check(String(world.research.start(bench_a, "beekeeping")["reason"]).find("前置") >= 0, "missing prerequisite rejected")
	check(String(world.research.start(bench_a, "flower_cultivation")["reason"]).find("样本") >= 0, "missing samples rejected without payment")
	var built_balance := world.primeval_stones
	world.primeval_stones = 2
	check(String(world.research.quote_start(bench_a, "flower_cultivation")["blockers"].back()).find("元石") >= 0, "insufficient stones named")
	world.primeval_stones = built_balance
	check(give_and_start(world, bench_a, "flower_cultivation")["ok"], "T01 starts with samples and fee")
	check(world.inventory.count("grain") == 0 and world.inventory.count("humus") == 1 - 1, "samples deducted once")
	check(world.primeval_stones == built_balance - 4, "fee deducted once")
	check(not world.research.start(bench_a, "biofiltration")["ok"], "busy bench rejected")
	check(String(world.research.start(bench_b, "flower_cultivation")["reason"]).find("在研") >= 0, "second bench on the same project rejected")
	check(world.research.project_of("flower_cultivation")["bench_uid"] == bench_a, "project bound to its bench")
	var flows: Dictionary = world.ledger.day_view(-1)
	var sampled := 0
	for reason in flows.get("outflows", {}).get("grain", {}):
		sampled += int(flows["outflows"]["grain"][reason])
	check(sampled == 2, "sample deduction recorded in the ledger")

# --- 2. Manual and worker receipts ---------------------------------------------

func _manual_and_worker_work() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 4, "raw_stone": 5, "fodder_grass": 6, "clean_water": 6})
	check(world.build_facility(Vector2i(2, 4), "research_bench")["ok"], "build bench")
	check(world.build_facility(Vector2i(7, 1), "pen")["ok"], "build pen")
	var bench := bench_uid(world)
	var pen := 0
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == "pen": pen = int(uid)
	world.husbandry.purchase(pen, 1)
	check(give_and_start(world, bench, "flower_cultivation")["ok"], "start T01")
	var ap_before := world.clock.ap
	check(world.research.work(bench)["ok"], "manual work spends its AP")
	check(world.clock.ap == ap_before - 1, "manual research costs exactly 1 AP")
	check(not world.research.work(bench)["ok"], "second manual work the same day refused")
	var project: Dictionary = world.research.project_of("flower_cultivation")
	check(project["progress"] == 0 and project["worked"].size() == 1, "receipt registered, progress waits for the settle")
	check(world.end_day()["ok"], "settle the receipt day")
	check(int(world.research.project_of("flower_cultivation")["progress"]) == 1, "settle advances one valid day")
	# Worker path: manual receipt in the morning, then the assigned worker must
	# not duplicate it at the settle (bench-day marker is shared).
	check(world.workforce.hire("研究员")["ok"], "hire the researcher")
	world.operations.assign_owner(bench, 1)
	world.operations.assign_owner(pen, 1)
	check(world.research.work(bench)["ok"], "morning manual receipt")
	check(world.end_day()["ok"], "settle the shared-marker day")
	var row: Dictionary = {}
	for entry in world.workforce.state["report"]["workers"]:
		if int(entry["worker_id"]) == 1: row = entry
	var research_steps := 0
	for entry in row.get("facilities", []):
		if int(entry["uid"]) == bench:
			research_steps = int(entry["steps"].get("研究", 0))
	check(research_steps == 0 and int(row["fee"]) >= 1, "worker does not duplicate the manual receipt (shared marker)")
	# Next day the bench is free (T01 completed); start a fresh project so the
	# worker owns that day's receipt.
	world.grant_scaffold({"mushroom": 1, "raw_stone": 3})
	check(world.research.start(bench, "rock_handling")["ok"], "start T05 on the freed bench")
	check(world.end_day()["ok"], "settle the worker research day")
	var row2: Dictionary = {}
	for entry in world.workforce.state["report"]["workers"]:
		if int(entry["worker_id"]) == 1: row2 = entry
	var research_steps2 := 0
	for entry in row2.get("facilities", []):
		if int(entry["uid"]) == bench:
			research_steps2 = int(entry["steps"].get("研究", 0))
	check(research_steps2 == 1 and int(row2["fee"]) >= 2, "worker research counted and charged once")

# --- 3. Completion unlocks the live gates ---------------------------------------

func _completion_unlocks() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 4, "raw_stone": 5})
	check(world.build_facility(Vector2i(2, 4), "research_bench")["ok"], "build bench")
	check(world.build_facility(Vector2i(7, 1), "pen")["ok"], "build pen for stock")
	var bench := bench_uid(world)
	check(not world.buy("honeybell_seed", 1)["ok"], "seed locked before T01")
	check(not world.plant(Vector2i(1, 1), "honeybell_bush")["ok"], "planting locked before T01")
	check(give_and_start(world, bench, "flower_cultivation")["ok"], "start T01")
	check(world.research.work(bench)["ok"], "work day 1")
	check(world.end_day()["ok"], "settle day 1")
	check(world.research.work(bench)["ok"], "work day 2")
	check(world.end_day()["ok"], "settle day 2 — completes T01")
	check(world.research.is_completed("flower_cultivation"), "T01 completed")
	check(world.research.active_project(bench).is_empty(), "bench freed on completion")
	check(world.buy("honeybell_seed", 2)["ok"], "seed purchasable after T01")
	world.till(Vector2i(1, 1))
	check(world.plant(Vector2i(1, 1), "honeybell_bush")["ok"], "planting unlocked after T01")
	check(not world.can_build_facility(Vector2i(9, 1), "bee_hive")["ok"], "bee hive still locked before T02")
	check(not world.can_build_facility(Vector2i(9, 1), "farm_processor")["ok"], "processor still locked before T03")
	world.grant_scaffold({"nectar": 2, "pollen": 1})
	check(give_and_start(world, bench, "beekeeping")["ok"], "T02 startable after T01")
	world.research.work(bench)
	check(world.end_day()["ok"], "settle T02 day 1")
	world.research.work(bench)
	check(world.end_day()["ok"], "settle T02 day 2 — completes")
	check(world.research.is_completed("beekeeping"), "T02 completed")
	world.grant_scaffold({"raw_wood": 2, "wood_plank": 2})
	check(world.can_build_facility(Vector2i(9, 1), "bee_hive")["ok"], "bee hive buildable after T02")
	# Production strategies accept unlocked recipes; locked ones stay blocked.
	world.grant_scaffold({"raw_wood": 2, "raw_stone": 2})
	check(world.build_facility(Vector2i(10, 4), "algae_tank")["ok"], "build tank")
	var tank := 0
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == "algae_tank": tank = int(uid)
	check(not world.operations.set_production(tank, true, "dense_algae_culture", "dense_algae", 3)["ok"], "locked strategy recipe rejected")
	check(not world.research.is_completed("water_recirculation"), "T08 still open")

# --- 4. Pause and the last-AP rollback -------------------------------------------

func _pause_and_rollback() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 2, "raw_stone": 2})
	check(world.build_facility(Vector2i(2, 4), "research_bench")["ok"], "build bench")
	var bench := bench_uid(world)
	check(give_and_start(world, bench, "rock_handling")["ok"], "start T05")
	check(world.research.set_paused(bench, true)["ok"], "pause the project")
	check(not world.research.work(bench)["ok"], "paused project refuses work")
	check(world.research.set_paused(bench, false)["ok"], "resume the project")
	check(world.research.work(bench)["ok"], "resumed project accepts work")
	check(world.research.set_paused(bench, true)["ok"], "pause after the receipt keeps it")
	check(world.end_day()["ok"], "settle advances the receipt despite the pause")
	check(int(world.research.project_of("rock_handling")["progress"]) == 1, "receipt survived the pause")
	# Last-AP work with a failing commit: receipt, progress and unlock roll back
	# together and the retry publishes them exactly once.
	var real := temp_store()
	var failing := FailingStore.new(real)
	var world2 := P8World.new(failing)
	world2.start_new(1)
	world2.grant_scaffold({"raw_wood": 2, "raw_stone": 2})
	check(world2.build_facility(Vector2i(2, 4), "research_bench")["ok"], "build rollback bench")
	var bench2 := bench_uid(world2)
	give_and_start(world2, bench2, "biofiltration")
	for index in range(23):
		world2.till(Vector2i(index % 12, 4 + index / 12))
	failing.fail_commits = true
	var last: Dictionary = world2.research.work(bench2)
	check(last["ok"], "last-AP work registers the receipt")
	check(world2.clock.total_days == 0 and world2.clock.ap == 1, "failed commit restores the pre-work state")
	check(world2.research.project_of("biofiltration")["worked"].is_empty(), "receipt rolled back with the world")
	failing.fail_commits = false
	check(world2.retry_day_save()["ok"], "retry publishes the settled day")
	var after: Dictionary = world2.research.project_of("biofiltration")
	check(after["worked"] == [0] and int(after["progress"]) == 1, "receipt and progress applied exactly once")

# --- 5. Demolish guards and snapshot contracts ------------------------------------

func _demolish_and_snapshot() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 2, "raw_stone": 2})
	check(world.build_facility(Vector2i(2, 4), "research_bench")["ok"], "build bench")
	var bench := bench_uid(world)
	give_and_start(world, bench, "flower_cultivation")
	check(not world.demolish_facility(bench)["ok"], "busy bench refuses demolition")
	check(world.research.set_paused(bench, true)["ok"], "pause the project")
	check(not world.demolish_facility(bench)["ok"], "paused bench still refuses demolition")
	world.research.set_paused(bench, false)
	world.research.work(bench)
	check(world.end_day()["ok"], "settle day 0 with the first receipt")
	world.research.work(bench)
	check(world.end_day()["ok"], "settle day 1 — completes T01 and frees the bench")
	check(world.research.is_completed("flower_cultivation"), "T01 completed before demolition")
	check(world.demolish_facility(bench)["ok"], "freed bench demolishes")
	check(world.research.is_completed("flower_cultivation"), "knowledge survives the demolition")
	var snapshot := world.to_snapshot()
	check(P8Snapshot.normalize(snapshot)["ok"], "own snapshot normalizes")
	# Tamper probes against a fresh active project.
	world.grant_scaffold({"grain": 2, "humus": 1, "raw_wood": 2, "raw_stone": 2})
	check(world.build_facility(Vector2i(2, 4), "research_bench")["ok"], "rebuild the bench")
	var fresh_bench := bench_uid(world)
	world.research.start(fresh_bench, "rock_handling")
	world.grant_scaffold({"mushroom": 1, "raw_stone": 3})
	world.research.start(fresh_bench, "rock_handling")
	var live := world.to_snapshot()
	var probe: Dictionary = live.duplicate(true)
	probe["world"]["research"]["projects"][0]["id"] = "dragon_tech"
	check(not P8Snapshot.normalize(probe)["ok"], "unknown project rejected")
	probe = live.duplicate(true)
	probe["world"]["research"]["completed"] = ["flower_cultivation", "rock_handling"]
	check(not P8Snapshot.normalize(probe)["ok"], "completed while in research rejected")
	probe = live.duplicate(true)
	probe["world"]["research"]["projects"][0]["progress"] = 1
	check(not P8Snapshot.normalize(probe)["ok"], "progress beyond receipts rejected")
	probe = live.duplicate(true)
	probe["world"]["research"]["projects"][0]["bench_uid"] = 99
	check(not P8Snapshot.normalize(probe)["ok"], "unknown bench binding rejected")
	probe = live.duplicate(true)
	probe["world"]["research"]["projects"][0]["paused"] = "yes"
	check(not P8Snapshot.normalize(probe)["ok"], "non-boolean pause flag rejected")
	probe = live.duplicate(true)
	probe["world"]["research"]["projects"][0]["id"] = "composite_spirit_food"
	probe["world"]["research"]["projects"][0]["progress"] = 0
	probe["world"]["research"]["projects"][0]["worked"] = []
	check(not P8Snapshot.normalize(probe)["ok"], "unmet prerequisite in research rejected")
	# Completed knowledge survives a reload.
	var restored := P8World.new()
	restored.apply_snapshot(snapshot)
	check(restored.research.is_completed("flower_cultivation"), "completed knowledge round trips")
