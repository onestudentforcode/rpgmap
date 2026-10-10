extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var fails: Array[String] = await load("res://scripts/farming/tests/phase06_records.gd").run(self)
	for failure in fails: print("[fail] " + failure)
	print("PHASE06 RECORDS TEST OK" if fails.is_empty() else "PHASE06 RECORDS TEST FAILED")
	quit(0 if fails.is_empty() else 1)
