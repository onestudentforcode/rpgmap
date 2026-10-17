extends RefCounted
## Player-facing management shares the existing responsive sidebar primitives.
var shell
var placing := ""
var focused := ""
func _init(owner) -> void: shell = owner
func manager(): return shell.world.logistics
func items_text(items: Dictionary) -> String:
	return "无" if items.is_empty() else shell._materials(items)

func open() -> void:
	shell._context = "logistics"
	shell._page("后勤蛊 · 部署与经营协同")
	var gu = manager()
	if not gu.state["provisioned"]:
		shell._heading(shell.sidebar,"首批后勤蛊试用配给")
		shell._label(shell.sidebar,"领取11只试用蛊：饭袋草/催生/锁水/节肥各两只，明光、智道研究、宙道研究各一只。每档一次，0AP；获取与成长尚未连接上游。")
		shell._icon(shell.sidebar,"claim","领取试用蛊虫",func(): shell._result(manager().provision()); open())
		return
	var fees := 0
	var deployed := 0
	var sleeping := 0
	for row in gu.state["instances"]:
		if gu.deployed(row):
			deployed += 1
			if row["enabled"]: fees += int(gu.definition(row)["fee"])
			else: sleeping += 1
	shell._label(shell.sidebar,"已部署%d · 休眠%d · 次日预计维护%d元石 · 累计已付%d元石" % [deployed,sleeping,fees,int(gu.state["spent"])])
	shell._label(shell.sidebar,"部署/撤回各1AP，次日生效；休眠免费，已付维护不退。启用时即使闲置仍需维护；食料与元石同时足够才扣。")
	for row in gu.state["instances"]:
		card(row,shell._card(shell.sidebar))
	shell._heading(shell.sidebar,"最近维护账单")
	for bill in gu.state["history"]:
		if bill["fees"] > 0 or not bill["food"].is_empty(): shell._label(shell.sidebar,"服务日%d：%d元石；食料%s" % [int(bill["day"])+1,int(bill["fees"]),items_text(bill["food"])])

