extends "res://scripts/farming/p8/p8_scene.gd"
## Production projection shell; logical world and schema17 remain unchanged.
const GroundProjection := preload("res://scripts/farming/p8/p87_projection.gd")
const ProjectedSurface := preload("res://assets/farming/shaders/p87_surface.gdshader")
const ProjectedShore := preload("res://assets/farming/shaders/p87_shore.gdshader")
const ProjectedGrounding := preload("res://scripts/farming/p8/p87_grounding.gd")
var projection := GroundProjection.new()
var show_rulers := false
var last_entities: Array[Dictionary] = []
var _bounds_dirty := true
var _camera_view_bounds := Rect2()

func _init() -> void:
	super()
	product_title = "灵田 Demo P10 · 后勤协同"
	if OS.get_cmdline_user_args().has("--p87-smoke"):
		store = P8Store.new("user://p87_probe_slots_%d" % OS.get_process_id())
		settings = Settings.new("user://p87_probe_settings_%d.cfg" % OS.get_process_id(),0.1)

func _ready() -> void:
	super()
	configure_projection("matched35")
	world.changed.connect(invalidate_projection_bounds)
	world.grid.cells_changed.connect(invalidate_projection_bounds)
	if OS.get_cmdline_user_args().has("--p87-smoke"):
		var probe = load("res://scripts/farming/validation/p87_release_smoke.gd").new()
		probe.shell = self
		add_child(probe)
		probe.run.call_deferred()

func configure_visual_trial(profile: String, runtime_dir: String = "") -> Dictionary:
	if _trial_grounding == null: _trial_grounding = ProjectedGrounding.new()
	var result := super(profile,runtime_dir)
	if result["ok"]:
		_apply_projection_layers()
		invalidate_projection_bounds()
	return result

func configure_projection(profile: String) -> Dictionary:
	if profile not in ["p86","matched35"]: return {"ok":false,"reason":"unknown projection profile"}
	var ground_center := projection.view_to_ground(camera.position)
	projection.configure(profile == "matched35")
	camera.position = projection.ground_to_view(ground_center)
	_apply_projection_layers()
	invalidate_projection_bounds()
	overlay.queue_redraw()
	return {"ok":true,"profile":profile,"depth":projection.depth}

func _apply_projection_layers() -> void:
	for layer: TileMapLayer in terrain.layers.values():
		layer.scale = Vector2(1,projection.depth)
		layer.material.shader = ProjectedSurface
		layer.material.set_shader_parameter("ground_view_scale",Vector2(1,projection.depth))
	if trial_environment != null and is_instance_valid(trial_environment._shore):
		trial_environment._shore.scale = Vector2(1,projection.depth)
		trial_environment._shore_material.shader = ProjectedShore
		trial_environment._shore_material.set_shader_parameter("ground_view_scale",Vector2(1,projection.depth))

func _cell(position: Vector2) -> Vector2i:
	return projection.cell_at(map_port.get_canvas_transform().affine_inverse()*position)

func _close_page() -> void:
	# The inherited close path redraws selected details. An unowned selection would
	# immediately reopen the purchase dialog, including after starting another slot.
	if _started and not world.land.at(selected).is_empty() and not world.land.contains(selected):
		selected = Vector2i(-1,-1)
	super()

