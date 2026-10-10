extends RefCounted
## Detached world validation. Crops and facilities share one derived occupancy map.
const Data := preload("res://scripts/farming/v1/v1_data.gd")

static func whole(value, minimum: int = 0, maximum: int = 9000000000000) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum

static func exact(value, keys: Array) -> bool:
	if not value is Dictionary or value.size() != keys.size():
		return false
	for key in keys:
		if not value.has(key):
			return false
	return true

static func fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

static func fresh(day: int = 0) -> Dictionary:
	var map := Data.load_map()
	var config: Dictionary = Data.load_data()["config"]
	var environment := []
	for _index in range(int(map["size"][0]) * int(map["size"][1])):
		environment.append([int(config["environment"]["initial_water"]), int(config["environment"]["initial_fertility"])])
	var used := {}
	for ident in Data.definitions("sources"):
		used[ident] = 0
	return {"map_id": config["map_id"], "tilled": [], "environment": environment,
		"crops": [], "next_uid": 1, "sources": {"day": day, "used": used},
		"facilities": [], "next_facility_uid": 1, "next_batch_uid": 1}

static func coordinate(value, width: int, height: int) -> bool:
	return value is Array and value.size() == 2 and whole(value[0], 0, width-1) and whole(value[1], 0, height-1)

static func normalize(value, day: int) -> Dictionary:
	if not exact(value, ["map_id", "tilled", "environment", "crops", "next_uid", "sources", "facilities", "next_facility_uid", "next_batch_uid"]):
		return fail("世界快照字段损坏")
	var map := Data.load_map()
	var width := int(map["size"][0])
	var height := int(map["size"][1])
	if value["map_id"] != map["id"] or not whole(value["next_uid"], 1):
		return fail("地图或作物序号非法")
	var source_defs := Data.definitions("sources")
	var sources = value["sources"]
	if not exact(sources, ["day", "used"]) or not whole(sources["day"]) or sources["day"] != day or not exact(sources["used"], source_defs.keys()):
		return fail("资源点日期或额度字段非法")
	var used := {}
	var source_cells := {}
	for ident in source_defs:
		var definition: Dictionary = source_defs[ident]
		var count = sources["used"][ident]
		if not whole(count, 0, int(definition["daily_limit"])) or int(count) % int(definition["quantity"]) != 0:
			return fail("资源点额度非法")
		used[ident] = int(count)
		source_cells[Vector2i(int(definition["position"][0]), int(definition["position"][1]))] = true
	if not value["tilled"] is Array or value["tilled"].size() > width * height:
		return fail("耕地列表非法")
	var tilled := []
	var seen := {}
	var tillable := Data.tillable_map()
	for pair in value["tilled"]:
		if not coordinate(pair, width, height):
			return fail("耕地坐标非法")
		var cell := Vector2i(int(pair[0]), int(pair[1]))
		if seen.has(cell) or source_cells.has(cell) or not tillable.get(map["grid"][cell.y][cell.x], false):
			return fail("耕地重复或地形不可种植")
		seen[cell] = true
		tilled.append([cell.x, cell.y])
	if not value["environment"] is Array or value["environment"].size() != width * height:
		return fail("土地环境大小非法")
	var environment := []
	for pair in value["environment"]:
		if not pair is Array or pair.size() != 2 or not whole(pair[0], 0, 100) or not whole(pair[1], 0, 100):
			return fail("土地环境数值非法")
		environment.append([int(pair[0]), int(pair[1])])
	if not value["crops"] is Array or value["crops"].size() > width * height:
		return fail("作物列表非法")
	var crop_defs := Data.definitions("crops")
	var crops := []
	var occupied := {}
	var uids := {}
	for row in value["crops"]:
		if not exact(row, ["uid", "crop_id", "origin", "progress", "state", "harvest_count"]) or not whole(row["uid"], 1, int(value["next_uid"])-1) or uids.has(row["uid"]):
			return fail("作物序号或字段非法")
		if not row["crop_id"] is String or not crop_defs.has(row["crop_id"]) or not coordinate(row["origin"], width, height) or not whole(row["harvest_count"]):
			return fail("作物定义或坐标非法")
		var definition: Dictionary = crop_defs[row["crop_id"]]
		var repeated: bool = row["harvest_count"] > 0
		if repeated and definition["mode"] != "tap_or_fell":
			return fail("一次性作物不能重复采收")
		var target := int(definition["cycle_days"] if repeated else definition["days"]) * 100
		var expected_state := "regrowing" if repeated else "growing"
		if not whole(row["progress"], 0, target) or (row["state"] != "mature" and row["state"] != expected_state) or ((row["state"] == "mature") != (row["progress"] == target)):
			return fail("作物成熟进度或周期非法")
		var origin := Vector2i(int(row["origin"][0]), int(row["origin"][1]))
		for dy in range(int(definition["footprint"][1])):
			for dx in range(int(definition["footprint"][0])):
				var cell := origin + Vector2i(dx, dy)
				if not seen.has(cell) or occupied.has(cell):
					return fail("作物越界、重叠或未开垦")
				occupied[cell] = true
		uids[row["uid"]] = true
		crops.append({"uid": int(row["uid"]), "crop_id": row["crop_id"], "origin": [origin.x, origin.y],
			"progress": int(row["progress"]), "state": row["state"], "harvest_count": int(row["harvest_count"])})
	if not whole(value["next_facility_uid"], 1) or not whole(value["next_batch_uid"], 1) or not value["facilities"] is Array or value["facilities"].size() > width * height:
		return fail("设施或批次序号非法")
	var facility_defs := Data.definitions("facilities")
	var recipe_defs := Data.definitions("recipes")
	var facilities := []
	var facility_uids := {}
	var batch_uids := {}
	for row in value["facilities"]:
		if not exact(row, ["uid", "facility_id", "origin", "batch"]) or not whole(row["uid"], 1, int(value["next_facility_uid"])-1) or facility_uids.has(row["uid"]):
			return fail("设施字段或序号非法")
		if not row["facility_id"] is String or not facility_defs.has(row["facility_id"]) or not coordinate(row["origin"], width, height):
			return fail("设施定义或坐标非法")
		var definition: Dictionary = facility_defs[row["facility_id"]]
		var origin := Vector2i(int(row["origin"][0]), int(row["origin"][1]))
		for dy in range(int(definition["footprint"][1])):
			for dx in range(int(definition["footprint"][0])):
				var cell := origin + Vector2i(dx,dy)
				if cell.x >= width or cell.y >= height or occupied.has(cell) or source_cells.has(cell) or not tillable.get(map["grid"][cell.y][cell.x], false):
					return fail("设施越界、重叠或覆盖不可建设地形")
				occupied[cell] = true
		var batch = row["batch"]
		if not batch is Dictionary:
			return fail("加工批次字段损坏")
		var normalized_batch := {}
		if not batch.is_empty():
			if not exact(batch, ["batch_id", "recipe_id", "inputs", "outputs", "start_day", "finish_day", "status"]) or not whole(batch["batch_id"], 1, int(value["next_batch_uid"])-1) or batch_uids.has(batch["batch_id"]):
				return fail("加工批次字段或序号非法")
			if not batch["recipe_id"] is String or not recipe_defs.has(batch["recipe_id"]):
				return fail("未知加工配方")
			var recipe: Dictionary = recipe_defs[batch["recipe_id"]]
			if recipe["facility"] != row["facility_id"] or not whole(batch["start_day"], 0, day) or not whole(batch["finish_day"]) or batch["finish_day"] != batch["start_day"] + recipe["days"]:
				return fail("加工设施或完成日期非法")
			var expected_status := "ready" if batch["finish_day"] <= day else "processing"
			if batch["status"] != expected_status:
				return fail("加工状态与游戏日不一致")
			var inputs := _quantities(batch["inputs"], recipe["inputs"])
			var outputs := _quantities(batch["outputs"], recipe["outputs"])
			if not inputs["ok"] or not outputs["ok"]:
				return fail("加工批次投入或产物非法")
			normalized_batch = {"batch_id": int(batch["batch_id"]), "recipe_id": batch["recipe_id"], "inputs": inputs["data"], "outputs": outputs["data"],
				"start_day": int(batch["start_day"]), "finish_day": int(batch["finish_day"]), "status": expected_status}
			batch_uids[batch["batch_id"]] = true
		facility_uids[row["uid"]] = true
		facilities.append({"uid": int(row["uid"]), "facility_id": row["facility_id"], "origin": [origin.x, origin.y], "batch": normalized_batch})
	return {"ok": true, "world": {"map_id": map["id"], "tilled": tilled, "environment": environment,
		"crops": crops, "next_uid": int(value["next_uid"]), "sources": {"day": day, "used": used},
		"facilities": facilities, "next_facility_uid": int(value["next_facility_uid"]), "next_batch_uid": int(value["next_batch_uid"])}}

static func _quantities(value, expected: Dictionary) -> Dictionary:
	if not exact(value, expected.keys()):
		return fail("物品数量表非法")
	var out := {}
	for ident in expected:
		if not whole(value[ident], 1, 1000000) or value[ident] != expected[ident]:
			return fail("物品数量非法")
		out[ident] = int(value[ident])
	return {"ok": true, "data": out}
