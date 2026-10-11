extends "res://scripts/farming/v1/v1_workforce.gd"
## P8 roster: workers may own several facilities (see p8_operations) and, with
## an explicit opt-in, keep farm duties at the same time. The unified scheduler
## in p8_operations replaces v1 settle; this class only adapts management and
## validation so the exclusive-caretaker restrictions never apply to P8 saves.
const PRIORITIES := ["high", "normal", "low"]

func _default_duty() -> Dictionary:
	return {"enabled": false, "priority": "normal"}

## Same roster rules as V1 plus the default-off farm-duty slot.
func hire(name: String) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	var cap := int(settings["max_workers"])
	if (cap > 0 and state["workers"].size() >= cap) or name.strip_edges().is_empty() or name.length() > 24:
		return _error("人数已满或姓名非法")
	var priorities := {}
	for kind in KINDS:
		priorities[kind] = 3
	var ident := int(state["next_worker_id"])
	state["next_worker_id"] = ident + 1
	state["workers"].append({"id": ident, "name": name.strip_edges(), "paused": false,
		"budget": int(settings["default_budget"]), "priorities": priorities, "areas": [],
		"farm_duty": _default_duty()})
	return _changed({"ok": true, "worker_id": ident})

## Dismissal also releases facility bindings; the registry is the single source.
func dismiss(ident: int) -> Dictionary:
	var result: Dictionary = super(ident)
	if result["ok"]:
		world.operations.forget_worker(ident)
	return result

## Farm duty stays a personal setting: enabled off means no errands run, but
## areas, kinds and source assignments are all preserved for a later restart.
## The P8 roster never carries the legacy exclusive binding, so the V1 guard
## in the parent configure never triggers.
func configure(ident: int, budget, paused, priorities, areas) -> Dictionary:
	return super(ident, budget, paused, priorities, areas)

func set_farm_duty(ident: int, enabled: bool, priority: String) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	var worker := _worker(ident)
	if worker.is_empty():
		return _error("未知雇工")
	if priority not in PRIORITIES:
		return _error("兼任优先级非法")
	worker["farm_duty"] = {"enabled": enabled, "priority": priority}
	return _changed({"ok": true})

func assign_source(source: String, worker_id: int) -> Dictionary:
	# Source assignments are legal for facility owners in P8; the errands only
	# run while the personal farm duty is enabled.
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

## Farm errands only exist for a worker whose farm duty is enabled.
func _jobs(worker: Dictionary) -> Array:
	if not bool(worker.get("farm_duty", _default_duty())["enabled"]):
		return []
	var jobs := []
	for source in state["sources"]:
		if state["sources"][source] == worker["id"]:
			jobs.append({"kind": "source", "priority": 5, "order": KINDS.find("source"), "id": 0, "source": source})
	for mark_entry in state["marks"]:
		var point := Vector2i(int(mark_entry["cell"][0]), int(mark_entry["cell"][1]))
		if _in_area(worker, point):
			var job: Dictionary = mark_entry.duplicate()
			job["order"] = KINDS.find(job["kind"])
			jobs.append(job)
	for plan in state["seed_plans"]:
		var point := Vector2i(int(plan["cell"][0]), int(plan["cell"][1]))
		var explicit := jobs.any(func(job): return job["kind"] == "plant" and job.get("cell") == plan["cell"])
		if not explicit and _in_area(worker, point) and world.grid.state_at(point) == Grid.State.TILLED:
			jobs.append({"kind": "plant", "cell": plan["cell"], "priority": 5, "order": KINDS.find("plant"), "id": 0})
	jobs = jobs.filter(func(job): return int(worker["priorities"][job["kind"]]) > 0)
	jobs.sort_custom(func(a, b):
		var ap := int(worker["priorities"][a["kind"]])
		var bp := int(worker["priorities"][b["kind"]])
		if ap != bp: return ap > bp
		if a["priority"] != b["priority"]: return a["priority"] > b["priority"]
		if a["order"] != b["order"]: return a["order"] < b["order"]
		if a["id"] != b["id"]: return a["id"] < b["id"]
		return String(a.get("source", str(a.get("cell", [])))) < String(b.get("source", str(b.get("cell", [])))))
	return jobs

