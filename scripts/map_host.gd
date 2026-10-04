class_name MapHost
## 烘焙地图的运行时加载与构建。只读 content/baked/，源数据与主题文件不进运行时。
## 烘焙产物由 tools/bake_maps.py 生成；改地图请改 content/ 源数据后重新 bake。

const WORLD_LAYER := 1    # 静态碰撞体所在层
const PLAYER_LAYER := 2   # 玩家体所在层（传送区/明雷区据此检测玩家）


static func load_index() -> Dictionary:
	return _read("res://content/baked/index.json")


static func load_theme(theme_id: String) -> Dictionary:
	return _read("res://content/baked/%s/theme.json" % theme_id)


static func load_map(theme_id: String, map_id: String) -> Dictionary:
	return _read("res://content/baked/%s/maps/%s.json" % [theme_id, map_id])


static func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("MapHost: 无法读取 " + path)
		return {}
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		return data
	push_error("MapHost: JSON 解析失败 " + path)
	return {}


static func to_v2i(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


static func cell_center(cell: Vector2i, tile_size: int) -> Vector2:
	return Vector2((cell.x + 0.5) * tile_size, (cell.y + 0.5) * tile_size)


static func find_portal(baked: Dictionary, cell: Vector2i) -> Dictionary:
	for p in baked["portals"]:
		if to_v2i(p["cell"]) == cell:
			return p
	return {}


static func find_interaction(baked: Dictionary, char_key: String) -> Dictionary:
	for it in baked["interactions"]:
		if it["char"] == char_key:
			return it
	return {}


## 由烘焙图块表构建 TileSet（实心图块带全格碰撞多边形）
static func build_tileset(baked: Dictionary) -> TileSet:
	var tsz := int(baked["tile_size"])
	var ts := TileSet.new()
	ts.tile_size = Vector2i(tsz, tsz)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, WORLD_LAYER)
	var src := TileSetAtlasSource.new()
	src.texture = load(baked["tileset_texture"])
	src.texture_region_size = Vector2i(tsz, tsz)
	ts.add_source(src, 0)  # 必须先挂到 TileSet，TileData 才能感知物理层
	var half := tsz / 2.0
	var box := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	])
	for t in baked["tiles"]:
		var atlas := to_v2i(t["atlas"])
		src.create_tile(atlas)
		if bool(t.get("solid", false)):
			var td := src.get_tile_data(atlas, 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, box)
	return ts


## 把烘焙地图填进三个容器（地面层 / 墙层 / 物件容器）
static func build(baked: Dictionary, ground: TileMapLayer, walls: TileMapLayer,
		objects: Node2D) -> void:
	var ts := int(baked["tile_size"])
	var size := to_v2i(baked["size"])
	var tiles: Array = baked["tiles"]
	var i := 0
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			var gi := int(baked["ground"][i])
			if gi >= 0:
				ground.set_cell(cell, 0, to_v2i(tiles[gi]["atlas"]))
			var wi := int(baked["walls"][i])
			if wi >= 0:
				walls.set_cell(cell, 0, to_v2i(tiles[wi]["atlas"]))
			i += 1
	var objects_tex: Texture2D = load(baked["objects_texture"])
	for o in baked["objects"]:
		_spawn_object(o, ts, objects_tex, objects)
	for it in baked["interactions"]:
		match str(it.get("type", "dialogue")):
			"battle":
				for c in it["cells"]:
					_spawn_battle_zone(it, to_v2i(c), ts, objects_tex, objects)
			_:
				for c in it["cells"]:
					_spawn_zone(it, to_v2i(c), ts, objects)
	for p in baked["portals"]:
		_spawn_portal(to_v2i(p["cell"]), ts, objects)


static func _atlas(tex: Texture2D, region: Array) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(region[0], region[1], region[2], region[3])
	return at


