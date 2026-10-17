extends RefCounted
## P8 research: farm-wide knowledge, one active project per bench, at most one
## work receipt per bench per service day, and progress advancing only from
## settled receipts — never from the click that registered them.
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")

var _owner: WeakRef
var world:
	get:
		return _owner.get_ref()
var state := {"projects": [], "completed": [], "bench_days": []}
## During settlement the clock has already advanced; receipts read this
## effective day instead so worker research stays on the completed day.
var _settle_day := -1

func _today() -> int:
	return _settle_day if _settle_day >= 0 else world.clock.total_days

func begin_settle(completed_day: int) -> void:
	_settle_day = completed_day

func finish_settle() -> void:
	_settle_day = -1

func _init(owner) -> void:
	_owner = weakref(owner)

func _error(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}

func project_defs() -> Dictionary:
	var out := {}
	for row in world.data_source.load_data()["research"]:
		out[String(row["id"])] = row
	return out

func project_def(project_id: String) -> Dictionary:
	return project_defs().get(project_id, {})

func is_completed(project_id: String) -> bool:
	return state["completed"].has(project_id)

func project_of(project_id: String) -> Dictionary:
	for project in state["projects"]:
		if String(project["id"]) == project_id:
			return project
	return {}

func active_project(bench_uid: int) -> Dictionary:
	for project in state["projects"]:
		if int(project["bench_uid"]) == bench_uid:
			return project
	return {}

func _bench_marker(bench_uid: int) -> int:
	for row in state["bench_days"]:
		if int(row["uid"]) == bench_uid:
			return int(row["day"])
	return -1

func _stamp_bench(bench_uid: int, day: int) -> void:
	for row in state["bench_days"]:
		if int(row["uid"]) == bench_uid:
			row["day"] = day
			return
	state["bench_days"].append({"uid": bench_uid, "day": day})

func _worked_today(project: Dictionary) -> bool:
	return project["worked"].has(_today()) or _bench_marker(int(project["bench_uid"])) == _today()

## Read-only start quote: every blocker is named, nothing is deducted.
func quote_start(bench_uid: int, project_id: String) -> Dictionary:
	var out := {"ok": false, "samples": {}, "fee": 0, "days": 0, "blockers": []}
	if not world.facilities.has(bench_uid) or world.facility_defs[String(world.facilities[bench_uid]["facility_id"])].get("kind") != "research":
		out["blockers"] = ["不是研究台"]
		return out
	var definition: Dictionary = project_def(project_id)
	if definition.is_empty():
		out["blockers"] = ["未知研究项目"]
		return out
	out["samples"] = definition["samples"].duplicate()
	out["fee"] = int(definition["fee"])
	out["days"] = int(definition["days"])
	var modifier: Dictionary = world.logistics.research_modifier(bench_uid)
	out["gu"] = modifier
	out["work_target"] = maxi(1,int(definition["days"])-int(modifier["flat"]))
	out["days"] = ceili(float(out["work_target"])/int(modifier["speed"]))
	for item in out["samples"]:
		out["samples"][item] = ceili(float(out["samples"][item])*int(modifier["materials"])/100.0)
	if not String(modifier["instance_id"]).is_empty() and not world.logistics.active(world.logistics.instance(modifier["instance_id"]),_today()):
		out["blockers"].append("入驻蛊未获得今日运行资格，请启用并支付维护后启动")
	if is_completed(project_id):
		out["blockers"].append("已完成，全场共享")
	if not project_of(project_id).is_empty():
		out["blockers"].append("已有研究台在研此项目")
	if not active_project(bench_uid).is_empty():
		out["blockers"].append("此研究台不空闲")
	for prerequisite in definition["prerequisites"]:
		if not is_completed(String(prerequisite)):
			out["blockers"].append("前置未完成：" + String(project_def(String(prerequisite)).get("name", prerequisite)))
	var missing := PackedStringArray()
	for item in out["samples"]:
		if world.inventory.count(String(item)) < int(out["samples"][item]):
			missing.append("%s×%d" % [world._items[String(item)]["name"], int(out["samples"][item]) - world.inventory.count(String(item))])
	if not missing.is_empty():
		out["blockers"].append("缺少样本：" + "、".join(missing))
	if world.primeval_stones < int(definition["fee"]):
		out["blockers"].append("元石不足：%d" % int(definition["fee"]))
	out["ok"] = out["blockers"].is_empty()
	return out

