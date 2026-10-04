extends Node2D
## 主控：搭建舞台（地面/墙/物件/玩家/UI），状态机（移动/对话/菜单/战斗桩/切图）。
## 只读 content/baked/ 烘焙产物（tools/bake_maps.py 生成）。
##
## 接缝（演示级，未连接外部系统；正式实现按 daoyan-reuse-plan 对齐）：
##   menu_command(map_id, item_id)      —— 功能入口命令（将来桥接宿主命令分发）
##   battle_requested(map_id, enemy_id) —— 战斗触发（将来接引擎战斗入口）
## 消费型状态存于 GameState（进程内）——正式实现应接引擎存档（写即存）。
##
## 运行模式：--selftest 无头自测；--shots=DIR 截图；--theme=ID 选主题。

const FADE_TIME := 0.3
const BATTLE_HOLD := 0.9

enum State { PLAYING, DIALOGUE, MENU, BATTLE, TRANSITION }

signal menu_command(map_id: String, item_id: String)
signal battle_requested(map_id: String, enemy_id: String)

var state := State.PLAYING
var current_map := ""

var player: Player
var dialogue: DialogueUI
var menu_panel: MenuPanel
var game_state := GameState.new()

var _theme_id := ""
var _baked: Dictionary = {}   # 当前地图烘焙数据
var _index: Dictionary = {}   # 烘焙索引（主题地图集 + 地图归属）

var _ground: TileMapLayer
var _walls: TileMapLayer
var _objects: Node2D
var _ysort: Node2D
var _fade: ColorRect
var _battle_label: Label
var _portal_until_ms := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var index := MapHost.load_index()
	_index = index
	_theme_id = index["default_theme"]
	for a in args:
		if a.begins_with("--theme="):
			_theme_id = a.get_slice("=", 1)
	if not (_theme_id in index["themes"]):
		push_error("未知主题: " + _theme_id)
		get_tree().quit(1)
		return
	var theme := MapHost.load_theme(_theme_id)
	_build_stage()
	_build_player_and_ui(theme)
	var first := MapHost.load_map(_theme_id, index["themes"][_theme_id]["default_map"])
	_load_map(first, MapHost.to_v2i(first["spawn"]), first["spawn_face"])
	_fade.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, 0.6)

	if "--selftest" in args:
		_run_selftest.call_deferred()
	for a in args:
		if a.begins_with("--shots="):
			if _theme_id == "wilds":
				_run_shots_wilds(a.get_slice("=", 1))
			else:
				_run_shots(a.get_slice("=", 1))


func _build_stage() -> void:
	_ground = TileMapLayer.new()
	_ground.name = "Ground"
	_ground.z_index = -1  # 地面不参与 Y-sort，永远垫底
	add_child(_ground)

	_ysort = Node2D.new()
	_ysort.name = "YSortRoot"
	_ysort.y_sort_enabled = true
	add_child(_ysort)

	_walls = TileMapLayer.new()
	_walls.name = "Walls"
	_walls.y_sort_enabled = true  # 与父容器联动，墙块按行参与伪深度排序
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

	var battle_layer := CanvasLayer.new()
	battle_layer.layer = 95  # 高于淡入遮罩（90）：遮罩压暗世界，不压战斗提示
	_battle_label = Label.new()
	_battle_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_battle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_battle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "sans-serif",
	])
	_battle_label.add_theme_font_override("font", font)
	_battle_label.add_theme_font_size_override("font_size", 22)
	_battle_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.5))
	_battle_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_battle_label.add_theme_constant_override("shadow_offset_y", 2)
	_battle_label.visible = false
	battle_layer.add_child(_battle_label)
	add_child(battle_layer)


