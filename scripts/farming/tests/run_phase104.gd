extends "res://scripts/farming/tests/run_phase103.gd"
## New service model: fixtures have explicit supplies; these are rule checks,
## not a claim of economic profitability.
func service_fixture() -> World:
	var w := _zone_fixture()
	w.grant_scaffold({"vine_ball":1,"twig":4,"straw":4})
	check(w.build_facility(Vector2i(8,3),"soothing_station")["ok"],"build soothe host")
	check(not w.facility_at(Vector2i(4,9)).is_empty(),"base fixture has toy station")
	var toy: int=w.facility_at(Vector2i(4,9))["uid"]
	check(w.services.install_toy(toy,true)["ok"],"durable toy installed")
	check(not w.services.install_toy(toy,true)["ok"],"duplicate installation rejected")
	w.logistics.provision()
	check(w.logistics.state["instances"].size()==15,"original provision and four new instances")
	check(not w.logistics.deploy("trial-012",Vector2i(-1,-1),int(w.facility_at(Vector2i(4,7))["uid"]))["ok"],"host tag admission rejects wrong use")
	check(w.logistics.deploy("trial-012",Vector2i(-1,-1),int(w.facility_at(Vector2i(8,3))["uid"]))["ok"],"soothe deployed")
	check(w.logistics.deploy("trial-014",Vector2i(-1,-1),int(w.facility_at(Vector2i(4,7))["uid"]))["ok"],"command deployed")
	check(w.services.set_system(0,"compound",[1,2,3,4,5])["ok"],"explicit compound membership")
	check(not w.services.set_system(0,"duplicate",[1])["ok"],"room cannot belong to two systems")
	check(w.ranch.purchase(1,"rock_mole",2)["ok"],"two juveniles bought")
	for i in range(3): check(w.end_day()["ok"],"normal nursery cycle")
	var animals: Array=w.ranch.state["animals"]
	check(animals.all(func(a):return a["stage"]=="adult"),"Q100 preserves three-day growth")
	var assignments:={int(animals[0]["uid"]):{"mode":"enclosure","zone_uid":2,"bed_uid":int(w.facility_at(Vector2i(10,2))["uid"]),"bed_slot":0},int(animals[1]["uid"]):{"mode":"work","zone_uid":3}}
	check(w.ranch.submit({"assign":assignments,"birth_targets":{2:1}})["ok"],"assign breeder and worker")
	w.end_day()
	return w

