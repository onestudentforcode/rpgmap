extends "res://scripts/farming/v2/v2_scene.gd"
## P8 local demo: independent slots/settings, research-gated ecology production,
## shared facility owners, and the beginner handbook.
const P8World := preload("res://scripts/farming/p8/p8_world.gd")
const P8Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const Handbook := preload("res://scripts/farming/p8/p8_handbook.gd")
var _handbook_chapter := "start"

func _init() -> void:
	store = P8Store.new()
	manual_mode = true
	minimum_map_zoom = 0.1
	settings = Settings.new("user://farm_demo_p8_settings.cfg", minimum_map_zoom)
	product_title = "灵田 Demo P8 · 生态经营"
	terrain_path = "res://content/farming/baked/p8/terrains.json"
	preview_prefix = "p8"

func _make_store(directory: String = ""):
	return P8Store.new() if directory.is_empty() else P8Store.new(directory)

func _make_world(slot_store):
	return P8World.new(slot_store)

func _extra_nav() -> void:
	super()
	_icon(top_nav,"research_bench","研究 · 三层工艺网络",_show_research)

func _water_action_text(quote: Dictionary) -> String:
	if not quote["ok"]:
		return "换水：%s" % String(quote["reason"])
	return "换水：%s → 水体+%d、污水+%d（每场每日一次，1AP）" % [_materials(quote["inputs"]), int(quote["gain"]), int(quote.get("wastewater", 0))]

## Research-gated seeds/cultures stay visible but explicitly non-purchasable.
func _market_lock_text(item_id: String) -> String:
	if not world._items.has(item_id):
		return ""
	return world.research_block(String(world._items[item_id].get("research", "")))

## Build catalog keeps every registered facility visible; gated ones show the
## lock reason instead of a placement button.
func _show_build() -> void:
	_context = "build"
	_page("营建 · 加工设施")
	_label(sidebar,"选择设施，再到地图点击放置。建造消耗1AP，工具持续选中；右键取消。")
	var grid := GridContainer.new()
	grid.set_meta("layout","two")
	grid.columns = 2 if window_panel.size.x >= 740 else 1
	sidebar.add_child(grid)
	for ident in world.facility_defs:
		var definition: Dictionary = world.facility_defs[ident]
		var locked: String = world.research_block(String(definition.get("research", "")))
		var card := _card(grid)
		var row := HBoxContainer.new()
		card.add_child(row)
		_picture(row,ident,56)
		_heading(row,definition["name"])
		_label(card,"占地%d×%d · %d元石 · 1AP" % [definition["footprint"][0],definition["footprint"][1],definition["cash"]])
		_label(card,"材料："+_materials(definition["materials"]))
		if not locked.is_empty():
			_label(card,"未解锁：%s" % locked)
		else:
			_label(card,_missing(_substituted_preview(String(ident))))
			if definition["materials"].has("raw_stone"):
				var choice := OptionButton.new()
				choice.add_item("建材：原石")
				choice.add_item("建材：复合石板 1:1替石")
				choice.add_item("建材：再生填料 2:1替石")
				choice.set_item_metadata(0, "")
				choice.set_item_metadata(1, "panel")
				choice.set_item_metadata(2, "fill")
				choice.selected = 0
				choice.item_selected.connect(func(index): world.build_substitute = String(choice.get_item_metadata(index)); _show_build())
				card.add_child(choice)
			_icon(card,"build","放置 "+definition["name"],func():
				_close_page()
				_select_tool("inspect")
				build_tool = ident
				notice.text = "放置%s · 占地%d×%d，%d元石+%s · 右键取消" % [definition["name"],definition["footprint"][0],definition["footprint"][1],definition["cash"],_materials(definition["materials"])])

