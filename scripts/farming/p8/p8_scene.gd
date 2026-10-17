extends "res://scripts/farming/v2/v2_scene.gd"
## P8 local demo: independent slots/settings, research-gated ecology production,
## shared facility owners, and the beginner handbook.
const P8World := preload("res://scripts/farming/p8/p8_world.gd")
const P8Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const Handbook := preload("res://scripts/farming/p8/p8_handbook.gd")
const PlantVisuals := preload("res://scripts/farming/p8/p8_plant_visuals.gd")
var plant_visuals := PlantVisuals.new()
const FacilityVisuals := preload("res://scripts/farming/p8/p8_facility_visuals.gd")
var facility_visuals := FacilityVisuals.new()
const TerrainSoften := preload("res://assets/farming/shaders/p8_terrain_soften.gdshader")
const TrialGrounding := preload("res://scripts/farming/p8/p8_grounding.gd")
const ProductionEnvironment := preload("res://scripts/farming/p8/p8_environment_visuals.gd")
const P8Style := preload("res://scripts/farming/p8/p8_ui_style.gd")
const Encyclopedia := preload("res://scripts/farming/p8/p8_encyclopedia.gd")
var encyclopedia := Encyclopedia.new(self)
const LogisticsUI := preload("res://scripts/farming/p8/p10_ui.gd")
var logistics_ui := LogisticsUI.new(self)
## Chosen orientation for the next agriculture-station placement.
var build_facing := "east"
const RoomsUI := preload("res://scripts/farming/p8/p102_ui.gd")
var rooms_ui := RoomsUI.new(self)

func _new(slot: int, overwrite: bool) -> void:
	rooms_ui.floor_tool=""
	logistics_ui.placing=""
	super(slot,overwrite)

func _select_tool(kind: String) -> void:
	rooms_ui.floor_tool=""
	super(kind)
var production_visuals := true
var _facility_thumbnails: Dictionary = {}
var visual_trial_profile := "baseline"
var trial_environment = null
var _trial_grounding = null
var _handbook_chapter := "start"
var _land_stamp := ""
var _land_focus := ""
var _map_pan := false

func _init() -> void:
	var release_probe := OS.get_cmdline_user_args().has("--p85-smoke") or OS.get_cmdline_user_args().has("--p86-smoke")
	store = P8Store.new("user://p85_probe_slots_%d" % OS.get_process_id()) if release_probe else P8Store.new()
	manual_mode = true
	minimum_map_zoom = 0.1
	settings = Settings.new("user://p85_probe_settings_%d.cfg" % OS.get_process_id() if release_probe else "user://farm_demo_p8_settings.cfg", minimum_map_zoom)
	product_title = "灵田 Demo P8.6 · 生态经营"
	terrain_path = "res://content/farming/baked/p8/terrains.json"
	preview_prefix = "p8"

func _make_store(directory: String = ""):
	return P8Store.new() if directory.is_empty() else P8Store.new(directory)

func _make_theme() -> Theme:
	return P8Style.theme() if production_visuals else super()

func _card(parent: Node) -> VBoxContainer:
	var body := super(parent)
	if production_visuals: body.get_parent().add_theme_stylebox_override("panel",UI.box(P8Style.CARD,P8Style.BORDER))
	return body

func facility_thumbnail(ident: String) -> Texture2D:
	if _facility_thumbnails.has(ident): return _facility_thumbnails[ident]
	if not facility_visuals.facilities.has(ident): return null
	var path := String(facility_visuals.facilities[ident]["path"])
	if not facility_visuals.textures.has(path): return null
	var texture: Texture2D = facility_visuals.textures[path]
	var image := texture.get_image()
	var region := Rect2(image.get_used_rect()).grow(8).intersection(Rect2(Vector2.ZERO,texture.get_size()))
	var thumbnail := AtlasTexture.new()
	thumbnail.atlas = texture
	thumbnail.region = region
	_facility_thumbnails[ident] = thumbnail
	return thumbnail