func _build_player_and_ui(theme: Dictionary) -> void:
	player = Player.new()
	player.name = "Player"
	player.main = self
	player.setup(theme["player"])
	_ysort.add_child(player)

	dialogue = DialogueUI.new()
	dialogue.name = "Dialogue"
	dialogue.closed.connect(_on_dialogue_closed)
	add_child(dialogue)

	menu_panel = MenuPanel.new()
	menu_panel.name = "MenuPanel"
	menu_panel.chosen.connect(_on_menu_chosen)
	menu_panel.canceled.connect(_on_menu_canceled)
	add_child(menu_panel)


## ---- 地图加载：场景树中始终只有当前地图 ----

func _load_map(baked: Dictionary, spawn_cell: Vector2i, face: String) -> void:
	_ground.clear()
	_walls.clear()
	for c in _objects.get_children():
		c.free()
	var ts := int(baked["tile_size"])
	var tileset := MapHost.build_tileset(baked)
	_ground.tile_set = tileset
	_walls.tile_set = tileset
	MapHost.build(baked, _ground, _walls, _objects)
	_baked = baked
	current_map = baked["id"]
	MapHost.apply_consumed(_objects, baked, game_state.map_consumed(current_map))
	var size_px := Vector2(baked["size"][0], baked["size"][1]) * ts
	player.set_camera_limits(Rect2(Vector2.ZERO, size_px))
	player.teleport(MapHost.cell_center(spawn_cell, ts), face)
	# 切图后短暂冷却，且出生格不在触发区上，防进门来回横跳
	_portal_until_ms = Time.get_ticks_msec() + 400
	for p in get_tree().get_nodes_in_group("portal"):
		p.body_entered.connect(_on_portal_entered.bind(p), CONNECT_DEFERRED)
	for b in get_tree().get_nodes_in_group("battle_trigger"):
		b.body_entered.connect(_on_battle_entered.bind(b), CONNECT_DEFERRED)


func _on_portal_entered(body: Node2D, area: Area2D) -> void:
	if body != player or state != State.PLAYING:
		return
	if Time.get_ticks_msec() < _portal_until_ms:
		return
	var cell: Vector2i = area.get_meta("portal_cell")
	var tr := MapHost.find_portal(_baked, cell)
	if tr.is_empty():
		push_error("触发格无门户数据: " + str(cell))
		return
	_do_transition(tr)


func _do_transition(tr: Dictionary) -> void:
	state = State.TRANSITION
	player.frozen = true
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
	await tw.finished
	# 跨主题门户（如城镇 hub ↔ 野外）：解析目标图归属主题并换装
	var to := str(tr["to"])
	if not (to in _index["themes"][_theme_id]["maps"]):
		_theme_id = _index["map_theme"][to]
		player.setup(MapHost.load_theme(_theme_id)["player"])
		player.retheme()
	var next := MapHost.load_map(_theme_id, to)
	_load_map(next, MapHost.to_v2i(tr["spawn"]), tr["face"])
	await get_tree().create_timer(0.05).timeout
	var tw2 := create_tween()
	tw2.tween_property(_fade, "modulate:a", 0.0, FADE_TIME)
	await tw2.finished
	state = State.PLAYING
	player.frozen = false


## ---- 交互分发（类型化） ----

func activate_zone(zone: Interactable) -> void:
	if state != State.PLAYING:
		return
	match zone.type:
		"menu":
			_open_menu(zone)
		"chest":
			_open_chest(zone)
		"battle":
			pass  # 明雷为走进触发，不走 E 键
		_:  # dialogue / save（save 文案在源数据里）
			_open_dialogue(zone.display_name, zone.pages)


func _open_dialogue(display_name: String, pages: PackedStringArray) -> void:
	if state != State.PLAYING:
		return
	state = State.DIALOGUE
	player.frozen = true
	dialogue.open(display_name, pages)


func _open_menu(zone: Interactable) -> void:
	state = State.MENU
	player.frozen = true
	menu_panel.open(zone.display_name, zone.params.get("items", []))


