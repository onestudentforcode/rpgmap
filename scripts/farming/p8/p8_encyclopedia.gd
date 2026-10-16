extends RefCounted
## P9.c in-game encyclopedia reader: ONI-inspired two-pane layout over the
## baked content layer. Left pane = search + categories + entry index; right
## pane = the entry with fields, sources/uses rows and cross-entry jumps.
## Reading only touches this module's own state — never the world, the clock
## or the save.
const UI := preload("res://scripts/farming/v1/v1_ui_style.gd")
const Icons := preload("res://scripts/farming/v1/v1_ui_icons.gd")
const P8Style := preload("res://scripts/farming/p8/p8_ui_style.gd")
const DATA_PATH := "res://content/farming/baked/encyclopedia/encyclopedia.json"

var shell
var data: Dictionary = {}
var entities: Dictionary = {}      # entity id -> row
var processes: Dictionary = {}     # process id -> row
var categories: Array = []
var category_title := {}           # category id -> title
var category_ids := []             # stable category order
var current_id := ""
var category := "crops"
var search := ""
var history: Array = []            # [{id, scroll}]
var detail_scroll := 0

var frame: HBoxContainer
var list_box: VBoxContainer
var detail_scroll_box: ScrollContainer
var detail_box: VBoxContainer
var search_box: LineEdit

func _init(owner) -> void:
	shell = owner
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	for entity in data.get("entities", []):
		entities[String(entity["id"])] = entity
	for process in data.get("processes", []):
		processes[String(process["id"])] = process
	categories = data.get("categories", [])
	for entry in categories:
		category_title[String(entry["id"])] = String(entry["title"])
		category_ids.append(String(entry["id"]))

func has(entity_id: String) -> bool:
	return entities.has(entity_id)

func name_of(entity_id: String) -> String:
	return String(entities[entity_id]["name"]) if entities.has(entity_id) else entity_id

func icon_of(entity_id: String) -> Texture2D:
	var ident := String(entities[entity_id].get("icon", "inspect")) if entities.has(entity_id) else "inspect"
	return Icons.get_icon(ident)

## Process icon: derived from the process type; item-driven types use the item.
func process_icon(process: Dictionary) -> Texture2D:
	var item: String = process["inputs"][0]["entity"] if not process["inputs"].is_empty() else (process["outputs"][0]["entity"] if not process["outputs"].is_empty() else "")
	var by_type := {
		"market_buy": "buy", "market_sell": "sell", "order_supply": "orders",
		"build": "build", "demolish": "clear", "land_buy": "area",
		"research_start": "research_bench", "research_work": "research_bench",
		"device_fuel": "growth_lamp", "worker_farm": "workers", "clear": "clear",
		"cull": "clear", "initial_grant": "day", "flower_pick": "nectar",
		"flower_share": "nectar", "field_care": "irrigate",
	}
	var ident := String(by_type.get(String(process["type"]), ""))
	if ident.is_empty():
		if String(process["type"]) == "device_service":
			ident = "field_service_station"
		elif item.begins_with("resource:"):
			ident = item.substr(9)
		else:
			ident = "inspect"
	return Icons.get_icon(ident)

# --- entry -------------------------------------------------------------------

func open(focus_id: String = "") -> void:
	if not focus_id.is_empty() and entities.has(focus_id) and not current_id.is_empty() and focus_id != current_id:
		_push_history()
	if not focus_id.is_empty() and entities.has(focus_id):
		current_id = focus_id
	elif current_id.is_empty():
		current_id = _first_entity_of(category)
	shell._context = "encyclopedia"
	shell._page("百科全书 · 目录 · 搜索 · 条目跳转")
	render_frame()

## Re-render after a day roll: keep the current entry, search and scroll.
func refresh() -> void:
	if frame == null or not is_instance_valid(frame):
		return
	render_detail()

func render_into(parent: Node) -> void:
	_build_frame(parent, false)

# --- frame -------------------------------------------------------------------

func render_frame() -> void:
	_build_frame(shell.sidebar, true)

