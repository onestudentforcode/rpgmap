extends "res://scripts/farming/tests/run_phase102_ui.gd"
const StageFixture := preload("res://scripts/farming/tests/p107_fixture.gd")

func marked(key: String, value) -> Button:
	for child in nodes(shell.sidebar):
		if child is Button and child.has_meta(key) and child.get_meta(key) == value: return child
	return null

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="): shots = arg.trim_prefix("--shots=")
	if not shots.is_empty(): DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots))
	shell = Scene.instantiate()
	var folder := "res://.art-work/p107-ui/slots-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	shell.store = Store.new(folder)
	shell.settings = shell.settings.get_script().new(folder + ".cfg", 0.1)
	root.add_child(shell)
	await process_frame
	shell._new(1, false)
	shell._show_market()
	check(marked("p107_navigation", true) != null, "market has discoverable stage/barter entry")
	marked("p107_navigation", true).pressed.emit()
	check(shell._context == "economy", "navigation opens actual economy page")
	check(marked("p107_event", "first_workshop").disabled, "unmet stage event disabled")
	StageFixture.unlock(shell.world, 1)
	shell.world.grant_scaffold({"resin": 100})
	shell.economy_ui.open()
	var old: int = shell.world.inventory.count("sludge")
	var cash: int = shell.world.primeval_stones
	var count: int = shell.world.progress.deliveries()
	var btn := marked("p107_offer", "resin_for_sludge")
	check(btn != null and not btn.disabled, "available barter button enabled")
	btn.pressed.emit()
	check(shell.world.inventory.count("sludge") == old + 2, "actual UI click transfers materials")
	check(shell.world.primeval_stones == cash and shell.world.progress.deliveries() == count, "UI exchange charges no cash and no supply count")
	var batch_selector: OptionButton
	for node in nodes(shell.sidebar):
		if node is OptionButton and node.name == "ExchangeBatchCount": batch_selector = node
	check(batch_selector != null, "batch selector is present on the real page")
	if batch_selector == null:
		quit(1)
		return
	batch_selector.select(1)
	batch_selector.item_selected.emit(1)
	check(shell.economy_ui.batches == 5, "actual selector signal changes batch count and rebuilds quotes")
	marked("p107_offer", "resin_for_sludge").pressed.emit()
	check(shell.world.inventory.count("sludge") == old + 12 and shell.world.primeval_stones == cash and shell.world.progress.deliveries() == count,
		"actual five-batch button debits and transfers five lots without fee or order credit")
	check(marked("p107_offer", "resin_for_panels").disabled, "later-stage offer visibly locked")
	StageFixture.unlock(shell.world, 2)
	shell.world.grant_scaffold(shell.world.progress.config["events"][2]["inputs"])
	for size in [Vector2i(960, 540), Vector2i(1400, 900), Vector2i(1920, 1080)]:
		await resize_window(size)
		var before: Dictionary = shell.world.to_snapshot()
		shell.economy_ui.open()
		await process_frame
		check(shell.world.to_snapshot() == before, "reading page and quotes is pure " + str(size))
		check(shell.window_panel.size.x <= size.x and shell.window_panel.get_global_rect().end.y <= size.y,
			"scrolling economy page fits " + str(size))
		await capture("economy-%d" % size.x)
	check(not marked("p107_event", "integrated_estate").disabled, "resource event accepts inventory from exchanges or production")
	marked("p107_event", "integrated_estate").pressed.emit()
	check(shell.world.progress.stage() == 3, "actual UI submits advanced event")
	check(marked("p107_event", "integrated_estate") == null, "completed event cannot be clicked twice")
	shell._show_orders()
	check(marked("p107_navigation", true) != null, "orders also exposes economy entry")
	print("P107 UI %s (%d)" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