func _picture(parent: Node, ident: String, extent: int = 40) -> TextureRect:
	var texture := facility_thumbnail(ident) if production_visuals else null
	if texture == null: return super(parent,ident,extent)
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(extent,extent)
	picture.set_meta("facility_thumbnail",ident)
	parent.add_child(picture)
	return picture

func _make_world(slot_store):
	return P8World.new(slot_store)

func _ready() -> void:
	super()
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	board.mouse_exited.connect(func(): _map_pan = false)
	var style: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/farming/p8/world_visuals.json"))
	for ident in style["terrain_tones"]:
		if not terrain.layers.has(ident): continue
		var material := ShaderMaterial.new()
		material.shader = TerrainSoften
		material.set_shader_parameter("terrain_tone",Color(String(style["terrain_tones"][ident])))
		material.set_shader_parameter("detail_strength",float(style["terrain_detail_strength"]))
		material.set_shader_parameter("surface_kind",int(style["terrain_surface_kinds"][ident]))
		material.set_shader_parameter("surface_detail",float(style["terrain_surface_detail"]))
		terrain.layers[ident].material = material
	if production_visuals and style.get("production_visuals",false):
		var configured := configure_visual_trial("integrated")
		if not configured["ok"]: push_error("P8.6 production visuals: %s" % configured["diagnostics"])
	if OS.get_cmdline_user_args().has("--p85-smoke"):
		var probe = load("res://scripts/farming/validation/p85_release_smoke.gd").new()
		probe.shell = self
		add_child(probe)
		probe.run.call_deferred()
	if OS.get_cmdline_user_args().has("--p86-smoke"):
		var probe = load("res://scripts/farming/validation/p86_release_smoke.gd").new()
		probe.shell = self
		add_child(probe)
		probe.run.call_deferred()

func configure_visual_trial(profile: String, runtime_dir: String = "") -> Dictionary:
	if profile not in ["baseline","grounding","integrated"]:
		return {"ok":false,"profile":visual_trial_profile,"replaced":[],"diagnostics":["unknown visual trial profile: "+profile]}
	if not is_node_ready():
		return {"ok":false,"profile":visual_trial_profile,"replaced":[],"diagnostics":["configure trial after scene ready"]}
	var replacements: Dictionary = plant_visuals.prepare_trial_replacements(runtime_dir if profile == "integrated" else "")
	var problems: Array = replacements["diagnostics"].duplicate()
	var prepared_grounding = _trial_grounding
	var prepared_environment = null
	if profile != "baseline":
		if prepared_grounding == null:
			prepared_grounding = TrialGrounding.new("res://content/farming/p8/grounding.json") if production_visuals else TrialGrounding.new()
		problems.append_array(prepared_grounding.diagnostics)
	if profile == "integrated":
		prepared_environment = _make_trial_environment()
		if prepared_environment == null: problems.append("trial environment module unavailable; current profile retained")
		else: problems.append_array(prepared_environment.prepare_assets())
	# Nothing live changes until every requested trial component is ready.
	if not problems.is_empty():
		return {"ok":false,"profile":visual_trial_profile,"requested_profile":profile,"replaced":[],"diagnostics":problems}
	if trial_environment != null: trial_environment.restore(self)
	trial_environment = prepared_environment
	_trial_grounding = prepared_grounding
	plant_visuals.commit_trial_replacements(replacements)
	visual_trial_profile = profile
	if trial_environment != null: trial_environment.apply(self)
	overlay.queue_redraw()
	return {"ok":true,"profile":profile,"replaced":replacements["replaced"],"diagnostics":problems}

func _make_trial_environment():
	if production_visuals: return ProductionEnvironment.new()
	var path := "res://scripts/farming/p8/p86_environment_trial.gd"
	if not ResourceLoader.exists(path): return null
	var environment_script = load(path)
	return environment_script.new() if environment_script != null and environment_script.can_instantiate() else null