## 物件：StaticBody2D 原点在脚底（tile 底边中点），参与 Y-sort。
## 无 box 的物件不生成碰撞，由所在墙格提供阻挡；
## frames 存在时播待机动画，否则画单帧 Sprite2D。
static func _spawn_object(o: Dictionary, ts: int, tex: Texture2D, objects: Node2D) -> void:
	var cell := to_v2i(o["cell"])
	var base := Vector2((cell.x + 0.5) * ts, (cell.y + 1) * ts)
	var body := StaticBody2D.new()
	body.name = "Obj_%s_%d_%d" % [o["kind"], cell.x, cell.y]
	body.position = base
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var box: Variant = o.get("box")
	if box != null:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(box[0], box[1])
		cs.shape = shape
		cs.position = Vector2(0, -shape.size.y / 2.0)
		body.add_child(cs)
	var frames: Variant = o.get("frames")
	if frames != null:
		var anim := AnimatedSprite2D.new()
		var sf := SpriteFrames.new()
		sf.add_animation("idle")
		for fr in frames:
			sf.add_frame("idle", _atlas(tex, fr))
		sf.set_animation_speed("idle", 2.0)
		sf.set_animation_loop("idle", true)
		anim.sprite_frames = sf
		anim.offset = Vector2(0, -int(frames[0][3]) / 2.0)
		anim.play("idle")
		body.add_child(anim)
	else:
		var spr := Sprite2D.new()
		spr.name = "Sprite"
		spr.texture = _atlas(tex, o["region"])
		spr.offset = Vector2(0, -int(o["region"][3]) / 2.0)
		body.add_child(spr)
	objects.add_child(body)


## 靠近触发的交互区（dialogue/menu/chest/save）
static func _spawn_zone(it: Dictionary, cell: Vector2i, ts: int, objects: Node2D) -> void:
	var zone := Interactable.new()
	zone.name = "Inter_%s_%d_%d" % [it["char"], cell.x, cell.y]
	var off: Array = it.get("zone_offset", [0, 0])
	zone.position = Vector2((cell.x + 0.5) * ts, (cell.y + 1) * ts) \
			+ Vector2(off[0], off[1])
	zone.type = str(it.get("type", "dialogue"))
	zone.params = it
	zone.display_name = it["name"]
	var pages := PackedStringArray()
	for p in it.get("pages", []):
		pages.append(str(p))
	zone.pages = pages
	zone.set_meta("zone_cell", cell)
	objects.add_child(zone)


## 明雷战斗触发区：走进触发 + 地面脉动标记（视觉预告，防"莫名开战"）
static func _spawn_battle_zone(it: Dictionary, cell: Vector2i, ts: int,
		tex: Texture2D, objects: Node2D) -> void:
	var area := Area2D.new()
	area.name = "Battle_%s_%d_%d" % [it["char"], cell.x, cell.y]
	area.position = cell_center(cell, ts)
	area.collision_layer = 16
	area.collision_mask = PLAYER_LAYER
	area.monitorable = false
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(ts, ts)
	cs.shape = shape
	area.add_child(cs)
	area.set_meta("zone_cell", cell)
	area.set_meta("battle", it)
	area.add_to_group("battle_trigger")
	objects.add_child(area)

	var mark: Variant = it.get("mark_region")
	if mark != null:
		var decal := Sprite2D.new()
		decal.name = "Mark_%s_%d_%d" % [it["char"], cell.x, cell.y]
		decal.texture = _atlas(tex, mark)
		decal.position = cell_center(cell, ts)
		decal.z_index = -1  # 垫在实体之下（z 优先于 y-sort）
		objects.add_child(decal)
		var tw := decal.create_tween().set_loops()
		tw.tween_property(decal, "modulate:a", 0.35, 0.7)
		tw.tween_property(decal, "modulate:a", 1.0, 0.7)


## 地图加载后按消费状态套用视觉（宝箱开盖）。consumed: {"x,y": true}
static func apply_consumed(objects: Node2D, baked: Dictionary, consumed: Dictionary) -> void:
	if consumed.is_empty():
		return
	for o in baked["objects"]:
		if o["kind"] != "chest" or o.get("open_region") == null:
			continue
		var c := to_v2i(o["cell"])
		if not consumed.has("%d,%d" % [c.x, c.y]):
			continue
		var body := objects.get_node_or_null("Obj_chest_%d_%d" % [c.x, c.y])
		if body == null:
			continue
		var spr: Sprite2D = body.get_node_or_null("Sprite")
		if spr != null:
			spr.texture.region = Rect2(o["open_region"][0], o["open_region"][1],
					o["open_region"][2], o["open_region"][3])


static func _spawn_portal(cell: Vector2i, ts: int, objects: Node2D) -> void:
	var area := Area2D.new()
	area.name = "Portal_%d_%d" % [cell.x, cell.y]
	area.position = cell_center(cell, ts)
	area.collision_layer = 8
	area.collision_mask = PLAYER_LAYER
	area.monitorable = false
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(ts, ts)
	cs.shape = shape
	area.add_child(cs)
	area.set_meta("portal_cell", cell)
	area.add_to_group("portal")
	objects.add_child(area)
