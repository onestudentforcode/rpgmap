extends RefCounted
## Host admission stays in logistics. This module evaluates actual services,
## durable toys and cross-room contributions in the existing ranch clock.
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")
const Canonical := preload("res://scripts/farming/p8/p10_logistics.gd")
const Draw := preload("res://scripts/farming/p8/p102_rooms.gd")
var _owner: WeakRef
var world:
	get: return _owner.get_ref()
var config: Dictionary
var state := fresh()
var _day := -1
var _capacity := {}
var _served := {}
var _toy_zones := {}
var _maintenance := {}
var _extra := {}
var _nursery := {}
var _candidates := []

static func fresh() -> Dictionary:
	return {"agriculture":{},"toys":{},"systems":[],"next_system_uid":1,
		"contributions":{},"pools":{},"history":[],"random_seed":104729,"day":-1}

func _init(owner, settings: Dictionary) -> void:
	_owner=weakref(owner)
	config=settings.duplicate(true)

func record(stage: String, payload: Dictionary) -> void:
	var row:=payload.duplicate(true)
	row["kind"]="service"
	row["stage"]=stage
	row["day"]=_day if _day>=0 else world.clock.total_days
	state["history"].append(row)
	world.record_operation(row)

func zone_of_host(uid: int) -> Dictionary:
	for zone in world.ranch.state["zones"]:
		for facility in world.ranch._facilities_in_zone(zone):
			if int(facility["uid"])==uid: return zone
	return {}

func host_ready(uid: int) -> bool:
	var host: Dictionary=world.facilities.get(uid,{})
	if host.is_empty(): return false
	if String(host["facility_id"])=="field_service_station":
		var c:=Vector2i(int(host["origin"][0]),int(host["origin"][1]))
		if world.rooms.floor_kind(c)!="ordinary": return false
		var field: Dictionary=world.rooms.field(int(state["agriculture"].get(str(uid),0)))
		if field.is_empty() or field["cells"].size()<int(config["agriculture_min_cells"]): return false
		var adjacent:=false
		for text in field["cells"]:
			var at: Vector2i=world.rooms.cell_at(text)
			if not world.rooms.farmland(at): return false
			if absi(at.x-c.x)+absi(at.y-c.y)==1: adjacent=true
		return adjacent
	var zone:=zone_of_host(uid)
	return not zone.is_empty() and world.ranch.zone_structural(zone)

func agriculture_target(uid: int, cell: Vector2i) -> bool:
	var field: Dictionary=world.rooms.field(int(state["agriculture"].get(str(uid),0)))
	return host_ready(uid) and world.rooms.key(cell) in field.get("cells",[])

func link_agriculture(uid: int, field_uid: int) -> Dictionary:
	var allowed: Dictionary=world._can_act(0)
	if not allowed["ok"]: return allowed
	if not world.facilities.has(uid) or String(world.facilities[uid]["facility_id"])!="field_service_station": return world._error("请选择农业维护站")
	if field_uid!=0 and world.rooms.field(field_uid).is_empty(): return world._error("未知登记田块")
	state["agriculture"][str(uid)]=field_uid
	world.rooms._invalidate()
	record("agriculture_link",{"host":uid,"field":field_uid})
	world.changed.emit()
	return {"ok":true}

func install_toy(uid: int, install: bool) -> Dictionary:
	var allowed: Dictionary=world._can_act(int(config["install_ap"]))
	if not allowed["ok"]: return allowed
	if not world.facilities.has(uid) or String(world.facilities[uid]["facility_id"])!="toy_station": return world._error("请选择玩具站")
	var occupied: bool=state["toys"].has(str(uid))
	if occupied==install: return world._error("玩具槽状态未改变")
	if install:
		if not world.inventory.has("vine_ball",1): return world._error("缺少藤球，请在木工台制作")
		world.inventory.remove("vine_ball",1)
		state["toys"][str(uid)]="vine_ball"
		world._record_flow({},{"vine_ball":1},"玩具装入")
	else:
		state["toys"].erase(str(uid))
		world.inventory.add("vine_ball",1)
		world._record_flow({"vine_ball":1},{},"玩具卸下")
	record("toy_install" if install else "toy_remove",{"host":uid,"item":"vine_ball","count":1})
	return world._finish(int(config["install_ap"]),{"ok":true})

func system_of(zone_uid: int) -> Dictionary:
	for system in state["systems"]:
		if zone_uid in system["zones"]: return system
	return {}

