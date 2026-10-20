extends "res://scripts/farming/v2/v2_husbandry.gd"
## P8 water habitats turn real water maintenance into a limited daily water
## change that also produces wastewater stock (the T04 research sample source),
## and research-gated optional diets stay unselectable until unlocked.
var _automatic_plan := {}

func quote_automatic(facility_uid: int) -> Dictionary:
	var previous: Dictionary = _automatic_plan
	_automatic_plan = world.operations.habitat_plan(facility_uid)
	var quote := quote_maintenance(facility_uid)
	_automatic_plan = previous
	return quote

func maintain_automatic(facility_uid: int, service_day: int) -> Dictionary:
	var previous: Dictionary = _automatic_plan
	_automatic_plan = world.operations.habitat_plan(facility_uid)
	var strategy: Dictionary = world.operations.strategy_of(facility_uid)
	var effective: int = world.operations.effective_stock(String(strategy["target_item"])) if strategy["enabled"] else 0
	var result := maintain(facility_uid, "worker", service_day)
	if result["ok"] and world.daily_save_error.is_empty():
		world.record_operation({"kind": "automation", "stage": "habitat", "day": service_day, "uid": facility_uid,
			"strategy": strategy, "effective_before": effective, "started": result.get("started", 0),
			"stock_after": world.inventory.to_save(), "reserves": world.operations.state["reserves"].duplicate()})
	_automatic_plan = previous
	return result

func _targets_today(habitat: Dictionary) -> Array:
	var targets: Array = super(habitat)
	if _automatic_plan.is_empty(): return targets
	return targets.filter(func(unit): return _automatic_plan["basic"].has(int(unit["uid"])))

func _special_targets(habitat: Dictionary) -> Array:
	var targets: Array = super(habitat)
	if _automatic_plan.is_empty(): return targets
	return targets.filter(func(unit): return _automatic_plan["special"].has(int(unit["uid"])))

func _automatic_basic(uid: int) -> bool:
	return _automatic_plan.is_empty() or _automatic_plan["basic"].has(uid)

func _automatic_special(uid: int) -> bool:
	return _automatic_plan.is_empty() or _automatic_plan["special"].has(uid)

func apply_save(value: Dictionary) -> void:
	_automatic_plan = {}
	super(value)

## Zero-input honey cycles are valid diets. Changing the manual recipe stops
## the old automatic strategy without rewriting receipts of running cycles.
func set_special_diet(facility_uid: int, diet_id: String) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]: return checked
	if not world.facilities.has(facility_uid): return _error("未知设施")
	if world.facility_defs[String(world.facilities[facility_uid]["facility_id"])].get("kind") != "habitat":
		return _error("该设施没有养殖食谱")
	var habitat := ensure(facility_uid)
	if habitat.is_empty(): return _error("该设施没有养殖食谱")
	if not diet_id.is_empty():
		var definition: Dictionary = world.operations.recipe_definition(facility_uid, diet_id)
		if definition.is_empty(): return _error("食谱不适用于该物种")
		var blocked: String = world.research_block(String(definition.get("research", "")))
		if not blocked.is_empty(): return _error(blocked)
		habitat["special_diet_id"] = diet_id
	habitat["production_enabled"] = not diet_id.is_empty()
	habitat["default_notice"] = false
	var strategy: Dictionary = world.operations.state["production"].get(facility_uid, {})
	if not strategy.is_empty() and (diet_id.is_empty() or strategy["recipe_id"] != diet_id):
		strategy["enabled"] = false
	world.changed.emit()
	return {"ok": true, "detail": "生产食谱已保存；已有批次保留原投入与产物"}

## P8 ownership lives in the operations registry, not on the worker row.
func caretaker_of(facility_uid: int) -> Dictionary:
	var owner: int = world.operations.owner_of(facility_uid)
	return world.workforce._worker(owner) if owner > 0 else {}

## P10.3/P10.5: the pen, species yards and intensive stations are structural
## ranch facilities. They never create habitat state, so the ranch species
## cannot enter the per-day feeding path from any entry point.
func _ranch_structural(facility_id: String) -> bool:
	return world.ranch != null and world.ranch.is_structural(facility_id)

