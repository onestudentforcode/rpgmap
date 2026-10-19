extends SceneTree
const Scene := preload("res://scenes/farming/farm_p87.tscn")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
var shell
var checks := 0
var failures := []
var shots := ""
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr(label)
func nodes(node: Node) -> Array:
	var out := []
	for child in node.get_children(): out.append(child); out.append_array(nodes(child))
	return out
func button(prefix: String) -> Button:
	for node in nodes(shell.sidebar):
		if node is Button and (node.text.begins_with(prefix) or String(node.get_meta("action_name","")).begins_with(prefix)): return node
	return null
func labels() -> Array:
	var out := []
	for node in nodes(shell.sidebar):
		if node is Label: out.append(node.text)
	return out
func card_button(card_text: String, prefix: String) -> Button:
	for node in nodes(shell.sidebar):
		if node is Label and node.text.contains(card_text):
			var parent = node.get_parent()
			while parent != null and parent != shell.sidebar:
				for child in parent.get_children():
					if child is Button and (child.text.begins_with(prefix) or String(child.get_meta("action_name","")).begins_with(prefix)):
						return child
				parent = parent.get_parent()
	return null
func option(items_text: String) -> OptionButton:
	for node in nodes(shell.sidebar):
		if node is OptionButton:
			for index in node.item_count:
				if node.get_item_text(index).contains(items_text): return node
	return null
