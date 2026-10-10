extends Control
## V1 interaction shell. Designations are free; people work only at day settlement.
const World := preload("res://scripts/farming/v1/v1_world.gd")
const Store := preload("res://scripts/farming/v1/v1_slot_store.gd")
const Workforce := preload("res://scripts/farming/v1/v1_workforce.gd")
const Data := preload("res://scripts/farming/v1/v1_data.gd")
const Terrain := preload("res://scripts/farming/rendering/terrain_renderer.gd")
const UI := preload("res://scripts/farming/rendering/farm_ui_style.gd")
const Journal := preload("res://scripts/farming/v1/v1_journal.gd")
const NAMES := {"inspect":"查看","till":"开垦","plant":"播种","harvest":"收获","irrigate":"浇水","fertilize":"施肥","fell":"砍伐","clear":"清理","cancel":"取消标记","area":"负责区域","source":"资源采集"}
const CROPS := {"golden_wheat":"金穗麦","fast_fir":"速生杉","resin_tree":"松脂树","wood_decay_mushroom":"木腐菇"}
const RECIPES := {"saw_planks":"锯切木板","shred_wood":"原木粉碎","shred_twigs":"枝条粉碎","char_twigs":"枝条炭化","compost_straw":"秸秆堆肥","compost_twigs":"枝条堆肥","compost_chips":"木屑堆肥","smelt_charcoal":"木炭冶炼","smelt_resin":"松脂冶炼"}
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
	DisplayServer.window_set_title("灵田 Demo V1 · 农务派工")
	get_tree().auto_accept_quit = false
	var args := OS.get_cmdline_user_args()
	var shots := ""
	var smoke := false
	for arg in args:
		if arg.begins_with("--v1-shots="): shots = arg.trim_prefix("--v1-shots=")
		if arg == "--v1-smoke": smoke = true
	if smoke or not shots.is_empty(): store = Store.new("user://v1_scene_preview_%d" % Time.get_ticks_usec())
	world = World.new(store)
	_build()
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
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _label(parent: Node, text: String) -> Label:
	var label := UI.label(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _build() -> void:
	var background := ColorRect.new()
	background.color = UI.INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var top := HBoxContainer.new()
	top.position = Vector2(8,6)
	top.size = Vector2(624,28)
	add_child(top)
	header = _label(top,"")
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(top,"雇工",_show_workers)
	_button(top,"行囊/交易",_show_market)
	_button(top,"订单",_show_orders)
	_button(top,"结束当天",func(): _result(world.end_day()))
	_button(top,"菜单",_menu)
	var help_row := HBoxContainer.new()
	help_row.position = Vector2(8,32)
	help_row.size = Vector2(624,18)
	add_child(help_row)
	guide_hint = UI.label("",true)
	guide_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_hint.clip_text = true
	help_row.add_child(guide_hint)
	_button(help_row,"手册",_show_help)
	_button(help_row,"记录",_show_history)
	map_view = SubViewportContainer.new()
	map_view.position = Vector2(8,58)
	map_view.stretch = true
	map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map_view)
	map_port = SubViewport.new()
	map_port.handle_input_locally = false
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
	camera.zoom = Vector2(0.5,0.5)
	root.add_child(camera)
	overlay = Overlay.new()
	overlay.owner_ref = weakref(self)
	root.add_child(overlay)
	board = Control.new()
	board.position = map_view.position
	board.mouse_default_cursor_shape = Control.CURSOR_CROSS
	board.gui_input.connect(_board_input)
	add_child(board)
	toolbar = VBoxContainer.new()
	toolbar.position = Vector2(8,304)
	toolbar.custom_minimum_size.x = 416
	add_child(toolbar)
	var toggle_row := HBoxContainer.new()
	toolbar.add_child(toggle_row)
	_button(toggle_row,"农务工具 ▾",func():
		expanded = not expanded
		_layout())
	var priority_label := _label(toggle_row,"标记优先级")
	priority_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	priority_label.custom_minimum_size.x = 84
	var urgency := SpinBox.new()
	urgency.min_value = 1
	urgency.max_value = 9
	urgency.value = task_priority
	urgency.value_changed.connect(func(value): task_priority = int(value))
	toggle_row.add_child(urgency)
	tool_grid = GridContainer.new()
	tool_grid.columns = 5
	toolbar.add_child(tool_grid)
	for kind in ["inspect","till","plant","harvest","irrigate","fertilize","fell","clear","cancel","area"]:
		var button := _button(tool_grid,NAMES[kind],_select_tool.bind(kind))
		button.custom_minimum_size.x = 80
		button.toggle_mode = true
		button.button_pressed = kind == tool
		tool_buttons[kind] = button
	var panel := PanelContainer.new()
	panel.position = Vector2(432,58)
	panel.size = Vector2(200,282)
	add_child(panel)
	side_scroll = ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(side_scroll)
	sidebar = VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.custom_minimum_size.x = 180
	side_scroll.add_child(sidebar)
	notice = UI.label("")
	notice.position = Vector2(8,346)
	notice.size = Vector2(624,14)
	notice.clip_text = true
	add_child(notice)
	digest = PanelContainer.new()
	digest.position = Vector2(12,62)
	digest.size = Vector2(400,0)
	digest.visible = false
	add_child(digest)
	digest_body = VBoxContainer.new()
	digest.add_child(digest_body)
	_layout()

