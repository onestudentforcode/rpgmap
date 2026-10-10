extends RefCounted
## V1 production model; settle crop/processing state before the single daily save.
signal changed()
signal daily_settled(total_days: int, saved: bool)
const Data := preload("res://scripts/farming/v1/v1_data.gd")
const Snapshot := preload("res://scripts/farming/v1/v1_snapshot.gd")
const Grid := preload("res://scripts/farming/core/grid/land_grid.gd")
const Clock := preload("res://scripts/farming/core/clock/farm_clock.gd")
const Inventory := preload("res://scripts/farming/core/inventory/farm_inventory.gd")

var grid: Grid
var clock: Clock
var inventory: Inventory
var primeval_stones := 60
var config: Dictionary
var crop_defs: Dictionary
var source_defs: Dictionary
var facility_defs: Dictionary
var recipe_defs: Dictionary
var crops: Dictionary = {}
var facilities: Dictionary = {}
var environment: Array = []
var _light: Array = []
var _next_uid := 1
var _next_facility_uid := 1
var _next_batch_uid := 1
var _tilled_under_buildings: Dictionary = {}
var _source_used: Dictionary = {}
var _source_day := 0
var _source_cells: Dictionary = {}
var _store
var daily_save_error := ""

func _init(slot_store = null) -> void:
	_store = slot_store
	config = Data.load_data()["config"]
	crop_defs = Data.definitions("crops")
	source_defs = Data.definitions("sources")
	facility_defs = Data.definitions("facilities")
	recipe_defs = Data.definitions("recipes")
	grid = Grid.new()
	clock = Clock.new()
	inventory = Inventory.new()
	var map := Data.load_map()
	grid.setup(int(map["size"][0]), int(map["size"][1]), map["grid"], Data.tillable_map())
	clock.setup({"time": {"ap_per_day": config["ap_per_day"], "days_per_term": config["days_per_term"]}})
	clock.day_changed.connect(_on_day_changed)
	for y in range(grid.height):
		for x in range(grid.width):
			var level := int(config["light"]["default"])
			for region in config["light"]["regions"]:
				var rect: Array = region["rect"]
				if Rect2i(int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3])).has_point(Vector2i(x,y)):
					level = int(region["level"])
			_light.append(level)
	for ident in source_defs:
		var position: Array = source_defs[ident]["position"]
		_source_cells[Vector2i(int(position[0]), int(position[1]))] = ident
	apply_snapshot(Snapshot.fresh())

