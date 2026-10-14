extends RefCounted
## 分层地形渲染（phase-01 §2.1）：基底满铺 + 各静态上层 + 动态耕地层。
## 构建一次全量；此后只响应 cells_changed 增量 set_cell，绝不整图重建。
##
## 素材替换契约（phase-01 §2.6）：纹理按注册表路径运行时直读（不走 .import），
## 正式 AI 图同名覆盖即生效；本类不引用任何像素内容。

const LandGrid := preload("res://scripts/farming/core/grid/land_grid.gd")

const TILE := 64

var tileset: TileSet
var layers: Dictionary = {}  # terrain_id -> TileMapLayer
var _grid: LandGrid  # preload 类型（RefCounted 脚本实例）
var _terrains: Array = []    # 注册表项（按 layer 排序，构建时附加 _src_*）
var _dynamic_id := ""
var _dynamic_src := -1       # 动态层过渡 atlas 的 source id（构建时缓存）


static func atlas_of(bm: int) -> Vector2i:
	return Vector2i(bm & 15, bm >> 4)


func build(root: Node2D, grid: LandGrid, terrains_data: Dictionary) -> bool:
	_grid = grid
	_terrains = terrains_data.get("terrains", [])
	var dyn := _terrains.filter(func(t): return t["dynamic"])
	if _terrains.is_empty() or dyn.size() != 1:
		push_error("[farm] 地形注册表异常（须恰一个 dynamic 层）")
		return false
	_dynamic_id = dyn[0]["id"]

	tileset = TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)

	var next_src := 0
	for t in _terrains:
		var ground := _load_tex(t["textures"]["ground"])
		if ground == null:
			return false
		var src_ground := TileSetAtlasSource.new()
		src_ground.texture = ground
		src_ground.texture_region_size = Vector2i(TILE, TILE)
		src_ground.create_tile(Vector2i.ZERO)
		tileset.add_source(src_ground, next_src)
		t["_src_ground"] = next_src
		next_src += 1
		if (int(t["layer"]) > 0 and t.get("edge_mode") != "full") or t["dynamic"]:  # 上层/动态层：过渡 atlas（256 配置）
			var trans := _load_tex(t["textures"]["trans"])
			if trans == null:
				return false
			var src_trans := TileSetAtlasSource.new()
			src_trans.texture = trans
			src_trans.texture_region_size = Vector2i(TILE, TILE)
			for row in range(16):
				for col in range(16):
					src_trans.create_tile(Vector2i(col, row))
			tileset.add_source(src_trans, next_src)
			t["_src_trans"] = next_src
			if t["dynamic"]:
				_dynamic_src = next_src
			next_src += 1

	for t in _terrains:
		var l := TileMapLayer.new()
		l.name = "Ground" if int(t["layer"]) == 0 else "T_" + t["id"]
		l.z_index = -10 + int(t["layer"])
		l.tile_set = tileset
		root.add_child(l)
		layers[t["id"]] = l

	_rebuild_static()
	refresh_dynamic_all()
	return true


## cells_changed 处理端：只重算受影响格的动态层 tile。
func update_cells(cells: Array[Vector2i]) -> void:
	if _grid == null:
		return
	var layer: TileMapLayer = layers[_dynamic_id]
	for c in cells:
		if not _grid.in_bounds(c.x, c.y):
			continue
		if not _grid.medium_at(c).is_empty():
			layer.set_cell(c, _dynamic_src, _dynamic_atlas(c))
		else:
			layer.erase_cell(c)


func used_count(terrain_id: String) -> int:
	var l: TileMapLayer = layers.get(terrain_id)
	return 0 if l == null else l.get_used_cells().size()


## 动态层某格当前 atlas 坐标（自测用）。
func dynamic_atlas_cell(cell: Vector2i) -> Vector2i:
	var l: TileMapLayer = layers[_dynamic_id]
	return l.get_cell_atlas_coords(cell)


# ------------------------------------------------------------ 内部

func _rebuild_static() -> void:
	var ground_layer: TileMapLayer = null
	for t in _terrains:
		if int(t["layer"]) == 0:
			ground_layer = layers[t["id"]]
			break
	var src0: int = 0
	for t in _terrains:
		if int(t["layer"]) == 0:
			src0 = t["_src_ground"]
			break
	for y in range(_grid.height):
		for x in range(_grid.origin_x, _grid.origin_x + _grid.width):
			if _grid.in_bounds(x, y): ground_layer.set_cell(Vector2i(x, y), src0, Vector2i.ZERO)

	for t in _terrains:
		if t["dynamic"] or int(t["layer"]) == 0:
			continue
		var layer: TileMapLayer = layers[t["id"]]
		var full: bool = t.get("edge_mode") == "full"
		var src: int = t["_src_ground"] if full else t["_src_trans"]
		var tid: String = t["id"]
		for y in range(_grid.height):
			for x in range(_grid.origin_x, _grid.origin_x + _grid.width):
				var cell := Vector2i(x, y)
				if _grid.in_bounds(x, y) and _grid.terrain_at(cell) == tid:
					layer.set_cell(cell, src, Vector2i.ZERO if full else _static_atlas(tid, cell))


## 全量刷新动态层（读档/复位后调用；常规变更走 update_cells 增量）。
func refresh_all() -> void:
	for layer in layers.values(): layer.clear()
	_rebuild_static()
	refresh_dynamic_all()

func refresh_dynamic_all() -> void:
	var cells: Array[Vector2i] = []
	for y in range(_grid.height):
		for x in range(_grid.origin_x, _grid.origin_x + _grid.width):
			cells.append(Vector2i(x,y))
	update_cells(cells)


func _static_atlas(tid: String, cell: Vector2i) -> Vector2i:
	var pred := func(x: int, y: int) -> bool: return _grid.terrain_at(Vector2i(x, y)) == tid
	return atlas_of(_grid.bitmask_if(cell, pred))


func _dynamic_atlas(cell: Vector2i) -> Vector2i:
	return atlas_of(_grid.bitmask_if(cell, _tilled_pred()))


func _tilled_pred() -> Callable:
	# 经 LandGrid 公开接口 state_at 判定，保持渲染层零内部状态依赖
	var grid := _grid
	return func(x: int, y: int) -> bool: return not grid.medium_at(Vector2i(x, y)).is_empty()


func _load_tex(rel: String) -> Texture2D:
	var path := "res://" + rel
	if OS.has_feature("farm_demo_release") or OS.has_feature("farm_demo_v1_release") or OS.has_feature("farm_demo_v2_release") or OS.has_feature("farm_demo_p8_release"):
		return load(path) as Texture2D
	var img := Image.new()
	var error := img.load_svg_from_string(FileAccess.get_file_as_string(path)) if path.ends_with(".svg") else img.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	if error != OK:
		push_error("[farm] 无法解码纹理 " + path)
		return null
	if img == null or img.is_empty():
		push_error("[farm] 无法加载纹理 res://" + rel)
		return null
	return ImageTexture.create_from_image(img)
