extends SceneTree
## P8.a foundation checks: namespace isolation, research lockout, real water
## changes, the candidate day transaction and the 45/46 freeze boundary.
const P8World := preload("res://scripts/farming/p8/p8_world.gd")
const P8Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const P8Snapshot := preload("res://scripts/farming/p8/p8_snapshot.gd")
const V2Snapshot := preload("res://scripts/farming/v2/v2_snapshot.gd")

var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func temp_store(directory: String = "") -> P8Store:
	return P8Store.new(directory if not directory.is_empty() else "user://p8a_test_%d" % Time.get_ticks_usec())

## Commit-failing wrapper used to exercise the rollback path; every other call
## forwards to the real store.
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
	_namespace()
	_research_lockout()
	_water_change()
	_candidate_transaction()
	_last_ap_rollback()
	_freeze_boundary()
	for failure in failures: printerr(failure)
	print("PHASE08A TEST %s · %d checks" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func tilled_count(world) -> int:
	var tilled := 0
	for y in range(world.grid.height):
		for x in range(world.grid.width):
			if world.grid.state_at(Vector2i(x, y)) == world.grid.State.TILLED:
				tilled += 1
	return tilled

# --- 1. Namespace and slot isolation ---------------------------------------

func _namespace() -> void:
	var world := P8World.new(temp_store())
	check(world.data_source.load_data()["product"] == "farm_demo_p8", "P8 product identity")
	check(world._items.size() == 84 and world.facility_defs.size() == 39, "84 resources and 39 facilities registered")
	check(world.recipe_defs.size() == 64 and world.crop_defs.size() == 10, "64 recipes and 10 crops registered")
	check(P8Snapshot.fresh()["schema"] == P8Snapshot.SCHEMA, "current schema with logistics and agriculture snapshots")
	check(not P8Snapshot.normalize(V2Snapshot.fresh())["ok"], "V2 snapshots rejected by the P8 codec")
	check(not V2Snapshot.normalize(P8Snapshot.fresh())["ok"], "P8 snapshots rejected by the V2 codec")
	check(world.start_new(1)["ok"], "start a P8 slot")
	var reopened: Dictionary = P8Snapshot.normalize(world.to_snapshot())
	check(reopened["ok"], "own snapshot normalizes")
	check(int(reopened["snapshot"]["world"]["next_uid"]) >= 1, "normalized body intact")

# --- 2. Research lockout ----------------------------------------------------

func _research_lockout() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 30, "raw_stone": 30, "wood_plank": 10, "iron_ingot": 3, "composite_stone_panel": 2})
	for row in [
		["bee_hive", Vector2i(7, 1)],
		["farm_processor", Vector2i(9, 1)],
		["purifying_bed", Vector2i(0, 1)],
		["rock_breaking_yard", Vector2i(3, 1)],
		["kitchen", Vector2i(5, 1)],
		["field_service_station", Vector2i(0, 3)],
		["growth_lamp", Vector2i(6, 3)],
	]:
		var result: Dictionary = world.can_build_facility(row[1], row[0])
		check(not result["ok"] and String(result["reason"]).find("研究") >= 0, "gated facility blocked: " + String(row[0]))
	var bench: Dictionary = world.can_build_facility(Vector2i(2, 4), "research_bench")
	check(bench["ok"], "research bench buildable without research")
	check(not world.buy("honeybell_seed", 1)["ok"], "gated seed purchase blocked")
	check(not world.buy("purifying_mat_culture", 1)["ok"], "gated culture purchase blocked")
	check(not world.plant(Vector2i(1, 1), "honeybell_bush")["ok"], "gated crop planting blocked")
	check(not world.plant(Vector2i(1, 1), "oilseed_flower")["ok"], "second gated crop blocked")
	# Locked recipes on default facilities: build a woodshop and try R09.
	check(world.build_facility(Vector2i(10, 1), "woodshop")["ok"], "build a default woodshop")
	var woodshop := 0
	for uid in world.facilities:
		if world.facilities[uid]["facility_id"] == "woodshop": woodshop = int(uid)
	check(not world.start_batch(woodshop, "make_filter_media")["ok"], "gated recipe start blocked")
	check(world.start_batch(woodshop, "saw_planks")["ok"], "default recipe still starts")
	# Optional research diets stay unselectable; defaults keep working. The
	# pen is a P10.3 structural facility: sheep buy through a ranch nursery.
	world.grant_scaffold({"fodder_grass": 6, "clean_water": 6, "raw_wood": 30, "raw_stone": 10})
	for y in range(1, 4):
		for x in range(6, 10):
			check(world.rooms.set_floor(Vector2i(x, y), "ordinary")["ok"], "pave ranch floor %d,%d" % [x, y])
	check(world.build_facility(Vector2i(6, 1), "pen")["ok"], "build a pen")
	var pen := 0
	for uid in world.facilities:
		if world.facilities[uid]["facility_id"] == "pen": pen = int(uid)
	check(not world.build_facility(Vector2i(4, 1), "pen")["ok"], "ranch facility needs ordinary floor")
	world.husbandry.ensure(pen)
	check(world.husbandry.set_diet(pen, "base_diets", "basic_diet_id", "land_meal")["reason"].length() > 0, "old habitat path closed for the pen")
	check(not world.husbandry.purchase(pen, 1)["ok"], "old species purchase closed for the pen")
	check(world.build_facility(Vector2i(8, 1), "feed_trough")["ok"], "build a trough")
	check(world.build_facility(Vector2i(9, 1), "medium_bed")["ok"], "build a medium bed group")
	var nursery: Dictionary = world.ranch.create_zone("nursery", ["6,1", "7,1", "8,1", "9,1", "6,2", "7,2", "8,2", "9,2", "6,3", "7,3", "8,3", "9,3"], "育幼区")
	check(nursery["ok"], "nursery zone created")
	check(not world.ranch.purchase(int(nursery["zone_uid"]), "filter_algae_carp", 1)["ok"], "ranch purchase refuses non-terrestrial species")
	check(world.ranch.purchase(int(nursery["zone_uid"]), "steel_sheep", 1)["ok"], "default species purchase works through the ranch")
	var sheep_uid := int(world.ranch.state["animals"][0]["uid"])
	check(world.ranch.set_diet(sheep_uid, "land_meal")["reason"].find("研究") >= 0, "gated base diet blocked")
	check(world.ranch.set_diet(sheep_uid, "grain_meal")["ok"], "default diet switch still works")

