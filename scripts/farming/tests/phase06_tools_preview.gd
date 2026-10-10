extends SceneTree
var shell
var output := "res://.shots/farm-phase06d"
func _initialize(): _run.call_deferred()
func capture(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var farm = shell.farm
	assert(Rect2(Vector2.ZERO,Vector2(640,360)).encloses(farm._crop_choice.get_global_rect()), "Toolbar must fit viewport")
	if farm.economy_panel.visible:
		assert(Rect2(Vector2.ZERO,Vector2(640,360)).encloses(farm.economy_panel.get_rect()), "Tools page must fit viewport")
	root.get_texture().get_image().save_png(output+"/"+filename)
func _run():
	DirAccess.make_dir_recursive_absolute(output)
	var directory := "user://farm_phase06_tools_preview_%d" % Time.get_ticks_usec()
	shell = load("res://scripts/farming/rendering/farm_demo.gd").new()
	shell.store = load("res://scripts/farming/core/storage/farm_slot_store.gd").new(directory)
	shell.legacy_path = directory + "/absent.json"
	root.add_child(shell)
	shell._start_slot("new",1,false)
	await process_frame
	var farm = shell.farm
	farm.economy_panel.select_tab(3)
	farm.economy_panel.show()
	await capture("shop.png")
	farm.economy_panel._buy_tool("hoe")
	await capture("purchased.png")
	farm.economy_panel.hide()
	farm.tools.switch_level("hoe")
	farm._select_kind("hoe")
	farm._hover = Vector2i(3,11)
	farm._cam.position = Vector2(3.5*64,11.5*64)
	farm._cam.zoom = Vector2(1.4,1.4)
	farm.grid.till(Vector2i(2,10))
	farm._update_hud()
	await capture("range-hoe.png")
	farm._act_on(Vector2i(3,11))
	farm.economy.primeval_stones = 100
	farm.tools.buy("sower",farm.economy)
	farm.tools.switch_level("sower")
	farm._select_crop(0)
	await capture("range-sower.png")
	farm._act_on(Vector2i(3,11))
	await capture("planted.png")
	shell._leave("menu")
	shell.store.delete_slot(1,true)
	DirAccess.remove_absolute(directory)
	print("TOOLS PREVIEW OK: five views within logical viewport")
	quit()
