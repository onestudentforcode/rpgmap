extends RefCounted
## Husbandry runtime: habitats reuse facility UIDs. P7.c adds special production
## cycles (sheep shear keeps the adult, carp harvest removes it) and two-branch
## whole-facility maintenance.
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")

var _owner: WeakRef
var world:
	get:
		return _owner.get_ref()
var state: Dictionary
var species_defs: Dictionary
var settings: Dictionary
## During settlement patrols the clock has already advanced; service checks read
## this effective day instead so worker feeding stays on the completed day.
var _patrol_day := -1

func _today() -> int:
	return _patrol_day if _patrol_day >= 0 else world.clock.total_days

func _init(owner, data: Dictionary) -> void:
	_owner = weakref(owner)
	species_defs = {}
	for row in data["livestock"]:
		species_defs[row["id"]] = row
	settings = data["husbandry"]
	state = {"habitats": [], "next_animal_uid": 1, "next_cycle_uid": 1}

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
		"production_enabled": true, "default_notice": true, "individuals": []}
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
	var out := {"total": habitat["individuals"].size(), "juvenile": 0, "adult": 0, "fed_today": 0,
		"idle_adults": 0, "running": 0, "ready": 0}
	for individual in habitat["individuals"]:
		out["adult" if individual["stage"] == "adult" else "juvenile"] += 1
		if int(individual["base_service"]["day"]) == _today():
			out["fed_today"] += 1
		var cycle: Dictionary = individual.get("cycle", {})
		if cycle.is_empty():
			if individual["stage"] == "adult":
				out["idle_adults"] += 1
		elif cycle["status"] == "ready":
			out["ready"] += 1
		else:
			out["running"] += 1
	return out

func _targets_today(habitat: Dictionary) -> Array:
	var out := []
	for individual in habitat["individuals"]:
		if int(individual["base_service"]["day"]) != _today():
			out.append(individual)
	return out

## Special-branch targets: adult, idle, already fed today, and the plan allows new cycles.
func _special_targets(habitat: Dictionary) -> Array:
	var out := []
	for individual in habitat["individuals"]:
		if individual["stage"] != "adult" or not individual.get("cycle", {}).is_empty():
			continue
		if int(individual["base_service"]["day"]) != _today():
			continue
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

## Read-only care preview: today's unfed demand, tomorrow's whole-herd demand,
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
	quote["after_count"] = int(habitat["individuals"].size()) + count
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
		if int(individual["base_service"]["day"]) == _today():
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
	# Juvenile purchases are real cash outflow inside the existing purchase total.
	world._cash("purchase_spend", total)
	var purchased := []
	for _index in range(count):
		var uid := int(state["next_animal_uid"])
		state["next_animal_uid"] = uid + 1
		purchased.append({"uid": uid, "stage": "juvenile", "growth": 0,
			"base_service": {"day": -1, "diet_id": "", "inputs": {}, "operator": ""},
			"cycle": {}})
		habitat["individuals"].append(purchased[-1])
	world._report_event({"category": "purchase", "facility_uid": facility_uid, "kind": String(habitat["species_id"]),
		"count": count, "items": {}, "note": "购入%d只，花费%d元石" % [count,total]})
	return world._finish(0, {"ok": true, "purchased": purchased, "total": total,
		"species_id": habitat["species_id"], "quote": quote})

func set_base_diet(facility_uid: int, diet_id: String) -> Dictionary:
	return _set_diet(facility_uid, "base_diets", "basic_diet_id", diet_id)

## Selecting "" stops new cycles but keeps the last legal recipe for a later restart.
func set_special_diet(facility_uid: int, diet_id: String) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	if not world.facilities.has(facility_uid):
		return _error("未知设施")
	var habitat := ensure(facility_uid)
	if diet_id.is_empty():
		habitat["production_enabled"] = false
		habitat["default_notice"] = false
		world.changed.emit()
		return {"ok": true}
	if diet_inputs(habitat["species_id"], "special_diets", diet_id).is_empty():
		return _error("食谱不适用于该物种")
	habitat["special_diet_id"] = diet_id
	habitat["production_enabled"] = true
	habitat["default_notice"] = false
	world.changed.emit()
	return {"ok": true}

