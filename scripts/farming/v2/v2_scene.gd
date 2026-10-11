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
var resource_watched_only := false
var overview_filter := "全部"
var overview_search := ""
var watch_panel: PanelContainer
var watch_body: VBoxContainer
var _watch_limit := 0

func _init() -> void:
	store = V2Store.new()
	manual_mode = true
	minimum_map_zoom = 0.1
	settings = Settings.new("user://farm_demo_v2_settings.cfg", minimum_map_zoom)
	product_title = "灵田 Demo V2"
	terrain_path = "res://content/farming/baked/v2/terrains.json"
	preview_prefix = "v2"
func _make_store(directory: String = ""):
	return V2Store.new() if directory.is_empty() else V2Store.new(directory)
func _make_world(slot_store):
	return V2World.new(slot_store)

func _effective_ui_scale() -> float:
	# Preserve the requested setting, but keep the minimum supported window usable.
	var viewport_size := get_viewport().get_visible_rect().size
	return minf(_ui_scale,minf(viewport_size.x/960.0,viewport_size.y/540.0))

func _refresh_input() -> void:
	super._refresh_input()
	if watch_panel != null: watch_panel.visible = _started and not shade.visible

func _refresh() -> void:
	super._refresh()
	_refresh_watch()
	_layout_extra()

func _extra_nav() -> void:
	_icon(top_nav,"pen","养殖总览 · 各设施状态与定位",_show_husbandry_overview)
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

## Main-UI watch strip: per-slot preference, empty by default with a purpose note.
func _extra_hud() -> void:
	watch_panel = PanelContainer.new()
	ui_root.add_child(watch_panel)
	watch_body = VBoxContainer.new()
	watch_panel.add_child(watch_body)
	_refresh_watch()

func _layout_extra() -> void:
	if watch_panel == null: return
	if _watch_limit != _watch_visible_count(): _refresh_watch()
	watch_panel.reset_size()
	var margin := 24.0 if ui_root.size.x >= 1600 else 12.0
	watch_panel.position = Vector2(margin+8,124)
	var available := side_panel.position.x-watch_panel.position.x-12 if side_panel.visible else board.size.x-16
	watch_panel.size = Vector2(minf(320 if ui_root.size.x < 1100 else 560,available),0)

func _watch_visible_count() -> int:
	return 2 if ui_root.size.x < 1100 or ui_root.size.y < 650 else (3 if ui_root.size.x < 1400 else 5)

func _refresh_watch() -> void:
	if watch_body == null: return
	_watch_limit = _watch_visible_count()
	for child in watch_body.get_children():
		watch_body.remove_child(child)
		child.queue_free()
	var watched: Array = (world as V2World).preferences["watched"]
	var today: Dictionary = books().day_view(-1)
	var totals_in := {}
	var totals_out := {}
	for item in today.get("inflows",{}):
		var total := 0
		for reason in today["inflows"][item]: total += int(today["inflows"][item][reason])
		totals_in[item] = total
	for item in today.get("outflows",{}):
		var total := 0
		for reason in today["outflows"][item]: total += int(today["outflows"][item][reason])
		totals_out[item] = total
	if watched.is_empty():
		var row := HBoxContainer.new()
		watch_body.add_child(row)
		_label(row,"关注资源：在资源一览中勾选材料，查看库存和今日净增长。")
		_icon(row,"locate","选择关注资源 · 打开资源一览",func(): resource_watched_only = false; _show_resources())
		return
	var visible_count := _watch_limit
	var shown := 0
	for item in watched:
		if shown >= visible_count: break
		shown += 1
		var line := HBoxContainer.new()
		watch_body.add_child(line)
		_picture(line,item,22)
		var net := int(totals_in.get(item,0)) - int(totals_out.get(item,0))
		_label(line,"%s %d · 今日%s%d" % [world._items[item]["name"],world.inventory.count(item),"+" if net > 0 else "",net] if net != 0 else "%s %d · 今日平衡" % [world._items[item]["name"],world.inventory.count(item)])
		line.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				resource_mode = 0
				resource_day = -1
				resource_watched_only = false
				resource_element = "全部"
				resource_search = ""
				resource_focus = String(item)
				_show_resources())
	if watched.size() > visible_count:
		var more := _button(watch_body,"更多(%d)" % (watched.size()-visible_count),func(): resource_watched_only = true; resource_element = "全部"; resource_search = ""; resource_focus = ""; _show_resources())
		more.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


