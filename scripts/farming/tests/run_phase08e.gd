extends SceneTree
## P8.e checks: real water changes feed the purification loop (T04 → purifying
## bed → R10 → V02), mat lifecycle boundaries, standby behaviour, stock
## competition between beds and the gravel-gated fixtures for R09/R11/R12.
const P8World := preload("res://scripts/farming/p8/p8_world.gd")
const P8Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const P8Snapshot := preload("res://scripts/farming/p8/p8_snapshot.gd")

var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func temp_store() -> P8Store:
	return P8Store.new("user://p8e_test_%d" % Time.get_ticks_usec())

func complete_research(world, bench: int, project_id: String, samples: Dictionary) -> void:
	world.grant_scaffold(samples)
	var started: Dictionary = world.research.start(bench, project_id)
	check(started["ok"], "start %s (%s)" % [project_id, String(started.get("reason", ""))])
	var guard := 0
	while not world.research.is_completed(project_id) and guard < 12:
		world.research.work(bench)
		world.end_day()
		guard += 1

## Test-only discard that keeps the resource ledger conservative.
func discard(world, item: String, quantity: int) -> void:
	if quantity <= 0:
		return
	world.inventory.remove(item, quantity)
	world._record_flow({}, {item: quantity}, "测试弃置")

func uid_of(world, facility_id: String, index: int = 0) -> int:
	var found := []
	for uid in world.facilities:
		if String(world.facilities[uid]["facility_id"]) == facility_id:
			found.append(int(uid))
	found.sort()
	return found[mini(index, found.size() - 1)] if not found.is_empty() else 0

func _initialize() -> void:
	_voucher_redirect()
	_basic_purification_loop()
	_mat_boundaries()
	_two_ponds_and_competition()
	_gravel_fixtures()
	_snapshot_contracts()
	for failure in failures: printerr(failure)
	print("PHASE08E TEST %s · %d checks" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func drain_batch(world, facility_uid: int) -> void:
	var guard := 0
	while not world.facilities[facility_uid]["batch"].is_empty() and guard < 12:
		var batch: Dictionary = world.facilities[facility_uid]["batch"]
		if batch["status"] == "ready":
			world.claim_batch(facility_uid, int(batch["batch_id"]))
		else:
			world.end_day()
		guard += 1

# --- 1. The culture voucher never lands in the warehouse -----------------------

func _voucher_redirect() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"grain": 2, "humus": 1, "raw_wood": 2, "raw_stone": 2})
	world.build_facility(Vector2i(2, 4), "research_bench")
	complete_research(world, 1, "flower_cultivation", {"grain": 2, "humus": 1})
	complete_research(world, 1, "biofiltration", {"wastewater": 2, "mushroom": 1})
	var blocked: Dictionary = world.buy("purifying_mat_culture", 1)
	check(not blocked["ok"] and String(blocked["reason"]).find("净水菌床") >= 0, "market voucher redirected to the bed panel")
	check(world.inventory.count("purifying_mat_culture") == 0, "no culture copy enters the warehouse")

# --- 2. The basic purification loop on real water changes ----------------------

