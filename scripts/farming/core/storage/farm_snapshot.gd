extends RefCounted
## Validates detached snapshots before any live world or slot is changed.
const Data := preload("res://scripts/farming/core/farm_data.gd")
const Economy := preload("res://scripts/farming/core/economy/farm_economy.gd")
const Tools := preload("res://scripts/farming/core/economy/farm_tools.gd")
const Records := preload("res://scripts/farming/core/economy/farm_records.gd")
const Inventory := preload("res://scripts/farming/core/inventory/farm_inventory.gd")

static func fresh() -> Dictionary:
	var config := Data.load_config()
	var inventory := Inventory.new()
	inventory.setup(config["start_inventory"])
	var economy := Economy.new()
	economy.setup(config, Data.items_by_id(Data.load_items()), crop_defs(), inventory)
	return {"schema": 3, "clock": {"total_days": 0, "ap": int(config["time"]["ap_per_day"])},
		"grid": {"schema": 1, "cells": [], "holders": {}, "media": []},
		"crops": {"next_uid": 1, "crops": []}, "inventory": inventory.to_save(), "economy": economy.to_save()}

static func crop_defs() -> Dictionary:
	var out := {}
	for crop in Data.load_crops()["crops"]:
		out[crop["crop_id"]] = crop
	return out

static func whole(value, minimum: int = 0, maximum: int = 9000000000000) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == floor(float(value)) and value >= minimum and value <= maximum

static func pair(value, minimum: int = 0) -> bool:
	return value is Array and value.size() == 2 and whole(value[0], minimum) and whole(value[1], minimum)

static func fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

static func normalize(value) -> Dictionary:
	if not value is Dictionary or not whole(value.get("schema"), 2, 3):
		return fail("不支持的农场存档版本")
	for key in ["clock", "grid", "crops", "inventory"]:
		if not value.get(key) is Dictionary:
			return fail("缺少或损坏的快照字段：" + key)
	var out: Dictionary = value.duplicate(true)
	var config := Data.load_config()
	var items := Data.items_by_id(Data.load_items())
	var crops := crop_defs()
	var clock: Dictionary = out["clock"]
	if not whole(clock.get("total_days")) or not whole(clock.get("ap"), 1, int(config["time"]["ap_per_day"])):
		return fail("日期或行动点非法")
	out["clock"] = {"total_days": int(clock["total_days"]), "ap": int(clock["ap"])}
	var inventory := {}
	for iid in out["inventory"]:
		if not items.has(iid) or not whole(out["inventory"][iid]):
			return fail("库存物品或数量非法")
		if out["inventory"][iid] > 0:
			inventory[iid] = int(out["inventory"][iid])
	out["inventory"] = inventory
	var grid_check := _grid(out["grid"], config)
	if not grid_check["ok"]:
		return grid_check
	out["grid"] = grid_check["data"]
	var crop_check := _crops(out["crops"], crops, grid_check)
	if not crop_check["ok"]:
		return crop_check
	out["crops"] = crop_check["data"]
	var inv := Inventory.new()
	inv.setup(inventory)
	var economy := Economy.new()
	economy.setup(config, items, crops, inv)
	if int(out["schema"]) == 3:
		if not out.get("economy") is Dictionary or not whole(out["economy"].get("primeval_stones")) or not economy.apply_save(out["economy"]):
			return fail("钱包或蛊虫数据非法")
	out["schema"] = 3
	out["economy"] = economy.to_save()
	if out.has("tools") and not Tools.valid(out["tools"], crops):
		return fail("工具拥有或选择状态非法")
	if out.has("tools"):
		for kind in Tools.KINDS: out["tools"]["levels"][kind] = int(out["tools"]["levels"][kind])
	if out.has("records") and not Records.valid(out["records"], int(clock["total_days"]), crops, items):
		return fail("经营记录或回顾数据非法")
	if out.has("records"):
		out["records"] = Records.normalize(out["records"])
	return {"ok": true, "snapshot": out}