func collect_entities() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for uid in world.crops:
		var crop: Dictionary = world.crops[uid]
		var definition: Dictionary = world.crop_defs[crop["crop_id"]]
		var rect := projection.footprint(crop["origin"],definition["footprint"])
		var visual: Dictionary = plant_visuals.visual(crop,definition,world.flowers.settings["oilseed_window"])
		var point := rect.get_center() if projection.enabled else plant_visuals.ground_root(crop["origin"],definition["footprint"])
		result.append({"kind":"crop","id":int(uid),"ident":crop["crop_id"],"data":crop,"rect":rect,"root":point,"visual":visual,"body_scale":1.0})
	for uid in world.facilities:
		var item: Dictionary = world.facilities[uid]
		var rect := projection.footprint(item["origin"],world.facility_defs[item["facility_id"]]["footprint"])
		result.append({"kind":"facility","id":int(uid),"ident":item["facility_id"],"data":item,"rect":rect,"root":rect.get_center(),"visual":facility_visuals.visual(item["facility_id"],rect),"body_scale":1.0})
	for ident in world.source_defs:
		var item: Dictionary = world.source_defs[ident]
		var rect := projection.footprint(item["position"],[1,1])
		var visual: Dictionary = trial_environment.source_visual(ident,rect)
		var data: Dictionary = trial_environment.resources[ident]
		var body_scale := 1.0
		if projection.enabled:
			body_scale = (64.0/float(projection.config["blender_units_per_tile"]))*float(projection.config["resource_camera_ortho_width"])/float(data["draw_size"][0])
		result.append({"kind":"source","id":0,"ident":ident,"data":item,"rect":rect,"root":rect.get_center(),"visual":visual,"body_scale":body_scale})
	for row in world.logistics.state["instances"]:
		if row["origin"].is_empty(): continue
		var rect := projection.footprint(row["origin"],[1,1])
		var point := rect.get_center()
		var visual := {"texture":Icons.get_icon("rice_bag_gu"),"root":point,"rect":Rect2(point-Vector2(28,48),Vector2(56,56))}
		result.append({"kind":"gu","id":int(String(row["instance_id"]).trim_prefix("trial-")),"ident":row["definition_id"],"data":row,"rect":rect,"root":point,"visual":visual,"body_scale":1.0})
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a["root"].y != b["root"].y: return a["root"].y < b["root"].y
		if a["root"].x != b["root"].x: return a["root"].x < b["root"].x
		if a["kind"] != b["kind"]: return a["kind"] < b["kind"]
		return a["id"] < b["id"])
	return result

func contact_visual(entity: Dictionary) -> Dictionary:
	var point: Vector2 = entity["root"]
	if entity["kind"] == "gu": return _trial_grounding._describe({"size":[38,10],"opacity":0.14},projection.ground_to_view(point))
	var contact: Dictionary
	if entity["kind"] == "crop":
		if entity["visual"].is_empty(): return {}
		contact = _trial_grounding.crop_shadow(entity["ident"],entity["visual"]["key"],point)
	elif entity["kind"] == "facility": contact = _trial_grounding.facility_shadow(entity["ident"],point)
	else: contact = _trial_grounding.source_shadow(entity["ident"],point)
	if contact.is_empty(): return {}
	# P8.6 ellipses already describe a projected contact. Translate, never squash twice.
	contact["rect"] = Rect2(projection.ground_to_view(point)+contact["rect"].position-point,contact["rect"].size)
	return contact

func _draw_world_entities(target: Node2D, readable: float) -> void:
	last_entities = collect_entities()
	for entity in last_entities: _draw_contact(target,cast_visual(entity))
	for entity in last_entities: _draw_contact(target,contact_visual(entity))
	for entity in last_entities:
		var visual: Dictionary = entity["visual"]
		if visual.is_empty():
			var fallback := projection.ground_rect(entity["rect"]).grow(-4)
			target.draw_rect(fallback,Color("deebd9"))
			var extent := minf(fallback.size.x,fallback.size.y)
			target.draw_texture_rect(Icons.get_icon(entity["ident"]),Rect2(fallback.get_center()-Vector2.ONE*extent/2,Vector2.ONE*extent),false)
		else:
			target.draw_texture_rect(visual["texture"],projection.body_rect(visual,entity["root"],entity["body_scale"]),false)
	for entity in last_entities:
		var point := projection.ground_to_view(entity["rect"].end-Vector2(10,10))
		if entity["kind"] == "crop":
			if entity["data"]["state"] == "mature": target.draw_circle(point,5*readable,UI.JADE)
			elif entity["data"]["state"] == "regrowing": target.draw_arc(point,5*readable,0,TAU,16,UI.WATER,2*readable)
		elif entity["kind"] == "facility" and entity["data"]["batch"].get("status") == "ready": target.draw_circle(point,6*readable,UI.WATER)
		elif entity["kind"] == "gu" and entity["data"]["job"].get("ready",false): target.draw_circle(point,5*readable,UI.JADE)

func _draw_facility_preview(target: Node2D, rect: Rect2) -> void:
	var visual: Dictionary = facility_visuals.visual(build_tool,rect)
	if visual.is_empty(): return
	var entry := {"kind":"facility","ident":build_tool,"root":rect.get_center(),"visual":visual}
	_draw_contact(target,cast_visual(entry),Color(1,1,1,0.65))
	_draw_contact(target,contact_visual(entry),Color(1,1,1,0.65))
	target.draw_texture_rect(visual["texture"],projection.body_rect(visual,rect.get_center()),false,Color(1,1,1,0.65))

