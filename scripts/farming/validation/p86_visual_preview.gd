extends SceneTree
## A-stage review fixture. Only isolated workspace saves and explicit trial visuals.
const Shell := preload("res://scripts/farming/p8/p8_scene.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
var failures: Array[String] = []
var frames: Array[Dictionary] = []
var shell
var directory := "res://.art-work/p86-trial/2560x1440"
var runtime_dir := "res://.art-work/p86-runtime"

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--p86-dir="): directory = argument.trim_prefix("--p86-dir=")
		if argument.begins_with("--runtime-dir="): runtime_dir = argument.trim_prefix("--runtime-dir=")
	DirAccess.make_dir_recursive_absolute(directory)
	shell = Shell.new()
	shell.production_visuals = false
	shell.store = Store.new(directory + "/slots-%d" % Time.get_ticks_usec())
	shell.settings = shell.settings.get_script().new(directory + "/settings.cfg", 0.1)
	root.add_child(shell)
	await process_frame
	shell._new(1, false)
	shell.world.journal["guide"]["dismissed"] = true
	shell._close_page()
	shell.digest.visible = false
	shell.expanded = true
	await shell._prepare_preview(directory)
	_prepare_world()
	# Keep each requested review camera fixed, including at small viewports.
	shell.set_process(false)
	if not failures.is_empty():
		_finish()
		return
	var before: Dictionary = shell.world.to_snapshot().duplicate(true)
	for profile in ["baseline", "grounding", "integrated"]:
		shell.selected = Vector2i(-1,-1)
		var configured: Dictionary = shell.configure_visual_trial(profile, runtime_dir)
		_check(bool(configured.get("ok", false)), "configure %s: %s" % [profile, configured])
		if profile == "integrated":
			_check(configured.get("replaced", []).size() == 6, "integrated requires six candidate seedling images")
			_check(configured.get("diagnostics", []).is_empty(), "integrated requires all trial resources: %s" % configured)
			_check(shell.trial_environment != null, "integrated environment instantiated")
		shell._side_open = false
		shell._layout()
		await _capture(profile, "scene-1.0", Vector2(640,570), 1.0)
		await _capture(profile, "seedlings-1.0", Vector2(520,230), 1.0)
		await _capture(profile, "seedlings-3.0", Vector2(320,210), 3.0)
		await _capture(profile, "waterfront-1.0", Vector2(500,860), 1.0)
		await _capture(profile, "waterfront-3.0", Vector2(470,900), 3.0)
		await _capture(profile, "resources-3.0", Vector2(1056,565), 3.0)
		await _capture(profile, "overview-0.1", Vector2(700,700), 0.1)
		shell._side_open = true
		shell.selected = Vector2i(2,12)
		shell._show_cell()
		shell._layout()
		await _capture(profile, "sidebar-1.0", Vector2(480,310), 1.0)
		_check(shell.world.to_snapshot() == before, "visual profile/capture mutated gameplay: " + profile)
	# Switching back must restore both the source textures and terrain materials.
	var restored: Dictionary = shell.configure_visual_trial("baseline")
	_check(bool(restored.get("ok", false)), "baseline restore")
	_check(shell.world.to_snapshot() == before, "restore mutated gameplay")
	_finish()

func _prepare_world() -> void:
	for project in shell.world.research.project_defs():
		shell.world.research.state["completed"].append(project)
	shell.world.primeval_stones = 2000
	var stock := {"clean_water":100,"raw_wood":100,"raw_stone":100,"humus":100}
	for definition in shell.world.crop_defs.values():
		stock[definition["seed"]] = 20
		for ingredient in definition["inputs"]: stock[ingredient] = 100
	for definition in shell.world.facility_defs.values():
		for ingredient in definition["materials"]: stock[ingredient] = 100
	shell.world.grant_scaffold(stock)
	for ident in ["golden_wheat", "pasture_grass", "resin_tree"]:
		var definition: Dictionary = shell.world.crop_defs[ident]
		var shape: Array = definition["footprint"]
		for stage in range(4):
			var cell := Vector2i(3+stage*3, 2 if ident == "golden_wheat" else 4)
			if ident == "resin_tree": cell = Vector2i([2,6,10,13][stage],9)
			for dy in range(int(shape[1])):
				for dx in range(int(shape[0])):
					shell.world.clock.ap = 24
					var tilled: Dictionary = shell.world.till(cell+Vector2i(dx,dy))
					_check(bool(tilled.get("ok",false)), "till %s/%d: %s" % [ident,stage,tilled])
			shell.world.clock.ap = 24
			var planted: Dictionary = shell.world.plant(cell,ident)
			_check(bool(planted.get("ok",false)), "plant %s/%d: %s" % [ident,stage,planted])
			if not planted.get("ok",false): continue
			var crop: Dictionary = shell.world.crops[int(planted["uid"])]
			crop["progress"] = ceili(float(int(definition["days"])*100)*stage/3.0)
			crop["state"] = "mature" if stage == 3 else "growing"
			_check(shell.plant_visuals.state_key(crop,definition,shell.world.flowers.settings["oilseed_window"]) == "stage_%d" % stage,
				"correct stage %s/%d" % [ident,stage])
	for entry in [["woodshop",Vector2i(2,12)],["fish_pond",Vector2i(7,14)]]:
		shell.world.clock.ap = 24
		var built: Dictionary = shell.world.build_facility(entry[1],entry[0])
		_check(bool(built.get("ok",false)), "build %s: %s" % [entry[0],built])
	shell.selected = Vector2i(-1,-1)
	shell._refresh()
	shell.digest.visible = false

func _capture(profile: String, name: String, center: Vector2, zoom: float) -> void:
	shell.camera.position = center
	shell.camera.zoom = Vector2.ONE*zoom
	shell.guide_hint.text = "P8.6 A样板 · %s · 固定场景对照（材料、研究和成长进度为夹具）" % profile
	shell.digest.visible = false
	shell.overlay.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shot-size="):
			var requested := argument.trim_prefix("--shot-size=").split("x")
			_check(picture.get_size() == Vector2i(int(requested[0]),int(requested[1])), "actual viewport size")
	var filename := "%s-%s.png" % [profile,name]
	_check(picture.save_png(directory+"/"+filename) == OK, "save " + filename)
	var crops := []
	for crop in shell.world.crops.values():
		var definition: Dictionary = shell.world.crop_defs[crop["crop_id"]]
		var visual: Dictionary = shell.plant_visuals.visual(crop,definition,shell.world.flowers.settings["oilseed_window"])
		var rect: Rect2 = visual["rect"]
		var transform: Transform2D = shell.map_view.get_global_transform()*shell.map_port.canvas_transform
		var screen_rect: Rect2 = transform*rect
		crops.append({"id":crop["crop_id"],"stage":visual["key"],"rect":[screen_rect.position.x,screen_rect.position.y,screen_rect.size.x,screen_rect.size.y]})
	frames.append({"file":filename,"profile":profile,"case":name,"size":[picture.get_width(),picture.get_height()],
		"camera":[center.x,center.y],"zoom":zoom,"sidebar":shell._side_open,"crops":crops})

func _finish() -> void:
	var report := FileAccess.open(directory+"/trial.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"fixture":"P8 production shell, real till/plant/build; scaffold stock/research/progress; isolated saves",
		"frames":frames,"failures":failures,"default_game_unchanged":true,"awaiting_user_visual_acceptance":true},"  "))
	for failure in failures: printerr(failure)
	print("P86 VISUAL PREVIEW OK: %d frames" % frames.size()) if failures.is_empty() else print("P86 VISUAL PREVIEW FAILED")
	quit(0 if failures.is_empty() else 1)
