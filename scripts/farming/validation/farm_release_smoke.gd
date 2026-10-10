extends Node
## Explicit --demo-smoke validation; isolated directories, never player slots/settings.
var shell
var directory: String
var shots := ""
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if ok: print("[ok] RELEASE: "+message)
	else: failures.append(message)

func run() -> void:
	await get_tree().process_frame
	check(shell._screen == "main" and shell.farm == null,"default menu")
	if OS.has_feature("farm_demo_release"):
		check(not ResourceLoader.exists("res://scenes/main.tscn") and not ResourceLoader.exists("res://scripts/farming/tests/phase05_economy.gd"),"legacy scenes and development tests absent")
	if not shots.is_empty():
		DirAccess.make_dir_recursive_absolute(shots)
		await capture("menu.png")
	shell._start_slot("new",1,false)
	await get_tree().process_frame
	var farm = shell.farm
	check(farm != null and farm.economy.primeval_stones == 60,"new slot and baked JSON")
	if farm == null:
		get_tree().quit(1)
		return
	var art_count := 0
	for terrain in farm._terrains_by_id().values():
		if image_ok("res://"+terrain["textures"]["ground"]): art_count += 1
		if terrain["textures"].has("trans") and image_ok("res://"+terrain["textures"]["trans"]): art_count += 1
	for id in farm._crops_by_id:
		var definition: Dictionary = farm._crops_by_id[id]
		for stage in definition["growth_stages"]:
			if image_ok("res://assets/farming/crops/"+id+"/"+stage["sprite"]+".png"): art_count += 1
		if definition["harvest_type"] == "regrow":
			for stage in ["stage_harvested","stage_exhausted"]:
				if image_ok("res://assets/farming/crops/"+id+"/"+stage+".png"): art_count += 1
	check(art_count == 27,"all ground, atlases and crop-state PNGs decode")
	farm._tool_buttons[0].pressed.emit()
	farm._act_on(Vector2i(1,1))
	farm._select_crop(0)
	farm._act_on(Vector2i(1,1))
	for day in range(4): farm.clock.end_day()
	farm._select_kind("harvester")
	farm._act_on(Vector2i(1,1))
	check(farm.inventory.count("dew_leaf") >= 1,"growing and actual harvest")
	check(farm.economy.trade("dew_leaf",1,false)["ok"],"material selling")
	farm.tools.buy("hoe",farm.economy)
	farm.clock.end_day()
	var money: int = farm.economy.primeval_stones
	shell._leave("menu")
	shell._start_slot("continue",1,false)
	await get_tree().process_frame
	check(shell.farm.economy.primeval_stones == money and shell.farm.tools.data["owned"].has("hoe"),"autosave reload includes wallet and tools")
	if not shots.is_empty(): await capture("farm.png")
	shell.show_settings()
	shell._settings_draft["show_fps"] = true
	shell.apply_settings()
	check(shell.settings.data["show_fps"],"separate settings writable")
	if not shots.is_empty(): await capture("settings.png")
	shell._leave("menu")
	for slot in [1,2,3]: shell.store.delete_slot(slot,true)
	DirAccess.remove_absolute(directory+"/slots")
	for suffix in ["", ".bak"]:
		if FileAccess.file_exists(shell.settings.path+suffix): DirAccess.remove_absolute(shell.settings.path+suffix)
	DirAccess.remove_absolute(directory)
	for failure in failures: print("[fail] RELEASE: "+failure)
	print("DEMO RELEASE SMOKE OK" if failures.is_empty() else "DEMO RELEASE SMOKE FAILED")
	get_tree().quit(0 if failures.is_empty() else 1)

func capture(filename: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots+"/"+filename)

func image_ok(path: String) -> bool:
	if OS.has_feature("farm_demo_release"):
		if not ResourceLoader.exists(path): return false
		var texture = load(path)
		return texture is Texture2D and not texture.get_image().is_empty()
	if not FileAccess.file_exists(path): return false
	var decoded := Image.new()
	return decoded.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK and not decoded.is_empty()
