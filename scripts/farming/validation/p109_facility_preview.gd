extends SceneTree
## P10.9 设施游戏内截图验收：真实GPU外壳中建造代表设施，legacy/p109 成对截图。
const Shell := preload("res://scripts/farming/p8/p87_scene.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const PLACEMENTS := [
	["dispatch_station", Vector2i(2, 2), "east"],
	["small_bed", Vector2i(4, 2), "east"],
	["medium_bed", Vector2i(6, 2), "east"],
	["large_bed", Vector2i(8, 2), "east"],
	["feed_trough", Vector2i(2, 6), "east"],
	["care_table", Vector2i(4, 6), "east"],
	["toy_station", Vector2i(6, 6), "east"],
	["wool_station", Vector2i(8, 6), "east"],
	["silkworm_rack", Vector2i(2, 10), "east"],
	["water_change_station", Vector2i(4, 10), "east"],
	["soothing_station", Vector2i(6, 10), "east"],
	["rock_breaking_yard", Vector2i(9, 10), "east"],
]
var directory := "res://.art-work/p109/facility-preview"
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
	# 阶段事件门槛：把全部事件标记完成（截图夹具数据，不进用户存档）
	for event in shell.world.progress.config["events"]:
		if not shell.world.progress.state["events"].any(func(row): return row.get("id") == event["id"]):
			shell.world.progress.state["events"].append({"id": event["id"], "seq": shell.world.progress.state["next_seq"], "at": 0})
			shell.world.progress.state["next_seq"] += 1
	var stock := {"raw_wood": 200, "raw_stone": 200, "twig": 100, "wood_plank": 100, "clay": 100}
	shell.world.grant_scaffold(stock)
	var built := 0
	var cursor := Vector2i(2, 2)
	for entry in PLACEMENTS:
		var placed := false
		var fp: Array = shell.world.facility_defs[String(entry[0])].get("footprint", [1, 1])
		while cursor.x < 30 and cursor.y < 30:
			var cell := cursor
			cursor += Vector2i(int(fp[0]) + 1, 0)
			if cursor.x >= 30: cursor = Vector2i(2, cursor.y + int(fp[1]) + 1)
			var ok_cell := true
			for dy in range(int(fp[1])):
				for dx in range(int(fp[0])):
					var c := cell + Vector2i(dx, dy)
					if not shell.world.grid.in_bounds(c.x, c.y) or not shell.world.grid.is_terrain_tillable(c) or not shell.world.source_at(c).is_empty():
						ok_cell = false
			if not ok_cell: continue
			for dy in range(int(fp[1])):
				for dx in range(int(fp[0])):
					shell.world.rooms.state["floors"][shell.world.rooms.key(cell + Vector2i(dx, dy))] = "ordinary"
			var result: Dictionary = shell.world.build_facility(cell, String(entry[0]), "east")
			if result.get("ok", false):
				built += 1
				placed = true
				break
			else:
				printerr("P109 FAC PREVIEW: build %s at %s failed: %s" % [entry[0], cell, result.get("reason", "")])
		if not placed: printerr("P109 FAC PREVIEW: no cell for " + String(entry[0]))
	shell.invalidate_projection_bounds()
	shell.camera.position = shell.projection.ground_to_view(Vector2(330, 330))
	shell.camera.zoom = Vector2.ONE * 1.05
	var before: Dictionary = shell.world.to_snapshot().duplicate(true)
	for profile in ["legacy", "p109"]:
		if not shell.configure_facility_profile(profile)["ok"]:
			printerr("P109 FAC PREVIEW FAILED: profile " + profile)
			quit(1)
			return
		await _frame("facilities-%s.png" % profile)
	if shell.world.to_snapshot() != before:
		printerr("P109 FAC PREVIEW FAILED: profile switch changed world")
		quit(1)
		return
	print("P109 FACILITY PREVIEW OK: built %d, shot legacy+p109" % built)
	quit(0)

func _frame(name: String) -> void:
	shell.overlay.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory + "/" + name)
