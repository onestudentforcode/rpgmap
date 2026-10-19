extends RefCounted
## P10.3/P10.5 terrestrial ranch: a nine-species animal roster, six floor zone
## types with shared space, bed-slot reservations, the eight-unit inner clock
## with whole-window maintenance, fixed work bans, day-opening fatigue, facility
## work posts and asexual breeding. Adults pick one use at a time — breeding in
## the enclosure, body-material rounds in the intensive zone, yard work in the
## work zone — and the ranch species never enter the per-day V2 habitat path.
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")

const SPECIES := ["steel_sheep", "rock_mole", "rock_belly_beast", "carbon_belly_bug", "leaf_silkworm",
	"dew_shell_snail", "mineral_scale_lizard", "compost_mouse", "gravel_shell_snail",
	"filter_algae_carp", "oilfin_fish", "pearl_mussel", "gel_jellyfish", "silt_loach", "reef_coral"]
const WATER_MODES := ["water_nursery", "water_enclosure", "water_production", "water_loach"]
const ZONE_TYPES := ["nursery", "enclosure", "intensive", "work", "maintenance", "pasture",
	"water_nursery", "water_enclosure", "water_production", "water_loach", "aqua_planting"]
const BED_TYPES := {"small_bed": "small", "medium_bed": "medium", "large_bed": "large"}
const PEN_ID := "pen"
const DISPATCH_ID := "dispatch_station"
const TROUGH_ID := "feed_trough"
const CARE_ID := "care_table"
## Ranch facilities must stand on ordinary floor; beds count as usable space.
const FLOOR_FACILITIES := [PEN_ID, "rock_breaking_yard", "ore_sorting_yard", "carbonization_nest",
	"compost_mouse_den", "shell_forming_station", DISPATCH_ID, TROUGH_ID, "small_bed", "medium_bed",
	"large_bed", CARE_ID, "wool_station", "silkworm_rack", "spirit_liquid_collector", "scale_station"]
const ANIMAL_KEYS := ["uid", "species_id", "stage", "growth", "mode", "zone_uid", "bed_uid", "bed_slot",
	"pending", "diet_id", "pattern", "priority", "fatigue", "ban_until", "qualified_until",
	"served_once", "natural", "breed", "death_streak", "account",
	"anchor", "miss_streak", "bad_water_streak"]

## Structural ranch facilities never create V2 habitat rows: the pen, the five
## species yards and the four intensive stations. One registry shared by the
## snapshot filter, husbandry and the world build hook.
static func structural_facility_ids(catalog) -> Array:
	var config: Dictionary = catalog.load_data()["p103"]
	var out := [PEN_ID]
	for fid in config["work"]["facilities"]:
		out.append(String(fid))
	for fid in config["stations"]:
		out.append(String(fid))
	return out

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

func species_medium(species_id: String) -> String:
	return String(species_config(species_id).get("medium", "land"))

func is_fixed_species(species_id: String) -> bool:
	return bool(species_config(species_id).get("fixed", false))

## Shared quality of the body behind the animal's zone; empty when the zone
## lost its body (treated as failing water).
func _body_of(row: Dictionary) -> Dictionary:
	var zone_row := zone(int(row["zone_uid"]))
	if zone_row.is_empty():
		return {}
	return world.water.body(int(zone_row.get("body_uid", 0)))

func water_ok(row: Dictionary) -> bool:
	var body := _body_of(row)
	return world.water.quality_ok(body)

## Sum of live aquatic space weights assigned to zones of this body.
func water_load(body_uid: int) -> int:
	var total := 0
	for row in state["animals"]:
		var sid := String(row["species_id"])
		if species_medium(sid) != "water":
			continue
		var zone_row := zone(int(row["zone_uid"]))
		if zone_row.is_empty() or int(zone_row.get("body_uid", 0)) != body_uid:
			continue
		total += int(species_config(sid)["space"])
	return total

## Free fixed-anchor cells in a zone: unblocked by facilities (beds never
## block) and not held by another fixed animal.
func _free_anchor_cells(zone_row: Dictionary, ignore_animal := 0) -> Array:
	var blocked := {}
	for uid in world.facilities:
		if is_bed(String(world.facilities[uid]["facility_id"])):
			continue
		for cell in facility_footprint(world.facilities[uid]):
			blocked["%d,%d" % [cell.x, cell.y]] = true
	var taken := {}
	for row in state["animals"]:
		if int(row["uid"]) == ignore_animal or String(row["anchor"]).is_empty():
			continue
		taken[String(row["anchor"])] = true
	var out: Array = []
	for text in zone_row["cells"]:
		if not blocked.has(String(text)) and not taken.has(String(text)):
			out.append(String(text))
	out.sort()
	return out

# --- static queries -----------------------------------------------------------

func species_config(species_id: String) -> Dictionary:
	return settings["species"].get(species_id, {})

func can_breed(species_id: String) -> bool:
	var config := species_config(species_id)
	return not config.is_empty() and bool(config.get("breedable", true)) and config.has("breed_units")

func natural_config(species_id: String) -> Dictionary:
	return species_config(species_id).get("natural", {})

func is_work_facility(facility_id: String) -> bool:
	return settings["work"]["facilities"].has(facility_id)

func is_station(facility_id: String) -> bool:
	return settings["stations"].has(facility_id)

func is_structural(facility_id: String) -> bool:
	return facility_id == PEN_ID or is_work_facility(facility_id) or is_station(facility_id)

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
	var zone_config: Dictionary = settings["zones"][zone_row["type"]]
	var required: Array = zone_config["structures"]
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
	# any_of groups: at least one member facility must stand in the zone. A
	# missing group never blocks the shared pen/bed/trough services.
	for group in zone_config.get("any_of", []):
		var found := false
		for member in group["members"]:
			if present.has(String(member)):
				found = true
				break
		if not found:
			missing.append(String(group["id"]))
	return missing

func zone_structural(zone_row: Dictionary) -> bool:
	if not structure_missing(zone_row).is_empty(): return false
	if available_space(zone_row)<int(settings["zones"][zone_row["type"]]["min_space"]): return false
	if zone_medium(String(zone_row["type"])) == "water":
		# Water zones qualify through fence membership of their one body, not
		# through ordinary floor paving.
		var body: Dictionary = world.water.body(int(zone_row.get("body_uid", 0)))
		if body.is_empty(): return false
		for text in zone_row["cells"]:
			if int(world.water.state["fences"].get(String(text), 0)) != int(body["uid"]):
				return false
		return true
	for text in zone_row["cells"]:
		if world.rooms.floor_kind(_cell_of(text))!="ordinary": return false
	return true

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
	return preload("res://scripts/farming/p8/room_geometry.gd").connected(cells)

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
	return {"anchor": String(row.get("anchor", "")), "miss_streak": int(row.get("miss_streak", 0)),
		"bad_water_streak": int(row.get("bad_water_streak", 0)),
		"uid": int(row["uid"]), "species_id": String(row["species_id"]), "stage": String(row["stage"]),
		"growth": int(row["growth"]), "mode": String(row["mode"]), "zone_uid": int(row["zone_uid"]),
		"bed_uid": int(row["bed_uid"]), "bed_slot": int(row["bed_slot"]), "pending": pending,
		"diet_id": String(row["diet_id"]), "pattern": String(row["pattern"]), "priority": int(row["priority"]),
		"fatigue": int(row["fatigue"]), "ban_until": int(row["ban_until"]), "qualified_until": int(row["qualified_until"]),
		"served_once": bool(row["served_once"]),
		"natural": {"round": int(row["natural"]["round"]), "units": int(row["natural"]["units"]),
			"pending": bool(row["natural"]["pending"]), "paid": bool(row["natural"]["paid"]),
			"diet_id": String(row["natural"].get("diet_id", ""))},
		"breed": {"round": int(row["breed"]["round"]), "units": int(row["breed"]["units"]), "pending": bool(row["breed"]["pending"])},
		"death_streak": int(row["death_streak"]),
		"account": {"w": int(account["w"]), "r": int(account["r"]), "fails": int(account["fails"])}}

