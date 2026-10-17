extends RefCounted
## P10.2: paving is independent of occupancy. Farmland uses the existing grid
## till state; only ordinary paving and per-plant reward provenance are saved.
const Grid := preload("res://scripts/farming/core/grid/land_grid.gd")
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")
const STEPS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var _owner: WeakRef
var world:
	get: return _owner.get_ref()
var settings: Dictionary
var state := fresh()
var _day := -1
var _regions := []
var _by_cell := {}

static func fresh() -> Dictionary:
	return {"floors": {}, "plants": {}, "gu_rounds": {}, "random_seed": 1729}

func _init(owner, config: Dictionary) -> void:
	_owner = weakref(owner)
	settings = config.duplicate(true)

static func key(cell: Vector2i) -> String: return "%d,%d" % [cell.x, cell.y]

static func cell_at(text: String) -> Vector2i:
	var parts := text.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

func farmland(cell: Vector2i) -> bool:
	var s: int = world.grid.state_at(cell)
	return s in [Grid.State.TILLED, Grid.State.PLANTED] or (s == Grid.State.OCCUPIED and not world.logistics.at(cell).is_empty() and world.grid._prev.get(cell) == Grid.State.TILLED)

func floor_kind(cell: Vector2i) -> String:
	return "farmland" if farmland(cell) else String(state["floors"].get(key(cell), "natural"))

func quote_floor(cell: Vector2i, kind: String) -> Dictionary:
	if kind not in ["farmland", "ordinary", "natural"]: return world._error("未知地板类型")
	if not world.grid.in_bounds(cell.x, cell.y) or not world.grid.is_terrain_tillable(cell) or not world.source_at(cell).is_empty(): return world._error("地格未开放或不可铺设")
	if world.grid.state_at(cell) not in [Grid.State.WILD, Grid.State.TILLED]: return world._error("请先收取或清理占用，不能直接覆盖")
	if floor_kind(cell) == kind: return world._error("地板类型未改变")
	var inputs: Dictionary = settings["floor"]["inputs"].duplicate() if kind == "ordinary" else {}
	for item in inputs:
		if not world.inventory.has(item, int(inputs[item])): return world._error("缺少铺设材料")
	return {"ok": true, "inputs": inputs, "ap": 1, "kind": kind}

func set_floor(cell: Vector2i, kind: String) -> Dictionary:
	var allowed: Dictionary = world._can_act(1)
	if not allowed["ok"]: return allowed
	var q := quote_floor(cell, kind)
	if not q["ok"]: return q
	if world.grid.state_at(cell) == Grid.State.TILLED: world.grid.untill(cell)
	state["floors"].erase(key(cell))
	if kind == "farmland": world.grid.till(cell)
	elif kind == "ordinary": state["floors"][key(cell)] = kind
	for item in q["inputs"]: world.inventory.remove(item, int(q["inputs"][item]))
	world._record_flow({}, q["inputs"], "铺设材料")
	world.record_operation({"kind":"room", "stage":"floor", "day":world.clock.total_days, "cell":[cell.x,cell.y], "floor":kind, "inputs":q["inputs"]})
	return world._finish(1, q)