func set_system(uid: int, label: String, zones: Array) -> Dictionary:
	var allowed: Dictionary=world._can_act(int(config["system_ap"]))
	if not allowed["ok"]: return allowed
	var seen:=[]
	for value in zones:
		if not Scalars.whole(value,1) or int(value) in seen or world.ranch.zone(int(value)).is_empty(): return world._error("系统房间不存在或重复")
		var owner:=system_of(int(value))
		if not owner.is_empty() and int(owner["uid"])!=uid: return world._error("房间已属于另一系统")
		seen.append(int(value))
	var target: Dictionary={}
	for row in state["systems"]:
		if int(row["uid"])==uid: target=row
	if uid>0 and target.is_empty(): return world._error("未知系统")
	if label.strip_edges().is_empty(): return world._error("系统需要名称")
	if not target.is_empty() and target["zones"]==seen and target["name"]==label.strip_edges(): return {"ok":true,"uid":uid}
	if target.is_empty():
		uid=int(state["next_system_uid"])
		state["next_system_uid"]=uid+1
		target={"uid":uid,"name":label.strip_edges(),"zones":seen}
		state["systems"].append(target)
	else:
		target["name"]=label.strip_edges()
		target["zones"]=seen
	record("system",target)
	return world._finish(int(config["system_ap"]),{"ok":true,"uid":uid})

func begin_day(day: int) -> void:
	_day=day
	_capacity.clear();_served.clear();_toy_zones.clear();_maintenance.clear()
	_extra.clear();_nursery.clear();_candidates.clear()

func mark_maintained(animal_uid: int, zone_uid: int, t: int) -> void:
	if not _maintenance.has(animal_uid): _maintenance[animal_uid]=[]
	_maintenance[animal_uid].append(zone_uid)
	record("maintenance",{"animal":animal_uid,"zone":zone_uid,"t":t})

func gu_service(row: Dictionary, kind: String, t: int) -> Dictionary:
	var identity:="%s:%d:%d" % [kind,int(row["uid"]),t]
	if _served.has(identity): return _served[identity]
	var zone: Dictionary=world.ranch.zone(int(row["zone_uid"]))
	if zone.is_empty() or not world.ranch.zone_structural(zone): return {}
	var choices:=[]
	for host in world.ranch._facilities_in_zone(zone):
		var gu: Dictionary=world.logistics.in_host(int(host["uid"]))
		if gu.is_empty() or not world.logistics.active(gu,_day): continue
		var definition: Dictionary=world.logistics.definition(gu)
		if String(definition["effect"])!=kind: continue
		choices.append({"host":int(host["uid"]),"instance":String(gu["instance_id"]),"rank":int(gu["rank"]),"value":int(definition["value"])})
	choices.sort_custom(func(a,b):
		if a["rank"]!=b["rank"]: return a["rank"]>b["rank"]
		return a["host"]<b["host"])
	var weight:=int(world.ranch.species_config(String(row["species_id"]))["space"])
	for choice in choices:
		var key:="%d:%d" % [choice["host"],t]
		if int(_capacity.get(key,0))+weight>int(config["capacity"]): continue
		_capacity[key]=int(_capacity.get(key,0))+weight
		choice["animal"]=int(row["uid"]);choice["t"]=t;choice["effect"]=kind;choice["space"]=weight
		_served[identity]=choice
		record("gu_service",choice)
		return choice
	return {}

## Level-3 gate (§16.2.11): the target zone counts as a level-2 intensive
## configuration only while one of its stations actually runs a paid product gu.
func product_service_ready(zone_row: Dictionary) -> bool:
	for host in world.ranch._facilities_in_zone(zone_row):
		var gu: Dictionary = world.logistics.in_host(int(host["uid"]))
		if gu.is_empty() or String(world.logistics.definition(gu)["effect"]) != "product_yield":
			continue
		if world.logistics.active(gu, _day if _day >= 0 else world.clock.total_days):
			return true
	return false

