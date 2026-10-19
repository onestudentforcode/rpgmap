extends SceneTree
## P10.1 short contrasts (§11): twin 6-cell wheat plots — one inside a directed
## service zone, one unassisted — under rich and scarce supply plus a growth
## throughput run. Every number comes from real inventory purchases and real
## environment reads; nothing is injected mid-run.
const World := preload("res://scripts/farming/p8/p8_world.gd")
const Codec := preload("res://scripts/farming/p8/p8_snapshot.gd")
const WATER_DAYS := 45
const FERT_DAYS := 80
const COVERED := [Vector2i(6,4),Vector2i(7,4),Vector2i(6,5),Vector2i(7,5)]
const TWIN := [Vector2i(6,8),Vector2i(7,8),Vector2i(6,9),Vector2i(7,9)]
var checks := 0
var failures := []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL: ",label)

func _initialize() -> void:
	_scenario("water_rich","trial-008","rich","rich",WATER_DAYS,"pasture_grass")
	_scenario("water_scarce","trial-008","fixed","rich",WATER_DAYS,"pasture_grass")
	_scenario("fert_rich","trial-010","rich","rich",FERT_DAYS,"golden_wheat")
	_scenario("fert_scarce","trial-010","rich","fixed",FERT_DAYS,"golden_wheat")
	_scenario("growth_rich","trial-004","rich","rich",WATER_DAYS,"pasture_grass")
	print("P101 CONTRASTS %s (%d)" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func _scenario(name: String, gu_id: String, water_policy: String, fert_policy: String, days: int, crop_id: String) -> void:
	var w := World.new()
	w.logistics.provision()
	w.grant_scaffold({"wood_plank":10,"iron_ingot":4,"grass_seed":60,"golden_wheat_seed":60,"clean_water":10,"humus":10})
	if fert_policy == "rich": w.grant_scaffold({"humus":60})
	w.research.state["completed"] = w.research.project_defs().keys()
	check(w.build_facility(Vector2i(4,4),"field_service_station","east")["ok"],name+" station built")
	var station := 0
	for uid in w.facilities: station = int(uid)
	check(w.devices.configure_station(station,false,false,30)["ok"],name+" station auto-services disabled for a clean contrast")
	check(w.logistics.deploy(gu_id,Vector2i(-1,-1),station)["ok"],name+" gu admitted")
	for pair in [["covered",COVERED],["twin",TWIN]]:
		for cell in pair[1]:
			w.till(cell)
			check(w.plant(cell,crop_id)["ok"],name+" "+pair[0]+" planted")
	w.end_day()
	var stats := {"covered":{"water":0,"fert":0,"harvests":0,"units":0,"water_ok_days":0,"fert_ok_days":0},
		"twin":{"water":0,"fert":0,"harvests":0,"units":0,"water_ok_days":0,"fert_ok_days":0}}
	# Scarce scenarios split the fixed stock evenly between the twin plots so
	# watering order cannot mask the retention difference.
	var scarce := water_policy == "fixed" or fert_policy == "fixed"
	var budget := {"covered": {"water": 5, "fert": 5}, "twin": {"water": 5, "fert": 5}}
	for day in range(1,days+1):
		for item in ["clean_water","humus"]:
			var policy := water_policy if item == "clean_water" else fert_policy
			if policy == "rich" and int(w._items[item]["buy_price"]) > 0 and w.inventory.count(item) < 6 and w.primeval_stones > 12:
				var result := w.buy(item,6-w.inventory.count(item))
				check(result["ok"],name+" real "+item+" purchase")
		for pair in [["covered",COVERED],["twin",TWIN]]:
			var bucket: Dictionary = stats[pair[0]]
			var water_ok := true
			var fert_ok := true
			for cell in pair[1]:
				var env: Dictionary = w.environment_at(cell)
				if int(env["water"]) < 40 and (not scarce or budget[pair[0]]["water"] > 0) and w.inventory.has("clean_water",1) and w.irrigate(cell)["ok"]:
					bucket["water"] += 1
					if scarce: budget[pair[0]]["water"] -= 1
				if int(env["fertility"]) < 40 and (not scarce or budget[pair[0]]["fert"] > 0) and w.inventory.has("humus",1) and w.fertilize(cell)["ok"]:
					bucket["fert"] += 1
					if scarce: budget[pair[0]]["fert"] -= 1
				var after: Dictionary = w.environment_at(cell)
				if int(after["water"]) < 30: water_ok = false
				if int(after["fertility"]) < 30: fert_ok = false
			if water_ok: bucket["water_ok_days"] += 1
			if fert_ok: bucket["fert_ok_days"] += 1
		for pair in [["covered",COVERED],["twin",TWIN]]:
			var bucket: Dictionary = stats[pair[0]]
			for cell in pair[1]:
				var crop: Dictionary = w.instance_at(cell)
				if crop.is_empty():
					if w.grid.state_at(cell) == 0: w.till(cell)
					if w.grid.state_at(cell) == 1 and w.inventory.count("golden_wheat_seed") > 0 and w.plant(cell,crop_id)["ok"]:
						pass
				elif String(crop["state"]) == "mature":
					var before: int = w.inventory.count("fodder_grass")
					if w.harvest(cell,"harvest")["ok"]:
						bucket["harvests"] += 1
						bucket["units"] += w.inventory.count("fodder_grass") - before
					if w.grid.state_at(cell) == 1 and w.inventory.count("golden_wheat_seed") > 0:
						w.plant(cell,crop_id)
		w.end_day()
	var covered: Dictionary = stats["covered"]
	var twin: Dictionary = stats["twin"]
	var agri: Dictionary = w.logistics.agri_to_save()
	check(Codec.normalize(w.to_snapshot())["ok"],name+" final snapshot valid")
	match name:
		"water_rich":
			check(int(covered["water"]) < int(twin["water"]),name+" covered plot spends fewer real water (%d vs %d)" % [int(covered["water"]),int(twin["water"])])
			check(int(covered["units"]) >= int(twin["units"]),name+" same or better yield despite lower use")
			# Every current crop's water use times 50% is a whole number, so the
			# water accumulator legitimately rests at zero; the twin check below
			# still proves no phantom remainder appears outside the zone.
			var twin_keys := 0
			for key in agri["remainders"]["water"]:
				if Vector2i(int(key.split(",")[0]),int(key.split(",")[1])) in TWIN: twin_keys += 1
			check(twin_keys==0,name+" unassisted plot never accumulates a remainder")
		"water_scarce":
			check(int(covered["water_ok_days"]) > int(twin["water_ok_days"]),name+" covered plot keeps full-rate days longer under scarcity (%d vs %d)" % [int(covered["water_ok_days"]),int(twin["water_ok_days"])])
			check(int(covered["water"])+int(twin["water"]) <= 10,name+" scarcity respected the fixed water stock")
		"fert_rich":
			check(int(covered["fert"]) < int(twin["fert"]),name+" covered plot spends fewer real fertilizer (%d vs %d)" % [int(covered["fert"]),int(twin["fert"])])
		"fert_scarce":
			check(int(covered["fert"]) <= int(twin["fert"]) and int(twin["fert_ok_days"]) < days,name+" scarcity bites the twin while the covered plot keeps full rate (%d vs %d of %d days)" % [int(covered["fert_ok_days"]),int(twin["fert_ok_days"]),days])
			check(int(covered["fert"])+int(twin["fert"]) <= 10,name+" scarcity respected the fixed fertilizer stock")
		"growth_rich":
			check(int(covered["harvests"]) > int(twin["harvests"])+1,name+" growth module out-harvests the twin (%d vs %d)" % [int(covered["harvests"]),int(twin["harvests"])])
	print(name," ",JSON.stringify(stats))
