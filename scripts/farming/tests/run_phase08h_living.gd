extends SceneTree
## Isolated boundary fixtures; normal business evidence is produced by the playtest.
const World := preload("res://scripts/farming/p8/p8_world.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const Snapshot := preload("res://scripts/farming/p8/p8_snapshot.gd")
const CropFixture := preload("res://scripts/farming/tests/p8_crop_fixture.gd")
var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func fresh():
	var world := World.new(Store.new("res://.art-work/p8h-unit/living_%d" % Time.get_ticks_usec()))
	check(world.start_new(1)["ok"], "isolated slot")
	world.grant_scaffold({"raw_wood": 40, "raw_stone": 40, "wood_plank": 10, "clean_water": 80,
		"mushroom": 40, "iron_ore": 20, "fodder_grass": 40, "wood_chip": 20, "wastewater": 40})
	world.primeval_stones += 500
	for project in world.data_source.load_data()["research"]:
		world.research.state["completed"].append(String(project["id"]))
	return world

func stock(world, item: String, count: int) -> void:
	var have: int = world.inventory.count(item)
	if have > count:
		world.inventory.remove(item, have - count)
		world._record_flow({}, {item: have - count}, "隔离测试调整")
	elif count > have: world.grant_scaffold({item: count - have})

func habitat(world, cell: Vector2i, type: String, species: String, count: int = 4, adult: bool = true) -> int:
	var built: Dictionary = world.build_facility(cell, type)
	check(built["ok"], "build " + type)
	var uid := int(built.get("facility_uid", 0))
	world.husbandry.ensure(uid)
	check(world.husbandry.purchase(uid, count)["ok"], "purchase units")
	if adult:
		for unit in world.husbandry.habitat_of(uid)["individuals"]:
			unit["stage"] = "adult"
			unit["growth"] = int(world.husbandry.species_def(species)["growth_days"]) * 100
	return uid

func owner(world, uids: Array) -> void:
	var hired: Dictionary = world.workforce.hire("经营负责人")
	check(hired["ok"], "hire")
	for uid in uids: check(world.operations.assign_owner(int(uid), int(hired["worker_id"]))["ok"], "bind")

func _initialize() -> void:
	_diet_facility_guard()
	_target_and_reserve()
	_mixed_units_and_stop()
	_shared_target()
	_bees_and_manual_override()
	for failure in failures: printerr(failure)
	print("PHASE08H LIVING %s · %d checks" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _target_and_reserve() -> void:
	# The three terrestrial species left the living-strategy path in P10.3; the
	# purifying mat carries the same target/reserve/wage semantics.
	var world = fresh()
	var bed := habitat(world, Vector2i(0, 1), "purifying_bed", "purifying_mat", 3)
	owner(world, [bed])
	stock(world, "wastewater", 20)
	stock(world, "clean_water", 0)
	check(world.operations.set_production(bed, true, "bio_purify", "clean_water", 3)["ok"], "living target accepted")
	check(world.operations.set_reserve("wastewater", 17)["ok"], "input reserve")
	var before: int = world.primeval_stones
	world.end_day()
	check(world.workforce.state["spent"] == 0 and world.primeval_stones == before, "blocked idle units take no wage")
	check(world.inventory.count("wastewater") == 20, "reserve blocks all new inputs")
	world.operations.set_reserve("wastewater", 12)
	world.end_day()
	check(world.inventory.count("wastewater") == 12, "only two units start for a three-unit target")
	check(world.operations.effective_stock("clean_water") == 4 and world.inventory.count("clean_water") == 0, "running or ready output counts once, never as real stock")
	check(world.workforce.state["spent"] == 1, "whole-facility start charged once")
	world.end_day()
	world.end_day()
	check(world.inventory.count("clean_water") == 4 and world.inventory.count("wastewater") == 12, "claim meets target without restarting")
	check(world.workforce.state["spent"] == 3, "start, advance and claim each charged once")
	world.end_day()
	check(world.workforce.state["spent"] == 3, "target satisfied costs no idle wage")
	var snapshot: Dictionary = world.to_snapshot()
	check(Snapshot.normalize(snapshot)["ok"], "living strategy normalizes")
	var restored := World.new()
	check(restored.apply_snapshot(snapshot)["ok"] and restored.operations.strategy_of(bed)["target_qty"] == 3, "strategy restore")
	var tampered: Dictionary = snapshot.duplicate(true)
	tampered["world"]["p8"]["production"][0]["recipe_id"] = "honey_cycle"
	check(not Snapshot.normalize(tampered)["ok"], "foreign species recipe rejected on load")
	check(world.husbandry.set_special_diet(bed, "recover_nutrients")["ok"] and not world.operations.strategy_of(bed)["enabled"], "manual recipe switch stops obsolete strategy")
	stock(world, "clean_water", 20)
	stock(world, "wastewater", 20)
	stock(world, "filter_media", 4)
	check(world.husbandry.maintain(bed)["ok"], "manual care remains available beyond target")

func _mixed_units_and_stop() -> void:
	var world = fresh()
	var bed := habitat(world, Vector2i(0, 1), "purifying_bed", "purifying_mat", 3, false)
	var units: Array = world.husbandry.habitat_of(bed)["individuals"]
	units[0]["stage"] = "adult"
	units[0]["growth"] = 200
	owner(world, [bed])
	world.operations.set_production(bed, true, "bio_purify", "clean_water", world.inventory.count("clean_water") + 1)
	world.end_day()
	check(not units[0]["cycle"].is_empty() and units[1]["growth"] == 100 and units[2]["growth"] == 100, "mixed adults and juveniles served together")
	check(world.operations.effective_stock("clean_water") == world.inventory.count("clean_water") + 2, "running purifier output counted")
	world.operations.set_production(bed, false, "bio_purify", "clean_water", 1)
	var raw: int = world.inventory.count("wastewater")
	world.end_day()
	check(units[0]["cycle"]["status"] == "ready" and units[1]["stage"] == "adult", "disabled starts still finish paid cycles and juvenile growth")
	world.end_day()
	check(world.inventory.count("sludge") == 1 and world.inventory.count("wastewater") == raw, "automatic claim works with strategy disabled")
	world.end_day()
	check(world.workforce.state["spent"] == 3, "no charge for disabled idle mat units")

func _shared_target() -> void:
	var world = fresh()
	var first := habitat(world, Vector2i(0, 1), "purifying_bed", "purifying_mat", 2)
	var second := habitat(world, Vector2i(3, 1), "purifying_bed", "purifying_mat", 2)
	owner(world, [first, second])
	stock(world, "wastewater", 20)
	stock(world, "clean_water", 0)
	world.operations.set_reserve("wastewater", 12)
	world.operations.set_production(first, true, "bio_purify", "clean_water", 6)
	world.operations.set_production(second, true, "bio_purify", "clean_water", 6)
	world.end_day()
	check(world.operations.effective_stock("clean_water") == 4 and world.inventory.count("wastewater") == 12, "two living facilities share one effective target and reserve")
	check(world.workforce.state["spent"] == 1, "second facility cannot start redundant batches")

func _bees_and_manual_override() -> void:
	var world = fresh()
	world.grant_scaffold({"honeybell_seed": 4})
	var hive := habitat(world, Vector2i(7, 1), "bee_hive", "bell_bee")
	for cell in [Vector2i(9, 1), Vector2i(10, 1), Vector2i(9, 2), Vector2i(10, 2)]:
		world.till(cell)
		world.plant(cell, "honeybell_bush")
	for crop in world.crops.values():
		crop["state"] = "mature"
		CropFixture.progress(world,int(crop["uid"]),600)
	owner(world, [hive])
	check(world.operations.set_production(hive, true, "honey_cycle", "honey", 1)["ok"], "zero-input honey recipe accepted")
	world.flowers.hive_coverage(hive)
	var water: int = world.inventory.count("clean_water")
	world.end_day()
	check(world.inventory.count("clean_water") == water - 1, "target limits flower and water draws to one colony")
	check(world.operations.effective_stock("honey") == 2, "running honey counts toward global target")
	var rows: Array = world.husbandry.habitat_of(hive)["individuals"]
	check(rows.filter(func(unit): return not unit["cycle"].is_empty()).size() == 1, "three idle colonies remain unstarted")
	world.end_day()
	world.end_day()
	world.end_day()
	check(world.inventory.count("honey") == 2 and world.inventory.count("beeswax") == 1, "automatic honey claim")
	var fee: int = world.workforce.state["spent"]
	world.end_day()
	check(world.workforce.state["spent"] == fee, "idle bee target incurs no flower or wage consumption")
	check(Snapshot.normalize(world.to_snapshot())["ok"], "honey strategy survives normalization")

func _diet_facility_guard() -> void:
	var world = fresh()
	var built: Dictionary = world.build_facility(Vector2i(0, 1), "woodshop")
	check(built["ok"], "ordinary workshop fixture")
	var uid := int(built["facility_uid"])
	var before: Dictionary = world.to_snapshot()
	check(not world.husbandry.set_special_diet(uid, "saw_planks")["ok"], "ordinary recipe cannot be selected as an animal diet")
	check(not world.husbandry.set_special_diet(uid, "")["ok"], "no animal production switch on an ordinary workshop")
	check(world.to_snapshot() == before, "invalid habitat selection changes no state")