func _error(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

func _can_act(ap: int = 1) -> Dictionary:
	if not daily_save_error.is_empty():
		return _error("日存档失败，请重试保存或放弃当天：" + daily_save_error)
	if _store != null and _store.active_slot() == 0:
		return _error("尚未选择V1存档槽")
	if not clock.can_spend(ap):
		return _error("行动点不足")
	return {"ok": true}

func _finish(ap: int, result: Dictionary) -> Dictionary:
	var before_day := clock.total_days
	clock.spend(ap)
	result["day_advanced"] = before_day != clock.total_days
	result["saved"] = result["day_advanced"] and _store != null and daily_save_error.is_empty()
	if not daily_save_error.is_empty():
		result["save_error"] = daily_save_error
	changed.emit()
	return result

func start_new(slot: int, overwrite_confirmed: bool = false) -> Dictionary:
	if _store == null:
		return _error("未配置存档服务")
	var created: Dictionary = _store.create_slot(slot, Snapshot.fresh(), overwrite_confirmed)
	if created["ok"]:
		apply_snapshot(created["snapshot"])
	return created

func open_game(slot: int) -> Dictionary:
	if _store == null:
		return _error("未配置存档服务")
	var loaded: Dictionary = _store.open_slot(slot)
	if loaded["ok"]:
		apply_snapshot(loaded["snapshot"])
	return loaded

func abandon_day() -> Dictionary:
	if _store == null or _store.active_slot() == 0:
		return _error("尚未选择V1存档槽")
	return open_game(_store.active_slot())

func end_day() -> Dictionary:
	var checked := _can_act(0)
	if not checked["ok"]:
		return checked
	clock.end_day()
	changed.emit()
	return {"ok": true, "saved": _store != null and daily_save_error.is_empty(), "save_error": daily_save_error}

func retry_day_save() -> Dictionary:
	if daily_save_error.is_empty() or _store == null or _store.active_slot() == 0:
		return _error("没有待重试的日存档")
	var saved: Dictionary = _store.commit(to_snapshot())
	if saved["ok"]:
		daily_save_error = ""
	return saved

func environment_at(cell: Vector2i) -> Dictionary:
	if not grid.in_bounds(cell.x, cell.y):
		return {}
	var index := cell.y * grid.width + cell.x
	return {"water": environment[index][0], "fertility": environment[index][1], "light": _light[index]}

func source_at(cell: Vector2i) -> String:
	return String(_source_cells.get(cell, ""))

func source_remaining(ident: String) -> int:
	return int(source_defs[ident]["daily_limit"]) - int(_source_used[ident]) if source_defs.has(ident) else 0

func instance_at(cell: Vector2i) -> Dictionary:
	for row in crops.values():
		var origin := Vector2i(int(row["origin"][0]), int(row["origin"][1]))
		var footprint: Array = crop_defs[row["crop_id"]]["footprint"]
		if Rect2i(origin.x, origin.y, int(footprint[0]), int(footprint[1])).has_point(cell):
			return row.duplicate(true)
	return {}

func till(cell: Vector2i) -> Dictionary:
	var checked := _can_act()
	if not checked["ok"]:
		return checked
	if _source_cells.has(cell):
		return _error("资源点不能开垦")
	checked = grid.till(cell)
	return _finish(1, checked) if checked["ok"] else checked

func plant(cell: Vector2i, crop_id: String) -> Dictionary:
	var checked := _can_act()
	if not checked["ok"]:
		return checked
	if not crop_defs.has(crop_id):
		return _error("未知植物")
	var definition: Dictionary = crop_defs[crop_id]
	var inputs: Dictionary = definition["inputs"].duplicate()
	inputs[definition["seed"]] = int(inputs.get(definition["seed"], 0)) + 1
	for ident in inputs:
		if not inventory.has(ident, int(inputs[ident])):
			return _error("缺少种植投入：" + ident)
	var footprint: Array = definition["footprint"]
	checked = grid.reserve(cell, int(footprint[0]), int(footprint[1]), "v1_crop:%d" % _next_uid, Grid.State.PLANTED)
	if not checked["ok"]:
		return checked
	for ident in inputs:
		inventory.remove(ident, int(inputs[ident]))
	var uid := _next_uid
	_next_uid += 1
	crops[uid] = {"uid": uid, "crop_id": crop_id, "origin": [cell.x, cell.y], "progress": 0, "state": "growing", "harvest_count": 0}
	# Culture water also moistens the bed; it is not charged twice as irrigation.
	if definition["mode"] == "culture_each_cycle":
		var index := cell.y * grid.width + cell.x
		environment[index][0] = mini(100, int(environment[index][0]) + int(inputs.get("clean_water", 0)) * int(config["environment"]["irrigate_gain"]))
	return _finish(1, {"ok": true, "uid": uid})

func harvest(cell: Vector2i, mode: String = "harvest") -> Dictionary:
	var checked := _can_act()
	if not checked["ok"]:
		return checked
	var instance := instance_at(cell)
	if instance.is_empty() or instance["state"] != "mature":
		return _error("没有成熟植物")
	var definition: Dictionary = crop_defs[instance["crop_id"]]
	if mode not in ["harvest", "fell"] or (mode == "fell" and definition["mode"] not in ["tap_or_fell", "fell_replant"]):
		return _error("采收方式不适用")
	var uid := int(instance["uid"])
	var outputs: Dictionary = definition["fell_outputs"] if mode == "fell" and definition["mode"] == "tap_or_fell" else definition["outputs"]
	for ident in outputs:
		inventory.add(ident, int(outputs[ident]))
	if definition["mode"] == "tap_or_fell" and mode == "harvest":
		crops[uid]["harvest_count"] = int(crops[uid]["harvest_count"]) + 1
		crops[uid]["progress"] = 0
		crops[uid]["state"] = "regrowing"
	else:
		grid.release("v1_crop:%d" % uid)
		crops.erase(uid)
	return _finish(1, {"ok": true, "items": outputs.duplicate(), "removed": not crops.has(uid)})

func irrigate(cell: Vector2i) -> Dictionary:
	return _improve(cell, 0, "clean_water", "irrigate_units", "irrigate_gain")

func fertilize(cell: Vector2i) -> Dictionary:
	return _improve(cell, 1, "humus", "fertilize_units", "fertilize_gain")

func _improve(cell: Vector2i, field: int, item: String, units: String, gain: String) -> Dictionary:
	var checked := _can_act()
	if not checked["ok"]:
		return checked
	if not grid.in_bounds(cell.x, cell.y) or grid.state_at(cell) not in [Grid.State.TILLED, Grid.State.PLANTED]:
		return _error("只能改善已开垦的土地")
	var index := cell.y * grid.width + cell.x
	var amount := int(config["environment"][units])
	if environment[index][field] >= 100 or not inventory.has(item, amount):
		return _error("环境已满或缺少投入")
	inventory.remove(item, amount)
	environment[index][field] = mini(100, int(environment[index][field]) + int(config["environment"][gain]))
	return _finish(1, {"ok": true})

func collect(ident: String) -> Dictionary:
	if not source_defs.has(ident):
		return _error("未知资源点")
	var definition: Dictionary = source_defs[ident]
	var checked := _can_act(int(definition["ap"]))
	if not checked["ok"]:
		return checked
	var quantity := int(definition["quantity"])
	if source_remaining(ident) < quantity:
		return _error("今日资源点配额不足")
	_source_used[ident] = int(_source_used[ident]) + quantity
	inventory.add(definition["item"], quantity)
	return _finish(int(definition["ap"]), {"ok": true, "item_id": definition["item"], "quantity": quantity})

func facility_at(cell: Vector2i) -> Dictionary:
	for row in facilities.values():
		var footprint: Array = facility_defs[row["facility_id"]]["footprint"]
		var origin: Array = row["origin"]
		if Rect2i(int(origin[0]), int(origin[1]), int(footprint[0]), int(footprint[1])).has_point(cell):
			return row.duplicate(true)
	return {}

func build_facility(cell: Vector2i, facility_id: String) -> Dictionary:
	var ap := int(config["construction"]["build_ap"])
	var checked := _can_act(ap)
	if not checked["ok"]:
		return checked
	if not facility_defs.has(facility_id):
		return _error("未知设施")
	var definition: Dictionary = facility_defs[facility_id]
	if primeval_stones < int(definition["cash"]):
		return _error("建设元石不足")
	for ident in definition["materials"]:
		if not inventory.has(ident, int(definition["materials"][ident])):
			return _error("建设材料不足：" + ident)
	var footprint: Array = definition["footprint"]
	var tilled_before := []
	for dy in range(int(footprint[1])):
		for dx in range(int(footprint[0])):
			var target := cell + Vector2i(dx,dy)
			if _source_cells.has(target):
				return _error("设施不能覆盖资源点")
			if grid.in_bounds(target.x, target.y) and grid.state_at(target) == Grid.State.TILLED:
				tilled_before.append(target)
	var uid := _next_facility_uid
	checked = grid.reserve(cell, int(footprint[0]), int(footprint[1]), "v1_facility:%d" % uid)
	if not checked["ok"]:
		return checked
	for target in tilled_before:
		_tilled_under_buildings[target] = true
	for ident in definition["materials"]:
		inventory.remove(ident, int(definition["materials"][ident]))
	primeval_stones -= int(definition["cash"])
	_next_facility_uid += 1
	facilities[uid] = {"uid": uid, "facility_id": facility_id, "origin": [cell.x,cell.y], "batch": {}}
	return _finish(ap, {"ok": true, "facility_uid": uid})

func demolish_facility(uid: int) -> Dictionary:
	var ap := int(config["construction"]["demolish_ap"])
	var checked := _can_act(ap)
	if not checked["ok"]:
		return checked
	if not facilities.has(uid) or not facilities[uid]["batch"].is_empty():
		return _error("只能拆除空闲设施")
	var cells: Array = grid.holder_cells("v1_facility:%d" % uid).duplicate()
	grid.release("v1_facility:%d" % uid)
	for target in cells:
		_tilled_under_buildings.erase(target)
	facilities.erase(uid)
	# No construction refunds and no destruction of processing/ready batches.
	return _finish(ap, {"ok": true})

func start_batch(facility_uid: int, recipe_id: String) -> Dictionary:
	if not facilities.has(facility_uid) or not recipe_defs.has(recipe_id):
		return _error("未知设施或配方")
	var recipe: Dictionary = recipe_defs[recipe_id]
	var checked := _can_act(int(recipe["start_ap"]))
	if not checked["ok"]:
		return checked
	var facility: Dictionary = facilities[facility_uid]
	if facility["facility_id"] != recipe["facility"] or not facility["batch"].is_empty():
		return _error("设施不适用或已有未收取批次")
	for ident in recipe["inputs"]:
		if not inventory.has(ident, int(recipe["inputs"][ident])):
			return _error("加工投入不足：" + ident)
	for ident in recipe["inputs"]:
		inventory.remove(ident, int(recipe["inputs"][ident]))
	var batch_id := _next_batch_uid
	_next_batch_uid += 1
	var inputs := {}
	var outputs := {}
	for ident in recipe["inputs"]:
		inputs[ident] = int(recipe["inputs"][ident])
	for ident in recipe["outputs"]:
		outputs[ident] = int(recipe["outputs"][ident])
	facility["batch"] = {"batch_id": batch_id, "recipe_id": recipe_id, "inputs": inputs,
		"outputs": outputs, "start_day": clock.total_days,
		"finish_day": clock.total_days + int(recipe["days"]), "status": "processing"}
	return _finish(int(recipe["start_ap"]), {"ok": true, "batch_id": batch_id})

func claim_batch(facility_uid: int, expected_batch_id: int) -> Dictionary:
	if not facilities.has(facility_uid):
		return _error("未知设施")
	var batch: Dictionary = facilities[facility_uid]["batch"]
	if batch.is_empty() or batch["batch_id"] != expected_batch_id or batch["status"] != "ready":
		return _error("批次未完成、已收取或已过期")
	var recipe: Dictionary = recipe_defs[batch["recipe_id"]]
	var checked := _can_act(int(recipe["claim_ap"]))
	if not checked["ok"]:
		return checked
	var outputs: Dictionary = batch["outputs"].duplicate(true)
	for ident in outputs:
		inventory.add(ident, int(outputs[ident]))
	facilities[facility_uid]["batch"] = {}
	return _finish(int(recipe["claim_ap"]), {"ok": true, "batch_id": expected_batch_id, "items": outputs})

func _on_day_changed(day: int) -> void:
	for uid in crops:
		var row: Dictionary = crops[uid]
		var definition: Dictionary = crop_defs[row["crop_id"]]
		var cells: Array = grid.holder_cells("v1_crop:%d" % uid)
		var water := 0
		var fertility := 0
		var light := 0
		for cell in cells:
			var index: int = cell.y * grid.width + cell.x
			water += int(environment[index][0])
			fertility += int(environment[index][1])
			light += int(_light[index])
		var settings: Dictionary = config["environment"]
		var water_rate := 100 if float(water) / cells.size() >= float(settings["optimal_water"]) else int(settings["low_water_efficiency"])
		var fertility_rate := 100 if float(fertility) / cells.size() >= float(settings["optimal_fertility"]) else int(settings["low_fertility_efficiency"])
		var light_rate := 100 if absf(float(light) / cells.size() - float(definition["light"])) <= float(settings["light_tolerance"]) else int(settings["low_light_efficiency"])
		var growth := maxi(1, floori(float(water_rate * fertility_rate * light_rate) / 10000.0))
		if row["state"] != "mature":
			var target := int(definition["cycle_days"] if row["harvest_count"] > 0 else definition["days"]) * 100
			row["progress"] = mini(target, int(row["progress"]) + growth)
			if row["progress"] == target:
				row["state"] = "mature"
		for cell in cells:
			var index: int = cell.y * grid.width + cell.x
			environment[index][0] = maxi(0, int(environment[index][0]) - int(definition["water_use"]))
			environment[index][1] = maxi(0, int(environment[index][1]) - int(definition["fertility_use"]))
	_source_day = day
	for ident in _source_used:
		_source_used[ident] = 0
	for row in facilities.values():
		var batch: Dictionary = row["batch"]
		if not batch.is_empty() and batch["status"] == "processing" and day >= int(batch["finish_day"]):
			batch["status"] = "ready"
	if _store != null:
		var saved: Dictionary = _store.commit(to_snapshot())
		daily_save_error = "" if saved["ok"] else String(saved["reason"])
	daily_settled.emit(day, _store != null and daily_save_error.is_empty())

func to_snapshot() -> Dictionary:
	var tilled := []
	for y in range(grid.height):
		for x in range(grid.width):
			if grid.state_at(Vector2i(x,y)) in [Grid.State.TILLED, Grid.State.PLANTED] or _tilled_under_buildings.has(Vector2i(x,y)):
				tilled.append([x,y])
	var rows := []
	for uid in crops.keys():
		rows.append(crops[uid].duplicate(true))
	var buildings := []
	for row in facilities.values():
		buildings.append(row.duplicate(true))
	return {"product": "farm_demo_v1", "schema": Snapshot.SCHEMA, "clock": clock.to_save(),
		"economy": {"primeval_stones": primeval_stones}, "inventory": inventory.to_save(),
		"world": {"map_id": config["map_id"], "tilled": tilled, "environment": environment.duplicate(true),
			"crops": rows, "next_uid": _next_uid, "sources": {"day": _source_day, "used": _source_used.duplicate()},
			"facilities": buildings, "next_facility_uid": _next_facility_uid, "next_batch_uid": _next_batch_uid}}

func apply_snapshot(value) -> Dictionary:
	var checked := Snapshot.normalize(value)
	if not checked["ok"]:
		return checked
	var snapshot: Dictionary = checked["snapshot"]
	var world: Dictionary = snapshot["world"]
	grid.reset()
	for pair in world["tilled"]:
		grid.till(Vector2i(int(pair[0]), int(pair[1])))
	crops.clear()
	for row in world["crops"]:
		var definition: Dictionary = crop_defs[row["crop_id"]]
		grid.reserve(Vector2i(int(row["origin"][0]), int(row["origin"][1])), int(definition["footprint"][0]), int(definition["footprint"][1]), "v1_crop:%d" % int(row["uid"]), Grid.State.PLANTED)
		crops[int(row["uid"])] = row.duplicate(true)
	facilities.clear()
	_tilled_under_buildings.clear()
	for row in world["facilities"]:
		var definition: Dictionary = facility_defs[row["facility_id"]]
		var origin := Vector2i(int(row["origin"][0]), int(row["origin"][1]))
		for dy in range(int(definition["footprint"][1])):
			for dx in range(int(definition["footprint"][0])):
				var cell := origin + Vector2i(dx,dy)
				if grid.state_at(cell) == Grid.State.TILLED:
					_tilled_under_buildings[cell] = true
		grid.reserve(origin, int(definition["footprint"][0]), int(definition["footprint"][1]), "v1_facility:%d" % int(row["uid"]))
		facilities[int(row["uid"])] = row.duplicate(true)
	_next_facility_uid = int(world["next_facility_uid"])
	_next_batch_uid = int(world["next_batch_uid"])
	clock.apply_save(snapshot["clock"])
	inventory.apply_save(snapshot["inventory"])
	primeval_stones = int(snapshot["economy"]["primeval_stones"])
	environment = world["environment"].duplicate(true)
	_next_uid = int(world["next_uid"])
	_source_day = int(world["sources"]["day"])
	_source_used = world["sources"]["used"].duplicate()
	daily_save_error = ""
	changed.emit()
	return {"ok": true}
