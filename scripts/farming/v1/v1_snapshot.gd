extends RefCounted
## Schema 6 adds bounded reports, first-45-day cash ledger and nonblocking guide.
const Data := preload("res://scripts/farming/v1/v1_data.gd")
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")
const Orders := preload("res://scripts/farming/v1/v1_orders.gd")
const Workforce := preload("res://scripts/farming/v1/v1_workforce.gd")
const Journal := preload("res://scripts/farming/v1/v1_journal.gd")
const SCHEMA := 6

static func fresh(catalog = Data, schema: int = SCHEMA) -> Dictionary:
	var config: Dictionary = catalog.load_data()["config"]
	return {"product": catalog.load_data()["product"], "schema": schema,
		"clock": {"total_days": 0, "ap": int(config["ap_per_day"])},
		"economy": {"primeval_stones": int(config["initial_primeval_stones"]), "sales_revenue": 0, "order_revenue": 0},
		"inventory": config["start_inventory"].duplicate(true), "world": Scalars.fresh(0, catalog), "orders": Orders.generate(0, 0, 0, catalog), "workforce": Workforce.fresh(),
		"journal": Journal.fresh(0,int(config["initial_primeval_stones"]))}

static func fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

static func normalize(value, catalog = Data, schema: int = SCHEMA, allow_legacy: bool = true, workforce_codec = Workforce) -> Dictionary:
	if not value is Dictionary or value.get("product") != catalog.load_data()["product"] or not Scalars.whole(value.get("schema"), 1 if allow_legacy else schema, schema):
		return fail("快照版本不匹配，请用对应版本重新开档")
	for key in value:
		if key not in ["product", "schema", "clock", "economy", "inventory", "slot_id", "world", "orders", "workforce", "journal"]:
			return fail("不支持的快照字段")
	if value.has("slot_id") and not Scalars.whole(value["slot_id"], 1, 3):
		return fail("槽位非法")
	for key in ["clock", "economy", "inventory"]:
		if not value.get(key) is Dictionary:
			return fail("快照字段损坏：" + key)
	var config: Dictionary = catalog.load_data()["config"]
	var clock: Dictionary = value["clock"]
	var economy: Dictionary = value["economy"]
	if clock.size() != 2 or not Scalars.whole(clock.get("total_days")) or not Scalars.whole(clock.get("ap"), 1, int(config["ap_per_day"])):
		return fail("日期或行动点非法")
	var old_schema := int(value["schema"]) < 4
	if int(value["schema"]) < 5 and value.has("workforce"):
		return fail("旧V1版本不能包含雇工字段")
	if int(value["schema"]) < 6 and value.has("journal"):
		return fail("旧V1版本不能包含经营记录")
	if old_schema and (not Scalars.exact(economy, ["primeval_stones"]) or value.has("orders")):
		return fail("旧V1版本不能包含订单或收入字段")
	if old_schema:
		economy = economy.duplicate(true)
		economy["sales_revenue"] = 0
		economy["order_revenue"] = 0
	if not Scalars.exact(economy, ["primeval_stones", "sales_revenue", "order_revenue"]) or not Scalars.whole(economy.get("primeval_stones")) or not Scalars.whole(economy.get("sales_revenue")) or not Scalars.whole(economy.get("order_revenue")):
		return fail("元石非法")
	var revenue := int(economy["sales_revenue"]) + int(economy["order_revenue"])
	if not Scalars.whole(revenue):
		return fail("累计收入越界")
	var orders_checked := Orders.normalize(Orders.generate(int(clock["total_days"]), 0, 0, catalog) if old_schema else value.get("orders"), int(clock["total_days"]), revenue, int(economy["order_revenue"]), catalog)
	if not orders_checked["ok"]:
		return orders_checked
	var items = catalog.resources(catalog.load_data())
	var inventory := {}
	for iid in value["inventory"]:
		if not items.has(iid) or not Scalars.whole(value["inventory"][iid]):
			return fail("库存物品或数量非法")
		if value["inventory"][iid] > 0:
			inventory[iid] = int(value["inventory"][iid])
	if int(value["schema"]) == 1 and value.has("world"):
		return fail("V1基础版本不能包含世界字段")
	var world = value.get("world") if int(value["schema"]) >= 2 else Scalars.fresh(int(clock["total_days"]), catalog)
	if int(value["schema"]) == 2:
		if not Scalars.exact(world, ["map_id", "tilled", "environment", "crops", "next_uid", "sources"]):
			return fail("V1种植版本世界字段非法")
		world = world.duplicate(true)
		world["facilities"] = []
		world["next_facility_uid"] = 1
		world["next_batch_uid"] = 1
	var checked := Scalars.normalize(world, int(clock["total_days"]), catalog)
	if not checked["ok"]:
		return checked
	var workforce_checked := workforce_codec.normalize(Workforce.fresh(int(clock["total_days"])) if int(value["schema"]) < 5 else value.get("workforce"),int(clock["total_days"]), catalog)
	if not workforce_checked["ok"]:
		return workforce_checked
	var journal_checked := Journal.normalize(Journal.fresh(int(clock["total_days"]),int(economy["primeval_stones"])) if int(value["schema"]) < 6 else value.get("journal"),int(clock["total_days"]), catalog)
	if not journal_checked["ok"]: return journal_checked
	return {"ok": true, "snapshot": {"product": catalog.load_data()["product"], "schema": schema,
		"clock": {"total_days": int(clock["total_days"]), "ap": int(clock["ap"])},
		"economy": {"primeval_stones": int(economy["primeval_stones"]), "sales_revenue": int(economy["sales_revenue"]), "order_revenue": int(economy["order_revenue"])},
		"inventory": inventory, "world": checked["world"], "orders": orders_checked["orders"], "workforce": workforce_checked["workforce"], "journal":journal_checked["journal"]}}