func ensure(facility_uid: int) -> Dictionary:
	if world.facilities.has(facility_uid) and _ranch_structural(String(world.facilities[facility_uid]["facility_id"])):
		return {}
	var habitat: Dictionary = super(facility_uid)
	if habitat.has("water") and not habitat.has("water_change_day"):
		habitat["water_change_day"] = -1
	return habitat

## Mixed yards pick their single species while empty; 0AP management only.
func set_yard_species(facility_uid: int, species_id: String) -> Dictionary:
	if world.facilities.has(facility_uid) and _ranch_structural(String(world.facilities[facility_uid]["facility_id"])):
		return _error("圈舍、役使设施与精养台已改为畜牧功能区结构件，请在畜牧分区中安置动物")
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	if not world.facilities.has(facility_uid):
		return _error("未知设施")
	var facility: Dictionary = world.facilities[facility_uid]
	if world.facility_defs[String(facility["facility_id"])].get("kind") != "habitat":
		return _error("该设施不能养殖")
	if not species_defs.has(species_id):
		return _error("未知物种")
	var definition: Dictionary = world.facility_defs[String(facility["facility_id"])]
	if not definition.get("species", []).has(species_id):
		return _error("该设施不接纳此物种")
	var habitat := ensure(facility_uid)
	if habitat.is_empty():
		return _error("该设施没有养殖配置")
	if not habitat["individuals"].is_empty():
		return _error("非空工作场不能更换物种；先清退全部动物")
	var blocked: String = world.research_block(String(species_defs[species_id].get("research", "")))
	if not blocked.is_empty(): return _error(blocked)
	habitat["species_id"] = species_id
	habitat["basic_diet_id"] = species_defs[species_id]["default_base_diet"]
	habitat["special_diet_id"] = species_defs[species_id]["default_special_diet"]
	habitat["production_enabled"] = true
	habitat["default_notice"] = true
	world.operations.state["production"].erase(facility_uid)
	world.changed.emit()
	return {"ok": true, "detail": "物种已切换，请重新设置本场自动生产策略"}

func quote_purchase(facility_uid: int, count: int) -> Dictionary:
	var stage_block: String = world.progress.block("capability", "animals")
	if not stage_block.is_empty(): return _error(stage_block)
	var habitat := habitat_of(facility_uid)
	if not habitat.is_empty():
		var blocked: String = world.research_block(String(species_defs[String(habitat["species_id"])].get("research", "")))
		if not blocked.is_empty(): return _error(blocked)
	return super(facility_uid, count)

## Read-only change quote; one real change per habitat per service day.
func quote_water(facility_uid: int) -> Dictionary:
	var base: Dictionary = super(facility_uid)
	if not base["ok"]:
		return base
	var habitat := habitat_of(facility_uid)
	if int(habitat.get("water_change_day", -1)) == _today():
		return _error("今日已换过水，每场每天最多一次换水")
	var change: Dictionary = settings["water"]["change"]
	base["inputs"] = change["inputs"].duplicate()
	base["gain"] = int(change["gain"])
	base["wastewater"] = int(change["wastewater"])
	return base

## Real water change: consumes clean water, raises the metric and issues the
## matching wastewater stock. Manual and caretaker runs share the day marker.
func maintain_water(facility_uid: int, operator: String = "player") -> Dictionary:
	var checked: Dictionary = world._can_act(int(settings["water"]["maintenance_ap"]))
	if not checked["ok"]:
		return checked
	var quote := quote_water(facility_uid)
	if not quote["ok"]:
		return quote
	var habitat := habitat_of(facility_uid)
	var before := int(habitat["water"])
	var day := _today()
	var inputs: Dictionary = quote["inputs"]
	var sewage := int(quote["wastewater"])
	if not Scalars.whole(world.inventory.count("wastewater") + sewage):
		return _error("输出库存越界：污水")
	for ident in inputs:
		world.inventory.remove(ident, int(inputs[ident]))
	world.inventory.add("wastewater", sewage)
	world._record_flow({"wastewater": sewage}, inputs, "水场换水")
	habitat["water"] = mini(int(settings["water"]["maximum"]), int(habitat["water"]) + int(quote["gain"]))
	habitat["water_change_day"] = _today()
	world._report_event({"category": "maintenance", "facility_uid": facility_uid, "kind": "水场换水",
		"count": 1, "items": inputs, "note": "水体+%d，产出污水%d" % [int(quote["gain"]), sewage]})
	var result: Dictionary = world._finish(int(quote["ap"]), {"ok": true, "water": int(habitat["water"]),
		"inputs": inputs, "wastewater": sewage, "operator": operator})

	if result["ok"] and world.daily_save_error.is_empty():
		world.record_operation({"kind": "water", "stage": "change", "day": day, "uid": facility_uid,
			"before": before, "after": result["water"], "inputs": inputs, "outputs": {"wastewater": sewage}, "operator": operator})
	return result

