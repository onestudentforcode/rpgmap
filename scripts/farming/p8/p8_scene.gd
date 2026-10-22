extends "res://scripts/farming/v2/v2_scene.gd"
## P8 local demo: independent slots/settings, research-gated ecology production,
## shared facility owners, and the beginner handbook.
const P8World := preload("res://scripts/farming/p8/p8_world.gd")
const P8Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const Handbook := preload("res://scripts/farming/p8/p8_handbook.gd")
const PlantVisuals := preload("res://scripts/farming/p8/p8_plant_visuals.gd")
var plant_visuals := PlantVisuals.new()
var plant_profile := "legacy"
var _plant_profiles: Dictionary = {}
const PLANT_PROFILES := {
	"legacy":"res://assets/farming/crops/plant_manifest.json",
	"p109":"res://assets/farming/p109/runtime/plant_manifest.json",
}
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
const RanchUI := preload("res://scripts/farming/p8/p103_ui.gd")
const ServicesUI := preload("res://scripts/farming/p8/p104_ui.gd")
var rooms_ui := RoomsUI.new(self)
var ranch_ui := RanchUI.new(self)
var services_ui := ServicesUI.new(self)
const EconomyUI := preload("res://scripts/farming/p8/p107_ui.gd")
var economy_ui := EconomyUI.new(self)
const BatchUI := preload("res://scripts/farming/p8/p108_batch.gd")
const Tutorial := preload("res://scripts/farming/p8/p108_tutorial.gd")
const P8Workforce := preload("res://scripts/farming/p8/p8_workforce.gd")
var selected_crop := "golden_wheat"
var crop_picker: OptionButton
var copy_config: Dictionary = {}
var tutorial_panel: PanelContainer
var tutorial_scroll: ScrollContainer
var tutorial_body: VBoxContainer
var reading_expanded := false
var reading_font := 1
var _help_scroll_anchor := 0
var _tutorial_compact_mode := false

func _new(slot: int, overwrite: bool) -> void:
	copy_config.clear()
	rooms_ui.floor_tool=""
	rooms_ui.field_tool=false
	logistics_ui.placing=""
	super(slot,overwrite)

func _select_tool(kind: String) -> void:
	rooms_ui.floor_tool=""
	rooms_ui.field_tool=false
	super(kind)
	if crop_picker != null: crop_picker.visible = kind == "plant" and manual_mode and _started and not shade.visible
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

func _economy_link() -> void:
	var button := _button(sidebar, "产业成长与以物换物", economy_ui.open)
	button.set_meta("p107_navigation", true)
	sidebar.move_child(button, 0)

func _show_market() -> void:
	super()
	_economy_link()

func _show_orders() -> void:
	super()
	_economy_link()

func _ready() -> void:
	super()
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	board.mouse_exited.connect(func(): _map_pan = false)
	_load_reading_preferences()
	var style: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/farming/p8/world_visuals.json"))
	var requested_plants := String(style.get("plant_profile", "legacy"))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--plants="): requested_plants = argument.trim_prefix("--plants=")
	var plant_result := configure_plant_profile(requested_plants)
	if not plant_result["ok"]: push_error("Plant profile retained: %s" % plant_result["diagnostics"])
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

