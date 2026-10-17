extends SceneTree
## Phase 10.1 model contracts: directed service zones, whole-footprint
## coverage, per-tag resolution, fixed-hundredths savings, host facings, the
## schema19 upgrade and the last-AP transaction around a facing commit.
const World := preload("res://scripts/farming/p8/p8_world.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const Codec := preload("res://scripts/farming/p8/p8_snapshot.gd")
const Logistics := preload("res://scripts/farming/p8/p10_logistics.gd")
var checks := 0
var failures := []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("FAIL: ",label)

func scaffold(w, station_cells: Array, facings: Array = []) -> Array:
	w.grant_scaffold({"wood_plank":30,"iron_ingot":12,"clean_water":40})
	w.research.state["completed"] = w.research.project_defs().keys()
	var uids := []
	for index in range(station_cells.size()):
		var facing := String(facings[index]) if index < facings.size() else "east"
		check(w.build_facility(station_cells[index],"field_service_station",facing)["ok"],"station built at "+str(station_cells[index]))
		for uid in w.facilities.keys():
			if w.facilities[uid]["origin"] == [station_cells[index].x,station_cells[index].y]:
				uids.append(int(uid))
	return uids

func _initialize() -> void:
	var w := World.new()
	check(w.logistics.provision()["ok"],"eleven trial instances provisioned")
	check(w.logistics.state["instances"].size()==11,"provision grants eleven instances")
	_geometry()
	_single_slot_and_combination()
	_coverage_rules()
	_resolution_order()
	_fixed_precision()
	_facing_flow()
	_upgrade()
	_rejections()
	_transaction()
	print("PHASE101 TEST OK (%d)" % checks if failures.is_empty() else "PHASE101 TEST FAIL (%d/%d)" % [failures.size(),checks])
	quit(0 if failures.is_empty() else 1)

func _geometry() -> void:
	# The frozen §3.2 table for a 2x2 host at (5,5).
	var host := [2,2]
	check(Logistics.directed_zone(Vector2i(5,5),host,"east") == Rect2i(7,5,3,3),"east zone matches frozen table")
	check(Logistics.directed_zone(Vector2i(5,5),host,"south") == Rect2i(4,7,3,3),"south zone matches frozen table")
	check(Logistics.directed_zone(Vector2i(5,5),host,"west") == Rect2i(2,4,3,3),"west zone matches frozen table")
	check(Logistics.directed_zone(Vector2i(5,5),host,"north") == Rect2i(5,2,3,3),"north zone matches frozen table")
	# Zones clip at the map edge without moving the host or granting land: the
	# map spans x -4..27, y 0..21, so a north-facing host at (5,1) keeps only
	# the bottom row of its zone.
	var w := World.new()
	w.logistics.provision()
	var uids := scaffold(w,[Vector2i(5,1)],["north"])
	check(w.logistics.deploy("trial-004",Vector2i(-1,-1),uids[0])["ok"],"north-edge station hosts growth gu")
	w.end_day()
	check(w.logistics.service_zone(w.logistics.instance("trial-004"),1) == Rect2i(5,0,3,1),"north zone clips to the map edge")
	w.grant_scaffold({"grass_seed":2})
	w.till(Vector2i(7,0))
	check(w.plant(Vector2i(7,0),"pasture_grass")["ok"],"clipped zone serves existing farmland only")
	check(Codec.normalize(w.to_snapshot())["ok"],"edge geometry snapshot valid")

func _single_slot_and_combination() -> void:
	var w := World.new()
	w.logistics.provision()
	# Three stations around (6,6): (4,4)+E, (7,3)+S, (4,7)+N all cover it.
	var uids := scaffold(w,[Vector2i(4,4),Vector2i(7,3),Vector2i(4,7)],["east","south","north"])
	check(w.logistics.deploy("trial-004",Vector2i(-1,-1),uids[0])["ok"],"growth gu admitted to the shared agriculture slot")
	check(not w.logistics.deploy("trial-008",Vector2i(-1,-1),uids[0])["ok"],"one slot rejects a second agriculture gu")
	check(not w.logistics.deploy("trial-007",Vector2i(-1,-1),uids[0])["ok"],"slot stays occupied for the same effect too")
	check(w.logistics.deploy("trial-008",Vector2i(-1,-1),uids[1])["ok"],"water gu admitted on the second host")
	check(not w.logistics.deploy("trial-010",Vector2i(-1,-1),uids[1])["ok"],"second host slot is occupied")
	check(w.logistics.deploy("trial-009",Vector2i(-1,-1),uids[2])["ok"],"another instance can use a free slot")
	w.logistics.withdraw("trial-009")
	check(w.logistics.deploy("trial-010",Vector2i(-1,-1),uids[2])["ok"],"fert gu admitted on the third host")
	w.till(Vector2i(6,6))
	w.plant(Vector2i(6,6),"golden_wheat")
	w.end_day()
	var outcome: Dictionary = w.logistics.resolve(Rect2i(Vector2i(6,6),Vector2i.ONE),["plant_grow"],1)
	check(int(outcome["groups"]["plant_growth_speed"]["value"])==150,"growth group adopted in combination")
	check(int(outcome["groups"]["plant_water_saving"]["value"])==50,"water group adopted in combination")
	check(int(outcome["groups"]["plant_fertility_saving"]["value"])==50,"fertility group adopted in combination")
	check(int(outcome["groups"]["plant_growth_speed"]["candidates"].size())==1,"one growth candidate per host slot")
	# Non-qualified targets (facilities, animals) carry no plant_grow tag.
	var facility_outcome: Dictionary = w.logistics.resolve(Rect2i(Vector2i(6,6),Vector2i.ONE),[],1)
	check(facility_outcome["groups"].is_empty(),"unqualified target gains no group")
	var mismatches := 0
	for entry in facility_outcome["rejected"]:
		if entry["reason"].contains("标签"): mismatches += 1
	check(mismatches==3,"rejected list explains every tag mismatch")
	check(Codec.normalize(w.to_snapshot())["ok"],"combination snapshot valid")

func _coverage_rules() -> void:
	var w := World.new()
	w.logistics.provision()
	# Station A east zone covers the left half of a 2x2 fast fir at (10,10);
	# station B south zone covers the right half; neither may serve it.
	var uids := scaffold(w,[Vector2i(6,9),Vector2i(12,7)],["east","south"])
	check(w.logistics.deploy("trial-004",Vector2i(-1,-1),uids[0])["ok"],"half-covering source A deployed")
	check(w.logistics.deploy("trial-007",Vector2i(-1,-1),uids[1])["ok"],"half-covering source B deployed")
	for cell in [Vector2i(10,10),Vector2i(11,10),Vector2i(10,11),Vector2i(11,11)]:
		w.till(cell)
	check(w.plant(Vector2i(10,10),"fast_fir")["ok"],"2x2 crop planted across both zones")
	w.end_day()
	var crop_rect := Rect2i(Vector2i(10,10),Vector2i(2,2))
	check(w.logistics.growth_percent(crop_rect,["plant_grow"],1)==100,"partial coverage from two sources never combines")
	var zone_a: Rect2i = w.logistics.service_zone(w.logistics.instance("trial-004"),1)
	var zone_b: Rect2i = w.logistics.service_zone(w.logistics.instance("trial-007"),1)
	check(zone_a.intersects(crop_rect) and not zone_a.encloses(crop_rect),"source A covers exactly part of the crop")
	check(zone_b.intersects(crop_rect) and not zone_b.encloses(crop_rect),"source B covers exactly part of the crop")
	# Anchor-only hits never substitute for the full footprint.
	var w2 := World.new()
	w2.logistics.provision()
	var uids2 := scaffold(w2,[Vector2i(4,4)])
	w2.logistics.deploy("trial-004",Vector2i(-1,-1),uids2[0])
	for cell in [Vector2i(8,4),Vector2i(9,4),Vector2i(8,5),Vector2i(9,5)]:
		w2.till(cell)
	check(w2.plant(Vector2i(8,4),"fast_fir")["ok"],"anchor-only crop planted beside the east zone")
	w2.end_day()
	check(w2.logistics.growth_percent(Rect2i(Vector2i(8,4),Vector2i(2,2)),["plant_grow"],1)==100,"anchor hit without full footprint grants nothing")

func _resolution_order() -> void:
	var w := World.new()
	w.logistics.provision()
	var uids := scaffold(w,[Vector2i(4,4),Vector2i(7,3)],["east","south"])
	w.logistics.deploy("trial-004",Vector2i(-1,-1),uids[0])
	w.logistics.deploy("trial-007",Vector2i(-1,-1),uids[1])
	w.till(Vector2i(6,5))
	w.plant(Vector2i(6,5),"golden_wheat")
	w.end_day()
	var target := Rect2i(Vector2i(6,5),Vector2i.ONE)
	# Same rank and value: the stable instance id decides, independent of order.
	var outcome: Dictionary = w.logistics.resolve(target,["plant_grow"],1)
	check(String(outcome["groups"]["plant_growth_speed"]["source"]["instance_id"])=="trial-004","equal sources break ties on the stable id")
	var suppressed := 0
	for entry in outcome["groups"]["plant_growth_speed"]["candidates"]:
		if not entry["adopted"]:
			suppressed += 1
			check(entry["reason"].contains("覆盖"),"suppressed source explains the override")
	check(suppressed==1,"exactly one same-tag source is suppressed")
	var paid := 0
	for id in ["trial-004","trial-007"]:
		if int(w.logistics.instance(id)["paid_day"])==1: paid += 1
	check(paid==2,"unadopted enabled source still pays maintenance")
	# A stronger rank wins while valid, and a dormant high rank steps aside.
	var rank2: Dictionary = w.logistics.instance("trial-007").duplicate(true)
	rank2["rank"] = 2
	w.logistics.state["instances"][6] = rank2
	outcome = w.logistics.resolve(target,["plant_grow"],1)
	check(int(outcome["groups"]["plant_growth_speed"]["source"]["rank"])==2,"higher rank wins the group")
	check(w.logistics.set_enabled("trial-007",false)["ok"],"high rank goes dormant")
	outcome = w.logistics.resolve(target,["plant_grow"],1)
	check(String(outcome["groups"]["plant_growth_speed"]["source"]["instance_id"])=="trial-004","dormant high rank never suppresses the valid low rank")
	# Unpaid sources are filtered before any ranking happens.
	var unpaid: Dictionary = w.logistics.instance("trial-004").duplicate(true)
	unpaid["instance_id"] = "test-unpaid"
	unpaid["rank"] = 3
	unpaid["paid_day"] = -1
	w.logistics.state["instances"].append(unpaid)
	outcome = w.logistics.resolve(target,["plant_grow"],1)
	check(int(outcome["groups"]["plant_growth_speed"]["source"]["rank"])==1,"unpaid source is filtered before ranking")
	w.logistics.state["instances"].pop_back()

func _fixed_precision() -> void:
	var w := World.new()
	w.logistics.provision()
	var captured := []
	w.operation_recorded.connect(func(entry): captured.append(entry))
	var uids := scaffold(w,[Vector2i(4,4),Vector2i(5,7)],["east","north"])
	check(w.logistics.deploy("trial-008",Vector2i(-1,-1),uids[0])["ok"],"water gu on the first host")
	check(w.logistics.deploy("trial-010",Vector2i(-1,-1),uids[1])["ok"],"fert gu on the north-facing second host")
	for cell in [Vector2i(6,4),Vector2i(7,4),Vector2i(6,5),Vector2i(7,5)]:
		w.till(cell)
		var index := w.grid.index_of(cell)
		w.environment[index][0] = 100
		w.environment[index][1] = 100
	check(w.plant(Vector2i(6,4),"fast_fir")["ok"],"2x2 fast fir inside both service zones")
	var anchor := w.grid.index_of(Vector2i(6,4))
	w.end_day()
	# Settle of day 0: gu are effective only from day 1, so day 0 pays the full
	# original deduction (3 water / 1 fertility per cell).
	check(int(w.environment[anchor][0])==97 and int(w.environment[anchor][1])==99,"pre-service day deducts the original amounts")
	w.end_day()
	# Day 1 with 50% retention: water 3x0.5 = 1.5 -> 1 deducted, 50 carried;
	# fertility 1x0.5 = 0.5 -> 0 deducted, 50 carried.
	check(int(w.environment[anchor][0])==96 and int(w.environment[anchor][1])==99,"retained day deducts floor and carries the fraction")
	var remainders: Dictionary = w.logistics.agri_to_save()["remainders"]
	check(int(remainders["water"].get("6,4",-1))==50 and int(remainders["fertility"].get("6,4",-1))==50,"hundredths remainders are persisted per cell")
	w.end_day()
	# Day 2: water 50+150 = 200 -> 2; fertility 50+50 = 100 -> 1. The two
	# retained fertility days together took exactly one point, never 0 or 2.
	check(int(w.environment[anchor][0])==94 and int(w.environment[anchor][1])==98,"accumulated fraction lands as one whole point across two days")
	# Rice is a plant target; it pays retained water but has no fertility use.
	# (Row 6 is the stone ridge, so the rice sits on the grass at (8,7).)
	w.logistics.deploy("trial-001",Vector2i(8,7))
	var rice_index := w.grid.index_of(Vector2i(8,7))
	w.environment[rice_index][1] = 42
	w.end_day()
	check(w.logistics.instance("trial-001")["job"].is_empty(),"deployed rice is only effective the next day")
	w.end_day()
	check(not w.logistics.instance("trial-001")["job"].is_empty(),"rice settles under the agriculture resolution")
	check(int(w.environment[rice_index][1])==42,"fert gu never invents fertility use for rice")
	var clamp_entries := captured.filter(func(e): return e.get("kind")=="agriculture" and e.get("stage")=="clamp")
	check(clamp_entries.is_empty(),"no fake free resources while the environment suffices")
	# Remainders survive a full JSON snapshot roundtrip and reload.
	var saved = JSON.parse_string(JSON.stringify(w.to_snapshot()))
	var restored := World.new()
	check(restored.apply_snapshot(saved)["ok"],"agriculture state serializes through JSON")
	check(restored.logistics.agri_to_save()["remainders"]==w.logistics.agri_to_save()["remainders"],"remainders survive reload unchanged")

func _facing_flow() -> void:
	var w := World.new()
	w.logistics.provision()
	var uids := scaffold(w,[Vector2i(4,4)])
	w.logistics.deploy("trial-004",Vector2i(-1,-1),uids[0])
	w.till(Vector2i(6,5))
	w.plant(Vector2i(6,5),"golden_wheat")
	w.end_day()
	var row: Dictionary = w.logistics.instance("trial-004")
	check(w.logistics.service_zone(row,1)==Rect2i(6,4,3,3),"default facing is east")
	var ap := w.clock.ap
	check(w.logistics.set_facing(uids[0],"south")["ok"],"facing commit costs 1 AP")
	check(w.clock.ap==ap-1,"facing commit spent the AP")
	check(w.logistics.service_zone(row,1)==Rect2i(6,4,3,3),"committed facing does not move today's locked zone")
	check(w.logistics.next_facing_of(uids[0])=="south","committed facing waits for the next opening")
	check(w.logistics.facing_of(uids[0])=="east","active facing stays east for the whole service day")
	check(not w.logistics.set_facing(uids[0],"south")["ok"],"same facing is rejected without spending AP")
	w.end_day()
	check(w.logistics.service_zone(w.logistics.instance("trial-004"),2)==Rect2i(3,6,3,3),"opening promotes the committed facing")
	check(w.logistics.growth_percent(Rect2i(Vector2i(6,5),Vector2i.ONE),["plant_grow"],2)==100,"turned-away crop loses the boost")
	check(Codec.normalize(w.to_snapshot())["ok"],"facing state serializes")

func _upgrade() -> void:
	# A real schema18-shaped save: six provisioned instances, growth deployed and
	# paid for today, no agriculture section.
	var w := World.new()
	w.logistics.provision()
	var uids := scaffold(w,[Vector2i(4,4)])
	w.logistics.deploy("trial-004",Vector2i(-1,-1),uids[0])
	w.till(Vector2i(3,4))
	w.plant(Vector2i(3,4),"golden_wheat")
	w.end_day()
	var snap := w.to_snapshot()
	snap["schema"] = 18
	snap["world"]["logistics"].erase("agri_supplement")
	snap["world"]["logistics"]["instances"] = snap["world"]["logistics"]["instances"].slice(0,6)
	snap["world"].erase("agriculture")
	var up := World.new()
	var result := up.apply_snapshot(snap)
	check(result["ok"],"schema18 upgrades losslessly")
	if not result["ok"]: print(result)
	check(up.logistics.state["instances"].size()==11,"upgrade supplements the five P10.1 instances once")
	check(bool(up.logistics.state["agri_supplement"]),"upgrade marks the supplement")
	for index in range(6,11):
		var r: Dictionary = up.logistics.state["instances"][index]
		check(not r["enabled"] and int(r["host_uid"])==0 and r["origin"].is_empty(),"supplement instance %d arrives undeployed" % (index+1))
	check(int(up.logistics.agri["legacy_until"])==1,"legacy switch day is the conversion day")
	# The already-paid day keeps the old contract: range-2 host expansion at 120%.
	check(up.logistics.growth_percent(Rect2i(Vector2i(3,4),Vector2i.ONE),["plant_grow"],1)==120,"legacy day keeps 120% and the old zone")
	var wheat_before := int(up.instance_at(Vector2i(3,4))["progress"])
	up.end_day()
	check(int(up.instance_at(Vector2i(3,4))["progress"])-wheat_before==120,"legacy-day settle actually advances at 120%")
	# After the switch the same crop sits outside the east zone and grows at the
	# natural rate; a cell inside the new zone would read 150% from day 2 on.
	check(up.logistics.growth_percent(Rect2i(Vector2i(3,4),Vector2i.ONE),["plant_grow"],2)==100,"outside the new zone the future day has no boost")
	check(up.logistics.growth_percent(Rect2i(Vector2i(6,4),Vector2i.ONE),["plant_grow"],2)==150,"inside the new east zone the future day is 150%")
	up.end_day()
	check(int(up.instance_at(Vector2i(3,4))["progress"])-wheat_before==220,"post-switch day advances at the natural rate only")
	check(not up.logistics.provision()["ok"],"upgraded save cannot reclaim the provision")
	# An unprovisioned 18 save provisions eleven directly.
	var fresh18 := World.new().to_snapshot()
	fresh18["schema"] = 18
	fresh18["world"]["logistics"].erase("agri_supplement")
	fresh18["world"].erase("agriculture")
	var up2 := World.new()
	check(up2.apply_snapshot(fresh18)["ok"],"unprovisioned schema18 upgrades")
	check(bool(up2.logistics.state["agri_supplement"]) and up2.logistics.state["instances"].is_empty(),"unprovisioned upgrade holds no instances")
	check(up2.logistics.provision()["ok"] and up2.logistics.state["instances"].size()==11,"later provision grants all eleven")
	check(int(up2.logistics.agri["legacy_until"])==0,"legacy marker is inert without a deployed growth gu")
	# A schema17 save upgrades through both hops.
	var old17 := World.new().to_snapshot()
	old17["schema"] = 17
	old17["world"].erase("logistics")
	old17["world"].erase("agriculture")
	var up3 := World.new()
	check(up3.apply_snapshot(old17)["ok"],"schema17 upgrades through both hops")
	check(up3.logistics.provision()["ok"] and up3.logistics.state["instances"].size()==11,"schema17 route also provisions eleven")

func _rejections() -> void:
	var w := World.new()
	w.logistics.provision()
	var uids := scaffold(w,[Vector2i(4,4),Vector2i(7,3)],["east","south"])
	w.logistics.deploy("trial-004",Vector2i(-1,-1),uids[0])
	w.till(Vector2i(6,5))
	w.plant(Vector2i(6,5),"golden_wheat")
	w.logistics.set_facing(uids[0],"south")
	w.end_day()
	var base = JSON.parse_string(JSON.stringify(w.to_snapshot()))
	for kind in ["agri_flag_18","agri_section_18","half_supplement","flag_mismatch","facing_dir","facing_host","remainder_zero","remainder_hundred","remainder_bounds","remainder_water","remainder_land","legacy_future"]:
		var b: Dictionary = base.duplicate(true)
		var agri: Dictionary = b["world"]["agriculture"]
		match kind:
			"agri_flag_18":
				b["schema"]=18
				b["world"]["logistics"].erase("agri_supplement")
				b["world"]["logistics"]["instances"]=b["world"]["logistics"]["instances"].slice(0,6)
			"agri_section_18":
				b["schema"]=18
				b["world"]["logistics"].erase("agri_supplement")
				b["world"]["logistics"]["instances"]=b["world"]["logistics"]["instances"].slice(0,6)
				b["world"]["agriculture"]["legacy_until"]=1
			"half_supplement":
				b["world"]["logistics"]["instances"]=b["world"]["logistics"]["instances"].slice(0,6)
			"flag_mismatch":
				b["world"]["logistics"]["agri_supplement"]=false
			"facing_dir": agri["facings"][str(uids[0])]["active"]="up"
			"facing_host": agri["facings"][9999]={"active":"east","next":"east"}
			"remainder_zero": agri["remainders"]["water"]["6,5"]=0
			"remainder_hundred": agri["remainders"]["water"]["6,5"]=100
			"remainder_bounds": agri["remainders"]["water"]["50,4"]=42
			"remainder_water": agri["remainders"]["water"]["5,25"]=42
			"remainder_land": agri["remainders"]["water"]["25,4"]=42
			"legacy_future": agri["legacy_until"]=99
		check(not Codec.normalize(b)["ok"],"reject agriculture corruption "+kind)
	check(Codec.normalize(base)["ok"],"clean agriculture snapshot still normalizes")

class FailingStore extends RefCounted:
	var inner
	var failing := false
	func _init(store): inner=store
	func active_slot() -> int: return inner.active_slot()
	func create_slot(slot: int, value: Dictionary, overwrite: bool=false) -> Dictionary: return inner.create_slot(slot,value,overwrite)
	func open_slot(slot: int) -> Dictionary: return inner.open_slot(slot)
	func commit(value: Dictionary) -> Dictionary: return {"ok":false,"reason":"isolated P10.1 write failure"} if failing else inner.commit(value)

func _transaction() -> void:
	var store := FailingStore.new(Store.new("res://.art-work/p101-model/transaction-%d" % Time.get_ticks_usec()))
	var w := World.new(store)
	check(w.start_new(1)["ok"],"isolated store creates the slot")
	w.logistics.provision()
	var uids := scaffold(w,[Vector2i(4,4)])
	w.logistics.deploy("trial-004",Vector2i(-1,-1),uids[0])
	w.till(Vector2i(6,5))
	w.plant(Vector2i(6,5),"golden_wheat")
	w.end_day()
	w.clock.ap = 1
	var before := w.to_snapshot()
	store.failing = true
	w.logistics.set_facing(uids[0],"west")
	check(not w.daily_save_error.is_empty(),"last-AP facing commit detects write failure")
	check(w.to_snapshot()==before,"facing rollback restores direction, remainders and production")
	var candidate: Dictionary = w._pending_day.duplicate(true)
	check(not candidate.is_empty() and Codec.normalize(candidate)["ok"],"retry candidate keeps a valid west-facing settlement")
	check(not w.retry_day_save()["ok"] and w.to_snapshot()==before,"failed retry publishes nothing")
	store.failing = false
	check(w.retry_day_save()["ok"],"retry publishes the candidate once")
	check(String(w.logistics.agri["facings"][uids[0]]["next"])=="west","published candidate carries the committed west facing")
	check(not w.retry_day_save()["ok"],"second retry cannot publish again")
	var after := w.to_snapshot()
	check(w.open_game(1)["ok"] and w.to_snapshot()==after,"disk save preserves facing and remainder state")
