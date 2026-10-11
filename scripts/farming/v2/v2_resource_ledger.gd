extends RefCounted
## Per-item inflow/outflow ledger. Real claims only: nothing is booked before it
## enters or leaves the shared inventory, and unclaimed batches never count as growth.
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")
const HISTORY_LIMIT := 15

var _owner: WeakRef
var world:
	get:
		return _owner.get_ref()
var state: Dictionary

func _init(owner) -> void:
	_owner = weakref(owner)

func _error(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

static func _flows(value) -> Dictionary:
	## Aggregated {item: {reason: count}}; zeros dropped so net numbers derive from
	## non-negative integers only.
	var out := {}
	for item in value:
		for reason in value[item]:
			var count := int(value[item][reason])
			if count > 0:
				if not out.has(item):
					out[item] = {}
				out[item][reason] = count
	return out

static func _totals(flows: Dictionary) -> Dictionary:
	var out := {}
	for item in flows:
		var total := 0
		for reason in flows[item]:
			total += int(flows[item][reason])
		out[item] = total
	return out

static func _balance(day: int, opening: Dictionary, inflows: Dictionary, outflows: Dictionary) -> Dictionary:
	var closing := opening.duplicate()
	for item in _totals(inflows):
		closing[item] = int(closing.get(item, 0)) + int(_totals(inflows)[item])
	for item in _totals(outflows):
		closing[item] = int(closing.get(item, 0)) - int(_totals(outflows)[item])
		if closing[item] < 0:
			return {"ok": false, "reason": "资源账出库大于库存：" + item}
		if closing[item] == 0:
			closing.erase(item)
	return {"ok": true, "closing": closing}

func fresh(day: int, opening: Dictionary) -> void:
	state = {"pending": {"day": day, "opening": opening.duplicate(), "inflows": {}, "outflows": {}}, "history": []}

func record(inflows: Dictionary, outflows: Dictionary, reason: String) -> void:
	## Called from successful model transactions only; failures never leave a trace.
	var pending: Dictionary = state["pending"]
	for item in inflows:
		if int(inflows[item]) > 0:
			if not pending["inflows"].has(item):
				pending["inflows"][item] = {}
			pending["inflows"][item][reason] = int(pending["inflows"][item].get(reason, 0)) + int(inflows[item])
	for item in outflows:
		if int(outflows[item]) > 0:
			if not pending["outflows"].has(item):
				pending["outflows"][item] = {}
			pending["outflows"][item][reason] = int(pending["outflows"][item].get(reason, 0)) + int(outflows[item])

## Close the completed day; the closing stock must equal the live inventory or the
## mismatch is reported so the daily save is blocked instead of papered over.
func settle(completed_day: int, inventory: Dictionary) -> String:
	var pending: Dictionary = state["pending"]
	if int(pending["day"]) != completed_day:
		return "资源账日期与日结不一致"
	var checked := _balance(int(pending["day"]), pending["opening"], _flows(pending["inflows"]), _flows(pending["outflows"]))
	if not checked["ok"]:
		return "资源账对账异常：" + String(checked["reason"])
	var closing: Dictionary = checked["closing"]
	for item in closing:
		if int(inventory.get(item, 0)) != int(closing[item]):
			return "资源账与库存不一致：%s（账%d，实%d）" % [item,int(closing[item]),int(inventory.get(item, 0))]
	for item in inventory:
		if int(inventory[item]) > 0 and int(closing.get(item, 0)) != int(inventory[item]):
			return "资源账与库存不一致：%s（账%d，实%d）" % [item,int(closing.get(item, 0)),int(inventory[item])]
	state["history"].append({"day": int(pending["day"]), "opening": pending["opening"].duplicate(),
		"inflows": _flows(pending["inflows"]), "outflows": _flows(pending["outflows"]), "closing": closing})
	while state["history"].size() > HISTORY_LIMIT:
		state["history"].pop_front()
	# Roll only the pending day; the archived history must survive this reset.
	state["pending"] = {"day": completed_day + 1, "opening": closing.duplicate(), "inflows": {}, "outflows": {}}
	return ""

## Read-only day view for the resource page; day -1 is the live, unsettled today.
func day_view(day: int) -> Dictionary:
	if day < 0:
		var pending: Dictionary = state["pending"]
		return {"day": int(pending["day"]), "opening": pending["opening"],
			"inflows": _flows(pending["inflows"]), "outflows": _flows(pending["outflows"]),
			"closing": world.inventory.to_save(), "label": "今日（实时，未结算）"}
	for row in state["history"]:
		if int(row["day"]) == day:
			return {"day": day, "opening": row["opening"], "inflows": row["inflows"],
				"outflows": row["outflows"], "closing": row["closing"], "label": "第%d日（已结算）" % (day + 1)}
	return {}

## Average over the most recent settled days; zero-activity days included, today never.
func average_view(days: int = 7) -> Dictionary:
	var sample: Array = state["history"].slice(maxi(0, state["history"].size() - days))
	var inflows := {}
	var outflows := {}
	for row in sample:
		for item in row["inflows"]:
			for reason in row["inflows"][item]:
				if not inflows.has(item):
					inflows[item] = {}
				inflows[item][reason] = int(inflows[item].get(reason, 0)) + int(row["inflows"][item][reason])
		for item in row["outflows"]:
			for reason in row["outflows"][item]:
				if not outflows.has(item):
					outflows[item] = {}
				outflows[item][reason] = int(outflows[item].get(reason, 0)) + int(row["outflows"][item][reason])
	var count := sample.size()
	var totals_in := {}
	var totals_out := {}
	for item in inflows:
		var total := 0
		for reason in inflows[item]:
			total += int(inflows[item][reason])
		totals_in[item] = [total, float(total) / count]
	for item in outflows:
		var total := 0
		for reason in outflows[item]:
			total += int(outflows[item][reason])
		totals_out[item] = [total, float(total) / count]
	return {"days": count, "inflows": inflows, "outflows": outflows, "totals_in": totals_in, "totals_out": totals_out,
		"label": ("最近%d日均值" % count) + "（含无活动日）" if count > 0 else "暂无已结算日"}

func to_save() -> Dictionary:
	return state.duplicate(true)

func apply_save(value: Dictionary) -> void:
	state = value.duplicate(true)

static func _normalize_opening(value, items) -> Dictionary:
	if not value is Dictionary:
		return Scalars.fail("库存表非法")
	var out := {}
	for item in value:
		if not items.has(item) or not Scalars.whole(value[item]) or int(value[item]) < 0:
			return Scalars.fail("库存物品或数量非法")
		if int(value[item]) > 0:
			out[item] = int(value[item])
	return {"ok": true, "opening": out}

static func _normalize_flows(value, items) -> Dictionary:
	if not value is Dictionary:
		return Scalars.fail("收支表非法")
	var out := {}
	for item in value:
		if not items.has(item) or not value[item] is Dictionary or value[item].is_empty():
			return Scalars.fail("收支物品非法")
		var reasons := {}
		for reason in value[item]:
			if not reason is String or reason.is_empty() or reason.length() > 24 or not Scalars.whole(value[item][reason], 1):
				return Scalars.fail("收支原因或数量非法")
			reasons[reason] = int(value[item][reason])
		out[item] = reasons
	return {"ok": true, "flows": out}

## Whole-ledger validation: continuity, conservation and agreement with the loaded
## inventory. Corrupt books are rejected before the world applies anything.
static func normalize(value, day: int, inventory: Dictionary, catalog) -> Dictionary:
	if not Scalars.exact(value, ["pending", "history"]):
		return Scalars.fail("资源账字段非法")
	var items = catalog.resources(catalog.load_data())
	var pending = value["pending"]
	if not Scalars.exact(pending, ["day", "opening", "inflows", "outflows"]) or not Scalars.whole(pending["day"], day, day):
		return Scalars.fail("当日账日期非法")
	var opening := _normalize_opening(pending["opening"], items)
	if not opening["ok"]:
		return opening
	var inflows := _normalize_flows(pending["inflows"], items)
	if not inflows["ok"]:
		return inflows
	var outflows := _normalize_flows(pending["outflows"], items)
	if not outflows["ok"]:
		return outflows
	var balanced := _balance(int(pending["day"]), opening["opening"], inflows["flows"], outflows["flows"])
	if not balanced["ok"]:
		return Scalars.fail(String(balanced["reason"]))
	var closing: Dictionary = balanced["closing"]
	if closing != inventory:
		return Scalars.fail("当日账与库存不符")
	if not value["history"] is Array or value["history"].size() > HISTORY_LIMIT or value["history"].size() > day:
		return Scalars.fail("资源账历史非法")
	var history := []
	var previous_closing = null
	for index in range(value["history"].size()):
		var row = value["history"][index]
		if not Scalars.exact(row, ["day", "opening", "inflows", "outflows", "closing"]):
			return Scalars.fail("历史账字段非法")
		if not Scalars.whole(row["day"], day - value["history"].size() + index, day - value["history"].size() + index):
			return Scalars.fail("历史账日期不连续")
		# The earliest archived day opens unconstrained; each later day must continue
		# exactly from its predecessor's closing stock.
		if previous_closing != null and row["opening"] != previous_closing:
			return Scalars.fail("上日结存与下日期初不连续")
		var row_opening := _normalize_opening(row["opening"], items)
		if not row_opening["ok"]:
			return row_opening
		var row_in := _normalize_flows(row["inflows"], items)
		if not row_in["ok"]:
			return row_in
		var row_out := _normalize_flows(row["outflows"], items)
		if not row_out["ok"]:
			return row_out
		var row_balance := _balance(int(row["day"]), row_opening["opening"], row_in["flows"], row_out["flows"])
		if not row_balance["ok"]:
			return Scalars.fail(String(row_balance["reason"]))
		var row_closing := _normalize_opening(row["closing"], items)
		if not row_closing["ok"]:
			return row_closing
		if row_closing["opening"] != row_balance["closing"]:
			return Scalars.fail("历史账结存与收支不符")
		previous_closing = row["closing"]
		history.append({"day": int(row["day"]), "opening": row_opening["opening"],
			"inflows": row_in["flows"], "outflows": row_out["flows"], "closing": row_balance["closing"].duplicate()})
	if not history.is_empty() and _normalize_opening(previous_closing, items)["opening"] != opening["opening"]:
		return Scalars.fail("历史账与当日期初不连续")
	if day > 0 and history.is_empty():
		return Scalars.fail("已过日档缺少资源账历史")
	return {"ok": true, "ledger": {"pending": {"day": int(pending["day"]), "opening": opening["opening"],
		"inflows": inflows["flows"], "outflows": outflows["flows"]}, "history": history}}
