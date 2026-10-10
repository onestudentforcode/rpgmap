extends SceneTree
const World := preload("res://scripts/farming/v1/v1_world.gd")
const Snapshot := preload("res://scripts/farming/v1/v1_snapshot.gd")
const Data := preload("res://scripts/farming/v1/v1_data.gd")
const Orders := preload("res://scripts/farming/v1/v1_orders.gd")
const Store := preload("res://scripts/farming/v1/v1_slot_store.gd")
const Workforce := preload("res://scripts/farming/v1/v1_workforce.gd")
var failures: Array[String] = []
var checks := 0

class FlakyStore extends "res://scripts/farming/v1/v1_slot_store.gd":
	var fail_write := false
	func _rename(from: String, to: String) -> Error:
		return ERR_CANT_CREATE if fail_write and from.ends_with(".tmp") else super._rename(from, to)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func unchanged(world: World, action: Callable, label: String) -> void:
	var before := world.to_snapshot()
	check(not action.call()["ok"] and world.to_snapshot() == before, label)

func days(world: World, count: int) -> void:
	for _index in range(count):
		world.end_day()

func fixture(day: int, revenue: int) -> World:
	# Explicit order/rank fixtures; the end-to-end production test never injects items.
	var snapshot := Snapshot.fresh()
	snapshot["clock"]["total_days"] = day
	snapshot["world"]["sources"]["day"] = day
	snapshot["workforce"] = Workforce.fresh(day)
	snapshot["economy"]["sales_revenue"] = revenue
	snapshot["orders"] = Orders.generate(day, revenue)
	var world := World.new()
	check(world.apply_snapshot(snapshot)["ok"], "rank fixture valid")
	return world