func _draw_contact(target: Node2D, contact: Dictionary, modulation: Color = Color.WHITE) -> void:
	if contact.is_empty(): return
	target.draw_texture_rect(contact["texture"],contact["rect"],false,contact.get("color",Color.WHITE)*modulation)

func _draw_resource_points(target: Node2D, readable: float) -> void:
	if visual_trial_profile != "integrated" or trial_environment == null:
		super(target,readable)
		return
	for ident in world.source_defs:
		var definition: Dictionary = world.source_defs[ident]
		var position := Vector2(float(definition["position"][0]),float(definition["position"][1]))*64.0
		var visual: Dictionary = trial_environment.source_visual(ident,Rect2(position,Vector2(64,64)))
		if visual.is_empty():
			target.draw_rect(Rect2(position+Vector2(4,4),Vector2(56,56)),Color("deedf0"))
			target.draw_texture_rect(Icons.get_icon(definition["item"]),Rect2(position+Vector2(8,8),Vector2(48,48)),false)
		if world.workforce.state["sources"].has(ident): target.draw_circle(position+Vector2(52,12),5*readable,UI.JADE)

func _refresh() -> void:
	super()
	guide_hint.text = guide_hint.text.replace("WASD平移","WASD/中键平移")
	var stamp := ",".join(PackedStringArray(world.land.to_save()["purchased"]))
	if stamp != _land_stamp:
		_land_stamp = stamp
		terrain.refresh_all()
		overlay.queue_redraw()

func _show_land(focus: String = "") -> void:
	_context = "land"
	_land_focus = focus
	_page("购地 · 连续农场与水库")
	var land_area := 0
	var water_area := 0
	var spent := 0
	for id in world.land.purchased:
		var parcel: Dictionary = world.land.parcels[id]
		var area: Rect2i = world.land.rect(parcel["rect"])
		if parcel["terrain"] == "water": water_area += area.get_area()
		else: land_area += area.get_area()
		spent += int(parcel["price"])
	_label(sidebar,"已增陆地%d格 · 水面%d格 · 累计购地%d元石（计入建设支出）。" % [land_area, water_area, spent])
	_label(sidebar,"购地0AP，每日结束保存。新地仍须开垦，水场整体占地必须已购；不赠送动物/建材，也不增加泉水日产量。所有区域共享仓库、人力和时间，各水场水体独立。")
	for id in world.land.parcels:
		if not focus.is_empty() and id != focus: continue
		var parcel: Dictionary = world.land.parcels[id]
		var quote: Dictionary = world.land.quote(id)
		var area: Rect2i = world.land.rect(parcel["rect"])
		var card := _card(sidebar)
		_heading(card, parcel["name"] + (" · 已购买" if quote["owned"] else " · 未购买"))
		_label(card,"%s%d格 · %d元石 · 左上(%d,%d)，%d×%d" % ["水面" if parcel["terrain"] == "water" else "陆地", area.get_area(), parcel["price"], area.position.x, area.position.y, area.size.x, area.size.y])
		if not quote["owned"]:
			_label(card,"当前%d元石 · 购买后%d元石%s" % [world.primeval_stones, quote["remaining"], " · " + quote["reason"] if not quote["ok"] else ""])
		var row := HBoxContainer.new()
		card.add_child(row)
		_icon(row,"locate","定位与预览购买边界",_locate_land.bind(id))
		if not quote["owned"]:
			var buy := _icon(row,"claim","购买%s · %d元石 · 0AP" % [parcel["name"],parcel["price"]],_confirm_land.bind(id))
			buy.set_meta("land_buy",id)
			buy.disabled = not quote["ok"]
	if not focus.is_empty(): _icon(sidebar,"back","查看全部地块",_show_land)

