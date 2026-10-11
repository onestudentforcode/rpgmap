extends Node2D
## Recommended use of the existing terrain; no free medium or land restriction.
const UI := preload("res://scripts/farming/rendering/farm_ui_style.gd")

func _ready() -> void:
	z_index = 4
	for entry in [
		{"text":"灵植种植区", "position":Vector2(5*64,5*64)},
		{"text":"菌床建议区 · B准备", "position":Vector2(15*64,5*64)},
		{"text":"石板通道", "position":Vector2(9*64,6*64-16)}]:
		var label := UI.label(entry["text"])
		label.position = entry["position"]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size",18)
		label.add_theme_color_override("font_shadow_color",UI.INK)
		label.add_theme_constant_override("shadow_offset_x",1)
		label.add_theme_constant_override("shadow_offset_y",1)
		add_child(label)
