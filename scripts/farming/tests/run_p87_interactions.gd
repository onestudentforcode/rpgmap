extends SceneTree
const Scene := preload("res://scenes/farming/farm_p87.tscn")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
var shell
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func mouse(button: int,pressed: bool,position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = position
	shell.board.gui_input.emit(event)
func screen_cell(cell: Vector2i) -> Vector2:
	return shell.map_port.get_canvas_transform()*shell.projection.ground_to_view(Vector2(cell)*64+Vector2(32,32))
func click(cell: Vector2i) -> void:
	var position := screen_cell(cell)
	mouse(MOUSE_BUTTON_LEFT,true,position)
	mouse(MOUSE_BUTTON_LEFT,false,position)
func _run() -> void:
	shell = Scene.instantiate()
	var path := "res://.art-work/p87-interactions/%d" % Time.get_ticks_usec()
	shell.store = Store.new(path)
	shell.settings = shell.settings.get_script().new(path+".cfg",0.1)
	root.add_child(shell)
	await process_frame
	shell._new(1,false)
	shell._close_page()
	shell.set_process(false)
	shell.world.journal["guide"]["dismissed"] = true
	var original: Dictionary = shell.world.to_snapshot().duplicate(true)
	for size in [Vector2i(2560,1440),Vector2i(1920,1080),Vector2i(960,540)]:
		root.size = size
		for ui_scale in [1.0,1.25,1.5]:
			shell._ui_scale = ui_scale
			for side_open in [false,true]:
				shell._side_open = side_open
				shell._layout()
				await process_frame
				await process_frame
				for zoom in [0.1,1.0,3.0]:
					shell.camera.zoom = Vector2.ONE*zoom
					shell.camera.position = shell.projection.ground_to_view(Vector2(600,500))
					shell.camera.force_update_scroll()
					await process_frame
					for cell in [Vector2i(2,2),Vector2i(9,8),Vector2i(-3,15)]:
						check(shell._cell(screen_cell(cell))==cell,"picker %s ui%s side%s zoom%s %s"%[size,ui_scale,side_open,zoom,cell])
					var cursor := Vector2(shell.map_port.size)*Vector2(0.41,0.37)
					var anchor: Vector2 = shell.map_port.get_canvas_transform().affine_inverse()*cursor
					mouse(MOUSE_BUTTON_WHEEL_UP,true,cursor)
					shell.camera.force_update_scroll()
					await process_frame
					check((shell.map_port.get_canvas_transform().affine_inverse()*cursor).distance_to(anchor)<0.002,"wheel preserves actual view anchor")
					var previous: Vector2 = shell.camera.position
					mouse(MOUSE_BUTTON_MIDDLE,true,cursor)
					var motion := InputEventMouseMotion.new()
					motion.relative = Vector2(12,-6)
					motion.position = cursor+motion.relative
					motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
					shell.board.gui_input.emit(motion)
					check(shell.camera.position.is_equal_approx(previous-motion.relative/shell.camera.zoom),"middle pan moves in projected view space")
					mouse(MOUSE_BUTTON_MIDDLE,false,motion.position)
				shell._fit_map()
				var available := Vector2(shell.map_port.size)-Vector2(shell._camera_side_margin(),shell._camera_bottom_margin())
				var bounds: Rect2 = shell.view_bounds()
				check(bounds.size.x*shell.camera.zoom.x <= available.x+1 and bounds.size.y*shell.camera.zoom.x <= available.y+1,"fit includes ground/tree canvas in usable board")
				shell.camera.position = Vector2(-100000,100000)
				shell._process(0)
				var clamped: Vector2 = shell.camera.position
				shell._process(0)
				check(shell.camera.position.is_equal_approx(clamped),"map boundary clamp stable at current layout")
	check(shell.world.to_snapshot()==original,"window/zoom/pan matrix never changes gameplay")
	# Focus must land in usable screen space, including the compact overlay sidebar.
	root.size = Vector2i(960,540)
	shell._ui_scale = 1.0
	shell._close_page()
	shell.camera.zoom = Vector2.ONE
	shell._locate(Vector2i(6,5))
	await process_frame
	shell.camera.force_update_scroll()
	var selected_screen := screen_cell(Vector2i(6,5))
	check(selected_screen.x < shell.side_panel.position.x-shell.board.position.x,"located cell remains left of compact sidebar")
	check(selected_screen.y < shell.map_port.size.y-shell._camera_bottom_margin(),"located cell remains above toolbar")
	shell._locate_area([3,4,4,2])
	check(not shell.shade.visible,"area locate closes management")
	var area_center: Vector2 = shell.projection.ground_to_view(Vector2(320,320))
	var offset: Vector2 = Vector2(shell._camera_side_margin(),shell._camera_bottom_margin())*0.5/shell.camera.zoom.x
	check(shell.camera.position.is_equal_approx(area_center+offset),"inherited area callback projects center")
	shell._locate_land("west_water")
	check(shell.selected.x<0 and shell.camera.position.x < 256,"negative parcel locate stays on projected west land")
	# Real board signals, real construction and manual actions on a fresh schema17 game.
	shell._new(2,false)
	shell._close_page()
	shell.world.journal["guide"]["dismissed"] = true
	shell._select_tool("till")
	shell.camera.force_update_scroll()
	await process_frame
	var ap: int = shell.world.clock.ap
	click(Vector2i(2,2))
	if shell.world.clock.ap != ap-1:
		printerr("manual diagnostic: ",{"started":shell._started,"manual":shell.manual_mode,"shade":shell.shade.visible,"confirmation":is_instance_valid(shell.confirmation),"focus":shell._text_focus(),"tool":shell.tool,"selected":shell.selected,"notice":shell.notice.text})
	check(shell.world.clock.ap==ap-1 and not shell.world.grid.can_till(Vector2i(2,2))["ok"],"real GUI click tills correct ground")
	check(shell.world.grid.can_till(Vector2i(2,3))["ok"],"next projected row not tilled")
	check(shell.world.workforce.set_seed(Vector2i(2,2),"golden_wheat")["ok"],"assign seed through existing model before planting")
	shell._select_tool("plant")
	await process_frame
	shell.camera.force_update_scroll()
	click(Vector2i(2,2))
	check(not shell.world.instance_at(Vector2i(2,2)).is_empty(),"real GUI plant hits same ground")
	if shell.world.instance_at(Vector2i(2,2)).is_empty(): printerr("plant diagnostic: ",shell.notice.text)
	shell.world.grant_scaffold({"raw_wood":100,"raw_stone":100})
	shell.build_tool = "woodshop"
	shell._close_page()
	shell.camera.force_update_scroll()
	await process_frame
	click(Vector2i(8,10))
	var facility: Dictionary = shell.world.facility_at(Vector2i(8,10))
	check(not facility.is_empty(),"real GUI two-cell facility build")
	if not facility.is_empty():
		shell._locate_facility(int(facility["uid"]))
		check(shell.selected==Vector2i(8,10),"facility locate retains logical origin")
	shell._close_page()
	shell._set_manual(false)
	shell._select_tool("till")
	shell.camera.force_update_scroll()
	await process_frame
	mouse(MOUSE_BUTTON_LEFT,true,screen_cell(Vector2i(3,3)))
	mouse(MOUSE_BUTTON_LEFT,false,screen_cell(Vector2i(5,4)))
	check(shell.world.workforce.state["marks"].size()==6,"projected drag selects exact logical 3x2 area")
	shell._set_manual(true)
	shell._select_tool("inspect")
	shell._close_page()
	shell.camera.force_update_scroll()
	await process_frame
	ap = shell.world.clock.ap
	click(Vector2i(-1,14))
	check(shell._context=="land" and shell.shade.visible,"unowned negative cell opens correct parcel purchase")
	check(shell.world.clock.ap==ap,"opening parcel never spends AP")
	shell._close_page()
	check(not shell.shade.visible,"unowned parcel dialog closes without reopening itself")
	check(shell.world.end_day()["ok"],"projected interactions can save schema17 normally")
	var saved: Dictionary = shell.world.to_snapshot().duplicate(true)
	check(shell.world.open_game(2)["ok"] and shell.world.to_snapshot()==saved,"normal save/open preserves full gameplay")
	for failure in failures: printerr(failure)
	print("P87 INTERACTIONS %s: %d checks"%["OK" if failures.is_empty() else "FAILED",checks])
	quit(0 if failures.is_empty() else 1)
