extends Node
## Exercise exported resources and slots. Opt-in only, never uses player directories.
var shell
var failures: Array[String] = []
var checks := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func run() -> void:
	await get_tree().process_frame
	check(not shell._started and shell.world._items.size() == 18,"V1 default menu and baked resource catalogue")
	check(ProjectSettings.get_setting("application/config/name") == "Sisyphus Mall MVP","historical application identity preserves existing user save paths")
	if OS.has_feature("farm_demo_v1_release"):
		check(not ResourceLoader.exists("res://scenes/farming/farm_demo.tscn") and not ResourceLoader.exists("res://scripts/farming/tests/run_v1_journal.gd"),"release contains no V0 scene or development tests")
	var count := 0
	for terrain in JSON.parse_string(FileAccess.get_file_as_string("res://content/farming/baked/terrains.json"))["terrains"]:
		for texture_path in terrain["textures"].values():
			var texture = load("res://"+texture_path)
			if texture is Texture2D and not texture.get_image().is_empty(): count += 1
	check(count == 7,"all four ground textures and three transition atlases decode")
	var symbols: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/farming/ui/manifest.json"))
	var decoded := 0
	for ident in symbols["icons"]:
		var icon = load("res://assets/farming/ui/%s.svg" % ident)
		if icon is Texture2D and icon.get_size() == Vector2(64,64) and not icon.get_image().is_empty(): decoded += 1
	check(decoded == symbols["icons"].size(),"all Phase6.5 vector symbols decode from exported resources")
	check(shell.get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED and shell.tool_buttons["clear"].accessibility_name.contains("清理"),"V1 responsive layout and compact accessible icon controls")
	shell._new(1,false)
	var world = shell.world
	check(shell._started and world.primeval_stones == 60,"new V1 slot uses initial60")
	world.workforce.hire("验收雇工")
	world.workforce.assign_source("spring_source",1)
	world.end_day()
	check(world.inventory.count("clean_water") == 30 and world.primeval_stones == 54,"exported worker commission and payroll")
	check(shell.digest.visible and world.journal["history"].size() == 1,"daily entry digest available")
	world.workforce.dismiss(1)
	world.workforce.set_seed(Vector2i(2,2),"golden_wheat")
	world.till(Vector2i(2,2))
	world.plant(Vector2i(2,2),"golden_wheat")
	world.guide_dismiss(true)
	while world.clock.total_days < 6: world.end_day()
	check(world.harvest(Vector2i(2,2))["ok"],"actual crop growth and harvesting in exported game")
	while world.clock.total_days < 45: world.end_day()
	await get_tree().process_frame
	check(world.journal["frozen"] and shell._context == "recap","day45 recap automatically shown")
	var snapshot: Dictionary = world.to_snapshot()
	check(world.open_game(1)["ok"] and world.to_snapshot() == snapshot and world.journal["guide"]["dismissed"],"exported autosave restores journal and guide")
	check(world.end_day()["ok"] and world.clock.total_days == 46 and world.journal["terms"] == snapshot["journal"]["terms"],"free play after frozen recap")
	var directory: String = shell.store.slot_path(1).get_base_dir()
	for slot in [1,2,3]:
		if shell.store.occupied(slot): shell.store.delete_slot(slot,true)
	DirAccess.remove_absolute(directory)
	for failure in failures: printerr(failure)
	print("V1 RELEASE SMOKE %s: %d checks" % ["OK" if failures.is_empty() else "FAIL",checks])
	get_tree().quit(0 if failures.is_empty() else 1)
