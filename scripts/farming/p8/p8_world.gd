extends "res://scripts/farming/v2/v2_world.gd"
## P8 development world: independent namespace, candidate day settlement with
## full rollback, real water changes and research-gated content registration.
const P8Data := preload("res://scripts/farming/p8/p8_data.gd")
const P8Snapshot := preload("res://scripts/farming/p8/p8_snapshot.gd")
const P8Husbandry := preload("res://scripts/farming/p8/p8_husbandry.gd")
const P8Operations := preload("res://scripts/farming/p8/p8_operations.gd")
const P8Workforce := preload("res://scripts/farming/p8/p8_workforce.gd")
const P8Research := preload("res://scripts/farming/p8/p8_research.gd")
const P8Flowers := preload("res://scripts/farming/p8/p8_flowers.gd")
const P8Land := preload("res://scripts/farming/p8/p8_land.gd")
const P8Devices := preload("res://scripts/farming/p8/p8_devices.gd")
const Logistics := preload("res://scripts/farming/p8/p10_logistics.gd")
const Rooms := preload("res://scripts/farming/p8/p102_rooms.gd")
const Ranch := preload("res://scripts/farming/p8/p103_ranch.gd")
const Services := preload("res://scripts/farming/p8/p104_services.gd")
const Water := preload("res://scripts/farming/p8/p106_water.gd")
const Economy := preload("res://scripts/farming/p8/p107_economy.gd")
## Observational receipts for external business audits; never grants resources or
## replays work. Day-save failures are still governed by the transaction below.
signal operation_recorded(entry: Dictionary)

func record_operation(entry: Dictionary) -> void:
	operation_recorded.emit(entry.duplicate(true))

## Session-only transaction state: the settled candidate awaiting a successful
## write, and the pre-action state a failed commit restores. Never persisted.
var _pending_day := {}
var _day_checkpoint := {}
## Facility ownership, production strategies, reserves and the scheduler.
var operations
## Research benches, farm-wide completed knowledge and daily receipts.
var research
## Flower shares, hand picks and pollination marks.
var flowers
## Field stations and growth lamps; they run inside the opening-day step.
var devices
var land
var logistics
var rooms
var ranch
var services
var water
var progress

func _init(slot_store = null) -> void:
	land = P8Land.new(self)
	operations = P8Operations.new(self)
	research = P8Research.new(self)
	flowers = P8Flowers.new(self, P8Data.load_data()["flowers"])
	devices = P8Devices.new(self, P8Data.load_data()["devices"])
	logistics = Logistics.new(self, P8Data.load_data()["logistics"])
	rooms = Rooms.new(self,P8Data.load_data()["rooms"])
	ranch = Ranch.new(self, P8Data.load_data()["p103"])
	services = Services.new(self, P8Data.load_data()["p104"])
	water = Water.new(self, P8Data.load_data()["p106"])
	progress = Economy.new(self, P8Data.load_data()["p107"])
	super(slot_store)

func _catalog():
	return P8Data

func _codec():
	return P8Snapshot

