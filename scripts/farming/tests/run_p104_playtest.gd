extends "res://scripts/farming/tests/run_phase104.gd"
## Each partition is independent and <=30 days. Never overwrites evidence.
var evidence_root:="res://.art-work/p104-playtest/core-v1"
var route:=""
var trace:=[]
var all_results:={}

func run() -> void:
	var cases: Array=["structure","hosts","toy","breeding","work","compound"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--root="): evidence_root=arg.substr(7)
		if arg.begins_with("--cases="): cases=Array(arg.substr(8).split(","))
	for name in cases:
		route=String(name)
		if route not in ["structure","hosts","toy","breeding","work","compound","breeding-base","work-base"]:
			printerr("Unknown partition: ",route);quit(1);return
		var directory:=evidence_root.path_join(route)
		if FileAccess.file_exists(directory.path_join("scenario.json")):
			printerr("Evidence exists; select a new root or archive this partition: ",directory);quit(1);return
		var start:=checks
		var start_failures:=failures.size()
		trace=[]
		var w: World=World.new() if route=="toy" else service_fixture()
		var opening: Dictionary=w.to_snapshot()
		w.operation_recorded.connect(func(row): trace.append(row.duplicate(true)))
		match route:
			"toy": _craft_toy(w)
			"structure": _structure(w)
			"hosts": _hosts(w)
			_: _cycles(w)
		var closing: Dictionary=w.to_snapshot()
		var valid: Dictionary=Codec.normalize(closing)
		check(valid["ok"],route+" final codec: "+str(valid.get("reason","")))
		check(int(closing["clock"]["total_days"])-int(opening["clock"]["total_days"])<=30,"partition <=30 days")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		var failed: Array=failures.slice(start_failures)
		var file:=FileAccess.open(directory.path_join("scenario.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"kind":"p104-module","route":route,"fixture":route!="toy","checks":checks-start,
			"failures":failed,"opening":opening,"closing":closing,"receipts":trace},"  "))
		file.close()
		all_results[route]={"checks":checks-start,"failures":failed,"days":int(closing["clock"]["total_days"])-int(opening["clock"]["total_days"])}
		print("P104 PARTITION %s %s (%d)" % [route,"OK" if failed.is_empty() else "FAIL",checks-start])
	var summary:=FileAccess.open(evidence_root.path_join("summary-%d.json" % Time.get_ticks_usec()),FileAccess.WRITE)
	summary.store_string(JSON.stringify(all_results,"  "));summary.close()
	print("P104 PLAYTEST %s (%d)" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func _craft_toy(w: World) -> void:
	for order in [["raw_wood",5],["raw_stone",4],["twig",2],["straw",2]]:
		check(w.buy(order[0],order[1])["ok"],"buy actual material "+order[0])
	check(w.build_facility(Vector2i(4,1),"woodshop")["ok"],"build ordinary woodshop without research")
	var shop: int=w.facility_at(Vector2i(4,1))["uid"]
	for recipe in ["saw_planks","make_vine_ball"]:
		var batch: Dictionary=w.start_batch(shop,recipe)
		check(batch["ok"],"start actual "+recipe)
		check(w.end_day()["ok"],"processing day")
		check(w.claim_batch(shop,int(batch.get("batch_id",0)))["ok"],"claim actual "+recipe)
	check(w.inventory.count("vine_ball")==1,"one ball manufactured")
	check(w.rooms.set_floor(Vector2i(8,1),"ordinary")["ok"],"pave station")
	check(w.build_facility(Vector2i(8,1),"toy_station")["ok"],"build toy station")
	var uid: int=w.facility_at(Vector2i(8,1))["uid"]
	check(w.services.install_toy(uid,true)["ok"] and w.inventory.count("vine_ball")==0,"install actual product")
	check(not w.services.install_toy(uid,true)["ok"],"duplicate install rejected")
	check(w.services.install_toy(uid,false)["ok"] and w.inventory.count("vine_ball")==1,"unload actual durable")
	check(not w.services.install_toy(uid,false)["ok"],"duplicate unload rejected")
	check(w.research.state["completed"].is_empty(),"no recipe unlock required")

func _structure(w: World) -> void:
	var care: int=w.facility_at(Vector2i(10,3))["uid"]
	check(w.demolish_facility(care)["ok"],"remove required structure")
	check(w.end_day()["ok"],"failed care day still settles")
	check(int(w.ranch.animal(1)["breed"]["units"])==0 and int(w.ranch.animal(1)["fatigue"])==12,"no breeding; maintenance failure causes fatigue")
	check(w.build_facility(Vector2i(10,3),"care_table")["ok"],"restore base facility")
	w.end_day()
	check(int(w.ranch.animal(1)["breed"]["units"])==0,"open-day fatigue prevents retrospective breeding")
	w.end_day()
	check(int(w.ranch.animal(1)["breed"]["units"])==900,"qualified breeding resumes")

func _hosts(w: World) -> void:
	w.logistics.set_enabled("trial-012",false)
	w.logistics.set_enabled("trial-014",false)
	w.end_day()
	check(int(w.ranch.animal(1)["breed"]["units"])==600,"ordinary breeding survives inactive gu")
	check(int(w.ranch.animal(2)["account"]["w"])==4,"ordinary work survives inactive gu")
	check(w.services.state["pools"].is_empty(),"no tier3 overflow from ordinary progress")
	w.logistics.set_enabled("trial-012",true)
	w.logistics.set_enabled("trial-014",true)
	w.end_day();w.end_day()
	check(int(w.ranch.animal(1)["breed"]["units"])>1800,"restored gu adds future progress")

func _cycles(w: World) -> void:
	var yard: int=w.facility_at(Vector2i(5,7))["uid"]
	if route=="breeding-base": w.logistics.set_enabled("trial-012",false)
	if route=="work-base": check(w.services.set_system(1,"without-work-synergy",[1,2,3,4])["ok"],"control keeps same assets and gu")
	var days:=12 if route=="compound" else (8 if route=="breeding-base" else 6)
	var first_birth:=-1
	for index in range(days):
		w.ranch.claim_workyard(yard)
		check(w.end_day()["ok"],"actual module day "+str(index))
		if bool(w.ranch.animal(1)["breed"]["pending"]):
			if first_birth<0: first_birth=index+1
			check(w.ranch.claim_births(2)["ok"],"place actual offspring")
		if route=="compound":
			for child in w.ranch.state["animals"]:
				if int(child["uid"])>2 and String(child["mode"])=="waiting":
					check(w.ranch.submit({"assign":{int(child["uid"]):{"mode":"work","zone_uid":3}}})["ok"],"offspring joins production chain")
		check(Codec.normalize(w.to_snapshot())["ok"],"daily codec")
	if route in ["breeding","compound"]: check(first_birth==6,"150 percent yields first mole offspring on sixth day")
	if route=="breeding-base": check(first_birth==8,"unboosted control first offspring on eighth day")
	if route in ["work","compound"]:
		check(w.services.state["history"].any(func(e):return e["stage"]=="pool_use"),"earned overflow reused after real input")
	if route=="work-base": check(w.services.state["pools"].is_empty(),"control cannot earn work synergy")
	if route=="compound":
		check(w.ranch.state["births"].size()==2,"two actual breeding rounds")
		check(w.ranch.state["animals"].any(func(a):return int(a["uid"])>2 and a["mode"]=="work"),"grown offspring works")