## Zone medium comes from the zone config: land zones stand on ordinary
## floor, water zones on fish-fence cells of exactly one water body.
func zone_medium(type_id: String) -> String:
	return String(settings["zones"].get(type_id, {}).get("medium", "land"))

func _zone_cells_free(cells: Array, ignore_zone := -1, medium := "land", body_uid := 0) -> String:
	for text in cells:
		var cell := _cell_of(String(text))
		if not world.grid.in_bounds(cell.x, cell.y):
			return "地格越界"
		if not world.land.contains(cell):
			return "地格不在已购地块内"
		if medium == "water":
			var owner: Dictionary = world.water.body_of(cell)
			if owner.is_empty():
				return "水功能区的地格必须先铺鱼栅"
			if body_uid > 0 and int(owner["uid"]) != body_uid:
				return "功能区不能跨越多个水体"
		elif world.rooms.floor_kind(cell) != "ordinary":
			return "功能区只能铺设在普通地板上"
		if not world.rooms.field_at(cell).is_empty():
			return "地格仍属于农业田块，请先编辑田块边界"
		for other in state["zones"]:
			if int(other["uid"]) == ignore_zone:
				continue
			if other["cells"].has(String(text)):
				return "地格已属于其他功能区"
	return ""

## The single body a water zone claim belongs to; 0 = none (invalid for water).
func _zone_body(cells: Array) -> int:
	var first := 0
	for text in cells:
		var owner: Dictionary = world.water.body_of(_cell_of(String(text)))
		if owner.is_empty():
			return 0
		if first == 0:
			first = int(owner["uid"])
		elif int(owner["uid"]) != first:
			return 0
	return first

func preview_zone(type_id: String, cells: Array) -> Dictionary:
	if not ZONE_TYPES.has(type_id):
		return _error("未知功能区类型")
	if cells.is_empty():
		return _error("没有选择地格")
	var medium := zone_medium(type_id)
	var body_uid := 0
	if medium == "water":
		body_uid = _zone_body(cells)
		if body_uid == 0:
			return _error("水功能区的地格必须同属一个已铺鱼栅的水体")
	var problem := _zone_cells_free(cells, -1, medium, body_uid)
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
	return {"nursery": "育幼区", "enclosure": "繁殖区", "intensive": "精养区", "work": "工作区",
		"maintenance": "维持放牧区", "pasture": "额外放牧区", "water_nursery": "育幼池",
		"water_enclosure": "繁殖池", "water_production": "生产池", "water_loach": "泥鳅净化区",
		"aqua_planting": "水生种植区"}[type_id]

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
		"cells": cells.duplicate(), "dispatch_uid": 0, "birth_target": 0, "body_uid": _zone_body(cells)})
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
	for other in state["zones"]:
		if int(other["birth_target"])==zone_uid: other["birth_target"]=0
	world.services.forget_zone(zone_uid)
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
		if row.is_empty() or not ["enclosure", "water_enclosure"].has(String(row["type"])):
			return _error("只有繁殖区可以选择育幼区")
		var nursery_type := "water_nursery" if String(row["type"]) == "water_enclosure" else "nursery"
		var nursery := zone(int(targets[zone_uid]))
		if nursery.is_empty() or String(nursery["type"]) != nursery_type:
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
	if not (["waiting", "nursery", "enclosure", "intensive", "work"] + WATER_MODES).has(mode):
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
		var water_zone: bool = WATER_MODES.has(mode)
		if (species_medium(String(row["species_id"])) == "water") != water_zone:
			return "水陆物种与功能区介质不符"
		if mode in ["enclosure", "intensive", "work", "water_enclosure", "water_production", "water_loach"] and String(row["stage"]) != "adult":
			return "只有成体可以进入该功能区"
		if mode == "enclosure" and not can_breed(String(row["species_id"])):
			return "该物种本期不能繁殖，不能进入繁殖区"
		if mode == "water_enclosure" and not can_breed(String(row["species_id"])):
			return "该物种本期不能繁殖，不能进入繁殖区"
		if water_zone and not zone_medium(String(target["type"])) == "water":
			return "目标功能区不是水域"
		if mode != "waiting" and is_fixed_species(String(row["species_id"])) and _free_anchor_cells(target, int(row["uid"])).is_empty():
			return "目标功能区没有空余固定格"
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
	if is_fixed_species(String(row["species_id"])):
		return _error("固定物种的休息资格由其固定格提供")
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
	var nursery_type := "water_nursery" if species_medium(species_id) == "water" else "nursery"
	if zone_row.is_empty() or String(zone_row["type"]) != nursery_type:
		return _error("请选择一个结构合格的育幼区" if nursery_type == "nursery" else "请选择一个结构合格的育幼池")
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
	var beds: Array = []
	var anchors: Array = []
	if is_fixed_species(species_id):
		anchors = _free_anchor_cells(zone_row)
		if anchors.size() < count:
			return _error("固定格不足：需%d，空余%d" % [count, anchors.size()])
	else:
		beds = free_bed_slots(zone_row, String(species_config(species_id)["bed"]))
		if beds.size() < count:
			return _error("适配床位不足：需%d，空余%d" % [count, beds.size()])
	var space := int(species_config(species_id)["space"])
	if _zone_usage(zone_row) + space * count > available_space(zone_row):
		return _error("育幼区空间不足")
	return {"ok": true, "total": int(species["juvenile_price"]) * count,
		"beds": beds.slice(0, count), "anchors": anchors.slice(0, count)}

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
		var bed_uid := 0
		var bed_slot := 0
		var anchor := ""
		if is_fixed_species(species_id):
			anchor = String(quote["anchors"][index])
		else:
			var bed: Dictionary = quote["beds"][index]
			bed_uid = int(bed["uid"])
			bed_slot = int(bed["slot"])
		state["animals"].append(_new_animal(uid, species_id, zone_uid,
			bed_uid, bed_slot, String(species["default_base_diet"]), anchor))
		bought.append(uid)
	_record("animal", "purchase", {"zone": zone_uid, "species": species_id, "count": count, "total": total, "animals": bought})
	world._report_event({"category": "purchase", "facility_uid": 0, "kind": species_id, "count": count,
		"items": {}, "note": "购入%d只幼体，花费%d元石" % [count, total]})
	return world._finish(0, {"ok": true, "purchased": bought, "total": total, "species_id": species_id})

