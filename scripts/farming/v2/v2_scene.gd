extends "res://scripts/farming/v1/v1_scene.gd"
## V2 shell: husbandry facility panels plus the daily resource overview window.
const V2World := preload("res://scripts/farming/v2/v2_world.gd")
const V2Store := preload("res://scripts/farming/v2/v2_slot_store.gd")
const HusbandryModule := preload("res://scripts/farming/v2/v2_husbandry.gd")
const LedgerModule := preload("res://scripts/farming/v2/v2_resource_ledger.gd")
const ELEMENTS := {"wood": "木", "fire": "火", "earth": "土", "water": "水", "gold": "金"}
var _habitat_expanded := false
var _habitat_expanded_uid := 0
var resource_mode := 0
var resource_day := -1
var resource_element := "全部"
var resource_search := ""
var resource_focus := ""

func _init() -> void:
	store = V2Store.new()
	manual_mode = true
	minimum_map_zoom = 0.1
	settings = Settings.new("user://farm_demo_v2_settings.cfg", minimum_map_zoom)
	product_title = "灵田 Demo V2 · P7.c"
	terrain_path = "res://content/farming/baked/v2/terrains.json"
	preview_prefix = "v2"
func _make_store(directory: String = ""):
	return V2Store.new() if directory.is_empty() else V2Store.new(directory)
func _make_world(slot_store):
	return V2World.new(slot_store)

func _extra_nav() -> void:
	_icon(top_nav,"locate","资源一览 · 每日净变化",_show_resources)

## Typed accessors for V2-only modules the typed V1 shell cannot see.
func hus() -> HusbandryModule:
	return (world as V2World).husbandry

func books() -> LedgerModule:
	return (world as V2World).ledger

func _fit_map() -> void:
	var extent := Vector2(world.grid.width,world.grid.height)*64.0
	# Leave room for the expanded toolbar, including at the compatibility window.
	var bottom := _camera_bottom_margin()
	var zoom := clampf(minf(board.size.x/extent.x,maxf(64,board.size.y-bottom)/extent.y)*0.94,minimum_map_zoom,3.0)
	camera.zoom = Vector2.ONE*zoom
	camera.position = extent*0.5+Vector2(0,bottom*0.5/zoom)

func _camera_bottom_margin() -> float:
	return 128.0 if tool_grid.columns == 10 else 176.0

func _diet_selector(habitat: Dictionary, caption: String, diet_kind: String, slot: String) -> void:
	var husbandry := hus()
	# Caption and selector stack vertically: side-by-side clips both at 360px.
	_label(sidebar,caption)
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for diet in husbandry.species_def(habitat["species_id"])[diet_kind]:
		selector.add_item("%s：%s" % [diet["name"],_materials(diet["inputs"])])
		selector.set_item_metadata(selector.item_count-1,diet["id"])
		if diet["id"] == habitat[slot]: selector.select(selector.item_count-1)
	selector.item_selected.connect(func(index): _result(husbandry.set_diet(int(habitat["facility_uid"]),diet_kind,slot,selector.get_item_metadata(index))); _show_cell())
	sidebar.add_child(selector)

## Special slot: legal recipes plus "暂不生产", which keeps the last recipe saved.
func _special_selector(habitat: Dictionary) -> void:
	var husbandry := hus()
	_label(sidebar,"特殊食物 · 成体生产计划")
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.add_item("暂不生产（保留当前食谱）")
	selector.set_item_metadata(0,"")
	if not habitat["production_enabled"]: selector.select(0)
	var index := 1
	for diet in husbandry.species_def(habitat["species_id"])["special_diets"]:
		selector.add_item("%s：%s" % [diet["name"],_materials(diet["inputs"])])
		selector.set_item_metadata(index,diet["id"])
		if habitat["production_enabled"] and diet["id"] == habitat["special_diet_id"]: selector.select(index)
		index += 1
	selector.item_selected.connect(func(choice): _result(husbandry.set_special_diet(int(habitat["facility_uid"]),selector.get_item_metadata(choice))); _show_cell())
	sidebar.add_child(selector)