func set_diet(facility_uid: int, diet_kind: String, slot: String, diet_id: String) -> Dictionary:
	if diet_kind == "special_diets":
		return set_special_diet(facility_uid, diet_id)
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

## Read-only two-branch maintenance quote. The special branch re-checks against the
## stock that remains after a successful basic branch would have deducted its feed.
func quote_maintenance(facility_uid: int) -> Dictionary:
	if not world.facilities.has(facility_uid):
		return _error("未知设施")
	var facility: Dictionary = world.facilities[facility_uid]
	if world.facility_defs[facility["facility_id"]].get("kind") != "habitat":
		return _error("该设施不能养殖")
	var habitat := habitat_of(facility_uid)
	if habitat.is_empty():
		return _error("养殖配置尚未初始化")
	if habitat.has("water") and not habitat["individuals"].is_empty():
		var predicted := maxi(0, int(habitat["water"]) - int(settings["water"]["decay"]))
		if predicted <= int(settings["water"]["pause_threshold"]):
			return _error("水体日结后将降至%d，本次投喂不能支持成长，请先维护水体" % predicted)
	var basic := {"targets": 0, "inputs": {}, "ok": false, "reason": "今日没有未服务个体"}
	var targets := _targets_today(habitat)
	if not targets.is_empty():
		basic["targets"] = targets.size()
		basic["inputs"] = _scale(diet_inputs(habitat["species_id"], "base_diets", habitat["basic_diet_id"]), targets.size())
		basic["ok"] = true
		for ident in basic["inputs"]:
			if not world.inventory.has(ident, int(basic["inputs"][ident])):
				basic["ok"] = false
				basic["reason"] = "缺少基础食物：" + world._items[ident]["name"]
				break
	var special := {"targets": 0, "inputs": {}, "ok": false, "reason": "", "enabled": bool(habitat["production_enabled"])}
	# The special branch re-runs after the basic branch: adults fed earlier today and
	# adults this action is about to feed both qualify for a new cycle.
	var special_targets := _special_targets(habitat)
	if int(basic["targets"]) > 0 and basic["ok"]:
		for individual in _targets_today(habitat):
			if individual["stage"] == "adult" and individual.get("cycle", {}).is_empty():
				special_targets.append(individual)
	if not bool(habitat["production_enabled"]):
		special["reason"] = "已停止启动新周期；已有周期仍按原投入继续"
	elif special_targets.is_empty():
		special["reason"] = "暂无成年空闲且今日已喂的个体"
	else:
		special["targets"] = special_targets.size()
		special["inputs"] = _scale(diet_inputs(habitat["species_id"], "special_diets", habitat["special_diet_id"]), special_targets.size())
		special["ok"] = true
		for ident in special["inputs"]:
			var reserved := int(basic["inputs"].get(ident, 0)) if basic["ok"] else 0
			if world.inventory.count(ident) - reserved < int(special["inputs"][ident]):
				special["ok"] = false
				special["reason"] = "缺少特殊投入：" + world._items[ident]["name"]
				break
	var work: bool = (int(basic["targets"]) > 0 and basic["ok"]) or (int(special["targets"]) > 0 and special["ok"])
	if not work:
		var reason := ""
		if int(basic["targets"]) > 0:
			reason = String(basic["reason"])
		elif habitat["individuals"].is_empty():
			reason = "场内没有动物"
		else:
			reason = "全部个体今日已服务"
		if int(special["targets"]) > 0:
			reason += "；特殊未启动：" + String(special["reason"])
		return _error(reason)
	return {"ok": true, "basic": basic, "special": special, "ap": int(settings["maintenance_ap"])}