func _on_menu_chosen(item: Dictionary) -> void:
	menu_command.emit(current_map, str(item["id"]))
	# 接缝演示：真实系统应在此把命令交给宿主功能面板；这里用占位对话呈现
	var text := "（功能入口『%s』命令已发出——接缝演示，未连接实际系统。）" % item["label"]
	if item.get("desc") != null:
		text = str(item["desc"]) + "\n" + text
	state = State.DIALOGUE
	dialogue.open(str(item["label"]), PackedStringArray([text]))


func _on_menu_canceled() -> void:
	if state == State.MENU:
		state = State.PLAYING
		player.frozen = false


func _open_chest(zone: Interactable) -> void:
	var cell: Vector2i = zone.get_meta("zone_cell")
	if game_state.is_consumed(current_map, cell):
		_open_dialogue(zone.display_name, PackedStringArray(["箱子已经空了。"]))
		return
	game_state.consume(current_map, cell)
	MapHost.apply_consumed(_objects, _baked, game_state.map_consumed(current_map))
	_open_dialogue(zone.display_name, zone.pages)


## ---- 明雷战斗（走进触发；地图只抛事件，不承载战斗） ----

func _on_battle_entered(body: Node2D, area: Area2D) -> void:
	if body != player or state != State.PLAYING:
		return
	var it: Dictionary = area.get_meta("battle")
	var cell: Vector2i = area.get_meta("zone_cell")
	if bool(it.get("once", false)) and game_state.is_consumed(current_map, cell):
		return
	if not game_state.battle_ready(current_map, cell, int(it.get("cooldown_s", 20))):
		return
	_do_battle(it, cell)


func _do_battle(it: Dictionary, cell: Vector2i) -> void:
	state = State.BATTLE
	player.frozen = true
	battle_requested.emit(current_map, str(it["enemy"]))
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
	await tw.finished
	_battle_label.text = "⚔ 遭遇 %s（战斗桩——接缝已触发）" % it["enemy"]
	_battle_label.visible = true
	await get_tree().create_timer(BATTLE_HOLD).timeout
	_battle_label.visible = false
	var tw2 := create_tween()
	tw2.tween_property(_fade, "modulate:a", 0.0, FADE_TIME)
	await tw2.finished
	# 战后处理：一次性遭遇消费掉，可重复遭遇进入冷却
	if bool(it.get("once", false)):
		game_state.consume(current_map, cell)
	else:
		game_state.set_battle_cooldown(current_map, cell, int(it.get("cooldown_s", 20)))
	state = State.PLAYING
	player.frozen = false


func _on_dialogue_closed() -> void:
	if state == State.DIALOGUE:
		state = State.PLAYING
		player.frozen = false


func _process(_delta: float) -> void:
	match state:
		State.DIALOGUE:
			if Input.is_action_just_pressed("interact"):
				dialogue.advance()
		State.MENU:
			if Input.is_action_just_pressed("move_down"):
				menu_panel.move(1)
			elif Input.is_action_just_pressed("move_up"):
				menu_panel.move(-1)
			elif Input.is_action_just_pressed("interact"):
				menu_panel.confirm()
			elif Input.is_action_just_pressed("ui_cancel"):
				menu_panel.cancel()


## ---- 自测/截图辅助 ----

func _find_zone(char_key: String, cell := Vector2i(-1, -1)) -> Interactable:
	for a in get_tree().get_nodes_in_group("interactable"):
		if a is Interactable and a.params.get("char") == char_key:
			if cell == Vector2i(-1, -1) or a.get_meta("zone_cell") == cell:
				return a
	return null


## ---- 无头逻辑自测：--selftest ----