func _confirm_land(id: String) -> void:
	var quote: Dictionary = world.land.quote(id)
	if not quote["ok"]: _result(quote); _show_land(id); return
	var parcel: Dictionary = world.land.parcels[id]
	_confirm("购买%s？支付%d元石，余额%d；0AP，永久开放，日结保存。" % [parcel["name"],quote["price"],quote["remaining"]],func():
		_result(world.land.buy(id))
		_show_land(id))

func _locate_land(id: String) -> void:
	_land_focus = id
	var area: Rect2i = world.land.rect(world.land.parcels[id]["rect"])
	_close_page()
	camera.position = Vector2(area.position + area.size/2)*64
	selected = area.position
	overlay.queue_redraw()

func _apply_manual(cell: Vector2i) -> void:
	if not logistics_ui.placing.is_empty():
		var row: Dictionary = world.logistics.instance(logistics_ui.placing)
		if row.is_empty():
			logistics_ui.placing = ""
			_result({"ok":false,"reason":"当前存档没有此实例，请从后勤管理页重新选择"})
			return
		var host_uid := int(world.facility_at(cell).get("uid",0)) if world.logistics.definition(row)["deployment"] == "host" else 0
		_result(world.logistics.deploy(logistics_ui.placing,cell,host_uid))
		if world.logistics.deployed(world.logistics.instance(logistics_ui.placing)): logistics_ui.placing = ""
		selected = cell
		_show_cell()
		return
	var parcel: String = world.land.at(cell)
	if _started and not parcel.is_empty() and not world.land.contains(cell):
		selected = cell
		_show_land(parcel)
		return
	super(cell)

func _show_cell() -> void:
	var gu: Dictionary = world.logistics.at(selected)
	if not gu.is_empty():
		_context = "cell"
		_page("后勤生产蛊")
		logistics_ui.focused = gu["instance_id"]
		logistics_ui.card(gu,sidebar)
		return
	var parcel: String = world.land.at(selected)
	if not parcel.is_empty() and not world.land.contains(selected):
		_show_land(parcel)
		return
	super()
	if _started and world.grid.in_bounds(selected.x,selected.y):
		_label(sidebar,"铺面：%s" % {"ordinary":"普通地板","farmland":"耕地","natural":"自然地面"}[world.rooms.floor_kind(selected)])
		_button(sidebar,"农业区与地板",rooms_ui.open)

func _board_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed: rooms_ui.floor_tool=""
	if _started and not shade.visible and not is_instance_valid(confirmation) and not rooms_ui.floor_tool.is_empty() and event is InputEventMouseMotion and not _map_pan:
		_hover=_cell(event.position)
		var change: Dictionary=world.rooms.preview_floor(_hover,rooms_ui.floor_tool)
		hover_hint.text=change.get("summary",change.get("reason",""))
		hover_hint.tooltip_text=hover_hint.text
		overlay.queue_redraw()
		return
	if _started and not shade.visible and not is_instance_valid(confirmation) and not rooms_ui.floor_tool.is_empty() and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if not event.pressed:
			_drag=false
			selected=_cell(event.position)
			_result(world.rooms.set_floor(selected,rooms_ui.floor_tool))
			_show_cell()
			overlay.queue_redraw()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed: logistics_ui.placing = ""
	if _started and not shade.visible and not is_instance_valid(confirmation) and not _text_focus():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
			_map_pan = event.pressed
			return
		if event is InputEventMouseMotion and _map_pan:
			if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
				camera.position -= event.relative / camera.zoom
				hover_hint.text = ""
				overlay.queue_redraw()
				return
			_map_pan = false
		# Station placement carries the chosen facing; every other build keeps
		# the shared base path unchanged.
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed \
				and build_tool == "field_service_station" and _drag:
			_drag = false
			_drag_end = _cell(event.position)
			selected = _drag_end
			# The P8 world takes the orientation; the base class signature stays 2-arg.
			var p8w: Variant = world
			_result(p8w.build_facility(selected,build_tool,build_facing))
			_show_cell()
			overlay.queue_redraw()
			return
	else:
		_map_pan = false
	super(event)
	if event is InputEventMouseMotion and _started and not shade.visible:
		var cell := _cell(event.position)
		var id: String = world.land.at(cell)
		if not id.is_empty() and not world.land.contains(cell):
			hover_hint.text = "%s · %d元石 · 点击查看购买条件" % [world.land.parcels[id]["name"],world.land.parcels[id]["price"]]

