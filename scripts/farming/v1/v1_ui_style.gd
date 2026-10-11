extends RefCounted
## Phase 6.5 UI tokens. World and V0 palettes remain independent.
const INK := Color("f6f4ed")
const PANEL := Color("fffdf8")
const SURFACE := Color("eef2e8")
const BORDER := Color("cfd8c6")
const PAPER := Color("334238")
const MUTED := Color("58665a")
const JADE := Color("58745b")
const SOFT := Color("deebd9")
const ERROR := Color("9b4e42")
const WATER := Color("446976")

static func box(color: Color, border: Color = BORDER, padding: int = 12) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.border_color = border
	result.set_border_width_all(1)
	result.set_corner_radius_all(8)
	result.content_margin_left = padding
	result.content_margin_right = padding
	result.content_margin_top = padding
	result.content_margin_bottom = padding
	return result

static func theme() -> Theme:
	var result := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	font.multichannel_signed_distance_field = true
	result.default_font = font
	result.default_font_size = 18
	for type in ["Label", "Button", "OptionButton", "CheckButton", "LineEdit", "SpinBox"]:
		result.set_color("font_color", type, PAPER)
		result.set_color("font_hover_color", type, PAPER)
		result.set_color("font_pressed_color", type, PAPER)
		result.set_color("font_focus_color", type, PAPER)
		result.set_color("icon_disabled_color", type, Color(0.45,0.45,0.45,0.55))
		result.set_color("font_disabled_color", type, MUTED)
	result.set_stylebox("panel", "PanelContainer", box(PANEL))
	result.set_stylebox("panel", "AcceptDialog", box(PANEL))
	result.set_stylebox("embedded_border", "Window", box(PANEL, JADE, 8))
	result.set_stylebox("embedded_unfocused_border", "Window", box(PANEL, BORDER, 8))
	result.set_color("title_color", "Window", PAPER)
	for type in ["Button", "OptionButton"]:
		result.set_stylebox("normal", type, box(SURFACE, BORDER, 8))
		result.set_stylebox("hover", type, box(SOFT, JADE, 8))
		result.set_stylebox("pressed", type, box(SOFT, JADE, 8))
		result.set_stylebox("focus", type, box(Color.TRANSPARENT, WATER, 8))
		result.set_stylebox("disabled", type, box(INK, BORDER, 8))
	result.set_stylebox("normal", "LineEdit", box(PANEL, BORDER, 6))
	result.set_stylebox("focus", "LineEdit", box(PANEL, WATER, 6))
	result.set_stylebox("panel", "PopupPanel", box(PANEL))
	result.set_stylebox("panel", "PopupMenu", box(PANEL))
	result.set_color("font_color", "PopupMenu", PAPER)
	result.set_stylebox("panel", "TooltipPanel", box(PANEL, JADE, 8))
	result.set_color("font_color", "TooltipLabel", PAPER)
	result.set_font_size("font_size", "TooltipLabel", 16)
	result.set_stylebox("background", "ProgressBar", box(SURFACE, BORDER, 0))
	result.set_stylebox("fill", "ProgressBar", box(JADE, JADE, 0))
	result.set_color("font_color", "ProgressBar", PAPER)
	for type in ["VBoxContainer", "HBoxContainer", "GridContainer"]:
		result.set_constant("separation", type, 8)
	result.set_constant("h_separation", "GridContainer", 12)
	result.set_constant("v_separation", "GridContainer", 12)
	return result

static func label(text: String, muted: bool = false) -> Label:
	var result := Label.new()
	result.text = text
	if muted:
		result.add_theme_color_override("font_color", MUTED)
		result.add_theme_font_size_override("font_size", 16)
	return result
