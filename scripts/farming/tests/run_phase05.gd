extends SceneTree
const Tests := preload("res://scripts/farming/tests/phase05_economy.gd")

func _initialize() -> void:
	var fails := Tests.run()
	for failure in fails:
		printerr(failure)
	quit(0 if fails.is_empty() else 1)
