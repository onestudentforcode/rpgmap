extends Node2D
## Phase 2 主农场场景：可开垦、可播种、按天生长、可收获（有限次再生+枯竭清理）、可存档。
## 时间体系：24 时节 × 15 天 × 24 行动点（master-plan v1.1 任务 2.3）。
## 地形数据只读烘焙产物；渲染增量更新；存档纯逻辑数据（素材替换零影响）。
##
## 默认入口：play.bat [--selftest] [--shots=DIR] [--fresh]；test.bat 运行当前模块测试。
## 兼容：play.bat farm [--farmtest] [--farm-shots=DIR]。
##   左键 行动 · 1-9/H 选工具（0 锄头，其余种子槽） · R 休息进入次日
##   每日结束自动存入所属槽 · Esc菜单 · WASD/方向键平移 · 滚轮缩放

const FarmData := preload("res://scripts/farming/core/farm_data.gd")
const LandGrid := preload("res://scripts/farming/core/grid/land_grid.gd")
const FarmClock := preload("res://scripts/farming/core/clock/farm_clock.gd")
const CropManager := preload("res://scripts/farming/core/crops/crop_manager.gd")
const FarmInventory := preload("res://scripts/farming/core/inventory/farm_inventory.gd")
const FarmSnapshot := preload("res://scripts/farming/core/storage/farm_snapshot.gd")
const FarmEconomy := preload("res://scripts/farming/core/economy/farm_economy.gd")
const FarmEconomyPanel := preload("res://scripts/farming/rendering/farm_economy_panel.gd")
const FarmUI := preload("res://scripts/farming/rendering/farm_ui_style.gd")
const Phase05Tests := preload("res://scripts/farming/tests/phase05_economy.gd")
const Phase05ContentTests := preload("res://scripts/farming/tests/phase05_content.gd")
const Phase06SlotTests := preload("res://scripts/farming/tests/phase06_slots.gd")
const Phase06DemoTests := preload("res://scripts/farming/tests/phase06_demo.gd")
const FarmTerrainRenderer := preload("res://scripts/farming/rendering/terrain_renderer.gd")
const CropRenderer := preload("res://scripts/farming/rendering/crop_renderer.gd")
const Phase04Tests := preload("res://scripts/farming/tests/phase04_foundation.gd")
const Phase04ContentTests := preload("res://scripts/farming/tests/phase04_content.gd")
const FarmCamera := preload("res://scripts/farming/rendering/farm_camera.gd")

const MAP_ID := "farm_01"
const TILE := 64
const SAVE_PATH := "user://farm_phase02_save.json"
const SAVE_PATH_TEST := "user://farm_phase02_save_test.json"

var grid: LandGrid
var renderer: FarmTerrainRenderer
var clock: FarmClock
var crop_mgr: CropManager
var inventory: FarmInventory
var economy: FarmEconomy
var economy_panel: FarmEconomyPanel
var crop_r: CropRenderer
const Records := preload("res://scripts/farming/core/economy/farm_records.gd")
var records = Records.new()
var demo_controller
var demo_snapshot: Dictionary = {}

var _config: Dictionary = {}
var _items_by_id: Dictionary = {}
var _crops_by_id: Dictionary = {}
var _tool_crop_ids: Array = []
var _ysort: Node2D
var _cam: Camera2D
var _cam_ctrl: FarmCamera
var _overlay_marks: Node2D
var _medium_marks: Node2D
var _hl: Node2D
var _hud: Label
var _hud_info: Label
var _hud_tool: Label
var _tool_buttons: Array[Button] = []
var _notice_timer: Timer
var _notice_text := ""
var _notice_ok := true
var _hover := Vector2i(-1, -1)
var _tool := 0  # 0=锄头；n=种子槽 _tool_crop_ids[n-1]
var _save_path := SAVE_PATH
var _snapshot_extra: Dictionary = {}

# 自测信号收集（lambda 捕获是值拷贝，经成员方法落盘）
var _farmtest_got: Array[Vector2i] = []
var _farmtest_day_events := 0
var _farmtest_crop_events := 0


func _sink_cells(cells: Array[Vector2i]) -> void:
	_farmtest_got = cells


func _sink_day(_total: int) -> void:
	_farmtest_day_events += 1


func _sink_crops() -> void:
	_farmtest_crop_events += 1


