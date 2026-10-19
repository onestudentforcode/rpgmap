extends RefCounted
var shell
var editing:=0
var selected: Array=[]
var label:="生产系统"
func _init(owner) -> void: shell=owner
func manager(): return shell.world.services

func render(parent: Node) -> void:
	var intro=shell._card(parent)
	shell._heading(intro,"三级畜牧系统")
	shell._label(intro,"一级配套允许运行；二级由蛊虫或特殊道具强化。将房间明确关联成系统，实际服务才取得三级收益；紧贴不会自动合并。")
	shell._label(intro,"繁育场：二级圈养＋一级育幼，出生最多赠送10%成长；协同役使场：二级工作＋一级维持＋二级额外放牧，保留同岗位同配方工作余量；两者并存为综合牧场。")
	for system in manager().state["systems"]:
		var card=shell._card(parent)
		shell._heading(card,String(system["name"])+" · 系统#"+str(system["uid"]))
		var members:=[]
		for uid in system["zones"]:
			var zone: Dictionary=shell.world.ranch.zone(int(uid))
			members.append(String(zone.get("name","已移除")))
		shell._label(card,"关联房间："+"、".join(members))
		var uid: int=system["uid"]
		shell._button(card,"编辑组合",func():
			editing=uid;selected=system["zones"].duplicate();label=String(system["name"]);shell.ranch_ui.open())
	var draft=shell._card(parent)
	shell._heading(draft,"编辑系统" if editing>0 else "创建系统（提交1AP）")
	var name_edit:=LineEdit.new()
	name_edit.text=label
	name_edit.placeholder_text="系统名称"
	name_edit.text_changed.connect(func(text): label=text)
	draft.add_child(name_edit)
	for zone in shell.world.ranch.state["zones"]:
		var box:=CheckBox.new()
		var uid: int=zone["uid"]
		var owner: Dictionary=manager().system_of(uid)
		box.text=String(zone["name"])
		box.button_pressed=uid in selected
		box.disabled=not owner.is_empty() and int(owner["uid"])!=editing
		box.toggled.connect(func(on):
			if on and not uid in selected: selected.append(uid)
			elif not on: selected.erase(uid))
		draft.add_child(box)
	shell._button(draft,"提交组合（1AP，无变化不收费）",func():
		var result: Dictionary=manager().set_system(editing,label,selected.duplicate())
		shell._result(result)
		if result["ok"]: editing=0;selected=[];label="生产系统"
		shell.ranch_ui.open())
	shell._button(draft,"取消编辑／创建另一系统",func(): editing=0;selected=[];label="生产系统";shell.ranch_ui.open())
	shell._encyclopedia_link(parent,"rule:animal-services")

func zone_card(parent: Node,zone: Dictionary) -> void:
	var status: Dictionary=manager().level_of(zone)
	var owner: Dictionary=manager().system_of(int(zone["uid"]))
	shell._label(parent,"房间：%s%s；所属系统：%s" % ["结构不合格" if status["level"]==0 else "%d级" % int(status["level"]),"（强化暂停）" if not status["active"] and status["level"]==2 else "",owner.get("name","未关联")])
	for host in shell.world.ranch._facilities_in_zone(zone):
		if String(host["facility_id"])=="toy_station": toy_controls(parent,int(host["uid"]),true)
		elif String(host["facility_id"]) in ["soothing_station","dispatch_station"]:
			var gu: Dictionary=shell.world.logistics.in_host(int(host["uid"]))
			shell._label(parent,"%s：%s，服务上限4空间/单位" % [shell.world.facility_defs[host["facility_id"]]["name"],"空蛊槽" if gu.is_empty() else shell.world.logistics.definition(gu)["name"]])
			shell._button(parent,"管理蛊虫入驻与维护",shell.logistics_ui.open)

func toy_controls(parent: Node,uid: int,ranch_page: bool=false) -> void:
	var installed: bool=manager().state["toys"].has(str(uid))
	shell._label(parent,"玩具站#%d：%s。藤球长期使用，每个有效额外放牧单位10%%额外恢复1疲劳，次日开日统一结算；服务上限4空间。" % [uid,"已装藤球" if installed else "空槽，仅基础活动"])
	shell._button(parent,"卸下藤球（1AP）" if installed else "装入藤球（1AP）",func():
		shell._result(manager().install_toy(uid,not installed))
		if ranch_page: shell.ranch_ui.open()
		else: shell._show_cell())

func agriculture(parent: Node) -> void:
	for uid in shell.world.facilities:
		var host: Dictionary=shell.world.facilities[uid]
		if host["facility_id"]!="field_service_station": continue
		var card=shell._card(parent)
		var id:=int(uid)
		var target: Dictionary=shell.world.rooms.field(int(manager().state["agriculture"].get(str(id),0)))
		shell._heading(card,"维护站#%d · %s" % [id,target.get("name","未关联田块")])
		shell._label(card,"一级可运行" if manager().host_ready(id) else "一级未成立：检查脚下普通地板、关联田块至少4格且与站相邻。")
		for field in shell.world.rooms.state["fields"]:
			var field_uid:=int(field["uid"])
			shell._button(card,"关联"+String(field["name"])+"（0AP）",func(): shell._result(manager().link_agriculture(id,field_uid));shell.rooms_ui.open())

func work_pool(parent: Node,yard: int) -> void:
	var total:=0
	for key in manager().state["pools"]:
		if int(String(key).split(":")[0])==yard: total+=int(manager().state["pools"][key]["points"])
	shell._label(parent,"已确认工作余量：%.2f点（限原岗位同配方；三级失效时封存）" % (total/100.0))
	if total>0:
		shell._button(parent,"放弃余量以切换配方／拆除",func():
			shell._confirm("放弃此工作场的全部已确认余量？不会返还材料。",func(): shell._result(manager().drop_carry(yard));shell.ranch_ui.open()))
