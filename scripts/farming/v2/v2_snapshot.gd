extends RefCounted
const Common := preload("res://scripts/farming/v1/v1_snapshot.gd")
const Data := preload("res://scripts/farming/v2/v2_data.gd")
const SCHEMA := 7
static func fresh() -> Dictionary:
	return Common.fresh(Data, SCHEMA)
static func normalize(value) -> Dictionary:
	return Common.normalize(value, Data, SCHEMA, false)