func toy_service(row: Dictionary, zone: Dictionary, t: int) -> void:
	var identity:="toy:%d:%d" % [int(row["uid"]),t]
	if _served.has(identity): return
	var weight:=int(world.ranch.species_config(String(row["species_id"]))["space"])
	for host in world.ranch._facilities_in_zone(zone):
		var uid:=int(host["uid"])
		if String(host["facility_id"])!="toy_station" or not state["toys"].has(str(uid)): continue
		var key:="%d:%d" % [uid,t]
		if int(_capacity.get(key,0))+weight>int(config["capacity"]): continue
		_capacity[key]=int(_capacity.get(key,0))+weight
		var roll:=Draw.draw(int(state["random_seed"]),"animal:"+str(row["uid"]),t,"toy")%100
		var extra:=int(config["toy_recovery"]) if roll<int(config["toy_percent"]) else 0
		var event:={"animal":int(row["uid"]),"t":t,"host":uid,"zone":int(zone["uid"]),"space":weight,"roll":roll,"extra":extra}
		_served[identity]=event
		if not _toy_zones.has(int(row["uid"])): _toy_zones[int(row["uid"])]=[]
		_toy_zones[int(row["uid"])].append(int(zone["uid"]))
		_extra[int(row["uid"])]=int(_extra.get(int(row["uid"]),0))+extra
		record("toy_service",event)
		return

func extra_recovery(uid: int) -> int:
	return int(_extra.get(uid,0))

func _components(system: Dictionary, type_id: String) -> Array:
	var out:=[]
	for uid in system.get("zones",[]):
		var zone: Dictionary=world.ranch.zone(int(uid))
		if not zone.is_empty() and String(zone["type"])==type_id and world.ranch.zone_structural(zone): out.append(zone)
	return out

func work_system(row: Dictionary) -> Dictionary:
	var system:=system_of(int(row["zone_uid"]))
	if system.is_empty(): return {}
	var zone: Dictionary=world.ranch.zone(int(row["zone_uid"]))
	var dispatch: int=world.ranch._dispatch_of(zone)
	var gu: Dictionary=world.logistics.in_host(dispatch)
	if gu.is_empty() or world.logistics.definition(gu)["effect"]!="work_speed" or not world.logistics.active(gu,_day): return {}
	var maintenance:=false
	for candidate in _components(system,"maintenance"):
		if int(candidate["dispatch_uid"])==dispatch: maintenance=true
	var pasture:=false
	for candidate in _components(system,"pasture"):
		if int(candidate["dispatch_uid"])!=dispatch: continue
		for host in world.ranch._facilities_in_zone(candidate):
			if state["toys"].has(str(host["uid"])): pasture=true
	return system if maintenance and pasture else {}

func breed_advance(row: Dictionary, t: int, increment: int) -> void:
	var system:=system_of(int(row["zone_uid"]))
	var source: Dictionary=_served.get("breed_speed:%d:%d" % [int(row["uid"]),t],{})
	if system.is_empty() or source.is_empty(): return
	var zone: Dictionary=world.ranch.zone(int(row["zone_uid"]))
	var target: Dictionary=world.ranch.zone(int(zone["birth_target"]))
	if target.is_empty() or not int(target["uid"]) in system["zones"] or not world.ranch.zone_structural(target): return
	var reserve_key:="%d:%d" % [int(target["uid"]),t]
	if not _nursery.has(reserve_key): _nursery[reserve_key]={"space":0,"beds":[]}
	var reservation: Dictionary=_nursery[reserve_key]
	var species: Dictionary=world.ranch.species_config(String(row["species_id"]))
	var weight:=int(species["space"])
	if world.ranch._zone_usage(target)+int(reservation["space"])+weight>world.ranch.available_space(target): return
	var selected:=""
	for bed in world.ranch.free_bed_slots(target,String(species["bed"])):
		var key:="%d:%d" % [bed["uid"],bed["slot"]]
		if not key in reservation["beds"]: selected=key;break
	if selected.is_empty(): return
	reservation["beds"].append(selected);reservation["space"]=int(reservation["space"])+weight
	var identity:="%d:%d" % [row["uid"],row["breed"]["round"]]
	if not state["contributions"].has(identity): state["contributions"][identity]={}
	var counters: Dictionary=state["contributions"][identity]
	var key:=str(target["uid"])
	counters[key]=int(counters.get(key,0))+increment
	record("breed_contribution",{"identity":identity,"target":int(target["uid"]),"points":increment,"total":int(counters[key]),"bed":selected,"space":weight,"t":t,"available":world.ranch.available_space(target),"occupied":world.ranch._zone_usage(target)})

