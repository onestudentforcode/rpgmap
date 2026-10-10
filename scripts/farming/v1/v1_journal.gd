extends RefCounted
## Actual cash ledger and bounded day reports. First 45 days freeze independently of later play.
const Data := preload("res://scripts/farming/v1/v1_data.gd")
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")
const COUNTS := ["plantings", "harvests", "produce", "collected", "batches_started", "batches_completed", "processed", "deliveries", "delivered_items", "buildings", "work_actions", "matured", "cleared", "fieldwork"]
const CASH := ["sales_revenue", "order_revenue", "purchase_spend", "construction_spend", "labour_spend"]
const GUIDE := ["seed", "designation", "plant", "processing", "order"]

static func bucket() -> Dictionary:
	var out := {}
	for key in COUNTS: out[key] = {}
	for key in CASH: out[key] = 0
	return out

static func fresh(day: int = 0, cash: int = 60) -> Dictionary:
	return {"start_day": day, "start_cash": cash, "frozen": day >= 45,
		"terms": [bucket(),bucket(),bucket()], "pending": bucket(), "history": [],
		"end_cash": cash if day >= 45 else 0, "end_inventory": {},
		"guide": {"dismissed": false,"seen": []}}

static func add_count(state: Dictionary, key: String, ident: String, quantity: int = 1) -> void:
	state["pending"][key][ident] = int(state["pending"][key].get(ident,0))+quantity

static func add_cash(state: Dictionary, key: String, amount: int) -> void:
	state["pending"][key] = int(state["pending"][key])+amount

static func observe(state: Dictionary, step: String) -> void:
	if step not in state["guide"]["seen"]: state["guide"]["seen"].append(step)

static func merge(target: Dictionary, source: Dictionary) -> void:
	for key in COUNTS:
		for ident in source[key]: target[key][ident] = int(target[key].get(ident,0))+int(source[key][ident])
	for key in CASH: target[key] = int(target[key])+int(source[key])

static func totals(state: Dictionary) -> Dictionary:
	var out := bucket()
	for term in state["terms"]: merge(out,term)
	return out

static func income(row: Dictionary) -> int:
	return int(row["sales_revenue"])+int(row["order_revenue"])

static func expense(row: Dictionary) -> int:
	return int(row["purchase_spend"])+int(row["construction_spend"])+int(row["labour_spend"])

static func settle(state: Dictionary, day: int, cash: int, inventory: Dictionary, workers: Array) -> void:
	var warnings := []
	for worker in workers:
		if worker["reason"] != "今日资源点配额不足" and ("缺" in worker["reason"] or "不足" in worker["reason"] or "未分配" in worker["reason"]):
			warnings.append({"name": worker["name"],"reason": worker["reason"]})
	state["history"].append({"day": day,"totals": state["pending"].duplicate(true),"warnings": warnings})
	while state["history"].size() > 15: state["history"].pop_front()
	if not state["frozen"] and day <= 45:
		merge(state["terms"][int((day-1)/15)],state["pending"])
		if day == 45:
			state["frozen"] = true
			state["end_cash"] = cash
			state["end_inventory"] = inventory.duplicate(true)
	state["pending"] = bucket()

static func _normalize_bucket(value) -> Dictionary:
	if not Scalars.exact(value,COUNTS+CASH): return Scalars.fail("经营统计字段非法")
	var crops := Data.definitions("crops")
	var recipes := Data.definitions("recipes")
	var items := Data.resources(Data.load_data())
	var facilities := Data.definitions("facilities")
	var allowed := {"plantings":crops,"harvests":crops,"matured":crops,"cleared":crops,
		"produce":items,"collected":items,"processed":items,"delivered_items":items,
		"batches_started":recipes,"batches_completed":recipes,"buildings":facilities,
		"deliveries":{"wood":true,"fire":true,"earth":true,"water":true,"gold":true},
		"fieldwork":{"till":true,"irrigate":true,"fertilize":true},
		"work_actions":{"source":true,"harvest":true,"till":true,"plant":true,"irrigate":true,"fertilize":true,"fell":true,"clear":true}}
	var out := bucket()
	for key in COUNTS:
		if not value[key] is Dictionary: return Scalars.fail("经营计数非法")
		for ident in value[key]:
			if not allowed[key].has(ident) or not Scalars.whole(value[key][ident],1): return Scalars.fail("经营计数物品或数量非法")
			out[key][ident] = int(value[key][ident])
	for key in CASH:
		if not Scalars.whole(value[key]): return Scalars.fail("经营金额非法")
		out[key] = int(value[key])
	if not Scalars.whole(income(out)) or not Scalars.whole(expense(out)): return Scalars.fail("经营合计越界")
	return {"ok":true,"bucket":out}