func configure_plant_profile(profile: String) -> Dictionary:
	if not PLANT_PROFILES.has(profile):
		return {"ok":false,"profile":plant_profile,"diagnostics":["unknown plant profile: " + profile]}
	if _plant_profiles.is_empty(): _plant_profiles[plant_profile] = plant_visuals
	var candidate = _plant_profiles.get(profile)
	if candidate == null: candidate = PlantVisuals.new(PLANT_PROFILES[profile])
	# Full species/stage sets must load before replacing any live visuals.
	var problems: Array = candidate.diagnostics.values()
	if candidate.plants.keys().size() != plant_visuals.plants.keys().size(): problems.append("plant species count mismatch")
	for ident in plant_visuals.plants:
		if not candidate.plants.has(ident):
			problems.append("missing plant: " + ident)
			continue
		for key in plant_visuals.plants[ident]["stages"]:
			if not candidate.plants[ident]["stages"].has(key): problems.append("missing plant stage: %s/%s" % [ident,key])
	if not problems.is_empty(): return {"ok":false,"profile":plant_profile,"diagnostics":problems}
	_plant_profiles[profile] = candidate
	plant_visuals = candidate
	plant_profile = profile
	if is_instance_valid(overlay): overlay.queue_redraw()
	if has_method("invalidate_projection_bounds"): call("invalidate_projection_bounds")
	return {"ok":true,"profile":plant_profile,"diagnostics":[]}

func _show_settings() -> void:
	super()
	_label(sidebar,"植物美术预览（本次运行生效）")
	var picker := OptionButton.new()
	picker.add_item("P10.9 新植物")
	picker.add_item("旧版植物")
	picker.select(0 if plant_profile == "p109" else 1)
	picker.item_selected.connect(func(index):
		var result := configure_plant_profile("p109" if index == 0 else "legacy")
		if not result["ok"]:
			picker.select(0 if plant_profile == "p109" else 1)
			_result(result))
	sidebar.add_child(picker)

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
	if tutorial_panel != null: _refresh_tutorial()
	if crop_picker != null: crop_picker.visible = tool == "plant" and manual_mode and _started and not shade.visible
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
	if manual_mode and tool=="plant":
		selected=cell
		_result(world.plant_manual(cell,selected_crop))
		_show_cell()
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
		var field: Dictionary = world.rooms.field_at(selected)
		if not field.is_empty(): _label(sidebar,"所属田块：%s（#%d）" % [field["name"],field["uid"]])
		_button(sidebar,"农业区与地板",rooms_ui.open)
		var ranch_here: bool = not world.facility_at(selected).is_empty() and (
			world.ranch.is_structural(String(world.facility_at(selected)["facility_id"]))
			or String(world.facility_at(selected)["facility_id"]) in ["dispatch_station","feed_trough","small_bed","medium_bed","large_bed","care_table","soothing_station","toy_station"])
		if ranch_here:
			_button(sidebar,"畜牧分区",ranch_ui.open)
	if _started and world.grid.in_bounds(selected.x,selected.y):
		var crop := world.instance_at(selected)
		var facility := world.facility_at(selected)
		var copy := _button(sidebar,"复制此处配置",func(): _copy_from_cell(selected))
		copy.tooltip_text = "仅复制首版白名单中的选种计划、通用加工策略或田间维护站开关"
		if crop.is_empty() and facility.is_empty() and world.rooms.floor_kind(selected) != "farmland": copy.disabled = true

