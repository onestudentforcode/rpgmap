extends Node2D
## Phase 0.4 最小拼接验证场景（master-plan 任务 0.4 / phase-00 §5）。
## 验证目标：无缝平铺、地形过渡、网格坐标↔显示一致、点击定位、Sprite 锚点与遮挡。
##
## 运行：play.bat farm [--farmtest] [--farm-shots=DIR]
##   --farmtest        逻辑自测（断言含相机平移 + 非整数缩放下的坐标换算）
##   --farm-shots=DIR  截图留档（窗口模式）
##
## 相机语义（Godot 4）：cam.zoom ∈ [0.5, 2.0]，2.0 = 放大 2×，0.5 = 缩小一半出全景。

const FarmMap := preload("res://scripts/farming/rendering/farm_phase00_map.gd")

const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0
const ZOOM_STEP := 1.15
const PAN_SPEED := 480.0

var _ground: TileMapLayer
var _transition: TileMapLayer
var _ysort: Node2D
var _tileset: TileSet
var _tall: Sprite2D
var _seed0: Sprite2D

var _cam: Camera2D
var _hl: Node2D
var _hud: Label
var _hud_hover: Label
var _hover := Vector2i(-1, -1)
var _crops: Dictionary = {}  # Vector2i -> Sprite2D
var _tex_crop: Texture2D
var _tex_tall: Texture2D
var _tex_shadow: Texture2D


func _ready() -> void:
	var built: Dictionary = FarmMap.build(self)
	if built.is_empty():
		get_tree().quit(1)
		return
	_ground = built["ground"]
	_transition = built["transition"]
	_ysort = built["ysort"]
	_tileset = built["tileset"]

	_tex_crop = FarmMap.load_texture("assets/farming/crops/_placeholder/stage_0.png")
	_tex_tall = FarmMap.load_texture("assets/farming/crops/_placeholder/tall_stone.png")
	_tex_shadow = FarmMap.load_texture("assets/farming/crops/_placeholder/shadow_ellipse.png")

	_setup_camera()
	_setup_overlay()
	_tall = _place_object(_tex_tall, Vector2i(6, 4))   # 固定高物体：验遮挡
	_seed0 = _place_object(_tex_crop, Vector2i(4, 3))  # 初始幼苗：直观可见锚点
	_update_hover(get_global_mouse_position())

	var args := OS.get_cmdline_user_args()
	if "--farmtest" in args:
		_run_farmtest.call_deferred()
	for a in args:
		if a.begins_with("--farm-shots="):
			_run_shots(a.get_slice("=", 1))


# ------------------------------------------------------------ 相机与输入

func _setup_camera() -> void:
	_cam = Camera2D.new()
	_cam.position = FarmMap.cell_center(4, 3)
	add_child(_cam)
	_cam.make_current()


func _process(_delta: float) -> void:
	if _cam == null:
		return
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_physical_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		dir.x += 1.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	_cam.position += dir * (PAN_SPEED / _cam.zoom.x) * _delta
	_clamp_camera()


func _clamp_camera() -> void:
	# 视口大于地图时不硬钳中心（允许露出图外底色）；小于地图时锁定边界
	var vs := get_viewport().get_visible_rect().size
	var half := vs * 0.5 / _cam.zoom.x
	var map_px := Vector2(FarmMap.MAP_W, FarmMap.MAP_H) * FarmMap.TILE
	var lo := Vector2(minf(half.x, map_px.x * 0.5), minf(half.y, map_px.y * 0.5))
	_cam.position.x = clampf(_cam.position.x, lo.x, map_px.x - lo.x)
	_cam.position.y = clampf(_cam.position.y, lo.y, map_px.y - lo.y)


