extends RefCounted
## P10.3 terrestrial ranch: an independent animal roster, five floor zone types
## with shared space, bed-slot reservations, the eight-unit inner clock with
## whole-window maintenance, fixed work bans, day-opening fatigue, facility
## work posts and asexual breeding. The three species leave the per-day V2
## habitat path entirely; other species keep it.
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")

const SPECIES := ["steel_sheep", "rock_mole", "rock_belly_beast"]
const ZONE_TYPES := ["nursery", "enclosure", "work", "maintenance", "pasture"]
const BED_TYPES := {"small_bed": "small", "medium_bed": "medium", "large_bed": "large"}
const WORKYARD_ID := "rock_workyard"
const PEN_ID := "pen"
const DISPATCH_ID := "dispatch_station"
const TROUGH_ID := "feed_trough"
const CARE_ID := "care_table"
## Ranch facilities must stand on ordinary floor; beds count as usable space.
const FLOOR_FACILITIES := ["pen", WORKYARD_ID, DISPATCH_ID, TROUGH_ID, "small_bed", "medium_bed", "large_bed", CARE_ID]
const ANIMAL_KEYS := ["uid", "species_id", "stage", "growth", "mode", "zone_uid", "bed_uid", "bed_slot",
	"pending", "diet_id", "pattern", "priority", "fatigue", "ban_until", "qualified_until",
	"served_once", "natural", "breed", "death_streak", "account"]

var _owner: WeakRef
var world:
	get: return _owner.get_ref()
var settings: Dictionary
var state := fresh()
## During day settlement the clock has already advanced; receipts must carry
## the completed day so audits line the flows up with the right ledger page.
var _settle_day := -1

func _init(owner, config: Dictionary) -> void:
	_owner = weakref(owner)
	settings = config.duplicate(true)

static func fresh() -> Dictionary:
	return {"next_zone_uid": 1, "next_animal_uid": 1, "next_window_uid": 1, "next_batch_uid": 1,
		"zones": [], "animals": [], "reservations": [], "workyards": {}, "births": [],
		"day": {"day": -1, "accounts": {}}}

