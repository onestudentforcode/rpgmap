extends SceneTree
## Independently rerunnable <=30-day cases. Each archives an external initial
## snapshot, public commands, operation receipts and external final snapshot.
const World := preload("res://scripts/farming/p8/p8_world.gd")
const Codec := preload("res://scripts/farming/p8/p8_snapshot.gd")
const Fixture := preload("res://scripts/farming/tests/p107_fixture.gd")
const CASES := ["stage-orders", "stage-resources", "barter", "research-access", "specialist-route", "growth-budget"]
var out := "res://.art-work/p107-playtest"
var selected := "all"
var route := ""
var file: FileAccess
var commands := 0
var operations := []
var checks := 0
var failures := []
var start_day := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(route + ": " + label)
		printerr("P107 PLAYTEST " + route + ": " + label)

func write_json(path: String, value) -> void:
	var target := FileAccess.open(path, FileAccess.WRITE)
	target.store_string(JSON.stringify(value, "\t"))
	target.close()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): selected = arg.trim_prefix("--case=")
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	if selected != "all" and not CASES.has(selected):
		printerr("Unknown P107 case: " + selected)
		quit(1)
		return
	for name in CASES:
		if selected != "all" and name != selected: continue
		route = name
		var folder := out.path_join(name)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		var w := World.new()
		var kind := "declared-rule-fixture"
		if name == "stage-orders": kind = "fresh-no-injection"
		elif name == "research-access":
			Fixture.unlock(w, 1)
			w.progress.state = w.progress.fresh()
			w.grant_scaffold({"raw_wood": 20, "raw_stone": 20, "wood_plank": 10, "mushroom": 4, "wastewater": 4})
		else:
			Fixture.unlock(w, 2)
			if name == "growth-budget":
				# Knowledge of basic cultivation/processing is the declared start;
				# no construction materials, seeds, cash or resin are added here.
				w.research.state["completed"] = ["flower_cultivation", "farm_preparation"]
			else: w.grant_scaffold({"resin": 120, "silk": 80})
		start_day = w.clock.total_days
		commands = 0
		file = FileAccess.open(folder.path_join("commands.jsonl"), FileAccess.WRITE)
		w.operation_recorded.connect(func(row: Dictionary): operations.append(row))
		write_json(folder.path_join("initial.json"), w.to_snapshot())
		write_json(folder.path_join("case.json"), {"case": name, "kind": kind, "start_day": start_day,
			"production_sha256": FileAccess.get_sha256("res://content/farming/baked/p8/production.json")})
		var prior_failures := failures.size()
		match name:
			"stage-orders": _orders(w)
			"research-access": _research(w)
			"growth-budget": _growth(w)
			_: _exchange(w)
		check(w.clock.total_days - start_day <= 30, "case bounded to thirty days")
		check(Codec.normalize(w.to_snapshot())["ok"], "final snapshot strict codec")
		file.close()
		write_json(folder.path_join("final.json"), w.to_snapshot())
		write_json(folder.path_join("result.json"), {"checks": checks, "commands": commands,
			"days": w.clock.total_days - start_day, "ok": failures.size() == prior_failures})
		print("P107 CASE %s %s (%d commands)" % [name, "OK" if failures.size() == prior_failures else "FAIL", commands])
	write_json(out.path_join("latest-result.json"), {"selected": selected, "checks": checks, "failures": failures})
	print("P107 PLAYTEST %s (%d)" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func view(w: World) -> Dictionary:
	return {"day": w.clock.total_days, "ap": w.clock.ap, "cash": w.primeval_stones,
		"inventory": w.inventory.to_save(), "stage": w.progress.stage(), "orders": w.progress.deliveries(),
		"sequence": w.progress.state["next_seq"], "crops": w.to_snapshot()["world"]["crops"]}

func act(w: World, name: String, args: Array = [], expected := true) -> Dictionary:
	var before := view(w)
	operations = []
	var result: Dictionary
	match name:
		"collect": result = w.collect(args[0])
		"buy": result = w.buy(args[0], args[1])
		"sell": result = w.sell(args[0], args[1])
		"order": result = w.deliver_order(args[0], args[1])
		"event": result = w.progress.complete_event(args[0])
		"exchange": result = w.progress.exchange(args[0], args[1])
		"end": result = w.end_day()
		"till": result = w.till(Vector2i(args[0], args[1]))
		"plant": result = w.plant(Vector2i(args[0], args[1]), args[2])
		"harvest": result = w.harvest(Vector2i(args[0], args[1]))
		"irrigate": result = w.irrigate(Vector2i(args[0], args[1]))
		"fertilize": result = w.fertilize(Vector2i(args[0], args[1]))
		"build": result = w.build_facility(Vector2i(args[0], args[1]), args[2])
		"start_batch": result = w.start_batch(args[0], args[1])
		"claim_batch": result = w.claim_batch(args[0], args[1])
		"start_research": result = w.research.start(args[0], args[1])
		"research_work": result = w.research.work(args[0])
		"buy_gu": result = w.logistics.buy_gu(args[0])
		_: result = {"ok": false, "reason": "unknown replay command"}
	var after := view(w)
	commands += 1
	file.store_line(JSON.stringify({"n": commands, "command": name, "args": args,
		"before": before, "result": result, "after": after, "operations": operations}))
	check(bool(result["ok"]) == expected and w.daily_save_error.is_empty(), name + " expected result: " + str(result))
	if not expected: check(before == after, "rejected command makes no transfer")
	return result

func _orders(w: World) -> void:
	for _day in range(24):
		for i in range(6): act(w, "collect", ["spring_source"])
		for order in w.daily_orders():
			if order["status"] != "open": continue
			for item in w._items:
				var quote: Dictionary = w.order_quote(int(order["id"]), item)
				if not quote.get("ok"): continue
				var needed := int(quote["quantity"])
				if w.inventory.has(item, needed):
					act(w, "order", [int(order["id"]), item])
					break
		if w.progress.event_quote()["ok"]: act(w, "event", [w.progress.event_quote()["id"]])
		if w.progress.stage() == 2: break
		act(w, "end")
	check(w.progress.stage() == 2 and w.progress.deliveries() >= 12, "fresh collected water reaches both supply milestones without injection or purchasing")

func _exchange(w: World) -> void:
	if route == "specialist-route":
		var existing := w.inventory.count("resin")
		# Consume declared initial resin through recorded trades. The final
		# event is subsequently funded solely by the silk trade below.
		act(w, "exchange", ["resin_for_sludge", existing / 2])
		act(w, "exchange", ["silk_for_resin", 20])
	else:
		act(w, "event", ["integrated_estate"], false)
		act(w, "exchange", ["unknown", 1], false)
		act(w, "exchange", ["resin_for_sludge", -1], false)
		if route == "barter":
			for i in range(12): act(w, "exchange", ["resin_for_sludge", 1])
	for spec in [["resin_for_panels", 3], ["resin_for_refined_oil", 2], ["resin_for_matrix", 2]]:
		act(w, "exchange", spec)
	act(w, "event", ["integrated_estate"])
	act(w, "event", ["integrated_estate"], false)
	check(w.progress.stage() == 3 and w.facilities.is_empty() and w.ranch.state["animals"].is_empty(), "cross-industry event delivery does not require all industries")
	act(w, "end")

func _research(w: World) -> void:
	var built := act(w, "build", [4, 1, "research_bench"])
	if not built["ok"]: return
	var uid := int(built["facility_uid"])
	act(w, "start_research", [uid, "biofiltration"], false)
	act(w, "event", ["first_workshop"])
	act(w, "start_research", [uid, "biofiltration"])
	for i in range(2):
		act(w, "research_work", [uid])
		act(w, "end")
	check(w.research.is_completed("biofiltration"), "same valid research bench completes after milestone")

func _growth(w: World) -> void:
	var origins := [Vector2i(4, 1), Vector2i(7, 1), Vector2i(10, 1)]
	for index in range(3):
		var origin: Vector2i = origins[index]
		if index > 0: act(w, "buy", ["resin_tree_seed", 1])
		for dy in range(2):
			for dx in range(2): act(w, "till", [origin.x + dx, origin.y + dy])
		act(w, "plant", [origin.x, origin.y, "resin_tree"])
	# Two ordinary expansions have now really paid their seeds, 8 tiles and
	# planting AP. First harvest funds the support workshops rather than being
	# counted twice as both working capital and milestone material.
	var rounds := 0
	var workshop := 0
	var compost := 0
	var smelter := 0
	var saw_rounds := 0
	var iron_started := false
	for _day in range(30):
		if w.clock.total_days - start_day >= 29: break
		for origin in origins:
			for dy in range(2):
				for dx in range(2):
					var cell: Vector2i = origin + Vector2i(dx, dy)
					if int(w.environment_at(cell)["water"]) < 34:
						if w.inventory.count("clean_water") < 1: act(w, "collect", ["spring_source"])
						act(w, "irrigate", [cell.x, cell.y])
		var ready: bool = origins.all(func(origin): return w.instance_at(origin).get("state") == "mature")
		if ready:
			for origin in origins: act(w, "harvest", [origin.x, origin.y])
			rounds += 1
			if rounds == 1:
				act(w, "sell", ["resin", 12])
				act(w, "buy", ["raw_wood", 11])
				act(w, "buy", ["fodder_grass", 2])
				act(w, "buy", ["grain", 1])
				for i in range(4): act(w, "collect", ["stone_source"])
				for i in range(2): act(w, "collect", ["ore_source"])
				workshop = int(act(w, "build", [4, 4, "woodshop"]).get("facility_uid", 0))
				compost = int(act(w, "build", [8, 4, "compost_bin"]).get("facility_uid", 0))
				act(w, "start_batch", [compost, "compost_grass"])
		for uid in [workshop, compost, smelter]:
			if uid == 0: continue
			var batch: Dictionary = w.facilities[uid].get("batch", {})
			if batch.get("status") == "ready": act(w, "claim_batch", [uid, int(batch["batch_id"])])
		if workshop > 0 and saw_rounds < 3 and w.facilities[workshop].get("batch", {}).is_empty():
			act(w, "start_batch", [workshop, "saw_planks"])
			saw_rounds += 1
		if workshop > 0 and smelter == 0 and w.inventory.count("wood_plank") >= 2:
			smelter = int(act(w, "build", [10, 4, "smelter"]).get("facility_uid", 0))
		if smelter > 0 and not iron_started and w.inventory.count("resin") > 0:
			act(w, "start_batch", [smelter, "smelt_resin"])
			iron_started = true
		if rounds == 6: break
		act(w, "end")
	check(rounds == 6, "first startup harvest plus five steady production rounds actually collected")
	check(w.inventory.count("resin") >= 52, "five paid-expansion rounds cover resource event after real support processing")
	for spec in [["resin_for_panels", 3], ["resin_for_refined_oil", 2], ["resin_for_matrix", 2]]: act(w, "exchange", spec)
	act(w, "event", ["integrated_estate"])
	var bench := int(act(w, "build", [13, 4, "research_bench"]).get("facility_uid", 0))
	while w.inventory.count("clean_water") < 4: act(w, "collect", ["spring_source"])
	act(w, "start_research", [bench, "field_maintenance"])
	for i in range(2):
		act(w, "research_work", [bench])
		act(w, "end")
	act(w, "build", [3, 1, "field_service_station"])
	act(w, "buy_gu", ["growth_gu"])
	check(w.research.is_completed("field_maintenance") and w.progress.stage() == 3 and w.primeval_stones >= 0, "cross-tier event research host and gu acquisition all paid without more injection")