func _ready() -> void:
	var terrains := FarmData.load_terrains()
	var map := FarmData.load_map(MAP_ID)
	_config = FarmData.load_config()
	var crops_data := FarmData.load_crops()
	var items_data := FarmData.load_items()
	if terrains.is_empty() or map.is_empty() or _config.is_empty() \
			or crops_data.is_empty() or items_data.is_empty():
		get_tree().quit(1)
		return
	_items_by_id = FarmData.items_by_id(items_data)
	for c in crops_data["crops"]:
		_crops_by_id[c["crop_id"]] = c
		_tool_crop_ids.append(c["crop_id"])

	var w := int(map["size"][0])
	var h := int(map["size"][1])
	var tillable := {}
	for t in terrains["terrains"]:
		tillable[t["id"]] = t["tillable"]

	grid = LandGrid.new()
	grid.setup(w, h, map["grid"], tillable, _medium_ids())
	renderer = FarmTerrainRenderer.new()
	if not renderer.build(self, grid, terrains):
		get_tree().quit(1)
		return
	grid.cells_changed.connect(renderer.update_cells)
	grid.cells_changed.connect(_on_cells_changed)

	_ysort = Node2D.new()
	_ysort.name = "YSort"
	_ysort.y_sort_enabled = true
	add_child(_ysort)

	clock = FarmClock.new()
	clock.setup(_config)
	crop_mgr = CropManager.new()
	crop_mgr.setup(grid, crops_data)
	inventory = FarmInventory.new()
	inventory.setup(_config.get("start_inventory", {}))
	economy = FarmEconomy.new()
	economy.setup(_config, _items_by_id, _crops_by_id, inventory)
	crop_r = CropRenderer.new()
	crop_r.build(_ysort, crop_mgr)
	clock.day_changed.connect(_on_day_changed)
	clock.day_changed.connect(_sink_day)
	crop_mgr.crops_changed.connect(_sink_crops)

	_setup_camera(w, h)
	_setup_overlay(w, h)

	var args := OS.get_cmdline_user_args()
	var testing := demo_controller == null and ("--farmtest" in args or "--selftest" in args)
	if testing:
		_save_path = SAVE_PATH_TEST
		_run_farmtest.call_deferred()
	elif demo_controller != null:
		if not apply_snapshot(demo_snapshot):
			push_error("Demo快照加载失败")
			return
	else:
		var preview: bool = "--fresh" in args or Array(args).any(func(arg): return arg.begins_with("--shots") or arg.begins_with("--farm-shots"))
		if not preview:
			get_tree().change_scene_to_file.call_deferred("res://scenes/farming/farm_demo.tscn")
	# Tests and screenshot demos have separate lifecycles; testing takes priority.
	if not testing and demo_controller == null:
		for i in range(args.size()):
			var a: String = args[i]
			if a.begins_with("--farm-shots=") or a.begins_with("--shots="):
				_run_shots(a.get_slice("=", 1))
				break
			if a in ["--farm-shots", "--shots"] and i + 1 < args.size():
				_run_shots(args[i + 1])
				break
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
	var hud_panel := PanelContainer.new()
	hud_panel.position = Vector2(8, 6)
	hud_panel.custom_minimum_size.x = 624
	hud_panel.theme = FarmUI.theme()
	layer.add_child(hud_panel)
	var hud_box := VBoxContainer.new()
	hud_panel.add_child(hud_box)
	hud_box.add_theme_constant_override("separation",2)

	_hud = _make_label()
	_hud.add_theme_font_size_override("font_size", 12)
	var status := HBoxContainer.new()
	hud_box.add_child(status)
	status.add_child(_hud)
	var menu := Button.new()
	menu.text = "槽%d · 菜单 Esc" % demo_controller.store.active_slot() if demo_controller != null else "菜单 Esc"
	menu.pressed.connect(func():
		if demo_controller != null:
			demo_controller.show_pause()
		else:
			_flash("预览模式：无存档槽",true))
	status.add_child(menu)

	_hud_info = _make_label()
	_hud_info.add_theme_font_size_override("font_size", 11)
	hud_box.add_child(_hud_info)
	var dock := PanelContainer.new()
	dock.position = Vector2(8, 282)
	dock.custom_minimum_size = Vector2(624, 72)
	dock.theme = FarmUI.theme()
	layer.add_child(dock)
	var dock_box := VBoxContainer.new()
	dock.add_child(dock_box)
	var tools := HBoxContainer.new()
	dock_box.add_child(tools)
	for index in range(_tool_crop_ids.size() + 1):
		var button := Button.new()
		button.text = "锄头" if index == 0 else "%s %d" % [_crop_name(_tool_crop_ids[index-1]), index]
		button.tooltip_text = "H轮换工具；点击地图开垦、恢复或清理" if index == 0 else "选择种子，再点击匹配介质的空耕地播种"
		button.toggle_mode = true
		button.pressed.connect(func():
			_tool = index
			_update_hud())
		tools.add_child(button)
		_tool_buttons.append(button)
	var medium_button := Button.new()
	medium_button.text = "介质 B"
	medium_button.tooltip_text = "将鼠标移到空耕地，按B轮换介质；菌床与朽木需要材料。"
	medium_button.pressed.connect(func(): _cycle_medium(_hover))
	tools.add_child(medium_button)
	var rest := Button.new()
	rest.text = "休息 R"
	rest.pressed.connect(func():
		clock.end_day()
		_flash("休息一晚 —— %s" % clock.describe(), true))
	tools.add_child(rest)
	var actions := HBoxContainer.new()
	dock_box.add_child(actions)
	_hud_tool = _make_label()
	_hud_tool.add_theme_font_size_override("font_size", 11)
	actions.add_child(_hud_tool)
	var market := Button.new()
	market.text = "行囊 / 集市 M"
	market.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	market.pressed.connect(_toggle_economy)
	actions.add_child(market)
	var shade := ColorRect.new()
	shade.size = Vector2(640, 360)
	shade.color = Color(0.04, 0.08, 0.05, 0.62)
	shade.hide()
	layer.add_child(shade)
	shade.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			economy_panel.hide())
	economy_panel = FarmEconomyPanel.new()
	layer.add_child(economy_panel)
	economy_panel.build(self)
	economy_panel.visibility_changed.connect(func():
		shade.visible = economy_panel.visible
		refresh_camera_lock())
	economy_panel.changed.connect(func(message: String, ok: bool):
		_update_hud()
		_flash(message, ok))
	_notice_timer = Timer.new()
	_notice_timer.one_shot = true
	_notice_timer.wait_time = 4.0
	_notice_timer.timeout.connect(_update_hud)
	add_child(_notice_timer)

	_medium_marks = Node2D.new()
	_medium_marks.name = "PlantingMedia"
	_medium_marks.z_index = -1  # Above ground, below Y-sort sprites.
	_medium_marks.draw.connect(_draw_media)
	add_child(_medium_marks)

	_overlay_marks = Node2D.new()
	_overlay_marks.name = "FieldMarks"
	_overlay_marks.z_index = 6
	_overlay_marks.draw.connect(_draw_marks)
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
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


# ------------------------------------------------------------ 输入与交互

func _unhandled_input(event: InputEvent) -> void:
	if demo_controller != null and demo_controller.is_modal():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		_toggle_economy()
		return
	if economy_panel != null and economy_panel.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			economy_panel.hide()
		return
	if event is InputEventMouseMotion:
		_update_hover(get_global_mouse_position())
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_act_on(_hover)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and demo_controller != null:
			demo_controller.show_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R:
			clock.end_day()
			_flash("休息一晚 —— %s" % clock.describe(), true)
		elif event.keycode == KEY_B:
			_cycle_medium(_hover)
		elif event.keycode == KEY_H:
			_tool = (_tool + 1) % (_tool_crop_ids.size() + 1)
			_update_hud()
		else:
			for i in range(_tool_crop_ids.size()):
				if event.keycode == KEY_1 + i:
					_tool = i + 1
					_update_hud()


func _act_on(cell: Vector2i) -> void:
	# 1) 收获优先：任意工具点成熟植株
	var hchk := crop_mgr.can_harvest(cell)
	if hchk["ok"]:
		if not clock.can_spend(clock.cost_of("harvest")):
			_flash("行动点不足", false)
			return
		var r: Dictionary = crop_mgr.harvest(cell)
		var parts := []
		for e in r["items"]:
			inventory.add(e["item_id"], int(e["qty"]))
			parts.append("%s×%d" % [_item_name(e["item_id"]), int(e["qty"])])
		var suffix := ""
		if r["exhausted"]:
			suffix = "（植株已枯竭，用锄头清理）"
		elif not r["removed"]:
			suffix = "（植株保留，再次结果中）"
		clock.spend(clock.cost_of("harvest"))
		_flash("收获 " + "、".join(parts) + suffix, true)
		return
	# 2) 锄头：清理 > 开垦 > 恢复
	if _tool == 0:
		if crop_mgr.can_clear(cell)["ok"]:
			if not clock.can_spend(clock.cost_of("clear")):
				_flash("行动点不足", false)
				return
			crop_mgr.clear(cell)
			clock.spend(clock.cost_of("clear"))
			_flash("已清理枯竭植株，地格恢复开垦态", true)
			return
		var st := grid.state_at(cell)
		if st == LandGrid.State.WILD:
			_do_till(cell)
		elif st == LandGrid.State.TILLED:
			_do_till(cell)  # 已开垦 → 恢复（Phase 1 行为）
		else:
			_flash(_reason_text(_reason_of_cell(cell)), false)
		return
	# 3) 种子槽：播种（种子扣除与占格原子，phase-02 §5）
	var cid: String = _tool_crop_ids[_tool - 1]
	var seed_id := cid + "_seed"
	var pchk: Dictionary = crop_mgr.can_plant(cell, cid)
	if not pchk["ok"]:
		_flash(_reason_text(pchk["reason"]), false)
		return
	if not inventory.has(seed_id, 1):
		_flash("种子不足：%s" % _crop_name(cid), false)
		return
	if not clock.can_spend(clock.cost_of("plant")):
		_flash("行动点不足", false)
		return
	var pr: Dictionary = crop_mgr.plant(cell, cid)
	if pr["ok"]:
		inventory.remove(seed_id, 1)
		clock.spend(clock.cost_of("plant"))
		_flash("已播种 %s" % _crop_name(cid), true)
	else:
		_flash(_reason_text(pr["reason"]), false)