## Starting costs the table fee and the samples once; it creates no valid day.
func start(bench_uid: int, project_id: String) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	var quote := quote_start(bench_uid, project_id)
	if not quote["ok"]:
		return _error("；".join(PackedStringArray(quote["blockers"])))
	var samples: Dictionary = quote["samples"]
	for item in samples:
		world.inventory.remove(String(item), int(samples[item]))
	world._record_flow({}, samples, "研究样本")
	world.primeval_stones -= int(quote["fee"])
	world._cash("purchase_spend", int(quote["fee"]))
	state["projects"].append({"id": project_id, "bench_uid": bench_uid, "progress": 0,
		"start_day": world.clock.total_days, "paused": false, "worked": [], "gu":quote["gu"].duplicate()})
	world._report_event({"category": "growth", "facility_uid": bench_uid, "kind": "研究启动",
		"count": 1, "items": samples, "note": "%s · 费用%d元石" % [String(project_def(project_id)["name"]), int(quote["fee"])]})
	world.changed.emit()
	return {"ok": true, "project_id": project_id, "fee": int(quote["fee"]), "samples": samples.duplicate()}

## Read-only work quote: an idle receipt slot on this bench for today.
func work_quote(bench_uid: int) -> Dictionary:
	var project := active_project(bench_uid)
	if project.is_empty():
		return _error("研究台空闲")
	if bool(project["paused"]):
		return _error("项目已暂停")
	var gu: Dictionary = project["gu"]
	if not String(gu["instance_id"]).is_empty() and not world.logistics.active(world.logistics.instance(gu["instance_id"]),_today()):
		return _error("锁定蛊休眠或缺特殊食料，研究暂停；投入与进度保留")
	if _worked_today(project):
		return _error("今日已登记研究工作")
	return {"ok": true, "project_id": String(project["id"]), "progress": int(project["progress"]),
		"days": maxi(1,int(project_def(String(project["id"]))["days"])-int(gu["flat"])), "ap": 1}

## One receipt per bench per service day. Manual work spends 1 player AP;
## the worker path runs inside the unified scheduler without AP.
func work(bench_uid: int, operator: String = "player") -> Dictionary:
	var checked: Dictionary = world._can_act(1)
	if not checked["ok"]:
		return checked
	var quote := work_quote(bench_uid)
	if not quote["ok"]:
		return quote
	var project := active_project(bench_uid)
	var day := _today()
	# The receipt is registered before the AP can roll the day, so the settle
	# below advances exactly this day and a save failure rolls both back together.
	project["worked"].append(day)
	_stamp_bench(bench_uid, day)
	if operator == "player":
		return world._finish(1, {"ok": true, "project_id": String(project["id"]), "receipt_day": day})
	world.changed.emit()
	return {"ok": true, "project_id": String(project["id"]), "receipt_day": day}

## Pausing keeps the invested fee, samples and progress; only future work stops.
func set_paused(bench_uid: int, paused: bool) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]:
		return checked
	var project := active_project(bench_uid)
	if project.is_empty():
		return _error("研究台空闲")
	project["paused"] = paused
	world.changed.emit()
	return {"ok": true}

## Advance only from receipts stamped on the completed day; completion frees the
## bench and shares the unlock farm-wide without a claim step.
func settle(completed_day: int) -> void:
	for project in state["projects"].duplicate():
		if not project["worked"].has(completed_day):
			continue
		var definition: Dictionary = project_def(String(project["id"]))
		var target := maxi(1,int(definition["days"])-int(project["gu"]["flat"]))
		project["progress"] = mini(target,int(project["progress"])+int(project["gu"]["speed"]))
		if int(project["progress"]) >= target:
			var bench_uid := int(project["bench_uid"])
			state["projects"].erase(project)
			state["completed"].append(String(project["id"]))
			world._report_event({"category": "growth", "facility_uid": bench_uid, "kind": "研究完成",
				"count": 1, "items": {}, "note": "%s已解锁，全农场共享" % String(definition["name"])})

func cancel(bench_uid: int) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]: return checked
	var project := active_project(bench_uid)
	if project.is_empty(): return _error("没有在研项目")
	if _worked_today(project): return _error("今日研究工作已登记，日结后才能取消")
	state["projects"].erase(project)
	return world._finish(0,{"ok":true})

## Demolishing an idle bench drops its day marker; knowledge is farm-wide.
func forget_bench(bench_uid: int) -> void:
	for row in state["bench_days"].duplicate():
		if int(row["uid"]) == bench_uid:
			state["bench_days"].erase(row)

func to_save() -> Dictionary:
	return state.duplicate(true)

func apply_save(value: Dictionary) -> void:
	state = value.duplicate(true)