## One whole-facility action: the basic and special branches each commit atomically,
## services and flows are written before the single AP can trigger the day end.
func maintain(facility_uid: int, operator: String = "player", service_day: int = -1) -> Dictionary:
	var checked: Dictionary = world._can_act(int(settings["maintenance_ap"]))
	if not checked["ok"]:
		return checked
	var quote := quote_maintenance(facility_uid)
	if not quote["ok"]:
		return quote
	var habitat := habitat_of(facility_uid)
	# Settlement patrols pass the completed service day explicitly: the clock has
	# already advanced and worker feeding must not land on tomorrow.
	var day: int = service_day if service_day >= 0 else world.clock.total_days
	var served := 0
	var started := 0
	var inputs := {}
	var basic: Dictionary = quote["basic"]
	if int(basic["targets"]) > 0 and basic["ok"]:
		var feed: Dictionary = basic["inputs"]
		for ident in feed:
			world.inventory.remove(ident, int(feed[ident]))
		world._record_flow({}, feed, "养殖投喂")
		var diet_id: String = habitat["basic_diet_id"]
		var diet := diet_inputs(habitat["species_id"], "base_diets", diet_id)
		for individual in _targets_today(habitat):
			individual["base_service"] = {"day": day, "diet_id": diet_id, "inputs": diet.duplicate(), "operator": operator}
			served += 1
		for ident in feed:
			inputs[ident] = int(feed[ident])
	var special: Dictionary = quote["special"]
	if int(special["targets"]) > 0 and special["ok"]:
		var feed_special: Dictionary = special["inputs"]
		for ident in feed_special:
			world.inventory.remove(ident, int(feed_special[ident]))
		world._record_flow({}, feed_special, "特殊投料")
		var species: Dictionary = species_defs[habitat["species_id"]]
		for individual in _special_targets(habitat):
			var cycle_uid := int(state["next_cycle_uid"])
			state["next_cycle_uid"] = cycle_uid + 1
			individual["cycle"] = {"uid": cycle_uid, "diet_id": habitat["special_diet_id"],
				"start_day": day, "inputs": diet_inputs(habitat["species_id"], "special_diets", habitat["special_diet_id"]),
				"outputs": species["outputs"].duplicate(), "progress": 0,
				"goal": int(species["cycle_days"]) * 100, "status": "running", "ready_day": -1}
			started += 1
		for ident in feed_special:
			inputs[ident] = int(inputs.get(ident, 0)) + int(feed_special[ident])
	if served == 0 and started == 0:
		return _error("本次维护没有可执行工作")
	if served > 0:
		world._report_event({"category": "maintenance", "facility_uid": facility_uid, "kind": "基础服务",
			"count": served, "items": quote["basic"]["inputs"], "note": ""})
	if started > 0:
		world._report_event({"category": "maintenance", "facility_uid": facility_uid, "kind": "特殊投料",
			"count": started, "items": quote["special"]["inputs"], "note": ""})
	var outcome := {"ok": true, "served": served, "started": started, "inputs": inputs}
	if served > 0 and started > 0:
		outcome["detail"] = "基础完成，%d只成体已启动周期" % started
	elif started > 0:
		outcome["detail"] = "沿用今日基础服务；启动%d只成体周期" % started
	else:
		outcome["detail"] = "基础完成；特殊未启动：" + String(special["reason"])
	return world._finish(int(settings["maintenance_ap"]), outcome)

