extends RefCounted
## Opt-in P8.6 contact study. Runtime images are cached independently of body PNGs.
const TILE := 64.0
const CONFIG_PATH := "res://content/farming/p8/p86_grounding_trial.json"
var config: Dictionary = {}
var textures: Dictionary = {}
var diagnostics: Array[String] = []

func _init(config_path: String = CONFIG_PATH) -> void:
	if not FileAccess.file_exists(config_path):
		diagnostics.append("missing contact trial config: %s" % config_path)
		return
	var parser := JSON.new()
	var error := parser.parse(FileAccess.get_file_as_string(config_path))
	if error != OK or not parser.data is Dictionary:
		diagnostics.append("invalid contact trial config: %s" % config_path)
		return
	var parsed: Dictionary = parser.data
	if not parsed.get("plants") is Dictionary or not parsed.get("facilities") is Dictionary:
		diagnostics.append("contact trial config needs plant and facility maps: %s" % config_path)
		return
	config = parsed

static func ground_root(origin: Array, footprint: Array, kind: String = "crop") -> Vector2:
	var rect := Rect2(Vector2(float(origin[0]),float(origin[1]))*TILE,Vector2(float(footprint[0]),float(footprint[1]))*TILE)
	return rect.get_center() if kind != "crop" else Vector2(rect.get_center().x,rect.end.y)

func crop_shadow(ident: String, stage: String, root: Vector2) -> Dictionary:
	var entry: Dictionary = config.get("plants",{}).get(ident,{})
	var states: Dictionary = entry.get("stages",{})
	if not states.has(stage): return {}
	return _describe(states[stage],root)

func facility_shadow(ident: String, root: Vector2) -> Dictionary:
	return _describe(config.get("facilities",{}).get(ident,{}),root)

func source_shadow(ident: String, root: Vector2) -> Dictionary:
	return _describe(config.get("sources",{}).get(ident,{}),root)

func _describe(entry: Dictionary, root: Vector2) -> Dictionary:
	if entry.is_empty(): return {}
	var size_data: Array = entry.get("size",[24.0,8.0])
	var offset_data: Array = entry.get("offset",[0.0,0.0])
	var size := Vector2(float(size_data[0]),float(size_data[1]))
	var point := root + Vector2(float(offset_data[0]),float(offset_data[1]))
	var kind := String(entry.get("kind","land"))
	var color := Color(String(config.get("water_color","507d78") if kind == "water" else config.get("land_color","4a4938")))
	color.a = float(entry.get("opacity",0.16))
	return {"texture":_texture(kind),"rect":Rect2(point-size*0.5,size),"color":color,"kind":kind,"root":root}

func _texture(kind: String) -> Texture2D:
	if textures.has(kind): return textures[kind]
	var image := Image.create(128,128,false,Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var distance := Vector2((float(x)+0.5)/64.0-1.0,(float(y)+0.5)/64.0-1.0).length()
			var alpha := pow(maxf(0.0,1.0-distance*distance),2.4)
			# A transparent-center water contact band, never a grey foundation disk.
			if kind == "water": alpha = exp(-pow((distance-0.70)/0.115,2.0))*0.8
			if distance >= 1.0: alpha = 0.0
			image.set_pixel(x,y,Color(1.0,1.0,1.0,alpha))
	image.fix_alpha_edges()
	image.generate_mipmaps()
	textures[kind] = ImageTexture.create_from_image(image)
	return textures[kind]
