extends Node2D
## 主控：搭建舞台（地面/墙/物件/玩家/UI），状态机（移动/对话/切图），
## 自带两种运行模式：--selftest 无头逻辑自测；--shots=DIR 窗口截图。

const FADE_TIME := 0.3

enum State { PLAYING, DIALOGUE, TRANSITION }

var state := State.PLAYING
var current_map := ""

var player: Player
var dialogue: DialogueUI

var _ground: TileMapLayer
var _walls: TileMapLayer
var _objects: Node2D
var _ysort: Node2D
var _fade: ColorRect
var _portal_until_ms := 0


func _ready() -> void:
	_build_stage()
	_build_player_and_ui()
	var start: Dictionary = MapData.MAPS["lobby"]
	_load_map("lobby", start["spawn"], start["spawn_face"])
	_fade.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, 0.6)

	var args := OS.get_cmdline_user_args()
	if "--selftest" in args:
		_run_selftest.call_deferred()
	for a in args:
		if a.begins_with("--shots="):
			_run_shots(a.get_slice("=", 1))


func _build_stage() -> void:
	var tileset := MapBuilder.build_tileset()

	_ground = TileMapLayer.new()
	_ground.name = "Ground"
	_ground.z_index = -1  # 地面不参与 Y-sort，永远垫底
	_ground.tile_set = tileset
	add_child(_ground)

	_ysort = Node2D.new()
	_ysort.name = "YSortRoot"
	_ysort.y_sort_enabled = true
	add_child(_ysort)

	_walls = TileMapLayer.new()
	_walls.name = "Walls"
	_walls.y_sort_enabled = true  # 与父容器联动，墙块按行参与伪深度排序
	_walls.tile_set = tileset
	_ysort.add_child(_walls)

	_objects = Node2D.new()
	_objects.name = "Objects"
	_objects.y_sort_enabled = true
	_ysort.add_child(_objects)

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 90
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	fade_layer.add_child(_fade)
	add_child(fade_layer)


func _build_player_and_ui() -> void:
	player = Player.new()
	player.name = "Player"
	player.main = self
	_ysort.add_child(player)

	dialogue = DialogueUI.new()
	dialogue.name = "Dialogue"
	dialogue.closed.connect(_on_dialogue_closed)
	add_child(dialogue)


## ---- 地图加载：场景树中始终只有当前地图 ----

func _load_map(map_id: String, spawn_cell: Vector2i, face: String) -> void:
	_ground.clear()
	_walls.clear()
	for c in _objects.get_children():
		c.free()
	var info := MapBuilder.build(map_id, _ground, _walls, _objects)
	current_map = map_id
	player.set_camera_limits(Rect2(Vector2.ZERO, info["size_px"]))
	player.teleport(MapBuilder.cell_center(spawn_cell), face)
	# 切图后短暂冷却，且出生格不在触发区上，防进门来回横跳
	_portal_until_ms = Time.get_ticks_msec() + 400
	for p in get_tree().get_nodes_in_group("portal"):
		p.body_entered.connect(_on_portal_entered.bind(p), CONNECT_DEFERRED)


func _on_portal_entered(body: Node2D, area: Area2D) -> void:
	if body != player or state != State.PLAYING:
		return
	if Time.get_ticks_msec() < _portal_until_ms:
		return
	var cell: Vector2i = area.get_meta("portal_cell")
	var tr: Dictionary = MapData.TRANSITIONS[current_map][cell]
	_do_transition(tr)


func _do_transition(tr: Dictionary) -> void:
	state = State.TRANSITION
	player.frozen = true
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
	await tw.finished
	_load_map(tr["to"], tr["spawn"], tr["face"])
	await get_tree().create_timer(0.05).timeout
	var tw2 := create_tween()
	tw2.tween_property(_fade, "modulate:a", 0.0, FADE_TIME)
	await tw2.finished
	state = State.PLAYING
	player.frozen = false


## ---- 对话 ----

func open_dialogue_for(target: Interactable) -> void:
	if state != State.PLAYING:
		return
	state = State.DIALOGUE
	player.frozen = true
	dialogue.open(target.display_name, target.pages)


func _on_dialogue_closed() -> void:
	if state == State.DIALOGUE:
		state = State.PLAYING
		player.frozen = false


func _process(_delta: float) -> void:
	if state == State.DIALOGUE and Input.is_action_just_pressed("interact"):
		dialogue.advance()


## ---- 无头逻辑自测：--selftest ----

