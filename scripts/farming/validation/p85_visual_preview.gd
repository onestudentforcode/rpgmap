extends SceneTree
## Screenshot-only fixture: real P8 shell, synthetic plants, isolated workspace slots.
const Shell := preload("res://scripts/farming/p8/p8_scene.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var shell := Shell.new()
	var directory := "res://.art-work/p85-visual-preview"
	DirAccess.make_dir_recursive_absolute(directory)
	shell.store = Store.new(directory + "/slots-%d" % Time.get_ticks_usec())
	shell.settings = shell.settings.get_script().new(directory + "/settings.cfg", 0.1)
	root.add_child(shell)
	await process_frame
	shell._new(1, false)
	shell.world.journal["guide"]["dismissed"] = true
	shell._close_page()
	shell.digest.visible = false
	shell.expanded = true
	root.size = Vector2i(1920,1080)
	await process_frame
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
	shell.camera.position = Vector2(650,360)
	shell.camera.zoom = Vector2.ONE * 1.3
	shell.selected = Vector2i(15,4)
	shell.overlay.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(directory + "/pilot.png")
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
		shell.camera.position = Vector2(area.position + area.size/2) * 64.0
		shell.camera.zoom = Vector2.ONE * 1.6
		shell.selected = area.position
		shell.overlay.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		error = maxi(error,root.get_texture().get_image().save_png(directory + "/negative-land.png"))
		break
	print("P85 VISUAL PREVIEW OK" if error == OK else "P85 VISUAL PREVIEW FAILED")
	quit(0 if error == OK else 1)
