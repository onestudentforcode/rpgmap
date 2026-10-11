extends "res://scripts/farming/v2/v2_scene.gd"
## P8 development shell: independent slots/settings, research-gated build, trade
## and diet surfaces, and the water-change habitat panel. The foundation stage
## registers the full catalog while later subphases switch the gates on.
const P8World := preload("res://scripts/farming/p8/p8_world.gd")
const P8Store := preload("res://scripts/farming/p8/p8_slot_store.gd")

func _init() -> void:
	store = P8Store.new()
	manual_mode = true
	minimum_map_zoom = 0.1
	settings = Settings.new("user://farm_demo_p8_settings.cfg", minimum_map_zoom)
	product_title = "灵田 Demo P8 · 开发底座"
	terrain_path = "res://content/farming/baked/p8/terrains.json"
	preview_prefix = "p8"

func _make_store(directory: String = ""):
	return P8Store.new() if directory.is_empty() else P8Store.new(directory)

func _make_world(slot_store):
	return P8World.new(slot_store)

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
			_label(card,_missing(definition["materials"]))
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
		_picture(sidebar,facility["facility_id"],64)
		_heading(sidebar,definition["name"])
		_label(sidebar,"研究台可建造与拆除；研究项目、样本与解锁将在后续阶段接入，当前没有可执行配方。")
		_icon(sidebar,"clear","拆除（1AP，无返还）",func(): _confirm("拆除%s？不返还建设材料或元石，消耗1AP。" % definition["name"],func(): _result(world.demolish_facility(int(facility["uid"]))); _show_cell()))
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

func _help_extra() -> void:
	super()
	_heading(sidebar,"P8生态产业（开发中）")
	_label(sidebar,"水场换水：有动物、水体未满时，清水×2换水体+40并产出污水×2；每场每天最多一次，手动与负责人共享当日标记。")
	_label(sidebar,"新设施、新作物、新食谱与研究台内容已登记但未开放；完成研究前在营建、市集与配方页保持锁定并说明原因。")
	_label(sidebar,"日结失败时世界回滚到触发操作前，保留唯一待提交候选；重试只写入该候选，放弃当天回到上一份有效档案。")
	_label(sidebar,"P8负责人：一人可负责多座设施，每设施一名、分高/普通/低优先级；所有成功工作共享每日12次与个人预算。")
	_label(sidebar,"农务兼任默认关闭，开启后按区域/类别/资源点与设施任务同池调度；持续生产按目标库存自动投料，原料保留量只挡自动批次。")

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
func _production_section(facility: Dictionary) -> void:
	var uid := int(facility["uid"])
	_owner_section(uid)
	_heading(sidebar,"持续生产 · 默认关闭")
	var strategy: Dictionary = ops().strategy_of(uid)
	var enabled := CheckButton.new()
	enabled.text = "启用自动投料（达到目标停止新批，在制照常完成）"
	enabled.button_pressed = bool(strategy["enabled"])
	enabled.toggled.connect(func(value):
		_result(ops().set_production(uid, value, String(strategy["recipe_id"]), String(strategy["target_item"]), int(strategy["target_qty"])))
		_show_cell())
	sidebar.add_child(enabled)
	var facility_id := String(world.facilities[uid]["facility_id"])
	var unlocked := []
	for ident in world.recipe_defs:
		var recipe: Dictionary = world.recipe_defs[ident]
		if String(recipe["facility"]) == facility_id and world.research_block(String(recipe.get("research", ""))).is_empty():
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
		recipes.add_item(RECIPES[unlocked[index]])
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
		var outputs: Dictionary = world.recipe_defs[recipe_id]["outputs"]
		var list := outputs.keys()
		list.sort()
		for index in range(list.size()):
			targets.add_item("%s（现存有效%d）" % [world._items[list[index]]["name"], ops().effective_stock(String(list[index]))])
			targets.set_item_metadata(index, list[index])
			if list[index] == keep_item: targets.select(index)
	refresh_targets.call(String(strategy["recipe_id"]) if not String(strategy["recipe_id"]).is_empty() else unlocked[0], String(strategy["target_item"]))
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
		for step in ["收取", "水体维护", "整体维护", "投料", "加工收取"]:
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
