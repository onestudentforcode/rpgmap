extends RefCounted
## Logistics owns deployment/paid service days, never upstream acquisition or
## growth. All mutations run inside the world's existing candidate transaction.
## P10.1 adds the three agriculture gu: one shared station slot, a directed 3x3
## service zone frozen per the phase doc table, whole-footprint coverage and a
## per-tag resolution (highest rank, then real benefit, then stable instance id).
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")
const Grid := preload("res://scripts/farming/core/grid/land_grid.gd")
const HOST_ID := "field_service_station"
const FACINGS := ["east", "south", "west", "north"]
const ZONE := 3
## Schema18 saves keep their final pre-upgrade service day on the old contract:
## host-rect expansion of 2 at 120%. These constants are that frozen contract.
const LEGACY_RANGE := 2
const LEGACY_GROWTH := 120
const EFFECT_TAG := {"growth_speed": "plant_growth_speed", "water_saving": "plant_water_saving",
	"fertility_saving": "plant_fertility_saving"}
const P10_PROVISION := ["rice_bag_gu", "rice_bag_gu", "bright_gu", "growth_gu", "wisdom_gu", "time_gu"]
var _owner: WeakRef
var world:
	get: return _owner.get_ref()
var config: Dictionary
var definitions := {}
var state := fresh()
## Host facings, per-cell water/fertility deduction remainders and the legacy
## switch day; serialized as the separate world.agriculture snapshot section.
var agri := fresh_agriculture()

static func fresh() -> Dictionary:
	return {"provisioned": false, "agri_supplement": false, "instances": [], "active_day": -1, "history": [], "spent": 0}

static func fresh_agriculture() -> Dictionary:
	return {"facings": {}, "remainders": {"water": {}, "fertility": {}}, "legacy_until": -1}

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
	state["agri_supplement"] = true
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

# --- Host facings (P10.1 §3.2) ----------------------------------------------

func attach_facing(uid: int, facing: String) -> void:
	agri["facings"][uid] = {"active": facing, "next": facing}

func forget_facility(uid: int) -> void:
	agri["facings"].erase(uid)

func facing_of(uid: int) -> String:
	return String(agri["facings"].get(uid, {}).get("active", "east"))

func next_facing_of(uid: int) -> String:
	return String(agri["facings"].get(uid, {}).get("next", "east"))

## Turning the service zone costs 1 AP and only takes effect at the next day
## opening; today's already-paid layout stays locked for the whole service day.
func set_facing(uid: int, facing: String) -> Dictionary:
	var checked: Dictionary = world._can_act(int(config.get("rotate_ap", 1)))
	if not checked["ok"]: return checked
	if not world.facilities.has(uid) or String(world.facilities[uid]["facility_id"]) != HOST_ID:
		return world._error("朝向只属于田间维护站")
	if not facing in FACINGS: return world._error("朝向非法")
	var row: Dictionary = agri["facings"].get(uid, {"active": facing_of(uid), "next": facing_of(uid)})
	if String(row["next"]) == facing: return world._error("朝向未改变")
	row["next"] = facing
	agri["facings"][uid] = row
	world.record_operation({"kind": "agriculture", "stage": "facing", "day": world.clock.total_days,
		"uid": uid, "facing": facing, "effective_day": world.clock.total_days+1})
	return world._finish(int(config.get("rotate_ap", 1)), {"ok": true})

## The frozen first-round table for a 2x2 host and a 3x3 zone (phase doc §3.2).
## Even host plus odd zone offsets are fixed here; nothing else may re-center.
static func directed_zone(origin: Vector2i, shape: Array, facing: String) -> Rect2i:
	var x := origin.x
	var y := origin.y
	var w := int(shape[0])
	var h := int(shape[1])
	match facing:
		"east": return Rect2i(x + w, y, ZONE, ZONE)
		"south": return Rect2i(x - 1, y + h, ZONE, ZONE)
		"west": return Rect2i(x - ZONE, y - 1, ZONE, ZONE)
	return Rect2i(x, y - ZONE, ZONE, ZONE)

