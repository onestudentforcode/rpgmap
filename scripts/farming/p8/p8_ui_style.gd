extends RefCounted
const Base := preload("res://scripts/farming/v1/v1_ui_style.gd")
const CARD := Color("f1f0e5")
const BORDER := Color("c7ceba")
static func theme() -> Theme:
	var result := Base.theme()
	result.set_stylebox("panel","PanelContainer",Base.box(Color("fbfaf3"),BORDER))
	return result