## Optional diets unlocked by research stay unselectable until P8.c tracks it.
func set_diet(facility_uid: int, diet_kind: String, slot: String, diet_id: String) -> Dictionary:
	var blocked := _diet_block(facility_uid, diet_kind, diet_id)
	if not blocked.is_empty():
		return _error(blocked)
	return super(facility_uid, diet_kind, slot, diet_id)

func _diet_block(facility_uid: int, diet_kind: String, diet_id: String) -> String:
	if diet_kind == "special_diets" and diet_id.is_empty():
		return ""
	if not world.facilities.has(facility_uid):
		return ""
	var habitat := habitat_of(facility_uid)
	if habitat.is_empty():
		return "该设施没有养殖配置"
	var species: Dictionary = species_def(habitat["species_id"])
	for diet in species[diet_kind]:
		if String(diet["id"]) == diet_id:
			return world.research_block(String(diet.get("research", "")))
	return ""


# --- P8.d bee colonies --------------------------------------------------------

func is_bee_habitat(facility_uid: int) -> bool:
	if not world.facilities.has(facility_uid):
		return false
	var habitat := habitat_of(facility_uid)
	return not habitat.is_empty() and String(habitat["species_id"]) == "bell_bee"

## Bees add one live flower share per unfed unit on top of the V2 quote.
func _bee_quote(facility_uid: int) -> Dictionary:
	var quote: Dictionary = super.quote_maintenance(facility_uid)
	if not quote["ok"] or not is_bee_habitat(facility_uid):
		return quote
	var needed := int(quote["basic"]["targets"])
	if needed <= 0:
		return quote
	var candidates: Array = world.flowers.hive_candidates(facility_uid)
	if candidates.size() < needed:
		return _error("附近花源份额不足：需%d份，可用%d份（手采与蜂群共享同一份额）" % [needed, candidates.size()])
	quote["flower_targets"] = candidates.slice(0, needed)
	return quote