static func normalize(value, day: int) -> Dictionary:
	if not Scalars.exact(value,fresh().keys()) or not Scalars.whole(value["start_day"],0,day) or not Scalars.whole(value["start_cash"]) or not value["frozen"] is bool or value["frozen"] != (day >= 45) or not value["terms"] is Array or value["terms"].size() != 3 or not value["history"] is Array or value["history"].size() > mini(15,day-int(value["start_day"])):
		return Scalars.fail("经营记录日期或结构非法")
	var out := fresh(int(value["start_day"]),int(value["start_cash"]))
	out["frozen"] = value["frozen"]
	for index in range(3):
		var checked := _normalize_bucket(value["terms"][index])
		if not checked["ok"]: return checked
		if (index*15 >= day or (index+1)*15 <= int(value["start_day"])) and checked["bucket"] != bucket(): return Scalars.fail("未经历时节不能有统计")
		out["terms"][index] = checked["bucket"]
	var pending := _normalize_bucket(value["pending"])
	if not pending["ok"]: return pending
	out["pending"] = pending["bucket"]
	for index in range(value["history"].size()):
		var row = value["history"][index]
		if not Scalars.exact(row,["day","totals","warnings"]) or not Scalars.whole(row["day"],day-value["history"].size()+index+1,day-value["history"].size()+index+1) or not row["warnings"] is Array or row["warnings"].size() > 2: return Scalars.fail("日报日期或告警非法")
		var checked := _normalize_bucket(row["totals"])
		if not checked["ok"]: return checked
		var warnings := []
		for warning in row["warnings"]:
			if not Scalars.exact(warning,["name","reason"]) or not warning["name"] is String or warning["name"].is_empty() or warning["name"].length() > 24 or not warning["reason"] is String or warning["reason"].is_empty() or warning["reason"].length() > 200: return Scalars.fail("日报告警内容非法")
			warnings.append(warning.duplicate())
		out["history"].append({"day":int(row["day"]),"totals":checked["bucket"],"warnings":warnings})
	if not Scalars.whole(value["end_cash"]) or not value["end_inventory"] is Dictionary: return Scalars.fail("回顾期末库存非法")
	var items := Data.resources(Data.load_data())
	for ident in value["end_inventory"]:
		if not items.has(ident) or not Scalars.whole(value["end_inventory"][ident],1): return Scalars.fail("回顾期末库存物品非法")
		out["end_inventory"][ident] = int(value["end_inventory"][ident])
	out["end_cash"] = int(value["end_cash"])
	var total := totals(out)
	if not Scalars.whole(income(total)) or not Scalars.whole(expense(total)): return Scalars.fail("回顾累计金额越界")
	if out["frozen"]:
		if int(out["end_cash"]) != int(out["start_cash"])+income(total)-expense(total): return Scalars.fail("回顾现金变化与账目不符")
	elif out["end_cash"] != 0 or not out["end_inventory"].is_empty(): return Scalars.fail("未结束回顾不能有期末快照")
	var guide = value["guide"]
	if not Scalars.exact(guide,["dismissed","seen"]) or not guide["dismissed"] is bool or not guide["seen"] is Array or guide["seen"].size() > GUIDE.size(): return Scalars.fail("操作引导非法")
	var seen := []
	for step in guide["seen"]:
		if step not in GUIDE or step in seen: return Scalars.fail("操作引导步骤非法")
		seen.append(step)
	out["guide"] = {"dismissed":guide["dismissed"],"seen":seen}
	return {"ok":true,"journal":out}