func _unhandled_input(event: InputEvent) -> void:
	if _cam == null:
		return
	if event is InputEventMouseMotion:
		_update_hover(get_global_mouse_position())
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_toggle_crop(_hover)
			MOUSE_BUTTON_WHEEL_UP:
				_set_zoom(_cam.zoom.x * ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				_set_zoom(_cam.zoom.x / ZOOM_STEP)


func _set_zoom(z: float) -> void:
	_cam.zoom = Vector2(clampf(z, ZOOM_MIN, ZOOM_MAX), clampf(z, ZOOM_MIN, ZOOM_MAX))
	_update_hud()


# ------------------------------------------------------------ 物件与交互

func _place_object(tex: Texture2D, cell: Vector2i) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = FarmMap.cell_bottom_center(cell.x, cell.y)
	s.offset = Vector2(0.0, -tex.get_height() * 0.5)  # 底部中心锚点（美术规范 §4.6）
	_ysort.add_child(s)
	return s


func _toggle_crop(cell: Vector2i) -> void:
	if not FarmMap.in_bounds(cell.x, cell.y):
		return
	if _crops.has(cell):
		_crops[cell].queue_free()
		_crops.erase(cell)
	else:
		var s := _place_object(_tex_crop, cell)
		var shadow := Sprite2D.new()
		shadow.texture = _tex_shadow
		shadow.position = Vector2(0.0, -4.0)
		shadow.z_index = -1  # 接触阴影独立贴片，垫在植株下（不烘焙进 Sprite）
		s.add_child(shadow)
		_crops[cell] = s
	_update_hud()


# ------------------------------------------------------------ Overlay

func _setup_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_hud = _make_label()
	_hud.position = Vector2(8, 6)
	_hud.text = "Phase00 拼接验证 · tile=64（D1 草案）· WASD/方向键 平移 · 滚轮 缩放 0.5×–2.0× · 左键 放置/移除占位作物"
	layer.add_child(_hud)

	_hud_hover = _make_label()
	_hud_hover.position = Vector2(8, 28)
	layer.add_child(_hud_hover)

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


func _update_hover(world: Vector2) -> void:
	var c := FarmMap.world_to_cell(world)
	if c != _hover:
		_hover = c
		if _hl != null:
			_hl.queue_redraw()
		_update_hud()


func _draw_highlight() -> void:
	if FarmMap.in_bounds(_hover.x, _hover.y):
		_hl.draw_rect(Rect2(Vector2(_hover) * FarmMap.TILE, Vector2.ONE * FarmMap.TILE),
				Color(1.0, 0.9, 0.35, 0.95), false, 2.0)


func _update_hud() -> void:
	if _hud_hover == null or _cam == null:
		return
	_hud_hover.text = "hover=(%d,%d)  zoom=%.2f  crops=%d" % [
		_hover.x, _hover.y, _cam.zoom.x, _crops.size(),
	]


# ------------------------------------------------------------ 逻辑自测

func _ok(msg: String) -> void:
	print("[ok] %s" % msg)


func _run_farmtest() -> void:
	var fails: Array[String] = []

	# 1. tile 基线（D1 草案 64×64）
	if _tileset.tile_size == Vector2i(64, 64):
		_ok("tile 尺寸 = 64×64（D1 草案）")
	else:
		fails.append("tile 尺寸错误: %s" % [str(_tileset.tile_size)])

	# 2. 图层内容与地图数据一致
	var ground_n := _ground.get_used_cells().size()
	if ground_n == FarmMap.MAP_W * FarmMap.MAP_H:
		_ok("草地满铺 %d 格" % ground_n)
	else:
		fails.append("草地格数错误: %d" % ground_n)
	var dirt_n := 0
	for y in range(FarmMap.MAP_H):
		for x in range(FarmMap.MAP_W):
			if FarmMap.is_dirt(x, y):
				dirt_n += 1
	var trans_n := _transition.get_used_cells().size()
	if trans_n == dirt_n and dirt_n == 23:
		_ok("泥土过渡格数 = %d，与地图泥土格一致" % dirt_n)
	else:
		fails.append("过渡格数 %d ≠ 泥土格数 %d" % [trans_n, dirt_n])

	# 3. 位掩码抽查：孤立泥岛=全草邻 0；区块内部=255；左上外角=E|S|SE=38
	var cases := [
		[Vector2i(6, 8), 0, "孤立泥岛"],
		[Vector2i(4, 3), 255, "区块内部"],
		[Vector2i(3, 2), FarmMap.BIT.E | FarmMap.BIT.S | FarmMap.BIT.SE, "左上外角"],
	]
	for c in cases:
		var cell: Vector2i = c[0]
		var want: int = c[1]
		var got := FarmMap.bitmask(cell.x, cell.y)
		if got == want:
			_ok("位掩码 %s(%d,%d) = %d" % [c[2], cell.x, cell.y, got])
		else:
			fails.append("位掩码 %s(%d,%d) = %d，期望 %d" % [c[2], cell.x, cell.y, got, want])

	# 4. 过渡 atlas 覆盖：每个在用位掩码都有 tile（数据级无裂缝）
	var src: TileSetAtlasSource = _tileset.get_source(1)
	var missing := 0
	for y in range(FarmMap.MAP_H):
		for x in range(FarmMap.MAP_W):
			if FarmMap.is_dirt(x, y):
				if not src.has_tile(FarmMap.atlas_of(FarmMap.bitmask(x, y))):
					missing += 1
	if missing == 0:
		_ok("全部泥土位掩码均有 atlas tile（无数据级裂缝）")
	else:
		fails.append("缺少 %d 个位掩码 tile" % missing)

	# 5. Sprite 底部中心锚点：格底边中点，offset 上移半高
	var probe := Vector2i(5, 7)
	_toggle_crop(probe)
	var s: Sprite2D = _crops.get(probe)
	if s != null \
			and s.global_position.distance_to(FarmMap.cell_bottom_center(probe.x, probe.y)) < 0.001 \
			and absf(s.offset.y + _tex_crop.get_height() * 0.5) < 0.001:
		_ok("Sprite 底部中心锚点对齐格底边中点")
	else:
		fails.append("锚点未对齐: pos=%s offset=%s" % [
			str(s.global_position if s else "<null>"), str(s.offset if s else "<null>")])
	_toggle_crop(probe)

	# 6. 世界→格子换算（含格边界 ±1px）
	var bc := FarmMap.cell_bottom_center(5, 7)
	if FarmMap.world_to_cell(bc + Vector2(0, -1)) == Vector2i(5, 7) \
			and FarmMap.world_to_cell(bc + Vector2(0, 2)) == Vector2i(5, 8):
		_ok("世界→格子换算正确（含格边界）")
	else:
		fails.append("世界→格子换算错误")

	# 7. 相机平移 + 非整数缩放（0.75）下的 canvas 变换往返与边界钳制
	_cam.position = Vector2(123, 77)
	_cam.zoom = Vector2(0.75, 0.75)
	await get_tree().process_frame
	await get_tree().process_frame
	var ct := get_viewport().get_canvas_transform()
	var vs := get_viewport().get_visible_rect().size
	var world_at_center: Vector2 = ct.affine_inverse() * (vs * 0.5)
	if world_at_center.distance_to(_cam.position) < 0.5:
		_ok("缩放 0.75 时屏幕中心↔世界坐标一致（误差<0.5px）")
	else:
		fails.append("相机中心换算误差 %.2fpx" % world_at_center.distance_to(_cam.position))
	var w := FarmMap.cell_bottom_center(3, 5)
	var back: Vector2 = ct.affine_inverse() * (ct * w)
	if back.distance_to(w) < 0.01:
		_ok("canvas 变换往返一致（任意像素，zoom=0.75）")
	else:
		fails.append("canvas 往返误差 %.3fpx" % back.distance_to(w))
	if absf(_cam.position.x - 320.0) < 0.01:
		_ok("相机边界钳制生效（缩小时不出图）")
	else:
		fails.append("相机钳制失效: x=%.1f（期望 320）" % _cam.position.x)

	# 8. Y-sort 基准：立石脚底 y > 幼苗脚底 y → 幼苗先画、立石可遮挡
	if _ysort.y_sort_enabled and _tall.position.y > _seed0.position.y:
		_ok("YSort 启用，脚底 y 排序基准成立（立石 y=%.0f > 幼苗 y=%.0f）" % [
			_tall.position.y, _seed0.position.y])
	else:
		fails.append("YSort 基准异常: y_sort=%s stone=%.1f seed=%.1f" % [
			str(_ysort.y_sort_enabled), _tall.position.y, _seed0.position.y])

	# 9. 占位 Sprite 尺寸
	if _tex_crop != null and _tex_tall != null and _tex_shadow != null \
			and _tex_crop.get_size() == Vector2(64, 64) \
			and _tex_tall.get_size() == Vector2(64, 128) \
			and _tex_shadow.get_size() == Vector2(48, 16):
		_ok("占位 Sprite 尺寸 64×64 / 64×128 / 阴影 48×16")
	else:
		fails.append("占位 Sprite 尺寸异常")

	if fails.is_empty():
		print("FARMTEST OK")
		get_tree().quit(0)
	else:
		for m in fails:
			print("[fail] %s" % m)
		print("FARMTEST FAIL (%d)" % fails.size())
		get_tree().quit(1)


# ------------------------------------------------------------ 截图留档

func _run_shots(dir: String) -> void:
	if dir.begins_with("res://"):
		dir = ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var shots := [
		["farm00_1_overview_z100.png", FarmMap.cell_center(4, 3), 1.0, false],
		["farm00_2_full_z050.png", FarmMap.cell_center(4, 4), 0.5, false],
		["farm00_3_corner_z200.png", Vector2(3.5 * 64, 2.8 * 64), 2.0, false],
		["farm00_4_objects_z150.png", Vector2(5.5 * 64, 4.3 * 64), 1.5, true],
	]
	for i in shots.size():
		var shot: Array = shots[i]
		_cam.position = shot[1]
		_cam.zoom = Vector2(shot[2], shot[2])
		if shot[3]:
			_toggle_crop(Vector2i(6, 5))
			_toggle_crop(Vector2i(6, 6))
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := dir.path_join(shot[0])
		img.save_png(path)
		print("[shot] %s" % path)
	get_tree().quit(0)
