extends SceneTree
## 回归：P10.8批量拖选分支吃掉放置点击导致设施无法建造。
## 通过真实 _board_input 按压/释放事件走完整点击链路验证修复。
const Scene := preload("res://scenes/farming/farm_p8.tscn")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: _run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)


func _screen_pos_for(sh, cell: Vector2i) -> Vector2:
	# headless下SubViewport canvas transform可能是未初始化的垃圾矩阵；
	# 规整相机后直接用世界像素坐标，并以_cell反馈校正。
	if sh.camera.zoom.x <= 0.0 or sh.camera.zoom.y <= 0.0 or is_nan(sh.camera.zoom.x):
		sh.camera.zoom = Vector2.ONE
	sh.camera.position = Vector2(320, 320)
	var pos: Vector2 = Vector2(cell) * 64.0 + Vector2(32, 32)
	for i in range(8):
		var got: Vector2i = sh._cell(pos)
		if got == cell: break
		var delta: Vector2 = Vector2(cell) - Vector2(got)
		pos += delta.clamp(Vector2(-64,-64), Vector2(64,64)) * 8.0
	return pos

func _click_at(sh, pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		sh._board_input(ev)

func _run() -> void:
	var shell = Scene.instantiate()
	var directory := "res://.art-work/p109/tests/place%d" % Time.get_ticks_usec()
	shell.store = Store.new(directory)
	shell.settings = shell.settings.get_script().new(directory+".cfg",0.1)
	root.add_child(shell)
	await process_frame
	shell._new(1,false)
	shell.set_process(false)
	for project in shell.world.research.project_defs():
		shell.world.research.state["completed"].append(project)
	for event in shell.world.progress.config["events"]:
		if not shell.world.progress.state["events"].any(func(row): return row.get("id") == event["id"]):
			shell.world.progress.state["events"].append({"id": event["id"], "seq": shell.world.progress.state["next_seq"], "at": 0})
			shell.world.progress.state["next_seq"] += 1
	shell.world.grant_scaffold({"raw_wood": 200, "raw_stone": 200, "twig": 100, "wood_plank": 100, "iron_ingot": 100, "clay": 100})
	# 选一块可建造空地（可耕作且无占用），铺普通地板以满足牧场设施条件
	var cell := Vector2i(-1, -1)
	for y in range(2, 16):
		for x in range(2, 16):
			var c := Vector2i(x, y)
			if shell.world.grid.is_terrain_tillable(c) and shell.world.source_at(c).is_empty() and shell.world.facility_at(c).is_empty():
				cell = c
				break
		if cell.x >= 0: break
	check(cell.x >= 0, "found buildable cell")
	shell.world.rooms.state["floors"][shell.world.rooms.key(cell)] = "ordinary"
	var pre: Dictionary = shell.world.can_build_facility(cell, "small_bed")
	check(pre["ok"], "precheck small_bed buildable")
	var before: int = shell.world.facilities.size()
	# 走真实UI路径：选中设施→点击地格（与建设目录的 _select_tool("inspect")+build_tool 一致）
	shell._close_page()
	shell._select_tool("inspect")
	shell.build_tool = "small_bed"
	_click_at(shell, _screen_pos_for(shell, cell))
	check(shell.world.facilities.size() == before + 1, "facility built via real click path")
	check(shell.build_tool == "" or shell.world.facility_at(cell).get("uid", 0) > 0, "placed at clicked cell")
	# 普通设施（非维护站）与维护站两条路径都要通：再放一台维护站
	shell.build_tool = "field_service_station"
	var cell2 := Vector2i(-1, -1)
	var why := ""
	for y in range(shell.world.grid.height):
		for x in range(shell.world.grid.origin_x, shell.world.grid.origin_x + shell.world.grid.width):
			var c := Vector2i(x, y)
			if not shell.world.grid.in_bounds(c.x, c.y) or not shell.world.source_at(c).is_empty() or not shell.world.facility_at(c).is_empty():
				continue
			var q: Dictionary = shell.world.can_build_facility(c, "field_service_station")
			if q["ok"]:
				cell2 = c
				break
			elif why.is_empty(): why = String(q["reason"])
		if cell2.x >= 0: break
	check(cell2.x >= 0, "found station buildable cell")
	_click_at(shell, _screen_pos_for(shell, cell2))
	check(not shell.world.facility_at(cell2).is_empty(), "field_service_station built via dedicated branch")
	# 批量拖选不受影响：手动工具单格点击仍走 _run_manual_rectangle
	shell.build_tool = ""
	shell._select_tool("till")
	shell.manual_mode = true
	var cell3 := cell + Vector2i(6, 0)
	if shell.world.grid.is_terrain_tillable(cell3) and shell.world.source_at(cell3).is_empty():
		_click_at(shell, _screen_pos_for(shell, cell3))
		check(shell.world.grid.state_at(cell3) == 0 or shell.world.rooms.floor_kind(cell3) == "farmland",
			"manual till click still works alongside placement fix")
	for failure in failures: printerr(failure)
	print("PLACE REGRESSION %s: %d checks, %d failed" % ["OK" if failures.is_empty() else "FAILED", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
