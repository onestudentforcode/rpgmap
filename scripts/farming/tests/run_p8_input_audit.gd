extends SceneTree
## P10.8批量拖选(c331b5a)输入路径审计：批量分支不得吞掉未覆盖模式的释放事件。
## 覆盖：手动单击/拖选（应工作）、委托框选（workforce marks）、手动取消标记单击、
## 未购地块单击打开购买页。所有交互走真实 _board_input 事件链。
const Scene := preload("res://scenes/farming/farm_p8.tscn")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: _run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _screen_pos_for(sh, cell: Vector2i) -> Vector2:
	if sh.camera.zoom.x <= 0.0 or sh.camera.zoom.y <= 0.0 or is_nan(sh.camera.zoom.x):
		sh.camera.zoom = Vector2.ONE
	sh.camera.position = Vector2(320, 320)
	var pos: Vector2 = Vector2(cell) * 64.0 + Vector2(32, 32)
	for i in range(8):
		var got: Vector2i = sh._cell(pos)
		if got == cell: break
		var delta: Vector2 = Vector2(cell) - Vector2(got)
		pos += delta.clamp(Vector2(-64, -64), Vector2(64, 64)) * 8.0
	return pos

func _press(sh, pos: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = pos
	sh._board_input(ev)

func _click_cell(sh, cell: Vector2i) -> void:
	var pos := _screen_pos_for(sh, cell)
	_press(sh, pos, true)
	_press(sh, pos, false)

func _drag_cells(sh, from: Vector2i, to: Vector2i) -> void:
	_press(sh, _screen_pos_for(sh, from), true)
	_press(sh, _screen_pos_for(sh, to), false)

func _empty_grass(sh) -> Vector2i:
	for y in range(2, 20):
		for x in range(2, 20):
			var c := Vector2i(x, y)
			if sh.world.grid.is_terrain_tillable(c) and sh.world.source_at(c).is_empty() \
					and sh.world.facility_at(c).is_empty() and sh.world.instance_at(c).is_empty() \
					and sh.world.rooms.floor_kind(c) == "natural":
				return c
	return Vector2i(-1, -1)

func _run() -> void:
	var shell = Scene.instantiate()
	var directory := "res://.art-work/p109/tests/audit%d" % Time.get_ticks_usec()
	shell.store = Store.new(directory)
	shell.settings = shell.settings.get_script().new(directory+".cfg",0.1)
	root.add_child(shell)
	await process_frame
	shell._new(1,false)
	shell.set_process(false)
	# 1) 手动开垦单击（批量路径）
	var c1 := _empty_grass(shell)
	check(c1.x >= 0, "audit found grass cell")
	shell._select_tool("till")
	shell.manual_mode = true
	shell.notice.text = ""
	_click_cell(shell, c1)
	check(shell.world.rooms.floor_kind(c1) == "farmland", "manual till single click works")
	# 2) 手动拖选批量（1x2）
	var c2 := _empty_grass(shell)
	var c3 := c2 + Vector2i(1, 0)
	check(c2.x >= 0, "audit found drag cells")
	shell.notice.text = ""
	_drag_cells(shell, c2, c3)
	check(shell.world.rooms.floor_kind(c2) == "farmland" and shell.world.rooms.floor_kind(c3) == "farmland",
		"manual till drag rectangle works")
	# 3) 委托模式框选：释放必须落到 apply_rectangle → workforce marks
	var w1 := _empty_grass(shell)
	var w2 := w1 + Vector2i(1, 0)
	check(w1.x >= 0, "audit found workforce cells")
	shell.manual_mode = false
	shell._select_tool("till")
	var marks_before: int = shell.world.workforce.state["marks"].size()
	shell.notice.text = ""
	_drag_cells(shell, w1, w2)
	var marks_after: int = shell.world.workforce.state["marks"].size()
	check(marks_after > marks_before, "workforce rectangle adds marks (release reaches apply_rectangle)")
	# 4) 取消标记是委托工具（v1在手动模式会把cancel/area映射为inspect）。
	# 契约：委托模式拖选 cancel → apply_rectangle → workforce.cancel 撤掉第3步的标记。
	shell.manual_mode = false
	shell._select_tool("cancel")
	check(shell.tool == "cancel", "cancel tool selectable in workforce mode")
	var marks_mid: int = shell.world.workforce.state["marks"].size()
	shell.notice.text = ""
	_drag_cells(shell, w1, w2)
	var marks_cancelled: int = shell.world.workforce.state["marks"].size()
	check(marks_cancelled < marks_mid, "workforce cancel rectangle removes marks (release reaches workforce path)")
	# 5) 未购地块单击：手动工具点击锁地块应打开购地页（_apply_manual 的地块分支）
	var parcel_cell := Vector2i(-1, -1)
	var parcel_id := ""
	for y in range(shell.world.grid.height):
		for x in range(shell.world.grid.origin_x, shell.world.grid.origin_x + shell.world.grid.width):
			var c := Vector2i(x, y)
			var pid: String = shell.world.land.at(c)
			if not pid.is_empty() and not shell.world.land.contains(c):
				parcel_cell = c
				parcel_id = pid
				break
		if parcel_cell.x >= 0: break
	if parcel_cell.x >= 0:
		shell.manual_mode = true
		shell._select_tool("till")
		shell._close_page()
		shell.notice.text = ""
		_click_cell(shell, parcel_cell)
		check(shell._context == "land", "manual click on locked parcel opens land purchase page")
	else:
		check(true, "no locked parcel on map (skipped)")
	for failure in failures: printerr(failure)
	print("INPUT AUDIT %s: %d checks, %d failed" % ["OK" if failures.is_empty() else "FAILED", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
