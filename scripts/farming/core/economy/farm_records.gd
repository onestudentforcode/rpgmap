extends RefCounted
## First-period accounting. Only successful domain settlements emit events.
const PERIOD := 45
var data: Dictionary = {}

static func fresh(start_day: int = 0) -> Dictionary:
	return {"schema": 1, "start_day": start_day, "planted": {}, "harvests": {},
		"yield": {}, "feeding": {}, "revenue": 0,
		"spending": {"seed": 0, "production": 0, "tool": 0}, "report": {}}

func active() -> bool:
	return data["report"].is_empty()

func _add(key: String, id: String, quantity: int) -> void:
	data[key][id] = int(data[key].get(id, 0)) + quantity

func planted(crop_id: String) -> void:
	if active(): _add("planted", crop_id, 1)

func harvested(crop_id: String, products: Array) -> void:
	if not active(): return
	_add("harvests", crop_id, 1)
	for product in products: _add("yield", product["item_id"], int(product["qty"]))

func traded(_id: String, _quantity: int, buying: bool, amount: int, kind: String) -> void:
	if not active(): return
	if buying:
		if data["spending"].has(kind): data["spending"][kind] += amount
	else: data["revenue"] += amount

func fed(item_id: String, quantity: int) -> void:
	if active(): _add("feeding", item_id, quantity)

func finish_day(total_days: int, balance: int) -> bool:
	if not active() or total_days < int(data["start_day"]) + PERIOD: return false
	var report := data.duplicate(true)
	report.erase("report")
	report["end_day"] = int(data["start_day"]) + PERIOD
	report["balance"] = balance
	report["net"] = int(data["revenue"]) - int(data["spending"]["seed"]) - int(data["spending"]["production"]) - int(data["spending"]["tool"])
	data["report"] = report
	return true

static func _whole(value, minimum: int = 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(float(value)) and value >= minimum and value <= 9000000000000

static func normalize(value: Dictionary) -> Dictionary:
	var result := {}
	for key in value:
		var entry = value[key]
		result[key] = normalize(entry) if entry is Dictionary else (int(entry) if entry is float else entry)
	return result

static func valid(value, day: int, crops: Dictionary, items: Dictionary) -> bool:
	if not value is Dictionary or value.get("schema") != 1 or not _whole(value.get("start_day")) or value["start_day"] > day: return false
	if not _whole(value.get("revenue")) or not value.get("spending") is Dictionary or not value.get("report") is Dictionary: return false
	if value["spending"].size() != 3: return false
	for kind in ["seed", "production", "tool"]:
		if not _whole(value["spending"].get(kind)): return false
	for key in ["planted", "harvests", "yield", "feeding"]:
		if not value.get(key) is Dictionary: return false
		for id in value[key]:
			if not _whole(value[key][id], 1): return false
			if key in ["planted", "harvests"]:
				if not crops.has(id): return false
			elif not items.has(id) or (key == "feeding" and items[id].get("kind") != "food"): return false
	var report: Dictionary = value["report"]
	if report.is_empty(): return day < int(value["start_day"]) + PERIOD
	if day < int(value["start_day"]) + PERIOD or report.get("end_day") != int(value["start_day"]) + PERIOD or not _whole(report.get("balance")): return false
	for key in ["schema", "start_day", "planted", "harvests", "yield", "feeding", "revenue", "spending"]:
		if report.get(key) != value[key]: return false
	return _whole(report.get("net"), -9000000000000) and report["net"] == value["revenue"] - value["spending"]["seed"] - value["spending"]["production"] - value["spending"]["tool"]
