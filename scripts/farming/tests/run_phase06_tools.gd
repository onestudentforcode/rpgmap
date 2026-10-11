extends SceneTree
func _initialize(): _run.call_deferred()
func _run():
	var tests = load("res://scripts/farming/tests/phase06_tools.gd").new()
	var fails: Array[String] = await tests.run(self)
	if not tests.completed: fails.append("工具测试未完整执行")
	for failure in fails: print("[fail] " + failure)
	print("PHASE06 TOOLS TEST OK" if fails.is_empty() else "PHASE06 TOOLS TEST FAILED")
	quit(0 if fails.is_empty() else 1)
