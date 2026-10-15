extends "res://scripts/farming/p8/p8_grounding.gd"
## Subtle projected contacts and lower-right soft casts, independent of body PNGs.
var style: Dictionary
func _init() -> void:
	super("res://content/farming/p8/grounding.json")
	style = JSON.parse_string(FileAccess.get_file_as_string("res://content/farming/p8/p87_shadows.json"))

func _describe(entry: Dictionary, root: Vector2) -> Dictionary:
	var result := super(entry,root)
	if not result.is_empty() and result["kind"] != "water":
		var color: Color = result["color"]
		color.a = minf(float(style["land_contact_opacity_limit"]),color.a*float(style["land_contact_opacity_multiplier"]))
		result["color"] = color
	return result

func source_shadow(ident: String, root: Vector2) -> Dictionary:
	var result := super(ident,root)
	if not result.is_empty():
		var scale := float(style["resource_contact_scale"])
		result["rect"] = Rect2(root+(result["rect"].position-root)*scale,result["rect"].size*scale)
	return result

func cast_shadow(kind: String, ident: String, stage: String, root: Vector2) -> Dictionary:
	var entry: Dictionary = {}
	if kind == "crop":
		if stage == "stage_0": return {}
		if ident in ["resin_tree","fast_fir"]:
			entry = style.get("tree_"+stage,{}).duplicate(true)
		elif stage in ["stage_2","stage_3","flowering"]:
			var contact: Dictionary = config["plants"][ident]["stages"].get(stage,{})
			if not contact.is_empty(): entry = {"size":[float(contact["size"][0])*1.1,float(contact["size"][1])*0.8],"offset":[6,3],"opacity":style["plant_cast_opacity"]}
	elif kind == "facility":
		var contact: Dictionary = config["facilities"].get(ident,{})
		if contact.get("kind","") == "water": return {}
		if not contact.is_empty(): entry = {"size":[float(contact["size"][0])*0.85,float(contact["size"][1])*0.65],"offset":[10,5],"opacity":style["facility_cast_opacity"]}
	elif kind == "source" and ident != "spring_source":
		entry = {"size":[58,16],"offset":[10,5],"opacity":style["resource_cast_opacity"]}
	if entry.is_empty(): return {}
	var distance := float(entry["offset"][0])
	var direction: Array = style["cast_direction"]
	entry["offset"] = [distance,distance*float(direction[1])/float(direction[0])]
	var result := super._describe(entry,root)
	var color: Color = result["color"]
	color = Color(String(style["cast_color"]),color.a)
	result["color"] = color
	return result