func _do_till(cell: Vector2i) -> void:
	var action := "till"
	var chk: Dictionary
	if grid.state_at(cell) == LandGrid.State.WILD:
		if not clock.can_spend(clock.cost_of(action)):
			_flash("行动点不足", false)
			return
		chk = grid.till(cell)
	else:
		action = "untill"
		if not clock.can_spend(clock.cost_of(action)):
			_flash("行动点不足", false)
			return
		chk = grid.untill(cell)
	if chk["ok"]:
		clock.spend(clock.cost_of(action))
		_flash("已开垦" if grid.state_at(cell) == LandGrid.State.TILLED else "已恢复为未开垦", true)
	else:
		_flash(_reason_text(chk["reason"]), false)


func _medium_ids() -> Array:
	return _config.get("planting_media", [{"id": "soil", "name": "土壤"}]).map(func(m): return m["id"])


func _medium_name(id: String) -> String:
	for medium in _config.get("planting_media", [{"id": "soil", "name": "土壤"}]):
		if medium["id"] == id:
			return String(medium["name"])
	return id


func _cycle_medium(cell: Vector2i) -> void:
	var ids := _medium_ids()
	var next: String = ids[(ids.find(grid.medium_at(cell)) + 1) % ids.size()]
	var chk := grid.can_prepare_medium(cell, next)
	if not chk["ok"]:
		_flash(_reason_text(chk["reason"]), false)
		return
	var cost := clock.cost_of("prepare_medium")
	if not clock.can_spend(cost):
		_flash("行动点不足", false)
		return
	var material := economy.medium_material(next)
	if not material.is_empty() and not inventory.remove(material, 1):
		_flash("材料不足：%s（可在集市购买）" % _item_name(material), false)
		return
	grid.prepare_medium(cell, next)
	clock.spend(cost)
	_flash("种植介质：%s" % _medium_name(next), true)


func _reason_of_cell(cell: Vector2i) -> String:
	var inst := crop_mgr.instance_at(cell)
	if not inst.is_empty():
		return "not_mature:" + CropManager.STATE_NAMES[inst["state"]]
	return "cell_busy:" + LandGrid.STATE_NAMES[grid.state_at(cell)]


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


func _on_day_changed(_total: int) -> void:
	if demo_controller != null:
		records.finish_day(_total, economy.primeval_stones)
	crop_mgr.on_day_changed()
	economy.on_day_changed()
	if _overlay_marks != null:
		_overlay_marks.queue_redraw()
	_update_hud()
	if economy_panel != null and economy_panel.visible:
		economy_panel.refresh()
	if demo_controller != null:
		demo_controller.save_world(capture_snapshot())


func refresh_camera_lock() -> void:
	if _cam_ctrl == null:
		return
	var locked: bool = (economy_panel != null and economy_panel.visible) or (demo_controller != null and demo_controller.is_modal())
	_cam_ctrl.set_process(not locked)
	_cam_ctrl.set_process_unhandled_input(not locked)


func _toggle_economy() -> void:
	economy_panel.visible = not economy_panel.visible
	if economy_panel.visible:
		economy_panel.refresh()


## External gameplay hook; the caller supplies the completed behavior and result.
func record_gu_use(behavior: String, succeeded: bool) -> Dictionary:
	var result := economy.record_use(behavior, succeeded)
	_update_hud()
	if economy_panel != null and economy_panel.visible:
		economy_panel.refresh()
	return result


# ------------------------------------------------------------ 绘制

func _draw_highlight() -> void:
	if grid != null and grid.in_bounds(_hover.x, _hover.y):
		_hl.draw_rect(Rect2(Vector2(_hover) * TILE, Vector2.ONE * TILE),
				Color(1.0, 0.9, 0.35, 0.95), false, 2.0)


func _draw_media() -> void:
	if grid == null:
		return
	for y in range(grid.height):
		for x in range(grid.width):
			var cell := Vector2i(x, y)
			var medium := grid.medium_at(cell)
			if medium not in ["", "soil"]:
				var color := Color(0.5, 0.4, 0.65, 0.3) if medium == "fungal_bed" else Color(0.3, 0.2, 0.1, 0.35)
				_medium_marks.draw_rect(Rect2(Vector2(cell) * TILE, Vector2.ONE * TILE), color, true)


func _draw_marks() -> void:
	if grid == null:
		return
	_medium_marks.queue_redraw()
	for c in grid.occupied_cells():  # 设施占用（红）
		if grid.state_at(c) != LandGrid.State.OCCUPIED:
			continue
		_overlay_marks.draw_rect(Rect2(Vector2(c) * TILE, Vector2.ONE * TILE),
				Color(0.85, 0.15, 0.15, 0.35), true)
		_overlay_marks.draw_rect(Rect2(Vector2(c) * TILE, Vector2.ONE * TILE),
				Color(0.9, 0.25, 0.2, 0.9), false, 2.0)
	if crop_mgr != null:
		for c in crop_mgr.mature_cells():  # 成熟（金点）
			var p := Vector2(c) * TILE
			_overlay_marks.draw_circle(p + Vector2(TILE - 9, 9), 5.0, Color(1.0, 0.82, 0.25, 0.95))
			_overlay_marks.draw_circle(p + Vector2(TILE - 9, 9), 3.0, Color(1.0, 1.0, 0.75, 0.95))
		for c in crop_mgr.exhausted_cells():  # 枯竭（灰褐叉）
			var p := Vector2(c) * TILE + Vector2.ONE * (TILE * 0.5)
			var d := Vector2(12, 8)
			_overlay_marks.draw_line(p - d, p + d, Color(0.45, 0.35, 0.22, 0.95), 3.0)
			_overlay_marks.draw_line(p + Vector2(-d.x, d.y), p + Vector2(d.x, -d.y),
					Color(0.45, 0.35, 0.22, 0.95), 3.0)


# ------------------------------------------------------------ HUD / 提示

