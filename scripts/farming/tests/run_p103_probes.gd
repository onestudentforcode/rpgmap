extends SceneTree
## P10.3.f tamper probes: every forged snapshot in .art-work/p103-playtest/probes
## must be rejected by the game codec; every honest final snapshot must load.
const Codec := preload("res://scripts/farming/p8/p8_snapshot.gd")
var checks := 0
var failures: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr(label)

func _initialize() -> void:
	var root := "res://.art-work/p103-playtest"
	var dir := DirAccess.open(root + "/probes")
	var files := []
	if dir != null:
		files = Array(dir.get_files()).filter(func(name): return String(name).ends_with(".json"))
	files.sort()
	check(not files.is_empty(), "probe snapshots exist")
	for name in files:
		var text := FileAccess.get_file_as_string(root + "/probes/" + name)
		var parsed = JSON.parse_string(text)
		check(parsed is Dictionary, "probe parses " + name)
		if not parsed is Dictionary:
			continue
		var result: Dictionary = Codec.normalize(parsed)
		check(not result["ok"], "codec rejects " + name)
	for name in ["nursery", "mixed-maintenance", "shift-work", "shortage-fatigue",
			"enclosure-breeding", "work-A", "work-B", "enclosure-A", "enclosure-B"]:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(root + "/" + name + "-final.json"))
		check(Codec.normalize(parsed)["ok"], "honest final loads " + name)
	print("P103 PROBES %s (%d)" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
