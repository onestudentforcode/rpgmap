extends RefCounted
## P10.3 ranch manager: zone painting, roster, purchases, assignments,
## schedules, recipes, claims and the warning feed. Reads never mutate.
var shell
var zone_tool := ""
var paint_zone := -1
var fence_target := -1
var fence_cells: Array = []
var paint_erase := false
var pending_cells: Array = []
var assign_uid := 0
var assign_mode := ""
const ZONE_NAMES := {"nursery": "育幼区", "enclosure": "繁殖区", "intensive": "精养区", "work": "工作区",
	"maintenance": "维持放牧区", "pasture": "额外放牧区", "water_nursery": "育幼池", "water_enclosure": "繁殖池",
	"water_production": "生产池", "water_loach": "泥鳅净化区", "aqua_planting": "水生种植区"}
const ZONE_COLORS := {"nursery": Color(0.42, 0.65, 0.55), "enclosure": Color(0.55, 0.62, 0.85),
	"intensive": Color(0.7, 0.55, 0.75), "work": Color(0.78, 0.6, 0.38), "maintenance": Color(0.62, 0.75, 0.4), "pasture": Color(0.45, 0.7, 0.72)}
const FACILITY_NAMES := {"rock_breaking_yard": "碎岩场", "ore_sorting_yard": "选矿场", "carbonization_nest": "炭化巢",
	"compost_mouse_den": "翻肥窝", "shell_forming_station": "岩壳成型台", "wool_station": "采毛台", "silkworm_rack": "蚕架",
	"spirit_liquid_collector": "集露台", "scale_station": "养鳞台", "intensive_station": "专属精养台（任一）", "work_yard": "专属役使设施（任一）"}

func _init(owner) -> void: shell = owner

func ranch():
	return shell.world.ranch

func _zone_type_of(zone_uid: int) -> String:
	var row: Dictionary = ranch().zone(zone_uid)
	return String(row.get("type", "")) if not row.is_empty() else ""

func open() -> void:
	shell._context = "ranch"
	shell.build_tool = ""
	shell.logistics_ui.placing = ""
	shell.rooms_ui.floor_tool = ""
	shell.rooms_ui.field_tool = false
	shell._page("畜牧分区 · 陆生动物名册与排班")
	shell._label(shell.sidebar, "九种陆生动物走名册制：普通地板划功能区，八单位日程自动结算维持、劳动、恢复；成体在繁殖、精养、役使三种用途中择一。")
	_warnings()
	_paint_controls()
	_zone_cards()
	_purchase_card()
	_roster_cards()
	_workyard_cards()
	_water_cards()
	shell.services_ui.render(shell.sidebar)
	shell._encyclopedia_link(shell.sidebar, "rule:animal-zones")

