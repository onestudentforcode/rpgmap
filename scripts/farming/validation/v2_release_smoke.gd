extends Node
var shell
func run() -> void:
	await get_tree().process_frame
	var ok: bool = shell.manual_mode and shell.world._items.size() == 25 and shell.terrain.used_count("water") == 160
	shell._new(1,false)
	ok = ok and shell.world.till(Vector2i(2,2))["ok"] and shell.world.end_day()["ok"]
	var snapshot: Dictionary = shell.world.to_snapshot()
	ok = ok and shell.world.open_game(1)["ok"] and snapshot == shell.world.to_snapshot()
	var directory: String = shell.store.slot_path(1).get_base_dir()
	shell.store.delete_slot(1,true)
	DirAccess.remove_absolute(directory)
	print("V2 P7.a SMOKE ", "OK" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