## Pure queries; panel reads do not advance contribution or draw random values.
func regions(day: int, override_cell := Vector2i(-999,-999), override_kind := "") -> Array:
	var pending := {}
	var bounds: Rect2i = world.grid.bounds()
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x,y)
			var is_field: bool = override_kind == "farmland" if cell == override_cell and not override_kind.is_empty() else farmland(cell)
			if is_field: pending[cell] = true
	var result := []
	while not pending.is_empty():
		var todo := [pending.keys()[0]]
		pending.erase(todo[0])
		var cells := []
		var covered := {"plant_growth_speed":true,"plant_water_saving":true,"plant_fertility_saving":true}
		var missing := {"plant_growth_speed":[],"plant_water_saving":[],"plant_fertility_saving":[]}
		var sources := {"plant_growth_speed":[],"plant_water_saving":[],"plant_fertility_saving":[]}
		var cursor := 0
		while cursor < todo.size():
			var c: Vector2i = todo[cursor]
			cursor += 1
			cells.append(c)
			var groups: Dictionary = world.logistics.resolve(Rect2i(c,Vector2i.ONE),["plant_grow"],day)["groups"]
			for tag in covered:
				covered[tag] = bool(covered[tag]) and groups.has(tag)
				if not groups.has(tag): missing[tag].append(c)
				elif not groups[tag]["source"]["instance_id"] in sources[tag]: sources[tag].append(groups[tag]["source"]["instance_id"])
			for step in STEPS:
				var next: Vector2i = c+step
				if pending.has(next): pending.erase(next); todo.append(next)
		var seed: bool = covered["plant_growth_speed"] and covered["plant_water_saving"]
		var material: bool = covered["plant_growth_speed"] and covered["plant_fertility_saving"]
		result.append({"cells":cells,"seed":seed,"material":material,"covered":covered,"missing":missing,"sources":sources,
			"level":2 if seed and material else (1 if seed or material else 0),
			"name":"二级·复合农业区" if seed and material else ("一级·育种田" if seed else ("一级·丰产田" if material else "普通田块"))})
	return result

## Predict connectivity and tier changes without touching the grid, rewards or RNG.
func preview_floor(cell: Vector2i, kind: String) -> Dictionary:
	var quote := quote_floor(cell,kind)
	if not quote["ok"]: return quote
	var before := []
	var after := []
	for pair in [[regions(world.clock.total_days),before],[regions(world.clock.total_days,cell,kind),after]]:
		for region in pair[0]:
			var touches: bool = cell in region["cells"]
			for step in STEPS: touches = touches or cell+step in region["cells"]
			if touches: pair[1].append(region)
	var downgrade := false
	for old in before:
		for next in after:
			for c in next["cells"]:
				if c in old["cells"] and (old["seed"] and not next["seed"] or old["material"] and not next["material"]): downgrade = true
	var descriptions := []
	for group in [before,after]:
		var labels := PackedStringArray()
		for region in group: labels.append("%s%d格" % [region["name"],region["cells"].size()])
		descriptions.append("＋".join(labels) if not labels.is_empty() else "无田块")
	return {"ok":true,"before":before,"after":after,"downgrade":downgrade,
		"summary":"%s → %s%s" % [descriptions[0],descriptions[1],"（将降低房间收益资格）" if downgrade else ""]}

func begin_settle(day: int) -> void:
	_day = day
	_regions = regions(day)
	_by_cell.clear()
	for region in _regions:
		for cell in region["cells"]: _by_cell[cell] = region

func qualification(rect: Rect2i, tags: Array, day: int) -> Dictionary:
	if _day != day: begin_settle(day)
	var region: Dictionary = _by_cell.get(rect.position,{})
	if region.is_empty(): return {"seed":false,"material":false}
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			if not Vector2i(x,y) in region["cells"]: return {"seed":false,"material":false}
	var groups: Dictionary = world.logistics.resolve(rect,tags,day)["groups"]
	var out := {}
	for channel in ["seed","material"]:
		var valid: bool = region[channel]
		for tag in settings["requirements"][channel]: valid = valid and groups.has(tag)
		out[channel] = valid
	return out

static func round_state(target: int, round_index: int = 0) -> Dictionary:
	return {"round":round_index,"target":target,"growth":0,"seed_work":0,"material_work":0,
		"frozen":false,"seed_checked":false,"seed_award":0,"seed_claimed":false,"seed_total":0,"seed_eligible":0}

func plant_started(row: Dictionary) -> void:
	state["plants"][str(row["uid"])] = round_state(int(world.crop_defs[row["crop_id"]]["days"])*100)

