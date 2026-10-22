extends SceneTree
## Real GPU/game shell; staged fixtures and isolated slots, never user saves.
const Shell := preload("res://scripts/farming/p8/p87_scene.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const IDS := ["golden_wheat","fast_fir","resin_tree","wood_decay_mushroom","pasture_grass","honeybell_bush","oilseed_flower","mulberry_tree","duckweed","reed"]
var directory := "res://.art-work/p109/plant-preview"
var shell
var frames: Array[Dictionary] = []
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview-dir="): directory = arg.trim_prefix("--preview-dir=")
	DirAccess.make_dir_recursive_absolute(directory)
	shell = Shell.new()
	shell.store = Store.new(directory+"/slots-%d"%Time.get_ticks_usec())
	shell.settings = shell.settings.get_script().new(directory+"/settings.cfg",0.1)
	root.add_child(shell)
	await process_frame
	shell._new(1,false)
	shell.world.journal["guide"]["dismissed"] = true
	shell.world.preferences["tutorial"]["enabled"] = false
	shell._close_page()
	shell.digest.visible = false
	shell.expanded = true
	await shell._prepare_preview(directory)
	shell.set_process(false)
	# Five catalogs, two species each; all land rows remain on grass.
	for page in range(5):
		shell.world.crops.clear()
		for row in range(2):
			var ident: String = IDS[page*2+row]
			var definition: Dictionary = shell.world.crop_defs[ident]
			for stage in range(4):
				var progress := ceili(float(int(definition["days"])*100)*stage/3.0)
				if ident == "oilseed_flower" and stage == 2: progress = 500
				_put(ident,Vector2i(2+stage*4,3+row*5),"mature" if stage == 3 else "growing",progress)
			if ident == "oilseed_flower": _put(ident,Vector2i(18,3+row*5),"growing",300)
		shell.invalidate_projection_bounds()
		shell.camera.position = shell.projection.ground_to_view(Vector2(650,380))
		shell.camera.zoom = Vector2.ONE*1.1
		await _pair("stages-%d"%(page+1))
	# Dense real planting operations; stage assignments only are fixture data.
	shell._new(2,false)
	shell.world.preferences["tutorial"]["enabled"] = false
	for project in shell.world.research.project_defs(): shell.world.research.state["completed"].append(project)
	var stock := {"raw_wood":100,"raw_stone":100,"twig":100,"wood_plank":100}
	for definition in shell.world.crop_defs.values():
		stock[definition["seed"]] = 20
		for ingredient in definition["inputs"]: stock[ingredient] = 100
	shell.world.grant_scaffold(stock)
	for ident in IDS:
		if ident in ["duckweed","reed"]: continue
		var definition: Dictionary = shell.world.crop_defs[ident]
		for index in range(6 if ident in ["golden_wheat","pasture_grass"] else 2):
			var cell := _free_cell(definition["footprint"])
			if cell.x < 0: _fail("no cell for "+ident); return
			shell.world.clock.ap = 24
			for dy in range(definition["footprint"][1]):
				for dx in range(definition["footprint"][0]): shell.world.till(cell+Vector2i(dx,dy))
			var planted: Dictionary = shell.world.plant(cell,ident)
			if not planted["ok"]: _fail(str(planted)); return
			var crop: Dictionary = shell.world.crops[int(planted["uid"])]
			crop["state"] = "mature" if index%2 == 0 else "growing"
			crop["progress"] = ceili(float(int(definition["days"])*100)*0.6)
	var built: Dictionary = shell.world.build_facility(_free_cell([2,2]),"woodshop")
	if not built["ok"]: _fail(str(built)); return
	shell._close_page()
	shell.digest.visible = false
	shell.invalidate_projection_bounds()
	for zoom in [1.0,2.0]:
		shell.camera.position = shell.projection.ground_to_view(Vector2(510,190))
		shell.camera.zoom = Vector2.ONE*zoom
		await _pair("mixed-%.1f"%zoom)
	# Real P10.6 fish fence + aquatic planting zone, not the retired fish_pond.
	shell._new(3,false)
	shell.world.preferences["tutorial"]["enabled"] = false
	preload("res://scripts/farming/tests/p107_fixture.gd").unlock(shell.world)
	shell.world.grant_scaffold(stock)
	shell.world.primeval_stones = 1000
	for project in shell.world.research.project_defs(): shell.world.research.state["completed"].append(project)
	var fence_cells: Array[Vector2i] = []
	var zone_cells: Array = []
	for y in range(14,17):
		for x in range(2,6):
			fence_cells.append(Vector2i(x,y))
			zone_cells.append("%d,%d"%[x,y])
	var fenced: Dictionary = shell.world.water.build_fence(fence_cells,0)
	if not fenced["ok"]: _fail(str(fenced)); return
	shell.world.end_day()
	var station: Dictionary = shell.world.build_facility(Vector2i(2,14),"aquatic_crop_station")
	if not station["ok"]: _fail(str(station)); return
	var zone: Dictionary = shell.world.ranch.create_zone("aqua_planting",zone_cells,"植物美术预览")
	if not zone["ok"]: _fail(str(zone)); return
	var positions := [Vector2i(4,14),Vector2i(5,14),Vector2i(4,15),Vector2i(5,15),Vector2i(2,16),Vector2i(3,16),Vector2i(4,16),Vector2i(5,16)]
	for i in range(2):
		var ident: String = ["duckweed","reed"][i]
		for stage in range(4):
			var definition: Dictionary = shell.world.crop_defs[ident]
			shell.world.clock.ap = 24
			var planted: Dictionary = shell.world.plant(positions[i*4+stage],ident)
			if not planted["ok"]: _fail(str(planted)); return
			var crop: Dictionary = shell.world.crops[int(planted["uid"])]
			crop["state"] = "mature" if stage == 3 else "growing"
			crop["progress"] = ceili(float(int(definition["days"])*100)*stage/3.0)
	shell.camera.position = shell.projection.ground_to_view(Vector2(260,975))
	shell.camera.zoom = Vector2.ONE*2.8
	shell._close_page()
	shell.digest.visible = false
	shell.invalidate_projection_bounds()
	await _pair("water")
	shell._show_settings()
	await _frame("settings.png")
	var record := FileAccess.open(directory+"/frames.json",FileAccess.WRITE)
	record.store_string(JSON.stringify({"fixture":"synthetic staged catalogs; dense land and fenced water use real planting with assigned stages; isolated saves", "frames":frames},"  "))
	print("P109 PLANT PREVIEW OK: %d GPU frames"%frames.size())
	quit()
func _put(ident: String,cell: Vector2i,state: String,progress: int) -> void:
	var uid: int = shell.world.crops.size()+1
	shell.world.crops[uid] = {"uid":uid,"crop_id":ident,"origin":[cell.x,cell.y],"state":state,"progress":progress,"harvest_count":0}
func _free_cell(shape: Array) -> Vector2i:
	for y in range(1,6):
		for x in range(1,14):
			var valid := true
			for dy in range(shape[1]):
				for dx in range(shape[0]):
					var cell := Vector2i(x+dx,y+dy)
					if not shell.world.grid.can_till(cell)["ok"] or shell.world._source_cells.has(cell): valid = false
			if valid: return Vector2i(x,y)
	return Vector2i(-1,-1)
func _pair(name: String) -> void:
	var before: Dictionary = shell.world.to_snapshot().duplicate(true)
	for profile in ["legacy","p109"]:
		if not shell.configure_plant_profile(profile)["ok"]: _fail("profile "+profile); return
		await _frame(name+"-"+profile+".png")
	if shell.world.to_snapshot() != before: _fail("profile switch changed world")
func _frame(name: String) -> void:
	shell.overlay.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_png(directory+"/"+name) != OK: _fail("save "+name); return
	frames.append({"file":name,"size":[image.get_width(),image.get_height()],"profile":shell.plant_profile,"zoom":shell.camera.zoom.x})
func _fail(message: String) -> void:
	printerr("P109 PLANT PREVIEW FAILED: "+message)
	quit(1)