## P8 saves validate the roster with the farm-duty slot and the unified report
## rows (facility step summaries instead of the exclusive caretaker record).
static func normalize(value, day: int, catalog = Data) -> Dictionary:
	if not Scalars.exact(value, fresh().keys()):
		return Scalars.fail("雇工快照字段非法")
	var config: Dictionary = catalog.load_data()["config"]["workers"]
	var map = catalog.load_map()
	var width := int(map["size"][0])
	var height := int(map["size"][1])
	if not value["workers"] is Array or (int(config["max_workers"]) > 0 and value["workers"].size() > int(config["max_workers"])) or not value["marks"] is Array or value["marks"].size() > width*height*KINDS.size() or not value["seed_plans"] is Array or value["seed_plans"].size() > width*height or not value["sources"] is Dictionary or not Scalars.whole(value["spent"]) or not Scalars.whole(value["next_worker_id"],1) or not Scalars.whole(value["next_mark_id"],1):
		return Scalars.fail("雇工人数、序号或工作列表非法")
	var out := fresh(day)
	out["spent"] = int(value["spent"])
	out["next_worker_id"] = int(value["next_worker_id"])
	out["next_mark_id"] = int(value["next_mark_id"])
	var worker_ids := {}
	var prior := 0
	for worker in value["workers"]:
		if not Scalars.exact(worker, ["id","name","paused","budget","priorities","areas","farm_duty"]) \
				or not Scalars.whole(worker["id"],prior+1,int(value["next_worker_id"])-1) or not worker["name"] is String or worker["name"].strip_edges().is_empty() or worker["name"].length() > 24 or not worker["paused"] is bool or not Scalars.whole(worker["budget"],0,1000000) or not Scalars.exact(worker["priorities"],KINDS):
			return Scalars.fail("雇工设置或编号非法")
		if not worker["farm_duty"] is Dictionary or not Scalars.exact(worker["farm_duty"], ["enabled","priority"]) or not worker["farm_duty"]["enabled"] is bool or worker["farm_duty"]["priority"] not in PRIORITIES:
			return Scalars.fail("农务兼任设置非法")
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
			"budget": int(worker["budget"]),"priorities": priorities,"areas": areas["areas"],
			"farm_duty": {"enabled": bool(worker["farm_duty"]["enabled"]),"priority": String(worker["farm_duty"]["priority"])}})
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
		var cell := Vector2i(int(mark_entry["cell"][0]), int(mark_entry["cell"][1]))
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
	if not Scalars.exact(report,["day","workers"]) or not Scalars.whole(report["day"],day-1,day-1) or not report["workers"] is Array or (int(config["max_workers"]) > 0 and report["workers"].size() > int(config["max_workers"])):
		return Scalars.fail("工作日报日期或人数非法")
	var paid := 0
	var reported := {}
	for row in report["workers"]:
		if not Scalars.exact(row,["worker_id","name","success","fee","counts","reason","facilities"]) \
				or not Scalars.whole(row["worker_id"],1,int(value["next_worker_id"])-1) or reported.has(int(row["worker_id"])) or not row["name"] is String or row["name"].is_empty() or row["name"].length() > 24 or not row["reason"] is String or row["reason"].length() > 200 \
				or not Scalars.whole(row["success"],0,int(config["daily_work_limit"])) or not Scalars.whole(row["fee"]) or not row["counts"] is Dictionary or not row["facilities"] is Array:
			return Scalars.fail("工作日报内容非法")
		var count := 0
		var counts := {}
		for kind in row["counts"]:
			if kind not in KINDS or not Scalars.whole(row["counts"][kind],1,int(config["daily_work_limit"])):
				return Scalars.fail("工作日报次数非法")
			counts[kind] = int(row["counts"][kind])
			count += counts[kind]
		var steps_total := 0
		var facility_rows := []
		var seen_uids := {}
		for entry in row["facilities"]:
			if not entry is Dictionary or not Scalars.exact(entry,["uid","steps","skipped"]):
				return Scalars.fail("设施工作记录非法")
			if not Scalars.whole(entry["uid"],1) or seen_uids.has(int(entry["uid"])):
				return Scalars.fail("设施工作记录指向非法")
			seen_uids[int(entry["uid"])] = true
			var steps := {}
			for step in entry["steps"]:
				if step not in ["收取","水体维护","整体维护","投料","加工收取"] or not Scalars.whole(entry["steps"][step],1,int(config["daily_work_limit"])):
					return Scalars.fail("设施工作步骤非法")
				steps[step] = int(entry["steps"][step])
				steps_total += steps[step]
			var skipped := []
			if not entry["skipped"] is Array or entry["skipped"].size() > 6:
				return Scalars.fail("设施停工原因非法")
			for reason in entry["skipped"]:
				if not reason is String or reason.is_empty() or reason.length() > 200:
					return Scalars.fail("设施停工原因非法")
				skipped.append(reason)
			facility_rows.append({"uid": int(entry["uid"]),"steps": steps,"skipped": skipped})
		if int(row["success"]) != count + steps_total or int(row["fee"]) != int(row["success"])*int(config["fee_per_success"]):
			return Scalars.fail("工作次数与费用不一致")
		paid += int(row["fee"])
		reported[int(row["worker_id"])] = true
		out["report"]["workers"].append({"worker_id": int(row["worker_id"]),"name": row["name"],"success": count+steps_total,"fee": int(row["fee"]),"counts": counts,"reason": row["reason"],"facilities": facility_rows})
	if paid > int(value["spent"]):
		return Scalars.fail("日报费用超出累计人工支出")
	return {"ok": true,"workforce": out}