func _warnings() -> void:
	var notes := []
	for row in ranch().state["animals"]:
		var tier: Dictionary = ranch().fatigue_tier(int(row["fatigue"]))
		var uid := int(row["uid"])
		if int(row["death_streak"]) > 0:
			notes.append("#%d 连续濒危%d天，再%d天死亡" % [uid, int(row["death_streak"]), 3 - int(row["death_streak"])])
		elif int(row["fatigue"]) >= 24:
			notes.append("#%d %s（疲劳%d）当天不劳动" % [uid, String(tier["label"]), int(row["fatigue"])])
		elif int(row["fatigue"]) >= 16:
			notes.append("#%d %s（疲劳%d）效率50%%" % [uid, String(tier["label"]), int(row["fatigue"])])
		if int(row["ban_until"]) > shell.world.clock.total_days * 8:
			notes.append("#%d 禁工至单位%d" % [uid, int(row["ban_until"])])
		if String(row["mode"]) == "work" and not bool(row["served_once"]):
			notes.append("#%d 待首次维持，暂无工作资格" % uid)
		if String(row["mode"]) == "waiting":
			notes.append("#%d 成体未安置，等待中" % uid)
		if bool(row["breed"]["pending"]):
			notes.append("#%d 待安置幼体，请领取" % uid)
		if bool(row["natural"]["pending"]):
			notes.append("#%d 精养产物待领取" % uid)
	for zone_row in ranch().state["zones"]:
		var missing: Array = ranch().structure_missing(zone_row)
		if not missing.is_empty():
			notes.append("%s结构缺件：%s" % [String(zone_row["name"]), "、".join(_structure_names(missing))])
		elif not ranch().zone_structural(zone_row):
			notes.append("%s一级未成立：检查完整普通地板与最小可用空间" % String(zone_row["name"]))
		if ["maintenance", "pasture"].has(String(zone_row["type"])) and int(zone_row["dispatch_uid"]) == 0:
			notes.append("%s未关联调度站，役使动物无法使用" % String(zone_row["name"]))
		if String(zone_row["type"]) == "enclosure" and int(zone_row["birth_target"]) == 0:
			var breeders: Array = ranch().animals_in_zone(int(zone_row["uid"]), ["enclosure"])
			if not breeders.is_empty():
				notes.append("%s未选择育幼目标，出生幼体无法安置" % String(zone_row["name"]))
	var card = shell._card(shell.sidebar)
	shell._heading(card, "预警")
	if notes.is_empty():
		shell._label(card, "当前没有缺供、禁工或安置预警。")
	else:
		for note in notes.slice(0, 12):
			shell._label(card, "· " + note)

func _structure_names(missing: Array) -> Array:
	var names := {"pen": "圈舍", "feed_trough": "供食槽", "bed": "床位", "care_table": "照料台", "dispatch_station": "调度站", "toy_station":"玩具站"}
	var out := []
	for key in missing:
		out.append(String(FACILITY_NAMES.get(String(key), String(names.get(String(key), String(key))))))
	return out

func _paint_controls() -> void:
	var card = shell._card(shell.sidebar)
	shell._heading(card, "功能区划定（0AP）")
	if zone_tool.is_empty():
		for type_id in ["nursery", "enclosure", "intensive", "work", "maintenance", "pasture",
				"water_nursery", "water_enclosure", "water_production", "water_loach", "aqua_planting"]:
			var min_space: int = int(ranch().settings["zones"][type_id]["min_space"])
			shell._button(card, "划定%s（最小空间%d）" % [ZONE_NAMES[type_id], min_space], func(): begin_zone(type_id))
	else:
		shell._label(card, "正在划定%s：点击普通地板加入（右键移除），已选%d格。" % [ZONE_NAMES[zone_tool], pending_cells.size()])
		var preview: Dictionary = ranch().preview_zone(zone_tool, pending_cells)
		shell._label(card, preview.get("summary", preview.get("reason", "先选择地格")) if preview.has("summary") else ("空间%d，结构缺件：%s" % [int(preview.get("space", 0)), "、".join(_structure_names(preview.get("missing", [])))]))
		shell._button(card, "确认创建", func(): commit_zone())
		shell._button(card, "取消", func(): cancel_zone())

func begin_zone(type_id: String) -> void:
	zone_tool = type_id
	paint_zone = -1
	paint_erase = false
	pending_cells = []
	assign_uid = 0
	shell._close_page()
	shell.notice.text = "点击普通地板加入%s（右键移除已选格）；已选0格。" % ZONE_NAMES[type_id]
	shell.overlay.queue_redraw()

func cancel_zone() -> void:
	zone_tool = ""
	pending_cells = []
	open()

func commit_zone() -> void:
	var result: Dictionary = ranch().create_zone(zone_tool, pending_cells.duplicate())
	shell._result(result)
	zone_tool = ""
	pending_cells = []
	open()

