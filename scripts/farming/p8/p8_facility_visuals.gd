extends RefCounted
## Body renders only. Top-down foundation and decorative fx are deferred layers.
var facilities: Dictionary = {}
var textures: Dictionary = {}
var diagnostics: Dictionary = {}

func _init() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://assets/farming/facilities/facility_manifest.json"))
	if not parsed is Dictionary or not parsed.get("facilities") is Dictionary:
		_diagnose("manifest", "invalid facility manifest")
		return
	facilities = parsed["facilities"]
	for ident in facilities:
		var path := String(facilities[ident]["path"])
		var data_path := String(facilities[ident].get("data_file",path))
		var image := Image.new()
		var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(data_path)) if FileAccess.file_exists(data_path) else ERR_FILE_NOT_FOUND
		if error != OK or image.is_empty():
			_diagnose(ident,"cannot load %s (%d)" % [path,error])
			continue
		image.fix_alpha_edges()
		image.generate_mipmaps()
		textures[path] = ImageTexture.create_from_image(image)

func _diagnose(key: String, message: String) -> void:
	if diagnostics.has(key): return
	diagnostics[key] = message
	push_warning("P8 facility visual %s: %s" % [key,message])

func visual(ident: String, footprint_rect: Rect2) -> Dictionary:
	if not facilities.has(ident): return {}
	var data: Dictionary = facilities[ident]
	var path := String(data["path"])
	if not textures.has(path):
		_diagnose(ident,"missing cached texture: %s" % path)
		return {}
	var size := Vector2(float(data["draw_size"][0]),float(data["draw_size"][1])) * float(data["scale_multiplier"])
	var anchor := Vector2(float(data["anchor_uv"][0]),float(data["anchor_uv"][1]))
	# Facility models use (0,0) as the center of their floor, unlike plant roots.
	var point := footprint_rect.get_center()
	return {"texture":textures[path],"rect":Rect2(point-size*anchor,size),"root":point}
