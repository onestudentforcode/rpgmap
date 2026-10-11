extends SceneTree
## Render QA uses real playthrough snapshots. Optional interactive mode leaves
## an isolated window open for native mouse checks; never opens player slots.
const Scene := preload("res://scenes/farming/farm_v2.tscn")
const Store := preload("res://scripts/farming/v2/v2_slot_store.gd")
const Settings := preload("res://scripts/farming/v1/v1_settings.gd")
var shell
var directory := "res://.shots/phase07f"
var state_path := "res://.art-work/phase07f-routeB-day30.json"
var interactive := false

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="): directory = arg.trim_prefix("--shots=")
		if arg.begins_with("--state="): state_path = arg.trim_prefix("--state=")
		if arg == "--interactive": interactive = true
	shell = Scene.instantiate()
	shell.store = Store.new("user://phase07f_ui_%d" % Time.get_ticks_usec())
	shell.settings = Settings.new("res://.art-work/phase07f-ui-settings.cfg",0.1)
	shell.product_title = "灵田 Demo V2 · P7.f 验收"
	root.add_child(shell)
	await process_frame
	shell._new(1,false)
	var snapshot = JSON.parse_string(FileAccess.get_file_as_string(state_path))
	var result: Dictionary = shell.world.apply_snapshot(snapshot)
	if not result["ok"]: printerr(result["reason"]); _cleanup(); quit(1); return
	await shell._prepare_preview(directory)
	shell._fit_map()
	shell._close_page()
	await shell._shot(directory,"main")
	if interactive:
		print("V2 INTERACTIVE REVIEW READY ",state_path)
		return
	var checks := []
	for page in ["overview","pen","pond","resources","workers","report"]:
		shell._close_page()
		match page:
			"overview": shell._show_husbandry_overview()
			"pen": shell._locate_facility(1)
			"pond": shell._locate_facility(2)
			"resources": shell._show_resources()
			"workers":
				for i in range(3): shell.world.workforce.hire("验收名册%d" % (i+3))
				shell._show_workers()
			"report": shell._show_report()
		await shell._shot(directory,page)
		checks.append({"page":page,"panel":[shell.window_panel.position.x,shell.window_panel.position.y,shell.window_panel.size.x,shell.window_panel.size.y],"ui_size":[shell.ui_root.size.x,shell.ui_root.size.y],"requested_scale":shell._ui_scale,"effective_scale":shell.ui_root.scale.x})
		if shell.shade.visible and (shell.watch_panel.visible or shell.window_panel.position.x+shell.window_panel.size.x > shell.ui_root.size.x+1):
			printerr("HUD overlap or horizontal panel overflow: ",page); _cleanup(); quit(1); return
	var recap = JSON.parse_string(FileAccess.get_file_as_string("res://.art-work/phase07f-routeB-day45.json"))
	if not shell.world.apply_snapshot(recap)["ok"]: printerr("actual day45 snapshot invalid"); _cleanup(); quit(1); return
	shell._show_recap(-1)
	await shell._shot(directory,"recap")
	var file := FileAccess.open(directory+"/layout.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"source":state_path,"recap_source":"phase07f-routeB-day45.json","roster_fixture":"three freely recruited idle employees","checks":checks},"\t"))
	_cleanup()
	print("V2 UI REVIEW SHOTS OK ",directory)
	quit()

func _cleanup() -> void:
	for slot in [1,2,3]:
		if shell.store.occupied(slot): shell.store.delete_slot(slot,true)
	DirAccess.remove_absolute(shell.store.slot_path(1).get_base_dir())
	shell.queue_free()
