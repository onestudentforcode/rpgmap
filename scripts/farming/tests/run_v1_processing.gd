extends SceneTree
const World := preload("res://scripts/farming/v1/v1_world.gd")
const Snapshot := preload("res://scripts/farming/v1/v1_snapshot.gd")
const Data := preload("res://scripts/farming/v1/v1_data.gd")
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

func days(world: World, count: int) -> void:
	for _day in range(count):
		world.end_day()

func fixture_materials(world: World) -> void:
	# Isolated negative/recipe fixtures only. _closed_loop uses no injected resources.
	for ident in ["raw_wood", "raw_stone", "wood_plank", "twig", "straw", "wood_chip", "iron_ore", "charcoal", "resin"]:
		world.inventory.add(ident, 30)

func _initialize() -> void:
	_construction()
	_recipes()
	_snapshot_guards()
	_storage()
	_closed_loop()
	for failure in failures:
		printerr(failure)
	print("V1 PROCESSING TEST %s: %d checks" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _construction() -> void:
	var world := World.new()
	var cell := Vector2i(2,2)
	unchanged(world, func(): return world.build_facility(cell, "woodshop"), "no free building materials")
	fixture_materials(world)
	unchanged(world, func(): return world.build_facility(cell, "unknown"), "unknown building")
	unchanged(world, func(): return world.build_facility(Vector2i(19,13), "woodshop"), "partial out of bounds atomic")
	unchanged(world, func(): return world.build_facility(Vector2i(0,5), "woodshop"), "road footprint atomic")
	unchanged(world, func(): return world.build_facility(Vector2i(15,8), "woodshop"), "no building over source")
	world.primeval_stones = 0
	unchanged(world, func(): return world.build_facility(cell, "woodshop"), "no free building currency")
	world.primeval_stones = 60
	world.till(cell)
	world.till(cell+Vector2i(1,0))
	var built := world.build_facility(cell, "woodshop")
	check(built["ok"] and world.primeval_stones == 52 and world.inventory.count("raw_wood") == 28 and world.inventory.count("raw_stone") == 28, "construction charges once")
	var uid := int(built["facility_uid"])
	check(world.clock.ap == 21 and world.facility_at(cell+Vector2i.ONE)["uid"] == uid, "one building AP and footprint query")
	unchanged(world, func(): return world.build_facility(cell+Vector2i.ONE, "compost_bin"), "facility overlap atomic")
	unchanged(world, func(): return world.till(cell), "occupied cannot till")
	unchanged(world, func(): return world.plant(cell, "golden_wheat"), "occupied cannot plant")
	var restored := World.new()
	check(restored.apply_snapshot(JSON.parse_string(JSON.stringify(world.to_snapshot())))["ok"] and restored.to_snapshot() == world.to_snapshot(), "mixed wild/tilled building roundtrip")
	var money := restored.primeval_stones
	var inventory := restored.inventory.to_save()
	check(restored.demolish_facility(uid)["ok"] and restored.primeval_stones == money and restored.inventory.to_save() == inventory, "demolition no refunds")
	check(restored.grid.state_at(cell) == Grid.State.TILLED and restored.grid.state_at(cell+Vector2i(0,1)) == Grid.State.WILD, "demolition restores each original land state")
	check(restored.facilities.is_empty() and restored.to_snapshot()["world"]["tilled"].size() == 2, "demolition releases all cells")
	unchanged(restored, func(): return restored.demolish_facility(uid), "cannot demolish twice")
	check(restored.plant(cell, "golden_wheat")["ok"], "released soil usable")
	unchanged(restored, func(): return restored.build_facility(cell, "woodshop"), "building cannot overwrite crop")
	var exposure := world.facility_at(cell)
	exposure["origin"][0] = 9
	check(world.facility_at(cell)["origin"][0] == 2, "facility query detached")

func _recipes() -> void:
	var expected := {"saw_planks": {"wood_plank": 2, "wood_chip": 1}, "shred_wood": {"wood_chip": 4}, "shred_twigs": {"wood_chip": 3},
		"char_twigs": {"charcoal": 3}, "compost_straw": {"humus": 2}, "compost_twigs": {"humus": 2}, "compost_chips": {"humus": 2},
		"smelt_charcoal": {"iron_ingot": 1}, "smelt_resin": {"iron_ingot": 1}}
	for recipe_id in expected:
		var world := World.new()
		fixture_materials(world)
		var recipe: Dictionary = world.recipe_defs[recipe_id]
		var uid := int(world.build_facility(Vector2i(2,2), recipe["facility"])["facility_uid"])
		var before := world.inventory.to_save()
		var ap := world.clock.ap
		var started := world.start_batch(uid, recipe_id)
		check(started["ok"] and world.clock.ap == ap-1, "start AP " + recipe_id)
		for item in recipe["inputs"]:
			check(world.inventory.count(item) == int(before.get(item, 0))-int(recipe["inputs"][item]), "real input/fuel " + recipe_id + " " + item)
		var charged := world.inventory.to_save()
		var batch_id := int(started["batch_id"])
		check(world.facilities[uid]["batch"]["status"] == "processing", "processing status " + recipe_id)
		unchanged(world, func(): return world.start_batch(uid, recipe_id), "one batch per facility " + recipe_id)
		unchanged(world, func(): return world.claim_batch(uid, batch_id), "no early claim " + recipe_id)
		unchanged(world, func(): return world.demolish_facility(uid), "no busy demolition " + recipe_id)
		var restored := World.new()
		check(restored.apply_snapshot(JSON.parse_string(JSON.stringify(world.to_snapshot())))["ok"] and restored.to_snapshot() == world.to_snapshot(), "in flight roundtrip " + recipe_id)
		world = restored
		if recipe["days"] == 2:
			world.end_day()
			check(world.facilities[uid]["batch"]["status"] == "processing", "not done after one day " + recipe_id)
		world.end_day()
		check(world.facilities[uid]["batch"]["status"] == "ready" and world.inventory.to_save() == charged, "ready holds output outside inventory " + recipe_id)
		days(world, 3)
		check(world.inventory.to_save() == charged and world.facilities[uid]["batch"]["batch_id"] == batch_id, "waiting never repeats output " + recipe_id)
		unchanged(world, func(): return world.start_batch(uid, recipe_id), "claim before next batch " + recipe_id)
		unchanged(world, func(): return world.demolish_facility(uid), "ready batch protected " + recipe_id)
		unchanged(world, func(): return world.claim_batch(uid, batch_id+1), "wrong batch id " + recipe_id)
		ap = world.clock.ap
		var claimed := world.claim_batch(uid, batch_id)
		check(claimed["ok"] and claimed["items"] == expected[recipe_id] and world.clock.ap == ap-1, "exact claim products/AP " + recipe_id)
		for item in expected[recipe_id]:
			check(world.inventory.count(item) == int(charged.get(item, 0))+int(expected[recipe_id][item]), "exact inventory output " + recipe_id)
		check(world.facilities[uid]["batch"].is_empty(), "idle after claim " + recipe_id)
		unchanged(world, func(): return world.claim_batch(uid, batch_id), "single claim only " + recipe_id)
		var next := world.start_batch(uid, recipe_id)
		check(next["ok"] and next["batch_id"] > batch_id, "unique next batch identity " + recipe_id)
		days(world, int(recipe["days"]))
		unchanged(world, func(): return world.claim_batch(uid, batch_id), "stale request cannot claim a new batch " + recipe_id)
	var world := World.new()
	fixture_materials(world)
	var uid := int(world.build_facility(Vector2i(2,2), "woodshop")["facility_uid"])
	unchanged(world, func(): return world.start_batch(uid, "char_twigs"), "wrong facility recipe atomic")
	unchanged(world, func(): return world.start_batch(uid, "missing"), "unknown recipe atomic")
	unchanged(world, func(): return world.start_batch(999, "shred_wood"), "unknown facility atomic")
	world.inventory.remove("raw_wood", world.inventory.count("raw_wood"))
	unchanged(world, func(): return world.start_batch(uid, "shred_wood"), "missing processing input atomic")
	world = World.new()
	fixture_materials(world)
	uid = int(world.build_facility(Vector2i(2,2), "smelter")["facility_uid"])
	for fuel in ["charcoal", "resin"]:
		world.inventory.remove(fuel, world.inventory.count(fuel))
	unchanged(world, func(): return world.start_batch(uid, "smelt_charcoal"), "missing charcoal leaves ore intact")
	unchanged(world, func(): return world.start_batch(uid, "smelt_resin"), "missing resin leaves ore intact")

func _snapshot_guards() -> void:
	var world := World.new()
	fixture_materials(world)
	world.till(Vector2i(2,2))
	world.plant(Vector2i(2,2), "golden_wheat")
	var uid := int(world.build_facility(Vector2i(4,2), "woodshop")["facility_uid"])
	world.start_batch(uid, "saw_planks")
	var baseline := world.to_snapshot()
	for mutation in [
		func(w): w["facilities"][0]["origin"] = [2,2],
		func(w): w["facilities"][0]["origin"] = [19,13],
		func(w): w["facilities"][0]["origin"] = [15,8],
		func(w): w["facilities"].append(w["facilities"][0].duplicate(true)),
		func(w): w["next_facility_uid"] = 1,
		func(w): w["next_batch_uid"] = 1,
		func(w): w["facilities"][0]["batch"]["status"] = "ready",
		func(w): w["facilities"][0]["batch"]["start_day"] = -1,
		func(w): w["facilities"][0]["batch"]["finish_day"] = 50,
		func(w): w["facilities"][0]["batch"]["recipe_id"] = "smelt_charcoal",
		func(w): w["facilities"][0]["batch"]["inputs"]["raw_wood"] = 1,
		func(w): w["facilities"][0]["batch"]["outputs"]["wood_plank"] = 100,
		func(w): w["facilities"][0]["batch"]["outputs"]["wood_chip"] = true,
		func(w): w["facilities"][0]["batch"]["outputs"]["unknown"] = 1,
		func(w): w["facilities"][0]["batch"]["extra"] = 1,
		func(w): w["facilities"][0]["batch"] = []]:
		var bad := baseline.duplicate(true)
		mutation.call(bad["world"])
		check(not world.apply_snapshot(bad)["ok"] and world.to_snapshot() == baseline, "invalid facility/batch rejected before world mutation")
	world.end_day()
	var ready := world.to_snapshot()
	ready["world"]["facilities"][0]["batch"]["status"] = "processing"
	check(not Snapshot.normalize(ready)["ok"], "completed day cannot stay in flight")
	var second := world.build_facility(Vector2i(8,2), "woodshop")
	world.start_batch(int(second["facility_uid"]), "shred_wood")
	var duplicate := world.to_snapshot()
	duplicate["world"]["facilities"][1]["batch"]["batch_id"] = duplicate["world"]["facilities"][0]["batch"]["batch_id"]
	check(not Snapshot.normalize(duplicate)["ok"], "global batch identities unique across facilities")
	duplicate = world.to_snapshot()
	duplicate["world"]["facilities"][1]["origin"] = duplicate["world"]["facilities"][0]["origin"].duplicate()
	check(not Snapshot.normalize(duplicate)["ok"], "distinct facility identities still cannot overlap")
	var prior_world := World.new()
	prior_world.till(Vector2i(2,2))
	prior_world.plant(Vector2i(2,2), "golden_wheat")
	days(prior_world, 2)
	prior_world.collect("spring_source")
	var old := prior_world.to_snapshot()
	old["schema"] = 2
	for field in ["facilities", "next_facility_uid", "next_batch_uid"]:
		old["world"].erase(field)
	var upgraded := Snapshot.normalize(old)
	check(upgraded["ok"] and upgraded["snapshot"]["schema"] == Snapshot.SCHEMA and upgraded["snapshot"]["world"]["facilities"].is_empty(), "V1.b gains empty processing fields")
	check(upgraded["snapshot"]["world"]["crops"] == old["world"]["crops"] and upgraded["snapshot"]["world"]["sources"] == old["world"]["sources"] and upgraded["snapshot"]["world"]["environment"] == old["world"]["environment"], "upgrade preserves existing crops quotas and environment")
	old["world"]["facilities"] = []
	check(not Snapshot.normalize(old)["ok"], "old schema cannot hide new state")

func _storage() -> void:
	var directory := "user://test_v1_processing_%d" % Time.get_ticks_usec()
	var store := FlakyStore.new(directory)
	var world := World.new(store)
	world.start_new(1)
	fixture_materials(world)
	world.clock.ap = 1
	var built := world.build_facility(Vector2i(2,2), "woodshop")
	var uid := int(built["facility_uid"])
	check(built["saved"] and store.read_slot(1)["snapshot"] == world.to_snapshot(), "last AP build persists fee/materials/footprint")
	world.clock.ap = 1
	var started := world.start_batch(uid, "shred_wood")
	var batch_id := int(started["batch_id"])
	check(started["saved"] and world.facilities[uid]["batch"]["status"] == "ready" and store.read_slot(1)["snapshot"] == world.to_snapshot(), "last AP start completes one day batch before save")
	var pending := world.to_snapshot()
	var count := world.inventory.count("wood_chip")
	world.claim_batch(uid, batch_id)
	check(world.inventory.count("wood_chip") == count+4, "claim increments inventory")
	check(world.abandon_day()["ok"] and world.to_snapshot() == pending, "abandon restores ready batch and pre claim inventory")
	world.clock.ap = 1
	var claimed := world.claim_batch(uid, batch_id)
	check(claimed["saved"] and store.read_slot(1)["snapshot"] == world.to_snapshot(), "last AP claim clears batch and saves products")
	world.open_game(1)
	unchanged(world, func(): return world.claim_batch(uid, batch_id), "reload never repeats a committed claim")
	world.clock.ap = 1
	check(world.demolish_facility(uid)["saved"] and store.read_slot(1)["snapshot"] == world.to_snapshot(), "last AP demolition persists release")

	world.start_new(2)
	fixture_materials(world)
	uid = int(world.build_facility(Vector2i(2,2), "woodshop")["facility_uid"])
	world.start_batch(uid, "shred_wood")
	world.collect("spring_source")
	world.till(Vector2i(8,2))
	world.plant(Vector2i(8,2), "golden_wheat")
	var result := world.end_day()
	check(result["saved"] and world.instance_at(Vector2i(8,2))["progress"] == 100 and world.source_remaining("spring_source") == 30 and world.facilities[uid]["batch"]["status"] == "ready", "same day growth/quota/processing settled together")
	check(store.read_slot(2)["snapshot"] == world.to_snapshot(), "single full daily snapshot")
	world.open_game(1)
	check(world.facilities.is_empty(), "processing state isolated by slot")

	world.start_new(3)
	fixture_materials(world)
	uid = int(world.build_facility(Vector2i(2,2), "woodshop")["facility_uid"])
	world.end_day()
	var before: Dictionary = store.read_slot(3)["snapshot"]
	world.clock.ap = 1
	store.fail_write = true
	started = world.start_batch(uid, "shred_wood")
	check(started["ok"] and not started["saved"] and store.read_slot(3)["snapshot"] == before, "processing failed save preserves previous file")
	pending = world.to_snapshot()
	unchanged(world, func(): return world.claim_batch(uid, int(started["batch_id"])), "failed daily save blocks claim")
	store.fail_write = false
	check(world.retry_day_save()["ok"] and world.to_snapshot() == pending and store.read_slot(3)["snapshot"] == pending, "retry does not consume twice or duplicate batch")
	for slot in [1,2,3]:
		check(store.delete_slot(slot, true)["ok"], "cleanup owned processing slots")
	DirAccess.remove_absolute(directory)

func plant_crop(world: World, cell: Vector2i, crop_id: String) -> void:
	var footprint: Array = world.crop_defs[crop_id]["footprint"]
	for y in range(int(footprint[1])):
		for x in range(int(footprint[0])):
			check(world.till(cell+Vector2i(x,y))["ok"], "self produced prepare " + crop_id)
	check(world.plant(cell, crop_id)["ok"], "self produced plant " + crop_id)

func _closed_loop() -> void:
	var world := World.new()
	plant_crop(world, Vector2i(5,2), "fast_fir")
	plant_crop(world, Vector2i(8,2), "fast_fir")
	plant_crop(world, Vector2i(2,2), "golden_wheat")
	for _index in range(6):
		check(world.collect("stone_source")["ok"], "self produced stone")
	for _index in range(2):
		check(world.collect("spring_source")["ok"] and world.collect("ore_source")["ok"], "self produced water/ore")
	days(world, 8)
	check(world.harvest(Vector2i(5,2), "fell")["ok"] and world.harvest(Vector2i(8,2), "fell")["ok"] and world.harvest(Vector2i(2,2))["ok"], "self produced timber and agricultural inputs")
	var wood := world.build_facility(Vector2i(1,0), "woodshop")
	var compost := world.build_facility(Vector2i(0,5), "compost_bin")
	var kiln := world.build_facility(Vector2i(1,3), "char_kiln")
	check(wood["ok"] and compost["ok"] and kiln["ok"], "three self funded facilities")
	var saw := world.start_batch(wood["facility_uid"], "saw_planks")
	var soil := world.start_batch(compost["facility_uid"], "compost_straw")
	var charcoal := world.start_batch(kiln["facility_uid"], "char_twigs")
	check(saw["ok"] and soil["ok"] and charcoal["ok"], "self produced inputs start three crafts")
	days(world, 1)
	check(world.claim_batch(wood["facility_uid"], saw["batch_id"])["ok"], "self produced planks")
	var smelter := world.build_facility(Vector2i(12,0), "smelter")
	check(smelter["ok"] and world.primeval_stones == 14, "all facilities funded from initial60, capital spend46")
	var shred := world.start_batch(wood["facility_uid"], "shred_wood")
	days(world, 1)
	check(world.claim_batch(wood["facility_uid"], shred["batch_id"])["ok"] and world.claim_batch(compost["facility_uid"], soil["batch_id"])["ok"] and world.claim_batch(kiln["facility_uid"], charcoal["batch_id"])["ok"], "self produced culture/soil/fuel")
	plant_crop(world, Vector2i(2,10), "wood_decay_mushroom")
	var iron := world.start_batch(smelter["facility_uid"], "smelt_charcoal")
	check(iron["ok"], "self produced ore and charcoal smelt")
	days(world, 2)
	check(world.claim_batch(smelter["facility_uid"], iron["batch_id"])["ok"], "self produced gold food")
	days(world, 2)
	check(world.harvest(Vector2i(2,10))["ok"], "self produced fungus with consumed chips")
	check(world.fertilize(Vector2i(2,2))["ok"] and world.environment_at(Vector2i(2,2))["fertility"] == 74, "organic material reflows into real soil fertility")
	check(world.inventory.count("raw_wood") == 0 and world.inventory.count("wood_chip") == 2 and world.inventory.count("charcoal") == 2 and world.inventory.count("iron_ore") == 1, "self produced processing consumes shared inputs and fuel")
	check(world.inventory.count("grain") == 3 and world.inventory.count("mushroom") == 3 and world.inventory.count("humus") == 2 and world.inventory.count("clean_water") == 8 and world.inventory.count("iron_ingot") == 1, "five elements all physically produced without injected items")
	check(Snapshot.normalize(world.to_snapshot())["ok"], "self produced cycle valid snapshot")