## Non-habitat panels: research benches explain the pending system, recipe cards
## carry an explicit lock line and stay unstartable while gated.
func _show_facility(facility: Dictionary) -> void:
	var definition: Dictionary = world.facility_defs[facility["facility_id"]]
	if definition.get("kind") == "research":
		_show_research_bench(facility)
		return
	if String(facility["facility_id"]) == "field_service_station" or String(facility["facility_id"]) == "growth_lamp":
		_show_device(facility)
		return
	if definition.get("kind") == "habitat":
		super(facility)
		return
	var uid := int(facility["uid"])
	var batch: Dictionary = facility["batch"]
	_picture(sidebar,facility["facility_id"],64)
	_heading(sidebar,definition["name"])
	if not batch.is_empty():
		_heading(sidebar,"待收取" if batch["status"] == "ready" else "加工中")
		_label(sidebar,RECIPES[batch["recipe_id"]])
		_label(sidebar,"产物："+_materials(batch["outputs"]))
		var days := int(world.recipe_defs[batch["recipe_id"]]["days"])
		var remaining := maxi(0,int(batch["finish_day"])-world.clock.total_days)
		_bar(sidebar,"加工进度",days-remaining,days)
		_label(sidebar,"剩余%d天 · 无需每日点击" % remaining)
		var claim := _icon(sidebar,"claim","收取（1AP）",func(): _result(world.claim_batch(uid,int(batch["batch_id"]))); _show_cell())
		claim.disabled = batch["status"] != "ready"
	else:
		_label(sidebar,"空闲 · 选择配方")
		for ident in world.recipe_defs:
			var recipe: Dictionary = world.recipe_defs[ident]
			if recipe["facility"] != facility["facility_id"]:
				continue
			var card := _card(sidebar)
			var locked: String = world.research_block(String(recipe.get("research", "")))
			_label(card,RECIPES[ident])
			_label(card,_materials(recipe["inputs"])+"\n↓\n"+_materials(recipe["outputs"]))
			if not locked.is_empty():
				_label(card,"未解锁：%s" % locked)
				continue
			_label(card,"%d天 · 启动/收取各1AP" % recipe["days"])
			_label(card,_missing(recipe["inputs"]))
			var start := _icon(card,"play","启动 "+RECIPES[ident],func(): _result(world.start_batch(uid,ident)); _show_cell())
			start.disabled = _missing(recipe["inputs"]) != "投入齐备" or world.clock.ap < 1
	_production_section(facility)
	_icon(sidebar,"clear","拆除（1AP，无返还）",func(): _confirm("拆除%s？不返还建设材料或元石，消耗1AP。" % definition["name"],func(): _result(world.demolish_facility(uid)); _show_cell()))

func _substituted_preview(facility_id: String) -> Dictionary:
	world.build_substitute = String(world.build_substitute)
	if world.build_substitute.is_empty():
		return world.facility_defs[facility_id]["materials"]
	var swap: Dictionary = world._substituted_materials(facility_id)
	return swap if not swap.is_empty() else world.facility_defs[facility_id]["materials"]

## P8 owns its handbook: legacy V2 caretaker/manual-only guidance is inapplicable.
func _show_help() -> void:
	_context = "help"
	_page("新手手册 · P8生态经营")
	_label(sidebar,"新档%d元石 · 每天%dAP · 首次45日回顾，之后自由经营。A/B是参考路线，不是限时目标。" % [int(world.config["initial_primeval_stones"]), int(world.config["ap_per_day"])])
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.set_meta("handbook_chapters", true)
	selector.tooltip_text = "选择手册章节；阅读和翻页不消耗AP或元石"
	for index in range(Handbook.CHAPTERS.size()):
		var entry: Dictionary = Handbook.CHAPTERS[index]
		selector.add_item(entry["title"])
		selector.set_item_metadata(index, entry["id"])
		if entry["id"] == _handbook_chapter: selector.select(index)
	selector.item_selected.connect(func(index):
		_handbook_chapter = String(selector.get_item_metadata(index))
		_show_help())
	sidebar.add_child(selector)
	var navigation := HBoxContainer.new()
	sidebar.add_child(navigation)
	_label(sidebar,"常用入口 · 悬停图标查看功能；开档后可直接进入对应页面。")
	for target in ["market", "build", "research", "workers", "resources", "orders"]:
		var captions := {"market": "市集", "build": "营建", "research": "研究", "workers": "雇工", "resources": "资源一览", "orders": "订单"}
		var icon_id: String = {"research": "research_bench", "resources": "locate"}.get(target, target)
		var button := _icon(navigation, icon_id, "打开" + captions[target], _handbook_open.bind(target))
		button.set_meta("handbook_target", target)
		button.disabled = not _started
	for card in Handbook.chapter(_handbook_chapter)["cards"]:
		var body := _card(sidebar)
		_heading(body, card["title"])
		for index in range(card["steps"].size()):
			_label(body,"%d. %s" % [index + 1, card["steps"][index]])
	if _started:
		var hints := HBoxContainer.new()
		sidebar.add_child(hints)
		_icon(hints,"cancel","跳过底栏操作提示",func(): _result(world.guide_dismiss(true)); _show_help())
		_icon(hints,"play","恢复底栏操作提示",func(): _result(world.guide_dismiss(false)); _show_help())

