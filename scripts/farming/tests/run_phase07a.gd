extends SceneTree
const Scene := preload("res://scenes/farming/farm_v2.tscn")
const World := preload("res://scripts/farming/v2/v2_world.gd")
const Snapshot := preload("res://scripts/farming/v2/v2_snapshot.gd")
const Store := preload("res://scripts/farming/v2/v2_slot_store.gd")
const V1Snapshot := preload("res://scripts/farming/v1/v1_snapshot.gd")
var ui
var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func click(cell: Vector2i, release = null) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = ui.map_port.get_canvas_transform()*(Vector2(cell)*64+Vector2(32,32))
	event.pressed = true
	ui.board.gui_input.emit(event)
	event.position = ui.map_port.get_canvas_transform()*(Vector2(cell if release == null else release)*64+Vector2(32,32))
	event.pressed = false
	ui.board.gui_input.emit(event)

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var world := World.new()
	check(world.grid.width == 20 and world.grid.height == 22 and world._items.size() == 25,"V2 map and resource catalogue")
	check(world.crop_defs.size() == 5 and world.facility_defs.size() == 7 and world.recipe_defs.size() == 13,"V2 content counts")
	check(Snapshot.normalize(world.to_snapshot())["ok"],"V2 fresh schema7 round trip")
	check(not Snapshot.normalize(V1Snapshot.fresh())["ok"] and not V1Snapshot.normalize(Snapshot.fresh())["ok"],"V1/V2 reject cross-version snapshots")
	var bad := Snapshot.fresh(); bad["schema"] = 6
	check(not Snapshot.normalize(bad)["ok"],"V2 has no schema6 migration")
	bad = Snapshot.fresh(); bad["world"]["environment"].pop_back()
	check(not Snapshot.normalize(bad)["ok"],"20x22 environment is required")
	var initial := world.to_snapshot()
	check(not world.till(Vector2i(0,14))["ok"] and world.to_snapshot() == initial,"water cannot be tilled, failure is free")
	world.inventory.add("raw_wood",10); world.inventory.add("raw_stone",20)
	initial = world.to_snapshot()
	for entry in [[Vector2i(0,0),"fish_pond"],[Vector2i(0,13),"fish_pond"],[Vector2i(19,21),"fish_pond"],[Vector2i(0,14),"pen"],[Vector2i(0,14),"algae_tank"]]:
		check(not world.build_facility(entry[0],entry[1])["ok"] and world.to_snapshot() == initial,"invalid footprint is atomic: "+str(entry))
	var built := world.build_facility(Vector2i(0,14),"fish_pond")
	check(built["ok"] and world.grid.state_at(Vector2i(1,15)) == world.Grid.State.OCCUPIED,"pond occupies all four water cells")
	var snapshot := world.to_snapshot()
	var restored := World.new()
	check(restored.apply_snapshot(snapshot)["ok"] and restored.to_snapshot() == snapshot,"water facility survives detached validation and restore")
	check(restored.demolish_facility(built["facility_uid"])["ok"] and restored.grid.state_at(Vector2i(0,14)) == world.Grid.State.UNAVAILABLE,"demolition restores unavailable water")
	bad = snapshot.duplicate(true); bad["world"]["facilities"][0]["origin"] = [0,13]
	check(not Snapshot.normalize(bad)["ok"],"damaged pond snapshot rejects mixed terrain")
	ui = Scene.instantiate()
	var directory := "user://phase07a_%d" % Time.get_ticks_usec()
	ui.store = Store.new(directory)
	root.add_child(ui)
	await process_frame
	ui._new(1,false)
	check(ui.manual_mode and ui.mode_button.text == "手动" and not ui.priority_controls.visible,"V2 defaults to manual even collapsed")
	var preferences: Dictionary = ui.settings.data.duplicate(true)
	preferences["map_zoom"] = 0.18
	check(ui.settings.valid(preferences,ui.settings.minimum_zoom) and not ui.settings.valid(preferences),"V2 accepts lower zoom without changing V1 preference validation")
	check(ui.terrain.used_count("water") == 160,"water placeholder renders full reservoir")
	ui._fit_map()
	await process_frame
	await process_frame
	var land_top: Vector2 = ui.map_port.get_canvas_transform()*Vector2.ZERO
	var water_bottom: Vector2 = ui.map_port.get_canvas_transform()*Vector2(1280,1408)
	check(land_top.y >= 0 and water_bottom.y <= ui.map_port.size.y-ui._camera_bottom_margin()+1,"all-map camera survives frame clamps and reserves toolbar space: %s %s viewport%s zoom%s" % [land_top,water_bottom,ui.map_port.size,ui.camera.zoom])
	world = ui.world
	ui._select_tool("till")
	initial = world.to_snapshot()
	for _repeat in range(3):
		ui._hover = Vector2i(2,2); ui._update_hover()
		check(world.to_snapshot() == initial,"hover quote is read-only")
	click(Vector2i(2,2))
	check(world.clock.ap == 23 and world.grid.state_at(Vector2i(2,2)) == world.Grid.State.TILLED and world.workforce.state["marks"].is_empty(),"actual manual board click immediately spends AP without task")
	initial = world.to_snapshot(); click(Vector2i(2,2)); click(Vector2i(0,14)); click(Vector2i(-1,0))
	check(world.to_snapshot() == initial,"repeated/water/outside click has zero mutation")
	click(Vector2i(15,8))
	check(world.to_snapshot() == initial,"resource point cannot be tilled through manual toolbar")
	click(Vector2i(3,2),Vector2i(4,2))
	check(world.to_snapshot() == initial,"manual dragging cannot batch or clamp to edge")
	world.workforce.set_seed(Vector2i(2,2),"golden_wheat")
	ui._select_tool("plant"); click(Vector2i(2,2))
	check(world.clock.ap == 22 and world.inventory.count("golden_wheat_seed") == 7,"manual planting uses persistent seed choice")
	world.workforce.set_seed(Vector2i(3,3),"pasture_grass")
	initial = world.to_snapshot()
	check(not world.action_quote(Vector2i(3,3),"plant")["ok"] and not world.action_quote(Vector2i(2,2),"irrigate")["ok"] and world.to_snapshot() == initial,"missing seed/irrigation quotes do not mutate state")
	ui._select_tool("clear"); click(Vector2i(2,2))
	check(is_instance_valid(ui.confirmation) and not world.instance_at(Vector2i(2,2)).is_empty(),"clear waits for confirmation")
	ui.confirmation.canceled.emit(); await process_frame
	check(world.clock.ap == 22,"cancel clear costs nothing")
	ui._set_manual(false); ui._select_tool("till")
	click(Vector2i(3,2),Vector2i(4,2))
	check(world.workforce.state["marks"].size() == 2 and world.clock.ap == 22,"delegated rectangle submits free tasks")
	var tasks: Dictionary = world.workforce.state.duplicate(true)
	ui._drag = true; ui._set_manual(true)
	check(not ui._drag and world.workforce.state == tasks,"mode switch cancels drag and preserves submitted tasks and seed plans")
	ui._set_manual(false); ui._select_tool("till")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = ui.map_port.get_canvas_transform()*(Vector2(8,2)*64+Vector2(32,32))
	press.pressed = true; ui.board.gui_input.emit(press)
	initial = world.to_snapshot()
	ui._set_manual(true)
	press.pressed = false; ui.board.gui_input.emit(press)
	check(world.to_snapshot() == initial,"mouseup after mode change cannot submit or execute old drag")
	ui._set_manual(false); ui._select_tool("cancel"); ui._set_manual(true)
	check(ui.tool == "inspect" and not ui.tool_buttons["cancel"].visible,"delegated-only tool falls back to inspect")
	world.workforce.hire("验收雇工")
	var worker: Dictionary = world.workforce.state["workers"][0]
	world.workforce.configure(1,12,false,worker["priorities"],[[3,2,2,1]])
	world.end_day()
	check(world.grid.state_at(Vector2i(3,2)) == world.Grid.State.TILLED and world.primeval_stones == 58,"manual mode does not stop workers or wages")
	ui._close_page()
	ui._select_tool("till"); world.clock.ap = 1
	click(Vector2i(5,2))
	check(world.clock.ap == 24 and world.clock.total_days == 2 and ui.store.read_slot(1)["snapshot"] == world.to_snapshot(),"last manual AP settles and autosaves correct V2 slot")
	initial = world.to_snapshot(); ui.shade.visible = true; click(Vector2i(6,2)); ui.shade.visible = false
	check(world.to_snapshot() == initial,"modal blocks map input")
	world.daily_save_error = "test failure"; click(Vector2i(6,2))
	check(world.to_snapshot() == initial,"save failure blocks manual actions")
	world.daily_save_error = ""
	check(not world.to_snapshot().has("manual_mode"),"execution mode stays outside save schema")
	var v1 := preload("res://scripts/farming/v1/v1_world.gd").new()
	check(v1._items.size() == 18 and v1.grid.height == 14 and v1.to_snapshot()["schema"] == 6,"V1 and V2 data providers coexist without global state")
	for slot in [1,2,3]:
		if ui.store.occupied(slot): ui.store.delete_slot(slot,true)
	DirAccess.remove_absolute(directory)
	ui.queue_free(); await process_frame
	for label in failures: printerr(label)
	print("PHASE07A TEST %s: %d checks" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