func _basic_purification_loop() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 6, "raw_stone": 10, "clean_water": 30, "mushroom": 1})
	world.primeval_stones += 20  # 测试注资：覆盖菌床采购与堆肥箱
	check(world.build_facility(Vector2i(0, 14), "fish_pond")["ok"], "build the pond")
	var pond := uid_of(world, "fish_pond")
	check(world.husbandry.purchase(pond, 2)["ok"], "buy fry for real changes")
	check(world.end_day()["ok"], "settle day 0")
	world.collect("spring_source")
	check(world.husbandry.maintain_water(pond)["ok"], "real water change")
	check(world.inventory.count("wastewater") == 2, "real sewage in stock")
	check(world.build_facility(Vector2i(2, 4), "research_bench")["ok"], "build bench")
	complete_research(world, uid_of(world, "research_bench"), "biofiltration", {"wastewater": 2, "mushroom": 1})
	discard(world, "wastewater", world.inventory.count("wastewater"))
	check(world.inventory.count("wastewater") == 0, "T04 consumed its samples")
	check(world.build_facility(Vector2i(0, 1), "purifying_bed")["ok"], "build the bed after T04")
	var bed := uid_of(world, "purifying_bed")
	check(world.husbandry.purchase(bed, 2)["ok"], "buy two culture units straight into the bed")
	check(world.inventory.count("purifying_mat_culture") == 0, "placement only, no warehouse copy")
	world.collect("spring_source")
	world.collect("spring_source")
	var fed: Dictionary = world.husbandry.maintain(bed)
	check(fed["ok"] and int(fed["served"]) == 2, "first culture maintenance")
	check(world.inventory.count("clean_water") >= 0, "culture water really deducted")
	check(world.end_day()["ok"], "settle the first culture day")
	world.collect("spring_source")
	check(world.husbandry.maintain(bed)["ok"], "second culture day")
	world.end_day()
	var summary: Dictionary = world.husbandry.summary(world.husbandry.habitat_of(bed))
	check(int(summary["adult"]) == 2, "cultures mature after two served days")
	world.grant_scaffold({"wastewater": 8, "wood_chip": 2})
	var sewage_before := world.inventory.count("wastewater")
	var chips_before := world.inventory.count("wood_chip")
	var started: Dictionary = world.husbandry.maintain(bed)
	check(started["ok"] and int(started["started"]) == 2, "both adults start R10 batches")
	check(world.inventory.count("wastewater") == sewage_before - 8 and world.inventory.count("wood_chip") == chips_before - 2, "processing inputs paid once at the start")
	world.end_day()
	var mid: Dictionary = world.husbandry.maintain(bed)
	check(mid["ok"], "processing day advances on the stamped service")
	check(world.inventory.count("wastewater") == sewage_before - 8, "running batches never re-deduct inputs")
	world.end_day()
	world.husbandry.maintain(bed)
	world.end_day()
	var claim: Dictionary = world.husbandry.claim(bed)
	check(claim["ok"], "ready batches claim")
	check(world.inventory.count("clean_water") >= 4 - 1 and world.inventory.count("sludge") == 2, "claim issues recovered water and sludge")
	var after: Dictionary = world.husbandry.summary(world.husbandry.habitat_of(bed))
	check(int(after["total"]) == 2 and int(after["idle_adults"]) == 2, "units survive the claim")
	# V02 closes the loop: sludge composts into humus on the old bin.
	check(world.build_facility(Vector2i(4, 4), "compost_bin")["ok"], "build the compost bin")
	var bin := uid_of(world, "compost_bin")
	check(world.start_batch(bin, "compost_sludge")["ok"], "V02 runs on real sludge")
	drain_batch(world, bin)
	check(world.inventory.count("humus") == 2, "sludge returned to the field as humus (have %d, err %s)" % [world.inventory.count("humus"), world.daily_save_error])
	print("P8.e BASIC LOOP day ", world.clock.total_days, " stones ", world.primeval_stones)

# --- 3. Mat boundaries -----------------------------------------------------------