func click(cell: Vector2i) -> void:
	shell.camera.force_update_scroll()
	shell._hover = cell
	var point: Vector2 = shell.map_port.get_canvas_transform()*shell.projection.ground_to_view(Vector2(cell)*64+Vector2(32,32))
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		shell.board.gui_input.emit(event)
func capture(name: String) -> void:
	if shots.is_empty() or DisplayServer.get_name() == "headless": return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name+".png"))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="): shots = arg.trim_prefix("--shots=")
	if not shots.is_empty(): DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots))
	root.size = Vector2i(2560,1440)
	shell = Scene.instantiate()
	var directory := "res://.art-work/p101-ui/slots-%d" % Time.get_ticks_usec()
	shell.store = Store.new(directory)
	shell.settings = shell.settings.get_script().new(directory+".cfg",0.1)
	root.add_child(shell)
	await process_frame
	shell._new(1,false)
	shell._close_page()
	shell.world.journal["guide"]["dismissed"] = true
	shell.logistics_ui.open()
	button("领取试用蛊虫").pressed.emit()
	check(shell.world.logistics.state["instances"].size()==11,"provision button grants eleven instances")
	await capture("01-manager")
	shell.world.grant_scaffold({"raw_wood":8,"raw_stone":8,"wood_plank":8,"iron_ingot":4,"composite_stone_panel":4,"grass_seed":4,"honeybell_seed":2,"fast_fir_seed":2})
	shell.world.research.state["completed"] = shell.world.research.project_defs().keys()
	# Build page offers the orientation selector; choosing south locks the zone.
	shell._show_build()
	var facing := option("南向")
	check(facing!=null,"station build page offers orientation options")
	var south := -1
	for index in facing.item_count:
		if facing.get_item_text(index).contains("南向"): south = index
	facing.select(south)
	facing.item_selected.emit(south)
	check(shell.build_facing=="south","orientation selector updates the pending build")
	var ap: int = shell.world.clock.ap
	check(card_button("田间维护站","放置")!=null,"station placement button visible")
	card_button("田间维护站","放置").pressed.emit()
	click(Vector2i(4,4))
	var station_uid := 0
	for uid in shell.world.facilities:
		if shell.world.facilities[uid]["origin"]==[4,4]: station_uid = int(uid)
	check(station_uid>0,"projected click builds the station")
	check(shell.world.logistics.facing_of(station_uid)=="south","built station carries the chosen facing")
	check(shell.world.clock.ap==ap-1,"placement costs exactly 1 AP")
	shell.world.end_day()
	# Admit the water gu through the real manager flow.
	shell.logistics_ui.open()
	for pair in [["trial-004","催生蛊"],["trial-008","锁水蛊"]]:
		var id: String = pair[0]
		shell.logistics_ui.focused = id
		shell.logistics_ui.open()
		card_button(pair[1],"地图选择兼容设施").pressed.emit()
		check(shell.logistics_ui.placing==id,"host placement mode selected for "+id)
		click(Vector2i(4,4))
		check(int(shell.world.logistics.instance(id)["host_uid"])==station_uid,"projected click admits "+id)
		shell.world.logistics.withdraw(id)
	shell.logistics_ui.focused = "trial-008"
	shell.logistics_ui.open()
	card_button("锁水蛊","地图选择兼容设施").pressed.emit()
	click(Vector2i(4,4))
	check(int(shell.world.logistics.instance("trial-008")["host_uid"])==station_uid,"water gu occupies the single slot after withdraw")
	await capture("02-host-admit")
	shell.world.end_day()
	# Host panel: facing display, turn buttons, zone/maintenance separation.
	shell.selected = Vector2i(4,4)
	shell._show_cell()
	check(button("转向东")!=null and button("转向北")!=null,"host panel shows real turn buttons")
	var zone_lines := 0
	for text in labels():
		if text.contains("蛊服务区"): zone_lines += 1
	check(zone_lines>=1,"host panel states the gu service zone separately")
	ap = shell.world.clock.ap
	button("转向东").pressed.emit()
	check(shell.world.logistics.next_facing_of(station_uid)=="east","turn button commits next-day east")
	check(shell.world.logistics.facing_of(station_uid)=="south","today's locked facing is unchanged")
	check(shell.world.clock.ap==ap-1,"turning costs 1 AP")
	check(button("转向东")!=null and button("转向东").disabled,"committed facing disables its own button")
	shell.world.end_day()
	check(shell.world.logistics.facing_of(station_uid)=="east","opening promotes the committed facing")
	# Crop panels explain adoption, suppression and partial coverage.
	shell.world.logistics.set_facing(station_uid,"south")
	shell.world.end_day()
	shell.world.till(Vector2i(4,7))
	shell.world.till(Vector2i(5,7))
	shell.world.till(Vector2i(5,8))
	shell.world.till(Vector2i(6,7))
	shell.world.till(Vector2i(6,8))
	shell.world.plant(Vector2i(4,7),"pasture_grass")
	shell.world.plant(Vector2i(5,7),"fast_fir")
	shell.world.end_day()
	shell.selected = Vector2i(4,7)
	shell._show_cell()
	var served := false
	for text in labels():
		if text.contains("水耗保留50%"): served = true
	check(served,"covered crop shows the resolved retention")
	shell.selected = Vector2i(5,7)
	shell._show_cell()
	var partial := false
	for text in labels():
		if text.contains("部分覆盖"): partial = true
	check(partial,"straddling 2x2 crop explains partial coverage")
	await capture("03-crop-explanations")
	# Encyclopedia carries the new gu and the agriculture rule; reading is free.
	var snapshot: Dictionary = shell.world.to_snapshot()
	shell.encyclopedia.open("gu:water_gu")
	check(shell.encyclopedia.current_id=="gu:water_gu","encyclopedia water gu entry accessible")
	shell.encyclopedia.open("rule:agriculture")
	check(shell.encyclopedia.current_id=="rule:agriculture","encyclopedia agriculture rule accessible")
	check(shell.world.to_snapshot()==snapshot,"reading has no gameplay side effects")
	await capture("04-encyclopedia")
	for size in [Vector2i(1920,1080),Vector2i(960,540)]:
		root.size = size
		shell._layout()
		shell.logistics_ui.open()
		await process_frame
		await process_frame
		check(shell.window_panel.size.x<=shell.get_viewport_rect().size.x,"manager fits viewport "+str(size))
		shell.selected = Vector2i(4,4)
		shell._show_cell()
		await process_frame
		check(shell.window_panel.size.x<=shell.get_viewport_rect().size.x,"host panel fits viewport "+str(size))
		await capture("05-panels-%d" % size.x)
	print("PHASE101 UI %s (%d)" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
