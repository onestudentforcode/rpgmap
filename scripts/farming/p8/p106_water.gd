extends RefCounted
## P10.6 water module: fish fences on owned natural water, explicit water
## bodies whose members share ONE integer quality total, a per-cell source
## ledger so demolishing and rebuilding a fence never mints fresh water,
## previewed topology edits (expand / merge / split / release) that conserve
## the total, and the daily services: manual change (1 AP, once per body per
## day), shore change stations (one auto service per facility per day) and the
## day-end quality decay. Bodies never merge by adjacency and rooms reference
## their body explicitly; this module owns no animals, no gu and no recipes.
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")
const Grid := preload("res://scripts/farming/core/grid/land_grid.gd")

var _owner: WeakRef
var world:
	get: return _owner.get_ref()
var settings: Dictionary
var state := fresh()
## Completed settle day for receipts, mirroring the ranch convention.
var _settle_day := -1

func _init(owner, config: Dictionary) -> void:
	_owner = weakref(owner)
	settings = config.duplicate(true)

static func fresh() -> Dictionary:
	return {"next_body_uid": 1, "bodies": [], "fences": {}, "sources": {}, "links": {}}

func _error(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

# --- static queries -----------------------------------------------------------

func body(uid: int) -> Dictionary:
	for row in state["bodies"]:
		if int(row["uid"]) == uid:
			return row
	return {}

func body_of(cell: Vector2i) -> Dictionary:
	var uid := int(state["fences"].get(_key(cell), 0))
	return body(uid) if uid > 0 else {}

func area(body_row: Dictionary) -> int:
	return body_row["cells"].size()

func points_per_cell() -> int:
	return int(settings["quality"]["points_per_cell"])

## The interface shows one mixed 0..100 value for the whole body.
func quality(body_row: Dictionary) -> int:
	if body_row.is_empty():
		return 0
	return int(body_row["quality"]) / (area(body_row) * 100)

func quality_ok(body_row: Dictionary) -> bool:
	return not body_row.is_empty() and quality(body_row) >= int(settings["quality"]["pause_threshold"])

func change_station_id() -> String:
	return String(settings["facilities"]["change_station"])

## Link rows: {"body": int, "day": int} per change station, so several stations
## may serve one body while each facility still runs at most once a day.
func linked_body(station_uid: int) -> int:
	var row: Dictionary = state["links"].get("%d" % station_uid, {})
	return int(row.get("body", 0)) if not row.is_empty() else 0

static func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

static func _cell_of(text: String) -> Vector2i:
	var parts := text.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

## Water bodies use plain 4-neighbor connectivity over their member texts;
## diagonal contact never connects two bodies or two cells.
static func _connected(texts: Array) -> bool:
	if texts.is_empty():
		return false
	var members := {}
	for text in texts:
		members[String(text)] = true
	var seen := {String(texts[0]): true}
	var frontier := [String(texts[0])]
	while not frontier.is_empty():
		var cell := _cell_of(frontier.pop_back())
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var key := _key(cell + step)
			if not seen.has(key) and members.has(key):
				seen[key] = true
				frontier.append(key)
	return seen.size() == members.size()

# --- fence building -----------------------------------------------------------

## Shared validation for a fence batch. target_body 0 creates a new body.
func _fence_blockers(cells: Array, target_body: int) -> String:
	if cells.is_empty():
		return "至少选择一格水面"
	var unique := {}
	var target := body(target_body)
	if target_body != 0 and target.is_empty():
		return "目标水体不存在"
	var texts: Array = []
	for value in cells:
		var cell: Vector2i = value
		var key := _key(cell)
		if unique.has(key):
			return "铺设列表中有重复地格"
		unique[key] = true
		texts.append(key)
		if not world.grid.in_bounds(cell.x, cell.y) or not world.land.contains(cell):
			return "只能铺设已购地权内的水面"
		if world.grid.terrain_at(cell) != "water":
			return "鱼栅只能铺在原始水面上"
		if int(state["fences"].get(key, 0)) > 0:
			return "该水面已有鱼栅"
		if world.grid.state_at(cell) in [Grid.State.OCCUPIED, Grid.State.PLANTED]:
			return "水面已被设施或作物占用"
	var joined: Array = texts.duplicate()
	if not target.is_empty():
		for key in target["cells"]:
			joined.append(key)
	if not _connected(joined):
		return "水体必须保持四邻接连通"
	return ""

func quote_fence(cells: Array, target_body := 0) -> Dictionary:
	var stage_block: String = world.progress.block("capability", "fence")
	if not stage_block.is_empty(): return _error(stage_block)
	var blocked: String = _fence_blockers(cells, target_body)
	if not blocked.is_empty():
		return _error(blocked)
	var inputs := {}
	for item in settings["fence"]["inputs"]:
		inputs[String(item)] = int(settings["fence"]["inputs"][item]) * cells.size()
	return {"ok": true, "cash": int(settings["fence"]["cash"]) * cells.size(),
		"inputs": inputs, "ap": int(settings["fence"]["ap"]) * cells.size(), "body": target_body}

func build_fence(cells: Array, target_body := 0) -> Dictionary:
	var quote := quote_fence(cells, target_body)
	if not quote["ok"]:
		return quote
	var ap := int(quote["ap"])
	var checked: Dictionary = world._can_act(ap)
	if not checked["ok"]:
		return checked
	if world.primeval_stones < int(quote["cash"]):
		return _error("元石不足")
	for item in quote["inputs"]:
		if not world.inventory.has(String(item), int(quote["inputs"][item])):
			return _error("缺少铺设材料：" + String(world._items[String(item)]["name"]))
	var row := body(target_body)
	if row.is_empty():
		row = {"uid": int(state["next_body_uid"]), "name": "水体%d" % [int(state["next_body_uid"])],
			"cells": [], "quality": 0, "change_day": -1}
		state["next_body_uid"] = int(state["next_body_uid"]) + 1
		state["bodies"].append(row)
	var grants := {}
	var laid: Array = []
	for value in cells:
		var cell: Vector2i = value
		var key := _key(cell)
		# First-ever grant is the full cell quality; released cells take back
		# exactly what they banked, so destroy-and-rebuild never mints water.
		var grant := int(state["sources"].get(key, points_per_cell()))
		state["sources"].erase(key)
		row["quality"] = int(row["quality"]) + grant
		row["cells"].append(key)
		state["fences"][key] = int(row["uid"])
		grants[key] = grant
		laid.append(key)
	row["cells"].sort()
	world.primeval_stones -= int(quote["cash"])
	world._cash("construction_spend", int(quote["cash"]))
	for item in quote["inputs"]:
		world.inventory.remove(String(item), int(quote["inputs"][item]))
	world._record_flow({}, quote["inputs"], "铺设鱼栅")
	world.record_operation({"kind": "water", "stage": "fence", "day": world.clock.total_days,
		"body": int(row["uid"]), "cells": laid, "grants": grants,
		"quality_after": int(row["quality"]), "cash": int(quote["cash"])})
	world.changed.emit()
	return world._finish(ap, {"ok": true, "body": int(row["uid"]), "detail": "鱼栅铺设完成"})

# --- topology edits -----------------------------------------------------------

## Cells with ranch zones, standing facilities or planted crops can never be
## released: something would be left without a place.
func _release_blockers(body_row: Dictionary, texts: Array) -> String:
	var zone_cells := {}
	for zone in world.ranch.state["zones"]:
		for text in zone["cells"]:
			zone_cells[String(text)] = int(zone["uid"])
	for key in texts:
		if not body_row["cells"].has(key):
			return "所选格子不全在该水体内"
		if zone_cells.has(key):
			return "格子属于功能房间，先重划房间"
		if world.grid.state_at(_cell_of(key)) in [Grid.State.OCCUPIED, Grid.State.PLANTED]:
			return "格子上还有设施或作物"
	var rest: Array = []
	for key in body_row["cells"]:
		if not texts.has(key):
			rest.append(key)
	if not rest.is_empty() and not _connected(rest):
		return "解除后会割裂剩余水体"
	return ""

## Per-cell share of the current quality, greedy by stable order when the
## total cannot cover every cell's full share.
func _release_shares(body_row: Dictionary, texts: Array) -> Dictionary:
	var total := int(body_row["quality"])
	var share := total / area(body_row)
	var shares := {}
	for key in texts:
		var take := mini(share, total)
		shares[key] = take
		total -= take
	return shares

func release_fence(cells: Array) -> Dictionary:
	if cells.is_empty():
		return _error("至少选择一格鱼栅")
	var first_cell: Vector2i = cells[0]
	var first := body_of(first_cell)
	if first.is_empty():
		return _error("所选格子没有鱼栅")
	var body_uid := int(first["uid"])
	var texts: Array = []
	for value in cells:
		var cell: Vector2i = value
		var owner := body_of(cell)
		if owner.is_empty() or int(owner["uid"]) != body_uid:
			return _error("解除操作不能跨水体")
		texts.append(_key(cell))
	var blocked: String = _release_blockers(first, texts)
	if not blocked.is_empty():
		return _error(blocked)
	var checked: Dictionary = world._can_act(1)
	if not checked["ok"]:
		return checked
	var shares := _release_shares(first, texts)
	var moved := 0
	for key in texts:
		state["fences"].erase(key)
		first["cells"].erase(key)
		state["sources"][key] = int(shares[key])
		moved += int(shares[key])
	first["quality"] = int(first["quality"]) - moved
	var emptied: bool = first["cells"].is_empty()
	if emptied:
		state["bodies"].erase(first)
	world.record_operation({"kind": "water", "stage": "release", "day": world.clock.total_days,
		"body": body_uid, "cells": texts.duplicate(), "shares": shares,
		"quality_after": int(first.get("quality", 0)), "empty": emptied})
	world.changed.emit()
	return world._finish(1, {"ok": true, "detail": "鱼栅已解除，继承水质已存入来源账"})

func merge_bodies(a_uid: int, b_uid: int) -> Dictionary:
	var row_a := body(a_uid)
	var row_b := body(b_uid)
	if row_a.is_empty() or row_b.is_empty() or a_uid == b_uid:
		return _error("请选择两个不同的水体")
	var checked: Dictionary = world._can_act(1)
	if not checked["ok"]:
		return checked
	var unioned: Array = row_a["cells"].duplicate()
	for key in row_b["cells"]:
		unioned.append(key)
	if not _connected(unioned):
		return _error("两个水体不相邻，不能合并")
	var quality_before := int(row_a["quality"]) + int(row_b["quality"])
	for key in row_b["cells"]:
		state["fences"][key] = a_uid
	row_a["cells"] = unioned
	row_a["cells"].sort()
	row_a["quality"] = quality_before
	state["bodies"].erase(row_b)
	# Rooms of the absorbed body follow the survivor, or they would dangle.
	for zone in world.ranch.state["zones"]:
		if int(zone.get("body_uid", 0)) == b_uid:
			zone["body_uid"] = a_uid
			world.ranch._record("zone", "rebody", {"zone": int(zone["uid"]), "body": a_uid})
	world.record_operation({"kind": "water", "stage": "merge", "day": world.clock.total_days,
		"body": a_uid, "removed": b_uid, "cells": row_a["cells"].duplicate(),
		"quality": quality_before})
	world.changed.emit()
	return world._finish(1, {"ok": true, "detail": "水体已合并，总量守恒"})

## Splits the given cells into a new body. Zones fully inside the outgoing
## cells follow the new body; a straddling zone blocks the split.
func split_body(body_uid: int, cells: Array) -> Dictionary:
	var row := body(body_uid)
	if row.is_empty():
		return _error("水体不存在")
	var texts: Array = []
	for value in cells:
		var cell: Vector2i = value
		texts.append(_key(cell))
	if texts.is_empty() or texts.size() >= row["cells"].size():
		return _error("请选择水体的一部分进行拆分")
	for key in texts:
		if not row["cells"].has(key):
			return _error("所选格子不全在该水体内")
	# A standing footprint may move wholesale with its cells, but no facility
	# or crop may be cut across the line (§16.2.4: 固定占地不可切开).
	for uid in world.facilities:
		var facility_cells: Array = world.ranch.facility_footprint(world.facilities[uid])
		var inside := 0
		for cell in facility_cells:
			if texts.has(_key(cell)):
				inside += 1
		if inside > 0 and inside < facility_cells.size():
			return _error("设施占地跨越拆分线，先重新安置设施")
	# Water crops are 1x1 anchored: a crop cell simply moves with its body.
	var keep: Array = []
	for key in row["cells"]:
		if not texts.has(key):
			keep.append(key)
	if not _connected(texts) or not _connected(keep):
		return _error("拆分后两部分都必须保持四邻接连通")
	for zone in world.ranch.state["zones"]:
		if int(zone.get("body_uid", 0)) != body_uid:
			continue
		var inside := 0
		var outside := 0
		for text in zone["cells"]:
			if texts.has(String(text)):
				inside += 1
			else:
				outside += 1
		if inside > 0 and outside > 0:
			return _error("功能区跨越拆分线，先重划房间")
	var checked: Dictionary = world._can_act(1)
	if not checked["ok"]:
		return checked
	# Quality split: uniform per-cell share, integer remainder walks the stable
	# cell order, and the two children always sum to the parent total.
	var total := int(row["quality"])
	var count := area(row)
	var per_cell := total / count
	var remainder := total % count
	var out_quality := per_cell * texts.size()
	var keep_quality := per_cell * keep.size()
	var order: Array = row["cells"].duplicate()
	order.sort()
	for key in order:
		if remainder <= 0:
			break
		remainder -= 1
		if texts.has(key):
			out_quality += 1
		else:
			keep_quality += 1
	var new_row := {"uid": int(state["next_body_uid"]), "name": "水体%d" % [int(state["next_body_uid"])],
		"cells": texts.duplicate(), "quality": out_quality, "change_day": int(row["change_day"])}
	new_row["cells"].sort()
	state["next_body_uid"] = int(state["next_body_uid"]) + 1
	state["bodies"].append(new_row)
	row["cells"] = keep
	row["quality"] = keep_quality
	for key in texts:
		state["fences"][key] = int(new_row["uid"])
	for zone in world.ranch.state["zones"]:
		if int(zone.get("body_uid", 0)) != body_uid:
			continue
		var all_out := true
		for text in zone["cells"]:
			if not texts.has(String(text)):
				all_out = false
				break
		if all_out:
			zone["body_uid"] = int(new_row["uid"])
			world.ranch._record("zone", "rebody", {"zone": int(zone["uid"]), "body": int(new_row["uid"])})
	world.record_operation({"kind": "water", "stage": "split", "day": world.clock.total_days,
		"body": body_uid, "new_body": int(new_row["uid"]), "cells": texts.duplicate(),
		"quality_parent": keep_quality, "quality_child": out_quality})
	world.changed.emit()
	return world._finish(1, {"ok": true, "body": int(new_row["uid"]), "detail": "水体已拆分，总量守恒"})

# --- water services -----------------------------------------------------------

func _apply_change(body_row: Dictionary, station_uid: int, operator: String, day: int) -> Dictionary:
	var cells := mini(area(body_row), int(settings["change"]["max_cells"]))
	var gain := int(settings["change"]["gain"]) * 100 * cells
	var cap: int = area(body_row) * points_per_cell()
	var before := int(body_row["quality"])
	var after := mini(before + gain, cap)
	var wasted := before + gain - after
	for item in settings["change"]["inputs"]:
		world.inventory.remove(String(item), int(settings["change"]["inputs"][item]))
	world.inventory.add("wastewater", int(settings["change"]["wastewater"]))
	world._record_flow({"wastewater": int(settings["change"]["wastewater"])}, settings["change"]["inputs"], "换水")
	body_row["quality"] = after
	world.record_operation({"kind": "water", "stage": "change", "day": day, "body": int(body_row["uid"]),
		"operator": operator, "station": station_uid, "cells": cells, "gain": gain,
		"applied": after - before, "wasted": wasted, "quality_after": after,
		"inputs": settings["change"]["inputs"].duplicate()})
	return {"ok": true, "applied": after - before, "wasted": wasted}

func change_water(body_uid: int) -> Dictionary:
	var row := body(body_uid)
	if row.is_empty():
		return _error("水体不存在")
	var day: int = world.clock.total_days
	if int(row["change_day"]) == day:
		return _error("该水体今日已人工换水")
	var checked: Dictionary = world._can_act(int(settings["change"]["ap"]))
	if not checked["ok"]:
		return checked
	for item in settings["change"]["inputs"]:
		if not world.inventory.has(String(item), int(settings["change"]["inputs"][item])):
			return _error("缺少换水投料")
	var result := _apply_change(row, 0, "player", day)
	row["change_day"] = day
	world.changed.emit()
	return world._finish(int(settings["change"]["ap"]), result)

## A shore station explicitly linked to one body performs one free-AP service
## per day; it pauses silently when the real inputs run out.
func link_station(station_uid: int, body_uid: int) -> Dictionary:
	var facility: Dictionary = world.facilities.get(station_uid, {})
	if facility.is_empty() or String(facility["facility_id"]) != change_station_id():
		return _error("只有换水站可以关联水体")
	if body_uid == 0:
		if linked_body(station_uid) == 0:
			return _error("该换水站没有关联")
		var checked0: Dictionary = world._can_act(1)
		if not checked0["ok"]:
			return checked0
		state["links"].erase("%d" % station_uid)
		world.record_operation({"kind": "water", "stage": "unlink", "day": world.clock.total_days,
			"station": station_uid})
		world.changed.emit()
		return world._finish(1, {"ok": true, "detail": "换水站已解除关联"})
	var row := body(body_uid)
	if row.is_empty():
		return _error("目标水体不存在")
	var current := linked_body(station_uid)
	if current == body_uid:
		return _error("换水站已关联该水体")
	if current != 0:
		return _error("换水站已关联另一水体，请先解除")
	# The station must sit on the shore of its body: its footprint touches at
	# least one member cell along a side.
	var adjacent := false
	for cell in world.ranch.facility_footprint(facility):
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if int(state["fences"].get(_key(cell + step), 0)) == body_uid:
				adjacent = true
	if not adjacent:
		return _error("换水站必须紧邻目标水体")
	var checked: Dictionary = world._can_act(1)
	if not checked["ok"]:
		return checked
	state["links"]["%d" % station_uid] = {"body": body_uid, "day": -1}
	world.record_operation({"kind": "water", "stage": "link", "day": world.clock.total_days,
		"station": station_uid, "body": body_uid})
	world.changed.emit()
	return world._finish(1, {"ok": true, "detail": "换水站已关联水体"})

func auto_services(day: int) -> void:
	_settle_day = day
	var station_uids := []
	for key in state["links"]:
		station_uids.append(int(key))
	station_uids.sort()
	for uid in station_uids:
		var link: Dictionary = state["links"]["%d" % uid]
		var row := body(int(link["body"]))
		if row.is_empty() or not world.facilities.has(uid):
			state["links"].erase("%d" % uid)
			continue
		if int(link["day"]) == day:
			continue
		var enough := true
		for item in settings["change"]["inputs"]:
			if not world.inventory.has(String(item), int(settings["change"]["inputs"][item])):
				enough = false
		if not enough:
			world.record_operation({"kind": "water", "stage": "auto_wait", "day": day,
				"station": uid, "body": int(row["uid"])})
			continue
		link["day"] = day
		_apply_change(row, uid, "station", day)
	_settle_day = -1

# --- day settlement -----------------------------------------------------------

## Aquatic load in body space weights; the ranch roster is the only source.
func _body_load(body_uid: int) -> int:
	if world.ranch == null:
		return 0
	return world.ranch.water_load(body_uid)

func settle(day: int) -> void:
	_settle_day = day
	for row in state["bodies"]:
		var cells := area(row)
		var load := _body_load(int(row["uid"]))
		var decay := int(settings["quality"]["base_decay"]) + (int(settings["quality"]["load_factor"]) * load + cells - 1) / cells
		var before := int(row["quality"])
		var after := maxi(0, before - decay * cells * 100)
		row["quality"] = after
		world.record_operation({"kind": "water", "stage": "decay", "day": day, "body": int(row["uid"]),
			"area": cells, "load": load, "decay_points": decay * cells * 100,
			"before": before, "after": after})
	_settle_day = -1

# --- persistence --------------------------------------------------------------

func to_save() -> Dictionary:
	return state.duplicate(true)

func apply_save(value: Dictionary) -> void:
	state = value.duplicate(true)

func forget_facility(facility_uid: int) -> void:
	state["links"].erase("%d" % facility_uid)

## Codec validation: one authoritative shape, cross-checked fence maps and
## conservation bounds. Runtime-only rules (shore adjacency) live in the ops.
static func normalize(value, snapshot: Dictionary, catalog) -> Dictionary:
	if not Scalars.exact(value, fresh().keys()):
		return Scalars.fail("水域快照结构非法")
	var config: Dictionary = catalog.load_data()["p106"]
	var out := fresh()
	if not Scalars.whole(value["next_body_uid"], 1):
		return Scalars.fail("水体序号非法")
	out["next_body_uid"] = int(value["next_body_uid"])
	var day: int = int(snapshot["clock"]["total_days"])
	var body_ids := {}
	var fenced := {}
	for row in value["bodies"]:
		if not Scalars.exact(row, ["uid", "name", "cells", "quality", "change_day"]):
			return Scalars.fail("水体字段非法")
		if not Scalars.whole(row["uid"], 1, int(value["next_body_uid"]) - 1) or body_ids.has(int(row["uid"])):
			return Scalars.fail("水体序号非法")
		if not row["name"] is String or String(row["name"]).is_empty():
			return Scalars.fail("水体名称非法")
		if not row["cells"] is Array or row["cells"].is_empty():
			return Scalars.fail("水体成员非法")
		for text in row["cells"]:
			if not text is String or fenced.has(String(text)):
				return Scalars.fail("水体地格非法或重叠")
			fenced[String(text)] = int(row["uid"])
		if not _connected(row["cells"]):
			return Scalars.fail("水体不连通")
		var cap: int = row["cells"].size() * int(config["quality"]["points_per_cell"])
		if not Scalars.whole(row["quality"], 0, cap):
			return Scalars.fail("水质总量越界")
		if not Scalars.whole(row["change_day"], -1, day):
			return Scalars.fail("换水日期非法")
		body_ids[int(row["uid"])] = true
		out["bodies"].append({"uid": int(row["uid"]), "name": String(row["name"]),
			"cells": row["cells"].duplicate(), "quality": int(row["quality"]),
			"change_day": int(row["change_day"])})
	if not value["fences"] is Dictionary or not value["sources"] is Dictionary or not value["links"] is Dictionary:
		return Scalars.fail("水域账本非法")
	if value["fences"].size() != fenced.size():
		return Scalars.fail("鱼栅登记与水体成员不一致")
	for key in value["fences"]:
		if not fenced.has(String(key)) or int(value["fences"][key]) != int(fenced[String(key)]):
			return Scalars.fail("鱼栅归属非法")
		out["fences"][String(key)] = int(value["fences"][key])
	for key in value["sources"]:
		if fenced.has(String(key)) or not Scalars.whole(value["sources"][key], 0, int(config["quality"]["points_per_cell"])):
			return Scalars.fail("来源账非法")
		out["sources"][String(key)] = int(value["sources"][key])
	var station_id := String(config["facilities"]["change_station"])
	var facility_ids := {}
	for row in snapshot["world"]["facilities"]:
		facility_ids[int(row["uid"])] = String(row["facility_id"])
	for key in value["links"]:
		var link = value["links"][key]
		if not link is Dictionary or not Scalars.exact(link, ["body", "day"]):
			return Scalars.fail("换水站关联字段非法")
		if not facility_ids.has(int(key)) or String(facility_ids[int(key)]) != station_id:
			return Scalars.fail("换水站关联非法")
		if not body_ids.has(int(link["body"])) or not Scalars.whole(link["day"], -1, day):
			return Scalars.fail("换水站关联目标非法")
		out["links"]["%d" % int(key)] = {"body": int(link["body"]), "day": int(link["day"])}
	return {"ok": true, "water": out}
