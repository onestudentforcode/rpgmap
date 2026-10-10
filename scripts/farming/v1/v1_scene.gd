extends Control
## V1 interaction shell. Designations are free; people work only at day settlement.
const World := preload("res://scripts/farming/v1/v1_world.gd")
const Store := preload("res://scripts/farming/v1/v1_slot_store.gd")
const Workforce := preload("res://scripts/farming/v1/v1_workforce.gd")
const Data := preload("res://scripts/farming/v1/v1_data.gd")
const Terrain := preload("res://scripts/farming/rendering/terrain_renderer.gd")
const UI := preload("res://scripts/farming/v1/v1_ui_style.gd")
const Icons := preload("res://scripts/farming/v1/v1_ui_icons.gd")
const Settings := preload("res://scripts/farming/v1/v1_settings.gd")
const Journal := preload("res://scripts/farming/v1/v1_journal.gd")
const NAMES := {"inspect":"查看","till":"开垦","plant":"播种","harvest":"收获","irrigate":"浇水","fertilize":"施肥","fell":"砍伐","clear":"清理","cancel":"取消标记","area":"负责区域","source":"资源采集"}
const CROPS := {"golden_wheat":"金穗麦","fast_fir":"速生杉","resin_tree":"松脂树","wood_decay_mushroom":"木腐菇"}
const RECIPES := {"saw_planks":"锯切木板","shred_wood":"原木粉碎","shred_twigs":"枝条粉碎","char_twigs":"枝条炭化","compost_straw":"秸秆堆肥","compost_twigs":"枝条堆肥","compost_chips":"木屑堆肥","smelt_charcoal":"木炭冶炼","smelt_resin":"松脂冶炼"}
var settings = Settings.new()
var ui_root: Control
var top: HBoxContainer
var help_row: HBoxContainer
var side_panel: PanelContainer
var detail_body: VBoxContainer
var shade: ColorRect
var window_panel: PanelContainer
var window_body: VBoxContainer
var window_scroll: ScrollContainer
var window_title: Label
var window_feedback: Label
var top_nav: HBoxContainer
var tool_caption: Label
var hover_hint: Label
var toolbar_panel: PanelContainer
var _side_open := true
var _hover := Vector2i(-1,-1)
var build_tool := ""
var market_category := "全部"
var market_item := "golden_wheat_seed"
var trade_quantity := 1
var trade_spin: SpinBox
var trade_buy: Button
var trade_sell: Button
var trade_total: Label
var confirmation: ConfirmationDialog
var _last_cash := 60
var _last_ap := 24
var _last_inventory: Dictionary = {}
var _ui_scale := 1.0
var _preview_mode := false
var store = Store.new()
var world: World
var tool := "inspect"
var expanded := false
var selected_worker := 0
var selected := Vector2i(-1,-1)
var task_priority := 5
var board: Control
var map_view: SubViewportContainer
var map_port: SubViewport
var camera: Camera2D
var overlay: Node2D
var terrain: Terrain
var header: Label
var notice: Label
var toolbar: VBoxContainer
var tool_grid: GridContainer
var tool_buttons: Dictionary = {}
var sidebar: VBoxContainer
var side_scroll: ScrollContainer
var _drag := false
var _drag_start := Vector2i.ZERO
var _drag_end := Vector2i.ZERO
var _started := false
var guide_hint: Label
var digest: PanelContainer
var digest_body: VBoxContainer
var _context := "slots"
const GUIDE_TEXT := {"seed":"点击地格分配种子；收获后保留选种。", "designation":"展开农务工具、框选标记，再给雇工分配负责区域。", "plant":"开垦完整占地后播种；雇工在日结工作，缺料会等待。", "processing":"建设加工设施，投料后按天完成，再点击收取。", "order":"打开订单交付同属性食材；也可出售，再买种子投资。"}

class Overlay extends Node2D:
	var owner_ref: WeakRef
	func _draw() -> void:
		var ui = owner_ref.get_ref()
		if ui != null: ui.draw_map(self)