## Read-only claim quote: products are frozen per cycle; claiming is never blocked
## by today's feeding or the paused water metric.
func quote_claim(facility_uid: int) -> Dictionary:
	if not world.facilities.has(facility_uid):
		return _error("未知设施")
	var habitat := habitat_of(facility_uid)
	if habitat.is_empty():
		return _error("养殖配置尚未初始化")
	var outputs := {}
	var ids := []
	var keeps := 0
	var removes := 0
	for individual in habitat["individuals"]:
		var cycle: Dictionary = individual.get("cycle", {})
		if cycle.is_empty() or cycle["status"] != "ready":
			continue
		ids.append([int(individual["uid"]), int(cycle["uid"])])
		for item in cycle["outputs"]:
			outputs[item] = int(outputs.get(item, 0)) + int(cycle["outputs"][item])
		if species_defs[habitat["species_id"]]["claim_removes"]:
			removes += 1
		else:
			keeps += 1
	if ids.is_empty():
		return _error("没有待收个体")
	return {"ok": true, "ready": ids.size(), "outputs": outputs, "keeps": keeps, "removes": removes, "ids": ids, "ap": int(settings["claim_ap"])}

## Collect every ready individual of the facility: sheep stay idle adults, carp are
## removed. Optional expected ids reject stale requests instead of claiming another batch.
func claim(facility_uid: int, expected: Array = [], operator: String = "player") -> Dictionary:
	var checked: Dictionary = world._can_act(int(settings["claim_ap"]))
	if not checked["ok"]:
		return checked
	var quote := quote_claim(facility_uid)
	if not quote["ok"]:
		return quote
	if not expected.is_empty() and expected != quote["ids"]:
		return _error("待收对象已变化，请刷新后重试")
	var habitat := habitat_of(facility_uid)
	var outputs: Dictionary = quote["outputs"]
	for item in outputs:
		if not Scalars.whole(world.inventory.count(item) + int(outputs[item])):
			return _error("输出库存越界：" + world._items[item]["name"])
	for item in outputs:
		world.inventory.add(item, int(outputs[item]))
	world._record_flow(outputs, {}, "养殖收取")
	for individual in habitat["individuals"].duplicate():
		var cycle: Dictionary = individual.get("cycle", {})
		if cycle.is_empty() or cycle["status"] != "ready":
			continue
		if species_defs[habitat["species_id"]]["claim_removes"]:
			habitat["individuals"].erase(individual)
		else:
			individual["cycle"] = {}
	world._report_event({"category": "claim", "facility_uid": facility_uid, "kind": "收取",
		"count": int(quote["ready"]), "items": outputs,
		"note": "移除%d只" % int(quote["removes"]) if int(quote["removes"]) > 0 else "保留%d只" % int(quote["keeps"])})
	return world._finish(int(settings["claim_ap"]), {"ok": true, "outputs": outputs.duplicate(),
		"kept": int(quote["keeps"]), "removed": int(quote["removes"]), "ids": quote["ids"].duplicate()})

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

func maintain_water(facility_uid: int, operator: String = "player") -> Dictionary:
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
	world._report_event({"category": "maintenance", "facility_uid": facility_uid, "kind": "水体维护",
		"count": 1, "items": inputs, "note": "水体+%d" % int(quote["gain"])})
	habitat["water"] = mini(int(settings["water"]["maximum"]), int(habitat["water"]) + int(quote["gain"]))
	return world._finish(int(quote["ap"]), {"ok": true, "water": int(habitat["water"]), "inputs": inputs})

## Abandoned cycles and pending products for the cull confirmation text.
func abandon_quote(facility_uid: int) -> Dictionary:
	var habitat := habitat_of(facility_uid)
	var outputs := {}
	var inputs := {}
	var pending := 0
	var running := 0
	for individual in habitat.get("individuals", []):
		var cycle: Dictionary = individual.get("cycle", {})
		if cycle.is_empty():
			continue
		if cycle["status"] == "ready":
			pending += 1
			for item in cycle["outputs"]:
				outputs[item] = int(outputs.get(item, 0)) + int(cycle["outputs"][item])
		else:
			running += 1
			for item in cycle["inputs"]:
				inputs[item] = int(inputs.get(item, 0)) + int(cycle["inputs"][item])
	return {"pending": pending, "running": running, "outputs": outputs, "inputs": inputs}

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
	var abandoned := abandon_quote(facility_uid)
	habitat["individuals"] = []
	world._report_event({"category": "cull", "facility_uid": facility_uid, "kind": "清退",
		"count": removed, "items": {}, "note": "放弃待收%s与在制%s" % [
			"、".join(abandoned["outputs"].keys()) if not abandoned["outputs"].is_empty() else "无",
			"、".join(abandoned["inputs"].keys()) if not abandoned["inputs"].is_empty() else "无"]})
	return world._finish(int(settings["maintenance_ap"]), {"ok": true, "removed": removed})