func click_cell(cell: Vector2i) -> bool:
	# Returns true when the click was consumed by an active ranch mode. The
	# page stays closed while painting: rebuilding it between clicks would
	# shift the canvas transform under the cursor.
	if not zone_tool.is_empty():
		var text := "%d,%d" % [cell.x, cell.y]
		if paint_erase or pending_cells.has(text):
			pending_cells.erase(text)
		else:
			pending_cells.append(text)
		shell.notice.text = "正在划定%s：已选%d格（右键移除）。回面板确认创建。" % [ZONE_NAMES[zone_tool], pending_cells.size()]
		shell.overlay.queue_redraw()
		return true
	if fence_target != -1:
		var text := "%d,%d" % [cell.x, cell.y]
		if paint_erase or fence_cells.has(text):
			fence_cells.erase(text)
		else:
			fence_cells.append(text)
		shell.notice.text = "铺鱼栅：已选%d格（右键移除）。回水域面板确认。" % fence_cells.size()
		shell.overlay.queue_redraw()
		return true
	if paint_zone > 0:
		var result: Dictionary
		if paint_erase:
			result = ranch().erase_cell(paint_zone, cell)
		else:
			result = ranch().paint_cell(paint_zone, cell)
		shell._result(result)
		shell.overlay.queue_redraw()
		return true
	return false

func _zone_cards() -> void:
	for zone_row in ranch().state["zones"]:
		var card = shell._card(shell.sidebar)
		var zone_uid := int(zone_row["uid"])
		var missing: Array = ranch().structure_missing(zone_row)
		var space: int = ranch().available_space(zone_row)
		shell._heading(card, "%s · %s" % [String(zone_row["name"]), ZONE_NAMES[String(zone_row["type"])]])
		shell.services_ui.zone_card(card,zone_row)
		shell._label(card, "地格%d，可用空间%d（床占地计入）；结构%s；当前全时占用%d。" % [
			int(zone_row["cells"].size()), space,
			"合格" if ranch().zone_structural(zone_row) else ("地板或可用空间不足" if missing.is_empty() else "缺件：" + "、".join(_structure_names(missing))),
			ranch()._zone_usage(zone_row)])
		if ["maintenance", "pasture"].has(String(zone_row["type"])):
			shell._button(card, "关联下一个调度站" if int(zone_row["dispatch_uid"]) == 0 else "换关联调度站", func(): cycle_link(zone_uid))
		if String(zone_row["type"]) == "enclosure":
			shell._button(card, "选择育幼目标", func(): cycle_birth_target(zone_uid))
		shell._button(card, "添加地格", func(): paint_mode(zone_uid, false))
		shell._button(card, "移除地格", func(): paint_mode(zone_uid, true))
		if not zone_row["cells"].is_empty():
			shell._button(card, "定位区域", func(): shell._locate(_first_cell(zone_row)))

func toggle_erase() -> void:
	if paint_zone > 0 or not zone_tool.is_empty():
		paint_erase = not paint_erase
		shell.notice.text = "点击地格：%s" % ("移除" if paint_erase else "加入")
		shell.overlay.queue_redraw()

func _first_cell(zone_row: Dictionary) -> Vector2i:
	var parts: PackedStringArray = String(zone_row["cells"][0]).split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

func paint_mode(zone_uid: int, erase: bool) -> void:
	paint_zone = zone_uid
	paint_erase = erase
	zone_tool = ""
	pending_cells = []
	shell._close_page()
	shell.notice.text = "点击地格%s%s（右键切换增删）" % ["移除自" if erase else "加入", String(ranch().zone(zone_uid)["name"])]
	shell.overlay.queue_redraw()

func cycle_link(zone_uid: int) -> void:
	var stations := []
	for uid in shell.world.facilities:
		if String(shell.world.facilities[uid]["facility_id"]) == "dispatch_station":
			stations.append(int(uid))
	stations.sort()
	if stations.is_empty():
		shell._result({"ok": false, "reason": "没有已建造的调度站"})
		open()
		return
	var row: Dictionary = ranch().zone(zone_uid)
	var next := 0
	for uid in stations:
		if int(uid) > int(row["dispatch_uid"]):
			next = int(uid)
			break
	var result: Dictionary = ranch().submit({"links": {zone_uid: next}})
	shell._result(result)
	open()