func _handbook_open(target: String) -> void:
	if not _started: return
	match target:
		"market": _show_market()
		"build": _show_build()
		"research": _show_research()
		"workers": _show_workers()
		"resources": _show_resources()
		"orders": _show_orders()

# --- P8.b ownership, production strategy and reserves -----------------------

const PRIORITY_NAMES := {"high": "高", "normal": "普通", "low": "低"}

func ops():
	return world.operations

## Shared owner block for habitat and processing panels: management state only.
func _owner_section(facility_uid: int) -> void:
	var binding: Dictionary = ops().binding_of(facility_uid)
	var owner := int(binding.get("owner", 0))
	_label(sidebar,"负责人 · 一人可负责多座设施，每设施一名（0AP、0元石）")
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.add_item("无人负责（玩家手动）")
	selector.set_item_metadata(0, 0)
	if owner == 0: selector.select(0)
	var index := 1
	for worker in world.workforce.state["workers"]:
		var caption: String = worker["name"]
		var owned: Array = ops().facilities_of(int(worker["id"]))
		if int(worker["id"]) == owner: caption += " · 当前负责"
		elif not owned.is_empty(): caption += " · 现负责%d座设施" % owned.size()
		if bool(worker.get("farm_duty", {}).get("enabled", false)): caption += " · 兼任农务"
		selector.add_item(caption)
		selector.set_item_metadata(index, int(worker["id"]))
		if int(worker["id"]) == owner: selector.select(index)
		index += 1
	selector.item_selected.connect(func(choice):
		var worker_id := int(selector.get_item_metadata(choice))
		if worker_id == owner: return
		_result(ops().assign_owner(facility_uid, worker_id))
		_show_cell())
	sidebar.add_child(selector)
	if owner > 0:
		var priority := String(binding.get("priority", "normal"))
		var row := HBoxContainer.new()
		sidebar.add_child(row)
		_label(row,"设施优先级（同级轮转，高级先安排）")
		for level in ["high", "normal", "low"]:
			var button := _button(row, PRIORITY_NAMES[level], func(): _result(ops().set_priority(facility_uid, level)); _show_cell())
			button.toggle_mode = true
			button.button_pressed = level == priority
		var waiting: int = ops().facility_waiting_days(facility_uid, world.clock.total_days)
		if waiting > 0:
			_label(sidebar,"已连续等待%d日未轮到执行（额度/预算被更高优先级占用）。" % waiting)
		_label(sidebar,"改派保留当日已服务与费用；不再清除该雇工的农务设置（兼任由其名册开关决定）。")

## Habitat panels keep the V2 layout but swap the caretaker block for the P8 one.
func _caretaker_section(habitat: Dictionary) -> void:
	_owner_section(int(habitat["facility_uid"]))
	var current: Dictionary = hus().caretaker_of(int(habitat["facility_uid"]))
	if not current.is_empty():
		_label(sidebar,"%s · 每日预算%d元石（最多支出）· 成功一次收费1元石，无固定日薪；%s" % [current["name"],
			int(current["budget"]), hus().patrol_estimate(int(habitat["facility_uid"]))])