## Water crops (P10.6 §16.2.8): fenced water cells of one structural
## aqua-planting zone, no grid reservation, one crop per cell, at most eight
## planting cells per aquatic crop station in the zone.
func _water_plant_block(cell: Vector2i, definition: Dictionary, _variant_id: String) -> String:
	if water == null:
		return "本产品没有水面种植"
	var zone_row := {}
	var body_uid := 0
	for dy in range(int(definition["footprint"][1])):
		for dx in range(int(definition["footprint"][0])):
			var target := cell + Vector2i(dx, dy)
			if not grid.in_bounds(target.x, target.y):
				return "种植格越界"
			var owner: Dictionary = water.body_of(target)
			if owner.is_empty():
				return "水生作物必须种在鱼栅水面上"
			if body_uid == 0:
				body_uid = int(owner["uid"])
			elif body_uid != int(owner["uid"]):
				return "种植格必须同属一个水体"
			if grid.state_at(target) == Grid.State.OCCUPIED:
				return "种植格被设施占用"
			if not instance_at(target).is_empty():
				return "种植格已有作物"
			for zone in ranch.state["zones"]:
				if String(zone["type"]) != "aqua_planting":
					continue
				if zone["cells"].has("%d,%d" % [target.x, target.y]):
					zone_row = zone
			if zone_row.is_empty() or int(zone_row.get("body_uid", 0)) != body_uid:
				return "种植格必须位于同一水体的水生种植区"
	if zone_row.is_empty() or not ranch.zone_structural(zone_row):
		return "水生种植区结构缺件"
	var stations := 0
	for facility in ranch._facilities_in_zone(zone_row):
		if String(facility["facility_id"]) == "aquatic_crop_station":
			stations += 1
	var planted := 0
	for uid in crops:
		var other: Dictionary = crops[uid]
		if String(crop_defs[String(other["crop_id"])].get("medium", "land")) != "water":
			continue
		var origin := Vector2i(int(other["origin"][0]), int(other["origin"][1]))
		if zone_row["cells"].has("%d,%d" % [origin.x, origin.y]):
			planted += 1
	if planted + 1 > stations * 8:
		return "水生种植台管理格数已满"
	return ""

## Water-crop day: light >= 60 and shared body quality >= 30 gate growth; each
## round pays its chosen nutrition once at the first advancing day.
func _settle_water_crop(row: Dictionary, definition: Dictionary, day: int) -> void:
	if String(row["state"]) == "mature":
		return
	var origin := Vector2i(int(row["origin"][0]), int(row["origin"][1]))
	var body: Dictionary = water.body_of(origin)
	if body.is_empty() or not water.quality_ok(body):
		record_operation({"kind": "water", "stage": "crop_pause", "day": day, "crop": String(row["crop_id"]),
			"origin": row["origin"], "quality": water.quality(body)})
		return
	if int(_light_at(origin)) < int(definition["light"]):
		record_operation({"kind": "water", "stage": "crop_pause", "day": day, "crop": String(row["crop_id"]),
			"origin": row["origin"], "quality": water.quality(body), "light": true})
		return
	if int(row.get("round_paid", -1)) != int(row["harvest_count"]):
		var wanted := String(row.get("round_input_id", "humus_round"))
		var chosen: Dictionary = {}
		for variant in definition.get("round_inputs", []):
			if String(variant["id"]) == wanted:
				chosen = variant
		if chosen.is_empty():
			chosen = definition["round_inputs"][0]
		var gate := String(chosen.get("research", ""))
		var enough := true
		for item in chosen["inputs"]:
			if not inventory.has(String(item), int(chosen["inputs"][item])):
				enough = false
		if not gate.is_empty() and not research.is_completed(gate):
			enough = false
		if not enough:
			record_operation({"kind": "water", "stage": "crop_short", "day": day, "crop": String(row["crop_id"]),
				"origin": row["origin"], "wanted": wanted})
			return
		for item in chosen["inputs"]:
			inventory.remove(String(item), int(chosen["inputs"][item]))
		_record_flow({}, chosen["inputs"], "水生作物轮投料")
		row["round_input_id"] = String(chosen["id"])
		row["round_paid"] = int(row["harvest_count"])
	var target := int(definition["cycle_days"] if int(row["harvest_count"]) > 0 else definition["days"]) * 100
	var before := int(row["progress"])
	row["progress"] = mini(target, before + 100)
	if int(row["progress"]) == target:
		row["state"] = "mature"
	record_operation({"kind": "water", "stage": "crop_grow", "day": day, "crop": String(row["crop_id"]),
		"origin": row["origin"], "before": before, "after": int(row["progress"]), "target": target,
		"quality": water.quality(body)})