func _update_hud() -> void:
	if _hud_info == null or grid == null:
		return
	_hud_info.modulate = Color(0.95, 0.92, 0.8)
	var text := ""
	if grid.in_bounds(_hover.x, _hover.y):
		var tid := grid.terrain_at(_hover)
		var tname: String = _terrains_by_id().get(tid, {}).get("name", tid)
		var inst := crop_mgr.instance_at(_hover) if crop_mgr != null else {}
		var extra := ""
		var medium := grid.medium_at(_hover)
		if not medium.is_empty():
			extra = " · 介质：" + _medium_name(medium)
		if not inst.is_empty():
			extra += " · " + _crop_name(inst["crop_id"]) + " " + _crop_state_text(inst)
		var state_names := {LandGrid.State.WILD:"荒地", LandGrid.State.TILLED:"已开垦",
			LandGrid.State.PLANTED:"种植中", LandGrid.State.OCCUPIED:"已占用", LandGrid.State.UNAVAILABLE:"不可种植"}
		text = "(%d,%d) %s · %s%s" % [_hover.x, _hover.y, tname,
				state_names[grid.state_at(_hover)], extra]
	if clock != null:
		_hud.text = "%s  |  元石 %d  |  木蛊 %d/6" % [clock.describe(), economy.primeval_stones, economy.gu["satiety"]]
	var notice_active := _notice_timer != null and not _notice_timer.is_stopped()
	_hud_info.text = _notice_text if notice_active else text
	if notice_active:
		_hud_info.modulate = FarmUI.JADE if _notice_ok else FarmUI.ERROR
	if _hud_tool != null:
		var tool_text := "工具：锄头（开垦/恢复/清理）"
		if _tool > 0:
			var cid: String = _tool_crop_ids[_tool - 1]
			tool_text = "工具：播种 %s（种子×%d）" % [_crop_name(cid), inventory.count(cid + "_seed")]
		_hud_tool.text = tool_text
		_hud_tool.tooltip_text = "左键行动 · H轮换工具 · WASD/方向键平移 · 滚轮缩放 · 每日自动保存 · Esc菜单"
		for index in range(_tool_buttons.size()):
			_tool_buttons[index].set_pressed_no_signal(index == _tool)


func _terrains_by_id() -> Dictionary:
	# 渲染/HUD 用地形名（每次查表，规模小无谓缓存）
	var out := {}
	var terrains := FarmData.load_terrains()
	for t in terrains.get("terrains", []):
		out[t["id"]] = t
	return out


func _crop_state_text(inst: Dictionary) -> String:
	match int(inst["state"]):
		CropManager.CropState.MATURE:
			return "成熟可采"
		CropManager.CropState.REGROWING:
			return "再次结果中(%d/%d天)" % [int(inst["regrow_days"]),
				int(_crops_by_id[inst["crop_id"]]["regrowth_duration"])]
		CropManager.CropState.EXHAUSTED:
			return "已枯竭（需清理）"
		_:
			return "生长中 第%d天/共%d天 阶段%d" % [int(inst["growth_days"]),
				crop_mgr.mature_day_threshold(_crops_by_id[inst["crop_id"]]),
				crop_mgr.stage_index(inst)]


func _flash(msg: String, ok: bool) -> void:
	_notice_text = msg
	_notice_ok = ok
	if _notice_timer != null:
		_notice_timer.start()
	_hud_info.modulate = FarmUI.JADE if ok else FarmUI.ERROR
	_hud_info.text = msg


func _item_name(item_id: String) -> String:
	return String(_items_by_id.get(item_id, {}).get("name", item_id))


func _crop_name(cid: String) -> String:
	return String(_crops_by_id.get(cid, {}).get("name", cid))


func _reason_text(reason: String) -> String:
	if reason.begins_with("medium_mismatch:"):
		return "需要种植介质：" + _medium_name(reason.get_slice(":", 1))
	if reason.begins_with("terrain_not_tillable:"):
		var tid := reason.get_slice(":", 1)
		return "不可种植/开垦：%s（%s）" % [_terrains_by_id().get(tid, {}).get("name", tid), tid]
	if reason.begins_with("not_wild:"):
		return "当前状态不可开垦（%s）" % reason.get_slice(":", 1)
	if reason.begins_with("not_tilled"):
		return "需要先开垦此地"
	if reason.begins_with("not_mature:"):
		return "尚未成熟，不能采收（%s）" % reason.get_slice(":", 1)
	if reason.begins_with("not_exhausted:"):
		return "只有枯竭植株才能清理"
	if reason.begins_with("cell_busy:"):
		return "该格已被占用/种植中（%s）" % reason.get_slice(":", 1)
	return {
		"unknown_medium": "未知种植介质",
		"medium_requires_empty_tilled": "先开垦空地，再切换种植介质",
		"out_of_bounds": "目标越界",
		"no_crop": "这里没有植株",
		"unknown_crop": "未知作物",
		"occupied": "该格已被占用",
		"planted": "种植中，不可操作",
		"holder_exists": "占用标识已存在",
		"bad_footprint": "非法占地尺寸",
	}.get(reason, "无法操作：%s" % reason.replace("_", " "))


# ------------------------------------------------------------ 完整快照（P6.a；三槽菜单接入见P6.b）

func capture_snapshot() -> Dictionary:
	var snapshot := _snapshot_extra.duplicate(true)
	if demo_controller != null:
		snapshot["records"] = records.data.duplicate(true)
	snapshot.merge({
		"schema": 3,
		"clock": clock.to_save(),
		"grid": grid.to_save(),
		"crops": crop_mgr.to_save(),
		"inventory": inventory.to_save(),
		"economy": economy.to_save(),
	}, true)
	return snapshot

func _save() -> void:
	var f := FileAccess.open(_save_path, FileAccess.WRITE)
	if f == null:
		_flash("存档失败：无法写入", false)
		return
	var data := capture_snapshot()
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	_flash("已存档", true)


func _load(silent: bool) -> bool:
	if not FileAccess.file_exists(_save_path):
		if not silent:
			_flash("没有存档", false)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(_save_path))
	return apply_snapshot(parsed, silent)


func apply_snapshot(value, silent: bool = true) -> bool:
	# Detached validation completes before touching any live model.
	var checked := FarmSnapshot.normalize(value)
	if not checked["ok"]:
		if not silent:
			_flash(checked["reason"], false)
		return false
	var parsed: Dictionary = checked["snapshot"]
	var loaded_economy := FarmEconomy.new()
	loaded_economy.setup(_config, _items_by_id, _crops_by_id, inventory)
	loaded_economy.apply_save(parsed["economy"])
	var ok := grid.apply_save(parsed["grid"]) \
			and crop_mgr.apply_save(parsed["crops"]) \
			and inventory.apply_save(parsed["inventory"])
	if not ok:
		if not silent:
			_flash("存档内容异常", false)
		return false
	clock.apply_save(parsed["clock"])
	economy = loaded_economy
	if demo_controller != null:
		records.data = parsed.get("records", Records.fresh(int(parsed["clock"]["total_days"]))).duplicate(true)
		if not crop_mgr.planted.is_connected(records.planted):
			crop_mgr.planted.connect(records.planted)
			crop_mgr.harvested.connect(records.harvested)
		economy.traded.connect(records.traded)
		economy.fed.connect(records.fed)
	_snapshot_extra = parsed.duplicate(true)
	for key in ["schema", "clock", "grid", "crops", "inventory", "economy"]:
		_snapshot_extra.erase(key)
	if economy_panel != null and economy_panel.visible:
		economy_panel.refresh()
	renderer.refresh_dynamic_all()
	if _overlay_marks != null:
		_overlay_marks.queue_redraw()
	if not silent:
		_flash("已读档 · %s" % clock.describe(), true)
	_update_hud()
	return true


