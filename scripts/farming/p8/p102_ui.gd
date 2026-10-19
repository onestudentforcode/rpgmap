extends RefCounted
var shell
var floor_tool := ""
var show_regions := false
var field_tool := false
var field_edit := 0
var field_cells: Array = []
const FLOOR_NAMES := {"ordinary":"普通地板","farmland":"耕地","natural":"拆除铺面"}
func _init(owner) -> void: shell = owner

func choose_floor(kind: String) -> void:
	field_tool = false
	floor_tool = kind
	shell.build_tool = ""
	shell.logistics_ui.placing = ""
	shell._close_page()
	shell.notice.text = "点击空闲地格：%s（1AP）；普通地板耗原木1，拆除不返料。右键取消。" % FLOOR_NAMES[kind]
	shell.overlay.queue_redraw()

func open() -> void:
	floor_tool=""
	field_tool=false
	shell._context = "rooms"
	shell._page("露天农业区 · 地板与收获奖励")
	shell._label(shell.sidebar,"先铺耕地，再明确划定田块。四邻接只检查同一田块内部；紧贴的田块不会合并，新耕地不会自动加入。不要求墙或门。")
	shell._button(shell.sidebar,"划定新田块（0AP）",func(): choose_field())
	for kind in ["ordinary","farmland","natural"]:
		shell._button(shell.sidebar,FLOOR_NAMES[kind]+"（1AP）",func(): choose_floor(kind))
	shell._label(shell.sidebar,"硬质地板的管道、输送和传动留待后续，当前不提供这些能力。")
	shell.services_ui.agriculture(shell.sidebar)
	shell._button(shell.sidebar,"隐藏区域覆盖" if show_regions else "显示区域覆盖",func(): show_regions=not show_regions; shell.overlay.queue_redraw(); open())
	shell._label(shell.sidebar,"一级配套允许运行；二级入驻蛊虫强化；三级育种田：催生＋锁水，首次成熟产种基础概率25%；三级丰产田：催生＋节肥，额外主产物25%；三级复合农业区同时拥有两种回报。概率与增产按本轮实际合格生长比例计算。")
	var regions: Array = shell.world.rooms.regions(shell.world.clock.total_days)
	if regions.is_empty(): shell._label(shell.sidebar,"尚无耕地。先开垦或用耕地工具铺设田块。")
	for region in regions:
		var card = shell._card(shell.sidebar)
		shell._label(card,"%s · 编号%d" % [region["label"],region["uid"]])
		var uid: int = region["uid"]
		shell._button(card,"编辑田块边界（0AP）",func(): choose_field(uid))
		shell._button(card,"解除田块划区（保留作物与历史贡献）",func(): shell._result(shell.world.rooms.erase_field(uid)); open())
		shell._heading(card,"%s · %d格" % [region["name"],region["cells"].size()])
		for tag in region["covered"]:
			var names := {"plant_growth_speed":"催生","plant_water_saving":"锁水","plant_fertility_saving":"节肥"}
			var missing: Array=region["missing"][tag]
			shell._label(card,"%s：%s；当日有效来源%d座" % [names[tag],"完整覆盖" if missing.is_empty() else "缺%d/%d格覆盖" % [missing.size(),region["cells"].size()],region["sources"][tag].size()])
			if not missing.is_empty():
				var gap: Vector2i=missing[0]
				shell._button(card,"定位%s覆盖缺口（%d,%d）" % [names[tag],gap.x,gap.y],func(): show_regions=true; shell._locate(gap))
		var c: Vector2i = region["cells"][0]
		shell._button(card,"定位田块",func(): show_regions=true; shell._locate(c))
	shell._encyclopedia_link(shell.sidebar,"rule:rooms")

func choose_field(uid: int = 0) -> void:
	field_tool = true
	field_edit = uid
	floor_tool = ""
	shell.build_tool = ""
	shell.logistics_ui.placing = ""
	shell.ranch_ui.zone_tool = ""
	shell.ranch_ui.paint_zone = -1
	field_cells = shell.world.rooms.field(uid).get("cells",[]).duplicate()
	_field_page()

func _field_page() -> void:
	shell._context = "rooms"
	shell._page("编辑田块" if field_edit > 0 else "划定田块")
	shell._label(shell.sidebar,"点击耕地加入/移除选区，右键取消。选中的地格须四邻接，不得与其他田块重叠或切开多格作物。已选%d格。" % field_cells.size())
	var q: Dictionary = shell.world.rooms.preview_field(field_cells,field_edit)
	shell._label(shell.sidebar,"选区可用" if q["ok"] else String(q["reason"]))
	shell._button(shell.sidebar,"确认边界（0AP）",func():
		var result: Dictionary = shell.world.rooms.edit_field(field_edit,field_cells) if field_edit > 0 else shell.world.rooms.create_field(field_cells)
		shell._result(result)
		if result["ok"]: open())
	shell._button(shell.sidebar,"取消",open)
	shell.overlay.queue_redraw()

func click_field(cell: Vector2i) -> void:
	var text: String = shell.world.rooms.key(cell)
	if text in field_cells: field_cells.erase(text)
	elif shell.world.rooms.farmland(cell): field_cells.append(text)
	_field_page()