func _run_selftest() -> void:
	var fails: Array[String] = []
	_check(fails, _ground.get_used_cells().size() > 0, "大厅地面已铺设")
	_check(fails, _walls.get_used_cells().size() > 0, "大厅墙体已铺设")
	_check(fails, _objects.get_children().size() >= 20, "大厅物件已生成 (%d)" % _objects.get_children().size())
	_check(fails, _cell_has_collision(_walls, Vector2i(0, 0)), "墙体有碰撞")
	_check(fails, not _cell_has_collision(_ground, Vector2i(2, 8)), "地面可行走")
	_check(fails, get_tree().get_nodes_in_group("portal").size() == 2, "大厅传送点 x2")
	_check(fails, get_tree().get_nodes_in_group("interactable").size() >= 15, "大厅交互点足够")

	_load_map("corridor", Vector2i(1, 5), "right")
	var spawn_pos := MapBuilder.cell_center(Vector2i(1, 5))
	_check(fails, player.global_position.distance_to(spawn_pos) < 1.0, "落点=门内一格")
	_check(fails, _walls.get_used_cells().size() == _expected_wall_cells("corridor"),
			"单地图加载：墙格数=后廊")
	_check(fails, _ground.get_used_cells().size() == _expected_ground_cells("corridor"),
			"单地图加载：地格数=后廊")
	_check(fails, get_tree().get_nodes_in_group("portal").size() == 2, "后廊传送点 x2")
	_check(fails, get_tree().get_nodes_in_group("interactable").size() >= 3, "后廊交互点足够")

	_load_map("lobby", Vector2i(2, 8), "down")
	_check(fails, player.global_position.distance_to(MapBuilder.cell_center(Vector2i(2, 8))) < 1.0,
			"返回大厅落点正确")
	_check(fails, _walls.get_used_cells().size() == _expected_wall_cells("lobby"), "返回大厅墙格数正确")

	dialogue.open("测试", PackedStringArray(["第一页", "第二页"]))
	_check(fails, dialogue.visible and dialogue.is_typing(), "对话打开且打字中")
	await get_tree().create_timer(0.2).timeout  # 越过防误触冷却；首页可能已自然打完
	for i in 6:  # 循环推进直到关闭（每次 advance 只做"补全/翻页"其一，对打字时序鲁棒）
		if not dialogue.visible:
			break
		dialogue.advance()
		await get_tree().create_timer(0.2).timeout
	_check(fails, not dialogue.visible, "逐页推进至关闭")
	_check(fails, state != State.DIALOGUE, "对话后状态恢复")

	if fails.is_empty():
		print("SELFTEST OK")
		get_tree().quit(0)
	else:
		for f in fails:
			push_error(f)
		print("SELFTEST FAILED (%d)" % fails.size())
		get_tree().quit(1)


func _check(fails: Array[String], ok: bool, label: String) -> void:
	print(("  [ok] " if ok else "  [FAIL] ") + label)
	if not ok:
		fails.append(label)


func _cell_has_collision(layer: TileMapLayer, cell: Vector2i) -> bool:
	var td := layer.get_cell_tile_data(cell)
	return td != null and td.get_collision_polygons_count(0) > 0


func _expected_wall_cells(map_id: String) -> int:
	var n := 0
	for row: String in MapData.MAPS[map_id]["layout"]:
		for ch in row:
			if ch in ["#", "E", " "]:
				n += 1
	return n


func _expected_ground_cells(map_id: String) -> int:
	var n := 0
	for row: String in MapData.MAPS[map_id]["layout"]:
		for ch in row:
			if not (ch in ["#", "E"]):
				n += 1
	return n


## ---- 窗口截图模式：--shots=DIR（需窗口环境，用于视觉验收）----

func _run_shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(0.8).timeout
	await _shot(dir.path_join("1_lobby.png"))

	player.teleport(MapBuilder.cell_center(Vector2i(4, 9)), "up")  # 站到告示牌旁
	await get_tree().create_timer(0.4).timeout
	await _shot(dir.path_join("2_prompt.png"))

	var clerk: Dictionary = MapData.MAPS["lobby"]["dialogues"]["N"]
	dialogue.open(clerk["name"], PackedStringArray(clerk["pages"]))
	await get_tree().create_timer(1.0).timeout
	await _shot(dir.path_join("3_dialogue.png"))
	for i in 8:  # 逐页推进直到关闭（每次 advance 只做"补全/翻页"其一）
		await get_tree().create_timer(0.6).timeout
		if not dialogue.visible:
			break
		dialogue.advance()

	_do_transition(MapData.TRANSITIONS["lobby"][Vector2i(23, 7)])
	await get_tree().create_timer(1.0).timeout
	player.teleport(MapBuilder.cell_center(Vector2i(10, 7)), "down")  # 摆到空地便于核对
	await get_tree().create_timer(0.4).timeout
	print("player at ", player.global_position, " map=", current_map)
	await _shot(dir.path_join("4_corridor.png"))
	print("SHOTS DONE")
	get_tree().quit(0)


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("shot -> ", path)
