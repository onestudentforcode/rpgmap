extends "res://scripts/farming/v2/v2_husbandry.gd"
## P8 water habitats turn real water maintenance into a limited daily water
## change that also produces wastewater stock (the T04 research sample source),
## and research-gated optional diets stay unselectable until unlocked.

## P8 ownership lives in the operations registry, not on the worker row.
func caretaker_of(facility_uid: int) -> Dictionary:
	var owner: int = world.operations.owner_of(facility_uid)
	return world.workforce._worker(owner) if owner > 0 else {}

func ensure(facility_uid: int) -> Dictionary:
	var habitat: Dictionary = super(facility_uid)
	if habitat.has("water") and not habitat.has("water_change_day"):
		habitat["water_change_day"] = -1
	return habitat

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
	return world._finish(int(quote["ap"]), {"ok": true, "water": int(habitat["water"]),
		"inputs": inputs, "wastewater": sewage, "operator": operator})

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
		return ""
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
func quote_maintenance(facility_uid: int) -> Dictionary:
	var quote: Dictionary = super(facility_uid)
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
func maintain(facility_uid: int, operator: String = "player", service_day: int = -1) -> Dictionary:
	if not is_bee_habitat(facility_uid):
		return super(facility_uid, operator, service_day)
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
