extends SceneTree
## Explicit preview only; --fresh avoids loading player saves. No saves written.
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var farm = load("res://scenes/farming/farm_main.tscn").instantiate()
	root.add_child(farm)
	await process_frame
	farm.inventory.add("dew_leaf", 3)
	farm.inventory.add("scarlet_berry_fruit", 3)
	farm.inventory.add("jade_fruit", 2)
	farm.inventory.add("moon_cap_flesh", 2)
	for day in range(6):
		farm.clock.end_day()
	farm._toggle_economy()
	await process_frame
	await process_frame
	assert(not farm._cam_ctrl.is_processing(), "Modal must pause map camera")
	assert(Rect2(Vector2.ZERO, Vector2(640,360)).encloses(farm.economy_panel.get_rect()), "Panel must fit logical viewport")
	var dir := ProjectSettings.globalize_path("res://.shots/farm-phase05")
	DirAccess.make_dir_recursive_absolute(dir)
	farm.economy_panel.select_tab(2)
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(dir + "/market-hungry.png")
	farm.economy_panel._feed("dew_leaf")
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(dir + "/market-fed.png")
	farm.economy_panel.select_tab(1)
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(dir + "/market-trade.png")
	farm.economy_panel._controls.get_child(3).pressed.emit()
	assert(farm.economy_panel._quantity.value == 5, "Quantity shortcut must set five")
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(dir + "/market-bulk.png")
	farm.economy_panel.select_tab(0)
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(dir + "/inventory.png")
	farm.economy_panel.hide()
	assert(farm._cam_ctrl.is_processing(), "Closing modal must restore camera")
	farm._tool_buttons[1].pressed.emit()
	farm._crop_choice.item_selected.emit(1)
	assert(farm._tool == 2, "Clickable sower and crop selector must select correct seed")
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(dir + "/hud.png")
	print("UI PREVIEW OK: modal camera, viewport bounds, quantity shortcut, crop toolbar")
	quit()