## 0-AP round-nutrition choice for a water crop (humus or the matrix).
func set_water_round_input(cell: Vector2i, round_input_id: String) -> Dictionary:
	var crop := instance_at(cell)
	if crop.is_empty():
		return _error("这里没有水生作物")
	var definition: Dictionary = crop_defs[String(crop["crop_id"])]
	if String(definition.get("medium", "land")) != "water":
		return _error("只有水生作物选择轮投料")
	for variant in definition.get("round_inputs", []):
		if String(variant["id"]) == round_input_id:
			var blocked: String = research_block(String(variant.get("research", "")))
			if not blocked.is_empty():
				return _error(blocked)
			if int(crop.get("round_paid", -1)) == int(crop["harvest_count"]):
				return _error("本轮投料已付，选择只影响下一轮")
			crops[int(crop["uid"])]["round_input_id"] = round_input_id
			changed.emit()
			return {"ok": true}
	return _error("未知轮投料")

func _make_husbandry():
	return P8Husbandry.new(self, P8Data.load_data())

func _make_workforce():
	return P8Workforce.new(self)

func _settle_workforce(completed_day: int) -> void:
	# The unified P8 scheduler replaces the V1/V2 settle: facilities, research
	# and opted-in farm duty share one quota and budget per worker.
	flowers.begin_settle(completed_day)
	operations.settle(completed_day)
	flowers.finish_settle()

## Research advances from today's receipts after husbandry and before the
## reports archive, so unlock events land on the completed day; unused flower
## shares expire with the completed day.
func _settle_husbandry(completed_day: int) -> void:
	rooms.begin_settle(completed_day)
	husbandry.settle(completed_day)
	water.auto_services(completed_day)
	ranch.settle(completed_day)
	water.settle(completed_day)
	logistics.settle(completed_day)
	research.settle(completed_day)
	flowers.settle(completed_day)
	reports.settle(completed_day)

## The pen, the species yards and the intensive stations are structural ranch
## facilities: no habitat row is created for them and the ranch species never
## enter the old path.
func _facility_built(uid: int) -> void:
	var facility_id := String(facilities[uid]["facility_id"])
	if facility_id == "pen" or ranch.is_structural(facility_id):
		return
	super(uid)

func begin_research_settle(completed_day: int) -> void:
	research.begin_settle(completed_day)

func finish_research_settle() -> void:
	research.finish_settle()

## Scheduler seam: owned research benches with an open receipt slot today.
func _research_candidates(worker: Dictionary) -> Array:
	var out := []
	for uid in operations.facilities_of(int(worker["id"])):
		var facility: Dictionary = facilities.get(uid, {})
		if facility.is_empty() or facility_defs[String(facility["facility_id"])].get("kind") != "research":
			continue
		if research.work_quote(int(uid))["ok"]:
			out.append(operations._candidate(_tier_of(String(operations.state["facilities"][uid]["priority"])), 3, int(uid), "研究",
				"研究台#%d推进" % uid, "research:%d" % uid,
				func(): return research.work(int(uid), "worker")))
	return out

func _tier_of(level: String) -> int:
	return {"high": 0, "normal": 1, "low": 2}[level]

func demolish_facility(uid: int) -> Dictionary:
	if services.state["toys"].has(str(uid)): return _error("请先卸下玩具站里的藤球")
	if services.has_carry(uid): return _error("请先处理工作场已保留的工作余量")
	if not logistics.in_host(uid).is_empty(): return _error("请先撤回入驻后勤蛊，再拆除设施")
	if research != null and not research.active_project(uid).is_empty():
		return _error("研究台有在研项目，完成或处理后才能拆除")
	if ranch != null and ranch.workyard_busy(uid):
		return _error("工作场有运行或待领取批次，先领取或处理后再拆除")
	var result: Dictionary = super.demolish_facility(uid)
	if result["ok"] and facilities.get(uid, {}).is_empty() and research != null:
		research.forget_bench(uid)
	return result

