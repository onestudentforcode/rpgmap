extends "res://scripts/farming/core/storage/farm_slot_store.gd"
const P8Snapshot := preload("res://scripts/farming/p8/p8_snapshot.gd")
func _init(directory: String = "user://farm_demo_p8_slots") -> void:
	super(directory, P8Snapshot)
