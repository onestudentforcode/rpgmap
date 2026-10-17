extends "res://scripts/farming/tests/run_p8_playtest.gd"
## Normal-economy room routes. No scaffold, research injection, forced seed,
## free materials or progress editing. The P8 operator runs the whole industry;
## this extension adds the same nine-cell wheat module under four configurations.
var room_mode := "compound"
var room_book: FileAccess
var observed_world
var observed_days := {}
var room_stats := {}
const ROOM_HOSTS := [
	{"cell":Vector2i(8,11),"facing":"east","gu":"trial-004","channel":"growth"},
	{"cell":Vector2i(12,11),"facing":"west","gu":"trial-008","channel":"seed"},
	{"cell":Vector2i(10,9),"facing":"south","gu":"trial-010","channel":"material"}]
const ROOM_CELLS := [Vector2i(9,10),Vector2i(10,10),Vector2i(11,10),Vector2i(9,11),Vector2i(10,11),Vector2i(11,11),Vector2i(9,12),Vector2i(10,12),Vector2i(11,12)]

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--room-mode="): room_mode=argument.trim_prefix("--room-mode=")
	check(room_mode in ["ordinary","seed","material","compound"],"known room comparison configuration")
	if OS.get_cmdline_user_args().has("--layout-only"):
		_layout_contract()
		for failure in failures: printerr(failure)
		print("P102 BUSINESS LAYOUT %s (%d)" % ["OK" if failures.is_empty() else "FAIL",checks])
		quit(0 if failures.is_empty() else 1)
		return
	super()
	var summary: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(audit_root.path_join("summary.json")))
	summary["settings"]["room_mode"]=room_mode
	write_json("summary.json",summary)

func _layout_contract() -> void:
	var w:=P8World.new()
	var cells: Array=ROOM_CELLS.duplicate()
	for spec in ROOM_HOSTS: cells.append(spec["cell"])
	var unique:={}
	for cell in cells:
		check(not unique.has(cell) and w.grid.can_till(cell)["ok"] and w.source_at(cell).is_empty(),"room module legal unique ground "+str(cell))
		unique[cell]=true
	for spec in ROOM_HOSTS:
		var zone: Rect2i=w.logistics.directed_zone(spec["cell"],[1,1],spec["facing"])
		for cell in ROOM_CELLS: check(zone.has_point(cell),"whole module covered from "+spec["channel"])
	# This module is separate from the base operator's fields and facilities.
	for cell in ROOM_CELLS:
		check(cell.x>=9 and cell.y>=10,"module does not join the base farm")

func enabled_host(spec: Dictionary) -> bool:
	return room_mode!="ordinary" and (spec["channel"]=="growth" or room_mode=="compound" or room_mode==spec["channel"])

func _run_route(route: String) -> void:
	room_stats={"module_plantings":0,"module_harvests":0,"seed_awards":0,"material_awards":0,"floor_cells":0}
	observed_days={};observed_world=null
	room_book=FileAccess.open(audit_root.path_join(route+"-rooms.jsonl"),FileAccess.WRITE)
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(audit_root.path_join("manifest.json")))
	for name in ["scripts/farming/tests/run_p102_playtest.gd","scripts/farming/p8/p102_rooms.gd"]:
		manifest[name]=FileAccess.get_sha256("res://"+name)
	write_json("manifest.json",manifest)
	super(route)
	check(room_stats["module_plantings"]>=9 and room_stats["module_harvests"]>=9,route+" normal room module cultivated and harvested")
	if room_mode in ["seed","compound"]: check(room_stats["seed_awards"]>0,route+" actual returned seeds, no forced random results")
	if room_mode in ["material","compound"]: check(room_stats["material_awards"]>0,route+" actual extra primary entered inventory")
	if room_mode=="ordinary": check(room_stats["seed_awards"]==0 and room_stats["material_awards"]==0,route+" unassisted control has no room rewards")
	room_book.close()
	write_json(route+"-room-summary.json",room_stats)

func record_operation(entry: Dictionary) -> void:
	super(entry)
	if entry.get("kind")!="room" or observed_world==null: return
	var w=observed_world
	var row: Dictionary=entry.duplicate(true)
	if row["stage"]=="growth":
		var day:=int(row["day"])
		if not observed_days.has(day):
			observed_days[day]=true
			var fields:=[]
			var bounds: Rect2i=w.grid.bounds()
			for y in range(bounds.position.y,bounds.end.y):
				for x in range(bounds.position.x,bounds.end.x):
					if w.rooms.farmland(Vector2i(x,y)): fields.append([x,y])
			var snapshot: Dictionary=w.to_snapshot()
			room_book.store_line(JSON.stringify({"stage":"context","day":day,"farmland":fields,
				"tilled":snapshot["world"]["tilled"],"land":w.land.to_save(),"floors":w.rooms.state["floors"].duplicate(),
				"facilities":snapshot["world"]["facilities"],"devices":w.devices.to_save(),
				"agriculture":w.logistics.agri_to_save(),"logistics":w.logistics.to_save()}))
		var uid:=int(String(row["identity"]).trim_prefix("crop:"))
		if String(row["identity"]).begins_with("crop:") and w.crops.has(uid):
			var crop: Dictionary=w.crops[uid]
			row["crop"]=crop.duplicate(true)
			var env:=[]
			for cell in w.grid.holder_cells("v1_crop:%d"%uid):
				var actual: Dictionary=w.environment_at(cell)
				env.append({"cell":[cell.x,cell.y],"water":actual["water"],"fertility":actual["fertility"],"light":actual["light"]})
			row["environment"]=env
	if row["stage"]=="plant" and Vector2i(row["crop"]["origin"][0],row["crop"]["origin"][1]) in ROOM_CELLS: room_stats["module_plantings"]+=1
	if row["stage"]=="claim":
		for item in row["seed"]: room_stats["seed_awards"]+=int(row["seed"][item])
		for item in row["material"]: room_stats["material_awards"]+=int(row["material"][item])
		var uid:=int(String(row["identity"]).trim_prefix("crop:"))
		if w.crops.has(uid) and Vector2i(w.crops[uid]["origin"][0],w.crops[uid]["origin"][1]) in ROOM_CELLS: room_stats["module_harvests"]+=1
	room_book.store_line(JSON.stringify(row))

