extends SceneTree
const Tests := preload("res://scripts/farming/tests/phase06_slots.gd")
func _initialize() -> void:
	var fails := Tests.run()
	for failure in fails:
		printerr(failure)
	print("PHASE06 SLOT TEST OK" if fails.is_empty() else "PHASE06 SLOT TEST FAIL")
	quit(0 if fails.is_empty() else 1)
