extends RefCounted
## Schema 3 adds facilities/batches. Earlier V1 schemas gain empty new fields; never imports V0.
const Data := preload("res://scripts/farming/v1/v1_data.gd")
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")
const SCHEMA := 3

static func fresh() -> Dictionary:
	var config: Dictionary = Data.load_data()["config"]
	return {"product": "farm_demo_v1", "schema": SCHEMA,
		"clock": {"total_days": 0, "ap": int(config["ap_per_day"])},
		"economy": {"primeval_stones": int(config["initial_primeval_stones"])},
		"inventory": config["start_inventory"].duplicate(true), "world": Scalars.fresh()}

static func fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

static func normalize(value) -> Dictionary:
	if not value is Dictionary or value.get("product") != "farm_demo_v1" or not Scalars.whole(value.get("schema"), 1, SCHEMA):
		return fail("不支持的V1快照版本")
	for key in value:
		if key not in ["product", "schema", "clock", "economy", "inventory", "slot_id", "world"]:
			return fail("不支持的V1快照字段")
	if value.has("slot_id") and not Scalars.whole(value["slot_id"], 1, 3):
		return fail("槽位非法")
	for key in ["clock", "economy", "inventory"]:
		if not value.get(key) is Dictionary:
			return fail("快照字段损坏：" + key)
	var config: Dictionary = Data.load_data()["config"]
	var clock: Dictionary = value["clock"]
	var economy: Dictionary = value["economy"]
	if clock.size() != 2 or not Scalars.whole(clock.get("total_days")) or not Scalars.whole(clock.get("ap"), 1, int(config["ap_per_day"])):
		return fail("日期或行动点非法")
	if economy.size() != 1 or not Scalars.whole(economy.get("primeval_stones")):
		return fail("元石非法")
	var items := Data.resources(Data.load_data())
	var inventory := {}
	for iid in value["inventory"]:
		if not items.has(iid) or not Scalars.whole(value["inventory"][iid]):
			return fail("库存物品或数量非法")
		if value["inventory"][iid] > 0:
			inventory[iid] = int(value["inventory"][iid])
	if int(value["schema"]) == 1 and value.has("world"):
		return fail("V1基础版本不能包含世界字段")
	var world = value.get("world") if int(value["schema"]) >= 2 else Scalars.fresh(int(clock["total_days"]))
	if int(value["schema"]) == 2:
		if not Scalars.exact(world, ["map_id", "tilled", "environment", "crops", "next_uid", "sources"]):
			return fail("V1种植版本世界字段非法")
		world = world.duplicate(true)
		world["facilities"] = []
		world["next_facility_uid"] = 1
		world["next_batch_uid"] = 1
	var checked := Scalars.normalize(world, int(clock["total_days"]))
	if not checked["ok"]:
		return checked
	return {"ok": true, "snapshot": {"product": "farm_demo_v1", "schema": SCHEMA,
		"clock": {"total_days": int(clock["total_days"]), "ap": int(clock["ap"])},
		"economy": {"primeval_stones": int(economy["primeval_stones"])}, "inventory": inventory, "world": checked["world"]}}
