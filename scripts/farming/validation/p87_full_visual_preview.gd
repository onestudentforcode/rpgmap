extends SceneTree
## Screenshot-only fixture: real P8 shell, synthetic plants, isolated workspace slots.
const Shell := preload("res://scripts/farming/p8/p87_scene.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
var current_shell
var captured_frames: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var shell := Shell.new()
	current_shell = shell
	var directory := "res://.art-work/p87-full-visual-preview"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--p87-full-dir="): directory = argument.trim_prefix("--p87-full-dir=")
	DirAccess.make_dir_recursive_absolute(directory)
	shell.store = Store.new(directory + "/slots-%d" % Time.get_ticks_usec())
	shell.settings = shell.settings.get_script().new(directory + "/settings.cfg", 0.1)
	root.add_child(shell)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--ground-detail="):
			var detail := float(argument.trim_prefix("--ground-detail="))
			for ident in ["grass", "dirt", "stone", "tilled"]:
				shell.terrain.layers[ident].material.set_shader_parameter("surface_detail", detail)
	await process_frame
	shell._new(1, false)
	shell.world.journal["guide"]["dismissed"] = true
	shell._close_page()
	shell.digest.visible = false
	shell.expanded = true
	root.size = Vector2i(1920,1080)
	await process_frame
	await shell._prepare_preview(directory)
	shell._layout()
	var uid := 1
	for i in range(4):
		for ident in ["golden_wheat", "resin_tree"]:
			var y := 2 if ident == "golden_wheat" else 5
			var progress := i * 135 if ident == "golden_wheat" else i * 267
			shell.world.crops[uid] = {"uid":uid,"crop_id":ident,"origin":[2+i*3,y],
				"state":"mature" if i == 3 else "growing","progress":progress,"harvest_count":0}
			uid += 1
	# Test overlapping rows and the retained mature body after a harvest.
	shell.world.crops[uid] = {"uid":uid,"crop_id":"resin_tree","origin":[14,3],
		"state":"regrowing","progress":0,"harvest_count":1}
	shell.world.grant_scaffold({"raw_wood":10,"raw_stone":10})
	var facility_cell := Vector2i(-999,-999)
	for y in range(1,10):
		for x in range(13,18):
			var candidate := Vector2i(x,y)
			var footprint := Rect2i(candidate,Vector2i(2,2))
			var overlaps := false
			for crop in shell.world.crops.values():
				var shape: Array = shell.world.crop_defs[crop["crop_id"]]["footprint"]
				if footprint.intersects(Rect2i(Vector2i(crop["origin"][0],crop["origin"][1]),Vector2i(shape[0],shape[1]))): overlaps = true
			if not overlaps and shell.world.can_build_facility(candidate,"woodshop")["ok"]:
				facility_cell = candidate
				break
		if facility_cell.x != -999: break
	var built: Dictionary = shell.world.build_facility(facility_cell,"woodshop")
	if not built["ok"]:
		printerr("preview facility failed: ",built)
		quit(1)
		return
	shell.camera.position = shell.projection.ground_to_view(Vector2(650,360))
	shell.camera.zoom = Vector2.ONE * 1.3
	shell.selected = Vector2i(15,4)
	shell.overlay.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error := await _save_frame(directory + "/pilot.png")
	shell.invalidate_projection_bounds()
	shell.world.crops.clear()
	var row := 0
	for ident in shell.world.crop_defs:
		var definition: Dictionary = shell.world.crop_defs[ident]
		for stage in range(4):
			uid += 1
			var progress := ceili(float(int(definition["days"])*100)*stage/3.0)
			if ident == "oilseed_flower" and stage == 2: progress = 500
			shell.world.crops[uid] = {"uid":uid,"crop_id":ident,"origin":[2+stage*4,row*2],"state":"mature" if stage == 3 else "growing","progress":progress,"harvest_count":0}
		if ident == "oilseed_flower":
			uid += 1
			shell.world.crops[uid] = {"uid":uid,"crop_id":ident,"origin":[18,row*2],"state":"growing","progress":300,"harvest_count":0}
		row += 1
	shell.camera.position = shell.projection.ground_to_view(Vector2(640,430))
	shell.camera.zoom = Vector2.ONE * 0.9
	shell.overlay.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	error = maxi(error,await _save_frame(directory + "/all-plants.png"))
	shell.invalidate_projection_bounds()
	shell.world.crops.clear()
	shell.world.facilities.clear()
	var facility_index := 0
	for ident in shell.world.facility_defs:
		uid += 1
		shell.world.facilities[uid] = {"uid":uid,"facility_id":ident,
			"origin":[1+(facility_index%5)*4,2+(facility_index/5)*4],
			"batch":{"status":"ready" if facility_index%2 == 0 else "idle"}}
		facility_index += 1
	shell.camera.position = shell.projection.ground_to_view(Vector2(640,430))
	shell.camera.zoom = Vector2.ONE * 0.9
	shell.overlay.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	error = maxi(error,await _save_frame(directory + "/all-facilities.png"))
	shell.build_tool = "woodshop"
	for preview_cell in [Vector2i(0,0),Vector2i(0,14)]:
		shell._hover = preview_cell
		shell.overlay.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		error = maxi(error,await _save_frame(directory + "/build-preview-%d.png" % preview_cell.y))
	shell.build_tool = ""
	# Exercise a real parcel purchase; scaffold money belongs only to this fixture.
	shell.world.primeval_stones = 1000
	for parcel_id in shell.world.land.parcels:
		var parcel: Dictionary = shell.world.land.parcels[parcel_id]
		var area: Rect2i = shell.world.land.rect(parcel["rect"])
		if area.position.x >= 0: continue
		var bought: Dictionary = shell.world.land.buy(parcel_id)
		if not bought["ok"]:
			printerr("preview land failed: ",bought)
			quit(1)
			return
		# Actual negative-x parcels are water, so use a legal pond rather than a tree.
		var pond: Dictionary = shell.world.build_facility(area.position,"fish_pond")
		if not pond["ok"]:
			printerr("preview west pond failed: ",pond)
			quit(1)
			return
		shell.camera.position = shell.projection.ground_to_view(Vector2(area.position + area.size/2) * 64.0)
		shell.camera.zoom = Vector2.ONE * 1.6
		shell.selected = area.position
		shell.overlay.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		error = maxi(error,await _save_frame(directory + "/negative-land.png"))
		break
	# Dense/mixed fixture uses real till/plant/build operations in a fresh slot.
	shell._new(2,false)
	for project in shell.world.research.project_defs(): shell.world.research.state["completed"].append(project)
	var stock := {"raw_wood":100,"raw_stone":100}
	for definition in shell.world.crop_defs.values():
		stock[definition["seed"]] = 20
		for ingredient in definition["inputs"]: stock[ingredient] = 100
	shell.world.grant_scaffold(stock)
	for ident in shell.world.crop_defs:
		var definition: Dictionary = shell.world.crop_defs[ident]
		var shape: Array = definition["footprint"]
		for index in range(6 if ident in ["golden_wheat","pasture_grass"] else 2):
			var cell := _free_cell(shell.world,shape)
			if cell.x < 0:
				printerr("dense fixture: no cell for ",ident)
				quit(1)
				return
			shell.world.clock.ap = 24
			for dy in range(shape[1]):
				for dx in range(shape[0]): shell.world.till(cell+Vector2i(dx,dy))
			var planted: Dictionary = shell.world.plant(cell,ident)
			if not planted["ok"]:
				printerr("dense fixture plant failed: ",planted)
				quit(1)
				return
			var crop: Dictionary = shell.world.crops[int(planted["uid"])]
			crop["state"] = "mature" if index%2 == 0 else "growing"
			crop["progress"] = int(definition["days"])*100 if index%2 == 0 else ceili(float(int(definition["days"])*100)*0.6)
			if ident == "oilseed_flower":
				crop["state"] = "growing"
				crop["progress"] = 300+index*200
	var build_cell := _free_cell(shell.world,[2,2])
	shell.world.clock.ap = 24
	var neighbor: Dictionary = shell.world.build_facility(build_cell,"woodshop")
	if not neighbor["ok"]:
		printerr("dense neighbor failed: ",neighbor)
		quit(1)
		return
	shell.digest.visible = false
	shell.selected = build_cell
	shell._close_page()
	if shell.shade.visible:
		printerr("dense fixture unexpectedly covered by a modal")
		quit(1)
		return
	for zoom in [0.1,1.0,3.0]:
		shell.camera.position = shell.projection.ground_to_view(Vector2(448,180))
		shell.camera.zoom = Vector2.ONE*zoom
		shell.overlay.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		error = maxi(error,await _save_frame(directory+"/dense-%.1f.png" % zoom))
	var before_pan := shell.camera.position
	var before_pan_model := shell.world.to_snapshot()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_MIDDLE
	press.pressed = true
	shell._board_input(press)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	motion.relative = Vector2(-60,-30)
	shell._board_input(motion)
	press.pressed = false
	shell._board_input(press)
	if shell.camera.position == before_pan or shell.world.to_snapshot() != before_pan_model:
		printerr("middle pan did not move camera or mutated the world")
		quit(1)
		return
	await process_frame
	await RenderingServer.frame_post_draw
	error = maxi(error,await _save_frame(directory+"/dense-pan.png"))

	# Full production samples, including UI and a clearly synthetic topology test.
	shell.camera.position = shell.projection.ground_to_view(Vector2(1056,570))
	shell.camera.zoom = Vector2.ONE*2.0
	await _frame(shell,directory+"/resources.png")
	shell._show_build()
	await _frame(shell,directory+"/facility-catalog.png")
	shell._close_page()
	shell._new(3,false)
	shell._close_page()
	shell._side_open = false
	shell._layout()
	shell.digest.visible = false
	for y in range(2,12):
		for x in range(1,13): shell.world.grid.terrain[y][x-shell.world.grid.origin_x] = "grass"
	for y in range(4,9):
		for x in range(4,9): shell.world.grid.terrain[y][x-shell.world.grid.origin_x] = "water"
	for cell in [Vector2i(6,6),Vector2i(4,4),Vector2i(4,5),Vector2i(5,4)]:
		shell.world.grid.terrain[cell.y][cell.x-shell.world.grid.origin_x] = "grass"
	for cell in [Vector2i(3,7),Vector2i(3,8),Vector2i(10,5)]:
		shell.world.grid.terrain[cell.y][cell.x-shell.world.grid.origin_x] = "water"
	shell.terrain.refresh_all()
	shell.trial_environment._mask_stamp = ""
	shell.trial_environment._refresh_shores()
	shell.guide_hint.text = "P8.7 岸线测试夹具 · 四方向、岛屿、凹凸角与孤立水格"
	shell.set_process(false)
	shell.camera.position = shell.projection.ground_to_view(Vector2(420,420))
	shell.camera.zoom = Vector2.ONE
	await _frame(shell,directory+"/shore-topology-1.0.png")
	shell.camera.position = shell.projection.ground_to_view(Vector2(340,370))
	shell.camera.zoom = Vector2.ONE*3.0
	await _frame(shell,directory+"/shore-topology-3.0.png")
	shell._new(1,true)
	shell._close_page()
	shell.world.grant_scaffold({"raw_wood":100,"raw_stone":100})
	var ui_facility: Dictionary = shell.world.build_facility(Vector2i(2,10),"woodshop")
	if not ui_facility["ok"]:
		printerr("UI fixture facility failed: ",ui_facility)
		quit(1)
		return
	var ui_facility_uid := int(shell.world.facility_at(Vector2i(2,10))["uid"])
	for scale_percent in [100,125,150]:
		for side in [false,true]:
			shell._ui_scale = float(scale_percent)/100.0
			shell._side_open = side
			shell._layout()
			shell.camera.zoom = Vector2.ONE
			shell._locate_facility(ui_facility_uid)
			shell.digest.visible = false
			await _frame(shell,directory+"/ui-%d-side-%s.png"%[scale_percent,str(side)])
	var manifest := FileAccess.open(directory+"/frames.json",FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"frames":captured_frames,"fixture":"synthetic staged/dense/shore/UI fixtures; isolated saves","projection":"35 degree production"},"  "))

	print("P87 FULL VISUAL PREVIEW OK" if error == OK else "P87 FULL VISUAL PREVIEW FAILED")
	quit(0 if error == OK else 1)