func cycle_birth_target(zone_uid: int) -> void:
	var nurseries := []
	for row in ranch().state["zones"]:
		if String(row["type"]) == "nursery":
			nurseries.append(int(row["uid"]))
	if nurseries.is_empty():
		shell._result({"ok": false, "reason": "没有育幼区可选"})
		open()
		return
	var row: Dictionary = ranch().zone(zone_uid)
	var next: int = int(nurseries[0])
	for uid in nurseries:
		if int(uid) > int(row["birth_target"]):
			next = int(uid)
			break
	var result: Dictionary = ranch().submit({"birth_targets": {zone_uid: next}})
	shell._result(result)
	open()

func _purchase_card() -> void:
	var card = shell._card(shell.sidebar)
	shell._heading(card, "购入幼体（0AP）")
	for medium in ["land", "water"]:
		var wanted := "nursery" if medium == "land" else "water_nursery"
		var nursery := 0
		for row in ranch().state["zones"]:
			if String(row["type"]) == wanted and ranch().structure_missing(row).is_empty():
				nursery = int(row["uid"])
				break
		if nursery == 0:
			shell._label(card, "需要结构合格的%s才能购入%s物种。" % ["育幼区" if medium == "land" else "育幼池", "陆生" if medium == "land" else "水产"])
			continue
		for species_id in ranch().SPECIES:
			if ranch().species_medium(species_id) != medium:
				continue
			var species: Dictionary = shell.world.husbandry.species_def(species_id)
			var unit := String(species.get("unit", "只"))
			var quote: Dictionary = ranch().quote_purchase(nursery, species_id, 1)
			shell._button(card, "购入%s幼%s（%d元石）%s" % [String(species["name"]), unit, int(species["juvenile_price"]), "" if quote["ok"] else " · " + String(quote["reason"])], func(): buy(species_id, nursery))

func buy(species_id: String, nursery: int) -> void:
	shell._result(ranch().purchase(nursery, species_id, 1))
	open()

