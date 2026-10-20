extends SceneTree
## Boundary/data contract probes. Quotes are exported for an independent Python
## calculation instead of treating supply nutrition as sale price.
const Data := preload("res://scripts/farming/p8/p8_data.gd")
const World := preload("res://scripts/farming/p8/p8_world.gd")
const Codec := preload("res://scripts/farming/p8/p8_snapshot.gd")
var checks := 0
var failures := []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("P107 CONTRACT " + label)

func _initialize() -> void:
	var data: Dictionary = Data.load_data()
	var rows := []
	for item in data["resources"]:
		if not item["supply_allowed"]: continue
		for path in data["orders"]["paths"]:
			for rank in range(1, 6):
				for demand in [1, int(data["orders"]["base_demand"]) * rank]:
					rows.append({"item": item["id"], "path": path, "rank": rank, "demand": demand,
						"quote": Data.demand_quote(path, rank, demand, item["id"])})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.art-work/p107-tests"))
	var file := FileAccess.open("res://.art-work/p107-tests/contract-quotes.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows))
	file.close()
	check(not Data.demand_quote("water", 0, 12, "clean_water")["ok"], "rank zero rejected")
	check(not Data.demand_quote("water", 6, 12, "clean_water")["ok"], "rank six rejected")
	check(not Data.demand_quote("water", 1, 0, "clean_water")["ok"], "zero demand rejected")
	check(not Data.demand_quote("water", 1, 5000001, "clean_water")["ok"], "demand limit rejected")
	var w := World.new()
	for i in range(6): check(w.collect("spring_source")["ok"], "daily resource harvest " + str(i))
	var before := w.to_snapshot()
	check(not w.collect("spring_source")["ok"] and w.to_snapshot() == before, "daily source capacity refuses extra collection without charge")
	check(w.inventory.count("clean_water") == 30, "six player AP gather thirty units")
	var order_id := 0
	for row in w.daily_orders():
		if row["path"] == "water": order_id = int(row["id"])
	check(order_id > 0 and w.daily_orders().size() == 3, "exactly three deterministic daily orders")
	check(w.deliver_order(order_id, "clean_water")["ok"] and w.progress.deliveries() == 1, "twelve units count as one successful order")
	check(w.buy("grain", 2)["ok"] and w.sell("grain", 1)["ok"] and w.progress.deliveries() == 1, "ordinary buy/sell never increases order milestones")
	before = w.to_snapshot()
	check(not w.deliver_order(order_id, "clean_water")["ok"] and w.to_snapshot() == before, "completed order cannot repeat")
	check(w.end_day()["ok"] and w.daily_orders().size() == 3, "next day replaces daily offers")
	before = w.to_snapshot()
	check(not w.deliver_order(order_id, "clean_water")["ok"] and w.to_snapshot() == before, "expired order cannot pay or count")
	check(w.progress.deliveries() == 1 and Codec.normalize(w.to_snapshot())["ok"], "complete settlement history retains the actual count")
	for recipe_id in data["p103"]["work"]["recipes"]:
		var reply: Dictionary = w.start_batch(999, recipe_id)
		check(not w.batch_block(recipe_id).is_empty() and not reply["ok"] and String(reply["reason"]).contains("动物岗位"), "all animal recipes reject the generic route " + recipe_id)
	_capture_costs(data)
	print("P107 CONTRACT %s (%d)" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _capture_costs(data: Dictionary) -> void:
	var observations := []
	for sid in ["filter_algae_carp", "oilfin_fish"]:
		var helper = preload("res://scripts/farming/tests/run_phase106.gd").new()
		var w: World = helper._world()
		# An explicit rule fixture: actual APIs/ledgers, no disk timing in this
		# lifetime measurement (disk transactions have their own checks).
		w._store = null
		var cfg: Dictionary = data["p103"]["species"][sid]
		var zones: Dictionary = helper._water_module(w, "water_production", cfg["natural"]["station"])
		check(w.build_facility(Vector2i(4, 14), "feed_trough")["ok"], "nursery has four meal places " + sid)
		check(w.build_facility(Vector2i(8, 15), "feed_trough")["ok"], "production has four meal places " + sid)
		if int(cfg["space"]) == 2:
			check(w.build_facility(Vector2i(7, 16), cfg["natural"]["station"])["ok"], "second large-animal production station")
			var nursery: Dictionary = w.ranch.zone(zones["nursery"])
			var cells: Array = nursery["cells"].duplicate()
			var added := []
			for y in range(14, 18):
				added.append(Vector2i(5, y))
				cells.append("5,%d" % y)
			check(w.water.build_fence(added, int(nursery["body_uid"]))["ok"], "eight-space population gets a full nursery footprint")
			check(w.ranch.erase_zone(zones["nursery"])["ok"], "replace empty nursery boundary explicitly")
			var replaced: Dictionary = w.ranch.create_zone("water_nursery", cells, "capture reference nursery")
			check(replaced["ok"], "expanded nursery structurally valid")
			zones["nursery"] = int(replaced.get("zone_uid", 0))
		var started := w.clock.total_days
		var before := w.inventory.to_save()
		var cash := w.primeval_stones
		var purchased: Dictionary = w.ranch.purchase(zones["nursery"], sid, 4)
		check(purchased["ok"], "purchase complete reference population " + sid + ": " + str(purchased))
		if not purchased["ok"]:
			helper.free()
			continue
		var bought := cash - w.primeval_stones
		for _day in range(10):
			if w.ranch.state["animals"].all(func(a): return a["stage"] == "adult"): break
			w.end_day()
		var grown := w.clock.total_days - started
		var assignments := {}
		var bed: Dictionary = w.facility_at(Vector2i(9, 15) if int(cfg["space"]) == 2 else Vector2i(9, 14))
		for index in range(4):
			var animal: Dictionary = w.ranch.state["animals"][index]
			assignments[int(animal["uid"])] = {"mode": "water_production", "zone_uid": zones["pool"], "bed_uid": bed["uid"], "bed_slot": index}
		var ap := w.clock.ap
		check(w.ranch.submit({"assign": assignments})["ok"] and w.clock.ap == ap - 1, "actual adult assignment costs one AP " + sid)
		w.end_day()
		check(w.ranch.state["animals"].all(func(a): return int(a["natural"]["units"]) == 0), "transfer boundary includes one waiting day " + sid)
		for _day in range(10):
			if w.ranch.state["animals"].all(func(a): return a["natural"]["pending"]): break
			w.end_day()
		var consumed := {}
		for item in before:
			var amount: int = int(before[item]) - w.inventory.count(item)
			if amount > 0: consumed[item] = amount
		var days := w.clock.total_days - started
		var expected := ceili(float(cfg["growth_units"]) / 600) + 1 + ceili(float(cfg["natural"]["units"]) / 600)
		check(days == expected and grown == ceili(float(cfg["growth_units"]) / 600), "measured full capture calendar " + sid)
		check(w.ranch.claim_natural(w.facility_at(Vector2i(6, 16))["uid"])["ok"], "actual capture claim " + sid)
		check(w.ranch.state["animals"].is_empty() and helper.failures.is_empty(), "captured population consumed after legal care " + sid)
		observations.append({"species": sid, "population": 4, "days": days, "inputs": consumed,
			"cash": bought, "assignment_ap": 1, "claim_ap": 1})
		helper.free()
	var file := FileAccess.open("res://.art-work/p107-tests/capture-costs.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(observations))
	file.close()