func _new_animal(uid: int, species_id: String, zone_uid: int, bed_uid: int, bed_slot: int, diet_id: String, anchor := "") -> Dictionary:
	var natural_diet := String(natural_config(species_id).get("default_diet", ""))
	return {"uid": uid, "species_id": species_id, "stage": "juvenile", "growth": 0,
		"mode": "water_nursery" if species_medium(species_id) == "water" else "nursery",
		"zone_uid": zone_uid, "bed_uid": bed_uid, "bed_slot": bed_slot,
		"pending": {}, "diet_id": diet_id, "pattern": "standard", "priority": 0,
		"fatigue": 0, "ban_until": -1, "qualified_until": -1, "served_once": false,
		"natural": {"round": 0, "units": 0, "pending": false, "paid": false, "diet_id": natural_diet},
		"breed": {"round": 0, "units": 0, "pending": false},
		"death_streak": 0, "account": {"w": 0, "r": 0, "fails": 0},
		"anchor": anchor, "miss_streak": 0, "bad_water_streak": 0}

# --- work yards ---------------------------------------------------------------

func workyard_state(facility_uid: int) -> Dictionary:
	var key := str(facility_uid)
	if not state["workyards"].has(key):
		state["workyards"][key] = peek_workyard(facility_uid)
	return state["workyards"][key]

func peek_workyard(facility_uid: int) -> Dictionary:
	if state["workyards"].has(str(facility_uid)): return state["workyards"][str(facility_uid)].duplicate(true)
	var facility: Dictionary = world.facilities.get(facility_uid, {})
	var recipes: Array = settings["work"]["facilities"].get(String(facility.get("facility_id", "")), [])
	var posts:=[]
	for _index in range(int(settings["work"]["posts_per_yard"])): posts.append(_idle_post())
	return {"recipe_id": String(recipes[0]) if not recipes.is_empty() else "", "posts": posts}

func _idle_post() -> Dictionary:
	return {"batch_id": 0, "recipe_id": "", "inputs": {}, "outputs": {}, "progress": 0, "target": 0, "status": "idle"}

func set_recipe(facility_uid: int, recipe_id: String) -> Dictionary:
	if world.services.has_carry(facility_uid): return _error("请先明确放弃原配方工作余量，再切换配方")
	var facility: Dictionary = world.facilities.get(facility_uid, {})
	var facility_id := String(facility.get("facility_id", ""))
	if facility.is_empty() or not is_work_facility(facility_id):
		return _error("未知役使设施")
	if not settings["work"]["facilities"][facility_id].has(recipe_id):
		return _error("该工艺不属于此设施")
	if not settings["work"]["recipes"].has(recipe_id):
		return _error("未知劳动配方")
	var yard := workyard_state(facility_uid)
	for post in yard["posts"]:
		if String(post["status"]) != "idle":
			return _error("有运行中批次的设施不能更换配方")
	var blocked: String = world.research_block(String(world.recipe_defs[recipe_id].get("research", "")))
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
	if facility.is_empty() or not is_work_facility(String(facility["facility_id"])):
		return _error("未知役使设施")
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

# --- intensive rounds and births ----------------------------------------------

## Round-feed variant choice (0 AP). Changing a paid round only affects the
## next one: the current round keeps its locked inputs.
func set_natural_diet(animal_uid: int, diet_id: String) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	var row := animal(animal_uid)
	if row.is_empty():
		return _error("未知动物")
	if natural_config(String(row["species_id"])).is_empty():
		return _error("该物种没有本体生产轮")
	var species: Dictionary = world.husbandry.species_def(String(row["species_id"]))
	for diet in species["special_diets"]:
		if String(diet["id"]) == diet_id:
			var blocked: String = world.research_block(String(diet.get("research", "")))
			if not blocked.is_empty():
				return _error(blocked)
			if String(row["natural"]["diet_id"]) == diet_id:
				return _error("没有实际变更")
			row["natural"]["diet_id"] = diet_id
			_record("natural", "diet", {"animal": animal_uid, "diet": diet_id,
				"effective": "next_round" if bool(row["natural"]["paid"]) else "this_round"})
			world.changed.emit()
			return {"ok": true}
	return _error("该物种没有这份补料")

## Body-material rights live on the animal and are claimed through the species
## station of the intensive zone it currently occupies.
func claim_natural(facility_uid: int) -> Dictionary:
	var facility: Dictionary = world.facilities.get(facility_uid, {})
	var facility_id := String(facility.get("facility_id", ""))
	if facility.is_empty() or not is_station(facility_id):
		return _error("请从精养台的专属领取入口领取")
	var station_species := String(settings["stations"][facility_id]["species"])
	var production_type := "water_production" if species_medium(station_species) == "water" else "intensive"
	var zone_row := {}
	for row in state["zones"]:
		if String(row["type"]) != production_type:
			continue
		for inside in _facilities_in_zone(row):
			if int(inside["uid"]) == facility_uid:
				zone_row = row
	if zone_row.is_empty():
		return _error("该设施不在精养区内")
	var outputs := {}
	var payers := []
	var captures := []
	for row in animals_in_zone(int(zone_row["uid"]), [production_type]):
		if String(row["species_id"]) != station_species or not bool(row["natural"]["pending"]):
			continue
		for item in natural_config(station_species)["outputs"]:
			var amount := int(natural_config(station_species)["outputs"][item])
			if not Scalars.whole(world.inventory.count(String(item)) + int(outputs.get(String(item), 0)) + amount):
				return _error("输出库存越界：" + String(world._items[String(item)]["name"]))
			outputs[String(item)] = int(outputs.get(String(item), 0)) + amount
		payers.append(int(row["uid"]))
	if payers.is_empty():
		return _error("没有待领取的精养产物")
	var capture := bool(natural_config(station_species).get("capture", false))
	for uid in payers:
		var row := animal(int(uid))
		var natural: Dictionary = row["natural"]
		if capture:
			captures.append(uid)
			continue
		natural["round"] = int(natural["round"]) + 1
		natural["units"] = 0
		natural["pending"] = false
		natural["paid"] = false
	for item in outputs:
		world.inventory.add(String(item), int(outputs[item]))
	world._record_flow(outputs, {}, "精养畜产领取")
	if not captures.is_empty():
		# Capture rounds consume the animal in the same transaction as the
		# payout; pending staged moves die with it.
		for uid in captures:
			state["animals"].erase(animal(int(uid)))
	_record("natural", "claim", {"station": facility_uid, "zone": int(zone_row["uid"]),
		"animals": payers, "captures": captures.duplicate(), "outputs": outputs.duplicate()})
	if not captures.is_empty():
		_record("natural", "capture", {"station": facility_uid, "animals": captures.duplicate(),
			"outputs": outputs.duplicate()})
	return world._finish(int(settings["ap"]["claim_products"]), {"ok": true, "items": outputs.duplicate(),
		"animals": payers.size(), "captures": captures.size()})

