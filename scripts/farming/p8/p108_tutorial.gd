extends RefCounted
## Adaptive first-farm route. Completion is derived from authoritative state;
## only presentation preferences and explicit opt-out are persisted.
const STEPS := [
	{"id":"first_field","title":"开出第一片田","hint":"在空地上框选开垦，再选择播种工具和作物。","kind":"planting"},
	{"id":"first_harvest","title":"收下第一批作物","hint":"观察成熟状态，使用收获工具收取成熟作物。","kind":"harvest"},
	{"id":"first_processing","title":"完成第一批加工","hint":"建设合适的加工设施，设置生产策略并领取完成批次。","kind":"processing"},
	{"id":"first_research","title":"完成第一项研究","hint":"在研究台选择项目，提供样本并完成研究工作。","kind":"research"},
	{"id":"first_order","title":"完成一次供货","hint":"打开订单，交付需求物资并核对结算。","kind":"order"},
	{"id":"first_milestone","title":"推进产业阶段","hint":"查看阶段事件，提交所需供货或复杂资源。","kind":"stage"},
	{"id":"active_field_gu","title":"让农业蛊虫实际生效","hint":"建设合格的农业模块，入驻适配蛊，并确认作物实际取得额外生长进度。","kind":"active_gu"},
]
const Journal := preload("res://scripts/farming/v1/v1_journal.gd")
const ReferenceRoute := preload("res://content/farming/p8/tutorial_route.json")

static func fresh() -> Dictionary:
	return {"enabled":true,"collapsed":false,"dismissed":false,"completed":[],"skipped":[]}

static func normalize(value) -> Dictionary:
	if not value is Dictionary or value.size() != 5:
		return {"ok":false,"reason":"新手指引存档字段非法"}
	for key in ["enabled","collapsed","dismissed"]:
		if not value.get(key) is bool: return {"ok":false,"reason":"新手指引偏好非法"}
	var valid := {}
	for step in STEPS: valid[String(step["id"])] = true
	var result := fresh()
	for key in ["enabled","collapsed","dismissed"]: result[key] = value[key]
	for key in ["completed","skipped"]:
		if not value.get(key) is Array or value[key].size() > STEPS.size(): return {"ok":false,"reason":"新手指引进度非法"}
		for id in value[key]:
			if not id is String or not valid.has(id) or id in result["completed"] or id in result["skipped"]:
				return {"ok":false,"reason":"新手指引步骤重复或未知"}
			result[key].append(id)
	return {"ok":true,"state":result}

static func progress(world, saved: Dictionary) -> Dictionary:
	var done: Array = saved["completed"].duplicate()
	var journal: Dictionary = world.journal
	var totals: Dictionary = Journal.totals(journal)
	for key in journal["pending"]:
		if totals[key] is Dictionary:
			for item in journal["pending"][key]: totals[key][item] = int(totals[key].get(item,0))+int(journal["pending"][key][item])
		elif key in totals: totals[key] = int(totals[key])+int(journal["pending"][key])
	var planted := false
	for id in totals["plantings"]:
		if int(totals["plantings"][id]) > 0: planted = true
	if planted: _add(done,"first_field")
	var harvested := false
	for id in totals["harvests"]:
		if int(totals["harvests"][id]) > 0: harvested = true
	if harvested: _add(done,"first_harvest")
	if not totals["batches_completed"].is_empty(): _add(done,"first_processing")
	if not world.research.state["completed"].is_empty(): _add(done,"first_research")
	var deliveries:=0
	for count in totals["deliveries"].values(): deliveries+=int(count)
	if deliveries>0: _add(done,"first_order")
	if world.progress.stage() > 0: _add(done,"first_milestone")
	var next := {}
	for step in STEPS:
		if step["id"] in done: continue
		next = step
		break
	return {"done":done,"next":next,"complete":next.is_empty()}

