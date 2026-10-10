extends SceneTree
const World := preload("res://scripts/farming/v1/v1_world.gd")
const Workforce := preload("res://scripts/farming/v1/v1_workforce.gd")
const Snapshot := preload("res://scripts/farming/v1/v1_snapshot.gd")
const Store := preload("res://scripts/farming/v1/v1_slot_store.gd")
const Grid := preload("res://scripts/farming/core/grid/land_grid.gd")
var checks := 0
var failures: Array[String] = []

class FlakyStore extends "res://scripts/farming/v1/v1_slot_store.gd":
	var fail_write := false
	func _rename(from: String,to: String) -> Error:
		return ERR_CANT_CREATE if fail_write and from.ends_with(".tmp") else super._rename(from,to)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func unchanged(world: World, action: Callable, label: String) -> void:
	var before := world.to_snapshot()
	check(not action.call()["ok"] and before == world.to_snapshot(),label)

func hire(world: World, budget: int = 12, areas: Array = [[0,0,20,14]]) -> int:
	var result: Dictionary = world.workforce.hire("Test farmer")
	check(result["ok"],"hire employee")
	var ident := int(result["worker_id"])
	var priorities := {}
	for kind in Workforce.KINDS: priorities[kind] = 3
	check(world.workforce.configure(ident,budget,false,priorities,areas)["ok"],"configure employee")
	return ident

