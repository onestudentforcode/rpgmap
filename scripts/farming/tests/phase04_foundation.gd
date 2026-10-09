extends RefCounted
## Isolated Phase 4 fixtures: shared lifecycle, mediums, footprints and old saves.
const LandGrid := preload("res://scripts/farming/core/grid/land_grid.gd")
const CropManager := preload("res://scripts/farming/core/crops/crop_manager.gd")
const FarmData := preload("res://scripts/farming/core/farm_data.gd")


static func check(ok: bool, label: String, fails: Array[String]) -> void:
	if ok:
		print("[ok] P4: " + label)
	else:
		fails.append("P4: " + label)


static func run() -> Array[String]:
	var fails: Array[String] = []
	var cells := []
	for y in range(6):
		cells.append(["grass", "grass", "grass", "grass", "grass", "grass"])
	var grid := LandGrid.new()
	grid.setup(6, 6, cells, {"grass": true}, ["soil", "fungal_bed", "rotten_log"])
	for y in range(6):
		for x in range(6):
			grid.till(Vector2i(x,y))
	var data := FarmData.load_crops().duplicate(true)
	var tree: Dictionary = data["crops"][1].duplicate(true)
	tree["crop_id"] = "test_tree"
	tree["category"] = "tree"
	tree["footprint"] = [2,2]
	tree["max_harvests"] = 2
	var fungus: Dictionary = data["crops"][0].duplicate(true)
	fungus["crop_id"] = "test_fungus"
	fungus["category"] = "fungus"
	fungus["planting_medium"] = "fungal_bed"
	fungus["growth_stages"] = [{"id": "mycelium", "days": 1, "sprite": "stage_0"},
		{"id": "mature", "days": 0, "sprite": "stage_1"}]
	var log_fungus: Dictionary = fungus.duplicate(true)
	log_fungus["crop_id"] = "test_log_fungus"
	log_fungus["planting_medium"] = "rotten_log"
	data["crops"].append_array([tree, fungus, log_fungus])
	var manager := CropManager.new()
	manager.setup(grid,data)
	check(grid.medium_at(Vector2i.ZERO) == "soil" and manager.can_plant(Vector2i.ZERO,"dew_grass")["ok"],
		"旧耕地默认土壤，花草继续可播种", fails)
	grid.prepare_medium(Vector2i(2,2),"fungal_bed")
	check(not manager.can_plant(Vector2i(2,2),"dew_grass")["ok"] and
		not manager.can_plant(Vector2i(0,2),"test_fungus")["ok"] and
		manager.can_plant(Vector2i(2,2),"test_fungus")["ok"],
		"花草拒绝菌床，真菌拒绝土壤并接受菌床", fails)
	var mixed := manager.plant(Vector2i(1,1),"test_tree")
	check(not mixed["ok"] and manager.crops.is_empty() and grid.occupied_cells().is_empty(),
		"多格混合介质被拒，实例与占格零副作用", fails)
	var planted := manager.plant(Vector2i.ZERO,"test_tree")
	check(planted["ok"] and grid.holder_cells(manager.holder_of(planted.get("uid",-1))).size()==4 and
		manager.instance_at(Vector2i(1,1)).get("crop_id","")=="test_tree" and
		not manager.plant(Vector2i(1,0),"scarlet_berry")["ok"] and
		not manager.plant(Vector2i(5,5),"test_tree")["ok"] and manager.crops.size()==1,
		"2×2果树四格占用、任意格查询、重叠与越界拒绝", fails)
	for day in range(4):
		manager.on_day_changed()
	var first := manager.harvest(Vector2i(1,1))
	for day in range(2):
		manager.on_day_changed()
	var last := manager.harvest(Vector2i(0,1))
	var cleared := manager.clear(Vector2i(1,0))
	check(first.get("ok",false) and not first.get("exhausted",true) and last.get("exhausted",false) and
		cleared["ok"] and grid.state_at(Vector2i(1,1))==LandGrid.State.TILLED and
		grid.medium_at(Vector2i(1,1))=="soil" and grid.occupied_cells().is_empty(),
		"果树按共享生命周期再生/枯竭/清理，四格恢复原介质", fails)
	manager.plant(Vector2i(2,2),"test_fungus")
	check(not grid.prepare_medium(Vector2i(2,2),"rotten_log")["ok"] and
		not grid.prepare_medium(Vector2i(3,2),"unknown")["ok"],
		"占用格不可换介质，未知介质被拒绝", fails)
	manager.on_day_changed()
	var saved_grid := grid.to_save()
	var saved_crops := manager.to_save()
	var restored := LandGrid.new()
	restored.setup(6,6,cells,{"grass":true},["soil","fungal_bed","rotten_log"])
	var restored_manager := CropManager.new()
	restored_manager.setup(restored,data)
	var restored_ok := restored.apply_save(saved_grid) and restored_manager.apply_save(saved_crops)
	var fungus_harvest := restored_manager.harvest(Vector2i(2,2))
	check(restored_ok and fungus_harvest.get("removed",false) and
		restored.state_at(Vector2i(2,2))==LandGrid.State.TILLED and restored.medium_at(Vector2i(2,2))=="fungal_bed",
		"两阶段真菌成熟采收，存读档后仍恢复菌床", fails)
	grid.prepare_medium(Vector2i(3,2),"rotten_log")
	check(manager.can_plant(Vector2i(3,2),"test_log_fungus")["ok"] and
		not manager.can_plant(Vector2i(3,2),"test_fungus")["ok"],
		"朽木与菌床独立限制，介质按数据匹配", fails)
	manager.plant(Vector2i(3,0),"test_tree")
	var old_save := grid.to_save()
	old_save.erase("media")
	for cell in old_save["cells"]:
		cell.erase("p")
	var old_grid := LandGrid.new()
	old_grid.setup(6,6,cells,{"grass":true})
	var old_ok := old_grid.apply_save(old_save)
	var uid: int = int(manager.instance_at(Vector2i(3,0))["uid"])
	old_grid.release(manager.holder_of(uid))
	check(old_ok and old_grid.medium_at(Vector2i(3,0))=="soil" and old_grid.state_at(Vector2i(3,0))==LandGrid.State.TILLED,
		"旧存档无media/p字段时默认土壤，释放已种植格恢复耕地", fails)
	var big: Dictionary = tree.duplicate(true)
	big["crop_id"] = "test_big_tree"
	big["footprint"] = [3,3]
	data["crops"].append(big)
	manager.setup(grid,data)
	var large := manager.plant(Vector2i(3,3),"test_big_tree")
	check(large["ok"] and grid.holder_cells(manager.holder_of(large.get("uid",-1))).size()==9,
		"3×3占地由配置驱动，无类别专用种植系统", fails)
	grid.prepare_medium(Vector2i(0,4),"fungal_bed")
	grid.untill(Vector2i(0,4))
	grid.till(Vector2i(0,4))
	check(grid.medium_at(Vector2i(0,4))=="soil","恢复荒地后再次开垦使用默认土壤",fails)
	return fails