func card(row: Dictionary, parent: Node) -> void:
	var gu = manager()
	var d: Dictionary = gu.definition(row)
	var id := String(row["instance_id"])
	shell._picture(parent,d["id"],48)
	shell._heading(parent,"%s · %d转 · %s" % [d["name"],int(row["rank"]),"第%d只" % (int(id.trim_prefix("trial-")))])
	shell._encyclopedia_link(parent,"gu:"+String(d["id"]))
	shell._label(parent,"维护%d元石/日；特殊食料：%s" % [int(d["fee"]),items_text(d["food"])])
	var descriptions := {"production":"光照≥60、水分≥30；每有效日扣水分8，3有效日收稻米4，不产秸秆、不消耗肥力。",
		"light":"范围外扩2格，提供光照80，与自然光/油灯取最大。入驻后替代该灯燃油模式；喜阴作物可能降效。",
		"growth_speed":"宿主四向3×3服务区（可转向，1AP次日生效），完整覆盖的植物目标生长×1.5；同tag最高转优先，不叠加。",
		"water_saving":"宿主四向3×3服务区，完整覆盖目标的水分扣耗保留50%（每格百分之一余量跨日累计）；不产水、不返还物品。",
		"fertility_saving":"宿主四向3×3服务区，完整覆盖目标的肥力扣耗保留50%（每格百分之一余量跨日累计）；无肥耗目标不生效。",
		"research_flat":"研究台工作量固定−1，最低1；样本不变；每天仍需玩家或负责人工作。",
		"research_speed":"研究速度×2，逐项样本×1.5向上取整；每天仍需一次研究工作与特殊食料。"}
	shell._label(parent,descriptions[d["effect"]])
	if not gu.deployed(row):
		if d["deployment"] == "independent":
			shell._icon(parent,"build","地图部署（1AP）",func():
				placing = id
				focused = id
				shell._close_page()
				shell._select_tool("inspect")
				shell.build_tool = ""
				shell.notice.text = "选择空闲陆地部署饭袋草蛊；不需开垦。右键取消。")
		else:
			shell._icon(parent,"locate","地图选择兼容设施（1AP）",func():
				placing = id
				focused = id
				shell._close_page()
				shell._select_tool("inspect")
				shell.build_tool = ""
				shell.notice.text = "点击高亮的兼容设施入驻%s；绿色可入驻，红色受阻，右键取消。" % d["name"])
			var found := false
			for uid in shell.world.facilities:
				if not gu.compatible(row,int(uid)): continue
				found = true
				var q: Dictionary = gu.quote_deploy(id,Vector2i(-1,-1),int(uid))
				var host_name := String(shell.world.facility_defs[shell.world.facilities[uid]["facility_id"]]["name"])
				var button: Button = shell._icon(parent,"build","入驻%s #%d（1AP）" % [host_name,int(uid)],func(): shell._result(manager().deploy(id,Vector2i(-1,-1),int(uid))); open())
				button.disabled = not q["ok"]
				if not q["ok"]: shell._label(parent,q["reason"])
			if not found: shell._label(parent,"暂无兼容设施。明光需补光灯；催生需田间维护站；研究蛊需研究台。可在营建与研究页查询解锁。")
		return
	var location := "地格(%d,%d)" % [int(row["origin"][0]),int(row["origin"][1])] if not row["origin"].is_empty() else "设施 #%d" % int(row["host_uid"])
	var blockers: Array = gu.blockers(row,shell.world.clock.total_days)
	shell._label(parent,location+" · "+("运行中" if blockers.is_empty() else "；".join(PackedStringArray(blockers))))
	shell._label(parent,"今日维护："+("已付%d元石；食料%s" % [int(row["paid_fee"]),items_text(row["paid_food"]) ] if int(row["paid_day"]) == shell.world.clock.total_days else "未付/尚未到生效日"))
	shell._icon(parent,"locate","定位/查看范围",func():
		focused = id
		if row["origin"].is_empty(): shell._locate_facility(int(row["host_uid"]))
		else: shell._locate(Vector2i(int(row["origin"][0]),int(row["origin"][1])))
	)
	shell._icon(parent,"cancel" if row["enabled"] else "play","休眠" if row["enabled"] else "申请次日恢复",func(): shell._result(manager().set_enabled(id,not bool(row["enabled"]))); open())
	if not row["origin"].is_empty():
		var cell := Vector2i(int(row["origin"][0]),int(row["origin"][1]))
		var env: Dictionary = shell.world.environment_at(cell)
		shell._label(parent,"水分%d / 光照%d · 肥力不参与本蛊生产" % [int(env["water"]),int(env["light"])])
		effect_details(parent,cell)
		shell._icon(parent,"irrigate","补水（清水1，1AP）",func(): shell._result(shell.world.irrigate(cell)); open())
	if not row["job"].is_empty():
		var job: Dictionary = row["job"]
		shell._bar(parent,"生产工作量",int(job["progress"]),int(job["target"]))
		shell._label(parent,"待收取" if job["ready"] else "生产中；受阻保留工作量")
		if job["ready"]: shell._icon(parent,"claim","收取%s（1AP）" % shell._materials(job["outputs"]),func(): shell._result(manager().claim(id)); open())
		else: shell._icon(parent,"clear","取消在制任务（不退款）",func(): shell._confirm("取消本批生产？进度清零，已投入不退。",func(): shell._result(manager().cancel_job(id)); open()))
	var withdraw: Button = shell._icon(parent,"clear","撤回库存（1AP）",func(): shell._result(manager().withdraw(id)); open())
	withdraw.disabled = gu.locked(id)
	if gu.locked(id): shell._label(parent,"任务锁定：请先完成/收取，或取消在制任务；研究取消在研究台操作。")

func effect_details(parent: Node, cell: Vector2i) -> void:
	var gu = manager()
	var day: int = shell.world.clock.total_days
	var d: Dictionary = gu.definition(gu.instance(focused) if not focused.is_empty() else {})
	var tags: Array = d.get("target_tags", ["plant_grow"]) if not d.is_empty() else ["plant_grow"]
	var outcome: Dictionary = gu.resolve(Rect2i(cell, Vector2i.ONE), tags, day)
	var best: int = int(outcome["groups"].get("plant_growth_speed", {}).get("value", 100))
	shell._label(parent,"当前生产速度×%.2f；同tag最高转优先，不叠加。" % (float(best)/100.0))
	for entry in outcome["groups"].get("plant_growth_speed", {}).get("candidates", []):
		shell._label(parent,"%s ×%.2f · %s" % [entry["name"],float(entry["value"])/100.0,"采用" if entry["adopted"] else entry["reason"]])
	for entry in outcome["rejected"]:
		shell._label(parent,"%s：%s" % [entry["name"],entry["reason"]])
	for entry in gu.effects_at(cell,"light",day): shell._label(parent,"光照来源：%s，强度%d（与自然/油灯取最大）" % [entry["name"],int(entry["value"])])