func _board_input(event: InputEvent) -> void:
	if _started and not shade.visible and not is_instance_valid(confirmation) and rooms_ui.field_tool and _context == "rooms":
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			rooms_ui.open()
			return
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _text_focus():
			rooms_ui.click_field(_cell(event.position))
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if not copy_config.is_empty():
			copy_config.clear()
			notice.text="已取消配置粘贴"
			return
		rooms_ui.floor_tool=""
		ranch_ui.toggle_erase()
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
	if _started and not shade.visible and not is_instance_valid(confirmation) and event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _drag and not _text_focus():
		var end_cell := _cell(event.position)
		var drag_rect := _rect(_drag_start,end_cell)
		_drag = false
		selected = end_cell
		if not copy_config.is_empty():
			_run_copy_rectangle(drag_rect)
			return
		if manual_mode and tool in ["till","plant","irrigate","fertilize","harvest","fell","clear"]:
			if tool in ["fell","clear"] and drag_rect.get_area() > 1:
				var count := _batch_candidate_count(drag_rect,tool)
				_confirm("批量%s %d株？该操作会移除作物；每株仍消耗1AP。" % [NAMES[tool],count],func(): _run_manual_rectangle(drag_rect))
			else: _run_manual_rectangle(drag_rect)
			return
	# Inspection is navigation, not an agricultural action: bypass batch planning
	# and the inherited manual-action path so even resource points refresh at once.
	if _started and not shade.visible and not is_instance_valid(confirmation) and not _text_focus() \
			and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed \
			and not _map_pan and tool=="inspect" and copy_config.is_empty() and logistics_ui.placing.is_empty():
		_drag=false
		selected=_cell(event.position)
		_side_open=true
		_show_cell()
		_layout()
		overlay.queue_redraw()
		return
	if _started and not shade.visible and not is_instance_valid(confirmation) and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed 			and (not ranch_ui.zone_tool.is_empty() or ranch_ui.paint_zone > 0) and not _text_focus():
		selected=_cell(event.position)
		ranch_ui.click_cell(selected)
		overlay.queue_redraw()
		return
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
		if _drag and manual_mode and tool in ["till","plant","irrigate","fertilize","harvest","fell","clear"]:
			var plan: Dictionary=BatchUI.preview(world,_rect(_drag_start,_drag_end),tool,selected_crop)
			hover_hint.text="%s · 可执行%d · 无效%d · 预算%d AP · %s%s" % [NAMES[tool],plan["targets"],plan["invalid"].size(),plan["ap"],String(plan["blocked"]) if not String(plan["blocked"]).is_empty() else "按地格顺序",(" · 投入 "+_materials(plan["inputs"])) if not plan["inputs"].is_empty() else ""]
			hover_hint.tooltip_text=hover_hint.text
			overlay.queue_redraw()
		var id: String = world.land.at(cell)
		if not id.is_empty() and not world.land.contains(cell):
			hover_hint.text = "%s · %d元石 · 点击查看购买条件" % [world.land.parcels[id]["name"],world.land.parcels[id]["price"]]

func _draw_batch_preview(target: Node2D, rect: Rect2i, readable: float) -> void:
	var plan: Dictionary=BatchUI.preview(world,rect,tool,selected_crop)
	for action in plan["actions"]:
		var cell: Vector2i=action["cell"]
		var shape: Array=world.crop_defs[selected_crop]["footprint"] if tool=="plant" else [1,1]
		target.draw_rect(Rect2(Vector2(cell)*64,Vector2(float(shape[0]),float(shape[1]))*64),Color(0.35,0.65,0.4,0.32))
	for invalid in plan["invalid"]:
		var cell: Vector2i=invalid["cell"]
		target.draw_rect(Rect2(Vector2(cell)*64,Vector2(64,64)),Color(0.7,0.25,0.2,0.26))
	if tool=="plant" and world.crop_defs.has(selected_crop):
		for cell in BatchUI.cells(rect):
			var shape: Array=world.crop_defs[selected_crop]["footprint"]
			var rect_crop:=Rect2i(cell,Vector2i(int(shape[0]),int(shape[1])))
			if rect.get_area()>1 and not rect.encloses(rect_crop): target.draw_rect(Rect2(Vector2(cell)*64,Vector2(64,64)),Color(0.7,0.25,0.2,0.22))

func _extra_hud() -> void:
	super()
	crop_picker = OptionButton.new()
	crop_picker.custom_minimum_size = Vector2(210,34)
	for ident in world.crop_defs:
		var definition: Dictionary = world.crop_defs[ident]
		if String(definition.get("medium","land")) == "water": continue
		var crop_name := String(definition.get("name", String(CROPS.get(String(ident), String(ident)))))
		crop_picker.add_item(crop_name)
		crop_picker.set_item_metadata(crop_picker.item_count-1,String(ident))
		if String(ident) == selected_crop: crop_picker.select(crop_picker.item_count-1)
	crop_picker.item_selected.connect(func(index): selected_crop=String(crop_picker.get_item_metadata(index)); _update_hover())
	ui_root.add_child(crop_picker)
	tutorial_panel = PanelContainer.new()
	tutorial_panel.visible = false
	ui_root.add_child(tutorial_panel)
	tutorial_scroll = ScrollContainer.new()
	tutorial_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tutorial_scroll.custom_minimum_size.y = 48
	tutorial_panel.add_child(tutorial_scroll)
	tutorial_body = VBoxContainer.new()
	tutorial_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tutorial_scroll.add_child(tutorial_body)
	_refresh_tutorial()

