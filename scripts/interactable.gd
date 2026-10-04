class_name Interactable
extends Area2D
## 可交互物判定区：挂靠近触发的交互（dialogue/menu/chest/save）。
## battle 类型不走本类（走进触发的 BattleZone 由 MapHost 另行生成）。
## type/params 来自烘焙数据；params 即该交互的完整烘焙条目。

var type := "dialogue"
var params: Dictionary = {}
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
