extends RefCounted
## Read only baked V1 data. Quotes have no inventory or wallet side effects.
const PATH := "res://content/farming/baked/v1/production.json"

static func load_data() -> Dictionary:
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

static func resources(data: Dictionary) -> Dictionary:
	var out := {}
	for item in data.get("resources", []):
		out[item["id"]] = item
	return out

static func load_map() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://content/farming/baked/maps/%s.json" % load_data()["config"]["map_id"]))

static func tillable_map() -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/farming/baked/terrains.json"))
	var out := {}
	for terrain in data["terrains"]:
		out[terrain["id"]] = terrain["tillable"]
	return out

static func definitions(section: String) -> Dictionary:
	var out := {}
	for row in load_data()[section]:
		out[row["id"]] = row
	return out

static func light_at(cell: Vector2i) -> int:
	var light: Dictionary = load_data()["config"]["light"]
	for region in light["regions"]:
		var rect: Array = region["rect"]
		if Rect2i(int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3])).has_point(cell):
			return int(region["level"])
	return int(light["default"])

static func supply_quote(path: String, rank: int, item_id: String) -> Dictionary:
	var data := load_data()
	if data.is_empty() or rank < 1 or rank > 5 or path not in data["orders"]["paths"]:
		return {"ok": false, "reason": "流派或转数非法"}
	var item: Dictionary = resources(data).get(item_id, {})
	if item.is_empty() or not item["supply_allowed"] or item["element"] != path or item["supply_value"] <= 0:
		return {"ok": false, "reason": "材料不具备对应食材资格"}
	var demand := int(data["orders"]["base_demand"]) * rank
	var quantity := ceili(float(demand) / float(item["supply_value"]))
	var base := quantity * int(item["sell_price"])
	var premium := floori(float(base) * float(data["orders"]["premium_percent"]) / 100.0)
	return {"ok": true, "item_id": item_id, "path": path, "rank": rank,
		"demand": demand, "quantity": quantity, "provided": quantity * int(item["supply_value"]),
		"base": base, "premium": premium, "payout": base + premium}

static func unlocked_rank(gross_revenue: int) -> int:
	var data := load_data()
	var rank := 1
	for candidate in range(1, 6):
		if gross_revenue >= int(data["orders"]["rank_unlock_revenue"][str(candidate)]):
			rank = candidate
	return rank