func _draw_world_entities(target: Node2D, readable: float) -> void:
	rooms_ui.draw_ground(target,false)
	var entities: Array[Dictionary] = []
	for uid in world.crops:
		var crop: Dictionary = world.crops[uid]
		var definition: Dictionary = world.crop_defs[crop["crop_id"]]
		var shape: Array = definition["footprint"]
		var rect := Rect2(Vector2(float(crop["origin"][0]),float(crop["origin"][1]))*64.0,Vector2(float(shape[0]),float(shape[1]))*64.0)
		var visual: Dictionary = plant_visuals.visual(crop, definition, world.flowers.settings["oilseed_window"])
		if visual.is_empty():
			target.draw_rect(rect.grow(-7),Color("deebd9") if crop["state"] != "mature" else Color("f1e2b1"))
		entities.append({"kind": "crop", "id": int(uid), "data": crop, "rect": rect,
			"root": plant_visuals.ground_root(crop["origin"], shape), "visual": visual})
	for uid in world.facilities:
		var building: Dictionary = world.facilities[uid]
		var shape: Array = world.facility_defs[building["facility_id"]]["footprint"]
		var rect := Rect2(Vector2(float(building["origin"][0]),float(building["origin"][1]))*64.0,Vector2(float(shape[0]),float(shape[1]))*64.0)
		var visual: Dictionary = facility_visuals.visual(String(building["facility_id"]),rect)
		if visual.is_empty(): target.draw_rect(rect.grow(-5),Color("eee5d6"))
		entities.append({"kind": "facility", "id": int(uid), "data": building, "rect": rect,
			"root": rect.get_center(), "visual": visual})
	if visual_trial_profile == "integrated" and trial_environment != null:
		for ident in world.source_defs:
			var definition: Dictionary = world.source_defs[ident]
			var rect := Rect2(Vector2(float(definition["position"][0]),float(definition["position"][1]))*64.0,Vector2(64,64))
			var visual: Dictionary = trial_environment.source_visual(ident,rect)
			if not visual.is_empty():
				entities.append({"kind":"source","id":0,"source_id":ident,"data":definition,"rect":rect,"root":visual["root"],"visual":visual})
	# Ground contacts stay below every world body; bodies keep the approved root order.
	if visual_trial_profile != "baseline" and _trial_grounding != null:
		for entity in entities:
			if entity["visual"].is_empty(): continue
			if entity["kind"] == "crop":
				_draw_contact(target,_trial_grounding.crop_shadow(entity["data"]["crop_id"],entity["visual"]["key"],entity["root"]))
			elif entity["kind"] == "facility":
				_draw_contact(target,_trial_grounding.facility_shadow(entity["data"]["facility_id"],entity["root"]))
			else:
				_draw_contact(target,_trial_grounding.source_shadow(entity["source_id"],entity["root"]))
	entities.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["root"].y != b["root"].y: return a["root"].y < b["root"].y
		if a["root"].x != b["root"].x: return a["root"].x < b["root"].x
		if a["kind"] != b["kind"]: return a["kind"] < b["kind"]
		return a["id"] < b["id"])
	for entity in entities:
		var rect: Rect2 = entity["rect"]
		if entity["kind"] == "crop":
			var visual: Dictionary = entity["visual"]
			if visual.is_empty():
				target.draw_texture_rect(Icons.get_icon(entity["data"]["crop_id"]),Rect2(rect.position+Vector2(10,8),rect.size-Vector2(20,20)),false)
			else:
				target.draw_texture_rect(visual["texture"], visual["rect"], false)
		elif entity["kind"] == "facility":
			var visual: Dictionary = entity["visual"]
			if visual.is_empty(): target.draw_texture_rect(Icons.get_icon(entity["data"]["facility_id"]),rect.grow(-14),false)
			else: target.draw_texture_rect(visual["texture"],visual["rect"],false)
		else:
			var visual: Dictionary = entity["visual"]
			target.draw_texture_rect(visual["texture"],visual["rect"],false)
	# All readiness markers follow every world entity, never underneath a tree.
	for entity in entities:
		var rect: Rect2 = entity["rect"]
		if entity["kind"] == "crop":
			if entity["data"]["state"] == "mature": target.draw_circle(rect.end-Vector2(10,10),5*readable,UI.JADE)
			elif entity["data"]["state"] == "regrowing": target.draw_arc(rect.end-Vector2(10,10),5*readable,0,TAU,16,UI.WATER,2*readable)
		elif entity["kind"] == "facility" and entity["data"]["batch"].get("status") == "ready": target.draw_circle(rect.end-Vector2(10,10),6*readable,UI.WATER)