func archive_day(world, day: int) -> void:
	super(world,day)
	if not world.daily_save_error.is_empty(): return
	room_book.store_line(JSON.stringify({"stage":"day","day":day,"rooms":world.rooms.to_save(),
		"crops":world.to_snapshot()["world"]["crops"],"stats":room_stats.duplicate(true),"logistics":world.logistics.to_save()}))

func _source_topups(world) -> void:
	if observed_world==null:
		observed_world=world
		room_book.store_line(JSON.stringify({"stage":"initial","snapshot":world.to_snapshot(),"mode":room_mode}))
	super(world)
	if not world.research.is_completed("field_maintenance"): return
	if room_mode!="ordinary" and not world.logistics.state["provisioned"]: act(world,"room trial provision",func(): return world.logistics.provision())
	_build_room(world)
	# Returned seed stays in the same warehouse; buy only the real shortfall.
	if world.inventory.count("golden_wheat_seed")<9 and world.primeval_stones>=45:
		act(world,"room buy seed shortfall",func(): return world.buy("golden_wheat_seed",9-world.inventory.count("golden_wheat_seed")))
	for cell in ROOM_CELLS:
		var crop: Dictionary=world.instance_at(cell)
		if not crop.is_empty() and crop["state"]=="mature":
			act(world,"room wheat harvest",func(): return world.harvest(cell))
		elif crop.is_empty():
			if world.grid.state_at(cell)==0: act(world,"room till",func(): return world.till(cell))
			if world.grid.state_at(cell)==1 and world.inventory.count("golden_wheat_seed")>0:
				act(world,"room wheat plant",func(): return world.plant(cell,"golden_wheat"))
		elif world.environment_at(cell)["fertility"]<30 and world.inventory.has("humus",1):
			act(world,"room fertilize",func(): return world.fertilize(cell))

func _sell_surplus(world) -> void:
	super(world)
	# Once research has no further sample demand, keep a small buffer and sell
	# surplus recovery liquid. Sludge has no direct market exit; it is handled
	# through the existing compost recipe below, never sold or discarded.
	if world.research.state["completed"].size()!=world.research.project_defs().size(): return
	for item in ["nutrient_liquid"]:
		if world.inventory.count(item)>maxi(2,sample_reserve(world,item)):
			act(world,"sell completed-research recovery surplus "+item,func(): return world.sell(item,1))

func _process_batches(world, plan: Array) -> void:
	var adjusted:=plan.duplicate(true)
	# Late resource reuse: a full humus buffer must not permanently block
	# turning accumulated sludge into useful fertilizer. Unclaimed products
	# still get their first production window in the inherited scheduler.
	if active_day>=85 and world.inventory.has("sludge",2):
		adjusted=adjusted.filter(func(row): return String(row[1])!="compost_sludge")
		adjusted.push_front(["compost_bin","compost_sludge","humus",maxi(10,world.operations.effective_stock("humus")+2)])
	super(world,adjusted)

func _build_room(world) -> void:
	for spec in ROOM_HOSTS:
		if not enabled_host(spec): continue
		var cell: Vector2i=spec["cell"]
		var facility: Dictionary=world.facility_at(cell)
		if facility.is_empty() and world.primeval_stones>=60 and world.inventory.has("wood_plank",3) and world.inventory.has("iron_ingot",2):
			if world.rooms.floor_kind(cell)=="natural" and world.inventory.has("raw_wood",1):
				var floor_result: Dictionary=act(world,"room ordinary host floor",func(): return world.rooms.set_floor(cell,"ordinary"))
				if floor_result["ok"]: room_stats["floor_cells"]+=1
			if world.rooms.floor_kind(cell)=="ordinary": act(world,"room host build",func(): return world.build_facility(cell,"field_service_station",spec["facing"]))
		facility=world.facility_at(cell)
		if facility.is_empty(): continue
		var uid:=int(facility["uid"])
		var device: Dictionary=world.devices.device_of(uid)
		if device.is_empty() or device["threshold"]!=45:
			act(world,"room ordinary services on",func(): return world.devices.configure_station(uid,true,true,45))
		var gu: Dictionary=world.logistics.instance(spec["gu"])
		if not world.logistics.deployed(gu): act(world,"room admit "+spec["channel"],func(): return world.logistics.deploy(spec["gu"],Vector2i(-1,-1),uid))
		elif not gu["enabled"] and world.primeval_stones>40: act(world,"room restore "+spec["channel"],func(): return world.logistics.set_enabled(spec["gu"],true))