func _layout() -> void:
	tool_grid.visible = expanded
	var height := toolbar.get_combined_minimum_size().y
	toolbar.size = Vector2(416,height)
	toolbar.position.y = 338-height
	board.size = Vector2(416,maxf(96,toolbar.position.y-62))
	map_view.size = board.size

func _refresh() -> void:
	header.text = "第%d天  AP %d/24  元石%d" % [world.clock.total_days+1,world.clock.ap,world.primeval_stones]
	board.mouse_filter = Control.MOUSE_FILTER_STOP if _started else Control.MOUSE_FILTER_IGNORE
	overlay.queue_redraw()
	guide_hint.text = "WASD平移，滚轮缩放；框选标记在日结执行。"
	if _started and not world.journal["guide"]["dismissed"]:
		for step in Journal.GUIDE:
			if step not in world.journal["guide"]["seen"]:
				guide_hint.text = "提示："+GUIDE_TEXT[step]
				break

func _page(title: String) -> void:
	for child in sidebar.get_children():
		sidebar.remove_child(child)
		child.queue_free()
	side_scroll.scroll_vertical = 0
	_label(sidebar,title)

func _result(result: Dictionary) -> void:
	notice.text = result.get("reason", "已更新；每日结束自动保存。") if not result["ok"] else "已更新；每日结束自动保存。"
	if result.get("save_error","") != "": notice.text = "日存档失败，请在日报重试。"
	notice.modulate = UI.PAPER if result["ok"] else UI.ERROR
	_refresh()

func _confirm(text: String, action: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = text
	dialog.title = "请确认"
	dialog.confirmed.connect(action)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.confirmed.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(340,140))

func _show_slots() -> void:
	_context = "slots"
	digest.visible = false
	_page("Demo V1 · 三个存档槽")
	_label(sidebar,"每日结束自动存档。新建不会转换V0存档。")
	for slot in [1,2,3]:
		var occupied: bool = store.occupied(slot)
		if occupied:
			_button(sidebar,"继续槽%d" % slot,_open.bind(slot))
		_button(sidebar,"新建槽%d" % slot,func():
			if occupied: _confirm("覆盖槽%d的V1存档？" % slot,_new.bind(slot,true))
			else: _new(slot,false))

func _new(slot: int, overwrite: bool) -> void:
	var result := world.start_new(slot,overwrite)
	_result(result)
	if result["ok"]:
		_started = true
		_refresh()
		_show_workers()

func _open(slot: int) -> void:
	var result := world.open_game(slot)
	_result(result)
	if result["ok"]:
		_started = true
		_refresh()
		_show_workers()

func _menu() -> void:
	if not _started: return
	_confirm("返回菜单将放弃当天尚未保存的操作。",func():
		world.abandon_day()
		store.close_session()
		_started = false
		_drag = false
		_show_slots()
		_refresh())