func _show_habitat(facility: Dictionary) -> void:
	var uid := int(facility["uid"])
	var husbandry := hus()
	var habitat: Dictionary = husbandry.ensure(uid)
	var definition: Dictionary = world.facility_defs[facility["facility_id"]]
	var species: Dictionary = husbandry.species_def(habitat["species_id"])
	var counts := husbandry.summary(habitat)
	if _habitat_expanded_uid != uid:
		_habitat_expanded = false
		_habitat_expanded_uid = uid
	_picture(sidebar,facility["facility_id"],64)
	_heading(sidebar,"%s · %d/%d只 · 幼体%d / 成体空闲%d / 周期%d / 待收%d" % [definition["name"],counts["total"],int(definition["capacity"]),counts["juvenile"],counts["idle_adults"],counts["running"],counts["ready"]])
	var claim_quote := husbandry.quote_claim(uid)
	if claim_quote["ok"]:
		_label(sidebar,"待收%d只：%s%s" % [int(claim_quote["ready"]),_materials(claim_quote["outputs"]),
			" · 出塘移除成体，不能回退" if int(claim_quote["removes"]) > 0 else " · 剪毛保留成体"])
		var claim_button := _icon(sidebar,"claim","收取（1AP）",func(): _result(husbandry.claim(uid)); _show_cell())
		claim_button.disabled = false
	if habitat["default_notice"]:
		_label(sidebar,"新建设施已采用默认配置：%s、%s、%s；尚未购入动物或投喂，选择食谱本身不扣料。" % [species["name"],
			husbandry.diet_name(habitat["species_id"],"base_diets",habitat["basic_diet_id"]),
			husbandry.diet_name(habitat["species_id"],"special_diets",habitat["special_diet_id"])])
	_label(sidebar,"动物：%s（幼体%d元石/只，每设施单物种）" % [species["name"],int(species["juvenile_price"])])
	_diet_selector(habitat,"基础食物 · 维持与成长","base_diets","basic_diet_id")
	_special_selector(habitat)
	if not habitat["production_enabled"]:
		_label(sidebar,"已停止启动新周期；已有周期仍按原投入继续，需要每日基础维护。")
	var quote := husbandry.quote_maintenance(uid)
	if counts["total"] > 0:
		var served := "今日已喂%d/%d" % [counts["fed_today"],counts["total"]]
		if quote["ok"]:
			var basic: Dictionary = quote["basic"]
			var special: Dictionary = quote["special"]
			if int(basic["targets"]) > 0:
				_label(sidebar,"%s · 本次基础补喂%d只：%s" % [served,int(basic["targets"]),_materials(basic["inputs"])])
			else:
				_label(sidebar,"%s · %s" % [served,String(basic["reason"])])
			if int(special["targets"]) > 0 and special["ok"]:
				_label(sidebar,"特殊投喂：%d只空闲成体 × %s" % [int(special["targets"]),_materials(special["inputs"])])
			elif int(special["targets"]) > 0:
				_label(sidebar,"特殊未启动：%s" % String(special["reason"]))
			else:
				_label(sidebar,"特殊无启动对象：%s" % String(special["reason"]))
			_label(sidebar,"整体维护成功一次仅扣1AP；基础/特殊分支各自整批执行，缺料不部分投。")
		else:
			_label(sidebar,"%s · %s" % [served,String(quote["reason"])])
		var feed := _icon(sidebar,"fodder_grass","整体维护（1AP）",func(): _result(husbandry.maintain(uid)); _show_cell())
		feed.disabled = not quote["ok"]
		var care := husbandry.care_quote(habitat,0)
		var coverage := PackedStringArray()
		for ident in care["coverage"]:
			coverage.append("%s可服务%d次" % [world._items[ident]["name"],int(care["coverage"][ident]["days"])])
		_label(sidebar,"明日起整场需求：%s · %s" % [_materials(care["tomorrow_full"]),
			"库存覆盖："+"、".join(coverage) if not coverage.is_empty() else "库存暂不覆盖一次整场服务"])
		if not _materials(care["growth_needs"]).is_empty():
			_label(sidebar,"幼体剩余育成需求：%s（按当前食谱，不含成体维持）" % _materials(care["growth_needs"]))
	else:
		_label(sidebar,"空场 · 购入幼体后开始养育；缺料暂停不死亡，补齐后恢复。")
	if habitat.has("water"):
		_bar(sidebar,"水体可用度",int(habitat["water"]),int(husbandry.settings["water"]["maximum"]))
		if counts["total"] > 0:
			var support := husbandry.water_support_days(habitat)
			var predicted := maxi(0,int(habitat["water"])-int(husbandry.settings["water"]["decay"]))
			_label(sidebar,"日结后预计%d · %s" % [predicted,"还可支持%d次日结成长" % support if support > 0 else "已达暂停线，先维护水体再投喂"])
			var water_quote := husbandry.quote_water(uid)
			_label(sidebar,"维护：%s → +40（1AP）· %s" % [_materials(water_quote["inputs"]) if water_quote["ok"] else "清水×2",String(water_quote["reason"]) if not water_quote["ok"] else "可执行"])
			var water_button := _icon(sidebar,"clean_water","维护水体（1AP）",func(): _result(husbandry.maintain_water(uid)); _show_cell())
			water_button.disabled = not water_quote["ok"]
		else:
			_label(sidebar,"空场水体不衰减，也无需维护。")
	var left: int = int(definition["capacity"]) - int(counts["total"])
	if left > 0:
		var row := HBoxContainer.new()
		sidebar.add_child(row)
		_label(row,"购入幼体（0AP）×")
		var count := SpinBox.new()
		count.min_value = 1
		count.max_value = left
		count.value = 1
		count.custom_minimum_size.x = 74
		row.add_child(count)
		var buy_quote := func(): return husbandry.quote_purchase(uid,int(count.value))
		_icon(row,"buy","按所选数量购入幼体",func():
			var quote_buy: Dictionary = buy_quote.call()
			if quote_buy["ok"]:
				_confirm("购入%s×%d，花费%d元石？购入即占用容量，不可退回。" % [species["name"],int(quote_buy["count"]),int(quote_buy["total"])],
					func(): _result(husbandry.purchase(uid,int(quote_buy["count"]))); _show_cell())
			else: _result(quote_buy))
		_label(row,"1只=%d元石" % int(species["juvenile_price"]))
	else:
		_label(sidebar,"容量已满%d/%d；成长不释放空位。" % [counts["total"],int(definition["capacity"])])
	if counts["total"] > 0:
		var abandon := husbandry.abandon_quote(uid)
		if int(abandon["pending"]) > 0 or int(abandon["running"]) > 0:
			_label(sidebar,"清退将放弃：待收产物%s、在制周期投入%s" % [_materials(abandon["outputs"]) if not abandon["outputs"].is_empty() else "无",
				_materials(abandon["inputs"]) if not abandon["inputs"].is_empty() else "无"])
		var expand := _icon(sidebar,"inspect","展开/收起个体明细",func(): _habitat_expanded = not _habitat_expanded; _show_cell())
		expand.toggle_mode = true
		expand.button_pressed = _habitat_expanded
		if _habitat_expanded:
			var target := int(species["growth_days"])
			var cycle_days := int(species["cycle_days"])
			for individual in habitat["individuals"]:
				var service: Dictionary = individual["base_service"]
				var fed := "今日已喂·%s" % husbandry.diet_name(habitat["species_id"],"base_diets",String(service["diet_id"])) if int(service["day"]) == world.clock.total_days else "今日未喂"
				var cycle: Dictionary = individual.get("cycle",{})
				if cycle.is_empty():
					if individual["stage"] == "adult":
						_label(sidebar,"#%d 成体空闲 · 下次整体维护可投特殊料 · %s" % [int(individual["uid"]),fed])
					else:
						_label(sidebar,"#%d 幼体 · 成长%d/%d有效日 · %s" % [int(individual["uid"]),int(int(individual["growth"])/100),target,fed])
				elif cycle["status"] == "ready":
					_label(sidebar,"#%d 待收 · %s（收取不受当日投喂/水体限制）" % [int(individual["uid"]),_materials(cycle["outputs"])])
				else:
					var remaining := int((int(cycle["goal"])-int(cycle["progress"]))/100)
					_label(sidebar,"#%d 周期%d/%d有效日 · 预计第%d日完成（连续正常维护时）· %s" % [int(individual["uid"]),int(int(cycle["progress"])/100),cycle_days,world.clock.total_days+remaining+1,fed])
	if counts["total"] > 0:
		_icon(sidebar,"fell","清退全部动物（1AP，不退款、不返饲料、不产物）",func():
			var give_up := husbandry.abandon_quote(uid)
			var detail := ""
			if int(give_up["pending"]) > 0: detail += "；放弃待收产物" + _materials(give_up["outputs"])
			if int(give_up["running"]) > 0: detail += "；放弃在制投入" + _materials(give_up["inputs"])
			_confirm("清退%s的全部%d只动物？不退款、不返饲料、不产物%s，消耗1AP。" % [definition["name"],counts["total"],detail],
				func(): _result(husbandry.cull(uid)); _show_cell()))
		_label(sidebar,"非空设施需先清退全部动物才能拆除。")
	else:
		_icon(sidebar,"clear","拆除（1AP，无返还）",func(): _result(world.demolish_facility(uid)); _show_cell())

