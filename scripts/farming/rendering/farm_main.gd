extends Node2D
## Phase 1 主农场场景（phase-01）：可开垦、可交互、可存档的经营地图。
## 地形数据只读烘焙产物；渲染增量更新；存档纯逻辑数据（素材替换零影响）。
##
## 运行：play.bat farm [--farmtest] [--farm-shots=DIR] [--fresh]
##   左键 开垦/恢复 · F5 存档 · F9 读档 · WASD/方向键 平移 · 滚轮 缩放

const FarmData := preload("res://scripts/farming/core/farm_data.gd")
const LandGrid := preload("res://scripts/farming/core/grid/land_grid.gd")
const FarmTerrainRenderer := preload("res://scripts/farming/rendering/terrain_renderer.gd")
const FarmCamera := preload("res://scripts/farming/rendering/farm_camera.gd")

const MAP_ID := "farm_01"
const TILE := 64
const SAVE_PATH := "user://farm_phase01_save.json"
const SAVE_PATH_TEST := "user://farm_phase01_save_test.json"

var grid: LandGrid
var renderer: FarmTerrainRenderer

var _cam: Camera2D
var _cam_ctrl: FarmCamera
var _overlay_marks: Node2D
var _hl: Node2D
var _hud: Label
var _hud_info: Label
var _hover := Vector2i(-1, -1)
var _save_path := SAVE_PATH
var _terrains_by_id := {}
var _farmtest_got: Array[Vector2i] = []


func _sink_cells(cells: Array[Vector2i]) -> void:
	_farmtest_got = cells


func _ready() -> void:
	var terrains := FarmData.load_terrains()
	var map := FarmData.load_map(MAP_ID)
	if terrains.is_empty() or map.is_empty():
		get_tree().quit(1)
		return
	_terrains_by_id = FarmData.terrain_by_id(terrains)

	var w := int(map["size"][0])
	var h := int(map["size"][1])
	var tillable := {}
	for t in terrains["terrains"]:
		tillable[t["id"]] = t["tillable"]

	grid = LandGrid.new()
	grid.setup(w, h, map["grid"], tillable)
	renderer = FarmTerrainRenderer.new()
	if not renderer.build(self, grid, terrains):
		get_tree().quit(1)
		return
	grid.cells_changed.connect(renderer.update_cells)
	grid.cells_changed.connect(_on_cells_changed)

	_setup_camera(w, h)
	_setup_overlay(w, h)

	var args := OS.get_cmdline_user_args()
	if "--farmtest" in args:
		_save_path = SAVE_PATH_TEST
		_run_farmtest.call_deferred()
	else:
		if "--fresh" not in args:
			_load(true)
	for a in args:
		if a.begins_with("--farm-shots="):
			_run_shots(a.get_slice("=", 1))
	_update_hover(get_global_mouse_position())
	_update_hud()


# ------------------------------------------------------------ 搭建

func _setup_camera(w: int, h: int) -> void:
	_cam = Camera2D.new()
	_cam.position = Vector2(w, h) * (TILE * 0.5)
	add_child(_cam)
	_cam.make_current()
	_cam_ctrl = FarmCamera.new()
	_cam_ctrl.name = "FarmCamera"
	_cam_ctrl.setup(_cam, Vector2i(w, h), TILE)
	_cam_ctrl.zoom_set.connect(func(_z: float) -> void: _update_hud())
	add_child(_cam_ctrl)


func _setup_overlay(w: int, h: int) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_hud = _make_label()
	_hud.position = Vector2(8, 6)
	_hud.text = "灵田·壹号（Phase 1）· 左键 开垦/恢复 · F5 存档 · F9 读档 · WASD 平移 · 滚轮 缩放"
	layer.add_child(_hud)

	_hud_info = _make_label()
	_hud_info.position = Vector2(8, 28)
	layer.add_child(_hud_info)

	_overlay_marks = Node2D.new()
	_overlay_marks.name = "OccupiedMarks"
	_overlay_marks.z_index = 6
	_overlay_marks.draw.connect(_draw_occupied)
	add_child(_overlay_marks)

	_hl = Node2D.new()
	_hl.name = "CellHighlight"
	_hl.z_index = 5
	_hl.draw.connect(_draw_highlight)
	add_child(_hl)


