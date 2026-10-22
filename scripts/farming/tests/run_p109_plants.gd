extends SceneTree
const Scene := preload("res://scenes/farming/farm_p8.tscn")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: _run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _run() -> void:
	var shell = Scene.instantiate()
	var directory := "res://.art-work/p109/tests/%d" % Time.get_ticks_usec()
	shell.store = Store.new(directory)
	shell.settings = shell.settings.get_script().new(directory+".cfg",0.1)
	root.add_child(shell)
	await process_frame
	shell._new(1,false)
	shell.set_process(false)
	check(shell.plant_profile == "p109", "default main scene activates new plant art")
	check(shell.plant_visuals.diagnostics.is_empty(),"all plant textures decode")
	check(shell.plant_visuals.textures.size() == 41,"41 active textures")
	var before: Dictionary = shell.world.to_snapshot().duplicate(true)
	var window: Array = shell.world.flowers.settings["oilseed_window"]
	for ident in shell.world.crop_defs:
		var definition: Dictionary = shell.world.crop_defs[ident]
		var data: Dictionary = shell.plant_visuals.plants[ident]
		check(data["footprint"] == definition["footprint"],"retained footprint "+ident)
		for key in data["stages"]:
			var progress := 0
			if key == "flowering": progress = int(window[0])
			elif key != "stage_3":
				progress = ceili(float(int(definition["days"])*100)*int(key[-1])/3.0)
				if ident == "oilseed_flower" and key == "stage_2": progress = maxi(progress,int(window[1]))
			var crop := {"crop_id":ident,"origin":[2,3],"state":"mature" if key == "stage_3" else "growing","progress":progress}
			var visual: Dictionary = shell.plant_visuals.visual(crop,definition,window)
			check(visual["key"] == key,"stage semantics %s/%s"%[ident,key])
			var root_point: Vector2 = shell.plant_visuals.ground_root(crop["origin"],definition["footprint"])
			var body: Rect2 = shell.projection.body_rect(visual,root_point)
			var anchor := Vector2(data["anchor_uv"][0],data["anchor_uv"][1])
			check((body.position+body.size*anchor).is_equal_approx(shell.projection.ground_to_view(root_point)),"projected root remains fixed %s/%s"%[ident,key])
			check(body.size == visual["rect"].size,"no second body flattening %s/%s"%[ident,key])
			var path: String = data["stages"][key]
			check(FileAccess.get_sha256(path) == data["sha256"][key],"runtime hash %s/%s"%[ident,key])
			var export: Dictionary = data["exports"][key]
			check(FileAccess.get_sha256("res://"+export["source_file"]) == export["source_sha256"],"source unchanged %s/%s"%[ident,key])
			check(absf(export["root_error_px"][0]) <= 0.5 and absf(export["root_error_px"][1]) <= 0.5,"subpixel anchor quantization %s/%s"%[ident,key])
		if definition["mode"] == "tap_or_fell":
			check(shell.plant_visuals.state_key({"crop_id":ident,"state":"regrowing","progress":0},definition,window) == "stage_3","regrowing mature body "+ident)
	for progress in [299,300,499,500]:
		check((shell.plant_visuals.state_key({"crop_id":"oilseed_flower","state":"growing","progress":progress},shell.world.crop_defs["oilseed_flower"],window) == "flowering") == (progress >= 300 and progress < 500),"flower window %d"%progress)
	var active = shell.plant_visuals
	check(not shell.configure_plant_profile("invalid")["ok"] and shell.plant_visuals == active,"unknown profile retained atomically")
	check(shell.configure_plant_profile("legacy")["ok"],"legacy rollback")
	check(shell.configure_visual_trial("baseline")["ok"],"environment profile remains independent")
	check(shell.configure_plant_profile("p109")["ok"] and shell.plant_visuals == active,"cached new profile restored")
	check(shell.configure_visual_trial("integrated")["ok"] and shell.plant_profile == "p109","environment restore retains plants")
	check(shell.world.to_snapshot() == before,"profile changes preserve complete gameplay snapshot")
	for failure in failures: printerr(failure)
	print("P109 PLANTS %s: %d checks"%["OK" if failures.is_empty() else "FAILED",checks])
	quit(0 if failures.is_empty() else 1)
