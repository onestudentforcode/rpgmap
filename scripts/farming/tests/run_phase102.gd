extends SceneTree
const World := preload("res://scripts/farming/p8/p8_world.gd")
const Codec := preload("res://scripts/farming/p8/p8_snapshot.gd")
const Rooms := preload("res://scripts/farming/p8/p102_rooms.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const Logistics := preload("res://scripts/farming/p8/p10_logistics.gd")
var checks := 0
var failures := []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr(label)
func fixture():
	var w := World.new()
	preload("res://scripts/farming/tests/p107_fixture.gd").unlock(w)
	w.grant_scaffold({"raw_wood":50,"raw_stone":50,"wood_plank":20,"iron_ingot":10,"golden_wheat_seed":99,"resin_tree_seed":10,"oilseed_flower_seed":10,"clean_water":99,"humus":99})
	w.primeval_stones=1000
	w.research.state["completed"]=w.research.project_defs().keys()
	return w
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var w = fixture()
	check(Codec.SCHEMA==25 and Codec.normalize(w.to_snapshot())["ok"],"schema25 agriculture fixture valid")
	for old in [17,18,19,20,21,22,23,24]:
		var bad: Dictionary=w.to_snapshot();bad["schema"]=old
		check(not Codec.normalize(bad)["ok"],"old schema rejected "+str(old))
	var cash_before: int=w.inventory.count("raw_wood")
	var ground_index: int=w.grid.index_of(Vector2i(3,3))
	w.logistics.consume_environment(Vector2i(3,3),ground_index,0,3,50)
	w.logistics.consume_environment(Vector2i(3,3),ground_index,1,1,50)
	var ground_before: Array=w.environment[ground_index].duplicate()
	check(w.rooms.set_floor(Vector2i(3,3),"ordinary")["ok"],"ordinary floor placed")
	check(w.inventory.count("raw_wood")==cash_before-1,"floor costs real wood")
	check(not w.till(Vector2i(3,3))["ok"],"ordinary floor prevents implicit till")
	check(w.rooms.set_floor(Vector2i(3,3),"farmland")["ok"],"floor can become farmland")
	check(w.rooms.farmland(Vector2i(3,3)),"single shared till state")
	check(w.rooms.set_floor(Vector2i(3,3),"natural")["ok"],"farmland can be removed")
	check(w.inventory.count("raw_wood")==cash_before-1,"no floor refund")
	check(w.environment[ground_index]==ground_before,"pave, convert and remove preserve real water and fertility")
	check(w.logistics.agri["remainders"]["water"]["3,3"]==50 and w.logistics.agri["remainders"]["fertility"]["3,3"]==50,"paving never clears fractional resource use")
	w.logistics.provision()
	for spec in [[5,4,"east","trial-004"],[9,4,"west","trial-008"],[7,2,"south","trial-010"]]:
		var cell:=Vector2i(spec[0],spec[1])
		w.rooms.set_floor(cell,"ordinary")
		var built: Dictionary=w.build_facility(cell,"field_service_station",spec[2])
		check(built["ok"],"single-cell host builds "+str(built))
		if not built["ok"]: quit(1); return
		var uid: int=w.facility_at(cell)["uid"]
		check(w.logistics.deploy(spec[3],Vector2i(-1,-1),uid)["ok"],"agri gu admitted")
		check(w.devices._coverage(uid).size==Vector2i(5,5),"ordinary service now 5x5")
		check(w.devices.configure_station(uid,false,false,30)["ok"],"isolate effect fixture from ordinary service")
	for y in range(3,6):
		for x in range(6,9): check(w.till(Vector2i(x,y))["ok"],"till shared nine-cell field")
	register_fields(w)
	w.end_day()
	var regions: Array=w.rooms.regions(w.clock.total_days)
	check(regions.size()==1 and regions[0]["level"]==3 and regions[0]["cells"].size()==9,"three sources form tier3 without center building")
	for y in range(3,6):
		for x in range(6,9): check(w.plant(Vector2i(x,y),"golden_wheat")["ok"],"room wheat planted")
	check(Codec.normalize(w.to_snapshot())["ok"],"growing room snapshot valid")
	for i in range(3): w.end_day()
	var crop: Dictionary=w.instance_at(Vector2i(6,3))
	check(crop["state"]=="mature","three effective days mature wheat")
	var reward: Dictionary=w.rooms.state["plants"][str(crop["uid"])]
	check(reward["growth"]==400 and reward["seed_work"]==400 and reward["material_work"]==400,"actual capped progress qualifies both channels")
	check(reward["seed_checked"] and reward["frozen"],"first maturity freezes seed")
	var snapshot: Dictionary=w.to_snapshot()
	check(Codec.normalize(snapshot)["ok"],"mature snapshot valid")
	var result: Dictionary=w.harvest(Vector2i(6,3))
	check(result["ok"] and int(result["base_items"].get("grain",0))==3 and int(result["base_items"].get("straw",0))==2,"base yield remains distinct "+str(result))
	check(result["room_rewards"]["material"].get("straw",0)==0,"no byproduct amplification")
	check(not w.harvest(Vector2i(6,3))["ok"],"cannot claim same crop twice")
	check(Codec.normalize(w.to_snapshot())["ok"],"claimed snapshot valid")
	check(w.apply_snapshot(snapshot)["ok"],"restore mature snapshot")
	var again: Dictionary=w.harvest(Vector2i(6,3))
	check(again["items"]==result["items"],"reload does not reroll")
	for n in [3,6,8]:
		for roll in [0,249999,500000,749999,999999]:
			var award: int=Rooms.award(n,400,400,roll)
			check(award>=n/4 and award<=ceili(float(n)/4),"random-rounding bounds")
	var wins:=0
	for id in range(4000):
		wins+=Rooms.award(1,400,400,Rooms.draw(1729,"crop:"+str(id),0,"seed"))
	check(wins>=850 and wins<=1150,"independent identities approximate 25 percent")
	var damaged: Dictionary=w.to_snapshot()
	var first: String=damaged["world"]["rooms"]["plants"].keys()[0]
	damaged["world"]["rooms"]["plants"][first]["material_work"]=99999
	check(not Codec.normalize(damaged)["ok"],"forged contribution rejected")
	_geometry_and_regions()
	_contribution_changes()
	_regrow_and_clear()
	_independent_gu()
	_ordinary_service()
	_transaction()
	_pollination_transaction()
	_invalid_rooms()
	_old_disk_slots()
	_large_irregular_room()
	print("P102 MODEL %s (%d)" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func room_fixture():
	var w=fixture()
	w.logistics.provision()
	for spec in [[5,4,"east","trial-004"],[9,4,"west","trial-008"],[7,2,"south","trial-010"]]:
		var cell:=Vector2i(spec[0],spec[1])
		w.rooms.set_floor(cell,"ordinary")
		var built: Dictionary=w.build_facility(cell,"field_service_station",spec[2])
		if not built["ok"]: printerr("invalid room fixture ",built); quit(1); return w
		var uid: int=w.facility_at(cell)["uid"]
		w.devices.configure_station(uid,false,false,30)
		w.logistics.deploy(spec[3],Vector2i(-1,-1),uid)
	for y in range(3,6):
		for x in range(6,9): w.till(Vector2i(x,y))
	register_fields(w)
	w.end_day()
	return w

func _geometry_and_regions() -> void:
	for spec in [["east",Rect2i(6,4,3,3)],["south",Rect2i(4,6,3,3)],["west",Rect2i(2,4,3,3)],["north",Rect2i(4,2,3,3)]]:
		check(Logistics.directed_zone(Vector2i(5,5),[1,1],spec[0])==spec[1],"one-cell facing "+spec[0])
	var w=room_fixture()
	var before: Dictionary=w.to_snapshot()
	var preview: Dictionary=w.rooms.preview_floor(Vector2i(6,2),"farmland")
	check(preview["ok"] and not preview["downgrade"],"unassigned floor does not change field boundary")
	check(w.to_snapshot()==before,"floor preview changes no state")
	w.till(Vector2i(6,2))
	check(w.rooms.regions(w.clock.total_days)[0]["level"]==3,"unassigned uncovered cell does not downgrade field")
	var expanded: Array=w.rooms.state["fields"][0]["cells"].duplicate()
	expanded.append("6,2")
	check(w.rooms.edit_field(1,expanded)["ok"],"explicit expansion")
	check(w.rooms.regions(w.clock.total_days)[0]["level"]<3,"explicit uncovered expansion removes tier3")
	expanded.erase("6,2")
	w.rooms.edit_field(1,expanded)
	w.rooms.set_floor(Vector2i(6,2),"ordinary")
	w.till(Vector2i(4,3));w.till(Vector2i(5,3))
	check(w.rooms.regions(w.clock.total_days).size()==1,"new bridge never creates or merges ownership")
	check(not w.rooms.quote_floor(Vector2i(0,14),"ordinary")["ok"],"floor cannot pave water")
	check(not w.rooms.quote_floor(Vector2i(25,4),"ordinary")["ok"],"floor cannot pave unowned land")
	check(not w.rooms.quote_floor(Vector2i(15,8),"ordinary")["ok"],"floor cannot cover natural source")
	check(not w.build_facility(Vector2i(6,3),"field_service_station")["ok"],"station cannot hide a farmland bridge")
	# Two growth sources cover each cell, but neither encloses the full 2x2 object.
	var s=fixture()
	s.logistics.provision()
	for spec in [[5,3,"south","trial-004"],[8,3,"south","trial-007"],[5,4,"east","trial-008"],[6,3,"south","trial-010"]]:
		var cell:=Vector2i(spec[0],spec[1])
		s.rooms.set_floor(cell,"ordinary")
		var built: Dictionary=s.build_facility(cell,"field_service_station",spec[2])
		if not built["ok"]: printerr("invalid split-source fixture ",built); quit(1); return
		var uid: int=s.facility_at(cell)["uid"]
		s.devices.configure_station(uid,false,false,30);s.logistics.deploy(spec[3],Vector2i(-1,-1),uid)
	for c in [Vector2i(6,4),Vector2i(7,4),Vector2i(6,5),Vector2i(7,5)]: s.till(c)
	register_fields(s)
	# Diagonal growth hosts need their own adjacent four-cell base field;
	# their directed service still tests single-source full-footprint coverage.
	for cells in [["4,2","5,2","6,2","7,2"],["8,4","9,4","8,5","9,5"]]:
		for text in cells: s.till(Rooms.cell_at(text))
	register_fields(s)
	s.end_day()
	var split_field: Dictionary=s.rooms.field_at(Vector2i(6,4))
	var region: Dictionary={}
	for candidate in s.rooms.regions(s.clock.total_days):
		if candidate["uid"]==split_field["uid"]: region=candidate
	check(region.get("level",0)==3,"cell masks can cover region from multiple sources")
	var q: Dictionary=s.rooms.qualification(Rect2i(6,4,2,2),["plant_grow"],s.clock.total_days)
	check(not q["seed"] and not q["material"],"two half-sources do not qualify a multi-cell plant")

func _contribution_changes() -> void:
	var w=room_fixture()
	w.plant(Vector2i(6,3),"golden_wheat")
	w.end_day() # 150 points in both channels.
	w.logistics.set_enabled("trial-010",false)
	w.end_day() # 150 seed-only points.
	w.logistics.set_enabled("trial-008",false)
	w.end_day() # Final 100 capped points without room rewards.
	var crop: Dictionary=w.instance_at(Vector2i(6,3))
	var r: Dictionary=w.rooms.state["plants"][str(crop["uid"])]
	check(r["growth"]==400 and r["seed_work"]==300 and r["material_work"]==150,"downgrades preserve separate actual contribution")
	check(r["seed_total"]==400 and r["seed_eligible"]==300,"first maturity freezes its contribution proof")
	var frozen: Dictionary=r.duplicate(true)
	w.end_day()
	check(w.rooms.state["plants"][str(crop["uid"]) ]==frozen,"mature waiting never increases contribution")
	check(Codec.normalize(w.to_snapshot())["ok"],"mixed-tier maturity valid")
	for roll in [0,124999,125000,999999]:
		check(Rooms.award(1,200,400,roll)==(1 if roll<125000 else 0),"half-qualified seed uses 12.5 percent boundary")
	check(Rooms.award(8,400,400,999999)==2,"integer material bonus draws no extra unit")
	check(Rooms.award(6,400,400,499999)==2 and Rooms.award(6,400,400,500000)==1,"material fractional boundary exact")
	check(Rooms.award(3,0,400,0)==0,"zero-qualified progress has no reward")
	for field in ["seed_claimed","seed_eligible","seed_total"]:
		var bad: Dictionary=w.to_snapshot()
		var row: Dictionary=bad["world"]["rooms"]["plants"][str(crop["uid"])]
		if field=="seed_claimed": row[field]=true
		else: row[field]=int(row[field])-1
		check(not Codec.normalize(bad)["ok"],"reject first-maturity tamper "+field)

func _regrow_and_clear() -> void:
	var w=room_fixture()
	check(w.plant(Vector2i(6,3),"resin_tree")["ok"],"room resin planted on four cells")
	for i in range(6): w.end_day()
	var crop: Dictionary=w.instance_at(Vector2i(6,3))
	var id:=str(crop["uid"])
	check(crop["state"]=="mature","resin reaches first maturity")
	var first: Dictionary=w.rooms.state["plants"][id].duplicate(true)
	var mature_snapshot: Dictionary=w.to_snapshot()
	var a: Dictionary=w.harvest(Vector2i(6,3))
	check(a["ok"] and a["room_rewards"]["material"].get("resin",0)==1,"full resin round yields fixed extra primary")
	check(w.rooms.state["plants"][id]["round"]==1 and w.rooms.state["plants"][id]["seed_claimed"],"tap advances round and consumes first seed chance")
	check(Codec.normalize(w.to_snapshot())["ok"],"regrowing snapshot preserves first seed proof")
	var alternative=fixture()
	check(alternative.apply_snapshot(mature_snapshot)["ok"],"same frozen maturity restores for alternate legal harvest mode")
	var felled: Dictionary=alternative.harvest(Vector2i(6,3),"fell")
	check(felled["room_rewards"]["seed"]==a["room_rewards"]["seed"],"tap versus fell cannot reroll frozen first seed")
	check(not felled["room_rewards"]["material"].has("twig") and not alternative.rooms.state["plants"].has(id),"mature felling only boosts registered wood and retires its rights")
	for i in range(2): w.end_day()
	var second: Dictionary=w.rooms.state["plants"][id]
	check(second["growth"]==300 and second["material_work"]==300,"regrowth tracks its own target and qualification")
	check(second["seed_total"]==first["seed_total"] and second["seed_award"]==first["seed_award"],"regrowth cannot reroll first seed")
	var b: Dictionary=w.harvest(Vector2i(6,3))
	check(b["room_rewards"]["seed"].is_empty() and b["room_rewards"]["material"].get("resin",0)==1,"second round only pays fresh material")
	check(Codec.normalize(w.to_snapshot())["ok"],"second claimed round valid")
	var m=room_fixture()
	m.plant(Vector2i(6,3),"golden_wheat")
	for i in range(3): m.end_day()
	var mature: Dictionary=m.instance_at(Vector2i(6,3))
	var seed: int=m.rooms.state["plants"][str(mature["uid"])]["seed_award"]
	var stock: int=m.inventory.count("golden_wheat_seed")
	var grain: int=m.inventory.count("grain")
	m.clear_crop(Vector2i(6,3))
	check(m.inventory.count("golden_wheat_seed")==stock+seed and m.inventory.count("grain")==grain,"mature clearing only pays pending seed, no material")
	check(not m.rooms.state["plants"].has(str(mature["uid"])) and Codec.normalize(m.to_snapshot())["ok"],"clearing removes award identity cleanly")
	m.plant(Vector2i(6,3),"golden_wheat")
	stock=m.inventory.count("golden_wheat_seed")
	m.clear_crop(Vector2i(6,3))
	check(m.inventory.count("golden_wheat_seed")==stock,"immature clearing does not mint seed")

func _independent_gu() -> void:
	var w=room_fixture()
	check(w.logistics.deploy("trial-001",Vector2i(6,3))["ok"],"rice gu deploys on farmland")
	w.end_day()
	check(Codec.normalize(w.to_snapshot())["ok"],"rice job snapshot contains room progress")
	w.end_day();w.end_day()
	var row: Dictionary=w.logistics.instance("trial-001")
	check(row["job"].get("ready",false),"room rice ready after boosted production")
	check(w.rooms.state["gu_rounds"]["trial-001"]["material_work"]==300,"rice records capped actual work")
	check(Codec.normalize(w.to_snapshot())["ok"],"rice ready snapshot valid")
	var result: Dictionary=w.logistics.claim("trial-001")
	check(result["items"].get("rice",0)==5,"full rice round pays four base and one extra")
	check(w.rooms.state["gu_rounds"]["trial-001"]["seed_award"]==0,"rice never creates gu seeds")
	check(Codec.normalize(w.to_snapshot())["ok"],"rice claimed snapshot valid")
	w.end_day();w.logistics.cancel_job("trial-001")
	check(Codec.normalize(w.to_snapshot())["ok"],"cancelled rice round resets qualification")
	var wild=fixture();wild.logistics.provision();wild.logistics.deploy("trial-001",Vector2i(6,3))
	for i in range(4): wild.end_day()
	check(wild.logistics.claim("trial-001")["items"].get("rice",0)==4,"wild rice retains base production with no room bonus")

func _ordinary_service() -> void:
	var w=fixture();w.logistics.provision()
	w.rooms.set_floor(Vector2i(5,4),"ordinary")
	w.build_facility(Vector2i(5,4),"field_service_station")
	var uid: int=w.facility_at(Vector2i(5,4))["uid"]
	w.logistics.deploy("trial-004",Vector2i(-1,-1),uid)
	w.logistics.set_enabled("trial-004",false)
	for c in [Vector2i(6,3),Vector2i(7,3),Vector2i(6,4),Vector2i(7,4)]: w.till(c)
	register_fields(w)
	var index: int=w.grid.index_of(Vector2i(6,3))
	w.environment[index][0]=0;w.environment[index][1]=0
	var water: int=w.inventory.count("clean_water");var humus: int=w.inventory.count("humus")
	w.end_day()
	check(w.environment[index][0]==30 and w.environment[index][1]==30,"dormant gu leaves ordinary water and fertilizer service active")
	check(w.inventory.count("clean_water")==water-1 and w.inventory.count("humus")==humus-1,"ordinary service spends actual stock")
	check(not w.logistics.active(w.logistics.instance("trial-004"),w.clock.total_days),"ordinary service does not activate dormant gu")
	var limit=fixture()
	limit.rooms.set_floor(Vector2i(5,4),"ordinary")
	limit.build_facility(Vector2i(5,4),"field_service_station")
	var station: int=limit.facility_at(Vector2i(5,4))["uid"]
	limit.devices.configure_station(station,true,true,90)
	var cells:=[]
	for y in range(2,6):
		for x in range(3,8):
			var c:=Vector2i(x,y)
			if c==Vector2i(5,4): continue
			limit.till(c);cells.append(c)
			var i: int=limit.grid.index_of(c)
			limit.environment[i][0]=0;limit.environment[i][1]=0
	register_fields(limit)
	water=limit.inventory.count("clean_water");humus=limit.inventory.count("humus")
	limit.end_day()
	var served:=0
	for c in cells:
		if limit.environment_at(c)["water"]==30: served+=1
	check(served==6 and limit.inventory.count("clean_water")==water-6 and limit.inventory.count("humus")==humus-6,"one-cell station retains independent six-cell quotas with real inputs")
	check(limit.devices.device_of(station)["cursor"]["irrigate"]==6 and limit.devices.device_of(station)["cursor"]["fertilize"]==6,"service cursors advance after six targets")
	limit.end_day()
	served=0
	for c in cells:
		if limit.environment_at(c)["water"]>0: served+=1
	check(served==12,"next opening rotates to six different low cells")

class FailingStore extends RefCounted:
	var inner
	var failing:=false
	func _init(store): inner=store
	func active_slot() -> int: return inner.active_slot()
	func create_slot(slot: int,value: Dictionary,overwrite: bool=false) -> Dictionary: return inner.create_slot(slot,value,overwrite)
	func open_slot(slot: int) -> Dictionary: return inner.open_slot(slot)
	func commit(value: Dictionary) -> Dictionary: return {"ok":false,"reason":"P102 isolated write failure"} if failing else inner.commit(value)

func _transaction() -> void:
	var w=room_fixture()
	w.plant(Vector2i(6,3),"golden_wheat")
	for i in range(3): w.end_day()
	var store=FailingStore.new(Store.new("res://.art-work/p102-model/transaction-%d" % Time.get_ticks_usec()))
	check(store.create_slot(1,w.to_snapshot())["ok"],"real disk slot created from room fixture")
	w._store=store
	w.clock.ap=1
	var before: Dictionary=w.to_snapshot()
	store.failing=true
	w.harvest(Vector2i(6,3))
	check(not w.daily_save_error.is_empty() and w.to_snapshot()==before,"last-AP harvest failure restores crop, stock and room rights")
	var candidate: Dictionary=w._pending_day.duplicate(true)
	check(not candidate.is_empty() and Codec.normalize(candidate)["ok"],"failed harvest retains valid frozen candidate")
	check(not w.retry_day_save()["ok"] and w.to_snapshot()==before,"failed retry publishes no bonus")
	store.failing=false
	check(w.retry_day_save()["ok"] and w.to_snapshot()==candidate,"retry publishes original candidate once")
	check(not w.retry_day_save()["ok"],"second retry cannot duplicate rewards")
	check(w.open_game(1)["ok"] and w.to_snapshot()==candidate,"disk reload preserves settled stock and rights")
	w.clock.ap=1
	before=w.to_snapshot();store.failing=true
	w.rooms.set_floor(Vector2i(6,3),"ordinary")
	check(not w.daily_save_error.is_empty() and w.to_snapshot()==before,"last-AP floor failure restores connectivity, cost and provenance")
	candidate=w._pending_day.duplicate(true);store.failing=false
	check(w.retry_day_save()["ok"] and w.to_snapshot()==candidate,"floor retry publishes exact candidate")

func _pollination_transaction() -> void:
	var w=room_fixture()
	w.plant(Vector2i(6,3),"oilseed_flower")
	w.end_day();w.end_day()
	var uid: int=w.instance_at(Vector2i(6,3))["uid"]
	check(w.flowers.consume(uid,"hive-test")["ok"],"isolated legitimate flower-share consumer pollinates oilseed")
	check(w.pick_flower(Vector2i(6,3))["ok"]==false,"spent flower share cannot be picked again")
	check(not w.rooms.state["plants"][str(uid)]["seed_checked"],"flower draw before maturity does not trigger seed roll")
	w.end_day();w.end_day()
	var before: Dictionary=w.to_snapshot()
	check(Codec.normalize(before)["ok"],"pollinated room crop ready snapshot valid")
	var result: Dictionary=w.harvest(Vector2i(6,3))
	check(result["base_items"].get("oilseed",0)==5 and result["base_items"].get("flower_petal",0)==1,"normal pollination bonus belongs to base primary yield")
	check(result["room_rewards"]["material"].get("oilseed",0) in [1,2] and not result["room_rewards"]["material"].has("flower_petal"),"room adds randomized 25 percent to pollinated primary only")
	w.apply_snapshot(before)
	var store=FailingStore.new(Store.new("res://.art-work/p102-model/clear-%d" % Time.get_ticks_usec()))
	check(store.create_slot(1,w.to_snapshot())["ok"],"pollinated clear disk slot created")
	w._store=store;w.clock.ap=1
	before=w.to_snapshot();store.failing=true
	w.clear_crop(Vector2i(6,3))
	check(not w.daily_save_error.is_empty() and w.to_snapshot()==before and w.flowers.pollinated(uid),"failed mature clear restores flower mark and pending seed")
	var candidate: Dictionary=w._pending_day.duplicate(true)
	check(Codec.normalize(candidate)["ok"],"clear candidate includes flower cleanup before save")
	store.failing=false
	check(w.retry_day_save()["ok"] and w.to_snapshot()==candidate,"clear retry publishes stock, cleanup and rights together")
	check(w.open_game(1)["ok"] and w.to_snapshot()==candidate,"mature clear survives real disk reopen")

func _invalid_rooms() -> void:
	var w=room_fixture()
	w.plant(Vector2i(6,3),"golden_wheat")
	var before: Dictionary=w.to_snapshot()
	for kind in ["missing","floor_unknown","floor_water","floor_unowned","floor_source","floor_occupied","floor_alias","plant_missing","plant_orphan","random_zero","frozen_early","seed_early","gu_orphan"]:
		var bad: Dictionary=before.duplicate(true)
		var rooms: Dictionary=bad["world"]["rooms"]
		var plant: Dictionary=rooms["plants"].values()[0]
		match kind:
			"missing": bad["world"].erase("rooms")
			"floor_unknown": rooms["floors"]["3,3"]="hard"
			"floor_water": rooms["floors"]["0,14"]="ordinary"
			"floor_unowned": rooms["floors"]["25,4"]="ordinary"
			"floor_source": rooms["floors"]["15,8"]="ordinary"
			"floor_occupied": rooms["floors"]["6,3"]="ordinary"
			"floor_alias": rooms["floors"]["03,3"]="ordinary"
			"plant_missing": rooms["plants"].clear()
			"plant_orphan": rooms["plants"]["999"]=rooms["plants"].values()[0].duplicate(true)
			"random_zero": rooms["random_seed"]=0
			"frozen_early": plant["frozen"]=true
			"seed_early": plant["seed_checked"]=true;plant["seed_total"]=400
			"gu_orphan": rooms["gu_rounds"]["absent"]=Rooms.round_state(300)
		check(not Codec.normalize(bad)["ok"],"reject room state corruption "+kind)
	check(Codec.normalize(before)["ok"],"corruption probes leave pristine room fixture valid")

func _old_disk_slots() -> void:
	var directory:="res://.art-work/p102-model/old-slots-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var store=Store.new(directory)
	var w=World.new(store)
	var before: Dictionary=w.to_snapshot()
	for schema in [17,18,19,20,21,22]:
		var old: Dictionary=before.duplicate(true);old["schema"]=schema
		var text:=JSON.stringify(old)
		var envelope:=JSON.stringify({"schema":1,"slot_id":1,"saved_at":0,"snapshot_json":text,"checksum":text.sha256_text()})
		for suffix in ["",".bak"]:
			var f:=FileAccess.open(store.slot_path(1)+suffix,FileAccess.WRITE)
			f.store_string(envelope);f.close()
		var result: Dictionary=w.open_game(1)
		check(not result["ok"] and String(result["reason"]).contains("重新开档"),"old disk slot explicitly requests new game "+str(schema))
		check(w.to_snapshot()==before and store.active_slot()==0,"rejected old disk slot leaves world and session untouched "+str(schema))
		check(FileAccess.get_file_as_string(store.slot_path(1))==envelope and FileAccess.get_file_as_string(store.slot_path(1)+".bak")==envelope,"old primary and backup preserved byte-for-byte "+str(schema))
		check(not store.create_slot(1,before)["ok"],"old slot cannot be overwritten without explicit confirmation "+str(schema))

func _large_irregular_room() -> void:
	var w=fixture();w.logistics.provision()
	# Two adjacent service modules form one irregular 16-cell field. The two
	# inner hosts are holes, not bridges; each 2x2 crop still has whole sources.
	for spec in [[5,4,"east","trial-004"],[12,4,"west","trial-007"],[7,2,"south","trial-008"],[10,2,"south","trial-009"],[9,4,"west","trial-010"],[8,4,"east","trial-011"]]:
		var c:=Vector2i(spec[0],spec[1])
		w.rooms.set_floor(c,"ordinary")
		var built: Dictionary=w.build_facility(c,"field_service_station",spec[2])
		check(built["ok"],"irregular module host builds "+str(c))
		if not built["ok"]: return
		var uid: int=w.facility_at(c)["uid"]
		w.devices.configure_station(uid,false,false,30);w.logistics.deploy(spec[3],Vector2i(-1,-1),uid)
	for y in range(3,6):
		for x in range(6,12):
			var c:=Vector2i(x,y)
			if not w.facility_at(c).is_empty(): continue
			check(w.till(c)["ok"],"irregular field tile "+str(c))
	register_fields(w)
	w.end_day()
	var regions: Array=w.rooms.regions(w.clock.total_days)
	check(regions.size()==1 and regions[0]["cells"].size()==16 and regions[0]["level"]==3,"multiple modules support one irregular field larger than 3x3")
	for rect in [Rect2i(6,3,2,2),Rect2i(10,3,2,2)]:
		var q: Dictionary=w.rooms.qualification(rect,["plant_grow"],w.clock.total_days)
		check(q["seed"] and q["material"],"each large crop has a complete source per channel "+str(rect))
	check(w.plant(Vector2i(6,3),"fast_fir")["ok"] and w.plant(Vector2i(10,3),"resin_tree")["ok"],"two real multi-cell plants fit around internal hosts")
	w.end_day()
	for crop in w.crops.values():
		var data: Dictionary=w.rooms.state["plants"][str(crop["uid"])]
		check(data["growth"]==150 and data["seed_work"]==150 and data["material_work"]==150,"irregular full-room growth qualifies real work")
	check(Codec.normalize(w.to_snapshot())["ok"],"irregular multi-module room saves strictly")

# Fixture construction explicitly registers selected farmland; production code
# never calls this flood-fill helper or automatically claims new floor tiles.
func register_fields(w) -> void:
	var pending := {}
	for y in range(w.grid.bounds().position.y,w.grid.bounds().end.y):
		for x in range(w.grid.bounds().position.x,w.grid.bounds().end.x):
			var c:=Vector2i(x,y)
			if w.rooms.farmland(c) and w.rooms.field_at(c).is_empty(): pending[c]=true
	while not pending.is_empty():
		var todo: Array=[pending.keys()[0]]
		pending.erase(todo[0])
		var selected: Array=[]
		while not todo.is_empty():
			var c: Vector2i=todo.pop_front()
			selected.append(w.rooms.key(c))
			for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if pending.has(c+step): pending.erase(c+step);todo.append(c+step)
		check(w.rooms.create_field(selected)["ok"],"explicit fixture field")
	for uid in w.facilities:
		var host: Dictionary=w.facilities[uid]
		if host["facility_id"]!="field_service_station": continue
		var c:=Vector2i(host["origin"][0],host["origin"][1])
		check(w.rooms.floor_kind(c)=="ordinary","host base floor")
		for field in w.rooms.state["fields"]:
			var adjacent:=false
			for text in field["cells"]:
				var at:=Rooms.cell_at(text)
				if absi(at.x-c.x)+absi(at.y-c.y)==1: adjacent=true
			if adjacent and field["cells"].size()>=4:
				check(w.services.link_agriculture(int(uid),int(field["uid"]))["ok"],"explicit station association")
				break
