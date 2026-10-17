extends RefCounted
## Player-facing management shares the existing responsive sidebar primitives.
var shell
var placing := ""
var focused := ""
func _init(owner) -> void: shell = owner
func manager(): return shell.world.logistics
func items_text(items: Dictionary) -> String:
	return "无" if items.is_empty() else shell._materials(items)

## Ability descriptions render from the live definition values so the manager,
## encyclopedia and handbook can never drift apart.
func ability_text(d: Dictionary) -> String:
	match String(d["effect"]):
		"production": return "光照≥60、水分≥30；每有效日扣水分8，3有效日收稻米4，不产秸秆、不消耗肥力。"
		"light": return "范围外扩%d格，提供光照%d，与自然光/油灯取最大。入驻后替代该灯燃油模式；喜阴作物可能降效。" % [int(d["range"]),int(d["value"])]
		"growth_speed": return "宿主四向%d×%d服务区（可转向，1AP次日生效），完整覆盖的植物目标生长×%.1f；同tag最高转优先，不叠加。" % [int(d["range"]),int(d["range"]),float(int(d["value"]))/100.0]
		"water_saving": return "宿主四向%d×%d服务区，完整覆盖目标的水分扣耗保留%d%%（每格百分之一余量跨日累计）；不产水、不返还物品。" % [int(d["range"]),int(d["range"]),int(d["value"])]
		"fertility_saving": return "宿主四向%d×%d服务区，完整覆盖目标的肥力扣耗保留%d%%（每格百分之一余量跨日累计）；无肥耗目标不生效。" % [int(d["range"]),int(d["range"]),int(d["value"])]
		"research_flat": return "研究台工作量固定−1，最低1；样本不变；每天仍需玩家或负责人工作。"
	return "研究速度×2，逐项样本×1.5向上取整；每天仍需一次研究工作与特殊食料。"

const FACING_NAMES := {"east":"东","south":"南","west":"西","north":"北"}

func open() -> void:
	shell.rooms_ui.floor_tool=""
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
	shell._label(parent,ability_text(d))
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
	if int(row["host_uid"]) > 0 and gu.EFFECT_TAG.has(String(d["effect"])):
		_agriculture_status(parent,row)
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
	var gu = manager()
	var d: Dictionary = shell.world.facility_defs[shell.world.facilities[uid]["facility_id"]]
	if not d.has("gu_slot"): return
	shell._heading(shell.sidebar,"后勤蛊槽 · 1个")
	var row: Dictionary = gu.in_host(uid)
	shell._label(shell.sidebar,"空槽 · 可在后勤管理页选择兼容蛊" if row.is_empty() else "%s · %s" % [gu.definition(row)["name"],"；".join(PackedStringArray(gu.blockers(row,shell.world.clock.total_days))) if not gu.blockers(row,shell.world.clock.total_days).is_empty() else "运行中"])
	shell._icon(shell.sidebar,"growth_gu","管理入驻与维护",open)
	# The agriculture service zone is a separate contract from the station's own
	# maintenance coverage; both are stated here with their own geometry.
	if String(shell.world.facilities[uid]["facility_id"]) == "field_service_station":
		var active: String = gu.facing_of(uid)
		var upcoming: String = gu.next_facing_of(uid)
		var shape: Array = shell.world.facility_defs[shell.world.facilities[uid]["facility_id"]]["footprint"]
		var origin := Vector2i(int(shell.world.facilities[uid]["origin"][0]),int(shell.world.facilities[uid]["origin"][1]))
		var zone: Rect2i = gu.directed_zone(origin,shape,upcoming).intersection(shell.world.grid.bounds())
		if zone.size.x > 0 and zone.size.y > 0:
			shell._label(shell.sidebar,"蛊服务区3×3（当前%s向，本日已锁定） · 次日%s向范围：(%d,%d)起%d×%d" % [
				FACING_NAMES[active],FACING_NAMES[upcoming],zone.position.x,zone.position.y,zone.size.x,zone.size.y])
		else:
			shell._label(shell.sidebar,"蛊服务区3×3（当前%s向） · 次日%s向超出地图，裁剪后为空" % [FACING_NAMES[active],FACING_NAMES[upcoming]])
		for facing in ["east","south","west","north"]:
			var turn: Button = shell._icon(shell.sidebar,"rotate","转向%s（1AP，次日生效）" % FACING_NAMES[facing],func():
				shell._result(manager().set_facing(uid,facing))
				shell._show_cell())
			turn.disabled = upcoming == facing
		shell._label(shell.sidebar,"建筑自身补水/施肥是独立来源，范围见下方装置段，不随蛊服务区或蛊停摆变化。")

