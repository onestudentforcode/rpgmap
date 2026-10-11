extends SceneTree
## P7.d checks: unlimited roster, exclusive caretaker binding and day-end patrols.
const Scene := preload("res://scenes/farming/farm_v2.tscn")
const World := preload("res://scripts/farming/v2/v2_world.gd")
const Snapshot := preload("res://scripts/farming/v2/v2_snapshot.gd")
const Store := preload("res://scripts/farming/v2/v2_slot_store.gd")
const V1World := preload("res://scripts/farming/v1/v1_world.gd")
var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func has_text(node: Node, text: String) -> bool:
	if node is Label and String(node.text).contains(text): return true
	if node is Button and (String(node.text).contains(text) or String(node.tooltip_text).contains(text)): return true
	for child in node.get_children():
		if has_text(child,text): return true
	return false

func adult(habitat: Dictionary, growth_target: int) -> void:
	for individual in habitat["individuals"]:
		individual["stage"] = "adult"
		individual["growth"] = growth_target

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	_roster_checks()
	_binding_checks()
	_patrol_checks()
	_snapshot_checks()
	await _ui_checks()
	for label in failures: printerr(label)
	print("PHASE07D TEST %s: %d checks" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

## Pen and pond with fed adults and running cycles on day 0.
func _prepared() -> World:
	var world := World.new()
	world.grant_scaffold({"raw_wood":6,"raw_stone":12})
	world.build_facility(Vector2i(7,1),"pen")
	world.build_facility(Vector2i(0,14),"fish_pond")
	world.primeval_stones += 100
	world.husbandry.purchase(1,2)
	world.husbandry.purchase(2,2)
	world.grant_scaffold({"fodder_grass":12,"clean_water":12,"algae_feed":12,"iron_ore":4,"grain":4})
	adult(world.husbandry.habitat_of(1),600)
	adult(world.husbandry.habitat_of(2),400)
	world.husbandry.maintain(1)
	world.husbandry.maintain(2)
	return world

func _roster_checks() -> void:
	var world := World.new()
	for index in range(5):
		check(world.workforce.hire("雇工%d" % (index+1))["ok"],"V2 hires past the old two-person cap: #%d" % (index+1))
	check(world.workforce.state["workers"].size() == 5,"roster holds five workers")
	var v1 := V1World.new()
	check(v1.workforce.hire("甲")["ok"] and v1.workforce.hire("乙")["ok"] and not v1.workforce.hire("丙")["ok"],"V1 keeps its own two-person cap")

func _binding_checks() -> void:
	var world := _prepared()
	world.workforce.hire("羊倌")
	world.workforce.hire("鱼倌")
	var worker: Dictionary = world.workforce._worker(1)
	worker["areas"] = [[3,2,2,1]]
	world.workforce.state["sources"]["spring_source"] = 1
	world.workforce.mark(Rect2i(3,2,2,1),"till")
	world.workforce.set_seed(Vector2i(3,3),"golden_wheat")
	check(world.husbandry.assign_caretaker(1,1)["ok"] and int(world.workforce._worker(1)["caretaker_facility"]) == 1,"assignment binds one worker to the pen")
	check(worker["areas"].is_empty() and not world.workforce.state["sources"].has("spring_source"),"binding releases personal areas and source duties")
	check(world.workforce.state["marks"].size() == 2 and not world.workforce.state["seed_plans"].is_empty(),"global marks and seed plans survive the reassignment")
	check(not world.husbandry.assign_caretaker(1,99)["ok"] and not world.husbandry.assign_caretaker(9,1)["ok"],"unknown worker or facility refuse")
	world.husbandry.assign_caretaker(2,1)
	check(int(world.workforce._worker(1)["caretaker_facility"]) == 2 and world.husbandry.caretaker_of(1).is_empty(),"moving a caretaker frees the previous facility")
	world.husbandry.assign_caretaker(2,2)
	check(int(world.workforce._worker(2)["caretaker_facility"]) == 2 and world.husbandry.caretaker_of(2)["id"] == 2,"reassignment displaces the previous caretaker")
	var state_before: Dictionary = world.to_snapshot()
	world.husbandry.assign_caretaker(2,0)
	check(world.husbandry.caretaker_of(2).is_empty() and int(world.workforce._worker(2).get("caretaker_facility",0)) == 0,"clearing restores an unassigned worker")
	world.husbandry.assign_caretaker(2,2)
	world.workforce.dismiss(2)
	check(world.husbandry.caretaker_of(2).is_empty(),"dismissing a caretaker clears the binding")
	var ap_before_assign: int = world.clock.ap
	var cash_before_assign: int = world.primeval_stones
	world.husbandry.assign_caretaker(9,0)
	world.husbandry.assign_caretaker(1,0)
	check(world.clock.ap == ap_before_assign and world.primeval_stones == cash_before_assign,"assignment changes are free of AP and fees")

func _patrol_checks() -> void:
	# Scenario A: claim runs before any maintenance; an emptied pond gets no extra work.
	var world := _prepared()
	world.end_day()
	world.grant_scaffold({"fodder_grass":4,"clean_water":4,"algae_feed":4})
	world.husbandry.maintain(1)
	world.husbandry.maintain(2)
	world.end_day()
	world.workforce.hire("羊倌")
	world.workforce.hire("鱼倌")
	world.husbandry.assign_caretaker(1,1)
	world.husbandry.assign_caretaker(2,2)
	world.grant_scaffold({"fodder_grass":4,"clean_water":4,"algae_feed":4,"iron_ore":2})
	var cash := world.primeval_stones
	world.end_day()
	var rows := {}
	for row in world.workforce.state["report"]["workers"]:
		rows[String(row["name"])] = row
	check(int(rows["羊倌"]["caretaker"]["steps"]["整体维护"]) == 1 and int(rows["羊倌"]["caretaker"]["steps"]["收取"]) == 0,"pen caretaker runs one whole maintenance")
	check(int(rows["鱼倌"]["caretaker"]["steps"]["收取"]) == 1 and int(rows["鱼倌"]["caretaker"]["steps"]["水体维护"]) == 0 and int(rows["鱼倌"]["caretaker"]["steps"]["整体维护"]) == 0,"pond caretaker claims first and stops when emptied")
	check(int(rows["羊倌"]["fee"]) == 1 and int(rows["鱼倌"]["fee"]) == 1 and world.primeval_stones == cash-2,"one fee per successful step, nothing else charged")
	check(world.inventory.count("fish_meat") == 6 and world.husbandry.habitat_of(2)["individuals"].is_empty(),"patrol claims every ready carp exactly once")
	check(world.husbandry.habitat_of(1)["individuals"][0]["base_service"]["operator"] == "worker","patrol services are recorded as worker labour")
	# Scenario B: the next day the patrol shears and restarts in one settle.
	world.end_day()
	for row in world.workforce.state["report"]["workers"]:
		rows[String(row["name"])] = row
	var shear_row: Dictionary = rows["羊倌"]
	check(world.inventory.count("steel_wool") == 2 and int(shear_row["caretaker"]["steps"]["收取"]) == 1,"the patrol shears the ready sheep")
	var pen: Dictionary = world.husbandry.habitat_of(1)
	check(not pen["individuals"][0]["cycle"].is_empty() and int(shear_row["caretaker"]["steps"]["整体维护"]) == 1 and int(shear_row["caretaker"]["steps"]["收取"]) == 1,"the same patrol restarts the cycle on fresh special feed")
	# Scenario C: paused caretaker costs nothing; resuming never backfills.
	var caretaker: Dictionary = world.workforce._worker(1)
	world.workforce.configure(1,12,true,caretaker["priorities"],[])
	var paused_cash := world.primeval_stones
	world.grant_scaffold({"fodder_grass":2,"clean_water":2})
	world.end_day()
	check(world.primeval_stones == paused_cash,"paused caretaker costs nothing")
	world.workforce.configure(1,12,false,caretaker["priorities"],[])
	# Scenario D: a tight budget stops the patrol with an explicit reason.
	world.workforce.configure(1,1,false,caretaker["priorities"],[])
	world.grant_scaffold({"fodder_grass":4,"clean_water":4,"iron_ore":2})
	world.end_day()
	var budget_row: Dictionary = world.workforce.state["report"]["workers"][0]
	check(int(budget_row["fee"]) <= 1 and budget_row["caretaker"]["skipped"].has("预算或元石不足"),"a tight budget stops the patrol with an explicit reason")
	world.workforce.configure(1,12,false,caretaker["priorities"],[])
	# Scenario E: water discipline — one automatic repair per day, only when needed.
	var fish_world := _prepared()
	fish_world.workforce.hire("鱼倌")
	fish_world.husbandry.assign_caretaker(2,1)
	fish_world.husbandry.habitat_of(2)["water"] = 55
	fish_world.grant_scaffold({"fodder_grass":2,"clean_water":4,"algae_feed":4})
	fish_world.end_day()
	check(int(fish_world.husbandry.habitat_of(2)["water"]) == 90,"one repair lifts 55 to 95 then the daily decay lands on 90")
	var water_row: Dictionary = fish_world.workforce.state["report"]["workers"][0]
	check(int(water_row["caretaker"]["steps"]["水体维护"]) == 1,"water maintenance happens at most once per day")
	fish_world.husbandry.habitat_of(2)["water"] = 0
	fish_world.grant_scaffold({"clean_water":4,"algae_feed":4,"fodder_grass":2})
	fish_world.end_day()
	check(int(fish_world.husbandry.habitat_of(2)["water"]) == 35,"a 0-to-40 repair survives the next decay above the pause line")

func _snapshot_checks() -> void:
	var world := _prepared()
	world.workforce.hire("羊倌")
	world.husbandry.assign_caretaker(1,1)
	world.grant_scaffold({"fodder_grass":2,"clean_water":2})
	world.end_day()
	var good: Dictionary = world.to_snapshot()
	check(Snapshot.normalize(good)["ok"],"caretaker snapshot validates")
	var old: Dictionary = good.duplicate(true)
	old["schema"] = 9
	check(not Snapshot.normalize(old)["ok"],"schema9 rejected without migration")
	for case in [
		["duplicate facility", func(s):
			s["workforce"]["workers"].append({"id":2,"name":"乙","paused":false,"budget":12,"priorities":s["workforce"]["workers"][0]["priorities"].duplicate(),"areas":[],"caretaker_facility":1})
			s["workforce"]["next_worker_id"] = 3
			s["workforce"]["report"]["workers"] = []],
		["unknown facility", func(s): s["workforce"]["workers"][0]["caretaker_facility"] = 9],
		["caretaker keeps areas", func(s): s["workforce"]["workers"][0]["areas"] = [[0,0,1,1]]],
		["caretaker keeps source", func(s): s["workforce"]["sources"]["spring_source"] = 1],
		["report steps mismatch", func(s): s["workforce"]["report"]["workers"][0]["success"] = 3],
	]:
		var damaged: Dictionary = good.duplicate(true)
		case[1].call(damaged)
		check(not Snapshot.normalize(damaged)["ok"],"damaged caretaker snapshot rejects: "+String(case[0]))
	var restored := World.new()
	check(restored.apply_snapshot(good)["ok"] and restored.to_snapshot() == good,"caretaker state round trips")

func _ui_checks() -> void:
	var ui = Scene.instantiate()
	var directory := "user://phase07d_%d" % Time.get_ticks_usec()
	ui.store = Store.new(directory)
	root.add_child(ui)
	await process_frame
	ui._new(1,false)
	ui.world.grant_scaffold({"raw_wood":4,"raw_stone":8,"fodder_grass":4,"clean_water":4})
	ui.world.build_facility(Vector2i(7,1),"pen")
	ui.world.husbandry.purchase(1,2)
	ui.world.workforce.hire("羊倌")
	ui.selected = Vector2i(7,1)
	ui._show_cell()
	check(has_text(ui.sidebar,"负责人 · 一人一设施"),"habitat panel shows the caretaker slot")
	check(has_text(ui.sidebar,"无人负责"),"unassigned caretaker option is visible")
	ui.world.husbandry.assign_caretaker(1,1)
	ui._show_cell()
	check(has_text(ui.sidebar,"羊倌") and has_text(ui.sidebar,"最多支出"),"binding shows name, budget and estimate")
	ui._show_workers()
	check(has_text(ui.window_panel,"人数不设固定上限"),"roster announces the open cap")
	check(has_text(ui.sidebar,"专责圈舍#1，其他农务不参与"),"roster shows exclusive duty and no farm edits")
	check(not has_text(ui.sidebar,"工作偏好0～5"),"caretaker hides the farm preference matrix")
	ui.world.end_day()
	ui._show_report()
	check(has_text(ui.sidebar,"专责巡栏"),"daily report lists caretaker steps")
	ui._close_page()
	for slot in [1,2,3]:
		if ui.store.occupied(slot): ui.store.delete_slot(slot,true)
	DirAccess.remove_absolute(directory)
	ui.queue_free()
	await process_frame
