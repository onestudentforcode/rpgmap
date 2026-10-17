extends RefCounted
## Logistics owns deployment/paid service days, never upstream acquisition or
## growth. All mutations run inside the world's existing candidate transaction.
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")
const Grid := preload("res://scripts/farming/core/grid/land_grid.gd")
var _owner: WeakRef
var world:
	get: return _owner.get_ref()
var config: Dictionary
var definitions := {}
var state := fresh()

static func fresh() -> Dictionary:
	return {"provisioned": false, "instances": [], "active_day": -1, "history": [], "spent": 0}

func _init(owner, settings: Dictionary) -> void:
	_owner = weakref(owner)
	config = _canonical(settings)
	for row in config["definitions"]: definitions[String(row["id"])] = row

func instance(id: String) -> Dictionary:
	for row in state["instances"]:
		if row["instance_id"] == id: return row
	return {}

func definition(row: Dictionary) -> Dictionary:
	return definitions.get(String(row.get("definition_id", "")), {})

## Read-only boundary for a future provider. Copying this result never grants
## instances or mutates the upstream inventory. Unsupported/combat rows reject.
func available_instances(provider_rows: Array) -> Dictionary:
	var result := []
	var seen := {}
	for row in provider_rows:
		if not row is Dictionary or not row.get("instance_id") is String or String(row["instance_id"]).is_empty() or seen.has(row["instance_id"]):
			return world._error("可派遣实例ID缺失或重复")
		if not definitions.has(row.get("definition_id")) or not Scalars.whole(row.get("rank"), 1, 5) or row.get("role") != "logistics":
			return world._error("仅接受已登记的一至五转后勤蛊实例")
		seen[row["instance_id"]] = true
		result.append(row.duplicate(true))
	return {"ok": true, "instances": result}

func provision() -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]: return checked
	if state["provisioned"]: return world._error("本档已领取试用配给")
	for index in range(config["provision"].size()):
		state["instances"].append({"instance_id": "trial-%03d" % (index+1), "definition_id": config["provision"][index],
			"rank": 1, "host_uid": 0, "origin": [], "enabled": false, "effective_day": 0,
			"paid_day": -1, "paid_fee": 0, "paid_food": {}, "reason": "未部署", "job": {}})
	state["provisioned"] = true
	return world._finish(0, {"ok": true})

func deployed(row: Dictionary) -> bool:
	return int(row["host_uid"]) > 0 or not row["origin"].is_empty()

func at(cell: Vector2i) -> Dictionary:
	for row in state["instances"]:
		if row["origin"] == [cell.x, cell.y]: return row
	return {}

func in_host(uid: int) -> Dictionary:
	for row in state["instances"]:
		if int(row["host_uid"]) == uid and uid > 0: return row
	return {}

func compatible(row: Dictionary, uid: int) -> bool:
	if not world.facilities.has(uid): return false
	var host: Dictionary = world.facility_defs[world.facilities[uid]["facility_id"]]
	var d := definition(row)
	return d["deployment"] == "host" and host.get("kind", "facility") in d["host_kinds"] and host.get("gu_slot", "") == d["slot"] and d["slot"] in d["tags"]

func quote_deploy(id: String, cell: Vector2i = Vector2i(-1,-1), host_uid: int = 0) -> Dictionary:
	var row := instance(id)
	if row.is_empty(): return world._error("未知后勤蛊实例")
	if deployed(row): return world._error("此实例已部署，请先撤回")
	var d := definition(row)
	if d["deployment"] == "host":
		if not compatible(row, host_uid): return world._error("设施类型或能力标签不兼容")
		if not in_host(host_uid).is_empty(): return world._error("蛊虫槽已占用")
		if not world.research.active_project(host_uid).is_empty() or not world.facilities[host_uid]["batch"].is_empty():
			return world._error("设施有运行任务，完成后才能更换研究方案")
	else:
		if host_uid != 0 or not world.grid.in_bounds(cell.x,cell.y) or not world.source_at(cell).is_empty(): return world._error("地块未开放或覆盖资源点")
		var reserve: Dictionary = world.grid.can_reserve(cell,1,1,"gu:"+id)
		if not reserve["ok"]: return world._error("地块被占用或不可部署")
	return {"ok": true, "ap": int(config["deploy_ap"]), "fee": int(d["fee"]), "food": d["food"].duplicate(), "effective_day": world.clock.total_days+1}