## Mussel shell harvest (§16.2.6): claims any pending pearls first, voids an
## in-progress round without refund, then removes the adult for mussel_shell.
func harvest_shell(animal_uid: int) -> Dictionary:
	var row := animal(animal_uid)
	if row.is_empty():
		return _error("未知动物")
	if String(row["species_id"]) != "pearl_mussel":
		return _error("只有珍珠蚌可以取壳")
	if String(row["stage"]) != "adult" or String(row["mode"]) != "water_production":
		return _error("只有在生产池的成年珍珠蚌可以取壳")
	var zone_row := zone(int(row["zone_uid"]))
	var station_uid := 0
	for facility in _facilities_in_zone(zone_row):
		if String(facility["facility_id"]) == "pearl_station":
			station_uid = int(facility["uid"])
	if station_uid == 0:
		return _error("生产池内没有采珠台")
	var checked: Dictionary = world._can_act(1)
	if not checked["ok"]:
		return checked
	var outputs := {"mussel_shell": 2}
	var natural: Dictionary = row["natural"]
	if bool(natural["pending"]):
		outputs["pearl"] = int(natural_config("pearl_mussel")["outputs"].get("pearl", 2))
	if not Scalars.whole(world.inventory.count("mussel_shell") + int(outputs["mussel_shell"])):
		return _error("输出库存越界：贝壳")
	for item in outputs:
		world.inventory.add(String(item), int(outputs[item]))
	world._record_flow(outputs, {}, "珍珠蚌取壳")
	state["animals"].erase(row)
	_record("shell", "harvest", {"animal": animal_uid, "station": station_uid,
		"round": int(natural["round"]), "voided_units": int(natural["units"]), "outputs": outputs.duplicate()})
	return world._finish(1, {"ok": true, "items": outputs.duplicate(), "animal": animal_uid})

func claim_births(zone_uid: int) -> Dictionary:
	var zone_row := zone(zone_uid)
	if zone_row.is_empty() or not ["enclosure", "water_enclosure"].has(String(zone_row["type"])):
		return _error("请从繁殖区领取待安置幼体")
	var nursery_type := "water_nursery" if String(zone_row["type"]) == "water_enclosure" else "nursery"
	var nursery := zone(int(zone_row["birth_target"]))
	if nursery.is_empty() or String(nursery["type"]) != nursery_type:
		return _error("请先为该繁殖区选择有效的目标育幼区")
	if not zone_structural(nursery):
		return _error("目标育幼区结构缺件：" + "、".join(structure_missing(nursery)))
	# Preflight the entire batch. A later missing bed must not leave an earlier
	# parent claimed without AP or a successful transaction.
	var plans := []
	var reserved := []
	var reserved_anchors := []
	var remaining := available_space(nursery)-_zone_usage(nursery)
	for parent in animals_in_zone(zone_uid, ["enclosure", "water_enclosure"]):
		if not bool(parent["breed"]["pending"]): continue
		var species: Dictionary=species_config(String(parent["species_id"]))
		var chosen: Dictionary={}
		var anchor := ""
		if is_fixed_species(String(parent["species_id"])):
			for cell in _free_anchor_cells(nursery):
				if not reserved_anchors.has(cell):
					anchor=cell;reserved_anchors.append(cell);break
			if anchor.is_empty(): return _error("目标育幼区没有空余固定格，整批未安置")
		else:
			var beds:=free_bed_slots(nursery,String(species["bed"]))
			for bed in beds:
				var key:="%d:%d" % [bed["uid"],bed["slot"]]
				if not key in reserved: chosen=bed;reserved.append(key);break
			if chosen.is_empty(): return _error("目标育幼区没有适配床位，整批未安置")
		remaining-=int(species["space"])
		if remaining<0: return _error("目标育幼区空间不足，整批未安置")
		plans.append({"animal":parent,"bed":chosen,"anchor":anchor})
	var born := []
	for plan in plans:
		var row: Dictionary=plan["animal"]
		var sid := String(row["species_id"])
		var child := int(state["next_animal_uid"])
		state["next_animal_uid"] = child + 1
		var newborn:=_new_animal(child,sid,int(nursery["uid"]),int(plan["bed"].get("uid",0)),int(plan["bed"].get("slot",0)),String(world.husbandry.species_def(sid)["default_base_diet"]),String(plan.get("anchor","")))
		world.services.birth_bonus(row,newborn,int(nursery["uid"]))
		state["animals"].append(newborn)
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
	world.services.begin_day(day)
	var out := {"animals": {}, "windows": [], "conflicts": []}
	var day0 := day * 8
	var shadow := {}
	var active := {}
	var window_rows: Array = state["reservations"].duplicate(true)
	var counter := int(state["next_window_uid"])
	var pasture_use := {}
	var post_taken := {}
	var station_use := {}
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
			var activity := _unit_activity(row, u, t, String(pattern_of(row)[u]), mutate, shadow, post_taken, pasture_use, station_use, accounts)
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
		world.services.end_day()
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
	var species_cfg: Dictionary = species_config(String(row["species_id"]))
	var fixed := bool(species_cfg.get("fixed", false))
	var facility: Dictionary = {}
	if fixed:
		# Fixed species rest on their anchor cell inside the zone.
		if String(row["anchor"]).is_empty() or not zone_row["cells"].has(String(row["anchor"])):
			record["failed"] = true
			record["reason"] = "固定栖息格缺失"
			out["conflicts"].append({"animal": int(row["uid"]), "t": t, "kind": "anchor_missing"})
			return record
	else:
		facility = world.facilities.get(int(row["bed_uid"]), {})
		if facility.is_empty() or bed_type_of(String(facility["facility_id"])) != String(species_cfg["bed"]) or not _facilities_in_zone(zone_row).has(facility):
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
	record["bed_uid"] = 0 if fixed else int(facility["uid"])
	record["bed_slot"] = 0 if fixed else int(row["bed_slot"])
	record["trough_uid"] = trough_uid
	record["zone_uid"] = int(zone_row["uid"])
	var bed_row: Dictionary = {} if fixed else facility
	window_rows.append(_reservation_row(counter, row, bed_row, record["bed_slot"], trough_uid, int(zone_row["uid"]), t, mutate))
	_record("window", "start", {"animal": int(row["uid"]), "t": t, "bed": record["bed_uid"],
		"slot": record["bed_slot"], "trough": trough_uid, "zone": int(zone_row["uid"]), "meals": int(record["meals"])})
	out["windows"].append({"animal": int(row["uid"]), "start": t, "end": t + 2, "ok": true})
	return record

