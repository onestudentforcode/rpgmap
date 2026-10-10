extends SceneTree
## Deterministic 45-day operating policy, using only real actions and baseline resources.
var shell
var farm
var oracle := {"planted": {},"harvests": {},"yield": {},"feeding": {},"revenue": 0,"spending": {"seed":0,"production":0,"tool":0}}
var daily: Array = []
var purchases: Array = []
var failures: Array[String] = []
var directory: String
var output := "res://.art-work/phase06-playtest.json"
var shots := ""
const PLOTS := [
	{"crop":"dew_grass","cell":Vector2i(5,2)}, {"crop":"dew_grass","cell":Vector2i(6,2)}, {"crop":"dew_grass","cell":Vector2i(5,3)},
	{"crop":"scarlet_berry","cell":Vector2i(7,2)}, {"crop":"scarlet_berry","cell":Vector2i(7,3)},
	{"crop":"jade_fruit_tree","cell":Vector2i(9,2)},
	{"crop":"moon_cap","cell":Vector2i(15,2)}, {"crop":"moon_cap","cell":Vector2i(16,2)}]

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
		if arg.begins_with("--playtest-shots="): shots = arg.trim_prefix("--playtest-shots=")
	_run.call_deferred()

func add_count(key: String, id: String, count: int) -> void:
	if count > 0: oracle[key][id] = int(oracle[key].get(id,0))+count

func act(cell: Vector2i, medium: bool = false) -> void:
	if farm.clock.total_days >= 45: return
	var before: Dictionary = farm.crop_mgr.crops.duplicate(true)
	var inventory: Dictionary = farm.inventory.to_save()
	if medium: farm._cycle_medium(cell)
	else: farm._act_on(cell)
	for uid in farm.crop_mgr.crops:
		if not before.has(uid): add_count("planted",farm.crop_mgr.crops[uid]["crop_id"],1)
	for uid in before:
		var inst: Dictionary = before[uid]
		if int(inst["state"]) == farm.crop_mgr.CropState.MATURE and (not farm.crop_mgr.crops.has(uid) or int(farm.crop_mgr.crops[uid]["harvest_count"]) > int(inst["harvest_count"])):
			add_count("harvests",inst["crop_id"],1)
	for entry in farm.inventory.entries():
		add_count("yield",entry["item_id"],int(entry["count"])-int(inventory.get(entry["item_id"],0)))

func trade(id: String, count: int, buying: bool) -> bool:
	if farm.clock.total_days >= 45: return false
	var before: int = farm.economy.primeval_stones
	var result: Dictionary = farm.economy.trade(id,count,buying)
	if result["ok"]:
		var difference: int = farm.economy.primeval_stones-before
		if buying: oracle["spending"][farm._items_by_id[id]["kind"]] -= difference
		else: oracle["revenue"] += difference
	return result["ok"]

func operate() -> void:
	if farm.economy.gu["satiety"] == 0:
		for id in ["dew_leaf","moon_cap_flesh","scarlet_berry_fruit","jade_fruit"]:
			var before: int = farm.inventory.count(id)
			var fed: Dictionary = farm.economy.feed(id)
			if fed["ok"]:
				add_count("feeding",id,before-farm.inventory.count(id))
				break
	farm._select_kind("harvester")
	var origins: Array = []
	for uid in farm.crop_mgr.crops:
		if farm.crop_mgr.crops[uid]["state"] == farm.crop_mgr.CropState.MATURE: origins.append(farm.crop_mgr.crops[uid]["origin"])
	for origin in origins:
		if farm.crop_mgr.can_harvest(origin)["ok"]: act(origin)
	for id in ["dew_leaf","scarlet_berry_fruit","jade_fruit","moon_cap_flesh"]:
		var available: int = farm.inventory.count(id)-(1 if id == "dew_leaf" else 0)
		if available > 0: trade(id,available,false)
	for kind in ["harvester","hoe","sower"]:
		if not farm.tools.data["owned"].has(kind) and farm.economy.primeval_stones >= int(farm.tools.prices[kind])+25 and farm.clock.total_days < 45:
			var before: int = farm.economy.primeval_stones
			if farm.tools.buy(kind,farm.economy)["ok"]:
				oracle["spending"]["tool"] += before-farm.economy.primeval_stones
				purchases.append({"day":farm.clock.total_days+1,"kind":kind,"price":before-farm.economy.primeval_stones})
				if kind == "harvester": farm.tools.switch_level(kind)
	for plot in PLOTS:
		if farm.clock.total_days >= 45: return
		var cell: Vector2i = plot["cell"]
		var crop: String = plot["crop"]
		if farm.crop_mgr.can_clear(cell)["ok"]:
			farm._select_kind("hoe")
			act(cell)
		if not farm.crop_mgr.instance_at(cell).is_empty(): continue
		var seed := crop+"_seed"
		if not farm.inventory.has(seed,1) and not trade(seed,1,true): continue
		var def: Dictionary = farm.crop_mgr.def_of(crop)
		for dy in range(int(def["footprint"][1])):
			for dx in range(int(def["footprint"][0])):
				var target := cell+Vector2i(dx,dy)
				if farm.grid.state_at(target) == farm.grid.State.WILD:
					farm._select_kind("hoe")
					act(target)
		if crop == "moon_cap" and farm.grid.medium_at(cell) == "soil":
			if not farm.inventory.has("fungal_bed_material",1) and not trade("fungal_bed_material",1,true): continue
			act(cell,true)
		farm._select_crop(farm._tool_crop_ids.find(crop))
		act(cell)