func _error(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

# --- static queries -----------------------------------------------------------

func species_config(species_id: String) -> Dictionary:
	return settings["species"].get(species_id, {})

func animal(uid: int) -> Dictionary:
	for row in state["animals"]:
		if int(row["uid"]) == uid:
			return row
	return {}

func zone(uid: int) -> Dictionary:
	for row in state["zones"]:
		if int(row["uid"]) == uid:
			return row
	return {}

func animals_in_zone(zone_uid: int, modes: Array = []) -> Array:
	var out := []
	for row in state["animals"]:
		if int(row["zone_uid"]) != zone_uid:
			continue
		if modes.is_empty() or modes.has(String(row["mode"])):
			out.append(row)
	return out

func facility_footprint(row: Dictionary) -> Array:
	var origin := Vector2i(int(row["origin"][0]), int(row["origin"][1]))
	var shape: Array = world.facility_defs[String(row["facility_id"])]["footprint"]
	var cells := []
	for dy in range(int(shape[1])):
		for dx in range(int(shape[0])):
			cells.append(origin + Vector2i(dx, dy))
	return cells

func bed_capacity(facility_id: String) -> int:
	return int(settings["bed_facilities"].get(facility_id, {}).get("slots", 0))

func bed_type_of(facility_id: String) -> String:
	return String(settings["bed_facilities"].get(facility_id, {}).get("type", ""))

func is_bed(facility_id: String) -> bool:
	return settings["bed_facilities"].has(facility_id)

## Full-time bed slots held by nursery, enclosure and waiting animals.
func _fulltime_slots() -> Dictionary:
	var taken := {}
	for row in state["animals"]:
		if int(row["bed_uid"]) > 0 and String(row["mode"]) != "work":
			taken["%d:%d" % [int(row["bed_uid"]), int(row["bed_slot"])]] = int(row["uid"])
	return taken

func free_bed_slots(zone_row: Dictionary, bed_type: String) -> Array:
	var taken := _fulltime_slots()
	var out := []
	for facility in _facilities_in_zone(zone_row):
		var fid := String(facility["facility_id"])
		if bed_type_of(fid) != bed_type:
			continue
		for slot in range(bed_capacity(fid)):
			if not taken.has("%d:%d" % [int(facility["uid"]), slot]):
				out.append({"uid": int(facility["uid"]), "slot": slot})
	out.sort_custom(func(a, b):
		if int(a["uid"]) != int(b["uid"]):
			return int(a["uid"]) < int(b["uid"])
		return int(a["slot"]) < int(b["slot"]))
	return out

## Facilities whose whole footprint lies inside the zone cells.
func _facilities_in_zone(zone_row: Dictionary) -> Array:
	var cells := {}
	for text in zone_row["cells"]:
		cells[String(text)] = true
	var out := []
	for uid in world.facilities:
		var inside := true
		for cell in facility_footprint(world.facilities[uid]):
			if not cells.has("%d,%d" % [cell.x, cell.y]):
				inside = false
				break
		if inside:
			out.append(world.facilities[uid])
	out.sort_custom(func(a, b): return int(a["uid"]) < int(b["uid"]))
	return out

## Beds never subtract space; every other facility footprint does.
func available_space(zone_row: Dictionary) -> int:
	var blocked := {}
	for uid in world.facilities:
		if is_bed(String(world.facilities[uid]["facility_id"])):
			continue
		for cell in facility_footprint(world.facilities[uid]):
			blocked["%d,%d" % [cell.x, cell.y]] = true
	var space := 0
	for text in zone_row["cells"]:
		if not blocked.has(String(text)):
			space += 1
	return space

func structure_missing(zone_row: Dictionary) -> Array:
	var required: Array = settings["zones"][zone_row["type"]]["structures"]
	var present := {}
	for facility in _facilities_in_zone(zone_row):
		var fid := String(facility["facility_id"])
		if is_bed(fid):
			present["bed"] = true
		present[fid] = true
	var missing := []
	for key in required:
		if not present.has(key):
			missing.append(key)
	return missing

func zone_structural(zone_row: Dictionary) -> bool:
	return structure_missing(zone_row).is_empty()

func pattern_of(row: Dictionary) -> Array:
	if String(row["mode"]) != "work":
		return settings["fixed_pattern"]
	return settings["patterns"].get(String(row["pattern"]), settings["patterns"]["standard"])

func fatigue_tier(value: int) -> Dictionary:
	for tier in settings["fatigue"]["tiers"]:
		if value <= int(tier["max"]):
			return tier
	return settings["fatigue"]["tiers"][-1]

func _ordered_animals() -> Array:
	var rows: Array = state["animals"].duplicate()
	rows.sort_custom(func(a, b):
		if int(a["priority"]) != int(b["priority"]):
			return int(a["priority"]) < int(b["priority"])
		return int(a["uid"]) < int(b["uid"]))
	return rows

# --- zone editing (0 AP) ------------------------------------------------------

static func _cell_of(text: String) -> Vector2i:
	var parts := text.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

static func _connected(cells: Array) -> bool:
	if cells.is_empty():
		return false
	var set := {}
	for text in cells:
		set[String(text)] = true
	var seen := {String(cells[0]): true}
	var todo := [String(cells[0])]
	while not todo.is_empty():
		var cell := _cell_of(String(todo.pop_front()))
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var key := "%d,%d" % [cell.x + step.x, cell.y + step.y]
			if set.has(key) and not seen.has(key):
				seen[key] = true
				todo.append(key)
	return seen.size() == set.size()

## Numeric-tolerant item-map equality: parsed JSON stores floats, live state ints.
static func _same_items(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a:
		if not b.has(key) or int(a[key]) != int(b[key]):
			return false
	return true

## Rebuilds one animal row with int casts: JSON round-trips turn integers
## into floats and the applied state must stay integer-clean.
static func _intified_animal(row: Dictionary) -> Dictionary:
	var pending := {}
	for key in row["pending"]:
		var value = row["pending"][key]
		pending[String(key)] = int(value) if String(key) in ["zone_uid", "bed_uid", "bed_slot"] else String(value)
	var account: Dictionary = row["account"]
	return {"uid": int(row["uid"]), "species_id": String(row["species_id"]), "stage": String(row["stage"]),
		"growth": int(row["growth"]), "mode": String(row["mode"]), "zone_uid": int(row["zone_uid"]),
		"bed_uid": int(row["bed_uid"]), "bed_slot": int(row["bed_slot"]), "pending": pending,
		"diet_id": String(row["diet_id"]), "pattern": String(row["pattern"]), "priority": int(row["priority"]),
		"fatigue": int(row["fatigue"]), "ban_until": int(row["ban_until"]), "qualified_until": int(row["qualified_until"]),
		"served_once": bool(row["served_once"]),
		"natural": {"round": int(row["natural"]["round"]), "units": int(row["natural"]["units"]),
			"pending": bool(row["natural"]["pending"]), "paid": bool(row["natural"]["paid"])},
		"breed": {"round": int(row["breed"]["round"]), "units": int(row["breed"]["units"]), "pending": bool(row["breed"]["pending"])},
		"death_streak": int(row["death_streak"]),
		"account": {"w": int(account["w"]), "r": int(account["r"]), "fails": int(account["fails"])}}

func _zone_cells_free(cells: Array, ignore_zone := -1) -> String:
	for text in cells:
		var cell := _cell_of(String(text))
		if not world.grid.in_bounds(cell.x, cell.y):
			return "地格越界"
		if not world.land.contains(cell):
			return "地格不在已购地块内"
		if world.rooms.floor_kind(cell) != "ordinary":
			return "功能区只能铺设在普通地板上"
		for other in state["zones"]:
			if int(other["uid"]) == ignore_zone:
				continue
			if other["cells"].has(String(text)):
				return "地格已属于其他功能区"
	return ""

func preview_zone(type_id: String, cells: Array) -> Dictionary:
	if not ZONE_TYPES.has(type_id):
		return _error("未知功能区类型")
	if cells.is_empty():
		return _error("没有选择地格")
	var problem := _zone_cells_free(cells)
	if not problem.is_empty():
		return _error(problem)
	if not _connected(cells):
		return _error("功能区必须上下左右连通")
	var draft := {"type": type_id, "cells": cells}
	var space := available_space(draft)
	return {"ok": true, "space": space, "missing": structure_missing(draft),
		"min_space": int(settings["zones"][type_id]["min_space"]),
		"enough": space >= int(settings["zones"][type_id]["min_space"])}

static func _zone_label(type_id: String) -> String:
	return {"nursery": "育幼区", "enclosure": "圈养区", "work": "工作区",
		"maintenance": "维持放牧区", "pasture": "额外放牧区"}[type_id]

func create_zone(type_id: String, cells: Array, zone_name := "") -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	var preview := preview_zone(type_id, cells)
	if not preview["ok"]:
		return preview
	if not preview["enough"]:
		return _error("可用空间不足：需要%d，实际%d" % [preview["min_space"], preview["space"]])
	var uid := int(state["next_zone_uid"])
	state["next_zone_uid"] = uid + 1
	if zone_name.strip_edges().is_empty():
		zone_name = "%s%d" % [_zone_label(type_id), uid]
	state["zones"].append({"uid": uid, "type": type_id, "name": zone_name.strip_edges(),
		"cells": cells.duplicate(), "dispatch_uid": 0, "birth_target": 0})
	_record("zone", "create", {"zone": uid, "type": type_id, "cells": cells.duplicate(), "name": zone_name})
	world.changed.emit()
	return {"ok": true, "zone_uid": uid, "detail": "功能区已创建：%s" % zone_name}

func rename_zone(zone_uid: int, zone_name: String) -> Dictionary:
	var row := zone(zone_uid)
	if row.is_empty():
		return _error("未知功能区")
	if zone_name.strip_edges().is_empty():
		return _error("名称不能为空")
	row["name"] = zone_name.strip_edges()
	_record("zone", "rename", {"zone": zone_uid, "name": row["name"]})
	world.changed.emit()
	return {"ok": true}

func paint_cell(zone_uid: int, cell: Vector2i) -> Dictionary:
	var row := zone(zone_uid)
	if row.is_empty():
		return _error("未知功能区")
	var text := "%d,%d" % [cell.x, cell.y]
	if row["cells"].has(text):
		return _error("地格已在该功能区内")
	var problem := _zone_cells_free([text], zone_uid)
	if not problem.is_empty():
		return _error(problem)
	var grown: Array = row["cells"].duplicate()
	grown.append(text)
	if not _connected(grown):
		return _error("新地格必须与功能区连通")
	row["cells"].append(text)
	_record("zone", "paint", {"zone": zone_uid, "cell": [cell.x, cell.y]})
	world.changed.emit()
	return {"ok": true}

func _zone_usage(zone_row: Dictionary) -> int:
	var usage := 0
	for row in state["animals"]:
		if int(row["zone_uid"]) == int(zone_row["uid"]) and String(row["mode"]) != "work":
			usage += int(species_config(String(row["species_id"]))["space"])
	return usage

func erase_cell(zone_uid: int, cell: Vector2i) -> Dictionary:
	var row := zone(zone_uid)
	if row.is_empty():
		return _error("未知功能区")
	var text := "%d,%d" % [cell.x, cell.y]
	if not row["cells"].has(text):
		return _error("地格不在该功能区内")
	if row["cells"].size() <= 1:
		return _error("功能区至少保留一格")
	var shrunk: Array = row["cells"].duplicate()
	shrunk.erase(text)
	if not _connected(shrunk):
		return _error("拆除会切断功能区连通")
	var draft := {"type": String(row["type"]), "cells": shrunk}
	var space_after := available_space(draft)
	if space_after < _zone_usage(row) or space_after < int(settings["zones"][String(row["type"])]["min_space"]):
		return _error("拆除后空间不足，请先移走动物或缩小规模")
	row["cells"] = shrunk
	_record("zone", "erase_cell", {"zone": zone_uid, "cell": [cell.x, cell.y]})
	world.changed.emit()
	return {"ok": true}

func erase_zone(zone_uid: int) -> Dictionary:
	var row := zone(zone_uid)
	if row.is_empty():
		return _error("未知功能区")
	if not animals_in_zone(zone_uid).is_empty():
		return _error("功能区内还有动物，先安置到其他区域")
	for row_animal in state["animals"]:
		if int(row_animal["pending"].get("zone_uid", 0)) == zone_uid:
			return _error("有待生效安置指向该功能区")
	_record("zone", "erase", {"zone": zone_uid, "cells": row["cells"].duplicate()})
	state["zones"].erase(row)
	world.changed.emit()
	return {"ok": true}

# --- module submission (1 AP per batch) ---------------------------------------

## Staged changes apply at the next day boundary: shift patterns, mode/zone/bed
## assignments, maintenance and pasture links, enclosure birth targets.
func submit(changes: Dictionary) -> Dictionary:
	var patterns: Dictionary = changes.get("patterns", {})
	for uid in patterns:
		var row := animal(int(uid))
		if row.is_empty() or String(row["mode"]) != "work":
			return _error("只有役使动物可以更换班次")
		var pattern := String(patterns[uid])
		if not settings["patterns"].has(pattern):
			return _error("未知班次")
		if String(row["pattern"]) == pattern and String(row["pending"].get("pattern", "")) != pattern:
			if not row["pending"].has("pattern"):
				return _error("没有实际变更")
	var applied := false
	for uid in patterns:
		var row := animal(int(uid))
		var pattern := String(patterns[uid])
		if String(row["pattern"]) == pattern and String(row["pending"].get("pattern", pattern)) == pattern:
			continue
		var block := _pattern_gap(row, pattern)
		if not block.is_empty():
			return _error(block)
		row["pending"]["pattern"] = pattern
		applied = true
	var assign: Dictionary = changes.get("assign", {})
	for uid in assign:
		var row := animal(int(uid))
		if row.is_empty():
			return _error("未知动物")
		var staged := _stage_assignment(row, assign[uid])
		if not staged.is_empty():
			return _error(staged)
		applied = true
	var links: Dictionary = changes.get("links", {})
	for zone_uid in links:
		var target := int(links[zone_uid])
		var row := zone(int(zone_uid))
		if row.is_empty() or not ["maintenance", "pasture"].has(String(row["type"])):
			return _error("只有维持/额外放牧区可以关联调度站")
		if int(row["dispatch_uid"]) == target:
			continue
		if target != 0 and zone_of_dispatch(target) == 0:
			return _error("调度站不在任何工作区内")
		row["dispatch_uid"] = target
		_record("zone", "link", {"zone": int(zone_uid), "dispatch": target})
		applied = true
	var targets: Dictionary = changes.get("birth_targets", {})
	for zone_uid in targets:
		var row := zone(int(zone_uid))
		if row.is_empty() or String(row["type"]) != "enclosure":
			return _error("只有圈养区可以选择育幼区")
		var nursery := zone(int(targets[zone_uid]))
		if nursery.is_empty() or String(nursery["type"]) != "nursery":
			return _error("目标不是育幼区")
		if int(row["birth_target"]) == int(nursery["uid"]):
			continue
		row["birth_target"] = int(nursery["uid"])
		_record("zone", "birth_target", {"zone": int(zone_uid), "target": row["birth_target"]})
		applied = true
	if not applied:
		return _error("没有实际变更")
	return world._finish(int(settings["ap"]["submit"]), {"ok": true, "detail": "变更已保存，次日日界生效"})

func zone_of_dispatch(dispatch_uid: int) -> int:
	for row in state["zones"]:
		if String(row["type"]) != "work":
			continue
		for facility in _facilities_in_zone(row):
			if int(facility["uid"]) == dispatch_uid and String(facility["facility_id"]) == DISPATCH_ID:
				return int(row["uid"])
	return 0

## Switching shifts must not open a maintenance gap: the next window end under
## the new pattern may not fall after the current qualification expires.
func _pattern_gap(row: Dictionary, pattern: String) -> String:
	if not bool(row["served_once"]):
		return ""
	var next_end := _first_window_end(pattern, world.clock.total_days + 1)
	if next_end > int(row["qualified_until"]):
		return "该班次会在维持资格到期前留下空档，先按原班次完成一轮维持"
	return ""

func _first_window_end(pattern: String, day: int) -> int:
	var symbols: Array = settings["patterns"][pattern]
	for u in range(8):
		if symbols[u] == "M":
			return day * 8 + u + 2
	return -1

## Validates one assignment request and stages it; empty string means staged.
func _stage_assignment(row: Dictionary, request: Dictionary) -> String:
	var mode := String(request.get("mode", row["mode"]))
	if not ["waiting", "nursery", "enclosure", "work"].has(mode):
		return "未知归属模式"
	var zone_uid := int(row["zone_uid"])
	if mode == "waiting":
		if String(row["mode"]) == "waiting":
			return "该动物已在等待安置"
	else:
		zone_uid = int(request.get("zone_uid", zone_uid))
		var target := zone(zone_uid)
		if target.is_empty():
			return "目标功能区不存在"
		if String(target["type"]) != mode:
			return "目标功能区类型与归属不符"
		if mode == "enclosure" and String(row["stage"]) != "adult":
			return "只有成体可以进入圈养区"
		if mode == "work" and String(row["stage"]) != "adult":
			return "只有成体可以役使"
	var bed_uid := int(row["bed_uid"])
	var bed_slot := int(row["bed_slot"])
	if mode != "work":
		if request.has("bed_uid"):
			bed_uid = int(request["bed_uid"])
			bed_slot = int(request.get("bed_slot", 0))
		if int(row["bed_uid"]) == bed_uid and int(row["bed_slot"]) == bed_slot and mode == String(row["mode"]) and zone_uid == int(row["zone_uid"]):
			return "没有实际变更"
	row["pending"]["mode"] = mode
	row["pending"]["zone_uid"] = zone_uid
	row["pending"]["bed_uid"] = bed_uid
	row["pending"]["bed_slot"] = bed_slot
	if mode == "work" and request.has("pattern"):
		# Entry pattern: choosing the shift when the animal first joins work is
		# not a schedule change; later switches keep the maintenance-gap rule.
		if not settings["patterns"].has(String(request["pattern"])):
			return "未知班次"
		if String(row["mode"]) != "work":
			row["pending"]["pattern"] = String(request["pattern"])
	return ""

## Bed reallocation inside the current zone is free and immediate.
func set_bed(animal_uid: int, bed_uid: int, bed_slot: int) -> Dictionary:
	var row := animal(animal_uid)
	if row.is_empty():
		return _error("未知动物")
	if String(row["mode"]) == "work":
		return _error("役使动物不占用全时床位")
	var zone_row := zone(int(row["zone_uid"]))
	var facility: Dictionary = world.facilities.get(bed_uid, {})
	if facility.is_empty() or bed_type_of(String(facility["facility_id"])) != String(species_config(String(row["species_id"]))["bed"]):
		return _error("床位体型不匹配")
	if not _facilities_in_zone(zone_row).has(facility):
		return _error("床位不在该功能区内")
	if bed_slot < 0 or bed_slot >= bed_capacity(String(facility["facility_id"])):
		return _error("床位序号非法")
	var taken := _fulltime_slots()
	var key := "%d:%d" % [bed_uid, bed_slot]
	if taken.has(key) and int(taken[key]) != animal_uid:
		return _error("床位已被占用")
	row["bed_uid"] = bed_uid
	row["bed_slot"] = bed_slot
	_record("animal", "bed", {"animal": animal_uid, "bed": bed_uid, "slot": bed_slot})
	world.changed.emit()
	return {"ok": true}

func set_diet(animal_uid: int, diet_id: String) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	var row := animal(animal_uid)
	if row.is_empty():
		return _error("未知动物")
	var species: Dictionary = world.husbandry.species_def(String(row["species_id"]))
	for diet in species["base_diets"]:
		if String(diet["id"]) == diet_id:
			var blocked: String = world.research_block(String(diet.get("research", "")))
			if not blocked.is_empty():
				return _error(blocked)
			row["diet_id"] = diet_id
			_record("animal", "diet", {"animal": animal_uid, "diet": diet_id})
			world.changed.emit()
			return {"ok": true}
	return _error("该物种没有这份基础餐")

func set_priority(animal_uid: int, priority: int) -> Dictionary:
	var row := animal(animal_uid)
	if row.is_empty():
		return _error("未知动物")
	if priority < 0 or priority > 99:
		return _error("优先级非法")
	row["priority"] = priority
	_record("animal", "priority", {"animal": animal_uid, "priority": priority})
	world.changed.emit()
	return {"ok": true}

# --- purchase -----------------------------------------------------------------

func quote_purchase(zone_uid: int, species_id: String, count: int) -> Dictionary:
	var zone_row := zone(zone_uid)
	if zone_row.is_empty() or String(zone_row["type"]) != "nursery":
		return _error("请选择一个结构合格的育幼区")
	if not SPECIES.has(species_id):
		return _error("本期未接入该物种")
	if count < 1:
		return _error("至少购入一只")
	if not zone_structural(zone_row):
		return _error("育幼区结构缺件：" + "、".join(structure_missing(zone_row)))
	var species: Dictionary = world.husbandry.species_def(species_id)
	var blocked: String = world.research_block(String(species.get("research", "")))
	if not blocked.is_empty():
		return _error(blocked)
	var beds := free_bed_slots(zone_row, String(species_config(species_id)["bed"]))
	if beds.size() < count:
		return _error("适配床位不足：需%d，空余%d" % [count, beds.size()])
	var space := int(species_config(species_id)["space"])
	if _zone_usage(zone_row) + space * count > available_space(zone_row):
		return _error("育幼区空间不足")
	return {"ok": true, "total": int(species["juvenile_price"]) * count, "beds": beds.slice(0, count)}

func purchase(zone_uid: int, species_id: String, count: int) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	var quote := quote_purchase(zone_uid, species_id, count)
	if not quote["ok"]:
		return quote
	var total := int(quote["total"])
	if world.primeval_stones < total:
		return _error("元石不足")
	world.primeval_stones -= total
	world._cash("purchase_spend", total)
	var species: Dictionary = world.husbandry.species_def(species_id)
	var bought := []
	for index in range(count):
		var uid := int(state["next_animal_uid"])
		state["next_animal_uid"] = uid + 1
		var bed: Dictionary = quote["beds"][index]
		state["animals"].append(_new_animal(uid, species_id, zone_uid,
			int(bed["uid"]), int(bed["slot"]), String(species["default_base_diet"])))
		bought.append(uid)
	_record("animal", "purchase", {"zone": zone_uid, "species": species_id, "count": count, "total": total, "animals": bought})
	world._report_event({"category": "purchase", "facility_uid": 0, "kind": species_id, "count": count,
		"items": {}, "note": "购入%d只幼体，花费%d元石" % [count, total]})
	return world._finish(0, {"ok": true, "purchased": bought, "total": total, "species_id": species_id})

func _new_animal(uid: int, species_id: String, zone_uid: int, bed_uid: int, bed_slot: int, diet_id: String) -> Dictionary:
	return {"uid": uid, "species_id": species_id, "stage": "juvenile", "growth": 0,
		"mode": "nursery", "zone_uid": zone_uid, "bed_uid": bed_uid, "bed_slot": bed_slot,
		"pending": {}, "diet_id": diet_id, "pattern": "standard", "priority": 0,
		"fatigue": 0, "ban_until": -1, "qualified_until": -1, "served_once": false,
		"natural": {"round": 0, "units": 0, "pending": false, "paid": false},
		"breed": {"round": 0, "units": 0, "pending": false},
		"death_streak": 0, "account": {"w": 0, "r": 0, "fails": 0}}

# --- work yards ---------------------------------------------------------------

func workyard_state(facility_uid: int) -> Dictionary:
	var key := str(facility_uid)
	if not state["workyards"].has(key):
		var posts := []
		for _index in range(int(settings["work"]["posts_per_yard"])):
			posts.append(_idle_post())
		state["workyards"][key] = {"recipe_id": String(settings["work"]["default_recipe"]), "posts": posts}
	return state["workyards"][key]

func _idle_post() -> Dictionary:
	return {"batch_id": 0, "recipe_id": "", "inputs": {}, "outputs": {}, "progress": 0, "target": 0, "status": "idle"}

func set_recipe(facility_uid: int, recipe_id: String) -> Dictionary:
	var facility: Dictionary = world.facilities.get(facility_uid, {})
	if facility.is_empty() or String(facility["facility_id"]) != WORKYARD_ID:
		return _error("未知工作场")
	if not settings["work"]["recipes"].has(recipe_id):
		return _error("未知劳动配方")
	var yard := workyard_state(facility_uid)
	for post in yard["posts"]:
		if String(post["status"]) != "idle":
			return _error("有运行中批次的工作场不能更换配方")
	var blocked: String = world.research_block(String(world.husbandry.species_def(String(settings["work"]["recipes"][recipe_id]["species"])).get("research", "")))
	if not blocked.is_empty():
		return _error(blocked)
	yard["recipe_id"] = recipe_id
	_record("workyard", "recipe", {"workyard": facility_uid, "recipe": recipe_id})
	world.changed.emit()
	return {"ok": true}

func workyard_busy(facility_uid: int) -> bool:
	var yard: Dictionary = state["workyards"].get(str(facility_uid), {})
	for post in yard.get("posts", []):
		if String(post["status"]) != "idle":
			return true
	return false

func claim_workyard(facility_uid: int) -> Dictionary:
	var facility: Dictionary = world.facilities.get(facility_uid, {})
	if facility.is_empty() or String(facility["facility_id"]) != WORKYARD_ID:
		return _error("未知工作场")
	var yard := workyard_state(facility_uid)
	var outputs := {}
	var claimed := 0
	for post in yard["posts"]:
		if String(post["status"]) != "ready":
			continue
		for item in post["outputs"]:
			var amount := int(post["outputs"][item])
			if not Scalars.whole(world.inventory.count(String(item)) + int(outputs.get(item, 0)) + amount):
				return _error("输出库存越界：" + String(world._items[String(item)]["name"]))
			outputs[String(item)] = int(outputs.get(String(item), 0)) + amount
	for post in yard["posts"]:
		if String(post["status"]) == "ready":
			var reset := _idle_post()
			for key in reset:
				post[key] = reset[key]
			claimed += 1
	if claimed == 0:
		return _error("没有待领取的批次")
	for item in outputs:
		world.inventory.add(String(item), int(outputs[item]))
	world._record_flow(outputs, {}, "畜牧劳动领取")
	_record("workyard", "claim", {"workyard": facility_uid, "recipe": String(yard["recipe_id"]), "outputs": outputs.duplicate(), "posts": claimed})
	return world._finish(int(settings["ap"]["claim_workyard"]), {"ok": true, "items": outputs.duplicate(), "posts": claimed})

# --- enclosure products and births --------------------------------------------

func claim_products(facility_uid: int) -> Dictionary:
	var facility: Dictionary = world.facilities.get(facility_uid, {})
	if facility.is_empty() or String(facility["facility_id"]) != PEN_ID:
		return _error("未知圈舍")
	var zone_row := {}
	for row in state["zones"]:
		if String(row["type"]) == "enclosure":
			for inside in _facilities_in_zone(row):
				if int(inside["uid"]) == facility_uid:
					zone_row = row
	if zone_row.is_empty():
		return _error("该圈舍不在圈养区内")
	var outputs := {}
	var payers := []
	for row in animals_in_zone(int(zone_row["uid"]), ["enclosure"]):
		if not bool(row["natural"]["pending"]):
			continue
		for item in species_config(String(row["species_id"]))["natural_outputs"]:
			var amount := int(species_config(String(row["species_id"]))["natural_outputs"][item])
			if not Scalars.whole(world.inventory.count(String(item)) + int(outputs.get(String(item), 0)) + amount):
				return _error("输出库存越界：" + String(world._items[String(item)]["name"]))
			outputs[String(item)] = int(outputs.get(String(item), 0)) + amount
		payers.append(int(row["uid"]))
	if payers.is_empty():
		return _error("没有待领取的畜产")
	for uid in payers:
		var natural: Dictionary = animal(int(uid))["natural"]
		natural["round"] = int(natural["round"]) + 1
		natural["units"] = 0
		natural["pending"] = false
		natural["paid"] = false
	for item in outputs:
		world.inventory.add(String(item), int(outputs[item]))
	world._record_flow(outputs, {}, "圈养畜产领取")
	_record("enclosure", "claim_products", {"zone": int(zone_row["uid"]), "animals": payers, "outputs": outputs.duplicate()})
	return world._finish(int(settings["ap"]["claim_products"]), {"ok": true, "items": outputs.duplicate(), "animals": payers.size()})

func claim_births(zone_uid: int) -> Dictionary:
	var zone_row := zone(zone_uid)
	if zone_row.is_empty() or String(zone_row["type"]) != "enclosure":
		return _error("请从圈养区领取待安置幼体")
	var nursery := zone(int(zone_row["birth_target"]))
	if nursery.is_empty() or String(nursery["type"]) != "nursery":
		return _error("请先为该圈养区选择有效的目标育幼区")
	if not zone_structural(nursery):
		return _error("目标育幼区结构缺件：" + "、".join(structure_missing(nursery)))
	var born := []
	for row in animals_in_zone(zone_uid, ["enclosure"]):
		if not bool(row["breed"]["pending"]):
			continue
		var sid := String(row["species_id"])
		var bed_type := String(species_config(sid)["bed"])
		var beds := free_bed_slots(nursery, bed_type)
		if beds.is_empty():
			return _error("目标育幼区没有适配床位")
		var space := int(species_config(sid)["space"])
		if _zone_usage(nursery) + space > available_space(nursery):
			return _error("目标育幼区空间不足")
		var child := int(state["next_animal_uid"])
		state["next_animal_uid"] = child + 1
		state["animals"].append(_new_animal(child, sid, int(nursery["uid"]),
			int(beds[0]["uid"]), int(beds[0]["slot"]), String(world.husbandry.species_def(sid)["default_base_diet"])))
		state["births"].append({"parent_uid": int(row["uid"]), "round": int(row["breed"]["round"]), "child_uid": child})
		row["breed"]["round"] = int(row["breed"]["round"]) + 1
		row["breed"]["units"] = 0
		row["breed"]["pending"] = false
		born.append(child)
	if born.is_empty():
		return _error("没有待安置的幼体")
	_record("enclosure", "claim_births", {"zone": zone_uid, "children": born})
	world._report_event({"category": "growth", "facility_uid": 0, "kind": "出生安置",
		"count": born.size(), "items": {}, "note": "%d只幼体进入育幼区" % born.size()})
	return world._finish(int(settings["ap"]["claim_births"]), {"ok": true, "children": born})

# --- the eight-unit planner ---------------------------------------------------

func _meals_for(mode: String) -> int:
	return int(settings["meals"].get(mode, 1))

func _shadow_count(item: String, shadow: Dictionary) -> int:
	return world.inventory.count(item) - int(shadow.get(item, 0))

func _shadow_spend(inputs: Dictionary, shadow: Dictionary) -> void:
	for item in inputs:
		shadow[String(item)] = int(shadow.get(String(item), 0)) + int(inputs[item])

func _dispatch_of(zone_row: Dictionary) -> int:
	for facility in _facilities_in_zone(zone_row):
		if String(facility["facility_id"]) == DISPATCH_ID:
			return int(facility["uid"])
	return 0

func _linked_zones(zone_row: Dictionary, type_id: String) -> Array:
	var dispatch := _dispatch_of(zone_row)
	var out := []
	if dispatch == 0:
		return out
	for row in state["zones"]:
		if String(row["type"]) == type_id and int(row["dispatch_uid"]) == dispatch:
			out.append(row)
	out.sort_custom(func(a, b): return int(a["uid"]) < int(b["uid"]))
	return out

static func _windows_overlap(a: int, b: int) -> bool:
	return absi(a - b) < 2

## Whole-day simulation. mutate=false keeps state and stock untouched so the UI
## can show the next day's plan under the same conflict rules.
func _plan_day(day: int, mutate: bool) -> Dictionary:
	var out := {"animals": {}, "windows": [], "conflicts": []}
	var day0 := day * 8
	var shadow := {}
	var active := {}
	var window_rows: Array = state["reservations"].duplicate(true)
	var counter := int(state["next_window_uid"])
	var pasture_use := {}
	var post_taken := {}
	var accounts := {}
	var rows := _ordered_animals()
	for row in rows:
		accounts[int(row["uid"])] = {"w": 0, "r": 0, "fails": 0}
		out["animals"][int(row["uid"])] = {"pattern": pattern_of(row).duplicate(), "units": []}
	for u in range(8):
		var t := day0 + u
		for row in rows:
			var uid := int(row["uid"])
			if active.has(uid) and int(active[uid]["start_t"]) + 2 == t:
				_end_window(row, active[uid], t, mutate, shadow, accounts, out)
				active.erase(uid)
		for row in rows:
			var uid := int(row["uid"])
			var symbols := pattern_of(row)
			if symbols[u] == "M" and (u == 0 or symbols[u - 1] != "M") and not active.has(uid):
				active[uid] = _start_window(row, t, window_rows, counter, mutate, out)
				counter = maxi(counter, int(state["next_window_uid"]))
		for row in rows:
			var uid := int(row["uid"])
			var activity := _unit_activity(row, u, t, String(pattern_of(row)[u]), mutate, shadow, post_taken, pasture_use, accounts)
			out["animals"][uid]["units"].append(activity)
	for uid in active.keys().duplicate():
		if int(active[uid]["start_t"]) + 2 == day0 + 8:
			_end_window(animal(int(uid)), active[uid], day0 + 8, mutate, shadow, accounts, out)
			active.erase(int(uid))
	if mutate:
		var keep := []
		for reservation in window_rows:
			if int(reservation["end_t"]) > day0 + 8:
				keep.append(reservation)
		state["reservations"] = keep
		_finish_day(day, accounts, out)
	return out

func _start_window(row: Dictionary, t: int, window_rows: Array, counter: int, mutate: bool, out: Dictionary) -> Dictionary:
	var record := {"animal_uid": int(row["uid"]), "start_t": t, "bed_uid": 0, "bed_slot": 0,
		"trough_uid": 0, "zone_uid": 0, "meals": _meals_for(String(row["mode"])), "failed": false, "reason": ""}
	var mode := String(row["mode"])
	var zone_row := zone(int(row["zone_uid"]))
	if mode == "work":
		if _dispatch_of(zone_row) == 0:
			record["failed"] = true
			record["reason"] = "工作区没有调度站"
			out["conflicts"].append({"animal": int(row["uid"]), "t": t, "kind": "no_dispatch"})
			return record
		for candidate in _linked_zones(zone_row, "maintenance"):
			if _reserve_window(row, candidate, t, window_rows, record):
				out["windows"].append({"animal": int(row["uid"]), "start": t, "end": t + 2, "ok": true})
				return record
		record["failed"] = true
		record["reason"] = "没有可预约的床位、食槽或维持空间"
		out["conflicts"].append({"animal": int(row["uid"]), "t": t, "kind": "no_maintenance_slot"})
		return record
	if zone_row.is_empty() or not zone_structural(zone_row):
		record["failed"] = true
		record["reason"] = "功能区结构缺件"
		out["conflicts"].append({"animal": int(row["uid"]), "t": t, "kind": "structure"})
		return record
	var facility: Dictionary = world.facilities.get(int(row["bed_uid"]), {})
	if facility.is_empty() or bed_type_of(String(facility["facility_id"])) != String(species_config(String(row["species_id"]))["bed"]) or not _facilities_in_zone(zone_row).has(facility):
		record["failed"] = true
		record["reason"] = "全时床位缺失或体型不匹配"
		out["conflicts"].append({"animal": int(row["uid"]), "t": t, "kind": "bed_missing"})
		return record
	var trough_uid := 0
	for candidate in _facilities_in_zone(zone_row):
		if String(candidate["facility_id"]) != TROUGH_ID:
			continue
		var used := 0
		for other in window_rows:
			if int(other["trough_uid"]) == int(candidate["uid"]) and _windows_overlap(int(other["start_t"]), t):
				used += 1
		if used < int(settings["trough_slots"]):
			trough_uid = int(candidate["uid"])
			break
	if trough_uid == 0:
		record["failed"] = true
		record["reason"] = "食槽服务位不足"
		out["conflicts"].append({"animal": int(row["uid"]), "t": t, "kind": "no_trough"})
		return record
	record["bed_uid"] = int(facility["uid"])
	record["bed_slot"] = int(row["bed_slot"])
	record["trough_uid"] = trough_uid
	record["zone_uid"] = int(zone_row["uid"])
	window_rows.append(_reservation_row(counter, row, facility, int(row["bed_slot"]), trough_uid, int(zone_row["uid"]), t, mutate))
	_record("window", "start", {"animal": int(row["uid"]), "t": t, "bed": int(facility["uid"]),
		"slot": int(row["bed_slot"]), "trough": trough_uid, "zone": int(zone_row["uid"]), "meals": int(record["meals"])})
	out["windows"].append({"animal": int(row["uid"]), "start": t, "end": t + 2, "ok": true})
	return record

func _reservation_row(counter: int, row: Dictionary, facility: Dictionary, slot: int, trough_uid: int, zone_uid: int, t: int, mutate: bool) -> Dictionary:
	if mutate:
		state["next_window_uid"] = maxi(int(state["next_window_uid"]), counter + 1)
	return {"uid": counter + 1, "animal_uid": int(row["uid"]), "bed_uid": int(facility["uid"]),
		"bed_slot": slot, "trough_uid": trough_uid, "zone_uid": zone_uid,
		"start_t": t, "end_t": t + 2, "meals": _meals_for(String(row["mode"]))}

func _reserve_window(row: Dictionary, candidate: Dictionary, t: int, window_rows: Array, record: Dictionary) -> bool:
	if not zone_structural(candidate):
		return false
	var bed_type := String(species_config(String(row["species_id"]))["bed"])
	var space := int(species_config(String(row["species_id"]))["space"])
	var used_space := 0
	for other in window_rows:
		if int(other["zone_uid"]) == int(candidate["uid"]) and _windows_overlap(int(other["start_t"]), t):
			used_space += int(species_config(String(animal(int(other["animal_uid"]))["species_id"]))["space"])
	if used_space + space > available_space(candidate):
		return false
	var counter := int(state["next_window_uid"])
	for facility in _facilities_in_zone(candidate):
		if not is_bed(String(facility["facility_id"])) or bed_type_of(String(facility["facility_id"])) != bed_type:
			continue
		for slot in range(bed_capacity(String(facility["facility_id"]))):
			var busy := false
			for other in window_rows:
				if int(other["bed_uid"]) == int(facility["uid"]) and int(other["bed_slot"]) == slot and _windows_overlap(int(other["start_t"]), t):
					busy = true
					break
			if busy:
				continue
			var trough_uid := 0
			for trough in _facilities_in_zone(candidate):
				if String(trough["facility_id"]) != TROUGH_ID:
					continue
				var used := 0
				for other in window_rows:
					if int(other["trough_uid"]) == int(trough["uid"]) and _windows_overlap(int(other["start_t"]), t):
						used += 1
				if used < int(settings["trough_slots"]):
					trough_uid = int(trough["uid"])
					break
			if trough_uid == 0:
				continue
			record["bed_uid"] = int(facility["uid"])
			record["bed_slot"] = slot
			record["trough_uid"] = trough_uid
			record["zone_uid"] = int(candidate["uid"])
			var reservation := _reservation_row(counter, row, facility, slot, trough_uid, int(candidate["uid"]), t, true)
			window_rows.append(reservation)
			_record("window", "start", {"animal": int(row["uid"]), "t": t, "bed": int(facility["uid"]),
				"slot": slot, "trough": trough_uid, "zone": int(candidate["uid"]), "meals": int(record["meals"])})
			return true
	return false

func _end_window(row: Dictionary, record: Dictionary, t: int, mutate: bool, shadow: Dictionary, accounts: Dictionary, out: Dictionary) -> void:
	if row.is_empty():
		return
	var account: Dictionary = accounts.get(int(row["uid"]), {"w": 0, "r": 0, "fails": 0})
	if bool(record["failed"]):
		_fail_window(row, String(record["reason"]), t, account, mutate, out)
		return
	var zone_row := zone(int(record["zone_uid"]))
	var bed: Dictionary = world.facilities.get(int(record["bed_uid"]), {})
	var trough: Dictionary = world.facilities.get(int(record["trough_uid"]), {})
	var meals := int(record["meals"])
	var inputs: Dictionary = world.husbandry.diet_inputs(String(row["species_id"]), "base_diets", String(row["diet_id"]))
	var scaled := {}
	for item in inputs:
		scaled[String(item)] = int(inputs[item]) * meals
	var broken := zone_row.is_empty() or bed.is_empty() or trough.is_empty() or not zone_structural(zone_row)
	if not broken:
		for item in scaled:
			if _shadow_count(String(item), shadow) < int(scaled[item]):
				broken = true
				record["reason"] = "基础餐缺料：" + String(world._items[String(item)]["name"])
				break
	if broken:
		if String(record["reason"]).is_empty():
			record["reason"] = "窗口中途结构或床位失效"
		_fail_window(row, String(record["reason"]), t, account, mutate, out)
		return
	if mutate:
		for item in scaled:
			world.inventory.remove(String(item), int(scaled[item]))
		world._record_flow({}, scaled, "畜牧维持")
	else:
		_shadow_spend(scaled, shadow)
	row["served_once"] = true
	row["qualified_until"] = t + 8
	_record("window", "success", {"animal": int(row["uid"]), "t": t, "inputs": scaled.duplicate(), "qualified_until": t + 8})
	out["windows"].append({"animal": int(row["uid"]), "end": t, "result": "success", "inputs": scaled.duplicate()})

func _fail_window(row: Dictionary, reason: String, t: int, account: Dictionary, mutate: bool, out: Dictionary) -> void:
	account["fails"] = int(account["fails"]) + 1
	row["ban_until"] = maxi(int(row["ban_until"]), t + 8)
	row["qualified_until"] = mini(int(row["qualified_until"]), t)
	if mutate:
		world._report_event({"category": "maintenance", "facility_uid": 0, "kind": "维持失败",
			"count": 1, "items": {}, "note": "%s（禁工至单位%d）" % [reason, t + 8]})
	_record("window", "fail", {"animal": int(row["uid"]), "t": t, "reason": reason, "ban_until": t + 8})
	out["windows"].append({"animal": int(row["uid"]), "end": t, "result": "fail", "reason": reason})

func _unit_activity(row: Dictionary, u: int, t: int, symbol: String, mutate: bool, shadow: Dictionary, post_taken: Dictionary, pasture_use: Dictionary, accounts: Dictionary) -> String:
	var account: Dictionary = accounts.get(int(row["uid"]), {"w": 0, "r": 0, "fails": 0})
	var qualified := t < int(row["qualified_until"])
	match symbol:
		"M":
			return "maintain"
		"W":
			if t < int(row["ban_until"]):
				return _try_roam(row, t, qualified, account, pasture_use, "ban_wait")
			if not qualified:
				return "unqualified_wait"
			if int(fatigue_tier(int(row["fatigue"]))["efficiency"]) <= 0:
				return _try_roam(row, t, qualified, account, pasture_use, "strike_wait")
			if _take_post(row, t, mutate, shadow, post_taken, account):
				return "work"
			return _try_roam(row, t, qualified, account, pasture_use, "no_post_wait")
		"R":
			return _try_roam(row, t, qualified, account, pasture_use, "wait")
		"C":
			if not qualified:
				return "care_wait"
			var mode := String(row["mode"])
			if mode == "nursery" and String(row["stage"]) == "juvenile":
				row["growth"] = mini(int(species_config(String(row["species_id"]))["growth_units"]), int(row["growth"]) + 1)
			elif mode == "enclosure" and String(row["stage"]) == "adult":
				_enclosure_care(row, mutate, shadow)
			account["r"] = int(account["r"]) + 1
			return "care"
	return "idle"

func _enclosure_care(row: Dictionary, mutate: bool, shadow: Dictionary) -> void:
	var config := species_config(String(row["species_id"]))
	var natural: Dictionary = row["natural"]
	if config.has("natural_units") and not bool(natural["pending"]):
		if not bool(natural["paid"]):
			var diet: Dictionary = world.husbandry.diet_inputs(String(row["species_id"]), "special_diets", String(config["natural_diet"]))
			var enough := true
			for item in diet:
				if _shadow_count(String(item), shadow) < int(diet[item]):
					enough = false
			if enough:
				if mutate:
					for item in diet:
						world.inventory.remove(String(item), int(diet[item]))
					world._record_flow({}, diet, "畜产特殊投料")
				else:
					_shadow_spend(diet, shadow)
				natural["paid"] = true
				_record("natural", "round_start", {"animal": int(row["uid"]), "round": int(natural["round"]), "inputs": diet.duplicate()})
		if bool(natural["pending"]) or not bool(natural["paid"]):
			pass
		else:
			natural["units"] = int(natural["units"]) + 1
			if int(natural["units"]) >= int(config["natural_units"]):
				natural["pending"] = true
				if mutate:
					world._report_event({"category": "growth", "facility_uid": 0, "kind": "畜产待领取",
						"count": 1, "items": config["natural_outputs"].duplicate(), "note": ""})
				_record("natural", "ready", {"animal": int(row["uid"]), "round": int(natural["round"]), "outputs": config["natural_outputs"].duplicate()})
	var breed: Dictionary = row["breed"]
	if not bool(breed["pending"]) and int(row["fatigue"]) == 0:
		breed["units"] = int(breed["units"]) + 1
		if int(breed["units"]) >= int(config["breed_units"]):
			breed["pending"] = true
			_record("breed", "ready", {"animal": int(row["uid"]), "round": int(breed["round"])})
			if mutate:
				world._report_event({"category": "growth", "facility_uid": 0, "kind": "待安置幼体",
					"count": 1, "items": {}, "note": "请在圈养区领取并选择育幼区"})

func _try_roam(row: Dictionary, t: int, qualified: bool, account: Dictionary, pasture_use: Dictionary, wait_label: String) -> String:
	if not qualified:
		return "unqualified_wait"
	var zone_row := zone(int(row["zone_uid"]))
	var space := int(species_config(String(row["species_id"]))["space"])
	for candidate in _linked_zones(zone_row, "pasture"):
		var key := "%d:%d" % [int(candidate["uid"]), t % 8]
		var used := int(pasture_use.get(key, 0))
		if used + space <= available_space(candidate):
			pasture_use[key] = used + space
			account["r"] = int(account["r"]) + 1
			return "roam"
	return wait_label

func _take_post(row: Dictionary, t: int, mutate: bool, shadow: Dictionary, post_taken: Dictionary, account: Dictionary) -> bool:
	var zone_row := zone(int(row["zone_uid"]))
	var yards: Array = _facilities_in_zone(zone_row).filter(func(f): return String(f["facility_id"]) == WORKYARD_ID)
	var points := int(fatigue_tier(int(row["fatigue"]))["efficiency"]) * int(settings["work"]["points_per_unit"]) / 100
	for yard in yards:
		var yard_state := workyard_state(int(yard["uid"]))
		var recipe_id := String(yard_state["recipe_id"])
		var recipe: Dictionary = settings["work"]["recipes"].get(recipe_id, {})
		if recipe.is_empty() or String(recipe["species"]) != String(row["species_id"]):
			continue
		for index in range(yard_state["posts"].size()):
			var post: Dictionary = yard_state["posts"][index]
			var key := "%d:%d:%d" % [int(yard["uid"]), index, t]
			if String(post["status"]) == "ready" or post_taken.has(key):
				continue
			if String(post["status"]) == "idle":
				var def: Dictionary = world.recipe_defs[recipe_id]
				var enough := true
				for item in def["inputs"]:
					if _shadow_count(String(item), shadow) < int(def["inputs"][item]):
						enough = false
				if not enough:
					continue
				if mutate:
					for item in def["inputs"]:
						world.inventory.remove(String(item), int(def["inputs"][item]))
					world._record_flow({}, def["inputs"], "劳动开批")
				else:
					_shadow_spend(def["inputs"], shadow)
				post["batch_id"] = int(state["next_batch_uid"])
				state["next_batch_uid"] = int(state["next_batch_uid"]) + 1
				post["recipe_id"] = recipe_id
				var paid := {}
				for item in def["inputs"]:
					paid[String(item)] = int(def["inputs"][item])
				var produced := {}
				for item in def["outputs"]:
					produced[String(item)] = int(def["outputs"][item])
				post["inputs"] = paid
				post["outputs"] = produced
				post["progress"] = 0
				post["target"] = int(recipe["target"])
				post["status"] = "running"
				_record("workyard", "batch_open", {"workyard": int(yard["uid"]), "post": index,
					"batch_id": int(post["batch_id"]), "recipe": recipe_id,
					"inputs": def["inputs"].duplicate(), "outputs": def["outputs"].duplicate()})
			post_taken[key] = true
			post["progress"] = mini(int(post["target"]), int(post["progress"]) + points)
			if int(post["progress"]) >= int(post["target"]) and String(post["status"]) == "running":
				post["status"] = "ready"
				_record("workyard", "batch_ready", {"workyard": int(yard["uid"]), "post": index,
					"batch_id": int(post["batch_id"]), "recipe": recipe_id})
				if mutate:
					world._report_event({"category": "growth", "facility_uid": int(yard["uid"]), "kind": "批次完成",
						"count": 1, "items": post["outputs"].duplicate(), "note": "待领取"})
			account["w"] = int(account["w"]) + 1
			_record("work", "unit", {"animal": int(row["uid"]), "t": t, "workyard": int(yard["uid"]),
				"post": index, "points": points, "progress": int(post["progress"])})
			return true
	return false

func _finish_day(day: int, accounts: Dictionary, out: Dictionary) -> void:
	var fatigue: Dictionary = settings["fatigue"]
	var survivors := []
	var day_accounts := {}
	for row in state["animals"]:
		var account: Dictionary = accounts.get(int(row["uid"]), {"w": 0, "r": 0, "fails": 0})
		var rest := int(account["r"])
		if String(row["mode"]) != "work":
			rest = mini(rest, int(fatigue["enclosure_rest_cap"]))
		var next := clampi(int(row["fatigue"]) + int(account["w"]) * int(fatigue["work_debt"])
			- rest * int(fatigue["rest_credit"]) + int(account["fails"]) * int(fatigue["fail_penalty"]),
			0, int(fatigue["cap"]))
		row["account"] = {"w": int(account["w"]), "r": rest, "fails": int(account["fails"])}
		var survivor := true
		_record("day", "account", {"animal": int(row["uid"]), "day": day, "w": int(account["w"]),
			"r": rest, "fails": int(account["fails"]), "fatigue": int(row["fatigue"]), "next": next})
		if next >= int(fatigue["death_threshold"]):
			row["death_streak"] = int(row["death_streak"]) + 1
		else:
			row["death_streak"] = 0
		if int(row["death_streak"]) >= int(fatigue["death_streak"]):
			world._report_event({"category": "pause", "facility_uid": 0, "kind": "动物死亡",
				"count": 1, "items": {}, "note": "%s因连续濒危死亡" % String(world.husbandry.species_def(String(row["species_id"]))["name"])})
			_record("animal", "death", {"animal": int(row["uid"]), "day": day, "fatigue": next, "streak": int(row["death_streak"])})
			survivor = false
		row["fatigue"] = next
		if String(row["stage"]) == "juvenile" and int(row["growth"]) >= int(species_config(String(row["species_id"]))["growth_units"]):
			row["stage"] = "adult"
			row["mode"] = "waiting"
			world._report_event({"category": "growth", "facility_uid": 0, "kind": "成年",
				"count": 1, "items": {}, "note": "请为其选择圈养或役使归属"})
			_record("animal", "adult", {"animal": int(row["uid"]), "day": day})
		if survivor:
			day_accounts[int(row["uid"])] = row["account"].duplicate()
			survivors.append(row)
	state["animals"] = survivors
	var kept_births := []
	for voucher in state["births"]:
		if not animal(int(voucher["parent_uid"])).is_empty():
			kept_births.append(voucher)
	state["births"] = kept_births
	_apply_pending()
	state["day"] = {"day": day, "accounts": day_accounts}
	_record("day", "settled", {"day": day, "animals": survivors.size()})

func _apply_pending() -> void:
	for row in state["animals"]:
		var staged: Dictionary = row["pending"]
		if staged.is_empty():
			continue
		if staged.has("pattern") and String(row["mode"]) == "work":
			row["pattern"] = String(staged["pattern"])
		var mode := String(staged.get("mode", row["mode"]))
		var zone_uid := int(staged.get("zone_uid", row["zone_uid"]))
		var bed_uid := int(staged.get("bed_uid", row["bed_uid"]))
		var bed_slot := int(staged.get("bed_slot", row["bed_slot"]))
		var ok := true
		if mode == "waiting":
			zone_uid = int(row["zone_uid"])
		else:
			var target := zone(zone_uid)
			if target.is_empty() or String(target["type"]) != mode:
				ok = false
		if ok and mode != "work":
			var facility: Dictionary = world.facilities.get(bed_uid, {})
			var zone_row := zone(zone_uid)
			if facility.is_empty() or bed_type_of(String(facility["facility_id"])) != String(species_config(String(row["species_id"]))["bed"]) or not _facilities_in_zone(zone_row).has(facility):
				ok = false
			else:
				var taken := _fulltime_slots()
				var key := "%d:%d" % [bed_uid, bed_slot]
				if taken.has(key) and int(taken[key]) != int(row["uid"]):
					ok = false
		if mode == "work":
			# Going to work releases the full-time bed slot immediately.
			bed_uid = 0
			bed_slot = 0
		if ok and (mode != String(row["mode"]) or zone_uid != int(row["zone_uid"]) or bed_uid != int(row["bed_uid"])):
			row["mode"] = mode
			row["zone_uid"] = zone_uid
			row["bed_uid"] = bed_uid
			row["bed_slot"] = bed_slot
			_record("animal", "assign", {"animal": int(row["uid"]), "mode": mode, "zone": zone_uid, "bed": bed_uid, "slot": bed_slot})
		elif mode != String(row["mode"]) or zone_uid != int(row["zone_uid"]):
			world._report_event({"category": "pause", "facility_uid": 0, "kind": "安置失效",
				"count": 1, "items": {}, "note": "待生效归属目标已失效，动物保持原归属"})
		row["pending"] = {}

func settle(completed_day: int) -> void:
	if int(state["day"]["day"]) >= completed_day:
		return
	_settle_day = completed_day
	_plan_day(completed_day, true)
	_settle_day = -1

func preview_next_day() -> Dictionary:
	return _plan_day(world.clock.total_days + 1, false)

# --- persistence --------------------------------------------------------------

func _record(kind: String, stage: String, payload: Dictionary) -> void:
	var entry := payload.duplicate()
	entry["kind"] = "ranch:" + kind
	entry["stage"] = stage
	entry["day"] = _settle_day if _settle_day >= 0 else world.clock.total_days
	world.record_operation(entry)

func to_save() -> Dictionary:
	return state.duplicate(true)

func apply_save(value: Dictionary) -> void:
	state = value.duplicate(true)

func forget_facility(facility_uid: int) -> void:
	state["workyards"].erase(str(facility_uid))
	for row in state["animals"]:
		if int(row["bed_uid"]) == facility_uid:
			row["bed_uid"] = 0
			row["bed_slot"] = 0

const Canonical := preload("res://scripts/farming/p8/p10_logistics.gd")

static func normalize(value, snapshot: Dictionary, catalog) -> Dictionary:
	if not Scalars.exact(value, fresh().keys()):
		return Scalars.fail("畜牧分区快照结构非法")
	var out := fresh()
	for field in ["next_zone_uid", "next_animal_uid", "next_window_uid", "next_batch_uid"]:
		if not Scalars.whole(value[field], 1):
			return Scalars.fail("畜牧分区序号非法")
		out[field] = int(value[field])
	var world_body: Dictionary = snapshot["world"]
	var facilities := {}
	for row in world_body["facilities"]:
		facilities[int(row["uid"])] = row
	var config: Dictionary = catalog.load_data()["p103"]
	var bed_capacity_map := {}
	for fid in config["bed_facilities"]:
		bed_capacity_map[fid] = int(config["bed_facilities"][fid]["slots"])
	if not value["zones"] is Array:
		return Scalars.fail("功能区别表非法")
	var zone_cells := {}
	var zone_types := {}
	var dispatch_ids := {}
	for uid in facilities:
		if String(facilities[uid]["facility_id"]) == DISPATCH_ID:
			dispatch_ids[int(uid)] = true
	for row in value["zones"]:
		if not Scalars.exact(row, ["uid", "type", "name", "cells", "dispatch_uid", "birth_target"]):
			return Scalars.fail("功能区字段非法")
		if not Scalars.whole(row["uid"], 1, int(value["next_zone_uid"]) - 1) or zone_types.has(int(row["uid"])):
			return Scalars.fail("功能区序号非法")
		if not ZONE_TYPES.has(String(row["type"])) or not row["name"] is String or String(row["name"]).is_empty():
			return Scalars.fail("功能区类型或名称非法")
		if not row["cells"] is Array or row["cells"].is_empty():
			return Scalars.fail("功能区地格非法")
		for text in row["cells"]:
			if not text is String or String(text).split(",").size() != 2:
				return Scalars.fail("功能区地格格式非法")
			if zone_cells.has(String(text)):
				return Scalars.fail("功能区地格重叠")
			zone_cells[String(text)] = int(row["uid"])
		if not _connected(row["cells"]):
			return Scalars.fail("功能区不连通")
		if not Scalars.whole(row["dispatch_uid"], 0) or not Scalars.whole(row["birth_target"], 0):
			return Scalars.fail("功能区关联非法")
		if int(row["dispatch_uid"]) > 0:
			if not ["maintenance", "pasture"].has(String(row["type"])) or not dispatch_ids.has(int(row["dispatch_uid"])):
				return Scalars.fail("功能区关联的调度站非法")
		if int(row["birth_target"]) > 0 and String(row["type"]) != "enclosure":
			return Scalars.fail("只有圈养区有育幼目标")
		zone_types[int(row["uid"])] = String(row["type"])
		out["zones"].append({"uid": int(row["uid"]), "type": String(row["type"]), "name": String(row["name"]),
			"cells": row["cells"].duplicate(), "dispatch_uid": int(row["dispatch_uid"]), "birth_target": int(row["birth_target"])})
	if not value["animals"] is Array:
		return Scalars.fail("动物名册非法")
	var species_defs: Dictionary = catalog.definitions("livestock")
	var animal_ids := {}
	var fulltime := {}
	for row in value["animals"]:
		if not Scalars.exact(row, ANIMAL_KEYS):
			return Scalars.fail("动物字段非法")
		if not Scalars.whole(row["uid"], 1, int(value["next_animal_uid"]) - 1) or animal_ids.has(int(row["uid"])):
			return Scalars.fail("动物序号非法")
		var sid := String(row["species_id"])
		if not SPECIES.has(sid):
			return Scalars.fail("动物物种不在畜牧范围")
		if String(row["stage"]) not in ["juvenile", "adult"]:
			return Scalars.fail("动物阶段非法")
		if String(row["mode"]) not in ["waiting", "nursery", "enclosure", "work"]:
			return Scalars.fail("动物归属非法")
		if not zone_types.has(int(row["zone_uid"])):
			return Scalars.fail("动物指向未知功能区")
		var expected := "nursery" if String(row["mode"]) in ["nursery", "waiting"] else String(row["mode"])
		if zone_types[int(row["zone_uid"])] != expected:
			return Scalars.fail("动物归属与功能区类型不符")
		var species_cfg: Dictionary = config["species"][sid]
		var gate := String(species_defs[sid].get("research", ""))
		if not gate.is_empty() and not snapshot["world"]["research"]["completed"].has(gate):
			return Scalars.fail("已购入物种缺少前置研究：" + gate)
		if not Scalars.whole(row["growth"], 0, int(species_cfg["growth_units"])):
			return Scalars.fail("动物成长进度非法")
		if not Scalars.whole(row["fatigue"], 0, 100):
			return Scalars.fail("动物疲劳非法")
		if not Scalars.whole(row["ban_until"], -1) or not Scalars.whole(row["qualified_until"], -1):
			return Scalars.fail("动物资格或禁工非法")
		if not ["standard", "late"].has(String(row["pattern"])):
			return Scalars.fail("动物班次非法")
		if not Scalars.whole(row["priority"], 0, 99) or not Scalars.whole(row["death_streak"], 0, 3):
			return Scalars.fail("动物优先级或濒危计数非法")
		if not row["served_once"] is bool:
			return Scalars.fail("动物服务标记非法")
		if not row["diet_id"] is String or not species_defs[sid]["base_diets"].any(func(d): return String(d["id"]) == String(row["diet_id"])):
			return Scalars.fail("动物基础餐非法")
		if not row["pending"] is Dictionary:
			return Scalars.fail("动物待生效变更非法")
		for key in row["pending"]:
			if not ["mode", "zone_uid", "bed_uid", "bed_slot", "pattern"].has(String(key)):
				return Scalars.fail("动物待生效字段非法")
		if int(row["bed_uid"]) > 0:
			if String(row["mode"]) == "work":
				return Scalars.fail("役使动物不持有全时床位")
			var bed: Dictionary = facilities.get(int(row["bed_uid"]), {})
			if bed.is_empty() or not bed_capacity_map.has(String(bed["facility_id"])):
				return Scalars.fail("动物床位指向非床设施")
			if int(row["bed_slot"]) < 0 or int(row["bed_slot"]) >= int(bed_capacity_map[String(bed["facility_id"])]):
				return Scalars.fail("动物床位序号非法")
			var key := "%d:%d" % [int(row["bed_uid"]), int(row["bed_slot"])]
			if fulltime.has(key):
				return Scalars.fail("全时床位重复占用")
			fulltime[key] = int(row["uid"])
		elif String(row["mode"]) != "work" and int(row["bed_slot"]) != 0:
			return Scalars.fail("动物床位序号非法")
		if not Scalars.exact(row["natural"], ["round", "units", "pending", "paid"]) or not Scalars.exact(row["breed"], ["round", "units", "pending"]):
			return Scalars.fail("动物周期结构非法")
		if not row["natural"]["pending"] is bool or not row["natural"]["paid"] is bool or not row["breed"]["pending"] is bool:
			return Scalars.fail("动物周期标记非法")
		if not Scalars.whole(row["natural"]["round"], 0) or not Scalars.whole(row["natural"]["units"], 0, 9999) or not Scalars.whole(row["breed"]["round"], 0) or not Scalars.whole(row["breed"]["units"], 0, 9999):
			return Scalars.fail("动物周期进度非法")
		if species_cfg.has("natural_units") and bool(row["natural"]["pending"]) == (int(row["natural"]["units"]) < int(species_cfg["natural_units"])):
			return Scalars.fail("畜产周期与待领状态不符")
		if not species_cfg.has("natural_units") and (int(row["natural"]["round"]) > 0 or int(row["natural"]["units"]) > 0 or bool(row["natural"]["pending"]) or bool(row["natural"]["paid"])):
			return Scalars.fail("无畜产物种携带周期")
		if bool(row["breed"]["pending"]) == (int(row["breed"]["units"]) < int(species_cfg["breed_units"])):
			return Scalars.fail("繁殖进度与待安置状态不符")
		if not Scalars.exact(row["account"], ["w", "r", "fails"]):
			return Scalars.fail("动物日账非法")
		for field in ["w", "r", "fails"]:
			if not Scalars.whole(row["account"][field], 0, 8):
				return Scalars.fail("动物日账数量非法")
		animal_ids[int(row["uid"])] = row
		out["animals"].append(_intified_animal(row))
	if not value["reservations"] is Array:
		return Scalars.fail("床位预约非法")
	var trough_ids := {}
	for uid in facilities:
		if String(facilities[uid]["facility_id"]) == TROUGH_ID:
			trough_ids[int(uid)] = true
	var seen_windows := {}
	for index in range(value["reservations"].size()):
		var row: Dictionary = value["reservations"][index]
		if not Scalars.exact(row, ["uid", "animal_uid", "bed_uid", "bed_slot", "trough_uid", "zone_uid", "start_t", "end_t", "meals"]):
			return Scalars.fail("预约字段非法")
		if not Scalars.whole(row["uid"], 1, int(value["next_window_uid"]) - 1) or seen_windows.has(int(row["uid"])):
			return Scalars.fail("预约序号非法")
		seen_windows[int(row["uid"])] = true
		if not animal_ids.has(int(row["animal_uid"])):
			return Scalars.fail("预约指向未知动物")
		if int(row["end_t"]) - int(row["start_t"]) != 2:
			return Scalars.fail("预约长度不是两单位")
		var bed: Dictionary = facilities.get(int(row["bed_uid"]), {})
		if bed.is_empty() or not bed_capacity_map.has(String(bed["facility_id"])):
			return Scalars.fail("预约床位非法")
		if int(row["bed_slot"]) < 0 or int(row["bed_slot"]) >= int(bed_capacity_map[String(bed["facility_id"])]):
			return Scalars.fail("预约床位序号非法")
		if not trough_ids.has(int(row["trough_uid"])):
			return Scalars.fail("预约食槽非法")
		if not zone_types.has(int(row["zone_uid"])):
			return Scalars.fail("预约指向未知功能区")
		if int(row["meals"]) < 1:
			return Scalars.fail("预约餐数非法")
		for other_index in range(index + 1, value["reservations"].size()):
			var other: Dictionary = value["reservations"][other_index]
			if _windows_overlap(int(other["start_t"]), int(row["start_t"])) and int(other["bed_uid"]) == int(row["bed_uid"]) and int(other["bed_slot"]) == int(row["bed_slot"]):
				return Scalars.fail("同一床位时段重叠")
		out["reservations"].append({"uid": int(row["uid"]), "animal_uid": int(row["animal_uid"]),
			"bed_uid": int(row["bed_uid"]), "bed_slot": int(row["bed_slot"]), "trough_uid": int(row["trough_uid"]),
			"zone_uid": int(row["zone_uid"]), "start_t": int(row["start_t"]), "end_t": int(row["end_t"]),
			"meals": int(row["meals"])})
	if not value["workyards"] is Dictionary:
		return Scalars.fail("工作场状态非法")
	var work_recipes: Dictionary = config["work"]["recipes"]
	var recipe_defs: Dictionary = catalog.definitions("recipes")
	for key in value["workyards"]:
		var uid := int(key)
		if not facilities.has(uid) or String(facilities[uid]["facility_id"]) != WORKYARD_ID:
			return Scalars.fail("工作场状态指向非工作场设施")
		var yard: Dictionary = value["workyards"][key]
		if not Scalars.exact(yard, ["recipe_id", "posts"]):
			return Scalars.fail("工作场字段非法")
		if not yard["posts"] is Array or yard["posts"].size() != int(config["work"]["posts_per_yard"]):
			return Scalars.fail("工作场岗位数非法")
		if not work_recipes.has(String(yard["recipe_id"])):
			return Scalars.fail("工作场配方非法")
		var used_batches := {}
		for post in yard["posts"]:
			if not Scalars.exact(post, ["batch_id", "recipe_id", "inputs", "outputs", "progress", "target", "status"]):
				return Scalars.fail("岗位字段非法")
			if String(post["status"]) == "idle":
				if int(post["batch_id"]) != 0 or not post["inputs"].is_empty() or not post["outputs"].is_empty() or int(post["progress"]) != 0 or int(post["target"]) != 0:
					return Scalars.fail("空闲岗位携带批次")
				continue
			if String(post["recipe_id"]) != String(yard["recipe_id"]) or not recipe_defs.has(String(post["recipe_id"])):
				return Scalars.fail("岗位配方与工作场不符")
			var target := int(work_recipes[String(post["recipe_id"])]["target"])
			if int(post["target"]) != target or not Scalars.whole(post["progress"], 0, target):
				return Scalars.fail("岗位进度或目标非法")
			if (int(post["progress"]) == target) != (String(post["status"]) == "ready"):
				return Scalars.fail("岗位达标与领取状态不符")
			if not Scalars.whole(post["batch_id"], 1, 10000000) or used_batches.has(int(post["batch_id"])):
				return Scalars.fail("岗位批次序号非法")
			used_batches[int(post["batch_id"])] = true
			var def: Dictionary = recipe_defs[String(post["recipe_id"])]
			if not _same_items(post["inputs"], def["inputs"]) or not _same_items(post["outputs"], def["outputs"]):
				return Scalars.fail("岗位批次投入产出被改写")
		out["workyards"][key] = Canonical._canonical(yard)
	if not value["births"] is Array:
		return Scalars.fail("出生凭证非法")
	var birth_pairs := {}
	for row in value["births"]:
		if not Scalars.exact(row, ["parent_uid", "round", "child_uid"]):
			return Scalars.fail("出生凭证字段非法")
		if not animal_ids.has(int(row["parent_uid"])) or not animal_ids.has(int(row["child_uid"])):
			return Scalars.fail("出生凭证指向未知动物")
		var pair := "%d:%d" % [int(row["parent_uid"]), int(row["round"])]
		if birth_pairs.has(pair):
			return Scalars.fail("出生凭证重复")
		birth_pairs[pair] = true
		if int(row["round"]) >= int(animal_ids[int(row["parent_uid"])]["breed"]["round"]):
			return Scalars.fail("出生凭证轮次超出亲体进度")
		out["births"].append({"parent_uid": int(row["parent_uid"]), "round": int(row["round"]), "child_uid": int(row["child_uid"])})
	if not value["day"] is Dictionary or not Scalars.whole(value["day"]["day"], -1):
		return Scalars.fail("畜牧日账非法")
	if not value["day"]["accounts"] is Dictionary:
		return Scalars.fail("畜牧日账名册非法")
	for uid in value["day"]["accounts"]:
		if not animal_ids.has(int(uid)):
			return Scalars.fail("畜牧日账指向未知动物")
	var day_accounts := {}
	for uid in value["day"]["accounts"]:
		var account: Dictionary = value["day"]["accounts"][uid]
		day_accounts[int(uid)] = {"w": int(account["w"]), "r": int(account["r"]), "fails": int(account["fails"])}
	out["day"] = {"day": int(value["day"]["day"]), "accounts": day_accounts}
	return {"ok": true, "ranch": out}