func birth_bonus(parent: Dictionary, child: Dictionary, target_uid: int) -> void:
	var identity:="%d:%d" % [parent["uid"],parent["breed"]["round"]]
	var points:=int(state["contributions"].get(identity,{}).get(str(target_uid),0))
	var species: Dictionary=world.ranch.species_config(String(parent["species_id"]))
	var gift:=int(int(species["growth_units"])*points*int(config["birth_percent"])/(100*int(species["breed_units"])))
	child["growth"]=gift
	state["contributions"].erase(identity)
	record("birth_bonus",{"identity":identity,"parent":int(parent["uid"]),"child":int(child["uid"]),"target":target_uid,"eligible":points,"gift":gift,"growth_target":int(species["growth_units"]),"breed_target":int(species["breed_units"])})

func use_carry(row: Dictionary, yard: int, post: int, recipe: String, t: int, batch: int) -> int:
	if work_system(row).is_empty(): return 0
	var key:="%d:%d" % [yard,post]
	var pool: Dictionary=state["pools"].get(key,{})
	if pool.is_empty() or pool["recipe"]!=recipe or int(pool["points"])==0: return 0
	var amount:=int(pool["points"])
	pool["points"]=0
	record("pool_use",{"key":key,"recipe":recipe,"points":amount,"animal":int(row["uid"]),"t":t,"batch":batch})
	return amount

func capture_carry(row: Dictionary, yard: int, post: int, recipe: String, overflow: int, t: int, batch: int) -> void:
	var system:=work_system(row)
	if overflow<=0 or system.is_empty() or not _served.has("work_speed:%d:%d" % [int(row["uid"]),t]): return
	var event:={"key":"%d:%d" % [yard,post],"recipe":recipe,"points":overflow,"animal":int(row["uid"]),"system":int(system["uid"]),"t":t,"batch":batch}
	_candidates.append(event)
	record("pool_candidate",event)

func end_day() -> void:
	for event in _candidates:
		var system: Dictionary={}
		for candidate in state["systems"]:
			if int(candidate["uid"])==int(event["system"]): system=candidate
		var valid_maintenance:=false
		for zone in _maintenance.get(int(event["animal"]),[]):
			if zone in system.get("zones",[]): valid_maintenance=true
		var valid_toy:=false
		for zone in _toy_zones.get(int(event["animal"]),[]):
			if zone in system.get("zones",[]): valid_toy=true
		if not valid_maintenance or not valid_toy:
			record("pool_discard",event)
			continue
		var key:=String(event["key"])
		if not state["pools"].has(key): state["pools"][key]={"recipe":event["recipe"],"points":0}
		var pool: Dictionary=state["pools"][key]
		var before:=int(pool["points"])
		var credited:=mini(int(event["points"]),int(config["carry_cap"])-before)
		pool["points"]=before+credited
		var receipt: Dictionary=event.duplicate()
		receipt["credited"]=credited;receipt["discarded"]=int(event["points"])-credited
		record("pool_credit",receipt)
	state["day"]=_day
	_candidates.clear()
	for identity in state["contributions"].keys():
		if world.ranch.animal(int(String(identity).split(":")[0])).is_empty():
			state["contributions"].erase(identity)
			record("contribution_drop",{"identity":identity})
	_day=-1

func level_of(zone: Dictionary) -> Dictionary:
	if not world.ranch.zone_structural(zone): return {"level":0,"active":false}
	var installed:=false
	var running:=false
	for host in world.ranch._facilities_in_zone(zone):
		var uid:=int(host["uid"])
		if state["toys"].has(str(uid)): installed=true;running=true
		var gu: Dictionary=world.logistics.in_host(uid)
		if not gu.is_empty() and world.logistics.definition(gu)["effect"] in ["breed_speed","work_speed","product_yield","feed_saving"]:
			installed=true
			running=running or world.logistics.active(gu,world.clock.total_days)
	return {"level":2 if installed else 1,"active":running if installed else true}

func drop_carry(yard: int) -> Dictionary:
	var allowed: Dictionary=world._can_act(0)
	if not allowed["ok"]: return allowed
	for key in state["pools"].keys():
		if int(String(key).split(":")[0])==yard:
			var pool: Dictionary=state["pools"][key]
			record("pool_drop",{"key":key,"recipe":pool["recipe"],"points":int(pool["points"])})
			state["pools"].erase(key)
	world.changed.emit()
	return {"ok":true}

func has_carry(yard: int) -> bool:
	for key in state["pools"]:
		if int(String(key).split(":")[0])==yard and int(state["pools"][key]["points"])>0: return true
	return false

func forget_facility(uid: int) -> void:
	state["agriculture"].erase(str(uid))
	for key in state["pools"].keys():
		if int(String(key).split(":")[0])==uid: state["pools"].erase(key)

