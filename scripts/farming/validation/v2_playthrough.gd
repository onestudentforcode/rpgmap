extends RefCounted
## Deterministic player strategy. Only public gameplay transactions; no grants,
## state edits, favourable orders or clock skips. Also used by exported smoke.
const Snapshot := preload("res://scripts/farming/v2/v2_snapshot.gd")
const Journal := preload("res://scripts/farming/v1/v1_journal.gd")
var world
var route := "A"
var rows := []
var failures: Array[String] = []
var current: Dictionary
var loop_day := -1
var facilities := {}
var first_sale := false
var extra_sale := false
var first_sheep := false
var first_fish := false
var delegated_day := -1
var full_day := -1
var sheep_claims := 0
var fish_claims := 0
var full_sheep_claims := 0
var full_fish_claims := 0
var animal_income := 0
var reinvested := false
var supplied := {}
var composted := {}
var fertilized := {}
var compost_source := ""
var snapshots := {}
var output_prefix := ""

func run(game_world, strategy: String, prefix: String = "") -> Dictionary:
	world = game_world
	route = strategy
	output_prefix = prefix
	_begin()
	for item in (["fodder_grass","clean_water"] if route == "A" else ["algae_feed","grain","iron_ore","clean_water","fodder_grass","humus","steel_wool"]):
		_do("watch",{"item":item},func(): return world.toggle_watch(item))
	_do("buy", {"item":"grass_seed","quantity":4}, func(): return world.buy("grass_seed",4))
	for x in range(1,5): _plant(Vector2i(x,1),"pasture_grass")
	_plant(Vector2i(10,1),"fast_fir")
	_plant(Vector2i(13,1),"fast_fir")
	for x in range(1,4): _plant(Vector2i(x,2),"golden_wheat")
	for x in range(1,6): _plant(Vector2i(x,4),"golden_wheat")
	while world.clock.total_days < 45 and failures.is_empty():
		loop_day = world.clock.total_days
		_fields()
		if loop_day >= 2 and world.inventory.count("resin_tree_seed") > 0 and _can(5): _plant(Vector2i(12,7),"resin_tree")
		_stock("spring_source","clean_water",30)
		_market()
		_build_startup()
		_algae()
		_animals()
		if loop_day >= 17: _renew_fields()
		_expansion()
		_husbandry()
		_market()
		_compost()
		if _can(0): _do("end_day",{},func(): return world.end_day())
	loop_day = -1
	_validate()
	var frozen: Dictionary = world.reports.state["recap"].duplicate(true)
	var terms: Array = world.reports.state["terms"].duplicate(true)
	var end_state: Dictionary = world.to_snapshot()
	# Real reload, then one more ordinary day. This day is outside the 45-day rows.
	if world._store != null:
		var loaded: Dictionary = world.open_game(1)
		# JSON reload makes integral numbers floats. Compare serialized values,
		# not Variant numeric types, while preserving every key and array order.
		if not loaded["ok"] or JSON.parse_string(JSON.stringify(world.to_snapshot())) != JSON.parse_string(JSON.stringify(end_state)):
			failures.append("day45 reload mismatch")
			if not output_prefix.is_empty():
				for pair in [["before",end_state],["after",world.to_snapshot()]]:
					var file := FileAccess.open(output_prefix+"-reload-"+pair[0]+".json",FileAccess.WRITE)
					file.store_string(JSON.stringify(pair[1]))
	var continued: Dictionary = world.end_day()
	if not continued["ok"] or not world.daily_save_error.is_empty() or world.clock.total_days != 46 or frozen != world.reports.state["recap"] or terms != world.reports.state["terms"]:
		failures.append("day46 changed the frozen first45 report or failed to save")
	return {"route":route,"status":"passed" if failures.is_empty() else "failed","failures":failures,
		"initial":{"cash":60,"inventory":world.config["start_inventory"],"schema":Snapshot.SCHEMA},
		"daily_rows":rows,"milestones":{"delegated_display_day":delegated_day+1,"full_capacity_display_day":full_day+1 if full_day >= 0 else null},
		"final":{"cash":end_state["economy"]["primeval_stones"],"gross_revenue":world.gross_revenue(),
			"labour":end_state["workforce"]["spent"],"inventory":end_state["inventory"],"husbandry":end_state["world"]["husbandry"],
			"terms":end_state["journal"]["terms"],"husbandry_terms":frozen["terms"] if not frozen.is_empty() else [],
			"supplied_paths":supplied,"composted":composted,"fertilized":fertilized,"animal_income":animal_income,"reinvested":reinvested,
			"full_population_claims":{"sheep":full_sheep_claims,"fish":full_fish_claims}},
		"day46_freeze_checked":failures.is_empty()}