func _draw_facility_preview(target: Node2D, rect: Rect2) -> void:
	var visual: Dictionary = facility_visuals.visual(build_tool,rect)
	if visual.is_empty(): super(target,rect)
	else:
		if visual_trial_profile != "baseline" and _trial_grounding != null:
			_draw_contact(target,_trial_grounding.facility_shadow(build_tool,visual["root"]),Color(1,1,1,0.65))
		target.draw_texture_rect(visual["texture"],visual["rect"],false,Color(1,1,1,0.65))

func draw_map(target: Node2D) -> void:
	super(target)
	# Build preview for the agriculture station: the directed service zone that
	# the placement will lock in, clipped to the map like the runtime zone.
	if build_tool == "field_service_station" and _started and world.grid.in_bounds(_hover.x,_hover.y):
		var def: Dictionary = world.facility_defs[build_tool]
		var zone: Rect2i = world.logistics.directed_zone(_hover, def["footprint"], build_facing).intersection(world.grid.bounds())
		if zone.size.x > 0 and zone.size.y > 0:
			var zone_rect := Rect2(Vector2(zone.position)*64,Vector2(zone.size)*64)
			target.draw_rect(zone_rect,Color("e8d9a0",0.18))
			target.draw_rect(zone_rect,Color("e8d9a0"),false,2)
	var font := theme.default_font
	var readable := maxf(1.0, 1.0/(camera.zoom.x*_ui_scale))
	for id in world.land.parcels:
		var parcel: Dictionary = world.land.parcels[id]
		var area: Rect2i = world.land.rect(parcel["rect"])
		var boundary := Rect2(Vector2(area.position)*64,Vector2(area.size)*64)
		if id not in world.land.purchased:
			var color := Color("dce9ee") if parcel["terrain"] == "water" else Color("e4ead7")
			target.draw_rect(boundary.grow(-2),color)
			target.draw_rect(boundary.grow(-2),UI.JADE,false,readable)
			var caption := "%s\n%d元石" % [parcel["name"],parcel["price"]] if boundary.size.x*camera.zoom.x*_ui_scale > 120 else str(parcel["price"])
			target.draw_multiline_string(font,boundary.position+Vector2(8,24*readable),caption,HORIZONTAL_ALIGNMENT_CENTER,boundary.size.x-16,int(14*readable),2,UI.JADE)
		if id == _land_focus: target.draw_rect(boundary,UI.JADE,false,3*readable)

func _extra_nav() -> void:
	super()
	_icon(top_nav,"area","农业区 · 地板与收获奖励",rooms_ui.open)
	_icon(top_nav,"growth_gu","后勤蛊 · 入驻、生产与维护",logistics_ui.open)
	_icon(top_nav,"research_bench","研究 · 三层工艺网络",_show_research)
	_icon(top_nav,"area","购地 · 陆地与东西侧水库",_show_land)