func _roster_cards() -> void:
	if ranch().state["animals"].is_empty():
		shell._label(shell.sidebar, "名册为空。购入幼体或等待繁殖。")
		return
	for row in ranch().state["animals"].duplicate():
		var uid := int(row["uid"])
		var card = shell._card(shell.sidebar)
		var species: Dictionary = shell.world.husbandry.species_def(String(row["species_id"]))
		var tier: Dictionary = ranch().fatigue_tier(int(row["fatigue"]))
		shell._heading(card, "#%d %s · %s" % [uid, String(species["name"]), _mode_label(row)])
		var config: Dictionary = ranch().species_config(String(row["species_id"]))
		if ranch().species_medium(String(row["species_id"])) == "water":
			shell._label(card, "水产：连续缺维持%d/3日，连续劣水%d/3日%s。" % [int(row["miss_streak"]), int(row["bad_water_streak"]),
				"；固定锚点%s" % String(row["anchor"]) if not String(row["anchor"]).is_empty() else ""])
			if int(row["intensive_target"]) > 0:
				shell._label(card, "精养目标：%s（已记贡献%.2f照料单位，凭证%s）。" % [String(ranch().zone(int(row["intensive_target"]))["name"]),
					float(int(row["contribution"]))/100.0, "已用" if String(row["voucher"]) == "used" else "未用"])
		if String(row["stage"]) == "juvenile":
			shell._label(card, "幼体成长%.2f/%.2f照料单位；食谱%s。" % [float(row["growth"])/100.0, float(config["growth_units"])/100.0, _diet_name(row)])
		else:
			shell._label(card, "成体；食谱%s；%s。" % [_diet_name(row), _schedule_text(row)])
		shell._label(card, "开日疲劳%d（%s，效率%d%%）；禁工%s；维持资格%s。" % [int(row["fatigue"]), String(tier["label"]), int(tier["efficiency"]),
			"无" if int(row["ban_until"]) <= shell.world.clock.total_days * 8 else "至单位%d" % int(row["ban_until"]),
			"有效" if bool(row["served_once"]) else "待首次维持"])
		if ranch().natural_config(String(row["species_id"])).size() > 0:
			var natural_row: Dictionary = row["natural"]
			shell._label(card, "精养轮次%d：%.2f/%.2f照料单位%s%s" % [int(natural_row["round"]), float(natural_row["units"])/100.0,
				float(ranch().natural_config(String(row["species_id"]))["units"])/100.0,
				"，已投料" if bool(natural_row["paid"]) else "", "，待领取" if bool(natural_row["pending"]) else ""])
			shell._button(card, "换精养补料（当前%s）" % _natural_diet_name(row), func(): cycle_natural_diet(uid))
		if String(row["stage"]) == "adult" and ranch().can_breed(String(row["species_id"])):
			shell._label(card, "繁殖轮次%d：%.2f/%.2f照料单位%s（需开日疲劳0）" % [int(row["breed"]["round"]), float(row["breed"]["units"])/100.0, float(config["breed_units"])/100.0, "，待安置" if bool(row["breed"]["pending"]) else ""])
		_diet_button(card, row)
		if String(row["stage"]) == "adult":
			var medium := ranch().species_medium(String(row["species_id"]))
			var breed_mode := "water_enclosure" if medium == "water" else "enclosure"
			var production_mode := "water_production" if medium == "water" else "intensive"
			if String(row["mode"]) != breed_mode and ranch().can_breed(String(row["species_id"])):
				shell._button(card, "转为繁殖（次日生效，1AP）", func(): begin_assign(uid, breed_mode))
			if String(row["mode"]) != production_mode and ranch().natural_config(String(row["species_id"])).size() > 0:
				shell._button(card, "转为精养生产（次日生效，1AP）", func(): begin_assign(uid, production_mode))
			if medium == "land":
				if String(row["mode"]) != "work":
					shell._button(card, "转为役使（次日生效，1AP）", func(): begin_assign(uid, "work"))
			elif String(row["species_id"]) == "silt_loach" and String(row["mode"]) != "water_loach":
				shell._button(card, "转为净化服务（次日生效，1AP）", func(): begin_assign(uid, "water_loach"))
			if String(row["mode"]) == "work":
				var next_pattern := "late" if String(row["pattern"]) == "standard" else "standard"
				shell._button(card, "换%s（次日生效，1AP）" % ("晚班" if next_pattern == "late" else "标准班"), func(): switch_pattern(uid, next_pattern))
		if bool(row["breed"]["pending"]):
			shell._button(card, "领取待安置幼体（1AP）", func(): claim_births(int(row["zone_uid"])))
		if bool(row["natural"]["pending"]):
			shell._button(card, "领取精养产物（1AP）", func(): claim_natural_for(int(row["zone_uid"]), String(row["species_id"])))
		if String(row["species_id"]) == "pearl_mussel" and String(row["stage"]) == "adult" and String(row["mode"]) == "water_production":
			shell._button(card, "取壳（消耗成体得贝壳2，1AP）", func(): shell._result(ranch().harvest_shell(uid)); open())
		if String(row["stage"]) == "juvenile" and not ranch().natural_config(String(row["species_id"])).is_empty():
			shell._button(card, "轮换精养目标（切换核销旧贡献）", func(): cycle_intensive_target(uid))
	if assign_uid > 0:
		var assign_card = shell._card(shell.sidebar)
		shell._heading(assign_card, "选择目标%s" % ZONE_NAMES[assign_mode])
		var found := false
		for zone_row in ranch().state["zones"]:
			if String(zone_row["type"]) == assign_mode:
				found = true
				var zone_uid := int(zone_row["uid"])
				shell._button(assign_card, "%s（空间%d/%d）" % [String(zone_row["name"]), ranch().available_space(zone_row), ranch()._zone_usage(zone_row)], func(): finish_assign(zone_uid))
		if not found:
			shell._label(assign_card, "没有%s可选，先划定。" % ZONE_NAMES[assign_mode])
		shell._button(assign_card, "取消安置", func(): assign_uid = 0; open())