const CATEGORY_NAMES := {"purchase": "购入", "maintenance": "维护", "growth": "成长/生产", "claim": "收取", "pause": "暂停", "cull": "清退", "labour": "人工"}

func _entry_text(entry: Dictionary) -> String:
	var name := "设施#%d" % int(entry.get("facility_uid", 0))
	for facility in world.facilities.values():
		if int(facility["uid"]) == int(entry.get("facility_uid", -1)):
			name = world.facility_defs[facility["facility_id"]]["name"] + "#%d" % int(facility["uid"])
	var counts := ""
	if int(entry.get("count", 0)) > 0: counts += "%d次/只" % int(entry["count"])
	if not entry.get("items", {}).is_empty(): counts += " " + _materials(entry["items"])
	var note := String(entry.get("note", ""))
	if not note.is_empty(): counts += " · " + note
	return "[%s] %s · %s%s" % [CATEGORY_NAMES.get(String(entry["category"]), String(entry["category"])), name, String(entry.get("kind", "")), ("：" + counts) if not counts.is_empty() else ""]

## Up to two husbandry highlights for the daily digest, newest first.
func _digest_husbandry(day: int) -> Array:
	var out := []
	var reports = (world as V2World).reports
	for entry in reports.day_entries(day):
		if String(entry["category"]) in ["claim", "pause", "cull"]:
			out.append("[养殖] " + _entry_text(entry))
	return out.slice(0, 2)

func _report_page_extra() -> void:
	var reports = (world as V2World).reports
	var day := int(world.workforce.state["report"]["day"])
	var entries: Array = reports.day_entries(day)
	if entries.is_empty(): return
	_heading(sidebar,"养殖条目 · 第%d天" % (day + 1))
	for entry in entries:
		_label(sidebar,_entry_text(entry))

func _history_day_extra(day: int) -> Array:
	var out := []
	var reports = (world as V2World).reports
	# Journal history stamps the new day; reports archive the completed service day.
	for entry in reports.day_entries(day - 1):
		out.append("[养殖] " + _entry_text(entry))
	return out

func _recap_extra(term_index: int) -> void:
	var reports = (world as V2World).reports
	if not reports.recap_active():
		_label(sidebar,"养殖统计自P7.e起记录；本档未到45天或缺少养殖数据。")
		return
	var source: Dictionary = reports.recap_totals() if term_index < 0 else reports.state["recap"]["terms"][term_index]
	var card := _card(sidebar)
	_heading(card,"养殖 · %s" % ("45天总计" if term_index < 0 else "第%d时节小计" % (term_index + 1)))
	for category in ["purchase", "maintenance", "growth", "claim", "pause", "cull", "labour"]:
		var bucket: Dictionary = source[category]
		if bucket.is_empty(): continue
		var parts := PackedStringArray()
		for key in bucket:
			if key == "count": continue
			var caption := String(world._items[key]["name"]) if world._items.has(key) else String(hus().species_def(key)["name"]) if hus().species_defs.has(key) else String(key)
			parts.append("%s %d" % [caption, int(bucket[key])])
		if parts.is_empty(): parts.append("合计%d" % int(bucket.get("count", 0)))
		_label(card,"%s：%s" % [CATEGORY_NAMES[category], "、".join(parts)])
	var recap: Dictionary = reports.state["recap"]
	var animal_parts := PackedStringArray()
	for species in recap["animals"]:
		animal_parts.append("%s 幼%d/成%d" % [hus().species_def(species)["name"], int(recap["animals"][species]["juvenile"]), int(recap["animals"][species]["adult"])])
	_label(card,"期末：元石%d · 人工累计%d · 待收周期%d · 在制%d\n在养：%s" % [int(recap["cash"]), int(recap["labour"]), int(recap["ready"]), int(recap["running"]), "、".join(animal_parts) if not animal_parts.is_empty() else "无"])
	_label(card,"期末仓库与在养个体为冻结快照，不按后续经营重算；未收权益不是可出售库存。")

