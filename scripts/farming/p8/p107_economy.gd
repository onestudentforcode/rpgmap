extends RefCounted
## Global milestones and permanent, fixed physical-resource exchanges. Orders
## already retain their entire validated settlement history: use that authority,
## rather than reconstructing a second counter from the 15-day journal.
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")
var _owner: WeakRef
var world:
	get: return _owner.get_ref()
var config: Dictionary
var state := fresh()

static func fresh() -> Dictionary:
	return {"events": [], "exchanges": [], "next_seq": 1}

func _init(owner, settings: Dictionary) -> void:
	_owner = weakref(owner)
	config = settings.duplicate(true)

static func order_count(orders: Dictionary, through_day := -1) -> int:
	var count := 0
	for row in orders.get("settlements", []):
		if through_day < 0 or int(row["entry"]["day"]) <= through_day:
			count += 1
	for row in orders.get("entries", []):
		if row["status"] == "completed" and (through_day < 0 or int(row["day"]) <= through_day):
			count += 1
	return count

func deliveries() -> int:
	return order_count(world._orders)

func stage() -> int:
	return state["events"].size()

func stage_name() -> String:
	return String(config["stage_names"][stage()])

func block(kind: String, id: String) -> String:
	var required := int(config["gates"].get(kind, {}).get(id, 0))
	if stage() >= required:
		return ""
	return "需先完成阶段事件「%s」" % String(config["events"][required - 1]["name"])

func event_quote() -> Dictionary:
	if stage() >= config["events"].size():
		return {"ok": false, "reason": "当前阶段事件已全部完成", "inputs": {}}
	var event: Dictionary = config["events"][stage()]
	var out := {"ok": true, "id": event["id"], "name": event["name"],
		"inputs": event["inputs"].duplicate(), "orders": int(event["orders"]), "completed_orders": deliveries(), "reason": ""}
	if deliveries() < int(event["orders"]):
		out["ok"] = false
		out["reason"] = "累计成功供货%d/%d次" % [deliveries(), int(event["orders"])]
	for item in event["inputs"]:
		if world.inventory.count(item) < int(event["inputs"][item]):
			out["ok"] = false
			out["reason"] = "缺少交付材料：" + String(world._items[item]["name"])
	return out

func complete_event(event_id: String) -> Dictionary:
	var allowed: Dictionary = world._can_act(0)
	if not allowed["ok"]: return allowed
	var quote := event_quote()
	if not quote["ok"]: return world._error(String(quote["reason"]))
	if quote["id"] != event_id: return world._error("阶段事件已变化，请重新查看")
	for item in quote["inputs"]:
		world.inventory.remove(item, int(quote["inputs"][item]))
	world._record_flow({}, quote["inputs"], "阶段事件交付")
	var row := {"id": event_id, "seq": int(state["next_seq"]), "day": world.clock.total_days, "orders": deliveries()}
	state["events"].append(row)
	state["next_seq"] += 1
	world.record_operation({"kind": "economy", "stage": "event", "day": world.clock.total_days,
		"seq": row["seq"], "event": event_id, "orders": deliveries(), "inputs": quote["inputs"].duplicate(), "level": stage()})
	return world._finish(0, {"ok": true, "event": event_id, "level": stage()})

func offer(id: String) -> Dictionary:
	for row in config["offers"]:
		if row["id"] == id: return row
	return {}

func exchange_quote(id: String, batches = 1) -> Dictionary:
	var out := {"ok": false, "reason": "未知兑换条目", "give": {}, "receive": {}, "offer": id}
	var row := offer(id)
	if row.is_empty(): return out
	if not Scalars.whole(batches, 1, 1000000):
		out["reason"] = "兑换批量必须是1至1000000的整数"
		return out
	for item in row["give"]: out["give"][item] = int(row["give"][item]) * int(batches)
	for item in row["receive"]: out["receive"][item] = int(row["receive"][item]) * int(batches)
	out["batches"] = int(batches)
	if stage() < int(row["stage"]):
		out["reason"] = "需先完成阶段事件「%s」" % config["events"][int(row["stage"]) - 1]["name"]
		return out
	for item in out["give"]:
		if world.inventory.count(item) < int(out["give"][item]):
			out["reason"] = "交换材料不足：" + String(world._items[item]["name"])
			return out
	for item in out["receive"]:
		if not Scalars.whole(world.inventory.count(item) - int(out["give"].get(item, 0)) + int(out["receive"][item])):
			out["reason"] = "交换后库存越界"
			return out
	out["ok"] = true
	out["reason"] = ""
	return out