func _mode_label(row: Dictionary) -> String:
	return {"nursery": "育幼", "waiting": "等待安置", "enclosure": "繁殖", "intensive": "精养", "work": "役使",
		"water_nursery": "水中育幼", "water_enclosure": "水中繁殖", "water_production": "水中生产",
		"water_loach": "净化服务"}[String(row["mode"])]

func _diet_name(row: Dictionary) -> String:
	var species: Dictionary = shell.world.husbandry.species_def(String(row["species_id"]))
	for diet in species["base_diets"]:
		if String(diet["id"]) == String(row["diet_id"]):
			return String(diet["name"])
	return String(row["diet_id"])

func _schedule_text(row: Dictionary) -> String:
	if String(row["mode"]) != "work":
		return "固定日程：维持2＋照料6单位"
	if String(row["pattern"]) == "late":
		return "晚班：工工放放维维工工"
	return "标准班：维维工工工工放放"

func _diet_button(parent: Node, row: Dictionary) -> void:
	var species: Dictionary = shell.world.husbandry.species_def(String(row["species_id"]))
	var diets: Array = species["base_diets"]
	if diets.size() < 2:
		return
	var uid := int(row["uid"])
	shell._button(parent, "换基础餐（当前%s）" % _diet_name(row), func(): cycle_diet(uid))

func cycle_diet(uid: int) -> void:
	var row: Dictionary = ranch().animal(uid)
	var species: Dictionary = shell.world.husbandry.species_def(String(row["species_id"]))
	var ids: Array = species["base_diets"].map(func(d): return String(d["id"]))
	var next: String = String(ids[0])
	for index in range(ids.size()):
		if String(ids[index]) == String(row["diet_id"]):
			next = String(ids[(index + 1) % ids.size()])
			break
	shell._result(ranch().set_diet(uid, next))
	open()

func begin_assign(uid: int, mode: String) -> void:
	assign_uid = uid
	assign_mode = mode
	open()

func finish_assign(zone_uid: int) -> void:
	var row: Dictionary = ranch().animal(assign_uid)
	if row.is_empty():
		assign_uid = 0
		open()
		return
	var request := {"mode": assign_mode, "zone_uid": zone_uid}
	if assign_mode == "enclosure" or assign_mode == "intensive":
		var beds: Array = ranch().free_bed_slots(ranch().zone(zone_uid), String(ranch().species_config(String(row["species_id"]))["bed"]))
		if beds.is_empty():
			shell._result({"ok": false, "reason": "目标功能区没有适配床位"})
			return
		request["bed_uid"] = int(beds[0]["uid"])
		request["bed_slot"] = int(beds[0]["slot"])
	shell._result(ranch().submit({"assign": {assign_uid: request}}))
	assign_uid = 0
	open()

func switch_pattern(uid: int, pattern: String) -> void:
	shell._result(ranch().submit({"patterns": {uid: pattern}}))
	open()

func claim_births(zone_uid: int) -> void:
	shell._result(ranch().claim_births(zone_uid))
	open()

func claim_natural_for(zone_uid: int, species_id: String) -> void:
	var station_id := String(ranch().natural_config(species_id).get("station", ""))
	var station_uid := 0
	for facility in ranch()._facilities_in_zone(ranch().zone(zone_uid)):
		if String(facility["facility_id"]) == station_id:
			station_uid = int(facility["uid"])
			break
	if station_uid == 0:
		shell._result({"ok": false, "reason": "精养区内没有该物种的专属精养台"})
	else:
		shell._result(ranch().claim_natural(station_uid))
	open()

func _natural_diet_name(row: Dictionary) -> String:
	var species: Dictionary = shell.world.husbandry.species_def(String(row["species_id"]))
	for diet in species["special_diets"]:
		if String(diet["id"]) == String(row["natural"]["diet_id"]):
			return String(diet["name"])
	return String(row["natural"]["diet_id"])