func _initialize() -> void:
	_templates()
	_delivery()
	_market()
	_validation()
	_storage()
	_closed_loop()
	for failure in failures:
		printerr(failure)
	print("V1 ORDERS TEST %s: %d checks" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _templates() -> void:
	var seen := {}
	var ids := {}
	for day in range(10):
		var generated := Orders.generate(day, 0)
		check(generated == Orders.generate(day, 0) and generated["entries"].size() == 3, "deterministic three orders daily")
		for entry in generated["entries"]:
			check(not ids.has(entry["id"]) and entry["rank"] == 1 and entry["demand"] == 12, "unique daily ID and initial rank")
			ids[entry["id"]] = true
			seen[entry["path"]] = true
	check(seen.size() == 5, "five paths in rotation")
	var ranks := {}
	for day in range(5):
		var entries: Array = Orders.generate(day, 1200)["entries"]
		check(entries[0]["rank"] == 1, "low rank remains available")
		for entry in entries:
			ranks[entry["rank"]] = true
	check(ranks.size() == 5, "all unlocked ranks participate instead of highest only")
	for rank in [1,3,5]:
		for entry in Orders.generate(0, 0, rank)["entries"]:
			check(entry["rank"] == rank and entry["demand"] == 12 * rank, "pure test override1/3/5")
	check(Orders.generate(-1, 0).is_empty() and Orders.generate(0, 0, 6).is_empty(), "invalid generator arguments")
	var world := World.new()
	var original := world.daily_orders()
	var exposed := world.daily_orders()
	exposed[0]["rank"] = 5
	check(world.daily_orders() == original, "order query detached")
	check(Data.demand_quote("wood", 3, 20, "grain")["quantity"] == 5, "independent explicit consumer demand adapter")
	check(not Data.demand_quote("wood", 3, 0, "grain")["ok"], "reject zero external demand")
	world.end_day()
	check(world.gross_revenue() == 0 and world.primeval_stones == 60 and world.daily_orders() != original, "unfulfilled refresh without penalties")

func _delivery() -> void:
	var foods := {"wood": "grain", "fire": "resin", "earth": "humus", "water": "clean_water", "gold": "iron_ingot"}
	var expected := {"grain": [3,9,15], "resin": [2,5,8], "humus": [3,9,15], "clean_water": [12,36,60], "iron_ingot": [2,4,6]}
	for cap in [1,3,5]:
		var revenue: int = {1: 0, 3: 300, 5: 1200}[cap]
		var found := {}
		for day in range(30):
			var world := fixture(day, revenue)
			for entry in world.daily_orders():
				if entry["rank"] != cap or found.has(entry["path"]):
					continue
				found[entry["path"]] = true
				var item: String = foods[entry["path"]]
				var quote := world.order_quote(entry["id"], item)
				check(quote["quantity"] == expected[item][[1,3,5].find(cap)], "independent necessary count " + item)
				unchanged(world, func(): return world.deliver_order(entry["id"], item), "insufficient materials zero change")
				world.inventory.add(item, int(quote["quantity"]) + 7)
				var balance := world.primeval_stones
				var ap := world.clock.ap
				var prior_revenue := world.gross_revenue()
				check(world.deliver_order(entry["id"], item)["ok"], "qualified delivery " + item)
				check(world.inventory.count(item) == 7 and world.primeval_stones == balance + int(quote["payout"]) and world.gross_revenue() == prior_revenue + int(quote["payout"]), "necessary units and once revenue")
				check(world.clock.ap == ap and world.daily_orders().size() == 3, "delivery no AP or replacement orders")
				unchanged(world, func(): return world.deliver_order(entry["id"], item), "duplicate delivery zero change")
				var restored := World.new()
				check(restored.apply_snapshot(JSON.parse_string(JSON.stringify(world.to_snapshot())))["ok"] and restored.to_snapshot() == world.to_snapshot(), "receipt and income roundtrip")
				unchanged(restored, func(): return restored.deliver_order(entry["id"], item), "reload cannot repeat paid delivery")
		check(found.size() == 5, "five paths tested at rank%d" % cap)
	var world := World.new()
	unchanged(world, func(): return world.deliver_order(1, "raw_wood"), "element alone not food eligibility")
	unchanged(world, func(): return world.deliver_order(1, "resin"), "wrong element rejected")
	unchanged(world, func(): return world.deliver_order(999, "grain"), "unknown ID rejected")
	world.end_day()
	unchanged(world, func(): return world.deliver_order(1, "grain"), "expired ID cannot settle a new day")

func _market() -> void:
	var world := World.new()
	for quantity in [0, -1, true, "1", 1.5, 1000001]:
		unchanged(world, func(): return world.buy("grain", quantity), "bad buy quantity")
		unchanged(world, func(): return world.sell("grain", quantity), "bad sell quantity")
	unchanged(world, func(): return world.buy("iron_ingot", 1), "produced ingots not sold by market")
	unchanged(world, func(): return world.buy("unknown", 1), "unknown market item")
	unchanged(world, func(): return world.sell("golden_wheat_seed", 1), "zero-price seeds not sellable")
	unchanged(world, func(): return world.buy("fast_fir_seed", 8), "cannot overspend")
	unchanged(world, func(): return world.sell("grain", 1), "cannot sell missing inventory")
	check(world.buy("grain", 3)["ok"] and world.primeval_stones == 42 and world.gross_revenue() == 0, "purchase not income")
	check(world.deliver_order(1, "grain")["ok"] and world.primeval_stones == 55 and world.gross_revenue() == 13, "purchased food allowed with loss rather than arbitrage")
	world.inventory.add("grain", 30)
	var original := world.daily_orders()
	check(world.sell("grain", 30)["ok"] and world.gross_revenue() == 133 and world.unlocked_rank() == 2, "sale revenue unlocks rank")
	check(world.daily_orders() == original, "midday unlock does not reroll orders")
	check(world.buy("resin_tree_seed", 10)["ok"] and world.unlocked_rank() == 2, "spending never demotes rank")
	check(world.clock.ap == 24 and world.clock.total_days == 0, "trading free AP and no manual save")
	world.end_day()
	check(world.to_snapshot()["orders"]["issued_revenue"] == 133, "next day captures new revenue")
	for threshold in [0,120,300,650,1200]:
		var rank: int = [0,120,300,650,1200].find(threshold) + 1
		check(Data.unlocked_rank(threshold) == rank and (threshold == 0 or Data.unlocked_rank(threshold-1) == rank-1), "exact unlock threshold")

func _validation() -> void:
	var world := World.new()
	world.buy("grain", 3)
	world.deliver_order(1, "grain")
	var before := world.to_snapshot()
	for mutate in [
		func(s): s["orders"]["day"] = 1,
		func(s): s["orders"]["issued_revenue"] = 120,
		func(s): s["orders"]["entries"].pop_back(),
		func(s): s["orders"]["entries"][1]["id"] = 1,
		func(s): s["orders"]["entries"][1]["path"] = "wood",
		func(s): s["orders"]["entries"][1]["rank"] = 5,
		func(s): s["orders"]["entries"][1]["demand"] = 13,
		func(s): s["orders"]["entries"][1]["receipt"] = {"item_id": "iron_ingot"},
		func(s): s["orders"]["entries"][0]["status"] = "open",
		func(s): s["orders"]["entries"][0]["receipt"]["item_id"] = "raw_wood",
		func(s): s["orders"]["entries"][0]["receipt"]["quantity"] = 4,
		func(s): s["orders"]["entries"][0]["receipt"]["provided"] = true,
		func(s): s["orders"]["entries"][0]["receipt"]["premium"] = 2,
		func(s): s["orders"]["entries"][0]["receipt"]["payout"] = 99,
		func(s): s["economy"]["order_revenue"] = 12,
		func(s): s["economy"]["sales_revenue"] = -1,
		func(s): s["economy"]["sales_revenue"] = true,
		func(s): s["orders"]["unknown"] = 1,
		func(s): s.erase("orders")]:
		var bad := before.duplicate(true)
		mutate.call(bad)
		check(not world.apply_snapshot(bad)["ok"] and world.to_snapshot() == before, "reject malformed order/economy atomically")
	for schema in [1,2,3]:
		var old := before.duplicate(true)
		old["schema"] = schema
		old.erase("orders")
		old.erase("workforce")
		old["economy"] = {"primeval_stones": 55}
		if schema == 1:
			old.erase("world")
		elif schema == 2:
			for key in ["facilities", "next_facility_uid", "next_batch_uid"]:
				old["world"].erase(key)
		var upgraded := Snapshot.normalize(old)
		check(upgraded["ok"] and upgraded["snapshot"]["economy"]["primeval_stones"] == 55 and upgraded["snapshot"]["economy"]["order_revenue"] == 0 and upgraded["snapshot"]["orders"] == Orders.generate(0, 0), "old V1 schema upgrades without invented revenue")
		old["orders"] = {}
		check(not Snapshot.normalize(old)["ok"], "old schema cannot conceal new order state")
	world.end_day()
	var archived := world.to_snapshot()
	check(world.order_settlements().size() == 1 and world.order_settlements()[0]["entry"]["receipt"]["payout"] == 13, "daily refresh preserves actual historical delivery and payout")
	var exposed := world.order_settlements()
	exposed[0]["entry"]["receipt"]["payout"] = 100
	check(world.order_settlements()[0]["entry"]["receipt"]["payout"] == 13, "historical query detached")
	for mutate in [
		func(s): s["orders"]["settlements"] = [],
		func(s): s["orders"]["issued_revenue"] = 0,
		func(s): s["orders"]["settlements"].append(s["orders"]["settlements"][0].duplicate(true)),
		func(s): s["orders"]["settlements"][0]["entry"]["id"] = 4,
		func(s): s["orders"]["settlements"][0]["entry"]["status"] = "open",
		func(s): s["orders"]["settlements"][0]["entry"]["receipt"]["payout"] = 14,
		func(s): s["orders"]["settlements"][0]["issued_revenue"] = true,
		func(s): s["economy"]["order_revenue"] = 14]:
		var bad := archived.duplicate(true)
		mutate.call(bad)
		check(not world.apply_snapshot(bad)["ok"] and world.to_snapshot() == archived, "corrupt missing or duplicated historical receipts rejected")
	var restored := World.new()
	check(restored.apply_snapshot(JSON.parse_string(JSON.stringify(archived)))["ok"] and restored.to_snapshot() == archived, "archived receipts JSON roundtrip")

func _storage() -> void:
	var directory := "user://test_v1_orders_%d" % Time.get_ticks_usec()
	var store := FlakyStore.new(directory)
	var world := World.new(store)
	unchanged(world, func(): return world.buy("grain", 3), "unbound economy blocked")
	world.start_new(1)
	var start := world.to_snapshot()
	world.buy("grain", 3)
	world.deliver_order(1, "grain")
	check(store.read_slot(1)["snapshot"] == start, "no manual saves from trading/delivery")
	check(world.abandon_day()["ok"] and world.to_snapshot() == start, "abandon restores orders inventory money income together")
	world.buy("grain", 3)
	world.deliver_order(1, "grain")
	world.clock.ap = 1
	check(world.collect("spring_source")["saved"] and store.read_slot(1)["snapshot"] == world.to_snapshot(), "last AP saves income refreshed orders and resource quota together")
	check(world.open_game(1)["ok"] and world.gross_revenue() == 13, "income retained on reload")
	check(world.order_settlements().size() == 1 and world.order_settlements()[0]["entry"]["id"] == 1, "committed historical receipt retained on reload")
	unchanged(world, func(): return world.deliver_order(1, "grain"), "prior day receipt cannot replay after reload")
	world.start_new(2)
	check(world.gross_revenue() == 0 and world.primeval_stones == 60, "slot2 separate income and orders")
	check(world.buy("raw_wood", 3)["ok"] and world.buy("raw_stone", 2)["ok"] and world.buy("grain", 3)["ok"] and world.deliver_order(1, "grain")["ok"], "joint day funds and delivers")
	world.till(Vector2i(2,2))
	world.plant(Vector2i(2,2), "golden_wheat")
	var facility := world.build_facility(Vector2i(5,2), "woodshop")
	world.collect("ore_source")
	world.clock.ap = 1
	var started := world.start_batch(facility["facility_uid"], "shred_wood")
	var combined := world.to_snapshot()
	check(started["saved"] and store.read_slot(2)["snapshot"] == combined, "crop processing orders revenue and quota commit in one last AP snapshot")
	check(combined["world"]["crops"][0]["progress"] == 100 and combined["world"]["facilities"][0]["batch"]["status"] == "ready" and combined["world"]["sources"]["used"]["ore_source"] == 0 and combined["orders"]["day"] == 1 and combined["orders"]["settlements"].size() == 1, "full daily settlement order before save")
	world.start_new(3)
	world.buy("grain", 3)
	world.deliver_order(1, "grain")
	var prior: Dictionary = store.read_slot(3)["snapshot"]
	store.fail_write = true
	check(not world.end_day()["saved"] and store.read_slot(3)["snapshot"] == prior, "failed write keeps prior economic state")
	var pending := world.to_snapshot()
	unchanged(world, func(): return world.buy("grain", 1), "save failure blocks purchase")
	unchanged(world, func(): return world.sell("clean_water", 1), "save failure blocks sale")
	unchanged(world, func(): return world.deliver_order(4, "resin"), "save failure blocks delivery")
	store.fail_write = false
	check(world.retry_day_save()["ok"] and world.to_snapshot() == pending and store.read_slot(3)["snapshot"] == pending, "retry keeps income and same order IDs without replay")
	check(store.read_slot(1)["snapshot"]["economy"]["primeval_stones"] == 55 and store.read_slot(2)["snapshot"]["economy"]["primeval_stones"] == 23 and store.read_slot(3)["snapshot"]["economy"]["primeval_stones"] == 55, "three slots stay isolated")
	for slot in [1,2,3]:
		check(store.delete_slot(slot, true)["ok"], "cleanup owned order slot")
	DirAccess.remove_absolute(directory)

func prepare(world: World, cell: Vector2i, crop_id: String) -> void:
	var shape: Array = world.crop_defs[crop_id]["footprint"]
	for y in range(int(shape[1])):
		for x in range(int(shape[0])):
			check(world.till(cell+Vector2i(x,y))["ok"], "closed loop prepare " + crop_id)
	check(world.plant(cell, crop_id)["ok"], "closed loop plant " + crop_id)

func _closed_loop() -> void:
	# All money/items come from initial60, seeds, real sources/crops and recipes.
	var world := World.new()
	prepare(world, Vector2i(5,2), "fast_fir")
	prepare(world, Vector2i(8,2), "fast_fir")
	prepare(world, Vector2i(2,2), "golden_wheat")
	prepare(world, Vector2i(11,2), "resin_tree")
	for _index in range(6):
		check(world.collect("stone_source")["ok"], "closed loop stone")
	for _index in range(3):
		check(world.collect("spring_source")["ok"] and world.collect("ore_source")["ok"], "closed loop water/ore")
	days(world, 8)
	check(world.harvest(Vector2i(5,2), "fell")["ok"] and world.harvest(Vector2i(8,2), "fell")["ok"] and world.harvest(Vector2i(2,2))["ok"] and world.harvest(Vector2i(11,2))["ok"], "closed loop harvest")
	var wood := world.build_facility(Vector2i(1,0), "woodshop")
	var compost := world.build_facility(Vector2i(0,5), "compost_bin")
	var kiln := world.build_facility(Vector2i(1,3), "char_kiln")
	check(wood["ok"] and compost["ok"] and kiln["ok"], "closed loop facilities")
	var saw := world.start_batch(wood["facility_uid"], "saw_planks")
	var soil := world.start_batch(compost["facility_uid"], "compost_straw")
	var coal := world.start_batch(kiln["facility_uid"], "char_twigs")
	days(world, 1)
	check(world.claim_batch(wood["facility_uid"], saw["batch_id"])["ok"], "closed loop planks")
	var smelter := world.build_facility(Vector2i(15,0), "smelter")
	var chips := world.start_batch(wood["facility_uid"], "shred_wood")
	days(world, 1)
	check(smelter["ok"] and world.claim_batch(wood["facility_uid"], chips["batch_id"])["ok"] and world.claim_batch(compost["facility_uid"], soil["batch_id"])["ok"] and world.claim_batch(kiln["facility_uid"], coal["batch_id"])["ok"], "closed loop supplies")
	prepare(world, Vector2i(2,10), "wood_decay_mushroom")
	var extra_soil := world.start_batch(compost["facility_uid"], "compost_twigs")
	var first := world.start_batch(smelter["facility_uid"], "smelt_charcoal")
	days(world, 2)
	check(world.claim_batch(smelter["facility_uid"], first["batch_id"])["ok"] and world.claim_batch(compost["facility_uid"], extra_soil["batch_id"])["ok"], "closed loop first ingot and extra soil")
	var second := world.start_batch(smelter["facility_uid"], "smelt_charcoal")
	days(world, 2)
	check(world.claim_batch(smelter["facility_uid"], second["batch_id"])["ok"] and world.harvest(Vector2i(2,10))["ok"], "closed loop second ingot and mushroom/humus")
	var supplied := {}
	var foods := {"wood": "grain", "fire": "resin", "earth": "humus", "water": "clean_water", "gold": "iron_ingot"}
	for _day in range(5):
		for entry in world.daily_orders():
			if not supplied.has(entry["path"]):
				var quote := world.order_quote(entry["id"], foods[entry["path"]])
				if world.inventory.has(foods[entry["path"]], int(quote["quantity"])):
					check(world.deliver_order(entry["id"], foods[entry["path"]])["ok"], "self produced delivery " + entry["path"])
					supplied[entry["path"]] = true
		world.end_day()
	check(supplied.size() == 5 and world.gross_revenue() == 78 and world.primeval_stones == 92, "five self produced foods supply orders, capital reinvested")
	check(world.fertilize(Vector2i(2,2))["ok"] and world.inventory.count("humus") == 1, "remaining humus reflows after order supply")
	check(world.sell("mushroom", 3)["ok"] and world.gross_revenue() == 96, "surplus sold alongside orders")
	check(world.buy("golden_wheat_seed", 2)["ok"] and world.primeval_stones == 104 and world.plant(Vector2i(2,2), "golden_wheat")["ok"], "earned currency purchases next crop inputs")
	check(Snapshot.normalize(world.to_snapshot())["ok"], "production delivery sale reinvestment full snapshot valid")
