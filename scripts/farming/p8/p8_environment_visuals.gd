extends RefCounted
## Production P8.6 scenery. Asset bytes come only from the packaged manifest.
const Surface := preload("res://assets/farming/shaders/p86_surface_trial.gdshader")
const Shore := preload("res://assets/farming/shaders/p86_shore.gdshader")
const MANIFEST := "res://assets/farming/p86/resource_manifest.json"
const TONES := {"grass":"94ad7f","dirt":"b0987a","stone":"a9af9e","tilled":"8c795f","water":"8fb7ae"}
const KINDS := {"grass":0,"dirt":1,"stone":2,"tilled":3,"water":4}
var diagnostics: Array[String] = []
var resources: Dictionary = {}
var textures: Dictionary = {}
var _materials: Dictionary = {}
var _filters: Dictionary = {}
var _shell: WeakRef
var _connected_world
var _shore: Polygon2D
var _shore_material: ShaderMaterial
var _mask_texture: ImageTexture
var _mask_stamp := ""
var _prepared := false

func prepare_assets() -> Array[String]:
	diagnostics.clear()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not parsed is Dictionary or not parsed.get("resources") is Dictionary:
		diagnostics.append("invalid P8.6 resource manifest")
		return diagnostics
	var prepared := {}
	for ident in parsed["resources"]:
		var entry: Dictionary = parsed["resources"][ident]
		var path := String(entry.get("data_file",entry["path"]))
		var bytes := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(bytes)
		var image := Image.new()
		if bytes.is_empty() or hash.finish().hex_encode() != String(entry["sha256"]) or image.load_png_from_buffer(bytes) != OK:
			diagnostics.append("invalid P8.6 resource bytes: "+ident)
			continue
		var canvas: Array = entry["canvas_px"]
		if image.get_size() != Vector2i(canvas[0],canvas[1]):
			diagnostics.append("invalid P8.6 resource canvas: "+ident)
			continue
		image.fix_alpha_edges()
		image.generate_mipmaps()
		prepared[ident] = ImageTexture.create_from_image(image)
	if diagnostics.is_empty():
		resources = parsed["resources"]
		textures = prepared
		_prepared = true
	return diagnostics

func apply(shell: Node) -> void:
	if not _prepared: prepare_assets()
	if not diagnostics.is_empty(): return
	if _shell != null: restore(_shell.get_ref())
	_shell = weakref(shell)
	for ident in TONES:
		if not shell.terrain.layers.has(ident): continue
		var layer: TileMapLayer = shell.terrain.layers[ident]
		_materials[ident] = layer.material
		_filters[ident] = layer.texture_filter
		var material := ShaderMaterial.new()
		material.shader = Surface
		material.set_shader_parameter("terrain_tone",Color(TONES[ident]))
		material.set_shader_parameter("surface_kind",KINDS[ident])
		layer.material = material
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_shore = Polygon2D.new()
	_shore.name = "P86Shoreline"
	_shore.z_index = -5
	_shore_material = ShaderMaterial.new()
	_shore_material.shader = Shore
	_shore.material = _shore_material
	shell.overlay.get_parent().add_child(_shore)
	_connected_world = shell.world
	_connected_world.changed.connect(_refresh_shores)
	_refresh_shores()
	shell.overlay.queue_redraw()

func restore(shell: Node) -> void:
	if _connected_world != null and _connected_world.changed.is_connected(_refresh_shores):
		_connected_world.changed.disconnect(_refresh_shores)
	if shell != null:
		for ident in _materials:
			shell.terrain.layers[ident].material = _materials[ident]
			shell.terrain.layers[ident].texture_filter = _filters[ident]
	if is_instance_valid(_shore):
		_shore.get_parent().remove_child(_shore)
		_shore.queue_free()
	_shore = null
	_materials.clear()
	_filters.clear()
	_mask_stamp = ""
	_shell = null
	_connected_world = null

func source_visual(ident: String, footprint_rect: Rect2) -> Dictionary:
	if _shell == null or not textures.has(ident): return {}
	var data: Dictionary = resources[ident]
	var point := footprint_rect.get_center()
	var size := Vector2(data["draw_size"][0],data["draw_size"][1])
	var anchor := Vector2(data["anchor_uv"][0],data["anchor_uv"][1])
	return {"texture":textures[ident],"rect":Rect2(point-size*anchor,size),"root":point}

func _refresh_shores() -> void:
	if _shell == null or not is_instance_valid(_shore): return
	var shell = _shell.get_ref()
	if shell == null: return
	var grid = shell.world.grid
	var bounds: Rect2i = grid.bounds()
	var stamp := "%s/%s" % [bounds,shell.world.land.to_save()]
	if stamp == _mask_stamp: return
	_mask_stamp = stamp
	var mask := Image.create(bounds.size.x,bounds.size.y,false,Image.FORMAT_RGBA8)
	for y in range(bounds.size.y):
		for x in range(bounds.size.x):
			var cell := bounds.position+Vector2i(x,y)
			var terrain_id: String = grid.terrain_at(cell)
			mask.set_pixel(x,y,Color(1.0 if terrain_id == "water" else 0.0,1.0 if grid.in_bounds(cell.x,cell.y) else 0.0,float(KINDS.get(terrain_id,0))/4.0,1.0))
	_mask_texture = ImageTexture.create_from_image(mask)
	_shore_material.set_shader_parameter("shore_mask",_mask_texture)
	_shore_material.set_shader_parameter("grid_origin",Vector2(bounds.position))
	_shore_material.set_shader_parameter("grid_size",Vector2(bounds.size))
	var rect := Rect2(Vector2(bounds.position)*64.0,Vector2(bounds.size)*64.0)
	_shore.polygon = PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
