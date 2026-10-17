extends SceneTree
## Real shell/controls, isolated workspace slot. Reading never changes gameplay.
const Shell := preload("res://scripts/farming/p8/p8_scene.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const Handbook := preload("res://scripts/farming/p8/p8_handbook.gd")
var failures: Array[String] = []
var checks := 0
var shell

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func nodes(parent: Node) -> Array:
	var found := []
	for child in parent.get_children():
		found.append(child)
		found.append_array(nodes(child))
	return found

func selector() -> OptionButton:
	for node in nodes(shell.sidebar):
		if node is OptionButton and node.has_meta("handbook_chapters"): return node
	return null

func text_of_page() -> String:
	var parts := PackedStringArray()
	for node in nodes(shell.sidebar):
		if node is Label: parts.append(node.text)
	return "\n".join(parts)

func choose(index: int) -> void:
	var picker := selector()
	picker.select(index)
	picker.item_selected.emit(index)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	shell = Shell.new()
	shell.store = Store.new("res://.art-work/p8-handbook/ui-slots-%d" % Time.get_ticks_usec())
	shell.settings = shell.settings.get_script().new("res://.art-work/p8-handbook/settings.cfg", 0.1)
	root.add_child(shell)
	await process_frame
	check(not shell._started, "shell begins at slots")
	shell._show_help()
	check(shell._context == "help" and selector().item_count == Handbook.CHAPTERS.size(), "existing handbook entry opens all chapters before a new game")
	for node in nodes(shell.sidebar):
		if node is Button and node.has_meta("handbook_target"):
			check(node.disabled, "navigation waits for a game")
	shell._close_page()
	shell._new(1, false)
	check(shell._started and shell.world.primeval_stones == 90, "fresh isolated P8 game")
	var before: Dictionary = shell.world.to_snapshot().duplicate(true)
	shell._show_help()
	var ids := {}
	for index in range(Handbook.CHAPTERS.size()):
		choose(index)
		var entry: Dictionary = Handbook.CHAPTERS[index]
		var id := String(entry["id"])
		check(not ids.has(id) and not entry["cards"].is_empty(), "chapter content exists " + id)
		ids[id] = true
		check(shell._handbook_chapter == id and selector().selected == index, "real chapter selection " + id)
		var text := text_of_page()
		check(text.contains(String(entry["cards"][0]["title"])) and text.contains(String(entry["cards"][-1]["steps"][-1])), "chapter renders first and last instructions " + id)
		check(not text.contains("一人一设施") and not text.contains("未实施路线"), "no obsolete guidance " + id)
	check(ids.has("route_a") and ids.has("route_b"), "both verified sample routes available")
	check(shell.world.to_snapshot() == before, "reading all chapters spends no AP/currency and changes no game state")
	var target_context := {"market": "market", "build": "build", "research": "research", "workers": "workers", "resources": "resources", "orders": "orders"}
	for target in target_context:
		shell._handbook_chapter = "route_b"
		shell._show_help()
		var link: Button
		for node in nodes(shell.sidebar):
			if node is Button and node.get_meta("handbook_target", "") == target: link = node
		check(link != null and not link.disabled, "navigation control " + target)
		if link == null: continue
		link.pressed.emit()
		check(shell._context == target_context[target], "real navigation event " + target)
		shell._show_help()
		check(shell._handbook_chapter == "route_b", "return preserves chapter " + target)
	check(shell.world.to_snapshot() == before, "navigation opens pages without gameplay changes")
	check(shell.world.end_day()["ok"], "ordinary day ends and saves")
	check(shell._context == "help" and shell._handbook_chapter == "route_b" and selector() != null, "daily refresh preserves handbook chapter")
	check(not shell.world.daily_save_error.length(), "no save error after reading")
	for failure in failures: printerr(failure)
	print("P8 HANDBOOK UI %s: %d checks" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