func _select_tool(kind: String) -> void:
	tool = kind
	_drag = false
	for ident in tool_buttons: tool_buttons[ident].set_pressed_no_signal(ident == kind)
	notice.text = "当前工具：%s；框选符合条件的地格。" % NAMES[kind]
	if kind == "clear": notice.text = "清理不返还投入；保留选种会重播，想留空请取消选种。"
	if kind == "cancel": notice.text = "取消手工标记；地格选种仍生效，想留空请取消选种。"
	if kind == "area": notice.text = "为当前雇工框选负责区域；可追加多个区域。"

func _cell(position: Vector2) -> Vector2i:
	var point := map_port.get_canvas_transform().affine_inverse()*position
	return Vector2i(floori(point.x/64.0),floori(point.y/64.0))

func _rect(a: Vector2i,b: Vector2i) -> Rect2i:
	var left := Vector2i(maxi(0,mini(a.x,b.x)),maxi(0,mini(a.y,b.y)))
	var right := Vector2i(mini(world.grid.width-1,maxi(a.x,b.x)),mini(world.grid.height-1,maxi(a.y,b.y)))
	return Rect2i(left,right-left+Vector2i.ONE)

func _board_input(event: InputEvent) -> void:
	if not _started: return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var zoom := clampf(camera.zoom.x*(2.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.5),0.5,2.0)
			camera.zoom = Vector2(zoom,zoom)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_start = _cell(event.position)
				_drag_end = _drag_start
				_drag = true
			elif _drag:
				_drag = false
				_drag_end = _cell(event.position)
				apply_rectangle(_rect(_drag_start,_drag_end))
	elif event is InputEventMouseMotion and _drag:
		_drag_end = _cell(event.position)
	overlay.queue_redraw()

func apply_rectangle(rect: Rect2i) -> void:
	if not _started or rect.size.x <= 0 or rect.size.y <= 0: return
	if tool == "inspect":
		selected = rect.position
		_show_cell()
	elif tool == "area":
		for worker in world.workforce.state["workers"]:
			if worker["id"] == selected_worker:
				var areas: Array = worker["areas"].duplicate(true)
				areas.append([rect.position.x,rect.position.y,rect.size.x,rect.size.y])
				_result(world.workforce.configure(selected_worker,worker["budget"],worker["paused"],worker["priorities"],areas))
				_show_workers()
				return
		notice.text = "请先在雇工面板选择一名雇工。"
	elif tool == "cancel":
		_result(world.workforce.cancel(rect))
	else:
		var result := world.workforce.mark(rect,tool,task_priority)
		_result(result)
		if result["ok"]: notice.text = "新增%d个标记，跳过%d个不适用地格。" % [result["added"],result["skipped"]]
	overlay.queue_redraw()