## Full-footprint agriculture explanation for a crop: actual growth multiplier,
## per-resource retention, adopted sources with rank, suppressed-but-paid
## sources and the current environment degradation reasons.
func crop_agriculture(parent: Node, crop: Dictionary) -> void:
	var gu = manager()
	var def: Dictionary = shell.world.crop_defs[crop["crop_id"]]
	var shape: Array = def["footprint"]
	var rect := Rect2i(Vector2i(int(crop["origin"][0]),int(crop["origin"][1])),Vector2i(int(shape[0]),int(shape[1])))
	var outcome: Dictionary = gu.resolve(rect, def.get("target_tags",[]), shell.world.clock.total_days)
	if outcome["groups"].is_empty() and outcome["rejected"].is_empty(): return
	var growth := int(outcome["groups"].get("plant_growth_speed",{}).get("value",100))
	var water := int(outcome["groups"].get("plant_water_saving",{}).get("value",100))
	var fertility := int(outcome["groups"].get("plant_fertility_saving",{}).get("value",100))
	var fert_note := "（本目标无肥耗，节肥不生效）" if int(def["fertility_use"]) == 0 else ""
	shell._heading(parent,"农业辅助")
	shell._label(parent,"完整占地%d×%d · 生长×%.1f · 水耗保留%d%% · 肥耗保留%d%%%s" % [
		int(shape[0]),int(shape[1]),float(growth)/100.0,water,fertility,fert_note])
	for tag in ["plant_growth_speed","plant_water_saving","plant_fertility_saving"]:
		var group: Dictionary = outcome["groups"].get(tag,{})
		if group.is_empty(): continue
		for entry in group["candidates"]:
			if entry["adopted"]:
				shell._label(parent,"采用：%s（%d转）· 来源值%d" % [entry["name"],int(entry["rank"]),int(entry["value"])])
			else:
				shell._label(parent,"%s" % entry["reason"])
	for entry in outcome["rejected"]:
		shell._label(parent,"%s：%s" % [entry["name"],entry["reason"]])
	var reasons := _environment_reasons(rect, def)
	if not reasons.is_empty(): shell._label(parent,"环境降效：%s" % "；".join(PackedStringArray(reasons)))

func _environment_reasons(rect: Rect2i, def: Dictionary) -> Array:
	var settings: Dictionary = shell.world.config["environment"]
	var water := 0
	var fertility := 0
	var light := 0
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			var env: Dictionary = shell.world.environment_at(Vector2i(x,y))
			water += int(env["water"])
			fertility += int(env["fertility"])
			light += int(env["light"])
	var cells := rect.get_area()
	var out := []
	if float(water)/cells < float(settings["optimal_water"]): out.append("水分低于适宜")
	if float(fertility)/cells < float(settings["optimal_fertility"]): out.append("肥力低于适宜")
	if absf(float(light)/cells - float(def["light"])) > float(settings["light_tolerance"]): out.append("光照偏离适宜")
	return out