func _can(ap: int) -> bool:
	return (loop_day < 0 or world.clock.total_days == loop_day) and world.clock.ap > ap and world.daily_save_error.is_empty()

func _do(action: String, parameters: Dictionary, call: Callable) -> bool:
	var day: int = world.clock.total_days
	var ap: int = world.clock.ap
	var cash: int = world.primeval_stones
	var stock: Dictionary = world.inventory.to_save()
	var result: Dictionary = call.call()
	var delta := {}
	var after: Dictionary = world.inventory.to_save()
	for item in world._items:
		var change := int(after.get(item,0)) - int(stock.get(item,0))
		if change != 0: delta[item] = change
	current["actions"].append({"action":action,"parameters":parameters,"ok":result["ok"],
		"reason":result.get("reason",""),"ap_used":0 if action == "end_day" else ap-world.clock.ap if day == world.clock.total_days else ap,
		"cash_delta":world.primeval_stones-cash,"inventory_delta":delta,"auto_day_end":day != world.clock.total_days and action != "end_day"})
	if not result["ok"]: failures.append("D%d %s %s: %s" % [day,action,parameters,result.get("reason","")])
	if not world.daily_save_error.is_empty(): failures.append("D%d save failed: %s" % [day,world.daily_save_error])
	if animal_income > 0 and world.primeval_stones < cash and action in ["buy","purchase_animal","build"]: reinvested = true
	if world.clock.total_days != day: _finish(day); _begin()
	return bool(result["ok"])

func _begin() -> void:
	current = {"service_day":world.clock.total_days,"display_day":world.clock.total_days+1,"cash_start":world.primeval_stones,
		"ap_start":world.clock.ap,"inventory_start":world.inventory.to_save(),"actions":[]}

func _finish(completed_day: int) -> void:
	var book: Dictionary = world.ledger.state["history"][-1]
	var totals: Dictionary = world.journal["history"][-1]["totals"]
	var payroll: Dictionary = world.workforce.state["report"].duplicate(true)
	var fees := 0
	for person in payroll["workers"]:
		fees += int(person["fee"])
		if int(person["fee"]) != int(person["success"]): failures.append("payroll success/fee mismatch")
	if fees != int(totals["labour_spend"]): failures.append("payroll/journal mismatch")
	if world.primeval_stones != int(current["cash_start"])+Journal.income(totals)-Journal.expense(totals): failures.append("cash ledger mismatch D%d" % completed_day)
	current.merge({"cash_end":world.primeval_stones,"cashflows":totals,"resources":book.duplicate(true),
		"inventory_end":world.inventory.to_save(),"husbandry":world.husbandry.to_save(),"payroll":payroll,
		"husbandry_entries":world.reports.day_entries(completed_day).duplicate(true),"saved":world.daily_save_error.is_empty(),"schema":Snapshot.SCHEMA})
	var ap_used := 0
	for action in current["actions"]: ap_used += int(action["ap_used"])
	current["ap_used"] = ap_used
	if ap_used > 24: failures.append("daily AP exceeded24")
	rows.append(current)
	var checked: Dictionary = Snapshot.normalize(world.to_snapshot())
	if not checked["ok"]: failures.append("snapshot invalid D%d: %s" % [completed_day,checked.get("reason","")])
	for item in book["inflows"]:
		if book["inflows"][item].has("脚手架注入"): failures.append("injection found in replay")
	for event in world.reports.day_entries(completed_day):
		if event["category"] == "claim":
			if event["items"].has("steel_wool"): sheep_claims += 1
			if event["items"].has("fish_meat"): fish_claims += 1
			# Sheep remain in a mixed-age pen and need not shear in lockstep.
			if event["items"].has("steel_wool"):
				var summary: Dictionary = world.husbandry.summary(world.husbandry.habitat_of(int(event["facility_uid"])))
				if summary["adult"] == 4: full_sheep_claims += 1
			if int(event["count"]) == 4 and event["items"].has("fish_meat"): full_fish_claims += 1
	if world.clock.total_days in [10,18,30,45] and not output_prefix.is_empty():
		var f := FileAccess.open("%s-day%d.json" % [output_prefix,world.clock.total_days],FileAccess.WRITE)
		f.store_string(JSON.stringify(world.to_snapshot()))

