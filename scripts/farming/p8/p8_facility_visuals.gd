extends RefCounted
## Body renders only. Top-down foundation and decorative fx are deferred layers.
const Grounding := preload("res://scripts/farming/p8/p8_grounding.gd")
const DEFAULT_MANIFEST := "res://assets/farming/facilities/facility_manifest.json"
var facilities: Dictionary = {}
var textures: Dictionary = {}
var diagnostics: Dictionary = {}

func _init(manifest_path: String = DEFAULT_MANIFEST) -> void:
	_load_manifest(manifest_path)

func _load_manifest(manifest_path: String) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary or not parsed.get("facilities") is Dictionary:
		_diagnose("manifest", "invalid facility manifest: %s" % manifest_path)
		return
	for ident in parsed["facilities"]:
		_load_facility(ident, parsed["facilities"][ident])

func _load_facility(ident: String, data: Dictionary) -> void:
	var path := String(data["path"])
	var data_path := String(data.get("data_file", path))
	var image := Image.new()
	var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(data_path)) if FileAccess.file_exists(data_path) else ERR_FILE_NOT_FOUND
	if error != OK or image.is_empty():
		_diagnose(ident, "cannot load %s (%d)" % [path, error])
		return
	image.fix_alpha_edges()
	image.generate_mipmaps()
	facilities[ident] = data
	textures[path] = ImageTexture.create_from_image(image)

## 用另一清单覆盖同名条目（P10.9 profile：p109 覆盖 25 项，其余沿用 legacy）。
## 返回问题列表；为空表示全部条目加载成功。
func merge_manifest(manifest_path: String) -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary or not parsed.get("facilities") is Dictionary:
		return ["invalid facility manifest: %s" % manifest_path]
	var problems: Array = []
	for ident in parsed["facilities"]:
		var before = diagnostics.get(ident)
		_load_facility(ident, parsed["facilities"][ident])
		if not facilities.has(ident) and (before == null or not String(before).begins_with("cannot load")):
			problems.append("merge cannot load %s" % ident)
	return problems

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

func ground_root(origin: Array, footprint: Array) -> Vector2:
	return Grounding.ground_root(origin,footprint,"facility")

