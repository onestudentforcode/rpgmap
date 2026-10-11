extends SceneTree
## No-injection P7.d replay: hand-raise until day 14, sell extra grain for wages,
## then hand both habitats to exclusive caretakers and let the patrols run them.
const World := preload("res://scripts/farming/v2/v2_world.gd")
const Snapshot := preload("res://scripts/farming/v2/v2_snapshot.gd")
var world := World.new()
var rows: Array = []
var current: Dictionary
var failures: Array[String] = []
var labour_paid := 0

func _initialize() -> void:
	_begin()
	_record("购买草籽4",func(): return world.buy("grass_seed",4))
	for cell in [Vector2i(1,1),Vector2i(2,1),Vector2i(3,1),Vector2i(4,1)]: _plant(cell,"pasture_grass")
	_plant(Vector2i(10,1),"fast_fir"); _plant(Vector2i(13,1),"fast_fir")
	for x in range(1,4): _plant(Vector2i(x,2),"golden_wheat")
	for x in range(1,6): _plant(Vector2i(x,4),"golden_wheat")
	while world.clock.total_days < 24:
		var day := world.clock.total_days
		_fieldwork()
		if world.inventory.count("grain") >= 3 and world.gross_revenue() == 0: _record("出售谷粒3",func(): return world.sell("grain",3))
		if world.inventory.count("raw_wood") >= 4 and world.facilities.keys().size() < 3:
			while world.inventory.count("raw_stone") < 8: _record("采石",func(): return world.collect("stone_source"))
			_record("建圈舍",func(): return world.build_facility(Vector2i(7,1),"pen"))
			_record("建水场",func(): return world.build_facility(Vector2i(0,14),"fish_pond"))
			_record("建藻槽",func(): return world.build_facility(Vector2i(9,4),"algae_tank"))
		_algae_rotation()
		if day == 8 and world.husbandry.habitat_of(1)["individuals"].is_empty():
			_record("购入钢绵羊幼体1",func(): return world.husbandry.purchase(1,1))
		if day == 10 and world.husbandry.habitat_of(2)["individuals"].is_empty() and world.inventory.count("algae_feed") >= 2:
			_record("购入滤藻鲤鱼苗2",func(): return world.husbandry.purchase(2,2))
		# Extra early grain sale funds the caretaker wages before the first harvest.
		if day == 12 and world.inventory.count("grain") >= 3:
			_record("额外早售谷粒3",func(): return world.sell("grain",3))
		# Day 15 (display): hire the caretakers, bind one habitat each, stop hand-feeding.
		if day == 14:
			_record("雇佣羊倌",func(): return world.workforce.hire("羊倌"))
			_record("雇佣鱼倌",func(): return world.workforce.hire("鱼倌"))
			_record("指派圈舍负责人",func(): return world.husbandry.assign_caretaker(1,1))
			_record("指派水场负责人",func(): return world.husbandry.assign_caretaker(2,2))
			while world.inventory.count("iron_ore") < 1: _record("采矿",func(): return world.collect("ore_source"))
		if day < 14: _daily_husbandry()
		else:
			# Caretakers never shop: the player keeps the shared pantry stocked.
			if world.inventory.count("clean_water") < 4:
				while world.inventory.count("clean_water") < 10: _record("泉水采集",func(): return world.collect("spring_source"))
		_production_stages(day)
		if world.clock.total_days == day: _record("结束一天",func(): return world.end_day())
		if world.primeval_stones < 0: failures.append("day%d cash went negative" % (day+1))
	_finish()
	_validate()
	var output := ".art-work/phase07d-caretaker-replay.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ledger="): output = arg.trim_prefix("--ledger=")
	var patrol_summary := []
	for row in world.workforce.state["report"]["workers"]:
		if row.has("caretaker"):
			patrol_summary.append({"name": row["name"], "steps": row["caretaker"]["steps"], "skipped": row["caretaker"]["skipped"]})
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"actual_P7d_delegated","daily_rows":rows,
		"final":{"day":world.clock.total_days+1,"cash":world.primeval_stones,
		"labour_spent":world.workforce.state["spent"],"last_patrols":patrol_summary,
		"wool":world.inventory.count("steel_wool"),"fish_meat":world.inventory.count("fish_meat"),
		"humus":world.inventory.count("humus")}},"\t"))
	for failure in failures: printerr(failure)
	print("P7.d CARETAKER REPLAY ","OK" if failures.is_empty() else "FAIL"," · ",rows.size()," days · wool ",world.inventory.count("steel_wool"),
		" · fish ",world.inventory.count("fish_meat")," · wages ",world.workforce.state["spent"]," · cash ",world.primeval_stones)
	quit(0 if failures.is_empty() else 1)

func _fieldwork() -> void:
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

