extends Node
## 相机行为组件（Phase 0 行为组件化，phase-01 §2.4）：
## WASD/方向键平移 + 滚轮缩放 0.5–2.0（Godot 4 语义：zoom>1 放大）+ 地图边界钳制。
## 消费方以 preload 引用（不依赖全局类缓存）。

signal zoom_set(z: float)

const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0
const ZOOM_STEP := 1.15
const PAN_SPEED := 480.0

var cam: Camera2D
var map_px := Vector2.ZERO
var view_top := 0.0
var view_bottom := 0.0


func setup(camera: Camera2D, cells: Vector2i, tile: int) -> void:
	cam = camera
	map_px = Vector2(cells) * float(tile)


func _process(delta: float) -> void:
	if cam == null:
		return
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_physical_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		dir.x += 1.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	cam.position += dir * (PAN_SPEED / cam.zoom.x) * delta
	_clamp()


func _unhandled_input(event: InputEvent) -> void:
	if cam == null or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_set_zoom(cam.zoom.x * ZOOM_STEP)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_set_zoom(cam.zoom.x / ZOOM_STEP)


func _set_zoom(z: float) -> void:
	var c := clampf(z, ZOOM_MIN, ZOOM_MAX)
	cam.zoom = Vector2(c, c)
	zoom_set.emit(c)


func _clamp() -> void:
	# 视口大于地图时不硬钳中心（允许露出图外底色）；小于地图时锁定边界
	var vs := get_viewport().get_visible_rect().size
	var half := vs * 0.5 / cam.zoom.x
	var lo := Vector2(minf(half.x, map_px.x * 0.5), minf(half.y, map_px.y * 0.5))
	cam.position.x = clampf(cam.position.x, lo.x, map_px.x - lo.x)
	var top := minf(half.y - view_top / cam.zoom.y, map_px.y * 0.5)
	var bottom := maxf(map_px.y - half.y + view_bottom / cam.zoom.y, map_px.y * 0.5)
	cam.position.y = clampf(cam.position.y, top, bottom)
