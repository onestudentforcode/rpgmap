extends SceneTree
const Handbook := preload("res://scripts/farming/p8/p8_handbook.gd")
const TARGET := "res://docs/farming/demo-p8-新手手册.md"
func _initialize() -> void:
	var expected := Handbook.markdown()
	if OS.get_cmdline_user_args().has("--check"):
		if not FileAccess.file_exists(TARGET) or FileAccess.get_file_as_string(TARGET).replace("\r\n", "\n") != expected:
			printerr("P8 HANDBOOK DOC FAIL: regenerate the player document")
			quit(1)
			return
	else:
		var file := FileAccess.open(TARGET, FileAccess.WRITE)
		if file == null:
			printerr("P8 HANDBOOK DOC FAIL: cannot write the player document")
			quit(1)
			return
		file.store_string(expected)
		file.close()
	print("P8 HANDBOOK DOC OK: %d chapters" % Handbook.CHAPTERS.size())
	quit(0)
