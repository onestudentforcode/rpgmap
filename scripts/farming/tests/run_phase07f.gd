extends SceneTree
## Isolated boundary fixtures. Unlike the two45 playtest these may grant inputs
## or construct damaged snapshots; never touch player saves.
const World := preload("res://scripts/farming/v2/v2_world.gd")
const Store := preload("res://scripts/farming/v2/v2_slot_store.gd")
const Snapshot := preload("res://scripts/farming/v2/v2_snapshot.gd")
const Data := preload("res://scripts/farming/v2/v2_data.gd")
const Scene := preload("res://scenes/farming/farm_v2.tscn")
var checks := 0
var failures: Array[String] = []
var stores := []

class FailingStore:
	extends "res://scripts/farming/v2/v2_slot_store.gd"
	var fail_write := false
	func commit(snapshot: Dictionary) -> Dictionary:
		return {"ok":false,"reason":"fixture I/O failure"} if fail_write else super.commit(snapshot)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func same(a, b) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func fresh(failing: bool = false) -> World:
	var path := "user://p7f_boundary_%d" % Time.get_ticks_usec()
	var store = FailingStore.new(path) if failing else Store.new(path)
	stores.append(store)
	var world := World.new(store)
	check(world.start_new(1)["ok"],"isolated fresh slot")
	return world

