extends "res://scripts/farming/tests/run_phase104.gd"
## Allocation contracts: synthetic requests against real paid hosts, not a
## business scenario. No synthetic request history is presented as a save.
func request(uid: int,species: String) -> Dictionary:
	return {"uid":uid,"species_id":species,"zone_uid":2}

func run() -> void:
	var w:=service_fixture()
	w.services.begin_day(w.clock.total_days)
	var t:=w.clock.total_days*8+2
	var first: Dictionary=w.services.gu_service(request(100,"steel_sheep"),"breed_speed",t)
	check(not first.is_empty() and first["space"]==2,"sheep consumes two service spaces")
	check(w.services.gu_service(request(100,"steel_sheep"),"breed_speed",t)==first,"repeated same-unit request reuses allocation")
	check(not w.services.gu_service(request(101,"rock_mole"),"breed_speed",t).is_empty(),"mixed mole consumes one space")
	check(not w.services.gu_service(request(102,"rock_belly_beast"),"breed_speed",t).is_empty(),"mixed beast fills fourth space")
	check(w.services.gu_service(request(103,"rock_mole"),"breed_speed",t).is_empty(),"fifth service space rejected")
	check(not w.services.gu_service(request(103,"rock_mole"),"breed_speed",t+1).is_empty(),"next unit gets independent capacity")
	var v:=service_fixture()
	check(v.ranch.paint_cell(2,Vector2i(11,4))["ok"],"extend selected room explicitly")
	check(v.build_facility(Vector2i(8,4),"soothing_station")["ok"],"second host retains min usable area")
	var high: int=v.facility_at(Vector2i(8,4))["uid"]
	check(v.logistics.deploy("trial-013",Vector2i(-1,-1),high)["ok"],"second real compatible instance")
	v.logistics.instance("trial-013")["rank"]=2 # Explicit allocation fixture.
	check(v.end_day()["ok"],"second host pays on activation day")
	v.services.begin_day(v.clock.total_days)
	t=v.clock.total_days*8+2
	check(v.services.gu_service(request(100,"steel_sheep"),"breed_speed",t).get("host")==high,"highest rank chosen first")
	check(v.services.gu_service(request(101,"steel_sheep"),"breed_speed",t).get("host")==high,"highest rank fills real capacity")
	check(v.services.gu_service(request(102,"rock_mole"),"breed_speed",t).get("host")!=high,"another compatible host shares overflow demand")
	var tired:=service_fixture()
	tired.ranch.animal(2)["fatigue"]=8 # Explicit day-opening fatigue fixture.
	check(tired.end_day()["ok"],"tired work day settles")
	var rows: Array=tired.services.state["history"].filter(func(e):return e["stage"]=="work_progress" and int(e["day"])==tired.clock.total_days-1)
	check(not rows.is_empty() and rows.all(func(e):return e["base"]==7500 and e["points"]==11250),"75 percent fatigue times 150 percent retains fractional work exactly")
	print("P104 CAPACITY %s (%d)" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