func deploy(id: String, cell: Vector2i = Vector2i(-1,-1), host_uid: int = 0) -> Dictionary:
	var checked: Dictionary = world._can_act(int(config["deploy_ap"]))
	if not checked["ok"]: return checked
	checked = quote_deploy(id,cell,host_uid)
	if not checked["ok"]: return checked
	var row := instance(id)
	row["host_uid"] = host_uid
	if definition(row)["deployment"] == "independent":
		world.grid.reserve(cell,1,1,"gu:"+id)
		row["origin"] = [cell.x,cell.y]
		# Preserve already-tilled ground through snapshots as facilities do.
		if world.grid._prev.get(cell) == Grid.State.TILLED: world._tilled_under_buildings[cell] = true
	row["enabled"] = true
	row["effective_day"] = world.clock.total_days+1
	row["reason"] = "次日启用"
	return world._finish(int(config["deploy_ap"]), {"ok": true})

func locked(id: String) -> bool:
	var row := instance(id)
	if row.is_empty(): return false
	return not row["job"].is_empty() or (int(row["host_uid"]) > 0 and not world.research.active_project(int(row["host_uid"])).is_empty())

func withdraw(id: String) -> Dictionary:
	var checked: Dictionary = world._can_act(int(config["deploy_ap"]))
	if not checked["ok"]: return checked
	var row := instance(id)
	if row.is_empty() or not deployed(row): return world._error("此蛊未部署")
	if locked(id): return world._error("生产/研究任务或待收产物锁定此蛊，请先完成收取或取消任务")
	if not row["origin"].is_empty():
		var cell := Vector2i(int(row["origin"][0]),int(row["origin"][1]))
		world.grid.release("gu:"+id)
		world._tilled_under_buildings.erase(cell)
	row["origin"] = []
	row["host_uid"] = 0
	row["enabled"] = false
	row["reason"] = "未部署"
	return world._finish(int(config["deploy_ap"]), {"ok": true})

func set_enabled(id: String, enabled: bool) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]: return checked
	var row := instance(id)
	if row.is_empty() or not deployed(row): return world._error("请先部署后勤蛊")
	if bool(row["enabled"]) == enabled: return world._error("启停状态未改变")
	# A registered research receipt is already paid work. Disallow revoking its
	# qualification before settlement; pausing the project remains available.
	if not enabled and int(row["host_uid"]) > 0:
		var project: Dictionary = world.research.active_project(int(row["host_uid"]))
		if not project.is_empty() and project["worked"].has(world.clock.total_days): return world._error("今日研究工作已登记，日结后可休眠")
	row["enabled"] = enabled
	row["effective_day"] = world.clock.total_days+1
	row["reason"] = "次日恢复" if enabled else "手动休眠"
	return world._finish(0, {"ok": true})

func active(row: Dictionary, day: int) -> bool:
	return deployed(row) and bool(row["enabled"]) and int(row["effective_day"]) <= day and int(row["paid_day"]) == day

func run_opening(day: int) -> void:
	if int(state["active_day"]) == day: return
	state["active_day"] = day
	var receipt := {"day": day, "fees": 0, "food": {}, "services": []}
	# Provision IDs are stable and ordered; never depend on dictionary iteration.
	var rows: Array = state["instances"].duplicate()
	rows.sort_custom(func(a,b): return a["instance_id"] < b["instance_id"])
	for row in rows:
		if not deployed(row) or not row["enabled"] or int(row["effective_day"]) > day: continue
		var d := definition(row)
		if world.primeval_stones < int(d["fee"]):
			row["enabled"] = false
			row["reason"] = "元石不足，自动休眠；需手动申请恢复"
			continue
		var enough := true
		for item in d["food"]:
			if not world.inventory.has(item,int(d["food"][item])): enough = false
		if not enough:
			row["reason"] = "特殊食料不足，运行受阻"
			continue
		world.primeval_stones -= int(d["fee"])
		world._cash("purchase_spend",int(d["fee"]))
		state["spent"] = int(state["spent"]) + int(d["fee"])
		for item in d["food"]:
			world.inventory.remove(item,int(d["food"][item]))
			receipt["food"][item] = int(receipt["food"].get(item,0))+int(d["food"][item])
		world._record_flow({},d["food"],"后勤蛊特殊食料")
		row["paid_day"] = day
		row["paid_fee"] = int(d["fee"])
		row["paid_food"] = d["food"].duplicate()
		row["reason"] = "运行中"
		receipt["fees"] += int(d["fee"])
		receipt["services"].append(row["instance_id"])
		world.record_operation({"kind":"logistics", "stage":"maintenance", "day":day,
			"instance_id":row["instance_id"], "fee":int(d["fee"]), "inputs":d["food"].duplicate()})
	state["history"].append(receipt)
	if state["history"].size() > 15: state["history"].pop_front()