## Processing panels add the owner block, the continuous production strategy
## and the farm-wide reserve editor.
func _production_section(facility: Dictionary, show_owner: bool = true) -> void:
	var uid := int(facility["uid"])
	if show_owner: _owner_section(uid)
	_heading(sidebar,"持续生产 · 默认关闭")
	var strategy: Dictionary = ops().strategy_of(uid)
	var enabled := CheckButton.new()
	enabled.text = "启用自动投料（达到目标停止新批，在制照常完成）"
	enabled.button_pressed = bool(strategy["enabled"])
	enabled.tooltip_text = "先选择配方、产物和数量，再点击保存策略"
	sidebar.add_child(enabled)
	var unlocked := []
	var recipe_options: Dictionary = ops().available_recipes(uid)
	for ident in recipe_options:
		var recipe: Dictionary = recipe_options[ident]
		if world.research_block(String(recipe.get("research", ""))).is_empty():
			unlocked.append(ident)
	unlocked.sort()
	if unlocked.is_empty():
		_label(sidebar,"该设施暂无已解锁配方，策略待后续研究开放。")
		return
	var recipe_row := HBoxContainer.new()
	sidebar.add_child(recipe_row)
	_label(recipe_row,"配方")
	var recipes := OptionButton.new()
	recipes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index in range(unlocked.size()):
		recipes.add_item(String(recipe_options[unlocked[index]].get("name", RECIPES.get(unlocked[index], unlocked[index]))))
		recipes.set_item_metadata(index, unlocked[index])
		if unlocked[index] == String(strategy["recipe_id"]): recipes.select(index)
	recipe_row.add_child(recipes)
	var target_row := HBoxContainer.new()
	sidebar.add_child(target_row)
	_label(target_row,"目标产物")
	var targets := OptionButton.new()
	targets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var refresh_targets := func(recipe_id: String, keep_item: String):
		targets.clear()
		var outputs: Dictionary = recipe_options[recipe_id]["outputs"]
		var list := outputs.keys()
		list.sort()
		for index in range(list.size()):
			targets.add_item("%s（现存有效%d）" % [world._items[list[index]]["name"], ops().effective_stock(String(list[index]))])
			targets.set_item_metadata(index, list[index])
			if list[index] == keep_item: targets.select(index)
	refresh_targets.call(String(strategy["recipe_id"]) if unlocked.has(String(strategy["recipe_id"])) else unlocked[0], String(strategy["target_item"]))
	target_row.add_child(targets)
	var quantity_row := HBoxContainer.new()
	sidebar.add_child(quantity_row)
	_label(quantity_row,"目标数量（含在制与待收）")
	var quantity := SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = 1000000
	quantity.value = maxi(1, int(strategy["target_qty"]))
	quantity.custom_minimum_size.x = 110
	quantity_row.add_child(quantity)
	var apply := _icon(sidebar,"play","保存策略（0AP，不立即投料）",func():
		var recipe_id := String(recipes.get_item_metadata(maxi(0, recipes.selected)))
		var target := String(targets.get_item_metadata(maxi(0, targets.selected)))
		_result(ops().set_production(uid, enabled.button_pressed, recipe_id, target, int(quantity.value)))
		_show_cell())
	apply.disabled = false
	recipes.item_selected.connect(func(index):
		refresh_targets.call(String(recipes.get_item_metadata(index)), "")
		targets.select(0))
	var blocked: String = ops().auto_start_block(uid)
	_label(sidebar,"自动投料状态：%s" % (blocked if not blocked.is_empty() else "条件满足时由负责人在日结启动"))
	_reserves_section()

## Farm-wide reserve editor: only automatic batch starts consult these numbers.
func _reserves_section() -> void:
	_heading(sidebar,"原料保留量 · 全农场（只挡自动投料，不锁仓库）")
	var reserves: Dictionary = ops().state["reserves"]
	var keys := reserves.keys()
	keys.sort()
	for item in keys:
		var row := HBoxContainer.new()
		sidebar.add_child(row)
		_label(row,"%s ≥ %d" % [world._items[item]["name"], int(reserves[item])])
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var remove := _icon(row,"cancel","清除保留",func(): _result(ops().set_reserve(String(item), 0)); _show_cell())
		remove.disabled = false
	var editor := HBoxContainer.new()
	sidebar.add_child(editor)
	_label(editor,"新增/调整")
	var items := world._items.keys()
	items.sort()
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index in range(items.size()):
		picker.add_item(world._items[items[index]]["name"])
		picker.set_item_metadata(index, items[index])
	editor.add_child(picker)
	var amount := SpinBox.new()
	amount.min_value = 1
	amount.max_value = 1000000
	amount.custom_minimum_size.x = 90
	editor.add_child(amount)
	_icon(editor,"area","设置保留量",func(): _result(ops().set_reserve(String(picker.get_item_metadata(maxi(0, picker.selected))), int(amount.value))); _show_cell())

func _worker_cap_text() -> String:
	return "雇工 · 一人可负责多设施，共享每日12次与预算"

## P8 always renders duty editing; ownership is summarized in the duty text.
func _is_caretaker(_worker: Dictionary) -> bool:
	return false