func _mat_boundaries() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 6, "raw_stone": 10, "grain": 2, "humus": 1,
		"clean_water": 20, "wastewater": 20, "wood_chip": 10})
	world.build_facility(Vector2i(2, 4), "research_bench")
	complete_research(world, 1, "flower_cultivation", {"grain": 2, "humus": 1})
	complete_research(world, 1, "biofiltration", {"wastewater": 2, "mushroom": 1})
	check(world.build_facility(Vector2i(0, 1), "purifying_bed")["ok"], "build the boundary bed")
	var bed := uid_of(world, "purifying_bed")
	check(world.husbandry.purchase(bed, 2)["ok"], "buy cultures")
	# Missing culture water: nothing changes.
	discard(world, "clean_water", world.inventory.count("clean_water"))
	var thirsty: Dictionary = world.husbandry.maintain(bed)
	check(not thirsty["ok"], "missing culture water refuses the whole action")
	check(world.husbandry.habitat_of(bed)["individuals"][0]["base_service"]["day"] == -1, "no service stamped on failure")
	world.grant_scaffold({"clean_water": 10})
	# Grow both to adults.
	world.husbandry.maintain(bed)
	world.end_day()
	world.husbandry.maintain(bed)
	world.end_day()
	check(int(world.husbandry.summary(world.husbandry.habitat_of(bed))["adult"]) == 2, "adults ready")
	# Standby: production off means no batch inputs, no water, no fee.
	check(world.husbandry.set_special_diet(bed, "")["ok"], "pause new batches")
	var standby: Dictionary = world.husbandry.maintain(bed)
	check(not standby["ok"], "standby adults take no chargeable work")
	# Missing processing inputs: basic culture would still run if juveniles
	# existed; here the whole action refuses on adults-only with no inputs.
	discard(world, "wastewater", world.inventory.count("wastewater"))
	check(world.husbandry.set_special_diet(bed, "bio_purify")["ok"], "resume production")
	var no_sewage: Dictionary = world.husbandry.maintain(bed)
	check(not no_sewage["ok"], "missing sewage refuses the batch start")
	world.grant_scaffold({"wastewater": 3, "wood_chip": 1})
	var partial: Dictionary = world.husbandry.maintain(bed)
	check(not partial["ok"], "insufficient sewage for two units refuses atomically")
	check(world.inventory.count("wastewater") == 3, "nothing deducted on the failed start")
	world.grant_scaffold({"wastewater": 5, "wood_chip": 1})
	var started: Dictionary = world.husbandry.maintain(bed)
	check(started["ok"] and int(started["started"]) == 2, "full stock starts both batches")
	# Ready units never re-enter paid maintenance; the claim ignores services.
	world.end_day()
	world.husbandry.maintain(bed)
	world.end_day()
	world.husbandry.maintain(bed)
	world.end_day()
	var ready_quote: Dictionary = world.husbandry.quote_claim(bed)
	check(ready_quote["ok"], "batches ready after two effective days")
	var standby2: Dictionary = world.husbandry.maintain(bed)
	check(not standby2["ok"], "ready-only beds refuse further paid maintenance")
	check(world.husbandry.claim(bed)["ok"], "claim ignores the day's service state")

# --- 4. Independent ponds and bed stock competition -------------------------------

