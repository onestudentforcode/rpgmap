extends "res://scripts/farming/tests/run_phase104.gd"
## One 60-day integration milestone, explicitly scaffolded, never a profit test.
## Covers shared agriculture/ranch/processing/research/water/save paths.
var events:=[]
var coverage:={"agriculture_claims":0,"material_rewards":0,"seed_rewards":0,"processing":0,"fish_claims":0,"research_work":0,"reloads":0,"shifts":0}

func fixture() -> World:
	var w:=World.new()
	w.grant_scaffold({"raw_wood":5200,"raw_stone":200,"wood_plank":50,"mushroom":800,"fodder_grass":200,"grain":200,"clean_water":400,"land_feed":100,"iron_ore":100})
	# Fund the scaffold through a recorded real trade so the day-45 cash recap
	# still balances. This sale of injected stock is never counted as profit.
	check(w.sell("raw_wood",5000)["ok"],"explicit scaffold funding trade")
	w.research.state["completed"]=w.research.project_defs().keys()
	return w

func run() -> void:
	var output:="res://.art-work/p104-smoke/final-v1.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.substr(9)
	if FileAccess.file_exists(output): printerr("Smoke evidence exists: ",output);quit(1);return
	var w:=service_fixture()
	w.grant_scaffold({"golden_wheat_seed":80,"humus":800,"mushroom":800,"algae_feed":80,"iron_ingot":10})
	for spec in [[12,4,"east","trial-004"],[16,4,"west","trial-008"],[14,2,"south","trial-010"]]:
		var c:=Vector2i(spec[0],spec[1])
		check(w.rooms.set_floor(c,"ordinary")["ok"],"smoke agriculture base floor")
		var built: Dictionary=w.build_facility(c,"field_service_station",spec[2])
		check(built["ok"],"smoke agriculture host "+str(built))
		if not built["ok"]: quit(1);return
		check(w.logistics.deploy(spec[3],Vector2i(-1,-1),int(w.facility_at(c)["uid"]))["ok"],"smoke agriculture gu")
	var cells:=[]
	for y in range(3,6):
		for x in range(13,16):
			check(w.till(Vector2i(x,y))["ok"],"smoke farmland")
			cells.append("%d,%d" % [x,y])
	var field: Dictionary=w.rooms.create_field(cells,"整合农业田")
	check(field["ok"],"smoke explicit field")
	for c in [Vector2i(12,4),Vector2i(16,4),Vector2i(14,2)]:
		check(w.services.link_agriculture(int(w.facility_at(c)["uid"]),int(field["uid"]))["ok"],"smoke agriculture association")
	for spec in [[17,3,"woodshop"],[18,7,"research_bench"],[0,14,"fish_pond"]]:
		var built: Dictionary=w.build_facility(Vector2i(spec[0],spec[1]),spec[2])
		check(built["ok"],"smoke integration facility "+spec[2]+str(built))
		if not built["ok"]: quit(1);return
	var shop: int=w.facility_at(Vector2i(17,3))["uid"]
	var bench: int=w.facility_at(Vector2i(18,7))["uid"]
	var pond: int=w.facility_at(Vector2i(0,14))["uid"]
	# Reopen one dependency-free project in this explicitly labelled fixture.
	w.research.state["completed"].erase("flower_cultivation")
	check(w.research.start(bench,"flower_cultivation")["ok"],"smoke real research start")
	check(w.husbandry.purchase(pond,1)["ok"],"smoke fish stocking")
	w.end_day()
	var store:=Store.new("res://.art-work/p104-smoke/slots-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	check(store.create_slot(1,w.to_snapshot())["ok"],"smoke actual disk slot")
	w._store=store
	var opening: Dictionary=w.to_snapshot()
	w.operation_recorded.connect(func(row): events.append(row.duplicate(true)))
	var start:=w.clock.total_days
	var yard: int=w.facility_at(Vector2i(5,7))["uid"]
	for step in range(60):
		var day:=w.clock.total_days
		check(day==start+step,"exact smoke day")
		for item in ["clean_water","raw_stone","raw_wood","grain"]:
			if w.inventory.count(item)<20: check(w.buy(item,100)["ok"],"smoke paid restock "+item)
		w.ranch.claim_workyard(yard)
		if bool(w.ranch.animal(1)["breed"]["pending"]) and w.ranch.state["animals"].size()<5:
			check(w.ranch.claim_births(2)["ok"],"smoke real offspring placement")
		for animal in w.ranch.state["animals"]:
			if int(animal["uid"])>2 and animal["mode"]=="waiting":
				check(w.ranch.submit({"assign":{int(animal["uid"]):{"mode":"work","zone_uid":3,"pattern":"late"}}})["ok"],"smoke grown offspring late shift")
				coverage["shifts"]+=1
		for c in [Vector2i(13,3),Vector2i(14,3),Vector2i(15,3)]:
			var crop: Dictionary=w.instance_at(c)
			if not crop.is_empty() and crop["state"]=="mature":
				var claim: Dictionary=w.harvest(c)
				check(claim["ok"],"smoke crop claim")
				coverage["agriculture_claims"]+=1
				for item in claim["room_rewards"]["material"]: coverage["material_rewards"]+=claim["room_rewards"]["material"][item]
				for item in claim["room_rewards"]["seed"]: coverage["seed_rewards"]+=claim["room_rewards"]["seed"][item]
			if w.instance_at(c).is_empty(): check(w.plant(c,"golden_wheat")["ok"],"smoke crop replant")
		var batch: Dictionary=w.facilities[shop]["batch"]
		if not batch.is_empty() and batch["status"]=="ready":
			check(w.claim_batch(shop,int(batch["batch_id"]))["ok"],"smoke ordinary processing claim")
			coverage["processing"]+=1
		if w.facilities[shop]["batch"].is_empty(): check(w.start_batch(shop,"saw_planks")["ok"],"smoke ordinary processing start")
		if w.research.work_quote(bench)["ok"]:
			check(w.research.work(bench)["ok"],"smoke real research work")
			coverage["research_work"]+=1
		if w.husbandry.quote_claim(pond)["ok"]:
			check(w.husbandry.claim(pond)["ok"],"smoke water animal claim")
			coverage["fish_claims"]+=1
			check(w.husbandry.purchase(pond,1)["ok"],"smoke restock water animal")
		if w.husbandry.quote_water(pond)["ok"]: check(w.husbandry.maintain_water(pond)["ok"],"smoke water exchange")
		if w.husbandry.quote_maintenance(pond)["ok"]: check(w.husbandry.maintain(pond)["ok"],"smoke water animal maintenance")
		check(w.clock.total_days==day,"smoke actions fit daily AP budget")
		check(w.end_day()["ok"] and w.daily_save_error.is_empty(),"smoke day transaction: "+w.daily_save_error)
		if not w.daily_save_error.is_empty(): quit(1);return
		check(Codec.normalize(w.to_snapshot())["ok"],"smoke daily strict codec")
		if step in [19,39,59]:
			var saved: Dictionary=w.to_snapshot()
			check(w.open_game(1)["ok"] and JSON.parse_string(JSON.stringify(saved))==JSON.parse_string(JSON.stringify(w.to_snapshot())),"smoke disk reload exact (canonical JSON)")
			coverage["reloads"]+=1
	check(w.ranch.state["births"].size()>=2,"smoke two breeding rounds")
	check(w.ranch.state["animals"].size()>=4 and coverage["shifts"]>=2,"smoke offspring working shifts")
	for key in coverage: check(coverage[key]>0,"smoke coverage "+key)
	check(w.services.state["history"].filter(func(e):return e["stage"]=="pool_use").size()>10,"smoke repeated earned carry")
	check(w.research.is_completed("flower_cultivation"),"smoke research completed")
	var closing: Dictionary=w.to_snapshot()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"kind":"p104-integration-smoke","fixture":true,"days":60,"coverage":coverage,"checks":checks,"failures":failures,"opening":opening,"closing":closing,"receipts":events},"  "));file.close()
	print("P104 SMOKE %s (%d), 60 days, %s" % ["OK" if failures.is_empty() else "FAIL",checks,str(coverage)])
	quit(0 if failures.is_empty() else 1)
