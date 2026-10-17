extends "res://scripts/farming/tests/run_p10_playtest.gd"
## P10.1 agriculture route: the inherited P10 operator keeps running the whole
## economy; this extension adds three more station modules (water, fertility,
## a second growth source), farms their directed zones through public actions
## only, rotates one module mid-run for the turned-away observation and keeps
## a per-day agriculture book for the strict conservation audit.
var agri_book: FileAccess
var agri_stats := {}
var _last_agri := {}
var _m4_rotated := false
var _saw_fraction := false
## Extra hosts beside the base-plan station at (7,9); each pairs with a gu and
## a fixed east zone so the audit can attribute retention per module.
const AGRI_STATIONS := {
	"M4": {"cell": Vector2i(13,10), "facing": "north", "gu": "trial-004", "kind": "growth"},
	"M2": {"cell": Vector2i(15,11), "facing": "east", "gu": "trial-008", "kind": "water"},
	"M3": {"cell": Vector2i(1,11), "facing": "east", "gu": "trial-010", "kind": "fert"},
}
const BASE_STATION := Vector2i(7,9)
const M1_WHEAT := [Vector2i(9,9),Vector2i(10,9),Vector2i(11,9),Vector2i(9,10),Vector2i(10,10),Vector2i(11,10),Vector2i(9,11),Vector2i(10,11),Vector2i(11,11)]
const M2_PASTURE := [Vector2i(17,11),Vector2i(18,11),Vector2i(19,11)]
const M2_WHEAT := [Vector2i(17,12),Vector2i(18,12),Vector2i(19,12),Vector2i(17,13),Vector2i(18,13),Vector2i(19,13)]
const M3_FIR := Vector2i(3,11)
const M3_WHEAT := [Vector2i(5,11),Vector2i(3,13),Vector2i(4,13),Vector2i(5,13)]
const M4_WHEAT := [Vector2i(13,7),Vector2i(14,7),Vector2i(15,7),Vector2i(13,8),Vector2i(14,8),Vector2i(13,9),Vector2i(14,9)]
# After the committed turn the same cells keep growing uncovered; the book
# samples them again as M4T so the audit can prove no phantom service remains.
const M4_TURNED_WHEAT := [Vector2i(13,7),Vector2i(14,7),Vector2i(15,7),Vector2i(13,8),Vector2i(14,8),Vector2i(13,9),Vector2i(14,9)]
const TURN_DAY := 50

func _run_route(route: String) -> void:
	agri_stats = {"irrigations":0,"fertilizations":0,"module_harvests":0,"wheat_units":0,"fir_units":0,"rotations":0,"turned_plantings":0}
	_m4_rotated = false
	_last_agri = {}
	_saw_fraction = false
	agri_book = FileAccess.open(audit_root.path_join(route+"-agri.jsonl"),FileAccess.WRITE)
	super(route)
	var agriculture: Dictionary = _last_agri.get("agriculture",{})
	var south_facings := 0
	for uid in agriculture.get("facings",{}):
		if String(agriculture["facings"][uid]["active"]) == "south": south_facings += 1
	check(int(agri_stats["module_harvests"])>0 and int(agri_stats["wheat_units"])>0,route+" agriculture modules really harvested")
	check(int(agri_stats["fir_units"])>0,route+" multi-cell fir module harvested")
	check(int(agri_stats["irrigations"])>0 and int(agri_stats["fertilizations"])>0,route+" real watering and fertilizing performed")
	check(int(agri_stats["rotations"])==1 and south_facings==1 and _m4_rotated,route+" committed rotation took effect")
	check(_saw_fraction,route+" fractional fertility savings engaged on the ground")
	# Water uses times the frozen 50% are all whole numbers, so water
	# remainders legitimately stay empty; only fertility (odd uses) carries,
	# and its final-day parity may rest at zero.
	agri_book.close()
	write_json(route+"-agri-summary.json",agri_stats)

func record_operation(entry: Dictionary) -> void:
	super(entry)
	if entry.get("kind") == "agriculture" and entry.get("stage") == "facing":
		agri_stats["rotations"] += 1

