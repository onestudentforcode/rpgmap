extends Node
## Packaged runtime probe; fresh private slots, raw PNG hashes and real lifecycle.
var shell
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _hash(path: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode()

func run() -> void:
	await get_tree().process_frame
	check(OS.has_feature("farm_demo_p8_release"),"actual P8 export feature")
	var expected_plants := 0
	for entry in shell.plant_visuals.plants.values(): expected_plants += entry["stages"].size()
	check(shell.plant_visuals.textures.size() == expected_plants,"all manifest plant textures packaged")
	check(shell.facility_visuals.textures.size() == shell.facility_visuals.facilities.size(),"all manifest facility textures packaged")
	check(shell.plant_visuals.diagnostics.is_empty() and shell.facility_visuals.diagnostics.is_empty(),"no initial missing resources")
	for ident in shell.plant_visuals.plants:
		var visual: Dictionary = shell.plant_visuals.plants[ident]
		for key in visual["stages"]:
			var path := String(visual.get("data_files",{}).get(key,visual["stages"][key]))
			check(FileAccess.file_exists(path) and _hash(path) == visual["sha256"][key],"raw packaged PNG %s/%s" % [ident,key])
	for ident in shell.facility_visuals.facilities:
		var visual: Dictionary = shell.facility_visuals.facilities[ident]
		var path := String(visual.get("data_file",visual["path"]))
		check(FileAccess.file_exists(path) and _hash(path) == visual["sha256"],"raw packaged facility %s" % ident)
	check(FileAccess.file_exists("res://content/farming/p8/world_visuals.json"),"packaged world style")
	check(shell.terrain.layers["grass"].material is ShaderMaterial,"packaged terrain shader")
	check(shell.world.crop_defs.size() == 7 and shell.world.facility_defs.size() == 15,"P8 runtime catalogs")

	check(shell.visual_trial_profile == "integrated" and shell.trial_environment != null,"production P8.6 active without art workspace")
	check(shell.trial_environment.diagnostics.is_empty(),"packaged scenery manifest loads")
	var scenery: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/farming/p86/resource_manifest.json"))
	var scenery_entries: Array = scenery["resources"].values()
	scenery_entries.append(scenery["transition"])
	for entry in scenery_entries:
		var data_path := String(entry.get("data_file",entry["path"]))
		check(FileAccess.file_exists(data_path) and _hash(data_path)==entry["sha256"],"packaged scenery hash "+String(entry["path"]))
	for ident in shell.world.facility_defs:
		check(shell.facility_thumbnail(ident) is AtlasTexture,"packaged facility thumbnail "+ident)

	shell._new(1,false)
	var world = shell.world
	check(world.till(Vector2i(1,1))["ok"],"real packaged till")
	var planted: Dictionary = world.plant(Vector2i(1,1),"golden_wheat")
	check(planted["ok"],"real packaged plant")
	if planted["ok"]:
		var uid := int(planted["uid"])
		for i in range(4): check(world.end_day()["ok"],"packaged day/save %d" % i)
		check(world.crops[uid]["state"] == "mature","natural mature state")
		check(shell.plant_visuals.visual(world.crops[uid],world.crop_defs["golden_wheat"],world.flowers.settings["oilseed_window"])["key"] == "stage_3","natural mature visual")
		shell._open(1)
		check(world.crops.has(uid) and world.crops[uid]["state"] == "mature","packaged reopen saved crop")
		check(world.harvest(Vector2i(1,1))["ok"] and not world.crops.has(uid),"packaged harvest removes sprite source")
		check(world.plant(Vector2i(1,1),"golden_wheat")["ok"],"packaged replant")
	# Real missing-file path, then restore the same manifest and reload it.
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/farming/crops/plant_manifest.json"))
	var original := String(manifest["plants"]["golden_wheat"]["stages"]["stage_0"])
	var original_data := String(manifest["plants"]["golden_wheat"].get("data_files",{}).get("stage_0",original))
	manifest["plants"]["golden_wheat"]["stages"]["stage_0"] = "res://assets/farming/crops/missing_for_probe.png"
	manifest["plants"]["golden_wheat"]["data_files"] = manifest["plants"]["golden_wheat"].get("data_files",{})
	manifest["plants"]["golden_wheat"]["data_files"]["stage_0"] = "res://assets/farming/crops/missing_for_probe.png"
	var temporary := "user://p86_probe_manifest_%d.json" % OS.get_process_id()
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	var missing = shell.PlantVisuals.new(temporary)
	check(missing.diagnostics.has("golden_wheat/stage_0"),"missing-file diagnostic identifies crop and stage")
	var seed := {"crop_id":"golden_wheat","origin":[1,1],"state":"growing","progress":0}
	check(missing.visual(seed,world.crop_defs["golden_wheat"],world.flowers.settings["oilseed_window"]).is_empty(),"missing-file visible fallback contract")
	manifest["plants"]["golden_wheat"]["stages"]["stage_0"] = original
	manifest["plants"]["golden_wheat"]["data_files"]["stage_0"] = original_data
	file = FileAccess.open(temporary,FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	var restored = shell.PlantVisuals.new(temporary)
	check(restored.diagnostics.is_empty() and not restored.visual(seed,world.crop_defs["golden_wheat"],world.flowers.settings["oilseed_window"]).is_empty(),"resource restoration")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--p86-render-probe=") and DisplayServer.get_name() != "headless":
			# Synthetic mature row for exported GPU validation, after real lifecycle checks.
			world.crops.clear()
			var index := 0
			for ident in world.crop_defs:
				world.crops[200+index] = {"uid":200+index,"crop_id":ident,"origin":[2+index*2,4],"state":"mature","progress":int(world.crop_defs[ident]["days"])*100,"harvest_count":0}
				index += 1
			shell.selected = Vector2i(2,4)
			shell._close_page()
			shell.digest.visible = false
			shell.camera.zoom = Vector2.ONE
			shell.camera.position = Vector2(640,420)
			shell.overlay.queue_redraw()
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			check(get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--p86-render-probe=")) == OK,"exported GPU frame saved")
	for failure in failures: printerr(failure)
	print("P86 RELEASE SMOKE %s: %d checks" % ["OK" if failures.is_empty() else "FAILED",checks])
	get_tree().quit(0 if failures.is_empty() else 1)
