extends RefCounted
const Snapshot := preload("res://scripts/farming/core/storage/farm_snapshot.gd")
const Batch := preload("res://scripts/farming/core/crops/farm_batch.gd")
var completed := false

func check(ok: bool, message: String, fails: Array[String]) -> void:
	if ok: print("[ok] P6.d: " + message)
	else: fails.append("P6.d: " + message)

func reset(farm, kind: String = "hoe", advanced: bool = true) -> void:
	farm.apply_snapshot(Snapshot.fresh())
	farm.economy.primeval_stones = 1000
	if advanced:
		farm.tools.buy(kind,farm.economy)
		farm.tools.switch_level(kind)
	farm._select_kind(kind)

func run(tree: SceneTree) -> Array[String]:
	var fails: Array[String] = []
	var directory := "user://farm_phase06_tools_tests_%d" % Time.get_ticks_usec()
	var shell = load("res://scripts/farming/rendering/farm_demo.gd").new()
	shell.store = load("res://scripts/farming/core/storage/farm_slot_store.gd").new(directory)
	shell.legacy_path = directory + "/absent.json"
	tree.root.add_child(shell)
	shell._start_slot("new",1,false)
	await tree.process_frame
	var farm = shell.farm
	check(farm.tools.data["owned"].is_empty() and not farm.tools.switch_level("hoe"), "新档只有普通工具且未购入不可切高级",fails)
	farm.tools.buy("hoe",farm.economy)
	check(farm.economy.primeval_stones == 30 and farm.records.data["spending"]["tool"] == 30 and farm.clock.ap == 24, "购入高级锄头扣30元石、记工具支出、不扣AP",fails)
	check(not farm.tools.buy("hoe",farm.economy)["ok"] and farm.economy.primeval_stones == 30, "重复购买拒绝且零扣款",fails)
	check(not farm.tools.buy("sower",farm.economy)["ok"] and not farm.tools.buy("unknown",farm.economy)["ok"], "余额不足及未知工具拒绝",fails)
	farm.tools.switch_level("hoe")
	check(farm.tools.advanced("hoe") and farm.tools.switch_level("hoe") and not farm.tools.advanced("hoe"), "已拥有工具可自由切换普通与高级",fails)
	check(farm._tool_buttons.size() == 3 and farm._crop_choice.item_count == 4, "三类工具各一个栏位、四作物共用种子选择器",fails)
	var center := Vector2i(3,11)
	var targets := Batch.cells(center,farm.grid)
	check(targets.size() == 9 and targets[0] == center-Vector2i.ONE and targets[4] == center and targets[8] == center+Vector2i.ONE, "范围居中且顺序上到下左到右",fails)
	check(Batch.cells(Vector2i.ZERO,farm.grid).size() == 4, "地图边缘截取有效格",fails)
	for count in [1,2,3,9]:
		reset(farm)
		for cell in targets: farm.grid.till(cell)
		for i in range(count): farm.grid.untill(targets[i])
		farm._act_on(center)
		check(farm.clock.ap == 24-ceili(count/2.0) and targets.all(func(cell): return farm.grid.state_at(cell) == farm.grid.State.TILLED), "成功%d次按整批折半扣%dAP" % [count,ceili(count/2.0)],fails)
	var before: Dictionary = farm.capture_snapshot()
	farm._act_on(center)
	check(farm.capture_snapshot() == before, "高级锄头不恢复已耕地、空批零AP",fails)
	var double_click := InputEventMouseButton.new()
	double_click.pressed = true
	double_click.button_index = MOUSE_BUTTON_LEFT
	double_click.double_click = true
	farm._hover = Vector2i(10,11)
	farm._unhandled_input(double_click)
	check(farm.capture_snapshot() == before, "双击的第二次事件不会另结算一批",fails)
	reset(farm,"hoe",false)
	farm._act_on(center)
	check(farm.clock.ap == 23 and targets.filter(func(cell): return farm.grid.state_at(cell) == farm.grid.State.TILLED).size() == 1, "普通工具仍为单目标原价",fails)
	reset(farm,"sower")
	for cell in targets: farm.grid.till(cell)
	farm.inventory.remove("dew_grass_seed",7)
	farm._select_crop(0)
	farm._act_on(center)
	check(farm.crop_mgr.crops.size() == 3 and farm.inventory.count("dew_grass_seed") == 0 and farm.clock.ap == 22, "种子不足按顺序完成三株、扣两AP，无负库存",fails)
	check(farm.crop_mgr.instance_at(targets[0]).size() > 0 and farm.crop_mgr.instance_at(targets[2]).size() > 0 and farm.crop_mgr.instance_at(targets[3]).is_empty(), "资源不足停止位置确定",fails)
	reset(farm,"sower")
	for cell in targets: farm.grid.till(cell)
	farm.clock.ap = 1
	farm._act_on(center)
	var saved: Dictionary = shell.store.read_slot(1)["snapshot"]
	check(farm.crop_mgr.crops.size() == 2 and farm.clock.total_days == 1 and farm.clock.ap == 24, "一AP只执行可负担两株、跨日后不续做",fails)
	check(saved["crops"]["crops"].size() == 2 and saved["inventory"]["dew_grass_seed"] == 8 and saved["records"]["planted"]["dew_grass"] == 2, "末AP批量自动档包含整批种子、作物和统计",fails)
	reset(farm,"sower")
	for cell in targets: farm.grid.till(cell)
	farm.grid.prepare_medium(targets[0],"fungal_bed")
	farm._act_on(center)
	check(farm.crop_mgr.crops.size() == 8 and farm.grid.medium_at(targets[0]) == "fungal_bed" and farm.clock.ap == 20, "混合介质跳过错误格并按成功数量收费",fails)
	reset(farm,"sower")
	for y in range(10,14):
		for x in range(5,9): farm.grid.till(Vector2i(x,y))
	farm.inventory.add("jade_fruit_tree_seed",1)
	farm._select_crop(2)
	farm._act_on(Vector2i(6,11))
	check(farm.crop_mgr.crops.size() == 4 and farm.grid.occupied_cells().size() == 16 and farm.clock.ap == 22, "多格作物校验完整占地并跳过重叠锚点",fails)
	reset(farm,"harvester")
	for cell in [Vector2i(5,11),Vector2i(6,11),Vector2i(5,12),Vector2i(6,12)]: farm.grid.till(cell)
	farm.crop_mgr.plant(Vector2i(5,11),"jade_fruit_tree")
	for day in range(10): farm.clock.end_day()
	farm._act_on(Vector2i(6,11))
	check(farm.records.data["harvests"]["jade_fruit_tree"] == 1 and farm.clock.ap == 23 and farm.inventory.count("jade_fruit") >= 3, "范围触及树任意格只采一次、产物一次入库",fails)
	before = farm.capture_snapshot()
	farm._act_on(Vector2i(6,11))
	check(farm.capture_snapshot() == before, "重复点击未成熟植株不重复收获或收费",fails)
	for harvest in range(2):
		for day in range(3): farm.clock.end_day()
		farm._act_on(Vector2i(6,11))
	farm.tools.buy("hoe",farm.economy)
	farm.tools.switch_level("hoe")
	farm._select_kind("hoe")
	for cell in Batch.cells(Vector2i(6,11),farm.grid):
		if farm.grid.state_at(cell) == farm.grid.State.WILD: farm.grid.till(cell)
	farm._act_on(Vector2i(6,11))
	check(farm.crop_mgr.crops.is_empty() and farm.grid.occupied_cells().is_empty() and farm.clock.ap == 22, "范围清理多格枯树一次、完整释放四格",fails)
	farm._select_kind("harvester")
	farm.clock.end_day()
	shell._leave("menu")
	shell._start_slot("continue",1,false)
	await tree.process_frame
	farm = shell.farm
	check(farm.tools.advanced("harvester") and farm.tools.advanced("hoe") and farm._tool == -1, "读档恢复工具拥有、各等级及选择",fails)
	var bad: Dictionary = farm.capture_snapshot()
	bad["tools"]["levels"]["sower"] = 1
	before = farm.capture_snapshot()
	check(not farm.apply_snapshot(bad) and farm.capture_snapshot() == before, "存档伪造未拥有高级档被拒且零变更",fails)
	farm._select_crop(1)
	farm._select_kind("hoe")
	farm.clock.end_day()
	shell._leave("menu")
	shell._start_slot("continue",1,false)
	await tree.process_frame
	check(shell.farm._selected_crop == 1 and shell.farm._tool == 0, "选种后切回锄头仍保存种子选择",fails)
	shell._leave("menu")
	shell._start_slot("new",2,false)
	await tree.process_frame
	check(shell.farm.tools.data["owned"].is_empty(), "另一个槽不共享工具",fails)
	shell._leave("menu")
	for slot in [1,2,3]: shell.store.delete_slot(slot,true)
	DirAccess.remove_absolute(directory)
	shell.queue_free()
	await tree.process_frame
	completed = true
	return fails