## Day settlement happens after workers and before crops; a valid day advances both
## growth and the running cycle by exactly one step, never two.
func settle(completed_day: int) -> void:
	for habitat in state["habitats"]:
		var occupied: bool = not habitat["individuals"].is_empty()
		var paused := false
		if habitat.has("water") and occupied:
			habitat["water"] = maxi(0, int(habitat["water"]) - int(settings["water"]["decay"]))
			paused = int(habitat["water"]) <= int(settings["water"]["pause_threshold"])
		if paused:
			world._report_event({"category": "pause", "facility_uid": int(habitat["facility_uid"]), "kind": "水体暂停",
				"count": int(habitat["individuals"].size()), "items": {}, "note": "水体已降至%d" % int(habitat["water"])})
			continue
		var grown := 0
		var readied := 0
		var target := int(species_defs[habitat["species_id"]]["growth_days"]) * 100
		for individual in habitat["individuals"]:
			if int(individual["base_service"]["day"]) != completed_day:
				continue
			if individual["stage"] == "juvenile":
				individual["growth"] = mini(target, int(individual["growth"]) + 100)
				if int(individual["growth"]) >= target:
					individual["stage"] = "adult"
					individual["growth"] = target
					grown += 1
			var cycle: Dictionary = individual.get("cycle", {})
			if not cycle.is_empty() and cycle["status"] == "running":
				cycle["progress"] = mini(int(cycle["goal"]), int(cycle["progress"]) + 100)
				if int(cycle["progress"]) >= int(cycle["goal"]):
					cycle["status"] = "ready"
					cycle["ready_day"] = completed_day
					readied += 1
		if grown > 0:
			world._report_event({"category": "growth", "facility_uid": int(habitat["facility_uid"]), "kind": "成年",
				"count": grown, "items": {}, "note": ""})
		if readied > 0:
			world._report_event({"category": "growth", "facility_uid": int(habitat["facility_uid"]), "kind": "就绪待收",
				"count": readied, "items": {}, "note": ""})

## Exclusive caretaker binding: one worker per habitat, one habitat per worker.
func caretaker_of(facility_uid: int) -> Dictionary:
	for worker in world.workforce.state["workers"]:
		if int(worker.get("caretaker_facility", 0)) == facility_uid:
			return worker
	return {}

func caretaker_preview(facility_uid: int, worker_id: int) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	if not world.facilities.has(facility_uid) or world.facility_defs[world.facilities[facility_uid]["facility_id"]].get("kind") != "habitat":
		return _error("只能指派圈舍或水场负责人")
	if worker_id != 0 and world.workforce._worker(worker_id).is_empty():
		return _error("未知雇工")
	var releases := {"areas": 0, "sources": []}
	if worker_id != 0:
		var worker: Dictionary = world.workforce._worker(worker_id)
		releases["areas"] = worker["areas"].size()
		for source in world.workforce.state["sources"]:
			if int(world.workforce.state["sources"][source]) == worker_id:
				releases["sources"].append(source)
	var displaced: Dictionary = caretaker_of(facility_uid)
	var moving := {}
	if worker_id != 0:
		var current: int = int(world.workforce._worker(worker_id).get("caretaker_facility", 0))
		if current > 0:
			moving = {"from_facility": current}
	return {"ok": true, "facility_uid": facility_uid, "worker_id": worker_id,
		"releases": releases, "displaced": displaced.get("name", ""), "moving": moving}

