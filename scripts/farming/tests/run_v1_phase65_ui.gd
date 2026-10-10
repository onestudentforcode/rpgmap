extends SceneTree
const Scene := preload("res://scenes/farming/farm_v1.tscn")
const Settings := preload("res://scripts/farming/v1/v1_settings.gd")
var ui
var checks := 0
var failures: Array[String] = []

class FlakyStore extends "res://scripts/farming/v1/v1_slot_store.gd":
	var fail_write := false
	func _rename(from: String,to: String) -> Error:
		return ERR_CANT_CREATE if fail_write and from.ends_with(".tmp") else super._rename(from,to)

func check(value: bool, text: String) -> void:
	checks += 1
	if not value: failures.append(text)

func _initialize() -> void: _run.call_deferred()

func button(action: String):
	for node in ui.find_children("*","Button",true,false):
		if node.get_meta("action_name","") == action: return node
	return null

func escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	ui._unhandled_key_input(event)

func board_click(cell: Vector2i) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = ui.map_port.get_canvas_transform()*(Vector2(cell)*64+Vector2(32,32))
	event.pressed = true
	ui.board.gui_input.emit(event)
	event.pressed = false
	ui.board.gui_input.emit(event)

func _run() -> void:
	var directory := "user://phase65_ui_%d" % Time.get_ticks_usec()
	ui = Scene.instantiate()
	ui.store = FlakyStore.new(directory)
	ui.settings = Settings.new(directory+".cfg")
	root.add_child(ui)
	await process_frame
	ui._new(1,false)
	check(not ui.shade.visible and ui._context == "cell","new game starts on map with independent detail panel")
	var saved: Dictionary = ui.world.to_snapshot()
	ui._show_slots()
	button("新建槽1").pressed.emit()
	check(is_instance_valid(ui.confirmation) and saved == ui.world.to_snapshot(),"occupied slot overwrite requires confirmation")
	ui.confirmation.canceled.emit()
	await process_frame
	check(saved == ui.world.to_snapshot() and ui.store.read_slot(1)["snapshot"] == saved,"cancel overwrite retains both live and stored game")
	ui._close_page()
	ui._show_market()
	ui.trade_spin.value = 5
	await process_frame
	check(ui.trade_total.text.contains("15") and not ui.trade_buy.disabled,"quantity5 displays total15 before trade")
	check(saved == ui.world.to_snapshot(),"market filtering and quantity preview are read only")
	ui._trade(true)
	check(ui.world.primeval_stones == 45 and ui.world.inventory.count("golden_wheat_seed") == 13 and ui.trade_quantity == 5,"one bulk purchase deducts total once and retains quantity")
	ui.trade_spin.value = 1000000
	await process_frame
	var before: Dictionary = ui.world.to_snapshot()
	check(ui.trade_buy.disabled and ui.trade_total.text.contains("元石不足"),"insufficient cash visibly disables buy")
	ui._trade(true)
	check(before == ui.world.to_snapshot(),"bulk purchase insufficient funds changes nothing even if invoked")
	ui.market_item = "grain"
	ui.trade_quantity = 5
	ui._show_market()
	await process_frame
	check(ui.trade_sell.disabled,"stock shortage disables sell")
	ui._trade(false)
	check(before == ui.world.to_snapshot(),"stock shortage leaves wallet and inventory unchanged")
	ui._select_tool("till")
	board_click(Vector2i(3,3))
	check(before == ui.world.to_snapshot(),"modal window blocks board emission as well as pointer dispatch")
	var zoom: Vector2 = ui.camera.zoom
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	ui.board.gui_input.emit(wheel)
	check(ui.camera.zoom == zoom,"panel scroll cannot zoom world")
	escape()
	check(ui.shade.visible and ui.tool == "inspect","Esc cancels selected tool before closing window")
	escape()
	check(not ui.shade.visible,"next Esc closes top window")
	ui._select_tool("till")
	var preview: Dictionary = ui.world.workforce.preview(Rect2i(14,8,4,1),"till")
	check(preview["invalid"].size() >= 3 and before == ui.world.to_snapshot(),"designation preview rejects source cells without mutations")
	board_click(Vector2i(3,3))
	check(ui.world.workforce.state["marks"].any(func(mark): return mark["cell"] == [3,3]),"board coordinates after modal close designate intended cell")
	check(ui.tool == "till","designation tool remains selected after rectangle")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	ui.board.gui_input.emit(right)
	check(ui.tool == "inspect" and not ui._drag,"right click cancels to inspect")
	ui.world.till(Vector2i(2,2))
	ui.world.workforce.set_seed(Vector2i(2,2),"golden_wheat")
	ui.world.plant(Vector2i(2,2),"golden_wheat")
	ui._select_tool("clear")
	before = ui.world.to_snapshot()
	ui.apply_rectangle(Rect2i(1,1,3,3))
	check(is_instance_valid(ui.confirmation) and before == ui.world.to_snapshot(),"batch clear shows one confirmation before creating any marks")
	button("结束当天 · R").pressed.emit()
	check(before == ui.world.to_snapshot(),"confirmation blocks navigation and day buttons")
	ui.confirmation.canceled.emit()
	await process_frame
	check(before == ui.world.to_snapshot(),"cancel batch clear has zero changes")
	ui.apply_rectangle(Rect2i(1,1,3,3))
	ui.confirmation.confirmed.emit()
	await process_frame
	check(ui.world.workforce.state["marks"].filter(func(mark): return mark["kind"] == "clear").size() == 1,"confirmed crop rectangle deduplicates one plant target")
	ui.world.inventory.add("raw_wood",10)
	ui.world.inventory.add("raw_stone",10)
	before = ui.world.to_snapshot()
	check(ui.world.can_build_facility(Vector2i(8,3),"woodshop")["ok"],"build preview accepts clear footprint with full resources")
	check(not ui.world.can_build_facility(Vector2i(15,8),"woodshop")["ok"] and not ui.world.can_build_facility(Vector2i(19,13),"woodshop")["ok"],"build preview rejects source and out of bounds")
	check(before == ui.world.to_snapshot(),"all construction previews are read only")
	ui._show_build()
	button("放置 木工台").pressed.emit()
	check(not ui.shade.visible and ui.build_tool == "woodshop","build catalogue closes into placement mode")
	board_click(Vector2i(8,3))
	check(ui.world.facilities.size() == 1 and ui.build_tool == "woodshop","placement builds once and remains active")
	before = ui.world.to_snapshot()
	board_click(Vector2i(8,3))
	check(before == ui.world.to_snapshot(),"duplicate placement on same footprint changes nothing")
	ui._select_tool("inspect")
	var facility: Dictionary = ui.world.facility_at(Vector2i(8,3))
	ui.selected = Vector2i(8,3)
	ui._show_cell()
	check(button("启动 锯切木板") != null,"facility recipe card exposes startup")
	button("拆除（1AP，无返还）").pressed.emit()
	ui.confirmation.canceled.emit()
	await process_frame
	check(before == ui.world.to_snapshot(),"cancel demolition preserves facility and resources")
	ui.world.start_batch(facility["uid"],"saw_planks")
	ui._show_cell()
	check(button("收取（1AP）").disabled and button("拆除（1AP，无返还）") == null,"processing state disables claim and omits demolition")
	ui.world.workforce.hire("阿禾")
	ui.selected_worker = 1
	var worker: Dictionary = ui.world.workforce._worker(1)
	ui.world.workforce.configure(1,12,false,worker["priorities"],[[1,1,2,2],[4,4,2,2]])
	ui._show_workers()
	button("删除区域1").pressed.emit()
	check(worker["areas"] == [[4,4,2,2]],"deleting one area retains the other")
	button("定位区域1").pressed.emit()
	check(not ui.shade.visible and ui.camera.position == Vector2(320,320),"area locate closes management and focuses correct center")
	ui._show_market()
	root.size = Vector2i(960,540)
	ui._ui_scale = 1.5
	ui._layout()
	await process_frame
	await process_frame
	check(ui.sidebar.find_children("*","GridContainer",true,false)[0].columns == 1,"live resize reflows open market into compact single column")
	ui._ui_scale = 1.0
	root.size = Vector2i(1280,720)
	ui._layout()
	ui._show_market()
	ui.trade_spin.get_line_edit().grab_focus()
	before = ui.world.to_snapshot()
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	ui._unhandled_key_input(key)
	check(before == ui.world.to_snapshot(),"quantity input blocks day shortcut")
	ui._close_page()
	var focus := root.gui_get_focus_owner()
	if focus != null: focus.release_focus()
	ui._select_tool("till")
	for dimensions in [Vector2i(2560,1440),Vector2i(1920,1080),Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		for scaling in [1.0,1.25,1.5]:
			ui._ui_scale = scaling
			ui._layout()
			await process_frame
			await process_frame
			check(ui.toolbar_panel.position.y >= 102 and ui.toolbar_panel.position.y+ui.toolbar_panel.size.y <= ui.ui_root.size.y,"toolbar fits %s at %s" % [dimensions,scaling])
			var map_zoom: Vector2 = ui.camera.zoom
			ui._show_settings()
			await process_frame
			check(ui.window_panel.position.x >= 0 and ui.window_panel.position.y >= 0 and ui.window_panel.size.y <= ui.ui_root.size.y and ui.camera.zoom == map_zoom,"settings fits and UI scale preserves map zoom %s/%s" % [dimensions,scaling])
			ui._close_page()
	ui._ui_scale = 1.0
	root.size = Vector2i(1280,720)
	ui._layout()
	var preferences := Settings.defaults()
	preferences["ui_scale"] = 125
	check(ui.settings.save_settings(preferences)["ok"],"V1 preferences persist independently")
	var reloaded := Settings.new(directory+".cfg")
	check(reloaded.load_settings() and reloaded.data == preferences,"preferences round trip exact")
	preferences["map_zoom"] = NAN
	check(not ui.settings.save_settings(preferences)["ok"],"nonfinite map zoom rejected")
	var broken := FileAccess.open(directory+".cfg",FileAccess.WRITE)
	broken.store_string("invalid settings")
	broken.close()
	check(not reloaded.load_settings() and reloaded.data == Settings.defaults() and not reloaded.warning.is_empty(),"corrupt preferences fall back with explicit warning")
	ui.store.fail_write = true
	ui._result(ui.world.end_day())
	check(not ui.world.daily_save_error.is_empty(),"daily write failure enters paused guard")
	before = ui.world.to_snapshot()
	ui._show_history()
	check(button("重试日存档") != null,"history exposes save retry")
	ui._result(ui.world.buy("golden_wheat_seed",1))
	check(before == ui.world.to_snapshot(),"write failure blocks trading")
	ui.store.fail_write = false
	button("重试日存档").pressed.emit()
	check(ui.world.daily_save_error.is_empty() and before == ui.world.to_snapshot() and ui.store.read_slot(1)["snapshot"] == before,"retry saves identical settlement without work or double charges")
	for slot in [1,2,3]:
		if ui.store.occupied(slot): ui.store.delete_slot(slot,true)
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(directory+".cfg"+suffix): DirAccess.remove_absolute(directory+".cfg"+suffix)
	ui.queue_free()
	await process_frame
	DirAccess.remove_absolute(directory)
	for failure in failures: printerr(failure)
	print("V1 PHASE65 UI TEST %s: %d checks" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