func _facility_removed(uid: int) -> void:
	super(uid)
	operations.forget_facility(uid)
	devices.forget(uid)
	logistics.forget_facility(uid)
	ranch.forget_facility(uid)
	services.forget_facility(uid)
	water.forget_facility(uid)

func to_snapshot() -> Dictionary:
	var snapshot := super.to_snapshot()
	snapshot["world"]["land"] = land.to_save()
	snapshot["world"]["p8"] = operations.to_save()
	snapshot["world"]["research"] = research.to_save()
	snapshot["world"]["flowers"] = flowers.to_save()
	snapshot["world"]["devices"] = devices.to_save()
	snapshot["world"]["logistics"] = logistics.to_save()
	snapshot["world"]["agriculture"] = logistics.agri_to_save()
	snapshot["world"]["rooms"] = rooms.to_save()
	snapshot["world"]["ranch"] = ranch.to_save()
	snapshot["world"]["services"] = services.to_save()
	snapshot["world"]["water"] = water.to_save()
	snapshot["world"]["economy_progress"] = progress.to_save()
	return snapshot

func apply_snapshot(value) -> Dictionary:
	var checked: Dictionary = P8Snapshot.normalize(value)
	if not checked["ok"]: return checked
	land.apply_save(checked["snapshot"]["world"]["land"])
	grid.cell_access = land.contains
	return super.apply_snapshot(checked["snapshot"])

func _snapshot_applied(snapshot: Dictionary) -> void:
	super(snapshot)
	if snapshot["world"].has("p8"):
		operations.apply_save(snapshot["world"]["p8"])
	if snapshot["world"].has("research"):
		research.apply_save(snapshot["world"]["research"])
	if snapshot["world"].has("flowers"):
		flowers.apply_save(snapshot["world"]["flowers"])
	if snapshot["world"].has("devices"):
		devices.apply_save(snapshot["world"]["devices"])
	if snapshot["world"].has("logistics"):
		logistics.apply_save(snapshot["world"]["logistics"])
	if snapshot["world"].has("agriculture"):
		logistics.apply_agri_save(snapshot["world"]["agriculture"])
	rooms.apply_save(snapshot["world"]["rooms"])
	ranch.apply_save(snapshot["world"]["ranch"])
	services.apply_save(snapshot["world"]["services"])
	if snapshot["world"].has("water"):
		water.apply_save(snapshot["world"]["water"])
	progress.apply_save(snapshot["world"]["economy_progress"])

## Pollination bonus: one extra oilseed per pollinated cycle at harvest.
func _harvest_bonus(instance: Dictionary) -> Dictionary:
	var uid := int(instance["uid"])
	if String(instance["crop_id"]) == "oilseed_flower" and flowers.pollinated(uid):
		flowers.forget_crop(uid)
		return {"oilseed": 1}
	return {}

## Export real harvests for the ecological audit, including the single-cycle bonus.
func harvest(cell: Vector2i, mode: String = "harvest") -> Dictionary:
	var crop: Dictionary = instance_at(cell).duplicate(true)
	var was_pollinated: bool = not crop.is_empty() and flowers.pollinated(int(crop["uid"]))
	var day: int = clock.total_days
	var result: Dictionary = super(cell, mode)
	if result["ok"] and daily_save_error.is_empty():
		record_operation({"kind": "harvest", "stage": mode, "day": day, "uid": crop["uid"],
			"crop": crop["crop_id"], "origin": crop["origin"], "pollinated": was_pollinated, "outputs": result["base_items"]})
	return result

