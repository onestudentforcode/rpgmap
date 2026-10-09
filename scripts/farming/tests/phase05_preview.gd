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
	var dir := ProjectSettings.globalize_path("res://.shots/farm-phase05")
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_png(dir + "/market-hungry.png")
	farm.economy_panel._feed("dew_leaf")
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(dir + "/market-fed.png")
	quit()