func pen(world: World) -> void:
	world.grant_scaffold({"raw_wood":4,"raw_stone":8})
	check(world.build_facility(Vector2i(7,1),"pen")["ok"],"fixture pen built")

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	_last_ap()
	_exclusive_and_shared()
	_water_and_pause()
	_many_facts()
	_bad_snapshots()
	_save_failure_and_slots()
	_supply_contracts()
	await _recap_ui()
	for store in stores:
		for slot in [1,2,3]:
			if store.occupied(slot): store.delete_slot(slot,true)
		DirAccess.remove_absolute(store.slot_path(1).get_base_dir())
	for failure in failures: printerr(failure)
	print("PHASE07F TEST %s: %d checks" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func _last_ap() -> void:
	var w := fresh()
	w.grant_scaffold({"raw_wood":4,"raw_stone":8})
	w.clock.ap = 1
	var result := w.build_facility(Vector2i(7,1),"pen")
	check(result["saved"] and w.open_game(1)["ok"] and w.husbandry.state["habitats"].size() == 1,"lastAP construction saves its default habitat")
	w.workforce.hire("caretaker")
	w.husbandry.assign_caretaker(1,1)
	w.clock.ap = 1
	result = w.demolish_facility(1)
	check(result["saved"] and w.daily_save_error.is_empty(),"lastAP demolition saves without orphan references")
	check(w.open_game(1)["ok"] and w.husbandry.state["habitats"].is_empty() and not w.workforce._worker(1).has("caretaker_facility"),"demolition clears bindings in the saved snapshot")

func _exclusive_and_shared() -> void:
	var w := fresh()
	pen(w)
	w.grant_scaffold({"fodder_grass":1,"clean_water":1})
	w.husbandry.purchase(1,1)
	w.workforce.hire("first caretaker")
	w.workforce.hire("second farmer")
	w.husbandry.assign_caretaker(1,1)
	var before := w.to_snapshot()
	check(not w.workforce.assign_source("spring_source",1)["ok"] and w.to_snapshot() == before,"caretaker cannot be assigned a source; failure is atomic")
	var worker: Dictionary = w.workforce._worker(1)
	check(not w.workforce.configure(1,12,false,worker["priorities"],[[3,2,2,1]])["ok"] and w.to_snapshot() == before,"caretaker cannot acquire a farm area")
	worker = w.workforce._worker(2)
	w.workforce.configure(2,12,false,worker["priorities"],[[3,2,2,1]])
	w.workforce.mark(Rect2i(3,2,2,1),"till")
	# Cash is a fixture for the shared-resource boundary, not a playthrough.
	w.primeval_stones = 2
	w.end_day()
	var rows: Array = w.workforce.state["report"]["workers"]
	check(rows[0]["success"] == 1 and rows[1]["success"] == 1 and w.primeval_stones == 0,"one shared UID round gives one job to each employee")
	check(w.husbandry.habitat_of(1)["individuals"][0]["growth"] == 100,"caretaker feeding precedes growth in its service day")

func _water_and_pause() -> void:
	var w := fresh()
	w.grant_scaffold({"raw_wood":2,"raw_stone":4,"algae_feed":1})
	w.build_facility(Vector2i(0,14),"fish_pond")
	w.husbandry.purchase(1,1)
	w.husbandry.habitat_of(1)["water"] = 55
	w.workforce.hire("fish keeper")
	w.husbandry.assign_caretaker(1,1)
	w.end_day()
	check(w.husbandry.habitat_of(1)["individuals"][0]["growth"] == 100,"failed buffer repair does not block valid feeding")
	check(w.workforce.state["report"]["workers"][0]["fee"] == 1 and w.husbandry.habitat_of(1)["water"] == 50,"only feeding is charged; water decay still happens")
	w.end_day()
	var paused := false
	for entry in w.reports.day_entries(1):
		if entry["category"] == "pause" and String(entry["note"]).contains("未服务"): paused = true
	check(paused and w.workforce.state["report"]["workers"][0]["reason"].contains("缺少"),"missing feed appears in historic facts and worker reason")

func _many_facts() -> void:
	var w := fresh()
	w.grant_scaffold({"raw_wood":1000,"raw_stone":1000,"iron_ore":1000,"fodder_grass":100,"clean_water":100})
	w.sell("iron_ore",1000)
	var built := 0
	for y in range(0,14,2):
		for x in range(0,20,2):
			if built >= 22: break
			if not w.can_build_facility(Vector2i(x,y),"pen")["ok"]: continue
			var result := w.build_facility(Vector2i(x,y),"pen")
			var uid := int(result["facility_uid"])
			w.husbandry.purchase(uid,1)
			w.workforce.hire("keeper%d" % uid)
			w.husbandry.assign_caretaker(uid,uid)
			built += 1
		if built >= 22: break
	check(built == 22 and w.end_day()["saved"],"66 legitimate husbandry facts can be saved")
	check(w.reports.day_entries(0).size() == 66 and w.open_game(1)["ok"],"large daily fact set survives reload")

func _bad_snapshots() -> void:
	var w := fresh()
	pen(w)
	w.husbandry.purchase(1,1)
	var good := w.to_snapshot()
	var cases := []
	var s := good.duplicate(true); s.erase("world"); cases.append(s)
	s = good.duplicate(true); s["world"]["husbandry"]["habitats"].append(s["world"]["husbandry"]["habitats"][0].duplicate(true)); cases.append(s)
	s = good.duplicate(true); s["world"]["husbandry"]["habitats"] = []; cases.append(s)
	s = good.duplicate(true); s["world"]["husbandry"]["habitats"][0]["individuals"][0]["cycle"] = 7; cases.append(s)
	s = good.duplicate(true); s["world"]["husbandry"]["habitats"][0]["individuals"][0]["base_service"]["inputs"] = 7; cases.append(s)
	s = good.duplicate(true); s["preferences"]["watched"] = ["grain","grain"]; cases.append(s)
	s = good.duplicate(true); s["schema"] = 7; cases.append(s)
	for index in range(cases.size()):
		check(not w.apply_snapshot(cases[index])["ok"] and w.to_snapshot() == good,"damaged snapshot refuses without live edits #%d" % index)

func _save_failure_and_slots() -> void:
	var w := fresh(true)
	pen(w)
	w.grant_scaffold({"fodder_grass":2,"clean_water":2})
	w.husbandry.purchase(1,1)
	w.workforce.hire("keeper")
	w.husbandry.assign_caretaker(1,1)
	w.toggle_watch("fodder_grass")
	w._store.fail_write = true
	check(not w.end_day()["saved"] and not w.daily_save_error.is_empty(),"failed daily save blocks gameplay")
	var settled := w.to_snapshot()
	check(not w.husbandry.maintain(1)["ok"] and not w.end_day()["ok"] and w.to_snapshot() == settled,"blocked actions cannot replay settlement")
	w._store.fail_write = false
	check(w.retry_day_save()["ok"] and w.to_snapshot() == settled,"retry writes the same animals, fees, facts and watch preferences")
	check(w.open_game(1)["ok"] and same(w.to_snapshot(),settled),"retried save restores all sections")
	w.toggle_watch("clean_water")
	check(w.abandon_day()["ok"] and w.preferences["watched"] == ["fodder_grass"],"abandon rolls back same-day watch changes")
	check(w.start_new(2)["ok"] and w.preferences["watched"].is_empty(),"slot2 has its own empty watch list")
	w.toggle_watch("grain"); w.end_day()
	check(w.open_game(1)["ok"] and w.preferences["watched"] == ["fodder_grass"],"slot1 watch list does not leak from slot2")
	check(w.start_new(3)["ok"] and w.preferences["watched"].is_empty(),"third slot remains independently usable")

func _supply_contracts() -> void:
	for rank in [1,3,5]:
		for pair in [["gold","steel_wool"],["wood","fish_meat"]]:
			var quote: Dictionary = Data.supply_quote(pair[0],rank,pair[1])
			var item: Dictionary = Data.resources(Data.load_data())[pair[1]]
			var quantity := ceili(float(12*rank)/int(item["supply_value"]))
			check(quote["ok"] and quote["quantity"] == quantity,"rank%d %s uses static feed value" % [rank,pair[1]])
			check(int(quote["premium"]) == floori(float(quote["base"])/10),"10percent premium is rounded only on necessary quantity")
	var data := Data.load_data()
	for item in data["resources"]:
		if int(item["buy_price"]) > 0 and bool(item["supply_allowed"]):
			check(int(item["buy_price"])*100 > int(item["sell_price"])*110,"purchasable feed cannot earn an order arbitrage")
	var w := fresh()
	w.grant_scaffold({"clean_water":40})
	var delivered := false
	for order in w.daily_orders():
		if order["path"] == "water":
			check(w.deliver_order(order["id"],"clean_water")["ok"],"real current order settles")
			var before := w.to_snapshot()
			check(not w.deliver_order(order["id"],"clean_water")["ok"] and w.to_snapshot() == before,"a settled order cannot pay twice")
			delivered = true
	check(delivered,"water contract fixture found a normally generated order")

func _recap_ui() -> void:
	var ui := Scene.instantiate()
	ui.store = Store.new("user://p7f_ui_%d" % Time.get_ticks_usec())
	stores.append(ui.store)
	root.add_child(ui)
	await process_frame
	ui._new(1,false)
	ui.world.toggle_watch("grain")
	for day in range(45): ui.world.end_day()
	await process_frame
	check(ui._context == "recap" and ui.world.reports.recap_active(),"day45 automatically opens the actual recap UI")
	for index in [-1,0,1,2]:
		ui._show_recap(index)
		check(ui.sidebar.get_child_count() > 0,"recap tab %d renders" % index)
	var frozen: Dictionary = ui.world.reports.state["recap"].duplicate(true)
	var bad: Dictionary = ui.world.to_snapshot()
	bad["reports"]["recap"]["cash"] += 1
	check(not Snapshot.normalize(bad)["ok"],"contradictory frozen cash is rejected")
	bad = ui.world.to_snapshot(); bad["reports"]["recap"]["inventory"]["grain"] = 1
	check(not Snapshot.normalize(bad)["ok"],"contradictory frozen inventory is rejected")
	ui.world.end_day()
	check(ui.world.reports.state["recap"] == frozen and ui.world.reports.state["terms"] == frozen["terms"],"day46 continues without changing first45 statistics")
	ui.queue_free()
	await process_frame