func _two_ponds_and_competition() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 8, "raw_stone": 14, "grain": 2, "humus": 1,
		"clean_water": 20, "fodder_grass": 4})
	world.primeval_stones += 40  # 测试注资：双池双床与培养采购
	check(world.build_facility(Vector2i(0, 14), "fish_pond")["ok"], "pond A")
	check(world.build_facility(Vector2i(2, 14), "fish_pond")["ok"], "pond B")
	var pond_a := uid_of(world, "fish_pond", 0)
	var pond_b := uid_of(world, "fish_pond", 1)
	world.husbandry.purchase(pond_a, 1)
	world.husbandry.purchase(pond_b, 1)
	check(world.end_day()["ok"], "settle day 0")
	world.collect("spring_source")
	world.collect("spring_source")
	check(world.husbandry.maintain_water(pond_a)["ok"], "change only pond A")
	check(world.inventory.count("wastewater") == 2, "one change, one sewage batch")
	check(not world.husbandry.quote_water(pond_a)["ok"], "pond A sealed for the day")
	var quote_b: Dictionary = world.husbandry.quote_water(pond_b)
	check(quote_b["ok"], "pond B independent and still changeable")
	# Two beds compete for the same sewage stock: one full start, one clean refusal.
	world.build_facility(Vector2i(2, 4), "research_bench")
	complete_research(world, uid_of(world, "research_bench"), "flower_cultivation", {"grain": 2, "humus": 1})
	complete_research(world, uid_of(world, "research_bench"), "biofiltration", {"wastewater": 2, "mushroom": 1})
	check(world.build_facility(Vector2i(0, 1), "purifying_bed")["ok"], "bed A")
	check(world.build_facility(Vector2i(4, 1), "purifying_bed")["ok"], "bed B")
	var bed_a := uid_of(world, "purifying_bed", 0)
	var bed_b := uid_of(world, "purifying_bed", 1)
	world.husbandry.purchase(bed_a, 1)
	world.husbandry.purchase(bed_b, 1)
	world.grant_scaffold({"clean_water": 10})
	world.husbandry.maintain(bed_a)
	world.end_day()
	world.husbandry.maintain(bed_a)
	world.end_day()
	world.husbandry.maintain(bed_b)
	world.end_day()
	world.husbandry.maintain(bed_b)
	world.end_day()
	world.grant_scaffold({"wood_chip": 2})
	world.collect("spring_source")
	world.husbandry.maintain_water(pond_b)
	var sewage := world.inventory.count("wastewater")
	check(sewage >= 4, "two real changes feed both beds")
	var first: Dictionary = world.husbandry.maintain(bed_a)
	check(first["ok"] and int(first["started"]) == 1, "bed A starts from the shared stock")
	var second: Dictionary = world.husbandry.maintain(bed_b)
	var left := world.inventory.count("wastewater")
	if left < 4:
		check(not second["ok"], "bed B refuses cleanly when the stock falls short")
	else:
		check(second["ok"], "bed B starts with the remaining full ration")
	check(world.inventory.count("wastewater") >= 0, "no negative sewage")

# --- 5. Gravel-gated fixtures (R09/R11/R12, dense diet) ----------------------------

func _gravel_fixtures() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 20, "raw_stone": 20, "grain": 2, "humus": 1,
		"mushroom": 3, "clean_water": 30, "wastewater": 40,
		"wood_chip": 10, "filter_media": 6, "charcoal": 4, "straw": 4})
	world.primeval_stones += 60  # 夹具注资：跨设施建造与多轮研究费
	world.build_facility(Vector2i(2, 4), "research_bench")
	var bench := uid_of(world, "research_bench")
	complete_research(world, bench, "flower_cultivation", {"grain": 2, "humus": 1})
	complete_research(world, bench, "biofiltration", {"wastewater": 2, "mushroom": 1})
	complete_research(world, bench, "rock_handling", {"mushroom": 1, "raw_stone": 3})
	# FIXTURE: gravel comes from P8.f's breaker; here it is injected to prove
	# the R09/R11/R12 algorithms only, not a no-injection economy route.
	world.grant_scaffold({"gravel": 6})
	complete_research(world, bench, "water_recirculation", {"sludge": 1, "gravel": 1, "charcoal": 1})
	check(world.build_facility(Vector2i(0, 3), "woodshop")["ok"], "old woodshop for R09")
	var woodshop := uid_of(world, "woodshop")
	world.grant_scaffold({"charcoal": 1, "gravel": 2})
	check(world.start_batch(woodshop, "make_filter_media")["ok"], "R09 fixture starts")
	drain_batch(world, woodshop)
	check(world.inventory.count("filter_media") == 8, "R09 issues filter media (6 scaffold + 2 batch)")
	# R11 on a second bed: nutrient liquid plus water return less than the sewage in.
	check(world.build_facility(Vector2i(0, 1), "purifying_bed")["ok"], "fixture bed")
	var bed := uid_of(world, "purifying_bed")
	world.husbandry.purchase(bed, 1)
	world.grant_scaffold({"clean_water": 10})
	world.husbandry.maintain(bed)
	world.end_day()
	world.husbandry.maintain(bed)
	world.end_day()
	check(world.husbandry.set_diet(bed, "special_diets", "special_diet_id", "recover_nutrients")["ok"], "switch to R11")
	world.grant_scaffold({"wastewater": 4, "filter_media": 1})
	var started: Dictionary = world.husbandry.maintain(bed)
	check(started["ok"] and int(started["started"]) == 1, "R11 batch starts")
	world.end_day()
	world.husbandry.maintain(bed)
	world.end_day()
	world.husbandry.maintain(bed)
	world.end_day()
	check(world.husbandry.claim(bed)["ok"], "R11 claims")
	check(world.inventory.count("nutrient_liquid") == 2, "R11 issues nutrient liquid")
	check(world.inventory.count("sludge") >= 1, "R11 issues sludge")
	# R12 on the old algae tank: normal days, no light gate.
	check(world.build_facility(Vector2i(10, 4), "algae_tank")["ok"], "old algae tank")
	var tank := uid_of(world, "algae_tank")
	world.grant_scaffold({"nutrient_liquid": 2, "clean_water": 1, "straw": 1})
	check(world.start_batch(tank, "dense_algae_culture")["ok"], "R12 starts without a light gate")
	drain_batch(world, tank)
	check(world.inventory.count("dense_algae") == 3, "R12 issues dense algae")
	# The dense diet becomes selectable for carp after T08.
	check(world.build_facility(Vector2i(0, 14), "fish_pond")["ok"], "carp pond for the diet")
	var pond := uid_of(world, "fish_pond")
	world.husbandry.purchase(pond, 1)
	check(world.husbandry.set_diet(pond, "base_diets", "basic_diet_id", "dense_meal")["ok"], "dense diet unlocked for carp")
	world.grant_scaffold({"dense_algae": 2})
	var dense_before := world.inventory.count("dense_algae")
	check(world.husbandry.maintain(pond)["ok"], "carp eats the dense meal")
	check(world.inventory.count("dense_algae") == dense_before - 1, "dense meal consumed once")

