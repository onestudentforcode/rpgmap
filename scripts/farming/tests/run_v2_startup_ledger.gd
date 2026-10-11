extends SceneTree
## Actual planting/collection/building ledger; animal reservations are projections.
const World := preload("res://scripts/farming/v2/v2_world.gd")
var world := World.new()
var rows: Array = []
var current: Dictionary
var failures: Array[String] = []

func _initialize() -> void:
	_begin()
	_record("购买草籽4",func(): return world.buy("grass_seed",4))
	for cell in [Vector2i(1,1),Vector2i(2,1),Vector2i(3,1),Vector2i(4,1)]: _plant(cell,"pasture_grass")
	_plant(Vector2i(10,1),"fast_fir"); _plant(Vector2i(13,1),"fast_fir")
	for x in range(1,4): _plant(Vector2i(x,2),"golden_wheat")
	for x in range(1,6): _plant(Vector2i(x,4),"golden_wheat")
	while world.clock.total_days < 10:
		var day := world.clock.total_days
		# Collect and irrigate existing beds; no inventory/cash injection.
		for crop in world.crops.values().duplicate(true):
			if crop["state"] == "mature": continue
			for cell in world.grid.holder_cells("v1_crop:%d" % crop["uid"]).duplicate():
				if world.environment_at(cell)["water"] < 35:
					if world.inventory.count("clean_water") < 1: _record("泉水采集",func(): return world.collect("spring_source"))
					_record("浇水%s" % cell,func(): return world.irrigate(cell))
		for crop in world.crops.values().duplicate(true):
			if crop["state"] != "mature": continue
			var cell := Vector2i(int(crop["origin"][0]),int(crop["origin"][1]))
			_record("采收"+crop["crop_id"],func(): return world.harvest(cell,"fell" if crop["crop_id"] == "fast_fir" else "harvest"))
		if world.inventory.count("grain") >= 3 and world.gross_revenue() == 0: _record("出售谷粒3启动水产",func(): return world.sell("grain",3))
		if world.inventory.count("raw_wood") >= 4 and world.facilities.is_empty():
			while world.inventory.count("raw_stone") < 8: _record("采石",func(): return world.collect("stone_source"))
			_record("建圈舍",func(): return world.build_facility(Vector2i(7,1),"pen"))
			_record("建水场",func(): return world.build_facility(Vector2i(0,14),"fish_pond"))
			_record("建藻槽",func(): return world.build_facility(Vector2i(9,4),"algae_tank"))
		if not world.facilities.is_empty() and world.inventory.count("algae_feed") < 12:
			for f in world.facilities.values():
				if f["facility_id"] != "algae_tank": continue
				if f["batch"].get("status") == "ready": _record("收取藻料",func(): return world.claim_batch(f["uid"],f["batch"]["batch_id"]))
				if f["batch"].is_empty() and world.inventory.count("straw") >= 2:
					while world.inventory.count("clean_water") < 3: _record("泉水采集",func(): return world.collect("spring_source"))
					_record("启动藻料培养",func(): return world.start_batch(f["uid"],"culture_algae"))
		if world.clock.total_days == day: _record("结束一天",func(): return world.end_day())
	_finish()
	var output := ".art-work/phase07a-startup-ledger.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ledger="): output=arg.trim_prefix("--ledger=")
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"actual_P7a_planting_building_only","initial_stones":60,"daily_rows":rows,"animal_projection":{"implemented":false,"one_sheep_two_fry_purchase":22,"cash_after_reserved_purchase":world.primeval_stones-22,"replay_after":"P7.b/c","maintenance_and_growth":"pending_runtime_replay"}},"\t"))
	if world.facilities.size() != 3 or world.primeval_stones < 22 or world.gross_revenue() != 12: failures.append("startup cannot fund facilities and reserve one sheep/two fish")
	for failure in failures: printerr(failure)
	print("P7.a STARTUP LEDGER ","OK" if failures.is_empty() else "FAIL"," · ",rows.size()," daily rows · cash ",world.primeval_stones," · animal purchase reservation22, not runtime animals")
	quit(0 if failures.is_empty() else 1)

func _begin() -> void:
	current={"display_day":world.clock.total_days+1,"service_day":world.clock.total_days,"ap_start":world.clock.ap,"cash_start":world.primeval_stones,"inventory_start":world.inventory.to_save(),"actions":[]}
func _finish() -> void:
	if current["actions"].is_empty(): return
	var ap_used := 0
	for action in current["actions"]: ap_used += int(action["ap_used"])
	current["ap_used"] = ap_used
	current["ap_remaining_before_settlement"] = 24-ap_used
	if ap_used > 24: failures.append("AP ledger exceeded daily budget")
	current["ap_end"]=world.clock.ap
	current["cash_end"]=world.primeval_stones
	current["inventory_end"]=world.inventory.to_save()
	rows.append(current)
func _record(label: String, action: Callable) -> void:
	var day := world.clock.total_days
	var ap := world.clock.ap
	var cash := world.primeval_stones
	var inventory := world.inventory.to_save()
	var result: Dictionary = action.call()
	if not result["ok"]: failures.append("day%d %s: %s" % [day+1,label,result["reason"]])
	current["actions"].append({"label":label,"ap_used":ap if world.clock.total_days != day and result.get("day_advanced",false) else maxi(0,ap-world.clock.ap),"cash_delta":world.primeval_stones-cash,"inventory_before":inventory,"inventory_after":world.inventory.to_save(),"source_used":world._source_used.duplicate(),"source_limits":{"stone":18,"ore":12,"water":30},"day_advanced":world.clock.total_days!=day,"result":result})
	if world.clock.total_days != day: _finish(); _begin()
func _plant(cell: Vector2i, crop_id: String) -> void:
	var footprint: Array = world.crop_defs[crop_id]["footprint"]
	for y in range(int(footprint[1])):
		for x in range(int(footprint[0])):
			var target := cell+Vector2i(x,y)
			_record("开垦%s" % target,func(): return world.till(target))
	_record("种植"+crop_id,func(): return world.plant(cell,crop_id))