func _show_cell() -> void:
	_context = "cell"
	if not world.grid.in_bounds(selected.x,selected.y): return
	_page("地格 (%d,%d)" % [selected.x,selected.y])
	var source := world.source_at(selected)
	if not source.is_empty():
		_label(sidebar,"资源采集独立派工；今日剩余%d份。" % world.source_remaining(source))
		_button(sidebar,"手动采集（1AP）",func(): _result(world.collect(source)); _show_cell())
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
	if not facility.is_empty():
		_show_facility(facility)
		return
	var crop := world.instance_at(selected)
	if not crop.is_empty(): selected = Vector2i(int(crop["origin"][0]),int(crop["origin"][1]))
	var env := world.environment_at(selected)
	_label(sidebar,"水分%d / 肥力%d / 光照%d" % [env["water"],env["fertility"],env["light"]])
	for mark in world.workforce.state["marks"]:
		if mark["cell"] == [selected.x,selected.y]:
			_label(sidebar,"待办：%s · 优先级%d" % [NAMES[mark["kind"]],mark["priority"]])
			_label(sidebar,world.workforce.task_status(selected,mark["kind"]))
	if not crop.is_empty():
		_label(sidebar,"%s · %s" % [CROPS[crop["crop_id"]],"成熟" if crop["state"] == "mature" else "生长中"])
		var definition: Dictionary = world.crop_defs[crop["crop_id"]]
		var target := int(definition["cycle_days"] if crop["harvest_count"] > 0 else definition["days"])*100
		_label(sidebar,"生长进度%d%%；偏好光照%d。" % [int(int(crop["progress"])*100/target),definition["light"]])
		if env["water"] < 30 or env["fertility"] < 30: _label(sidebar,"水分/肥力偏低会延缓生长，不会死亡。")
		if absi(int(env["light"])-int(definition["light"])) > int(world.config["environment"]["light_tolerance"]): _label(sidebar,"光照不合适，生长较慢；菌菇更适合阴区。")
		_label(sidebar,"清理不返还投入；保留选种会重播。")
	_label(sidebar,"地格选种：空闲后自动沿用，仍需种子和全部投入。")
	var seeds := OptionButton.new()
	seeds.add_item("不播种 / 保持空闲")
	seeds.set_item_metadata(0,"")
	var plan := world.workforce.seed_plan(selected)
	for ident in CROPS:
		seeds.add_item("%s（种子%d）" % [CROPS[ident],world.inventory.count(world.crop_defs[ident]["seed"])])
		seeds.set_item_metadata(seeds.item_count-1,ident)
		if plan.get("crop_id") == ident: seeds.select(seeds.item_count-1)
	seeds.item_selected.connect(func(index): _result(world.workforce.set_seed(selected,seeds.get_item_metadata(index))); _show_cell())
	sidebar.add_child(seeds)
	if not plan.is_empty():
		_label(sidebar,"自动播种："+world.workforce.task_status(selected,"plant"))
		var definition: Dictionary = world.crop_defs[plan["crop_id"]]
		var inputs: Dictionary = definition["inputs"].duplicate()
		inputs[definition["seed"]] = int(inputs.get(definition["seed"],0))+1
		_label(sidebar,"每轮投入："+_materials(inputs))
		for ident in inputs:
			var missing := int(inputs[ident])-world.inventory.count(ident)
			if missing > 0: _label(sidebar,"待补充：%s×%d" % [Data.resources(Data.load_data())[ident]["name"],missing])
		_label(sidebar,"占地%d×%d，必须全部开垦且空闲。" % definition["footprint"])
	for kind in ["till","plant","harvest","irrigate","fertilize","fell","clear"]:
		_button(sidebar,"手动%s（1AP）" % NAMES[kind],_manual.bind(kind))
	_label(sidebar,"建设仍手动；须有元石和完整材料。")
	for ident in world.facility_defs:
		_label(sidebar,"%d元石；%s" % [world.facility_defs[ident]["cash"],_materials(world.facility_defs[ident]["materials"])])
		_button(sidebar,"建造 %s" % world.facility_defs[ident].get("name",ident),func(): _result(world.build_facility(selected,ident)); _show_cell())

func _materials(counts: Dictionary) -> String:
	var items := Data.resources(Data.load_data())
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
	_label(sidebar,world.facility_defs[facility["facility_id"]].get("name",facility["facility_id"]))
	if not batch.is_empty():
		_label(sidebar,"%s · %s" % [RECIPES[batch["recipe_id"]],"待收取" if batch["status"] == "ready" else "加工中"])
		_label(sidebar,"产物：%s；剩余%d天。" % [_materials(batch["outputs"]),maxi(0,int(batch["finish_day"])-world.clock.total_days)])
		var claim := _button(sidebar,"收取（1AP）",func(): _result(world.claim_batch(uid,int(batch["batch_id"]))); _show_cell())
		claim.disabled = batch["status"] != "ready"
	else:
		for ident in world.recipe_defs:
			if world.recipe_defs[ident]["facility"] == facility["facility_id"]:
				_label(sidebar,"%s → %s；%d天" % [_materials(world.recipe_defs[ident]["inputs"]),_materials(world.recipe_defs[ident]["outputs"]),world.recipe_defs[ident]["days"]])
				_button(sidebar,"启动 %s" % RECIPES[ident],func(): _result(world.start_batch(uid,ident)); _show_cell())
		_button(sidebar,"拆除（1AP，无返还）",func(): _confirm("拆除这座空闲设施？不返还材料或元石。",func(): _result(world.demolish_facility(uid)); _show_cell()))

