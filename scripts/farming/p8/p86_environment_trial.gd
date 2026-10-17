extends RefCounted
## Optional representative-scene materials. Only reads the live farm model.
const Surface := preload("res://assets/farming/shaders/p86_surface_trial.gdshader")
const Shore := preload("res://assets/farming/shaders/p86_shore_trial.gdshader")
const TONES := {"grass":"94ad7f", "dirt":"b0987a", "stone":"a9af9e", "tilled":"8c795f", "water":"8fb7ae"}
const KINDS := {"grass":0, "dirt":1, "stone":2, "tilled":3, "water":4}
var _shell: WeakRef
var _materials: Dictionary = {}
var _filters: Dictionary = {}
var _source_textures: Dictionary = {}
var _shore_root: Node2D
var asset_directory := "res://.art-work/p86-assets"
var _prepared := false
var _transition_texture: Texture2D
var _stone_texture: Texture2D
var _stone_anchor := Vector2(0.5,0.64)
var _stone_draw_size := Vector2(83.2,83.2)
var diagnostics: Array[String] = []

func prepare_assets() -> Array[String]:
	diagnostics.clear()
	var transition := _load_texture(asset_directory+"/transition_soft.png",false,Vector2i(1024,1024))
	var stone := _load_texture(asset_directory+"/stone_source.png",true,Vector2i(256,256))
	var transition_metadata := _read_metadata("transition-report.json","transition_soft.png")
	var stone_metadata := _read_metadata("stone-source-report.json","stone_source.png")
	var anchor = stone_metadata.get("anchor_uv")
	var size = stone_metadata.get("draw_size")
	if not _number_pair(anchor,0.0,1.0):
		diagnostics.append("invalid stone-source anchor_uv")
	if not _number_pair(size,1.0,256.0):
		diagnostics.append("invalid stone-source draw_size")
	if transition_metadata.get("tile_px") != 64 or transition_metadata.get("variants") != 256:
		diagnostics.append("invalid transition tile/variant contract")
	_prepared = diagnostics.is_empty()
	if _prepared:
		_transition_texture = transition
		_stone_texture = stone
		_stone_anchor = Vector2(float(anchor[0]),float(anchor[1]))
		_stone_draw_size = Vector2(float(size[0]),float(size[1]))
	return diagnostics

func apply(shell: Node) -> void:
	if not _prepared: prepare_assets()
	if not diagnostics.is_empty(): return
	if _shell != null:
		var previous = _shell.get_ref()
		if previous != null: restore(previous)
	_shell = weakref(shell)
	for ident in TONES:
		if not shell.terrain.layers.has(ident): continue
		var layer: TileMapLayer = shell.terrain.layers[ident]
		_materials[ident] = layer.material
		_filters[ident] = layer.texture_filter
		var material := ShaderMaterial.new()
		material.shader = Surface
		material.set_shader_parameter("terrain_tone", Color(TONES[ident]))
		material.set_shader_parameter("surface_kind", KINDS[ident])
		layer.material = material
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if _transition_texture != null:
		var tileset: TileSet = shell.terrain.tileset
		for index in tileset.get_source_count():
			var source_id := tileset.get_source_id(index)
			var source = tileset.get_source(source_id)
			if source is TileSetAtlasSource and source.texture.get_size() == Vector2(1024,1024):
				_source_textures[source_id] = source.texture
				source.texture = _transition_texture
	_shore_root = Node2D.new()
	_shore_root.name = "P86ShorelineTrial"
	_shore_root.z_index = -5
	shell.overlay.get_parent().add_child(_shore_root)
	shell.world.changed.connect(_refresh_shores)
	_refresh_shores()
	shell.overlay.queue_redraw()