func _help_extra() -> void:
	_heading(sidebar,"养殖与负责人")
	_label(sidebar,"圈舍/水场2×2、同种容量4：购入幼体→每日整体维护→成体投特殊料→剪毛保留/出塘移除；缺料或缺水只暂停，补齐恢复。")
	_label(sidebar,"粪肥经堆肥箱回田；负责人一人一设施、日结巡栏（收取→必要修水→整体维护），成功一次1元石，人数不设上限。")
	_label(sidebar,"资源一览按实际收支记账，完成未领不计增长；勾选“关注”后主界面显示库存与今日净变化。")

func _worker_cap_text() -> String:
	return "雇工 · 人数不设固定上限"

func _worker_limit() -> int:
	return 999999

func _is_caretaker(worker: Dictionary) -> bool:
	return int(worker.get("caretaker_facility", 0)) > 0

func _worker_duty_text(worker: Dictionary) -> String:
	if not _is_caretaker(worker):
		return ""
	var facility_uid := int(worker["caretaker_facility"])
	if not world.facilities.has(facility_uid):
		return "专责设施已拆除，待重新指派"
	var facility: Dictionary = world.facilities[facility_uid]
	return "专责%s#%d，其他农务不参与" % [world.facility_defs[facility["facility_id"]]["name"], facility_uid]

func _worker_report_extra(report: Dictionary) -> String:
	if not report.has("caretaker"):
		return ""
	var steps: Dictionary = report["caretaker"]["steps"]
	var parts := PackedStringArray()
	for step in ["收取", "水体维护", "整体维护"]:
		if int(steps[step]) > 0: parts.append("%s×%d" % [step,int(steps[step])])
	if parts.is_empty(): return "专责巡栏：无待办"
	var skipped: Array = report["caretaker"]["skipped"]
	return "专责巡栏："+"、".join(parts)+("；未完成："+"、".join(skipped) if not skipped.is_empty() else "")

## Caretaker slot below the three husbandry columns: management state only.
func _caretaker_section(habitat: Dictionary) -> void:
	var husbandry := hus()
	var uid := int(habitat["facility_uid"])
	var current: Dictionary = husbandry.caretaker_of(uid)
	_label(sidebar,"负责人 · 一人一设施，不参与其他农务")
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.add_item("无人负责（玩家手动）")
	selector.set_item_metadata(0, 0)
	if current.is_empty(): selector.select(0)
	var index := 1
	for worker in world.workforce.state["workers"]:
		var bound := int(worker.get("caretaker_facility", 0))
		var caption: String = worker["name"]
		if bound == uid: caption += " · 当前负责"
		elif bound > 0: caption += " · 现负责其他设施"
		elif not worker["areas"].is_empty() or not _worker_sources(int(worker["id"])).is_empty(): caption += " · 现负责农务"
		selector.add_item(caption)
		selector.set_item_metadata(index, int(worker["id"]))
		if bound == uid: selector.select(index)
		index += 1
	selector.item_selected.connect(func(choice):
		var worker_id := int(selector.get_item_metadata(choice))
		var preview: Dictionary = husbandry.caretaker_preview(uid, worker_id)
		if not preview["ok"]:
			_result(preview)
			return
		if worker_id == 0:
			_result(husbandry.assign_caretaker(uid, 0))
			_show_cell()
			return
		var changes := PackedStringArray()
		if int(preview["releases"]["areas"]) > 0: changes.append("解除其%d处负责区域" % int(preview["releases"]["areas"]))
		if not preview["releases"]["sources"].is_empty(): changes.append("解除其资源点指派")
		if not String(preview["displaced"]).is_empty(): changes.append("改派原负责人%s为待分配" % String(preview["displaced"]))
		if preview["moving"].has("from_facility"): changes.append("从设施#%d改派" % int(preview["moving"]["from_facility"]))
		var detail := "；".join(changes) if not changes.is_empty() else "无原安排需要解除"
		_confirm("指派%s负责本设施？%s。指派本身0AP、0元石，首次工作在日结执行。" % [world.workforce._worker(worker_id)["name"], detail],
			func(): _result(husbandry.assign_caretaker(uid, worker_id)); _show_cell()))
	sidebar.add_child(selector)
	if not current.is_empty():
		var estimate := husbandry.patrol_estimate(uid)
		_label(sidebar,"%s · %s · 每日预算%d元石（最多支出）
成功一次收费1元石，无固定日薪；%s" % [current["name"],
			"暂停中，不工作不收费" if current["paused"] else "受雇中", int(current["budget"]), estimate])