func _layout_extra() -> void:
	super()
	if crop_picker != null:
		crop_picker.position=Vector2(toolbar_panel.position.x,toolbar_panel.position.y-40)
		crop_picker.visible=_started and not shade.visible and manual_mode and tool=="plant"
	if tutorial_panel != null:
		var margin := 24.0 if ui_root.size.x >= 1600 else 12.0
		var available_width := maxf(220.0, minf(340.0,board.size.x*0.42))
		var compact_guidance := ui_root.size.x < 1100.0 or ui_root.size.y < 650.0
		if compact_guidance != _tutorial_compact_mode:
			_tutorial_compact_mode=compact_guidance
			_refresh_tutorial()
		tutorial_scroll.custom_minimum_size.y=48.0
		tutorial_panel.reset_size()
		var resource_bottom := 124.0
		if watch_panel != null and watch_panel.visible:
			resource_bottom = maxf(resource_bottom,watch_panel.position.y+maxf(watch_panel.size.y,watch_panel.get_combined_minimum_size().y))
		tutorial_panel.position=Vector2(margin+8,resource_bottom+8)
		tutorial_panel.custom_minimum_size.x=available_width
		tutorial_body.custom_minimum_size.x=maxf(180.0,available_width-24.0)
		var bottom_limit := toolbar_panel.position.y-8
		if crop_picker!=null and crop_picker.visible:
			bottom_limit=minf(bottom_limit,crop_picker.position.y-8)
		var available_height:=maxf(64.0,bottom_limit-tutorial_panel.position.y)
		var minimum_height:=tutorial_panel.get_combined_minimum_size().y
		var header_height:=maxf(0.0,minimum_height-tutorial_scroll.custom_minimum_size.y)
		var content_height:=tutorial_body.get_combined_minimum_size().y
		var collapsed:=bool(world.preferences.get("tutorial",{}).get("collapsed",false))
		var desired_height:=minimum_height if collapsed else header_height+maxf(48.0,content_height)
		var panel_height:=minf(desired_height,available_height)
		tutorial_panel.size=Vector2(available_width,panel_height)
		tutorial_scroll.custom_minimum_size=Vector2(available_width-24.0,maxf(48.0,panel_height-header_height))
		tutorial_panel.visible=_started and not shade.visible and bool(world.preferences.get("tutorial",{}).get("enabled",true))
	if digest!=null and digest.visible:
		digest.reset_size()
		var right_edge:=board.position.x+board.size.x-8
		var digest_width:=minf(320.0,maxf(220.0,board.size.x*0.38))
		digest.position=Vector2(maxf(board.position.x+8,right_edge-digest_width),board.position.y+8)
		digest.custom_minimum_size.x=digest_width
		if watch_panel!=null and watch_panel.visible and digest.position.x<watch_panel.position.x+watch_panel.size.x+8:
			# On compact layouts the daily digest is represented by the notice strip;
			# the full record remains available from the history page.
			digest.visible=false

func _layout() -> void:
	super()
	if window_panel==null or ui_root==null: return
	if reading_expanded and shade.visible and _context=="help":
		var margin:=12.0
		window_panel.reset_size()
		window_panel.position=Vector2(margin,100)
		window_panel.size=Vector2(maxf(320,ui_root.size.x-2*margin),maxf(240,ui_root.size.y-112))
		window_panel.add_theme_font_size_override("font_size",16+2*reading_font)
	else:
		window_panel.remove_theme_font_size_override("font_size")
	_layout_extra()

