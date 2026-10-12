extends RefCounted
## P8 devices: field service stations and growth lamps run once per opening
## day inside the settlement transaction. They never spend AP or wages, only
## real stock, and reloads never re-run an opening.
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")
const STATION_ID := "field_service_station"
const LAMP_ID := "growth_lamp"

var _owner: WeakRef
var world:
	get:
		return _owner.get_ref()
var settings: Dictionary
## {devices: {uid: {...}}, active_day: int, active_lamps: [uid]}
var state := {"devices": {}, "active_day": -1, "active_lamps": []}

func _init(owner, device_settings: Dictionary) -> void:
	_owner = weakref(owner)
	settings = device_settings

func _error(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

func device_of(facility_uid: int) -> Dictionary:
	return state["devices"].get(facility_uid, {})

func _ensure(facility_uid: int, kind: String) -> Dictionary:
	if not state["devices"].has(facility_uid):
		if kind == STATION_ID:
			state["devices"][facility_uid] = {"kind": STATION_ID, "irrigate": true, "fertilize": true,
				"threshold": int(settings["station"]["threshold"]), "cursor": {"irrigate": 0, "fertilize": 0}}
		else:
			state["devices"][facility_uid] = {"kind": LAMP_ID, "enabled": false}
	return state["devices"][facility_uid]

## Management only: switches and thresholds take effect at the next opening.
func configure_station(facility_uid: int, irrigate: bool, fertilize: bool, threshold: int) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	if not world.facilities.has(facility_uid) or String(world.facilities[facility_uid]["facility_id"]) != STATION_ID:
		return _error("未知维护站")
	if not Scalars.whole(threshold, 1, 99):
		return _error("阈值非法")
	var device := _ensure(facility_uid, STATION_ID)
	device["irrigate"] = irrigate
	device["fertilize"] = fertilize
	device["threshold"] = int(threshold)
	world.changed.emit()
	return {"ok": true}

func configure_lamp(facility_uid: int, enabled: bool) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	if not world.facilities.has(facility_uid) or String(world.facilities[facility_uid]["facility_id"]) != LAMP_ID:
		return _error("未知补光灯")
	var device := _ensure(facility_uid, LAMP_ID)
	device["enabled"] = enabled
	world.changed.emit()
	return {"ok": true}

func forget(facility_uid: int) -> void:
	state["devices"].erase(facility_uid)
	state["active_lamps"].erase(facility_uid)

func _coverage(facility_uid: int) -> Rect2i:
	var facility: Dictionary = world.facilities.get(facility_uid, {})
	if facility.is_empty():
		return Rect2i()
	var footprint: Array = world.facility_defs[String(facility["facility_id"])]["footprint"]
	var origin := Vector2i(int(facility["origin"][0]), int(facility["origin"][1]))
	var margin := int(settings["lamp" if String(world.facility_defs[String(facility["facility_id"])]["id"]) == LAMP_ID else "station"]["range"])
	return Rect2i(origin.x - margin, origin.y - margin,
		int(footprint[0]) + margin * 2, int(footprint[1]) + margin * 2).intersection(Rect2i(0, 0, world.grid.width, world.grid.height))

func _sorted_device_uids(kind: String) -> Array:
	var out := []
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == kind:
			out.append(int(uid))
	out.sort()
	return out

## Lamps stay effective from their opening through the next settle roll: the
## D+1 crop settle still evaluates day D's lit conditions.
func lamp_active_at(cell: Vector2i) -> bool:
	if int(state["active_day"]) < world.clock.total_days - 1:
		return false
	for uid in state["active_lamps"]:
		if _coverage(int(uid)).has_point(cell):
			return true
	return false

## The one-per-day opening: lamps first, then station services, all against
## live shared stock with per-cell re-verification and rotating cursors.
func run_opening(day: int) -> void:
	if int(state["active_day"]) == day:
		return
	state["active_day"] = day
	state["active_lamps"] = []
	var fuel: Dictionary = settings["lamp"]["fuel"]
	for uid in _sorted_device_uids(LAMP_ID):
		var device := _ensure(int(uid), LAMP_ID)
		if not bool(device["enabled"]):
			continue
		var coverage := _coverage(int(uid))
		var has_crop := false
		for crop in world.crops.values():
			if coverage.has_point(Vector2i(int(crop["origin"][0]), int(crop["origin"][1]))):
				has_crop = true
				break
		if not has_crop:
			continue
		if not world.inventory.has(String(fuel["item"]), int(fuel["units"])):
			continue
		world.inventory.remove(String(fuel["item"]), int(fuel["units"]))
		world._record_flow({}, {String(fuel["item"]): int(fuel["units"])}, "设备燃油")
		state["active_lamps"].append(int(uid))
	var services: Dictionary = settings["station"]["services"]
	var limit := int(settings["station"]["daily_limit"])
	for uid in _sorted_device_uids(STATION_ID):
		var device := _ensure(int(uid), LAMP_ID if false else STATION_ID)
		var coverage := _coverage(int(uid))
		for item in ["irrigate", "fertilize"]:
			if not bool(device[item]):
				continue
			var service: Dictionary = services[item]
			var field := 0 if item == "irrigate" else 1
			var targets: Array = []
			for y in range(coverage.position.y, coverage.end.y):
				for x in range(coverage.position.x, coverage.end.x):
					var cell := Vector2i(x, y)
					if world.grid.state_at(cell) not in [1, 2]:
						continue
					var index: int = cell.y * world.grid.width + cell.x
					if int(world.environment[index][field]) >= int(device["threshold"]):
						continue
					targets.append(cell)
			if targets.is_empty():
				device["cursor"][item] = 0
				continue
			var offset := int(device["cursor"][item]) % targets.size()
			var served := 0
			for step in range(targets.size()):
				if served >= limit:
					break
				var cell: Vector2i = targets[(offset + step) % targets.size()]
				var index: int = cell.y * world.grid.width + cell.x
				if int(world.environment[index][field]) >= int(device["threshold"]):
					continue
				if not world.inventory.has(String(service["item"]), int(service["units"])):
					break
				world.inventory.remove(String(service["item"]), int(service["units"]))
				world._record_flow({}, {String(service["item"]): int(service["units"])}, "设备维护")
				world.environment[index][field] = mini(100, int(world.environment[index][field]) + int(service["gain"]))
				served += 1
			device["cursor"][item] = (offset + served) % maxi(1, targets.size())

## Read-only panel data.
func station_overview(facility_uid: int) -> Dictionary:
	var device := device_of(facility_uid)
	var coverage := _coverage(facility_uid)
	var low := {"irrigate": 0, "fertilize": 0}
	if not device.is_empty():
		for y in range(coverage.position.y, coverage.end.y):
			for x in range(coverage.position.x, coverage.end.x):
				var cell := Vector2i(x, y)
				if world.grid.state_at(cell) not in [1, 2]:
					continue
				var index: int = cell.y * world.grid.width + cell.x
				for item in ["irrigate", "fertilize"]:
					var field := 0 if item == "irrigate" else 1
					if int(world.environment[index][field]) < int(device["threshold"]):
						low[item] += 1
	return {"coverage": coverage, "cells": coverage.get_area(), "low": low, "limit": int(settings["station"]["daily_limit"])}

func lamp_overview(facility_uid: int) -> Dictionary:
	var coverage := _coverage(facility_uid)
	var crops := []
	var shade := []
	for crop in world.crops.values():
		var anchor := Vector2i(int(crop["origin"][0]), int(crop["origin"][1]))
		if coverage.has_point(anchor):
			crops.append(String(crop["crop_id"]))
			if absi(int(world.crop_defs[String(crop["crop_id"])]["light"]) - int(settings["lamp"]["light"])) > int(world.config["environment"]["light_tolerance"]):
				shade.append(String(crop["crop_id"]))
	var fuel: Dictionary = settings["lamp"]["fuel"]
	return {"coverage": coverage, "crops": crops, "shade": shade,
		"fuel_item": String(fuel["item"]), "fuel_units": int(fuel["units"]),
		"active": state["active_lamps"].has(facility_uid)}

func to_save() -> Dictionary:
	var devices := []
	for uid in state["devices"].keys():
		devices.append({"uid": int(uid), "data": state["devices"][uid].duplicate(true)})
	devices.sort_custom(func(a, b): return int(a["uid"]) < int(b["uid"]))
	return {"devices": devices, "active_day": int(state["active_day"]),
		"active_lamps": (state["active_lamps"] as Array).duplicate()}

func apply_save(value: Dictionary) -> void:
	state = {"devices": {}, "active_day": int(value["active_day"]), "active_lamps": []}
	for row in value["devices"]:
		state["devices"][int(row["uid"])] = row["data"].duplicate(true)
	for uid in value["active_lamps"]:
		state["active_lamps"].append(int(uid))

## Detached validation against the normalized world snapshot.
static func normalize(value, day: int, world: Dictionary, catalog) -> Dictionary:
	if not value is Dictionary or not Scalars.exact(value, ["devices", "active_day", "active_lamps"]):
		return Scalars.fail("设备快照字段非法")
	var settings: Dictionary = catalog.load_data()["devices"]
	var facilities := {}
	for row in world["facilities"]:
		facilities[int(row["uid"])] = String(row["facility_id"])
	var out := {"devices": [], "active_day": int(value["active_day"]), "active_lamps": []}
	if not Scalars.whole(value["active_day"], -1, day):
		return Scalars.fail("设备开日标记非法")
	var seen := {}
	for row in value["devices"]:
		if not row is Dictionary or not Scalars.exact(row, ["uid", "data"]):
			return Scalars.fail("设备记录字段非法")
		var uid := int(row["uid"])
		if seen.has(uid) or not facilities.has(uid):
			return Scalars.fail("设备指向未知或重复设施")
		seen[uid] = true
		var data = row["data"]
		if facilities[uid] == STATION_ID:
			if not data is Dictionary or not Scalars.exact(data, ["kind", "irrigate", "fertilize", "threshold", "cursor"]):
				return Scalars.fail("维护站配置字段非法")
			if data["kind"] != STATION_ID or not data["irrigate"] is bool or not data["fertilize"] is bool \
					or not Scalars.whole(data["threshold"], 1, 99) or not data["cursor"] is Dictionary:
				return Scalars.fail("维护站配置非法")
			var cursor := {}
			for item in data["cursor"]:
				if item not in ["irrigate", "fertilize"] or not Scalars.whole(data["cursor"][item], 0):
					return Scalars.fail("维护站游标非法")
				cursor[item] = int(data["cursor"][item])
			out["devices"].append({"uid": uid, "data": {"kind": STATION_ID, "irrigate": bool(data["irrigate"]),
				"fertilize": bool(data["fertilize"]), "threshold": int(data["threshold"]), "cursor": cursor}})
		elif facilities[uid] == LAMP_ID:
			if not data is Dictionary or not Scalars.exact(data, ["kind", "enabled"]) or data["kind"] != LAMP_ID or not data["enabled"] is bool:
				return Scalars.fail("补光灯配置非法")
			out["devices"].append({"uid": uid, "data": {"kind": LAMP_ID, "enabled": bool(data["enabled"])}})
		else:
			return Scalars.fail("设备记录指向非装置设施")
	var lamps_seen := {}
	for uid in value["active_lamps"]:
		if not Scalars.whole(uid, 1) or not facilities.has(int(uid)) or facilities[int(uid)] != LAMP_ID:
			return Scalars.fail("生效补光灯指向非法")
		if lamps_seen.has(int(uid)):
			return Scalars.fail("生效补光灯重复")
		lamps_seen[int(uid)] = true
		out["active_lamps"].append(int(uid))
	return {"ok": true, "devices": out}
