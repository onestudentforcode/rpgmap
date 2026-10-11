extends SceneTree
const World := preload("res://scripts/farming/v1/v1_world.gd")
const Journal := preload("res://scripts/farming/v1/v1_journal.gd")
const Snapshot := preload("res://scripts/farming/v1/v1_snapshot.gd")
const Store := preload("res://scripts/farming/v1/v1_slot_store.gd")
var checks := 0
var failures: Array[String] = []

class FlakyStore extends "res://scripts/farming/v1/v1_slot_store.gd":
	var fail_write := false
	func _rename(from: String,to: String) -> Error:
		return ERR_CANT_CREATE if fail_write and from.ends_with(".tmp") else super._rename(from,to)

func check(condition: bool,label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func _initialize() -> void:
	_boundaries()
	_storage()
	_validation()
	_playthrough()
	for failure in failures: printerr(failure)
	print("V1 JOURNAL TEST %s: %d checks" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func _boundaries() -> void:
	var world := World.new()
	var before := world.to_snapshot()
	check(not world.plant(Vector2i(2,2),"wood_decay_mushroom")["ok"] and before == world.to_snapshot(),"failed action has no journal or guide effect")
	check(not world.workforce.set_seed(Vector2i(15,8),"golden_wheat")["ok"] and world.journal["guide"]["seen"].is_empty(),"invalid seed allocation cannot advance guide")
	world.workforce.set_seed(Vector2i(2,2),"golden_wheat")
	world.workforce.mark(Rect2i(2,2,1,1),"till")
	check(world.journal["guide"]["seen"] == ["seed","designation"] and world.inventory.count("golden_wheat_seed") == 8,"nonblocking intentions only mark successful guide events")
	world.till(Vector2i(2,2))
	world.plant(Vector2i(2,2),"golden_wheat")
	world.collect("spring_source")
	world.buy("golden_wheat_seed",2)
	world.sell("clean_water",1)
	check(Journal.totals(world.journal) == Journal.bucket(),"unfinished day excluded from settled recap")
	world.end_day()
	var first: Dictionary = world.journal["history"][0]["totals"]
	check(first["plantings"] == {"golden_wheat":1} and first["collected"] == {"clean_water":5},"manual production counts use actual units")
	check(first["purchase_spend"] == 6 and first["sales_revenue"] == 1 and world.primeval_stones == 55,"actual cash costs only, seed AP/time not double charged")
	check(world.journal["pending"] == Journal.bucket(),"daily totals settle once then clear pending")
	while world.clock.total_days < 14: world.end_day()
	world.sell("clean_water",1)
	world.end_day()
	check(world.journal["terms"][0]["sales_revenue"] == 2 and world.journal["terms"][1] == Journal.bucket(),"day15 actions belong to first term")
	world.buy("golden_wheat_seed",1)
	world.end_day()
	check(world.journal["terms"][1]["purchase_spend"] == 3 and world.journal["terms"][0]["purchase_spend"] == 6,"day16 belongs to second term")
	while world.clock.total_days < 44: world.end_day()
	world.clear_crop(Vector2i(2,2))
	world.end_day()
	check(world.journal["frozen"] and world.journal["end_cash"] == 53 and world.journal["terms"][2]["cleared"] == {"golden_wheat":1},"day45 full action is included before freeze")
	check(world.journal["history"].size() == 15 and world.journal["history"][0]["day"] == 31 and world.journal["history"].back()["day"] == 45,"last15 reports bounded and chronological")
	var frozen := world.journal.duplicate(true)
	world.collect("spring_source")
	world.sell("clean_water",1)
	world.end_day()
	check(world.journal["terms"] == frozen["terms"] and world.journal["end_cash"] == frozen["end_cash"] and world.journal["end_inventory"] == frozen["end_inventory"],"later play cannot rewrite first45 cash or inventory")
	check(world.journal["history"].back()["day"] == 46 and world.journal["history"].back()["totals"]["sales_revenue"] == 1,"daily reports continue after recap freeze")
	check(Snapshot.normalize(JSON.parse_string(JSON.stringify(world.to_snapshot())))["snapshot"] == world.to_snapshot(),"journal JSON roundtrip retains integer counters")

func _storage() -> void:
	var directory := "user://test_v1_journal_%d" % Time.get_ticks_usec()
	var store := FlakyStore.new(directory)
	var world := World.new(store)
	check(world.start_new(1)["ok"],"journal own slot created")
	world.guide_dismiss(true)
	world.workforce.set_seed(Vector2i(2,2),"golden_wheat")
	world.workforce.hire("阿禾")
	var worker: Dictionary = world.workforce.state["workers"][0]
	world.workforce.configure(1,3,false,worker["priorities"],[[2,2,2,1]])
	world.workforce.mark(Rect2i(2,2,2,1),"till")
	world.clock.spend(23)
	world.collect("spring_source")
	var saved := world.to_snapshot()
	check(store.read_slot(1)["snapshot"] == saved and saved["journal"]["guide"]["dismissed"],"lastAP saves guide and full journal")
	check(saved["journal"]["terms"][0]["labour_spend"] == 3 and saved["journal"]["terms"][0]["work_actions"] == {"till":2,"plant":1} and saved["journal"]["terms"][0]["plantings"] == {"golden_wheat":1},"worker actual actions included once, not counted twice by wrapper")
	world.guide_dismiss(false)
	world.buy("golden_wheat_seed",1)
	check(world.abandon_day()["ok"] and world.to_snapshot() == saved,"abandon rolls back guide and pending spending together")
	check(world.start_new(2)["ok"] and not world.journal["guide"]["dismissed"] and Journal.totals(world.journal) == Journal.bucket(),"new slot has independent guide and zero initial-gift revenue")
	while world.clock.total_days < 44: world.end_day()
	world.buy("golden_wheat_seed",1)
	store.fail_write = true
	check(not world.end_day()["saved"] and world.journal["frozen"],"failed45 save preserves settled freeze in memory")
	var pending := world.to_snapshot()
	check(not world.guide_dismiss(true)["ok"] and world.to_snapshot() == pending,"save failure blocks guide edits")
	store.fail_write = false
	check(world.retry_day_save()["ok"] and world.to_snapshot() == pending and store.read_slot(2)["snapshot"] == pending,"retry45 writes exactly same report and costs")
	check(world.open_game(2)["ok"] and world.to_snapshot() == pending,"reload45 cannot replay summary settlement")
	for slot in [1,2,3]:
		if store.occupied(slot): store.delete_slot(slot,true)
	DirAccess.remove_absolute(directory)

func _validation() -> void:
	var world := World.new()
	world.end_day()
	var before := world.to_snapshot()
	for mutate in [
		func(s): s.erase("journal"),
		func(s): s["journal"]["start_day"] = 2,
		func(s): s["journal"]["terms"][1]["purchase_spend"] = 1,
		func(s): s["journal"]["pending"]["plantings"]["unknown"] = 1,
		func(s): s["journal"]["terms"][0]["sales_revenue"] = true,
		func(s): s["journal"]["frozen"] = true,
		func(s): s["journal"]["end_inventory"]["grain"] = 1,
		func(s): s["journal"]["guide"]["seen"] = ["seed","seed"],
		func(s): s["journal"]["guide"]["seen"] = ["cheat"],
		func(s): s["journal"]["history"][0]["day"] = 2]:
		var bad := before.duplicate(true)
		mutate.call(bad)
		check(not world.apply_snapshot(bad)["ok"] and world.to_snapshot() == before,"reject malformed journal before world mutation")
	var legacy := before.duplicate(true)
	legacy["schema"] = 5
	legacy.erase("journal")
	var migrated := Snapshot.normalize(legacy)
	check(migrated["ok"] and migrated["snapshot"]["journal"]["start_day"] == 1 and migrated["snapshot"]["workforce"] == legacy["workforce"],"schema5 keeps old world but does not invent missing past statistics")
	check(world.apply_snapshot(migrated["snapshot"])["ok"],"migrated journal usable")
	while world.clock.total_days < 45: world.end_day()
	var late := world.to_snapshot()
	late["schema"] = 5
	late.erase("journal")
	var late_result := Snapshot.normalize(late)
	check(late_result["ok"] and late_result["snapshot"]["journal"]["start_day"] == 45 and late_result["snapshot"]["journal"]["frozen"],"post45 old archive explicitly unrecorded")
	var bad := world.to_snapshot()
	bad["journal"]["end_cash"] += 1
	check(not Snapshot.normalize(bad)["ok"],"frozen cash reconciles actual income and expenses")

func days(world: World,count: int) -> void:
	for _index in range(count): check(world.end_day()["ok"],"playthrough advances legitimate day")

func prepare(world: World,cell: Vector2i,crop_id: String) -> void:
	var shape: Array = world.crop_defs[crop_id]["footprint"]
	for y in range(int(shape[1])):
		for x in range(int(shape[0])): check(world.till(cell+Vector2i(x,y))["ok"],"prepare full crop footprint")
	check(world.plant(cell,crop_id)["ok"],"plant from actual seed stock")

func _playthrough() -> void:
	# No injected wallet/items or mature crops. Route builds all four facilities before hiring.
	var world := World.new()
	prepare(world,Vector2i(5,2),"fast_fir")
	prepare(world,Vector2i(8,2),"fast_fir")
	prepare(world,Vector2i(2,2),"golden_wheat")
	prepare(world,Vector2i(11,2),"resin_tree")
	for _index in range(6): check(world.collect("stone_source")["ok"],"collect building stone")
	for _index in range(3):
		check(world.collect("spring_source")["ok"] and world.collect("ore_source")["ok"],"collect real water and ore")
	days(world,8)
	check(world.harvest(Vector2i(5,2),"fell")["ok"] and world.harvest(Vector2i(8,2),"fell")["ok"] and world.harvest(Vector2i(2,2))["ok"] and world.harvest(Vector2i(11,2))["ok"],"real mature harvests")
	var wood := world.build_facility(Vector2i(1,0),"woodshop")
	var compost := world.build_facility(Vector2i(0,5),"compost_bin")
	var kiln := world.build_facility(Vector2i(1,3),"char_kiln")
	check(wood["ok"] and compost["ok"] and kiln["ok"],"first60 permits facilities")
	var saw := world.start_batch(wood["facility_uid"],"saw_planks")
	var soil := world.start_batch(compost["facility_uid"],"compost_straw")
	var coal := world.start_batch(kiln["facility_uid"],"char_twigs")
	days(world,1)
	check(world.claim_batch(wood["facility_uid"],saw["batch_id"])["ok"],"collect building planks")
	var smelter := world.build_facility(Vector2i(15,0),"smelter")
	var chips := world.start_batch(wood["facility_uid"],"shred_wood")
	days(world,1)
	check(smelter["ok"] and world.claim_batch(wood["facility_uid"],chips["batch_id"])["ok"] and world.claim_batch(compost["facility_uid"],soil["batch_id"])["ok"] and world.claim_batch(kiln["facility_uid"],coal["batch_id"])["ok"],"real intermediate production")
	prepare(world,Vector2i(2,10),"wood_decay_mushroom")
	var extra := world.start_batch(compost["facility_uid"],"compost_twigs")
	var iron := world.start_batch(smelter["facility_uid"],"smelt_charcoal")
	days(world,2)
	check(world.claim_batch(smelter["facility_uid"],iron["batch_id"])["ok"] and world.claim_batch(compost["facility_uid"],extra["batch_id"])["ok"],"metal and compost products")
	iron = world.start_batch(smelter["facility_uid"],"smelt_charcoal")
	days(world,2)
	check(world.claim_batch(smelter["facility_uid"],iron["batch_id"])["ok"] and world.harvest(Vector2i(2,10))["ok"],"fungus recycling returns humus")
	var supplied := {}
	var foods := {"wood":"grain","fire":"resin","earth":"humus","water":"clean_water","gold":"iron_ingot"}
	for _day in range(5):
		for entry in world.daily_orders():
			if not supplied.has(entry["path"]):
				var quote := world.order_quote(entry["id"],foods[entry["path"]])
				if world.inventory.has(foods[entry["path"]],int(quote["quantity"])):
					check(world.deliver_order(entry["id"],foods[entry["path"]])["ok"],"self-produced path supplied")
					supplied[entry["path"]] = true
		world.end_day()
	check(supplied.size() == 5,"five food paths complete before expansion")
	check(world.fertilize(Vector2i(2,2))["ok"] and world.sell("mushroom",3)["ok"] and world.buy("golden_wheat_seed",2)["ok"] and world.plant(Vector2i(2,2),"golden_wheat")["ok"],"actual compost reflow and income reinvestment")
	world.workforce.hire("阿禾")
	var prefs: Dictionary = world.workforce.state["workers"][0]["priorities"].duplicate()
	prefs["harvest"] = 5
	prefs["plant"] = 4
	world.workforce.configure(1,2,false,prefs,[[2,2,1,1]])
	world.workforce.set_seed(Vector2i(2,2),"golden_wheat")
	world.workforce.mark(Rect2i(2,2,1,1),"harvest")
	world.workforce.assign_source("spring_source",1)
	var ledger := []
	while world.clock.total_days < 45:
		if world.inventory.count("golden_wheat_seed") < 2: check(world.buy("golden_wheat_seed",2)["ok"],"earned income pays recurring seed cost")
		for entry in world.daily_orders():
			var food: String = foods[entry["path"]]
			var quote := world.order_quote(entry["id"],food)
			if quote["ok"] and world.inventory.has(food,int(quote["quantity"])): world.deliver_order(entry["id"],food)
		if world.inventory.count("clean_water") > 40: world.sell("clean_water",10)
		if world.inventory.count("grain") > 6: world.sell("grain",3)
		world.end_day()
		check(world.daily_save_error.is_empty() and Snapshot.normalize(world.to_snapshot())["ok"],"45day route keeps valid complete snapshot")
		ledger.append({"day":world.clock.total_days,"cash":world.primeval_stones,"rank":world.unlocked_rank(),"wages":world.workforce.state["spent"]})
	var total := Journal.totals(world.journal)
	check(world.journal["frozen"] and world.journal["end_cash"] == world.primeval_stones and world.primeval_stones == 60+Journal.income(total)-Journal.expense(total),"45day route reconciles all actual cash")
	check(total["plantings"].size() == 4 and total["deliveries"].size() == 5 and total["buildings"].size() == 4 and total["processed"].size() >= 5,"recap reflects all plants paths and facilities")
	check(total["labour_spend"] > 0 and total["purchase_spend"] > 0 and total["construction_spend"] == 46 and world.primeval_stones > 0,"route supports purchases labour and construction with positive endcash")
	check(world.journal["guide"]["seen"].size() == Journal.GUIDE.size(),"successful free play completes all guide steps without prescribed sequence")
	var result := {"ledger":ledger,"journal":world.journal,"end_cash":world.primeval_stones,"rank":world.unlocked_rank(),"snapshot":world.to_snapshot()}
	DirAccess.make_dir_recursive_absolute("res://.art-work")
	var file := FileAccess.open("res://.art-work/v1-f-45days.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result,"\t"))
