extends RefCounted
## Marked errands and per-worker preferences; one deterministic settlement per day.
const Data := preload("res://scripts/farming/v1/v1_data.gd")
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")
const Grid := preload("res://scripts/farming/core/grid/land_grid.gd")
const KINDS := ["source", "harvest", "till", "plant", "irrigate", "fertilize", "fell", "clear"]
var _owner: WeakRef
var world:
	get:
		return _owner.get_ref()
var state: Dictionary
var settings: Dictionary

func _init(owner) -> void:
	_owner = weakref(owner)
	settings = owner.data_source.load_data()["config"]["workers"]
	state = fresh()

static func fresh(day: int = 0) -> Dictionary:
	return {"workers": [], "next_worker_id": 1, "marks": [], "next_mark_id": 1,
		"seed_plans": [], "sources": {}, "spent": 0, "report": {"day": day-1, "workers": []}}

func _error(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

func _changed(result: Dictionary) -> Dictionary:
	world.changed.emit()
	return result

func _worker(ident: int) -> Dictionary:
	for worker in state["workers"]:
		if worker["id"] == ident:
			return worker
	return {}

func hire(name: String) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	if state["workers"].size() >= int(settings["max_workers"]) or name.strip_edges().is_empty() or name.length() > 24:
		return _error("人数已满或姓名非法")
	var priorities := {}
	for kind in KINDS:
		priorities[kind] = 3
	var ident := int(state["next_worker_id"])
	state["next_worker_id"] = ident+1
	state["workers"].append({"id": ident, "name": name.strip_edges(), "paused": false,
		"budget": int(settings["default_budget"]), "priorities": priorities, "areas": []})
	return _changed({"ok": true, "worker_id": ident})

func dismiss(ident: int) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	var worker := _worker(ident)
	if worker.is_empty():
		return _error("未知雇工")
	state["workers"].erase(worker)
	for source in state["sources"].keys():
		if state["sources"][source] == ident:
			state["sources"].erase(source)
	return _changed({"ok": true})

func configure(ident: int, budget, paused, priorities, areas) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	var worker := _worker(ident)
	if worker.is_empty() or not Scalars.whole(budget, 0, 1000000) or not paused is bool or not Scalars.exact(priorities, KINDS) or not areas is Array:
		return _error("雇工设置非法")
	var packed := {}
	for kind in KINDS:
		if not Scalars.whole(priorities[kind], 0, 5):
			return _error("工作偏好须为0～5；0表示禁止")
		packed[kind] = int(priorities[kind])
	var normalized := normalize_areas(areas, world.grid.width, world.grid.height)
	if not normalized["ok"]:
		return normalized
	worker["budget"] = int(budget)
	worker["paused"] = paused
	worker["priorities"] = packed
	worker["areas"] = normalized["areas"]
	return _changed({"ok": true})

func assign_source(source: String, worker_id: int) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	if not world.source_defs.has(source) or (worker_id != 0 and _worker(worker_id).is_empty()):
		return _error("资源点或雇工非法")
	if worker_id == 0:
		state["sources"].erase(source)
	else:
		state["sources"][source] = worker_id
	return _changed({"ok": true})

func seed_plan(cell: Vector2i) -> Dictionary:
	for plan in state["seed_plans"]:
		if plan["cell"] == [cell.x,cell.y]:
			return plan.duplicate(true)
	return {}

func set_seed(cell: Vector2i, crop_id: String) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	var old := seed_plan(cell)
	if crop_id.is_empty():
		for plan in state["seed_plans"].duplicate():
			if plan["cell"] == [cell.x,cell.y]:
				state["seed_plans"].erase(plan)
		return _changed({"ok": true})
	if not world.crop_defs.has(crop_id):
		return _error("未知植物")
	var shape: Array = world.crop_defs[crop_id]["footprint"]
	var rect := Rect2i(cell.x,cell.y,int(shape[0]),int(shape[1]))
	for point in footprint(rect):
		if not world.grid.in_bounds(point.x,point.y) or not world.grid.is_terrain_tillable(point) or not world.source_at(point).is_empty() or not world.facility_at(point).is_empty():
			return _error("选种占地不合法")
	for plan in state["seed_plans"]:
		if plan["cell"] == old.get("cell"):
			continue
		var other_shape: Array = world.crop_defs[plan["crop_id"]]["footprint"]
		if rect.intersects(Rect2i(int(plan["cell"][0]),int(plan["cell"][1]),int(other_shape[0]),int(other_shape[1]))):
			return _error("选种占地与已有种植计划重叠")
	for plan in state["seed_plans"].duplicate():
		if plan["cell"] == [cell.x,cell.y]:
			state["seed_plans"].erase(plan)
	state["seed_plans"].append({"cell": [cell.x,cell.y], "crop_id": crop_id})
	world.Journal.observe(world.journal,"seed")
	return _changed({"ok": true})

static func footprint(rect: Rect2i) -> Array:
	var out := []
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			out.append(Vector2i(x,y))
	return out

func _target(cell: Vector2i, kind: String) -> Dictionary:
	if not world.grid.in_bounds(cell.x,cell.y) or not world.source_at(cell).is_empty():
		return _error("地格无效或是资源点")
	if kind == "till":
		return {"ok": world.grid.can_till(cell)["ok"], "cell": cell}
	if kind in ["plant", "irrigate", "fertilize"]:
		return {"ok": world.grid.state_at(cell) in [Grid.State.TILLED, Grid.State.PLANTED], "cell": cell}
	var crop: Dictionary = world.instance_at(cell)
	if crop.is_empty():
		return _error("没有可指定的植物")
	var mode: String = world.crop_defs[crop["crop_id"]]["mode"]
	var allowed := kind == "clear" or (kind == "harvest" and mode != "fell_replant") or (kind == "fell" and mode in ["tap_or_fell", "fell_replant"])
	return {"ok": allowed, "cell": Vector2i(int(crop["origin"][0]),int(crop["origin"][1]))}

func preview(rect: Rect2i, kind: String) -> Dictionary:
	var valid := []
	var invalid := []
	var targets := []
	if kind not in KINDS or kind == "source" or rect.size.x <= 0 or rect.size.y <= 0 or rect.size.x > world.grid.width or rect.size.y > world.grid.height:
		return {"valid":valid,"invalid":invalid,"targets":targets}
	for cell in footprint(rect):
		var target := _target(cell,kind)
		if target["ok"]:
			valid.append(cell)
			if target["cell"] not in targets: targets.append(target["cell"])
		else: invalid.append(cell)
	return {"valid":valid,"invalid":invalid,"targets":targets}

func mark(rect: Rect2i, kind: String, priority: int = 5) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	if kind not in KINDS or kind == "source" or priority < 1 or priority > 9 or rect.size.x <= 0 or rect.size.y <= 0 or rect.size.x > world.grid.width or rect.size.y > world.grid.height:
		return _error("框选工具或优先级非法")
	var added := 0
	var skipped := 0
	for cell in footprint(rect):
		var target := _target(cell, kind)
		if not target["ok"]:
			skipped += 1
			continue
		var point: Vector2i = target["cell"]
		if kind in ["harvest", "fell", "clear"]:
			for existing in state["marks"].duplicate():
				if existing["cell"] == [point.x,point.y] and existing["kind"] in ["harvest", "fell", "clear"] and existing["kind"] != kind:
					state["marks"].erase(existing)
		var duplicate := false
		for existing in state["marks"]:
			if existing["kind"] == kind and existing["cell"] == [point.x,point.y]:
				existing["priority"] = priority
				duplicate = true
		if not duplicate:
			state["marks"].append({"id": int(state["next_mark_id"]), "kind": kind,
				"cell": [point.x,point.y], "priority": priority})
			state["next_mark_id"] = int(state["next_mark_id"])+1
			added += 1
	if added > 0: world.Journal.observe(world.journal,"designation")
	return _changed({"ok": true, "added": added, "skipped": skipped})

func cancel(rect: Rect2i) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	var removed := 0
	for entry in state["marks"].duplicate():
		if rect.has_point(Vector2i(int(entry["cell"][0]),int(entry["cell"][1]))):
			state["marks"].erase(entry)
			removed += 1
	return _changed({"ok": true, "removed": removed})

func _in_area(worker: Dictionary, cell: Vector2i) -> bool:
	for rect in worker["areas"]:
		if Rect2i(int(rect[0]),int(rect[1]),int(rect[2]),int(rect[3])).has_point(cell):
			return true
	return false

func _jobs(worker: Dictionary) -> Array:
	var jobs := []
	for source in state["sources"]:
		if state["sources"][source] == worker["id"]:
			jobs.append({"kind": "source", "priority": 5, "order": KINDS.find("source"), "id": 0, "source": source})
	for mark_entry in state["marks"]:
		var point := Vector2i(int(mark_entry["cell"][0]),int(mark_entry["cell"][1]))
		if _in_area(worker, point):
			var job: Dictionary = mark_entry.duplicate()
			job["order"] = KINDS.find(job["kind"])
			jobs.append(job)
	for plan in state["seed_plans"]:
		var point := Vector2i(int(plan["cell"][0]),int(plan["cell"][1]))
		var explicit := jobs.any(func(job): return job["kind"] == "plant" and job.get("cell") == plan["cell"])
		if not explicit and _in_area(worker, point) and world.grid.state_at(point) == Grid.State.TILLED:
			jobs.append({"kind": "plant", "cell": plan["cell"], "priority": 5, "order": KINDS.find("plant"), "id": 0})
	jobs = jobs.filter(func(job): return int(worker["priorities"][job["kind"]]) > 0)
	jobs.sort_custom(func(a,b):
		var ap := int(worker["priorities"][a["kind"]])
		var bp := int(worker["priorities"][b["kind"]])
		if ap != bp: return ap > bp
		if a["priority"] != b["priority"]: return a["priority"] > b["priority"]
		if a["order"] != b["order"]: return a["order"] < b["order"]
		if a["id"] != b["id"]: return a["id"] < b["id"]
		return String(a.get("source", str(a.get("cell", [])))) < String(b.get("source", str(b.get("cell", [])))))
	return jobs

func _execute(job: Dictionary) -> Dictionary:
	var kind: String = job["kind"]
	if kind == "source":
		return world.collect(job["source"])
	var cell := Vector2i(int(job["cell"][0]),int(job["cell"][1]))
	if kind == "till":
		return world.till(cell)
	if kind == "plant":
		var plan := seed_plan(cell)
		return _error("尚未分配种子") if plan.is_empty() else world.plant(cell, plan["crop_id"])
	if kind == "clear":
		return world.clear_crop(cell)
	if kind in ["irrigate", "fertilize"]:
		var env: Dictionary = world.environment_at(cell)
		var value := int(env["water" if kind == "irrigate" else "fertility"])
		if value >= int(settings["water_threshold" if kind == "irrigate" else "fertility_threshold"]):
			return _error("环境未低于养护阈值")
		return world.irrigate(cell) if kind == "irrigate" else world.fertilize(cell)
	var target := _target(cell,kind)
	if not target["ok"]:
		return _error("植物已变化或工作不适用")
	return world.harvest(cell, "fell" if kind == "fell" else "harvest")

func task_status(cell: Vector2i, kind: String) -> String:
	# Inspection never invokes the action or alters AP, stock, guide or marks.
	var target := _target(cell,kind)
	if not target["ok"]: return "当前目标不适用，等待地格状态变化"
	if kind == "plant":
		var plan := seed_plan(cell)
		if plan.is_empty(): return "尚未给地格分配种子"
		var definition: Dictionary = world.crop_defs[plan["crop_id"]]
		for point in footprint(Rect2i(cell.x,cell.y,int(definition["footprint"][0]),int(definition["footprint"][1]))):
			if not world.grid.in_bounds(point.x,point.y) or world.grid.state_at(point) != Grid.State.TILLED: return "等待完整占地开垦并空闲"
		var inputs: Dictionary = definition["inputs"].duplicate()
		inputs[definition["seed"]] = int(inputs.get(definition["seed"],0))+1
		var missing := PackedStringArray()
		for ident in inputs:
			if world.inventory.count(ident) < int(inputs[ident]): missing.append("%s×%d" % [world._items[ident]["name"],int(inputs[ident])-world.inventory.count(ident)])
		if not missing.is_empty(): return "缺少："+"、".join(missing)
	elif kind in ["irrigate","fertilize"]:
		var field := "water" if kind == "irrigate" else "fertility"
		if int(world.environment_at(cell)[field]) >= int(settings[field+"_threshold"]): return "尚未低于养护阈值%d" % settings[field+"_threshold"]
		var item := "clean_water" if kind == "irrigate" else "humus"
		var units := int(world.config["environment"]["irrigate_units" if kind == "irrigate" else "fertilize_units"])
		if not world.inventory.has(item,units): return "缺少："+world._items[item]["name"]
	elif kind in ["harvest","fell"] and world.instance_at(cell)["state"] != "mature": return "等待植物成熟"
	return "条件就绪；需负责雇工启用该工作，日结执行"

func settle(completed_day: int) -> void:
	var reports := []
	for worker in state["workers"]:
		reports.append({"worker_id": int(worker["id"]), "name": worker["name"], "success": 0,
			"fee": 0, "counts": {}, "reason": "已暂停" if worker["paused"] else "没有可执行工作"})
	var fee := int(settings["fee_per_success"])
	world._labour_action = true
	# One successful action per worker each round: shared targets and quota are rechecked.
	for _round in range(int(settings["daily_work_limit"])):
		var progressed := false
		for index in range(state["workers"].size()):
			var worker: Dictionary = state["workers"][index]
			var report: Dictionary = reports[index]
			if worker["paused"]:
				continue
			if int(report["fee"])+fee > int(worker["budget"]) or world.primeval_stones < fee:
				report["reason"] = "预算或元石不足"
				continue
			for job in _jobs(worker):
				var result := _execute(job)
				if not result["ok"]:
					report["reason"] = result.get("reason", "目标当前不可执行")
					continue
				world.primeval_stones -= fee
				state["spent"] = int(state["spent"])+fee
				world._cash("labour_spend",fee)
				world._count("work_actions",job["kind"])
				report["success"] = int(report["success"])+1
				report["fee"] = int(report["fee"])+fee
				report["counts"][job["kind"]] = int(report["counts"].get(job["kind"],0))+1
				report["reason"] = "工作完成"
				if job["kind"] in ["till", "plant", "clear"]:
					for entry in state["marks"].duplicate():
						if entry["id"] == job["id"]:
							state["marks"].erase(entry)
				progressed = true
				break
		if not progressed:
			break
	world._labour_action = false
	for report in reports:
		if report["success"] == int(settings["daily_work_limit"]):
			report["reason"] = "达到每日工作上限"
	state["report"] = {"day": completed_day, "workers": reports}

static func normalize_areas(areas, width: int, height: int) -> Dictionary:
	if not areas is Array or areas.size() > width*height:
		return Scalars.fail("负责区域非法")
	var out := []
	for rect in areas:
		if not rect is Array or rect.size() != 4 or not Scalars.whole(rect[0],0,width-1) or not Scalars.whole(rect[1],0,height-1) or not Scalars.whole(rect[2],1,width) or not Scalars.whole(rect[3],1,height) or int(rect[0])+int(rect[2]) > width or int(rect[1])+int(rect[3]) > height:
			return Scalars.fail("负责区域越界")
		out.append([int(rect[0]),int(rect[1]),int(rect[2]),int(rect[3])])
	return {"ok": true, "areas": out}

static func normalize(value, day: int, catalog = Data) -> Dictionary:
	if not Scalars.exact(value, fresh().keys()):
		return Scalars.fail("雇工快照字段非法")
	var config: Dictionary = catalog.load_data()["config"]["workers"]
	var map = catalog.load_map()
	var width := int(map["size"][0])
	var height := int(map["size"][1])
	if not value["workers"] is Array or value["workers"].size() > int(config["max_workers"]) or not value["marks"] is Array or value["marks"].size() > width*height*KINDS.size() or not value["seed_plans"] is Array or value["seed_plans"].size() > width*height or not value["sources"] is Dictionary or not Scalars.whole(value["spent"]) or not Scalars.whole(value["next_worker_id"],1) or not Scalars.whole(value["next_mark_id"],1):
		return Scalars.fail("雇工人数、序号或工作列表非法")
	var out := fresh(day)
	out["spent"] = int(value["spent"])
	out["next_worker_id"] = int(value["next_worker_id"])
	out["next_mark_id"] = int(value["next_mark_id"])
	var worker_ids := {}
	var prior := 0
	for worker in value["workers"]:
		if not Scalars.exact(worker,["id","name","paused","budget","priorities","areas"]) or not Scalars.whole(worker["id"],prior+1,int(value["next_worker_id"])-1) or not worker["name"] is String or worker["name"].strip_edges().is_empty() or worker["name"].length() > 24 or not worker["paused"] is bool or not Scalars.whole(worker["budget"],0,1000000) or not Scalars.exact(worker["priorities"],KINDS):
			return Scalars.fail("雇工设置或编号非法")
		var priorities := {}
		for kind in KINDS:
			if not Scalars.whole(worker["priorities"][kind],0,5):
				return Scalars.fail("雇工工作偏好非法")
			priorities[kind] = int(worker["priorities"][kind])
		var areas := normalize_areas(worker["areas"],width,height)
		if not areas["ok"]: return areas
		prior = int(worker["id"])
		worker_ids[prior] = true
		out["workers"].append({"id": prior,"name": worker["name"],"paused": worker["paused"],
			"budget": int(worker["budget"]),"priorities": priorities,"areas": areas["areas"]})
	var sources = catalog.definitions("sources")
	var source_cells := {}
	for ident in sources:
		source_cells[Vector2i(int(sources[ident]["position"][0]),int(sources[ident]["position"][1]))] = true
	for ident in value["sources"]:
		if not sources.has(ident) or not Scalars.whole(value["sources"][ident],1) or not worker_ids.has(int(value["sources"][ident])):
			return Scalars.fail("资源点分配非法")
		out["sources"][ident] = int(value["sources"][ident])
	var mark_ids := {}
	var mark_cells := {}
	var terrain = catalog.tillable_map()
	for mark_entry in value["marks"]:
		if not Scalars.exact(mark_entry,["id","kind","cell","priority"]) or not Scalars.whole(mark_entry["id"],1,int(value["next_mark_id"])-1) or mark_ids.has(int(mark_entry["id"])) or mark_entry["kind"] not in KINDS or mark_entry["kind"] == "source" or not Scalars.coordinate(mark_entry["cell"],width,height) or not Scalars.whole(mark_entry["priority"],1,9):
			return Scalars.fail("任务标记非法")
		var cell := Vector2i(int(mark_entry["cell"][0]),int(mark_entry["cell"][1]))
		var key := "%s:%s" % [cell,mark_entry["kind"]]
		var exclusive_key := "%s:crop" % cell
		if source_cells.has(cell) or not terrain.get(map["grid"][cell.y][cell.x],false) or mark_cells.has(key) or (mark_entry["kind"] in ["harvest","fell","clear"] and mark_cells.has(exclusive_key)):
			return Scalars.fail("任务重复、互斥或地形非法")
		mark_ids[int(mark_entry["id"])] = true
		mark_cells[key] = true
		if mark_entry["kind"] in ["harvest","fell","clear"]:
			mark_cells[exclusive_key] = true
		out["marks"].append({"id": int(mark_entry["id"]),"kind": mark_entry["kind"],"cell": [cell.x,cell.y],"priority": int(mark_entry["priority"])})
	var crop_defs = catalog.definitions("crops")
	var planned := {}
	for plan in value["seed_plans"]:
		if not Scalars.exact(plan,["cell","crop_id"]) or not Scalars.coordinate(plan["cell"],width,height) or not crop_defs.has(plan["crop_id"]):
			return Scalars.fail("地格选种非法")
		var shape: Array = crop_defs[plan["crop_id"]]["footprint"]
		for cell in footprint(Rect2i(int(plan["cell"][0]),int(plan["cell"][1]),int(shape[0]),int(shape[1]))):
			if cell.x >= width or cell.y >= height or source_cells.has(cell) or planned.has(cell) or not terrain.get(map["grid"][cell.y][cell.x],false):
				return Scalars.fail("选种占地越界或重叠")
			planned[cell] = true
		out["seed_plans"].append({"cell": [int(plan["cell"][0]),int(plan["cell"][1])],"crop_id": plan["crop_id"]})
	var report = value["report"]
	if not Scalars.exact(report,["day","workers"]) or not Scalars.whole(report["day"],day-1,day-1) or not report["workers"] is Array or report["workers"].size() > int(config["max_workers"]):
		return Scalars.fail("工作日报日期或人数非法")
	var paid := 0
	var reported := {}
	for row in report["workers"]:
		if not Scalars.exact(row,["worker_id","name","success","fee","counts","reason"]) or not Scalars.whole(row["worker_id"],1,int(value["next_worker_id"])-1) or reported.has(int(row["worker_id"])) or not row["name"] is String or row["name"].is_empty() or row["name"].length() > 24 or not row["reason"] is String or row["reason"].length() > 200 or not Scalars.whole(row["success"],0,int(config["daily_work_limit"])) or not Scalars.whole(row["fee"]) or not row["counts"] is Dictionary:
			return Scalars.fail("工作日报内容非法")
		var count := 0
		var counts := {}
		for kind in row["counts"]:
			if kind not in KINDS or not Scalars.whole(row["counts"][kind],1,int(config["daily_work_limit"])):
				return Scalars.fail("工作日报次数非法")
			counts[kind] = int(row["counts"][kind])
			count += counts[kind]
		if count != int(row["success"]) or int(row["fee"]) != count*int(config["fee_per_success"]):
			return Scalars.fail("工作次数与费用不一致")
		paid += int(row["fee"])
		reported[int(row["worker_id"])] = true
		out["report"]["workers"].append({"worker_id": int(row["worker_id"]),"name": row["name"],"success": count,"fee": int(row["fee"]),"counts": counts,"reason": row["reason"]})
	if paid > int(value["spent"]):
		return Scalars.fail("日报费用超出累计人工支出")
	return {"ok": true,"workforce": out}