func _make_label() -> Label:
	var l := Label.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "sans-serif"])
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


# ------------------------------------------------------------ 交互

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(get_global_mouse_position())
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_act_on(_hover)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			_save()
		elif event.keycode == KEY_F9:
			_load(false)


func _act_on(cell: Vector2i) -> void:
	var chk: Dictionary
	if grid.state_at(cell) == LandGrid.State.TILLED:
		chk = grid.untill(cell)
	else:
		chk = grid.till(cell)
	if chk["ok"]:
		_flash("已开垦" if grid.state_at(cell) == LandGrid.State.TILLED else "已恢复为未开垦", true)
	else:
		_flash(_reason_text(chk["reason"]), false)


func _update_hover(world: Vector2) -> void:
	var c := Vector2i(floori(world.x / float(TILE)), floori(world.y / float(TILE)))
	if c != _hover:
		_hover = c
		if _hl != null:
			_hl.queue_redraw()
		_update_hud()


func _on_cells_changed(_cells: Array[Vector2i]) -> void:
	if _overlay_marks != null:
		_overlay_marks.queue_redraw()
	_update_hud()


func _draw_highlight() -> void:
	if grid != null and grid.in_bounds(_hover.x, _hover.y):
		_hl.draw_rect(Rect2(Vector2(_hover) * TILE, Vector2.ONE * TILE),
				Color(1.0, 0.9, 0.35, 0.95), false, 2.0)


func _draw_occupied() -> void:
	if grid == null:
		return
	for c in grid.occupied_cells():
		_overlay_marks.draw_rect(Rect2(Vector2(c) * TILE, Vector2.ONE * TILE),
				Color(0.85, 0.15, 0.15, 0.35), true)
		_overlay_marks.draw_rect(Rect2(Vector2(c) * TILE, Vector2.ONE * TILE),
				Color(0.9, 0.25, 0.2, 0.9), false, 2.0)


func _update_hud() -> void:
	if _hud_info == null or grid == null:
		return
	_hud_info.modulate = Color(0.95, 0.92, 0.8)
	var text := ""
	if grid.in_bounds(_hover.x, _hover.y):
		var tid := grid.terrain_at(_hover)
		var tname: String = _terrains_by_id.get(tid, {}).get("name", tid)
		text = "(%d,%d) %s · %s" % [_hover.x, _hover.y, tname, LandGrid.STATE_NAMES[grid.state_at(_hover)]]
	text += "  |  已开垦 %d · 占用 %d · zoom %.2f" % [
		grid.cells_with_state(LandGrid.State.TILLED).size(),
		grid.occupied_cells().size(),
		_cam.zoom.x if _cam != null else 1.0,
	]
	_hud_info.text = text


func _flash(msg: String, ok: bool) -> void:
	_hud_info.modulate = Color(0.95, 0.4, 0.35) if not ok else Color(0.6, 0.95, 0.6)
	_hud_info.text = msg


func _reason_text(reason: String) -> String:
	if reason.begins_with("terrain_not_tillable:"):
		var tid := reason.get_slice(":", 1)
		return "不可开垦：%s（%s）" % [_terrains_by_id.get(tid, {}).get("name", tid), tid]
	if reason.begins_with("not_wild:"):
		return "当前状态不可开垦（%s）" % reason.get_slice(":", 1)
	if reason.begins_with("not_tilled:"):
		return "尚未开垦（%s）" % reason.get_slice(":", 1)
	return {
		"out_of_bounds": "目标越界",
		"occupied": "该格已被占用",
		"planted": "种植中，不可操作",
		"holder_exists": "占用标识已存在",
		"bad_footprint": "非法占地尺寸",
	}.get(reason, "无法操作：%s" % reason.replace("_", " "))