func archive_day(world, day: int) -> void:
	super(world,day)
	if world.daily_save_error.is_empty():
		var modules := {}
		var m2_cells: Array = M2_PASTURE.duplicate()
		m2_cells.append_array(M2_WHEAT)
		var m3_cells: Array = M3_WHEAT.duplicate()
		m3_cells.append_array([M3_FIR,Vector2i(4,11),Vector2i(3,12),Vector2i(4,12)])
		for pair in [["M1",M1_WHEAT],["M2",m2_cells],["M3",m3_cells],["M4",M4_WHEAT],["M4T",M4_TURNED_WHEAT]]:
			var cells := {}
			for cell in pair[1]:
				var env: Dictionary = world.environment_at(cell)
				var crop: Dictionary = world.instance_at(cell)
				cells["%d,%d" % [cell.x,cell.y]] = {"water": int(env["water"]), "fertility": int(env["fertility"]),
					"crop": String(crop.get("crop_id","")), "state": String(crop.get("state",""))}
			modules[String(pair[0])] = cells
		var line := {"day":day,"agriculture":world.logistics.agri_to_save(),
			"modules":modules,"stats":agri_stats.duplicate(true)}
		agri_book.store_line(JSON.stringify(line))
		_last_agri = line
		_saw_fraction = _saw_fraction or not world.logistics.agri_to_save()["remainders"]["fertility"].is_empty()

## Field maintenance unlocks the hosts, so the agriculture route researches it
## first instead of waiting for the base ordering.
func _start_research(world) -> void:
	if not world.research.is_completed("field_maintenance") and world.research.active_project(uid_of(world,"research_bench")).get("id","") != "field_maintenance":
		for uid in world.facilities.keys():
			if String(world.facilities[uid]["facility_id"]) == "research_bench" and world.research.active_project(int(uid)).is_empty():
				if world.research.quote_start(int(uid),"field_maintenance")["ok"]:
					act(world,"world.research.start field_maintenance first",func(): return world.research.start(int(uid),"field_maintenance"))
				break
	super(world)

func _source_topups(world) -> void:
	super(world)
	_agriculture_day(world)

func _agriculture_day(world) -> void:
	if not world.research.is_completed("field_maintenance"): return
	if world.inventory.count("golden_wheat_seed") < 12 and world.primeval_stones >= 30:
		act(world,"module wheat seed purchase",func(): return world.buy("golden_wheat_seed",mini(12-world.inventory.count("golden_wheat_seed"),world.primeval_stones/4)))
	if world.inventory.count("fast_fir_seed") < 2 and world.primeval_stones >= 40:
		act(world,"module fir seed purchase",func(): return world.buy("fast_fir_seed",2-world.inventory.count("fast_fir_seed")))
	if world.inventory.count("grass_seed") < 9 and world.primeval_stones >= 30:
		act(world,"module grass seed purchase",func(): return world.buy("grass_seed",mini(9-world.inventory.count("grass_seed"),world.primeval_stones/4)))
	_agriculture_build(world)
	_agriculture_rotate(world)
	_farm_fir(world)
	_farm_module_cells(world,"M1",M1_WHEAT,"golden_wheat",false)
	_farm_module_cells(world,"M2",M2_PASTURE,"pasture_grass",false)
	_farm_module_cells(world,"M2",M2_WHEAT,"golden_wheat",false)
	_farm_module_cells(world,"M3",M3_WHEAT,"golden_wheat",false)
	_farm_module_cells(world,"M4",M4_WHEAT,"golden_wheat",_m4_rotated)

func _agriculture_build(world) -> void:
	for key in AGRI_STATIONS:
		var spec: Dictionary = AGRI_STATIONS[key]
		var cell: Vector2i = spec["cell"]
		if not world.facility_at(cell).is_empty(): continue
		if world.primeval_stones < 60: continue
		# Iron is scarce: keep one ingot banked for each still-missing base-plan
		# build (growth lamp, plan station) so the inherited operator's own
		# checks never starve because of the modules.
		var reserved := 0
		if count_of(world,"growth_lamp") == 0: reserved += 1
		if world.facility_at(BASE_STATION).is_empty(): reserved += 1
		if world.inventory.count("iron_ingot") < 1 + reserved: continue
		var station: Dictionary = world.facility_defs["field_service_station"]
		for item in station["materials"]:
			var short: int = int(station["materials"][item]) - world.inventory.count(String(item))
			if short > 0 and int(world._items[String(item)]["buy_price"]) > 0:
				act(world,"module station material "+String(item),func(): return world.buy(String(item),short))
		if world.can_build_facility(cell,"field_service_station")["ok"]:
			act(world,"module station build "+key,func(): return world.build_facility(cell,"field_service_station",String(spec["facing"])))
	# The module gu are the object of study: every station (including the base
	# plan host) keeps its own auto-services off so the audit can attribute
	# each environment delta to a receipted manual action or a settlement.
	for uid in world.facilities.keys().duplicate():
		if String(world.facilities[uid]["facility_id"]) == "field_service_station":
			var device: Dictionary = world.devices.device_of(int(uid))
			if device.is_empty() or bool(device.get("irrigate",true)) or bool(device.get("fertilize",true)):
				act(world,"module station auto-services off",func(): return world.devices.configure_station(int(uid),false,false,30))
	var gu = world.logistics
	for key in AGRI_STATIONS:
		var spec: Dictionary = AGRI_STATIONS[key]
		var uid := uid_at(world,Vector2i(spec["cell"]))
		var row: Dictionary = gu.instance(String(spec["gu"]))
		if uid > 0 and not gu.deployed(row) and world.primeval_stones > 40:
			act(world,"admit agriculture gu "+key,func(): return gu.deploy(String(spec["gu"]),Vector2i(-1,-1),uid))
		elif uid > 0 and gu.deployed(row) and not row["enabled"] and world.primeval_stones > 40:
			act(world,"restore agriculture gu "+key,func(): return gu.set_enabled(String(spec["gu"]),true))

