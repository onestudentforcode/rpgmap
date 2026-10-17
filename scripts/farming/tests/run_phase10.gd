extends SceneTree
const World := preload("res://scripts/farming/p8/p8_world.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const Codec := preload("res://scripts/farming/p8/p8_snapshot.gd")
var checks := 0
var failures := []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL: ",label)

func _initialize() -> void:
	var w := World.new()
	print("fresh ",Codec.normalize(w.to_snapshot())) if not Codec.normalize(w.to_snapshot())["ok"] else print("fresh valid")
	check(Codec.normalize(w.to_snapshot())["ok"],"fresh current-schema valid")
	check(w.logistics.provision()["ok"],"claim trial provision")
	check(not w.logistics.provision()["ok"],"cannot claim twice")
	check(w.logistics.state["instances"].size()==11,"eleven instances from seven prototypes")
	check(w.logistics.deploy("trial-001",Vector2i(5,5))["ok"],"rice on wild land")
	check(not w.logistics.deploy("trial-001",Vector2i(6,5))["ok"],"same instance cannot deploy twice")
	check(w.logistics.deploy("trial-002",Vector2i(6,5))["ok"],"same definition another instance deploys")
	check(Codec.normalize(w.to_snapshot())["ok"],"deployed snapshot valid")
	var cash := w.primeval_stones
	w.end_day()
	check(w.primeval_stones==cash-2,"one fee each at opening")
	var before := w.to_snapshot()
	w.logistics.run_opening(w.clock.total_days)
	check(w.to_snapshot()==before,"opening idempotent")
	for i in range(3): w.end_day()
	check(w.logistics.instance("trial-001")["job"].get("ready",false),"rice completes after three effective days")
	check(w.inventory.count("rice")==0,"ready is not inventory")
	check(not w.logistics.withdraw("trial-001")["ok"],"ready locks withdrawal")
	check(w.logistics.claim("trial-001")["ok"] and w.inventory.count("rice")==4,"claim real rice")
	check(not w.logistics.claim("trial-001")["ok"],"claim once")
	check(w.logistics.withdraw("trial-001")["ok"],"withdraw after claim")
	check(Codec.normalize(w.to_snapshot())["ok"],"production/withdraw roundtrip")
	var restored := World.new()
	var result := restored.apply_snapshot(w.to_snapshot())
	check(result["ok"],"restore deployed instance and job")
	if not result["ok"]: print(result)
	check(restored.to_snapshot()==w.to_snapshot(),"snapshot exact roundtrip")
	var damaged := w.to_snapshot()
	damaged["world"]["logistics"]["instances"][1]["instance_id"] = "trial-001"
	check(not Codec.normalize(damaged)["ok"],"duplicate identity rejected")
	# P10.2 explicitly rejects early development saves; it does not migrate them.
	var old := World.new().to_snapshot()
	old["schema"]=17
	old["world"].erase("logistics")
	check(not Codec.normalize(old)["ok"],"schema17 rejected without deleting old files")
	_research()
	_long_research()
	_environment()
	_shortage()
	_growth()
	_food_atomic()
	_transaction()
	_corruption()
	print("PHASE10 TEST OK (%d)" % checks if failures.is_empty() else "PHASE10 TEST FAIL (%d/%d)" % [failures.size(),checks])
	quit(0 if failures.is_empty() else 1)

func _research() -> void:
	for id in ["", "trial-005", "trial-006"]:
		var w := World.new()
		w.grant_scaffold({"raw_wood":10,"raw_stone":10,"grain":10,"humus":10,"time_feed":10})
		w.logistics.provision()
		check(w.build_facility(Vector2i(4,4),"research_bench")["ok"],"build research host")
		var uid := int(w.facilities.keys()[0])
		if not id.is_empty():
			check(w.logistics.deploy(id,Vector2i(-1,-1),uid)["ok"],"research gu admission")
			w.end_day()
		var q: Dictionary = w.research.quote_start(uid,"flower_cultivation")
		check(q["days"]==(2 if id.is_empty() else 1),"2-day research quote")
		check(q["samples"]["grain"]==(3 if id=="trial-006" else 2),"independent material multiplier")
		check(w.research.start(uid,"flower_cultivation")["ok"],"start research with locked plan")
		if not id.is_empty(): check(not w.logistics.withdraw(id)["ok"],"active research locks gu")
		check(w.research.work(uid)["ok"],"one research receipt")
		check(not w.research.work(uid)["ok"],"no repeated receipt")
		check(Codec.normalize(w.to_snapshot())["ok"],"unsettled modified receipt valid")
		w.end_day()
		if id.is_empty():
			check(not w.research.is_completed("flower_cultivation"),"ordinary needs second receipt")
			w.research.work(uid)
			w.end_day()
		check(w.research.is_completed("flower_cultivation"),"research completion actual agrees quote")
		check(Codec.normalize(w.to_snapshot())["ok"],"completed research snapshot valid")

func _environment() -> void:
	var w := World.new()
	w.logistics.provision()
	w.grant_scaffold({"raw_wood":10,"raw_stone":10,"wood_plank":10,"iron_ingot":10,"composite_stone_panel":2,"refined_oil":4,"clean_water":8})
	# Host-gate fixture only; normal-route reachability is separately audited.
	w.research.state["completed"] = w.research.project_defs().keys()
	check(w.build_facility(Vector2i(2,10),"growth_lamp")["ok"],"build lamp fixture")
	var lamp := int(w.facilities.keys()[0])
	check(w.logistics.deploy("trial-003",Vector2i(-1,-1),lamp)["ok"],"light gu host slot")
	check(not w.logistics.deploy("trial-004",Vector2i(-1,-1),lamp)["ok"],"ability incompatibility")
	check(w.logistics.deploy("trial-001",Vector2i(3,10))["ok"],"shade rice fixture")
	w.devices.configure_lamp(lamp,true)
	var oil := w.inventory.count("refined_oil")
	w.end_day()
	check(w.environment_at(Vector2i(3,10))["light"]==80,"gu light raises shade to80")
	check(w.inventory.count("refined_oil")==oil,"gu mode never consumes lamp oil")
	check(w.logistics.set_enabled("trial-003",false)["ok"],"stop source immediately")
	check(w.environment_at(Vector2i(3,10))["light"]==30,"no residual gu light")
	w.end_day()
	check(w.logistics.instance("trial-001")["job"].is_empty(),"hard light gate pauses independent production")
	check(w.logistics.set_enabled("trial-003",true)["ok"],"source schedules restoration")
	check(w.environment_at(Vector2i(3,10))["light"]==30,"no free immediate restart")
	w.end_day()
	w.end_day()
	check(not w.logistics.instance("trial-001")["job"].is_empty(),"light restoration resumes")
	check(Codec.normalize(w.to_snapshot())["ok"],"light state serializable")
	check(w.logistics.withdraw("trial-003")["ok"],"idle light source can withdraw")
	oil=w.inventory.count("refined_oil")
	w.end_day()
	check(w.inventory.count("refined_oil")==oil-1 and w.environment_at(Vector2i(3,10))["light"]==80,"ordinary oil lamp also services independent gu")

func _complete_prerequisites(w, id: String) -> void:
	for parent in w.research.project_def(id)["prerequisites"]:
		_complete_prerequisites(w,parent)
		if parent not in w.research.state["completed"]: w.research.state["completed"].append(parent)

func _long_research() -> void:
	for project_id in ["advanced_feed_oil_wax","composite_spirit_food"]:
		for id in ["","trial-005","trial-006"]:
			var w := World.new()
			w.logistics.provision()
			w.grant_scaffold({"raw_wood":4,"raw_stone":4,"time_feed":12})
			w.build_facility(Vector2i(4,4),"research_bench")
			var uid := int(w.facilities.keys()[0])
			_complete_prerequisites(w,project_id)
			if not id.is_empty():
				w.logistics.deploy(id,Vector2i(-1,-1),uid)
				w.end_day()
			var q: Dictionary = w.research.quote_start(uid,project_id)
			w.grant_scaffold(q["samples"])
			check(w.research.start(uid,project_id)["ok"],"long research starts "+project_id+id)
			var expected := ceili(float(maxi(1,int(w.research.project_def(project_id)["days"])-(1 if id=="trial-005" else 0)))/(2 if id=="trial-006" else 1))
			check(int(q["days"])==expected,"long research quote correct "+project_id+id)
			for i in range(expected):
				check(w.research.work(uid)["ok"],"long research one paid-work receipt")
				w.end_day()
				check(w.research.is_completed(project_id)==(i==expected-1),"long research actual completion matches quote")
			check(Codec.normalize(JSON.parse_string(JSON.stringify(w.to_snapshot())))["ok"],"long research JSON normalizes")

func _shortage() -> void:
	var w := World.new()
	w.logistics.provision()
	w.logistics.deploy("trial-001",Vector2i(5,5))
	w.logistics.deploy("trial-002",Vector2i(6,5))
	w.primeval_stones=1
	w.end_day()
	check(w.primeval_stones==0,"exact balance never negative")
	check(w.logistics.instance("trial-001")["paid_day"]==1 and not w.logistics.instance("trial-002")["enabled"],"stable instance priority and dormancy")
	check(Codec.normalize(w.to_snapshot())["ok"],"shortage snapshot valid")
	var b := w.to_snapshot()
	check(not w.logistics.available_instances([{"instance_id":"combat","definition_id":"rice_bag_gu","rank":1,"role":"combat"}])["ok"],"combat provider rejected")
	check(w.to_snapshot()==b,"provider query read-only")

func _growth() -> void:
	var w := World.new()
	w.logistics.provision()
	w.grant_scaffold({"wood_plank":5,"iron_ingot":2,"clean_water":8})
	w.research.state["completed"] = w.research.project_defs().keys()
	check(w.build_facility(Vector2i(4,4),"field_service_station")["ok"],"growth host built")
	var uid := int(w.facilities.keys()[0])
	check(w.logistics.deploy("trial-004",Vector2i(-1,-1),uid)["ok"],"growth host compatibility")
	# The 1x1 host's east service zone is x5..7,y3..5 (P10.2 §3.3).
	w.logistics.deploy("trial-001",Vector2i(6,4))
	w.till(Vector2i(7,5))
	w.plant(Vector2i(7,5),"golden_wheat")
	w.end_day()
	var before: int = w.instance_at(Vector2i(7,5))["progress"]
	w.end_day()
	check(int(w.logistics.instance("trial-001")["job"]["progress"])==150,"directed zone boosts rice to 1.5 work per day")
	check(int(w.instance_at(Vector2i(7,5))["progress"])-before==150,"same boost applies to ordinary crop")
	check(w.logistics.growth_percent(Rect2i(Vector2i(10,10),Vector2i.ONE),["plant_grow"],2)==100,"outside coverage no boost")
	# Two explicit effect-source fixtures prove max selection and removal. They
	# are not save fixtures or normal-play acquisition paths.
	var stronger: Dictionary = w.logistics.definitions["growth_gu"].duplicate(true)
	stronger["id"]="strong_test"
	stronger["value"]=160
	w.logistics.definitions["strong_test"]=stronger
	var source: Dictionary = w.logistics.instance("trial-004").duplicate(true)
	source["instance_id"]="test-source"
	source["definition_id"]="strong_test"
	w.logistics.state["instances"].append(source)
	check(w.logistics.growth_percent(Rect2i(Vector2i(6,4),Vector2i.ONE),["plant_grow"],2)==160,"same family takes strongest, not multiplied")
	check(w.logistics.definitions["growth_gu"]["value"]==150 and w.logistics.definitions["strong_test"]["value"]==160,"effect sources never enhance each other")
	w.logistics.state["instances"].pop_back()
	check(w.logistics.growth_percent(Rect2i(Vector2i(6,4),Vector2i.ONE),["plant_grow"],2)==150,"stronger source removed restores weaker")
	var cell := Vector2i(6,4)
	w.environment[w.grid.index_of(cell)][0]=0
	var progress: int = w.logistics.instance("trial-001")["job"]["progress"]
	var fertility: int = w.environment[w.grid.index_of(cell)][1]
	w.end_day()
	# Default maintenance station restores the occupied gu square before the
	# next valid day; it must never fertilize that square.
	check(w.environment[w.grid.index_of(cell)][0]>=30,"station irrigates occupied independent gu")
	check(w.environment[w.grid.index_of(cell)][1]==fertility,"station never fertilizes independent gu")
	check(int(w.logistics.instance("trial-001")["job"]["progress"])==progress,"missing water pauses without lost work")

func _food_atomic() -> void:
	var w := World.new()
	w.logistics.provision()
	w.grant_scaffold({"raw_wood":4,"raw_stone":4})
	w.build_facility(Vector2i(4,4),"research_bench")
	var uid := int(w.facilities.keys()[0])
	w.logistics.deploy("trial-006",Vector2i(-1,-1),uid)
	var cash := w.primeval_stones
	w.end_day()
	check(w.primeval_stones==cash,"missing food does not take maintenance stones")
	check(w.logistics.instance("trial-006")["paid_day"]==-1,"missing food grants no service")
	check(w.buy("time_feed",2)["ok"],"special food reachable via normal market")
	cash=w.primeval_stones
	w.end_day()
	check(w.primeval_stones==cash-2 and w.inventory.count("time_feed")==1,"food and fee paid exactly once together")
	w.grant_scaffold({"grain":4,"humus":2})
	check(w.research.start(uid,"flower_cultivation")["ok"],"food-supported research starts")
	check(w.research.work(uid)["ok"],"food-supported work registered")
	check(not w.logistics.set_enabled("trial-006",false)["ok"],"cannot revoke already-registered research qualification")
	check(not w.research.cancel(uid)["ok"],"cannot cancel after today's registered receipt")
	var serialized = JSON.parse_string(JSON.stringify(w.to_snapshot()))
	check(Codec.normalize(serialized)["ok"],"JSON numeric roundtrip with modified project and food")

class FailingStore extends RefCounted:
	var inner
	var failing := false
	func _init(store): inner=store
	func active_slot() -> int: return inner.active_slot()
	func create_slot(slot: int, value: Dictionary, overwrite: bool=false) -> Dictionary: return inner.create_slot(slot,value,overwrite)
	func open_slot(slot: int) -> Dictionary: return inner.open_slot(slot)
	func commit(value: Dictionary) -> Dictionary: return {"ok":false,"reason":"isolated P10 write failure"} if failing else inner.commit(value)

func _transaction() -> void:
	var store := FailingStore.new(Store.new("res://.art-work/p10-model/transaction-%d" % Time.get_ticks_usec()))
	var w := World.new(store)
	check(w.start_new(1)["ok"],"isolated real three-slot store creates")
	w.logistics.provision()
	w.logistics.deploy("trial-001",Vector2i(5,5))
	w.grant_scaffold({"clean_water":2})
	w.end_day()
	check(w.daily_save_error.is_empty(),"first maintenance saves")
	w.clock.ap=1
	var before := w.to_snapshot()
	store.failing=true
	w.irrigate(Vector2i(5,5))
	check(not w.daily_save_error.is_empty(),"last-AP day detects write failure")
	check(w.to_snapshot()==before,"last-AP watering plus gu settlement fully rolls back")
	var candidate: Dictionary = w._pending_day.duplicate(true)
	check(not candidate.is_empty() and Codec.normalize(candidate)["ok"],"retry candidate preserves valid maintenance/job state")
	check(not w.retry_day_save()["ok"] and w.to_snapshot()==before,"failed retry never repeats work")
	store.failing=false
	check(w.retry_day_save()["ok"],"retry publishes candidate once")
	check(w.to_snapshot()==candidate,"published candidate exact")
	check(not w.retry_day_save()["ok"],"second retry cannot publish again")
	var after := w.to_snapshot()
	check(w.open_game(1)["ok"] and w.to_snapshot()==after,"actual disk save/open preserves gu numbers and receipts")
	check(not w.logistics.provision()["ok"],"actual reload cannot reclaim trial provision")

func _corruption() -> void:
	var w := World.new()
	w.logistics.provision()
	w.logistics.deploy("trial-001",Vector2i(5,5))
	w.logistics.deploy("trial-002",Vector2i(6,5))
	w.end_day()
	w.end_day()
	var base := w.to_snapshot()
	for kind in ["overlap","fraction","unknown","paid","service","amount","food","target","job","rank","land","origin","null_job"]:
		var b: Dictionary = base.duplicate(true)
		var g: Dictionary = b["world"]["logistics"]
		var row: Dictionary = g["instances"][0]
		match kind:
			"overlap": g["instances"][1]["origin"]=row["origin"].duplicate()
			"fraction": row["job"]["progress"]=1.25
			"unknown": row["definition_id"]="unknown"
			"paid": row["paid_day"]=w.clock.total_days+1
			"service": g["history"][-1]["services"]=[]; g["history"][-1]["fees"]=0
			"amount": row["paid_fee"]=999
			"food": row["paid_food"]={"time_feed":999}
			"target": row["job"]["target"]=0
			"job": row["job"]["outputs"]={"rice":999}
			"rank": row["rank"]=0
			"land": row["origin"]=[20,1]
			"origin": row["origin"]=[-999,1]
			"null_job": g["instances"][4]["job"]=null
		check(not Codec.normalize(b)["ok"],"reject corrupt gu "+kind)