func _stock(source: String, item: String, target: int) -> void:
	while world.inventory.count(item) < target and world.source_remaining(source) >= int(world.source_defs[source]["quantity"]) and _can(1):
		_do("collect",{"source":source},func(): return world.collect(source))

func _plant(cell: Vector2i, crop: String) -> void:
	var footprint: Array = world.crop_defs[crop]["footprint"]
	for y in range(int(footprint[1])):
		for x in range(int(footprint[0])):
			var point := cell+Vector2i(x,y)
			if world.grid.state_at(point) == world.Grid.State.WILD: _do("till",{"cell":[point.x,point.y]},func(): return world.till(point))
	_do("plant",{"cell":[cell.x,cell.y],"crop":crop},func(): return world.plant(cell,crop))

func _fields() -> void:
	for crop in world.crops.values().duplicate(true):
		if not _can(1): return
		var cell := Vector2i(int(crop["origin"][0]),int(crop["origin"][1]))
		if crop["state"] == "mature":
			_do("harvest",{"cell":[cell.x,cell.y],"crop":crop["crop_id"]},func(): return world.harvest(cell,"fell" if crop["crop_id"] == "fast_fir" else "harvest"))
		else:
			for point in world.grid.holder_cells("v1_crop:%d" % crop["uid"]).duplicate():
				if not _can(1): return
				if int(world.environment_at(point)["water"]) < 35:
					_stock("spring_source","clean_water",1)
					if world.inventory.count("clean_water") > 0 and _can(1): _do("irrigate",{"cell":[point.x,point.y]},func(): return world.irrigate(point))

func _renew_fields() -> void:
	var plans := []
	for x in range(1,5): plans.append([Vector2i(x,1),"pasture_grass"])
	if route == "B":
		for x in range(1,5): plans.append([Vector2i(x,3),"pasture_grass"])
	for x in range(1,4): plans.append([Vector2i(x,2),"golden_wheat"])
	for x in range(1,6): plans.append([Vector2i(x,4),"golden_wheat"])
	for plan in plans:
		var cell: Vector2i = plan[0]
		if not world.instance_at(cell).is_empty() or not _can(3): continue
		var seed: String = world.crop_defs[plan[1]]["seed"]
		if world.inventory.count(seed) == 0:
			if world.primeval_stones < int(world._items[seed]["buy_price"])+12: continue
			_do("buy",{"item":seed,"quantity":1},func(): return world.buy(seed,1))
		_plant(cell,plan[1])

func _build(kind: String, cell: Vector2i, key: String = "") -> bool:
	var definition: Dictionary = world.facility_defs[kind]
	if not _can(1) or world.primeval_stones < int(definition["cash"]): return false
	for item in definition["materials"]:
		if world.inventory.count(item) < int(definition["materials"][item]): return false
	var uid: int = world._next_facility_uid
	if _do("build",{"facility":kind,"cell":[cell.x,cell.y]},func(): return world.build_facility(cell,kind)):
		facilities[kind if key.is_empty() else key] = uid
		return true
	return false

func _build_startup() -> void:
	if world.inventory.count("raw_wood") < 4 or facilities.has("algae_tank"): return
	_stock("stone_source","raw_stone",8)
	if not facilities.has("pen"): _build("pen",Vector2i(7,1))
	if not facilities.has("fish_pond"): _build("fish_pond",Vector2i(0,14))
	if not facilities.has("algae_tank"): _build("algae_tank",Vector2i(9,4))

