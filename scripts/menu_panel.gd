class_name MenuPanel
extends CanvasLayer
## 功能入口菜单（menu 型交互点）：标题 + 选项列表。
## 选择后发 chosen 信号（Main 侧转 menu_command 接缝），Esc 取消。
## UI 接缝注释：正式实现应换成宿主的面板体系与主题 token。

signal chosen(item: Dictionary)
signal canceled

var _title: Label
var _rows: VBoxContainer
var _items: Array = []
var _sel := 0
var _row_labels: Array[Label] = []


func _ready() -> void:
	layer = 40
	visible = false
	_build()


func _build() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "sans-serif",
	])
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08, 0.96)
	sb.border_color = Color(0.77, 0.60, 0.31)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(180, 70)
	panel.size = Vector2(280, 150)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	_title = Label.new()
	_title.position = Vector2(12, 6)
	_title.add_theme_font_override("font", font)
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", Color(0.85, 0.72, 0.45))
	panel.add_child(_title)

	_rows = VBoxContainer.new()
	_rows.position = Vector2(12, 32)
	_rows.size = Vector2(256, 80)
	_rows.add_theme_constant_override("separation", 4)
	panel.add_child(_rows)

	var hint := Label.new()
	hint.text = "↑↓ 选择 · E 确认 · Esc 返回"
	hint.add_theme_font_override("font", font)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.55, 0.52, 0.45))
	hint.position = Vector2(12, 122)
	panel.add_child(hint)


func open(title: String, items: Array) -> void:
	_items = items
	_sel = 0
	_title.text = title
	for c in _rows.get_children():
		c.free()
	_row_labels.clear()
	for it in items:
		var l := Label.new()
		l.add_theme_font_override("font", _title.get_theme_font("font"))
		l.add_theme_font_size_override("font_size", 13)
		l.text = "  " + str(it["label"])
		_rows.add_child(l)
		_row_labels.append(l)
	_refresh()
	visible = true


func move(dir: int) -> void:
	if not visible or _items.is_empty():
		return
	_sel = clampi(_sel + dir, 0, _items.size() - 1)
	_refresh()


func confirm() -> void:
	if not visible or _items.is_empty():
		return
	var item: Dictionary = _items[_sel]
	visible = false
	chosen.emit(item)


func cancel() -> void:
	if not visible:
		return
	visible = false
	canceled.emit()


func _refresh() -> void:
	for i in _row_labels.size():
		var l := _row_labels[i]
		l.text = ("▶ " if i == _sel else "  ") + str(_items[i]["label"])
		l.add_theme_color_override("font_color",
				Color(0.92, 0.82, 0.55) if i == _sel else Color(0.85, 0.83, 0.78))