func host_section(uid: int) -> void:
	var d: Dictionary = shell.world.facility_defs[shell.world.facilities[uid]["facility_id"]]
	if not d.has("gu_slot"): return
	shell._heading(shell.sidebar,"后勤蛊槽 · 1个")
	var row: Dictionary = manager().in_host(uid)
	shell._label(shell.sidebar,"空槽 · 可在后勤管理页选择兼容蛊" if row.is_empty() else "%s · %s" % [manager().definition(row)["name"],"；".join(PackedStringArray(manager().blockers(row,shell.world.clock.total_days))) if not manager().blockers(row,shell.world.clock.total_days).is_empty() else "运行中"])
	shell._icon(shell.sidebar,"growth_gu","管理入驻与维护",open)

func draw_overlay(target: Node2D, projected: bool = false) -> void:
	var gu = manager()
	var id := placing if not placing.is_empty() else focused
	var row: Dictionary = gu.instance(id)
	if not placing.is_empty() and shell.world.grid.in_bounds(shell._hover.x,shell._hover.y):
		var rect := Rect2(Vector2(shell._hover)*64,Vector2(64,64))
		if projected: rect = shell.projection.ground_rect(rect)
		var host_uid := int(shell.world.facility_at(shell._hover).get("uid",0)) if not row.is_empty() and gu.definition(row)["deployment"] == "host" else 0
		var valid: bool = gu.quote_deploy(placing,shell._hover,host_uid)["ok"]
		target.draw_rect(rect,Color(0.36,0.64,0.45,0.35) if valid else Color(0.8,0.3,0.25,0.35))
	if not placing.is_empty() and not row.is_empty() and gu.definition(row)["deployment"] == "host":
		for uid in shell.world.facilities:
			if not gu.compatible(row,int(uid)): continue
			var host: Dictionary = shell.world.facilities[uid]
			var shape: Array = shell.world.facility_defs[host["facility_id"]]["footprint"]
			var host_rect := Rect2(Vector2(host["origin"][0],host["origin"][1])*64,Vector2(shape[0],shape[1])*64)
			if projected: host_rect = shell.projection.ground_rect(host_rect)
			var allowed: bool = gu.quote_deploy(placing,Vector2i(-1,-1),int(uid))["ok"]
			target.draw_rect(host_rect,Color(0.36,0.64,0.45,0.25) if allowed else Color(0.8,0.3,0.25,0.25))
			target.draw_rect(host_rect,Color("599d81") if allowed else Color("bd6554"),false,2)
	if row.is_empty() or not gu.deployed(row): return
	var d: Dictionary = gu.definition(row)
	var area: Rect2i = gu.service_zone(row, shell.world.clock.total_days) if gu.EFFECT_TAG.has(String(d["effect"])) else gu.coverage(row)
	var rect := Rect2(Vector2(area.position)*64,Vector2(area.size)*64)
	if projected: rect = shell.projection.ground_rect(rect)
	target.draw_rect(rect,Color(0.35,0.65,0.55,0.12))
	target.draw_rect(rect,Color(0.35,0.65,0.55,0.7),false,2)
	var targets := []
	for crop in shell.world.crops.values(): targets.append({"origin":crop["origin"],"eligible":true})
	for other in gu.state["instances"]:
		if not other["origin"].is_empty(): targets.append({"origin":other["origin"],"eligible":true})
	for host in shell.world.facilities.values(): targets.append({"origin":host["origin"],"eligible":false})
	for target_row in targets:
		var cell := Vector2i(int(target_row["origin"][0]),int(target_row["origin"][1]))
		if not area.has_point(cell): continue
		var point := Vector2(cell)*64+Vector2(32,32)
		if projected: point = shell.projection.ground_to_view(point)
		var eligible: bool = target_row["eligible"] and (d["effect"] == "light" or gu.EFFECT_TAG.has(String(d["effect"])))
		var effective: bool = eligible and gu.active(row,shell.world.clock.total_days)
		target.draw_arc(point,18,0,TAU,24,Color("599d81") if effective else (Color("d8b96a") if eligible else Color("a6aaa2")),2)
