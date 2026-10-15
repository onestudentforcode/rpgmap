extends SceneTree
## Trial isolation, reversible caches and root/geometry compatibility.
const Grounding := preload("res://scripts/farming/p8/p8_grounding.gd")
const Shell := preload("res://scripts/farming/p8/p8_scene.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
class AssetFixtureShell extends Shell:
	var asset_override := ""
	func _make_trial_environment():
		var environment = super()
		if environment != null and not asset_override.is_empty(): environment.asset_directory = asset_override
		return environment
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var grounding := Grounding.new()
	check(Grounding.ground_root([-2,3],[1,1]) == Vector2(-96,256),"plant root retains negative-coordinate bottom center")
	check(Grounding.ground_root([-2,3],[2,2],"facility") == Vector2(-64,256),"facility root retains floor center")
	var plant := grounding.crop_shadow("golden_wheat","stage_0",Vector2(-96,256))
	var mature := grounding.crop_shadow("golden_wheat","stage_3",Vector2(-96,256))
	check(plant["root"] == mature["root"] and plant["rect"].size.x < mature["rect"].size.x,"stage contacts share root and retain seedling hierarchy")
	check(plant["texture"] == mature["texture"],"land contacts reuse independent cache")
	var water := grounding.facility_shadow("fish_pond",Vector2(32,32))
	check(water["kind"] == "water","pond gets water contact")
	var water_image: Image = water["texture"].get_image()
	check(water_image.get_pixel(64,64).a < 0.01 and water_image.get_pixel(108,64).a > 0.3,"water contact leaves center transparent")
	check(grounding.facility_shadow("unknown",Vector2.ZERO).is_empty(),"unknown contacts safely omit")
	var directory := "res://.art-work/p86-grounding-tests/%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	check(not Grounding.new(directory+"/missing-contact.json").diagnostics.is_empty(),"missing contact config reports failure")
	var shell := AssetFixtureShell.new()
	shell.production_visuals = false
	shell.store = Store.new(directory+"/slots")
	shell.settings = shell.settings.get_script().new(directory+"/settings.cfg",0.1)
	root.add_child(shell)
	await process_frame
	shell._new(1,false)
	var snapshot: Dictionary = shell.world.to_snapshot().duplicate(true)
	var crop := {"crop_id":"golden_wheat","origin":[-2,3],"state":"growing","progress":0}
	var definition: Dictionary = shell.world.crop_defs["golden_wheat"]
	var original: Dictionary = shell.plant_visuals.visual(crop,definition,[300,500])
	var baseline_presentation := _presentation(shell)
	check(shell.visual_trial_profile == "baseline" and shell.trial_environment == null,"default shell stays baseline")
	var contact_result: Dictionary = shell.configure_visual_trial("grounding")
	check(contact_result["ok"] and contact_result["replaced"].is_empty(),"grounding enables without replacing bodies")
	check(shell.plant_visuals.visual(crop,definition,[300,500]) == original,"grounding leaves original visual contract identical")
	var relative := "assets/farming/crops/golden_wheat/stage_0.png"
	DirAccess.make_dir_recursive_absolute(directory.path_join(relative.get_base_dir()))
	var image := Image.create(256,256,false,Image.FORMAT_RGBA8)
	image.fill(Color(0.2,0.45,0.25,1.0))
	check(image.save_png(directory.path_join(relative)) == OK,"candidate fixture saved outside approved assets")
	var trial_result: Dictionary = shell.configure_visual_trial("integrated",directory)
	var trial: Dictionary = shell.plant_visuals.visual(crop,definition,[300,500])
	check(trial_result["ok"] and trial_result["replaced"] == ["golden_wheat/stage_0"],"only available juvenile candidate replaces cache")
	check(trial["texture"] != original["texture"] and trial["rect"] == original["rect"] and trial["root"] == original["root"] and trial["key"] == original["key"],"candidate preserves approved geometry/state")
	var integrated_presentation := _presentation(shell)
	image = Image.create(8,8,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	image.save_png(directory.path_join(relative))
	trial_result = shell.configure_visual_trial("integrated",directory)
	check(not trial_result["ok"] and trial_result["replaced"].is_empty() and not trial_result["diagnostics"].is_empty(),"bad candidate canvas fails the profile change")
	check(_presentation(shell) == integrated_presentation,"bad candidate preserves complete previous integrated presentation")
	trial_result = shell.configure_visual_trial("integrated",directory+"/empty-candidates")
	check(not trial_result["ok"] and not trial_result["diagnostics"].is_empty(),"nonempty directory with zero candidates reports failure")
	check(_presentation(shell) == integrated_presentation,"zero candidates leaves previous profile and caches intact")
	image = Image.create(256,256,false,Image.FORMAT_RGBA8)
	image.fill(Color(0.2,0.45,0.25,1.0))
	image.save_png(directory.path_join(relative))
	shell.asset_override = directory+"/missing-environment"
	trial_result = shell.configure_visual_trial("integrated",directory)
	check(not trial_result["ok"] and not trial_result["diagnostics"].is_empty(),"missing required environment assets propagate to configure failure")
	check(_presentation(shell) == integrated_presentation,"missing environment retains old materials atlases resource and shore instances")
	check(not shell.configure_visual_trial("not-a-profile")["ok"] and shell.visual_trial_profile == "integrated","invalid profile preserves current trial")
	check(_presentation(shell) == integrated_presentation,"invalid profile is fully atomic")
	shell.asset_override = ""
	shell.configure_visual_trial("baseline")
	check(shell.plant_visuals.visual(crop,definition,[300,500]) == original,"baseline restores original cached texture and geometry")
	check(_presentation(shell) == baseline_presentation,"baseline restores exact original materials textures filters and scene nodes")
	check(shell.world.to_snapshot() == snapshot,"trial switching leaves model and save data unchanged")
	for failure in failures: printerr(failure)
	print("P86 GROUNDING TRIAL %s: %d checks" % ["OK" if failures.is_empty() else "FAILED",checks])
	quit(0 if failures.is_empty() else 1)

func _presentation(shell) -> Dictionary:
	var materials := {}
	var filters := {}
	var atlas_textures := {}
	for ident in shell.terrain.layers:
		materials[ident] = shell.terrain.layers[ident].material
		filters[ident] = shell.terrain.layers[ident].texture_filter
	for index in shell.terrain.tileset.get_source_count():
		var source_id: int = shell.terrain.tileset.get_source_id(index)
		atlas_textures[source_id] = shell.terrain.tileset.get_source(source_id).texture
	return {"profile":shell.visual_trial_profile,"environment":shell.trial_environment,
		"plants":shell.plant_visuals.textures.duplicate(),"facilities":shell.facility_visuals.textures.duplicate(),
		"materials":materials,"filters":filters,"atlases":atlas_textures,
		"shore":shell.overlay.get_parent().get_node_or_null("P86ShorelineTrial")}