func cycle_natural_diet(uid: int) -> void:
	var row: Dictionary = ranch().animal(uid)
	var species: Dictionary = shell.world.husbandry.species_def(String(row["species_id"]))
	var ids: Array = species["special_diets"].map(func(d): return String(d["id"]))
	var next: String = String(ids[0])
	for index in range(ids.size()):
		if String(ids[index]) == String(row["natural"]["diet_id"]):
			next = String(ids[(index + 1) % ids.size()])
			break
	shell._result(ranch().set_natural_diet(uid, next))
	open()

func cycle_intensive_target(uid: int) -> void:
	var row: Dictionary = ranch().animal(uid)
	if row.is_empty():
		return
	var medium := ranch().species_medium(String(row["species_id"]))
	var production_type := "water_production" if medium == "water" else "intensive"
	var candidates := [0]
	for zone_row in ranch().state["zones"]:
		if String(zone_row["type"]) == production_type:
			candidates.append(int(zone_row["uid"]))
	var next := 0
	for candidate in candidates:
		if candidate > int(row["intensive_target"]):
			next = candidate
			break
	shell._result(ranch().set_intensive_target(uid, next))
	open()

func _water_cards() -> void:
	var card = shell._card(shell.sidebar)
	shell._heading(card, "水域（P10.6）")
	var water = shell.world.water
	if water.state["bodies"].is_empty():
		shell._label(card, "还没有水体：先铺鱼栅（每格1元石＋树枝1＋1AP），划定水功能房间后即可养育水产。")
	else:
		for body in water.state["bodies"]:
			var body_uid := int(body["uid"])
			shell._label(card, "%s：%d格，水质%d/100，今日已人工换水%s；换水站关联%d座。" % [String(body["name"]),
				water.area(body), water.quality(body), "是" if int(body["change_day"]) == shell.world.clock.total_days else "否",
				water.state["links"].size()])
			shell._button(card, "人工换水（清水2→污水2，1AP）", func(): shell._result(water.change_water(body_uid)); open())
			if fence_target == body_uid:
				shell._label(card, "正在为该水体添加鱼栅：已选%d格，回面板确认。" % fence_cells.size())
				shell._button(card, "确认铺设", func(): commit_fence(body_uid))
				shell._button(card, "取消", func(): fence_target = 0; fence_cells = []; open())
			else:
				shell._button(card, "为该水体加铺鱼栅", func(): fence_target = body_uid; fence_cells = []; shell._close_page(); shell.notice.text = "点击未铺的水面加入该水体（右键移除）。")
		shell._button(card, "新建水体（铺鱼栅）", func(): fence_target = 0; fence_cells = []; shell._close_page(); shell.notice.text = "点击未铺的水面创建新水体（右键移除）。")
		if not fence_cells.is_empty():
			shell._label(card, "当前已选%d格。" % fence_cells.size())
			shell._button(card, "确认铺设所选鱼栅", func(): commit_fence(fence_target))
			shell._button(card, "取消选择", func(): fence_cells = []; shell.overlay.queue_redraw())
	shell._encyclopedia_link(shell.sidebar, "rule:water-systems")

func commit_fence(target_body: int) -> void:
	var cells := []
	for text in fence_cells:
		var parts := String(text).split(",")
		cells.append(Vector2i(int(parts[0]), int(parts[1])))
	shell._result(shell.world.water.build_fence(cells, target_body))
	fence_target = -1
	fence_cells = []
	open()

