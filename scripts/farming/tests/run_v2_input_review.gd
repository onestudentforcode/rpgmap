extends SceneTree
## Engine GUI event integration; distinct from unavailable native OS mouse QA.
const Scene := preload("res://scenes/farming/farm_v2.tscn")
const Store := preload("res://scripts/farming/v2/v2_slot_store.gd")
const Settings := preload("res://scripts/farming/v1/v1_settings.gd")
var shell
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); print("INPUT CHECK FAILED: ",label)
func frames() -> void:
	await process_frame
	await process_frame
	await process_frame
func button(parent: Node, caption: String) -> BaseButton:
	for child in parent.get_children():
		if child is BaseButton and child.is_visible_in_tree() and String(child.get_meta("action_name",child.tooltip_text)).begins_with(caption): return child
		var found := button(child,caption)
		if found != null: return found
	return null
func click(control: Control) -> void:
	if control == null: failures.append("click target missing"); return
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await frames()
	var viewport := control.get_viewport()
	var point := control.get_global_rect().get_center()
	if viewport is Window and viewport != root:
		point = Vector2(viewport.position)+point*viewport.content_scale_factor
		viewport = root
	var motion := InputEventMouseMotion.new()
	motion.position = point
	viewport.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		viewport.push_input(event,true)
		await process_frame
	await frames()
func key(viewport: Viewport, code: int) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		viewport.push_input(event,true)
		await process_frame
	await frames()

func click_cell(cell: Vector2i) -> void:
	await frames()
	var point: Vector2 = shell.map_port.get_canvas_transform()*(Vector2(cell)*64+Vector2(32,32))
	point = shell.board.get_global_transform()*point
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
	await frames()

func _run() -> void:
	shell = Scene.instantiate()
	shell.store = Store.new("user://phase07f_input_%d" % Time.get_ticks_usec())
	shell.settings = Settings.new("res://.art-work/phase07f-input-settings.cfg",0.1)
	root.add_child(shell)
	await frames()
	shell._new(1,false)
	check(shell.world.apply_snapshot(JSON.parse_string(FileAccess.get_file_as_string("res://.art-work/phase07f-routeB-day30.json")))["ok"],"real playthrough snapshot loads")
	await frames()
	check(shell.watch_body.get_child_count() > 1,"saved watch list refreshes without another checkbox click")
	await click(button(shell.top_nav,"养殖总览"))
	check(shell._context == "overview" and not shell.watch_panel.visible,"overview mouse event opens unobscured modal")
	await click(button(shell.sidebar,"定位并打开"))
	check(shell.selected == Vector2i(7,1) and not shell.shade.visible,"locate click returns to pen detail")
	var water: int = shell.world.inventory.count("clean_water")
	var grass: int = shell.world.inventory.count("fodder_grass")
	var ap: int = shell.world.clock.ap
	await click(button(shell.sidebar,"整体维护"))
	check(shell.hus().summary(shell.hus().habitat_of(1))["fed_today"] == 4,"maintenance click serves all four animals")
	check(shell.world.inventory.count("clean_water") == water-4 and shell.world.inventory.count("fodder_grass") == grass-4 and shell.world.clock.ap == ap-1,"click deducts the quoted stock and one player AP")
	var special: OptionButton
	for child in shell.sidebar.get_children():
		if child is OptionButton:
			for index in range(child.item_count):
				if child.get_item_text(index).contains("暂不生产"): special = child
	if special == null: printerr("special selector missing"); quit(1); return
	await click(special)
	var popup := special.get_popup()
	var point := Vector2(popup.position)+Vector2(40,20)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
	await frames()
	check(not shell.hus().habitat_of(1)["production_enabled"],"special menu accepts temporarily no production")
	await click(button(shell.top_nav,"资源一览"))
	check(shell._context == "resources" and not shell.watch_panel.visible,"resource navigation click opens modal")
	var watched: int = shell.world.preferences["watched"].size()
	var box: CheckBox
	for control in shell.sidebar.find_children("*","CheckBox",true,false):
		if not control.button_pressed: box = control; break
	await click(box)
	check(shell.world.preferences["watched"].size() == watched+1,"resource checkbox records a player preference")
	# Close via the actual window chrome; Escape must not perform a farm action.
	await key(root,KEY_ESCAPE)
	check(not shell.shade.visible and shell.watch_panel.visible,"Escape restores map and watch HUD")
	await click(button(shell.top_nav,"行囊/交易"))
	check(shell._context == "market","market navigation accepts mouse event")
	var cash: int = shell.world.primeval_stones
	var seeds: int = shell.world.inventory.count("golden_wheat_seed")
	await click(shell.trade_buy)
	check(shell.world.inventory.count("golden_wheat_seed") == seeds+1 and shell.world.primeval_stones == cash-3,"market purchase click follows normal price")
	await click(button(shell.sidebar,"普通岩石"))
	await click(shell.trade_buy)
	await click(shell.trade_buy)
	check(shell.world.inventory.count("raw_stone") == 4,"market selector purchases construction inputs")
	await key(root,KEY_ESCAPE)
	await click(button(shell.top_nav,"建设"))
	await click(button(shell.sidebar,"放置 圈舍"))
	await click_cell(Vector2i(16,1))
	var facility: Dictionary = shell.world.facility_at(Vector2i(16,1))
	check(not facility.is_empty(),"build catalogue and map click create a real2x2 pen")
	if facility.is_empty(): printerr("pen mouse placement failed"); quit(1); return
	var new_uid := int(facility["uid"])
	await click(button(shell.sidebar,"按所选数量购入"))
	check(is_instance_valid(shell.confirmation),"juvenile purchase opens price confirmation")
	await click(shell.confirmation.get_ok_button())
	check(shell.hus().summary(shell.hus().habitat_of(new_uid))["juvenile"] == 1,"confirmed purchase creates one paid juvenile")
	await click(button(shell.sidebar,"整体维护"))
	check(shell.hus().summary(shell.hus().habitat_of(new_uid))["fed_today"] == 1,"new juvenile can be served through the same detail UI")
	await click(button(shell.top,"结束当天"))
	check(shell.world.clock.total_days == 31 and shell.store.occupied(1),"day-end click autosaves without a manual save entry")
	var after: Dictionary = shell.world.to_snapshot()
	check(shell.world.open_game(1)["ok"] and JSON.stringify(after) == JSON.stringify(shell.world.to_snapshot()),"clicked day-end restores complete slot state")
	for slot in [1,2,3]:
		if shell.store.occupied(slot): shell.store.delete_slot(slot,true)
	DirAccess.remove_absolute(shell.store.slot_path(1).get_base_dir())
	for failure in failures: printerr(failure)
	print("V2 INPUT REVIEW %s: %d checks" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