func _algae() -> void:
	for facility in world.facilities.values().duplicate(true):
		if facility["facility_id"] != "algae_tank" or not _can(2): continue
		var uid := int(facility["uid"])
		if facility["batch"].get("status") == "ready": _do("claim_batch",{"uid":uid},func(): return world.claim_batch(uid,int(facility["batch"]["batch_id"])))
		if world.facilities[uid]["batch"].is_empty() and world.inventory.count("straw") >= 2 and world.inventory.count("algae_feed") < (30 if route == "B" else 14):
			_stock("spring_source","clean_water",3)
			if world.inventory.count("clean_water") >= 3: _do("start_batch",{"uid":uid,"recipe":"culture_algae"},func(): return world.start_batch(uid,"culture_algae"))

func _animals() -> void:
	if facilities.has("pen") and not first_sheep and loop_day >= 8 and world.primeval_stones >= 12:
		_do("purchase_animal",{"uid":facilities["pen"],"quantity":1},func(): return world.husbandry.purchase(facilities["pen"],1))
		first_sheep = true
	if facilities.has("fish_pond") and loop_day >= 10 and world.husbandry.habitat_of(facilities["fish_pond"])["individuals"].is_empty() and world.inventory.count("algae_feed") >= (4 if full_day >= 0 else 2):
		var count := 4 if full_day >= 0 else 2
		if world.primeval_stones >= count*5+6:
			_do("purchase_animal",{"uid":facilities["fish_pond"],"quantity":count},func(): return world.husbandry.purchase(facilities["fish_pond"],count))
			first_fish = true

func _expansion() -> void:
	if route != "B" or loop_day < 22 or not first_fish or full_day >= 0 or world.primeval_stones < 80 or world.inventory.count("fodder_grass") < 12: return
	if not facilities.has("algae_tank_2"):
		_stock("stone_source","raw_stone",1)
		_build("algae_tank",Vector2i(9,5),"algae_tank_2")
	if not facilities.has("algae_tank_2"): return
	var sheep_count: int = world.husbandry.habitat_of(facilities["pen"])["individuals"].size()
	if sheep_count < 4: _do("purchase_animal",{"uid":facilities["pen"],"quantity":4-sheep_count},func(): return world.husbandry.purchase(facilities["pen"],4-sheep_count))
	var fish_count: int = world.husbandry.habitat_of(facilities["fish_pond"])["individuals"].size()
	if fish_count < 4: _do("purchase_animal",{"uid":facilities["fish_pond"],"quantity":4-fish_count},func(): return world.husbandry.purchase(facilities["fish_pond"],4-fish_count))
	full_day = loop_day

func _delegate() -> void:
	if delegated_day < 0:
		_do("hire",{"name":"羊倌"},func(): return world.workforce.hire("羊倌"))
		_do("hire",{"name":"鱼倌"},func(): return world.workforce.hire("鱼倌"))
		delegated_day = loop_day
	for pair in [["pen",1],["fish_pond",2]]:
		if facilities.has(pair[0]) and int(world.workforce._worker(pair[1]).get("caretaker_facility",0)) == 0:
			_do("assign",{"uid":facilities[pair[0]],"worker":pair[1]},func(): return world.husbandry.assign_caretaker(facilities[pair[0]],pair[1]))

func _husbandry() -> void:
	if not first_sheep: return
	_stock("ore_source","iron_ore",8 if full_day >= 0 else 2)
	if route == "B" or (sheep_claims > 0 and fish_claims > 0 and animal_income > 0): _delegate()
	if delegated_day >= 0: return
	for key in ["pen","fish_pond"]:
		if not facilities.has(key) or not _can(1): continue
		var uid: int = facilities[key]
		if world.husbandry.quote_claim(uid)["ok"]:
			_do("claim_animals",{"uid":uid},func(): return world.husbandry.claim(uid))
		if world.husbandry.quote_water(uid)["ok"] and world.husbandry.habitat_of(uid).get("water",100) <= 60 and _can(1):
			_do("repair_water",{"uid":uid},func(): return world.husbandry.maintain_water(uid))
		if world.husbandry.quote_maintenance(uid)["ok"] and _can(1): _do("maintain",{"uid":uid},func(): return world.husbandry.maintain(uid))

