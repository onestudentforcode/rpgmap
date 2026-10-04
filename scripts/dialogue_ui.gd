class_name DialogueUI
extends CanvasLayer
## 底部对话框：打字机效果 + 多页文本，interact 键翻页/关闭。

signal closed

const TYPE_SPEED := 45.0  # 字/秒

var _pages: PackedStringArray = PackedStringArray()
var _page := 0
var _shown := 0.0
var _typing := false
var _opened_at_ms := 0
var _blink := 0.0

var _name_label: Label
var _body: Label
var _hint: Label


func _ready() -> void:
	layer = 20
	visible = false
	_build()


func _build() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "sans-serif",
	])

	var panel := Panel.new()
	panel.name = "Panel"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08, 0.95)
	sb.border_color = Color(0.77, 0.60, 0.31)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(16, 262)
	panel.size = Vector2(608, 84)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	_name_label = Label.new()
	_name_label.position = Vector2(12, 6)
	_name_label.add_theme_font_override("font", font)
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.add_theme_color_override("font_color", Color(0.85, 0.72, 0.45))
	panel.add_child(_name_label)

	_body = Label.new()
	_body.position = Vector2(12, 26)
	_body.size = Vector2(584, 50)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_override("font", font)
	_body.add_theme_font_size_override("font_size", 14)
	_body.add_theme_color_override("font_color", Color(0.92, 0.90, 0.85))
	panel.add_child(_body)

	_hint = Label.new()
	_hint.text = "▼"
	_hint.add_theme_font_override("font", font)
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Color(0.85, 0.72, 0.45))
	_hint.position = Vector2(584, 62)
	panel.add_child(_hint)


func open(display_name: String, pages: PackedStringArray) -> void:
	_pages = pages
	_page = 0
	_name_label.text = display_name
	visible = true
	_show_page()


func _show_page() -> void:
	_body.text = _pages[_page]
	_shown = 0.0
	_typing = true
	_opened_at_ms = Time.get_ticks_msec()
	_hint.visible = false


func advance() -> void:
	if not visible:
		return
	if Time.get_ticks_msec() - _opened_at_ms < 60:  # 防打开瞬间同帧双触发
		return
	if _typing:
		_shown = _body.text.length()
		_typing = false
		_hint.visible = true
		return
	_page += 1
	if _page >= _pages.size():
		visible = false
		closed.emit()
	else:
		_show_page()


func is_typing() -> bool:
	return _typing


func _process(delta: float) -> void:
	if not visible:
		return
	if _typing:
		var total := _body.text.length()
		_shown = minf(_shown + delta * TYPE_SPEED, total)
		_body.visible_characters = int(_shown)
		if _shown >= total:
			_typing = false
			_hint.visible = true
	else:
		_blink += delta
		_hint.visible = fmod(_blink, 0.8) < 0.5
