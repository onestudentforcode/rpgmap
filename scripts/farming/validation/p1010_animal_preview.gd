extends SceneTree
## P10.10 动物视野叠层游戏内截图验收：真实购买入册，叠层开/关成对截图。
const Shell := preload("res://scripts/farming/p8/p87_scene.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
var directory := "res://.art-work/p1010/preview"
var shell

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview-dir="): directory = arg.trim_prefix("--preview-dir=")
	DirAccess.make_dir_recursive_absolute(directory)
	shell = Shell.new()
	shell.store = Store.new(directory + "/slots-%d" % Time.get_ticks_usec())
	shell.settings = shell.settings.get_script().new(directory + "/settings.cfg", 0.1)
	root.add_child(shell)
	await process_frame
	shell._new(1, false)
	shell.world.journal["guide"]["dismissed"] = true
	shell.world.preferences["tutorial"]["enabled"] = false
	shell._close_page()
	shell.digest.visible = false
	shell.expanded = true
	await shell._prepare_preview(directory)
	shell.set_process(false)
	for project in shell.world.research.project_defs():
		shell.world.research.state["completed"].append(project)
	for event in shell.world.progress.config["events"]:
		if not shell.world.progress.state["events"].any(func(row): return row.get("id") == event["id"]):
			shell.world.progress.state["events"].append({"id": event["id"], "seq": shell.world.progress.state["next_seq"], "at": 0})
			shell.world.progress.state["next_seq"] += 1
	shell.world.grant_scaffold({"raw_wood": 400, "raw_stone": 400, "twig": 200, "wood_plank": 200, "iron_ingot": 100, "clay": 100})
	var base := Vector2i(-1, -1)
	for y in range(2, 16):
		for x in range(2, 16):
			var ok := true
			for dy in range(4):
				for dx in range(4):
					var cell := Vector2i(x+dx, y+dy)
					if not shell.world.grid.is_terrain_tillable(cell) or not shell.world.source_at(cell).is_empty() or not shell.world.facility_at(cell).is_empty():
						ok = false
			if ok: base = Vector2i(x, y); break
		if base.x >= 0: break
	if base.x < 0:
		printerr("P1010 PREVIEW FAILED: no space")
		quit(1)
		return
	for dy in range(-1, 6):
		for dx in range(-1, 6):
			var fc := base + Vector2i(dx, dy)
			if shell.world.grid.in_bounds(fc.x, fc.y) and shell.world.grid.is_terrain_tillable(fc):
				shell.world.rooms.state["floors"][shell.world.rooms.key(fc)] = "ordinary"
	for entry in [["small_bed", base], ["small_bed", base+Vector2i(1,0)], ["feed_trough", base+Vector2i(2,0)]]:
		var b: Dictionary = shell.world.build_facility(entry[1], String(entry[0]))
		if not b.get("ok", false): printerr("P1010 PREVIEW: %s failed %s" % [entry[0], b.get("reason","")])
	for candidate in [[0,2],[1,2],[2,2],[0,3],[1,3],[2,3],[3,2],[3,3]]:
		var c := base + Vector2i(candidate[0], candidate[1])
		if shell.world.build_facility(c, "pen").get("ok", false): break
	var zone_cells: Array = []
	for dy in range(4):
		for dx in range(4):
			zone_cells.append("%d,%d" % [base.x+dx, base.y+dy])
	var zone_result: Dictionary = shell.world.ranch.create_zone("nursery", zone_cells)
	var buy: Dictionary = shell.world.ranch.purchase(int(zone_result.get("zone_uid", 0)), "rock_mole", 4)
	if not buy.get("ok", false): printerr("P1010 PREVIEW: purchase failed %s" % buy.get("reason",""))
	shell.invalidate_projection_bounds()
	shell.camera.position = shell.projection.ground_to_view(Vector2(base + Vector2i(1, 2)) * 64.0)
	shell.camera.zoom = Vector2.ONE * 1.35
	await _frame("animals-on.png")
	shell.animal_view.enabled = false
	await _frame("animals-off.png")
	shell.animal_view.enabled = true
	print("P1010 ANIMAL PREVIEW OK: roster=%d shots saved" % shell.world.ranch.state["animals"].size())
	quit(0)

func _frame(name: String) -> void:
	shell.overlay.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory + "/" + name)
