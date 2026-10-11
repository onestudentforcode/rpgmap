extends RefCounted
## Pure deterministic templates and detached validation. Runtime cannot force a rank.
const Data := preload("res://scripts/farming/v1/v1_data.gd")
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")

static func generate(day: int, revenue: int, test_rank: int = 0, catalog = Data) -> Dictionary:
	if not Scalars.whole(day) or not Scalars.whole(revenue) or test_rank < 0 or test_rank > 5:
		return {}
	var settings: Dictionary = catalog.load_data()["orders"]
	var limit := int(settings["daily_limit"])
	var cap: int = catalog.unlocked_rank(revenue)
	var entries := []
	for index in range(limit):
		# Offset each five-day cycle so path and rank rotations cannot lock together.
		var cycle: int = day / settings["paths"].size()
		var rank := test_rank if test_rank > 0 else (1 if index == 0 else 1 + (day * (limit-1) + index-1 + cycle) % cap)
		entries.append({"id": day * limit + index + 1, "day": day,
			"path": settings["paths"][(day * limit + index) % settings["paths"].size()],
			"rank": rank, "demand": int(settings["base_demand"]) * rank,
			"status": "open", "receipt": {}})
	return {"day": day, "issued_revenue": revenue, "entries": entries, "settlements": []}

static func advance(previous: Dictionary, day: int, revenue: int, catalog = Data) -> Dictionary:
	var next := generate(day, revenue, 0, catalog)
	next["settlements"] = previous["settlements"].duplicate(true)
	for entry in previous["entries"]:
		if entry["status"] == "completed":
			next["settlements"].append({"issued_revenue": previous["issued_revenue"], "entry": entry.duplicate(true)})
	return next

static func normalize_entry(entry, template: Dictionary, catalog = Data) -> Dictionary:
	if not Scalars.exact(entry, template.keys()):
		return Scalars.fail("订单字段非法")
	for key in ["id", "day", "rank", "demand"]:
		if not Scalars.whole(entry[key], int(template[key]), int(template[key])):
			return Scalars.fail("订单模板或编号非法")
	if entry["path"] != template["path"] or entry["status"] not in ["open", "completed"] or not entry["receipt"] is Dictionary:
		return Scalars.fail("订单流派或状态非法")
	var paid := 0
	if entry["status"] == "open":
		if not entry["receipt"].is_empty():
			return Scalars.fail("未完成订单不能包含回款")
	else:
		var receipt: Dictionary = entry["receipt"]
		if not receipt.get("item_id") is String:
			return Scalars.fail("订单交付材料非法")
		var quote = catalog.demand_quote(template["path"], int(template["rank"]), int(template["demand"]), receipt["item_id"])
		if not quote["ok"] or not Scalars.exact(receipt, ["item_id", "quantity", "provided", "base", "premium", "payout"]):
			return Scalars.fail("订单交付记录非法")
		for key in ["quantity", "provided", "base", "premium", "payout"]:
			if not Scalars.whole(receipt[key], int(quote[key]), int(quote[key])):
				return Scalars.fail("订单数量或回款非法")
		for key in receipt:
			template["receipt"][key] = receipt[key] if key == "item_id" else int(receipt[key])
		paid = int(quote["payout"])
	template["status"] = entry["status"]
	return {"ok": true, "entry": template, "paid": paid}

static func normalize(value, day: int, revenue: int, order_revenue: int, catalog = Data) -> Dictionary:
	if not Scalars.exact(value, ["day", "issued_revenue", "entries", "settlements"]) or not Scalars.whole(value["day"], day, day) or not Scalars.whole(value["issued_revenue"], 0, revenue) or not value["entries"] is Array or not value["settlements"] is Array:
		return Scalars.fail("订单日期或生成收入非法")
	var expected := generate(day, int(value["issued_revenue"]), 0, catalog)
	if value["entries"].size() != expected["entries"].size():
		return Scalars.fail("每日订单数量非法")
	var paid := 0
	for index in range(expected["entries"].size()):
		var checked := normalize_entry(value["entries"][index], expected["entries"][index], catalog)
		if not checked["ok"]:
			return checked
		paid += int(checked["paid"])
	if int(value["issued_revenue"]) + paid > revenue:
		return Scalars.fail("订单回款与累计收入不一致")
	var current_paid := paid
	var prior_id := 0
	var limit := int(catalog.load_data()["orders"]["daily_limit"])
	for record in value["settlements"]:
		if not Scalars.exact(record, ["issued_revenue", "entry"]) or not Scalars.whole(record["issued_revenue"], 0, revenue) or not record["entry"] is Dictionary or not Scalars.whole(record["entry"].get("id"), prior_id+1, day*limit):
			return Scalars.fail("历史订单编号或收入非法")
		var ident := int(record["entry"]["id"])
		var historical_day: int = (ident-1) / limit
		var templates := generate(historical_day, int(record["issued_revenue"]), 0, catalog)
		var checked := normalize_entry(record["entry"], templates["entries"][(ident-1) % limit], catalog)
		if not checked["ok"] or checked["entry"]["status"] != "completed":
			return Scalars.fail("历史订单结算记录非法")
		expected["settlements"].append({"issued_revenue": int(record["issued_revenue"]), "entry": checked["entry"]})
		paid += int(checked["paid"])
		prior_id = ident
	if paid != order_revenue:
		return Scalars.fail("订单结算合计与累计收入不一致")
	if int(value["issued_revenue"]) < order_revenue - current_paid:
		return Scalars.fail("当日生成收入不能低于历史订单回款")
	return {"ok": true, "orders": expected}