func _show_workers() -> void:
	_context = "workers"
	_page("雇工 · 最多2人")
	_label(sidebar,"成功1次收费1元石；每人每日最多12次。只在负责区域找农务目标。")
	if world.workforce.state["workers"].size() < 2:
		_button(sidebar,"雇佣一人（无固定费用）",func():
			var result := world.workforce.hire("雇工%d" % world.workforce.state["next_worker_id"])
			_result(result)
			if result["ok"]: selected_worker = int(result["worker_id"])
			_show_workers())
	for worker in world.workforce.state["workers"]:
		_button(sidebar,worker["name"],func(): selected_worker = int(worker["id"]); _show_workers(); overlay.queue_redraw())
		if worker["id"] != selected_worker: continue
		var budget := SpinBox.new()
		budget.min_value = 0
		budget.max_value = 1000000
		budget.value = worker["budget"]
		_label(sidebar,"每日预算（元石）")
		sidebar.add_child(budget)
		budget.value_changed.connect(func(value): _result(world.workforce.configure(worker["id"],int(value),worker["paused"],worker["priorities"],worker["areas"])))
		var pause := CheckButton.new()
		pause.text = "暂停委托"
		pause.button_pressed = worker["paused"]
		pause.toggled.connect(func(value): _result(world.workforce.configure(worker["id"],worker["budget"],value,worker["priorities"],worker["areas"])))
		sidebar.add_child(pause)
		_label(sidebar,"个人工作偏好0～5：0禁止；个人偏好先于标记优先级。")
		for kind in Workforce.KINDS:
			var row := HBoxContainer.new()
			sidebar.add_child(row)
			var label := _label(row,NAMES[kind])
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var preference := SpinBox.new()
			preference.min_value = 0
			preference.max_value = 5
			preference.value = worker["priorities"][kind]
			preference.value_changed.connect(func(value):
				var priorities: Dictionary = worker["priorities"].duplicate()
				priorities[kind] = int(value)
				_result(world.workforce.configure(worker["id"],worker["budget"],worker["paused"],priorities,worker["areas"])))
			row.add_child(preference)
		_label(sidebar,"负责区域%d处；资源点在地格面板单独派工。" % worker["areas"].size())
		_button(sidebar,"框选追加负责区域",func(): expanded = true; _layout(); _select_tool("area"))
		_button(sidebar,"清空负责区域",func(): _result(world.workforce.configure(worker["id"],worker["budget"],worker["paused"],worker["priorities"],[])); _show_workers())
		_button(sidebar,"解雇（免费）",func(): _result(world.workforce.dismiss(worker["id"])); selected_worker = 0; _show_workers())
	_button(sidebar,"查看上次工作日报",_show_report)

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
	_button(sidebar,"雇工设置",_show_workers)
	_button(sidebar,"经营条目",_show_history)