func cast_visual(entity: Dictionary) -> Dictionary:
	if entity["visual"].is_empty(): return {}
	var point: Vector2 = entity["root"]
	var stage := String(entity["visual"].get("key",""))
	var cast: Dictionary = _trial_grounding.cast_shadow(entity["kind"],entity["ident"],stage,point)
	if not cast.is_empty(): cast["rect"] = Rect2(projection.ground_to_view(point)+cast["rect"].position-point,cast["rect"].size)
	return cast

func draw_map(target: Node2D) -> void:
	var font := theme.default_font
	var readable := maxf(1.0,1.0/(camera.zoom.x*_ui_scale))
	_draw_world_entities(target,readable)
	logistics_ui.draw_overlay(target,true)
	for entity in last_entities:
		if entity["kind"] == "source" and world.workforce.state["sources"].has(entity["ident"]):
			target.draw_circle(projection.ground_to_view(entity["rect"].position+Vector2(52,12)),5*readable,UI.JADE)
	for worker in world.workforce.state["workers"]:
		if worker["id"] != selected_worker: continue
		for area in worker["areas"]:
			target.draw_rect(projection.ground_rect(Rect2(area[0]*64,area[1]*64,area[2]*64,area[3]*64)),Color(0.4,0.7,0.7,0.16))
	var stacks := {}
	for mark in world.workforce.state["marks"]:
		var position := projection.ground_to_view(Vector2(mark["cell"][0],mark["cell"][1])*64)
		var index := int(stacks.get(position,0))
		stacks[position] = index+1
		if index > 0 and camera.zoom.x*_ui_scale < 0.8: continue
		position += Vector2(3+(index%2)*29,3+(index/2)*22)*readable
		target.draw_rect(Rect2(position,Vector2(28,22)*readable),UI.PANEL)
		target.draw_texture_rect(Icons.get_icon(mark["kind"]),Rect2(position,Vector2(18,18)*readable),false)
		target.draw_string(font,position+Vector2(18,16)*readable,str(mark["priority"]),HORIZONTAL_ALIGNMENT_LEFT,-1,int(14*readable),UI.PAPER)
	for plan in world.workforce.state["seed_plans"]:
		target.draw_circle(projection.ground_to_view(Vector2(plan["cell"][0],plan["cell"][1])*64+Vector2(52,12)),4*readable,UI.JADE)
	if world.grid.in_bounds(selected.x,selected.y): target.draw_rect(projection.ground_rect(Rect2(Vector2(selected)*64,Vector2(64,64))),UI.JADE,false,2*readable)
	if not build_tool.is_empty() and world.grid.in_bounds(_hover.x,_hover.y):
		var valid: bool = world.can_build_facility(_hover,build_tool)["ok"]
		var rect := projection.footprint([_hover.x,_hover.y],world.facility_defs[build_tool]["footprint"])
		var view_rect := projection.ground_rect(rect)
		target.draw_rect(view_rect,Color(0.35,0.6,0.4,0.3) if valid else Color(0.7,0.25,0.2,0.3))
		target.draw_rect(view_rect,UI.JADE if valid else UI.ERROR,false,3*readable)
		_draw_facility_preview(target,rect)
	if manual_mode and tool != "inspect" and build_tool.is_empty() and world.grid.in_bounds(_hover.x,_hover.y):
		var valid: bool = world.action_quote(_hover,tool)["ok"]
		target.draw_rect(projection.ground_rect(Rect2(Vector2(_hover)*64,Vector2(64,64))),UI.JADE if valid else UI.ERROR,false,2*readable)
	if _drag and not manual_mode:
		var rect := _rect(_drag_start,_drag_end)
		if tool not in ["inspect","area","cancel"]:
			var preview: Dictionary = world.workforce.preview(rect,tool)
			for cell in preview["valid"]: target.draw_rect(projection.ground_rect(Rect2(Vector2(cell)*64,Vector2(64,64))),Color(0.35,0.65,0.4,0.3))
			for cell in preview["invalid"]: target.draw_rect(projection.ground_rect(Rect2(Vector2(cell)*64,Vector2(64,64))),Color(0.7,0.25,0.2,0.28))
		target.draw_rect(projection.ground_rect(Rect2(Vector2(rect.position)*64,Vector2(rect.size)*64)),UI.PANEL,false,2*readable)
	for id in world.land.parcels:
		var parcel: Dictionary = world.land.parcels[id]
		var area: Rect2i = world.land.rect(parcel["rect"])
		var boundary := projection.ground_rect(Rect2(Vector2(area.position)*64,Vector2(area.size)*64))
		if id not in world.land.purchased:
			target.draw_rect(boundary.grow(-2),Color("dce9ee") if parcel["terrain"] == "water" else Color("e4ead7"))
			target.draw_rect(boundary.grow(-2),UI.JADE,false,readable)
			var caption := "%s · %d元石" % [parcel["name"],parcel["price"]] if boundary.size.x*camera.zoom.x*_ui_scale > 120 else str(parcel["price"])
			target.draw_string(font,boundary.position+Vector2(8,20*readable),caption,HORIZONTAL_ALIGNMENT_CENTER,boundary.size.x-16,int(13*readable),UI.JADE)
		if id == _land_focus: target.draw_rect(boundary,UI.JADE,false,3*readable)
	if show_rulers:
		for y in range(1,14):
			for x in range(1,20):
				target.draw_rect(projection.ground_rect(Rect2(x*64,y*64,64,64)),Color(0.3,0.4,0.3,0.16),false,readable)
		var point := projection.ground_to_view(Vector2(64,64))
		target.draw_line(point,projection.ground_to_view(Vector2(320,64)),Color("e4b75f"),3*readable)
		target.draw_line(point,projection.ground_to_view(Vector2(64,320)),Color("5c99ab"),3*readable)
		target.draw_string(font,point+Vector2(8,-10)*readable,"X/Y各4格 · 64单位/格",HORIZONTAL_ALIGNMENT_LEFT,-1,int(14*readable),UI.JADE)