## Binding is management state only: 0AP, 0 stones, no feeding, no claiming.
func assign_caretaker(facility_uid: int, worker_id: int) -> Dictionary:
	var preview := caretaker_preview(facility_uid, worker_id)
	if not preview["ok"]:
		return preview
	var workforce = world.workforce
	for worker in workforce.state["workers"]:
		if int(worker.get("caretaker_facility", 0)) == facility_uid and int(worker["id"]) != worker_id:
			worker.erase("caretaker_facility")
	if worker_id == 0:
		world.changed.emit()
		return {"ok": true}
	var worker: Dictionary = workforce._worker(worker_id)
	for other in workforce.state["workers"]:
		if int(other.get("caretaker_facility", 0)) == facility_uid:
			other.erase("caretaker_facility")
	worker["caretaker_facility"] = facility_uid
	# Exclusive scope: personal areas and source assignments end; global marks and
	# seed plans stay for the remaining farm workers.
	worker["areas"] = []
	for source in workforce.state["sources"].keys().duplicate():
		if int(workforce.state["sources"][source]) == worker_id:
			workforce.state["sources"].erase(source)
	world.changed.emit()
	return {"ok": true, "released": preview["releases"]}

## Read-only daily cost preview for the caretaker card.
func patrol_estimate(facility_uid: int) -> String:
	if not world.facilities.has(facility_uid):
		return "设施不存在"
	var labels := PackedStringArray()
	if quote_claim(facility_uid)["ok"]:
		labels.append("收取")
	var habitat := habitat_of(facility_uid)
	if not habitat.is_empty() and habitat.has("water") and not habitat["individuals"].is_empty() 	and int(habitat["water"]) <= int(settings["water"]["worker_threshold"]) and quote_water(facility_uid)["ok"]:
		labels.append("水体维护")
	if quote_maintenance(facility_uid)["ok"]:
		labels.append("整体维护")
	if labels.is_empty():
		return "当前无待办，费用0"
	return "按当前状态可能："+"→".join(labels)+"，最多约%d元石" % labels.size()

## Day-end patrol per facility: claim → necessary water → whole maintenance.
## One step per worker per round; every step rechecks budget, cash and stock.
func run_patrols(completed_day: int) -> void:
	var workforce = world.workforce
	var fee := int(workforce.settings["fee_per_success"])
	var limit := int(workforce.settings["daily_work_limit"])
	var caretakers := []
	for worker in workforce.state["workers"]:
		if int(worker.get("caretaker_facility", 0)) <= 0:
			continue
		caretakers.append(worker)
	if caretakers.is_empty():
		return
	_patrol_day = completed_day
	var rows := {}
	for row in workforce.state["report"]["workers"]:
		rows[int(row["worker_id"])] = row
	for worker in caretakers:
		var row: Dictionary = rows[int(worker["id"])]
		row["caretaker"] = {"facility_uid": int(worker["caretaker_facility"]),
			"steps": {"收取": 0, "水体维护": 0, "整体维护": 0}, "skipped": []}
		if worker["paused"]:
			row["reason"] = "已暂停"
	var water_done := {}
	world._labour_action = true
	for _round in range(limit):
		var progressed := false
		for worker in caretakers:
			if worker["paused"]:
				continue
			var row: Dictionary = rows[int(worker["id"])]
			if int(row["fee"]) + fee > int(worker["budget"]) or world.primeval_stones < fee:
				if not row["caretaker"]["skipped"].has("预算或元石不足"):
					row["caretaker"]["skipped"].append("预算或元石不足")
				row["reason"] = "预算或元石不足"
				continue
			var facility_uid := int(worker["caretaker_facility"])
			var step := _patrol_step(facility_uid, water_done, completed_day)
			if step.is_empty():
				if not worker["paused"] and String(row["reason"]) in ["没有可执行工作", "工作完成"]:
					row["reason"] = "专责设施无待办"
				continue
			var result: Dictionary = step["action"].call()
			if not result["ok"]:
				if not row["caretaker"]["skipped"].has(result.get("reason", "步骤失败")):
					row["caretaker"]["skipped"].append(String(result.get("reason", "步骤失败")))
				continue
			world.primeval_stones -= fee
			workforce.state["spent"] = int(workforce.state["spent"]) + fee
			world._cash("labour_spend", fee)
			row["success"] = int(row["success"]) + 1
			row["fee"] = int(row["fee"]) + fee
			row["caretaker"]["steps"][step["kind"]] = int(row["caretaker"]["steps"][step["kind"]]) + 1
			world._report_event({"category": "labour", "facility_uid": facility_uid, "kind": String(step["kind"]),
				"count": 1, "items": {}, "note": String(worker["name"])})
			row["reason"] = "巡栏完成：" + String(step["kind"])
			if step["kind"] == "水体维护":
				water_done[facility_uid] = true
			progressed = true
		if not progressed:
			break
	_patrol_day = -1
	world._labour_action = false

