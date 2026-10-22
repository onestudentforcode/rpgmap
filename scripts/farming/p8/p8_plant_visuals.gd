extends RefCounted
## Manifest-driven plant art: persistent textures, projected roots and fixed canvases.
const Grounding := preload("res://scripts/farming/p8/p8_grounding.gd")
var plants: Dictionary = {}
var textures: Dictionary = {}
var diagnostics: Dictionary = {}
var enabled_ids: Array[String] = []
var _trial_original_textures: Dictionary = {}

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
			var data_path := String(plants[ident].get("data_files",{}).get(key,path))
			var image := Image.new()
			var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(data_path)) if FileAccess.file_exists(data_path) else ERR_FILE_NOT_FOUND
			if error != OK or image.is_empty():
				_diagnose("%s/%s" % [ident, key], "cannot load %s (%d)" % [path, error])
				continue
			var canvas: Array = plants[ident]["canvas_px"]
			if image.get_size() != Vector2i(int(canvas[0]),int(canvas[1])):
				_diagnose("%s/%s" % [ident,key], "canvas mismatch: " + path)
				continue
			image.fix_alpha_edges()
			image.generate_mipmaps()
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
	return Grounding.ground_root(origin,footprint)

func prepare_trial_replacements(directory: String = "") -> Dictionary:
	# Decode the entire selected subset before committing any cache replacement.
	var prepared: Dictionary = (_trial_original_textures if not _trial_original_textures.is_empty() else textures).duplicate()
	var replaced: Array[String] = []
	var problems: Array[String] = []
	if directory.is_empty(): return {"textures":prepared,"replaced":replaced,"diagnostics":problems}
	for ident in plants:
		for key in ["stage_0","stage_1"]:
			var canonical := String(plants[ident]["stages"].get(key,""))
			var path := directory.path_join(canonical.trim_prefix("res://"))
			if not FileAccess.file_exists(path): continue
			var image := Image.new()
			var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
			var canvas: Array = plants[ident]["canvas_px"]
			if error != OK or image.is_empty() or image.get_size() != Vector2i(int(canvas[0]),int(canvas[1])):
				problems.append("invalid trial canvas: %s" % path)
				continue
			image.fix_alpha_edges()
			image.generate_mipmaps()
			prepared[canonical] = ImageTexture.create_from_image(image)
			replaced.append("%s/%s" % [ident,key])
	if replaced.is_empty() and problems.is_empty(): problems.append("no juvenile trial candidates found in %s" % directory)
	return {"textures":prepared,"replaced":replaced,"diagnostics":problems}

func commit_trial_replacements(prepared: Dictionary) -> void:
	# Approved PNGs and manifests are never rewritten by the trial.
	if _trial_original_textures.is_empty(): _trial_original_textures = textures.duplicate()
	textures = prepared["textures"]

func configure_trial_replacements(directory: String = "") -> Dictionary:
	var prepared := prepare_trial_replacements(directory)
	if prepared["diagnostics"].is_empty(): commit_trial_replacements(prepared)
	return {"ok":prepared["diagnostics"].is_empty(),"replaced":prepared["replaced"] if prepared["diagnostics"].is_empty() else [],"diagnostics":prepared["diagnostics"]}

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