# ------------------------------------------------------------ 存档（逻辑数据 only；Phase 5 换主游戏存档适配层）

func _save() -> void:
	var f := FileAccess.open(_save_path, FileAccess.WRITE)
	if f == null:
		_flash("存档失败：无法写入", false)
		return
	f.store_string(JSON.stringify(grid.to_save(), "\t"))
	f.close()
	_flash("已存档", true)


func _load(silent: bool) -> bool:
	if not FileAccess.file_exists(_save_path):
		if not silent:
			_flash("没有存档", false)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(_save_path))
	if parsed == null or not grid.apply_save(parsed):
		if not silent:
			_flash("存档损坏", false)
		return false
	renderer.refresh_dynamic_all()
	if _overlay_marks != null:
		_overlay_marks.queue_redraw()
	if not silent:
		_flash("已读档", true)
	return true


# ------------------------------------------------------------ 逻辑自测

func _ok(msg: String) -> void:
	print("[ok] %s" % msg)


func _run_farmtest() -> void:
	var fails: Array[String] = []
	var chk: Dictionary = {}
	grid.reset()
	renderer.refresh_dynamic_all()

	# 1. 烘焙数据与注册表
	var terrains := FarmData.load_terrains()
	var map := FarmData.load_map(MAP_ID)
	var ts: Array = terrains["terrains"]
	if int(map["size"][0]) == 20 and int(map["size"][1]) == 14 and ts.size() == 4:
		_ok("烘焙数据：地图 20×14，注册 %d 地形" % ts.size())
	else:
		fails.append("烘焙数据异常")
	var layers_ok := true
	for i in ts.size():
		if int(ts[i]["layer"]) != i:
			layers_ok = false
	if layers_ok and ts[0]["id"] == "grass" and ts[0]["tillable"] \
			and ts[1]["tillable"] and not ts[2]["tillable"] and ts[3]["dynamic"]:
		_ok("注册表：层号 0–3 连续；grass/dirt 可开垦、stone 不可、tilled 动态")
	else:
		fails.append("注册表内容异常")

	# 2. 初始状态：stone→UNAVAILABLE（29 格），其余 WILD（251 格）
	if grid.cells_with_state(LandGrid.State.UNAVAILABLE).size() == 29 \
			and grid.cells_with_state(LandGrid.State.WILD).size() == 251:
		_ok("初始状态：石板 29 格 UNAVAILABLE，其余 251 格 WILD")
	else:
		fails.append("初始状态异常")

	# 3. 渲染层初始：基底 280、dirt 32、stone 29、动态层 0
	var ground_n := renderer.used_count("grass")
	var dirt_n := renderer.used_count("dirt")
	var stone_n := renderer.used_count("stone")
	if ground_n == 280 and dirt_n == 32 and stone_n == 29 \
			and renderer.used_count("tilled") == 0:
		_ok("静态层格数：grass 280 / dirt 32 / stone 29，动态层 0")
	else:
		fails.append("静态层格数异常： %d/%d/%d" % [ground_n, dirt_n, stone_n])

	# 4. 开垦迁移 + 信号携带「变更格∪8邻」（经成员方法接收：lambda 捕获是值拷贝）
	_farmtest_got.clear()
	grid.cells_changed.connect(_sink_cells)
	chk = grid.till(Vector2i(3, 9))
	grid.cells_changed.disconnect(_sink_cells)
	var want := {}
	for dc in [Vector2i.ZERO] + LandGrid.DIRS:
		want[Vector2i(3, 9) + dc] = true
	if chk["ok"] and _farmtest_got.size() == want.size() \
			and _farmtest_got.all(func(c): return want.has(c)):
		_ok("开垦 WILD→TILLED，cells_changed 携带 9 格（自身∪8邻）")
	else:
		fails.append("开垦/信号异常：ok=%s cells=%d" % [str(chk["ok"]), _farmtest_got.size()])

	# 5. 重复开垦拒绝 / 6. 恢复
	if not grid.till(Vector2i(3, 9))["ok"] and grid.untill(Vector2i(3, 9))["ok"] \
			and grid.state_at(Vector2i(3, 9)) == LandGrid.State.WILD:
		_ok("重复开垦拒绝；恢复 TILLED→WILD")
	else:
		fails.append("重复开垦/恢复异常")

	# 7. 石板开垦拒绝 / 8. 越界拒绝
	if not grid.till(Vector2i(15, 8))["ok"] and not grid.till(Vector2i(-1, 0))["ok"]:
		_ok("石板地与越界开垦被拒绝（reason: %s）" % grid.till(Vector2i(15, 8))["reason"])
	else:
		fails.append("非法开垦未被拒绝")

	# 9. 占用：2×2 原子成功
	chk = grid.reserve(Vector2i(2, 11), 2, 2, "h1")
	if chk["ok"] and grid.occupied_cells().size() == 4 \
			and grid.state_at(Vector2i(3, 12)) == LandGrid.State.OCCUPIED:
		_ok("reserve 2×2 成功：4 格 OCCUPIED（prev=WILD）")
	else:
		fails.append("reserve 失败：%s" % chk["reason"])

	# 10. 重叠占用拒绝且原子（无部分占用）
	chk = grid.reserve(Vector2i(3, 11), 2, 2, "h2")
	if not chk["ok"] and grid.occupied_cells().size() == 4:
		_ok("重叠 reserve 拒绝，无部分占用（原子性）")
	else:
		fails.append("重叠 reserve 原子性异常")

	# 11. 占用格开垦拒绝
	if not grid.till(Vector2i(2, 11))["ok"]:
		_ok("OCCUPIED 格开垦被拒绝")
	else:
		fails.append("占用格开垦未被拒绝")

	# 12. 跨地形脚印拒绝（含石板格）
	chk = grid.reserve(Vector2i(14, 8), 2, 2, "h3")
	if not chk["ok"] and chk["reason"].begins_with("terrain_not_tillable") \
			and grid.occupied_cells().size() == 4:
		_ok("跨石板 2×2 reserve 拒绝（原因 terrain_not_tillable，原子）")
	else:
		fails.append("跨地形 reserve 异常")

	# 13. TILLED 上占用 → 释放恢复 TILLED
	grid.till(Vector2i(6, 11))
	grid.till(Vector2i(7, 11))
	chk = grid.reserve(Vector2i(6, 11), 2, 1, "h4")
	var released := grid.release("h4")
	if chk["ok"] and released and grid.state_at(Vector2i(6, 11)) == LandGrid.State.TILLED:
		_ok("TILLED 上占用后释放恢复 TILLED（prev 机制）")
	else:
		fails.append("占用 prev 恢复异常")

	# 14. 动态过渡 atlas：邻接开垦后两侧 tile 均按位掩码更新
	grid.till(Vector2i(4, 9))
	if renderer.dynamic_atlas_cell(Vector2i(4, 9)) == Vector2i(0, 0):
		_ok("单格开垦 tile = atlas_of(0)")
	else:
		fails.append("单格开垦 tile 异常: %s" % renderer.dynamic_atlas_cell(Vector2i(4, 9)))
	grid.till(Vector2i(5, 9))
	if renderer.dynamic_atlas_cell(Vector2i(4, 9)) == Vector2i(2, 0) \
			and renderer.dynamic_atlas_cell(Vector2i(5, 9)) == Vector2i(8, 0):
		_ok("邻接开垦后 tile 更新为 bm=E(2) / bm=W(8)")
	else:
		fails.append("邻接 tile 更新异常: %s / %s" % [
			renderer.dynamic_atlas_cell(Vector2i(4, 9)), renderer.dynamic_atlas_cell(Vector2i(5, 9))])

	# 15. 增量更新：静态层格数不变（未整图重建）
	if renderer.used_count("grass") == 280 and renderer.used_count("dirt") == 32 \
			and renderer.used_count("stone") == 29:
		_ok("全部操作后静态层格数不变（无整图重建）")
	else:
		fails.append("静态层被意外改动")

	# 16. 存档磁盘 roundtrip：save → 复位 → load → 状态/占用逐一恢复
	var before := _dump_states()
	var saved := grid.to_save()
	var f := FileAccess.open(_save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(saved, "\t"))
	f.close()
	grid.reset()
	renderer.refresh_dynamic_all()
	var loaded := _load(true)
	if loaded and _dump_states() == before and grid.holder_cells("h1").size() == 4 \
			and grid.release("h1") and grid.state_at(Vector2i(2, 11)) == LandGrid.State.WILD:
		_ok("存档磁盘 roundtrip：状态/占用逐一恢复，释放后回 WILD")
	else:
		fails.append("存档 roundtrip 异常")

	# 17. 存档纯逻辑：无贴图/atlas/路径字段
	var raw := JSON.stringify(saved)
	if not (raw.contains("png") or raw.contains("atlas") or raw.contains("assets") or raw.contains("res://")):
		_ok("存档内容纯逻辑数据（无贴图引用）")
	else:
		fails.append("存档混入了渲染数据")

	# 18. 空存档 → 默认状态
	var fresh := LandGrid.new()
	fresh.setup(20, 14, map["grid"], _tillable_of(terrains))
	if fresh.apply_save({"schema": 1}) and fresh.cells_with_state(LandGrid.State.WILD).size() == 251:
		_ok("空存档应用 → 全默认（首次进入路径）")
	else:
		fails.append("空存档应用异常")

	# 19. tile 基线
	if renderer.tileset.tile_size == Vector2i(64, 64):
		_ok("tile 尺寸 = 64×64（Phase 0 D1）")
	else:
		fails.append("tile 尺寸异常")

	grid.reset()
	renderer.refresh_dynamic_all()
	if fails.is_empty():
		print("FARMTEST OK")
		get_tree().quit(0)
	else:
		for m in fails:
			print("[fail] %s" % m)
		print("FARMTEST FAIL (%d)" % fails.size())
		get_tree().quit(1)