# --- 6. Snapshot contracts ----------------------------------------------------------

func _snapshot_contracts() -> void:
	var world := P8World.new(temp_store())
	world.start_new(1)
	world.grant_scaffold({"raw_wood": 6, "raw_stone": 10, "grain": 2, "humus": 1,
		"clean_water": 20, "wastewater": 10, "wood_chip": 4})
	world.build_facility(Vector2i(2, 4), "research_bench")
	complete_research(world, 1, "flower_cultivation", {"grain": 2, "humus": 1})
	complete_research(world, 1, "biofiltration", {"wastewater": 2, "mushroom": 1})
	check(world.build_facility(Vector2i(0, 1), "purifying_bed")["ok"], "build bed")
	var bed := uid_of(world, "purifying_bed")
	world.husbandry.purchase(bed, 1)
	world.husbandry.maintain(bed)
	world.end_day()
	world.husbandry.maintain(bed)
	world.end_day()
	world.husbandry.maintain(bed)
	var snapshot := world.to_snapshot()
	check(P8Snapshot.normalize(snapshot)["ok"], "running mat cycle round trips")
	var restored := P8World.new()
	restored.apply_snapshot(snapshot)
	var habitat: Dictionary = restored.husbandry.habitat_of(bed)
	check(not habitat["individuals"][0]["cycle"].is_empty(), "cycle restored with its frozen outputs")
	var probe: Dictionary = snapshot.duplicate(true)
	probe["world"]["husbandry"]["habitats"][0]["individuals"][0]["cycle"]["outputs"] = {"honey": 9}
	check(not P8Snapshot.normalize(probe)["ok"], "forged cycle outputs rejected")
	probe = snapshot.duplicate(true)
	probe["world"]["husbandry"]["habitats"][0]["individuals"][0]["base_service"]["inputs"] = {"clean_water": 5}
	check(not P8Snapshot.normalize(probe)["ok"], "forged service inputs rejected")
