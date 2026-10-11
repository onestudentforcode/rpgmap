extends RefCounted
const KINDS := ["hoe", "sower", "harvester"]
const NAMES := {"hoe": "锄头", "sower": "播种器", "harvester": "采收器"}
var data := fresh()
var prices: Dictionary = {}

static func fresh() -> Dictionary:
	return {"owned": [], "levels": {"hoe": 0, "sower": 0, "harvester": 0}, "kind": "hoe", "crop": "dew_grass"}

static func valid(value, crops: Dictionary) -> bool:
	if not value is Dictionary or not value.get("owned") is Array or not value.get("levels") is Dictionary: return false
	if value.get("kind") not in KINDS or not crops.has(value.get("crop")) or value["levels"].size() != 3: return false
	var seen := {}
	for kind in value["owned"]:
		if kind not in KINDS or seen.has(kind): return false
		seen[kind] = true
	for kind in KINDS:
		var level = value["levels"].get(kind)
		if not (level is int or level is float) or not is_finite(float(level)) or (level != 0 and level != 1) or (level == 1 and not seen.has(kind)): return false
	return true

func buy(kind: String, economy) -> Dictionary:
	if kind not in KINDS or not prices.has(kind): return {"ok": false, "reason": "未知工具"}
	if data["owned"].has(kind): return {"ok": false, "reason": "已拥有，无需重复购买"}
	var price := int(prices[kind])
	if price <= 0 or economy.primeval_stones < price: return {"ok": false, "reason": "元石不足"}
	economy.primeval_stones -= price
	data["owned"].append(kind)
	economy.traded.emit(kind, 1, true, price, "tool")
	return {"ok": true, "amount": price}

func switch_level(kind: String) -> bool:
	if not data["owned"].has(kind): return false
	data["levels"][kind] = 1 - int(data["levels"][kind])
	return true

func advanced(kind: String) -> bool:
	return data["owned"].has(kind) and int(data["levels"][kind]) == 1
