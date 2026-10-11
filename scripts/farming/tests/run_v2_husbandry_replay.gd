extends SceneTree
## Continues the P7.a no-injection route: real purchases, feeding and day ends only.
## Sheep bought on display day 9 and fry on day 11 must both be adult by day 15.
const World := preload("res://scripts/farming/v2/v2_world.gd")
const Snapshot := preload("res://scripts/farming/v2/v2_snapshot.gd")
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
	while world.clock.total_days < 14:
		var day := world.clock.total_days
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
		if world.inventory.count("grain") >= 3 and world.gross_revenue() == 0: _record("出售谷粒3",func(): return world.sell("grain",3))
		if world.inventory.count("raw_wood") >= 4 and world.facilities.is_empty():
			while world.inventory.count("raw_stone") < 8: _record("采石",func(): return world.collect("stone_source"))
			_record("建圈舍",func(): return world.build_facility(Vector2i(7,1),"pen"))
			_record("建水场",func(): return world.build_facility(Vector2i(0,14),"fish_pond"))
			_record("建藻槽",func(): return world.build_facility(Vector2i(9,4),"algae_tank"))
		if not world.facilities.is_empty():
			for f in world.facilities.values():
				if f["facility_id"] != "algae_tank": continue
				if f["batch"].get("status") == "ready": _record("收取藻料",func(): return world.claim_batch(f["uid"],f["batch"]["batch_id"]))
				if f["batch"].is_empty() and world.inventory.count("straw") >= 2 and world.inventory.count("algae_feed") < 12:
					while world.inventory.count("clean_water") < 3: _record("泉水采集",func(): return world.collect("spring_source"))
					_record("启动藻料培养",func(): return world.start_batch(f["uid"],"culture_algae"))
			# Day 9 (display): the cash from grain sales funds one sheep for the empty pen.
			if day == 8 and world.husbandry.habitat_of(1)["individuals"].is_empty():
				_record("购入钢绵羊幼体1",func(): return world.husbandry.purchase(1,1))
			# Day 11 (display): the first algae batch feeds two fry.
			if day == 10 and world.husbandry.habitat_of(2)["individuals"].is_empty() and world.inventory.count("algae_feed") >= 2:
				_record("购入滤藻鲤鱼苗2",func(): return world.husbandry.purchase(2,2))
			for habitat_uid in [1,2]:
				if world.husbandry.habitat_of(habitat_uid)["individuals"].is_empty(): continue
				if world.inventory.count("clean_water") < 2: _record("泉水采集",func(): return world.collect("spring_source"))
				_record("整体投喂%d" % habitat_uid,func(): return world.husbandry.maintain(habitat_uid))
		if world.clock.total_days == day: _record("结束一天",func(): return world.end_day())
	_finish()
	_validate()
	var output := ".art-work/phase07b-husbandry-replay.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ledger="): output = arg.trim_prefix("--ledger=")
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"actual_P7b_growth_only","daily_rows":rows,
		"final":{"day":world.clock.total_days+1,"cash":world.primeval_stones,
		"sheep":_species_summary(1),"carp":_species_summary(2),
		"inventory":world.inventory.to_save(),"ledger_days":world.ledger.state["history"].size()}},"\t"))
	for failure in failures: printerr(failure)
	print("P7.b HUSBANDRY REPLAY ","OK" if failures.is_empty() else "FAIL"," · ",rows.size()," days · sheep ",_species_summary(1)," · carp ",_species_summary(2))
	quit(0 if failures.is_empty() else 1)

func _species_summary(uid: int) -> Dictionary:
	var habitat: Dictionary = world.husbandry.habitat_of(uid)
	if habitat.is_empty(): return {"error":"missing"}
	var juvenile := 0
	var adult := 0
	for individual in habitat["individuals"]:
		if individual["stage"] == "adult": adult += 1
		else: juvenile += 1
	var summary := {"juvenile":juvenile,"adult":adult,"water":int(habitat.get("water",-1))}
	return summary

func _validate() -> void:
	if world.clock.total_days != 14: failures.append("replay must end on display day 15")
	var sheep: Dictionary = _species_summary(1)
	var carp: Dictionary = _species_summary(2)
	if sheep.get("adult") != 1: failures.append("sheep must be adult after six fed days")
	if carp.get("adult") != 2 or carp.get("juvenile") != 0: failures.append("both fry must be adult after four fed days")
	if int(carp.get("water",-1)) != 80: failures.append("pond water should have decayed exactly to 80")
	var checked: Dictionary = Snapshot.normalize(world.to_snapshot())
	if not checked["ok"]: failures.append("final snapshot invalid: "+String(checked.get("reason","")))
	var pending: Dictionary = world.ledger.state["pending"]
	if int(pending["day"]) != 14 or world.ledger.state["history"].size() != 14: failures.append("ledger days must track every settled day")
	if world.inventory.count("algae_feed") < 0 or world.primeval_stones < 0: failures.append("negative balance")

func _begin() -> void:
	current = {"display_day":world.clock.total_days+1,"ap_start":world.clock.ap,"cash_start":world.primeval_stones,"inventory_start":world.inventory.to_save(),"actions":[]}
func _finish() -> void:
	if current["actions"].is_empty(): return
	var ap_used := 0
	for action in current["actions"]: ap_used += int(action["ap_used"])
	if ap_used > 24: failures.append("AP ledger exceeded daily budget on day %d" % int(current["display_day"]))
	current["ap_used"] = ap_used
	current["cash_end"] = world.primeval_stones
	current["inventory_end"] = world.inventory.to_save()
	rows.append(current)
func _record(label: String, action: Callable) -> void:
	var day := world.clock.total_days
	var ap := world.clock.ap
	var cash := world.primeval_stones
	var result: Dictionary = action.call()
	if not result["ok"]: failures.append("day%d %s: %s" % [day+1,label,result.get("reason","无理由")])
	current["actions"].append({"label":label,"ap_used":ap-world.clock.ap if world.clock.total_days == day else ap,"cash_delta":world.primeval_stones-cash,
		"inventory_after":world.inventory.to_save(),"day_advanced":world.clock.total_days != day,"result_ok":result["ok"]})
	if world.clock.total_days != day: _finish(); _begin()
func _plant(cell: Vector2i, crop_id: String) -> void:
	var footprint: Array = world.crop_defs[crop_id]["footprint"]
	for y in range(int(footprint[1])):
		for x in range(int(footprint[0])):
			var target := cell+Vector2i(x,y)
			_record("开垦%s" % target,func(): return world.till(target))
	_record("种植"+crop_id,func(): return world.plant(cell,crop_id))