static func draw(seed_value: int, identity: String, round_index: int, channel: String) -> int:
	# Fixed millionth draw; SHA256 is stable across platforms and reloads.
	return int(("%d|%s|%d|%s" % [seed_value,identity,round_index,channel]).sha256_text().substr(0,8).hex_to_int() % 1000000)

static func award(base: int, qualified: int, total: int, roll: int) -> int:
	if total <= 0: return 0
	var numerator := base * 25 * qualified
	var denominator := total * 100
	return int(numerator / denominator) + (1 if roll * denominator < (numerator % denominator) * 1000000 else 0)

func advance(identity: String, data: Dictionary, delta: int, rect: Rect2i, tags: Array, day: int, seed_item: String) -> void:
	if data["frozen"] or delta <= 0: return
	var flags := qualification(rect,tags,day)
	data["growth"] += delta
	if flags["seed"]: data["seed_work"] += delta
	if flags["material"]: data["material_work"] += delta
	if data["growth"] == data["target"]:
		data["frozen"] = true
		if not data["seed_checked"]:
			data["seed_checked"] = true
			data["seed_total"] = data["growth"]
			data["seed_eligible"] = data["seed_work"]
			data["seed_award"] = award(1,int(data["seed_work"]),int(data["growth"]),draw(int(state["random_seed"]),identity,0,"seed")) if not seed_item.is_empty() else 0
	world.record_operation({"kind":"room","stage":"growth","day":day,"identity":identity,"round":data["round"],"delta":delta,
		"seed_qualified":flags["seed"],"material_qualified":flags["material"],"state":data.duplicate(true)})

func crop_grew(row: Dictionary, delta: int, day: int) -> void:
	var data: Dictionary = state["plants"][str(row["uid"])]
	var d: Dictionary = world.crop_defs[row["crop_id"]]
	advance("crop:"+str(row["uid"]),data,delta,world._crop_rect(row),d.get("target_tags",[]),day,String(d["seed"]))

func gu_grew(row: Dictionary, delta: int, day: int) -> void:
	var id := String(row["instance_id"])
	if not state["gu_rounds"].has(id): state["gu_rounds"][id] = round_state(int(row["job"]["target"]))
	var rect := Rect2i(Vector2i(int(row["origin"][0]),int(row["origin"][1])),Vector2i.ONE)
	advance("gu:"+id,state["gu_rounds"][id],delta,rect,world.logistics.definition(row)["target_tags"],day,"")

func rewards(identity: String, data: Dictionary, definition_id: String, mode: String, base: Dictionary, seed_item: String) -> Dictionary:
	var seed := {}
	var material := {}
	if data["frozen"]:
		if not data["seed_claimed"] and not seed_item.is_empty() and int(data["seed_award"]) > 0: seed[seed_item] = 1
		var item := String(settings["primary"].get(definition_id,{}).get(mode,""))
		if not item.is_empty() and base.has(item):
			var n := award(int(base[item]),int(data["material_work"]),int(data["growth"]),draw(int(state["random_seed"]),identity,int(data["round"]),"material:"+item))
			if n > 0: material[item] = n
	data["seed_claimed"] = bool(data["seed_checked"])
	for pair in [[seed,"育种奖励"],[material,"丰产奖励"]]:
		for item in pair[0]: world.inventory.add(item,int(pair[0][item]))
		world._record_flow(pair[0],{},pair[1])
	world.record_operation({"kind":"room","stage":"claim","day":world.clock.total_days,"identity":identity,"round":data["round"],
		"definition":definition_id,"mode":mode,"base":base.duplicate(),"seed":seed,"material":material,"state":data.duplicate(true)})
	return {"seed":seed,"material":material}

func claim_crop(row: Dictionary, mode: String, base: Dictionary, removed: bool) -> Dictionary:
	var id := str(row["uid"])
	var d: Dictionary = world.crop_defs[row["crop_id"]]
	var data: Dictionary = state["plants"][id]
	var out := rewards("crop:"+id,data,row["crop_id"],mode,base,String(d["seed"]))
	if removed: state["plants"].erase(id)
	else:
		var next := round_state(int(d["cycle_days"])*100,int(data["round"])+1)
		for field in ["seed_checked","seed_award","seed_claimed","seed_total","seed_eligible"]: next[field] = data[field]
		state["plants"][id] = next
	return out