func forget_field(uid: int) -> void:
	for key in state["agriculture"]:
		if int(state["agriculture"][key])==uid: state["agriculture"][key]=0

func forget_zone(uid: int) -> void:
	for system in state["systems"]:
		if uid in system["zones"]:
			system["zones"].erase(uid)
			record("system",system)

func to_save() -> Dictionary: return state.duplicate(true)
func apply_save(value: Dictionary) -> void: state=Canonical._canonical(value)

static func normalize(value, snapshot: Dictionary, catalog) -> Dictionary:
	if not Scalars.exact(value,fresh().keys()): return Scalars.fail("生产服务快照结构非法")
	if not Scalars.whole(value["random_seed"],1,2147483647) or not Scalars.whole(value["day"],-1,int(snapshot["clock"]["total_days"])) or not Scalars.whole(value["next_system_uid"],1): return Scalars.fail("服务种子或序号非法")
	for field in ["agriculture","toys","contributions","pools"]:
		if not value[field] is Dictionary: return Scalars.fail("服务索引非法")
	if not value["systems"] is Array or not value["history"] is Array: return Scalars.fail("服务列表非法")
	var history_check:=preload("res://scripts/farming/p8/p104_codec.gd").validate(value,snapshot,catalog)
	if not history_check["ok"]: return history_check
	var facilities:={}
	for host in snapshot["world"]["facilities"]: facilities[int(host["uid"])]=host
	for key in value["toys"]:
		if not facilities.has(int(key)) or facilities[int(key)]["facility_id"]!="toy_station" or value["toys"][key]!="vine_ball": return Scalars.fail("玩具安装记录非法")
	for key in value["agriculture"]:
		if not facilities.has(int(key)) or facilities[int(key)]["facility_id"]!="field_service_station" or not Scalars.whole(value["agriculture"][key],0): return Scalars.fail("农业服务关联非法")
	var systems:={}
	var owned:={}
	for row in value["systems"]:
		if not Scalars.exact(row,["uid","name","zones"]) or not Scalars.whole(row["uid"],1,int(value["next_system_uid"])-1) or systems.has(int(row["uid"])) or not row["name"] is String or String(row["name"]).strip_edges().is_empty() or not row["zones"] is Array: return Scalars.fail("生产系统身份非法")
		systems[int(row["uid"])]=true
		for uid in row["zones"]:
			if not Scalars.whole(uid,1,int(snapshot["world"]["ranch"]["next_zone_uid"])-1) or owned.has(int(uid)): return Scalars.fail("系统房间重复或未知")
			owned[int(uid)]=true
	var balances:={}
	var births:={}
	var toys:={}
	for event in value["history"]:
		if not event is Dictionary or event.get("kind")!="service" or not event.get("stage") is String or not Scalars.whole(event.get("day"),0,int(snapshot["clock"]["total_days"])): return Scalars.fail("服务收据非法")
		var stage:=String(event["stage"])
		if stage=="toy_service":
			var key:="%d:%d" % [int(event["animal"]),int(event["t"])]
			var roll:=Draw.draw(int(value["random_seed"]),"animal:"+str(int(event["animal"])),int(event["t"]),"toy")%100
			if toys.has(key) or event["roll"]!=roll or event["extra"]!=(1 if roll<10 else 0): return Scalars.fail("玩具重复服务或概率被篡改")
			toys[key]=true
		if stage=="birth_bonus":
			if births.has(event["identity"]) or event["gift"]!=int(int(event["growth_target"])*int(event["eligible"])/(10*int(event["breed_target"]))): return Scalars.fail("初始成长重复或被篡改")
			births[event["identity"]]=true
		if stage in ["pool_credit","pool_use","pool_drop"]:
			var key:=String(event["key"])
			balances[key]=int(balances.get(key,0))+(int(event["credited"]) if stage=="pool_credit" else -int(event["points"]))
			if int(balances[key])<0: return Scalars.fail("工作余量无源支出")
	for key in value["pools"]:
		var pool=value["pools"][key]
		if not Scalars.exact(pool,["recipe","points"]) or not Scalars.whole(pool["points"],0,10000) or not catalog.load_data()["p103"]["work"]["recipes"].has(pool["recipe"]) or int(pool["points"])!=int(balances.get(key,0)): return Scalars.fail("工作余量不守恒")
	for key in balances:
		if int(balances[key])!=int(value["pools"].get(key,{}).get("points",0)): return Scalars.fail("工作余量凭空消失")
	return {"ok":true,"services":Canonical._canonical(value)}