func _show_resources() -> void:
	_context = "resources"
	_page("资源一览 · 每日净变化")
	var ledger := books()
	var controls := HBoxContainer.new()
	sidebar.add_child(controls)
	var mode := OptionButton.new()
	mode.add_item("当日实际")
	mode.add_item("最近7日均值")
	mode.select(resource_mode)
	mode.item_selected.connect(func(index): resource_mode = int(index); resource_day = -1; _show_resources())
	controls.add_child(mode)
	var days := OptionButton.new()
	var settled: Array = ledger.state["history"]
	var labels := ["今日（实时·未结算）"]
	labels.resize(1+mini(15,settled.size()))
	for index in range(settled.size()):
		labels[settled.size()-index] = "第%d日" % (int(settled[index]["day"])+1)
	days.add_item(labels[0])
	days.set_item_metadata(0,-1)
	for index in range(1,labels.size()):
		days.add_item(labels[index])
		days.set_item_metadata(days.item_count-1,int(settled[settled.size()-index]["day"]))
		if int(settled[settled.size()-index]["day"]) == resource_day: days.select(days.item_count-1)
	days.item_selected.connect(func(index): resource_day = int(days.get_item_metadata(index)); _show_resources())
	days.disabled = resource_mode != 0 or settled.is_empty()
	controls.add_child(days)
	var filter := OptionButton.new()
	filter.add_item("全部五行")
	filter.set_item_metadata(0,"全部")
	for element in ["wood","fire","earth","water","gold"]:
		filter.add_item(ELEMENTS[element])
		filter.set_item_metadata(filter.item_count-1,element)
		if resource_element == element: filter.select(filter.item_count-1)
	filter.item_selected.connect(func(index): resource_element = String(filter.get_item_metadata(index)); _show_resources())
	controls.add_child(filter)
	var search := LineEdit.new()
	search.placeholder_text = "搜索资源名称"
	search.text = resource_search
	search.custom_minimum_size.x = 130
	search.text_submitted.connect(func(value): resource_search = value; _show_resources())
	controls.add_child(search)
	_cash_card(resource_mode,resource_day)
	var view: Dictionary = ledger.day_view(resource_day) if resource_mode == 0 else ledger.average_view()
	if resource_mode == 1 and view["days"] == 0:
		_label(sidebar,"暂无已结算日；今日的实时数据见“当日实际”。")
		return
	_label(sidebar,"口径：%s · 净增长＝实际入库−实际出库；完成未领不计增长，领取当日才入账。" % String(view["label"]))
	var totals_in := {}
	var totals_out := {}
	var reasons: Dictionary = {}
	if resource_mode == 0:
		var inflows: Dictionary = view["inflows"]
		var outflows: Dictionary = view["outflows"]
		for item in inflows:
			var total := 0
			for reason in inflows[item]: total += int(inflows[item][reason])
			totals_in[item] = total
		for item in outflows:
			var total := 0
			for reason in outflows[item]: total += int(outflows[item][reason])
			totals_out[item] = total
		reasons = {"in": inflows, "out": outflows}
	else:
		totals_in = view["totals_in"]
		totals_out = view["totals_out"]
		reasons = {"in": view["inflows"], "out": view["outflows"]}
	var rows := []
	for item in world._items:
		var definition: Dictionary = world._items[item]
		if resource_element != "全部" and definition["element"] != resource_element: continue
		if not resource_search.is_empty() and not definition["name"].contains(resource_search): continue
		var inflow := 0.0
		var outflow := 0.0
		if totals_in.has(item): inflow = float(totals_in[item][0] if resource_mode == 1 else totals_in[item])
		if totals_out.has(item): outflow = float(totals_out[item][0] if resource_mode == 1 else totals_out[item])
		rows.append({"item": item, "name": String(definition["name"]), "in": inflow, "out": outflow, "net": inflow-outflow,
			"stock": world.inventory.count(item), "closing": int(view.get("closing",{}).get(item,world.inventory.count(item)))})
	rows.sort_custom(func(a,b): return absf(float(a["net"])) > absf(float(b["net"])) or (absf(float(a["net"])) == absf(float(b["net"])) and String(a["name"]) < String(b["name"])))
	var stock_caption := "当前库存" if resource_mode == 1 or resource_day < 0 else "该日期末"
	var balanced: Array = rows.filter(func(row): return float(row["net"]) >= 0.0)
	var negative: Array = rows.filter(func(row): return float(row["net"]) < 0.0)
	_resource_group("增长与平衡（净值≥0；0＝平衡）",balanced,stock_caption,resource_mode,reasons)
	_resource_group("负增长（净值<0，不一定等于缺料）",negative,stock_caption,resource_mode,reasons)
	_pending_card()