func _build_frame(parent: Node, clear_host: bool = true) -> void:
	if clear_host:
		_clear(parent)
	frame = HBoxContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_constant_override("separation", 12)
	# The window body lives inside a ScrollContainer that only sizes children to
	# their combined minimum; give the frame the viewport height so both panes
	# fill the window instead of collapsing to the left column's minimum.
	var available := 540.0
	if shell.window_scroll != null and is_instance_valid(shell.window_scroll):
		available = maxf(540.0, shell.window_scroll.size.y - 8.0)
	frame.custom_minimum_size = Vector2(0, available)
	parent.add_child(frame)
	_build_left(frame)
	detail_scroll_box = ScrollContainer.new()
	detail_scroll_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll_box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(detail_scroll_box)
	detail_box = VBoxContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll_box.add_child(detail_box)
	render_list()
	render_detail()

func _build_left(parent: Node) -> void:
	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_stylebox_override("panel", UI.box(Color("f7f6ee"), P8Style.BORDER, 10))
	parent.add_child(left)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	left.add_child(column)
	var search_row := HBoxContainer.new()
	column.add_child(search_row)
	search_box = LineEdit.new()
	search_box.placeholder_text = "搜索名称 / ID / 标签"
	search_box.text = search
	search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_box.custom_minimum_size.x = 150
	search_box.set_meta("encyclopedia_search", true)
	search_box.clear_button_enabled = true
	search_box.text_changed.connect(func(value): search = value; render_list())
	search_row.add_child(search_box)
	var cat_scroll := ScrollContainer.new()
	cat_scroll.custom_minimum_size = Vector2(0, 196)
	cat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(cat_scroll)
	var cats := VBoxContainer.new()
	cats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat_scroll.add_child(cats)
	for entry in categories:
		var cid := String(entry["id"])
		var button := Button.new()
		button.text = "%s（%d）" % [category_title[cid], _count_of(cid)]
		button.tooltip_text = "%s分类浏览" % category_title[cid]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = search.is_empty() and category == cid
		button.add_theme_font_size_override("font_size", 16)
		button.set_meta("encyclopedia_category", cid)
		button.pressed.connect(func():
			category = cid
			search = ""
			if search_box != null and is_instance_valid(search_box): search_box.text = ""
			render_list())
		cats.add_child(button)
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(list_scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list_box)

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _first_entity_of(cid: String) -> String:
	for entity in data["entities"]:
		if String(entity["category"]) == cid:
			return String(entity["id"])
	return ""

func _count_of(cid: String) -> int:
	var kinds: Array = []
	for entry in categories:
		if String(entry["id"]) == cid:
			kinds = entry["kinds"]
	var total := 0
	for entity in entities.values():
		if kinds.has(String(entity["kind"])): total += 1
	return total

# --- index list --------------------------------------------------------------

func _matches(entity: Dictionary) -> bool:
	var text := search.strip_edges().to_lower()
	if text.is_empty():
		return String(entity["category"]) == category
	var haystack := PackedStringArray([String(entity["name"]).to_lower(), String(entity["source_id"]).to_lower()])
	for tag in entity.get("tags", []):
		haystack.append(String(tag).to_lower())
	for row in haystack:
		if row.contains(text):
			return true
	return false

func render_list() -> void:
	if list_box == null or not is_instance_valid(list_box):
		return
	_clear(list_box)
	var shown := 0
	# Stable registry order: entities are baked sorted by (category, id).
	for entity in data["entities"]:
		if not _matches(entity):
			continue
		shown += 1
		var eid := String(entity["id"])
		var button := Button.new()
		button.text = String(entity["name"])
		button.icon = icon_of(eid)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 22)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = eid == current_id
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("encyclopedia_entry", eid)
		button.tooltip_text = "%s · %s" % [entity["name"], _kind_label(String(entity["kind"]))]
		button.pressed.connect(func():
			if current_id == eid:
				_select(eid)
			else:
				open(eid))
		if not _locks_of(entity).is_empty() and shell._started and not _unlocked(entity):
			button.modulate = Color(0.62, 0.62, 0.62)
			button.tooltip_text += " · 本档未解锁（可先阅读静态内容）"
		list_box.add_child(button)
	if shown == 0:
		var empty := UI.label("没有匹配的条目；清空搜索或切换分类。", true)
		list_box.add_child(empty)