func _water_action_text(quote: Dictionary) -> String:
	if not quote["ok"]:
		return "换水：%s" % String(quote["reason"])
	return "换水：%s → 水体+%d、污水+%d（每场每日一次，1AP）" % [_materials(quote["inputs"]), int(quote["gain"]), int(quote.get("wastewater", 0))]

## Market item card: jump into the encyclopedia entry for this item.
func _market_extra(card: Node, item_id: String) -> void:
	_encyclopedia_link(card,"resource:" + String(item_id))

## Research-gated seeds/cultures stay visible but explicitly non-purchasable.
func _market_lock_text(item_id: String) -> String:
	if not world._items.has(item_id):
		return ""
	return world.research_block(String(world._items[item_id].get("research", "")))

## Build catalog keeps every registered facility visible; gated ones show the
## lock reason instead of a placement button.
func _show_build() -> void:
	rooms_ui.floor_tool=""
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
		_encyclopedia_link(row,"facility:" + String(ident))
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
			if ident == "field_service_station":
				var facing_row := HBoxContainer.new()
				card.add_child(facing_row)
				_label(facing_row,"朝向")
				var facing_choice := OptionButton.new()
				for dir in ["east","south","west","north"]:
					facing_choice.add_item(logistics_ui.FACING_NAMES[dir]+"向")
					facing_choice.set_item_metadata(facing_choice.item_count-1, dir)
				facing_choice.selected = ["east","south","west","north"].find(build_facing)
				facing_choice.item_selected.connect(func(index): build_facing = String(facing_choice.get_item_metadata(index)))
				facing_row.add_child(facing_choice)
				_label(card,"蛊服务区在朝向侧3×3，建造时选定；之后转向1AP、次日开日生效。")
			_icon(card,"build","放置 "+definition["name"],func():
				_close_page()
				_select_tool("inspect")
				build_tool = ident
				notice.text = "放置%s · 占地%d×%d，%d元石+%s%s · 右键取消" % [definition["name"],definition["footprint"][0],definition["footprint"][1],definition["cash"],_materials(definition["materials"]),
					(" · 服务区%s向3×3" % logistics_ui.FACING_NAMES[build_facing]) if ident == "field_service_station" else ""])

## Non-habitat panels: research benches explain the pending system, recipe cards
## carry an explicit lock line and stay unstartable while gated.
func _show_facility(facility: Dictionary) -> void:
	logistics_ui.host_section(int(facility["uid"]))
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
	_encyclopedia_link(sidebar,"facility:" + String(facility["facility_id"]))
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

## P8 owns its handbook: the unified reading entry keeps the tutorial chapters
## and adds the encyclopedia tab. Reading either tab never touches gameplay.
var _help_mode := "guide"

func _encyclopedia_link(parent: Node, entity_id: String) -> Button:
	if not encyclopedia.has(entity_id):
		return null
	var button := _icon(parent,"locate","百科：%s" % encyclopedia.name_of(entity_id),func(): encyclopedia.open(entity_id))
	button.set_meta("encyclopedia_link",entity_id)
	return button

func _context_refresh() -> void:
	if _context == "rooms": rooms_ui.open(); return
	if _context == "logistics": logistics_ui.open()
	if _context == "encyclopedia":
		encyclopedia.refresh()

func _show_report() -> void:
	super()
	rooms_ui.report(sidebar)
	if not world.logistics.state["provisioned"]: return
	var card := _card(sidebar)
	_heading(card,"后勤蛊 · 实际维护与生产")
	_label(card,"后勤维护元石计入采购支出，特殊食料与稻米收取计入实际资源出入库；待收产物不计入库存。")
	_label(card,"累计已付维护%d元石；当日开日维护属于当日，不写入前一日或已冻结回顾。" % int(world.logistics.state["spent"]))
	for bill in world.logistics.state["history"]:
		if int(bill["fees"]) > 0:
			_label(card,"服务日%d：维护%d元石，食料%s" % [int(bill["day"])+1,int(bill["fees"]),logistics_ui.items_text(bill["food"])])
	_icon(card,"growth_gu","查看部署、生产进度与收取",logistics_ui.open)