func _patrol_step(facility_uid: int, water_done: Dictionary, patrol_day: int) -> Dictionary:
	if not world.facilities.has(facility_uid):
		return {}
	if husbandry_claim_ready(facility_uid):
		return {"kind": "收取", "action": func(): return claim(facility_uid, [], "worker")}
	var habitat := habitat_of(facility_uid)
	if not habitat.is_empty() and habitat.has("water") and not habitat["individuals"].is_empty() 	and not water_done.has(facility_uid) and int(habitat["water"]) <= int(settings["water"]["worker_threshold"]):
		var quote := quote_water(facility_uid)
		if quote["ok"]:
			return {"kind": "水体维护", "action": func(): return maintain_water(facility_uid, "worker")}
		return {"kind": "水体维护", "action": func(): return _error(String(quote["reason"]))}
	var quote := quote_maintenance(facility_uid)
	if quote["ok"]:
		return {"kind": "整体维护", "action": func(): return maintain(facility_uid, "worker", patrol_day)}
	return {}

func husbandry_claim_ready(facility_uid: int) -> bool:
	var quote := quote_claim(facility_uid)
	return quote["ok"]

func to_save() -> Dictionary:
	return state.duplicate(true)

func apply_save(value: Dictionary) -> void:
	state = value.duplicate(true)

## Caretaker bindings live in the workforce rows; cross-validate them against the
## normalized world: real habitat facilities, one caretaker each, no farm duties left.
static func validate_caretakers(workforce: Dictionary, world: Dictionary, catalog) -> Dictionary:
	var facility_defs: Dictionary = catalog.definitions("facilities")
	var facilities := {}
	for row in world["facilities"]:
		facilities[int(row["uid"])] = row
	var taken := {}
	for worker in workforce["workers"]:
		var bound := int(worker.get("caretaker_facility", 0))
		if bound <= 0:
			continue
		if not facilities.has(bound) or facility_defs[facilities[bound]["facility_id"]].get("kind") != "habitat":
			return Scalars.fail("负责人指向未知或非养殖设施")
		if taken.has(bound):
			return Scalars.fail("同一设施不能有多名负责人")
		taken[bound] = true
		if not worker["areas"].is_empty():
			return Scalars.fail("专责雇工不能保留负责区域")
		for source in workforce["sources"]:
			if int(workforce["sources"][source]) == int(worker["id"]):
				return Scalars.fail("专责雇工不能保留资源点指派")
	return {"ok": true}

