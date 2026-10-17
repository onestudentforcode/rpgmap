extends "res://scripts/farming/tests/run_p8_playtest.gd"
## The P8 business operator remains unchanged; this extension buys nothing for
## free and uses only public logistics actions, normal market/source proceeds.
var gu_book: FileAccess
var gu_stats := {}
func _run_route(route: String) -> void:
	gu_stats = {"claims":0,"rice":0,"maintenance":0,"wisdom_projects":0,"time_projects":0,"lit_days":0,"growth_days":0}
	gu_book = FileAccess.open(audit_root.path_join(route+"-logistics.jsonl"),FileAccess.WRITE)
	super(route)
	gu_book.close()
	var final: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(audit_root.path_join(route+"-day%d.json" % horizon)))
	var gu: Dictionary = final["world"]["logistics"]
	check(int(gu["spent"])>0 and int(gu_stats["rice"])>0,route+" real gu maintenance and rice claims")
	check(int(gu_stats["lit_days"])>0 and int(gu_stats["growth_days"])>0,route+" environmental and growth gu operated")
	check(int(gu_stats["wisdom_projects"])>0 and int(gu_stats["time_projects"])>0,route+" both research gu used in actual projects")
	check(int(claimed.get("mill_rice",0))>0,route+" rice milled through a normal registered recipe")
	write_json(route+"-logistics-summary.json",gu_stats)

func record_operation(entry: Dictionary) -> void:
	super(entry)
	if entry["kind"] == "logistics" and entry["stage"] == "claim":
		gu_stats["claims"] += 1
		gu_stats["rice"] += int(entry["outputs"].get("rice",0))

func archive_day(world, day: int) -> void:
	super(world,day)
	gu_book.store_line(JSON.stringify({"day":day,"logistics":world.logistics.to_save(),"inventory":world.inventory.to_save(),"cash":world.primeval_stones}))
	for row in world.logistics.state["instances"]:
		if world.logistics.active(row,world.clock.total_days):
			if row["definition_id"] == "bright_gu": gu_stats["lit_days"] += 1
			if row["definition_id"] == "growth_gu": gu_stats["growth_days"] += 1
	gu_stats["maintenance"] = int(world.logistics.state["spent"])

func _source_topups(world) -> void:
	super(world)
	var gu = world.logistics
	if not gu.state["provisioned"]: act(world,"trial provision",func(): return gu.provision())
	if not gu.deployed(gu.instance("trial-001")):
		act(world,"deploy sun rice",func(): return gu.deploy("trial-001",Vector2i(10,11)))
	for id in ["trial-001","trial-002"]:
		var row: Dictionary = gu.instance(id)
		if row["origin"].is_empty(): continue
		if row["job"].get("ready",false): act(world,"claim rice",func(): return gu.claim(id))
		var cell := Vector2i(int(row["origin"][0]),int(row["origin"][1]))
		if int(world.environment_at(cell)["water"])<40 and world.inventory.has("clean_water",1): act(world,"water gu",func(): return world.irrigate(cell))
		if not row["enabled"] and world.primeval_stones>30: act(world,"restore rice gu",func(): return gu.set_enabled(id,true))
	var rice: int = world.inventory.count("rice")
	if rice>6: act(world,"sell rice surplus",func(): return world.sell("rice",rice-6))
	# Each bench receives a different single-slot choice before its next project.
	for pair in [[0,"trial-005"],[1,"trial-006"]]:
		var uid := uid_of(world,"research_bench",int(pair[0]))
		var id := String(pair[1])
		var row: Dictionary = gu.instance(id)
		if uid == 0: continue
		if world.research.state["completed"].size() == world.research.project_defs().size():
			if gu.deployed(row) and row["enabled"]: act(world,"rest research gu",func(): return gu.set_enabled(id,false))
			continue
		if id == "trial-006" and world.inventory.count("time_feed")<3 and world.primeval_stones>40:
			act(world,"buy time food",func(): return world.buy("time_feed",3-world.inventory.count("time_feed")))
		if not gu.deployed(row) and world.primeval_stones>30:
			act(world,"admit research gu",func(): return gu.deploy(id,Vector2i(-1,-1),uid))
		elif gu.deployed(row) and not row["enabled"] and world.primeval_stones>30:
			act(world,"restore research gu",func(): return gu.set_enabled(id,true))

func _start_research(world) -> void:
	var before: Array = world.research.state["projects"].duplicate(true)
	super(world)
	for project in world.research.state["projects"]:
		var known := false
		for old in before:
			if old["id"]==project["id"]: known=true
		if known: continue
		if project["gu"]["instance_id"]=="trial-005": gu_stats["wisdom_projects"] += 1
		if project["gu"]["instance_id"]=="trial-006": gu_stats["time_projects"] += 1

func _configure_devices(world) -> void:
	super(world)
	var gu = world.logistics
	for pair in [["growth_lamp","trial-003"],["field_service_station","trial-004"]]:
		var uid := uid_of(world,pair[0])
		var id := String(pair[1])
		if uid>0 and not gu.deployed(gu.instance(id)):
			act(world,"admit area gu",func(): return gu.deploy(id,Vector2i(-1,-1),uid))
	if uid_of(world,"growth_lamp")>0 and not gu.deployed(gu.instance("trial-002")):
		act(world,"deploy shaded rice",func(): return gu.deploy("trial-002",Vector2i(5,12)))

func _process_batches(world, plan: Array) -> void:
	var extended := plan.duplicate(true)
	if int(claimed.get("mill_rice",0))==0 and world.inventory.count("rice")>=3:
		extended.push_front(["farm_processor","mill_rice","grain_meal",8])
	super(world,extended)
