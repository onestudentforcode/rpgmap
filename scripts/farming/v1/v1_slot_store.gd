extends "res://scripts/farming/core/storage/farm_slot_store.gd"
const V1Snapshot := preload("res://scripts/farming/v1/v1_snapshot.gd")

func _init(directory: String = "user://farm_demo_v1_slots") -> void:
	super(directory, V1Snapshot)
