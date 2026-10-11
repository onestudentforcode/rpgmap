extends Node
## Real no-injection45-day route, in both source and exported PCK.
const Playthrough := preload("res://scripts/farming/validation/v2_playthrough.gd")
var shell
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func run() -> void:
	await get_tree().process_frame
	check(not shell._started and shell.manual_mode and shell.world._items.size() == 25,"V2 menu and manual default")
	check(shell.terrain.used_count("water") == 160 and shell.world.grid.height == 22,"actual20x22 map has bottom20x8 reservoir")
	if OS.has_feature("farm_demo_v2_release"):
		check(not ResourceLoader.exists("res://scenes/farming/farm_v1.tscn") and not ResourceLoader.exists("res://scenes/farming/farm_demo.tscn") and not ResourceLoader.exists("res://scripts/farming/tests/run_phase07f.gd"),"package excludes old scenes and development tests")
	var decoded := 0
	for terrain in JSON.parse_string(FileAccess.get_file_as_string("res://content/farming/baked/v2/terrains.json"))["terrains"]:
		for path in terrain["textures"].values():
			var texture = load("res://"+path)
			if texture is Texture2D and not texture.get_image().is_empty(): decoded += 1
	check(decoded == 8,"five ground textures and three transition atlases decode")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/farming/ui/manifest.json"))
	decoded = 0
	for id in manifest["icons"]:
		var texture = load("res://assets/farming/ui/%s.svg" % id)
		if texture is Texture2D and not texture.get_image().is_empty(): decoded += 1
	check(decoded == manifest["icons"].size(),"all UI symbols decode in the running build")
	shell._new(1,false)
	var world = shell.world
	check(world.primeval_stones == 60 and world.preferences["watched"].is_empty(),"fresh60 and player-chosen watch list")
	# Avoid rebuilding identical widgets for every strategy action in one frame.
	world.changed.disconnect(shell._refresh)
	var result: Dictionary = Playthrough.new().run(world,"A")
	world.changed.connect(shell._refresh)
	check(result["status"] == "passed","real45-day husbandry, manure, five paths and reinvestment")
	for failure in result["failures"]: failures.append(String(failure))
	check(world.clock.total_days == 46 and result["day46_freeze_checked"],"daily save/reload and continued play preserve frozen recap")
	check(world.workforce.state["workers"].size() == 2 and world.workforce.state["spent"] > 0,"exclusive caretaker patrols actually charge fees")
	check(world.preferences["watched"] == ["fodder_grass","clean_water"],"watch choices restore from the actual daily save")
	await get_tree().process_frame
	shell._refresh()
	shell._show_husbandry_overview()
	check(shell._context == "overview","management overview opens")
	shell._show_resources()
	check(shell._context == "resources" and world.ledger.state["history"].size() == 15,"actual/average resource page and15-day ledger")
	shell._show_recap(-1)
	await get_tree().process_frame
	check(shell._context == "recap" and world.reports.recap_active(),"45-day total recap renders in the executable")
	for index in range(3): shell._show_recap(index)
	check(shell.sidebar.get_child_count() > 0,"all three term tabs render")
	shell._close_page()
	var directory: String = shell.store.slot_path(1).get_base_dir()
	for slot in [1,2,3]:
		if shell.store.occupied(slot): shell.store.delete_slot(slot,true)
	check(not shell.store.occupied(1),"test slot cleaned without touching player slots")
	DirAccess.remove_absolute(directory)
	for failure in failures: printerr(failure)
	print("V2 RELEASE SMOKE %s: %d checks" % ["OK" if failures.is_empty() else "FAIL",checks])
	get_tree().quit(0 if failures.is_empty() else 1)
