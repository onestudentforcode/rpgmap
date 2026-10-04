class_name MapBuilder
## 把 MapData 的 ASCII 布局构建进给定节点：地面/墙 TileMapLayer + 物件 + 传送区。
## 地图切换 = 清空这三个容器重填，场景树中始终只有一张地图。

const WORLD_LAYER := 1    # 静态碰撞体所在层
const PLAYER_LAYER := 2   # 玩家体所在层（传送区/交互区据此检测玩家）


static func build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(MapData.TILE, MapData.TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, WORLD_LAYER)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/tileset.png")
	src.texture_region_size = Vector2i(MapData.TILE, MapData.TILE)
	ts.add_source(src, 0)  # 必须先挂到 TileSet，TileData 才能感知物理层
	var solid_box := PackedVector2Array([
		Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16),
	])
	for i in 7:
		var coord := Vector2i(i, 0)
		src.create_tile(coord)
		if coord == MapData.T_WALL or coord == MapData.T_VOID:
			var td := src.get_tile_data(coord, 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, solid_box)
	return ts


static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * MapData.TILE, (cell.y + 0.5) * MapData.TILE)


## 返回 {"size_px": Vector2}
static func build(map_id: String, ground: TileMapLayer, walls: TileMapLayer,
		objects: Node2D) -> Dictionary:
	var map: Dictionary = MapData.MAPS[map_id]
	var layout: Array = map["layout"]
	var floor_tiles: Dictionary = map["floor_tiles"]
	var dialogues: Dictionary = map["dialogues"]
	var size := MapData.map_size(map_id)

	for y in size.y:
		var row: String = layout[y]
		for x in size.x:
			var ch := row[x]
			var cell := Vector2i(x, y)
			match ch:
				"#":
					walls.set_cell(cell, 0, MapData.T_WALL)
				"E":
					walls.set_cell(cell, 0, MapData.T_WALL)
					_spawn_elevator(map_id, cell, objects)
				"D":
					ground.set_cell(cell, 0, MapData.T_DOOR)
					_spawn_portal(cell, objects)
				" ":
					ground.set_cell(cell, 0, MapData.T_VOID)
					walls.set_cell(cell, 0, MapData.T_VOID)
				_:
					if MapData.SOLID_OBJECTS.has(ch):
						ground.set_cell(cell, 0, floor_tiles.get(".", MapData.T_FLOOR_A))
						_spawn_object(map_id, ch, cell, objects)
					else:
						ground.set_cell(cell, 0, floor_tiles.get(ch, MapData.T_FLOOR_A))
	return {"size_px": Vector2(size) * MapData.TILE}


static func _atlas(region: Rect2) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/objects.png")
	at.region = region
	return at


## 固体物件：StaticBody2D 原点在脚底（tile 底边中点），参与 Y-sort。
static func _spawn_object(map_id: String, symbol: String, cell: Vector2i,
		objects: Node2D) -> void:
	var data: Dictionary = MapData.SOLID_OBJECTS[symbol]
	var region: Rect2 = data["region"]
	var box: Vector2 = data["box"]
	var base := Vector2((cell.x + 0.5) * MapData.TILE, (cell.y + 1) * MapData.TILE)

	var body := StaticBody2D.new()
	body.name = "Obj_%s_%d_%d" % [symbol, cell.x, cell.y]
	body.position = base
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = box
	cs.shape = shape
	cs.position = Vector2(0, -box.y / 2.0)
	body.add_child(cs)

	if data.get("npc", false):
		var anim := AnimatedSprite2D.new()
		var sf := SpriteFrames.new()
		sf.add_animation("idle")
		sf.add_frame("idle", _atlas(MapData.OBJ_NPC0))
		sf.add_frame("idle", _atlas(MapData.OBJ_NPC1))
		sf.set_animation_speed("idle", 2.0)
		sf.set_animation_loop("idle", true)
		anim.sprite_frames = sf
		anim.offset = Vector2(0, -region.size.y / 2.0)
		anim.play("idle")
		body.add_child(anim)
	else:
		var spr := Sprite2D.new()
		spr.texture = _atlas(region)
		spr.offset = Vector2(0, -region.size.y / 2.0)
		body.add_child(spr)

	objects.add_child(body)

	var dialogues: Dictionary = MapData.MAPS[map_id]["dialogues"]
	if dialogues.has(symbol):
		var info: Dictionary = dialogues[symbol]
		var zone := Interactable.new()
		zone.name = "Inter_%s_%d_%d" % [symbol, cell.x, cell.y]
		zone.position = base
		zone.display_name = info["name"]
		zone.pages = PackedStringArray(info["pages"])
		objects.add_child(zone)


## 电梯：画在墙面上（墙体 tile 已提供碰撞），交互区放在门前一格。
static func _spawn_elevator(map_id: String, cell: Vector2i, objects: Node2D) -> void:
	var base := Vector2((cell.x + 0.5) * MapData.TILE, (cell.y + 1) * MapData.TILE)
	var spr := Sprite2D.new()
	spr.name = "Elevator_%d_%d" % [cell.x, cell.y]
	spr.texture = _atlas(MapData.OBJ_ELEVATOR)
	spr.offset = Vector2(0, -32)
	spr.position = base
	objects.add_child(spr)

	var dialogues: Dictionary = MapData.MAPS[map_id]["dialogues"]
	var info: Dictionary = dialogues["E"]
	var zone := Interactable.new()
	zone.name = "Inter_E_%d_%d" % [cell.x, cell.y]
	zone.position = base + Vector2(0, 20)
	zone.display_name = info["name"]
	zone.pages = PackedStringArray(info["pages"])
	objects.add_child(zone)


static func _spawn_portal(cell: Vector2i, objects: Node2D) -> void:
	var area := Area2D.new()
	area.name = "Portal_%d_%d" % [cell.x, cell.y]
	area.position = cell_center(cell)
	area.collision_layer = 8
	area.collision_mask = PLAYER_LAYER
	area.monitorable = false
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(MapData.TILE, MapData.TILE)
	cs.shape = shape
	area.add_child(cs)
	area.set_meta("portal_cell", cell)
	area.add_to_group("portal")
	objects.add_child(area)
