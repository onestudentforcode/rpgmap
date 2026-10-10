extends RefCounted
## Pure module state. Currency and material dictionary semantics match upstream.
signal traded(item_id: String, quantity: int, buying: bool, amount: int, kind: String)
signal fed(item_id: String, quantity: int)
var primeval_stones := 60
var gu: Dictionary = {}
var items: Dictionary = {}
var nutrition: Dictionary = {}
var _config: Dictionary = {}
var _inventory


func setup(config: Dictionary, item_defs: Dictionary, crop_defs: Dictionary, inventory) -> void:
	_config = config.get("economy", {})
	_inventory = inventory
	items = item_defs
	primeval_stones = int(_config.get("initial_primeval_stones", 60))
	gu = {"instance_id": "farm_test_wood_gu", "path_id": "wood", "satiety": 6,
		"feeding_count": 0, "materials_consumed": {}}
	nutrition = {}
	for cid in crop_defs:
		var crop: Dictionary = crop_defs[cid]
		var harvests := int(crop.get("max_harvests", 1))
		var days := 0
		for stage in crop["growth_stages"]:
			days += int(stage["days"])
		days += (harvests - 1) * int(crop.get("regrowth_duration", 0))
		var ap_costs: Dictionary = config["ap_costs"]
		var area := int(crop["footprint"][0]) * int(crop["footprint"][1])
		var actions := area * int(ap_costs["till"]) + int(ap_costs["plant"]) + harvests * int(ap_costs["harvest"])
		if crop["harvest_type"] == "regrow":
			actions += int(ap_costs["clear"])
		var cash := int(items[String(cid) + "_seed"]["buy_price"])
		var material := medium_material(String(crop["planting_medium"]))
		if not material.is_empty():
			cash += area * int(items[material]["buy_price"])
			actions += area * int(ap_costs["prepare_medium"])
		var total := float(cash) + actions * float(_config.get("ap_weight", 1)) + days * float(_config.get("day_weight", 1))
		for product in crop["harvest_items"]:
			var iid: String = product["item_id"]
			if items[iid].get("kind", "") != "food":
				continue
			var expected := (float(product["min"]) + float(product["max"])) * 0.5 * harvests
			nutrition[iid] = maxi(1, ceili(total / expected))


func medium_material(medium: String) -> String:
	return String(_config.get("medium_materials", {}).get(medium, ""))


func trade(item_id: String, quantity: int, buying: bool) -> Dictionary:
	if quantity <= 0 or quantity > 1000000:
		return _error("数量必须为 1～1000000 的整数")
	var item: Dictionary = items.get(item_id, {})
	var price := int(item.get("buy_price" if buying else "sell_price", 0))
	if price <= 0:
		return _error("该物品不支持此交易")
	var amount := price * quantity
	if buying:
		if primeval_stones < amount:
			return _error("元石不足")
		primeval_stones -= amount
		_inventory.add(item_id, quantity)
	else:
		if not _inventory.remove(item_id, quantity):
			return _error("库存不足")
		primeval_stones += amount
	traded.emit(item_id, quantity, buying, amount, String(item.get("kind", "")))
	return {"ok": true, "amount": amount}


func feed_quantity(item_id: String) -> int:
	var value := int(nutrition.get(item_id, 0))
	return ceili(6.0 / value) if value > 0 else 0


func feed(item_id: String) -> Dictionary:
	if int(gu["satiety"]) != 0:
		return _error("蛊虫尚未饥饿")
	var item: Dictionary = items.get(item_id, {})
	if item.get("kind", "") != "food" or not item.get("path_ids", []).has(gu["path_id"]):
		return _error("食材五行不匹配")
	var quantity := feed_quantity(item_id)
	if quantity <= 0 or not _inventory.remove(item_id, quantity):
		return _error("食材不足")
	gu["satiety"] = 6
	gu["feeding_count"] = int(gu["feeding_count"]) + 1
	var consumed: Dictionary = gu["materials_consumed"]
	consumed[item_id] = int(consumed.get(item_id, 0)) + quantity
	fed.emit(item_id, quantity)
	return {"ok": true, "quantity": quantity}


func on_day_changed() -> void:
	gu["satiety"] = maxi(0, int(gu["satiety"]) - 1)


func can_use() -> bool:
	return int(gu["satiety"]) > 0


## Integration hook: caller reports only a completed designated action.
func record_use(behavior: String, succeeded: bool) -> Dictionary:
	if not _config.get("use_behaviors", ["battle"]).has(behavior):
		return _error("该行为不消耗蛊虫饱食度")
	if not succeeded:
		return _error("行为未成功，不扣饱食度")
	if not can_use():
		return _error("蛊虫饥饿，无法使用")
	gu["satiety"] = int(gu["satiety"]) - 1
	return {"ok": true}


func to_save() -> Dictionary:
	return {"primeval_stones": primeval_stones, "gu": gu.duplicate(true)}


func apply_save(data: Dictionary) -> bool:
	# Validate the entire economy snapshot before replacing state.
	var money = data.get("primeval_stones", -1)
	var saved_gu = data.get("gu", {})
	if not _whole(money) or money < 0 or not saved_gu is Dictionary:
		return false
	if saved_gu.get("instance_id", "") != "farm_test_wood_gu" or saved_gu.get("path_id", "") != "wood":
		return false
	var satiety = saved_gu.get("satiety", -1)
	var feeds = saved_gu.get("feeding_count", -1)
	var consumed = saved_gu.get("materials_consumed", null)
	if not _whole(satiety) or satiety < 0 or satiety > 6 or not _whole(feeds) or feeds < 0 or not consumed is Dictionary:
		return false
	for iid in consumed:
		if not nutrition.has(iid) or not _whole(consumed[iid]) or consumed[iid] <= 0:
			return false
	primeval_stones = int(money)
	gu = saved_gu.duplicate(true)
	gu["satiety"] = int(satiety)
	gu["feeding_count"] = int(feeds)
	for iid in gu["materials_consumed"]:
		gu["materials_consumed"][iid] = int(gu["materials_consumed"][iid])
	return true


func export_materials() -> Dictionary:
	var out := {}
	for entry in _inventory.entries():
		if items.get(entry["item_id"], {}).get("kind", "") == "food":
			out[entry["item_id"]] = entry["count"]
	return out


func _whole(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))


func _error(message: String) -> Dictionary:
	return {"ok": false, "reason": message}