func _load_reading_preferences() -> void:
	var config:=ConfigFile.new()
	if config.load(settings.path+".reading")!=OK: return
	reading_expanded=bool(config.get_value("reading","expanded",false))
	reading_font=clampi(int(config.get_value("reading","font",1)),0,2)

func _save_reading_preferences() -> void:
	var config:=ConfigFile.new()
	config.set_value("reading","schema",1)
	config.set_value("reading","expanded",reading_expanded)
	config.set_value("reading","font",reading_font)
	var error:=config.save(settings.path+".reading")
	if error!=OK: notice.text="无法保存阅读偏好"

func _set_reading(expanded_value: bool, font_value: int) -> void:
	_help_scroll_anchor=window_scroll.scroll_vertical
	reading_expanded=expanded_value
	reading_font=clampi(font_value,0,2)
	_save_reading_preferences()
	_show_help()
	window_scroll.set_deferred("scroll_vertical",_help_scroll_anchor)
	_layout()

func _refresh_tutorial() -> void:
	if tutorial_body==null or world==null or not _started: return
	var compact_guidance := ui_root.size.x < 1100.0 or ui_root.size.y < 650.0
	for child in tutorial_body.get_children(): tutorial_body.remove_child(child);child.queue_free()
	var saved: Dictionary=world.preferences.get("tutorial",Tutorial.fresh())
	var state: Dictionary=Tutorial.progress(world,saved)
	var plan: Dictionary=Tutorial.today(world,saved)
	var header_row:=HBoxContainer.new()
	tutorial_body.add_child(header_row)
	var next: Dictionary=state["next"]
	var caption:="新手指引"
	if bool(saved.get("collapsed",false)) and not next.is_empty(): caption+=" · "+String(next["title"])
	if compact_guidance and not next.is_empty(): caption+=" · 第%d天%s"%[int(plan["day"]),"·等待" if bool(plan["waiting"]) else ""]
	_heading(header_row,caption)
	var fold:=_button(header_row,"展开" if bool(saved.get("collapsed",false)) else "收起",func(): _tutorial_pref("collapsed",not bool(saved.get("collapsed",false))))
	_icon(header_row,"close","取消指引",func(): _tutorial_pref("enabled",false))
	if not next.is_empty(): _icon(header_row,"locate","打开当前建议",func(): _open_tutorial_target(String(next["kind"])))
	if bool(saved.get("collapsed",false)): return
	if bool(state["complete"]):
		_label(tutorial_body,"主线指引已完成。你可以自由經營，或在手册中回顾路线。")
		return
	if compact_guidance:
		if not plan["items"].is_empty(): _label(tutorial_body,_tutorial_display_text(String(plan["items"][0])))
	else:
		var reference_suffix := " · 参考路线第%d天（可顺延）"%int(plan["reference_day"]) if plan.has("reference_day") else ""
		_label(tutorial_body,"第%d天%s%s" % [int(plan["day"]),reference_suffix," · 等待条件" if bool(plan["waiting"]) else " · 今日建议"])
		for item in plan["items"]: _label(tutorial_body,_tutorial_display_text(String(item)))
		_label(tutorial_body,"路线进度 %d/%d" % [state["done"].size(),Tutorial.STEPS.size()])

func _tutorial_display_text(value: String) -> String:
	var result:=value
	var ids: Array=[]
	for crop_id in CROPS: ids.append(String(crop_id))
	for item_id in world._items: ids.append(String(item_id))
	ids.sort_custom(func(a,b): return String(a).length()>String(b).length())
	for ident in ids:
		var display:=String(CROPS.get(ident,world._items.get(ident,{}).get("name",ident)))
		if display!=ident: result=result.replace(ident,display)
	return result

