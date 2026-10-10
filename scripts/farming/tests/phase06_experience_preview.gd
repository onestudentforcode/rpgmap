extends SceneTree
var shell
var directory: String
var output := "res://.shots/farm-phase06e"

func _initialize(): _run.call_deferred()

func capture(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var logical := Rect2(Vector2.ZERO,Vector2(640,360))
	if shell.is_modal(): assert(logical.encloses(shell._surface.get_child(1).get_rect()),"Menu must fit viewport")
	if shell.farm != null:
		assert(logical.encloses(shell.farm._tutorial_panel.get_rect()),"Tutorial must fit viewport")
		assert(logical.encloses(shell.farm._crop_choice.get_global_rect()),"Toolbar must fit viewport")
	root.get_texture().get_image().save_png(output+"/"+filename)

func _run():
	DirAccess.make_dir_recursive_absolute(output)
	directory = "user://farm_phase06_experience_preview_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	shell = load("res://scripts/farming/rendering/farm_demo.gd").new()
	shell.store = load("res://scripts/farming/core/storage/farm_slot_store.gd").new(directory+"/slots")
	shell.settings = load("res://scripts/farming/core/storage/farm_settings.gd").new(directory+"/settings.cfg")
	shell.legacy_path = directory+"/absent.json"
	root.add_child(shell)
	shell.show_settings()
	await capture("settings-main.png")
	shell._settings_draft["resolution"] = 0
	shell._settings_draft["frame_mode"] = "60"
	shell._settings_draft["show_fps"] = true
	shell.apply_settings()
	await process_frame
	assert(DisplayServer.window_get_size() == Vector2i(960,540),"960x540 must apply")
	assert(Engine.max_fps == 60 and shell._fps.visible,"FPS settings must apply")
	await capture("settings-960.png")
	shell._start_slot("new",1,false)
	await process_frame
	var farm = shell.farm
	await capture("tutorial-960.png")
	farm._tool_buttons[0].pressed.emit()
	farm._act_on(Vector2i(1,1))
	farm._crop_choice.item_selected.emit(0)
	farm._act_on(Vector2i(1,1))
	await capture("tutorial-growth.png")
	shell.show_settings()
	shell._settings_draft["resolution"] = 3
	shell._settings_draft["frame_mode"] = "120"
	shell.apply_settings()
	await process_frame
	assert(DisplayServer.window_get_size() == Vector2i(1920,1080),"1920x1080 must apply")
	await capture("settings-1920.png")
	shell._settings_draft["fullscreen"] = true
	shell.apply_settings()
	await process_frame
	assert(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,"Fullscreen must apply")
	await capture("settings-fullscreen.png")
	shell._settings_draft["fullscreen"] = false
	shell._settings_draft["resolution"] = 1
	shell._settings_draft["frame_mode"] = "vsync"
	shell.apply_settings()
	await process_frame
	assert(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_size() == Vector2i(1280,720),"Windowed mode must restore selected resolution")
	shell._show_help()
	await capture("help-replay.png")
	shell.restart_tutorial()
	assert(not shell.is_modal() and farm._cam_ctrl.is_processing(),"Closing menu must restore map input")
	shell.skip_tutorial()
	await capture("tutorial-skipped.png")
	shell._leave("menu")
	shell.store.delete_slot(1,true)
	DirAccess.remove_absolute(directory+"/slots")
	for suffix in ["", ".bak"]: DirAccess.remove_absolute(shell.settings.path+suffix)
	DirAccess.remove_absolute(directory)
	print("EXPERIENCE PREVIEW OK: eight views, window sizes, fullscreen, FPS, input resume")
	quit()
