extends "res://scripts/farming/tests/run_phase102_ui.gd"
const Tutorial := preload("res://scripts/farming/p8/p108_tutorial.gd")
const Grid := preload("res://scripts/farming/core/grid/land_grid.gd")
const StageFixture := preload("res://scripts/farming/tests/p107_fixture.gd")
const BatchUI := preload("res://scripts/farming/p8/p108_batch.gd")

func at(cell: Vector2i) -> Vector2:
	shell.camera.force_update_scroll()
	return shell.map_port.get_canvas_transform()*shell.projection.ground_to_view(Vector2(cell)*64+Vector2(32,32))

func drag(from_cell: Vector2i,to_cell: Vector2i) -> void:
	var a:=at(from_cell)
	var b:=at(to_cell)
	var down:=InputEventMouseButton.new()
	down.position=a;down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true
	shell.board.gui_input.emit(down)
	var motion:=InputEventMouseMotion.new()
	motion.position=b;motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	shell.board.gui_input.emit(motion)
	var up:=InputEventMouseButton.new()
	up.position=b;up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false
	shell.board.gui_input.emit(up)

func titled_button(parent: Node,title: String) -> Button:
	for child in nodes(parent):
		if child is Button and (child.text==title or child.tooltip_text==title): return child
	return null

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="): shots=arg.trim_prefix("--shots=")
	if not shots.is_empty(): DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots))
	root.size=Vector2i(1920,1080)
	shell=Scene.instantiate()
	var folder:="res://.art-work/p108-ui/slots-%d-%d"%[OS.get_process_id(),Time.get_ticks_usec()]
	shell.store=Store.new(folder)
	shell.settings=shell.settings.get_script().new(folder+".cfg",0.1)
	root.add_child(shell)
	await process_frame
	await resize_window(Vector2i(1920,1080))
	shell._new(1,false)
	shell._close_page()
	shell._fit_map()
	var localized_advice: String=shell._tutorial_display_text("golden_wheat、pasture_grass、wood_decay_mushroom、honeybell_bush、oilseed_flower")
	check(localized_advice=="金穗麦、青牧草、木腐菇、蜜铃灌木、油籽花","tutorial route maps crop IDs to Chinese display names")
	var visible_tutorial_text: Array[String]=[]
	for node in nodes(shell.tutorial_body):
		if node is Label: visible_tutorial_text.append(node.text)
	var visible_tutorial_copy: String=" ".join(visible_tutorial_text)
	check(visible_tutorial_copy.contains("金穗麦") and not visible_tutorial_copy.contains("golden_wheat"),"visible route advice displays the localized crop name")
	var base: Rect2i=shell.world.land.base
	var till_rect:=Rect2i(base.position+Vector2i(2,2),Vector2i(3,2))
	shell._select_tool("till")
	drag(till_rect.position,till_rect.end-Vector2i.ONE)
	check(shell.world.grid.state_at(till_rect.position)==Grid.State.TILLED,"real projected drag tills a rectangle")
	var golden_index:=0
	for i in range(shell.crop_picker.item_count):
		if String(shell.crop_picker.get_item_metadata(i))=="golden_wheat": golden_index=i
	shell.crop_picker.select(golden_index)
	shell.crop_picker.item_selected.emit(golden_index)
	shell._select_tool("plant")
	drag(till_rect.position,till_rect.end-Vector2i.ONE)
	check(shell.world.instance_at(till_rect.position).get("crop_id","")=="golden_wheat","tool-selected crop batch plants through real map drag")
	check(shell.world.workforce.seed_plan(till_rect.position).get("crop_id","")=="golden_wheat","successful UI planting persists future seed plan")
	var cell_pick:=till_rect.position
	shell._select_tool("plant")
	drag(cell_pick,cell_pick)
	var selected_heading:=String((shell.sidebar.get_child(0) as Label).text)
	check(shell.selected==cell_pick and selected_heading=="地格 (%d,%d)"%[cell_pick.x,cell_pick.y],"clicking an invalid action target immediately refreshes the selected-cell sidebar")
	var quarry_cell:=Vector2i(15,8)
	var ap_before_inspection:=int(shell.world.clock.ap)
	shell._select_tool("inspect")
	drag(quarry_cell,quarry_cell)
	var quarry_labels: Array[String]=[]
	for node in nodes(shell.sidebar):
		if node is Label: quarry_labels.append(node.text)
	check(shell.world.source_at(quarry_cell)=="stone_source" and shell.selected==quarry_cell and "采石点" in quarry_labels and int(shell.world.clock.ap)==ap_before_inspection,"inspect click opens quarry details directly without batch work or AP cost")
	var reverse_rect:=Rect2i(base.position+Vector2i(8,2),Vector2i(2,2))
	shell._select_tool("till")
	drag(reverse_rect.end-Vector2i.ONE,reverse_rect.position)
	check(shell.world.grid.state_at(reverse_rect.position)==Grid.State.TILLED and shell.world.grid.state_at(reverse_rect.end-Vector2i.ONE)==Grid.State.TILLED,"reverse drag normalizes the same rectangular till target")
	var seed_targets: Array[Vector2i]=[till_rect.position+Vector2i(till_rect.size.x,0),till_rect.position+Vector2i(till_rect.size.x,1)]
	for cell in seed_targets: check(shell.world.rooms.set_floor(cell,"farmland")["ok"],"seed-copy target is explicit farmland")
	var field_cells:=BatchUI.cells(till_rect)
	for cell in seed_targets: field_cells.append(cell)
	var field_keys:=[]
	for cell in field_cells: field_keys.append(shell.world.rooms.key(cell))
	var field_result: Dictionary=shell.world.rooms.create_field(field_keys,"P108 copy field")
	if not field_result["ok"]: print("P108 UI field fixture failed: ",field_result)
	check(field_result["ok"],"seed-copy fixture is one explicit field")
	shell.selected=till_rect.position;shell._show_cell()
	var seed_copy:=titled_button(shell.sidebar,"复制此处配置")
	check(seed_copy!=null,"planted crop exposes seed-plan copy")
	if seed_copy!=null:
		seed_copy.pressed.emit()
		shell._run_copy_rectangle(Rect2i(seed_targets[0],Vector2i(1,2)))
		check(shell.world.workforce.seed_plan(seed_targets[0]).get("crop_id","")=="golden_wheat" and shell.world.workforce.seed_plan(seed_targets[1]).get("crop_id","")=="golden_wheat","copy pastes only the seed plan across compatible field cells")
		check(shell.world.instance_at(seed_targets[0]).is_empty() and shell.world.instance_at(seed_targets[1]).is_empty(),"seed-plan copy does not plant crops")
		seed_copy=titled_button(shell.sidebar,"复制此处配置")
		if seed_copy!=null: seed_copy.pressed.emit()
		shell._run_copy_rectangle(Rect2i(seed_targets[0],Vector2i(1,3)))
		check(shell.world.workforce.seed_plan(seed_targets[0]+Vector2i(0,2)).is_empty() and shell.notice.text.contains("成功2处，跳过1处"),"mixed copy rectangle applies compatible targets and reports invalid ones")
		seed_copy=titled_button(shell.sidebar,"复制此处配置")
		if seed_copy!=null: seed_copy.pressed.emit()
		shell._run_copy_rectangle(Rect2i(seed_targets[0]+Vector2i(0,2),Vector2i.ONE))
		check(shell.world.workforce.seed_plan(seed_targets[0]+Vector2i(0,2)).is_empty() and shell.notice.text.contains("成功0处，跳过1处"),"copy to an incompatible target has no partial write")
	for size in [Vector2i(960,540),Vector2i(1400,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
		await resize_window(size)
		await process_frame
		var watch_rect: Rect2=shell.watch_panel.get_global_rect()
		var tutorial_rect: Rect2=shell.tutorial_panel.get_global_rect()
		var toolbar_rect: Rect2=shell.toolbar_panel.get_global_rect()
		check(not (shell.watch_panel.visible and watch_rect.intersects(tutorial_rect)),"resource watch and tutorial do not overlap "+str(size))
		check(not toolbar_rect.intersects(tutorial_rect),"tutorial avoids the farming toolbar "+str(size))
		await capture("main-guidance-%d"%size.x)
	# Check every supported global UI scale against all four target windows,
	# with the crop picker visible so it participates in layout collision checks.
	shell._select_tool("plant")
	for size in [Vector2i(960,540),Vector2i(1400,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
		for scale in [1.0,1.25,1.5]:
			await resize_window(size)
			shell._ui_scale=scale
			shell._layout()
			await process_frame
			var watch: Rect2=shell.watch_panel.get_global_rect()
			var guidance: Rect2=shell.tutorial_panel.get_global_rect()
			var toolbar: Rect2=shell.toolbar_panel.get_global_rect()
			var sidebar: Rect2=shell.side_panel.get_global_rect()
			var picker: Rect2=shell.crop_picker.get_global_rect()
			check(not (shell.watch_panel.visible and watch.intersects(guidance)),"resource watch avoids guidance at %s scale %d"%[size,roundi(scale*100)])
			check(not toolbar.intersects(guidance),"farming toolbar avoids guidance at %s scale %d"%[size,roundi(scale*100)])
			check(not (shell.side_panel.visible and sidebar.intersects(guidance)),"detail sidebar avoids guidance at %s scale %d"%[size,roundi(scale*100)])
			check(not (shell.crop_picker.visible and picker.intersects(guidance)),"crop picker avoids guidance at %s scale %d"%[size,roundi(scale*100)])
			check(guidance.position.x>=0 and guidance.position.y>=0 and guidance.end.x<=size.x+1 and guidance.end.y<=size.y+1,"guidance stays in viewport at %s scale %d"%[size,roundi(scale*100)])
			await capture("main-guidance-%d-scale-%d"%[size.x,roundi(scale*100)])
	shell._ui_scale=1.0
	shell._layout()
	shell._select_tool("till")
	await resize_window(Vector2i(960,540))
	await process_frame
	var guidance_expanded_height: float=shell.tutorial_panel.size.y
	var fold:=titled_button(shell.tutorial_panel,"收起")
	check(fold!=null,"tutorial panel exposes fold control")
	if fold!=null:
		fold.pressed.emit()
		await process_frame
		check(bool(shell.world.preferences["tutorial"]["collapsed"]) and shell.tutorial_panel.size.y<guidance_expanded_height,"folding reduces the tutorial to its compact current goal")
		await capture("main-guidance-collapsed-960")
		var expand:=titled_button(shell.tutorial_panel,"展开")
		if expand!=null: expand.pressed.emit()
	check(shell.tutorial_panel.visible,"fresh save shows nonblocking tutorial panel")
	var stop:=titled_button(shell.tutorial_panel,"取消指引")
	check(stop!=null,"tutorial exposes an explicit cancel control")
	if stop!=null: stop.pressed.emit()
	check(not bool(shell.world.preferences["tutorial"]["enabled"]) and not shell.tutorial_panel.visible,"cancel hides tutorial and persists preference")
	var cancelled_save: Dictionary=shell.store.read_slot(1)
	check(cancelled_save.get("ok",false) and not bool(cancelled_save["snapshot"]["preferences"]["tutorial"]["enabled"]),"cancel is persisted immediately in the active save slot")
	shell._show_help()
	var resume:=titled_button(shell.sidebar,"恢复指引")
	check(resume!=null,"manual can restore a cancelled tutorial")
	if resume!=null: resume.pressed.emit()
	check(bool(shell.world.preferences["tutorial"]["enabled"]),"restore reenables tutorial without resetting progress")
	var restored_save: Dictionary=shell.store.read_slot(1)
	check(restored_save.get("ok",false) and bool(restored_save["snapshot"]["preferences"]["tutorial"]["enabled"]),"manual restore is persisted immediately in the active save slot")
	for size in [Vector2i(960,540),Vector2i(1400,900),Vector2i(1920,1080)]:
		await resize_window(size)
		shell._show_help()
		shell._set_reading(true,2)
		await process_frame
		var panel: Rect2=shell.window_panel.get_global_rect()
		check(panel.position.x>=0 and panel.position.y>=0 and panel.end.x<=size.x+1 and panel.end.y<=size.y+1,"expanded reading fits viewport "+str(size))
		check(shell.reading_font==2 and shell.reading_expanded,"reading controls retain selected preference")
		await capture("reading-%d"%size.x)
		shell._set_reading(false,1)
	# Config copy remains a whitelist operation and reuses the original device API.
	StageFixture.unlock(shell.world,1)
	shell.world.research.state["completed"].append("field_maintenance")
	shell.world.inventory.add("wood_plank",20)
	shell.world.inventory.add("iron_ingot",10)
	shell.world.primeval_stones+=200
	var source:=base.position+Vector2i(10,2)
	var target:=base.position+Vector2i(11,2)
	var a: Dictionary=shell.world.build_facility(source,"field_service_station")
	var b: Dictionary=shell.world.build_facility(target,"field_service_station")
	check(a.get("ok",false) and b.get("ok",false),"configuration copy station fixtures build")
	if a.get("ok",false) and b.get("ok",false):
		var source_uid:=int(shell.world.facility_at(source)["uid"])
		var target_uid:=int(shell.world.facility_at(target)["uid"])
		shell.world.devices.configure_station(source_uid,false,true,47)
		shell.selected=source;shell._show_cell()
		var copy:=titled_button(shell.sidebar,"复制此处配置")
		check(copy!=null,"station details expose copy configuration")
		if copy!=null:
			copy.pressed.emit()
			shell._run_copy_rectangle(Rect2i(target,Vector2i.ONE))
			var device: Dictionary=shell.world.devices.device_of(target_uid)
			check(not bool(device.get("irrigate",true)) and bool(device.get("fertilize",false)) and int(device.get("threshold",0))==47,"copy applies station whitelist via its settings API")
	# The production strategy whitelist must copy settings only, leaving target
	# batches and resources untouched.
	shell.world.inventory.add("raw_wood",12)
	shell.world.inventory.add("raw_stone",12)
	var wood_a: Dictionary=shell.world.build_facility(base.position+Vector2i(15,3),"woodshop")
	var wood_b: Dictionary=shell.world.build_facility(base.position+Vector2i(18,3),"woodshop")
	check(wood_a.get("ok",false) and wood_b.get("ok",false),"production-copy fixtures build real facilities")
	if wood_a.get("ok",false) and wood_b.get("ok",false):
		var source_uid:=int(shell.world.facility_at(base.position+Vector2i(15,3))["uid"])
		var target_uid:=int(shell.world.facility_at(base.position+Vector2i(18,3))["uid"])
		var source_strategy: Dictionary=shell.world.operations.set_production(source_uid,true,"saw_planks","wood_plank",4)
		if not source_strategy["ok"]: print("P108 UI source strategy failed: ",source_strategy)
		var target_batch: Dictionary=shell.world.facilities[target_uid]["batch"].duplicate(true)
		shell.selected=base.position+Vector2i(15,3);shell._show_cell()
		var copy:=titled_button(shell.sidebar,"复制此处配置")
		check(copy!=null,"ordinary processor exposes strategy copy")
		if copy!=null:
			copy.pressed.emit()
			shell._run_copy_rectangle(Rect2i(base.position+Vector2i(18,3),Vector2i.ONE))
			var strategy: Dictionary=shell.world.operations.strategy_of(target_uid)
			if not bool(strategy["enabled"]): print("P108 UI copied strategy mismatch: ",strategy," clipboard=",shell.copy_config)
			check(bool(strategy["enabled"]) and strategy["recipe_id"]=="saw_planks" and strategy["target_item"]=="wood_plank" and int(strategy["target_qty"])==4,"copy applies ordinary production strategy whitelist")
			check(shell.world.facilities[target_uid]["batch"]==target_batch,"copy leaves the target's in-progress batch untouched")
	print("P108 UI %s (%d)"%["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