func coverage(row: Dictionary) -> Rect2i:
	var origin: Array = row["origin"]
	var shape := [1,1]
	if int(row["host_uid"]) > 0 and world.facilities.has(int(row["host_uid"])):
		var host: Dictionary = world.facilities[int(row["host_uid"])]
		origin = host["origin"]
		shape = world.facility_defs[host["facility_id"]]["footprint"]
	if origin.is_empty(): return Rect2i()
	var r := int(definition(row)["range"])
	return Rect2i(int(origin[0])-r,int(origin[1])-r,int(shape[0])+r*2,int(shape[1])+r*2).intersection(world.grid.bounds())

func effects_at(cell: Vector2i, effect: String, day: int, target_tags: Array = []) -> Array:
	var out := []
	for row in state["instances"]:
		var d := definition(row)
		if not target_tags.is_empty():
			var match_target := false
			for tag in target_tags:
				if tag in d["target_tags"]: match_target = true
			if not match_target: continue
		if d["effect"] == effect and active(row,day) and coverage(row).has_point(cell):
			out.append({"instance_id":row["instance_id"], "name":d["name"], "value":int(d["value"])})
	return out

func light_at(cell: Vector2i, day: int) -> int:
	var value := 0
	for effect in effects_at(cell,"light",day): value = maxi(value,int(effect["value"]))
	return value

func growth_percent(cell: Vector2i, day: int) -> int:
	var value := 100
	for effect in effects_at(cell,"growth_speed",day,["biological_production"]): value = maxi(value,int(effect["value"]))
	return value

func research_modifier(uid: int) -> Dictionary:
	var row := in_host(uid)
	var result := {"instance_id":"", "flat":0, "speed":1, "materials":100}
	if row.is_empty(): return result
	result["instance_id"] = row["instance_id"]
	var d := definition(row)
	if d["effect"] == "research_flat": result["flat"] = int(d["value"])
	if d["effect"] == "research_speed": result["speed"] = int(d["value"])/100
	result["materials"] = int(d.get("material_percent",100))
	return result

func blockers(row: Dictionary, day: int) -> Array:
	var reasons := []
	if not deployed(row): return ["未部署"]
	if not active(row,day): reasons.append(String(row["reason"]))
	var d := definition(row)
	if d.has("production"):
		var env: Dictionary = world.environment_at(Vector2i(int(row["origin"][0]),int(row["origin"][1])))
		if int(env["water"]) < int(d["production"]["min_water"]): reasons.append("水分不足")
		if int(env["light"]) < int(d["production"]["min_light"]): reasons.append("光照不足")
	return reasons

func settle(day: int) -> void:
	for row in state["instances"]:
		var d := definition(row)
		if not d.has("production") or not deployed(row): continue
		if not blockers(row,day).is_empty(): continue
		var p: Dictionary = d["production"]
		var job: Dictionary = row["job"]
		if job.is_empty():
			var enough := true
			for item in p["inputs"]:
				if not world.inventory.has(item,int(p["inputs"][item])): enough = false
			if not enough:
				row["reason"] = "生产原料不足"
				continue
			for item in p["inputs"]: world.inventory.remove(item,int(p["inputs"][item]))
			world._record_flow({},p["inputs"],"后勤蛊生产投料")
			job = {"target":int(p["days"])*100,"progress":0,"inputs":p["inputs"].duplicate(),"outputs":p["outputs"].duplicate(),"ready":false}
			row["job"] = job
		if job["ready"]: continue
		var cell := Vector2i(int(row["origin"][0]),int(row["origin"][1]))
		job["progress"] = mini(int(job["target"]),int(job["progress"])+growth_percent(cell,day))
		job["ready"] = job["progress"] == job["target"]
		var index: int = world.grid.index_of(cell)
		world.environment[index][0] = maxi(0,int(world.environment[index][0])-int(p["water_use"]))
		world.record_operation({"kind":"logistics", "stage":"progress", "day":day,"instance_id":row["instance_id"],"progress":job["progress"],"ready":job["ready"]})