func _worker_duty_text(worker: Dictionary) -> String:
	var parts := PackedStringArray()
	var owned: Array = ops().facilities_of(int(worker["id"]))
	if not owned.is_empty():
		var names := PackedStringArray()
		for uid in owned:
			var binding: Dictionary = ops().binding_of(int(uid))
			names.append("设施#%d(%s)" % [int(uid), PRIORITY_NAMES.get(String(binding.get("priority", "normal")), "?")])
		parts.append("负责：" + "、".join(names))
	var duty: Dictionary = worker.get("farm_duty", {})
	if bool(duty.get("enabled", false)):
		parts.append("农务兼任：开（%s级）" % PRIORITY_NAMES.get(String(duty.get("priority", "normal")), "?"))
	else:
		parts.append("农务兼任：关")
	if worker["areas"].is_empty() and owned.is_empty():
		return ""
	return " · ".join(parts)

func _worker_report_extra(report: Dictionary) -> String:
	if not report.has("facilities") or report["facilities"].is_empty():
		return ""
	var lines := PackedStringArray()
	for entry in report["facilities"]:
		var steps: Dictionary = entry["steps"]
		var parts := PackedStringArray()
		for step in ["收取", "水体维护", "整体维护", "研究", "投料", "加工收取"]:
			if int(steps.get(step, 0)) > 0: parts.append("%s×%d" % [step, int(steps[step])])
		if parts.is_empty(): parts.append("无待办")
		var skipped: Array = entry["skipped"]
		lines.append("设施#%d：%s%s" % [int(entry["uid"]), "、".join(parts), ("；未完成：" + "、".join(skipped)) if not skipped.is_empty() else ""])
	return "\n".join(lines)

## Farm duty opt-in sits above the V1 duty matrix; settings survive toggling.
func _show_worker_duties(worker: Dictionary) -> void:
	_heading(sidebar,"农务兼任 · 默认关闭")
	var duty: Dictionary = worker.get("farm_duty", {"enabled": false, "priority": "normal"})
	var toggle := CheckButton.new()
	toggle.text = "启用农务兼任（与设施任务共享每日12次与预算）"
	toggle.button_pressed = bool(duty["enabled"])
	toggle.toggled.connect(func(value): _result(world.workforce.set_farm_duty(int(worker["id"]), value, String(duty["priority"]))); _show_workers())
	sidebar.add_child(toggle)
	var row := HBoxContainer.new()
	sidebar.add_child(row)
	_label(row,"兼任优先级")
	for level in ["high", "normal", "low"]:
		var button := _button(row, PRIORITY_NAMES[level], func(): _result(world.workforce.set_farm_duty(int(worker["id"]), bool(duty["enabled"]), level)); _show_workers())
		button.toggle_mode = true
		button.button_pressed = level == String(duty["priority"])
	_label(sidebar,"关闭兼任保留区域/类别/资源点设置，仅停止执行农务；不撤销全农场待办标记。")
	super(worker)


# --- P8.c research ----------------------------------------------------------

const RESEARCH_STATUS := {"locked": "锁定", "ready": "可启动", "active": "在研", "paused": "已暂停", "done": "已完成"}

func _project_status(project_id: String) -> String:
	if world.research.is_completed(project_id):
		return "done"
	var active: Dictionary = world.research.project_of(project_id)
	if not active.is_empty():
		return "paused" if bool(active["paused"]) else "active"
	var definition: Dictionary = world.research.project_def(project_id)
	for prerequisite in definition["prerequisites"]:
		if not world.research.is_completed(String(prerequisite)):
			return "locked"
	return "ready"

func _sample_route(item_id: String) -> String:
	var item: Dictionary = world._items[item_id]
	var parts := PackedStringArray()
	for source in item["sources"]:
		if source == "market":
			parts.append("市集采购")
		elif world.recipe_defs.has(source):
			parts.append("配方·%s（%s）" % [RECIPES[source], world.facility_defs[String(world.recipe_defs[source]["facility"])]["name"]])
		elif world.crop_defs.has(source):
			parts.append("种植·%s" % CROPS[source])
		elif world.source_defs.has(source):
			parts.append("资源点采集")
		elif world.husbandry.species_defs.has(source):
			parts.append("养殖·%s" % world.husbandry.species_def(source)["name"])
	return item["name"] + "：" + ("、".join(parts) if not parts.is_empty() else "暂无来源")