func clear_crop(row: Dictionary) -> Dictionary:
	var id := str(row["uid"])
	var result := {}
	if row["state"] == "mature": result = rewards("crop:"+id,state["plants"][id],row["crop_id"],"clear",{},String(world.crop_defs[row["crop_id"]]["seed"]))
	state["plants"].erase(id)
	return result

func claim_gu(row: Dictionary, base: Dictionary) -> Dictionary:
	var id := String(row["instance_id"])
	var data: Dictionary = state["gu_rounds"][id]
	var out := rewards("gu:"+id,data,row["definition_id"],"claim",base,"")
	state["gu_rounds"][id] = round_state(int(data["target"]),int(data["round"])+1)
	return out

func cancel_gu(id: String) -> void:
	if state["gu_rounds"].has(id):
		var data: Dictionary = state["gu_rounds"][id]
		state["gu_rounds"][id] = round_state(int(data["target"]),int(data["round"])+1)

func to_save() -> Dictionary: return state.duplicate(true)

func apply_save(value: Dictionary) -> void:
	state = value.duplicate(true)
	_day = -1
	_by_cell.clear()
	_regions.clear()

static func normalize(value, snapshot: Dictionary, catalog) -> Dictionary:
	if not Scalars.exact(value,fresh().keys()) or not Scalars.whole(value["random_seed"],1,2147483647): return Scalars.fail("农业房间快照结构或随机种子非法")
	for field in ["floors","plants","gu_rounds"]:
		if not value[field] is Dictionary: return Scalars.fail("农业房间索引非法")
	var out := fresh()
	out["random_seed"] = int(value["random_seed"])
	var body: Dictionary = snapshot["world"]
	var m: Dictionary = catalog.load_map()
	var owned = load("res://scripts/farming/p8/p8_land.gd")
	var land: Dictionary = owned.settings()
	var rects := [owned.rect(land["base"])]
	for p in land["parcels"]:
		if p["id"] in body["land"]["purchased"]: rects.append(owned.rect(p["rect"]))
	for text in value["floors"]:
		if not text is String or text.split(",").size()!=2: return Scalars.fail("铺面坐标非法")
		var c := cell_at(text)
		if key(c)!=text or not Scalars.coordinate([c.x,c.y],int(m["size"][0]),int(m["size"][1]),int(m.get("origin_x",0))): return Scalars.fail("铺面坐标越界")
		var accessible := false
		for r in rects:
			if r.has_point(c): accessible = true
		if not accessible or not catalog.tillable_map().get(m["grid"][c.y][c.x-int(m.get("origin_x",0))],false): return Scalars.fail("铺面地权或地形非法")
		if value["floors"][text]!="ordinary" or [c.x,c.y] in body["tilled"]: return Scalars.fail("铺面与耕地冲突")
		for source in catalog.definitions("sources").values():
			if source["position"]==[c.x,c.y]: return Scalars.fail("铺面覆盖资源点")
		out["floors"][text] = "ordinary"
	var crops := {}
	for crop in body["crops"]: crops[str(crop["uid"])] = crop
	if value["plants"].size()!=crops.size(): return Scalars.fail("植物奖励索引不完整")
	var definitions: Dictionary = catalog.definitions("crops")
	for id in value["plants"]:
		if not id is String or not crops.has(id): return Scalars.fail("植物奖励身份非法")
		var crop: Dictionary = crops[id]
		var d: Dictionary = definitions[crop["crop_id"]]
		var checked := _normalize_round(value["plants"][id],int(value["random_seed"]),"crop:"+id,String(d["seed"]))
		if not checked["ok"]: return checked
		var row: Dictionary = checked["row"]
		var target := int(d["cycle_days"] if int(crop["harvest_count"])>0 else d["days"])*100
		if row["round"]!=crop["harvest_count"] or row["target"]!=target or row["growth"]!=crop["progress"] or row["frozen"]!=(crop["state"]=="mature"): return Scalars.fail("植物奖励与生长状态不符")
		if int(crop["harvest_count"])>0 and (not row["seed_checked"] or not row["seed_claimed"]): return Scalars.fail("留株不得重置首次育种")
		if int(crop["harvest_count"])==0 and row["seed_checked"]!=row["frozen"]: return Scalars.fail("首次成熟育种标记不符")
		if int(crop["harvest_count"])==0 and (row["seed_claimed"] or row["seed_checked"] and (row["seed_total"]!=row["growth"] or row["seed_eligible"]!=row["seed_work"])): return Scalars.fail("首次育种权益与成熟贡献不符")
		if row["seed_checked"] and row["seed_total"]!=int(d["days"])*100: return Scalars.fail("育种目标不符")
		out["plants"][id] = row
	var instances := {}
	for instance in body["logistics"]["instances"]: instances[instance["instance_id"]]=instance
	for id in value["gu_rounds"]:
		if not instances.has(id) or not instances[id]["definition_id"]=="rice_bag_gu": return Scalars.fail("独立蛊奖励身份非法")
		var checked := _normalize_round(value["gu_rounds"][id],int(value["random_seed"]),"gu:"+id,"")
		if not checked["ok"]: return checked
		var row: Dictionary = checked["row"]
		var job: Dictionary = instances[id]["job"]
		if row["target"]!=300 or row["growth"]!=int(job.get("progress",0)) or row["frozen"]!=bool(job.get("ready",false)): return Scalars.fail("独立蛊奖励与任务不符")
		if row["seed_checked"]!=row["frozen"] or row["seed_claimed"] or row["seed_checked"] and (row["seed_total"]!=row["growth"] or row["seed_eligible"]!=row["seed_work"]): return Scalars.fail("独立蛊成熟记录不符")
		out["gu_rounds"][id] = row
	for id in instances:
		if not instances[id]["job"].is_empty() and not out["gu_rounds"].has(id): return Scalars.fail("独立蛊任务缺少奖励进度")
	return {"ok":true,"rooms":out}