## Hand pick: one AP draws the plant's remaining share into real stock.
func pick_flower(cell: Vector2i) -> Dictionary:
	var checked: Dictionary = _can_act(1)
	if not checked["ok"]:
		return checked
	var crop := instance_at(cell)
	if crop.is_empty() or not flowers.is_flower_crop(String(crop["crop_id"])):
		return _error("这里没有可采花植物")
	var uid := int(crop["uid"])
	var drawn: Dictionary = flowers.consume(uid, "player")
	if not bool(drawn["ok"]):
		return _error("今日无可用花源份额（花期未到、环境不足或已用尽）")
	var contents: Dictionary = flowers.share_contents()
	for item in contents:
		inventory.add(item, int(contents[item]))
	_record_flow(contents, {}, "采花收获")
	return _finish(1, {"ok": true, "items": contents.duplicate(), "crop_uid": uid})

# --- Research gating -------------------------------------------------------

## Completed research is farm-wide knowledge; every gated def reads it live.
func _research_done(research_id: String) -> bool:
	return research.is_completed(research_id)

func research_block(research_id: String) -> String:
	var blocked: String = progress.block("research", research_id)
	if not blocked.is_empty(): return blocked
	if research_id.is_empty() or _research_done(research_id):
		return ""
	return "需先完成研究「%s」" % _research_name(research_id)

func _research_name(research_id: String) -> String:
	for row in P8Data.load_data()["research"]:
		if String(row["id"]) == research_id:
			return String(row["name"])
	return research_id

## Explicit construction substitutes for the plain-stone part of a build:
## composite panels 1:1 or reclaimed fill 2:1; special materials never swap.
var build_substitute := ""

func _substituted_materials(facility_id: String) -> Dictionary:
	var materials: Dictionary = facility_defs[facility_id]["materials"].duplicate()
	if build_substitute.is_empty() or not materials.has("raw_stone"):
		return materials
	var stones := int(materials["raw_stone"])
	materials.erase("raw_stone")
	if build_substitute == "panel":
		materials["composite_stone_panel"] = int(materials.get("composite_stone_panel", 0)) + stones
	elif build_substitute == "fill":
		materials["reclaimed_fill"] = int(materials.get("reclaimed_fill", 0)) + stones * 2
	return materials

## Swap the facility's material group for the substituted one around the shared
## validation/build so the plain-stone part is replaced as one whole group.
func _with_substituted(facility_id: String, action: Callable) -> Dictionary:
	var definition: Dictionary = facility_defs[facility_id]
	var original: Dictionary = definition["materials"]
	definition["materials"] = _substituted_materials(facility_id)
	var result: Dictionary = action.call()
	definition["materials"] = original
	return result

func can_build_facility(cell: Vector2i, facility_id: String) -> Dictionary:
	var stage_block: String = progress.block("facility", facility_id)
	if not stage_block.is_empty(): return _error(stage_block)
	if facility_id=="field_service_station" and grid.state_at(cell)==Grid.State.TILLED: return _error("请先把维护站脚下耕地改为普通地板或还原，避免桥接田块")
	if facility_defs.has(facility_id):
		var blocked := research_block(String(facility_defs[facility_id].get("research", "")))
		if not blocked.is_empty():
			return _error(blocked)
	# Ranch structures stand on ordinary floor; since P10.6 the dual-medium
	# shared structures and the aquatic facilities may instead stand on fenced
	# water cells (§16.2.5). Water-only facilities never accept floor cells.
	if facility_id in Ranch.FLOOR_FACILITIES or String(facility_defs[facility_id].get("terrain", "")) == "water":
		var shape: Array = facility_defs[facility_id]["footprint"]
		var wants_water: bool = String(facility_defs[facility_id].get("terrain", "")) == "water"
		var dual: bool = facility_defs[facility_id].has("terrains")
		for dy in range(int(shape[1])):
			for dx in range(int(shape[0])):
				var target := cell + Vector2i(dx, dy)
				if not grid.in_bounds(target.x, target.y):
					return _error("畜牧设施必须建在普通地板或鱼栅水面上，请先铺设")
				var on_floor: bool = rooms.floor_kind(target) == "ordinary"
				var on_fence: bool = grid.terrain_at(target) == "water" and not water.body_of(target).is_empty()
				if wants_water:
					if on_fence:
						continue
					return _error("水产设施必须建在鱼栅水面上")
				if on_floor or (dual and on_fence):
					continue
				return _error("畜牧设施必须建在普通地板上，请先铺设")
	if facility_defs.has(facility_id):
		var shape: Array = facility_defs[facility_id]["footprint"]
		for dy in range(int(shape[1])):
			for dx in range(int(shape[0])):
				var target := cell + Vector2i(dx, dy)
				if not land.contains(target): return _error(land.reason(target))
	if not build_substitute.is_empty() and facility_defs[facility_id]["materials"].has("raw_stone"):
		return _with_substituted(facility_id, func(): return super.can_build_facility(cell, facility_id))
	return super(cell, facility_id)

