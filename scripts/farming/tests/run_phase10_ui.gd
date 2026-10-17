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
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	if shots.is_empty() or DisplayServer.get_name() == "headless": return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(shots.path_join(name+".png"))
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="): shots = arg.trim_prefix("--shots=")
	if not shots.is_empty(): DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots))
	root.size = Vector2i(2560,1440)
	shell = Scene.instantiate()
	var directory := "res://.art-work/p10-ui/slots-%d" % Time.get_ticks_usec()
	shell.store = Store.new(directory)
	shell.settings = shell.settings.get_script().new(directory+".cfg",0.1)
	root.add_child(shell)
	await process_frame
	shell._new(1,false)
	shell._close_page()
	shell.world.journal["guide"]["dismissed"] = true
	shell.logistics_ui.open()
	check(button("领取试用蛊虫")!=null,"trial provision visible")
	button("领取试用蛊虫").pressed.emit()
	check(shell.world.logistics.state["provisioned"],"real provision button grants once")
	check(button("领取试用蛊虫")==null,"provision disappears after claim")
	await capture("01-manager")
	button("地图部署").pressed.emit()
	check(not shell.logistics_ui.placing.is_empty(),"placement mode selected through UI")
	var cell := Vector2i(5,5)
	shell.camera.force_update_scroll()
	await process_frame
	var point: Vector2 = shell.map_port.get_canvas_transform()*shell.projection.ground_to_view(Vector2(cell)*64+Vector2(32,32))
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		shell.board.gui_input.emit(event)
	check(not shell.world.logistics.at(cell).is_empty(),"projected board click deploys the correct cell")
	check(shell.logistics_ui.placing.is_empty(),"placement finishes once")
	shell.world.end_day()
	shell.world.end_day()
	shell.world.end_day()
	shell.world.end_day()
	shell.selected = cell
	shell._show_cell()
	check(button("收取")!=null,"ready gu exposes real claim button")
	await capture("02-ready-map")
	button("收取").pressed.emit()
	check(shell.world.inventory.count("rice")==4,"UI claim enters inventory")
	var snapshot: Dictionary = shell.world.to_snapshot()
	shell.encyclopedia.open("gu:rice_bag_gu")
	check(shell.encyclopedia.current_id=="gu:rice_bag_gu","encyclopedia gu entry accessible")
	check(shell.world.to_snapshot()==snapshot,"reading has no gameplay side effects")
	await capture("03-encyclopedia")
	for size in [Vector2i(1920,1080),Vector2i(960,540)]:
		root.size = size
		shell._layout()
		shell.logistics_ui.open()
		await process_frame
		await process_frame
		check(shell.window_panel.size.x<=shell.get_viewport_rect().size.x,"manager fits viewport "+str(size))
		await capture("04-manager-%d" % size.x)
	# Real host management, research descriptions and gu mode are built from the
	# exact live shell; only setup stock/knowledge below is a UI test fixture.
	shell._close_page()
	shell.world.grant_scaffold({"raw_wood":8,"raw_stone":8,"wood_plank":8,"iron_ingot":4,"composite_stone_panel":4})
	shell.world.research.state["completed"] = shell.world.research.project_defs().keys()
	for spec in [["research_bench",8,4],["growth_lamp",3,10],["field_service_station",6,9]]:
		var c := Vector2i(spec[1],spec[2])
		check(shell.world.build_facility(c,spec[0])["ok"],"host fixture "+spec[0])
		shell.selected = c
		shell._show_cell()
		check(button("管理入驻与维护")!=null,"host shows slot management "+spec[0])
	root.size=Vector2i(2560,1440)
	shell._layout()
	shell.logistics_ui.open()
	await capture("05-host-options")
	button("地图选择兼容设施").pressed.emit()
	check(shell.logistics_ui.placing=="trial-003","host placement mode selected through manager")
	shell.camera.force_update_scroll()
	await process_frame
	point = shell.map_port.get_canvas_transform()*shell.projection.ground_to_view(Vector2(3,10)*64+Vector2(32,32))
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.position=point
		event.pressed=pressed
		shell.board.gui_input.emit(event)
	check(int(shell.world.logistics.instance("trial-003")["host_uid"])>0 and shell.logistics_ui.placing.is_empty(),"projected click admits gu to compatible host once")
	shell.world.end_day()
	shell.logistics_ui.focused="trial-003"
	shell.overlay.queue_redraw()
	await capture("06-light-range")
	shell.logistics_ui.placing="trial-006"
	shell._new(2,false)
	var ap: int = shell.world.clock.ap
	shell._apply_manual(Vector2i(5,5))
	check(shell.logistics_ui.placing.is_empty() and shell.world.clock.ap==ap,"switching slot invalidates old placement without crash or AP cost")
	print("PHASE10 UI %s (%d)" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