func restore(shell: Node) -> void:
	if shell.world != null and shell.world.changed.is_connected(_refresh_shores):
		shell.world.changed.disconnect(_refresh_shores)
	for ident in _materials:
		if not shell.terrain.layers.has(ident): continue
		shell.terrain.layers[ident].material = _materials[ident]
		shell.terrain.layers[ident].texture_filter = _filters[ident]
	for source_id in _source_textures:
		shell.terrain.tileset.get_source(source_id).texture = _source_textures[source_id]
	if is_instance_valid(_shore_root):
		_shore_root.get_parent().remove_child(_shore_root)
		_shore_root.queue_free()
	_shore_root = null
	_materials.clear()
	_filters.clear()
	_source_textures.clear()
	_shell = null
	shell.overlay.queue_redraw()

func source_visual(ident: String, footprint_rect: Rect2) -> Dictionary:
	if _shell == null or ident != "stone_source" or _stone_texture == null: return {}
	var point := footprint_rect.get_center()
	var size := _stone_draw_size
	return {"texture":_stone_texture,"rect":Rect2(point-size*_stone_anchor,size),"root":point}

func _load_texture(path: String, mipmaps: bool, expected_size: Vector2i) -> Texture2D:
	var image := Image.new()
	var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) if FileAccess.file_exists(path) else ERR_FILE_NOT_FOUND
	if error != OK or image.is_empty():
		diagnostics.append("cannot load trial asset %s (%d)" % [path,error])
		push_warning(diagnostics[-1])
		return null
	if image.get_size() != expected_size:
		diagnostics.append("invalid trial canvas %s: %s" % [path,image.get_size()])
		return null
	image.fix_alpha_edges()
	if mipmaps: image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _read_metadata(filename: String, image_filename: String) -> Dictionary:
	var path := asset_directory+"/"+filename
	if not FileAccess.file_exists(path):
		diagnostics.append("missing trial metadata "+path)
		return {}
	var metadata = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not metadata is Dictionary:
		diagnostics.append("invalid trial metadata "+path)
		return {}
	var image_path := asset_directory+"/"+image_filename
	if FileAccess.file_exists(image_path):
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(FileAccess.get_file_as_bytes(image_path))
		if context.finish().hex_encode() != String(metadata.get("sha256","")):
			diagnostics.append("trial PNG hash differs from metadata "+image_path)
	return metadata

func _number_pair(value, minimum: float, maximum: float) -> bool:
	if not value is Array or value.size() != 2: return false
	for number in value:
		if not (number is int or number is float): return false
		if not is_finite(float(number)) or float(number) < minimum or float(number) > maximum: return false
	return true

func _refresh_shores() -> void:
	if _shell == null or not is_instance_valid(_shore_root): return
	var shell = _shell.get_ref()
	if shell == null: return
	for child in _shore_root.get_children():
		_shore_root.remove_child(child)
		child.queue_free()
	var grid = shell.world.grid
	var bounds: Rect2i = grid.bounds()
	# This trial deliberately covers north-facing reservoir shores only. It does
	# not invent land, change the water footprint or cover purchase controls.
	for y in range(1,bounds.end.y):
		var start_x := bounds.position.x
		var running := false
		for x in range(bounds.position.x,bounds.end.x+1):
			var has_shore: bool = x < bounds.end.x and grid.in_bounds(x,y) and grid.in_bounds(x,y-1) and grid.terrain_at(Vector2i(x,y)) == "water" and grid.terrain_at(Vector2i(x,y-1)) == "grass"
			if has_shore and not running:
				start_x = x
				running = true
			elif running and not has_shore:
				_add_shore(start_x*64.0,x*64.0,y*64.0)
				running = false

func _add_shore(left: float, right: float, y: float) -> void:
	var polygon := Polygon2D.new()
	polygon.polygon = PackedVector2Array([Vector2(left,y-12),Vector2(right,y-12),Vector2(right,y+24),Vector2(left,y+24)])
	var material := ShaderMaterial.new()
	material.shader = Shore
	material.set_shader_parameter("shore_y",y)
	material.set_shader_parameter("land_tone",Color(TONES["grass"]))
	polygon.material = material
	_shore_root.add_child(polygon)