func build_facility(cell: Vector2i, facility_id: String, facing: String = "east") -> Dictionary:
	if facility_id=="field_service_station" and grid.state_at(cell)==Grid.State.TILLED: return _error("请先把维护站脚下耕地改为普通地板或还原")
	# The optional facing only applies to the agriculture host and takes effect
	# immediately: nothing can be active in a slot on its build day.
	if facility_id == "field_service_station" and not facing in ["east", "south", "west", "north"]:
		return _error("朝向非法")
	if not build_substitute.is_empty() and facility_defs[facility_id]["materials"].has("raw_stone"):
		return _with_substituted(facility_id, func(): return super.build_facility(cell, facility_id))
	var known := facilities.keys().duplicate()
	var result: Dictionary = super(cell, facility_id)
	if result["ok"] and facility_id == "field_service_station":
		for uid in facilities.keys():
			if not known.has(uid): logistics.attach_facing(int(uid), facing)
	return result

func plant(cell: Vector2i, crop_id: String, variant_id := "") -> Dictionary:
	if crop_defs.has(crop_id):
		var definition: Dictionary = crop_defs[crop_id]
		var shape: Array = definition["footprint"]
		if String(definition.get("medium", "land")) != "water" and not rooms.footprint_allowed(Rect2i(cell,Vector2i(int(shape[0]),int(shape[1])))):
			return _error("作物完整占地不能跨越田块边界")
		var blocked := research_block(String(definition.get("research", "")))
		if not blocked.is_empty():
			return _error(blocked)
		if not variant_id.is_empty():
			var gate := ""
			for row in definition.get("input_variants", []):
				if String(row["id"]) == variant_id:
					gate = String(row.get("research", ""))
			if not gate.is_empty():
				var blocked_variant: String = research_block(gate)
				if not blocked_variant.is_empty():
					return _error(blocked_variant)
	return super(cell, crop_id, variant_id)

func buy(item_id: String, quantity) -> Dictionary:
	if item_id == "purifying_mat_culture":
		return _error("培养单位请在净水菌床面板直接购入：扣款即占位，不入仓库")
	if _items.has(item_id):
		var blocked := research_block(String(_items[item_id].get("research", "")))
		if not blocked.is_empty():
			return _error(blocked)
	return super(item_id, quantity)

## The biological registry is the single authority for true animal labour.
## Filtering only the UI leaves manual/worker/model and save-forgery bypasses.
func batch_block(recipe_id: String) -> String:
	if ranch.settings["work"]["recipes"].has(recipe_id):
		return "生物工艺须由实际动物岗位推进，请在专属工作场安排生产"
	return ""

