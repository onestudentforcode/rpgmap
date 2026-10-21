extends SceneTree
const World := preload("res://scripts/farming/p8/p8_world.gd")
const Codec := preload("res://scripts/farming/p8/p8_snapshot.gd")
const Batch := preload("res://scripts/farming/p8/p108_batch.gd")
const Tutorial := preload("res://scripts/farming/p8/p108_tutorial.gd")
const SlotStore := preload("res://scripts/farming/p8/p8_slot_store.gd")
var checks:=0
var failures: Array=[]

class FailingPreferenceStore extends RefCounted:
	var inner
	var failing := false
	func _init(store): inner=store
	func active_slot() -> int: return inner.active_slot()
	func create_slot(slot: int,snapshot: Dictionary,overwrite: bool=false) -> Dictionary: return inner.create_slot(slot,snapshot,overwrite)
	func open_slot(slot: int) -> Dictionary: return inner.open_slot(slot)
	func read_slot(slot: int) -> Dictionary: return inner.read_slot(slot)
	func commit(snapshot: Dictionary) -> Dictionary:
		return {"ok":false,"reason":"simulated tutorial preference write failure"} if failing else inner.commit(snapshot)

class GrowthProofFixture extends RefCounted:
	var percent: int
	func _init(value: int): percent=value
	func growth_percent(_rect: Rect2i,_tags: Array,_day: int) -> int: return percent

class RoomGrowthFixture extends RefCounted:
	func crop_grew(_row: Dictionary,_delta: int,_day: int) -> void: pass

func _initialize() -> void: call_deferred("run")

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);printerr("P108 MODEL "+label)