func _run_selftest() -> void:
	var fails: Array[String] = []
	var index := MapHost.load_index()
	var lobby := MapHost.load_map(_theme_id, "lobby")
	_load_map(lobby, MapHost.to_v2i(lobby["spawn"]), lobby["spawn_face"])
	_check(fails, _ground.get_used_cells().size() == _count_used(lobby["ground"]),
			"大厅地面格数=烘焙数据")
	_check(fails, _walls.get_used_cells().size() == _count_used(lobby["walls"]),
			"大厅墙格数=烘焙数据")
	_check(fails, _cell_has_collision(_walls, Vector2i(0, 0)), "墙体有碰撞")
	_check(fails, not _cell_has_collision(_ground, Vector2i(2, 8)), "地面可行走")

	# R3 验证：共享同一布局的各主题，格数与节点数必须完全一致
	for tid in index["themes"]:
		if not ("lobby" in index["themes"][tid]["maps"]):
			continue  # 野外主题不含大厅（按主题分配地图集）
		var lb := MapHost.load_map(tid, "lobby")
		_check(fails, _count_used(lb["ground"]) == _count_used(lobby["ground"])
				and _count_used(lb["walls"]) == _count_used(lobby["walls"])
				and _node_count(lb) == _node_count(lobby),
				"主题 %s 大厅布局与基准一致" % tid)

	# ---- 宝箱：开启 → 外观切换 → 跨图持久 ----
	var storeroom := MapHost.load_map(_theme_id, "storeroom")
	_load_map(storeroom, Vector2i(3, 9), "down")
	var chest := _find_zone("X")
	_check(fails, chest != null and chest.type == "chest", "储物间宝箱区存在")
	activate_zone(chest)
	_check(fails, state == State.DIALOGUE and dialogue.visible, "宝箱首次开启出对话")
	_check(fails, game_state.is_consumed("storeroom", chest.get_meta("zone_cell")),
			"宝箱标记为已消费")
	_check(fails, _chest_is_open(storeroom, Vector2i(14, 9)), "宝箱贴图已切换为开盖")
	await _advance_dialogue_fully()
	_load_map(MapHost.load_map(_theme_id, "corridor"), Vector2i(18, 5), "right")
	_load_map(storeroom, Vector2i(2, 9), "down")  # 切走再切回
	_check(fails, _chest_is_open(storeroom, Vector2i(14, 9)), "宝箱开盖状态跨图持久")
	var chest2 := _find_zone("X")
	activate_zone(chest2)
	_check(fails, dialogue.visible, "已开宝箱再次交互有反馈（空箱文案）")
	await _advance_dialogue_fully()

	# ---- 存档石：交互有反馈 ----
	var save_zone := _find_zone("V")
	_check(fails, save_zone != null and save_zone.type == "save", "存档石交互区存在")
	activate_zone(save_zone)
	_check(fails, dialogue.visible, "存档石交互出对话")
	await _advance_dialogue_fully()

	# ---- 坊市：menu 接缝 + 明雷战斗桩 ----
	var market := MapHost.load_map(_theme_id, "market")
	_load_map(market, Vector2i(8, 3), "down")
	var menu_zone := _find_zone("C")
	_check(fails, menu_zone != null and menu_zone.type == "menu", "坊市菜单区存在")
	var got_item := []
	menu_command.connect(func(m: String, i: String) -> void: got_item.append([m, i]))
	activate_zone(menu_zone)
	_check(fails, state == State.MENU and menu_panel.visible, "菜单打开进入 MENU 态")
	menu_panel.move(1)
	menu_panel.confirm()
	_check(fails, got_item.size() == 1 and got_item[0][0] == "market",
			"菜单选择发出 menu_command 接缝事件")
	_check(fails, state == State.DIALOGUE and dialogue.visible, "菜单选择有占位反馈")
	await _advance_dialogue_fully()

	var battle_cell := Vector2i(6, 6)
	player.teleport(MapHost.cell_center(battle_cell, 32), "down")  # 走进明雷格
	var battles := []
	battle_requested.connect(func(m: String, e: String) -> void: battles.append([m, e]))
	await get_tree().create_timer(0.4).timeout
	_check(fails, state == State.BATTLE, "走进明雷格进入战斗桩")
	_check(fails, battles.size() == 1 and battles[0][1] == "market_shade",
			"battle_requested 接缝事件携带 enemy_id")
	await get_tree().create_timer(BATTLE_HOLD + 2 * FADE_TIME + 0.3).timeout
	_check(fails, state == State.PLAYING, "战斗桩结束恢复移动")
	player.teleport(MapHost.cell_center(Vector2i(6, 7), 32), "down")
	await get_tree().create_timer(0.4).timeout
	_check(fails, state == State.PLAYING and battles.size() == 1,
			"冷却期内重复走进不再触发")

	# ---- 野外：一次性精英遭遇 + 消费后不再触发 ----
	var wilds_entry: Dictionary = index["themes"]["wilds"]
	_check(fails, "plains" in wilds_entry["maps"], "wilds 主题分配 plains 地图集")
	var plains := MapHost.load_map("wilds", "plains")
	var saved_theme := _theme_id
	_theme_id = "wilds"
	_load_map(plains, Vector2i(36, 4), "down")
	_theme_id = saved_theme
	_check(fails, _walls.get_used_cells().size() == _count_used(plains["walls"]),
			"野外墙格数=烘焙数据")
	var wild_marks := 0
	for it in plains["interactions"]:
		if str(it.get("type")) == "battle":
			wild_marks += it["cells"].size()
	_check(fails, wild_marks == 4, "野外明雷 x4（3 普通 + 1 精英）")
	var elite_cell := Vector2i(35, 22)
	player.teleport(MapHost.cell_center(elite_cell, 32), "down")
	await get_tree().create_timer(0.4).timeout
	_check(fails, state == State.BATTLE, "走进精英格进入战斗桩")
	_check(fails, battles.size() == 2 and battles[1][1] == "wild_elite",
			"精英遭遇携带 enemy_id")
	await get_tree().create_timer(BATTLE_HOLD + 2 * FADE_TIME + 0.3).timeout
	_check(fails, state == State.PLAYING, "精英战结束恢复移动")
	_check(fails, game_state.is_consumed("plains", elite_cell), "一次性遭遇已消费")
	player.teleport(MapHost.cell_center(Vector2i(35, 21), 32), "down")
	await get_tree().create_timer(0.3).timeout
	player.teleport(MapHost.cell_center(elite_cell, 32), "down")
	await get_tree().create_timer(0.4).timeout
	_check(fails, state == State.PLAYING and battles.size() == 2, "已消费遭遇不再触发")

	# ---- 门户往返 ----
	_load_map(lobby, Vector2i(2, 8), "down")
	var tr := MapHost.find_portal(lobby, Vector2i(11, 15))
	_check(fails, not tr.is_empty() and tr["to"] == "market", "大厅南门→坊市门户存在")
	_load_map(MapHost.load_map(_theme_id, tr["to"]), MapHost.to_v2i(tr["spawn"]), tr["face"])
	_check(fails, player.global_position.distance_to(MapHost.cell_center(
			MapHost.to_v2i(tr["spawn"]), 32)) < 1.0, "坊市落点正确")

	dialogue.open("测试", PackedStringArray(["第一页", "第二页"]))
	_check(fails, dialogue.visible and dialogue.is_typing(), "对话打开且打字中")
	await _advance_dialogue_fully()
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


