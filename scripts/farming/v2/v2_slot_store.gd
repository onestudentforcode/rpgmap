extends "res://scripts/farming/core/storage/farm_slot_store.gd"
const V2Snapshot := preload("res://scripts/farming/v2/v2_snapshot.gd")
func _init(directory: String = "user://farm_demo_v2_slots") -> void:
	super(directory, V2Snapshot)
