extends SceneTree
## P7.c checks: special cycles, two-branch maintenance, claims and the byproduct loop.
const Scene := preload("res://scenes/farming/farm_v2.tscn")
const World := preload("res://scripts/farming/v2/v2_world.gd")
const Snapshot := preload("res://scripts/farming/v2/v2_snapshot.gd")
const Store := preload("res://scripts/farming/v2/v2_slot_store.gd")
var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func has_text(node: Node, text: String) -> bool:
	if node is Label and String(node.text).contains(text): return true
	if node is Button and (String(node.text).contains(text) or String(node.tooltip_text).contains(text)): return true
	for child in node.get_children():
		if has_text(child,text): return true
	return false

func adult(habitat: Dictionary, growth_target: int) -> void:
	for individual in habitat["individuals"]:
		individual["stage"] = "adult"
		individual["growth"] = growth_target

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	_cycle_checks()
	_branch_checks()
	_claim_checks()
	_ledger_checks()
	await _ui_checks()
	for label in failures: printerr(label)
	print("PHASE07C TEST %s: %d checks" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

## Two habitats, four fed adults with running cycles on day 0.
func _prepared() -> World:
	var world := World.new()
	world.grant_scaffold({"raw_wood":6,"raw_stone":12})
	world.build_facility(Vector2i(7,1),"pen")
	world.build_facility(Vector2i(0,14),"fish_pond")
	world.primeval_stones += 100
	world.husbandry.purchase(1,2)
	world.husbandry.purchase(2,2)
	world.grant_scaffold({"fodder_grass":8,"clean_water":8,"algae_feed":8,"iron_ore":4,"grain":4})
	adult(world.husbandry.habitat_of(1),600)
	adult(world.husbandry.habitat_of(2),400)
	world.husbandry.maintain(1)
	world.husbandry.maintain(2)
	return world

func _cycle_checks() -> void:
	var world := _prepared()
	var pen: Dictionary = world.husbandry.habitat_of(1)
	var pond: Dictionary = world.husbandry.habitat_of(2)
	var cycle: Dictionary = pen["individuals"][0]["cycle"]
	check(not cycle.is_empty() and cycle["status"] == "running" and int(cycle["progress"]) == 0 and int(cycle["goal"]) == 300,"sheep cycle starts at zero of three valid days")
	var sheep_rules: Dictionary = world.husbandry.species_def("steel_sheep")
	check(cycle["inputs"] == sheep_rules["special_diets"][0]["inputs"] and cycle["outputs"] == sheep_rules["outputs"],"cycle freezes inputs and outputs")
	check(world.inventory.count("iron_ore") == 2,"special feed deducted once per sheep")
	check(world.husbandry.summary(pen)["running"] == 2 and world.husbandry.summary(pond)["running"] == 2,"summary groups running cycles")
	# Pausing: skip a day of basic service, cycle keeps its progress.
	world.end_day()
	world.grant_scaffold({"fodder_grass":4,"clean_water":4,"algae_feed":4})
	world.end_day()
	check(int(pen["individuals"][0]["cycle"]["progress"]) == 100 and int(pond["individuals"][0]["cycle"]["progress"]) == 100,"missed basic day pauses the cycle without clearing it")
	check(world.husbandry.set_special_diet(1,"")["ok"] and not pen["production_enabled"] and pen["special_diet_id"] == "iron_supplement","paused production keeps the last legal recipe")
	world.grant_scaffold({"fodder_grass":4,"clean_water":4,"algae_feed":4})
	world.husbandry.maintain(1)
	world.husbandry.maintain(2)
	world.end_day()
	check(int(pen["individuals"][0]["cycle"]["progress"]) == 200,"running cycle continues under a paused plan")
	check(not world.husbandry.set_special_diet(1,"alien")["ok"],"alien special diets refuse")
	world.husbandry.set_special_diet(1,"iron_supplement")
	world.end_day()
	world.grant_scaffold({"fodder_grass":4,"clean_water":4,"algae_feed":4})
	world.husbandry.maintain(1)
	world.husbandry.maintain(2)
	world.end_day()
	check(pen["individuals"][0]["cycle"]["status"] == "ready" and int(pen["individuals"][0]["cycle"]["ready_day"]) >= 0,"sheep cycle reaches ready after three valid days")
	check(pond["individuals"][0]["cycle"]["status"] == "ready" and int(pond["individuals"][0]["cycle"]["progress"]) == 200,"carp cycle reaches ready after two valid days")
	var saved := world.to_snapshot()
	var restored := World.new()
	check(restored.apply_snapshot(saved)["ok"] and restored.to_snapshot() == saved,"cycle state round trips through the snapshot")
	var corrupt: Dictionary = saved.duplicate(true)
	corrupt["world"]["husbandry"]["habitats"][0]["individuals"][0]["cycle"]["outputs"] = {"steel_wool":9}
	check(not Snapshot.normalize(corrupt)["ok"],"inflated cycle outputs reject")
	corrupt = saved.duplicate(true)
	corrupt["world"]["husbandry"]["habitats"][0]["individuals"][1]["cycle"]["uid"] = corrupt["world"]["husbandry"]["habitats"][0]["individuals"][0]["cycle"]["uid"]
	check(not Snapshot.normalize(corrupt)["ok"],"duplicate cycle identities reject")
	corrupt = saved.duplicate(true)
	corrupt["world"]["husbandry"]["habitats"][0]["individuals"][0]["cycle"]["status"] = "running"
	check(not Snapshot.normalize(corrupt)["ok"],"ready cycle flipped back to running rejects")
	corrupt = saved.duplicate(true)
	corrupt["world"]["husbandry"]["next_cycle_uid"] = 1
	check(not Snapshot.normalize(corrupt)["ok"],"cycle counter below identities rejects")
	corrupt = saved.duplicate(true)
	corrupt["world"]["husbandry"]["habitats"][1]["individuals"][0]["cycle"]["diet_id"] = "iron_supplement"
	check(not Snapshot.normalize(corrupt)["ok"],"cross-species cycle diet rejects")
	corrupt = saved.duplicate(true)
	corrupt["world"]["husbandry"]["habitats"][0]["individuals"][0]["cycle"]["inputs"] = {"iron_ore":9}
	check(not Snapshot.normalize(corrupt)["ok"],"custom cycle rations reject")

func _branch_checks() -> void:
	var world := World.new()
	world.grant_scaffold({"raw_wood":2,"raw_stone":3})
	world.build_facility(Vector2i(7,1),"pen")
	world.husbandry.purchase(1,2)
	world.grant_scaffold({"fodder_grass":4,"clean_water":4,"iron_ore":2})
	adult(world.husbandry.habitat_of(1),600)
	var quote: Dictionary = world.husbandry.quote_maintenance(1)
	check(quote["ok"] and int(quote["basic"]["targets"]) == 2 and int(quote["special"]["targets"]) == 2 and quote["special"]["ok"],"one action previews both branches including just-fed adults")
	var result: Dictionary = world.husbandry.maintain(1)
	check(result["ok"] and result["served"] == 2 and result["started"] == 2 and world.clock.ap == 22,"both branches commit for a single AP after the build AP")
	check(world.inventory.count("fodder_grass") == 2 and world.inventory.count("iron_ore") == 0,"branch materials deducted separately")
	# Already fed adults, special stock empty: refuse, then special-only restart.
	world.husbandry.habitat_of(1)["individuals"][0]["cycle"] = {}
	world.husbandry.habitat_of(1)["individuals"][1]["cycle"] = {}
	var ap: int = world.clock.ap
	var restart: Dictionary = world.husbandry.maintain(1)
	check(not restart["ok"] and world.clock.ap == ap,"missing special stock refuses the restart with zero change")
	world.grant_scaffold({"iron_ore":2})
	restart = world.husbandry.maintain(1)
	check(restart["ok"] and restart["started"] == 2 and restart["served"] == 0 and world.clock.ap == ap-1,"special-only maintenance starts cycles for already fed adults")
	# Unfed targets with base missing but a previously fed idle adult: only special runs.
	world.husbandry.habitat_of(1)["individuals"][0]["cycle"] = {}
	world.husbandry.habitat_of(1)["individuals"][1]["cycle"] = {}
	world.husbandry.habitat_of(1)["individuals"][1]["base_service"]["day"] = -1
	world.inventory.remove("fodder_grass",2)
	world.inventory.remove("clean_water",2)
	world.grant_scaffold({"iron_ore":1})
	ap = world.clock.ap
	var mixed: Dictionary = world.husbandry.maintain(1)
	check(mixed["ok"] and mixed["served"] == 0 and mixed["started"] == 1 and world.inventory.count("fodder_grass") == 0,"base-starved branch does not partially feed while a fed adult still starts")
	check(world.clock.ap == ap-1,"the mixed outcome still costs exactly one AP")
	# Paused plan keeps the basic branch alive.
	world.husbandry.set_special_diet(1,"")
	world.husbandry.habitat_of(1)["individuals"][0]["base_service"]["day"] = -1
	world.husbandry.habitat_of(1)["individuals"][1]["base_service"]["day"] = -1
	world.grant_scaffold({"fodder_grass":2,"clean_water":2})
	ap = world.clock.ap
	var off: Dictionary = world.husbandry.maintain(1)
	check(off["ok"] and off["served"] == 2 and off["started"] == 0 and world.clock.ap == ap-1,"paused plan still allows the basic branch")
	check(not world.husbandry.quote_maintenance(1)["ok"],"next same-day maintenance with nothing to do is not work")

func _claim_checks() -> void:
	var world := _prepared()
	var pond: Dictionary = world.husbandry.habitat_of(2)
	world.end_day()
	world.grant_scaffold({"fodder_grass":4,"clean_water":4,"algae_feed":4})
	world.husbandry.maintain(1)
	world.husbandry.maintain(2)
	world.end_day()
	var ready_quote: Dictionary = world.husbandry.quote_claim(2)
	check(ready_quote["ok"] and int(ready_quote["ready"]) == 2,"claim quote counts ready carp")
	check(not world.husbandry.claim(1)["ok"],"sheep not ready yet refuses claim")
	check(not world.husbandry.claim(2,[[99,99]])["ok"],"stale expected ids refuse to claim another batch")
	var claim: Dictionary = world.husbandry.claim(2,ready_quote["ids"])
	check(claim["ok"] and int(claim["removed"]) == 2 and pond["individuals"].is_empty(),"claiming harvest removes every ready carp")
	check(world.inventory.count("fish_meat") == 6 and world.inventory.count("fish_manure") == 2,"harvest books the full main and byproduct once")
	check(not world.husbandry.claim(2)["ok"],"empty pond cannot claim again")
	# Sheep: third valid day then claim keeps adults.
	world.grant_scaffold({"fodder_grass":2,"clean_water":2,"iron_ore":2})
	world.husbandry.maintain(1)
	world.end_day()
	var pen: Dictionary = world.husbandry.habitat_of(1)
	var sheep_ids: Array = world.husbandry.quote_claim(1)["ids"]
	var shear: Dictionary = world.husbandry.claim(1,sheep_ids)
	check(shear["ok"] and int(shear["kept"]) == 2 and world.husbandry.summary(pen)["idle_adults"] == 2,"shearing keeps both adults idle")
	check(world.inventory.count("steel_wool") == 2 and world.inventory.count("sheep_manure") == 2,"shear products enter stock once")
	# Same-day restart only consumes new special feed; the day's basic service lands once.
	var iron_before: int = world.inventory.count("iron_ore")
	world.grant_scaffold({"fodder_grass":2,"clean_water":2})
	world.husbandry.maintain(1)
	check(not pen["individuals"][0]["cycle"].is_empty() and int(pen["individuals"][0]["cycle"]["uid"]) != int(sheep_ids[0][1]) and world.inventory.count("iron_ore") == iron_before-2,"same-day restart starts fresh cycles on new special feed")
	check(int(pen["individuals"][0]["base_service"]["day"]) == 3 and not world.husbandry.maintain(1)["ok"],"the restart day keeps exactly one basic service")
	world.end_day()
	check(world.clock.ap == 24,"day settles cleanly after the restart")

func _ledger_checks() -> void:
	var world := _prepared()
	world.end_day()
	var day0: Dictionary = world.ledger.day_view(0)
	check(day0["outflows"]["iron_ore"]["特殊投料"] == 2 and day0["outflows"]["grain"]["特殊投料"] == 2,"special feeds book under their own reason")
	world.grant_scaffold({"fodder_grass":4,"clean_water":4,"algae_feed":4})
	world.husbandry.maintain(1)
	world.husbandry.maintain(2)
	world.end_day()
	var claim_ids: Array = world.husbandry.quote_claim(2)["ids"]
	world.husbandry.claim(2,claim_ids)
	var pending: Dictionary = world.ledger.state["pending"]
	check(pending["inflows"]["fish_meat"]["养殖收取"] == 6 and pending["inflows"]["fish_manure"]["养殖收取"] == 2,"claims book real inflows on the claiming day")
	check(not world.ledger.day_view(1)["inflows"].has("fish_meat"),"the earlier settled day does not retroactively gain fish meat")
	# Byproduct loop: fish manure compost then real fertilization.
	world.grant_scaffold({"raw_wood":1,"raw_stone":1})
	world.build_facility(Vector2i(9,4),"compost_bin")
	world.start_batch(3,"compost_fish_manure")
	world.end_day()
	world.end_day()
	world.claim_batch(3,1)
	check(world.inventory.count("humus") >= 2,"composted fish manure yields humus")
	world.till(Vector2i(2,2))
	world.fertilize(Vector2i(2,2))
	check(world.environment_at(Vector2i(2,2))["fertility"] > 60,"humus actually fertilizes the field: the loop closes")
	# Market and rank quotes against the fixed formula.
	var data_quote: Dictionary = world.data_source.demand_quote("gold",1,12,"steel_wool")
	check(data_quote["ok"] and int(data_quote["quantity"]) == 2 and int(data_quote["payout"]) == 26,"gold rank1 steel wool needs 2 for 26")
	data_quote = world.data_source.demand_quote("gold",3,36,"steel_wool")
	check(int(data_quote["quantity"]) == 4 and int(data_quote["payout"]) == 52,"gold rank3 steel wool needs 4 for 52")
	data_quote = world.data_source.demand_quote("gold",5,60,"steel_wool")
	check(int(data_quote["quantity"]) == 6 and int(data_quote["payout"]) == 79,"gold rank5 steel wool needs 6 for 79")
	data_quote = world.data_source.demand_quote("wood",1,12,"fish_meat")
	check(int(data_quote["quantity"]) == 2 and int(data_quote["payout"]) == 19,"wood rank1 fish meat needs 2 for 19")
	data_quote = world.data_source.demand_quote("wood",3,36,"fish_meat")
	check(int(data_quote["quantity"]) == 6 and int(data_quote["payout"]) == 59,"wood rank3 fish meat needs 6 for 59")
	data_quote = world.data_source.demand_quote("wood",5,60,"fish_meat")
	check(int(data_quote["quantity"]) == 10 and int(data_quote["payout"]) == 99,"wood rank5 fish meat needs 10 for 99")
	check(not world.data_source.demand_quote("earth",1,12,"sheep_manure")["ok"] and not world.data_source.demand_quote("earth",1,12,"fish_manure")["ok"],"manure is not a supply ingredient")
	check(int(world._items["steel_wool"]["supply_value"]) == 11 and int(world._items["fish_meat"]["supply_value"]) == 6,"static supply values stay 11 and 6")

func _ui_checks() -> void:
	var ui = Scene.instantiate()
	var directory := "user://phase07c_%d" % Time.get_ticks_usec()
	ui.store = Store.new(directory)
	root.add_child(ui)
	await process_frame
	ui._new(1,false)
	ui.world.grant_scaffold({"raw_wood":4,"raw_stone":8,"fodder_grass":4,"clean_water":4,"iron_ore":2})
	ui.world.build_facility(Vector2i(7,1),"pen")
	ui.world.husbandry.purchase(1,2)
	var world: World = ui.world
	world.husbandry.habitat_of(1)["individuals"][0]["stage"] = "adult"
	world.husbandry.habitat_of(1)["individuals"][0]["growth"] = 600
	world.husbandry.habitat_of(1)["individuals"][1]["stage"] = "juvenile"
	ui.selected = Vector2i(7,1)
	ui._show_cell()
	check(has_text(ui.sidebar,"幼体1 / 成体空闲1"),"mixed herd groups by stage")
	check(has_text(ui.sidebar,"本次基础补喂2只") and has_text(ui.sidebar,"特殊投喂：1只空闲成体"),"two branches list their targets and inputs")
	ui.world.husbandry.set_special_diet(1,"")
	ui._show_cell()
	check(has_text(ui.sidebar,"已停止启动新周期"),"paused plan is announced in the panel")
	ui.world.husbandry.set_special_diet(1,"iron_supplement")
	ui.world.husbandry.maintain(1)
	ui.world.end_day()
	ui.world.grant_scaffold({"fodder_grass":2,"clean_water":2})
	ui.world.husbandry.maintain(1)
	ui.world.end_day()
	ui.world.grant_scaffold({"fodder_grass":2,"clean_water":2})
	ui.world.husbandry.maintain(1)
	ui.world.end_day()
	ui._habitat_expanded = true
	ui._show_cell()
	check(has_text(ui.sidebar,"待收") and has_text(ui.sidebar,"剪毛保留成体"),"ready panel announces the claim and the keep rule")
	check(has_text(ui.sidebar,"待收产物") or has_text(ui.sidebar,"钢绒"),"pending products visible before culling")
	ui._close_page()
	for slot in [1,2,3]:
		if ui.store.occupied(slot): ui.store.delete_slot(slot,true)
	DirAccess.remove_absolute(directory)
	ui.queue_free()
	await process_frame