## Detached validation against the normalized world snapshot.
static func normalize(value, day: int, world: Dictionary, catalog) -> Dictionary:
	if not value is Dictionary or not Scalars.exact(value, ["projects", "completed", "bench_days"]):
		return Scalars.fail("研究快照字段非法")
	var research := {}
	for row in catalog.load_data()["research"]:
		research[String(row["id"])] = row
	var facility_defs: Dictionary = catalog.definitions("facilities")
	var facilities := {}
	for row in world["facilities"]:
		facilities[int(row["uid"])] = row
	var out := {"projects": [], "completed": [], "bench_days": []}
	var completed := []
	for ident in value["completed"]:
		if not research.has(String(ident)) or completed.has(String(ident)):
			return Scalars.fail("完成研究非法或重复")
		completed.append(String(ident))
	var seen_projects := {}
	var seen_benches := {}
	var seen_days := {}
	for project in value["projects"]:
		if not project is Dictionary or not Scalars.exact(project, ["id", "bench_uid", "progress", "start_day", "paused", "worked", "gu"]):
			return Scalars.fail("在研项目字段非法")
		var ident := String(project["id"])
		if not research.has(ident) or completed.has(ident) or seen_projects.has(ident):
			return Scalars.fail("在研项目非法或重复")
		seen_projects[ident] = true
		var bench := int(project["bench_uid"])
		if not facilities.has(bench) or facility_defs[String(facilities[bench]["facility_id"])].get("kind") != "research":
			return Scalars.fail("在研项目绑定非研究台")
		if seen_benches.has(bench):
			return Scalars.fail("一台研究台只能承担一个项目")
		seen_benches[bench] = true
		var definition: Dictionary = research[ident]
		var gu = project["gu"]
		if not Scalars.exact(gu,["instance_id","flat","speed","materials"]) or not gu["instance_id"] is String or not Scalars.whole(gu["flat"],0,1) or not Scalars.whole(gu["speed"],1,2) or not Scalars.whole(gu["materials"],100,150): return Scalars.fail("研究蛊修饰非法")
		if gu["instance_id"].is_empty() and (int(gu["flat"]) != 0 or int(gu["speed"]) != 1 or int(gu["materials"]) != 100): return Scalars.fail("无蛊研究不能携带修饰")
		var target := maxi(1,int(definition["days"])-int(gu["flat"]))
		if not Scalars.whole(project["progress"],0,target-1): return Scalars.fail("研究进度非法")
		if not Scalars.whole(project["start_day"], 0, day) or not project["paused"] is bool:
			return Scalars.fail("在研项目日期或暂停非法")
		if not project["worked"] is Array or project["worked"].size() > int(definition["days"]):
			return Scalars.fail("在研项目有效日数量非法")
		var worked: Array = project["worked"]
		var previous := int(project["start_day"]) - 1
		var packed_worked := []
		for stamp in worked:
			if not Scalars.whole(stamp, int(project["start_day"]), day) or int(stamp) <= previous:
				return Scalars.fail("在研项目工作日非法")
			previous = int(stamp)
			packed_worked.append(int(stamp))
		# Progress equals settled receipts; at most today's receipt may still be
		# unsettled (mid-day checkpoints are normalized through the same path).
		var settled_count := packed_worked.size()
		if not packed_worked.is_empty() and int(packed_worked[-1]) == day: settled_count -= 1
		if int(project["progress"]) != settled_count * int(gu["speed"]):
			return Scalars.fail("在研项目进度与收据不符")
		if int(project["progress"]) > int(definition["days"]):
			return Scalars.fail("在研项目进度越界")
		for prerequisite in definition["prerequisites"]:
			if not completed.has(String(prerequisite)):
				return Scalars.fail("在研项目前置未完成")
		out["projects"].append({"id": ident, "bench_uid": bench, "progress": int(project["progress"]),
			"start_day": int(project["start_day"]), "paused": bool(project["paused"]), "worked": packed_worked,"gu":{"instance_id":gu["instance_id"],"flat":int(gu["flat"]),"speed":int(gu["speed"]),"materials":int(gu["materials"])}})
	var markers := {}
	for row in value["bench_days"]:
		if not row is Dictionary or not Scalars.exact(row, ["uid", "day"]):
			return Scalars.fail("研究台日标记非法")
		var bench := int(row["uid"])
		if not facilities.has(bench) or facility_defs[String(facilities[bench]["facility_id"])].get("kind") != "research":
			return Scalars.fail("研究台日标记指向非法设施")
		if markers.has(bench) or not Scalars.whole(row["day"], 0, day):
			return Scalars.fail("研究台日标记重复或日期非法")
		markers[bench] = int(row["day"])
		out["bench_days"].append({"uid": bench, "day": int(row["day"])})
	# With receipts in, an active project's bench marker equals its latest one;
	# a marker without receipts is a leftover from an earlier, completed project.
	for project in out["projects"]:
		var bench := int(project["bench_uid"])
		if project["worked"].is_empty():
			continue
		var latest := -1
		for stamp in project["worked"]:
			latest = maxi(latest, int(stamp))
		if markers.get(bench, -1) != latest:
			return Scalars.fail("研究台日标记与在研项目收据不符")
	out["completed"] = completed
	return {"ok": true, "research": out}