func check(ok: bool, message: String) -> void:
	if ok: print("[ok] P6.f: "+message)
	else: failures.append(message)

func _run() -> void:
	directory = "user://farm_phase06_playtest_%d" % Time.get_ticks_usec()
	shell = load("res://scripts/farming/rendering/farm_demo.gd").new()
	shell.store = load("res://scripts/farming/core/storage/farm_slot_store.gd").new(directory)
	shell.legacy_path = directory+"/absent.json"
	root.add_child(shell)
	shell._start_slot("new",1,false)
	await process_frame
	farm = shell.farm
	var baseline_money: int = farm.economy.primeval_stones
	var baseline_inventory: Dictionary = farm.inventory.to_save()
	while farm.clock.total_days < 45:
		var day: int = farm.clock.total_days+1
		operate()
		if farm.clock.total_days == day-1: farm.clock.end_day()
		daily.append({"day":day,"balance":farm.economy.primeval_stones,"ap_after_save":farm.clock.ap,"satiety":farm.economy.gu["satiety"],"inventory":farm.inventory.to_save(),"crops":farm.crop_mgr.crops.size(),"totals":oracle.duplicate(true)})
		var saved: Dictionary = shell.store.read_slot(1)
		if not saved["ok"]: failures.append("日存档失败"); break
		if day in [15,30]:
			shell._leave("menu")
			shell._start_slot("continue",1,false)
			await process_frame
			farm = shell.farm
		await process_frame
	var report: Dictionary = farm.records.data["report"].duplicate(true)
	var normal_inventory := {}
	for id in farm._config["start_inventory"]: normal_inventory[id] = int(farm._config["start_inventory"][id])
	check(baseline_money == 60 and baseline_inventory == normal_inventory,"仅使用正式初始60元石和种子，无资源/时间注入")
	check(daily.size() == 45 and farm.clock.total_days == 45,"完成连续45天经营，含第15/30天读档恢复")
	for key in oracle: check(report.get(key) == oracle[key],"回顾与独立状态差额账本一致："+key)
	check(report.get("balance") == 60+int(oracle["revenue"])-int(oracle["spending"]["seed"])-int(oracle["spending"]["production"])-int(oracle["spending"]["tool"]),"期末余额符合初始资金加净收入")
	check(oracle["spending"]["seed"] > 0 and oracle["spending"]["production"] > 0 and purchases.size() == 3,"出售后持续买种/买生产材料、三种高级工具可负担")
	check(oracle["feeding"].size() > 0 and oracle["harvests"].size() == 4 and report.get("balance",0) > 60,"四种作物多轮收获并维持喂养、资金增长")
	check(shell.store.read_slot(1)["snapshot"]["records"]["report"] == report,"最终回顾持久化，读档不改写首次记录")
	if not shots.is_empty():
		DirAccess.make_dir_recursive_absolute(shots)
		shell.show_records()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(shots+"/day45-report.png")
		shell._set_modal(false)
		farm.tutorial.skip()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(shots+"/day46-farm.png")
	var result := {"schema":1,"policy":"8 fixed plots; retain one dew leaf; sell other food; buy seeds when depleted; buy tools with 25-stone reserve; advanced harvesting only; reload on days 15 and 30","initial_money":baseline_money,"initial_inventory":baseline_inventory,"daily":daily,"tool_purchases":purchases,"oracle":oracle,"report":report,"failures":failures}
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	shell._leave("menu")
	shell.store.delete_slot(1,true)
	DirAccess.remove_absolute(directory)
	for failure in failures: print("[fail] P6.f: "+failure)
	print("45 DAY PLAYTEST OK" if failures.is_empty() else "45 DAY PLAYTEST FAILED")
	quit(0 if failures.is_empty() else 1)