func _free_cell(world, shape: Array) -> Vector2i:
	for y in range(1,6):
		for x in range(1,14):
			var candidate := Vector2i(x,y)
			var valid := true
			for dy in range(shape[1]):
				for dx in range(shape[0]):
					var cell := candidate+Vector2i(dx,dy)
					if not world.grid.can_till(cell)["ok"] or world._source_cells.has(cell): valid = false
			if valid: return candidate
	return Vector2i(-1,-1)

func _frame(shell, path: String) -> void:
	shell.overlay.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result := await _save_frame(path)
	if result != OK:
		printerr("Cannot save production visual frame: "+path)
		quit(1)

func _save_frame(path: String) -> Error:
	var desired := Vector2i(1920,1080)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shot-size="):
			var parts := argument.trim_prefix("--shot-size=").split("x")
			desired = Vector2i(int(parts[0]),int(parts[1]))
	var picture := root.get_texture().get_image()
	for attempt in range(4):
		if picture.get_size() == desired: break
		root.size += desired-picture.get_size()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		picture = root.get_texture().get_image()
	if picture.get_size() != desired:
		push_error("P87 actual GPU frame dimensions differ from requested viewport")
		return ERR_INVALID_DATA
	var result := picture.save_png(path)
	captured_frames.append({"file":path.get_file(),"size":[picture.get_width(),picture.get_height()],
		"ui_scale_requested":current_shell._ui_scale,"ui_scale_effective":current_shell._effective_ui_scale(),
		"side_open":current_shell._side_open,"zoom":current_shell.camera.zoom.x,"depth":current_shell.projection.depth})
	return result