func _reservation_row(counter: int, row: Dictionary, facility: Dictionary, slot: int, trough_uid: int, zone_uid: int, t: int, mutate: bool) -> Dictionary:
	if mutate:
		state["next_window_uid"] = maxi(int(state["next_window_uid"]), counter + 1)
	var bed_uid := 0
	if not facility.is_empty():
		bed_uid = int(facility["uid"])
	return {"uid": counter + 1, "animal_uid": int(row["uid"]), "bed_uid": bed_uid,
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
	var fixed := is_fixed_species(String(row["species_id"]))
	var bed: Dictionary = {} if fixed else world.facilities.get(int(record["bed_uid"]), {})
	var trough: Dictionary = world.facilities.get(int(record["trough_uid"]), {})
	var meals := int(record["meals"])
	var inputs: Dictionary = world.husbandry.diet_inputs(String(row["species_id"]), "base_diets", String(row["diet_id"]))
	var scaled := {}
	for item in inputs:
		scaled[String(item)] = int(inputs[item]) * meals
	var broken := zone_row.is_empty() or (bed.is_empty() and not fixed) or trough.is_empty() or not zone_structural(zone_row)
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
	world.services.mark_maintained(int(row["uid"]),int(record["zone_uid"]),t)
	row["served_once"] = true
	row["qualified_until"] = t + 8
	_record("window", "success", {"animal": int(row["uid"]), "t": t, "inputs": scaled.duplicate(), "qualified_until": t + 8})
	out["windows"].append({"animal": int(row["uid"]), "end": t, "result": "success", "inputs": scaled.duplicate()})

func _fail_window(row: Dictionary, reason: String, t: int, account: Dictionary, mutate: bool, out: Dictionary) -> void:
	world.services.record("maintenance_fail",{"animal":int(row["uid"]),"t":t})
	account["fails"] = int(account["fails"]) + 1
	row["ban_until"] = maxi(int(row["ban_until"]), t + 8)
	row["qualified_until"] = mini(int(row["qualified_until"]), t)
	if mutate:
		world._report_event({"category": "maintenance", "facility_uid": 0, "kind": "维持失败",
			"count": 1, "items": {}, "note": "%s（禁工至单位%d）" % [reason, t + 8]})
	_record("window", "fail", {"animal": int(row["uid"]), "t": t, "reason": reason, "ban_until": t + 8})
	out["windows"].append({"animal": int(row["uid"]), "end": t, "result": "fail", "reason": reason})

func _unit_activity(row: Dictionary, u: int, t: int, symbol: String, mutate: bool, shadow: Dictionary, post_taken: Dictionary, pasture_use: Dictionary, station_use: Dictionary, accounts: Dictionary) -> String:
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
			if WATER_MODES.has(mode) and not water_ok(row):
				_record("water", "pause", {"animal": int(row["uid"]), "t": t, "mode": mode,
					"quality": world.water.quality(_body_of(row))})
				return "water_pause"
			if mode == "nursery" and String(row["stage"]) == "juvenile":
				var before:=int(row["growth"])
				row["growth"] = mini(int(species_config(String(row["species_id"]))["growth_units"]), int(row["growth"]) + int(world.services.config["precision"]))
				world.services.record("growth",{"animal":int(row["uid"]),"before":before,"after":int(row["growth"]),"target":int(species_config(String(row["species_id"]))["growth_units"]),"t":t})
			elif mode == "water_nursery" and String(row["stage"]) == "juvenile":
				var before0:=int(row["growth"])
				row["growth"] = mini(int(species_config(String(row["species_id"]))["growth_units"]), int(row["growth"]) + int(world.services.config["precision"]))
				world.services.record("growth",{"animal":int(row["uid"]),"before":before0,"after":int(row["growth"]),"target":int(species_config(String(row["species_id"]))["growth_units"]),"t":t})
			elif mode == "enclosure" and String(row["stage"]) == "adult":
				_enclosure_care(row, t, mutate, shadow)
			elif mode == "water_enclosure" and String(row["stage"]) == "adult":
				_enclosure_care(row, t, mutate, shadow)
			elif mode == "intensive" and String(row["stage"]) == "adult":
				_intensive_care(row, t, mutate, shadow, station_use)
			elif mode == "water_production" and String(row["stage"]) == "adult":
				_intensive_care(row, t, mutate, shadow, station_use)
			elif mode == "water_loach" and String(row["stage"]) == "adult":
				_loach_service(row, t, mutate, shadow, station_use)
			account["r"] = int(account["r"]) + 1
			world.services.record("activity",{"animal":int(row["uid"]),"t":t,"zone":int(row["zone_uid"]),"activity":"care"})
			return "care"
	return "idle"

## Enclosure adults only breed: the old dual wool-plus-breed path is gone and
## body materials now advance exclusively in the intensive zone.
func _enclosure_care(row: Dictionary, t: int, mutate: bool, _shadow: Dictionary) -> void:
	var config := species_config(String(row["species_id"]))
	var breed: Dictionary = row["breed"]
	if not bool(breed["pending"]) and int(row["fatigue"]) == 0:
		var source: Dictionary=world.services.gu_service(row,"breed_speed",t)
		var before:=int(breed["units"])
		var increment:=mini(int(config["breed_units"])-before,100 if source.is_empty() else int(source["value"]))
		breed["units"] = before+increment
		world.services.record("breed_progress",{"identity":"%d:%d" % [row["uid"],breed["round"]],"before":before,"points":increment,"after":int(breed["units"]),"target":int(config["breed_units"]),"t":t,"source":source.duplicate()})
		world.services.breed_advance(row,t,increment)
		if int(breed["units"]) >= int(config["breed_units"]):
			breed["pending"] = true
			_record("breed", "ready", {"animal": int(row["uid"]), "round": int(breed["round"])})
			if mutate:
				world._report_event({"category": "growth", "facility_uid": 0, "kind": "待安置幼体",
					"count": 1, "items": {}, "note": "请在繁殖区领取并选择育幼区"})

## One intensive station serves up to `capacity` space per care unit; a heavier
## animal consumes its full space weight. Stable by facility UID.
func _station_service(row: Dictionary, t: int, station_use: Dictionary) -> int:
	var sid := String(row["species_id"])
	var natural: Dictionary = natural_config(sid)
	if natural.is_empty():
		return 0
	var station_id := String(natural["station"])
	var zone_row := zone(int(row["zone_uid"]))
	var wanted := "water_production" if species_medium(String(row["species_id"])) == "water" else "intensive"
	if zone_row.is_empty() or String(zone_row["type"]) != wanted:
		return 0
	var weight := int(species_config(sid)["space"])
	var capacity := int(settings["stations"][station_id]["capacity"])
	for facility in _facilities_in_zone(zone_row):
		if String(facility["facility_id"]) != station_id:
			continue
		var key := "%d:%d" % [int(facility["uid"]), t]
		if int(station_use.get(key, 0)) + weight > capacity:
			continue
		station_use[key] = int(station_use.get(key, 0)) + weight
		return int(facility["uid"])
	return 0

## Intensive care: opening-day efficiency gates the round (100/75/50/0), the
## round feed is paid once on the first advancing unit, soothing gu never
## multiplies body-material progress.
func _intensive_care(row: Dictionary, t: int, mutate: bool, shadow: Dictionary, station_use: Dictionary) -> void:
	var sid := String(row["species_id"])
	var config: Dictionary = natural_config(sid)
	if config.is_empty():
		return
	var natural: Dictionary = row["natural"]
	if bool(natural["pending"]):
		return
	var station_uid := _station_service(row, t, station_use)
	if station_uid == 0:
		world.services.record("natural_wait", {"animal": int(row["uid"]), "t": t})
		return
	var efficiency := int(fatigue_tier(int(row["fatigue"]))["efficiency"])
	if efficiency <= 0:
		world.services.record("natural_stall", {"animal": int(row["uid"]), "t": t, "efficiency": 0, "station": station_uid})
		return
	if not bool(natural["paid"]):
		var diet_id := String(natural["diet_id"])
		var diet: Dictionary = world.husbandry.diet_inputs(sid, "special_diets", diet_id)
		if diet.is_empty():
			world.services.record("natural_wait", {"animal": int(row["uid"]), "t": t})
			return
		var enough := true
		for item in diet:
			if _shadow_count(String(item), shadow) < int(diet[item]):
				enough = false
		if not enough:
			world.services.record("natural_short", {"animal": int(row["uid"]), "t": t, "station": station_uid})
			return
		if mutate:
			for item in diet:
				world.inventory.remove(String(item), int(diet[item]))
			world._record_flow({}, diet, "精养开轮投料")
		else:
			_shadow_spend(diet, shadow)
		natural["paid"] = true
		_record("natural", "round_start", {"animal": int(row["uid"]), "round": int(natural["round"]),
			"diet": diet_id, "inputs": diet.duplicate(), "station": station_uid})
	var target := int(config["units"])
	var gain := efficiency * int(world.services.config["precision"]) / 100
	var before := int(natural["units"])
	natural["units"] = mini(target, before + gain)
	world.services.record("natural_progress", {"identity": "%d:%d" % [int(row["uid"]), int(natural["round"])],
		"animal": int(row["uid"]), "before": before, "points": int(natural["units"]) - before, "after": int(natural["units"]),
		"target": target, "t": t, "efficiency": efficiency, "station": station_uid, "species": sid})
	if int(natural["units"]) >= target and not bool(natural["pending"]):
		natural["pending"] = true
		_record("natural", "ready", {"animal": int(row["uid"]), "round": int(natural["round"]),
			"outputs": config["outputs"].duplicate()})
		if mutate:
			world._report_event({"category": "growth", "facility_uid": station_uid, "kind": "精养畜产待领取",
				"count": 1, "items": config["outputs"].duplicate(), "note": "请到专属精养台领取"})

## Loach processing (§16.2.6): the animal serves a facility post on care
## units; progress is full-width because aquatic species carry no fatigue.
func _loach_service(row: Dictionary, t: int, mutate: bool, shadow: Dictionary, _station_use: Dictionary) -> void:
	var zone_row := zone(int(row["zone_uid"]))
	if zone_row.is_empty() or not zone_structural(zone_row):
		return
	var yards: Array = _facilities_in_zone(zone_row).filter(func(f): return is_work_facility(String(f["facility_id"])))
	for yard in yards:
		var yard_state := workyard_state(int(yard["uid"]))
		var recipe_id := String(yard_state["recipe_id"])
		var recipe: Dictionary = settings["work"]["recipes"].get(recipe_id, {})
		if recipe.is_empty() or String(recipe["species"]) != String(row["species_id"]):
			continue
		if not settings["work"]["facilities"][String(yard["facility_id"])].has(recipe_id):
			continue
		for index in range(yard_state["posts"].size()):
			var post: Dictionary = yard_state["posts"][index]
			if String(post["status"]) == "ready":
				continue
			if String(post["status"]) == "idle":
				var opening: Dictionary = world.recipe_defs[recipe_id]
				var enough := true
				for item in opening["inputs"]:
					if _shadow_count(String(item), shadow) < int(opening["inputs"][item]):
						enough = false
				if not enough:
					continue
				if mutate:
					for item in opening["inputs"]:
						world.inventory.remove(String(item), int(opening["inputs"][item]))
					world._record_flow({}, opening["inputs"], "处理开批")
				else:
					_shadow_spend(opening["inputs"], shadow)
				post["batch_id"] = int(state["next_batch_uid"])
				state["next_batch_uid"] = int(state["next_batch_uid"]) + 1
				post["recipe_id"] = recipe_id
				var paid := {}
				for item in opening["inputs"]:
					paid[String(item)] = int(opening["inputs"][item])
				post["inputs"] = paid
				var produced := {}
				for item in opening["outputs"]:
					produced[String(item)] = int(opening["outputs"][item])
				post["outputs"] = produced
				post["progress"] = 0
				post["target"] = int(recipe["target"])
				post["status"] = "running"
				_record("workyard", "batch_open", {"workyard": int(yard["uid"]), "post": index,
					"batch_id": int(post["batch_id"]), "recipe": recipe_id,
					"inputs": opening["inputs"].duplicate(), "outputs": opening["outputs"].duplicate()})
			var points := int(world.services.config["precision"])
			var before := int(post["progress"])
			post["progress"] = mini(int(post["target"]), before + points)
			_record("loach", "service", {"animal": int(row["uid"]), "t": t, "workyard": int(yard["uid"]),
				"post": index, "points": points, "before": before, "after": int(post["progress"])})
			if int(post["progress"]) >= int(post["target"]) and String(post["status"]) == "running":
				post["status"] = "ready"
				_record("workyard", "batch_ready", {"workyard": int(yard["uid"]), "post": index,
					"batch_id": int(post["batch_id"]), "recipe": recipe_id})
				if mutate:
					world._report_event({"category": "growth", "facility_uid": int(yard["uid"]), "kind": "批次完成",
						"count": 1, "items": post["outputs"].duplicate(), "note": "待领取"})
			return

func _try_roam(row: Dictionary, t: int, qualified: bool, account: Dictionary, pasture_use: Dictionary, wait_label: String) -> String:
	if not qualified:
		return "unqualified_wait"
	var zone_row := zone(int(row["zone_uid"]))
	var space := int(species_config(String(row["species_id"]))["space"])
	for candidate in _linked_zones(zone_row, "pasture"):
		if not zone_structural(candidate): continue
		var key := "%d:%d" % [int(candidate["uid"]), t % 8]
		var used := int(pasture_use.get(key, 0))
		if used + space <= available_space(candidate):
			pasture_use[key] = used + space
			world.services.toy_service(row,candidate,t)
			world.services.record("activity",{"animal":int(row["uid"]),"t":t,"zone":int(candidate["uid"]),"activity":"roam"})
			account["r"] = int(account["r"]) + 1
			return "roam"
	return wait_label

func _take_post(row: Dictionary, t: int, mutate: bool, shadow: Dictionary, post_taken: Dictionary, account: Dictionary) -> bool:
	var zone_row := zone(int(row["zone_uid"]))
	if zone_row.is_empty() or not zone_structural(zone_row): return false
	var yards: Array = _facilities_in_zone(zone_row).filter(func(f): return is_work_facility(String(f["facility_id"])))
	var points := int(fatigue_tier(int(row["fatigue"]))["efficiency"]) * int(settings["work"]["points_per_unit"]) / 100
	for yard in yards:
		var facility_id := String(yard["facility_id"])
		var yard_state := workyard_state(int(yard["uid"]))
		var recipe_id := String(yard_state["recipe_id"])
		var recipe: Dictionary = settings["work"]["recipes"].get(recipe_id, {})
		if recipe.is_empty() or String(recipe["species"]) != String(row["species_id"]):
			continue
		if not settings["work"]["facilities"][facility_id].has(recipe_id):
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
			var source: Dictionary=world.services.gu_service(row,"work_speed",t)
			var base_points:=points
			if not source.is_empty(): points=int(points*int(source["value"])/100)
			var carried: int=world.services.use_carry(row,int(yard["uid"]),index,recipe_id,t,int(post["batch_id"])) if int(post["progress"])==0 else 0
			var before:=int(post["progress"])
			var raw: int=before+points+carried
			var overflow:=maxi(0,raw-int(post["target"]))
			post["progress"] = mini(int(post["target"]),raw)
			world.services.capture_carry(row,int(yard["uid"]),index,recipe_id,overflow,t,int(post["batch_id"]))
			world.services.record("work_progress",{"animal":int(row["uid"]),"t":t,"yard":int(yard["uid"]),"post":index,"batch":int(post["batch_id"]),"recipe":recipe_id,"base":base_points,"points":points,"carry":carried,"before":before,"after":int(post["progress"]),"target":int(post["target"]),"overflow":overflow,"source":source.duplicate()})
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

## Aquatic survival (§16.2.7): no fatigue at all; separate miss and bad-water
## streaks, either reaching three settled days kills the animal once.
func _finish_water_day(day: int, row: Dictionary, account: Dictionary) -> void:
	var missed := int(account["fails"]) > 0
	row["miss_streak"] = 0 if not missed else int(row["miss_streak"]) + 1
	var bad_water := not water_ok(row)
	row["bad_water_streak"] = 0 if not bad_water else int(row["bad_water_streak"]) + 1
	row["account"] = {"w": 0, "r": int(account["r"]), "fails": int(account["fails"])}
	_record("water", "account", {"animal": int(row["uid"]), "day": day,
		"miss_streak": int(row["miss_streak"]), "bad_water_streak": int(row["bad_water_streak"]),
		"quality": world.water.quality(_body_of(row))})
	if maxi(int(row["miss_streak"]), int(row["bad_water_streak"])) >= 3:
		row["death_streak"] = 3
		var reason := "连续缺维持" if int(row["miss_streak"]) >= 3 else "连续劣水"
		world._report_event({"category": "pause", "facility_uid": 0, "kind": "动物死亡",
			"count": 1, "items": {}, "note": "%s（%s）死亡" % [String(world.husbandry.species_def(String(row["species_id"]))["name"]), reason]})
		_record("animal", "death", {"animal": int(row["uid"]), "day": day, "reason": reason,
			"miss_streak": int(row["miss_streak"]), "bad_water_streak": int(row["bad_water_streak"])})
		state["animals"].erase(row)
	else:
		row["death_streak"] = 0

func _finish_day(day: int, accounts: Dictionary, out: Dictionary) -> void:
	var fatigue: Dictionary = settings["fatigue"]
	var survivors := []
	var day_accounts := {}
	for row in state["animals"]:
		var account: Dictionary = accounts.get(int(row["uid"]), {"w": 0, "r": 0, "fails": 0})
		if species_medium(String(row["species_id"])) == "water":
			_finish_water_day(day, row, account)
			if int(row["death_streak"]) == 0 and String(row["stage"]) == "juvenile" and int(row["growth"]) >= int(species_config(String(row["species_id"]))["growth_units"]):
				row["stage"] = "adult"
				row["mode"] = "waiting"
				world._report_event({"category": "growth", "facility_uid": 0, "kind": "成年",
					"count": 1, "items": {}, "note": "请为其选择繁殖、生产或净化归属"})
				_record("animal", "adult", {"animal": int(row["uid"]), "day": day})
			if int(row["death_streak"]) == 0:
				day_accounts[int(row["uid"])] = row["account"].duplicate()
				survivors.append(row)
			continue
		var rest := int(account["r"])
		if String(row["mode"]) != "work":
			rest = mini(rest, int(fatigue["enclosure_rest_cap"]))
		var next := clampi(int(row["fatigue"]) + int(account["w"]) * int(fatigue["work_debt"])
			- rest * int(fatigue["rest_credit"]) - world.services.extra_recovery(int(row["uid"])) + int(account["fails"]) * int(fatigue["fail_penalty"]),
			0, int(fatigue["cap"]))
		row["account"] = {"w": int(account["w"]), "r": rest, "fails": int(account["fails"])}
		var survivor := true
		world.services.record("fatigue",{"animal":int(row["uid"]),"open":int(row["fatigue"]),"w":int(account["w"]),"r":rest,"fails":int(account["fails"]),"toy_extra":world.services.extra_recovery(int(row["uid"])),"next":next})
		_record("day", "account", {"animal": int(row["uid"]), "day": day, "w": int(account["w"]),
			"r": rest, "fails": int(account["fails"]), "toy_extra":world.services.extra_recovery(int(row["uid"])), "fatigue": int(row["fatigue"]), "next": next})
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
				"count": 1, "items": {}, "note": "请为其选择繁殖、精养或役使归属"})
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
		if ok and is_fixed_species(String(row["species_id"])) and zone_uid != int(row["zone_uid"]):
			var anchors := _free_anchor_cells(zone(zone_uid), int(row["uid"]))
			if not anchors.is_empty():
				row["anchor"] = String(anchors[0])
				_record("animal", "anchor", {"animal": int(row["uid"]), "cell": String(anchors[0])})
		if ok and mode != "work" and not is_fixed_species(String(row["species_id"])):
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
	var detached=world.get_script().new()
	var loaded: Dictionary=detached.apply_snapshot(world.to_snapshot())
	if not loaded["ok"]: return {"animals":{},"windows":[],"conflicts":[loaded]}
	return detached.ranch._plan_day(world.clock.total_days,false)

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

