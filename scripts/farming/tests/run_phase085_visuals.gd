extends SceneTree
const Visuals := preload("res://scripts/farming/p8/p8_plant_visuals.gd")
const Shell := preload("res://scripts/farming/p8/p8_scene.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	var visuals := Visuals.new()
	check(visuals.textures.size() == 29, "29 textures cached")
	check(visuals.diagnostics.is_empty(), "no missing textures")
	var definitions: Dictionary = {}
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/farming/p8/production.json"))
	for definition in config["crops"]: definitions[definition["id"]] = definition
	var wheat := {"crop_id":"golden_wheat", "origin":[-2,3], "state":"growing", "progress":0}
	var first := visuals.visual(wheat, definitions["golden_wheat"], [300,500])
	check(first["root"] == Vector2(-96,256), "negative x root")
	for progress in [0,134,267]:
		wheat["progress"] = progress
		var image := visuals.visual(wheat, definitions["golden_wheat"], [300,500])
		check(image["rect"] == first["rect"], "fixed canvas across wheat growth")
	wheat["state"] = "mature"
	check(visuals.visual(wheat, definitions["golden_wheat"], [300,500])["key"] == "stage_3", "mature wheat")
	var mature_path := String(visuals.plants["golden_wheat"]["stages"]["stage_3"])
	var mature_texture = visuals.textures[mature_path]
	visuals.textures.erase(mature_path)
	check(visuals.visual(wheat, definitions["golden_wheat"], [300,500]).is_empty(), "missing image uses fallback")
	visuals.visual(wheat, definitions["golden_wheat"], [300,500])
	check(visuals.diagnostics.size() == 1, "missing image warning deduplicated")
	visuals.textures[mature_path] = mature_texture
	var tree := {"crop_id":"resin_tree", "origin":[1,2], "state":"regrowing", "progress":0}
	var tree_visual := visuals.visual(tree, definitions["resin_tree"], [300,500])
	check(tree_visual["key"] == "stage_3", "harvested tree remains mature")
	check(is_equal_approx(tree_visual["rect"].size.y/tree_visual["rect"].size.x,1.5), "tree aspect")
	var oil := {"crop_id":"oilseed_flower", "origin":[0,0], "state":"growing", "progress":299}
	for progress in [299,300,499,500]:
		oil["progress"] = progress
		check((visuals.state_key(oil,definitions["oilseed_flower"],[300,500]) == "flowering") == (progress >= 300 and progress < 500), "flower boundary %d" % progress)
	oil["state"] = "mature"
	check(visuals.state_key(oil,definitions["oilseed_flower"],[300,500]) == "stage_3", "mature oilseed")
	var shell := Shell.new()
	check(shell.plant_visuals.enabled_ids == ["golden_wheat", "resin_tree"], "pilot scope")
	shell.free()
	for failure in failures: printerr(failure)
	print("PHASE085 VISUALS OK: %d checks" % checks) if failures.is_empty() else print("PHASE085 VISUALS FAILED")
	quit(0 if failures.is_empty() else 1)