func _select(eid: String) -> void:
	current_id = eid
	render_list()
	render_detail()

# --- detail ------------------------------------------------------------------

func _locks_of(entity: Dictionary) -> Dictionary:
	# JSON null (ungated entries) arrives as Nil; normalise to an empty Dictionary.
	var locks = entity.get("locks")
	return locks if locks is Dictionary else {}

func _value_of(dictionary: Dictionary, key: String) -> String:
	var value = dictionary.get(key)
	if value == null:
		return ""
	return String(value)

func _unlocked(entity: Dictionary) -> bool:
	var locks := _locks_of(entity)
	if locks.is_empty():
		return true
	# locks carry the full entity id; the runtime expects the bare project id.
	return shell.world.research.is_completed(String(locks["research"]).trim_prefix("research:"))

func render_detail() -> void:
	if detail_box == null or not is_instance_valid(detail_box):
		return
	detail_scroll = detail_scroll_box.scroll_vertical if detail_scroll_box != null else 0
	_clear(detail_box)
	var entity: Dictionary = entities.get(current_id, {})
	if entity.is_empty():
		detail_box.add_child(UI.label("请选择左侧条目。", true))
		return
	# header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	detail_box.add_child(header)
	var picture := TextureRect.new()
	picture.texture = icon_of(current_id)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(52, 52)
	picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(picture)
	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_column)
	var title_row := HBoxContainer.new()
	title_column.add_child(title_row)
	var title := UI.label(String(entity["name"]))
	title.add_theme_font_size_override("font_size", 24)
	title_row.add_child(title)
	if not _locks_of(entity).is_empty():
		var chip := PanelContainer.new()
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var unlocked: bool = shell._started and _unlocked(entity)
		if unlocked:
			chip.add_theme_stylebox_override("panel", UI.box(Color("deebd9"), UI.JADE, 6))
		else:
			chip.add_theme_stylebox_override("panel", UI.box(Color("f6e8d2"), Color("cba884"), 6))
		var chip_text := UI.label("本档已解锁" if unlocked else "本档未解锁")
		chip_text.add_theme_font_size_override("font_size", 14)
		chip_text.autowrap_mode = TextServer.AUTOWRAP_OFF
		chip.add_child(chip_text)
		title_row.add_child(chip)
		if not unlocked:
			var gate := UI.label("需研究「%s」；静态内容仍可阅读，阅读不解锁玩法。" % String(entity["locks"]["research_name"]), true)
			title_column.add_child(gate)
	elif not shell._started:
		title_column.add_child(UI.label("未开档：仅展示静态内容。", true))
	var back := Button.new()
	back.text = "← 返回"
	back.disabled = history.is_empty()
	back.tooltip_text = "回到上一个条目（保留搜索与分类）"
	back.set_meta("encyclopedia_back", true)
	back.pressed.connect(_back)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(back)
	var identity := UI.label("%s · %s · ID %s" % [_kind_label(String(entity["kind"])), category_title.get(String(entity["category"]), ""), String(entity["source_id"])], true)
	identity.autowrap_mode = TextServer.AUTOWRAP_OFF
	identity.clip_text = true
	detail_box.add_child(identity)
	if not String(entity.get("summary", "")).is_empty():
		var summary := UI.label(String(entity["summary"]), true)
		detail_box.add_child(summary)
	# fields card
	if not entity.get("fields", []).is_empty():
		var card := _card(detail_box, "条目数据")
		for field in entity["fields"]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			card.add_child(row)
			var key := UI.label(String(field["label"]), true)
			key.custom_minimum_size = Vector2(104, 0)
			key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(key)
			var value := UI.label(String(field["text"]))
			value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(value)
	# sources / uses for resources
	for section in [["获取来源", "sources"], ["直接用途", "uses"]]:
		var rows: Array = entity.get(section[1], [])
		if rows.is_empty():
			continue
		var head := _card(detail_box, "%s（%d条）" % [section[0], rows.size()])
		for row in rows:
			_render_relation(head, row)
	# links
	if not entity.get("links", []).is_empty():
		var card := _card(detail_box, "关联条目 · 点击跳转")
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		card.add_child(flow)
		for link in entity["links"]:
			var button := Button.new()
			button.text = "%s：%s" % [String(link["label"]), String(link["name"])]
			button.tooltip_text = "打开条目 " + String(link["name"])
			button.set_meta("encyclopedia_jump", String(link["entity"]))
			button.pressed.connect(func(): _jump(String(link["entity"])))
			flow.add_child(button)
	# rules
	if not entity.get("related_rules", []).is_empty():
		var card := _card(detail_box, "相关规则 · 点击查看")
		var flow := HFlowContainer.new()
		card.add_child(flow)
		for rid in entity["related_rules"]:
			var button := Button.new()
			button.text = name_of(String(rid))
			button.set_meta("encyclopedia_jump", String(rid))
			button.pressed.connect(func(): _jump(String(rid)))
			flow.add_child(button)
	detail_scroll_box.scroll_vertical = detail_scroll

