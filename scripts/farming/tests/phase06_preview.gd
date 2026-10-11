extends SceneTree
const Slots := preload("res://scripts/farming/core/storage/farm_slot_store.gd")
const Snapshot := preload("res://scripts/farming/core/storage/farm_snapshot.gd")
var _directory: String
var _output: String
var _shell

func _initialize() -> void:
	_run.call_deferred()

func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	if _shell.is_modal():
		assert(Rect2(Vector2.ZERO,Vector2(640,360)).encloses(_shell._surface.get_child(1).get_rect()), "Menu must fit viewport")
	root.get_texture().get_image().save_png(_output + "/" + filename)

func _run() -> void:
	_directory = "user://farm_phase06_preview_%d" % Time.get_ticks_usec()
	_output = ProjectSettings.globalize_path("res://.shots/farm-phase06b")
	DirAccess.make_dir_recursive_absolute(_output)
	var store := Slots.new(_directory)
	var snapshot := Snapshot.fresh()
	snapshot["clock"]["total_days"] = 12
	store.create_slot(1,snapshot)
	store.create_slot(2,Snapshot.fresh())
	store.close_session()
	_shell = load("res://scripts/farming/rendering/farm_demo.gd").new()
	_shell.store = store
	_shell.legacy_path = _directory + "/legacy.json"
	var file := FileAccess.open(_shell.legacy_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot))
	file.close()
	root.add_child(_shell)
	await _capture("main-menu.png")
	_shell._show_slots("continue")
	await _capture("slots.png")
	_shell._show_slots("new")
	_shell._select_slot("new",1)
	await _capture("overwrite.png")
	_shell._show_slots("continue")
	_shell._confirm_delete(2)
	await _capture("delete.png")
	_shell._show_slots("continue")
	_shell._select_slot("continue",1)
	await _capture("farm.png")
	_shell.show_pause()
	await _capture("pause.png")
	_shell.request_exit("menu")
	await _capture("exit-choice.png")
	_shell.choose_exit("cancel")
	_shell._last_result = {"ok": false, "reason": "模拟磁盘写入失败"}
	_shell._pending_snapshot = _shell.farm.capture_snapshot()
	_shell._show_save_error()
	await _capture("save-error.png")
	_shell._leave("menu")
	for slot in [1,2,3]: store.delete_slot(slot,true)
	DirAccess.remove_absolute(_shell.legacy_path)
	DirAccess.remove_absolute(_directory)
	print("DEMO PREVIEW OK: eight views within logical viewport")
	quit()
