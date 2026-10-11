extends SceneTree
## P7.b checks: habitats, three-slot config, basic service, growth, water and ledger.
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

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	_model_checks()
	await _ui_checks()
	for label in failures: printerr(label)
	print("PHASE07B TEST %s: %d checks" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func _model_checks() -> void:
	var world := World.new()
	check(Snapshot.normalize(Snapshot.fresh())["ok"],"schema%d fresh round trip" % Snapshot.SCHEMA)
	var older: Dictionary = Snapshot.fresh()
	older["schema"] = Snapshot.SCHEMA-1
	check(not Snapshot.normalize(older)["ok"],"older schema rejected without migration")
	world.grant_scaffold({"raw_wood":6,"raw_stone":12})
	world.build_facility(Vector2i(7,1),"pen")
	world.build_facility(Vector2i(0,14),"fish_pond")
	var pen: Dictionary = world.husbandry.habitat_of(1)
	var pond: Dictionary = world.husbandry.habitat_of(2)
	check(pen["species_id"] == "steel_sheep" and pen["basic_diet_id"] == "grass_meal" and pen["special_diet_id"] == "iron_supplement" and pen["default_notice"],"pen gets notified defaults")
	check(pond["species_id"] == "filter_algae_carp" and pond["basic_diet_id"] == "algae_meal" and int(pond["water"]) == 100,"pond gets water metric and defaults")
	var initial: Dictionary = world.to_snapshot()
	check(not world.husbandry.purchase(1,0)["ok"] and not world.husbandry.purchase(1,5)["ok"] and not world.husbandry.purchase(1,99)["ok"],"purchase bounds reject 0/5/nonsense")
	check(world.to_snapshot() == initial,"failed purchase mutates nothing")
	world.primeval_stones = 5
	check(not world.husbandry.purchase(1,1)["ok"] and world.primeval_stones == 5,"insufficient stones refuses")
	world.primeval_stones = 32
	var quote: Dictionary = world.husbandry.quote_purchase(1,2)
	check(world.to_snapshot() == initial,"read-only purchase quote keeps state untouched")
	check(quote["ok"] and quote["total"] == 24 and quote["capacity_left"] == 4 and quote["after_count"] == 2,"purchase quote prices and capacity")
	check(quote["growth_needs"]["fodder_grass"] == 12 and quote["growth_needs"]["clean_water"] == 12,"growth rations count six valid days each")
	check(world.husbandry.purchase(1,2)["ok"] and world.primeval_stones == 8 and world.husbandry.summary(pen)["total"] == 2,"successful purchase charges once and occupies capacity")
	world.primeval_stones += 100
	check(world.husbandry.purchase(1,2)["ok"] and not world.husbandry.purchase(1,1)["ok"] and world.husbandry.summary(pen)["total"] == 4,"capacity four counts juveniles and rejects the fifth")
	world.grant_scaffold({"fodder_grass":4,"clean_water":4})
	var before: Dictionary = world.to_snapshot()
	check(not world.husbandry.maintain(2)["ok"] and world.to_snapshot() == before,"empty pond maintenance is not work")
	var ap_before: int = world.clock.ap
	check(world.husbandry.maintain(1)["ok"] and world.clock.ap == ap_before-1,"whole-branch basic service spends one AP for four animals")
	var fed: Dictionary = world.husbandry.habitat_of(1)
	check(world.husbandry.summary(fed)["fed_today"] == 4 and int(fed["individuals"][0]["base_service"]["day"]) == 0 and fed["individuals"][0]["base_service"]["diet_id"] == "grass_meal","service recorded per individual with actual diet")
	check(not world.husbandry.maintain(1)["ok"] and world.clock.ap == ap_before-1,"repeat feeding finds no target and costs nothing")
	check(world.husbandry.set_base_diet(1,"grain_meal")["ok"] and fed["individuals"][0]["base_service"]["diet_id"] == "grass_meal" and fed["default_notice"] == false,"diet switch keeps today's service record and clears the notice")
	var day0: Dictionary = world.to_snapshot()
	world.buy("grain",1)
	check(not world.husbandry.maintain(1)["ok"] and world.to_snapshot() != day0,"already fully served day refuses without consuming grain")
	world.sell("grain",1)
	world.clock.ap = 1
	var last_ap: Dictionary = world.husbandry.maintain(1)
	check(not last_ap["ok"] and world.clock.ap == 1,"no unserved individuals remains refused on the last AP")
	# Reset today's service to exercise the last-AP ordering with a fresh target.
	world.husbandry.habitat_of(1)["individuals"][0]["base_service"]["day"] = -1
	world.grant_scaffold({"grain":1,"clean_water":1})
	check(world.husbandry.maintain(1)["ok"] and world.clock.total_days == 1 and world.clock.ap == 24,"last AP feeds then settles the same day")
	var ledger: Dictionary = world.ledger.state
	check(ledger["history"][0]["outflows"]["fodder_grass"]["养殖投喂"] == 4 and ledger["history"][0]["outflows"]["grain"]["养殖投喂"] == 1,"feeding flows are booked before the day closes")
	var reloaded := World.new()
	check(reloaded.apply_snapshot(world.to_snapshot())["ok"] and reloaded.to_snapshot() == world.to_snapshot(),"husbandry and ledger survive save and reload")
	var sheep: Array = reloaded.husbandry.habitat_of(1)["individuals"]
	check(int(sheep[0]["growth"]) == 100 and int(sheep[3]["growth"]) == 100,"one served day advanced every juvenile")
	for _day in range(5):
		reloaded.grant_scaffold({"grain":4,"clean_water":4})
		check(reloaded.husbandry.maintain(1)["ok"],"daily whole-branch service continues")
		reloaded.end_day()
	sheep = reloaded.husbandry.habitat_of(1)["individuals"]
	var grown := 0
	for individual in sheep: grown += int(individual["stage"] == "adult")
	check(grown == 4 and int(sheep[0]["growth"]) == 600 and int(sheep[0]["uid"]) == 1,"exactly six valid days make adults with unchanged UIDs")
	check(reloaded.inventory.count("steel_wool") == 0 and reloaded.inventory.count("sheep_manure") == 0,"adults produce nothing before P7.c")
	check(not reloaded.demolish_facility(1)["ok"],"non-empty habitat refuses demolition")
	check(reloaded.husbandry.cull(1)["ok"] and reloaded.husbandry.summary(reloaded.husbandry.habitat_of(1))["total"] == 0 and not reloaded.husbandry.cull(1)["ok"],"cull removes every animal once")
	check(reloaded.demolish_facility(1)["ok"] and reloaded.husbandry.habitat_of(1).is_empty(),"emptied habitat demolishes and forgets plans")
	# Water metric: precheck, restore, decay pacing and pause.
	var fish_world := World.new()
	fish_world.grant_scaffold({"raw_wood":2,"raw_stone":6})
	fish_world.build_facility(Vector2i(0,14),"fish_pond")
	fish_world.husbandry.purchase(1,1)
	var pond_solo: Dictionary = fish_world.husbandry.habitat_of(1)
	check(fish_world.husbandry.water_support_days(pond_solo) == 13,"from 100 the metric supports exactly thirteen more day-ends")
	pond_solo["water"] = 35
	fish_world.grant_scaffold({"algae_feed":1})
	var blocked: Dictionary = fish_world.husbandry.quote_maintenance(1)
	check(not blocked["ok"] and blocked["reason"].contains("水体"),"predicted decay to 30 blocks feeding with a water reason")
	var block_state: Dictionary = fish_world.to_snapshot()
	check(not fish_world.husbandry.maintain(1)["ok"] and fish_world.to_snapshot() == block_state,"blocked feeding consumes nothing")
	fish_world.grant_scaffold({"clean_water":2})
	check(fish_world.husbandry.maintain_water(1)["ok"] and int(pond_solo["water"]) == 75,"water maintenance adds forty capped at one hundred")
	check(fish_world.husbandry.maintain(1)["ok"],"feeding proceeds after water recovery")
	pond_solo["water"] = 100
	for day in range(14):
		fish_world.husbandry.settle(day)
		if day < 13:
			check(int(pond_solo["water"]) > 30,"decay keeps the pond above the pause line through settle %d" % (day+1))
	check(int(pond_solo["water"]) == 30,"fourteenth settle lands exactly on the pause threshold")
	fish_world.husbandry.habitat_of(1)["individuals"][0]["base_service"]["day"] = 13
	fish_world.husbandry.habitat_of(1)["individuals"][0]["growth"] = 0
	fish_world.husbandry.settle(13)
	check(fish_world.husbandry.habitat_of(1)["individuals"][0]["growth"] == 0,"paused water stops growth without clearing progress")
	pond_solo["water"] = 60
	fish_world.husbandry.settle(13)
	check(fish_world.husbandry.habitat_of(1)["individuals"][0]["growth"] == 100,"recovered water resumes growth from the kept progress")
	var emptied: Dictionary = fish_world.husbandry.habitat_of(1)
	emptied["individuals"] = []
	var before_empty: int = int(emptied["water"])
	fish_world.husbandry.settle(99)
	check(int(emptied["water"]) == before_empty,"empty pond neither decays nor needs work")
	# Corrupt snapshots must reject before the world applies anything.
	_bad_snapshot_checks()
	_ledger_checks()

func _bad_snapshot_checks() -> void:
	var world := World.new()
	world.grant_scaffold({"raw_wood":2,"raw_stone":6})
	world.build_facility(Vector2i(0,14),"fish_pond")
	world.husbandry.purchase(1,1)
	world.grant_scaffold({"algae_feed":1})
	world.husbandry.maintain(1)
	var good: Dictionary = world.to_snapshot()
	check(Snapshot.normalize(good)["ok"],"live snapshot with a served individual validates")
	for case in [
		["duplicate uid", func(s): s["world"]["husbandry"]["habitats"][0]["individuals"].append(s["world"]["husbandry"]["habitats"][0]["individuals"][0].duplicate(true))],
		["wrong facility", func(s): s["world"]["husbandry"]["habitats"][0]["facility_uid"] = 9],
		["over capacity", func(s):
			for _n in range(4): s["world"]["husbandry"]["habitats"][0]["individuals"].append({"uid": 90+_n,"stage":"juvenile","growth":0,"base_service":{"day":-1,"diet_id":"","inputs":{},"operator":""}})],
		["illegal growth", func(s): s["world"]["husbandry"]["habitats"][0]["individuals"][0]["growth"] = 999],
		["future service day", func(s): s["world"]["husbandry"]["habitats"][0]["individuals"][0]["base_service"]["day"] = 8],
		["alien diet", func(s): s["world"]["husbandry"]["habitats"][0]["individuals"][0]["base_service"]["diet_id"] = "grain_fatten"],
		["counter below uid", func(s): s["world"]["husbandry"]["next_animal_uid"] = 1],
		["water on land habitat", func(s):
			var copy: Dictionary = s["world"]["husbandry"]["habitats"][0].duplicate(true)
			copy["facility_uid"] = 9
			s["world"]["facilities"].append({"uid":9,"facility_id":"pen","origin":[7,1],"batch":{}})
			copy["species_id"] = "steel_sheep"
			copy["basic_diet_id"] = "grass_meal"
			copy["special_diet_id"] = "iron_supplement"
			s["world"]["husbandry"]["habitats"].append(copy)],
		["unbalanced ledger", func(s): s["ledger"]["pending"]["outflows"] = {"algae_feed":{"养殖投喂":5}}],
		["ledger date break", func(s): s["ledger"]["pending"]["day"] = 3],
		["missing husbandry", func(s): s["world"].erase("husbandry")],
		["missing ledger", func(s): s.erase("ledger")],
	]:
		var damaged: Dictionary = good.duplicate(true)
		case[1].call(damaged)
		check(not Snapshot.normalize(damaged)["ok"],"damaged snapshot rejects: "+String(case[0]))
	var switched: Dictionary = good.duplicate(true)
	switched["world"]["husbandry"]["habitats"][0]["basic_diet_id"] = "grain_meal"
	check(not Snapshot.normalize(switched)["ok"],"plan referencing another species diet rejects")

func _ledger_checks() -> void:
	var world := World.new()
	world.grant_scaffold({"raw_wood":4,"raw_stone":4})
	world.buy("grass_seed",1)
	world.collect("spring_source")
	world.till(Vector2i(2,2))
	world.plant(Vector2i(2,2),"golden_wheat")
	world.irrigate(Vector2i(2,2))
	world.build_facility(Vector2i(9,4),"algae_tank")
	world.grant_scaffold({"straw":2,"clean_water":3})
	world.start_batch(1,"culture_algae")
	world.sell("clean_water",1)
	world.workforce.hire("记账雇工")
	var pending: Dictionary = world.ledger.state["pending"]
	check(pending["inflows"]["grass_seed"]["市场采购"] == 1 and pending["outflows"]["golden_wheat_seed"]["播种投料"] == 1,"purchase and planting both visible with distinct reasons")
	check(pending["outflows"]["clean_water"]["浇水"] == 1 and pending["inflows"]["clean_water"]["资源采集"] == 5,"collection and watering record exact quantities")
	check(pending["outflows"]["raw_wood"]["建设材料"] == 1 and pending["outflows"]["clean_water"]["加工投料"] == 3,"construction and batch inputs flow out")
	check(pending["outflows"]["clean_water"]["市场出售"] == 1,"sales flow out while cash is separate")
	world.end_day()
	var worker_view: Dictionary = world.ledger.day_view(0)
	check(worker_view["closing"] == world.inventory.to_save(),"settled day closes on the live inventory")
	world.end_day()
	world.grant_scaffold({"straw":2,"clean_water":3})
	check(world.claim_batch(1,1)["ok"] and world.ledger.state["pending"]["inflows"]["algae_feed"]["加工收取"] == 6,"claim books inflow only on the claiming day")
	var unclaimed := World.new()
	unclaimed.grant_scaffold({"raw_wood":1,"raw_stone":1})
	unclaimed.build_facility(Vector2i(9,4),"algae_tank")
	unclaimed.grant_scaffold({"straw":2,"clean_water":3})
	unclaimed.start_batch(1,"culture_algae")
	unclaimed.end_day()
	var view: Dictionary = unclaimed.ledger.day_view(0)
	check(not view["inflows"].has("algae_feed"),"completed but unclaimed batch books no inflow")
	var average: Dictionary = unclaimed.ledger.average_view(7)
	check(average["days"] == 1 and not average["totals_in"].has("algae_feed"),"average counts the quiet settled day without inventing growth")
	for day in range(3): unclaimed.end_day()
	check(unclaimed.ledger.average_view(7)["days"] == 4 and unclaimed.ledger.state["history"].size() == 4,"averages include zero-activity days and today stays out")
	var balanced_flow: Dictionary = unclaimed.ledger.state["pending"]
	check(balanced_flow["day"] == 4,"pending day advances with the clock")
	world.daily_save_error = "模拟失败"
	var before_retry: Dictionary = world.to_snapshot()
	world.retry_day_save()
	check(world.to_snapshot() == before_retry,"retry resaves the same settlement without new flows")

func _ui_checks() -> void:
	var ui = Scene.instantiate()
	var directory := "user://phase07b_%d" % Time.get_ticks_usec()
	ui.store = Store.new(directory)
	root.add_child(ui)
	await process_frame
	ui._new(1,false)
	ui.world.grant_scaffold({"raw_wood":4,"raw_stone":8,"fodder_grass":2,"clean_water":4})
	ui.world.build_facility(Vector2i(7,1),"pen")
	ui.world.build_facility(Vector2i(0,14),"fish_pond")
	ui.selected = Vector2i(7,1)
	ui._show_cell()
	check(has_text(ui.sidebar,"新建设施已采用默认配置"),"default configuration is announced in the panel")
	check(has_text(ui.sidebar,"钢绵羊") and has_text(ui.sidebar,"牧草餐") and has_text(ui.sidebar,"含铁补料"),"three slots show species and diet names")
	check(has_text(ui.sidebar,"含铁补料"),"special slot shows the default production recipe")
	ui.world.husbandry.purchase(1,2)
	ui._show_cell()
	check(has_text(ui.sidebar,"2/4只") and has_text(ui.sidebar,"今日已喂0/2"),"counts and feeding state are visible")
	var fed: Dictionary = ui.world.husbandry.maintain(1)
	check(fed["ok"],"panel-level maintenance call succeeds")
	ui._show_cell()
	check(has_text(ui.sidebar,"今日已喂2/2"),"panel refresh path shows served animals")
	ui._habitat_expanded = true
	ui._show_cell()
	check(has_text(ui.sidebar,"#1 幼体"),"expanded individuals list rows")
	check(has_text(ui.sidebar,"非空设施需先清退"),"occupied habitat explains the demolition block")
	ui.selected = Vector2i(0,14)
	ui._show_cell()
	check(has_text(ui.sidebar,"水体可用度"),"pond shows the water metric")
	check(has_text(ui.sidebar,"空场水体不衰减"),"empty pond states no decay")
	ui.resource_focus = "fodder_grass"
	ui._show_resources()
	check(has_text(ui.sidebar,"元石（真实收入/支出，单列）"),"resource page separates cash")
	check(has_text(ui.sidebar,"增长与平衡") and has_text(ui.sidebar,"负增长"),"resource page groups by net sign")
	check(has_text(ui.sidebar,"养殖投喂"),"feeding shows among outflow reasons after expansion")
	check(has_text(ui.sidebar,"完成未领不计增长"),"page states the claim-only policy")
	ui.resource_mode = 1
	ui._show_resources()
	check(has_text(ui.sidebar,"暂无已结算日"),"average view without history says so")
	ui._close_page()
	for slot in [1,2,3]:
		if ui.store.occupied(slot): ui.store.delete_slot(slot,true)
	DirAccess.remove_absolute(directory)
	ui.queue_free()
	await process_frame