static func _normalize_round(value, random_seed: int, identity: String, seed_item: String) -> Dictionary:
	if not Scalars.exact(value,round_state(1).keys()): return Scalars.fail("奖励轮结构非法")
	for field in ["round","target","growth","seed_work","material_work","seed_total","seed_eligible","seed_award"]:
		if not Scalars.whole(value[field]): return Scalars.fail("奖励轮数量非法")
	for field in ["frozen","seed_checked","seed_claimed"]:
		if not value[field] is bool: return Scalars.fail("奖励轮标记非法")
	if value["target"]<=0 or value["growth"]>value["target"] or value["seed_work"]>value["growth"] or value["material_work"]>value["growth"] or value["seed_eligible"]>value["seed_total"]: return Scalars.fail("奖励贡献超过真实生长")
	if value["frozen"]!=(value["growth"]==value["target"]) or value["seed_award"]>1 or (value["seed_claimed"] and not value["seed_checked"]): return Scalars.fail("奖励成熟或领取标记非法")
	if not value["seed_checked"] and (value["seed_award"]!=0 or value["seed_total"]!=0 or value["seed_eligible"]!=0): return Scalars.fail("未成熟伪造种子权益")
	var expected := award(1,int(value["seed_eligible"]),int(value["seed_total"]),draw(random_seed,identity,0,"seed")) if not seed_item.is_empty() else 0
	if value["seed_award"]!=expected: return Scalars.fail("育种随机结果被改写")
	return {"ok":true,"row":preload("res://scripts/farming/p8/p10_logistics.gd")._canonical(value)}