# ------------------------------------------------------------ 逻辑自测

func _ok(msg: String) -> void:
	print("[ok] %s" % msg)


func _run_farmtest() -> void:
	var fails: Array[String] = []
	var chk: Dictionary = {}

	# ============ Phase 1：土地系统（19 项） ============
	grid.reset()
	renderer.refresh_dynamic_all()

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
	if grid.cells_with_state(LandGrid.State.UNAVAILABLE).size() == 29 \
			and grid.cells_with_state(LandGrid.State.WILD).size() == 251:
		_ok("初始状态：石板 29 格 UNAVAILABLE，其余 251 格 WILD")
	else:
		fails.append("初始状态异常")
	var ground_n := renderer.used_count("grass")
	var dirt_n := renderer.used_count("dirt")
	var stone_n := renderer.used_count("stone")
	if ground_n == 280 and dirt_n == 32 and stone_n == 29 \
			and renderer.used_count("tilled") == 0:
		_ok("静态层格数：grass 280 / dirt 32 / stone 29，动态层 0")
	else:
		fails.append("静态层格数异常：%d/%d/%d" % [ground_n, dirt_n, stone_n])
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
	if not grid.till(Vector2i(3, 9))["ok"] and grid.untill(Vector2i(3, 9))["ok"] \
			and grid.state_at(Vector2i(3, 9)) == LandGrid.State.WILD:
		_ok("重复开垦拒绝；恢复 TILLED→WILD")
	else:
		fails.append("重复开垦/恢复异常")
	if not grid.till(Vector2i(15, 8))["ok"] and not grid.till(Vector2i(-1, 0))["ok"]:
		_ok("石板地与越界开垦被拒绝（reason: %s）" % grid.till(Vector2i(15, 8))["reason"])
	else:
		fails.append("非法开垦未被拒绝")
	chk = grid.reserve(Vector2i(2, 11), 2, 2, "h1")
	if chk["ok"] and grid.occupied_cells().size() == 4 \
			and grid.state_at(Vector2i(3, 12)) == LandGrid.State.OCCUPIED:
		_ok("reserve 2×2 成功：4 格 OCCUPIED（prev=WILD）")
	else:
		fails.append("reserve 失败：%s" % chk["reason"])
	chk = grid.reserve(Vector2i(3, 11), 2, 2, "h2")
	if not chk["ok"] and grid.occupied_cells().size() == 4:
		_ok("重叠 reserve 拒绝，无部分占用（原子性）")
	else:
		fails.append("重叠 reserve 原子性异常")
	if not grid.till(Vector2i(2, 11))["ok"]:
		_ok("OCCUPIED 格开垦被拒绝")
	else:
		fails.append("占用格开垦未被拒绝")
	chk = grid.reserve(Vector2i(14, 8), 2, 2, "h3")
	if not chk["ok"] and chk["reason"].begins_with("terrain_not_tillable") \
			and grid.occupied_cells().size() == 4:
		_ok("跨石板 2×2 reserve 拒绝（原因 terrain_not_tillable，原子）")
	else:
		fails.append("跨地形 reserve 异常")
	grid.till(Vector2i(6, 11))
	grid.till(Vector2i(7, 11))
	chk = grid.reserve(Vector2i(6, 11), 2, 1, "h4")
	var released := grid.release("h4")
	if chk["ok"] and released and grid.state_at(Vector2i(6, 11)) == LandGrid.State.TILLED:
		_ok("TILLED 上占用后释放恢复 TILLED（prev 机制）")
	else:
		fails.append("占用 prev 恢复异常")
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
	if renderer.used_count("grass") == 280 and renderer.used_count("dirt") == 32 \
			and renderer.used_count("stone") == 29:
		_ok("全部操作后静态层格数不变（无整图重建）")
	else:
		fails.append("静态层被意外改动")
	var grid_saved := grid.to_save()  # 内存 roundtrip（磁盘复合存档见 Phase 2 段）
	var grid_before := _dump_states()
	if grid.apply_save(grid_saved) and _dump_states() == grid_before:
		_ok("土地数据序列化 roundtrip（内存）")
	else:
		fails.append("土地数据 roundtrip 异常")
	var raw_grid := JSON.stringify(grid_saved)
	if not (raw_grid.contains("png") or raw_grid.contains("atlas") or raw_grid.contains("assets")):
		_ok("土地存档内容纯逻辑数据")
	else:
		fails.append("土地存档混入渲染数据")
	var fresh := LandGrid.new()
	fresh.setup(20, 14, map["grid"], _tillable_of(terrains))
	if fresh.apply_save({"schema": 1}) and fresh.cells_with_state(LandGrid.State.WILD).size() == 251:
		_ok("空存档应用 → 全默认（首次进入路径）")
	else:
		fails.append("空存档应用异常")
	if renderer.tileset.tile_size == Vector2i(64, 64):
		_ok("tile 尺寸 = 64×64（Phase 0 D1）")
	else:
		fails.append("tile 尺寸异常")

	# ============ Phase 2：时间 / 作物 / 库存（16 项） ============
	grid.reset()
	renderer.refresh_dynamic_all()
	crop_mgr.reset_all()
	clock.setup(_config)
	inventory.setup(_config.get("start_inventory", {}))
	_farmtest_day_events = 0
	_farmtest_crop_events = 0

	# 20. 时间常量（v1.1：24 时节 × 15 天 × 24 AP）
	if clock.terms_per_year == 24 and clock.days_per_term == 15 and clock.ap_per_day == 24 \
			and clock.term_names.size() == 24 and String(clock.term_names[0]) == "立春" \
			and clock.cost_of("till") == 1 and clock.cost_of("harvest") == 1:
		_ok("时间常量：24 时节 × 15 天 × 24 行动点，立春起，AP 消耗表就绪")
	else:
		fails.append("时间常量异常")

	# 21. 初始时间
	if clock.term_name() == "立春" and clock.day_in_term() == 1 and clock.year() == 1 \
			and clock.ap == 24 and clock.describe().contains("行动点 24/24"):
		_ok("初始时间：立春 · 第 1 天（第 1 年）· AP 24")
	else:
		fails.append("初始时间异常: %s" % clock.describe())
	# 22. AP 消耗与自动次日
	clock.spend(23)
	var auto_day := clock.spend(1)
	if auto_day and clock.total_days == 1 and clock.ap == 24 and _farmtest_day_events == 1:
		_ok("AP 归零自动进入次日（day_changed ×1）")
	else:
		fails.append("AP 自动次日异常: days=%d ap=%d ev=%d" % [
			clock.total_days, clock.ap, _farmtest_day_events])
	if not clock.spend(25):
		_ok("AP 不足的支出被拒绝")
	else:
		fails.append("AP 溢出支出未被拒绝")
	# 23. 时节/年 wrap（第 16 天→雨水；第 361 天→第 2 年立春）
	clock.apply_save({"total_days": 15, "ap": 24})
	if clock.term_name() == "雨水" and clock.day_in_term() == 1:
		_ok("第 16 天进入第 2 时节（雨水）")
	else:
		fails.append("时节推进异常: %s" % clock.describe())
	clock.apply_save({"total_days": 359, "ap": 24})
	if clock.term_name() == "大寒" and clock.day_in_term() == 15 and clock.year() == 1:
		_ok("第 360 天 = 大寒 · 第 15 天（年末）")
	else:
		fails.append("年末计算异常: %s" % clock.describe())
	clock.apply_save({"total_days": 360, "ap": 24})
	if clock.term_name() == "立春" and clock.year() == 2:
		_ok("第 361 天回绕 第 2 年立春")
	else:
		fails.append("跨年回绕异常: %s" % clock.describe())
	clock.setup(_config)

	# 24. 播种校验
	chk = crop_mgr.can_plant(Vector2i(5, 11), "dew_grass")
	if not chk["ok"] and chk["reason"] == "not_tilled":
		_ok("WILD 格播种拒绝（需先开垦）")
	else:
		fails.append("WILD 播种校验异常")
	chk = crop_mgr.can_plant(Vector2i(15, 8), "dew_grass")
	if not chk["ok"] and chk["reason"].begins_with("terrain_not_tillable:stone"):
		_ok("石板格播种拒绝（%s）" % chk["reason"])
	else:
		fails.append("石板播种校验异常")
	if not crop_mgr.can_plant(Vector2i(0, 0), "no_such_crop")["ok"]:
		_ok("未知作物拒绝")
	else:
		fails.append("未知作物未被拒绝")

	# 25. 校验失败零副作用（原子前提）
	var seed0 := inventory.count("dew_grass_seed")
	var st0 := grid.state_at(Vector2i(5, 11))
	chk = crop_mgr.plant(Vector2i(5, 11), "dew_grass")
	if not chk["ok"] and inventory.count("dew_grass_seed") == seed0 \
			and grid.state_at(Vector2i(5, 11)) == st0 and crop_mgr.crops.is_empty():
		_ok("播种校验失败：种子/地格/实例零变化（原子前提）")
	else:
		fails.append("播种失败出现副作用")

	# 26. 播种成功链（扣种子+占格+实例）
	grid.till(Vector2i(4, 11))
	_farmtest_crop_events = 0
	chk = crop_mgr.plant(Vector2i(4, 11), "dew_grass")
	var uid1: int = int(chk.get("uid", -1))
	if chk["ok"] and grid.state_at(Vector2i(4, 11)) == LandGrid.State.PLANTED \
			and inventory.remove("dew_grass_seed", 1) and inventory.count("dew_grass_seed") == seed0 - 1 \
			and crop_mgr.crops.has(uid1) and crop_mgr.stage_index(crop_mgr.crops[uid1]) == 0 \
			and _farmtest_crop_events >= 1:
		_ok("播种成功：扣 1 种子、地格 PLANTED、实例 SEED 期、crops_changed 发射")
	else:
		fails.append("播种成功链异常")

	# 27. 生长按天推进（阶段数取自配置：1/1/2/0 → 第 4 天成熟）
	var dew_def: Dictionary = crop_mgr.def_of("dew_grass")
	var stage_seq := []
	for i in range(4):
		crop_mgr.on_day_changed()
		var inst: Dictionary = crop_mgr.crops[uid1]
		stage_seq.append(crop_mgr.stage_index(inst))
	if dew_def["growth_stages"].size() == 4 and stage_seq == [1, 2, 2, 3] \
			and crop_mgr.crops[uid1]["state"] == CropManager.CropState.MATURE:
		_ok("生长按天推进：阶段序 %s（配置 4 段，第 4 天成熟）" % str(stage_seq))
	else:
		fails.append("生长推进异常: %s state=%s" % [str(stage_seq),
			CropManager.STATE_NAMES.get(crop_mgr.crops[uid1]["state"], "?")])

	# 28. 非成熟期采收拒绝（第 3 天时 GROWING——用新植株验证）
	grid.till(Vector2i(8, 11))
	var chk_p: Dictionary = crop_mgr.plant(Vector2i(8, 11), "dew_grass")
	var uid2: int = int(chk_p.get("uid", -1))
	crop_mgr.on_day_changed()
	chk = crop_mgr.can_harvest(Vector2i(8, 11))
	if chk_p["ok"] and not chk["ok"] and chk["reason"].begins_with("not_mature:GROWING"):
		_ok("非成熟期采收拒绝（not_mature:GROWING）")
	else:
		fails.append("未成熟采收校验异常: %s" % chk.get("reason"))

	# 29. remove 型收获：多产出 + 确定性掷量 + 地格恢复
	for i in range(3):
		crop_mgr.on_day_changed()  # uid2: 1+3=4 天 → MATURE
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d" % [uid2, 0])
	var expected := []
	for e in dew_def["harvest_items"]:
		var q := rng.randi_range(int(e["min"]), int(e["max"]))
		if q > 0:
			expected.append({"item_id": e["item_id"], "qty": q})
	chk = crop_mgr.harvest(Vector2i(8, 11))
	var items_eq: bool = chk["ok"] and chk["items"].size() == expected.size()
	if items_eq:
		for i in expected.size():
			if expected[i]["item_id"] != chk["items"][i]["item_id"] \
					or int(expected[i]["qty"]) != int(chk["items"][i]["qty"]):
				items_eq = false
	var bounds_ok := true
	var has_leaf := false
	for e in chk["items"]:
		var def_e: Dictionary = _find_harvest_def(dew_def, e["item_id"])
		if int(e["qty"]) < int(def_e["min"]) or int(e["qty"]) > int(def_e["max"]):
			bounds_ok = false
		if e["item_id"] == "dew_leaf":
			has_leaf = true
	if items_eq and bounds_ok and has_leaf and chk["removed"] \
			and grid.state_at(Vector2i(8, 11)) == LandGrid.State.TILLED \
			and not crop_mgr.crops.has(uid2):
		_ok("remove 型收获：多产出入界、掷量可复算、植株移除、地格回 TILLED")
	else:
		fails.append("remove 收获异常 items=%s" % str(chk.get("items")))

	# 30. regrow 型：3 次采收 → 枯竭（有限次再生，v1.1）
	grid.till(Vector2i(6, 11))
	chk = crop_mgr.plant(Vector2i(6, 11), "scarlet_berry")
	var uid3: int = int(chk.get("uid", -1))
	inventory.remove("scarlet_berry_seed", 1)
	for i in range(4):
		crop_mgr.on_day_changed()
	var berry_def: Dictionary = crop_mgr.def_of("scarlet_berry")
	var fruit_in_bounds := true
	var harvest_count_end := 0
	var saw_regrowing := false
	for round_n in range(3):
		chk = crop_mgr.harvest(Vector2i(6, 11))
		if not chk["ok"]:
			fruit_in_bounds = false
			break
		for e in chk["items"]:
			var de: Dictionary = _find_harvest_def(berry_def, e["item_id"])
			if int(e["qty"]) < int(de["min"]) or int(e["qty"]) > int(de["max"]):
				fruit_in_bounds = false
		if round_n < 2:
			if crop_mgr.crops[uid3]["state"] == CropManager.CropState.REGROWING:
				saw_regrowing = true
			crop_mgr.on_day_changed()  # 再生长第 1 天
			if crop_mgr.crops[uid3]["state"] != CropManager.CropState.REGROWING:
				fruit_in_bounds = false
			crop_mgr.on_day_changed()  # 第 2 天 → MATURE
			if crop_mgr.crops[uid3]["state"] != CropManager.CropState.MATURE:
				fruit_in_bounds = false
		else:
			harvest_count_end = int(crop_mgr.crops[uid3]["harvest_count"])
	var exhausted_now: bool = crop_mgr.crops[uid3]["state"] == CropManager.CropState.EXHAUSTED
	if chk["ok"] and fruit_in_bounds and saw_regrowing and harvest_count_end == 3 and exhausted_now \
			and grid.state_at(Vector2i(6, 11)) == LandGrid.State.PLANTED \
			and crop_mgr.exhausted_cells().has(Vector2i(6, 11)) \
			and not crop_mgr.can_harvest(Vector2i(6, 11))["ok"]:
		_ok("regrow 型：2 次采收各经再生长 2 天回成熟，第 3 次后枯竭；地格保持 PLANTED 待清理")
	else:
		fails.append("regrow 收获链异常 state=%s count=%d" % [
			CropManager.STATE_NAMES.get(crop_mgr.crops[uid3]["state"], "?"), harvest_count_end])

	# 31. 清理枯竭 → TILLED
	chk = crop_mgr.clear(Vector2i(6, 11))
	if chk["ok"] and grid.state_at(Vector2i(6, 11)) == LandGrid.State.TILLED \
			and not crop_mgr.crops.has(uid3) and not crop_mgr.can_clear(Vector2i(6, 11))["ok"]:
		_ok("清理枯竭植株：地格回 TILLED，实例销毁")
	else:
		fails.append("清理异常")

	# 32. 库存
	inventory.add("dew_leaf", 3)
	var inv_ok := inventory.count("dew_leaf") >= 3 and inventory.remove("dew_leaf", 2) \
			and not inventory.remove("dew_leaf", 9999)
	inventory.apply_save({})
	if inv_ok:
		_ok("库存 add/remove/count/超扣拒绝")
	else:
		fails.append("库存操作异常")

	# 33. 复合存档 roundtrip（schema v2，含读档后跨天生长）
	grid.reset()
	renderer.refresh_dynamic_all()
	crop_mgr.reset_all()
	clock.setup(_config)
	inventory.setup(_config.get("start_inventory", {}))
	grid.till(Vector2i(2, 12))
	grid.till(Vector2i(3, 12))
	crop_mgr.plant(Vector2i(2, 12), "dew_grass")
	inventory.remove("dew_grass_seed", 1)
	crop_mgr.on_day_changed()
	crop_mgr.on_day_changed()
	clock.apply_save({"total_days": 7, "ap": 5})
	inventory.add("dew_leaf", 3)
	var snap_clock: Dictionary = clock.to_save()
	var snap_crops: Dictionary = crop_mgr.to_save()
	var snap_inv: Dictionary = inventory.to_save()
	var snap_states := _dump_states()
	_save()
	grid.reset()
	crop_mgr.reset_all()
	clock.setup(_config)
	inventory.setup(_config.get("start_inventory", {}))
	var loaded2 := _load(true)
	var crops_match: bool = loaded2 and crop_mgr.to_save()["crops"].size() == snap_crops["crops"].size()
	if crops_match and snap_crops["crops"].size() == 1:
		var a: Dictionary = snap_crops["crops"][0]
		var b: Dictionary = crop_mgr.to_save()["crops"][0]
		crops_match = a["crop_id"] == b["crop_id"] and int(a["growth_days"]) == int(b["growth_days"]) \
				and a["state"] == b["state"] and a["origin"] == b["origin"]
	if loaded2 and _dump_states() == snap_states and clock.to_save() == snap_clock \
			and inventory.to_save() == snap_inv and crops_match:
		crop_mgr.on_day_changed()  # 读档后跨天：growth 2→3 继续
		if int(crop_mgr.to_save()["crops"][0]["growth_days"]) == 3:
			_ok("复合存档磁盘 roundtrip（时钟/土地/作物/库存），读档后跨天生长正确")
		else:
			fails.append("读档后跨天生长异常")
	else:
		fails.append("复合存档 roundtrip 异常")

	# 34. 日推进不重建静态层
	var g280 := renderer.used_count("grass")
	for i in range(3):
		crop_mgr.on_day_changed()
	if renderer.used_count("grass") == g280 and renderer.used_count("dirt") == 32 \
			and renderer.used_count("stone") == 29:
		_ok("多日推进后静态层格数不变")
	else:
		fails.append("日推进触发整图重建")

	# 35. 作物素材契约（阶段齐全；素材替换同名覆盖）
	var assets_ok := true
	for cid in _tool_crop_ids:
		var def_c: Dictionary = crop_mgr.def_of(cid)
		for s in def_c["growth_stages"]:
			if not FileAccess.file_exists("res://assets/farming/crops/%s/%s.png" % [cid, s["sprite"]]):
				assets_ok = false
		if def_c["harvest_type"] == "regrow":
			for extra in ["stage_harvested", "stage_exhausted"]:
				if not FileAccess.file_exists("res://assets/farming/crops/%s/%s.png" % [cid, extra]):
					assets_ok = false
	if assets_ok:
		_ok("作物素材契约：所有已登记作物阶段图齐全（含 regrow 双态）")
	else:
		fails.append("作物素材缺失")
	fails.append_array(Phase04Tests.run())
	# Exercise the real B-key/plant handlers, including AP and seed atomicity.
	grid.reset()
	crop_mgr.reset_all()
	clock.setup(_config)
	inventory.setup(_config.get("start_inventory", {}))
	var medium_cell := Vector2i(1,1)
	inventory.add("fungal_bed_material", 1)  # P5: prepare now requires a purchased material.
	grid.till(medium_cell)
	var before_ap := clock.ap
	_cycle_medium(medium_cell)
	if grid.medium_at(medium_cell)=="fungal_bed" and clock.ap==before_ap-clock.cost_of("prepare_medium"):
		_ok("P4: B键准备介质消耗配置AP")
	else:
		fails.append("P4: 准备介质/AP异常")
	_tool = _tool_crop_ids.find("dew_grass") + 1
	var before_seed := inventory.count("dew_grass_seed")
	before_ap = clock.ap
	_act_on(medium_cell)
	if inventory.count("dew_grass_seed")==before_seed and clock.ap==before_ap and crop_mgr.crops.is_empty():
		_ok("P4: 错误介质播种不扣种子/AP，无实例")
	else:
		fails.append("P4: 错误介质播种出现副作用")
	grid.prepare_medium(medium_cell,"soil")
	_act_on(medium_cell)
	before_ap = clock.ap
	_cycle_medium(medium_cell)
	if not crop_mgr.instance_at(medium_cell).is_empty() and grid.medium_at(medium_cell)=="soil" and clock.ap==before_ap:
		_ok("P4: 种植后B键换介质被拒且不扣AP")
	else:
		fails.append("P4: 占用格换介质出现副作用")
	fails.append_array(Phase04ContentTests.run(self))
	fails.append_array(Phase05Tests.run())
	fails.append_array(Phase05ContentTests.run(self))
	fails.append_array(Phase06SlotTests.run())
	fails.append_array(Phase06SlotTests.run_scene(self))
	fails.append_array(await Phase06DemoTests.run(get_tree()))

	grid.reset()
	renderer.refresh_dynamic_all()
	crop_mgr.reset_all()
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