func start_batch(facility_uid: int, recipe_id: String) -> Dictionary:
	var biological: String = batch_block(recipe_id)
	if not biological.is_empty(): return _error(biological)
	if recipe_defs.has(recipe_id):
		var blocked := research_block(String(recipe_defs[recipe_id].get("research", "")))
		if not blocked.is_empty():
			return _error(blocked)
	var day := clock.total_days - 1 if _labour_action else clock.total_days
	var before := inventory.to_save()
	var strategy: Dictionary = operations.strategy_of(facility_uid)
	var effective: int = operations.effective_stock(String(strategy["target_item"])) if strategy["enabled"] else 0
	var result: Dictionary = super(facility_uid, recipe_id)
	if result.get("ok") and daily_save_error.is_empty():
		var batch: Dictionary = recipe_defs[recipe_id]
		record_operation({"kind": "batch", "stage": "start", "day": day, "uid": facility_uid,
			"batch_id": int(result["batch_id"]), "recipe": recipe_id, "inputs": batch["inputs"], "outputs": batch["outputs"],
			"operator": "worker" if _labour_action else "player", "stock_before": before, "strategy": strategy,
			"effective_before": effective, "reserves": operations.state["reserves"].duplicate()})
	return result

func claim_batch(facility_uid: int, expected_batch_id: int) -> Dictionary:
	var batch: Dictionary = facilities.get(facility_uid, {}).get("batch", {}).duplicate(true)
	var biological: String = batch_block(String(batch.get("recipe_id", "")))
	if not biological.is_empty(): return _error(biological)
	var day := clock.total_days - 1 if _labour_action else clock.total_days
	var result: Dictionary = super(facility_uid, expected_batch_id)
	if result.get("ok") and daily_save_error.is_empty():
		record_operation({"kind": "batch", "stage": "claim", "day": day, "uid": facility_uid,
			"batch_id": expected_batch_id, "recipe": batch["recipe_id"], "inputs": batch["inputs"], "outputs": batch["outputs"],
			"operator": "worker" if _labour_action else "player"})
	return result

func deliver_order(order_id: int, item_id: String) -> Dictionary:
	var result: Dictionary = super(order_id, item_id)
	if result.get("ok"):
		record_operation({"kind": "economy", "stage": "order", "day": clock.total_days,
			"order": order_id, "item": item_id, "quote": result["quote"].duplicate(), "orders": progress.deliveries()})
	return result

# --- Candidate day settlement ----------------------------------------------

func _can_act(ap: int = 1) -> Dictionary:
	# Capture the pre-action state whenever this action may trigger the day end;
	# a failed commit then restores the exact pre-operation world, keeping the
	# settled result only as a retryable candidate.
	if ap > 0 and not _labour_action and daily_save_error.is_empty() and clock.ap - ap <= 0:
		_day_checkpoint = to_snapshot()
	return super(ap)

func end_day() -> Dictionary:
	if daily_save_error.is_empty():
		_day_checkpoint = to_snapshot()
	return super()

## Day D+1 opening: lamps light first, then station services, all on real
## stock; a reload or replayed candidate never triggers a second opening.
func _opening_devices(day: int) -> void:
	logistics.run_opening(day)
	devices.run_opening(day)

func start_new(slot: int, overwrite_confirmed: bool = false) -> Dictionary:
	var created: Dictionary = super(slot, overwrite_confirmed)
	if created["ok"]:
		_opening_devices(0)
	return created

## Effective light: the day's active lamps lift covered cells to the lamp
## value; everything (growth, flowers, UI) reads this one query.
func environment_at(cell: Vector2i) -> Dictionary:
	var env := super(cell)
	if env.is_empty(): return env
	env["light"] = _light_at(cell)
	return env

func _light_at(cell: Vector2i) -> int:
	var natural := super(cell)
	if devices.lamp_active_at(cell):
		natural = maxi(natural, int(P8Data.load_data()["devices"]["lamp"]["light"]))
	if logistics != null: natural = maxi(natural,logistics.light_at(cell,int(logistics.state["active_day"])))
	return natural

func _crop_growth_percent(crop: Dictionary, day: int) -> int:
	# The agriculture gu resolve against the crop's full footprint and its
	# qualification tags, never against a single anchor cell.
	return logistics.growth_percent(_crop_rect(crop), crop_defs[crop["crop_id"]].get("target_tags", []), day)

func _crop_resource_retention(row: Dictionary, day: int) -> Dictionary:
	return logistics.retention_percent(_crop_rect(row), crop_defs[row["crop_id"]].get("target_tags", []), day)

