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
	_icon(sidebar,"clear","拆除（1AP，无返还）",func(): _confirm("拆除%s？不返还建设材料或元石，消耗1AP。" % definition["name"],func(): _result(world.demolish_facility(uid)); _show_cell()))

func _help_extra() -> void:
	super()
	_heading(sidebar,"P8生态产业（开发中）")
	_label(sidebar,"水场换水：有动物、水体未满时，清水×2换水体+40并产出污水×2；每场每天最多一次，手动与负责人共享当日标记。")
	_label(sidebar,"新设施、新作物、新食谱与研究台内容已登记但未开放；完成研究前在营建、市集与配方页保持锁定并说明原因。")
	_label(sidebar,"日结失败时世界回滚到触发操作前，保留唯一待提交候选；重试只写入该候选，放弃当天回到上一份有效档案。")
