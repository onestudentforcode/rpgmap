extends SceneTree
const World := preload("res://scripts/farming/v1/v1_world.gd")
const Snapshot := preload("res://scripts/farming/v1/v1_snapshot.gd")
const Store := preload("res://scripts/farming/v1/v1_slot_store.gd")
const Grid := preload("res://scripts/farming/core/grid/land_grid.gd")
var failures: Array[String] = []
var checks := 0

class FlakyStore extends "res://scripts/farming/v1/v1_slot_store.gd":
	var fail_write := false
	func _rename(from: String, to: String) -> Error:
		return ERR_CANT_CREATE if fail_write and from.ends_with(".tmp") else super._rename(from, to)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func unchanged(world: World, action: Callable, label: String) -> void:
	var before := world.to_snapshot()
	check(not action.call()["ok"] and world.to_snapshot() == before, label)

func prepare(world: World, cell: Vector2i, crop_id: String) -> void:
	var definition: Dictionary = world.crop_defs[crop_id]
	for y in range(int(definition["footprint"][1])):
		for x in range(int(definition["footprint"][0])):
			check(world.till(cell + Vector2i(x,y))["ok"], "prepare " + crop_id)

func days(world: World, count: int) -> void:
	for _day in range(count):
		world.end_day()

func _initialize() -> void:
	_lifecycles()
	_environment()
	_sources()
	_validation()
	_daily_storage()
	for failure in failures:
		printerr(failure)
	print("V1 PRODUCTION TEST %s: %d checks" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _lifecycles() -> void:
	var world := World.new()
	var wheat := Vector2i(5,2)
	prepare(world, wheat, "golden_wheat")
	check(world.plant(wheat, "golden_wheat")["ok"], "plant wheat")
	check(world.inventory.count("golden_wheat_seed") == 7 and world.clock.ap == 22, "seed/AP consumed once")
	unchanged(world, func(): return world.plant(wheat, "golden_wheat"), "overlap atomic")
	unchanged(world, func(): return world.harvest(wheat), "early harvest atomic")
	unchanged(world, func(): return world.plant(Vector2i(0,0), "golden_wheat"), "untilled planting atomic")
	days(world, 3)
	check(world.instance_at(wheat)["progress"] == 300 and world.instance_at(wheat)["state"] == "growing", "wheat three ideal days")
	days(world, 1)
	check(world.instance_at(wheat)["state"] == "mature", "wheat matures day4")
	unchanged(world, func(): return world.harvest(wheat, "fell"), "wrong harvest mode atomic")
	check(world.harvest(wheat)["ok"] and world.inventory.count("grain") == 3 and world.inventory.count("straw") == 2, "wheat exact products")
	check(world.instance_at(wheat).is_empty() and world.grid.state_at(wheat) == Grid.State.TILLED, "wheat frees tilled bed")
	unchanged(world, func(): return world.harvest(wheat), "harvest only once")
	check(world.plant(wheat, "golden_wheat")["ok"] and world.inventory.count("golden_wheat_seed") == 6, "wheat consumes new seed")

	world = World.new()
	var tree := Vector2i(5,2)
	prepare(world, tree, "fast_fir")
	var before := world.to_snapshot()
	check(not world.plant(Vector2i(6,2), "fast_fir")["ok"] and world.to_snapshot() == before, "partial footprint atomic")
	check(world.plant(tree, "fast_fir")["ok"], "plant fir 2x2")
	days(world, 8)
	check(world.instance_at(tree + Vector2i.ONE)["state"] == "mature" and world.environment_at(tree)["water"] == 36, "multi cell one growth, per cell drain")
	check(world.harvest(tree + Vector2i.ONE, "fell")["ok"] and world.inventory.count("raw_wood") == 4 and world.inventory.count("twig") == 4, "fir exact single batch from any occupied cell")
	check(world.crops.is_empty() and world.grid.holder_cells("v1_crop:1").is_empty(), "fir footprint released")
	check(world.plant(tree, "fast_fir")["ok"] and world.inventory.count("fast_fir_seed") == 0, "fir replants using seed")

	world = World.new()
	prepare(world, tree, "resin_tree")
	check(world.plant(tree, "resin_tree")["ok"], "plant resin tree")
	days(world, 8)
	check(world.harvest(tree)["ok"] and world.inventory.count("resin") == 4 and world.instance_at(tree)["state"] == "regrowing", "resin tap retains tree")
	unchanged(world, func(): return world.harvest(tree), "no instant repeat resin")
	unchanged(world, func(): return world.harvest(tree, "fell"), "same period not both tap and fell")
	days(world, 3)
	check(world.instance_at(tree)["state"] == "mature", "resin three day cycle")
	check(world.harvest(tree, "fell")["ok"] and world.inventory.count("raw_wood") == 4 and world.inventory.count("twig") == 3 and world.inventory.count("resin") == 4, "fell gives wood instead of resin")
	unchanged(world, func(): return world.harvest(tree), "no tap after fell")

	world = World.new()
	var bed := Vector2i(2,10)
	prepare(world, bed, "wood_decay_mushroom")
	unchanged(world, func(): return world.plant(bed, "wood_decay_mushroom"), "missing substrate atomic")
	# Test fixture inputs stand in for V1.c production/V1.e market, not free game rewards.
	world.inventory.add("wood_chip", 6)
	world.inventory.add("clean_water", 4)
	check(world.plant(bed, "wood_decay_mushroom")["ok"] and world.inventory.count("wood_decay_spawn") == 3 and world.inventory.count("wood_chip") == 3 and world.inventory.count("clean_water") == 2, "fungus full recurring inputs")
	check(world.environment_at(bed)["water"] == 100 and world.clock.ap == 22, "culture water moistens without extra action")
	days(world, 4)
	check(world.harvest(bed)["ok"] and world.inventory.count("mushroom") == 3 and world.inventory.count("humus") == 1, "fungus two products")
	check(world.plant(bed, "wood_decay_mushroom")["ok"] and world.inventory.count("wood_chip") == 0 and world.inventory.count("clean_water") == 0, "substrate consumed every cycle")
	days(world, 4)
	check(world.harvest(bed)["ok"] and world.inventory.count("mushroom") == 6, "second fungus cycle")
	unchanged(world, func(): return world.plant(bed, "wood_decay_mushroom"), "old bed not permanent substrate")

func _environment() -> void:
	var world := World.new()
	check(world.environment_at(Vector2i(2,2))["light"] == 80 and world.environment_at(Vector2i(2,10))["light"] == 30, "fixed sun/shade")
	var cell := Vector2i(2,2)
	prepare(world, cell, "golden_wheat")
	check(world.plant(cell, "golden_wheat")["ok"], "environment wheat planted")
	var snapshot := world.to_snapshot()
	snapshot["world"]["environment"][cell.y * 20 + cell.x] = [0,0]
	check(world.apply_snapshot(snapshot)["ok"], "zero water fertility valid")
	days(world, 1)
	check(world.instance_at(cell)["progress"] == 37 and world.instance_at(cell)["state"] == "growing", "low water/fertility slows, never dies")
	var before := world.to_snapshot()
	check(not world.irrigate(cell)["ok"] and not world.fertilize(cell)["ok"] and world.to_snapshot() == before, "missing improvement inputs atomic")
	world.inventory.add("clean_water", 4)
	world.inventory.add("humus", 4)
	check(world.irrigate(cell)["ok"] and world.fertilize(cell)["ok"] and world.environment_at(cell)["water"] == 30 and world.environment_at(cell)["fertility"] == 30, "real water/humus consumption")
	check(world.inventory.count("clean_water") == 3 and world.inventory.count("humus") == 3 and world.clock.ap == 22, "improvement inventory/AP")
	days(world, 1)
	check(world.instance_at(cell)["progress"] == 137, "improved growth resumes ideal rate")
	for _index in range(3):
		world.irrigate(cell)
		world.fertilize(cell)
	check(world.environment_at(cell)["water"] == 100 and world.environment_at(cell)["fertility"] == 100, "environment clamped")
	unchanged(world, func(): return world.irrigate(cell), "full water no charge")
	unchanged(world, func(): return world.fertilize(cell), "full fertility no charge")
	unchanged(world, func(): return world.irrigate(Vector2i(-1,0)), "outside improvement atomic")
	unchanged(world, func(): return world.irrigate(Vector2i(0,0)), "wild improvement atomic")

	world = World.new()
	cell = Vector2i(2,10)
	prepare(world, cell, "golden_wheat")
	world.plant(cell, "golden_wheat")
	days(world, 1)
	check(world.instance_at(cell)["progress"] == 50, "wrong light slows wheat")
	days(world, 50)
	check(world.instance_at(cell)["state"] == "mature", "poor conditions eventually mature")

	world = World.new()
	cell = Vector2i(5,2)
	prepare(world, cell, "fast_fir")
	world.plant(cell, "fast_fir")
	snapshot = world.to_snapshot()
	# Average water=30 across four cells; growth runs once, not four times.
	for offset in [Vector2i.ZERO, Vector2i(1,0), Vector2i(0,1)]:
		snapshot["world"]["environment"][(cell.y+offset.y)*20 + cell.x+offset.x][0] = 20
	snapshot["world"]["environment"][(cell.y+1)*20 + cell.x+1][0] = 60
	world.apply_snapshot(snapshot)
	days(world, 1)
	check(world.instance_at(cell)["progress"] == 100 and world.environment_at(cell)["water"] == 17, "multi cell average rate and single progress")

func _sources() -> void:
	var world := World.new()
	for source in ["stone_source", "ore_source", "spring_source"]:
		for _index in range(6):
			check(world.collect(source)["ok"], "collect " + source)
		check(world.source_remaining(source) == 0, "finite daily capacity " + source)
		unchanged(world, func(): return world.collect(source), "exhausted source atomic " + source)
	check(world.inventory.count("raw_stone") == 18 and world.inventory.count("iron_ore") == 12 and world.inventory.count("clean_water") == 30 and world.clock.ap == 6, "capacity units and action costs")
	unchanged(world, func(): return world.collect("missing"), "unknown source atomic")
	unchanged(world, func(): return world.till(Vector2i(15,8)), "source cannot till")
	check(world.source_at(Vector2i(16,8)) == "ore_source", "source fixed location")
	var restored := World.new()
	check(restored.apply_snapshot(JSON.parse_string(JSON.stringify(world.to_snapshot())))["ok"] and restored.source_remaining("spring_source") == 0, "reload does not refresh quota")
	world.end_day()
	check(world.source_remaining("spring_source") == 30 and world.source_remaining("stone_source") == 18 and world.clock.ap == 24, "day resets all quotas/AP once")
	check(world.collect("spring_source")["ok"] and world.inventory.count("clean_water") == 35, "next day collect")

func _validation() -> void:
	var world := World.new()
	var cell := Vector2i(5,2)
	prepare(world, cell, "fast_fir")
	world.plant(cell, "fast_fir")
	days(world, 2)
	var snapshot := world.to_snapshot()
	var restored := World.new()
	check(restored.apply_snapshot(JSON.parse_string(JSON.stringify(snapshot)))["ok"] and restored.to_snapshot() == snapshot, "full detached round trip")
	check(restored.grid.state_at(cell+Vector2i.ONE) == Grid.State.PLANTED, "derived occupancy restored")
	for world_mutation in [
		func(w): w["tilled"].append(w["tilled"][0]),
		func(w): w["tilled"].append([0,6]),
		func(w): w["environment"][0] = [true, 60],
		func(w): w["environment"][0] = [101, 60],
		func(w): w["environment"].pop_back(),
		func(w): w["sources"]["day"] += 1,
		func(w): w["sources"]["used"]["stone_source"] = 1,
		func(w): w["sources"]["used"]["ore_source"] = 14,
		func(w): w["crops"][0]["progress"] = 900,
		func(w): w["crops"][0]["state"] = "mature",
		func(w): w["crops"][0]["harvest_count"] = 1,
		func(w): w["crops"][0]["origin"] = [19,13],
		func(w): w["crops"].append(w["crops"][0].duplicate(true)),
		func(w): w["tilled"].pop_back(),
		func(w): w["next_uid"] = 1,
		func(w): w["map_id"] = "wrong",
		func(w): w["unknown"] = true]:
		var bad := snapshot.duplicate(true)
		world_mutation.call(bad["world"])
		check(not restored.apply_snapshot(bad)["ok"] and restored.to_snapshot() == snapshot, "invalid world rejected before mutation")
	var basis := Snapshot.fresh()
	basis["schema"] = 1
	basis.erase("world")
	basis["clock"]["total_days"] = 7
	var upgraded := Snapshot.normalize(basis)
	check(upgraded["ok"] and upgraded["snapshot"]["schema"] == 2 and upgraded["snapshot"]["world"]["sources"]["day"] == 7, "only V1.a foundation upgrades to blank world")
	var exposure := world.instance_at(cell)
	exposure["progress"] = 0
	check(world.instance_at(cell)["progress"] == 200, "query returns detached crop")

func _daily_storage() -> void:
	var directory := "user://test_v1_production_%d" % Time.get_ticks_usec()
	var store := FlakyStore.new(directory)
	var world := World.new(store)
	unchanged(world, func(): return world.till(Vector2i(2,2)), "slot selection required")
	check(world.start_new(1)["ok"], "start bound game")
	for action in ["plant", "harvest", "irrigate", "fertilize", "collect"]:
		world.start_new(1, true)
		var cell := Vector2i(2,2)
		world.till(cell)
		if action == "harvest":
			world.plant(cell, "golden_wheat")
			days(world, 4)
		world.inventory.add("clean_water", 1)
		world.inventory.add("humus", 1)
		world.clock.ap = 1
		var result: Dictionary
		match action:
			"plant": result = world.plant(cell, "golden_wheat")
			"harvest": result = world.harvest(cell)
			"irrigate": result = world.irrigate(cell)
			"fertilize": result = world.fertilize(cell)
			"collect": result = world.collect("spring_source")
		check(result["ok"] and result["saved"] and result["day_advanced"], "last AP triggers save after " + action)
		check(store.read_slot(1)["snapshot"] == world.to_snapshot(), "all settled state persisted " + action)
		check(world.clock.ap == 24 and world.source_remaining("spring_source") == 30, "next day reset persisted " + action)
		if action == "plant":
			check(world.inventory.count("golden_wheat_seed") == 7 and world.instance_at(cell)["progress"] == 100, "last AP plant progress and seed saved")
		if action == "harvest":
			check(world.crops.is_empty() and world.inventory.count("grain") == 3, "last AP harvest inventory and release saved")
		if action == "collect":
			check(world.inventory.count("clean_water") == 6, "last AP collect product retained after quota reset")
	world.start_new(2)
	var baseline := world.to_snapshot()
	world.till(Vector2i(2,2))
	world.plant(Vector2i(2,2), "golden_wheat")
	world.collect("spring_source")
	check(world.abandon_day()["ok"] and world.to_snapshot() == baseline, "abandon restores grid/crops/environment/AP/inventory/quota")
	check(world.open_game(1)["ok"] and world.inventory.count("clean_water") == 6, "world slot isolation")

	world.start_new(3)
	baseline = world.to_snapshot()
	world.clock.ap = 1
	store.fail_write = true
	var result := world.till(Vector2i(2,2))
	check(result["ok"] and not result["saved"] and not world.daily_save_error.is_empty(), "failed day save visible")
	check(store.read_slot(3)["snapshot"] == baseline, "failed day save preserves disk")
	unchanged(world, func(): return world.collect("spring_source"), "pending day save blocks next action")
	unchanged(world, func(): return world.end_day(), "pending day save blocks another day")
	var pending := world.to_snapshot()
	store.fail_write = false
	check(world.retry_day_save()["ok"] and world.to_snapshot() == pending and store.read_slot(3)["snapshot"] == pending, "retry persists exactly once without replaying day")
	check(world.till(Vector2i(3,2))["ok"], "actions resume after successful retry")
	world.clock.ap = 1
	store.fail_write = true
	world.till(Vector2i(4,2))
	check(world.abandon_day()["ok"] and world.to_snapshot() == pending and world.daily_save_error.is_empty(), "failed save can abandon to last persisted day")
	store.fail_write = false
	for slot in [1,2,3]:
		check(store.delete_slot(slot, true)["ok"], "cleanup owned production slot")
	DirAccess.remove_absolute(directory)