func view_bounds() -> Rect2:
	if not _bounds_dirty: return _camera_view_bounds
	var bounds := projection.ground_rect(Rect2(Vector2(world.grid.bounds().position)*64,Vector2(world.grid.bounds().size)*64))
	for entity in collect_entities():
		if not entity["visual"].is_empty(): bounds = bounds.merge(projection.body_rect(entity["visual"],entity["root"],entity["body_scale"]))
	_camera_view_bounds = bounds.grow(12)
	_bounds_dirty = false
	return _camera_view_bounds

func invalidate_projection_bounds(_cells: Array = []) -> void:
	_bounds_dirty = true

func _fit_map() -> void:
	var bounds := view_bounds()
	var bottom := _camera_bottom_margin()
	var side := _camera_side_margin()
	var zoom := clampf(minf(maxf(64,board.size.x-side)/bounds.size.x,maxf(64,board.size.y-bottom)/bounds.size.y)*0.94,minimum_map_zoom,3.0)
	camera.zoom = Vector2.ONE*zoom
	camera.position = bounds.get_center()+Vector2(side,bottom)*0.5/zoom

func _camera_side_margin() -> float:
	# Wide layouts shrink the board; compact layouts overlay the same sidebar.
	if not side_panel.visible or ui_root.size.x >= 1100: return 0.0
	return maxf(0.0,board.size.x-(side_panel.position.x-board.position.x-12.0))

func _focus_ground(point: Vector2) -> void:
	camera.position = projection.ground_to_view(point)+Vector2(_camera_side_margin(),_camera_bottom_margin())*0.5/camera.zoom.x

func _process(delta: float) -> void:
	if not _started: return
	if settings.data["show_fps"]: _refresh()
	if shade.visible or _text_focus() or is_instance_valid(confirmation): return
	camera.position += Input.get_vector("move_left","move_right","move_up","move_down")*(400.0/camera.zoom.x)*delta
	var bounds := view_bounds()
	var margins := Vector2(_camera_side_margin(),_camera_bottom_margin())
	var half := (Vector2(map_port.size)-margins)*0.5/camera.zoom.x
	var offset := margins*0.5/camera.zoom.x
	for axis in range(2):
		var middle := bounds.get_center()[axis]
		var low := minf(bounds.position[axis]+half[axis],middle)
		var high := maxf(bounds.end[axis]-half[axis],middle)
		camera.position[axis] = clampf(camera.position[axis]-offset[axis],low,high)+offset[axis]

func _locate(cell: Vector2i) -> void:
	super(cell)
	_focus_ground(Vector2(cell)*64+Vector2(32,32))

func _locate_area(area: Array) -> void:
	_close_page()
	_focus_ground(Vector2(float(area[0])+float(area[2])*0.5,float(area[1])+float(area[3])*0.5)*64)

func _locate_land(id: String) -> void:
	super(id)
	_focus_ground(camera.position)

func _locate_facility(uid: int) -> void:
	super(uid)
	for item in world.facilities.values():
		if int(item["uid"]) == uid:
			_focus_ground(projection.footprint(item["origin"],world.facility_defs[item["facility_id"]]["footprint"]).get_center())
			return