func claim(id: String) -> Dictionary:
	var checked: Dictionary = world._can_act(int(config["claim_ap"]))
	if not checked["ok"]: return checked
	var row := instance(id)
	if row.is_empty() or row["job"].is_empty() or not row["job"]["ready"]: return world._error("尚无可收取产物")
	var outputs: Dictionary = row["job"]["outputs"].duplicate()
	for item in outputs: world.inventory.add(item,int(outputs[item]))
	world._record_flow(outputs,{},"后勤蛊产物收取")
	row["job"] = {}
	world.record_operation({"kind":"logistics", "stage":"claim", "day":world.clock.total_days,"instance_id":id,"outputs":outputs})
	return world._finish(int(config["claim_ap"]),{"ok":true,"items":outputs})

func cancel_job(id: String) -> Dictionary:
	var checked: Dictionary = world._can_act(0)
	if not checked["ok"]: return checked
	var row := instance(id)
	if row.is_empty() or row["job"].is_empty() or row["job"].get("ready",false): return world._error("没有可取消的在制任务；待收产物请先收取")
	row["job"] = {}
	return world._finish(0,{"ok":true})

func to_save() -> Dictionary:
	return state.duplicate(true)

func apply_save(value: Dictionary) -> void:
	state = value.duplicate(true)
	for row in state["instances"]:
		if row["origin"].is_empty(): continue
		var cell := Vector2i(int(row["origin"][0]),int(row["origin"][1]))
		var tilled: bool = world.grid.state_at(cell) == Grid.State.TILLED
		world.grid.reserve(cell,1,1,"gu:"+String(row["instance_id"]))
		if tilled: world._tilled_under_buildings[cell] = true