func _show_help() -> void:
	_context = "help"
	_page("经营手册 · 随时可自由操作")
	for step in Journal.GUIDE:
		_label(sidebar,("✓ " if step in world.journal["guide"]["seen"] else "• ")+GUIDE_TEXT[step])
	_label(sidebar,"资源点点选后单独派工；仓库共享，不需要搬运。每天24AP，结束当天统一结算和保存。")
	_label(sidebar,"清理不返还投入；取消任务不会取消选种。建筑建拆、加工启动/收取仍手动。")
	if _started:
		_button(sidebar,"跳过操作提示",func(): _result(world.guide_dismiss(true)); _show_help())
		_button(sidebar,"恢复操作提示",func(): _result(world.guide_dismiss(false)); _show_help())
	_button(sidebar,"查看经营记录",_show_history)

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
	_button(row,"详情",_show_history)
	_button(row,"收起",func(): digest.visible = false)
	var report: Dictionary = world.journal["history"].back()
	var entries := _entries(report)
	if not saved and not world.daily_save_error.is_empty(): entries.push_front("[存档] 保存失败，请打开详情重试。")
	if day%15 == 0 and day <= 45:
		var term: Dictionary = world.journal["terms"][int(day/15)-1]
		entries.push_front("[时节] 本节收入%d、支出%d，净现金变化%d元石" % [Journal.income(term),Journal.expense(term),Journal.income(term)-Journal.expense(term)])
	for index in range(mini(3,entries.size())):
		var line := UI.label("• "+entries[index])
		line.custom_minimum_size.x = 380
		line.clip_text = true
		digest_body.add_child(line)
	if entries.size() > 3:
		var more := _label(digest_body,"另有%d条，点击详情查看。" % (entries.size()-3))
		more.autowrap_mode = TextServer.AUTOWRAP_OFF
	digest.size.y = 0
	digest.reset_size.call_deferred()
	digest.visible = true
	if day == 45: _show_recap.call_deferred(-1)

func _show_history() -> void:
	_context = "history"
	_page("经营条目 · 最近15天")
	_button(sidebar,"首次45天回顾",_show_recap.bind(-1))
	_button(sidebar,"详细工作日报",_show_report)
	if not world.daily_save_error.is_empty():
		_label(sidebar,"日存档失败，后续操作暂停。")
		_button(sidebar,"重试日存档",func(): _result(world.retry_day_save()); _show_history())
	for index in range(world.journal["history"].size()-1,-1,-1):
		var report: Dictionary = world.journal["history"][index]
		_label(sidebar,"第%d天%s" % [report["day"]," · 时节更替" if int(report["day"])%15 == 0 else ""])
		for entry in _entries(report): _label(sidebar,"• "+entry)

func _show_recap(term_index: int = -1) -> void:
	_context = "recap"
	_page("首次45天经营回顾" if term_index < 0 else "第%d时节 · 第%d～%d天" % [term_index+1,term_index*15+1,(term_index+1)*15])
	var state: Dictionary = world.journal
	if int(state["start_day"]) >= 45:
		_label(sidebar,"此旧存档的首次45天未记录，无法生成回顾；升级后的每日经营条目仍可查看。")
		_button(sidebar,"每日经营条目",_show_history)
		return
	if int(state["start_day"]) > 0: _label(sidebar,"旧档从第%d天开始记录，此前行为未记录。" % (int(state["start_day"])+1))
	_label(sidebar,"第45天结束冻结统计，此后可继续经营。" if state["frozen"] else "已结算%d/45天；当天尚未结算的操作暂不计入。" % world.clock.total_days)
	_button(sidebar,"45天总计",_show_recap.bind(-1))
	for index in range(3): _button(sidebar,"第%d时节小计" % (index+1),_show_recap.bind(index))
	var row: Dictionary = Journal.totals(state) if term_index < 0 else state["terms"][term_index]
	_label(sidebar,"收入%d（销售%d / 订单%d）\n支出%d（采购%d / 建设%d / 人工%d）\n净现金变化%d元石" % [Journal.income(row),row["sales_revenue"],row["order_revenue"],Journal.expense(row),row["purchase_spend"],row["construction_spend"],row["labour_spend"],Journal.income(row)-Journal.expense(row)])
	for key in ["plantings","harvests","produce","collected","batches_started","batches_completed","processed","deliveries","delivered_items","buildings","work_actions","fieldwork"]:
		if row[key].is_empty(): continue
		_label(sidebar,{"plantings":"种植株次","harvests":"收获次数","produce":"作物产量","collected":"采集数量","batches_started":"加工投料批次","batches_completed":"完成批次","processed":"加工收取产量","deliveries":"五行供货单数","delivered_items":"供货材料","buildings":"建设数量","work_actions":"雇工成功操作","fieldwork":"开垦与养护次数"}[key])
		for ident in row[key]:
			var name: String = CROPS.get(ident,RECIPES.get(ident,NAMES.get(ident,world.facility_defs.get(ident,{}).get("name",Data.resources(Data.load_data()).get(ident,{}).get("name",{"wood":"木","fire":"火","earth":"土","water":"水","gold":"金"}.get(ident,ident))))))
			_label(sidebar,"• %s ×%d" % [name,row[key][ident]])
	if term_index < 0 and state["frozen"]:
		_label(sidebar,"记录期初%d → 第45天期末%d元石；库存另列，不折算利润。" % [state["start_cash"],state["end_cash"]])
		if not state["end_inventory"].is_empty(): _label(sidebar,"期末库存："+_materials(state["end_inventory"]))

