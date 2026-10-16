extends SceneTree
const Scene := preload("res://scenes/farming/farm_v1.tscn")
const Store := preload("res://scripts/farming/v1/v1_slot_store.gd")
var checks := 0
var failures: Array[String] = []
var ui

func check(condition: bool,label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func find_button(parent: Node,text: String):
	for child in parent.get_children():
		if child is Button and (child.text == text or child.get_meta("action_name","") == text or str(child.get_meta("action_name","")).begins_with(text+" ·")): return child
		var found = find_button(child,text)
		if found != null: return found
	return null

func click(text: String) -> void:
	var button = find_button(ui,text)
	check(button != null,"UI button exists " + text)
	if button != null: button.pressed.emit()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280,720)
	var directory := "user://test_v1_workforce_ui_%d" % Time.get_ticks_usec()
	ui = Scene.instantiate()
	ui.store = Store.new(directory)
	root.add_child(ui)
	await process_frame
	check(not ui._started and ui.store.active_slot() == 0,"V1 starts at own three slot selector")
	click("新建槽1")
	check(ui._started and ui.store.active_slot() == 1,"UI binds selected V1 slot")
	click("雇工")
	click("雇佣一人（无固定费用）")
	check(ui.world.workforce.state["workers"].size() == 1 and ui.selected_worker == 1,"UI hires selectable employee")
	click("框选追加负责区域")
	check(ui.expanded and ui.tool == "area" and ui.tool_grid.visible,"expanded toolbar selects area")
	ui.apply_rectangle(Rect2i(2,2,3,2))
	check(ui.world.workforce.state["workers"][0]["areas"] == [[2,2,3,2]],"rectangle assigns worker area")
	click("委托")
	check(ui.manual_mode and not ui.tool_buttons["area"].visible,"manual mode hides and downgrades delegation tools")
	click("雇工")
	click("框选追加负责区域")
	check(not ui.manual_mode and ui.expanded and ui.tool == "area" and ui.tool_grid.visible,"area button auto leaves manual mode with the area tool ready")
	ui.apply_rectangle(Rect2i(5,2,2,2))
	check(ui.world.workforce.state["workers"][0]["areas"].has([5,2,2,2]),"rectangle assignable right after the automatic mode switch")
	click("开垦")
	check(ui.tool_buttons["till"].button_pressed and not ui.tool_buttons["inspect"].button_pressed,"selected designation tool remains visibly selected")
	ui.apply_rectangle(Rect2i(2,2,2,1))
	check(ui.world.workforce.state["marks"].size() == 2 and ui.world.crops.is_empty(),"toolbar designation instead of immediate work")
	click("查看")
	ui.apply_rectangle(Rect2i(2,2,1,1))
	var seed_choice: OptionButton
	for child in ui.sidebar.get_children():
		if child is OptionButton: seed_choice = child
	check(seed_choice != null,"land click exposes seed selector")
	seed_choice.select(1)
	seed_choice.item_selected.emit(1)
	check(ui.world.workforce.seed_plan(Vector2i(2,2))["crop_id"] == "golden_wheat","land choice stores seed crop")
	click("结束当天")
	check(ui.world.crops.size() == 1 and ui.world.primeval_stones == 57 and ui.world.clock.ap == 24,"UI day executes till2 seed1 and wage3")
	check(ui.digest.visible and ui._context == "cell","normal daily digest keeps selected sidebar context")
	check(ui.digest_body.get_child_count() >= 2 and ui.world.journal["history"].back()["totals"]["plantings"] == {"golden_wheat":1},"digest renders structured actual daily entries")
	await process_frame
	await process_frame
	check(ui.digest.size.y <= 220 and ui.digest.position.y + ui.digest.size.y < ui.toolbar_panel.position.y,"daily digest stays compact: %s at %s / toolbar %s / UI %s" % [ui.digest.size,ui.digest.position,ui.toolbar_panel.position,ui.ui_root.size])
	check(ui.store.read_slot(1)["snapshot"] == ui.world.to_snapshot(),"UI day auto saves full labour state")
	click("查看")
	ui.apply_rectangle(Rect2i(17,8,1,1))
	var source_choice: OptionButton
	for child in ui.sidebar.get_children():
		if child is OptionButton: source_choice = child
	check(source_choice != null,"resource click has separate worker selector")
	source_choice.select(1)
	source_choice.item_selected.emit(1)
	check(ui.world.workforce.state["sources"].get("spring_source") == 1,"source panel assigns one employee")
	click("结束当天")
	check(ui.world.inventory.count("clean_water") == 30 and ui.world.primeval_stones == 51,"resource commission reflected in warehouse and payroll")
	click("行囊/交易")
	check(ui.trade_total.text.contains("买入总价 3") and not ui.trade_buy.disabled,"market exposes quantity and priced seed inputs")
	click("订单")
	check(find_button(ui,"清水×12 → 13元石") != null,"orders expose necessary quantity and reward")
	click("雇工")
	var preferences := 0
	for field in ui.sidebar.find_children("*","SpinBox",true,false):
		if field.has_meta("preference"):
			preferences += 1
			if field.get_meta("preference") == "source": field.value = 0
	check(preferences == 8 and ui.world.workforce.state["workers"][0]["priorities"]["source"] == 0,"work preferences editable including disable")
	ui._close_page()
	click("开垦")
	ui.camera.position = Vector2(450,220)
	await process_frame
	var location: Vector2 = ui.map_port.get_canvas_transform()*(Vector2(4,3)*64.0+Vector2(32,32))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = location
	event.pressed = true
	ui.board.gui_input.emit(event)
	event.pressed = false
	ui.board.gui_input.emit(event)
	check(ui.world.workforce.state["marks"].any(func(mark): return mark["cell"] == [4,3] and mark["kind"] == "till"),"actual board mouse coordinates create intended world cell mark")
	check(ui.board.position.x + ui.board.size.x <= ui.ui_root.size.x and ui.toolbar_panel.position.y + ui.toolbar_panel.size.y <= ui.ui_root.size.y,"map toolbar within responsive viewport")
	var before: Dictionary = ui.world.to_snapshot()
	check(ui.world.workforce.task_status(Vector2i(2,2),"harvest") == "等待植物成熟" and before == ui.world.to_snapshot(),"task inspection does not execute or charge pending work")
	click("手册")
	check(ui._context == "help" and find_button(ui,"跳过操作提示") != null,"nonblocking guide accessible at any time")
	click("跳过操作提示")
	check(ui.world.journal["guide"]["dismissed"] and before["economy"] == ui.world.to_snapshot()["economy"],"skip guide changes no wallet or production")
	click("恢复操作提示")
	check(not ui.world.journal["guide"]["dismissed"],"guide can resume without progress gifts")
	click("记录")
	check(ui._context == "history" and find_button(ui,"首次45天回顾") != null,"history offers detailed entries and recap")
	click("首次45天回顾")
	check(ui._context == "recap" and find_button(ui,"第3时节小计") != null,"recap offers total and three term selectors")
	click("第1时节小计")
	while ui.world.clock.total_days < 45: ui.world.end_day()
	await process_frame
	check(ui._context == "recap" and ui.world.journal["frozen"],"day45 automatically offers frozen recap without preventing further play")
	var frozen: Array = ui.world.journal["terms"].duplicate(true)
	click("继续经营")
	click("结束当天")
	check(ui.world.clock.total_days == 46 and ui.world.journal["terms"] == frozen,"continue beyond45 through real day button with recap intact")
	for slot in [1,2,3]:
		if ui.store.occupied(slot): ui.store.delete_slot(slot,true)
	ui.queue_free()
	await process_frame
	DirAccess.remove_absolute(directory)
	for failure in failures: printerr(failure)
	print("V1 WORKFORCE UI TEST %s: %d checks" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