func crop_details(parent: Node, row: Dictionary) -> void:
	var data: Dictionary = shell.world.rooms.state["plants"].get(str(row["uid"]),{})
	if data.is_empty(): return
	shell._heading(parent,"农业房间回报")
	var total := maxi(1,int(data["growth"]))
	shell._label(parent,"本轮实际生长%d/%d点；育种合格%d点，丰产合格%d点。" % [data["growth"],data["target"],data["seed_work"],data["material_work"]])
	shell._label(parent,"本轮丰产比例%.1f%%；主产物增产期望%.1f%%，小数概率取整。" % [float(data["material_work"])*100/total,float(data["material_work"])*25/total])
	if data["seed_checked"]:
		shell._label(parent,"首次育种已固定："+("已领取/已结算" if data["seed_claimed"] else ("种子1份，首次收获一并领取" if data["seed_award"]>0 else "本株未产种，留株不重抽")))
	else:
		shell._label(parent,"首次成熟产种基础25%%；按当前合格进度计算为%.2f%%。未成熟不抽奖。" % (float(data["seed_work"])*25/total))
	shell._button(parent,"查看农业区与铺面",open)

func result_text(result: Dictionary) -> String:
	if not result.get("ok",false) or not result.get("save_error","").is_empty() or not result.has("room_rewards"): return ""
	return "基础收成：%s；育种奖励：%s；丰产奖励：%s" % [shell.logistics_ui.items_text(result["base_items"]),shell.logistics_ui.items_text(result["room_rewards"]["seed"]),shell.logistics_ui.items_text(result["room_rewards"]["material"])]

func report(parent: Node) -> void:
	var card=shell._card(parent)
	shell._heading(card,"农业收获 · 基础与房间奖励")
	shell._label(card,"以下为资源账保留的最近15个结算日与今日实际入库；未领取权益不计入，环境节约不计实物。")
	var reasons:={"采收收获":{},"后勤蛊产物收取":{},"育种奖励":{},"丰产奖励":{}}
	var rows: Array=shell.world.ledger.state["history"].duplicate()
	rows.append(shell.world.ledger.state["pending"])
	for row in rows:
		for item in row["inflows"]:
			for reason in row["inflows"][item]:
				if reasons.has(reason): reasons[reason][item]=int(reasons[reason].get(item,0))+int(row["inflows"][item][reason])
	for reason in reasons: shell._label(card,reason+"："+shell.logistics_ui.items_text(reasons[reason]))
	shell._button(card,"查看农业区与铺面",open)

func draw_ground(target: Node2D, projected: bool) -> void:
	for text in shell.world.rooms.state["floors"]:
		var c: Vector2i = shell.world.rooms.cell_at(text)
		var rect := Rect2(Vector2(c)*64,Vector2(64,64))
		if projected: rect = shell.projection.ground_rect(rect)
		target.draw_rect(rect,Color("cbbda0"))
		target.draw_rect(rect.grow(-1),Color("9d8f76"),false,1)
		for part in [1,2,3]:
			var y: float = rect.position.y+rect.size.y*float(part)/4
			target.draw_line(Vector2(rect.position.x,y),Vector2(rect.end.x,y),Color("b4a58a"),1)
	if not show_regions: return
	for region in shell.world.rooms.regions(shell.world.clock.total_days):
		var color := Color.from_hsv(fmod(float(region["uid"])*0.381966,1.0),0.5,0.8)
		for c in region["cells"]:
			var rect := Rect2(Vector2(c)*64,Vector2(64,64))
			if projected: rect=shell.projection.ground_rect(rect)
			target.draw_rect(rect,Color(color,0.16))
			target.draw_rect(rect.grow(-1),Color(color,0.7),false,1)

func draw_preview(target: Node2D, projected: bool) -> void:
	if field_tool and shell._context == "rooms":
		for text in field_cells:
			var cell: Vector2i = shell.world.rooms.cell_at(text)
			var box := Rect2(Vector2(cell)*64,Vector2(64,64))
			if projected: box = shell.projection.ground_rect(box)
			target.draw_rect(box,Color(0.2,0.6,0.8,0.35))
		return
	if floor_tool.is_empty() or not shell.world.grid.in_bounds(shell._hover.x,shell._hover.y): return
	var rect:=Rect2(Vector2(shell._hover)*64,Vector2(64,64))
	if projected: rect=shell.projection.ground_rect(rect)
	var allowed: bool=shell.world.rooms.quote_floor(shell._hover,floor_tool)["ok"]
	target.draw_rect(rect,Color(0.3,0.65,0.4,0.4) if allowed else Color(0.8,0.3,0.25,0.4))
	if not allowed: return
	var change: Dictionary=shell.world.rooms.preview_floor(shell._hover,floor_tool)
	for region in change["after"]:
		for cell in region["cells"]:
			var affected:=Rect2(Vector2(cell)*64,Vector2(64,64))
			if projected: affected=shell.projection.ground_rect(affected)
			target.draw_rect(affected.grow(-1),Color(0.8,0.5,0.2,0.7) if change["downgrade"] else Color(0.3,0.65,0.4,0.6),false,1)
	var readable: float=1.0/maxf(0.1,shell.camera.zoom.x*shell._ui_scale)
	var font: Font=shell.get_theme_default_font()
	var font_size:=int(14*readable)
	var point: Vector2=rect.end+Vector2(4,18)*readable
	var extent: Vector2=font.get_string_size(change["summary"],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	target.draw_rect(Rect2(point-Vector2(4,17)*readable,extent+Vector2(8,5)*readable),Color(0.98,0.97,0.93,0.95))
	target.draw_string(font,point,change["summary"],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("8a4934") if change["downgrade"] else Color("305c42"))