func _find_harvest_def(def: Dictionary, item_id: String) -> Dictionary:
	for e in def["harvest_items"]:
		if e["item_id"] == item_id:
			return e
	return {"min": 0, "max": 0}


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
	# 演示态：一排多阶段作物 + 一株枯竭 + 占用红框
	grid.reset()
	crop_mgr.reset_all()
	clock.setup(_config)
	inventory.setup(_config.get("start_inventory", {}))
	for x in range(2, 8):
		grid.till(Vector2i(x, 11))
	crop_mgr.plant(Vector2i(2, 11), "dew_grass")
	crop_mgr.plant(Vector2i(4, 11), "scarlet_berry")
	crop_mgr.plant(Vector2i(6, 11), "dew_grass")
	crop_mgr.plant(Vector2i(5, 11), "dew_grass")
	clock.end_day()  # 第 1 天后：幼苗
	clock.end_day()
	clock.end_day()
	clock.end_day()  # 第 4 天后：成熟
	crop_mgr.harvest(Vector2i(4, 11))  # 赤纹果 → 再次结果中
	inventory.add("scarlet_berry_fruit", 3)
	grid.till(Vector2i(9, 11))
	var chk_b: Dictionary = crop_mgr.plant(Vector2i(9, 11), "scarlet_berry")
	var uid_b: int = int(chk_b.get("uid", -1))
	for round_n in range(3):  # 采 3 次 → 枯竭
		for i in range(4):
			clock.end_day()
		crop_mgr.harvest(Vector2i(9, 11))
		if round_n < 2:
			clock.end_day()
			clock.end_day()
	grid.reserve(Vector2i(12, 11), 2, 2, "demo_shot")
	grid.prepare_medium(Vector2i(3,11),"fungal_bed")
	grid.prepare_medium(Vector2i(7,11),"rotten_log")
	renderer.refresh_dynamic_all()
	_overlay_marks.queue_redraw()
	_update_hover(Vector2(3.5 * TILE, 11.5 * TILE))
	var shots := [
		["farm02_1_overview_z055.png", Vector2(640, 448), 0.55],
		["farm02_2_crops_stages_z120.png", Vector2(5.5 * TILE, 11.9 * TILE), 1.2],
		["farm02_3_exhausted_clear_z140.png", Vector2(9.5 * TILE, 11.9 * TILE), 1.4],
		["farm02_4_dirtpatch_z100.png", Vector2(7.0 * TILE, 3.0 * TILE), 1.0],
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
	await _run_phase04_shots(dir)
	get_tree().quit(0)


func _run_phase04_shots(dir: String) -> void:
	# Four real definitions; keep generated placeholders distinct from delivered art.
	crop_mgr.reset_all()
	grid.reset()
	clock.setup(_config)
	inventory.setup(_config["start_inventory"])
	for y in range(10,13):
		for x in range(4,12):
			grid.till(Vector2i(x,y))
	crop_mgr.plant(Vector2i(7,10),"jade_fruit_tree")
	for day in range(6):
		clock.end_day()
	crop_mgr.plant(Vector2i(4,11),"dew_grass")
	crop_mgr.plant(Vector2i(5,11),"scarlet_berry")
	grid.prepare_medium(Vector2i(10,11),"fungal_bed")
	crop_mgr.plant(Vector2i(10,11),"moon_cap")
	for day in range(4):
		clock.end_day()
	_tool=_tool_crop_ids.find("jade_fruit_tree")+1
	_update_hover(Vector2(8.5*TILE,11.5*TILE))
	_update_hud()
	await _capture_phase04(dir,"farm04_1_four_categories.png",Vector2(7.5*TILE,11*TILE),1.2)
	_act_on(Vector2i(8,11))
	_act_on(Vector2i(10,11))
	await _capture_phase04(dir,"farm04_2_harvested_and_bed.png",Vector2(7.5*TILE,11*TILE),1.2)
	crop_mgr.reset_all()
	grid.reset()
	clock.setup(_config)
	for y in range(11,13):
		for x in range(2,14):
			grid.till(Vector2i(x,y))
	crop_mgr.plant(Vector2i(11,11),"jade_fruit_tree")
	for day in range(5):
		clock.end_day()
	crop_mgr.plant(Vector2i(8,11),"jade_fruit_tree")
	for day in range(3):
		clock.end_day()
	crop_mgr.plant(Vector2i(5,11),"jade_fruit_tree")
	for day in range(2):
		clock.end_day()
	crop_mgr.plant(Vector2i(2,11),"jade_fruit_tree")
	_update_hover(Vector2(11.5*TILE,11.5*TILE))
	await _capture_phase04(dir,"farm04_3_tree_stages.png",Vector2(7.5*TILE,11.5*TILE),0.7)


func _capture_phase04(dir: String, filename: String, center: Vector2, zoom: float) -> void:
	renderer.refresh_dynamic_all()
	_overlay_marks.queue_redraw()
	_cam.position=center
	_cam.zoom=Vector2(zoom,zoom)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := dir.path_join(filename)
	get_viewport().get_texture().get_image().save_png(path)
	print("[shot] %s" % path)