func _show_market() -> void:
	_context = "market"
	_page("共享行囊 / 固定价格交易")
	var items := Data.resources(Data.load_data())
	for ident in items:
		var item: Dictionary = items[ident]
		_label(sidebar,"%s ×%d" % [item["name"],world.inventory.count(ident)])
		var row := HBoxContainer.new()
		sidebar.add_child(row)
		if int(item["buy_price"]) > 0: _button(row,"买1 · %d元石" % item["buy_price"],func(): _result(world.buy(ident,1)); _show_market())
		if int(item["sell_price"]) > 0: _button(row,"卖1 · %d元石" % item["sell_price"],func(): _result(world.sell(ident,1)); _show_market())

func _show_orders() -> void:
	_context = "orders"
	_page("五行供货 · 当前开放%d转" % world.unlocked_rank())
	_label(sidebar,"营业收入%d元石；每日3单，未完成不罚款。" % world.gross_revenue())
	var items := Data.resources(Data.load_data())
	for order in world.daily_orders():
		var path_names := {"wood":"木","fire":"火","earth":"土","water":"水","gold":"金"}
		_label(sidebar,"%s · %d转 · 需求%d" % [path_names[order["path"]],order["rank"],order["demand"]])
		if order["status"] == "completed":
			_label(sidebar,"已交付，回款%d元石" % order["receipt"]["payout"])
			continue
		for ident in items:
			var quote := world.order_quote(order["id"],ident)
			if quote["ok"]:
				var button := _button(sidebar,"%s×%d → %d元石" % [items[ident]["name"],quote["quantity"],quote["payout"]],func(): _result(world.deliver_order(order["id"],ident)); _show_orders())
				button.disabled = not world.inventory.has(ident,int(quote["quantity"]))

func _process(delta: float) -> void:
	if not _started: return
	var dir := Input.get_vector("move_left","move_right","move_up","move_down")
	camera.position += dir*(400.0/camera.zoom.x)*delta
	var half := Vector2(map_port.size)*0.5/camera.zoom.x
	camera.position.x = clampf(camera.position.x,minf(half.x,640.0),maxf(640.0,1280.0-half.x))
	camera.position.y = clampf(camera.position.y,minf(half.y,448.0),maxf(448.0,896.0-half.y))

