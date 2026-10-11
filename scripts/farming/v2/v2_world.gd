extends "res://scripts/farming/v1/v1_world.gd"
const V2Data := preload("res://scripts/farming/v2/v2_data.gd")
const V2Snapshot := preload("res://scripts/farming/v2/v2_snapshot.gd")
func _init(slot_store = null) -> void:
	super(slot_store, V2Data, V2Snapshot)