func _show_research_bench(facility: Dictionary) -> void:
	var uid := int(facility["uid"])
	var definition: Dictionary = world.facility_defs[facility["facility_id"]]
	_picture(sidebar,facility["facility_id"],64)
	_heading(sidebar,definition["name"])
	var active: Dictionary = world.research.active_project(uid)
	if active.is_empty():
		_label(sidebar,"空闲 · 选择项目并支付样本与启动费；启动本身0AP、不产生有效日。")
		var startable := []
		for project_id in world.research.project_defs():
			if _project_status(String(project_id)) == "ready" and world.research.project_of(String(project_id)).is_empty():
				startable.append(String(project_id))
		startable.sort()
		if startable.is_empty():
			_label(sidebar,"当前无可启动项目：先完成前置研究（见研究页）。")
		else:
			var selector := OptionButton.new()
			selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for index in range(startable.size()):
				var def: Dictionary = world.research.project_def(startable[index])
				selector.add_item("%s · %d元石＋%s · %d有效日" % [def["name"], int(def["fee"]), _materials(def["samples"]), int(def["days"])])
				selector.set_item_metadata(index, startable[index])
			sidebar.add_child(selector)
			_icon(sidebar,"play","启动所选研究",func():
				var project_id := String(selector.get_item_metadata(maxi(0, selector.selected)))
				var quote: Dictionary = world.research.quote_start(uid, project_id)
				if not quote["ok"]:
					_result({"ok": false, "reason": "；".join(PackedStringArray(quote["blockers"]))})
					return
				_confirm("启动%s？一次性支付%d元石并消耗样本%s；暂停不退款。" % [world.research.project_def(project_id)["name"], int(quote["fee"]), _materials(quote["samples"])],
					func(): _result(world.research.start(uid, project_id)); _show_cell()))
	else:
		var def: Dictionary = world.research.project_def(String(active["id"]))
		_heading(sidebar,"%s · %d/%d有效日" % [def["name"], int(active["progress"]), int(def["days"])])
		_bar(sidebar,"研究进度",int(active["progress"]),int(def["days"]))
		_label(sidebar,"样本与启动费已支付；每天一次研究工作：手动1AP，或由负责人日结执行（1元石）。")
		var work_quote: Dictionary = world.research.work_quote(uid)
		if work_quote["ok"]:
			_icon(sidebar,"play","手动研究（1AP，登记今日收据）",func(): _result(world.research.work(uid)); _show_cell())
		else:
			_label(sidebar,String(work_quote["reason"]))
		var pause := _icon(sidebar,"cancel","暂停/恢复（保留投入与进度）",func(): _result(world.research.set_paused(uid, not bool(active["paused"]))); _show_cell())
		pause.text = "恢复研究" if bool(active["paused"]) else "暂停研究"
	_owner_section(uid)
	if active.is_empty():
		_icon(sidebar,"clear","拆除（1AP，无返还）",func(): _confirm("拆除%s？不返还建设材料或元石，消耗1AP。" % definition["name"],func(): _result(world.demolish_facility(uid)); _show_cell()))
	else:
		_label(sidebar,"在研研究台不能拆除；完成或暂停处理后再操作。已完成的研究知识归全农场，拆除空台不丢失。")

func _show_research() -> void:
	_context = "research"
	_page("研究 · 三层工艺网络")
	_label(sidebar,"已完成的研究全场共享；启动付样本与元石，每天一次有效工作：手动1AP或负责人1元石。")
	var completed := 0
	for layer in [1, 2, 3]:
		_heading(sidebar,"第%d层" % layer)
		for project_id in world.research.project_defs():
			var def: Dictionary = world.research.project_defs()[project_id]
			if int(def["layer"]) != layer:
				continue
			if world.research.is_completed(String(project_id)):
				completed += 1
			var status := _project_status(String(project_id))
			var card := _card(sidebar)
			_heading(card,"%s · %s" % [def["name"], RESEARCH_STATUS[status]])
			if status == "active":
				var active: Dictionary = world.research.project_of(String(project_id))
				_label(card,"进度%d/%d有效日（研究台#%d%s）" % [int(active["progress"]), int(def["days"]), int(active["bench_uid"]), "，已暂停" if bool(active["paused"]) else ""])
			var prereqs := PackedStringArray()
			for prerequisite in def["prerequisites"]:
				var mark: String = "✓" if world.research.is_completed(String(prerequisite)) else "…"
				prereqs.append("%s%s" % [mark, String(world.research.project_def(String(prerequisite)).get("name", prerequisite))])
			_label(card,"前置：%s" % ("、".join(prereqs) if not prereqs.is_empty() else "无"))
			var samples := PackedStringArray()
			for item in def["samples"]:
				samples.append("%s %d/%d" % [world._items[String(item)]["name"], world.inventory.count(String(item)), int(def["samples"][item])])
			_label(card,"样本：%s · 启动%d元石 · %d有效日" % ["、".join(samples) if not samples.is_empty() else "无", int(def["fee"]), int(def["days"])])
			var unlocks := PackedStringArray()
			var registry: Dictionary = def["unlocks"]
			if not registry["facilities"].is_empty(): unlocks.append("设施%d座" % registry["facilities"].size())
			if not registry["recipes"].is_empty(): unlocks.append("配方%d条" % registry["recipes"].size())
			if not registry["purchases"].is_empty(): unlocks.append("采购%d项" % registry["purchases"].size())
			if not registry["crops"].is_empty(): unlocks.append("种植%d种" % registry["crops"].size())
			if not registry["species"].is_empty(): unlocks.append("物种%d种" % registry["species"].size())
			if not registry["diets"].is_empty(): unlocks.append("食谱%d种" % registry["diets"].size())
			_label(card,"解锁：%s" % ("、".join(unlocks) if not unlocks.is_empty() else "能力标记"))
			for item in def["samples"]:
				_label(card,"获取路线 · " + _sample_route(String(item)))
	_label(sidebar,"已完成%d/12项 · 解锁后前往营建/市集配置生产；需要操作路线时可打开新手手册。" % completed)
	_icon(sidebar,"build","营建研究台",_show_build)