func draw_map(target: Node2D) -> void:
	var font := theme.default_font
	for crop in world.crops.values():
		var shape: Array = world.crop_defs[crop["crop_id"]]["footprint"]
		var rect := Rect2(Vector2(float(crop["origin"][0]),float(crop["origin"][1]))*64.0,Vector2(float(shape[0]),float(shape[1]))*64.0)
		target.draw_rect(rect.grow(-8),UI.JADE if crop["state"] != "mature" else Color("e8cf76"))
		target.draw_string(font,rect.position+Vector2(10,38),CROPS[crop["crop_id"]],HORIZONTAL_ALIGNMENT_LEFT,-1,18,UI.INK)
	for building in world.facilities.values():
		var shape: Array = world.facility_defs[building["facility_id"]]["footprint"]
		var rect := Rect2(Vector2(float(building["origin"][0]),float(building["origin"][1]))*64.0,Vector2(float(shape[0]),float(shape[1]))*64.0)
		target.draw_rect(rect.grow(-5),UI.SURFACE)
		target.draw_string(font,rect.position+Vector2(8,32),world.facility_defs[building["facility_id"]].get("name",building["facility_id"]),HORIZONTAL_ALIGNMENT_LEFT,-1,20,UI.PAPER)
	for ident in world.source_defs:
		var def: Dictionary = world.source_defs[ident]
		var position := Vector2(float(def["position"][0]),float(def["position"][1]))*64.0
		target.draw_rect(Rect2(position+Vector2(4,4),Vector2(56,56)),Color("59868d"))
		var text: String = {"stone_source":"石","ore_source":"矿","spring_source":"泉"}[ident]
		target.draw_string(font,position+Vector2(14,38),text,HORIZONTAL_ALIGNMENT_LEFT,-1,30,UI.PAPER)
		if world.workforce.state["sources"].has(ident): target.draw_circle(position+Vector2(52,12),6,UI.JADE)
	for worker in world.workforce.state["workers"]:
		if worker["id"] != selected_worker: continue
		for area in worker["areas"]:
			target.draw_rect(Rect2(Vector2(float(area[0]),float(area[1]))*64.0,Vector2(float(area[2]),float(area[3]))*64.0),Color(0.4,0.8,0.8,0.12))
	var stacks := {}
	for mark in world.workforce.state["marks"]:
		var position := Vector2(float(mark["cell"][0]),float(mark["cell"][1]))*64.0
		target.draw_rect(Rect2(position+Vector2(2,2),Vector2(60,60)),UI.PAPER,false,2)
		var index := int(stacks.get(position,0))
		stacks[position] = index+1
		var offset := Vector2(4+(index%2)*28,20+(index/2)*18)
		target.draw_rect(Rect2(position+offset-Vector2(0,16),Vector2(28,18)),Color(0.08,0.16,0.12,0.85))
		target.draw_string(font,position+offset,NAMES[mark["kind"]].substr(0,1)+str(mark["priority"]),HORIZONTAL_ALIGNMENT_LEFT,-1,18,UI.PAPER)
	for plan in world.workforce.state["seed_plans"]:
		var position := Vector2(float(plan["cell"][0]),float(plan["cell"][1]))*64.0
		target.draw_circle(position+Vector2(52,12),5,UI.JADE)
	if selected.x >= 0: target.draw_rect(Rect2(Vector2(selected)*64.0,Vector2(64,64)),UI.JADE,false,3)
	if _drag:
		var rect := _rect(_drag_start,_drag_end)
		target.draw_rect(Rect2(Vector2(rect.position)*64.0,Vector2(rect.size)*64.0),UI.PAPER,false,3)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_confirm("退出将放弃当天未保存的操作。",func(): get_tree().quit())

func _preview(directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	_new(1,false)
	world.workforce.hire("阿禾")
	selected_worker = 1
	var worker: Dictionary = world.workforce.state["workers"][0]
	world.workforce.configure(1,12,false,worker["priorities"],[[1,1,8,4]])
	world.workforce.set_seed(Vector2i(2,2),"golden_wheat")
	world.workforce.mark(Rect2i(1,1,8,4),"till")
	expanded = true
	_layout()
	camera.position = Vector2(350,230)
	_show_workers()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory+"/workforce.png")
	world.end_day()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory+"/work-report.png")
	_show_history()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory+"/daily-entries.png")
	_show_help()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory+"/guide.png")
	expanded = false
	_layout()
	world.workforce.assign_source("spring_source",1)
	selected = Vector2i(17,8)
	camera.position = Vector2(864,550)
	_show_cell()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory+"/source-assignment.png")
	if FileAccess.file_exists("res://.art-work/v1-f-45days.json"):
		var result: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.art-work/v1-f-45days.json"))
		if result.has("snapshot") and store.create_slot(1,result["snapshot"],true)["ok"]:
			world.open_game(1)
			digest.visible = false
			_show_recap(-1)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(directory+"/45day-recap.png")
			_show_recap(1)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(directory+"/term-recap.png")
	for slot in [1,2,3]:
		if store.occupied(slot): store.delete_slot(slot,true)
	DirAccess.remove_absolute(store.slot_path(1).get_base_dir())
	get_tree().quit()
