extends SceneTree
const World := preload("res://scripts/farming/p8/p8_world.gd")
const Codec := preload("res://scripts/farming/p8/p8_snapshot.gd")
const Fixture := preload("res://scripts/farming/tests/p107_fixture.gd")
var checks := 0
var failures := []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("P107 MODEL " + label)

func run() -> void:
	var w := World.new()
	check(Codec.normalize(w.to_snapshot())["ok"], "fresh schema25 normalizes")
	check(w.progress.stage() == 0 and w.progress.deliveries() == 0, "starts at global stage0")
	check(not w.progress.complete_event("first_workshop")["ok"], "orders required")
	check(not w.logistics.provision()["ok"], "trial gu acquisition event gate")
	check(not w.logistics.buy_gu("product_yield_gu")["ok"], "market gu event gate")
	check(not w.research.quote_start(1, "biofiltration")["ok"], "invalid bench refuses")
	check(not w.can_build_facility(Vector2i(4, 1), "pen")["ok"], "animal infrastructure event gate")
	check(not w.water.quote_fence([Vector2i(4, 15)])["ok"], "fence event gate")
	check(w.progress.block("research", "farm_preparation").is_empty(), "basic processing remains available")
	check(not w.progress.block("research", "biofiltration").is_empty(), "stage1 research remains gated")
	Fixture.unlock(w, 1)
	check(w.progress.stage() == 1 and w.progress.deliveries() >= 3, "real successful orders open stage1")
	check(Codec.normalize(w.to_snapshot())["ok"], "stage1 roundtrip")
	check(not w.progress.complete_event("first_workshop")["ok"], "duplicate event refuses")
	var completed_order: Dictionary = w.daily_orders()[0]
	var count: int = w.progress.deliveries()
	check(not w.deliver_order(int(completed_order["id"]), String(completed_order["receipt"]["item_id"]))["ok"], "duplicate supply refuses")
	check(w.progress.deliveries() == count, "duplicate supply never counts")
	w.grant_scaffold({"resin": 500, "silk": 40})
	var before := w.to_snapshot()
	check(not w.progress.exchange("resin_for_panels")["ok"], "later-stage barter refuses")
	check(not w.progress.exchange("resin_for_sludge", 0)["ok"], "zero batches refuse")
	check(not w.progress.exchange("resin_for_sludge", 1.5)["ok"], "fractional batches refuse")
	check(w.to_snapshot() == before, "failed quotes and exchanges are readonly")
	var cash := w.primeval_stones
	var ap := w.clock.ap
	var resin := w.inventory.count("resin")
	var sludge := w.inventory.count("sludge")
	check(w.progress.exchange("resin_for_sludge", 3)["ok"], "fixed batch exchange succeeds")
	check(w.inventory.count("resin") == resin - 6 and w.inventory.count("sludge") == sludge + 6, "physical quantities exact")
	check(w.primeval_stones == cash and w.clock.ap == ap and w.progress.deliveries() == count, "exchange changes neither cash AP nor supply count")
	for i in range(12): check(w.progress.exchange("resin_for_sludge")["ok"], "no daily exchange quota %d" % i)
	check(Codec.normalize(w.to_snapshot())["ok"], "multiple exchanges and milestones serialize")
	Fixture.unlock(w, 2)
	check(w.progress.deliveries() >= 12 and w.progress.stage() == 2, "cumulative history opens stage2")
	check(w.progress.block("research", "aquatic_intensive_care").is_empty(), "complex recipe available before final event")
	check(w.progress.block("research", "composite_spirit_food") != "", "final-stage project still gated")
	w.grant_scaffold({"resin": 100})
	for id in ["resin_for_panels", "resin_for_refined_oil", "resin_for_matrix"]:
		var event: Dictionary = w.progress.config["events"][2]
		var swap: Dictionary = w.progress.offer(id)
		var item: String = swap["receive"].keys()[0]
		var amount := int(event["inputs"][item])
		# Previous fixture supply may include these inputs. Remove it explicitly
		# so this assertion proves the exchange path, not injected final goods.
		var old := w.inventory.count(item)
		if old > 0:
			w.inventory.remove(item, old)
			w._record_flow({}, {item: old}, "清除夹具高级材料")
		check(w.progress.exchange(id, ceili(float(amount) / int(swap["receive"][item])))["ok"], "specialist obtains " + item)
	check(w.progress.complete_event("integrated_estate")["ok"], "exchanged complex materials submit")
	check(w.progress.stage() == 3, "advanced event opens global stage3")
	check(Codec.normalize(w.to_snapshot())["ok"], "stage3 serializes without any animal rooms")
	var bad := w.to_snapshot()
	bad["world"]["economy_progress"]["next_seq"] += 1
	check(not Codec.normalize(bad)["ok"], "forged sequence refuses")
	bad = w.to_snapshot()
	bad["world"]["economy_progress"]["events"][0]["orders"] = 9999
	check(not Codec.normalize(bad)["ok"], "supply count backed by actual orders")
	bad = w.to_snapshot()
	bad["world"]["economy_progress"]["exchanges"][0]["offer"] = "unknown"
	check(not Codec.normalize(bad)["ok"], "unknown exchange receipt refuses")
	bad = w.to_snapshot()
	bad["world"]["economy_progress"]["exchanges"][0]["seq"] = 1
	check(not Codec.normalize(bad)["ok"], "repeated transaction refuses")
	_biological(w)
	print("P107 MODEL %s (%d)" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _biological(w: World) -> void:
	w.research.state["completed"] = w.research.project_defs().keys()
	w.grant_scaffold({"raw_wood": 20, "raw_stone": 20, "wood_plank": 20, "twig": 20})
	for y in range(1, 3):
		for x in range(4, 6): w.rooms.set_floor(Vector2i(x, y), "ordinary")
	var built: Dictionary = w.build_facility(Vector2i(4, 1), "carbonization_nest")
	check(built["ok"], "proper stage can build biological yard")
	if not built["ok"]: return
	var uid := int(built["facility_uid"])
	var before := w.to_snapshot()
	check(not w.start_batch(uid, "bug_char_twigs")["ok"], "zero animals cannot use generic batch")
	check(w.to_snapshot() == before, "rejected biological start pays nothing")
	check(not w.operations.set_production(uid, true, "bug_char_twigs", "charcoal", 10)["ok"], "automation cannot configure bypass")
	check(w.operations.available_recipes(uid).is_empty(), "UI strategy recipes exclude animal labour")
	var forged := w.to_snapshot()
	for row in forged["world"]["facilities"]:
		if int(row["uid"]) == uid:
			row["batch"] = {"batch_id": 1, "recipe_id": "bug_char_twigs", "inputs": {"twig": 4}, "outputs": {"charcoal": 4, "humus": 1},
				"start_day": w.clock.total_days, "finish_day": w.clock.total_days + 1, "status": "processing"}
	forged["world"]["next_batch_uid"] = 2
	check(not Codec.normalize(forged)["ok"], "forged generic biological batch refuses")
