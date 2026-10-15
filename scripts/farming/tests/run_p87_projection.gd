extends SceneTree
const GroundProjection := preload("res://scripts/farming/p8/p87_projection.gd")
const Trial := preload("res://scripts/farming/p8/p87_projection_trial.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var projection := GroundProjection.new()
	projection.configure(true)
	var calibration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(projection.config["calibration_report"]))
	check(calibration["body_renders_checked"] == 44,"44 actual body cameras audited")
	check(absf(projection.ground_to_view(Vector2(64,64)).y-float(calibration["projected_cell_size"][1])) < 0.0001,"projection matches independent Blender calibration")
	for cell in [Vector2i(-4,14),Vector2i(-1,0),Vector2i(0,0),Vector2i(19,21)]:
		for offset in [Vector2(0.002,0.002),Vector2(32,32),Vector2(63.998,63.998)]:
			var point: Vector2 = Vector2(cell)*64+offset
			check(projection.view_to_ground(projection.ground_to_view(point)).distance_to(point)<0.0001,"point roundtrip %s"%point)
			check(projection.cell_at(projection.ground_to_view(point))==cell,"half-open cell including negatives %s"%point)
	var shell := Trial.new()
	var path := "res://.art-work/p87-tests/%d" % Time.get_ticks_usec()
	shell.store = Store.new(path)
	shell.settings = shell.settings.get_script().new(path+".cfg",0.1)
	root.add_child(shell)
	await process_frame
	shell._new(1,false)
	shell._close_page()
	shell.set_process(false)
	var before: Dictionary = shell.world.to_snapshot().duplicate(true)
	for profile in ["p86","matched35","p86","matched35"]:
		check(shell.configure_projection(profile)["ok"],"configure "+profile)
		check(shell.world.to_snapshot()==before,"projection leaves schema17 snapshot identical")
		for layer: TileMapLayer in shell.terrain.layers.values(): check(is_equal_approx(layer.scale.y,shell.projection.depth),"ground transforms with profile")
	check(not shell.configure_projection("invalid")["ok"] and shell.projection.enabled,"bad profile preserves state")
	for ident in shell.world.crop_defs:
		var definition: Dictionary = shell.world.crop_defs[ident]
		shell.world.crops[1] = {"uid":1,"crop_id":ident,"origin":[2,2],"state":"mature","progress":int(definition["days"])*100,"harvest_count":0}
		var item: Dictionary = shell.collect_entities().filter(func(e: Dictionary): return e["kind"] == "crop")[0]
		var visual: Dictionary = item["visual"]
		var rect: Rect2 = shell.projection.body_rect(visual,item["root"])
		var anchor: Array = shell.plant_visuals.plants[ident]["anchor_uv"]
		check(rect.size.is_equal_approx(visual["rect"].size),"body not vertically squashed "+ident)
		check((rect.position+rect.size*Vector2(anchor[0],anchor[1])).distance_to(shell.projection.ground_to_view(item["rect"].get_center()))<0.0001,"real model origin at footprint center "+ident)
		var contact: Dictionary = shell.contact_visual(item)
		var old: Dictionary = shell._trial_grounding.crop_shadow(ident,visual["key"],item["root"])
		check(contact["rect"].size==old["rect"].size,"contact not squashed twice "+ident)
	shell.world.crops.clear()
	for zoom in [0.1,1.0,3.0]:
		shell.camera.zoom = Vector2.ONE*zoom
		shell.camera.position = shell.projection.ground_to_view(Vector2(300,240))
		shell.camera.force_update_scroll()
		await process_frame
		for cell in [Vector2i(1,1),Vector2i(6,4),Vector2i(-1,14)]:
			var screen := shell.map_port.get_canvas_transform()*shell.projection.ground_to_view(Vector2(cell)*64+Vector2(32,32))
			check(shell._cell(screen)==cell,"viewport/camera inverse picks correct ground %s/%s"%[zoom,cell])
	# Real click path: projected target must till exactly one intended grid cell.
	shell.world.journal["guide"]["dismissed"] = true
	shell._select_tool("till")
	var target := Vector2i(2,2)
	check(shell.world.grid.can_till(target)["ok"],"real action fixture is legal")
	shell.camera.zoom = Vector2.ONE
	shell.camera.force_update_scroll()
	await process_frame
	var screen := shell.map_port.get_canvas_transform()*shell.projection.ground_to_view(Vector2(target)*64+Vector2(32,32))
	var ap: int = shell.world.clock.ap
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = screen
		shell._board_input(event)
	check(shell.world.clock.ap==ap-1,"projected click spends one AP")
	if shell.world.clock.ap != ap-1:
		printerr("click diagnostic: ",{"started":shell._started,"shade":shell.shade.visible,"confirmation":is_instance_valid(shell.confirmation),"text_focus":shell._text_focus(),"cell":shell._cell(screen),"tool":shell.tool,"notice":shell.notice.text})
	check(not shell.world.grid.can_till(target)["ok"],"projected click tills intended cell")
	check(shell.world.grid.can_till(target+Vector2i(0,1))["ok"],"adjacent depth row untouched")
	for failure in failures: printerr(failure)
	print("P87 PROJECTION %s: %d checks" % ["OK" if failures.is_empty() else "FAILED",checks])
	quit(0 if failures.is_empty() else 1)
