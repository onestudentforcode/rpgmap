extends "res://scripts/farming/p8/p8_scene.gd"
## Explicit development shell. Production P8.6 scene and saved games stay untouched.
const GroundProjection := preload("res://scripts/farming/p8/p87_projection.gd")
const ProjectedSurface := preload("res://assets/farming/shaders/p87_surface.gdshader")
const ProjectedShore := preload("res://assets/farming/shaders/p87_shore.gdshader")
var projection := GroundProjection.new()
var show_rulers := true
var last_entities: Array[Dictionary] = []

func _init() -> void:
	super()
	var path := "res://.art-work/p87-interactive/session-%d" % OS.get_process_id()
	store = P8Store.new(path)
	settings = Settings.new(path+"/settings.cfg",0.1)

func _ready() -> void:
	super()
	configure_projection("matched35")

func configure_projection(profile: String) -> Dictionary:
	if profile not in ["p86","matched35"]: return {"ok":false,"reason":"unknown projection profile"}
	var ground_center := projection.view_to_ground(camera.position)
	projection.configure(profile == "matched35")
	camera.position = projection.ground_to_view(ground_center)
	for layer: TileMapLayer in terrain.layers.values():
		layer.scale = Vector2(1,projection.depth)
		layer.material.shader = ProjectedSurface
		layer.material.set_shader_parameter("ground_view_scale",Vector2(1,projection.depth))
	if trial_environment != null and is_instance_valid(trial_environment._shore):
		trial_environment._shore.scale = Vector2(1,projection.depth)
		trial_environment._shore_material.shader = ProjectedShore
		trial_environment._shore_material.set_shader_parameter("ground_view_scale",Vector2(1,projection.depth))
	product_title = "P8.7 A · 35°投影试样" if projection.enabled else "P8.7 A · P8.6对照"
	overlay.queue_redraw()
	return {"ok":true,"profile":profile,"depth":projection.depth}

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not _text_focus():
		if event.keycode == KEY_F7:
			configure_projection("p86" if projection.enabled else "matched35")
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F8:
			show_rulers = not show_rulers
			overlay.queue_redraw()
			get_viewport().set_input_as_handled()
			return
	super(event)

func _cell(position: Vector2) -> Vector2i:
	return projection.cell_at(map_port.get_canvas_transform().affine_inverse()*position)

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
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a["root"].y != b["root"].y: return a["root"].y < b["root"].y
		if a["root"].x != b["root"].x: return a["root"].x < b["root"].x
		if a["kind"] != b["kind"]: return a["kind"] < b["kind"]
		return a["id"] < b["id"])
	return result

func contact_visual(entity: Dictionary) -> Dictionary:
	var point: Vector2 = entity["root"]
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

func _draw_facility_preview(target: Node2D, rect: Rect2) -> void:
	var visual: Dictionary = facility_visuals.visual(build_tool,rect)
	if visual.is_empty(): return
	var entry := {"kind":"facility","ident":build_tool,"root":rect.get_center(),"visual":visual}
	_draw_contact(target,contact_visual(entry),Color(1,1,1,0.65))
	target.draw_texture_rect(visual["texture"],projection.body_rect(visual,rect.get_center()),false,Color(1,1,1,0.65))

func draw_map(target: Node2D) -> void:
	var font := theme.default_font
	var readable := maxf(1.0,1.0/(camera.zoom.x*_ui_scale))
	_draw_world_entities(target,readable)
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
	var bounds := projection.ground_rect(Rect2(Vector2(world.grid.bounds().position)*64,Vector2(world.grid.bounds().size)*64))
	for entity in collect_entities():
		if not entity["visual"].is_empty(): bounds = bounds.merge(projection.body_rect(entity["visual"],entity["root"],entity["body_scale"]))
	return bounds.grow(12)

func _fit_map() -> void:
	var bounds := view_bounds()
	var bottom := _camera_bottom_margin()
	var zoom := clampf(minf(board.size.x/bounds.size.x,maxf(64,board.size.y-bottom)/bounds.size.y)*0.94,minimum_map_zoom,3.0)
	camera.zoom = Vector2.ONE*zoom
	camera.position = bounds.get_center()+Vector2(0,bottom*0.5/zoom)

func _process(delta: float) -> void:
	if not _started: return
	if settings.data["show_fps"]: _refresh()
	if shade.visible or _text_focus() or is_instance_valid(confirmation): return
	camera.position += Input.get_vector("move_left","move_right","move_up","move_down")*(400.0/camera.zoom.x)*delta
	var bounds := view_bounds()
	var margin := _camera_bottom_margin()
	var half := (Vector2(map_port.size)-Vector2(0,margin))*0.5/camera.zoom.x
	var offset := margin*0.5/camera.zoom.x
	for axis in range(2):
		var middle := bounds.get_center()[axis]
		var low := minf(bounds.position[axis]+half[axis],middle)
		var high := maxf(bounds.end[axis]-half[axis],middle)
		camera.position[axis] = clampf(camera.position[axis]-(offset if axis == 1 else 0.0),low,high)+(offset if axis == 1 else 0.0)

func _locate(cell: Vector2i) -> void:
	super(cell)
	camera.position = projection.ground_to_view(Vector2(cell)*64+Vector2(32,32))

func _locate_land(id: String) -> void:
	super(id)
	camera.position = projection.ground_to_view(camera.position)

func _locate_facility(uid: int) -> void:
	super(uid)
	for item in world.facilities.values():
		if int(item["uid"]) == uid:
			camera.position = projection.ground_to_view(projection.footprint(item["origin"],world.facility_defs[item["facility_id"]]["footprint"]).get_center())
			return