func _agriculture_rotate(world) -> void:
	# One documented mid-run turn: M4 faces south from the next opening and its
	# plot moves; the old cells keep growing at the natural rate.
	if active_day >= TURN_DAY and not _m4_rotated:
		var uid := uid_at(world,AGRI_STATIONS["M4"]["cell"])
		if uid > 0 and world.logistics.next_facing_of(uid) != "south":
			var result := act(world,"rotate M4 south",func(): return world.logistics.set_facing(uid,"south"))
			if result["ok"]: _m4_rotated = true

func uid_at(world, cell: Vector2i) -> int:
	var facility: Dictionary = world.facility_at(cell)
	return int(facility.get("uid",0))

func _farm_module_cells(world, module: String, cells: Array, crop_id: String, turned: bool) -> void:
	var seed_id := "grass_seed" if crop_id == "pasture_grass" else "golden_wheat_seed"
	for cell in cells:
		var crop: Dictionary = world.instance_at(cell)
		if not crop.is_empty() and String(crop["state"]) == "mature":
			var before: int = world.inventory.count("grain")
			if act(world,"module harvest "+module,func(): return world.harvest(cell,"harvest"))["ok"]:
				agri_stats["module_harvests"] += 1
				agri_stats["wheat_units"] += world.inventory.count("grain") - before
			continue
		if crop.is_empty():
			if world.grid.state_at(cell) == 0:
				act(world,"module till "+module,func(): return world.till(cell))
			if world.grid.state_at(cell) == 1 and world.inventory.count(seed_id) > 0:
				if act(world,"module plant "+module,func(): return world.plant(cell,crop_id))["ok"] and turned:
					agri_stats["turned_plantings"] += 1
			continue
		var env: Dictionary = world.environment_at(cell)
		if int(env["water"]) < 35 and world.inventory.has("clean_water",1):
			if act(world,"module irrigate "+module,func(): return world.irrigate(cell))["ok"]:
				agri_stats["irrigations"] += 1
		elif int(env["fertility"]) < 35 and world.inventory.has("humus",1):
			if act(world,"module fertilize "+module,func(): return world.fertilize(cell))["ok"]:
				agri_stats["fertilizations"] += 1

func _farm_fir(world) -> void:
	var crop: Dictionary = world.instance_at(M3_FIR)
	if crop.is_empty():
		for cell in [M3_FIR,Vector2i(4,11),Vector2i(3,12),Vector2i(4,12)]:
			if world.grid.state_at(cell) == 0: act(world,"module fir till",func(): return world.till(cell))
		if world.grid.state_at(M3_FIR) == 1 and world.inventory.count("fast_fir_seed") > 0:
			act(world,"module fir plant",func(): return world.plant(M3_FIR,"fast_fir"))
		return
	if String(crop["state"]) == "mature":
		var before: int = world.inventory.count("raw_wood")
		if act(world,"module fir fell",func(): return world.harvest(M3_FIR,"fell"))["ok"]:
			agri_stats["module_harvests"] += 1
			agri_stats["fir_units"] += world.inventory.count("raw_wood") - before
		return
	var env: Dictionary = world.environment_at(M3_FIR)
	if int(env["water"]) < 35 and world.inventory.has("clean_water",1):
		if act(world,"module fir irrigate",func(): return world.irrigate(M3_FIR))["ok"]:
			agri_stats["irrigations"] += 1
	elif int(env["fertility"]) < 35 and world.inventory.has("humus",1):
		if act(world,"module fir fertilize",func(): return world.fertilize(M3_FIR))["ok"]:
			agri_stats["fertilizations"] += 1
