extends SceneTree
## Real P8 operations with explicitly scaffolded stock/research/growth and L-shaped shore.
const Trial := preload("res://scripts/farming/p8/p87_projection_trial.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
var shell
var directory := "res://.art-work/p87-trial/1920x1080"
var frames: Array[Dictionary] = []
var failures: Array[String] = []
var world_hash_before := ""
var world_hash_after := ""
var desired_size := Vector2i(1920,1080)
func _initialize() -> void: _run.call_deferred()
func verify(ok: bool,label: String) -> void:
	if not ok: failures.append(label)
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--p87-dir="): directory = arg.trim_prefix("--p87-dir=")
		if arg.begins_with("--shot-size="):
			var parts := arg.trim_prefix("--shot-size=").split("x")
			desired_size = Vector2i(int(parts[0]),int(parts[1]))
	DirAccess.make_dir_recursive_absolute(directory)
	shell = Trial.new()
	shell.store = Store.new(directory+"/slots-%d"%Time.get_ticks_usec())
	shell.settings = shell.settings.get_script().new(directory+"/settings.cfg",0.1)
	root.add_child(shell)
	await process_frame
	await shell._prepare_preview(directory)
	shell._new(1,false)
	shell.world.journal["guide"]["dismissed"] = true
	shell._close_page()
	shell.set_process(false)
	_prepare_world()
	if not failures.is_empty(): _finish(); return
	var before: Dictionary = shell.world.to_snapshot().duplicate(true)
	world_hash_before = JSON.stringify(before).sha256_text()
	for profile in ["p86","matched35"]:
		verify(shell.configure_projection(profile)["ok"],"configure "+profile)
		shell._side_open = false
		shell._layout()
		shell.selected = Vector2i(-1,-1)
		shell.show_rulers = true
		await _capture(profile,"scene-1.0",Vector2(640,570),1.0)
		await _capture(profile,"plants-1.0",Vector2(620,350),1.0)
		await _capture(profile,"seedlings-3.0",Vector2(380,240),3.0)
		await _capture(profile,"shore-1.0",Vector2(640,910),1.0)
		await _capture(profile,"shore-3.0",Vector2(470,930),3.0)
		await _capture(profile,"resources-3.0",Vector2(1056,565),3.0)
		await _capture(profile,"overview-0.1",Vector2(640,700),0.1)
		shell._fit_map()
		await _capture_current(profile,"fit-to-play")
		shell.show_rulers = false
		await _capture_current(profile,"clean-fit-to-play")
		shell.selected = Vector2i(2,12)
		shell._side_open = true
		shell._show_cell()
		shell._layout()
		await _capture(profile,"sidebar-1.0",Vector2(420,650),1.0)
		shell.build_tool = "woodshop"
		shell._hover = Vector2i(16,10)
		await _capture(profile,"build-preview",Vector2(1040,700),1.0)
		shell.build_tool = ""
		verify(shell.world.to_snapshot()==before,"profile/capture does not change gameplay "+profile)
	verify(shell.configure_projection("p86")["ok"],"restore baseline projection")
	verify(shell.world.to_snapshot()==before,"restore leaves exact schema17 world")
	world_hash_after = JSON.stringify(shell.world.to_snapshot()).sha256_text()
	_finish()

func _prepare_world() -> void:
	for project in shell.world.research.project_defs(): shell.world.research.state["completed"].append(project)
	shell.world.primeval_stones = 2000
	var stock := {"clean_water":100,"raw_wood":100,"raw_stone":100,"humus":100}
	for definition in shell.world.crop_defs.values():
		stock[definition["seed"]] = 20
		for ingredient in definition["inputs"]: stock[ingredient] = 100
	for definition in shell.world.facility_defs.values():
		for ingredient in definition["materials"]: stock[ingredient] = 100
	shell.world.grant_scaffold(stock)
	for ident in ["golden_wheat","pasture_grass","resin_tree"]:
		var definition: Dictionary = shell.world.crop_defs[ident]
		var shape: Array = definition["footprint"]
		for stage in range(4):
			var cell := Vector2i(3+stage*3,2 if ident == "golden_wheat" else 4)
			if ident == "resin_tree": cell = Vector2i([2,6,10,13][stage],9)
			for dy in range(int(shape[1])):
				for dx in range(int(shape[0])):
					shell.world.clock.ap = 24
					verify(shell.world.till(cell+Vector2i(dx,dy))["ok"],"till %s/%d"%[ident,stage])
			shell.world.clock.ap = 24
			var planted: Dictionary = shell.world.plant(cell,ident)
			verify(planted["ok"],"plant %s/%d"%[ident,stage])
			if not planted["ok"]: continue
			var crop: Dictionary = shell.world.crops[int(planted["uid"])]
			crop["progress"] = ceili(float(int(definition["days"])*100)*stage/3.0)
			crop["state"] = "mature" if stage == 3 else "growing"
	for item in [["woodshop",Vector2i(2,12)],["fish_pond",Vector2i(7,14)],["compost_bin",Vector2i(12,12)]]:
		shell.world.clock.ap = 24
		verify(shell.world.build_facility(item[1],item[0])["ok"],"build "+item[0])
	# L-shore test geometry is explicit fixture data, not a naturally generated farm.
	for y in range(14,17):
		for x in range(14,17): shell.world.grid.terrain[y][x-shell.world.grid.origin_x] = "grass"
	shell.terrain.refresh_all()
	shell.trial_environment._mask_stamp = ""
	shell.trial_environment._refresh_shores()
	shell._refresh()
	shell.digest.visible = false
	shell.watch_panel.visible = false

func _capture(profile: String,name: String,center: Vector2,zoom: float) -> void:
	shell.camera.position = shell.projection.ground_to_view(center)
	shell.camera.zoom = Vector2.ONE*zoom
	await _capture_current(profile,name)

func _capture_current(profile: String,name: String) -> void:
	var framing := "各自适合全图取景" if "fit-to-play" in name else "横向同标尺"
	shell.guide_hint.text = "P8.7 A · %s · %s · zoom %.2f · 材料/研究/成长/L岸为夹具"%[profile,framing,shell.camera.zoom.x]
	shell.digest.visible = false
	shell.watch_panel.visible = false
	shell.overlay.queue_redraw()
	shell.camera.force_update_scroll()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	# Validate the actual render target, including delayed Windows non-client changes.
	for attempt in range(4):
		if picture.get_size() == desired_size: break
		root.size += desired_size-picture.get_size()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		picture = root.get_texture().get_image()
	verify(picture.get_size()==desired_size,"actual GPU target dimensions "+name)
	var file := profile+"-"+name+".png"
	verify(picture.save_png(directory+"/"+file)==OK,"write "+file)
	frames.append({"file":file,"size":[picture.get_width(),picture.get_height()],"zoom":shell.camera.zoom.x,
		"viewport":[root.get_visible_rect().size.x,root.get_visible_rect().size.y],"camera":[shell.camera.position.x,shell.camera.position.y],"projection":profile,"depth":shell.projection.depth})

func _finish() -> void:
	var report := FileAccess.open(directory+"/trial.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"fixture":"real till/plant/build; scaffold stock/research/growth and L-shore; isolated saves",
		"sample_user_accepted":false,"world_hash_before":world_hash_before,"world_hash_after":world_hash_after,"frames":frames,"failures":failures},"  "))
	for failure in failures: printerr(failure)
	print("P87 VISUAL PREVIEW %s: %d frames"%["OK" if failures.is_empty() else "FAILED",frames.size()])
	quit(0 if failures.is_empty() else 1)
