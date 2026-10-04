class_name Interactable
extends Area2D
## 可交互物判定区：挂在物件/电梯前的脚底位置，玩家靠近时由 Player 的 reach 区检测。

var display_name := ""
var pages: PackedStringArray = PackedStringArray()


func _init() -> void:
	add_to_group("interactable")
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 26.0
	cs.shape = shape
	cs.position = Vector2(0, -4)
	add_child(cs)