func _algae_rotation() -> void:
	if world.facilities.is_empty(): return
	for f in world.facilities.values():
		if f["facility_id"] != "algae_tank": continue
		if f["batch"].get("status") == "ready": _record("收取藻料",func(): return world.claim_batch(f["uid"],f["batch"]["batch_id"]))
		if f["batch"].is_empty() and world.inventory.count("straw") >= 2 and world.inventory.count("algae_feed") < 12:
			while world.inventory.count("clean_water") < 3: _record("泉水采集",func(): return world.collect("spring_source"))
			_record("启动藻料培养",func(): return world.start_batch(f["uid"],"culture_algae"))

func _daily_husbandry() -> void:
	if world.facilities.is_empty(): return
	for habitat_uid in [1,2]:
		if world.husbandry.habitat_of(habitat_uid)["individuals"].is_empty(): continue
		if world.inventory.count("clean_water") < 2: _record("泉水采集",func(): return world.collect("spring_source"))
		if habitat_uid == 1 and world.husbandry.habitat_of(1)["basic_diet_id"] == "grass_meal" and world.inventory.count("fodder_grass") < 2 and world.inventory.count("grain") >= 2:
			_record("切换谷粒餐",func(): return world.husbandry.set_base_diet(1,"grain_meal"))
		_record("手动整体维护%d" % habitat_uid,func(): return world.husbandry.maintain(habitat_uid))

## Only non-husbandry stages stay manual after delegation: compost, humus, ore.
## Products land in stock during the settle (day N end), so stages read them from N+1.
func _production_stages(day: int) -> void:
	if day == 13:
		while world.inventory.count("iron_ore") < 2: _record("采矿备特殊料",func(): return world.collect("ore_source"))
	if day == 17 and world.inventory.count("fish_manure") >= 2 and not world.facilities.has(4):
		while world.inventory.count("raw_stone") < 1 or world.inventory.count("raw_wood") < 1:
			_record("采石",func(): return world.collect("stone_source"))
		_record("建堆肥箱",func(): return world.build_facility(Vector2i(8,4),"compost_bin"))
		_record("鱼粪堆肥",func(): return world.start_batch(4,"compost_fish_manure"))
	if day == 20 and _compost_ready():
		_record("收取腐殖土",func(): return world.claim_batch(4,int(world.facilities[4]["batch"]["batch_id"])))
		_till_and_fertilize("鱼粪腐殖土")
		while world.inventory.count("iron_ore") < 1: _record("采矿备二次重启",func(): return world.collect("ore_source"))
	if day == 21 and world.inventory.count("sheep_manure") >= 2 and _compost_free():
		_record("羊粪堆肥",func(): return world.start_batch(4,"compost_sheep_manure"))
	if day == 23 and _compost_ready() and world.inventory.count("sheep_manure") == 0:
		_record("收取腐殖土二",func(): return world.claim_batch(4,int(world.facilities[4]["batch"]["batch_id"])))
		_till_and_fertilize("羊粪腐殖土")

func _compost_ready() -> bool:
	return world.facilities.has(4) and world.facilities[4]["batch"].get("status") == "ready"

func _compost_free() -> bool:
	return world.facilities.has(4) and world.facilities[4]["batch"].is_empty()

func _till_and_fertilize(label: String) -> void:
	var cell := _fertilizable()
	if world.grid.state_at(cell) == world.Grid.State.WILD:
		_record("开垦%s" % cell,func(): return world.till(cell))
	_record("施肥%s（%s）" % [cell,label],func(): return world.fertilize(cell))

func _fertilizable() -> Vector2i:
	for cell in [Vector2i(2,7),Vector2i(3,7),Vector2i(4,7),Vector2i(5,7)]:
		if world.grid.state_at(cell) == world.Grid.State.WILD and world.grid.can_till(cell)["ok"]:
			return cell
	for cell in [Vector2i(2,7),Vector2i(3,7),Vector2i(4,7),Vector2i(5,7)]:
		if world.grid.state_at(cell) in [world.Grid.State.TILLED, world.Grid.State.PLANTED]:
			return cell
	return Vector2i(2,7)

func _validate() -> void:
	if world.clock.total_days != 24: failures.append("replay must end on display day 25")
	if world.inventory.count("steel_wool") != 2: failures.append("caretakers must shear twice")
	if world.inventory.count("fish_meat") != 6: failures.append("caretakers must harvest the pond once")
	if world.inventory.count("fish_manure") != 0 or world.inventory.count("sheep_manure") != 0: failures.append("both manure streams must be composted")
	if world.inventory.count("humus") < 2: failures.append("two compost batches must leave humus after fertilizing")
	if world.husbandry.habitat_of(2)["individuals"].size() != 0: failures.append("harvested carp must be gone")
	if world.husbandry.habitat_of(1)["individuals"].size() != 1: failures.append("the sheared sheep must stay")
	if world.workforce.state["spent"] <= 0: failures.append("caretaker wages must actually be paid")
	var checked: Dictionary = Snapshot.normalize(world.to_snapshot())
	if not checked["ok"]: failures.append("final snapshot invalid: "+String(checked.get("reason","")))
	if world.ledger.state["history"].size() != 15: failures.append("ledger history keeps the latest fifteen settled days")

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
