extends SceneTree
var shell
var output := "res://.shots/farm-phase06c"

func _initialize() -> void:
	_run.call_deferred()

func capture(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(Rect2(Vector2.ZERO,Vector2(640,360)).encloses(shell._surface.get_child(1).get_rect()), "Report must fit viewport")
	root.get_texture().get_image().save_png(output + "/" + filename)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var directory := "user://farm_phase06_records_preview_%d" % Time.get_ticks_usec()
	shell = load("res://scripts/farming/rendering/farm_demo.gd").new()
	shell.store = load("res://scripts/farming/core/storage/farm_slot_store.gd").new(directory)
	shell.legacy_path = directory + "/absent.json"
	root.add_child(shell)
	shell._start_slot("new",1,false)
	await process_frame
	var farm = shell.farm
	farm.economy.trade("dew_grass_seed",2,true)
	farm.grid.till(Vector2i(1,1))
	farm._tool = 1
	farm._act_on(Vector2i(1,1))
	for day in range(4): farm.clock.end_day()
	farm._act_on(Vector2i(1,1))
	farm.economy.trade("dew_leaf",1,false)
	farm.inventory.add("dew_leaf",1)
	farm.economy.gu["satiety"] = 0
	farm.economy.feed("dew_leaf")
	shell.show_records()
	await capture("ongoing.png")
	shell._set_modal(false)
	while farm.clock.total_days < 45: farm.clock.end_day()
	await capture("report.png")
	for child in shell._box.get_children():
		if child is ScrollContainer: child.scroll_vertical = 1000
	await capture("report-details.png")
	shell._leave("menu")
	shell.store.delete_slot(1,true)
	DirAccess.remove_absolute(directory)
	print("RECORDS PREVIEW OK: three views fit logical viewport")
	quit()