func _render_relation(parent: Node, row: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UI.box(Color("fbfaf3"), UI.BORDER, 8))
	parent.add_child(panel)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	panel.add_child(line)
	var target := _jump_target_of(String(row["process"]))
	if not target.is_empty():
		var jump := Button.new()
		jump.icon = icon_of(target)
		jump.expand_icon = true
		jump.add_theme_constant_override("icon_max_width", 22)
		jump.custom_minimum_size = Vector2(34, 30)
		jump.tooltip_text = "打开 %s" % name_of(target)
		jump.set_meta("encyclopedia_jump", target)
		jump.pressed.connect(func(): _jump(target))
		line.add_child(jump)
	else:
		var mark := TextureRect.new()
		mark.texture = process_icon(processes[String(row["process"])])
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.custom_minimum_size = Vector2(26, 26)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(mark)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(column)
	var main := UI.label(String(row["detail"]))
	column.add_child(main)
	if not String(row.get("others", "")).is_empty():
		column.add_child(UI.label("同批：" + String(row["others"]), true))

func _jump_target_of(process_id: String) -> String:
	var process: Dictionary = processes.get(process_id, {})
	if process.is_empty():
		return ""
	for key in ["crop", "species", "facility", "research"]:
		var target := _value_of(process, key)
		if not target.is_empty():
			return target
	if process_id.begins_with("proc:collect:"):
		return "source:" + process_id.substr(12)
	if process_id.begins_with("proc:land:"):
		return "parcel:" + process_id.substr(9)
	return ""

func _card(parent: Node, title_text: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UI.box(P8Style.CARD, P8Style.BORDER, 10))
	parent.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	panel.add_child(body)
	var title := UI.label(title_text, true)
	title.add_theme_font_size_override("font_size", 17)
	body.add_child(title)
	return body

func _kind_label(kind: String) -> String:
	return {"resource": "物品", "crop": "作物", "species": "物种", "diet": "食谱", "facility": "设施",
	        "recipe": "配方", "research": "研究", "source": "资源点", "parcel": "地块", "map": "地图",
	        "rule": "规则"}.get(kind, kind)

# --- navigation --------------------------------------------------------------

func _push_history() -> void:
	history.append({"id": current_id, "scroll": detail_scroll_box.scroll_vertical if detail_scroll_box != null else 0})
	if history.size() > 50:
		history.pop_front()

func _jump(target: String) -> void:
	if not entities.has(target) or target == current_id:
		return
	_push_history()
	current_id = target
	render_list.call_deferred()
	render_detail()

func open_and_switch(target: String) -> void:
	if not entities.has(target):
		return
	_push_history()
	current_id = target
	if not search.is_empty():
		search = ""
		if search_box != null and is_instance_valid(search_box):
			search_box.text = ""
	render_list()
	render_detail()

func _back() -> void:
	if history.is_empty():
		return
	var last: Dictionary = history.pop_back()
	current_id = String(last["id"])
	detail_scroll = int(last["scroll"])
	render_list()
	render_detail()