func _advance_dialogue_fully() -> void:
	for i in 8:
		if not dialogue.visible:
			return
		dialogue.advance()
		await get_tree().create_timer(0.15).timeout


func _chest_is_open(baked: Dictionary, cell: Vector2i) -> bool:
	for o in baked["objects"]:
		if o["kind"] == "chest" and MapHost.to_v2i(o["cell"]) == cell:
			var body := _objects.get_node_or_null("Obj_chest_%d_%d" % [cell.x, cell.y])
			if body == null:
				return false
			var spr: Sprite2D = body.get_node_or_null("Sprite")
			if spr == null:
				return false
			var at := spr.texture as AtlasTexture
			if at == null:
				return false
			var r: Rect2 = at.region
			var orp: Array = o["open_region"]
			return r == Rect2(orp[0], orp[1], orp[2], orp[3])
	return false


func _check(fails: Array[String], ok: bool, label: String) -> void:
	print(("  [ok] " if ok else "  [FAIL] ") + label)
	if not ok:
		fails.append(label)


func _cell_has_collision(layer: TileMapLayer, cell: Vector2i) -> bool:
	var td := layer.get_cell_tile_data(cell)
	return td != null and td.get_collision_polygons_count(0) > 0


static func _count_used(arr: Array) -> int:
	var n := 0
	for v in arr:
		if int(v) >= 0:
			n += 1
	return n