func _resource_group(title: String, rows: Array, stock_caption: String, mode_kind: int, reasons: Dictionary) -> void:
	_heading(sidebar,"%s · %d种" % [title,rows.size()])
	var header := GridContainer.new()
	header.columns = 5
	sidebar.add_child(header)
	for cell in ["资源",stock_caption,"入库","出库","净变化"]:
		var label := _label(header,cell)
		label.add_theme_font_size_override("font_size",15)
	for row in rows:
		var line := GridContainer.new()
		line.columns = 5
		sidebar.add_child(line)
		var name_label := _label(line,String(row["name"]))
		name_label.mouse_filter = Control.MOUSE_FILTER_STOP
		name_label.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				resource_focus = "" if resource_focus == String(row["item"]) else String(row["item"])
				_show_resources())
		var stock_value := int(row["closing"]) if mode_kind == 0 and resource_day >= 0 else int(row["stock"])
		_label(line,str(stock_value))
		_label(line,_flow_text(float(row["in"]),mode_kind))
		_label(line,_flow_text(float(row["out"]),mode_kind))
		var net := float(row["net"])
		var net_label := _label(line,"平衡" if net == 0.0 else _net_text(net,mode_kind))
		net_label.add_theme_color_override("font_color",UI.PAPER if net >= 0.0 else UI.ERROR)
		if resource_focus == String(row["item"]):
			var detail := _card(sidebar)
			_label(detail,"明细："+String(row["name"]))
			_flow_reasons(detail,"入库来源",reasons["in"].get(String(row["item"]),{}))
			_flow_reasons(detail,"出库去向",reasons["out"].get(String(row["item"]),{}))