func run() -> void:
	var world:=World.new()
	check(Codec.SCHEMA==26 and Codec.normalize(world.to_snapshot())["ok"],"schema26 fresh state and strict codec")
	var snapshot: Dictionary=world.to_snapshot()
	snapshot["preferences"]["tutorial"]["completed"]=["bogus"]
	check(not Codec.normalize(snapshot)["ok"],"unknown tutorial milestone rejected")
	snapshot=world.to_snapshot()
	snapshot["preferences"].erase("tutorial")
	check(not Codec.normalize(snapshot)["ok"],"missing tutorial state rejected")
	var state:=Tutorial.fresh()
	check(Tutorial.normalize(state)["ok"],"fresh tutorial preferences normalize")
	state["completed"]=["first_field"]
	state["skipped"]=["first_field"]
	check(not Tutorial.normalize(state)["ok"],"overlapping completed/skipped rejected")
	var paid_but_ineffective:=World.new()
	paid_but_ineffective.logistics.state["history"].append({"day":1,"fees":1,"food":{},"services":["trial-004"]})
	check("active_field_gu" not in Tutorial.progress(paid_but_ineffective,Tutorial.fresh())["done"],"a paid/active service receipt alone does not complete effective-field-gu milestone")
	var effective_growth:=World.new()
	effective_growth.logistics=GrowthProofFixture.new(150)
	effective_growth.rooms=RoomGrowthFixture.new()
	effective_growth._crop_grew({"uid":1,"crop_id":"golden_wheat","origin":[0,0]},1,1)
	check("active_field_gu" in effective_growth.preferences["tutorial"]["completed"],"tutorial records a real positive crop-growth receipt under gu acceleration")
	var no_growth:=World.new()
	no_growth.logistics=GrowthProofFixture.new(150)
	no_growth.rooms=RoomGrowthFixture.new()
	no_growth._crop_grew({"uid":1,"crop_id":"golden_wheat","origin":[0,0]},0,1)
	check("active_field_gu" not in no_growth.preferences["tutorial"]["completed"],"no-growth receipt does not complete field-gu milestone")
	_test_tutorial_preference_persistence()
	var fresh_advice: Dictionary=Tutorial.today(world,Tutorial.fresh())
	check(fresh_advice["day"]==1 and fresh_advice.get("reference_day",0)==1 and not fresh_advice["items"].is_empty(),"fresh save receives day-one replay-based guidance")
	var route_world:=World.new()
	route_world.clock.total_days=89
	check(Tutorial.today(route_world,Tutorial.fresh()).get("reference_day",0)==90,"guide reaches the last day of its verified replay segment")
	route_world.clock.total_days=90
	check(not Tutorial.today(route_world,Tutorial.fresh()).has("reference_day"),"reference schedule ends cleanly and returns to adaptive milestone guidance")
	var deviated_world:=World.new()
	var advanced_preferences:=Tutorial.fresh()
	advanced_preferences["completed"]=["first_field","first_harvest"]
	var deviation_advice: Dictionary=Tutorial.today(deviated_world,advanced_preferences)
	check(deviation_advice["title"]=="完成第一批加工" and deviation_advice["items"][0]==Tutorial.STEPS[2]["hint"],"guide prioritizes the current milestone when the replay day does not cover it")
	deviated_world.clock.total_days=4 # Replay day 5 contains actual batch-start evidence.
	deviation_advice=Tutorial.today(deviated_world,advanced_preferences)
	check(deviation_advice["items"].has("查看原料库存，启动当前可负担的加工批次。"),"guide retains replay advice when it matches the player's current milestone")
	_test_batch(world)
	print("P108 MODEL %s (%d)"%["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func _test_tutorial_preference_persistence() -> void:
	var directory := "res://.art-work/p108-model/tutorial-prefs-%d" % OS.get_process_id()
	var raw_store = SlotStore.new(directory)
	var store = FailingPreferenceStore.new(raw_store)
	var saved_world = World.new(store)
	var created: Dictionary = saved_world.start_new(1)
	check(created.get("ok",false),"preference persistence fixture creates a real slot")
	var baseline: Dictionary = store.read_slot(1)["snapshot"]
	saved_world.inventory.add("humus",7) # Deliberately unsaved world mutation.
	var result: Dictionary = saved_world.set_tutorial_preference("collapsed",true)
	check(result.get("ok",false) and result.get("saved",false),"tutorial preference saves immediately to active slot")
	var persisted: Dictionary = store.read_slot(1)["snapshot"]
	check(bool(persisted["preferences"]["tutorial"]["collapsed"]),"saved tutorial preference survives reopening the slot")
	check(persisted["inventory"]==baseline["inventory"],"preference save does not commit unsaved gameplay inventory")
	var rejected: Dictionary = saved_world.set_tutorial_preference("unknown",true)
	check(not rejected.get("ok",false),"tutorial preference writer rejects non-whitelisted fields")
	store.failing=true
	rejected=saved_world.set_tutorial_preference("enabled",false)
	check(not rejected.get("ok",false) and bool(saved_world.preferences["tutorial"]["enabled"]),"failed preference commit rolls back the live setting")
	check(bool(store.read_slot(1)["snapshot"]["preferences"]["tutorial"]["enabled"]),"failed preference commit leaves the prior slot snapshot intact")
	store.failing=false
	check(saved_world.open_game(1).get("ok",false) and bool(saved_world.preferences["tutorial"]["collapsed"]),"tutorial display preference reloads with the slot")
	check(saved_world.inventory.to_save()==baseline["inventory"],"reopening still discards the deliberately unsaved gameplay mutation")
	saved_world.daily_save_error="simulated pending day-save failure"
	rejected=saved_world.set_tutorial_preference("enabled",false)
	check(not rejected.get("ok",false) and bool(saved_world.preferences["tutorial"]["enabled"]),"pending day-save blocks preference writes without mutating the preference")
	raw_store.delete_slot(1,true)

func _test_batch(world) -> void:
	var base: Rect2i=world.land.base
	var rect:=Rect2i(base.position+Vector2i(1,1),Vector2i(3,2))
	for cell in Batch.cells(rect):
		var result: Dictionary=world.till(cell)
		check(result["ok"],"till fixture cell "+str(cell))
	var till_plan: Dictionary=Batch.preview(world,rect,"till")
	check(till_plan["actions"].is_empty() and till_plan["invalid"].size()==rect.get_area(),"pure preview rejects already tilled cells")
	world.inventory.add("golden_wheat_seed",20)
	var crop_plan: Dictionary=Batch.preview(world,rect,"plant","golden_wheat")
	check(crop_plan["actions"].size()==rect.get_area(),"batch crop plan uses row-major legal cells")
	check(world.clock.ap==int(world.config["ap_per_day"])-rect.get_area(),"preview does not spend AP")
	var first: Dictionary=crop_plan["actions"][0]
	var planted: Dictionary=world.plant_manual(first["cell"],"golden_wheat")
	check(planted.get("ok",false),"manual crop action succeeds")
	check(world.workforce.seed_plan(first["cell"])["crop_id"]=="golden_wheat","manual crop and repeat plan share action transaction")
	var harvest_advice: Dictionary=Tutorial.today(world,Tutorial.fresh())
	check(harvest_advice["title"]=="收下第一批作物" and harvest_advice["waiting"],"tutorial switches to a condition-based wait after planting")
	var large_origin:=base.position+Vector2i(7,1)
	for cell in [large_origin,large_origin+Vector2i(1,0),large_origin+Vector2i(0,1),large_origin+Vector2i(1,1)]: world.till(cell)
	var seed_plan: Dictionary=world.plant_quote(large_origin,"fast_fir")
	world.inventory.add("fast_fir_seed",1)
	seed_plan=world.plant_quote(large_origin,"fast_fir")
	check(seed_plan["ok"],"single-cell quote accepts complete 2x2 crop placement")
	var large: Dictionary=world.plant_manual(large_origin,"fast_fir")
	check(large.get("ok",false),"single manual action places a 2x2 crop")
	var crop: Dictionary=world.instance_at(large_origin+Vector2i(1,1))
	if not crop.is_empty(): world.crops[int(crop["uid"])]["state"]="mature"
	var harvest_plan: Dictionary=Batch.preview(world,Rect2i(large_origin,Vector2i(2,2)),"fell")
	check(harvest_plan["targets"]==1 and harvest_plan["actions"].size()==1,"multi-cell mature crop is planned and felled once")
	var before: Dictionary=world.to_snapshot()
	var preview: Dictionary=Batch.preview(world,rect,"fertilize")
	check(world.to_snapshot()==before,"batch preview is read-only")
	check(preview["targets"]<=rect.get_area(),"batch preview has finite deterministic targets")
	# Force one AP left after preparing two eligible cells. Planning/execution may
	# spend that final AP once, but no action can cross into the next day.
	world.inventory.add("humus",20)
	world.clock.ap=1
	var final_ap_plan: Dictionary=Batch.preview(world,Rect2i(rect.position,Vector2i(2,1)),"fertilize")
	check(final_ap_plan["actions"].size()==1 and final_ap_plan["blocked"]=="行动点不足","preview stops at final AP budget")
	var day:int=world.clock.total_days
	var last: Dictionary=world.fertilize(final_ap_plan["actions"][0]["cell"])
	check(last.get("ok",false) and world.clock.total_days==day+1,"last AP performs one action and advances once")
	print("P108 MODEL batch-plan=%d invalid=%d last_ap_day=%d"%[crop_plan["targets"],crop_plan["invalid"].size(),world.clock.total_days])