static func _zone_count(baked: Dictionary) -> int:
	var n := 0
	for it in baked["interactions"]:
		n += it["cells"].size()
	return n


static func _node_count(baked: Dictionary) -> int:
	return baked["objects"].size() + _zone_count(baked) + baked["portals"].size()


## ---- 窗口截图模式：--shots=DIR（需窗口环境，用于视觉验收）----

func _run_shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(0.8).timeout
	await _shot(dir.path_join("1_lobby.png"))

	player.teleport(MapHost.cell_center(Vector2i(4, 9), 32), "up")  # 站到告示牌旁
	await get_tree().create_timer(0.4).timeout
	await _shot(dir.path_join("2_prompt.png"))

	var clerk := MapHost.find_interaction(_baked, "N")
	dialogue.open(clerk["name"], PackedStringArray(clerk["pages"]))
	await get_tree().create_timer(1.0).timeout
	await _shot(dir.path_join("3_dialogue.png"))
	for i in 8:  # 逐页推进直到关闭（每次 advance 只做"补全/翻页"其一）
		await get_tree().create_timer(0.6).timeout
		if not dialogue.visible:
			break
		dialogue.advance()

	_do_transition(MapHost.find_portal(_baked, Vector2i(23, 7)))
	await get_tree().create_timer(1.0).timeout
	player.teleport(MapHost.cell_center(Vector2i(10, 7), 32), "down")
	await get_tree().create_timer(0.4).timeout
	print("player at ", player.global_position, " map=", current_map)
	await _shot(dir.path_join("4_corridor.png"))

	_do_transition(MapHost.find_portal(_baked, Vector2i(19, 5)))
	await get_tree().create_timer(1.0).timeout
	await _shot(dir.path_join("5_storeroom.png"))

	var market := MapHost.load_map(_theme_id, "market")
	_load_map(market, Vector2i(8, 3), "up")
	await get_tree().create_timer(0.4).timeout
	await _shot(dir.path_join("6_market.png"))
	activate_zone(_find_zone("C"))
	await get_tree().create_timer(0.3).timeout
	await _shot(dir.path_join("7_menu.png"))
	print("SHOTS DONE")
	get_tree().quit(0)


## ---- 野外主题截图：--theme=wilds --shots=DIR ----

func _run_shots_wilds(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().create_timer(0.8).timeout
	await _shot(dir.path_join("1_plains.png"))

	player.teleport(MapHost.cell_center(Vector2i(6, 7), 32), "down")  # 明雷旁
	await get_tree().create_timer(0.4).timeout
	await _shot(dir.path_join("2_mark.png"))

	player.teleport(MapHost.cell_center(Vector2i(6, 6), 32), "down")  # 走进明雷
	await get_tree().create_timer(FADE_TIME + 0.4).timeout
	await _shot(dir.path_join("3_battle_stub.png"))
	await get_tree().create_timer(BATTLE_HOLD + FADE_TIME + 0.3).timeout

	player.teleport(MapHost.cell_center(Vector2i(36, 4), 32), "up")  # 宝箱旁
	await get_tree().create_timer(0.4).timeout
	activate_zone(_find_zone("X"))
	await get_tree().create_timer(0.8).timeout
	await _shot(dir.path_join("4_chest.png"))
	print("SHOTS DONE")
	get_tree().quit(0)


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("shot -> ", path)