func _tutorial_pref(field: String,value: bool) -> void:
	var result: Dictionary=world.set_tutorial_preference(field,value)
	if not result.get("ok",false):
		notice.text="指引设置未保存："+String(result.get("reason","未知错误"))
		return
	world.changed.emit()
	_layout()

func _open_tutorial_target(kind: String) -> void:
	match kind:
		"planting": _select_tool("till")
		"harvest": _select_tool("harvest")
		"processing": _show_build()
		"research": _show_research()
		"order": _show_orders()
		"stage": economy_ui.open()
		"active_gu": logistics_ui.open()

func _run_manual_rectangle(rect: Rect2i) -> void:
	if rect.size.x<=0 or rect.size.y<=0: return
	var plan: Dictionary=BatchUI.preview(world,rect,tool,selected_crop)
	if plan["actions"].is_empty():
		notice.text="没有可执行目标"+ (" · "+String(plan["blocked"]) if not String(plan["blocked"]).is_empty() else "")
		_show_cell()
		_layout()
		overlay.queue_redraw()
		return
	var start_day:=int(world.clock.total_days)
	var completed:=0
	var failures: Array=[]
	for action in plan["actions"]:
		if int(world.clock.total_days)!=start_day or not world.daily_save_error.is_empty(): break
		var cell: Vector2i=action["cell"]
		var result: Dictionary=_execute_manual_action(cell,tool,action)
		if not result.get("ok",false):
			failures.append(String(result.get("reason","操作失败")))
			break
		if not world.daily_save_error.is_empty() or result.has("save_error"):
			failures.append("日存档失败，本次末项已回滚")
			break
		completed+=1
		if int(world.clock.total_days)!=start_day or not world.daily_save_error.is_empty(): break
	_last_cash=world.primeval_stones
	_last_ap=world.clock.ap
	_last_inventory=world.inventory.to_save()
	_refresh()
	var not_run:=maxi(0,plan["actions"].size()-completed)+int(plan["unplanned"])
	var line:="%s完成%d项" % [NAMES[tool],completed]
	if not_run>0: line+=" · 未执行%d项" % not_run
	if not String(plan["blocked"]).is_empty(): line+=" · "+String(plan["blocked"])
	if not failures.is_empty(): line+=" · "+failures[0]
	if not plan["invalid"].is_empty(): line+=" · 跳过%d个无效目标" % plan["invalid"].size()
	if not world.daily_save_error.is_empty(): line+=" · 日存档失败，请到经营记录重试"
	notice.text=line
	notice.tooltip_text=line
	_show_cell()
	_layout()

func _execute_manual_action(cell: Vector2i, kind: String, action: Dictionary={}) -> Dictionary:
	match kind:
		"till": return world.till(cell)
		"plant": return world.plant_manual(cell,String(action.get("crop_id",selected_crop)),String(action.get("variant_id","")))
		"harvest": return world.harvest(cell)
		"fell": return world.harvest(cell,"fell")
		"clear": return world.clear_crop(cell)
		"irrigate": return world.irrigate(cell)
		"fertilize": return world.fertilize(cell)
	return {"ok":false,"reason":"未知农务工具"}

func _batch_candidate_count(rect: Rect2i,kind: String) -> int:
	return int(BatchUI.preview(world,rect,kind,selected_crop)["targets"])