## Zone summary for a host-deployed agriculture gu card: served area versus
## partially covered plants, so hidden quotas can never masquerade as service.
func _agriculture_status(parent: Node, row: Dictionary) -> void:
	var gu = manager()
	var day: int = shell.world.clock.total_days
	var zone: Rect2i = gu.service_zone(row, day)
	if zone.size.x <= 0 or zone.size.y <= 0:
		shell._label(parent,"服务区超出地图（裁剪后为空），不产生效果。")
		return
	var served := 0
	var partial := 0
	var lines := []
	for crop in shell.world.crops.values():
		var def: Dictionary = shell.world.crop_defs[crop["crop_id"]]
		var shape: Array = def["footprint"]
		var rect := Rect2i(Vector2i(int(crop["origin"][0]),int(crop["origin"][1])),Vector2i(int(shape[0]),int(shape[1])))
		if zone.encloses(rect):
			served += int(shape[0])*int(shape[1])
			if lines.size() < 6:
				var outcome: Dictionary = gu.resolve(rect, def.get("target_tags",[]), day)
				var mine := false
				for tag in outcome["groups"]:
					if String(outcome["groups"][tag]["source"].get("instance_id","")) == String(row["instance_id"]):
						mine = true
				lines.append("(%d,%d) %s%d×%d%s" % [rect.position.x,rect.position.y,String(def.get("name",crop["crop_id"])),int(shape[0]),int(shape[1])," · 本源采用" if mine else ""])
		elif zone.intersects(rect):
			partial += 1
	shell._label(parent,"服务区(%d,%d)%d×%d：完整覆盖种植面积%d格 · 部分覆盖%d株不生效" % [
		zone.position.x,zone.position.y,zone.size.x,zone.size.y,served,partial])
	for line in lines: shell._label(parent,line)
	var next: String = gu.next_facing_of(int(row["host_uid"]))
	if next != gu.facing_of(int(row["host_uid"])):
		shell._label(parent,"已提交转向：%s向，次日开日生效。" % FACING_NAMES[next])

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
	var day: int = shell.world.clock.total_days
	var agriculture: bool = gu.EFFECT_TAG.has(String(d["effect"]))
	var area: Rect2i = gu.service_zone(row, day) if agriculture else gu.coverage(row)
	var rect := Rect2(Vector2(area.position)*64,Vector2(area.size)*64)
	if projected: rect = shell.projection.ground_rect(rect)
	target.draw_rect(rect,Color(0.35,0.65,0.55,0.12))
	target.draw_rect(rect,Color(0.35,0.65,0.55,0.7),false,2)
	if agriculture and int(row["host_uid"]) > 0:
		# The committed-but-not-yet-effective zone reads as a distinct outline;
		# targets are graded by the shared resolution, colors never replace the
		# written reasons in the panels.
		var upcoming: String = gu.next_facing_of(int(row["host_uid"]))
		if upcoming != gu.facing_of(int(row["host_uid"])):
			var host: Dictionary = shell.world.facilities[int(row["host_uid"])]
			var shape: Array = shell.world.facility_defs[host["facility_id"]]["footprint"]
			var next_zone: Rect2i = gu.directed_zone(Vector2i(int(host["origin"][0]),int(host["origin"][1])),shape,upcoming).intersection(shell.world.grid.bounds())
			if next_zone.size.x > 0 and next_zone.size.y > 0:
				var next_rect := Rect2(Vector2(next_zone.position)*64,Vector2(next_zone.size)*64)
				if projected: next_rect = shell.projection.ground_rect(next_rect)
				target.draw_rect(next_rect,Color("e8d9a0",0.9),false,3)
		for crop in shell.world.crops.values():
			var def: Dictionary = shell.world.crop_defs[crop["crop_id"]]
			var shape: Array = def["footprint"]
			var crop_rect := Rect2i(Vector2i(int(crop["origin"][0]),int(crop["origin"][1])),Vector2i(int(shape[0]),int(shape[1])))
			if not area.encloses(crop_rect) and not area.intersects(crop_rect): continue
			var center := Vector2(crop_rect.position+crop_rect.size/2)*64
			if projected: center = shell.projection.ground_to_view(center)
			var color := Color("a6aaa2")
			if area.encloses(crop_rect):
				var outcome: Dictionary = gu.resolve(crop_rect, def.get("target_tags",[]), day)
				var mine := false
				for tag in outcome["groups"]:
					if String(outcome["groups"][tag]["source"].get("instance_id","")) == String(row["instance_id"]):
						mine = true
				color = Color("599d81") if mine else Color("d8b96a")
			else:
				color = Color("bd6554")
			target.draw_arc(center,18,0,TAU,24,color,2)
		return
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
		var effective: bool = eligible and gu.active(row,day)
		target.draw_arc(point,18,0,TAU,24,Color("599d81") if effective else (Color("d8b96a") if eligible else Color("a6aaa2")),2)