func _workyard_cards() -> void:
	var yards: Array = []
	var wanted: Array = ranch().settings["work"]["facilities"].keys()
	for uid in shell.world.facilities:
		if wanted.has(String(shell.world.facilities[uid]["facility_id"])):
			yards.append(int(uid))
	yards.sort()
	for yard_uid in yards:
		var yard: Dictionary = ranch().peek_workyard(yard_uid)
		var facility_name := String(FACILITY_NAMES.get(String(shell.world.facilities[yard_uid]["facility_id"]), ""))
		var card = shell._card(shell.sidebar)
		var busy := ""
		var ready := 0
		for post in yard["posts"]:
			if String(post["status"]) == "ready":
				ready += 1
			elif String(post["status"]) == "running":
				busy += " [%.2f/%.2f]" % [float(post["progress"])/100.0,float(post["target"])/100.0]
		shell._heading(card, "%s#%d · %s" % [facility_name, yard_uid, _recipe_name(String(yard["recipe_id"]))])
		shell._label(card, "四并行岗位；运行中：%s；待领取%d批。" % [busy if not busy.is_empty() else "无", ready])
		shell.services_ui.work_pool(card,yard_uid)
		if ready > 0:
			shell._button(card, "领取完成批次（1AP）", func(): shell._result(ranch().claim_workyard(yard_uid)); open())
		var recipes: Array = ranch().settings["work"]["facilities"][String(shell.world.facilities[yard_uid]["facility_id"])]
		var index := recipes.find(String(yard["recipe_id"]))
		if recipes.size() > 1:
			var next_recipe: String = String(recipes[(index + 1) % recipes.size()])
			shell._button(card, "换配方为%s（空场时0AP）" % _recipe_name(next_recipe), func(): shell._result(ranch().set_recipe(yard_uid, next_recipe)); open())

func _recipe_name(recipe_id: String) -> String:
	var names := {"break_stone": "碎石", "break_ore": "碎矿", "concentrate_ore": "富集",
		"bug_char_twigs": "树枝炭化", "bug_char_chips": "木屑炭化",
		"mouse_compost_fiber": "秸秆翻肥", "mouse_compost_residue": "残料翻肥",
		"form_rock_shell": "岩壳成型"}
	return String(names.get(recipe_id, recipe_id))

func result_text(result: Dictionary) -> String:
	if not result.has("items"):
		return ""
	return "畜牧领取：" + shell.logistics_ui.items_text(result["items"])

func draw_ground(target: Node2D, projected: bool) -> void:
	for zone_row in ranch().state["zones"]:
		var color: Color = ZONE_COLORS[String(zone_row["type"])]
		for text in zone_row["cells"]:
			var parts: PackedStringArray = String(text).split(",")
			var rect := Rect2(Vector2(int(parts[0]), int(parts[1])) * 64, Vector2(64, 64))
			if projected:
				rect = shell.projection.ground_rect(rect)
			target.draw_rect(rect, Color(color, 0.10))
			target.draw_rect(rect.grow(-1), Color(color, 0.55), false, 1)

func draw_preview(target: Node2D, projected: bool) -> void:
	if zone_tool.is_empty() and paint_zone < 0:
		return
	if not pending_cells.is_empty():
		for text in pending_cells:
			var parts: PackedStringArray = String(text).split(",")
			var rect := Rect2(Vector2(int(parts[0]), int(parts[1])) * 64, Vector2(64, 64))
			if projected:
				rect = shell.projection.ground_rect(rect)
			var ok_cell: bool = shell.world.rooms.floor_kind(Vector2i(int(parts[0]), int(parts[1]))) == "ordinary"
			target.draw_rect(rect, Color(ZONE_COLORS[zone_tool], 0.35) if ok_cell else Color(0.8, 0.3, 0.25, 0.35))
	if shell.world.grid.in_bounds(shell._hover.x, shell._hover.y):
		var rect := Rect2(Vector2(shell._hover) * 64, Vector2(64, 64))
		if projected:
			rect = shell.projection.ground_rect(rect)
		var allowed := false
		if not zone_tool.is_empty():
			allowed = shell.world.rooms.floor_kind(shell._hover) == "ordinary"
		elif paint_zone > 0:
			allowed = shell.world.rooms.floor_kind(shell._hover) == "ordinary"
		target.draw_rect(rect.grow(-2), Color(0.95, 0.85, 0.35, 0.8) if allowed else Color(0.8, 0.3, 0.25, 0.6), false, 2)