func _initialize() -> void:
	_marks_and_seeds()
	_priorities()
	_limits_and_sources()
	_lifecycle()
	_storage()
	_validation()
	for failure in failures: printerr(failure)
	print("V1 WORKFORCE TEST %s: %d checks" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func _marks_and_seeds() -> void:
	var world := World.new()
	var labour := world.workforce
	check(labour.mark(Rect2i(15,8,3,1),"till")["added"] == 0,"toolbar cannot assign source collection")
	check(labour.mark(Rect2i(0,6,2,1),"till")["added"] == 0,"skip unavailable terrain")
	var result := labour.mark(Rect2i(2,2,2,2),"till")
	check(result["added"] == 4 and world.grid.state_at(Vector2i(2,2)) == Grid.State.WILD and world.clock.ap == 24,"designation marks without work or AP")
	check(labour.mark(Rect2i(2,2,2,2),"till",9)["added"] == 0 and labour.state["marks"].size() == 4,"repeat marks change urgency without duplication")
	check(labour.cancel(Rect2i(2,2,1,1))["removed"] == 1 and labour.state["marks"].size() == 3,"cancel marks by rectangle")
	unchanged(world,func(): return labour.mark(Rect2i(2,2,1,1),"source"),"source is separate assignment")
	unchanged(world,func(): return labour.mark(Rect2i(2,2,1,1),"till",10),"bad mark priority")
	check(labour.set_seed(Vector2i(5,2),"fast_fir")["ok"],"allocate multi tile seed before preparation")
	unchanged(world,func(): return labour.set_seed(Vector2i(6,2),"golden_wheat"),"seed footprint plans cannot overlap")
	unchanged(world,func(): return labour.set_seed(Vector2i(19,13),"fast_fir"),"seed footprint cannot cross map")
	unchanged(world,func(): return labour.set_seed(Vector2i(15,8),"golden_wheat"),"no seed plan on resource")
	var exposed := labour.seed_plan(Vector2i(5,2))
	exposed["crop_id"] = "unknown"
	check(labour.seed_plan(Vector2i(5,2))["crop_id"] == "fast_fir","seed plan query detached")
	check(labour.set_seed(Vector2i(5,2),"")["ok"] and labour.seed_plan(Vector2i(5,2)).is_empty(),"clear seed disables auto replant")
	check(Snapshot.normalize(world.to_snapshot())["ok"],"pending marks do not imply occupied land")

func _priorities() -> void:
	var world := World.new()
	var ident := hire(world,1)
	world.till(Vector2i(2,2))
	world.environment[2*20+2][0] = 0
	world.inventory.add("clean_water",1)
	world.workforce.mark(Rect2i(2,2,1,1),"irrigate",9)
	world.workforce.mark(Rect2i(3,2,1,1),"till",1)
	var worker: Dictionary = world.workforce.state["workers"][0]
	var priorities: Dictionary = worker["priorities"].duplicate()
	priorities["till"] = 5
	priorities["irrigate"] = 1
	world.workforce.configure(ident,1,false,priorities,[[0,0,20,14]])
	world.end_day()
	check(world.grid.state_at(Vector2i(3,2)) == Grid.State.TILLED and world.inventory.count("clean_water") == 1,"personal preference outranks task urgency")
	check(world.workforce.state["report"]["workers"][0]["fee"] == 1 and world.primeval_stones == 59,"one completed work charges one")
	world = World.new()
	hire(world,1)
	world.workforce.mark(Rect2i(2,2,1,1),"till",1)
	world.workforce.mark(Rect2i(3,2,1,1),"till",9)
	world.end_day()
	check(world.grid.state_at(Vector2i(3,2)) == Grid.State.TILLED and world.grid.state_at(Vector2i(2,2)) == Grid.State.WILD,"urgency sorts within work preference")
	world = World.new()
	ident = hire(world,12,[[2,2,1,1]])
	world.workforce.mark(Rect2i(2,2,2,1),"till")
	world.end_day()
	check(world.grid.state_at(Vector2i(2,2)) == Grid.State.TILLED and world.grid.state_at(Vector2i(3,2)) == Grid.State.WILD,"manual area limits automatic selection")
	worker = world.workforce.state["workers"][0]
	priorities = worker["priorities"].duplicate()
	priorities["till"] = 0
	world.workforce.configure(ident,12,false,priorities,[[0,0,20,14]])
	world.end_day()
	check(world.grid.state_at(Vector2i(3,2)) == Grid.State.WILD and world.workforce.state["report"]["workers"][0]["fee"] == 0,"disabled work is never chosen")

func _limits_and_sources() -> void:
	var world := World.new()
	var first := hire(world,100)
	hire(world,100)
	unchanged(world,func(): return world.workforce.hire("Third"),"two people maximum")
	world.workforce.mark(Rect2i(0,9,8,5),"till")
	world.end_day()
	var report: Dictionary = world.workforce.state["report"]
	check(report["workers"][0]["success"] == 12 and report["workers"][1]["success"] == 12 and world.primeval_stones == 36,"12 jobs each round robin shared overlapping region")
	check(world.clock.total_days == 1 and world.clock.ap == 24,"paid work never spends player AP or advances extra day")
	check(world.workforce.state["marks"].size() == 16,"completed till marks removed once")
	world = World.new()
	first = hire(world,0)
	world.workforce.mark(Rect2i(2,2,1,1),"till")
	world.end_day()
	check(world.grid.state_at(Vector2i(2,2)) == Grid.State.WILD and world.primeval_stones == 60,"zero budget no work no fee")
	world = World.new()
	first = hire(world)
	world.workforce.assign_source("spring_source",first)
	for _index in range(5): world.collect("spring_source")
	world.end_day()
	check(world.inventory.count("clean_water") == 30 and world.primeval_stones == 59 and world.workforce.state["report"]["workers"][0]["success"] == 1,"worker shares today's residual source quota")
	check(world.source_remaining("spring_source") == 30,"quota resets after paid work")
	world.end_day()
	check(world.inventory.count("clean_water") == 60 and world.primeval_stones == 53,"continuing source commission six gathers next day")
	check(world.workforce.dismiss(first)["ok"] and world.workforce.state["sources"].is_empty(),"dismiss removes source assignment free")
	world = World.new()
	first = hire(world)
	world.workforce.assign_source("ore_source",first)
	world.primeval_stones = 1
	world.end_day()
	check(world.inventory.count("iron_ore") == 2 and world.primeval_stones == 0,"wallet stops labour without borrowing")
	world.end_day()
	check(world.inventory.count("iron_ore") == 2 and world.workforce.state["report"]["workers"][0]["fee"] == 0,"no money no extra products")

func _lifecycle() -> void:
	var world := World.new()
	hire(world)
	world.workforce.mark(Rect2i(2,2,1,1),"till")
	world.workforce.set_seed(Vector2i(2,2),"golden_wheat")
	world.end_day()
	check(world.instance_at(Vector2i(2,2))["progress"] == 100 and world.inventory.count("golden_wheat_seed") == 7 and world.primeval_stones == 58,"same day till seed and then growth")
	world.workforce.mark(Rect2i(2,2,1,1),"harvest")
	for _day in range(3): world.end_day()
	check(world.instance_at(Vector2i(2,2))["state"] == "mature" and world.inventory.count("grain") == 0,"newly mature waits until next labour settlement")
	world.end_day()
	check(world.inventory.count("grain") == 3 and world.inventory.count("golden_wheat_seed") == 6 and world.instance_at(Vector2i(2,2))["progress"] == 100,"harvest stores products and replants persistent seed")
	check(world.workforce.state["report"]["workers"][0]["counts"] == {"harvest":1,"plant":1},"report counts actual operations")
	world.workforce.mark(Rect2i(2,2,1,1),"clear")
	world.workforce.set_seed(Vector2i(2,2),"")
	var stock := world.inventory.to_save()
	world.end_day()
	check(world.instance_at(Vector2i(2,2)).is_empty() and world.grid.state_at(Vector2i(2,2)) == Grid.State.TILLED and world.inventory.to_save() == stock,"clear growing crop without refunds and empty seed stays idle")
	check(world.workforce.state["marks"].is_empty(),"clear replaces harvest and is one shot")
	world = World.new()
	hire(world)
	world.workforce.mark(Rect2i(5,2,2,2),"till")
	world.workforce.set_seed(Vector2i(5,2),"resin_tree")
	world.end_day()
	world.workforce.mark(Rect2i(5,2,2,2),"harvest")
	check(world.workforce.state["marks"].size() == 1,"multi cell harvest collapses to origin")
	for _day in range(7): world.end_day()
	world.end_day()
	check(world.inventory.count("resin") == 4 and world.inventory.count("raw_wood") == 0,"harvest retains resin tree")
	world.workforce.mark(Rect2i(5,2,2,2),"fell")
	world.workforce.set_seed(Vector2i(5,2),"")
	for _day in range(3): world.end_day()
	check(world.inventory.count("raw_wood") == 4 and world.inventory.count("resin") == 4 and world.crops.is_empty(),"explicit fell waits maturity and produces timber only")
	world = World.new()
	hire(world)
	world.till(Vector2i(2,2))
	world.workforce.set_seed(Vector2i(2,2),"wood_decay_mushroom")
	world.workforce.mark(Rect2i(3,2,1,1),"till")
	world.end_day()
	check(world.crops.is_empty() and world.inventory.count("wood_decay_spawn") == 4 and world.grid.state_at(Vector2i(3,2)) == Grid.State.TILLED and world.primeval_stones == 59,"missing culture inputs skipped, other work continues")
	world = World.new()
	hire(world)
	world.till(Vector2i(2,2))
	world.environment[42] = [0,0]
	world.inventory.add("clean_water",1)
	world.inventory.add("humus",1)
	world.workforce.mark(Rect2i(2,2,1,1),"irrigate")
	world.workforce.mark(Rect2i(2,2,1,1),"fertilize")
	world.end_day()
	check(world.environment[42] == [30,30] and world.primeval_stones == 58,"threshold care consumes warehouse inputs once each")
	world.end_day()
	check(world.primeval_stones == 58,"healthy empty soil not filled to100 or charged again")

func _storage() -> void:
	var dir := "user://test_v1_workforce_%d" % Time.get_ticks_usec()
	var store := FlakyStore.new(dir)
	var world := World.new(store)
	unchanged(world,func(): return world.workforce.hire("Unbound"),"hire requires chosen slot")
	world.start_new(1)
	var before := world.to_snapshot()
	hire(world)
	world.workforce.mark(Rect2i(2,2,1,1),"till")
	world.workforce.set_seed(Vector2i(2,2),"golden_wheat")
	check(world.abandon_day()["ok"] and world.to_snapshot() == before,"abandon reverts hires marks seed choices")
	hire(world)
	world.workforce.mark(Rect2i(2,2,1,1),"till")
	world.workforce.set_seed(Vector2i(2,2),"golden_wheat")
	world.clock.ap = 1
	check(world.collect("spring_source")["saved"],"last AP pays work and saves")
	var committed := world.to_snapshot()
	check(store.read_slot(1)["snapshot"] == committed and committed["workforce"]["spent"] == 2 and committed["world"]["crops"][0]["progress"] == 100,"complete paid day one atomic snapshot")
	check(world.open_game(1)["ok"] and world.to_snapshot() == committed,"reload no labour replay")
	world.start_new(2)
	check(world.workforce.state["workers"].is_empty() and world.workforce.state["spent"] == 0,"new slot no employees or bills from other slot")
	hire(world)
	world.workforce.mark(Rect2i(3,2,1,1),"till")
	store.fail_write = true
	check(not world.end_day()["saved"],"labour day write fails")
	var pending := world.to_snapshot()
	unchanged(world,func(): return world.workforce.dismiss(1),"failed save blocks commission edits")
	store.fail_write = false
	check(world.retry_day_save()["ok"] and world.to_snapshot() == pending and store.read_slot(2)["snapshot"] == pending,"retry no extra wages or task generation")
	world.start_new(3)
	check(store.read_slot(1)["snapshot"] == committed,"three labour slots independent")
	for slot in [1,2,3]: store.delete_slot(slot,true)
	DirAccess.remove_absolute(dir)

func _validation() -> void:
	var world := World.new()
	hire(world)
	world.workforce.mark(Rect2i(2,2,1,1),"till")
	world.workforce.set_seed(Vector2i(5,2),"fast_fir")
	var before := world.to_snapshot()
	for mutate in [
		func(s): s["workforce"]["workers"][0]["budget"] = true,
		func(s): s["workforce"]["workers"][0]["priorities"]["till"] = 6,
		func(s): s["workforce"]["workers"][0]["areas"] = [[19,13,2,2]],
		func(s): s["workforce"]["workers"].append(s["workforce"]["workers"][0].duplicate(true)),
		func(s): s["workforce"]["sources"]["spring_source"] = 99,
		func(s): s["workforce"]["marks"][0]["kind"] = "build",
		func(s): s["workforce"]["marks"][0]["priority"] = 0,
		func(s): s["workforce"]["marks"].append(s["workforce"]["marks"][0].duplicate(true)),
		func(s): s["workforce"]["seed_plans"][0]["cell"] = [19,13],
		func(s): s["workforce"]["seed_plans"].append({"cell":[6,2],"crop_id":"golden_wheat"}),
		func(s): s["workforce"]["spent"] = -1,
		func(s): s["workforce"]["report"]["day"] = 1,
		func(s): s.erase("workforce")]:
		var bad := before.duplicate(true)
		mutate.call(bad)
		check(not world.apply_snapshot(bad)["ok"] and world.to_snapshot() == before,"reject malformed labour before mutation")
	world.end_day()
	var completed := world.to_snapshot()
	var bad := completed.duplicate(true)
	bad["workforce"]["report"]["workers"][0]["fee"] += 1
	check(not Snapshot.normalize(bad)["ok"],"report wages match successful count")
	check(Snapshot.normalize(JSON.parse_string(JSON.stringify(completed)))["snapshot"] == completed,"labour JSON roundtrip exact integers")
	var old := completed.duplicate(true)
	old["schema"] = 4
	old.erase("workforce")
	var migrated := Snapshot.normalize(old)
	check(migrated["ok"] and migrated["snapshot"]["orders"] == old["orders"] and migrated["snapshot"]["economy"] == old["economy"] and migrated["snapshot"]["world"] == old["world"] and migrated["snapshot"]["workforce"]["workers"].is_empty(),"schema4 preserves production order history and earnings")
	old["workforce"] = {}
	check(not Snapshot.normalize(old)["ok"],"older schema cannot hide worker data")