func _worker_sources(worker_id: int) -> Array:
	var out := []
	for source in world.workforce.state["sources"]:
		if int(world.workforce.state["sources"][source]) == worker_id:
			out.append(source)
	return out

## Water panel line; derived products reword it when the action changes meaning.
func _water_action_text(quote: Dictionary) -> String:
	return "维护：%s → +40（1AP）· %s" % [_materials(quote["inputs"]) if quote["ok"] else "清水×2",String(quote["reason"]) if not quote["ok"] else "可执行"]

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
	_caretaker_section(habitat)
	var claim_quote := husbandry.quote_claim(uid)
	if claim_quote["ok"]:
		_label(sidebar,"待收%d只：%s%s" % [int(claim_quote["ready"]),_materials(claim_quote["outputs"]),
			" · 出塘移除成体，不能回退" if int(claim_quote["removes"]) > 0 else " · 剪毛保留成体"])
		var claim_button := _icon(sidebar,"claim","收取（1AP）",func(): _result(husbandry.claim(uid)); _show_cell())
		claim_button.disabled = false
	if habitat["default_notice"]:
		_label(sidebar,"新建设施已采用默认配置：%s、%s、%s；可在下方调整，选择食谱本身不扣料。" % [species["name"],
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
			_label(sidebar,_water_action_text(water_quote))
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

## One row per habitat facility, by stable UID; read-only, 0AP locate.
func _show_husbandry_overview() -> void:
	_context = "overview"
	_page("养殖总览")
	var husbandry := hus()
	var habitats := []
	for facility in world.facilities.values():
		if world.facility_defs[facility["facility_id"]].get("kind") != "habitat": continue
		habitats.append(facility)
	var totals := {"juvenile": 0, "adult": 0, "ready": 0}
	for facility in habitats:
		var habitat: Dictionary = husbandry.habitat_of(int(facility["uid"]))
		if habitat.is_empty(): continue
		var counts := husbandry.summary(habitat)
		totals["juvenile"] += int(counts["juvenile"])
		totals["adult"] += int(counts["adult"])
		totals["ready"] += int(counts["ready"])
	_label(sidebar,"设施%d座 · 幼体%d / 成体%d · 待收%d只（羊只与鱼尾分列，不合并件数）" % [habitats.size(),totals["juvenile"],totals["adult"],totals["ready"]])
	var controls := HBoxContainer.new()
	sidebar.add_child(controls)
	var filter := OptionButton.new()
	for option in ["全部","圈舍","水场","待收","需处理"]:
		filter.add_item(option)
		if option == overview_filter: filter.select(filter.item_count-1)
	filter.item_selected.connect(func(index): overview_filter = filter.get_item_text(index); _show_husbandry_overview())
	controls.add_child(filter)
	var search := LineEdit.new()
	search.placeholder_text = "搜索名称或UID"
	search.text = overview_search
	search.custom_minimum_size.x = 130
	search.text_submitted.connect(func(value): overview_search = value; _show_husbandry_overview())
	controls.add_child(search)
	if habitats.is_empty():
		_label(sidebar,"建造圈舍或水场后，可在这里查看养殖和维护情况。")
		_icon(sidebar,"build","打开建设目录",_show_build)
		return
	var matched := false
	for facility in habitats:
		var uid := int(facility["uid"])
		var habitat: Dictionary = husbandry.habitat_of(uid)
		var summary: Dictionary = husbandry.summary(habitat)
		var definition: Dictionary = world.facility_defs[facility["facility_id"]]
		var is_pond: bool = definition.get("terrain") == "water"
		if overview_filter == "圈舍" and is_pond: continue
		if overview_filter == "水场" and not is_pond: continue
		if overview_filter == "待收" and int(summary["ready"]) == 0: continue
		if overview_filter == "需处理" and not _needs_attention(uid): continue
		if not overview_search.is_empty():
			var text := "%s#%d (%d,%d)" % [definition["name"],uid,int(facility["origin"][0]),int(facility["origin"][1])]
			if not text.contains(overview_search) and not String(habitat["species_id"]).contains(overview_search): continue
		matched = true
		var card := _card(sidebar)
		var row := HBoxContainer.new()
		card.add_child(row)
		_picture(row,facility["facility_id"],36)
		_heading(row,"%s#%d（%d,%d）" % [definition["name"],uid,int(facility["origin"][0]),int(facility["origin"][1])])
		_icon(row,"locate","定位并打开设施详情",func(): _locate_facility(uid))
		_label(card,"在养：%s %d/%d · 幼体%d / 成体%d（待收%d为成体子集）" % [husbandry.species_def(habitat["species_id"])["name"],
			int(summary["total"]),int(definition["capacity"]),int(summary["juvenile"]),int(summary["adult"]),int(summary["ready"])])
		var quote: Dictionary = husbandry.quote_maintenance(uid)
		var served_line := "今日已喂%d/%d" % [int(summary["fed_today"]),int(summary["total"])]
		if int(summary["total"]) == 0:
			served_line = "空场 · 购入幼体后开始养育"
		elif quote["ok"]:
			served_line += " · 本次可执行：基础%d" % int(quote["basic"]["targets"])
			if int(quote["special"]["targets"]) > 0: served_line += "＋特殊%d" % int(quote["special"]["targets"])
		else:
			served_line += " · " + String(quote["reason"])
		_label(card,served_line)
		var production := "生产：空闲%d / 周期%d / 待收%d" % [int(summary["idle_adults"]),int(summary["running"]),int(summary["ready"])]
		if not habitat["production_enabled"]: production += " · 计划：暂不生产（已有周期继续）"
		_label(card,production)
		if habitat.has("water"):
			var support := husbandry.water_support_days(habitat)
			_label(card,"水体：%d/100 · 日结后预计%d · %s" % [int(habitat["water"]),maxi(0,int(habitat["water"])-5),"还可支持%d次日结" % support if support > 0 else "已达暂停线"])
		var caretaker: Dictionary = husbandry.caretaker_of(uid)
		if caretaker.is_empty():
			_label(card,"负责人：无人 · 手动维护；可在设施详情中指派。")
		else:
			_label(card,"负责人：%s · %s · 每日预算%d元石（最多支出）\n%s" % [caretaker["name"],"暂停中" if caretaker["paused"] else "专责本设施",int(caretaker["budget"]),husbandry.patrol_estimate(uid)])
		for line in _attention_lines(uid):
			_label(card,line)
	if not matched:
		_label(sidebar,"没有符合筛选的设施；可清除筛选后查看全部。")
		_button(sidebar,"清除筛选",func(): overview_filter = "全部"; overview_search = ""; _show_husbandry_overview())

## Explainable attention set: blocked quotes, low water, stalled caretakers.
func _needs_attention(facility_uid: int) -> bool:
	return not _attention_lines(facility_uid).is_empty()

func _attention_lines(facility_uid: int) -> Array:
	var husbandry := hus()
	var lines := []
	var habitat: Dictionary = husbandry.habitat_of(facility_uid)
	if habitat.is_empty() or habitat["individuals"].is_empty():
		return lines
	var quote: Dictionary = husbandry.quote_maintenance(facility_uid)
	if not quote["ok"] and String(quote.get("reason","")) != "全部个体今日已服务":
		lines.append("需处理：" + String(quote["reason"]))
	if habitat.has("water") and int(habitat["water"]) <= int(husbandry.settings["water"]["pause_threshold"]):
		lines.append("需处理：水体已达暂停线，先维护水体。")
	var caretaker: Dictionary = husbandry.caretaker_of(facility_uid)
	if not caretaker.is_empty() and caretaker["paused"]:
		var summary: Dictionary = husbandry.summary(habitat)
		if int(summary["fed_today"]) < int(summary["total"]):
			lines.append("需处理：负责人暂停且今日未喂，可手动维护。")
	return lines

## Locate closes the window, centres the full 2x2 footprint and opens the detail;
## a stale UID never selects a facility built later on the same spot.
func _locate_facility(facility_uid: int) -> void:
	for facility in world.facilities.values():
		if int(facility["uid"]) != facility_uid: continue
		_close_page()
		var origin: Array = facility["origin"]
		var footprint: Array = world.facility_defs[facility["facility_id"]]["footprint"]
		camera.position = (Vector2(float(origin[0]),float(origin[1]))+Vector2(float(footprint[0]),float(footprint[1]))*0.5)*64.0
		selected = Vector2i(int(origin[0]),int(origin[1]))
		_show_cell()
		return
	notice.text = "该设施已不存在"
	notice.add_theme_color_override("font_color",UI.ERROR)

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
	filter.add_item("仅关注")
	filter.set_item_metadata(filter.item_count-1,"watched")
	if resource_watched_only: filter.select(filter.item_count-1)
	filter.item_selected.connect(func(index):
		var choice := String(filter.get_item_metadata(index))
		if choice == "watched":
			resource_watched_only = true
			resource_element = "全部"
		else:
			resource_watched_only = false
			resource_element = choice
		_show_resources())
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
	_label(sidebar,"勾选“关注”后，所选材料显示在主界面关注条；仅由玩家勾选。")
	var rows := []
	for item in world._items:
		var definition: Dictionary = world._items[item]
		if resource_watched_only and not String(item) in (world as V2World).preferences["watched"]: continue
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
	header.columns = 6
	sidebar.add_child(header)
	for cell in ["关注","资源",stock_caption,"入库","出库","净变化"]:
		var label := _label(header,cell)
		label.add_theme_font_size_override("font_size",15)
	for row in rows:
		var line := header
		var watch := CheckBox.new()
		watch.button_pressed = String(row["item"]) in (world as V2World).preferences["watched"]
		watch.tooltip_text = "关注后显示在主界面关注条"
		watch.toggled.connect(func(value): world.toggle_watch(String(row["item"])); _refresh_watch(); _show_resources())
		line.add_child(watch)
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
	for row in rows:
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
	(world as V2World).grant_scaffold({"fodder_grass":4,"clean_water":8,"algae_feed":4})
	hus().maintain(2)
	hus().maintain_water(1)
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
	world.workforce.hire("鱼倌")
	hus().assign_caretaker(1,1)
	_show_workers()
	await _shot(directory,"caretaker")
	selected = Vector2i(0,14)
	_show_cell()
	await _shot(directory,"caretaker_pond")
	world.end_day()
	_show_report()
	await _shot(directory,"caretaker_report")
	_show_husbandry_overview()
	await _shot(directory,"overview")
	_close_page()
	world.toggle_watch("fodder_grass")
	world.toggle_watch("clean_water")
	_refresh_watch()
	await _shot(directory,"watch_strip")
	_show_resources()
	await _shot(directory,"resources")
	var preview_directory: String = store.slot_path(1).get_base_dir()
	store.delete_slot(1,true)
	DirAccess.remove_absolute(preview_directory)
	get_tree().quit()