func service_zone(row: Dictionary, day: int) -> Rect2i:
	if int(row["host_uid"]) <= 0 or not world.facilities.has(int(row["host_uid"])): return Rect2i()
	var host: Dictionary = world.facilities[int(row["host_uid"])]
	var origin := Vector2i(int(host["origin"][0]), int(host["origin"][1]))
	var shape: Array = world.facility_defs[host["facility_id"]]["footprint"]
	if day <= int(agri["legacy_until"]):
		return Rect2i(origin.x - LEGACY_RANGE, origin.y - LEGACY_RANGE,
			int(shape[0]) + LEGACY_RANGE * 2, int(shape[1]) + LEGACY_RANGE * 2).intersection(world.grid.bounds())
	return directed_zone(origin, shape, facing_of(int(row["host_uid"]))).intersection(world.grid.bounds())

func active(row: Dictionary, day: int) -> bool:
	return deployed(row) and bool(row["enabled"]) and int(row["effective_day"]) <= day and int(row["paid_day"]) == day

func run_opening(day: int) -> void:
	if int(state["active_day"]) == day: return
	state["active_day"] = day
	# The committed facing becomes today's locked layout before any service runs.
	for uid in agri["facings"]:
		agri["facings"][uid]["active"] = agri["facings"][uid]["next"]
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

## Expand-around-host coverage for the P10 area effects (light). The agriculture
## gu use service_zone() with their directed geometry instead.
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

# --- Agriculture resolution (P10.1 §4.2) --------------------------------------

## One shared decision for models, UI, predictions and audits: input is the full
## target (footprint rect, qualification tags, service day); output carries each
## effect group's adopted source plus every candidate and rejection reason.
func resolve(target: Rect2i, target_tags: Array, day: int) -> Dictionary:
	var legacy := day <= int(agri["legacy_until"])
	var rows: Array = state["instances"].duplicate()
	rows.sort_custom(func(a,b): return a["instance_id"] < b["instance_id"])
	var pools := {}
	var rejected := []
	for row in rows:
		var d := definition(row)
		var tag := String(EFFECT_TAG.get(String(d["effect"]), ""))
		if tag.is_empty(): continue
		var reasons := []
		if not deployed(row): reasons.append("未部署")
		elif not bool(row["enabled"]): reasons.append(String(row["reason"]))
		elif int(row["effective_day"]) > day: reasons.append("次日生效")
		elif int(row["paid_day"]) != day: reasons.append("当日未付维护")
		else:
			var zone := service_zone(row, day)
			if not zone.encloses(target):
				reasons.append("部分覆盖不生效" if zone.intersects(target) else "未覆盖")
			elif target_tags.is_empty() or not _shares_tag(target_tags, d["target_tags"]):
				reasons.append("目标标签不符")
		if not reasons.is_empty():
			if deployed(row): rejected.append({"instance_id": row["instance_id"], "name": d["name"], "reason": "；".join(PackedStringArray(reasons))})
			continue
		var value := int(d["value"])
		if legacy and String(d["effect"]) == "growth_speed": value = LEGACY_GROWTH
		if not pools.has(tag): pools[tag] = []
		pools[tag].append({"instance_id": row["instance_id"], "name": d["name"], "effect": String(d["effect"]),
			"rank": int(row["rank"]), "value": value})
	var groups := {}
	for tag in pools:
		var best := {}
		for entry in pools[tag]:
			if best.is_empty() or _stronger(entry, best): best = entry
		var candidates := []
		for entry in pools[tag]:
			var adopted: bool = entry["instance_id"] == best["instance_id"]
			candidates.append({"instance_id": entry["instance_id"], "name": entry["name"], "rank": int(entry["rank"]),
				"value": int(entry["value"]), "adopted": adopted,
				"reason": "" if adopted else "同类被%s（%d转）覆盖，仍付维护" % [String(best["name"]), int(best["rank"])]})
		groups[tag] = {"source": best, "value": int(best["value"]), "candidates": candidates}
	return {"groups": groups, "rejected": rejected}

static func _shares_tag(target_tags: Array, served: Array) -> bool:
	for tag in served:
		if tag in target_tags: return true
	return false

## Rank first; at equal rank the real benefit decides (higher growth multiplier
## or lower retention); ties break on the stable instance id, never on order.
static func _stronger(a: Dictionary, b: Dictionary) -> bool:
	if int(a["rank"]) != int(b["rank"]): return int(a["rank"]) > int(b["rank"])
	if String(a["effect"]) == "growth_speed":
		if int(a["value"]) != int(b["value"]): return int(a["value"]) > int(b["value"])
	else:
		if int(a["value"]) != int(b["value"]): return int(a["value"]) < int(b["value"])
	return String(a["instance_id"]) < String(b["instance_id"])

