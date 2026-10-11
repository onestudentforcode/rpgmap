extends SceneTree
const Tests := preload("res://scripts/farming/tests/phase06_demo.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var fails := await Tests.run(self)
	for failure in fails:
		printerr(failure)
	print("PHASE06 DEMO TEST OK" if fails.is_empty() else "PHASE06 DEMO TEST FAIL")
	quit(0 if fails.is_empty() else 1)