static func normalize(value, day: int, body: Dictionary, catalog) -> Dictionary:
	if not Scalars.exact(value,fresh().keys()) or not value["provisioned"] is bool or not value["instances"] is Array or not value["history"] is Array or not Scalars.whole(value["spent"]) or not Scalars.whole(value["active_day"],-1,day):
		return Scalars.fail("后勤蛊快照结构非法")
	# Validate scalar ranges before canonicalizing; never round invalid fractions.
	var cfg: Dictionary = _canonical(catalog.load_data()["logistics"])
	var defs := {}
	for d in cfg["definitions"]: defs[d["id"]] = d
	if value["instances"].size() != (cfg["provision"].size() if value["provisioned"] else 0): return Scalars.fail("试用实例配给数量非法")
	var occupied := {}
	var hosts := {}
	var facilities := {}
	var m: Dictionary = catalog.load_map()
	var width := int(m["size"][0])
	var height := int(m["size"][1])
	var origin_x := int(m.get("origin_x",0))
	for source in catalog.definitions("sources").values(): occupied[str(source["position"])] = true
	for section in ["crops","facilities"]:
		for r in body["world"][section]:
			var def: Dictionary = catalog.definitions(section)[r["crop_id"] if section == "crops" else r["facility_id"]]
			for y in range(int(def["footprint"][1])):
				for x in range(int(def["footprint"][0])): occupied[str([int(r["origin"][0])+x,int(r["origin"][1])+y])] = true
			if section == "facilities": facilities[int(r["uid"])] = def
	var seen := {}
	for index in range(value["instances"].size()):
		var r = value["instances"][index]
		if not Scalars.exact(r,["instance_id","definition_id","rank","host_uid","origin","enabled","effective_day","paid_day","paid_fee","paid_food","reason","job"]): return Scalars.fail("后勤蛊实例字段非法")
		if r["instance_id"] != "trial-%03d" % (index+1) or seen.has(r["instance_id"]) or r["definition_id"] != cfg["provision"][index] or not Scalars.whole(r["rank"],1,5): return Scalars.fail("后勤蛊实例身份或转数非法")
		if not r["job"] is Dictionary: return Scalars.fail("后勤蛊任务结构非法")
		seen[r["instance_id"]] = true
		var d: Dictionary = defs[r["definition_id"]]
		if not r["enabled"] is bool or not Scalars.whole(r["host_uid"]) or not r["origin"] is Array or not r["reason"] is String or not Scalars.whole(r["effective_day"],0,day+1) or not Scalars.whole(r["paid_day"],-1,day): return Scalars.fail("后勤蛊部署状态非法")
		if int(r["paid_day"]) > int(value["active_day"]) or (r["paid_day"] == -1 and (r["paid_fee"] != 0 or r["paid_food"] != {})) or (r["paid_day"] >= 0 and (r["paid_fee"] != d["fee"] or not _quantities_equal(r["paid_food"],d["food"]))): return Scalars.fail("后勤蛊付费收据非法")
		if not r["origin"].is_empty():
			if d["deployment"] != "independent" or r["host_uid"] != 0 or not Scalars.coordinate(r["origin"],width,height,origin_x) or occupied.has(str(r["origin"])): return Scalars.fail("独立蛊占地非法或重叠")
			var c := Vector2i(int(r["origin"][0]),int(r["origin"][1]))
			if not catalog.tillable_map().get(m["grid"][c.y][c.x-origin_x],false): return Scalars.fail("独立蛊占地地形非法")
			var land_cfg: Dictionary = catalog.load_data().get("_unused",{})
			# Ownership is validated from the actual parcel configuration.
			var land_script = load("res://scripts/farming/p8/p8_land.gd")
			land_cfg = land_script.settings()
			var owned: bool = land_script.rect(land_cfg["base"]).has_point(c)
			for parcel in land_cfg["parcels"]:
				if parcel["id"] in body["world"]["land"]["purchased"] and land_script.rect(parcel["rect"]).has_point(c): owned = true
			if not owned: return Scalars.fail("独立蛊位于未购地块")
			occupied[str(r["origin"])] = true
		if int(r["host_uid"]) > 0:
			if d["deployment"] != "host" or not facilities.has(int(r["host_uid"])) or hosts.has(r["host_uid"]): return Scalars.fail("后勤蛊宿主未知或重复占槽")
			var host: Dictionary = facilities[int(r["host_uid"])]
			if host.get("kind","facility") not in d["host_kinds"] or host.get("gu_slot","") != d["slot"]: return Scalars.fail("后勤蛊宿主标签不兼容")
			hosts[r["host_uid"]] = true
		if r["origin"].is_empty() and r["host_uid"] == 0 and (r["enabled"] or not r["job"].is_empty()): return Scalars.fail("未部署蛊不可启用或有任务")
		if not r["job"].is_empty():
			var job: Dictionary = r["job"]
			if not d.has("production") or not Scalars.exact(job,["target","progress","inputs","outputs","ready"]): return Scalars.fail("后勤蛊任务字段非法")
			var p: Dictionary = d["production"]
			if job["target"] != int(p["days"])*100 or not _quantities_equal(job["inputs"],p["inputs"]) or not _quantities_equal(job["outputs"],p["outputs"]) or not Scalars.whole(job["progress"],0,int(job["target"])) or not job["ready"] is bool or job["ready"] != (job["progress"] == job["target"]): return Scalars.fail("后勤蛊在制进度或投入产出非法")
	if value["history"].size() > 15: return Scalars.fail("后勤蛊维护历史过长")
	var previous := -1
	var history_spent := 0
	var last_services := []
	for receipt in value["history"]:
		if not Scalars.exact(receipt,["day","fees","food","services"]) or not Scalars.whole(receipt["day"],previous+1,day) or not receipt["services"] is Array: return Scalars.fail("后勤蛊维护日报非法")
		previous = int(receipt["day"])
		if previous == int(value["active_day"]): last_services = receipt["services"]
		var fee := 0
		var food := {}
		var served := []
		for id in receipt["services"]:
			if not seen.has(id) or id in served: return Scalars.fail("后勤蛊维护服务未知或重复")
			served.append(id)
			var r: Dictionary = value["instances"][int(String(id).trim_prefix("trial-"))-1]
			var d: Dictionary = defs[r["definition_id"]]
			fee += int(d["fee"])
			for item in d["food"]: food[item] = int(food.get(item,0))+int(d["food"][item])
			if int(receipt["day"]) == int(value["active_day"]) and int(r["paid_day"]) != int(receipt["day"]): return Scalars.fail("后勤蛊当日服务与扣费标记不符")
		if receipt["fees"] != fee or not _quantities_equal(receipt["food"],food): return Scalars.fail("后勤蛊维护金额或食料不符")
		history_spent += fee
	if history_spent > int(value["spent"]) or previous != int(value["active_day"]): return Scalars.fail("后勤蛊维护总账/日期不符")
	for r in value["instances"]:
		if int(r["paid_day"]) >= 0 and int(r["paid_day"]) == int(value["active_day"]) and r["instance_id"] not in last_services: return Scalars.fail("后勤蛊付费资格缺少维护服务收据")
	return {"ok":true,"logistics":_canonical(value)}

static func _quantities_equal(value, expected: Dictionary) -> bool:
	if not Scalars.exact(value,expected.keys()): return false
	for key in expected:
		if not Scalars.whole(value[key],int(expected[key]),int(expected[key])): return false
	return true

static func _canonical(value):
	if value is Dictionary:
		var out := {}
		for key in value: out[key] = _canonical(value[key])
		return out
	if value is Array:
		var out := []
		for item in value: out.append(_canonical(item))
		return out
	return int(value) if value is float else value