func growth_percent(target: Rect2i, target_tags: Array, day: int) -> int:
	var group: Dictionary = resolve(target, target_tags, day)["groups"].get("plant_growth_speed", {})
	return int(group.get("value", 100))

## Water and fertility retention resolve independently; 100 means no saving.
func retention_percent(target: Rect2i, target_tags: Array, day: int) -> Dictionary:
	var outcome: Dictionary = resolve(target, target_tags, day)["groups"]
	return {"water": int(outcome.get("plant_water_saving", {}).get("value", 100)),
		"fertility": int(outcome.get("plant_fertility_saving", {}).get("value", 100))}

## Fixed-hundredths accumulation per cell (P10.1 §5.3). The remainder belongs
## to the ground cell and survives harvests, replants, gu swaps, turns, reloads.
func consume_environment(cell: Vector2i, index: int, field: int, use: int, retention: int) -> void:
	var key := "water" if field == 0 else "fertility"
	var cell_key := "%d,%d" % [cell.x, cell.y]
	var remainder := int(agri["remainders"][key].get(cell_key, 0))
	var accumulated := remainder + use * maxi(0, retention)
	var deduct := int(accumulated / 100)
	remainder = int(accumulated % 100)
	if remainder == 0: agri["remainders"][key].erase(cell_key)
	else: agri["remainders"][key][cell_key] = remainder
	var before := int(world.environment[index][field])
	var applied := mini(before, deduct)
	world.environment[index][field] = before - applied
	if applied < deduct:
		world.record_operation({"kind": "agriculture", "stage": "clamp", "day": world.clock.total_days,
			"cell": [cell.x, cell.y], "field": key, "unmet": deduct - applied})

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
		var env: Dictionary = world.environment_at(Vector2i(int(row["origin"][0]), int(row["origin"][1])))
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
		var cell := Vector2i(int(row["origin"][0]), int(row["origin"][1]))
		var target := Rect2i(cell, Vector2i.ONE)
		job["progress"] = mini(int(job["target"]), int(job["progress"]) + growth_percent(target, d["target_tags"], day))
		job["ready"] = job["progress"] == job["target"]
		var index: int = world.grid.index_of(cell)
		var retention := int(retention_percent(target, d["target_tags"], day)["water"])
		consume_environment(cell, index, 0, int(p["water_use"]), retention)
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

func agri_to_save() -> Dictionary:
	return agri.duplicate(true)

func apply_save(value: Dictionary) -> void:
	state = value.duplicate(true)
	for row in state["instances"]:
		if row["origin"].is_empty(): continue
		var cell := Vector2i(int(row["origin"][0]), int(row["origin"][1]))
		var tilled: bool = world.grid.state_at(cell) == Grid.State.TILLED
		world.grid.reserve(cell,1,1,"gu:"+String(row["instance_id"]))
		if tilled: world._tilled_under_buildings[cell] = true

func apply_agri_save(value: Dictionary) -> void:
	agri = value.duplicate(true)

static func normalize(value, day: int, body: Dictionary, catalog) -> Dictionary:
	if not Scalars.exact(value,fresh().keys()) or not value["provisioned"] is bool or not value["agri_supplement"] is bool or not value["instances"] is Array or not value["history"] is Array or not Scalars.whole(value["spent"]):
		return Scalars.fail("后勤蛊快照结构非法")
	if bool(value["provisioned"]) and not bool(value["agri_supplement"]): return Scalars.fail("已领取档缺少农业配给标记")
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
			var c := Vector2i(int(r["origin"][0]), int(r["origin"][1]))
			if not catalog.tillable_map().get(m["grid"][c.y][c.x-origin_x],false): return Scalars.fail("独立蛊占地地形非法")
			var land_script = load("res://scripts/farming/p8/p8_land.gd")
			var land_cfg: Dictionary = land_script.settings()
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

