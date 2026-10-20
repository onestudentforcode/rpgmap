extends RefCounted
## P8 operations: facility ownership registry, per-facility production
## strategies, farm-wide material reserves and the unified day-end scheduler.
## One worker may own several facilities; every success — facility steps,
## research and farm duty — shares the same daily quota and personal budget.
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")

const PRIORITIES := ["high", "normal", "low"]
const TIER_ORDER := {"high": 0, "normal": 1, "low": 2}
## Within one priority tier: claims and necessary water first, then maintenance
## and research, then batch starts, then farm work.
const CLASS_ORDER := {"收取": 0, "水体维护": 1, "整体维护": 2, "研究": 3, "投料": 4, "农务": 5}
const FACILITY_STEPS := ["收取", "水体维护", "整体维护", "投料", "加工收取"]

var _owner: WeakRef
var world:
	get:
		return _owner.get_ref()
var state := {"facilities": {}, "production": {}, "reserves": {}, "waiting": {}}

func _init(owner) -> void:
	_owner = weakref(owner)

func _error(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

# --- Bindings --------------------------------------------------------------

func owner_of(facility_uid: int) -> int:
	return int(state["facilities"].get(facility_uid, {}).get("owner", 0))

func facilities_of(worker_id: int) -> Array:
	var out := []
	for uid in state["facilities"]:
		if int(state["facilities"][uid]["owner"]) == worker_id:
			out.append(int(uid))
	out.sort()
	return out

func binding_of(facility_uid: int) -> Dictionary:
	return state["facilities"].get(facility_uid, {}).duplicate()

## Binding is management state only: 0AP, 0 stones, no work executes here.
## Reassignment keeps today's services and fees; farm duty settings stay.
func assign_owner(facility_uid: int, worker_id: int) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	if not world.facilities.has(facility_uid):
		return _error("未知设施")
	if worker_id != 0 and world.workforce._worker(worker_id).is_empty():
		return _error("未知雇工")
	if worker_id == 0:
		state["facilities"].erase(facility_uid)
	else:
		state["facilities"][facility_uid] = {"owner": worker_id, "priority": "normal"}
	state["waiting"].erase(facility_uid)
	world.changed.emit()
	return {"ok": true}

func set_priority(facility_uid: int, level: String) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	if not state["facilities"].has(facility_uid):
		return _error("尚未指派负责人")
	if level not in PRIORITIES:
		return _error("优先级非法")
	state["facilities"][facility_uid]["priority"] = level
	world.changed.emit()
	return {"ok": true}

func forget_facility(facility_uid: int) -> void:
	state["facilities"].erase(facility_uid)
	state["production"].erase(facility_uid)
	state["waiting"].erase(facility_uid)

func forget_worker(worker_id: int) -> void:
	for uid in state["facilities"].keys().duplicate():
		if int(state["facilities"][uid]["owner"]) == worker_id:
			state["facilities"].erase(uid)
			state["waiting"].erase(uid)

# --- Production strategy and reserves --------------------------------------

func strategy_of(facility_uid: int) -> Dictionary:
	return state["production"].get(facility_uid, {"enabled": false, "recipe_id": "", "target_item": "", "target_qty": 0}).duplicate(true)

static func living_recipe(species: Dictionary, recipe_id: String, recipe_defs: Dictionary) -> Dictionary:
	for diet in species.get("special_diets", []):
		if String(diet["id"]) == recipe_id:
			return {"id": recipe_id, "name": diet.get("name", recipe_id), "inputs": diet["inputs"].duplicate(),
				"outputs": diet.get("outputs", species["outputs"]).duplicate(),
				"research": diet.get("research", recipe_defs.get(recipe_id, {}).get("research", ""))}
	return {}

func recipe_definition(facility_uid: int, recipe_id: String) -> Dictionary:
	var facility: Dictionary = world.facilities.get(facility_uid, {})
	if facility.is_empty(): return {}
	if world.facility_defs[facility["facility_id"]].get("kind") == "habitat":
		var habitat: Dictionary = world.husbandry.habitat_of(facility_uid)
		if habitat.is_empty(): return {}
		return living_recipe(world.husbandry.species_def(String(habitat["species_id"])), recipe_id, world.recipe_defs)
	var recipe: Dictionary = world.recipe_defs.get(recipe_id, {})
	if not world.batch_block(recipe_id).is_empty(): return {}
	return recipe if String(recipe.get("facility", "")) == String(facility["facility_id"]) else {}

func available_recipes(facility_uid: int) -> Dictionary:
	var out := {}
	var facility: Dictionary = world.facilities[facility_uid]
	if world.facility_defs[facility["facility_id"]].get("kind") == "habitat":
		var habitat: Dictionary = world.husbandry.habitat_of(facility_uid)
		if not habitat.is_empty():
			for diet in world.husbandry.species_def(String(habitat["species_id"]))["special_diets"]:
				out[String(diet["id"])] = recipe_definition(facility_uid, String(diet["id"]))
	else:
		for id in world.recipe_defs:
			var recipe := recipe_definition(facility_uid, String(id))
			if not recipe.is_empty(): out[id] = recipe
	return out

## Enabling a strategy never starts anything by itself; the day-end scheduler
## revalidates recipe, stock, reserves, owner and quota when it runs.
func set_production(facility_uid: int, enabled: bool, recipe_id: String, target_item: String, target_qty: int) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	if not world.facilities.has(facility_uid):
		return _error("未知设施")
	var facility: Dictionary = world.facilities[facility_uid]
	var definition: Dictionary = world.facility_defs[facility["facility_id"]]
	if definition.get("kind") == "research" or facility["facility_id"] in ["growth_lamp", "field_service_station"]:
		return _error("该设施不使用持续生产策略")
	if enabled:
		var recipe := recipe_definition(facility_uid, recipe_id)
		if recipe.is_empty():
			return _error("配方不属于该设施")
		var blocked: String = world.research_block(String(recipe.get("research", "")))
		if not blocked.is_empty():
			return _error(blocked)
		if not recipe["outputs"].has(target_item):
			return _error("目标物品不是该配方产物")
		if not Scalars.whole(target_qty, 1):
			return _error("目标数量非法")
		if definition.get("kind") == "habitat":
			var selected: Dictionary = world.husbandry.set_special_diet(facility_uid, recipe_id)
			if not selected["ok"]: return selected
	state["production"][facility_uid] = {"enabled": enabled, "recipe_id": recipe_id,
		"target_item": target_item, "target_qty": int(target_qty) if enabled else int(state["production"].get(facility_uid, {}).get("target_qty", 0))}
	world.changed.emit()
	return {"ok": true}

## Reserves only gate automatic batch starts; manual work, trades, building,
## research and base husbandry never consult them.
func set_reserve(item_id: String, quantity: int) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	if not world._items.has(item_id):
		return _error("未知资源")
	if not Scalars.whole(quantity):
		return _error("保留量非法")
	if quantity == 0:
		state["reserves"].erase(item_id)
	else:
		state["reserves"][item_id] = int(quantity)
	world.changed.emit()
	return {"ok": true}

## Effective stock of an item: warehouse plus every in-progress or ready batch
## output plus pending habitat claims; nothing is counted twice.
func effective_stock(item_id: String) -> int:
	var total: int = world.inventory.count(item_id)
	for facility in world.facilities.values():
		var batch: Dictionary = facility["batch"]
		if not batch.is_empty():
			total += int(batch["outputs"].get(item_id, 0))
	for habitat in world.husbandry.state["habitats"]:
		for individual in habitat["individuals"]:
			var cycle: Dictionary = individual.get("cycle", {})
			if not cycle.is_empty():
				total += int(cycle["outputs"].get(item_id, 0))
	return total

## A whole unit is the smallest batch. Basic care for juveniles and running
## cycles continues even when the target is met or automatic starts are off.
func habitat_plan(facility_uid: int) -> Dictionary:
	var habitat: Dictionary = world.husbandry.habitat_of(facility_uid)
	var out := {"basic": [], "special": [], "reason": "持续生产已关闭"}
	if habitat.is_empty(): return out
	var hus = world.husbandry
	var species: Dictionary = hus.species_def(String(habitat["species_id"]))
	var base: Dictionary = hus.diet_inputs(String(habitat["species_id"]), "base_diets", String(habitat["basic_diet_id"]))
	var juvenile_only := bool(hus.diet_definition(String(habitat["species_id"]), "base_diets", String(habitat["basic_diet_id"])).get("juvenile_only", false))
	var basic_cost := {}
	var idle := []
	for individual in habitat["individuals"]:
		var cycle: Dictionary = individual.get("cycle", {})
		if individual["stage"] == "adult" and cycle.is_empty():
			idle.append(individual)
		elif (individual["stage"] == "juvenile" or cycle.get("status") == "running") and int(individual["base_service"]["day"]) != hus._today():
			out["basic"].append(int(individual["uid"]))
			if not juvenile_only or individual["stage"] == "juvenile":
				for item in base: basic_cost[item] = int(basic_cost.get(item, 0)) + int(base[item])
	var strategy := strategy_of(facility_uid)
	if not bool(strategy["enabled"]) or not bool(habitat["production_enabled"]): return out
	if strategy["recipe_id"] != habitat["special_diet_id"]:
		out["reason"] = "生产食谱已改变，请重新设置自动策略"
		return out
	var recipe := recipe_definition(facility_uid, String(strategy["recipe_id"]))
	if recipe.is_empty(): return out
	var blocked: String = world.research_block(String(recipe.get("research", "")))
	if not blocked.is_empty():
		out["reason"] = blocked
		return out
	var missing := int(strategy["target_qty"]) - effective_stock(String(strategy["target_item"]))
	if missing <= 0:
		out["reason"] = "目标库存已满足"
		return out
	var needed := ceili(float(missing) / int(recipe["outputs"][strategy["target_item"]]))
	idle.sort_custom(func(a, b): return int(a["uid"]) < int(b["uid"]))
	out["reason"] = "没有空闲成体"
	for individual in idle:
		if out["special"].size() >= needed: break
		var unfed: bool = int(individual["base_service"]["day"]) != hus._today()
		var projected: Dictionary = basic_cost.duplicate()
		if unfed and not juvenile_only:
			for item in base: projected[item] = int(projected.get(item, 0)) + int(base[item])
		var possible := true
		for item in projected:
			if world.inventory.count(item) < int(projected[item]): possible = false
		for item in recipe["inputs"]:
			if world.inventory.count(item) - int(projected.get(item, 0)) - int(recipe["inputs"][item]) * (out["special"].size() + 1) < int(state["reserves"].get(item, 0)):
				possible = false
				out["reason"] = "原料不足或保留量阻挡：" + world._items[item]["name"]
		if not possible: break
		out["special"].append(int(individual["uid"]))
		if unfed: out["basic"].append(int(individual["uid"]))
		basic_cost = projected
		out["reason"] = "可启动%d个单位" % out["special"].size()
	return out

## Read-only auto-start check: target unmet, recipe legal and every input
## leaves the reserve untouched after a full batch.
func auto_start_block(facility_uid: int) -> String:
	if not state["production"].has(facility_uid):
		return "未配置持续生产"
	var strategy: Dictionary = state["production"][facility_uid]
	if not bool(strategy["enabled"]):
		return "持续生产已关闭"
	if owner_of(facility_uid) == 0:
		return "尚未指派负责人"
	var facility: Dictionary = world.facilities.get(facility_uid, {})
	if facility.is_empty():
		return "设施不存在"
	if world.facility_defs[facility["facility_id"]].get("kind") == "habitat":
		var plan := habitat_plan(facility_uid)
		return "" if not plan["special"].is_empty() else String(plan["reason"])
	if not facility["batch"].is_empty():
		return "在制批次未完成"
	var recipe: Dictionary = world.recipe_defs.get(String(strategy["recipe_id"]), {})
	var biological: String = world.batch_block(String(strategy["recipe_id"]))
	if not biological.is_empty(): return biological
	if recipe.is_empty() or String(recipe["facility"]) != String(facility["facility_id"]):
		return "策略配方不适用"
	var blocked: String = world.research_block(String(recipe.get("research", "")))
	if not blocked.is_empty():
		return blocked
	if effective_stock(String(strategy["target_item"])) >= int(strategy["target_qty"]):
		return "目标库存已满足"
	for item in recipe["inputs"]:
		if world.inventory.count(item) - int(recipe["inputs"][item]) < int(state["reserves"].get(item, 0)):
			return "原料保留量阻挡：" + world._items[item]["name"]
	return ""

# --- Unified day-end scheduler ---------------------------------------------

## One successful action per worker per round; candidates are rebuilt every
## pick so shared stock, services and quotas are always rechecked.
func settle(completed_day: int) -> void:
	var workforce = world.workforce
	var husbandry = world.husbandry
	var reports := []
	for worker in workforce.state["workers"]:
		reports.append({"worker_id": int(worker["id"]), "name": worker["name"], "success": 0, "fee": 0,
			"counts": {}, "facilities": [], "reason": "已暂停" if worker["paused"] else "没有可执行工作"})
	husbandry.begin_patrols(completed_day, [])
	if world.has_method("begin_research_settle"):
		world.begin_research_settle(completed_day)
	world._labour_action = true
	var fee := int(workforce.settings["fee_per_success"])
	var limit := int(workforce.settings["daily_work_limit"])
	var cursors := {}
	var blocked := {}
	for _round in range(limit):
		var progressed := false
		for index in range(workforce.state["workers"].size()):
			var worker: Dictionary = workforce.state["workers"][index]
			var report: Dictionary = reports[index]
			if worker["paused"]:
				continue
			if int(report["fee"]) + fee > int(worker["budget"]) or world.primeval_stones < fee:
				report["reason"] = "预算或元石不足"
				continue
			if not cursors.has(int(worker["id"])): cursors[int(worker["id"])] = {}
			if not blocked.has(int(worker["id"])): blocked[int(worker["id"])] = {}
			var seen: Dictionary = cursors[int(worker["id"])]
			var skips: Dictionary = blocked[int(worker["id"])]
			var picked := _next_candidate(worker, seen, skips)
			if picked.is_empty():
				continue
			var result: Dictionary = picked["action"].call()
			if not result["ok"]:
				var condition := String(picked["condition"])
				if not skips.has(condition):
					skips[condition] = String(result.get("reason", "步骤失败"))
				report["reason"] = String(skips[condition])
				continue
			world.primeval_stones -= fee
			workforce.state["spent"] = int(workforce.state["spent"]) + fee
			world._cash("labour_spend", fee)
			world._report_event({"category": "labour", "facility_uid": int(picked.get("facility_uid", 0)),
				"kind": String(picked.get("step", picked.get("kind", "农务"))), "count": 1, "items": {},
				"note": String(worker["name"])})
			report["success"] = int(report["success"]) + 1
			report["fee"] = int(report["fee"]) + fee
			report["reason"] = "工作完成：" + String(picked["label"])
			if picked.has("facility_uid"):
				_bump_step(report, int(picked["facility_uid"]), String(picked["step"]))
			else:
				world._count("work_actions", String(picked["kind"]))
				report["counts"][String(picked["kind"])] = int(report["counts"].get(String(picked["kind"]), 0)) + 1
				# Executed one-shot errands leave the roster exactly like the V1 day.
				if String(picked["kind"]) in ["till", "plant", "clear"] and picked["job"].get("id", 0) > 0:
					for entry in world.workforce.state["marks"].duplicate():
						if int(entry["id"]) == int(picked["job"]["id"]):
							world.workforce.state["marks"].erase(entry)
			progressed = true
		if not progressed:
			break
	world._labour_action = false
	husbandry.finish_patrols()
	if world.has_method("finish_research_settle"):
		world.finish_research_settle()
	for report in reports:
		if int(report["success"]) >= limit:
			report["reason"] = "达到每日工作上限"
	_update_waiting(completed_day, reports)
	workforce.state["report"] = {"day": completed_day, "workers": reports}

func _bump_step(report: Dictionary, facility_uid: int, step: String) -> void:
	for row in report["facilities"]:
		if int(row["uid"]) == facility_uid:
			row["steps"][step] = int(row["steps"].get(step, 0)) + 1
			return
	report["facilities"].append({"uid": facility_uid, "steps": {step: 1}, "skipped": []})

## Sorted candidate list for one worker; derived products extend the research
## seam in P8.c. Farm duty only runs with the explicit opt-in.
func _candidates(worker: Dictionary) -> Array:
	var out := []
	var husbandry = world.husbandry
	for uid in facilities_of(int(worker["id"])):
		var facility: Dictionary = world.facilities.get(uid, {})
		if facility.is_empty():
			continue
		var definition: Dictionary = world.facility_defs[facility["facility_id"]]
		var tier := int(TIER_ORDER[String(state["facilities"][uid]["priority"])])
		if definition.get("kind") == "habitat":
			if husbandry.quote_claim(uid)["ok"]:
				out.append(_candidate(tier, 0, uid, "收取", "收取设施#%d" % uid, "claim:%d" % uid,
					func(): return husbandry.claim(uid, [], "worker")))
			var habitat: Dictionary = husbandry.habitat_of(uid)
			if not habitat.is_empty() and habitat.has("water") and not habitat["individuals"].is_empty() \
					and int(habitat["water"]) <= int(husbandry.settings["water"]["worker_threshold"]) \
					and husbandry.quote_water(uid)["ok"]:
				out.append(_candidate(tier, 1, uid, "水体维护", "换水设施#%d" % uid, "water:%d" % uid,
					func(): return husbandry.maintain_water(uid, "worker")))
			if husbandry.quote_automatic(uid)["ok"]:
				out.append(_candidate(tier, 2, uid, "整体维护", "维护设施#%d" % uid, "maintain:%d" % uid,
					func(): return husbandry.maintain_automatic(uid, husbandry._today())))
		elif definition.get("kind") != "research":
			var batch: Dictionary = facility["batch"]
			if not batch.is_empty() and batch["status"] == "ready":
				var batch_id := int(batch["batch_id"])
				out.append(_candidate(tier, 0, uid, "加工收取", "收取设施#%d批次" % uid, "claim_batch:%d" % uid,
					func(): return world.claim_batch(uid, batch_id)))
			elif batch.is_empty() and auto_start_block(uid).is_empty():
				var recipe_id := String(state["production"][uid]["recipe_id"])
				out.append(_candidate(tier, 4, uid, "投料", "设施#%d启动%s" % [uid, recipe_id], "start:%d" % uid,
					func(): return world.start_batch(uid, recipe_id)))
	out.append_array(world._research_candidates(worker))
	if bool(worker.get("farm_duty", {}).get("enabled", false)):
		var order := 0
		for job in world.workforce._jobs(worker):
			out.append({"tier": int(TIER_ORDER[String(worker["farm_duty"]["priority"])]), "class": 5,
				"uid": 0, "order": order, "kind": String(job["kind"]), "label": "农务：" + str(job.get("source", job.get("cell", ""))),
				"condition": "farm:%d" % order, "job": job,
				"action": func(): return world.workforce._execute(job)})
			order += 1
	out.sort_custom(func(a, b):
		if a["tier"] != b["tier"]: return a["tier"] < b["tier"]
		if a["class"] != b["class"]: return a["class"] < b["class"]
		if a["uid"] != b["uid"]: return a["uid"] < b["uid"]
		return a["order"] < b["order"])
	return out

func _candidate(tier: int, class_order: int, uid: int, step: String, label: String, condition: String, action: Callable) -> Dictionary:
	return {"tier": tier, "class": class_order, "uid": uid, "order": 0, "step": step,
		"label": label, "condition": condition, "facility_uid": uid, "action": action}

## First runnable candidate by (tier, class); same-group candidates rotate by a
## per-group cursor so one facility cannot monopolise a tier, and conditions
## that already failed this settle are skipped until state changes.
func _next_candidate(worker: Dictionary, seen: Dictionary, skips: Dictionary) -> Dictionary:
	var candidates := _candidates(worker)
	var index := 0
	while index < candidates.size():
		var group := [candidates[index]]
		var key := "%d:%d" % [int(candidates[index]["tier"]), int(candidates[index]["class"])]
		var scan := index + 1
		while scan < candidates.size() and int(candidates[scan]["tier"]) == int(candidates[index]["tier"]) \
				and int(candidates[scan]["class"]) == int(candidates[index]["class"]):
			group.append(candidates[scan])
			scan += 1
		var offset := int(seen.get(key, -1)) + 1
		for step in range(group.size()):
			var candidate: Dictionary = group[(offset + step) % group.size()]
			if not skips.has(String(candidate["condition"])):
				seen[key] = (offset + step) % group.size()
				return candidate
		index = scan
	return {}

## Facilities with runnable work whose owner ran out of quota or budget keep a
## first-waiting day for the backlog display; anything served clears it.
func _update_waiting(completed_day: int, reports: Array) -> void:
	var exhausted := {}
	for report in reports:
		if String(report["reason"]) in ["达到每日工作上限", "预算或元石不足"]:
			exhausted[int(report["worker_id"])] = true
	for uid in state["facilities"].keys().duplicate():
		var owner := int(state["facilities"][uid]["owner"])
		if owner == 0 or not world.facilities.has(uid):
			state["waiting"].erase(uid)
			continue
		if not exhausted.has(owner) or _facility_actionable(int(uid)).is_empty():
			state["waiting"].erase(uid)
		elif not state["waiting"].has(uid):
			state["waiting"][uid] = completed_day

## Read-only labels of what the owner could do at this facility right now.
func _facility_actionable(facility_uid: int) -> Array:
	var worker: Dictionary = world.workforce._worker(owner_of(facility_uid))
	if worker.is_empty() or bool(worker["paused"]):
		return []
	return _candidates(worker).filter(func(row): return int(row.get("facility_uid", 0)) == facility_uid)

func facility_waiting_days(facility_uid: int, today: int) -> int:
	if not state["waiting"].has(facility_uid):
		return 0
	return maxi(0, today - int(state["waiting"][facility_uid]))

# --- Persistence -------------------------------------------------------------

func to_save() -> Dictionary:
	var facilities := []
	for uid in state["facilities"].keys():
		facilities.append({"uid": int(uid), "owner": int(state["facilities"][uid]["owner"]), "priority": String(state["facilities"][uid]["priority"])})
	facilities.sort_custom(func(a, b): return int(a["uid"]) < int(b["uid"]))
	var production := []
	for uid in state["production"].keys():
		var strategy: Dictionary = state["production"][uid]
		production.append({"uid": int(uid), "enabled": bool(strategy["enabled"]), "recipe_id": String(strategy["recipe_id"]),
			"target_item": String(strategy["target_item"]), "target_qty": int(strategy["target_qty"])})
	production.sort_custom(func(a, b): return int(a["uid"]) < int(b["uid"]))
	var reserves := []
	for item in state["reserves"].keys():
		reserves.append({"item": String(item), "qty": int(state["reserves"][item])})
	reserves.sort_custom(func(a, b): return String(a["item"]) < String(b["item"]))
	var waiting := []
	for uid in state["waiting"].keys():
		waiting.append({"uid": int(uid), "day": int(state["waiting"][uid])})
	waiting.sort_custom(func(a, b): return int(a["uid"]) < int(b["uid"]))
	return {"facilities": facilities, "production": production, "reserves": reserves, "waiting": waiting}

func apply_save(value: Dictionary) -> void:
	state = {"facilities": {}, "production": {}, "reserves": {}, "waiting": {}}
	for row in value["facilities"]:
		state["facilities"][int(row["uid"])] = {"owner": int(row["owner"]), "priority": String(row["priority"])}
	for row in value["production"]:
		state["production"][int(row["uid"])] = {"enabled": bool(row["enabled"]), "recipe_id": String(row["recipe_id"]),
			"target_item": String(row["target_item"]), "target_qty": int(row["target_qty"])}
	for row in value["reserves"]:
		state["reserves"][String(row["item"])] = int(row["qty"])
	for row in value["waiting"]:
		state["waiting"][int(row["uid"])] = int(row["day"])

## Detached validation against the already normalized base world snapshot.
static func normalize(value, day: int, world: Dictionary, workforce: Dictionary, catalog, completed_research: Array = [], husbandry: Dictionary = {}) -> Dictionary:
	if not value is Dictionary or not Scalars.exact(value, ["facilities", "production", "reserves", "waiting"]):
		return Scalars.fail("P8运营快照字段非法")
	var facility_defs: Dictionary = catalog.definitions("facilities")
	var recipe_defs: Dictionary = catalog.definitions("recipes")
	var items = catalog.resources(catalog.load_data())
	var facilities := {}
	for row in world["facilities"]:
		facilities[int(row["uid"])] = row
	var workers := {}
	for worker in workforce["workers"]:
		workers[int(worker["id"])] = true
	var out := {"facilities": [], "production": [], "reserves": [], "waiting": []}
	var seen_facilities := {}
	for row in value["facilities"]:
		if not row is Dictionary or not Scalars.exact(row, ["uid", "owner", "priority"]):
			return Scalars.fail("设施绑定字段非法")
		var uid := int(row["uid"])
		if not facilities.has(uid) or seen_facilities.has(uid):
			return Scalars.fail("绑定指向未知或重复设施")
		seen_facilities[uid] = true
		if not Scalars.whole(row["owner"], 1) or not workers.has(int(row["owner"])):
			return Scalars.fail("绑定指向未知雇工")
		if row["priority"] not in PRIORITIES:
			return Scalars.fail("设施优先级非法")
		out["facilities"].append({"uid": uid, "owner": int(row["owner"]), "priority": String(row["priority"])})
	var seen_production := {}
	for row in value["production"]:
		if not row is Dictionary or not Scalars.exact(row, ["uid", "enabled", "recipe_id", "target_item", "target_qty"]):
			return Scalars.fail("持续生产字段非法")
		var uid := int(row["uid"])
		if not facilities.has(uid) or seen_production.has(uid):
			return Scalars.fail("策略指向未知或重复设施")
		seen_production[uid] = true
		var definition: Dictionary = facility_defs[String(facilities[uid]["facility_id"])]
		if definition.get("kind") == "research" or definition["id"] in ["growth_lamp", "field_service_station"]:
			return Scalars.fail("该设施不使用持续生产策略")
		if bool(row["enabled"]):
			if catalog.load_data()["p103"]["work"]["recipes"].has(String(row["recipe_id"])):
				return Scalars.fail("生物岗位不接受通用加工策略")
			var recipe = recipe_defs.get(String(row["recipe_id"]))
			if definition.get("kind") == "habitat":
				recipe = null
				for habitat in husbandry.get("habitats", []):
					if int(habitat["facility_uid"]) == uid:
						recipe = living_recipe(catalog.definitions("livestock")[habitat["species_id"]], String(row["recipe_id"]), recipe_defs)
						if row["recipe_id"] != habitat["special_diet_id"] or not habitat["production_enabled"]:
							return Scalars.fail("活体策略与所选食谱不一致")
			elif recipe != null and String(recipe["facility"]) != String(facilities[uid]["facility_id"]):
				recipe = null
			if recipe == null or recipe.is_empty():
				return Scalars.fail("策略配方不属于该设施")
			if String(recipe.get("research", "")) != "" and not completed_research.has(String(recipe.get("research", ""))):
				return Scalars.fail("策略配方未解锁")
			if not recipe["outputs"].has(String(row["target_item"])) or not Scalars.whole(row["target_qty"], 1):
				return Scalars.fail("策略目标非法")
		out["production"].append({"uid": uid, "enabled": bool(row["enabled"]), "recipe_id": String(row["recipe_id"]),
			"target_item": String(row["target_item"]), "target_qty": int(row["target_qty"])})
	var seen_reserves := {}
	for row in value["reserves"]:
		if not row is Dictionary or not Scalars.exact(row, ["item", "qty"]):
			return Scalars.fail("保留量字段非法")
		if not items.has(String(row["item"])) or seen_reserves.has(String(row["item"])) or not Scalars.whole(row["qty"], 1):
			return Scalars.fail("保留量物品或数量非法")
		seen_reserves[String(row["item"])] = true
		out["reserves"].append({"item": String(row["item"]), "qty": int(row["qty"])})
	var seen_waiting := {}
	for row in value["waiting"]:
		if not row is Dictionary or not Scalars.exact(row, ["uid", "day"]):
			return Scalars.fail("积压字段非法")
		var uid := int(row["uid"])
		if not seen_facilities.has(uid) or seen_waiting.has(uid) or not Scalars.whole(row["day"], 0, day):
			return Scalars.fail("积压指向未绑定设施或日期非法")
		seen_waiting[uid] = true
		out["waiting"].append({"uid": uid, "day": int(row["day"])})
	return {"ok": true, "operations": out}