func _copy_from_cell(cell: Vector2i) -> void:
	var crop:=world.instance_at(cell)
	var facility:=world.facility_at(cell)
	if not facility.is_empty():
		var ident:=String(facility["facility_id"])
		if ident=="field_service_station":
			var device: Dictionary=world.devices.device_of(int(facility["uid"]))
			copy_config={"kind":"station","facility_id":ident,"irrigate":bool(device.get("irrigate",true)),"fertilize":bool(device.get("fertilize",true)),"threshold":int(device.get("threshold",world.devices.settings["station"]["threshold"]))}
		elif world.facility_defs[ident].get("kind","facility")=="facility":
			var strategy: Dictionary=world.operations.strategy_of(int(facility["uid"]))
			copy_config={"kind":"production","facility_id":ident,"strategy":strategy}
		else:
			notice.text="此设施不在首版配置复制范围内";return
	elif not crop.is_empty():
		var plan: Dictionary=world.workforce.seed_plan(Vector2i(int(crop["origin"][0]),int(crop["origin"][1])))
		copy_config={"kind":"seed","crop_id":String(plan.get("crop_id",""))}
	elif world.rooms.floor_kind(cell)=="farmland":
		var plan: Dictionary=world.workforce.seed_plan(cell)
		copy_config={"kind":"seed","crop_id":String(plan.get("crop_id",""))}
	else:
		notice.text="这里没有可复制的配置";return
	notice.text="已取样配置；拖动或点击目标地格粘贴。右键取消。"

func _run_copy_rectangle(rect: Rect2i) -> void:
	var succeeded:=0
	var skipped:=0
	var reason:=""
	var pasted_footprints: Array[Rect2i]=[]
	for cell in BatchUI.cells(rect):
		var candidate_footprint:=Rect2i()
		if String(copy_config.get("kind",""))=="seed" and not String(copy_config.get("crop_id","")).is_empty():
			var crop_shape: Array=world.crop_defs[String(copy_config["crop_id"])]["footprint"]
			candidate_footprint=Rect2i(cell,Vector2i(int(crop_shape[0]),int(crop_shape[1])))
			var duplicate_anchor:=false
			for placed in pasted_footprints:
				if placed.has_point(cell): duplicate_anchor=true;break
			if duplicate_anchor: continue
		var result: Dictionary={"ok":false,"reason":"目标类型不兼容"}
		match String(copy_config.get("kind","")):
			"seed":
				var crop_id:=String(copy_config["crop_id"])
				if crop_id.is_empty():
					if world.rooms.floor_kind(cell)=="farmland": result=world.workforce.set_seed(cell,"")
					else: result={"ok":false,"reason":"目标不是耕地"}
				else:
					var definition: Dictionary=world.crop_defs[crop_id]
					var shape: Array=definition["footprint"]
					var footprint:=Rect2i(cell,Vector2i(int(shape[0]),int(shape[1])))
					if rect.get_area()>1 and not rect.encloses(footprint): result={"ok":false,"reason":"完整占地超出框选范围"}
					else:
						var field_uid:=int(world.rooms.field_at(cell).get("uid",-1))
						var compatible:=field_uid>0
						for point in P8Workforce.footprint(footprint):
							if world.rooms.floor_kind(point)!="farmland" or int(world.rooms.field_at(point).get("uid",-2))!=field_uid: compatible=false
						if compatible: result=world.workforce.set_seed(cell,crop_id)
						else: result={"ok":false,"reason":"完整占地必须位于同一耕地田块"}
			"station", "production":
				var facility: Dictionary=world.facility_at(cell)
				if not facility.is_empty() and String(facility["facility_id"])==String(copy_config["facility_id"]):
					if copy_config["kind"]=="station":
						result=world.devices.configure_station(int(facility["uid"]),bool(copy_config["irrigate"]),bool(copy_config["fertilize"]),int(copy_config["threshold"]))
					else:
						var strategy: Dictionary=copy_config["strategy"]
						result=world.operations.copy_production(int(facility["uid"]),strategy)
		if result.get("ok",false):
			succeeded+=1
			if String(copy_config.get("kind",""))=="seed" and not String(copy_config.get("crop_id","")).is_empty(): pasted_footprints.append(candidate_footprint)
		else:
			skipped+=1
			if reason.is_empty(): reason=String(result.get("reason","目标类型不兼容"))
	copy_config.clear()
	notice.text="配置粘贴完成：成功%d处，跳过%d处%s" % [succeeded,skipped," · "+reason if not reason.is_empty() else ""]
	_show_cell()
	_layout()