func run() -> void:
	var fresh_world:=World.new()
	check(Codec.normalize(fresh_world.to_snapshot())["ok"],"fresh service snapshot valid")
	var w:=service_fixture()
	var before: Dictionary=w.to_snapshot()
	var valid: Dictionary=Codec.normalize(before)
	check(valid["ok"],"configured snapshot valid: "+str(valid.get("reason","")))
	w.ranch.preview_next_day()
	check(w.to_snapshot()==before,"complete preview leaves state and RNG untouched")
	var breeder: Dictionary=w.ranch.animal(1)
	var worker: Dictionary=w.ranch.animal(2)
	check(breeder["mode"]=="enclosure" and worker["mode"]=="work","roles applied")
	check(w.end_day()["ok"],"first combined service day")
	check(int(breeder["breed"]["units"])==900,"six real care units at 150 percent")
	check(int(w.services.state["contributions"].get("1:0",{}).get("1",0))==900,"only actual qualified growth contributes")
	var pool_total:=0
	for pool in w.services.state["pools"].values(): pool_total+=int(pool["points"])
	check(pool_total==5000,"450 work points complete 400 and preserve 50")
	var toy: int=w.facility_at(Vector2i(4,9))["uid"]
	check(w.inventory.count("vine_ball")==0 and w.services.state["toys"].has(str(toy)),"services never consume durable toy")
	var after: Dictionary=w.to_snapshot()
	valid=Codec.normalize(after)
	check(valid["ok"],"serviced snapshot valid: "+str(valid.get("reason","")))
	_codec_probes(after)
	var downgraded:=World.new()
	check(downgraded.apply_snapshot(after)["ok"],"fork legitimate partial-downgrade scenario")
	downgraded.logistics.set_enabled("trial-012",false)
	downgraded.end_day()
	check(int(downgraded.ranch.animal(1)["breed"]["units"])==1500,"lost soothe removes speed only; ordinary care continues")
	check(Codec.normalize(downgraded.to_snapshot())["ok"],"legitimate inactive configuration can save")
	check(w.apply_snapshot(JSON.parse_string(JSON.stringify(after)))["ok"],"reload service state")
	var yard: int=w.facility_at(Vector2i(5,7))["uid"]
	for i in range(5):
		w.ranch.claim_workyard(yard)
		check(w.end_day()["ok"],"repeat combined service day")
	breeder=w.ranch.animal(1)
	check(bool(breeder["breed"]["pending"]),"accelerated breeder ready within six days")
	check(w.ranch.claim_births(2)["ok"],"birth receives historical contribution")
	var child: Dictionary=w.ranch.animal(3)
	check(int(child["growth"])==180,"full contribution grants ten percent initial growth")
	check(not w.ranch.claim_births(2)["ok"],"no duplicate child or initial growth")
	valid=Codec.normalize(w.to_snapshot())
	check(valid["ok"],"birth and pools persist: "+str(valid.get("reason","")))
	var forged: Dictionary=w.to_snapshot()
	for animal in forged["world"]["ranch"]["animals"]:
		if int(animal["uid"])==3: animal["growth"]=181
	check(not Codec.normalize(forged)["ok"],"newborn cannot forge extra initial growth")
	check(w.services.install_toy(toy,false)["ok"] and w.inventory.count("vine_ball")==1,"unload returns one durable toy")
	check(not w.services.install_toy(toy,false)["ok"] and w.inventory.count("vine_ball")==1,"unload cannot duplicate")
	_transaction_services()
	print("P104 MODEL %s (%d)" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func _transaction_services() -> void:
	var legacy=load("res://scripts/farming/tests/run_phase102.gd")
	var w:=service_fixture()
	var store=legacy.FailingStore.new(legacy.Store.new("res://.art-work/p104-model/rollback-%d" % Time.get_ticks_usec()))
	check(store.create_slot(1,w.to_snapshot())["ok"],"real service disk slot")
	w._store=store
	w.clock.ap=1
	var before: Dictionary=w.to_snapshot()
	store.failing=true
	w.services.install_toy(int(w.facility_at(Vector2i(4,9))["uid"]),false)
	check(not w.daily_save_error.is_empty() and w.to_snapshot()==before,"failed last-AP toy removal restores toy, inventory, gu fee, progress and histories")
	var candidate: Dictionary=w._pending_day.duplicate(true)
	check(not candidate.is_empty() and Codec.normalize(candidate)["ok"],"service candidate codec valid")
	check(not w.retry_day_save()["ok"] and w.to_snapshot()==before,"failed service retry does not publish")
	store.failing=false
	check(w.retry_day_save()["ok"] and w.to_snapshot()==candidate,"service retry publishes exact frozen candidate")
	check(not w.retry_day_save()["ok"],"service retry cannot duplicate")
	check(w.open_game(1)["ok"] and w.to_snapshot()==candidate,"actual disk reopen preserves service candidate")

func _codec_probes(snapshot: Dictionary) -> void:
	for kind in ["roll","repeat_toy","duplicate_install","pool","credit","candidate","contribution","source","missing"]:
		var forged: Dictionary=snapshot.duplicate(true)
		var services: Dictionary=forged["world"]["services"]
		var history: Array=services["history"]
		match kind:
			"roll":
				for event in history:
					if event["stage"]=="toy_service": event["roll"]=(int(event["roll"])+1)%100;break
			"repeat_toy":
				for event in history:
					if event["stage"]=="toy_service": history.append(event.duplicate(true));break
			"duplicate_install": services["toys"]["0"+String(services["toys"].keys()[0])]="vine_ball"
			"pool": services["pools"].values()[0]["points"]+=1
			"credit":
				for event in history:
					if event["stage"]=="pool_credit": event["credited"]+=1;break
			"candidate":
				for event in history:
					if event["stage"]=="pool_candidate": event["points"]+=1;break
			"contribution": services["contributions"].values()[0]["1"]+=1
			"source":
				for event in history:
					if event["stage"]=="work_progress" and not event["source"].is_empty(): event["source"]["value"]+=1;break
			"missing":
				for event in history:
					if event["stage"]=="toy_service": event.erase("roll");break
		check(not Codec.normalize(forged)["ok"],"service Codec rejects "+kind)
