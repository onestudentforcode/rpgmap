extends SceneTree
## Checks reversible visual trial changes against the actual P8 model.
const Shell := preload("res://scripts/farming/p8/p8_scene.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const TrialEnvironment := preload("res://scripts/farming/p8/p86_environment_trial.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok: failures.append(caption)

func _run() -> void:
	var shell := Shell.new()
	shell.production_visuals = false
	var directory := "res://.art-work/p86-environment-check"
	DirAccess.make_dir_recursive_absolute(directory)
	shell.store = Store.new(directory+"/slots-%d" % Time.get_ticks_usec())
	shell.settings = shell.settings.get_script().new(directory+"/settings.cfg",0.1)
	root.add_child(shell)
	await process_frame
	shell._new(1,false)
	shell._close_page()
	var before: Dictionary = shell.world.to_snapshot().duplicate(true)
	var old_materials := {}
	var old_sources := {}
	for ident in shell.terrain.layers: old_materials[ident] = shell.terrain.layers[ident].material
	for index in shell.terrain.tileset.get_source_count():
		var source_id: int = shell.terrain.tileset.get_source_id(index)
		old_sources[source_id] = shell.terrain.tileset.get_source(source_id).texture
	var trial := TrialEnvironment.new()
	check(trial.prepare_assets().is_empty(),"valid asset preflight")
	check(shell.world.to_snapshot() == before,"asset preflight leaves operating snapshot unchanged")
	check(shell.terrain.layers["grass"].material == old_materials["grass"],"asset preflight leaves visual profile unchanged")
	trial.apply(shell)
	check(trial.diagnostics.is_empty(),"trial PNGs decoded without errors")
	check(shell.world.to_snapshot() == before,"apply leaves entire operating snapshot unchanged")
	for ident in TrialEnvironment.TONES:
		check(shell.terrain.layers[ident].material != old_materials[ident],"trial material "+ident)
	check(trial._shore_root.get_child_count() == 1,"real north reservoir shore forms one visual segment")
	var source_rect := Rect2(Vector2(15,8)*64.0,Vector2(64,64))
	var source: Dictionary = trial.source_visual("stone_source",source_rect)
	check(not source.is_empty() and source["root"] == source_rect.get_center(),"stone-source fixed center root")
	check(trial.source_visual("ore_source",source_rect).is_empty(),"ore placeholder remains outside trial")
	check(trial.source_visual("spring_source",source_rect).is_empty(),"spring placeholder remains outside trial")
	var active_grass = shell.terrain.layers["grass"].material
	var missing := TrialEnvironment.new()
	missing.asset_directory = directory+"/missing-%d" % Time.get_ticks_usec()
	check(not missing.prepare_assets().is_empty(),"missing assets fail preflight")
	missing.apply(shell)
	check(shell.terrain.layers["grass"].material == active_grass,"missing-asset apply keeps existing visual profile")
	check(shell.world.to_snapshot() == before,"missing-asset apply leaves operating snapshot unchanged")
	var corrupt := TrialEnvironment.new()
	corrupt.asset_directory = directory+"/bad-meta-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(corrupt.asset_directory)
	for filename in ["transition_soft.png","transition-report.json","stone_source.png"]:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(trial.asset_directory+"/"+filename),ProjectSettings.globalize_path(corrupt.asset_directory+"/"+filename))
	var invalid_meta := FileAccess.open(corrupt.asset_directory+"/stone-source-report.json",FileAccess.WRITE)
	invalid_meta.store_string("{\"anchor_uv\":[\"invalid\",2]}")
	invalid_meta.close()
	check(not corrupt.prepare_assets().is_empty(),"invalid metadata fails preflight")
	corrupt.apply(shell)
	check(shell.terrain.layers["grass"].material == active_grass,"invalid-metadata apply keeps existing visual profile")
	check(shell.world.to_snapshot() == before,"invalid-metadata apply leaves operating snapshot unchanged")
	trial.apply(shell)
	check(shell.world.to_snapshot() == before,"repeat apply is observational")
	check(trial._shore_root.get_child_count() == 1,"repeat apply does not duplicate shore")
	trial.restore(shell)
	check(shell.world.to_snapshot() == before,"restore leaves entire operating snapshot unchanged")
	for ident in old_materials:
		check(shell.terrain.layers[ident].material == old_materials[ident],"restored material "+ident)
	for source_id in old_sources:
		check(shell.terrain.tileset.get_source(source_id).texture == old_sources[source_id],"restored atlas %d" % source_id)
	check(not shell.overlay.get_parent().has_node("P86ShorelineTrial"),"restore removes shore node")
	check(trial.source_visual("stone_source",source_rect).is_empty(),"restore releases trial resource visual")
	trial.restore(shell)
	check(shell.world.to_snapshot() == before,"repeat restore remains observational")
	check(not shell.world.changed.is_connected(trial._refresh_shores),"restore disconnects shore refresh")
	for failure in failures: printerr("P86 ENVIRONMENT FAIL: ",failure)
	print("P86 ENVIRONMENT CHECK ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
