extends RefCounted
## P7.b husbandry runtime: habitats reuse existing facility UIDs; P7.c adds production cycles.
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")

var _owner: WeakRef
var world:
	get:
		return _owner.get_ref()
var state: Dictionary
var species_defs: Dictionary
var settings: Dictionary

func _init(owner, data: Dictionary) -> void:
	_owner = weakref(owner)
	species_defs = {}
	for row in data["livestock"]:
		species_defs[row["id"]] = row
	settings = data["husbandry"]
	state = {"habitats": [], "next_animal_uid": 1}

func _error(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

func species_def(species_id: String) -> Dictionary:
	return species_defs[species_id]

func diet_inputs(species_id: String, diet_kind: String, diet_id: String) -> Dictionary:
	var species: Dictionary = species_defs[species_id]
	for diet in species[diet_kind]:
		if diet["id"] == diet_id:
			return diet["inputs"].duplicate()
	return {}

func diet_name(species_id: String, diet_kind: String, diet_id: String) -> String:
	var species: Dictionary = species_defs[species_id]
	for diet in species[diet_kind]:
		if diet["id"] == diet_id:
			return String(diet["name"])
	return ""

func is_water_habitat(facility_id: String) -> bool:
	return world.facility_defs[facility_id].get("terrain") == "water"

## Live habitat row; habitat facilities without an entry (built on the last AP tick)
## get their notified default configuration created on first touch.
func ensure(facility_uid: int) -> Dictionary:
	for habitat in state["habitats"]:
		if int(habitat["facility_uid"]) == facility_uid:
			return habitat
	var facility: Dictionary = world.facilities[facility_uid]
	var species_id: String = world.facility_defs[facility["facility_id"]]["species"][0]
	var species: Dictionary = species_defs[species_id]
	var habitat := {"facility_uid": facility_uid, "species_id": species_id,
		"basic_diet_id": species["default_base_diet"], "special_diet_id": species["default_special_diet"],
		"production_enabled": false, "default_notice": true, "individuals": []}
	if is_water_habitat(facility["facility_id"]):
		habitat["water"] = int(settings["water"]["initial"])
	state["habitats"].append(habitat)
	return habitat

func habitat_of(facility_uid: int) -> Dictionary:
	for habitat in state["habitats"]:
		if int(habitat["facility_uid"]) == facility_uid:
			return habitat
	return {}

func forget(facility_uid: int) -> void:
	for habitat in state["habitats"].duplicate():
		if int(habitat["facility_uid"]) == facility_uid:
			state["habitats"].erase(habitat)

func summary(habitat: Dictionary) -> Dictionary:
	var out := {"total": habitat["individuals"].size(), "juvenile": 0, "adult": 0, "fed_today": 0}
	for individual in habitat["individuals"]:
		out["adult" if individual["stage"] == "adult" else "juvenile"] += 1
		if int(individual["base_service"]["day"]) == world.clock.total_days:
			out["fed_today"] += 1
	return out

func _targets_today(habitat: Dictionary) -> Array:
	var out := []
	for individual in habitat["individuals"]:
		if int(individual["base_service"]["day"]) != world.clock.total_days:
			out.append(individual)
	return out

func _scale(inputs: Dictionary, count: int) -> Dictionary:
	var out := {}
	for ident in inputs:
		out[ident] = int(inputs[ident]) * count
	return out

## Valid day-ends before the water metric pauses growth; 0 when already at or below.
func water_support_days(habitat: Dictionary) -> int:
	if not habitat.has("water") or habitat["individuals"].is_empty():
		return 0
	var value := int(habitat["water"])
	var decay := int(settings["water"]["decay"])
	var threshold := int(settings["water"]["pause_threshold"])
	var support := 0
	while value - decay > threshold:
		value -= decay
		support += 1
	return support

## Shared read-only care preview: today's unfed demand, tomorrow's whole-herd demand,
## remaining growth rations, stock coverage and water support days.
func care_quote(habitat: Dictionary, extra: int) -> Dictionary:
	var diet := diet_inputs(habitat["species_id"], "base_diets", habitat["basic_diet_id"])
	var after := int(habitat["individuals"].size()) + extra
	return {"today_unfed": _scale(diet, _targets_today(habitat).size() + extra),
		"tomorrow_full": _scale(diet, after),
		"growth_needs": _growth_needs(habitat, extra),
		"coverage": _coverage(diet, after),
		"water_support_days": water_support_days(habitat)}

## Read-only purchase quote: risk previews never reserve stock or block trading.
func quote_purchase(facility_uid: int, count: int) -> Dictionary:
	if not world.facilities.has(facility_uid):
		return _error("未知设施")
	var facility: Dictionary = world.facilities[facility_uid]
	var definition: Dictionary = world.facility_defs[facility["facility_id"]]
	if definition.get("kind") != "habitat":
		return _error("该设施不能养殖")
	var habitat := habitat_of(facility_uid)
	if habitat.is_empty():
		return _error("养殖配置尚未初始化")
	var capacity := int(definition["capacity"])
	var left := capacity - int(habitat["individuals"].size())
	if not Scalars.whole(count, 1, left):
		return _error("购入数量非法或超出剩余容量%d" % left)
	var quote := care_quote(habitat, count)
	quote["ok"] = true
	quote["count"] = count
	quote["total"] = int(species_defs[habitat["species_id"]]["juvenile_price"]) * count
	quote["capacity_left"] = left
	quote["after_count"] = habitat["individuals"].size() + count
	return quote

## Remaining feed for juveniles to reach adulthood; a served-but-unsettled day is
## subtracted so the same ration is never demanded twice.
func _growth_needs(habitat: Dictionary, extra: int) -> Dictionary:
	var diet := diet_inputs(habitat["species_id"], "base_diets", habitat["basic_diet_id"])
	var days := 0
	for individual in habitat["individuals"]:
		if individual["stage"] != "juvenile":
			continue
		var remaining := int(species_defs[habitat["species_id"]]["growth_days"]) - int(int(individual["growth"]) / 100)
		if int(individual["base_service"]["day"]) == world.clock.total_days:
			remaining -= 1
		days += maxi(0, remaining)
	days += int(species_defs[habitat["species_id"]]["growth_days"]) * extra
	return _scale(diet, days)

func _coverage(diet: Dictionary, daily_heads: int) -> Dictionary:
	var out := {}
	if daily_heads <= 0:
		return out
	for ident in diet:
		var per_day := int(diet[ident]) * daily_heads
		if per_day > 0:
			out[ident] = {"daily": per_day, "days": int(world.inventory.count(ident) / per_day)}
	return out

## Juveniles plus 0 AP; money, capacity and species are hard checks.
func purchase(facility_uid: int, count: int) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	var quote := quote_purchase(facility_uid, count)
	if not quote["ok"]:
		return quote
	var habitat := habitat_of(facility_uid)
	var total := int(quote["total"])
	if world.primeval_stones < total:
		return _error("元石不足")
	world.primeval_stones -= total
	var purchased := []
	for _index in range(count):
		var uid := int(state["next_animal_uid"])
		state["next_animal_uid"] = uid + 1
		purchased.append({"uid": uid, "stage": "juvenile", "growth": 0,
			"base_service": {"day": -1, "diet_id": "", "inputs": {}, "operator": ""}})
		habitat["individuals"].append(purchased[-1])
	return world._finish(0, {"ok": true, "purchased": purchased, "total": total,
		"species_id": habitat["species_id"], "quote": quote})

func set_base_diet(facility_uid: int, diet_id: String) -> Dictionary:
	return _set_diet(facility_uid, "base_diets", "basic_diet_id", diet_id)

func set_special_diet(facility_uid: int, diet_id: String) -> Dictionary:
	return _set_diet(facility_uid, "special_diets", "special_diet_id", diet_id)

func set_diet(facility_uid: int, diet_kind: String, slot: String, diet_id: String) -> Dictionary:
	return _set_diet(facility_uid, diet_kind, slot, diet_id)

func _set_diet(facility_uid: int, diet_kind: String, slot: String, diet_id: String) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	if not world.facilities.has(facility_uid):
		return _error("未知设施")
	var habitat := ensure(facility_uid)
	if diet_inputs(habitat["species_id"], diet_kind, diet_id).is_empty():
		return _error("食谱不适用于该物种")
	habitat[slot] = diet_id
	habitat["default_notice"] = false
	world.changed.emit()
	return {"ok": true}

## Read-only whole-facility basic-service quote, including the predicted post-decay
## water check that blocks feeding when today's growth could never apply.
func quote_maintenance(facility_uid: int) -> Dictionary:
	if not world.facilities.has(facility_uid):
		return _error("未知设施")
	var facility: Dictionary = world.facilities[facility_uid]
	if world.facility_defs[facility["facility_id"]].get("kind") != "habitat":
		return _error("该设施不能养殖")
	var habitat := habitat_of(facility_uid)
	if habitat.is_empty():
		return _error("养殖配置尚未初始化")
	var targets := _targets_today(habitat)
	if targets.is_empty():
		return _error("场内没有动物" if habitat["individuals"].is_empty() else "全部个体今日已服务")
	var inputs := _scale(diet_inputs(habitat["species_id"], "base_diets", habitat["basic_diet_id"]), targets.size())
	for ident in inputs:
		if not world.inventory.has(ident, int(inputs[ident])):
			return _error("缺少基础食物：" + world._items[ident]["name"])
	if habitat.has("water") and not habitat["individuals"].is_empty():
		var predicted := maxi(0, int(habitat["water"]) - int(settings["water"]["decay"]))
		if predicted <= int(settings["water"]["pause_threshold"]):
			return _error("水体日结后将降至%d，本次投喂不能支持成长，请先维护水体" % predicted)
	return {"ok": true, "targets": targets.size(), "inputs": inputs, "ap": int(settings["maintenance_ap"])}

## One whole-branch service: all unserved individuals or nobody; the service ledger
## entry is written before the AP so the last action point still counts as today's feeding.
func maintain(facility_uid: int) -> Dictionary:
	var checked: Dictionary = world._can_act(int(settings["maintenance_ap"]))
	if not checked["ok"]:
		return checked
	var quote := quote_maintenance(facility_uid)
	if not quote["ok"]:
		return quote
	var habitat := habitat_of(facility_uid)
	var targets := _targets_today(habitat)
	var diet_id: String = habitat["basic_diet_id"]
	var diet := diet_inputs(habitat["species_id"], "base_diets", diet_id)
	var inputs: Dictionary = quote["inputs"]
	for ident in inputs:
		world.inventory.remove(ident, int(inputs[ident]))
	world._record_flow({}, inputs, "养殖投喂")
	var day: int = world.clock.total_days
	for individual in targets:
		individual["base_service"] = {"day": day, "diet_id": diet_id, "inputs": diet.duplicate(), "operator": "player"}
	return world._finish(int(settings["maintenance_ap"]), {"ok": true, "served": targets.size(), "inputs": inputs})

## Read-only water quote; an empty pond neither decays nor needs maintenance.
func quote_water(facility_uid: int) -> Dictionary:
	if not world.facilities.has(facility_uid):
		return _error("未知设施")
	var facility: Dictionary = world.facilities[facility_uid]
	if not is_water_habitat(facility["facility_id"]):
		return _error("该设施没有水体")
	var habitat := habitat_of(facility_uid)
	if habitat.is_empty():
		return _error("养殖配置尚未初始化")
	if habitat["individuals"].is_empty():
		return _error("空场水体不衰减，无需维护")
	if int(habitat["water"]) >= int(settings["water"]["maximum"]):
		return _error("水体已满")
	var inputs: Dictionary = settings["water"]["maintenance_inputs"]
	for ident in inputs:
		if not world.inventory.has(ident, int(inputs[ident])):
			return _error("缺少维护材料：" + world._items[ident]["name"])
	var occupied := maxi(0, int(habitat["water"]) - int(settings["water"]["decay"]))
	return {"ok": true, "current": int(habitat["water"]), "predicted": occupied,
		"inputs": inputs.duplicate(), "gain": int(settings["water"]["maintenance_gain"]), "ap": int(settings["water"]["maintenance_ap"])}

func maintain_water(facility_uid: int) -> Dictionary:
	var checked: Dictionary = world._can_act(int(settings["water"]["maintenance_ap"]))
	if not checked["ok"]:
		return checked
	var quote := quote_water(facility_uid)
	if not quote["ok"]:
		return quote
	var habitat := habitat_of(facility_uid)
	var inputs: Dictionary = quote["inputs"]
	for ident in inputs:
		world.inventory.remove(ident, int(inputs[ident]))
	world._record_flow({}, inputs, "水体维护")
	habitat["water"] = mini(int(settings["water"]["maximum"]), int(habitat["water"]) + int(quote["gain"]))
	return world._finish(int(quote["ap"]), {"ok": true, "water": int(habitat["water"]), "inputs": inputs})

## Remove every animal of one habitat; no refunds, no products, facility and plans stay.
func cull(facility_uid: int) -> Dictionary:
	var checked: Dictionary = world._can_act(int(settings["maintenance_ap"]))
	if not checked["ok"]:
		return checked
	if not world.facilities.has(facility_uid):
		return _error("未知设施")
	var habitat := habitat_of(facility_uid)
	if habitat.is_empty() or habitat["individuals"].is_empty():
		return _error("空场没有可清退的动物")
	var removed := int(habitat["individuals"].size())
	habitat["individuals"] = []
	return world._finish(int(settings["maintenance_ap"]), {"ok": true, "removed": removed})

## Day settlement happens after workers and before crops; P7.b only advances growth.
func settle(completed_day: int) -> void:
	for habitat in state["habitats"]:
		var occupied: bool = not habitat["individuals"].is_empty()
		var paused := false
		if habitat.has("water") and occupied:
			habitat["water"] = maxi(0, int(habitat["water"]) - int(settings["water"]["decay"]))
			paused = int(habitat["water"]) <= int(settings["water"]["pause_threshold"])
		if paused:
			continue
		var target := int(species_defs[habitat["species_id"]]["growth_days"]) * 100
		for individual in habitat["individuals"]:
			if individual["stage"] == "juvenile" and int(individual["base_service"]["day"]) == completed_day:
				individual["growth"] = mini(target, int(individual["growth"]) + 100)
				if int(individual["growth"]) >= target:
					individual["stage"] = "adult"
					individual["growth"] = target

func to_save() -> Dictionary:
	return state.duplicate(true)

func apply_save(value: Dictionary) -> void:
	state = value.duplicate(true)

## Detached validation against the already normalized base world snapshot.
static func normalize(value, day: int, world: Dictionary, catalog, settings: Dictionary) -> Dictionary:
	if not Scalars.exact(value, ["habitats", "next_animal_uid"]):
		return Scalars.fail("养殖快照字段非法")
	if not value["habitats"] is Array or not Scalars.whole(value["next_animal_uid"], 1):
		return Scalars.fail("养殖序号非法")
	var species_defs := {}
	for row in catalog.load_data()["livestock"]:
		species_defs[row["id"]] = row
	var facility_defs: Dictionary = catalog.definitions("facilities")
	var facilities := {}
	var max_facility_uid := 0
	for row in world["facilities"]:
		facilities[int(row["uid"])] = row
		max_facility_uid = maxi(max_facility_uid, int(row["uid"]))
	var out := {"habitats": [], "next_animal_uid": int(value["next_animal_uid"])}
	var seen_uids := {}
	for habitat in value["habitats"]:
		if not Scalars.exact(habitat, ["facility_uid", "species_id", "basic_diet_id", "special_diet_id", "production_enabled", "default_notice", "individuals"] + (["water"] if habitat.get("water") != null else [])):
			return Scalars.fail("养殖设施字段非法")
		if not Scalars.whole(habitat["facility_uid"], 1, max_facility_uid) or not facilities.has(int(habitat["facility_uid"])) or not habitat["species_id"] is String:
			return Scalars.fail("养殖设施引用非法")
		var facility: Dictionary = facilities[int(habitat["facility_uid"])]
		var definition: Dictionary = facility_defs[facility["facility_id"]]
		if definition.get("kind") != "habitat" or not definition["species"].has(habitat["species_id"]):
			return Scalars.fail("设施与物种不匹配")
		var species: Dictionary = species_defs[habitat["species_id"]]
		var base_ids := {}
		for diet in species["base_diets"]:
			base_ids[diet["id"]] = diet["inputs"]
		var special_ids := {}
		for diet in species["special_diets"]:
			special_ids[diet["id"]] = diet["inputs"]
		if not base_ids.has(habitat["basic_diet_id"]) or not special_ids.has(habitat["special_diet_id"]):
			return Scalars.fail("食谱不属于该物种")
		if not habitat["production_enabled"] is bool or not habitat["default_notice"] is bool:
			return Scalars.fail("养殖配置标志非法")
		var wants_water: bool = definition.get("terrain") == "water"
		if wants_water != habitat.has("water") or (wants_water and not Scalars.whole(habitat["water"], 0, int(settings["water"]["maximum"]))):
			return Scalars.fail("水体字段非法")
		if not habitat["individuals"] is Array or habitat["individuals"].size() > int(definition["capacity"]):
			return Scalars.fail("个体数量超出容量")
		var individuals := []
		var target := int(species["growth_days"]) * 100
		for individual in habitat["individuals"]:
			if not Scalars.exact(individual, ["uid", "stage", "growth", "base_service"]):
				return Scalars.fail("个体字段非法")
			if not Scalars.whole(individual["uid"], 1, int(value["next_animal_uid"]) - 1) or seen_uids.has(int(individual["uid"])):
				return Scalars.fail("个体序号重复或非法")
			seen_uids[int(individual["uid"])] = true
			if individual["stage"] not in ["juvenile", "adult"]:
				return Scalars.fail("个体阶段非法")
			if individual["stage"] == "adult":
				if int(individual["growth"]) != target:
					return Scalars.fail("成体成长进度非法")
			elif not Scalars.whole(individual["growth"], 0, target - 100):
				return Scalars.fail("幼体成长进度非法")
			var service = individual["base_service"]
			if not Scalars.exact(service, ["day", "diet_id", "inputs", "operator"]) or not Scalars.whole(service["day"], -1, day):
				return Scalars.fail("服务记录非法")
			if int(service["day"]) < 0:
				if service["diet_id"] != "" or not service["inputs"].is_empty() or service["operator"] != "":
					return Scalars.fail("未服务个体不能有服务记录")
			else:
				# Same-day history may legitimately differ from the current plan.
				if not base_ids.has(service["diet_id"]) or service["inputs"] != base_ids[service["diet_id"]]:
					return Scalars.fail("服务食谱或投入与记录不符")
				if service["operator"] != "player":
					return Scalars.fail("未知服务来源")
			individuals.append(individual.duplicate(true))
		var normalized := {"facility_uid": int(habitat["facility_uid"]), "species_id": habitat["species_id"],
			"basic_diet_id": habitat["basic_diet_id"], "special_diet_id": habitat["special_diet_id"],
			"production_enabled": habitat["production_enabled"], "default_notice": habitat["default_notice"],
			"individuals": individuals}
		if wants_water:
			normalized["water"] = int(habitat["water"])
		out["habitats"].append(normalized)
	return {"ok": true, "husbandry": out}