## Strict schema18 -> 19 conversion for the logistics section. The old shape is
## checked first (six P10 instances max, no agriculture flag), then the five
## supplement instances are appended once; everything else is re-validated by
## the normal normalize pass against the converted structure.
static func upgrade18(value, catalog) -> Dictionary:
	if not value is Dictionary or not Scalars.exact(value, ["provisioned","instances","active_day","history","spent"]):
		return Scalars.fail("schema18后勤蛊结构非法")
	var cfg: Dictionary = _canonical(catalog.load_data()["logistics"])
	var provision: Array = cfg["provision"]
	if provision.slice(0, P10_PROVISION.size()) != P10_PROVISION: return Scalars.fail("配给前六位与P10基线不符")
	if bool(value["provisioned"]) and value["instances"].size() != P10_PROVISION.size(): return Scalars.fail("schema18试用实例数量非法")
	if not bool(value["provisioned"]) and not value["instances"].is_empty(): return Scalars.fail("未领取档不得持有实例")
	for receipt in value["history"]:
		if not receipt is Dictionary or not receipt.get("services") is Array: return Scalars.fail("schema18维护日报结构非法")
		for id in receipt["services"]:
			var index := int(String(id).trim_prefix("trial-")) if String(id).begins_with("trial-") else 0
			if index < 1 or index > P10_PROVISION.size(): return Scalars.fail("schema18维护服务超出当时实例范围")
	var out: Dictionary = value.duplicate(true)
	out["agri_supplement"] = true
	if bool(value["provisioned"]):
		for index in range(P10_PROVISION.size(), provision.size()):
			out["instances"].append({"instance_id": "trial-%03d" % (index+1), "definition_id": provision[index],
				"rank": 1, "host_uid": 0, "origin": [], "enabled": false, "effective_day": 0,
				"paid_day": -1, "paid_fee": 0, "paid_food": {}, "reason": "未部署", "job": {}})
	return {"ok": true, "logistics": _canonical(out)}

## Converted saves keep their final pre-upgrade service day on the legacy
## contract; from the next opening the directed zone and 150% take over.
static func converted_agriculture(day: int) -> Dictionary:
	return {"facings": {}, "remainders": {"water": {}, "fertility": {}}, "legacy_until": day}

static func normalize_agriculture(value, day: int, active_day: int, world: Dictionary, catalog) -> Dictionary:
	if not value is Dictionary or not Scalars.exact(value, ["facings", "remainders", "legacy_until"]):
		return Scalars.fail("农业辅助快照结构非法")
	if not Scalars.whole(value["legacy_until"], -1, day): return Scalars.fail("农业切换日非法")
	if int(value["legacy_until"]) >= 0 and int(value["legacy_until"]) < maxi(0, active_day - 1): return Scalars.fail("农业切换日早于最后服务日")
	var m: Dictionary = catalog.load_map()
	var width := int(m["size"][0])
	var height := int(m["size"][1])
	var origin_x := int(m.get("origin_x", 0))
	var facilities := {}
	for row in world["facilities"]: facilities[int(row["uid"])] = String(row["facility_id"])
	var facings := {}
	for uid in value["facings"]:
		var key := int(uid)
		if not facilities.has(key) or facilities[key] != HOST_ID: return Scalars.fail("朝向宿主非法")
		var row = value["facings"][uid]
		if not row is Dictionary or not Scalars.exact(row, ["active", "next"]): return Scalars.fail("朝向字段非法")
		if not (row["active"] in FACINGS and row["next"] in FACINGS): return Scalars.fail("朝向取值非法")
		facings[key] = {"active": String(row["active"]), "next": String(row["next"])}
	var land_script = load("res://scripts/farming/p8/p8_land.gd")
	var land_cfg: Dictionary = land_script.settings()
	var owned_rects := [land_script.rect(land_cfg["base"])]
	for parcel in land_cfg["parcels"]:
		if parcel["id"] in world["land"]["purchased"]: owned_rects.append(land_script.rect(parcel["rect"]))
	var remainders := {"water": {}, "fertility": {}}
	for key in ["water", "fertility"]:
		var section = value["remainders"].get(key, null)
		if not section is Dictionary: return Scalars.fail("余量结构非法")
		for cell_key in section:
			var parts := String(cell_key).split(",")
			if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return Scalars.fail("余量坐标非法")
			var c := Vector2i(int(parts[0]), int(parts[1]))
			if c.x < origin_x or c.x >= origin_x + width or c.y < 0 or c.y >= height: return Scalars.fail("余量坐标越界")
			if not catalog.tillable_map().get(m["grid"][c.y][c.x - origin_x], false): return Scalars.fail("余量位于不可种植地形")
			var owned := false
			for rect in owned_rects:
				if rect.has_point(c): owned = true
			if not owned: return Scalars.fail("余量位于未购地块")
			if not Scalars.whole(section[cell_key], 1, 99): return Scalars.fail("余量数值非法")
			remainders[key][String(cell_key)] = int(section[cell_key])
	return {"ok": true, "agriculture": {"facings": facings, "remainders": remainders, "legacy_until": int(value["legacy_until"])}}

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
