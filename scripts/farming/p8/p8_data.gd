extends RefCounted
## P8 reads its own baked catalog; every query is re-declared against it because
## GDScript statics do not dispatch virtually through subclass overrides.
const Common := preload("res://scripts/farming/v1/v1_data.gd")
static func load_data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://content/farming/baked/p8/production.json"))
static func resources(data: Dictionary) -> Dictionary:
	return Common.resources(data)
static func load_map() -> Dictionary:
	return Common.load_map(load_data())
static func tillable_map() -> Dictionary:
	var result := Common.tillable_map()
	result["water"] = false
	return result
static func definitions(section: String) -> Dictionary:
	return Common.definitions(section, load_data())
static func light_at(cell: Vector2i) -> int:
	return Common.light_at(cell, load_data())
static func supply_quote(path: String, rank: int, item: String) -> Dictionary:
	return Common.supply_quote(path, rank, item, load_data())
static func demand_quote(path: String, rank: int, demand: int, item: String) -> Dictionary:
	return Common.demand_quote(path, rank, demand, item, load_data())
static func unlocked_rank(revenue: int) -> int:
	return Common.unlocked_rank(revenue, load_data())