func _ready() -> void:
	theme = UI.theme()
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = Vector2i.ZERO
	get_window().gui_embed_subwindows = true
	get_window().min_size = Vector2i(960,540)
	if DisplayServer.get_name() == "headless" and get_window().size.x < 960: get_window().size = Vector2i(1280,720)
	DisplayServer.window_set_title("灵田 Demo V1")
	get_tree().auto_accept_quit = false
	var shots := ""
	var smoke := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--v1-shots="): shots = arg.trim_prefix("--v1-shots=")
		if arg == "--v1-smoke": smoke = true
	_preview_mode = smoke or not shots.is_empty()
	if _preview_mode:
		store = Store.new("user://v1_scene_preview_%d" % Time.get_ticks_usec())
	else:
		settings.load_settings()
		if not OS.get_cmdline_args().has("--resolution"): settings.apply_display()
	_ui_scale = float(settings.data["ui_scale"])/100.0
	world = World.new(store)
	_last_inventory = world.inventory.to_save()
	_build()
	get_viewport().size_changed.connect(_layout)
	world.changed.connect(_refresh)
	world.daily_settled.connect(_daily_summary)
	_show_slots()
	_refresh()
	if not shots.is_empty(): _preview.call_deferred(shots)
	if smoke:
		var probe = load("res://scripts/farming/validation/v1_release_smoke.gd").new()
		probe.shell = self
		add_child(probe)
		probe.run.call_deferred()

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.set_meta("action_name",text)
	button.tooltip_text = text
	button.accessibility_name = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _icon(parent: Node, ident: String, text: String, action: Callable, extent: int = 36) -> Button:
	var button := _button(parent,"",action)
	button.icon = Icons.get_icon(ident)
	button.set_meta("action_name",text)
	button.tooltip_text = text
	button.accessibility_name = text
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width",20)
	button.custom_minimum_size = Vector2(extent,extent)
	button.focus_entered.connect(func(): notice.text = text)
	return button

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _card(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var body := VBoxContainer.new()
	panel.add_child(body)
	return body

func _picture(parent: Node, ident: String, extent: int = 40) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = Icons.get_icon(ident)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(extent,extent)
	parent.add_child(picture)
	return picture

func _heading(parent: Node, text: String) -> Label:
	var label := _label(parent,text)
	label.add_theme_font_size_override("font_size",22)
	return label

func _bar(parent: Node, text: String, value: float, maximum: float = 100.0) -> void:
	_label(parent,"%s  %d/%d" % [text,value,maximum])
	var bar := ProgressBar.new()
	bar.max_value = maximum
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	parent.add_child(bar)

func _label(parent: Node, text: String) -> Label:
	var label := UI.label(text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_OFF if parent is HBoxContainer and text.length() < 35 else TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _build() -> void:
	ui_root = Control.new()
	ui_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(ui_root)
	var background := ColorRect.new()
	background.color = UI.INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(background)
	top = HBoxContainer.new()
	ui_root.add_child(top)
	header = _label(top,"")
	header.autowrap_mode = TextServer.AUTOWRAP_OFF
	header.clip_text = true
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_icon(top,"day","结束当天 · R",func(): _result(world.end_day()),40)
	_icon(top,"menu","菜单 · Esc",_menu)
	help_row = HBoxContainer.new()
	ui_root.add_child(help_row)
	guide_hint = UI.label("",true)
	guide_hint.clip_text = true
	guide_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help_row.add_child(guide_hint)
	top_nav = HBoxContainer.new()
	help_row.add_child(top_nav)
	_icon(top_nav,"market","行囊/交易 · M",_show_market)
	_icon(top_nav,"orders","订单 · O",_show_orders)
	_icon(top_nav,"workers","雇工 · U",_show_workers)
	_icon(top_nav,"build","建设 · B",_show_build)
	_icon(top_nav,"history","记录 · J",_show_history)
	_icon(top_nav,"help","手册",_show_help)
	_icon(top_nav,"fit","回到全图 · F",_fit_map)
	_icon(top_nav,"inspect","展开/收起地格详情",func(): _side_open = not _side_open; _layout())
	map_view = SubViewportContainer.new()
	map_view.stretch = true
	map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(map_view)
	map_port = SubViewport.new()
	map_port.handle_input_locally = false
	map_port.transparent_bg = true
	map_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	map_view.add_child(map_port)
	var root := Node2D.new()
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_port.add_child(root)
	terrain = Terrain.new()
	terrain.build(root,world.grid,JSON.parse_string(FileAccess.get_file_as_string("res://content/farming/baked/terrains.json")))
	world.grid.cells_changed.connect(terrain.update_cells)
	camera = Camera2D.new()
	camera.position = Vector2(640,448)
	camera.zoom = Vector2.ONE*float(settings.data["map_zoom"])
	root.add_child(camera)
	overlay = Overlay.new()
	overlay.owner_ref = weakref(self)
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root.add_child(overlay)
	board = Control.new()
	board.mouse_default_cursor_shape = Control.CURSOR_CROSS
	board.gui_input.connect(_board_input)
	board.mouse_exited.connect(func(): _hover = Vector2i(-1,-1); hover_hint.text = ""; overlay.queue_redraw())
	ui_root.add_child(board)
	toolbar_panel = PanelContainer.new()
	ui_root.add_child(toolbar_panel)
	toolbar = VBoxContainer.new()
	toolbar_panel.add_child(toolbar)
	var row := HBoxContainer.new()
	toolbar.add_child(row)
	_icon(row,"till","展开/收起农务工具",func(): expanded = not expanded; _layout(),40)
	tool_caption = _label(row,"农务 · 查看")
	_label(row,"优先级")
	var urgency := SpinBox.new()
	urgency.min_value = 1
	urgency.max_value = 9
	urgency.value = task_priority
	urgency.custom_minimum_size.x = 82
	urgency.value_changed.connect(func(value): task_priority = int(value))
	row.add_child(urgency)
	tool_grid = GridContainer.new()
	tool_grid.columns = 10
	toolbar.add_child(tool_grid)
	var index := 0
	for kind in ["inspect","till","plant","harvest","irrigate","fertilize","fell","clear","cancel","area"]:
		var button := _icon(tool_grid,kind,NAMES[kind]+" · "+str(index),_select_tool.bind(kind),40)
		button.toggle_mode = true
		button.button_pressed = kind == tool
		tool_buttons[kind] = button
		index += 1
	side_panel = PanelContainer.new()
	ui_root.add_child(side_panel)
	side_scroll = ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_panel.add_child(side_scroll)
	detail_body = VBoxContainer.new()
	detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(detail_body)
	sidebar = detail_body
	_label(sidebar,"选择地格，查看种植与加工。")
	notice = UI.label("")
	notice.clip_text = true
	ui_root.add_child(notice)
	hover_hint = UI.label("",true)
	hover_hint.clip_text = true
	hover_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(hover_hint)
	digest = PanelContainer.new()
	digest.visible = false
	ui_root.add_child(digest)
	digest_body = VBoxContainer.new()
	digest.add_child(digest_body)
	shade = ColorRect.new()
	shade.color = Color(0.18,0.24,0.20,0.28)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.visible = false
	ui_root.add_child(shade)
	window_panel = PanelContainer.new()
	shade.add_child(window_panel)
	window_body = VBoxContainer.new()
	window_panel.add_child(window_body)
	var title_row := HBoxContainer.new()
	window_body.add_child(title_row)
	var seal := PanelContainer.new()
	seal.custom_minimum_size = Vector2(36,36)
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	seal.add_theme_stylebox_override("panel",UI.box(Color("f6e8d2"),Color("cba884"),4))
	title_row.add_child(seal)
	var seal_text := _label(seal,"灵")
	seal_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	seal_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal_text.add_theme_color_override("font_color",Color("855b32"))
	seal_text.add_theme_font_size_override("font_size",22)
	window_title = _heading(title_row,"")
	window_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	window_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_icon(title_row,"close","关闭窗口 · Esc",_close_page)
	window_scroll = ScrollContainer.new()
	window_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	window_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	window_body.add_child(window_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window_scroll.add_child(body)
	window_scroll.set_meta("body",body)
	window_feedback = UI.label("",true)
	window_feedback.clip_text = true
	window_body.add_child(window_feedback)
	_layout()

func _layout() -> void:
	if ui_root == null: return
	ui_root.scale = Vector2.ONE*_ui_scale
	var dimensions := get_viewport().get_visible_rect().size/_ui_scale
	ui_root.size = dimensions
	var margin := 24.0 if dimensions.x >= 1600 else 12.0
	var compact := dimensions.x < 1100
	top.position = Vector2(margin,8)
	top.size = Vector2(dimensions.x-2*margin,44)
	help_row.position = Vector2(margin,54)
	help_row.size = Vector2(dimensions.x-2*margin,36)
	guide_hint.visible = not compact
	tool_grid.visible = expanded
	tool_grid.columns = 10 if dimensions.x >= 800 else 5
	toolbar_panel.reset_size()
	toolbar_panel.position = Vector2(margin,dimensions.y-32-toolbar_panel.get_combined_minimum_size().y)
	toolbar.size = toolbar.get_combined_minimum_size()
	var side_width := minf(360.0,dimensions.x*0.43)
	side_panel.visible = _side_open and _started
	side_panel.position = Vector2(dimensions.x-margin-side_width,102)
	side_panel.size = Vector2(side_width,maxf(100,dimensions.y-140))
	detail_body.custom_minimum_size.x = side_width-40
	var available := dimensions.x-2*margin-(side_width+12 if side_panel.visible and not compact else 0.0)
	board.position = Vector2(margin,102)
	board.size = Vector2(available,maxf(96,dimensions.y-142))
	map_view.position = board.position
	map_view.size = board.size
	notice.position = Vector2(margin,dimensions.y-26)
	notice.size = Vector2(dimensions.x-2*margin,22)
	hover_hint.position = board.position+Vector2(8,8)
	hover_hint.size = Vector2(maxf(100,available-16),24)
	digest.position = board.position+Vector2(8,8 if dimensions.y < 600 else 40)
	digest.custom_minimum_size.x = minf(520,available-16)
	shade.size = dimensions
	var window_size := Vector2(minf(1040,dimensions.x-2*margin),minf(780,dimensions.y-2*margin))
	window_panel.position = (dimensions-window_size)/2
	window_panel.size = window_size
	for grid in window_scroll.get_meta("body").find_children("*","GridContainer",true,false):
		match grid.get_meta("layout",""):
			"three": grid.columns = 3 if window_size.x >= 900 else (2 if window_size.x >= 660 else 1)
			"slots": grid.columns = 3 if window_size.x >= 900 else 1
			"two": grid.columns = 2 if window_size.x >= 740 else 1
			"matrix": grid.columns = 4 if window_size.x >= 740 else 2
	window_scroll.get_meta("body").custom_minimum_size.x = window_size.x-52
	_refresh_input()

func _refresh_input() -> void:
	board.mouse_filter = Control.MOUSE_FILTER_STOP if _started and not shade.visible else Control.MOUSE_FILTER_IGNORE

func _fit_map() -> void:
	camera.position = Vector2(640,448)
	var zoom := minf(board.size.x/1280.0,board.size.y/896.0)*0.94
	camera.zoom = Vector2.ONE*clampf(zoom,0.25,3.0)

func _refresh() -> void:
	tool_caption.text = "营建" if not build_tool.is_empty() else "农务 · "+NAMES[tool]
	var day := world.clock.total_days+1
	header.text = "灵田  ·  第%d时节 %d/15日     行动 %d/24     元石 %d" % [int((day-1)/15)+1,int((day-1)%15)+1,world.clock.ap,world.primeval_stones]
	if settings.data["show_fps"]: header.text += "   %d FPS" % Engine.get_frames_per_second()
	_refresh_input()
	overlay.queue_redraw()
	guide_hint.text = "WASD平移 · 滚轮缩放 · 右键查看 · 日结执行雇工待办"
	if _started and not world.journal["guide"]["dismissed"]:
		for step in Journal.GUIDE:
			if step not in world.journal["guide"]["seen"]:
				guide_hint.text = "提示："+GUIDE_TEXT[step]
				break
	if not world.daily_save_error.is_empty():
		notice.text = "日存档失败 · 后续操作暂停；打开记录重试，重试不会重复劳动或收费。"
		notice.add_theme_color_override("font_color",UI.ERROR)

func _page(title: String) -> void:
	if _context == "cell":
		sidebar = detail_body
		_clear(sidebar)
		_heading(sidebar,title)
		side_scroll.scroll_vertical = 0
	else:
		shade.visible = true
		_drag = false
		sidebar = window_scroll.get_meta("body")
		_clear(sidebar)
		if window_title.text != title: window_feedback.text = ""
		window_title.text = title
		window_scroll.scroll_vertical = 0
		if not world.daily_save_error.is_empty():
			_label(sidebar,"日存档失败 · 后续操作暂停，请打开经营记录重试。")
	_refresh_input()

func _close_page() -> void:
	shade.visible = false
	_context = "cell" if _started else "slots"
	sidebar = detail_body
	if _started:
		_show_cell()
	else: _show_slots()
	_refresh_input()

func _text_focus() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit

func _result(result: Dictionary) -> void:
	if result.get("ok",false):
		var changes := PackedStringArray()
		var cash := world.primeval_stones-_last_cash
		var ap := world.clock.ap-_last_ap
		if cash != 0: changes.append("元石 %s%d" % ["+" if cash > 0 else "",cash])
		if ap != 0: changes.append("行动 %s%d" % ["+" if ap > 0 else "",ap])
		var item_changes := PackedStringArray()
		for ident in world._items:
			var difference := world.inventory.count(ident)-int(_last_inventory.get(ident,0))
			if difference != 0: item_changes.append("%s %s%d" % [world._items[ident]["name"],"+" if difference > 0 else "",difference])
		for index in range(mini(2,item_changes.size())): changes.append(item_changes[index])
		if item_changes.size() > 2: changes.append("另%d类物品变化" % (item_changes.size()-2))
		notice.text = "已完成"+(" · "+" / ".join(changes) if not changes.is_empty() else " · 每日结束自动保存")
	else: notice.text = result.get("reason","操作失败")
	if result.get("save_error","") != "": notice.text = "日存档失败，后续操作暂停；打开记录重试。"
	notice.add_theme_color_override("font_color",UI.PAPER if result.get("ok",false) else UI.ERROR)
	_last_cash = world.primeval_stones
	_last_ap = world.clock.ap
	_last_inventory = world.inventory.to_save()
	_refresh()
	window_feedback.text = notice.text
	window_feedback.tooltip_text = notice.text
	notice.tooltip_text = notice.text
	window_feedback.add_theme_color_override("font_color",UI.PAPER if result.get("ok",false) else UI.ERROR)

func _confirm(text: String, action: Callable) -> void:
	if is_instance_valid(confirmation): return
	confirmation = ConfirmationDialog.new()
	confirmation.dialog_text = text
	confirmation.borderless = true
	confirmation.dialog_autowrap = true
	confirmation.title = "请确认"
	confirmation.ok_button_text = "确认"
	confirmation.cancel_button_text = "取消"
	confirmation.content_scale_factor = _ui_scale
	confirmation.confirmed.connect(action)
	confirmation.canceled.connect(func(): confirmation.queue_free())
	confirmation.confirmed.connect(func(): confirmation.queue_free())
	add_child(confirmation)
	confirmation.popup_centered(Vector2i(Vector2(480,180)*_ui_scale))

func _show_slots() -> void:
	_context = "slots"
	digest.visible = false
	_page("灵田 · 三个存档")
	_label(sidebar,"种植、加工、供货，把一方田园经营成自己的天地。")
	_label(sidebar,"每日结束自动存档。V1存档独立保存，首次45天后仍可继续经营。")
	var cards := GridContainer.new()
	cards.set_meta("layout","slots")
	cards.columns = 3 if window_panel.size.x >= 900 else 1
	sidebar.add_child(cards)
	for info in store.list_slots():
		var slot := int(info["slot_id"])
		var card := _card(cards)
		_heading(card,"卷 %d" % slot)
		if info["status"] == "ready":
			_label(card,"第%d天 · 元石 %d" % [int(info["total_days"])+1,info["primeval_stones"]])
			_label(card,"保存于 "+Time.get_datetime_string_from_unix_time(int(info["saved_at"])+int(Time.get_time_zone_from_system()["bias"])*60).replace("T"," "))
			_icon(card,"play","继续槽%d" % slot,_open.bind(slot))
		elif info["status"] != "empty": _label(card,"存档无法读取；可新建覆盖。")
		else: _label(card,"空白田园 · 初始60元石")
		_icon(card,"plant","新建槽%d" % slot,func():
			if info["status"] != "empty": _confirm("覆盖卷%d？旧V1存档与经营进度将被永久替换。" % slot,_new.bind(slot,true))
			else: _new(slot,false))
	var row := HBoxContainer.new()
	sidebar.add_child(row)
	_icon(row,"settings","显示设置",_show_settings)
	_icon(row,"help","经营手册",_show_help)

func _new(slot: int, overwrite: bool) -> void:
	var result := world.start_new(slot,overwrite)
	_result(result)
	if result["ok"]:
		_started = true
		_refresh()
		_close_page()
		_layout()
		_fit_map()

func _open(slot: int) -> void:
	var result := world.open_game(slot)
	_result(result)
	if result["ok"]:
		_started = true
		_refresh()
		_close_page()
		_layout()
		_fit_map()

func _menu() -> void:
	_context = "menu"
	_page("田园小憩")
	if _started:
		_icon(sidebar,"play","继续经营",_close_page)
		_label(sidebar,"每日结束保存；返回开始页或退出会放弃当天尚未保存的操作。")
		_icon(sidebar,"back","返回开始页",func(): _confirm("放弃当天操作并返回开始页？上次日存档仍保留。",func():
			world.abandon_day()
			store.close_session()
			_started = false
			_drag = false
			_show_slots()
			_layout()))
	_icon(sidebar,"settings","显示设置",_show_settings)
	_icon(sidebar,"help","经营手册",_show_help)
	_icon(sidebar,"close","退出游戏",func(): _confirm("退出游戏？当天未保存的操作将放弃。",func(): get_tree().quit()))

func _show_settings() -> void:
	_context = "settings"
	_page("显示设置")
	_label(sidebar,"UI缩放独立于地图缩放。设置保存到全局配置，不占用田园存档。")
	var draft: Dictionary = settings.data.duplicate(true)
	var fullscreen := CheckButton.new()
	fullscreen.text = "全屏"
	fullscreen.button_pressed = draft["fullscreen"]
	fullscreen.toggled.connect(func(value): draft["fullscreen"] = value)
	sidebar.add_child(fullscreen)
	_label(sidebar,"窗口分辨率")
	var resolution := OptionButton.new()
	for value in Settings.RESOLUTIONS: resolution.add_item("%d × %d" % [value.x,value.y])
	resolution.select(draft["resolution"])
	resolution.item_selected.connect(func(value): draft["resolution"] = value)
	sidebar.add_child(resolution)
	_label(sidebar,"帧率")
	var frames := OptionButton.new()
	for value in ["垂直同步","60 FPS","120 FPS","不限制"]: frames.add_item(value)
	frames.select(Settings.FRAME_MODES.find(draft["frame_mode"]))
	frames.item_selected.connect(func(value): draft["frame_mode"] = Settings.FRAME_MODES[value])
	sidebar.add_child(frames)
	var fps := CheckButton.new()
	fps.text = "显示FPS"
	fps.button_pressed = draft["show_fps"]
	fps.toggled.connect(func(value): draft["show_fps"] = value)
	sidebar.add_child(fps)
	_label(sidebar,"UI缩放")
	var ui_scale := OptionButton.new()
	for value in [100,125,150]: ui_scale.add_item("%d%%" % value)
	ui_scale.select([100,125,150].find(draft["ui_scale"]))
	ui_scale.item_selected.connect(func(value): draft["ui_scale"] = [100,125,150][value])
	sidebar.add_child(ui_scale)
	_icon(sidebar,"claim","应用设置",func():
		draft["map_zoom"] = camera.zoom.x
		var result: Dictionary = settings.save_settings(draft)
		_result(result)
		if result["ok"]:
			settings.apply_display()
			_ui_scale = float(draft["ui_scale"])/100.0
			_layout())
	if not settings.warning.is_empty(): _label(sidebar,settings.warning)
	_label(sidebar,"本阶段暂无音乐，音量选项随音频内容接入。")

func _select_tool(kind: String) -> void:
	tool = kind
	build_tool = ""
	_drag = false
	for ident in tool_buttons: tool_buttons[ident].set_pressed_no_signal(ident == kind)
	tool_caption.text = "农务 · "+NAMES[kind]
	notice.text = "当前工具：%s · 框选添加待办，日结由雇工执行。" % NAMES[kind]
	if kind == "clear": notice.text = "当前工具：清理 · 不返还投入；保留选种会重播。"
	if kind == "cancel": notice.text = "当前工具：取消标记 · 地格选种仍保留。"
	if kind == "area": notice.text = "当前工具：负责区域 · 为选中雇工框选，可追加多处。"
	overlay.queue_redraw()

func _cell(position: Vector2) -> Vector2i:
	var point := map_port.get_canvas_transform().affine_inverse()*position
	return Vector2i(floori(point.x/64.0),floori(point.y/64.0))

func _rect(a: Vector2i,b: Vector2i) -> Rect2i:
	var left := Vector2i(maxi(0,mini(a.x,b.x)),maxi(0,mini(a.y,b.y)))
	var right := Vector2i(mini(world.grid.width-1,maxi(a.x,b.x)),mini(world.grid.height-1,maxi(a.y,b.y)))
	return Rect2i(left,right-left+Vector2i.ONE)

func _board_input(event: InputEvent) -> void:
	if not _started or shade.visible or is_instance_valid(confirmation) or _text_focus(): return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_select_tool("inspect")
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var anchor: Vector2 = map_port.get_canvas_transform().affine_inverse()*event.position
			var zoom := clampf(camera.zoom.x*(1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/1.2),0.25,3.0)
			camera.zoom = Vector2.ONE*zoom
			camera.position = anchor-(event.position-Vector2(map_port.size)*0.5)/zoom
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_start = _cell(event.position)
				_drag_end = _drag_start
				_drag = true
			elif _drag:
				_drag = false
				_drag_end = _cell(event.position)
				if not build_tool.is_empty():
					selected = _drag_end
					_result(world.build_facility(selected,build_tool))
					_show_cell()
				else: apply_rectangle(_rect(_drag_start,_drag_end))
	elif event is InputEventMouseMotion:
		_hover = _cell(event.position)
		if _drag: _drag_end = _hover
		_update_hover()
	overlay.queue_redraw()

func _update_hover() -> void:
	if not world.grid.in_bounds(_hover.x,_hover.y): hover_hint.text = ""; return
	if not build_tool.is_empty():
		var result := world.can_build_facility(_hover,build_tool)
		hover_hint.text = "%s · %s" % [world.facility_defs[build_tool]["name"],"可放置 · 点击建造" if result["ok"] else result["reason"]]
	elif _drag and tool not in ["inspect","area","cancel"]:
		var preview := world.workforce.preview(_rect(_drag_start,_drag_end),tool)
		hover_hint.text = "%s · 有效%d格 / 跳过%d格 · %d个目标" % [NAMES[tool],preview["valid"].size(),preview["invalid"].size(),preview["targets"].size()]
	else:
		var crop := world.instance_at(_hover)
		var source := world.source_at(_hover)
		var facility := world.facility_at(_hover)
		hover_hint.text = "(%d,%d) · " % [_hover.x,_hover.y]
		if not crop.is_empty(): hover_hint.text += CROPS[crop["crop_id"]]+(" · 成熟" if crop["state"] == "mature" else " · 生长中")
		elif not source.is_empty(): hover_hint.text += {"stone_source":"采石点","ore_source":"采矿点","spring_source":"泉水点"}[source]+" · 今日剩余%d" % world.source_remaining(source)
		elif not facility.is_empty(): hover_hint.text += world.facility_defs[facility["facility_id"]]["name"]
		else: hover_hint.text += "点击查看 · "+NAMES[tool]

func apply_rectangle(rect: Rect2i) -> void:
	if not _started or rect.size.x <= 0 or rect.size.y <= 0: return
	if tool == "inspect":
		selected = rect.position
		_side_open = true
		_show_cell()
		_layout()
	elif tool == "area":
		for worker in world.workforce.state["workers"]:
			if worker["id"] == selected_worker:
				var areas: Array = worker["areas"].duplicate(true)
				areas.append([rect.position.x,rect.position.y,rect.size.x,rect.size.y])
				_result(world.workforce.configure(selected_worker,worker["budget"],worker["paused"],worker["priorities"],areas))
				return
		notice.text = "请先在雇工面板选择一名雇工。"
	elif tool == "cancel": _result(world.workforce.cancel(rect))
	else:
		var kind := tool
		var priority := task_priority
		if kind == "clear":
			var preview := world.workforce.preview(rect,kind)
			if preview["targets"].is_empty(): notice.text = "没有可清理的植物。"; return
			_confirm("标记清理%d株植物？雇工日结执行，投入与未成熟产物均不返还；选种计划保留。" % preview["targets"].size(),_mark.bind(rect,kind,priority))
		else: _mark(rect,kind,priority)
	overlay.queue_redraw()

func _mark(rect: Rect2i, kind: String, priority: int) -> void:
	var result := world.workforce.mark(rect,kind,priority)
	_result(result)
	if result["ok"]: notice.text = "新增%d个%s标记，跳过%d格；当前工具保持选中。" % [result["added"],NAMES[kind],result["skipped"]]

func _show_cell() -> void:
	_context = "cell"
	shade.visible = false
	_page("地格 (%d,%d)" % [selected.x,selected.y] if selected.x >= 0 else "一方灵田")
	if not world.grid.in_bounds(selected.x,selected.y):
		_label(sidebar,"点击地格查看详情，展开农务工具框选待办。")
		return
	var source := world.source_at(selected)
	if not source.is_empty():
		var definition: Dictionary = world.source_defs[source]
		_picture(sidebar,definition["item"])
		_heading(sidebar,{"stone_source":"采石点","ore_source":"采矿点","spring_source":"泉水点"}[source])
		_label(sidebar,"每批%s×%d · 手动1AP" % [world._items[definition["item"]]["name"],definition["quantity"]])
		_label(sidebar,"今日剩余%d / %d份" % [world.source_remaining(source),definition["daily_limit"]])
		var collect := _icon(sidebar,"claim","手动采集（1AP）",func(): _result(world.collect(source)); _show_cell())
		collect.disabled = world.source_remaining(source) < int(definition["quantity"])
		_label(sidebar,"指派雇工 · 与手动采集共享日额度")
		var choice := OptionButton.new()
		choice.add_item("不分配")
		choice.set_item_metadata(0,0)
		for worker in world.workforce.state["workers"]:
			choice.add_item(worker["name"])
			choice.set_item_metadata(choice.item_count-1,int(worker["id"]))
			if world.workforce.state["sources"].get(source) == worker["id"]: choice.select(choice.item_count-1)
		choice.item_selected.connect(func(index): _result(world.workforce.assign_source(source,int(choice.get_item_metadata(index)))))
		sidebar.add_child(choice)
		return
	var facility := world.facility_at(selected)
	if not facility.is_empty(): _show_facility(facility); return
	var crop := world.instance_at(selected)
	if not crop.is_empty(): selected = Vector2i(int(crop["origin"][0]),int(crop["origin"][1]))
	var env := world.environment_at(selected)
	if not crop.is_empty():
		_picture(sidebar,crop["crop_id"],64)
		_heading(sidebar,CROPS[crop["crop_id"]]+(" · 成熟" if crop["state"] == "mature" else " · 生长中"))
		var definition: Dictionary = world.crop_defs[crop["crop_id"]]
		var target := int(definition["cycle_days"] if crop["harvest_count"] > 0 else definition["days"])*100
		_bar(sidebar,"生长",int(crop["progress"])*100.0/target)
		_label(sidebar,"偏好光照 %d" % definition["light"])
		if absi(int(env["light"])-int(definition["light"])) > int(world.config["environment"]["light_tolerance"]):
			_label(sidebar,"当前光照不合适，生长较慢。")
	_bar(sidebar,"水分",env["water"])
	_bar(sidebar,"肥力",env["fertility"])
	_label(sidebar,"固定光照 %d · 阴区更适合菌菇" % env["light"])
	if env["water"] < 30 or env["fertility"] < 30: _label(sidebar,"水肥不足会降效，不会死亡。")
	for mark in world.workforce.state["marks"]:
		if mark["cell"] == [selected.x,selected.y]:
			_label(sidebar,"待办 %s · 优先级%d\n%s" % [NAMES[mark["kind"]],mark["priority"],world.workforce.task_status(selected,mark["kind"])])
	_label(sidebar,"持续选种 · 空闲后沿用")
	var seeds := OptionButton.new()
	seeds.add_item("不播种 / 保持空闲")
	seeds.set_item_metadata(0,"")
	var plan := world.workforce.seed_plan(selected)
	for ident in CROPS:
		seeds.add_item("%s（种子%d）" % [CROPS[ident],world.inventory.count(world.crop_defs[ident]["seed"])])
		seeds.set_item_metadata(seeds.item_count-1,ident)
		if plan.get("crop_id") == ident: seeds.select(seeds.item_count-1)
	seeds.add_theme_constant_override("icon_max_width",24)
	seeds.item_selected.connect(func(index): _result(world.workforce.set_seed(selected,seeds.get_item_metadata(index))); _show_cell())
	sidebar.add_child(seeds)
	if not plan.is_empty():
		_label(sidebar,"自动播种："+world.workforce.task_status(selected,"plant"))
		var definition: Dictionary = world.crop_defs[plan["crop_id"]]
		var inputs: Dictionary = definition["inputs"].duplicate()
		inputs[definition["seed"]] = int(inputs.get(definition["seed"],0))+1
		_label(sidebar,"每轮投入："+_materials(inputs))
		_label(sidebar,_missing(inputs))
		_label(sidebar,"占地%d×%d，全部开垦且空闲才能播种。" % definition["footprint"])
		_label(sidebar,"基础%d天 · 偏好光照%d\n产物：%s" % [definition["days"],definition["light"],_materials(definition["outputs"])])
	_label(sidebar,"手动操作 · 每次成功消耗1AP")
	var row := HBoxContainer.new()
	sidebar.add_child(row)
	for kind in ["till","plant","harvest","irrigate","fertilize","fell","clear"]:
		var eligible: Dictionary = world.workforce._target(selected,kind)
		if not eligible["ok"]: continue
		if kind == "plant" and (plan.is_empty() or not crop.is_empty()): continue
		var button := _icon(row,kind,"手动%s（1AP）" % NAMES[kind],func():
			if kind == "clear": _confirm("清理%s？不返还投入与未成熟产物；保留选种。" % CROPS[crop["crop_id"]],_manual.bind(kind))
			else: _manual(kind))
		if kind in ["harvest","fell"]: button.disabled = crop.get("state") != "mature"
		if kind in ["irrigate","fertilize"]:
			var item := "clean_water" if kind == "irrigate" else "humus"
			button.disabled = world.inventory.count(item) < 1
			button.tooltip_text += " · 消耗%s×1（持有%d）" % [world._items[item]["name"],world.inventory.count(item)]
	_label(sidebar,"养护每次：清水×1（持有%d）或腐殖土×1（持有%d）" % [world.inventory.count("clean_water"),world.inventory.count("humus")])
	_icon(sidebar,"build","选择设施并放置",_show_build)

func _missing(inputs: Dictionary) -> String:
	var missing := {}
	for ident in inputs:
		var amount := int(inputs[ident])-world.inventory.count(ident)
		if amount > 0: missing[ident] = amount
	return "投入齐备" if missing.is_empty() else "缺少："+_materials(missing)

func _materials(counts: Dictionary) -> String:
	var items: Dictionary = world._items
	var parts := PackedStringArray()
	for ident in counts: parts.append("%s×%d" % [items[ident]["name"],counts[ident]])
	return "、".join(parts)

func _manual(kind: String) -> void:
	var result := {"ok":false,"reason":"请先给地格分配种子"}
	match kind:
		"till": result = world.till(selected)
		"plant":
			var plan := world.workforce.seed_plan(selected)
			if not plan.is_empty(): result = world.plant(selected,plan["crop_id"])
		"harvest":
			var crop := world.instance_at(selected)
			if not crop.is_empty() and world.crop_defs[crop["crop_id"]]["mode"] == "fell_replant":
				result = {"ok":false,"reason":"速生杉取材请使用砍伐。"}
			else: result = world.harvest(selected)
		"fell": result = world.harvest(selected,"fell")
		"clear": result = world.clear_crop(selected)
		"irrigate": result = world.irrigate(selected)
		"fertilize": result = world.fertilize(selected)
	_result(result)
	_show_cell()

func _show_facility(facility: Dictionary) -> void:
	var uid := int(facility["uid"])
	var batch: Dictionary = facility["batch"]
	_picture(sidebar,facility["facility_id"],64)
	_heading(sidebar,world.facility_defs[facility["facility_id"]]["name"])
	if not batch.is_empty():
		_heading(sidebar,"待收取" if batch["status"] == "ready" else "加工中")
		_label(sidebar,RECIPES[batch["recipe_id"]])
		_label(sidebar,"产物："+_materials(batch["outputs"]))
		var days := int(world.recipe_defs[batch["recipe_id"]]["days"])
		var remaining := maxi(0,int(batch["finish_day"])-world.clock.total_days)
		_bar(sidebar,"加工进度",days-remaining,days)
		_label(sidebar,"剩余%d天 · 无需每日点击" % remaining)
		var claim := _icon(sidebar,"claim","收取（1AP）",func(): _result(world.claim_batch(uid,int(batch["batch_id"]))); _show_cell())
		claim.disabled = batch["status"] != "ready"
	else:
		_label(sidebar,"空闲 · 选择配方")
		for ident in world.recipe_defs:
			var recipe: Dictionary = world.recipe_defs[ident]
			if recipe["facility"] != facility["facility_id"]: continue
			var card := _card(sidebar)
			_label(card,RECIPES[ident])
			_label(card,_materials(recipe["inputs"])+"\n↓\n"+_materials(recipe["outputs"]))
			_label(card,"%d天 · 启动/收取各1AP" % recipe["days"])
			_label(card,_missing(recipe["inputs"]))
			var start := _icon(card,"play","启动 "+RECIPES[ident],func(): _result(world.start_batch(uid,ident)); _show_cell())
			start.disabled = _missing(recipe["inputs"]) != "投入齐备" or world.clock.ap < 1
		_icon(sidebar,"clear","拆除（1AP，无返还）",func(): _confirm("拆除%s？不返还建设材料或元石，消耗1AP。" % world.facility_defs[facility["facility_id"]]["name"],func(): _result(world.demolish_facility(uid)); _show_cell()))

func _show_build() -> void:
	_context = "build"
	_page("营建 · 加工设施")
	_label(sidebar,"选择设施，再到地图点击放置。建造消耗1AP，工具持续选中；右键取消。")
	var grid := GridContainer.new()
	grid.set_meta("layout","two")
	grid.columns = 2 if window_panel.size.x >= 740 else 1
	sidebar.add_child(grid)
	for ident in world.facility_defs:
		var definition: Dictionary = world.facility_defs[ident]
		var card := _card(grid)
		var row := HBoxContainer.new()
		card.add_child(row)
		_picture(row,ident,56)
		_heading(row,definition["name"])
		_label(card,"占地%d×%d · %d元石 · 1AP" % [definition["footprint"][0],definition["footprint"][1],definition["cash"]])
		_label(card,"材料："+_materials(definition["materials"]))
		_label(card,_missing(definition["materials"]))
		_icon(card,"build","放置 "+definition["name"],func():
			_close_page()
			_select_tool("inspect")
			build_tool = ident
			notice.text = "放置%s · 占地%d×%d，%d元石+%s · 右键取消" % [definition["name"],definition["footprint"][0],definition["footprint"][1],definition["cash"],_materials(definition["materials"])])

func _show_workers() -> void:
	_context = "workers"
	_page("雇工 · 最多2人")
	_label(sidebar,"成功1次收费1元石 · 每人每日最多12次 · 日结执行，不消耗玩家AP")
	var people := HBoxContainer.new()
	sidebar.add_child(people)
	for worker in world.workforce.state["workers"]:
		var card := _card(people)
		_heading(card,worker["name"]+(" · 当前" if worker["id"] == selected_worker else ""))
		_label(card,"%s · 每日预算%d元石" % ["暂停" if worker["paused"] else "受雇中",worker["budget"]])
		for report in world.workforce.state["report"]["workers"]:
			if report["worker_id"] == worker["id"]:
				_label(card,"上次成功%d次 · 费用%d元石" % [report["success"],report["fee"]])
		_icon(card,"workers","选择 "+worker["name"],func(): selected_worker = int(worker["id"]); _show_workers(); overlay.queue_redraw())
	if world.workforce.state["workers"].size() < 2:
		_icon(people,"workers","雇佣一人（无固定费用）",func():
			var result := world.workforce.hire("雇工%d" % world.workforce.state["next_worker_id"])
			_result(result)
			if result["ok"]: selected_worker = int(result["worker_id"])
			_show_workers())
	var worker := world.workforce._worker(selected_worker)
	if not worker.is_empty():
		var row := HBoxContainer.new()
		sidebar.add_child(row)
		_label(row,"每日预算（元石）")
		var budget := SpinBox.new()
		budget.min_value = 0
		budget.max_value = 1000000
		budget.value = worker["budget"]
		budget.custom_minimum_size.x = 130
		row.add_child(budget)
		budget.value_changed.connect(func(value): _result(world.workforce.configure(worker["id"],int(value),worker["paused"],worker["priorities"],worker["areas"])))
		var pause := CheckButton.new()
		pause.text = "暂停委托"
		pause.button_pressed = worker["paused"]
		pause.toggled.connect(func(value): _result(world.workforce.configure(worker["id"],worker["budget"],value,worker["priorities"],worker["areas"])))
		row.add_child(pause)
		_label(sidebar,"工作偏好0～5：0禁止。个人偏好 → 标记优先级 → 默认农务顺序。")
		var matrix := GridContainer.new()
		matrix.set_meta("layout","matrix")
		matrix.columns = 4 if window_panel.size.x >= 740 else 2
		sidebar.add_child(matrix)
		for kind in Workforce.KINDS:
			var field := VBoxContainer.new()
			matrix.add_child(field)
			_label(field,NAMES[kind])
			var preference := SpinBox.new()
			preference.set_meta("preference",kind)
			preference.min_value = 0
			preference.max_value = 5
			preference.value = worker["priorities"][kind]
			preference.value_changed.connect(func(value):
				var priorities: Dictionary = worker["priorities"].duplicate()
				priorities[kind] = int(value)
				_result(world.workforce.configure(worker["id"],worker["budget"],worker["paused"],priorities,worker["areas"])))
			field.add_child(preference)
		_heading(sidebar,"负责区域 · %d处" % worker["areas"].size())
		for index in range(worker["areas"].size()):
			var area: Array = worker["areas"][index]
			var line := HBoxContainer.new()
			sidebar.add_child(line)
			var label := _label(line,"区域%d · (%d,%d) %d×%d" % [index+1,area[0],area[1],area[2],area[3]])
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_icon(line,"locate","定位区域%d" % (index+1),func(): _close_page(); camera.position = Vector2(float(area[0])+float(area[2])*0.5,float(area[1])+float(area[3])*0.5)*64)
			_icon(line,"cancel","删除区域%d" % (index+1),func():
				var areas: Array = worker["areas"].duplicate(true)
				areas.remove_at(index)
				_result(world.workforce.configure(worker["id"],worker["budget"],worker["paused"],worker["priorities"],areas))
				_show_workers())
		var actions := HBoxContainer.new()
		sidebar.add_child(actions)
		_icon(actions,"area","框选追加负责区域",func(): _close_page(); expanded = true; _layout(); _select_tool("area"))
		_icon(actions,"cancel","清空负责区域",func(): _result(world.workforce.configure(worker["id"],worker["budget"],worker["paused"],worker["priorities"],[])); _show_workers())
		_icon(actions,"clear","解雇（免费）",func(): _result(world.workforce.dismiss(worker["id"])); selected_worker = 0; _show_workers())
		_label(sidebar,"资源点单独指派；区域之外不找农务目标。物品直接进出共享仓库。")
	_icon(sidebar,"history","查看上次工作日报",_show_report)

func _show_report() -> void:
	_context = "report"
	_page("日结工作报告")
	var report: Dictionary = world.workforce.state["report"]
	_label(sidebar,"累计人工支出：%d元石" % world.workforce.state["spent"])
	for worker in report["workers"]:
		_label(sidebar,"%s：成功%d次，费用%d元石\n%s" % [worker["name"],worker["success"],worker["fee"],worker["reason"]])
		for kind in worker["counts"]: _label(sidebar,"%s %d次" % [NAMES[kind],worker["counts"][kind]])
	if not world.daily_save_error.is_empty():
		_label(sidebar,"保存失败，后续操作暂停。")
		_button(sidebar,"重试日存档",func(): _result(world.retry_day_save()); _show_report())
	_icon(sidebar,"workers","雇工设置",_show_workers)
	_icon(sidebar,"history","经营条目",_show_history)

func _show_help() -> void:
	_context = "help"
	_page("经营手册 · 随时可自由操作")
	for step in Journal.GUIDE:
		_label(sidebar,("✓ " if step in world.journal["guide"]["seen"] else "• ")+GUIDE_TEXT[step])
	_label(sidebar,"资源点点选后单独派工；仓库共享，不需要搬运。每天24AP，结束当天统一结算和保存。")
	_label(sidebar,"清理不返还投入；取消任务不会取消选种。建筑建拆、加工启动/收取仍手动。")
	if _started:
		_icon(sidebar,"cancel","跳过操作提示",func(): _result(world.guide_dismiss(true)); _show_help())
		_icon(sidebar,"play","恢复操作提示",func(): _result(world.guide_dismiss(false)); _show_help())
	_icon(sidebar,"history","查看经营记录",_show_history)

func _entries(report: Dictionary) -> Array:
	var row: Dictionary = report["totals"]
	var entries := []
	for warning in report["warnings"]: entries.append("[雇工] %s：%s" % [warning["name"],warning["reason"]])
	if not row["fieldwork"].is_empty():
		var work := PackedStringArray()
		for kind in row["fieldwork"]: work.append("%s%d次" % [NAMES[kind],row["fieldwork"][kind]])
		entries.append("[农务] "+"、".join(work))
	for key in ["plantings","harvests","matured","cleared"]:
		for ident in row[key]: entries.append("[农务] %s%s%d次" % [CROPS[ident],{"plantings":"播种","harvests":"收获","matured":"成熟","cleared":"清理"}[key],row[key][ident]])
	if not row["produce"].is_empty(): entries.append("[收成] "+_materials(row["produce"]))
	if not row["collected"].is_empty(): entries.append("[采集] "+_materials(row["collected"]))
	for ident in row["batches_completed"]: entries.append("[加工] %s完成%d批，等待收取" % [RECIPES[ident],row["batches_completed"][ident]])
	for ident in row["batches_started"]: entries.append("[加工] %s投料%d批" % [RECIPES[ident],row["batches_started"][ident]])
	if not row["processed"].is_empty(): entries.append("[入库] "+_materials(row["processed"]))
	for path in row["deliveries"]: entries.append("[供货] %s行完成%d单" % [{"wood":"木","fire":"火","earth":"土","water":"水","gold":"金"}[path],row["deliveries"][path]])
	for ident in row["buildings"]: entries.append("[建设] %s%d座" % [world.facility_defs[ident]["name"],row["buildings"][ident]])
	if Journal.income(row) > 0: entries.append("[交易] 销售%d、订单%d元石" % [row["sales_revenue"],row["order_revenue"]])
	if Journal.expense(row) > 0: entries.append("[支出] 采购%d、建设%d、人工%d元石" % [row["purchase_spend"],row["construction_spend"],row["labour_spend"]])
	if entries.is_empty(): entries.append("[田间] 今日休养，无新增经营事件。")
	return entries

func _daily_summary(day: int, saved: bool) -> void:
	match _context:
		"cell": _show_cell()
		"workers": _show_workers()
		"market": _show_market()
		"orders": _show_orders()
		"report": _show_report()
		"help": _show_help()
		"history": _show_history()
		"recap": _show_recap(-1)
	for child in digest_body.get_children():
		digest_body.remove_child(child)
		child.queue_free()
	var row := HBoxContainer.new()
	digest_body.add_child(row)
	var title := _label(row,"第%d天 · %s" % [day,"时节更替" if day%15 == 0 else "经营摘要"])
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_icon(row,"history","摘要详情",_show_history)
	_icon(row,"close","收起摘要",func(): digest.visible = false)
	var report: Dictionary = world.journal["history"].back()
	var entries := _entries(report)
	if not saved and not world.daily_save_error.is_empty(): entries.push_front("[存档] 保存失败，请打开详情重试。")
	if day%15 == 0 and day <= 45:
		var term: Dictionary = world.journal["terms"][int(day/15)-1]
		entries.push_front("[时节] 本节收入%d、支出%d，净现金变化%d元石" % [Journal.income(term),Journal.expense(term),Journal.income(term)-Journal.expense(term)])
	var compact := ui_root.size.y < 600
	var limit := 1 if compact else 3
	if compact: title.text = "第%d天 · %d条记事" % [day,entries.size()]
	for index in range(mini(limit,entries.size())):
		var line := UI.label("• "+entries[index])
		line.custom_minimum_size.x = minf(480,board.size.x-48)
		line.clip_text = true
		line.tooltip_text = entries[index]
		digest_body.add_child(line)
	if entries.size() > limit and not compact:
		var more := _label(digest_body,"另有%d条，点击详情查看。" % (entries.size()-3))
		more.autowrap_mode = TextServer.AUTOWRAP_OFF
	digest.size.y = 0
	digest.reset_size.call_deferred()
	digest.visible = true
	if day == 45: _show_recap.call_deferred(-1)

func _show_history() -> void:
	_context = "history"
	_page("田园记事 · 最近15天")
	var row := HBoxContainer.new()
	sidebar.add_child(row)
	_button(row,"首次45天回顾",_show_recap.bind(-1))
	_button(row,"详细工作日报",_show_report)
	if not world.daily_save_error.is_empty():
		_label(sidebar,"日存档失败，后续操作暂停。")
		_button(sidebar,"重试日存档",func(): _result(world.retry_day_save()); _show_history())
	for index in range(world.journal["history"].size()-1,-1,-1):
		var report: Dictionary = world.journal["history"][index]
		var card := _card(sidebar)
		_heading(card,"第%d天%s" % [report["day"]," · 时节更替" if int(report["day"])%15 == 0 else ""])
		if int(report["day"])%15 == 0 and int(report["day"]) <= 45:
			var term: Dictionary = world.journal["terms"][int(int(report["day"])/15)-1]
			_label(card,"本时节 收入%d / 支出%d / 净现金变化%d元石" % [Journal.income(term),Journal.expense(term),Journal.income(term)-Journal.expense(term)])
		for entry in _entries(report):
			var line := HBoxContainer.new()
			card.add_child(line)
			var kind: String = "history"
			if entry.begins_with("[农务]") or entry.begins_with("[收成]"): kind = "plant"
			elif entry.begins_with("[加工]") or entry.begins_with("[入库]"): kind = "build"
			elif entry.begins_with("[雇工]"): kind = "workers"
			elif entry.begins_with("[供货]"): kind = "orders"
			elif entry.begins_with("[交易]") or entry.begins_with("[支出]"): kind = "market"
			_picture(line,kind,24)
			var label := _label(line,entry)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Historical aggregates retain no cell identity. Only current, still-existing targets are linked.
		for recipe in report["totals"]["batches_completed"]:
			for facility in world.facilities.values():
				if facility["batch"].get("recipe_id") == recipe:
					_icon(card,"locate","定位现有设施："+RECIPES[recipe],func(): _locate(Vector2i(int(facility["origin"][0]),int(facility["origin"][1]))))
		for item in report["totals"]["collected"]:
			for source in world.source_defs.values():
				if source["item"] == item:
					_icon(card,"locate","定位资源点："+world._items[item]["name"],func(): _locate(Vector2i(int(source["position"][0]),int(source["position"][1]))))
		for ident in report["totals"]["matured"]:
			for crop in world.crops.values():
				if crop["crop_id"] == ident and crop["state"] == "mature":
					_icon(card,"locate","定位现有成熟植物："+CROPS[ident],func(): _locate(Vector2i(int(crop["origin"][0]),int(crop["origin"][1]))))

func _locate(cell: Vector2i) -> void:
	_close_page()
	selected = cell
	_side_open = true
	camera.position = Vector2(cell)*64+Vector2(32,32)
	_show_cell()
	_layout()

func _show_recap(term_index: int = -1) -> void:
	_context = "recap"
	_page("首次45天 · 经营账")
	var state: Dictionary = world.journal
	if int(state["start_day"]) >= 45:
		_label(sidebar,"此旧存档的首次45天未记录，无法生成回顾；升级后的每日经营条目仍可查看。")
		_button(sidebar,"每日经营条目",_show_history)
		return
	if int(state["start_day"]) > 0: _label(sidebar,"旧档从第%d天开始记录，此前行为未记录。" % (int(state["start_day"])+1))
	_label(sidebar,"第45天结束已冻结统计；关闭窗口继续经营。" if state["frozen"] else "已结算%d/45天；当天尚未结算的操作暂不计入。" % world.clock.total_days)
	var tabs := HBoxContainer.new()
	sidebar.add_child(tabs)
	_button(tabs,"45天总计",_show_recap.bind(-1))
	for index in range(3): _button(tabs,"第%d时节小计" % (index+1),_show_recap.bind(index))
	var comparison := GridContainer.new()
	comparison.columns = 4
	sidebar.add_child(comparison)
	for heading in ["收支（元石）","第1时节","第2时节","第3时节"]: _label(comparison,heading)
	for kind in ["sales_revenue","order_revenue","purchase_spend","construction_spend","labour_spend","net"]:
		_label(comparison,{"sales_revenue":"销售收入","order_revenue":"订单收入","purchase_spend":"采购支出","construction_spend":"建设支出","labour_spend":"人工支出","net":"净现金变化"}[kind])
		for term in state["terms"]:
			_label(comparison,str(Journal.income(term)-Journal.expense(term) if kind == "net" else term[kind]))
	var row: Dictionary = Journal.totals(state) if term_index < 0 else state["terms"][term_index]
	var accounts := _card(sidebar)
	_heading(accounts,"45天总计" if term_index < 0 else "第%d时节小计" % (term_index+1))
	_label(accounts,"收入%d（销售%d / 订单%d） · 支出%d（采购%d / 建设%d / 人工%d）\n净现金变化%d元石" % [Journal.income(row),row["sales_revenue"],row["order_revenue"],Journal.expense(row),row["purchase_spend"],row["construction_spend"],row["labour_spend"],Journal.income(row)-Journal.expense(row)])
	var grid := GridContainer.new()
	grid.set_meta("layout","three")
	grid.columns = 3 if window_panel.size.x >= 900 else (2 if window_panel.size.x >= 660 else 1)
	sidebar.add_child(grid)
	for key in ["plantings","harvests","produce","collected","batches_started","batches_completed","processed","deliveries","delivered_items","buildings","work_actions","fieldwork"]:
		if row[key].is_empty(): continue
		var card := _card(grid)
		_label(card,{"plantings":"种植株次","harvests":"收获次数","produce":"作物产量","collected":"采集数量","batches_started":"加工投料批次","batches_completed":"完成批次","processed":"加工收取产量","deliveries":"五行供货单数","delivered_items":"供货材料","buildings":"建设数量","work_actions":"雇工成功操作","fieldwork":"开垦与养护次数"}[key])
		for ident in row[key]:
			var name: String = CROPS.get(ident,RECIPES.get(ident,NAMES.get(ident,world.facility_defs.get(ident,{}).get("name",world._items.get(ident,{}).get("name",{"wood":"木","fire":"火","earth":"土","water":"水","gold":"金"}.get(ident,ident))))))
			_label(card,"%s ×%d" % [name,row[key][ident]])
	if term_index < 0 and state["frozen"]:
		_label(sidebar,"记录期初%d → 第45天期末%d元石；库存另列，不折算利润。" % [state["start_cash"],state["end_cash"]])
		if not state["end_inventory"].is_empty(): _label(sidebar,"期末库存："+_materials(state["end_inventory"]))
	_icon(sidebar,"play","继续经营",_close_page)

func _show_market() -> void:
	_context = "market"
	_page("行囊与市集 · 固定价格")
	_label(sidebar,"共有18类物品 · 仓库共享 · 当前元石 %d" % world.primeval_stones)
	var categories := HBoxContainer.new()
	sidebar.add_child(categories)
	for category in ["全部","种子","原料","加工","可供养","持有"]:
		var button := _button(categories,category,func(): market_category = category; _show_market())
		button.toggle_mode = true
		button.button_pressed = market_category == category
	var grid := GridContainer.new()
	grid.set_meta("layout","three")
	grid.columns = 3 if window_panel.size.x >= 900 else (2 if window_panel.size.x >= 660 else 1)
	sidebar.add_child(grid)
	for ident in world._items:
		var item: Dictionary = world._items[ident]
		if market_category == "种子" and "seed" not in item["tags"]: continue
		if market_category == "加工" and item["stage"] != "intermediate": continue
		if market_category == "原料" and ("seed" in item["tags"] or item["stage"] == "intermediate"): continue
		if market_category == "可供养" and not item["supply_allowed"]: continue
		if market_category == "持有" and world.inventory.count(ident) == 0: continue
		var button := _button(grid,"%s  ×%d" % [item["name"],world.inventory.count(ident)],func(): market_item = ident; _show_market())
		button.icon = Icons.get_icon(ident)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",30)
		button.toggle_mode = true
		button.button_pressed = ident == market_item
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "%s · 买%d / 卖%d元石 · %s" % [item["name"],item["buy_price"],item["sell_price"],"可供养" if item["supply_allowed"] else "生产材料"]
	var item: Dictionary = world._items[market_item]
	var card := _card(sidebar)
	sidebar.move_child(card.get_parent(),categories.get_index()+1)
	_heading(card,item["name"])
	_label(card,"持有%d · 单价 买%d / 卖%d元石 · 可购%d / 可售%d" % [world.inventory.count(market_item),item["buy_price"],item["sell_price"],int(world.primeval_stones/maxi(1,item["buy_price"])) if item["buy_price"] > 0 else 0,world.inventory.count(market_item) if item["sell_price"] > 0 else 0])
	var row := HBoxContainer.new()
	card.add_child(row)
	_label(row,"数量")
	trade_spin = SpinBox.new()
	trade_spin.min_value = 1
	trade_spin.max_value = 1000000
	trade_spin.value = trade_quantity
	trade_spin.custom_minimum_size.x = 130
	row.add_child(trade_spin)
	for amount in [1,5,10]: _button(row,str(amount),func(): trade_spin.value = amount)
	trade_total = _label(card,"")
	var actions := HBoxContainer.new()
	card.add_child(actions)
	trade_buy = _icon(actions,"buy","购买所选数量",func(): _trade(true))
	trade_sell = _icon(actions,"sell","出售所选数量",func(): _trade(false))
	trade_spin.value_changed.connect(func(value): trade_quantity = int(value); _update_trade())
	_update_trade()

func _update_trade() -> void:
	var item: Dictionary = world._items[market_item]
	var buy := int(item["buy_price"])*trade_quantity
	var sell := int(item["sell_price"])*trade_quantity
	trade_total.text = "买入总价 %d / 卖出总价 %d 元石" % [buy,sell]
	trade_buy.disabled = item["buy_price"] <= 0 or buy > world.primeval_stones
	trade_sell.disabled = item["sell_price"] <= 0 or trade_quantity > world.inventory.count(market_item)
	trade_buy.tooltip_text = "不可采购" if item["buy_price"] <= 0 else ("元石不足，需%d" % buy if buy > world.primeval_stones else "买入%d份 · %d元石" % [trade_quantity,buy])
	trade_sell.tooltip_text = "不可出售" if item["sell_price"] <= 0 else ("库存不足，持有%d" % world.inventory.count(market_item) if trade_quantity > world.inventory.count(market_item) else "出售%d份 · %d元石" % [trade_quantity,sell])
	if trade_buy.disabled and item["buy_price"] > 0: trade_total.text += " · 元石不足"
	if trade_sell.disabled and item["sell_price"] > 0: trade_total.text += " · 库存不足"

func _trade(buying: bool) -> void:
	trade_spin.apply()
	trade_quantity = int(trade_spin.value)
	var scroll := window_scroll.scroll_vertical
	_result(world.buy(market_item,trade_quantity) if buying else world.sell(market_item,trade_quantity))
	_show_market()
	window_scroll.set_deferred("scroll_vertical",scroll)

func _show_orders() -> void:
	_context = "orders"
	_page("五行供货 · 当前开放%d转" % world.unlocked_rank())
	_label(sidebar,"营业收入%d元石 · 每日3单 · 未完成不罚款 · 仅必要数量享10%%溢价" % world.gross_revenue())
	for order in world.daily_orders():
		var card := _card(sidebar)
		var row := HBoxContainer.new()
		card.add_child(row)
		_picture(row,order["path"])
		_heading(row,"%s行 · %d转 · 需求%d供养值" % [{"wood":"木","fire":"火","earth":"土","water":"水","gold":"金"}[order["path"]],order["rank"],order["demand"]])
		if order["status"] == "completed":
			_label(card,"✓ 已交付 · 回款%d元石 · 每单仅结算一次" % order["receipt"]["payout"])
			continue
		for ident in world._items:
			var quote := world.order_quote(order["id"],ident)
			if not quote["ok"]: continue
			var item: Dictionary = world._items[ident]
			var line := HBoxContainer.new()
			card.add_child(line)
			_picture(line,ident,30)
			var label := _label(line,"%s · 持有%d / 需要%d · 每份%d供养\n回款%d = 市价%d + 溢价%d" % [item["name"],world.inventory.count(ident),quote["quantity"],item["supply_value"],quote["payout"],quote["base"],quote["premium"]])
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var button := _icon(line,"claim","%s×%d → %d元石" % [item["name"],quote["quantity"],quote["payout"]],func(): _result(world.deliver_order(order["id"],ident)); _show_orders())
			button.disabled = not world.inventory.has(ident,int(quote["quantity"]))
			if button.disabled: button.tooltip_text += " · 库存不足"

func _process(delta: float) -> void:
	if not _started: return
	if settings.data["show_fps"]: _refresh()
	if shade.visible or _text_focus() or is_instance_valid(confirmation): return
	var dir := Input.get_vector("move_left","move_right","move_up","move_down")
	camera.position += dir*(400.0/camera.zoom.x)*delta
	var half := Vector2(map_port.size)*0.5/camera.zoom.x
	camera.position.x = clampf(camera.position.x,minf(half.x,640.0),maxf(640.0,1280.0-half.x))
	camera.position.y = clampf(camera.position.y,minf(half.y,448.0),maxf(448.0,896.0-half.y))

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if is_instance_valid(confirmation): return
	if event.keycode == KEY_ESCAPE:
		if _drag or not build_tool.is_empty() or tool != "inspect": _select_tool("inspect")
		elif shade.visible and _started: _close_page()
		else: _menu()
		get_viewport().set_input_as_handled()
		return
	if _text_focus() or shade.visible or not _started: return
	var tools := ["inspect","till","plant","harvest","irrigate","fertilize","fell","clear","cancel","area"]
	if event.keycode >= KEY_0 and event.keycode <= KEY_9:
		expanded = true
		_layout()
		_select_tool(tools[event.keycode-KEY_0])
	match event.keycode:
		KEY_M: _show_market()
		KEY_O: _show_orders()
		KEY_U: _show_workers()
		KEY_B: _show_build()
		KEY_J: _show_history()
		KEY_F: _fit_map()
		KEY_R: _result(world.end_day())

func draw_map(target: Node2D) -> void:
	var font := theme.default_font
	var readable := maxf(1.0,1.0/(camera.zoom.x*_ui_scale))
	for crop in world.crops.values():
		var shape: Array = world.crop_defs[crop["crop_id"]]["footprint"]
		var rect := Rect2(Vector2(float(crop["origin"][0]),float(crop["origin"][1]))*64.0,Vector2(float(shape[0]),float(shape[1]))*64.0)
		target.draw_rect(rect.grow(-7),Color("deebd9") if crop["state"] != "mature" else Color("f1e2b1"))
		target.draw_texture_rect(Icons.get_icon(crop["crop_id"]),Rect2(rect.position+Vector2(10,8),rect.size-Vector2(20,20)),false)
		if crop["state"] == "mature": target.draw_circle(rect.end-Vector2(10,10),5*readable,UI.JADE)
	for building in world.facilities.values():
		var shape: Array = world.facility_defs[building["facility_id"]]["footprint"]
		var rect := Rect2(Vector2(float(building["origin"][0]),float(building["origin"][1]))*64.0,Vector2(float(shape[0]),float(shape[1]))*64.0)
		target.draw_rect(rect.grow(-5),Color("eee5d6"))
		target.draw_texture_rect(Icons.get_icon(building["facility_id"]),rect.grow(-14),false)
		if building["batch"].get("status") == "ready": target.draw_circle(rect.end-Vector2(10,10),6*readable,UI.WATER)
	for ident in world.source_defs:
		var definition: Dictionary = world.source_defs[ident]
		var position := Vector2(float(definition["position"][0]),float(definition["position"][1]))*64.0
		target.draw_rect(Rect2(position+Vector2(4,4),Vector2(56,56)),Color("deedf0"))
		target.draw_texture_rect(Icons.get_icon(definition["item"]),Rect2(position+Vector2(8,8),Vector2(48,48)),false)
		if world.workforce.state["sources"].has(ident): target.draw_circle(position+Vector2(52,12),5*readable,UI.JADE)
	for worker in world.workforce.state["workers"]:
		if worker["id"] != selected_worker: continue
		for area in worker["areas"]:
			target.draw_rect(Rect2(Vector2(float(area[0]),float(area[1]))*64.0,Vector2(float(area[2]),float(area[3]))*64.0),Color(0.4,0.7,0.7,0.16))
	var stacks := {}
	for mark in world.workforce.state["marks"]:
		var position := Vector2(float(mark["cell"][0]),float(mark["cell"][1]))*64.0
		var index := int(stacks.get(position,0))
		stacks[position] = index+1
		if index > 0 and camera.zoom.x*_ui_scale < 0.8: continue
		var offset := Vector2(3+(index%2)*29,3+(index/2)*22)
		var extent := Vector2(28,22)*readable
		target.draw_rect(Rect2(position+offset,extent),UI.PANEL)
		target.draw_texture_rect(Icons.get_icon(mark["kind"]),Rect2(position+offset,Vector2(18,18)*readable),false)
		target.draw_string(font,position+offset+Vector2(18,16)*readable,str(mark["priority"]),HORIZONTAL_ALIGNMENT_LEFT,-1,int(14*readable),UI.PAPER)
	for plan in world.workforce.state["seed_plans"]:
		var position := Vector2(float(plan["cell"][0]),float(plan["cell"][1]))*64.0
		target.draw_circle(position+Vector2(52,12),4*readable,UI.JADE)
	if selected.x >= 0: target.draw_rect(Rect2(Vector2(selected)*64.0,Vector2(64,64)),UI.JADE,false,2*readable)
	if not build_tool.is_empty() and world.grid.in_bounds(_hover.x,_hover.y):
		var definition: Dictionary = world.facility_defs[build_tool]
		var valid: bool = world.can_build_facility(_hover,build_tool)["ok"]
		var rect := Rect2(Vector2(_hover)*64,Vector2(float(definition["footprint"][0]),float(definition["footprint"][1]))*64)
		target.draw_rect(rect,Color(0.35,0.6,0.4,0.3) if valid else Color(0.7,0.25,0.2,0.3))
		target.draw_rect(rect,UI.JADE if valid else UI.ERROR,false,3*readable)
		target.draw_texture_rect(Icons.get_icon(build_tool),rect.grow(-12),false,Color(1,1,1,0.65))
	if _drag:
		var rect := _rect(_drag_start,_drag_end)
		if tool not in ["inspect","area","cancel"]:
			var preview := world.workforce.preview(rect,tool)
			for cell in preview["valid"]: target.draw_rect(Rect2(Vector2(cell)*64,Vector2(64,64)),Color(0.35,0.65,0.4,0.3))
			for cell in preview["invalid"]: target.draw_rect(Rect2(Vector2(cell)*64,Vector2(64,64)),Color(0.7,0.25,0.2,0.28))
		target.draw_rect(Rect2(Vector2(rect.position)*64.0,Vector2(rect.size)*64.0),UI.PANEL,false,2*readable)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_confirm("退出将放弃当天未保存的操作。",func(): get_tree().quit())

func _shot(directory: String, name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory+"/"+name+".png")

func _preview(directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var desired := Vector2i.ZERO
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-size="):
			var parts := arg.trim_prefix("--shot-size=").split("x")
			desired = Vector2i(int(parts[0]),int(parts[1]))
	if desired.x > 0 and desired.y > 0:
		get_window().borderless = true
		await get_tree().process_frame
		await get_tree().process_frame
		get_window().size = desired
		await get_tree().process_frame
		await get_tree().process_frame
		# Windows can retain the old non-client extent after a borderless transition.
		for attempt in range(2):
			var actual := Vector2i(get_viewport().get_visible_rect().size)
			if actual == desired: break
			get_window().size -= actual-desired
			await get_tree().process_frame
			await get_tree().process_frame
		var dimensions := FileAccess.open(directory+"/dimensions.json",FileAccess.WRITE)
		dimensions.store_string(JSON.stringify({"requested":[desired.x,desired.y],"viewport":[get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y]}))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ui-scale="): _ui_scale = float(arg.trim_prefix("--ui-scale="))/100.0
	_layout()
	await _shot(directory,"slots")
	_new(1,false)
	world.workforce.hire("阿禾")
	selected_worker = 1
	var worker: Dictionary = world.workforce.state["workers"][0]
	world.workforce.configure(1,12,false,worker["priorities"],[[1,1,8,4]])
	world.workforce.set_seed(Vector2i(2,2),"golden_wheat")
	world.workforce.mark(Rect2i(1,1,8,4),"till")
	expanded = true
	_layout()
	_fit_map()
	_show_workers()
	await _shot(directory,"workforce")
	_close_page()
	world.end_day()
	await _shot(directory,"daily-digest")
	_show_report()
	await _shot(directory,"work-report")
	_show_history()
	await _shot(directory,"daily-entries")
	_show_help()
	await _shot(directory,"guide")
	_show_market()
	await _shot(directory,"market")
	_show_orders()
	await _shot(directory,"orders")
	_show_build()
	await _shot(directory,"build")
	_show_settings()
	await _shot(directory,"settings")
	_close_page()
	digest.visible = false
	world.workforce.assign_source("spring_source",1)
	_locate(Vector2i(17,8))
	await _shot(directory,"source-assignment")
	_locate(Vector2i(2,2))
	await _shot(directory,"crop-detail")
	_select_tool("till")
	_drag = true
	_drag_start = Vector2i(1,1)
	_drag_end = Vector2i(9,4)
	_hover = _drag_end
	_update_hover()
	await _shot(directory,"designation-preview")
	_drag = false
	_select_tool("inspect")
	# Isolated visual fixture only: never written to player slots.
	world.inventory.add("raw_wood",12)
	world.inventory.add("raw_stone",12)
	build_tool = "woodshop"
	_hover = Vector2i(8,3)
	_update_hover()
	await _shot(directory,"placement-preview")
	world.build_facility(Vector2i(8,3),"woodshop")
	build_tool = ""
	_locate(Vector2i(8,3))
	await _shot(directory,"processing")
	_confirm("清理金穗麦？不返还投入，持续选种计划保留。",func(): pass)
	await _shot(directory,"confirmation")
	confirmation.queue_free()
	if FileAccess.file_exists("res://.art-work/v1-f-45days.json"):
		var result: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.art-work/v1-f-45days.json"))
		if result.has("snapshot") and store.create_slot(1,result["snapshot"],true)["ok"]:
			world.open_game(1)
			_show_recap(-1)
			await _shot(directory,"45day-recap")
			_show_recap(1)
			await _shot(directory,"term-recap")
	for slot in [1,2,3]:
		if store.occupied(slot): store.delete_slot(slot,true)
	DirAccess.remove_absolute(store.slot_path(1).get_base_dir())
	get_tree().quit()