static func zone_row_of(value: Dictionary, zone_uid: int) -> Dictionary:
	for row in value["zones"]:
		if int(row["uid"]) == zone_uid:
			return row
	return {}

static func zone_has_cell(zone_row: Dictionary, cell: String) -> bool:
	if zone_row.is_empty():
		return false
	return zone_row["cells"].has(cell)

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
		if not Scalars.exact(row, ["uid", "type", "name", "cells", "dispatch_uid", "birth_target", "body_uid"]):
			return Scalars.fail("功能区字段非法")
		if not Scalars.whole(row["uid"], 1, int(value["next_zone_uid"]) - 1) or zone_types.has(int(row["uid"])):
			return Scalars.fail("功能区序号非法")
		if not config["zones"].has(String(row["type"])) or not row["name"] is String or String(row["name"]).is_empty():
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
		if int(row["birth_target"]) > 0 and not ["enclosure", "water_enclosure"].has(String(row["type"])):
			return Scalars.fail("只有圈养区或繁殖池有育幼目标")
		var medium := String(config["zones"].get(String(row["type"]), {}).get("medium", "land"))
		if not Scalars.whole(row["body_uid"], 0):
			return Scalars.fail("水体关联非法")
		if medium == "water":
			var water_bodies := {}
			for water_row in snapshot["world"].get("water", {"bodies": []})["bodies"]:
				water_bodies[int(water_row["uid"])] = water_row
			if int(row["body_uid"]) <= 0 or not water_bodies.has(int(row["body_uid"])):
				return Scalars.fail("水功能区必须关联存在的水体")
			for text in row["cells"]:
				if not String(text) in water_bodies[int(row["body_uid"])]["cells"]:
					return Scalars.fail("水功能区地格不在关联水体内")
		elif int(row["body_uid"]) != 0:
			return Scalars.fail("陆功能区不能关联水体")
		zone_types[int(row["uid"])] = String(row["type"])
		out["zones"].append({"uid": int(row["uid"]), "type": String(row["type"]), "name": String(row["name"]),
			"cells": row["cells"].duplicate(), "dispatch_uid": int(row["dispatch_uid"]), "birth_target": int(row["birth_target"]),
			"body_uid": int(row["body_uid"])})
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
		if not config["species"].has(sid):
			return Scalars.fail("动物物种不在畜牧范围")
		var species_cfg: Dictionary = config["species"][sid]
		if String(row["stage"]) not in ["juvenile", "adult"]:
			return Scalars.fail("动物阶段非法")
		if String(row["mode"]) not in ["waiting", "nursery", "enclosure", "intensive", "work"] + WATER_MODES:
			return Scalars.fail("动物归属非法")
		if not zone_types.has(int(row["zone_uid"])):
			return Scalars.fail("动物指向未知功能区")
		var mode := String(row["mode"])
		var zone_type := String(zone_types[int(row["zone_uid"])])
		if mode == "waiting":
			if not ["nursery", "water_nursery"].has(zone_type):
				return Scalars.fail("动物归属与功能区类型不符")
		elif zone_type != mode:
			return Scalars.fail("动物归属与功能区类型不符")
		var is_water_zone: bool = WATER_MODES.has(zone_type)
		if (String(species_cfg.get("medium", "land")) == "water") != is_water_zone:
			return Scalars.fail("水陆物种与功能区介质不符")
		if not Scalars.whole(row["miss_streak"], 0, 3) or not Scalars.whole(row["bad_water_streak"], 0, 3):
			return Scalars.fail("水产生存计数非法")
		if bool(species_cfg.get("fixed", false)):
			if not row["anchor"] is String or not zone_has_cell(zone_row_of(value, int(row["zone_uid"])), String(row["anchor"])):
				return Scalars.fail("固定物种缺少合法锚点")
		elif not String(row["anchor"]).is_empty():
			return Scalars.fail("非固定物种不携带锚点")

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
			if bool(species_cfg.get("fixed", false)):
				return Scalars.fail("固定物种不持有床位")
			var bed: Dictionary = facilities.get(int(row["bed_uid"]), {})
			if bed.is_empty() or not bed_capacity_map.has(String(bed["facility_id"])):
				return Scalars.fail("动物床位指向非床设施")
			if int(row["bed_slot"]) < 0 or int(row["bed_slot"]) >= int(bed_capacity_map[String(bed["facility_id"])]):
				return Scalars.fail("动物床位序号非法")
			var key := "%d:%d" % [int(row["bed_uid"]), int(row["bed_slot"])]
			if fulltime.has(key):
				return Scalars.fail("全时床位重复占用")
			fulltime[key] = int(row["uid"])
		elif String(row["mode"]) != "work" and not bool(species_cfg.get("fixed", false)) and int(row["bed_slot"]) != 0:
			return Scalars.fail("动物床位序号非法")
		if not Scalars.exact(row["natural"], ["round", "units", "pending", "paid", "diet_id"]) or not Scalars.exact(row["breed"], ["round", "units", "pending"]):
			return Scalars.fail("动物周期结构非法")
		if not row["natural"]["pending"] is bool or not row["natural"]["paid"] is bool or not row["breed"]["pending"] is bool:
			return Scalars.fail("动物周期标记非法")
		if not row["natural"]["diet_id"] is String:
			return Scalars.fail("动物补料标记非法")
		if not Scalars.whole(row["natural"]["round"], 0) or not Scalars.whole(row["natural"]["units"], 0, 9999) or not Scalars.whole(row["breed"]["round"], 0) or not Scalars.whole(row["breed"]["units"], 0, 9999):
			return Scalars.fail("动物周期进度非法")
		if species_cfg.has("natural"):
			var natural_units := int(species_cfg["natural"]["units"])
			if bool(row["natural"]["pending"]) == (int(row["natural"]["units"]) < natural_units):
				return Scalars.fail("精养轮与待领状态不符")
			var diet_ok := false
			for diet in species_defs[sid]["special_diets"]:
				if String(diet["id"]) == String(row["natural"]["diet_id"]):
					diet_ok = true
					var diet_gate := String(diet.get("research", ""))
					if not diet_gate.is_empty() and not snapshot["world"]["research"]["completed"].has(diet_gate):
						return Scalars.fail("精养轮补料缺少前置研究：" + diet_gate)
			if not diet_ok:
				return Scalars.fail("精养轮补料不属于该物种")
		elif int(row["natural"]["round"]) > 0 or int(row["natural"]["units"]) > 0 or bool(row["natural"]["pending"]) or bool(row["natural"]["paid"]) or not String(row["natural"]["diet_id"]).is_empty():
			return Scalars.fail("无本体产物物种携带精养轮")
		if not species_cfg.has("breed_units"):
			if int(row["breed"]["round"]) > 0 or int(row["breed"]["units"]) > 0 or bool(row["breed"]["pending"]):
				return Scalars.fail("不可繁殖物种携带繁殖进度")
		elif bool(row["breed"]["pending"]) == (int(row["breed"]["units"]) < int(species_cfg["breed_units"])):
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
		if int(row["bed_uid"]) == 0:
			var reserved_sid := String(animal_ids[int(row["animal_uid"])]["species_id"]) if animal_ids.has(int(row["animal_uid"])) else ""
			var reserved_cfg: Dictionary = config["species"].get(reserved_sid, {})
			if not animal_ids.has(int(row["animal_uid"])) or not bool(reserved_cfg.get("fixed", false)):
				return Scalars.fail("预约床位非法")
		elif bed.is_empty() or not bed_capacity_map.has(String(bed["facility_id"])):
			return Scalars.fail("预约床位非法")
		if int(row["bed_uid"]) > 0 and (int(row["bed_slot"]) < 0 or int(row["bed_slot"]) >= int(bed_capacity_map[String(bed["facility_id"])])):
			return Scalars.fail("预约床位序号非法")
		if not trough_ids.has(int(row["trough_uid"])):
			return Scalars.fail("预约食槽非法")
		if not zone_types.has(int(row["zone_uid"])):
			return Scalars.fail("预约指向未知功能区")
		if int(row["meals"]) < 1:
			return Scalars.fail("预约餐数非法")
		for other_index in range(index + 1, value["reservations"].size()):
			var other: Dictionary = value["reservations"][other_index]
			if int(row["bed_uid"]) == 0:
				continue
			if _windows_overlap(int(other["start_t"]), int(row["start_t"])) and int(other["bed_uid"]) == int(row["bed_uid"]) and int(other["bed_slot"]) == int(row["bed_slot"]):
				return Scalars.fail("同一床位时段重叠")
		out["reservations"].append({"uid": int(row["uid"]), "animal_uid": int(row["animal_uid"]),
			"bed_uid": int(row["bed_uid"]), "bed_slot": int(row["bed_slot"]), "trough_uid": int(row["trough_uid"]),
			"zone_uid": int(row["zone_uid"]), "start_t": int(row["start_t"]), "end_t": int(row["end_t"]),
			"meals": int(row["meals"])})
	if not value["workyards"] is Dictionary:
		return Scalars.fail("工作场状态非法")
	var work_recipes: Dictionary = config["work"]["recipes"]
	var work_facilities: Dictionary = config["work"]["facilities"]
	var recipe_defs: Dictionary = catalog.definitions("recipes")
	for key in value["workyards"]:
		var uid := int(key)
		if not facilities.has(uid) or not work_facilities.has(String(facilities[uid]["facility_id"])):
			return Scalars.fail("工作场状态指向非役使设施")
		var yard_recipes: Array = work_facilities[String(facilities[uid]["facility_id"])]
		var yard: Dictionary = value["workyards"][key]
		if not Scalars.exact(yard, ["recipe_id", "posts"]):
			return Scalars.fail("工作场字段非法")
		if not yard["posts"] is Array or yard["posts"].size() != int(config["work"]["posts_per_yard"]):
			return Scalars.fail("工作场岗位数非法")
		if not work_recipes.has(String(yard["recipe_id"])) or not yard_recipes.has(String(yard["recipe_id"])):
			return Scalars.fail("工作场配方非法或与设施不符")
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
		var parent_sid := String(animal_ids[int(row["parent_uid"])]["species_id"])
		if not config["species"][parent_sid].has("breed_units"):
			return Scalars.fail("不可繁殖物种携带出生凭证")
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