func _result(result: Dictionary) -> void:
	super(result)
	var receipt: String=rooms_ui.result_text(result)
	if receipt.is_empty(): return
	notice.text=receipt
	notice.tooltip_text=receipt
	window_feedback.text=receipt
	window_feedback.tooltip_text=receipt

func _show_help() -> void:
	_context = "help"
	_page("手册 · 新手引导与百科")
	var tabs := HBoxContainer.new()
	sidebar.add_child(tabs)
	var guide_tab := _button(tabs,"新手引导",func(): _help_mode = "guide"; _show_help())
	guide_tab.toggle_mode = true
	guide_tab.button_pressed = _help_mode == "guide"
	var wiki_tab := _button(tabs,"百科目录",func(): _help_mode = "encyclopedia"; _show_help())
	wiki_tab.toggle_mode = true
	wiki_tab.button_pressed = _help_mode == "encyclopedia"
	if _help_mode == "encyclopedia":
		encyclopedia.render_into(sidebar)
		return
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
				var estimate: Dictionary = world.research.quote_start(uid,startable[index])
				selector.add_item("%s · %d元石＋%s · 预计%d有效工作日" % [def["name"], int(estimate["fee"]), _materials(estimate["samples"]), int(estimate["days"])])
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
		var target := maxi(1,int(def["days"])-int(active["gu"]["flat"]))
		_heading(sidebar,"%s · %d/%d工作量" % [def["name"], int(active["progress"]), target])
		_label(sidebar,"基础%d − 固定减免%d → 目标%d；每有效工作日推进%d；样本倍率%.2f，逐项向上取整。" % [int(def["days"]),int(active["gu"]["flat"]),target,int(active["gu"]["speed"]),float(active["gu"]["materials"])/100.0])
		_encyclopedia_link(sidebar,"research:" + String(active["id"]))
		_bar(sidebar,"研究进度",int(active["progress"]),target)
		_label(sidebar,"样本与启动费已支付；每天一次研究工作：手动1AP，或由负责人日结执行（1元石）。")
		var work_quote: Dictionary = world.research.work_quote(uid)
		if work_quote["ok"]:
			_icon(sidebar,"play","手动研究（1AP，登记今日收据）",func(): _result(world.research.work(uid)); _show_cell())
		else:
			_label(sidebar,String(work_quote["reason"]))
		var pause := _icon(sidebar,"cancel","暂停/恢复（保留投入与进度）",func(): _result(world.research.set_paused(uid, not bool(active["paused"]))); _show_cell())
		pause.text = "恢复研究" if bool(active["paused"]) else "暂停研究"
		_icon(sidebar,"clear","取消研究（样本/费用不退）",func(): _confirm("取消研究？已付样本与元石不退，进度清零。",func(): _result(world.research.cancel(uid)); _show_cell()))
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
			_encyclopedia_link(card,"research:" + String(project_id))
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
	logistics_ui.crop_agriculture(sidebar, crop)
	rooms_ui.crop_details(sidebar,crop)
	_encyclopedia_link(sidebar,"crop:" + String(crop["crop_id"]))
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
	_encyclopedia_link(sidebar,"species:" + String(habitat["species_id"]))
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
		var gu_mode: bool = not world.logistics.in_host(uid).is_empty()
		if gu_mode: _label(sidebar,"当前为明光蛊供能模式：不消耗精炼油，休眠不自动回退。光照与费用见上方蛊虫槽。")
		var enabled := CheckButton.new()
		enabled.text = "启用补光（覆盖内有作物时每日精炼油1）"
		enabled.button_pressed = not device.is_empty() and bool(device.get("enabled", false))
		enabled.disabled = gu_mode
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