## Detached validation against the already normalized base world snapshot.
static func normalize(value, day: int, world: Dictionary, catalog, settings: Dictionary) -> Dictionary:
	if not Scalars.exact(value, ["habitats", "next_animal_uid", "next_cycle_uid"]):
		return Scalars.fail("养殖快照字段非法")
	if not value["habitats"] is Array or not Scalars.whole(value["next_animal_uid"], 1) or not Scalars.whole(value["next_cycle_uid"], 1):
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
	var out := {"habitats": [], "next_animal_uid": int(value["next_animal_uid"]), "next_cycle_uid": int(value["next_cycle_uid"])}
	var seen_uids := {}
	var seen_cycles := {}
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
		var cycle_goal := int(species["cycle_days"]) * 100
		for individual in habitat["individuals"]:
			if not Scalars.exact(individual, ["uid", "stage", "growth", "base_service", "cycle"]):
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
				if service["operator"] not in ["player", "worker"]:
					return Scalars.fail("未知服务来源")
			var cycle = individual["cycle"]
			var normalized_cycle := {}
			if not cycle.is_empty():
				if individual["stage"] != "adult":
					return Scalars.fail("只有成体可以携带周期")
				if not Scalars.exact(cycle, ["uid", "diet_id", "start_day", "inputs", "outputs", "progress", "goal", "status", "ready_day"]):
					return Scalars.fail("周期字段非法")
				if not Scalars.whole(cycle["uid"], 1, int(value["next_cycle_uid"]) - 1) or seen_cycles.has(int(cycle["uid"])):
					return Scalars.fail("周期序号重复或非法")
				seen_cycles[int(cycle["uid"])] = true
				if not special_ids.has(cycle["diet_id"]) or cycle["inputs"] != special_ids[cycle["diet_id"]]:
					return Scalars.fail("周期食谱或投入与冻结记录不符")
				# Frozen outputs must stay exactly the configured species products.
				if cycle["outputs"] != species["outputs"]:
					return Scalars.fail("周期产物与物种配置不符")
				if int(cycle["goal"]) != cycle_goal or not Scalars.whole(cycle["progress"], 0, cycle_goal):
					return Scalars.fail("周期目标或进度非法")
				if not Scalars.whole(cycle["start_day"], 0, day):
					return Scalars.fail("周期开始日非法")
				if cycle["status"] == "running":
					if int(cycle["progress"]) > cycle_goal - 100 or int(cycle["ready_day"]) != -1:
						return Scalars.fail("进行中周期进度或就绪日非法")
				elif cycle["status"] == "ready":
					if int(cycle["progress"]) != cycle_goal or not Scalars.whole(cycle["ready_day"], 0, day) or int(cycle["ready_day"]) <= int(cycle["start_day"]):
						return Scalars.fail("待收周期进度或就绪日非法")
				else:
					return Scalars.fail("周期状态非法")
				normalized_cycle = {"uid": int(cycle["uid"]), "diet_id": cycle["diet_id"], "start_day": int(cycle["start_day"]),
					"inputs": cycle["inputs"].duplicate(), "outputs": cycle["outputs"].duplicate(),
					"progress": int(cycle["progress"]), "goal": int(cycle["goal"]), "status": cycle["status"],
					"ready_day": int(cycle["ready_day"])}
			var normalized_service := {}
			if int(service["day"]) < 0:
				normalized_service = {"day": -1, "diet_id": "", "inputs": {}, "operator": ""}
			else:
				normalized_service = {"day": int(service["day"]), "diet_id": service["diet_id"],
					"inputs": service["inputs"].duplicate(), "operator": "player" if service["operator"] == "player" else "worker"}
			if int(service["day"]) >= 0 and service["operator"] not in ["player", "worker"]:
				return Scalars.fail("未知服务来源")
			individuals.append({"uid": int(individual["uid"]), "stage": individual["stage"], "growth": int(individual["growth"]),
				"base_service": normalized_service, "cycle": normalized_cycle})
		var normalized_habitat := {"facility_uid": int(habitat["facility_uid"]), "species_id": habitat["species_id"],
			"basic_diet_id": habitat["basic_diet_id"], "special_diet_id": habitat["special_diet_id"],
			"production_enabled": habitat["production_enabled"], "default_notice": habitat["default_notice"],
			"individuals": individuals}
		if wants_water:
			normalized_habitat["water"] = int(habitat["water"])
		out["habitats"].append(normalized_habitat)
	return {"ok": true, "husbandry": out}