func _flow_reasons(parent: Node, title: String, flows: Dictionary) -> void:
	if flows.is_empty():
		_label(parent,title+"：无")
		return
	var parts := PackedStringArray()
	for reason in flows: parts.append("%s×%d" % [reason,int(flows[reason])])
	_label(parent,title+"："+"、".join(parts))

func _flow_text(value: float, mode_kind: int) -> String:
	if mode_kind == 0: return str(int(value))
	return _decimal(value)

func _net_text(value: float, mode_kind: int) -> String:
	if mode_kind == 0: return "%s%d" % ["+" if value > 0 else "",int(value)]
	if value > -0.01 and value < 0.0: return "−<0.01/日"
	return "%s%s/日" % ["+" if value > 0 else "−",_decimal(absf(value))]

func _decimal(value: float) -> String:
	if is_equal_approx(value,roundf(value)): return str(int(roundf(value)))
	return "%.2f" % value

func _cash_card(mode_kind: int, day: int) -> void:
	var card := _card(sidebar)
	_heading(card,"元石（真实收入/支出，单列）")
	if mode_kind == 1:
		var settled: Array = world.ledger.state["history"]
		var sample: Array = settled.slice(maxi(0,settled.size()-7))
		var income := 0
		var expense := 0
		var index := 0
		for row in sample:
			var totals: Dictionary = _cash_bucket(world.journal,int(row["day"]))
			income += int(totals["income"])
			expense += int(totals["expense"])
			index += 1
		if index == 0:
			_label(card,"暂无已结算日")
		else:
			_label(card,"最近%d日：收入%d · 支出%d · 净额%s%d/日" % [index,income,expense,"+" if income-expense >= 0 else "",int((income-expense)/index)])
		return
	var totals := _cash_bucket(world.journal,day)
	var caption := "今日（实时）" if day < 0 else "第%d日" % (day+1)
	_label(card,"%s：收入%d · 支出%d · 净额%s%d" % [caption,int(totals["income"]),int(totals["expense"]),"+" if totals["income"]-totals["expense"] >= 0 else "",int(totals["income"])-int(totals["expense"])])