func _consume_environment(cell: Vector2i, index: int, field: int, use: int, retention: int) -> void:
	logistics.consume_environment(cell, index, field, use, retention)

func _crop_rect(crop: Dictionary) -> Rect2i:
	var def: Dictionary = crop_defs[crop["crop_id"]]
	return Rect2i(Vector2i(int(crop["origin"][0]), int(crop["origin"][1])),
		Vector2i(int(def["footprint"][0]), int(def["footprint"][1])))

func till(cell: Vector2i) -> Dictionary:
	if rooms.state["floors"].has(Rooms.key(cell)): return _error("请使用地板工具将普通地板改为耕地")
	var result: Dictionary=super(cell)
	if result["ok"]: rooms._invalidate()
	return result

func action_quote(cell: Vector2i, kind: String) -> Dictionary:
	if kind=="till" and rooms.state["floors"].has(Rooms.key(cell)): return _error("普通地板不能直接开垦")
	return super(cell,kind)

func _crop_planted(row: Dictionary) -> void: rooms.plant_started(row)

func _crop_grew(row: Dictionary, delta: int, day: int) -> void: rooms.crop_grew(row,delta,day)

func _crop_clearing(row: Dictionary) -> Dictionary:
	# Cleanup belongs to the removal/seed candidate, before _finish can roll back.
	flowers.forget_crop(int(row["uid"]))
	return rooms.clear_crop(row)

func _crop_room_rewards(row: Dictionary, mode: String, base: Dictionary, removed: bool) -> Dictionary:
	return rooms.claim_crop(row,mode,base,removed)

func irrigate(cell: Vector2i) -> Dictionary:
	if logistics.at(cell).is_empty(): return super(cell)
	var checked := _can_act(1)
	if not checked["ok"]: return checked
	var settings: Dictionary = config["environment"]
	var index := grid.index_of(cell)
	if int(environment[index][0]) >= 100 or not inventory.has("clean_water",int(settings["irrigate_units"])): return _error("水分已满或缺少清水")
	inventory.remove("clean_water",int(settings["irrigate_units"]))
	_record_flow({}, {"clean_water":int(settings["irrigate_units"])},"后勤蛊补水")
	environment[index][0] = mini(100,int(environment[index][0])+int(settings["irrigate_gain"]))
	_count("fieldwork","irrigate")
	return _finish(1,{"ok":true})

func _commit_day(_day: int, ledger_error: String) -> void:
	if _store == null:
		return
	if not ledger_error.is_empty():
		_fail_day(ledger_error, {})
		return
	var candidate := to_snapshot()
	var saved: Dictionary = _store.commit(candidate)
	if saved["ok"]:
		_pending_day = {}
		_day_checkpoint = {}
		daily_save_error = ""
	else:
		_fail_day(String(saved["reason"]), candidate)

func _fail_day(reason: String, candidate: Dictionary) -> void:
	_pending_day = candidate
	if not _day_checkpoint.is_empty():
		var restore: Dictionary = _day_checkpoint
		_day_checkpoint = {}
		apply_snapshot(restore)
	daily_save_error = reason
	changed.emit()

## Retrying writes the retained candidate exactly once and publishes it; it
## never re-runs workers, ecology or the opening step.
func retry_day_save() -> Dictionary:
	if daily_save_error.is_empty() or _store == null or _store.active_slot() == 0:
		return _error("没有待重试的日存档")
	if _pending_day.is_empty():
		return _error("本日结未通过校验，无法重试；请放弃当天")
	var saved: Dictionary = _store.commit(_pending_day)
	if saved["ok"]:
		var publish: Dictionary = _pending_day
		_pending_day = {}
		_day_checkpoint = {}
		apply_snapshot(publish)
	return saved

func abandon_day() -> Dictionary:
	_pending_day = {}
	_day_checkpoint = {}
	return super()