func _draw_world_entities(target: Node2D, readable: float) -> void:
	rooms_ui.draw_ground(target,false)
	ranch_ui.draw_ground(target,false)
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
	_icon(top_nav,"dispatch_station","畜牧分区 · 名册、功能区与排班",ranch_ui.open)
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
	if facility["facility_id"]=="toy_station": services_ui.toy_controls(sidebar,int(facility["uid"]))
	var definition: Dictionary = world.facility_defs[facility["facility_id"]]
	var facility_id := String(facility["facility_id"])
	if facility_id == "pen" or world.ranch.is_structural(facility_id) or ["soothing_station","toy_station"].has(facility_id):
		_picture(sidebar,facility_id,64)
		_heading(sidebar,String(definition["name"]))
		_encyclopedia_link(sidebar,"facility:"+facility_id)
		var purpose:={"pen":"由畜牧分区统一管理动物与产出。","soothing_station":"在完整繁殖区提供安抚蛊槽，提升实际繁殖进度；每单位服务4空间。","toy_station":"在额外放牧区管理耐用玩具；空槽保留基础活动，装球后提供概率恢复服务。"}
		if not purpose.has(facility_id):
			purpose[facility_id] = "专属畜牧设施：在畜牧管理页安置动物、设置日程、工艺与领取产出。"
		_label(sidebar,String(purpose[facility_id]))
		_button(sidebar,"打开畜牧管理",ranch_ui.open)
		_icon(sidebar,"clear","拆除（1AP，无返还）",func(): _confirm("拆除此畜牧设施？先处理动物、在制批次与工作余量。",func(): _result(world.demolish_facility(int(facility["uid"])));_show_cell()))
		return
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
			if not world.batch_block(String(ident)).is_empty(): continue
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
	if _context == "economy": economy_ui.open(); return
	if _context == "rooms": rooms_ui.open(); return
	if _context == "ranch": ranch_ui.open(); return
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
	var reading:=HBoxContainer.new()
	sidebar.add_child(reading)
	var expand:=_button(reading,"恢复窗口" if reading_expanded else "展开阅读",func(): _set_reading(not reading_expanded,reading_font))
	expand.tooltip_text="阅读模式只改变手册/百科弹窗布局，不切换游戏窗口"
	var fonts:=OptionButton.new()
	for title in ["默认字号","较大字号","大字号"]: fonts.add_item(title)
	fonts.select(reading_font)
	fonts.item_selected.connect(func(index): _set_reading(reading_expanded,index))
	reading.add_child(fonts)
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
		var saved_tutorial: Dictionary=world.preferences.get("tutorial",Tutorial.fresh())
		var tutorial_row:=_card(sidebar)
		_heading(tutorial_row,"逐日新手指引")
		var progress: Dictionary=Tutorial.progress(world,saved_tutorial)
		if bool(saved_tutorial.get("enabled",true)):
			var next: Dictionary=progress["next"]
			_label(tutorial_row,"%d/%d步 · %s" % [progress["done"].size(),Tutorial.STEPS.size(),"已完成" if bool(progress["complete"]) else String(next["title"])])
			_icon(tutorial_row,"close","取消指引（进度保留）",func(): _tutorial_pref("enabled",false);_show_help())
		else:
			_label(tutorial_row,"指引已取消，进度保留；不会自动弹出。")
			_icon(tutorial_row,"play","恢复指引",func(): _tutorial_pref("enabled",true);_tutorial_pref("dismissed",false);_show_help())
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
	if not world.progress.block("research", project_id).is_empty(): return "locked"
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
			var stage_block: String = world.progress.block("research", String(project_id))
			if not stage_block.is_empty(): _label(card, stage_block)
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
	if world.facility_defs[String(world.facilities[int(habitat["facility_uid"])]["facility_id"])].get("species", []).size() > 1:
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
