extends "res://scripts/farming/tests/run_phase102.gd"
## A fixed, <=30-day module fixture, not an economic profitability run.
func run() -> void:
	var w = fixture()
	w.logistics.provision()
	for spec in [[5,4,"east","trial-004"],[9,4,"west","trial-008"],[7,2,"south","trial-010"]]:
		var c := Vector2i(spec[0],spec[1])
		check(w.build_facility(c,"field_service_station",spec[2])["ok"],"host")
		var uid: int = w.facility_at(c)["uid"]
		w.devices.configure_station(uid,false,false,30)
		check(w.logistics.deploy(spec[3],Vector2i(-1,-1),uid)["ok"],"deploy")
	var selected := []
	for y in range(3,6):
		for x in range(6,9):
			w.till(Vector2i(x,y)); selected.append("%d,%d" % [x,y])
	check(w.rooms.create_field(selected,"covered")["ok"],"covered field")
	w.till(Vector2i(9,3));w.till(Vector2i(10,3))
	check(w.rooms.create_field(["9,3","10,3"],"neighbor")["ok"],"touching unqualified field")
	w.end_day()
	check(w.rooms.regions(w.clock.total_days)[0]["seed"] and not w.rooms.regions(w.clock.total_days)[1]["seed"],"only owned covered field qualifies")
	check(w.plant(Vector2i(6,3),"golden_wheat")["ok"],"plant covered")
	check(w.plant(Vector2i(10,3),"golden_wheat")["ok"],"plant neighbor")
	var opening: Dictionary = w.to_snapshot()
	var receipts := []
	w.operation_recorded.connect(func(row): receipts.append(row.duplicate(true)))
	for i in range(3): check(w.end_day()["ok"],"settle real growth")
	var a: Dictionary = w.instance_at(Vector2i(6,3))
	var b: Dictionary = w.instance_at(Vector2i(10,3))
	check(w.rooms.state["plants"][str(a["uid"])]["seed_work"]==400,"adjacent uncovered field does not suppress A")
	check(w.rooms.state["plants"][str(b["uid"])]["seed_work"]==0,"B cannot borrow A room qualification")
	check(w.harvest(Vector2i(6,3))["ok"],"real primary and room claim")
	check(Codec.normalize(w.to_snapshot())["ok"],"scenario final load valid")
	var root := "res://.art-work/p104-boundary"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	var f := FileAccess.open(root+"/scenario.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"kind":"boundary-module","fixture":true,"checks":checks,"failures":failures,
		"opening":opening,"closing":w.to_snapshot(),"receipts":receipts},"  "))
	f.close()
	print("BOUNDARY SCENARIO %s (%d)" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