# --- P8.d flower sources -----------------------------------------------------

func _crop_extra(crop: Dictionary) -> void:
	if not world.flowers.is_flower_crop(String(crop["crop_id"])):
		return
	var uid := int(crop["uid"])
	var share: Dictionary = world.flowers.share_of(uid)
	var contents: Dictionary = world.flowers.share_contents()
	if share.is_empty():
		_label(sidebar,"花源 · 当前不具备供花资格（成熟/花期区间/水肥光照），今日无份额。")
		return
	var used := int(share["used"])
	var left := maxi(0, 1 - used)
	if world.flowers.eligible(uid):
		_label(sidebar,"花源 · 今日剩余份额%d/%d · 手采可得%s（1AP）" % [left, 1, _materials(contents)])
		if world.flowers.pollinated(uid):
			_label(sidebar,"本周期已由蜂群授粉 · 收获额外油籽+1")
		var pick := _icon(sidebar,"nectar","手采花源（1AP）",func(): _result(world.pick_flower(Vector2i(int(crop["origin"][0]),int(crop["origin"][1])))); _show_cell())
		pick.disabled = left < 1
	else:
		_label(sidebar,"花源 · 今日已初始化份额但当前水肥/光照不足，剩余份额暂停可用；恢复环境后可继续使用。")
	if String(crop["crop_id"]) == "oilseed_flower" and not world.flowers.pollinated(uid):
		_label(sidebar,"蜂群利用本株份额可为本周期的油籽收获+1（多次/多箱不叠加）。")

func _habitat_extra(habitat: Dictionary) -> void:
	_production_section(world.facilities[int(habitat["facility_uid"])], false)
	if String(world.facility_defs[String(world.facilities[int(habitat["facility_uid"])]["facility_id"])].get("id", "")) == "rock_workyard" or world.facility_defs[String(world.facilities[int(habitat["facility_uid"])]["facility_id"])].get("species", []).size() > 1:
		if habitat["individuals"].is_empty():
			_label(sidebar,"本场只能养一种岩兽；空场可切换物种后再购入。")
			var picker := OptionButton.new()
			for species_id in world.facility_defs[String(world.facilities[int(habitat["facility_uid"])]["facility_id"])]["species"]:
				picker.add_item("%s（幼体%d元石）" % [world.husbandry.species_def(String(species_id))["name"], int(world.husbandry.species_def(String(species_id))["juvenile_price"])])
				picker.set_item_metadata(picker.item_count - 1, String(species_id))
				if String(habitat["species_id"]) == String(species_id):
					picker.select(picker.item_count - 1)
			picker.item_selected.connect(func(index): _result(world.husbandry.set_yard_species(int(habitat["facility_uid"]), String(picker.get_item_metadata(index)))); _show_cell())
			sidebar.add_child(picker)
			return
		_label(sidebar,"单场单物种：日粮维持成长/有效日，加工矿料在启动轮一次付清；基础食物不产矿。")
		return
	if String(habitat["species_id"]) == "purifying_mat":
		_label(sidebar,"培养单位购入即占位（不入仓库）；幼体每日清水1培养，成体只按处理配方取料，无批次时待机不扣水。")
		_label(sidebar,"污水仅来自水场真实换水；炭砂滤料所需砂砾由啮岩鼹破石取得（P8.f路线）。")
		return
	if String(habitat["species_id"]) != "bell_bee":
		return
	var uid := int(habitat["facility_uid"])
	var coverage: Dictionary = world.flowers.hive_coverage(uid)
	_label(sidebar,"花源覆盖 · 外扩2格 · 区内花株%d株，可用份额%d份" % [int(coverage["plants"]), int(coverage["available"])])
	_label(sidebar,"每群每日基础服务消耗1份额＋清水1；份额与手采共享，多箱按稳定顺序分配，不叠加授粉。")


