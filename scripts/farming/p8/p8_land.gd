extends RefCounted
## Paid parcels in one continuous coordinate space; original cells never move.
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")
const PATH := "res://content/farming/baked/p8/expansion.json"
var _owner: WeakRef
var config: Dictionary
var parcels: Dictionary = {}
var purchased: Array = []
var base: Rect2i

static func settings() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(PATH))

static func rect(value: Array) -> Rect2i:
	return Rect2i(int(value[0]), int(value[1]), int(value[2]), int(value[3]))

static func expanded_map(original: Dictionary) -> Dictionary:
	var data := settings()
	var start := int(data["origin_x"])
	var size: Array = data["size"]
	var rows := []
	for y in range(int(size[1])):
		var row := []
		for x in range(start, start + int(size[0])):
			var terrain := "grass"
			if rect(data["base"]).has_point(Vector2i(x, y)):
				terrain = original["grid"][y][x]
			else:
				for parcel in data["parcels"]:
					if rect(parcel["rect"]).has_point(Vector2i(x, y)):
						terrain = parcel["terrain"]
						break
			row.append(terrain)
		rows.append(row)
	var out := original.duplicate(true)
	out["size"] = size.duplicate()
	out["origin_x"] = start
	out["grid"] = rows
	return out

func _init(owner) -> void:
	_owner = weakref(owner)
	config = settings()
	base = rect(config["base"])
	for parcel in config["parcels"]: parcels[parcel["id"]] = parcel

func contains(cell: Vector2i) -> bool:
	if base.has_point(cell): return true
	for id in purchased:
		if rect(parcels[id]["rect"]).has_point(cell): return true
	return false

func at(cell: Vector2i) -> String:
	for id in parcels:
		if rect(parcels[id]["rect"]).has_point(cell): return id
	return ""

func reason(cell: Vector2i) -> String:
	var id := at(cell)
	return "请先购买「%s」" % parcels[id]["name"] if not id.is_empty() else "此处尚未开放"

func quote(id: String) -> Dictionary:
	var world = _owner.get_ref()
	if not parcels.has(id): return {"ok": false, "reason": "未知地块"}
	var parcel: Dictionary = parcels[id]
	var blockers := []
	if id in purchased: blockers.append("已经购买，不会重复扣款")
	for prerequisite in parcel["requires"]:
		if prerequisite not in purchased: blockers.append("需先购买「%s」" % parcels[prerequisite]["name"])
	var active: Dictionary = world._can_act(0)
	if not active["ok"]: blockers.append(active["reason"])
	if world.primeval_stones < int(parcel["price"]): blockers.append("元石不足")
	return {"ok": blockers.is_empty(), "reason": "；".join(PackedStringArray(blockers)),
		"price": int(parcel["price"]), "remaining": world.primeval_stones - int(parcel["price"]),
		"owned": id in purchased}

func buy(id: String) -> Dictionary:
	var checked := quote(id)
	if not checked["ok"]: return checked
	var world = _owner.get_ref()
	var parcel: Dictionary = parcels[id]
	world.primeval_stones -= int(parcel["price"])
	world._cash("construction_spend", int(parcel["price"]))
	purchased.append(id)
	var cells: Array[Vector2i] = []
	var area := rect(parcel["rect"])
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x): cells.append(Vector2i(x, y))
	world.grid.refresh_access(cells)
	world.record_operation({"kind": "expansion", "day": world.clock.total_days, "parcel": id, "price": int(parcel["price"])})
	return world._finish(0, {"ok": true, "parcel": id, "cells": cells.size(), "price": int(parcel["price"])})

func to_save() -> Dictionary:
	var ids := []
	for id in parcels:
		if id in purchased: ids.append(id)
	return {"purchased": ids}

func apply_save(value: Dictionary) -> void:
	purchased = value["purchased"].duplicate()

static func normalize(value, world: Dictionary, workforce: Dictionary, catalog) -> Dictionary:
	var data := settings()
	var defs := {}
	for parcel in data["parcels"]: defs[parcel["id"]] = parcel
	if not Scalars.exact(value, ["purchased"]) or not value["purchased"] is Array or value["purchased"].size() > defs.size():
		return Scalars.fail("扩地记录字段非法")
	var ids := []
	for id in value["purchased"]:
		if not id is String or not defs.has(id) or id in ids: return Scalars.fail("扩地记录未知或重复地块")
		ids.append(id)
	for id in ids:
		for prerequisite in defs[id]["requires"]:
			if prerequisite not in ids: return Scalars.fail("扩地记录缺少前置地块")
	var is_owned := func(cell: Vector2i) -> bool:
		if rect(data["base"]).has_point(cell): return true
		for id in ids:
			if rect(defs[id]["rect"]).has_point(cell): return true
		return false
	for pair in world["tilled"]:
		if not is_owned.call(Vector2i(int(pair[0]), int(pair[1]))): return Scalars.fail("未购地块存在耕地")
	for section in ["crops", "facilities"]:
		var registry: Dictionary = catalog.definitions(section)
		for row in world[section]:
			var shape: Array = registry[row["crop_id"] if section == "crops" else row["facility_id"]]["footprint"]
			for dy in range(int(shape[1])):
				for dx in range(int(shape[0])):
					if not is_owned.call(Vector2i(int(row["origin"][0]) + dx, int(row["origin"][1]) + dy)):
						return Scalars.fail("作物或设施跨越未购地块")
	for mark in workforce["marks"]:
		if not is_owned.call(Vector2i(int(mark["cell"][0]), int(mark["cell"][1]))): return Scalars.fail("未购地块存在工作标记")
	for plan in workforce["seed_plans"]:
		var shape: Array = catalog.definitions("crops")[plan["crop_id"]]["footprint"]
		for dy in range(int(shape[1])):
			for dx in range(int(shape[0])):
				if not is_owned.call(Vector2i(int(plan["cell"][0]) + dx, int(plan["cell"][1]) + dy)):
					return Scalars.fail("选种计划跨越未购地块")
	var ordered := []
	for id in defs:
		if id in ids: ordered.append(id)
	return {"ok": true, "land": {"purchased": ordered}}