func _tillable_of(terrains: Dictionary) -> Dictionary:
	var out := {}
	for t in terrains["terrains"]:
		out[t["id"]] = t["tillable"]
	return out


func _dump_states() -> Array:
	var rows := []
	for y in range(grid.height):
		var row := []
		for x in range(grid.width):
			row.append(grid.state_at(Vector2i(x, y)))
		rows.append(row)
	return rows


# ------------------------------------------------------------ 截图留档

func _run_shots(dir: String) -> void:
	if dir.begins_with("res://"):
		dir = ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	# 演示态：连续开垦 5×3 + 占用 2×2（红框）+ 预设 hover 高亮
	grid.reset()
	for y in range(3):
		for x in range(5):
			grid.till(Vector2i(2 + x, 11 + y))
	grid.reserve(Vector2i(10, 11), 2, 2, "demo_shot")
	renderer.refresh_dynamic_all()
	_overlay_marks.queue_redraw()
	_update_hover(Vector2(3.5 * TILE, 11.5 * TILE))
	var shots := [
		["farm01_1_overview_z055.png", Vector2(640, 448), 0.55],
		["farm01_2_dirtpatch_z100.png", Vector2(7.0 * TILE, 3.0 * TILE), 1.0],
		["farm01_3_tilled_z120.png", Vector2(4.5 * TILE, 12.0 * TILE), 1.2],
		["farm01_4_occupied_z140.png", Vector2(11.0 * TILE, 12.0 * TILE), 1.4],
		["farm01_5_stone_yard_z150.png", Vector2(16.0 * TILE, 9.0 * TILE), 1.5],
	]
	for shot in shots:
		_cam.position = shot[1]
		_cam.zoom = Vector2(shot[2], shot[2])
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := dir.path_join(shot[0])
		img.save_png(path)
		print("[shot] %s" % path)
	get_tree().quit(0)