static func _grid(data: Dictionary, config: Dictionary) -> Dictionary:
	if data.get("schema") != 1 or not data.get("cells", []) is Array \
		or not data.get("holders", {}) is Dictionary or not data.get("media", []) is Array:
		return fail("土地快照结构非法")
	var map := Data.load_map("farm_01")
	var width := int(map["size"][0])
	var height := int(map["size"][1])
	var tillable := {}
	for terrain in Data.load_terrains()["terrains"]:
		tillable[terrain["id"]] = terrain["tillable"]
	var states := {}
	for y in range(height):
		for x in range(width):
			states[Vector2i(x,y)] = "WILD" if tillable[map["grid"][y][x]] else "UNAVAILABLE"
	var occupied := {}
	var cells := []
	var seen := {}
	for entry in data.get("cells", []):
		if not entry is Dictionary or not whole(entry.get("x"), 0, width-1) or not whole(entry.get("y"), 0, height-1):
			return fail("土地坐标非法")
		var cell := Vector2i(int(entry["x"]), int(entry["y"]))
		var state = entry.get("s")
		if seen.has(cell) or state not in ["WILD", "TILLED", "PLANTED", "OCCUPIED", "UNAVAILABLE"]:
			return fail("重复地格或非法状态")
		if (states[cell] == "UNAVAILABLE") != (state == "UNAVAILABLE"):
			return fail("不可操作地形状态不一致")
		seen[cell] = true
		states[cell] = state
		var normalized := {"x": cell.x, "y": cell.y, "s": state}
		if state in ["PLANTED", "OCCUPIED"]:
			var previous = entry.get("p", "TILLED" if state == "PLANTED" else "WILD")
			if previous not in ["WILD", "TILLED"] or (state == "PLANTED" and previous != "TILLED"):
				return fail("占地恢复状态非法")
			normalized["p"] = previous
			occupied[cell] = previous
		cells.append(normalized)
	var holders := {}
	var coverage := {}
	for holder in data.get("holders", {}):
		var meta = data["holders"][holder]
		if not holder is String or holder.is_empty() or not meta is Dictionary or not pair(meta.get("o")) or not pair(meta.get("f"), 1):
			return fail("占地标识非法")
		if meta["o"][0] >= width or meta["o"][1] >= height or meta["f"][0] > width or meta["f"][1] > height:
			return fail("占地越界")
		var origin := Vector2i(int(meta["o"][0]), int(meta["o"][1]))
		var size := Vector2i(int(meta["f"][0]), int(meta["f"][1]))
		if origin.x + size.x > width or origin.y + size.y > height:
			return fail("占地越界")
		for dy in range(size.y):
			for dx in range(size.x):
				var cell := origin + Vector2i(dx,dy)
				if coverage.has(cell) or not occupied.has(cell):
					return fail("占地重叠或地格状态不匹配")
				coverage[cell] = holder
		holders[holder] = {"o": [origin.x, origin.y], "f": [size.x, size.y]}
	if coverage.size() != occupied.size():
		return fail("存在无标识的占用地格")
	var media := []
	var media_at := {}
	var medium_ids := []
	for medium in config["planting_media"]:
		medium_ids.append(medium["id"])
	for entry in data.get("media", []):
		if not entry is Dictionary or not whole(entry.get("x"), 0, width-1) or not whole(entry.get("y"), 0, height-1) or entry.get("medium") not in medium_ids:
			return fail("介质坐标或类型非法")
		var cell := Vector2i(int(entry["x"]), int(entry["y"]))
		if media_at.has(cell) or (states[cell] != "TILLED" and occupied.get(cell, "") != "TILLED"):
			return fail("介质重复或地格未开垦")
		media_at[cell] = entry["medium"]
		media.append({"x": cell.x, "y": cell.y, "medium": entry["medium"]})
	return {"ok": true, "data": {"schema": 1, "cells": cells, "holders": holders, "media": media},
		"states": states, "media": media_at, "coverage": coverage}

static func _crops(data: Dictionary, defs: Dictionary, grid: Dictionary) -> Dictionary:
	if not whole(data.get("next_uid", 1), 1) or not data.get("crops", []) is Array:
		return fail("作物快照结构非法")
	var list := []
	var ids := {}
	var next_uid := int(data.get("next_uid", 1))
	for entry in data.get("crops", []):
		if not entry is Dictionary or not defs.has(entry.get("crop_id")) or not whole(entry.get("uid"), 1, next_uid-1) or not pair(entry.get("origin")):
			return fail("作物ID、定义或坐标非法")
		var def: Dictionary = defs[entry["crop_id"]]
		var uid := int(entry["uid"])
		if ids.has(uid) or entry.get("state") not in ["GROWING", "MATURE", "REGROWING", "EXHAUSTED"]:
			return fail("重复作物或非法阶段")
		ids[uid] = true
		var growth := 0
		for stage in def["growth_stages"]:
			growth += int(stage["days"])
		if not whole(entry.get("growth_days"), 0, growth) or not whole(entry.get("regrow_days"), 0, int(def["regrowth_duration"])) \
			or not whole(entry.get("harvest_count"), 0, int(def["max_harvests"])):
			return fail("作物生长或收获计数非法")
		var state: String = entry["state"]
		var count := int(entry["harvest_count"])
		if state == "GROWING":
			if entry["growth_days"] >= growth or count != 0 or entry["regrow_days"] != 0:
				return fail("生长期计数不一致")
		elif entry["growth_days"] != growth:
			return fail("成熟作物生长计数不一致")
		if state == "EXHAUSTED":
			if def["harvest_type"] != "regrow" or count != int(def["max_harvests"]):
				return fail("枯竭状态不一致")
		elif count >= int(def["max_harvests"]):
			return fail("收获上限不一致")
		if state == "REGROWING" and (def["harvest_type"] != "regrow" or count == 0 or entry["regrow_days"] >= int(def["regrowth_duration"])):
			return fail("再生状态不一致")
		var holder := "crop:%d" % uid
		var origin: Array = [int(entry["origin"][0]), int(entry["origin"][1])]
		var footprint := [int(def["footprint"][0]), int(def["footprint"][1])]
		if grid["data"]["holders"].get(holder, {}) != {"o": origin, "f": footprint}:
			return fail("作物与土地占格不一致")
		for dy in range(int(def["footprint"][1])):
			for dx in range(int(def["footprint"][0])):
				var cell := Vector2i(origin[0] + dx, origin[1] + dy)
				if grid["states"].get(cell) != "PLANTED" or grid["media"].get(cell, "soil") != def["planting_medium"]:
					return fail("作物土地状态或介质不一致")
		list.append({"uid": uid, "crop_id": entry["crop_id"], "origin": origin, "state": state,
			"growth_days": int(entry["growth_days"]), "regrow_days": int(entry["regrow_days"]), "harvest_count": count})
	for cell in grid["coverage"]:
		var holder: String = grid["coverage"][cell]
		if holder.begins_with("crop:"):
			var uid := holder.trim_prefix("crop:").to_int()
			if holder != "crop:%d" % uid or not ids.has(uid):
				return fail("占地引用缺失作物")
		elif grid["states"][cell] != "OCCUPIED":
			return fail("非作物占地状态非法")
	return {"ok": true, "data": {"next_uid": next_uid, "crops": list}}
