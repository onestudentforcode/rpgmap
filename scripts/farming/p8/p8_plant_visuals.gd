extends RefCounted
## Offline Blender renders: persistent textures, projected roots and fixed canvases.
var plants: Dictionary = {}
var textures: Dictionary = {}
var diagnostics: Dictionary = {}
var enabled_ids: Array[String] = []

func _init(manifest_path: String = "res://assets/farming/crops/plant_manifest.json") -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary or not parsed.get("plants") is Dictionary:
		_diagnose(manifest_path, "invalid plant manifest")
		return
	plants = parsed["plants"]
	for ident in plants:
		enabled_ids.append(String(ident))
		for key in plants[ident]["stages"]:
			var path := String(plants[ident]["stages"][key])
			var image := Image.new()
			var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) if FileAccess.file_exists(path) else ERR_FILE_NOT_FOUND
			if error != OK or image.is_empty():
				_diagnose("%s/%s" % [ident, key], "cannot load %s (%d)" % [path, error])
				continue
			textures[path] = ImageTexture.create_from_image(image)

func _diagnose(key: String, message: String) -> void:
	if diagnostics.has(key): return
	diagnostics[key] = message
	push_warning("P8 plant visual %s: %s" % [key, message])

func state_key(crop: Dictionary, definition: Dictionary, flower_window: Array) -> String:
	if crop["state"] == "mature": return "stage_3"
	if crop["state"] == "regrowing" and definition["mode"] == "tap_or_fell": return "stage_3"
	var progress := int(crop["progress"])
	if crop["crop_id"] == "oilseed_flower" and crop["state"] == "growing" and progress >= int(flower_window[0]) and progress < int(flower_window[1]):
		return "flowering"
	var target := maxi(1, int(definition["days"]) * 100)
	return "stage_%d" % clampi(int(float(progress) * 3.0 / target), 0, 2)

func ground_root(origin: Array, footprint: Array) -> Vector2:
	return Vector2((float(origin[0]) + float(footprint[0]) * 0.5) * 64.0,
		(float(origin[1]) + float(footprint[1])) * 64.0)

func visual(crop: Dictionary, definition: Dictionary, flower_window: Array) -> Dictionary:
	var ident := String(crop["crop_id"])
	if ident not in enabled_ids or not plants.has(ident): return {}
	var data: Dictionary = plants[ident]
	var key := state_key(crop, definition, flower_window)
	var path := String(data["stages"].get(key, ""))
	if not textures.has(path):
		_diagnose("%s/%s" % [ident, key], "missing cached texture: %s" % path)
		return {}
	var size := Vector2(float(data["draw_size"][0]), float(data["draw_size"][1])) * float(data["scale_multiplier"])
	var anchor := Vector2(float(data["anchor_uv"][0]), float(data["anchor_uv"][1]))
	var point := ground_root(crop["origin"], definition["footprint"])
	return {"texture": textures[path], "rect": Rect2(point - size * anchor, size), "root": point, "key": key}
