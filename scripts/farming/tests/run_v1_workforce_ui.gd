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
		if child is Button and child.text == text: return child
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
	var directory := "user://test_v1_workforce_ui_%d" % Time.get_ticks_usec()
	ui = Scene.instantiate()
	ui.store = Store.new(directory)
	root.add_child(ui)
	await process_frame
	check(not ui._started and ui.store.active_slot() == 0,"V1 starts at own three slot selector")
	click("新建槽1")
	check(ui._started and ui.store.active_slot() == 1,"UI binds selected V1 slot")
	click("雇佣一人（无固定费用）")
	check(ui.world.workforce.state["workers"].size() == 1 and ui.selected_worker == 1,"UI hires selectable employee")
	click("框选追加负责区域")
	check(ui.expanded and ui.tool == "area" and ui.tool_grid.visible,"expanded toolbar selects area")
	ui.apply_rectangle(Rect2i(2,2,3,2))
	check(ui.world.workforce.state["workers"][0]["areas"] == [[2,2,3,2]],"rectangle assigns worker area")
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
	check(find_button(ui,"买1 · 3元石") != null,"market exposes priced seed inputs")
	click("订单")
	check(find_button(ui,"清水×12 → 13元石") != null,"orders expose necessary quantity and reward")
	click("雇工")
	var preferences := 0
	for child in ui.sidebar.get_children():
		if child is HBoxContainer:
			for field in child.get_children():
				if field is SpinBox:
					preferences += 1
					if preferences == 1:
						field.value = 0
	check(preferences == 8 and ui.world.workforce.state["workers"][0]["priorities"]["source"] == 0,"work preferences editable including disable")
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
	check(ui.board.size.x <= 432 and ui.toolbar.position.y + ui.toolbar.size.y <= 360,"map toolbar within base viewport")
	for slot in [1,2,3]:
		if ui.store.occupied(slot): ui.store.delete_slot(slot,true)
	ui.queue_free()
	await process_frame
	DirAccess.remove_absolute(directory)
	for failure in failures: printerr(failure)
	print("V1 WORKFORCE UI TEST %s: %d checks" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