func _cash_bucket(journal: Dictionary, day: int) -> Dictionary:
	if day < 0:
		return {"income": Journal.income(journal["pending"]), "expense": Journal.expense(journal["pending"])}
	for row in journal["history"]:
		if int(row["day"]) == day:
			return {"income": Journal.income(row["totals"]), "expense": Journal.expense(row["totals"])}
	return {"income": 0, "expense": 0}

func _pending_card() -> void:
	var pending := {}
	for facility in world.facilities.values():
		var batch: Dictionary = facility["batch"]
		if not batch.is_empty() and batch["status"] == "ready":
			for item in batch["outputs"]:
				pending[item] = int(pending.get(item,0)) + int(batch["outputs"][item])
	var mature := {}
	for crop in world.crops.values():
		if crop["state"] != "mature": continue
		var outputs: Dictionary = world.crop_defs[crop["crop_id"]]["outputs"]
		for item in outputs:
			mature[item] = int(mature.get(item,0)) + int(outputs[item])
	if pending.is_empty() and mature.is_empty(): return
	var card := _card(sidebar)
	_heading(card,"待领取（不加入净额，领取当日才入账）")
	if not pending.is_empty(): _label(card,"完成批次待收："+_materials(pending))
	if not mature.is_empty(): _label(card,"成熟作物待采："+_materials(mature))

func _preview(directory: String) -> void:
	await _prepare_preview(directory)
	await _shot(directory,"slots")
	_new(1,false)
	world.buy("grass_seed",4)
	world.workforce.set_seed(Vector2i(2,2),"pasture_grass")
	world.till(Vector2i(2,2))
	world.plant(Vector2i(2,2),"pasture_grass")
	selected = Vector2i(2,2)
	_show_cell()
	expanded = true
	_select_tool("irrigate")
	_hover = selected
	_update_hover()
	_layout()
	_fit_map()
	await _shot(directory,"manual")
	_set_manual(false)
	_select_tool("till")
	_drag = true
	_drag_start = Vector2i(3,2)
	_drag_end = Vector2i(7,4)
	_hover = _drag_end
	_update_hover()
	await _shot(directory,"delegated")
	_set_manual(true)
	# Screenshot fixture only. The separate startup ledger never injects materials.
	(world as V2World).grant_scaffold({"raw_wood":6,"raw_stone":10,"fodder_grass":4,"clean_water":8,"algae_feed":4})
	world.build_facility(Vector2i(0,14),"fish_pond")
	world.build_facility(Vector2i(7,1),"pen")
	selected = Vector2i(0,14)
	_show_cell()
	await _shot(directory,"reservoir")
	_show_build()
	await _shot(directory,"construction")
	world.primeval_stones += 40
	hus().purchase(2,2)
	hus().purchase(1,2)
	world.inventory.add("fodder_grass",4)
	world.inventory.add("clean_water",8)
	hus().maintain(2)
	hus().maintain_water(1)
	world.inventory.add("algae_feed",4)
	hus().maintain(1)
	selected = Vector2i(7,1)
	_show_cell()
	await _shot(directory,"habitat_pen")
	selected = Vector2i(0,14)
	_show_cell()
	await _shot(directory,"habitat_pond")
	# Screenshot fixture only: force adulthood, start real cycles and advance days.
	var fixture_pen: Dictionary = (world as V2World).husbandry.habitat_of(2)
	for individual in fixture_pen["individuals"]:
		individual["stage"] = "adult"
		individual["growth"] = 600
	var fixture_pond: Dictionary = (world as V2World).husbandry.habitat_of(1)
	for individual in fixture_pond["individuals"]:
		individual["stage"] = "adult"
		individual["growth"] = 400
	(world as V2World).grant_scaffold({"iron_ore":2,"grain":4,"fodder_grass":4,"clean_water":8,"algae_feed":4})
	hus().maintain(2)
	hus().maintain(1)
	world.end_day()
	world.end_day()
	_habitat_expanded = true
	selected = Vector2i(7,1)
	_show_cell()
	await _shot(directory,"production_sheep")
	selected = Vector2i(0,14)
	_show_cell()
	await _shot(directory,"production_carp")
	_show_resources()
	await _shot(directory,"resources")
	var preview_directory: String = store.slot_path(1).get_base_dir()
	store.delete_slot(1,true)
	DirAccess.remove_absolute(preview_directory)
	get_tree().quit()