## Whole-hive action: basic feeding draws real water plus internal flower
## shares; the honey cycle starts for idle adults (no extra stock inputs).
func _bee_maintain(facility_uid: int, operator: String = "player", service_day: int = -1) -> Dictionary:
	var checked: Dictionary = world._can_act(int(settings["maintenance_ap"]))
	if not checked["ok"]:
		return checked
	var quote := quote_maintenance(facility_uid)
	if not quote["ok"]:
		return quote
	var habitat := habitat_of(facility_uid)
	var day: int = service_day if service_day >= 0 else world.clock.total_days
	var basic: Dictionary = quote["basic"]
	var targets := _targets_today(habitat)
	var consumed_shares := []
	var pollinated_marks := []
	if int(basic["targets"]) > 0 and basic["ok"]:
		# Atomic share draw: on any failure the already-drawn shares go back.
		var shares: Array = world.flowers.hive_candidates(facility_uid)
		for index in range(int(basic["targets"])):
			var drawn: Dictionary = world.flowers.consume(int(shares[index]), "hive:%d" % facility_uid)
			if not bool(drawn["ok"]):
				for share_uid in consumed_shares:
					world.flowers.release(int(share_uid), false)
				return _error("花源份额竞争失败，本次未执行")
			consumed_shares.append(int(shares[index]))
			if bool(drawn["pollinated"]):
				pollinated_marks.append(int(shares[index]))
		var feed: Dictionary = basic["inputs"]
		for ident in feed:
			world.inventory.remove(ident, int(feed[ident]))
		world._record_flow({}, feed, "蜂群饲喂")
		var diet_id: String = habitat["basic_diet_id"]
		var diet := diet_inputs(habitat["species_id"], "base_diets", diet_id)
		for individual in targets:
			individual["base_service"] = {"day": day, "diet_id": diet_id, "inputs": diet.duplicate(), "operator": operator}
	var served := int(basic["targets"])
	var special: Dictionary = quote["special"]
	var started := 0
	if int(special["targets"]) > 0 and special["ok"] and bool(habitat["production_enabled"]):
		# Newly fed adults qualify through the stamped service record above.
		var species: Dictionary = species_defs[habitat["species_id"]]
		for individual in _special_targets(habitat):
			var cycle_uid := int(state["next_cycle_uid"])
			state["next_cycle_uid"] = cycle_uid + 1
			individual["cycle"] = {"uid": cycle_uid, "diet_id": habitat["special_diet_id"],
				"start_day": day, "inputs": {}, "outputs": species["outputs"].duplicate(),
				"progress": 0, "goal": int(species["cycle_days"]) * 100, "status": "running", "ready_day": -1}
			started += 1
	if served == 0 and started == 0:
		for share_uid in consumed_shares:
			world.flowers.release(int(share_uid), pollinated_marks.has(share_uid))
		return _error("本次维护没有可执行工作")
	if served > 0:
		world._report_event({"category": "maintenance", "facility_uid": facility_uid, "kind": "基础服务",
			"count": served, "items": quote["basic"]["inputs"], "note": "内部花源%d份" % served})
	if started > 0:
		world._report_event({"category": "maintenance", "facility_uid": facility_uid, "kind": "特殊投料",
			"count": started, "items": {}, "note": "开启酿蜜周期"})
	var outcome := {"ok": true, "served": served, "started": started, "shares": consumed_shares.duplicate()}
	outcome["detail"] = ("基础完成，%d群开启酿蜜周期" % started) if started > 0 else "基础完成；清水×%d，内部花源%d份" % [served, served]
	return world._finish(int(settings["maintenance_ap"]), outcome)

# --- P8.e purifying mats -----------------------------------------------------

func is_mat_habitat(facility_uid: int) -> bool:
	if not world.facilities.has(facility_uid):
		return false
	var habitat := habitat_of(facility_uid)
	return not habitat.is_empty() and String(habitat["species_id"]) == "purifying_mat"

## Mat maintenance: only juveniles drink culture water; running adults advance
## on their stamped service day without any base-diet input; idle adults start
## processing cycles whose inputs are paid once at the cycle start.
func _mat_quote(facility_uid: int) -> Dictionary:
	if not world.facilities.has(facility_uid):
		return _error("未知设施")
	var habitat := habitat_of(facility_uid)
	if habitat.is_empty():
		return _error("养殖配置尚未初始化")
	var juveniles := 0
	var runners := 0
	var idle_adults := 0
	for individual in habitat["individuals"]:
		if not _automatic_basic(int(individual["uid"])) and not _automatic_special(int(individual["uid"])): continue
		if int(individual["base_service"]["day"]) == _today():
			continue
		if individual["stage"] == "juvenile":
			juveniles += 1
		elif not individual.get("cycle", {}).is_empty():
			# Ready units wait for the claim; they take no further paid service.
			if String(individual["cycle"]["status"]) == "running":
				runners += 1
		else:
			idle_adults += 1
	var basic := {"targets": 0, "inputs": {}, "ok": false, "reason": ""}
	if juveniles > 0:
		basic["targets"] = juveniles
		basic["inputs"] = _scale(diet_inputs("purifying_mat", "base_diets", String(habitat["basic_diet_id"])), juveniles)
		basic["ok"] = true
		for ident in basic["inputs"]:
			if not world.inventory.has(ident, int(basic["inputs"][ident])):
				basic["ok"] = false
				basic["reason"] = "缺少培养清水：" + world._items[ident]["name"]
				break
	var special := {"targets": 0, "inputs": {}, "ok": false, "reason": "", "enabled": bool(habitat["production_enabled"])}
	if not bool(habitat["production_enabled"]):
		special["reason"] = "已停止启动新批次；已有批次仍按原投入继续"
	elif idle_adults > 0:
		special["targets"] = idle_adults
		special["inputs"] = _scale(diet_inputs("purifying_mat", "special_diets", String(habitat["special_diet_id"])), idle_adults)
		special["ok"] = true
		for ident in special["inputs"]:
			var reserved := int(basic["inputs"].get(ident, 0)) if basic["ok"] else 0
			if world.inventory.count(ident) - reserved < int(special["inputs"][ident]):
				special["ok"] = false
				special["reason"] = "缺少处理投入：" + world._items[ident]["name"]
				break
	elif juveniles == 0 and runners == 0:
		special["reason"] = "没有空闲成体可启动批次"
	if not basic["ok"] and basic["targets"] > 0:
		return _error(String(basic["reason"]))
	if juveniles == 0 and runners == 0 and int(special["targets"]) == 0:
		if habitat["individuals"].is_empty():
			return _error("床内没有培养单位")
		return _error("全部单位今日已维护")
	var work: bool = (int(basic["targets"]) > 0 and basic["ok"]) or runners > 0 or (int(special["targets"]) > 0 and special["ok"])
	if not work:
		var reason := String(basic["reason"]) if int(basic["targets"]) > 0 else ""
		if int(special["targets"]) > 0:
			reason += "；批次未启动：" + String(special["reason"])
		return _error(reason if not reason.is_empty() else "本次维护没有可执行工作")
	return {"ok": true, "basic": basic, "special": special, "runners": runners, "ap": int(settings["maintenance_ap"])}