# --- 3. Real water change ---------------------------------------------------

func _water_change() -> void:
	# P10.6 §16.2.12: fish_pond is retired; the real water change now lives on
	# explicit water bodies (fence + change_water), so this scenario follows the
	# live module instead of the retired habitat path.
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"twig": 4, "clean_water": 12})
	world.primeval_stones += 4
	check(not world.water.change_water(1)["ok"], "unknown body refuses a change")
	var fenced: Dictionary = world.water.build_fence([Vector2i(0, 14), Vector2i(1, 14)], 0)
	check(fenced["ok"], "fence two cells")
	var body_uid := int(fenced["body"])
	check(int(world.water.body(body_uid)["quality"]) == 20000, "body starts full")
	check(world.water.change_water(body_uid)["ok"], "change runs on a full body")
	check(world.inventory.count("wastewater") == 2, "sewage enters stock")
	check(world.inventory.count("clean_water") == 10, "clean water actually deducted")
	check(int(world.water.body(body_uid)["quality"]) == 20000, "full body stays at the cap, excess wasted")
	check(not world.water.change_water(body_uid)["ok"], "second same-day change refused")
	check(world.end_day()["ok"], "settle day 0")
	check(world.water.quality(world.water.body(body_uid)) == 98, "water decays to 98")
	var day1: Dictionary = world.water.change_water(body_uid)
	check(day1["ok"] and int(day1["applied"]) == 400 and world.inventory.count("wastewater") == 4,
		"next day allows a fresh change")
	# Ledger rows carry the real flow under one reason label.
	var flows: Dictionary = world.ledger.day_view(-1)
	var seen_sewage := 0
	for reason in flows.get("inflows", {}).get("wastewater", {}):
		seen_sewage += int(flows["inflows"]["wastewater"][reason])
	check(seen_sewage == 2, "today's ledger records the sewage inflow")
	check(world.end_day()["ok"], "settle day 1 with conservation intact")
	# The body and its change marker persist through save/load.
	var restored := P8World.new()
	restored.apply_snapshot(world.to_snapshot())
	check(int(restored.water.body(body_uid)["change_day"]) == 1, "water-change marker round trips")
	check(restored.water.quality(restored.water.body(body_uid)) == 98, "body quality round trips")
	check(restored.daily_save_error.is_empty(), "restored world stays playable")