# --- P8.g devices ---------------------------------------------------------------

func _show_device(facility: Dictionary) -> void:
	var uid := int(facility["uid"])
	var definition: Dictionary = world.facility_defs[facility["facility_id"]]
	_picture(sidebar, facility["facility_id"], 64)
	_heading(sidebar, definition["name"])
	if String(facility["facility_id"]) == "field_service_station":
		var device: Dictionary = world.devices.device_of(uid)
		if device.is_empty():
			_label(sidebar,"新站次日开日起运行；以下配置0AP、当日修改次日生效。")
		var irrigate := CheckButton.new()
		irrigate.text = "自动浇水（每格清水1，+30至100）"
		irrigate.button_pressed = device.is_empty() or bool(device.get("irrigate", true))
		var fertilize := CheckButton.new()
		fertilize.text = "自动施肥（每格腐殖土1，+30至100）"
		fertilize.button_pressed = device.is_empty() or bool(device.get("fertilize", true))
		var row := HBoxContainer.new()
		sidebar.add_child(row)
		_label(row,"阈值")
		var threshold := SpinBox.new()
		threshold.min_value = 1
		threshold.max_value = 99
		threshold.value = int(device.get("threshold", 30))
		threshold.custom_minimum_size.x = 80
		row.add_child(threshold)
		for button in [irrigate, fertilize]:
			sidebar.add_child(button)
		_icon(sidebar,"play","保存配置（次日开日生效）",func():
			_result(world.devices.configure_station(uid, irrigate.button_pressed, fertilize.button_pressed, int(threshold.value)))
			_show_cell())
		var overview: Dictionary = world.devices.station_overview(uid)
		_label(sidebar,"覆盖%d格 · 待浇水%d格 · 待施肥%d格 · 每项每日最多%d次，按格轮转。" % [
			int(overview["cells"]), int(overview["low"]["irrigate"]), int(overview["low"]["fertilize"]), int(overview["limit"])])
		_label(sidebar,"装置服务不占雇工次数、不扣玩家AP、不收工资；原料保留量不约束设备消费。")
	else:
		var device: Dictionary = world.devices.device_of(uid)
		var enabled := CheckButton.new()
		enabled.text = "启用补光（覆盖内有作物时每日精炼油1）"
		enabled.button_pressed = not device.is_empty() and bool(device.get("enabled", false))
		enabled.toggled.connect(func(value): _result(world.devices.configure_lamp(uid, value)); _show_cell())
		sidebar.add_child(enabled)
		var overview: Dictionary = world.devices.lamp_overview(uid)
		_label(sidebar,"光照80、外扩2格取最大值不叠加；空范围不耗油。" )
		_label(sidebar,"覆盖内作物%d株%s" % [int((overview["crops"] as Array).size()),
			("；喜阴降效：" + "、".join(PackedStringArray((overview["shade"] as Array).map(func(c): return CROPS[c])))) if not (overview["shade"] as Array).is_empty() else ""])
		_label(sidebar,"今日%s · 燃料%s（库存%d）" % ["已点亮" if bool(overview["active"]) else "未点亮",
			world._items[String(overview["fuel_item"])]["name"], world.inventory.count(String(overview["fuel_item"]))])
		_label(sidebar,"拆除立即取消剩余光照，已耗燃料不退；重建为新实例次日启用。")
	_icon(sidebar,"clear","拆除（1AP，无返还）",func(): _confirm("拆除%s？不返还建设材料或元石，消耗1AP。" % definition["name"],func(): _result(world.demolish_facility(uid)); _show_cell()))