func maintain(facility_uid: int, operator: String = "player", service_day: int = -1) -> Dictionary:
	var first_cycle := int(state["next_cycle_uid"])
	var day: int = service_day if service_day >= 0 else world.clock.total_days
	var result: Dictionary
	if is_bee_habitat(facility_uid):
		result = _bee_maintain(facility_uid, operator, service_day)
	elif is_mat_habitat(facility_uid):
		result = _mat_maintain(facility_uid, operator, service_day)
	else:
		result = super(facility_uid, operator, service_day)
	if result.get("ok") and world.daily_save_error.is_empty():
		var habitat := habitat_of(facility_uid)
		for unit in habitat["individuals"]:
			var cycle: Dictionary = unit.get("cycle", {})
			if not cycle.is_empty() and int(cycle["uid"]) >= first_cycle:
				_cycle_receipt(habitat, unit, cycle, "start", day, operator)
	return result

func _cycle_receipt(habitat: Dictionary, unit: Dictionary, cycle: Dictionary, stage: String, day: int, operator: String) -> void:
	world.record_operation({"kind": "cycle", "stage": stage, "day": day, "uid": int(habitat["facility_uid"]),
		"batch_id": int(cycle["uid"]), "unit": int(unit["uid"]), "species": habitat["species_id"],
		"recipe": cycle["diet_id"], "inputs": cycle["inputs"], "outputs": cycle["outputs"], "operator": operator})

func claim(facility_uid: int, expected: Array = [], operator: String = "player") -> Dictionary:
	var habitat := habitat_of(facility_uid).duplicate(true)
	var day := _today()
	var result: Dictionary = super(facility_uid, expected, operator)
	if result.get("ok") and world.daily_save_error.is_empty():
		for unit in habitat.get("individuals", []):
			var cycle: Dictionary = unit.get("cycle", {})
			if not cycle.is_empty() and cycle["status"] == "ready": _cycle_receipt(habitat, unit, cycle, "claim", day, operator)
	return result

func quote_maintenance(facility_uid: int) -> Dictionary:
	if is_bee_habitat(facility_uid):
		return _bee_quote(facility_uid)
	if is_mat_habitat(facility_uid):
		return _mat_quote(facility_uid)
	return super(facility_uid)