func _market() -> void:
	if not first_sale and world.inventory.count("grain") >= 3:
		_do("sell",{"item":"grain","quantity":3,"purpose":"startup"},func(): return world.sell("grain",3)); first_sale = true
	if route == "B" and first_sale and not extra_sale and world.inventory.count("grain") >= 3:
		_do("sell",{"item":"grain","quantity":3,"purpose":"early_wages"},func(): return world.sell("grain",3)); extra_sale = true
	var candidates := {"wood":"fish_meat","gold":"steel_wool","water":"clean_water","fire":"resin","earth":"humus"}
	for order in world.daily_orders():
		var path: String = order["path"]
		if supplied.has(path) or order["status"] != "open": continue
		var item: String = candidates[path]
		var quote: Dictionary = world.order_quote(int(order["id"]),item)
		var reserve := 12 if item == "clean_water" else 2 if item == "humus" else 0
		if quote["ok"] and world.inventory.count(item) >= int(quote["quantity"])+reserve:
			_do("deliver",{"order":order["id"],"item":item,"rank":order["rank"],"path":path},func(): return world.deliver_order(order["id"],item))
			supplied[path] = {"service_day":loop_day,"item":item,"rank":order["rank"],"quantity":quote["quantity"],"payout":quote["payout"]}
			if item in ["steel_wool","fish_meat"]: animal_income += int(quote["payout"])
	for item in ["fish_meat","steel_wool","resin","grain"]:
		if item == "steel_wool" and not supplied.has("gold"): continue
		if item == "fish_meat" and not supplied.has("wood") and animal_income > 0: continue
		var reserve := 12 if item == "grain" else 6 if item == "resin" and not supplied.has("fire") else 0
		var quantity: int = world.inventory.count(item)-reserve
		if quantity > 0 and (item != "grain" or loop_day >= 17):
			var income: int = quantity*int(world._items[item]["sell_price"])
			_do("sell",{"item":item,"quantity":quantity},func(): return world.sell(item,quantity))
			if item in ["steel_wool","fish_meat"]: animal_income += income

func _compost() -> void:
	if not facilities.has("compost_bin") and (world.inventory.count("fish_manure") >= 2 or world.inventory.count("sheep_manure") >= 2):
		_stock("stone_source","raw_stone",1)
		_build("compost_bin",Vector2i(8,4))
	if not facilities.has("compost_bin") or not _can(2): return
	var uid: int = facilities["compost_bin"]
	var batch: Dictionary = world.facilities[uid]["batch"]
	if batch.get("status") == "ready":
		_do("claim_batch",{"uid":uid,"source":compost_source},func(): return world.claim_batch(uid,int(batch["batch_id"])))
		composted[compost_source] = int(composted.get(compost_source,0))+2
		var cell := Vector2i(1,2)
		if world.inventory.count("humus") > 0 and world.environment_at(cell)["fertility"] < 100:
			_do("fertilize",{"cell":[cell.x,cell.y],"source":compost_source},func(): return world.fertilize(cell))
			fertilized[compost_source] = int(fertilized.get(compost_source,0))+1
	if world.facilities[uid]["batch"].is_empty():
		for item in ["fish_manure","sheep_manure"]:
			if world.inventory.count(item) >= 2:
				compost_source = item
				_do("start_batch",{"uid":uid,"recipe":"compost_"+item},func(): return world.start_batch(uid,"compost_"+item)); break

func _validate() -> void:
	if rows.size() != 45 or world.clock.total_days != 45: failures.append("must complete exactly45 days")
	if not first_sheep or not first_fish or sheep_claims < 2 or fish_claims < 2: failures.append("missing sustained sheep/fish cycles")
	if delegated_day < 0 or (route == "B" and delegated_day >= 14): failures.append("caretaker timing not met")
	if route == "B" and (full_day < 0 or full_day > 34): failures.append("full4+4 must operate well before the final day")
	if route == "B" and (full_sheep_claims < 2 or full_fish_claims < 2): failures.append("missing repeated full4 population production")
	for source in ["sheep_manure","fish_manure"]:
		if not composted.has(source) or not fertilized.has(source): failures.append("missing real manure compost/fertilizer: "+source)
	for path in ["wood","gold","water","fire","earth"]:
		if not supplied.has(path): failures.append("missing supply path: "+path)
	if animal_income <= 0 or not reinvested: failures.append("animal income did not fund reinvestment")
	if not world.reports.recap_active(): failures.append("missing frozen recap")
