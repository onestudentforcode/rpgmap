extends SceneTree
## P10.10 动物视野叠层验证：确定性四分区槽位、固定锚点、缩略图装载、
## 地格内容列表与个体详情、视图操作不改玩法快照、工具输入不受影响。
const Scene := preload("res://scenes/farming/farm_p8.tscn")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: _run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _screen_pos_for(sh, cell: Vector2i) -> Vector2:
	if sh.camera.zoom.x <= 0.0 or sh.camera.zoom.y <= 0.0 or is_nan(sh.camera.zoom.x):
		sh.camera.zoom = Vector2.ONE
	sh.camera.position = Vector2(320, 320)
	var pos: Vector2 = Vector2(cell) * 64.0 + Vector2(32, 32)
	for i in range(8):
		var got: Vector2i = sh._cell(pos)
		if got == cell: break
		var delta: Vector2 = Vector2(cell) - Vector2(got)
		pos += delta.clamp(Vector2(-64, -64), Vector2(64, 64)) * 8.0
	return pos

func _run() -> void:
	var shell = Scene.instantiate()
	var directory := "res://.art-work/p1010/tests/%d" % Time.get_ticks_usec()
	shell.store = Store.new(directory)
	shell.settings = shell.settings.get_script().new(directory+".cfg",0.1)
	root.add_child(shell)
	await process_frame
	shell._new(1,false)
	shell.set_process(false)
	for project in shell.world.research.project_defs():
		shell.world.research.state["completed"].append(project)
	for event in shell.world.progress.config["events"]:
		if not shell.world.progress.state["events"].any(func(row): return row.get("id") == event["id"]):
			shell.world.progress.state["events"].append({"id": event["id"], "seq": shell.world.progress.state["next_seq"], "at": 0})
			shell.world.progress.state["next_seq"] += 1
	shell.world.grant_scaffold({"raw_wood": 300, "raw_stone": 300, "twig": 150, "wood_plank": 150, "iron_ingot": 100, "clay": 100})
	# 找4格连通空地：两格放床（区域结构），两格留空
	var base := Vector2i(-1, -1)
	for y in range(2, 16):
		for x in range(2, 16):
			var ok := true
			for dy in range(4):
				for dx in range(4):
					var cell := Vector2i(x+dx, y+dy)
					if not shell.world.grid.is_terrain_tillable(cell) or not shell.world.source_at(cell).is_empty() or not shell.world.facility_at(cell).is_empty():
						ok = false
			if ok: base = Vector2i(x,y); break
		if base.x >= 0: break
	check(base.x >= 0, "found 4x4 free area")
	var cells := [ "%d,%d"%[base.x,base.y], "%d,%d"%[base.x+1,base.y], "%d,%d"%[base.x,base.y+1], "%d,%d"%[base.x+1,base.y+1] ]
	for c in [base, base+Vector2i(1,0), base+Vector2i(0,1), base+Vector2i(1,1)]:
		shell.world.rooms.state["floors"][shell.world.rooms.key(c)] = "ordinary"
	# 宽域铺普通地板，结构设施就位后再划区
	for dy in range(-1, 6):
		for dx in range(-1, 6):
			var fc := base + Vector2i(dx, dy)
			if shell.world.grid.in_bounds(fc.x, fc.y) and shell.world.grid.is_terrain_tillable(fc):
				shell.world.rooms.state["floors"][shell.world.rooms.key(fc)] = "ordinary"
	var plans := [["small_bed", base], ["small_bed", base+Vector2i(1,0)], ["feed_trough", base+Vector2i(2,0)]]
	for entry in plans:
		var built: Dictionary = shell.world.build_facility(entry[1], String(entry[0]))
		check(built.get("ok", false), "%s built at %s (%s)" % [entry[0], entry[1], built.get("reason","")])
	var pen_built := false
	for candidate in [[0,2],[1,2],[2,2],[0,3],[1,3],[2,3],[3,2],[3,3],[0,1],[1,1],[2,1],[3,1]]:
		var c := base + Vector2i(candidate[0], candidate[1])
		if not shell.world.grid.in_bounds(c.x, c.y) or not shell.world.source_at(c).is_empty() or not shell.world.facility_at(c).is_empty():
			continue
		if shell.world.build_facility(c, "pen").get("ok", false):
			pen_built = true
			break
	check(pen_built, "pen built somewhere near the zone")
	var zone_cells: Array = []
	for dy in range(0, 4):
		for dx in range(0, 4):
			zone_cells.append("%d,%d" % [base.x+dx, base.y+dy])
	var zone_result: Dictionary = shell.world.ranch.create_zone("nursery", zone_cells)
	check(zone_result.get("ok", false), "nursery zone created (%s)" % zone_result.get("reason",""))
	var zone_uid := int(zone_result.get("zone_uid", 0))
	var buy: Dictionary = shell.world.ranch.purchase(zone_uid, "rock_mole", 4)
	check(buy.get("ok", false), "purchased 4 rock moles (%s)" % buy.get("reason",""))
	print("DBG buy=", JSON.stringify(buy).substr(0, 160), " roster=", shell.world.ranch.state["animals"].size())
	check(shell.world.ranch.state["animals"].size() >= 4, "roster has purchased animals")
	# 固定锚点物种：直插一只礁珊瑚（展示逻辑验证，不进生产结算）
	var ranch = shell.world.ranch
	var anchor_cell := base + Vector2i(6, 0)
	var fixed_row: Dictionary = ranch._new_animal(int(ranch.state["next_animal_uid"]), "reef_coral", zone_uid, 0, 0, "", "%d,%d"%[anchor_cell.x,anchor_cell.y])
	ranch.state["next_animal_uid"] = int(ranch.state["next_animal_uid"]) + 1
	ranch.state["animals"].append(fixed_row)
	# 1) 槽位确定性
	var slots_a: Array = shell.animal_view.display_slots(shell.world)
	var slots_b: Array = shell.animal_view.display_slots(shell.world)
	check(str(slots_a) == str(slots_b), "display slots deterministic")
	# 2) 全部个体各出现一次
	var all_uids: Array = []
	for slot in slots_a:
		all_uids.append_array(slot["animals"])
	var expected: Array = ranch.state["animals"].map(func(row): return int(row["uid"]))
	all_uids.sort()
	expected.sort()
	check(str(all_uids) == str(expected), "every animal appears exactly once")
	# 3) 固定锚点落位
	var fixed_slot := {}
	for slot in slots_a:
		if slot["animals"].has(int(fixed_row["uid"])): fixed_slot = slot
	check(not fixed_slot.is_empty() and fixed_slot["cell"] == anchor_cell, "fixed species anchored at its cell")
	# 4) 游走分配：单格不超过4（本例无溢出）
	var overflow_free := true
	for slot in slots_a:
		if slot["animals"].size() > 4 and not slot["animals"].has(int(fixed_row["uid"])): overflow_free = false
	check(overflow_free, "roaming slots respect four-per-cell without overflow here")
	# 5) 缩略图装载（成体/幼体）
	check(shell.animal_view.thumbnail("steel_sheep", "juvenile") != null, "steel sheep juvenile thumbnail loads")
	check(shell.animal_view.thumbnail("reef_coral", "adult") != null, "reef coral adult thumbnail loads")
	# 6) 地格内容列表
	var sheep_slot := {}
	for slot in slots_a:
		if slot["animals"].has(int(expected[0])): sheep_slot = slot
	print("DBG slots=", slots_a.size(), " sheep_slot=", JSON.stringify(sheep_slot).substr(0, 120))
	if sheep_slot.is_empty():
		for failure in failures: printerr(failure)
		print("P1010 ANIMALS FAILED EARLY: %d checks, sheep slot missing" % checks)
		quit(1)
		return
	shell.selected = sheep_slot["cell"]
	shell._side_open = true
	shell._close_page()
	shell._show_cell()
	var texts := ""
	for node in shell.sidebar.get_children():
		if node is Label: texts += String(node.text) + ";"
		elif node is Button: texts += String(node.text) + ";"
	check(texts.contains("本格动物"), "cell content list shows animals section")
	check(texts.contains("啮岩鼹"), "cell content list names the species")
	check(texts.contains("所属区域"), "cell content list links the zone")
	# 7) 个体详情与返回
	var first_uid := int(expected[0])
	shell.animal_view.show_detail(shell.world, first_uid)
	var detail_texts := ""
	for node in shell.sidebar.get_children():
		if node is Label or node is Button: detail_texts += String(node.text) + ";"
	check(detail_texts.contains("#%d" % first_uid), "animal detail page opens by uid")
	shell._show_cell()
	# 8) 视图开关与快照不变
	var before: Dictionary = shell.world.to_snapshot().duplicate(true)
	shell.animal_view.enabled = false
	shell.animal_view.enabled = true
	shell.animal_view.show_detail(shell.world, first_uid)
	check(shell.world.to_snapshot() == before, "view-only operations preserve gameplay snapshot")
	# 9) 工具输入不受影响（叠层开启时手动开垦单击仍工作）
	var tool_cell := base + Vector2i(0, 4)
	if shell.world.grid.is_terrain_tillable(tool_cell) and shell.world.source_at(tool_cell).is_empty():
		shell._close_page()
		shell._select_tool("till")
		shell.manual_mode = true
		var pos := _screen_pos_for(shell, tool_cell)
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = pressed
			ev.position = pos
			shell._board_input(ev)
		check(shell.world.rooms.floor_kind(tool_cell) == "farmland", "manual till click unaffected by animal overlay")
	for failure in failures: printerr(failure)
	print("P1010 ANIMALS %s: %d checks, %d failed" % ["OK" if failures.is_empty() else "FAILED", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
