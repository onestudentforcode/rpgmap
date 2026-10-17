extends SceneTree
const Scene := preload("res://scenes/farming/farm_p87.tscn")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const CropFixture := preload("res://scripts/farming/tests/p8_crop_fixture.gd")
var shell
var checks:=0
var failures:=[]
var shots:=""
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr(label)
func nodes(parent: Node) -> Array:
	var out:=[]
	for child in parent.get_children(): out.append(child);out.append_array(nodes(child))
	return out
func button(prefix: String) -> Button:
	for child in nodes(shell.sidebar):
		if child is Button and (child.text.begins_with(prefix) or String(child.get_meta("action_name","")).begins_with(prefix)): return child
	return null
func click(cell: Vector2i) -> void:
	shell.camera.force_update_scroll()
	shell._hover=cell
	var point: Vector2=shell.map_port.get_canvas_transform()*shell.projection.ground_to_view(Vector2(cell)*64+Vector2(32,32))
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		shell.board.gui_input.emit(event)
func capture(name: String) -> void:
	if shots.is_empty() or DisplayServer.get_name()=="headless": return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var frame:=root.get_texture().get_image()
	check(frame.get_size()==root.size,"capture matches actual viewport "+name)
	frame.save_png(shots.path_join(name+".png"))
func resize_window(dimensions: Vector2i) -> void:
	root.mode=Window.MODE_WINDOWED
	root.size=dimensions
	await process_frame
	await process_frame
	shell._layout()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="): shots=arg.trim_prefix("--shots=")
	if not shots.is_empty(): DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots))
	root.size=Vector2i(1920,1080)
	shell=Scene.instantiate()
	var folder:="res://.art-work/p102-ui/slots-%d" % Time.get_ticks_usec()
	shell.store=Store.new(folder)
	shell.settings=shell.settings.get_script().new(folder+".cfg",0.1)
	root.add_child(shell)
	await process_frame
	await resize_window(Vector2i(1920,1080))
	shell._new(1,false)
	shell._close_page()
	shell.world.grant_scaffold({"raw_wood":20,"wood_plank":20,"iron_ingot":10,"golden_wheat_seed":20})
	shell.rooms_ui.open()
	check(button("普通地板")!=null,"floor control exposed")
	button("普通地板").pressed.emit()
	click(Vector2i(3,3))
	check(shell.world.rooms.floor_kind(Vector2i(3,3))=="ordinary","projected click places floor")
	shell.rooms_ui.open();button("耕地").pressed.emit();click(Vector2i(3,3))
	check(shell.world.rooms.farmland(Vector2i(3,3)),"projected click converts floor to farmland")
	shell.world.rooms.set_floor(Vector2i(3,3),"natural")
	shell.world.logistics.provision()
	shell.world.research.state["completed"]=shell.world.research.project_defs().keys()
	for spec in [[5,4,"east","trial-004"],[9,4,"west","trial-008"],[7,2,"south","trial-010"]]:
		var c:=Vector2i(spec[0],spec[1])
		check(shell.world.build_facility(c,"field_service_station",spec[2])["ok"],"UI host fixture")
		var uid: int=shell.world.facility_at(c)["uid"]
		shell.world.devices.configure_station(uid,false,false,30)
		shell.world.logistics.deploy(spec[3],Vector2i(-1,-1),uid)
	for y in range(3,6):
		for x in range(6,9): shell.world.till(Vector2i(x,y))
	shell.world.end_day()
	shell.world.plant(Vector2i(6,3),"golden_wheat")
	shell.rooms_ui.show_regions=true
	shell.rooms_ui.floor_tool=""
	shell._close_page()
	shell._fit_map()
	await capture("01-field-and-stations")
	shell.rooms_ui.choose_floor("farmland")
	var motion:=InputEventMouseMotion.new()
	motion.position=shell.map_port.get_canvas_transform()*shell.projection.ground_to_view(Vector2(6,2)*64+Vector2(32,32))
	shell.board.gui_input.emit(motion)
	check(shell.hover_hint.text.contains("将降低房间收益资格"),"hover warns of room downgrade before placement")
	await capture("01b-downgrade-preview")
	shell.rooms_ui.floor_tool=""
	var before: Dictionary=shell.world.to_snapshot()
	shell.rooms_ui.open()
	check(shell.world.to_snapshot()==before,"reading room manager has no side effects")
	var text:=""
	for child in nodes(shell.sidebar):
		if child is Label: text+=child.text
	check(text.contains("二级·复合农业区"),"manager explains level2")
	check(shell.encyclopedia.has("rule:rooms"),"room encyclopedia rule exists")
	shell.encyclopedia.open("rule:rooms")
	check(shell.encyclopedia.current_id=="rule:rooms" and shell.world.to_snapshot()==before,"room encyclopedia is read-only")
	shell.rooms_ui.open()
	await capture("02-manager")
	for size in [Vector2i(1920,1080),Vector2i(960,540)]:
		await resize_window(size)
		shell.rooms_ui.open()
		await process_frame
		check(Vector2i(shell.get_viewport_rect().size)==size,"actual viewport matches requested "+str(size))
		check(shell.window_panel.size.x<=shell.get_viewport_rect().size.x,"manager fits "+str(size))
		check(shell.window_scroll.size.y>100 and shell.window_panel.get_global_rect().end.y<=size.y,"manager scroll and bottom reachable "+str(size))
		await capture("03-manager-%d"%size.x)
	shell._close_page();shell.selected=Vector2i(6,3);shell._show_cell()
	check(button("查看农业区")!=null,"crop exposes room provenance")
	await capture("04-crop-reward")
	for i in range(3): shell.world.end_day()
	var harvest: Dictionary=shell.world.harvest(Vector2i(6,3))
	shell._result(harvest)
	check(shell.notice.text.contains("基础收成") and shell.notice.text.contains("育种奖励") and shell.notice.text.contains("丰产奖励"),"claim feedback separates all reward channels")
	shell._show_report()
	text=""
	for child in nodes(shell.sidebar):
		if child is Label: text+=child.text
	check(text.contains("农业收获") and text.contains("未领取权益不计入"),"report distinguishes actual stock from pending rights")
	# Visual-only setup: inspect adjacent single-cell hosts, paving, roots,
	# shadows and a real 2x2 plant. Not a normal-economy business fixture.
	shell.world.primeval_stones+=100
	shell.world._cash("sales_revenue",100)
	for cell in [Vector2i(3,3),Vector2i(4,3),Vector2i(3,4),Vector2i(4,4)]:
		check(shell.world.rooms.set_floor(cell,"ordinary")["ok"],"dense sample ordinary paving "+str(cell))
	for cell in [Vector2i(3,3),Vector2i(4,3)]:
		check(shell.world.build_facility(cell,"field_service_station")["ok"],"adjacent single-cell hosts build "+str(cell))
	check(shell.world.plant(Vector2i(6,3),"fast_fir")["ok"],"2x2 crop beside single-cell stations")
	CropFixture.progress(shell.world,int(shell.world.instance_at(Vector2i(6,3))["uid"]),800)
	await resize_window(Vector2i(1920,1080))
	shell._select_tool("inspect");shell._locate(Vector2i(6,4))
	shell.camera.zoom=Vector2(2,2);shell.camera.force_update_scroll()
	await process_frame
	for cell in [Vector2i(3,3),Vector2i(4,3)]:
		click(cell)
		check(shell.selected==cell and not shell.world.facility_at(cell).is_empty(),"adjacent station projected pickup is distinct "+str(cell))
	await capture("05-dense-stations-paving-tree")
	shell.rooms_ui.choose_floor("ordinary")
	shell._new(2,false)
	check(shell.rooms_ui.floor_tool.is_empty(),"new slot clears old floor mode")
	print("P102 UI %s (%d)" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
