extends RefCounted
## UI tokens separate from the world palette: jade ink and warm paper.
const INK := Color("172922")
const SURFACE := Color("223b31")
const HOVER := Color("315545")
const BORDER := Color("627c62")
const PAPER := Color("f2ead3")
const MUTED := Color("b8c5b2")
const JADE := Color("a5dfad")
const ERROR := Color("ffb6a3")

static func box(color: Color, border: Color = BORDER) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.border_color = border
	result.set_border_width_all(1)
	result.set_corner_radius_all(4)
	result.content_margin_left = 8
	result.content_margin_right = 8
	result.content_margin_top = 4
	result.content_margin_bottom = 4
	return result

static func theme() -> Theme:
	var result := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "sans-serif"])
	result.default_font = font
	result.default_font_size = 12
	result.set_color("font_color", "Label", PAPER)
	result.set_stylebox("panel", "PanelContainer", box(INK))
	result.set_stylebox("normal", "Button", box(SURFACE))
	result.set_stylebox("hover", "Button", box(HOVER))
	result.set_stylebox("pressed", "Button", box(HOVER, JADE))
	result.set_stylebox("focus", "Button", box(Color(0,0,0,0), PAPER))
	result.set_stylebox("disabled", "Button", box(INK, SURFACE))
	result.set_color("font_color", "Button", PAPER)
	result.set_color("font_disabled_color", "Button", MUTED)
	result.set_stylebox("tab_selected", "TabBar", box(HOVER, JADE))
	result.set_stylebox("tab_unselected", "TabBar", box(SURFACE))
	result.set_stylebox("tab_hovered", "TabBar", box(HOVER))
	result.set_color("font_selected_color", "TabBar", PAPER)
	result.set_color("font_unselected_color", "TabBar", MUTED)
	return result

static func label(text: String, muted: bool = false) -> Label:
	var result := Label.new()
	result.text = text
	if muted:
		result.add_theme_color_override("font_color", MUTED)
	return result