static func today(world, saved: Dictionary) -> Dictionary:
	var state: Dictionary = progress(world,saved)
	if bool(state["complete"]): return {"day":int(world.clock.total_days)+1,"items":["主线已完成，可以自由经营或回顾手册。"],"waiting":false}
	var next: Dictionary=state["next"]
	var reference: Dictionary=ReferenceRoute.data
	var route_day:=int(world.clock.total_days)+1
	if route_day<=int(reference.get("reference_days",0)):
		var entry: Dictionary=reference["timeline"][route_day-1]
		var items: Array=entry["advice"].duplicate()
		var waiting:=false
		if String(next["id"])=="first_harvest":
			var mature:=0
			for crop in world.crops.values():
				if String(crop.get("state",""))=="mature": mature+=1
			if mature>0:
				items=["收取已经成熟的作物，并核对入库。"]
			else:
				waiting=true
				items=["作物尚未成熟；检查水肥，有缺口时再维护。","等待期间可以查看订单或领取已完成加工。"]
		if not waiting and not _route_covers_milestone(String(next["id"]),entry.get("evidence_codes",[])):
			items.push_front(String(next["hint"]))
		return {"day":route_day,"reference_day":route_day,"title":String(next["title"]),"items":items,"waiting":waiting}
	var items: Array[String]=[]
	var waiting:=false
	match String(next["id"]):
		"first_field":
			items=["检查开垦与播种工具；选择小麦，在一小片耕地上播种。","有余力时收集清水并查看今日订单。"]
		"first_harvest":
			var mature:=0
			for crop in world.crops.values():
				if String(crop.get("state",""))=="mature": mature+=1
			if mature>0:
				items=["今天有%d株作物成熟，可用框选工具收取并核对入库。"%mature]
			else:
				waiting=true
				items=["作物尚未成熟；按需查看水肥，不必反复执行无效浇水。","可收集基础资源、查看订单或安排加工设施。"]
		"first_processing":
			var ready:=0
			var active:=0
			for row in world.facilities.values():
				var batch: Dictionary=row.get("batch",{})
				if batch.is_empty(): continue
				active+=1
				if String(batch.get("status",""))=="ready": ready+=1
			if ready>0: items=["有%d批加工已完成，领取后再决定下一项生产。"%ready]
			elif active>0:
				waiting=true
				items=["加工正在进行；查看设施的原料、剩余时间和领取条件。","空闲行动可用于种植、订单或采集，不需要连续等待。"]
			else: items=["查看营建所需材料，建造一座基础加工设施并设置可负担的配方。"]
		"first_research":
			items=["打开研究页，查看样本与前置条件；缺少样本时先查手册中的来源。","研究台空闲且材料齐全时，再启动并投入有效研究工作。"]
		"first_order":
			items=["查看订单所需物资与交付数量；只交付库存充足且当前不急需留用的物资。","交付后核对元石和供货记录。"]
		"first_milestone":
			items=["查看当前经济阶段事件及缺口，优先用已有生产路线补齐需求。","复杂资源尚未就绪时可继续经营，不要求当天完成。"]
		"active_field_gu":
			items=["查看田间维护研究与建造条件，准备田间维护站和适配农业蛊。","入驻后确认区域、供给和服务记录，再把它视为已生效。"]
	return {"day":int(world.clock.total_days)+1,"title":String(next["title"]),"items":items,"waiting":waiting}

static func _add(items: Array, id: String) -> void:
	if id not in items: items.append(id)

static func _route_covers_milestone(step_id: String, evidence: Array) -> bool:
	var relevant: Array[String]=[]
	match step_id:
		"first_field": relevant=["plant"]
		"first_harvest": relevant=["harvest"]
		"first_processing": relevant=["batch_start","batch_claim"]
		"first_research": relevant=["research_start","research_work"]
		"first_order": relevant=["order"]
		"first_milestone": relevant=["stage_submit"]
		"active_field_gu": relevant=["field_gu_effect"]
		_: return true
	for code in relevant:
		if code in evidence: return true
	return false