func _mat_maintain(facility_uid: int, operator: String = "player", service_day: int = -1) -> Dictionary:
	var checked: Dictionary = world._can_act(int(settings["maintenance_ap"]))
	if not checked["ok"]:
		return checked
	var quote := _mat_quote(facility_uid)
	if not quote["ok"]:
		return quote
	var habitat := habitat_of(facility_uid)
	var day: int = service_day if service_day >= 0 else world.clock.total_days
	var basic: Dictionary = quote["basic"]
	var special: Dictionary = quote["special"]
	var inputs := {}
	var juveniles := 0
	var stamped := 0
	var started := 0
	if int(basic["targets"]) > 0 and basic["ok"]:
		for ident in basic["inputs"]:
			world.inventory.remove(ident, int(basic["inputs"][ident]))
			inputs[ident] = int(basic["inputs"][ident])
		world._record_flow({}, basic["inputs"], "菌毯培养")
	var diet_id: String = String(habitat["basic_diet_id"])
	var diet := diet_inputs("purifying_mat", "base_diets", diet_id)
	var species: Dictionary = species_defs["purifying_mat"]
	var special_outputs := diet_outputs("purifying_mat", "special_diets", String(habitat["special_diet_id"]))
	for individual in habitat["individuals"]:
		if not _automatic_basic(int(individual["uid"])): continue
		if int(individual["base_service"]["day"]) == _today():
			continue
		if individual["stage"] == "juvenile":
			individual["base_service"] = {"day": day, "diet_id": diet_id, "inputs": diet.duplicate(), "operator": operator}
			juveniles += 1
			stamped += 1
		elif not individual.get("cycle", {}).is_empty() and String(individual["cycle"]["status"]) == "running":
			# Running batches advance on the stamped service day; the inputs
			# were paid in full once at the cycle start.
			individual["base_service"] = {"day": day, "diet_id": diet_id, "inputs": {}, "operator": operator}
			stamped += 1
	if int(special["targets"]) > 0 and special["ok"]:
		for ident in special["inputs"]:
			world.inventory.remove(ident, int(special["inputs"][ident]))
			inputs[ident] = int(inputs.get(ident, 0)) + int(special["inputs"][ident])
		world._record_flow({}, special["inputs"], "净化启动")
		for individual in habitat["individuals"]:
			if not _automatic_special(int(individual["uid"])): continue
			if individual["stage"] != "adult" or not individual.get("cycle", {}).is_empty() or int(individual["base_service"]["day"]) == _today():
				continue
			var cycle_uid := int(state["next_cycle_uid"])
			state["next_cycle_uid"] = cycle_uid + 1
			individual["base_service"] = {"day": day, "diet_id": diet_id, "inputs": {}, "operator": operator}
			individual["cycle"] = {"uid": cycle_uid, "diet_id": String(habitat["special_diet_id"]),
				"start_day": day, "inputs": diet_inputs("purifying_mat", "special_diets", String(habitat["special_diet_id"])),
				"outputs": special_outputs.duplicate(), "progress": 0,
				"goal": int(species["cycle_days"]) * 100, "status": "running", "ready_day": -1}
			started += 1
			stamped += 1
	if stamped == 0:
		return _error("本次维护没有可执行工作")
	if juveniles > 0:
		world._report_event({"category": "maintenance", "facility_uid": facility_uid, "kind": "基础服务",
			"count": juveniles, "items": quote["basic"]["inputs"], "note": "幼体培养清水"})
	if started > 0:
		world._report_event({"category": "maintenance", "facility_uid": facility_uid, "kind": "特殊投料",
			"count": started, "items": quote["special"]["inputs"], "note": "启动净化批次"})
	if juveniles == 0 and started == 0:
		world._report_event({"category": "maintenance", "facility_uid": facility_uid, "kind": "基础服务",
			"count": int(quote["runners"]), "items": {}, "note": "推进在制批次"})
	var outcome := {"ok": true, "served": stamped, "started": started, "inputs": inputs}
	if started > 0:
		outcome["detail"] = "培养%d幼体；启动%d个净化批次" % [juveniles, started]
	elif juveniles > 0:
		outcome["detail"] = "培养%d幼体；推进%d个在制批次" % [juveniles, int(quote["runners"])]
	else:
		outcome["detail"] = "推进%d个在制批次" % int(quote["runners"])
	return world._finish(int(settings["maintenance_ap"]), outcome)