func exchange(id: String, batches = 1) -> Dictionary:
	var allowed: Dictionary = world._can_act(0)
	if not allowed["ok"]: return allowed
	var quote := exchange_quote(id, batches)
	if not quote["ok"]: return world._error(String(quote["reason"]))
	for item in quote["give"]: world.inventory.remove(item, int(quote["give"][item]))
	for item in quote["receive"]: world.inventory.add(item, int(quote["receive"][item]))
	world._record_flow(quote["receive"], quote["give"], "以物换物")
	var row := {"offer": id, "batches": int(batches), "day": world.clock.total_days, "seq": int(state["next_seq"])}
	state["exchanges"].append(row)
	state["next_seq"] += 1
	world.record_operation({"kind": "economy", "stage": "exchange", "day": world.clock.total_days,
		"seq": row["seq"], "offer": id, "batches": int(batches),
		"give": quote["give"].duplicate(), "receive": quote["receive"].duplicate(), "level": stage()})
	return world._finish(0, {"ok": true, "offer": id, "give": quote["give"], "receive": quote["receive"]})

func to_save() -> Dictionary:
	return state.duplicate(true)

func apply_save(value: Dictionary) -> void:
	state = value.duplicate(true)

static func normalize(value, snapshot: Dictionary, catalog) -> Dictionary:
	if not Scalars.exact(value, ["events", "exchanges", "next_seq"]) or not value["events"] is Array or not value["exchanges"] is Array:
		return Scalars.fail("经济阶段字段非法")
	var cfg: Dictionary = catalog.load_data()["p107"]
	if value["events"].size() > cfg["events"].size() or not Scalars.whole(value["next_seq"], 1):
		return Scalars.fail("经济阶段事件或序号非法")
	if int(value["next_seq"]) != value["events"].size() + value["exchanges"].size() + 1:
		return Scalars.fail("经济事务序号不连续")
	var rows := []
	for event in value["events"]:
		if not Scalars.exact(event, ["id", "seq", "day", "orders"]): return Scalars.fail("阶段事件凭证非法")
		var r: Dictionary = event.duplicate()
		r["type"] = "event"
		rows.append(r)
	for swap in value["exchanges"]:
		if not Scalars.exact(swap, ["offer", "batches", "day", "seq"]): return Scalars.fail("兑换凭证非法")
		var r: Dictionary = swap.duplicate()
		r["type"] = "exchange"
		rows.append(r)
	for row in rows:
		if not Scalars.whole(row["seq"], 1, int(value["next_seq"]) - 1) or not Scalars.whole(row["day"], 0, int(snapshot["clock"]["total_days"])):
			return Scalars.fail("经济事务日期或序号非法")
	rows.sort_custom(func(a, b): return a["seq"] < b["seq"])
	var level := 0
	var sequence := 1
	var prior_day := 0
	var offers := {}
	for row in cfg["offers"]: offers[row["id"]] = row
	for row in rows:
		if int(row["seq"]) != sequence or int(row["day"]) < prior_day: return Scalars.fail("经济事务重复或倒序")
		sequence += 1
		prior_day = int(row["day"])
		if row["type"] == "event":
			if level >= cfg["events"].size() or row["id"] != cfg["events"][level]["id"]:
				return Scalars.fail("阶段事件顺序非法")
			if not Scalars.whole(row["orders"], int(cfg["events"][level]["orders"]), order_count(snapshot["orders"], int(row["day"]))):
				return Scalars.fail("阶段供货次数无真实交付依据")
			level += 1
		else:
			if not offers.has(row["offer"]) or not Scalars.whole(row["batches"], 1, 1000000): return Scalars.fail("兑换条目或批量非法")
			if int(offers[row["offer"]]["stage"]) > level: return Scalars.fail("兑换发生于开放之前")
	for row in snapshot["world"]["research"]["completed"]:
		if int(cfg["gates"]["research"].get(row, 0)) > level: return Scalars.fail("已完成研究缺少阶段事件")
	for row in snapshot["world"]["research"]["projects"]:
		if int(cfg["gates"]["research"].get(row["id"], 0)) > level: return Scalars.fail("在研项目缺少阶段事件")
	for row in snapshot["world"]["facilities"]:
		if int(cfg["gates"]["facility"].get(row["facility_id"], 0)) > level: return Scalars.fail("已建设施缺少阶段事件")
	for row in snapshot["world"]["logistics"]["instances"]:
		if int(cfg["gates"]["gu"].get(row["definition_id"], 0)) > level: return Scalars.fail("已获蛊虫缺少阶段事件")
	if level < int(cfg["gates"]["capability"]["systems"]) and not snapshot["world"]["services"]["systems"].is_empty():
		return Scalars.fail("协同系统缺少阶段事件")
	# JSON numbers are floats on read. Return one canonical integer shape,
	# as the other snapshot sections do, so disk reload and candidate retry
	# preserve the exact runtime snapshot rather than only a valid shape.
	var canonical := fresh()
	canonical["next_seq"] = int(value["next_seq"])
	for row in rows:
		if row["type"] == "event":
			canonical["events"].append({"id": String(row["id"]), "seq": int(row["seq"]),
				"day": int(row["day"]), "orders": int(row["orders"])})
		else:
			canonical["exchanges"].append({"offer": String(row["offer"]), "batches": int(row["batches"]),
				"day": int(row["day"]), "seq": int(row["seq"])})
	return {"ok": true, "economy": canonical}