# --- 4. Candidate day transaction ------------------------------------------

func _candidate_transaction() -> void:
	var real := temp_store()
	var failing := FailingStore.new(real)
	var world := P8World.new(failing)
	world.start_new(1)
	check(world.buy("grass_seed", 2)["ok"], "day 0 purchase before the failure")
	var stones_before := world.primeval_stones
	var result: Dictionary = world.end_day()
	check(not String(result.get("save_error", "")).is_empty() or not world.daily_save_error.is_empty(), "explicit day end fails on write error")
	check(world.clock.total_days == 0 and world.clock.ap == 24, "world rolled back to the pre-action state")
	check(world.primeval_stones == stones_before, "cash rolled back with the world")
	check(world.inventory.count("grass_seed") == 2, "inventory rolled back with the world")
	check(not world.buy("grass_seed", 1)["ok"], "operations locked while a candidate is pending")
	failing.fail_commits = false
	var retried: Dictionary = world.retry_day_save()
	check(retried["ok"], "retry writes the retained candidate")
	check(world.clock.total_days == 1, "candidate published exactly once")
	check(world.primeval_stones == stones_before and world.inventory.count("grass_seed") == 2, "published state matches the settled candidate")
	check(world.daily_save_error.is_empty(), "error cleared after publishing")
	var settle1: Dictionary = world.end_day()
	check(settle1["ok"] and world.daily_save_error.is_empty(), "next day settles normally after retry")
	check(world.journal["history"].size() == 2, "two settled days in the journal")
	# A second failure followed by abandon restores the last valid archive.
	failing.fail_commits = true
	world.end_day()
	check(world.clock.total_days == 2, "failed commit keeps the world at day 2")
	check(not world.daily_save_error.is_empty(), "error surfaced after second failure")
	var abandoned: Dictionary = world.abandon_day()
	check(abandoned["ok"] and world.clock.total_days == 2, "abandon reloads the last valid save")
	check(world.daily_save_error.is_empty(), "abandon clears the failure")

# --- 5. Last-AP action rollback --------------------------------------------

func _last_ap_rollback() -> void:
	var real := temp_store()
	var failing := FailingStore.new(real)
	var world := P8World.new(failing)
	world.start_new(1)
	for index in range(23):
		if not world.till(Vector2i(index % 12, index / 12 + 1))["ok"]:
			check(false, "till %d should succeed" % index)
			break
	failing.fail_commits = true
	var last: Dictionary = world.till(Vector2i(11, 2))
	check(not bool(last.get("saved", false)), "last-AP action reports the save failure")
	check(world.clock.total_days == 0 and world.clock.ap == 1, "world restored before the last action")
	check(tilled_count(world) == 23, "exactly the first 23 tills survive the rollback")
	failing.fail_commits = false
	check(world.retry_day_save()["ok"], "retry publishes the settled day")
	check(tilled_count(world) == 24 and world.clock.total_days == 1, "candidate applies the 24th till and the new day")

# --- 6. 45/46 freeze boundary ------------------------------------------------

func _freeze_boundary() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	while world.clock.total_days < 46:
		if not world.end_day()["ok"]:
			check(false, "day %d settle failed: %s" % [world.clock.total_days, world.daily_save_error])
			break
	check(world.clock.total_days == 46, "46 days settled")
	check(world.journal["frozen"], "journal frozen after day 45")
	check(world.journal["end_cash"] == int(world.config["initial_primeval_stones"]), "recap keeps the day-45 cash")
	check(world.journal["history"].size() == 15, "journal keeps 15 day rows")
	var ledger_history: Array = world.ledger.state["history"]
	check(ledger_history.size() == 15 and int(ledger_history[-1]["day"]) == 45, "ledger rolls to day 45")
	check(int(world.ledger.state["pending"]["day"]) == 46, "day 46 opens a fresh pending ledger")
	check(world.reports.recap_active(), "husbandry recap frozen")
	var recap_cash: int = int(world.reports.state["recap"]["cash"])
	var day46: Dictionary = world.end_day()
	check(day46["ok"], "day 46 settles")
	check(int(world.reports.state["recap"]["cash"]) == recap_cash, "day 46 does not rewrite the frozen recap")
