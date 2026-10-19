# -*- coding: utf-8 -*-
"""One-shot stage-c patch part 3: loach service, day finish, pending, codec."""
from pathlib import Path

p = Path('scripts/farming/p8/p103_ranch.gd')
s = p.read_text(encoding='utf-8')

def sub(old, new, count=1):
    global s
    assert old in s, 'anchor missing: ' + old[:80]
    s = s.replace(old, new, count)

# 13. Loach batch service: facility posts driven by care units, no fatigue.
sub('''func _try_roam(row: Dictionary, t: int, qualified: bool, account: Dictionary, pasture_use: Dictionary, wait_label: String) -> String:''',
'''## Loach processing (§16.2.6): the animal serves a facility post on care
## units; progress is full-width because aquatic species carry no fatigue.
func _loach_service(row: Dictionary, t: int, mutate: bool, shadow: Dictionary, _station_use: Dictionary) -> void:
	var zone_row := zone(int(row["zone_uid"]))
	if zone_row.is_empty() or not zone_structural(zone_row):
		return
	var yards: Array = _facilities_in_zone(zone_row).filter(func(f): return is_work_facility(String(f["facility_id"])))
	for yard in yards:
		var yard_state := workyard_state(int(yard["uid"]))
		var recipe_id := String(yard_state["recipe_id"])
		var recipe: Dictionary = settings["work"]["recipes"].get(recipe_id, {})
		if recipe.is_empty() or String(recipe["species"]) != String(row["species_id"]):
			continue
		if not settings["work"]["facilities"][String(yard["facility_id"])].has(recipe_id):
			continue
		for index in range(yard_state["posts"].size()):
			var post: Dictionary = yard_state["posts"][index]
			var key := "%d:%d:%d" % [int(yard["uid"]), index, t]
			if String(post["status"]) == "ready" or String(post["status"]) == "idle":
				continue
			var points := int(world.services.config["precision"])
			var before := int(post["progress"])
			post["progress"] = mini(int(post["target"]), before + points)
			_record("loach", "service", {"animal": int(row["uid"]), "t": t, "workyard": int(yard["uid"]),
				"post": index, "points": points, "before": before, "after": int(post["progress"])})
			if int(post["progress"]) >= int(post["target"]) and String(post["status"]) == "running":
				post["status"] = "ready"
				_record("workyard", "batch_ready", {"workyard": int(yard["uid"]), "post": index,
					"batch_id": int(post["batch_id"]), "recipe": recipe_id})
				if mutate:
					world._report_event({"category": "growth", "facility_uid": int(yard["uid"]), "kind": "批次完成",
						"count": 1, "items": post["outputs"].duplicate(), "note": "待领取"})
			return
	# Running posts are all served for this unit; idle posts open through the
	# normal workyard recipe flow once inputs exist.

func _try_roam(row: Dictionary, t: int, qualified: bool, account: Dictionary, pasture_use: Dictionary, wait_label: String) -> String:''')

# Wait: idle posts must open when a loach serves and inputs exist — mirror the
# _take_post opening block. Replace the tail comment with real idle handling.
sub('''	# Running posts are all served for this unit; idle posts open through the
	# normal workyard recipe flow once inputs exist.
''',
'''	return
''')

# Insert the idle-opening logic inside the post loop (before the ready/idle skip).
sub('''		for index in range(yard_state["posts"].size()):
			var post: Dictionary = yard_state["posts"][index]
			var key := "%d:%d:%d" % [int(yard["uid"]), index, t]
			if String(post["status"]) == "ready" or String(post["status"]) == "idle":
				continue
			var points := int(world.services.config["precision"])''',
'''		for index in range(yard_state["posts"].size()):
			var post: Dictionary = yard_state["posts"][index]
			var key := "%d:%d:%d" % [int(yard["uid"]), index, t]
			if String(post["status"]) == "ready":
				continue
			if String(post["status"]) == "idle":
				var opening: Dictionary = world.recipe_defs[recipe_id]
				var enough := true
				for item in opening["inputs"]:
					if _shadow_count(String(item), shadow) < int(opening["inputs"][item]):
						enough = false
				if not enough:
					continue
				if mutate:
					for item in opening["inputs"]:
						world.inventory.remove(String(item), int(opening["inputs"][item]))
					world._record_flow({}, opening["inputs"], "处理开批")
				else:
					_shadow_spend(opening["inputs"], shadow)
				post["batch_id"] = int(state["next_batch_uid"])
				state["next_batch_uid"] = int(state["next_batch_uid"]) + 1
				post["recipe_id"] = recipe_id
				var paid := {}
				for item in opening["inputs"]:
					paid[String(item)] = int(opening["inputs"][item])
				post["inputs"] = paid
				var produced := {}
				for item in opening["outputs"]:
					produced[String(item)] = int(opening["outputs"][item])
				post["outputs"] = produced
				post["progress"] = 0
				post["target"] = int(recipe["target"])
				post["status"] = "running"
				_record("workyard", "batch_open", {"workyard": int(yard["uid"]), "post": index,
					"batch_id": int(post["batch_id"]), "recipe": recipe_id,
					"inputs": opening["inputs"].duplicate(), "outputs": opening["outputs"].duplicate()})
			var points := int(world.services.config["precision"])''')

# 14. Day finish: aquatic branch — no fatigue, survival streaks, same deaths.
sub('''func _finish_day(day: int, accounts: Dictionary, out: Dictionary) -> void:
	var fatigue: Dictionary = settings["fatigue"]
	var survivors := []
	var day_accounts := {}
	for row in state["animals"]:
		var account: Dictionary = accounts.get(int(row["uid"]), {"w": 0, "r": 0, "fails": 0})
		var rest := int(account["r"])
		if String(row["mode"]) != "work":
			rest = mini(rest, int(fatigue["enclosure_rest_cap"]))''',
'''func _finish_day(day: int, accounts: Dictionary, out: Dictionary) -> void:
	var fatigue: Dictionary = settings["fatigue"]
	var survivors := []
	var day_accounts := {}
	for row in state["animals"]:
		var account: Dictionary = accounts.get(int(row["uid"]), {"w": 0, "r": 0, "fails": 0})
		if species_medium(String(row["species_id"])) == "water":
			_finish_water_day(day, row, account)
			if int(row["death_streak"]) == 0 and String(row["stage"]) == "juvenile" and int(row["growth"]) >= int(species_config(String(row["species_id"]))["growth_units"]):
				row["stage"] = "adult"
				row["mode"] = "waiting"
				world._report_event({"category": "growth", "facility_uid": 0, "kind": "成年",
					"count": 1, "items": {}, "note": "请为其选择繁殖、生产或净化归属"})
				_record("animal", "adult", {"animal": int(row["uid"]), "day": day})
			if int(row["death_streak"]) == 0:
				day_accounts[int(row["uid"])] = row["account"].duplicate()
				survivors.append(row)
			continue
		var rest := int(account["r"])
		if String(row["mode"]) != "work":
			rest = mini(rest, int(fatigue["enclosure_rest_cap"]))''')

# 15. The aquatic day finisher, placed before _finish_day.
sub('''func _finish_day(day: int, accounts: Dictionary, out: Dictionary) -> void:''',
'''## Aquatic survival (§16.2.7): no fatigue at all; separate miss and bad-water
## streaks, either reaching three settled days kills the animal once.
func _finish_water_day(day: int, row: Dictionary, account: Dictionary) -> void:
	var missed := int(account["fails"]) > 0
	row["miss_streak"] = 0 if not missed else int(row["miss_streak"]) + 1
	var bad_water := not water_ok(row)
	row["bad_water_streak"] = 0 if not bad_water else int(row["bad_water_streak"]) + 1
	row["account"] = {"w": 0, "r": int(account["r"]), "fails": int(account["fails"])}
	_record("water", "account", {"animal": int(row["uid"]), "day": day,
		"miss_streak": int(row["miss_streak"]), "bad_water_streak": int(row["bad_water_streak"]),
		"quality": world.water.quality(_body_of(row))})
	if maxi(int(row["miss_streak"]), int(row["bad_water_streak"])) >= 3:
		row["death_streak"] = 3
		var reason := "连续缺维持" if int(row["miss_streak"]) >= 3 else "连续劣水"
		world._report_event({"category": "pause", "facility_uid": 0, "kind": "动物死亡",
			"count": 1, "items": {}, "note": "%s（%s）死亡" % [String(world.husbandry.species_def(String(row["species_id"]))["name"]), reason]})
		_record("animal", "death", {"animal": int(row["uid"]), "day": day, "reason": reason,
			"miss_streak": int(row["miss_streak"]), "bad_water_streak": int(row["bad_water_streak"])})
		state["animals"].erase(row)
	else:
		row["death_streak"] = 0

func _finish_day(day: int, accounts: Dictionary, out: Dictionary) -> void:''')

# 16. Pending apply: fixed species re-anchor when the zone changes.
sub('''		if ok and mode != "work":
			var facility: Dictionary = world.facilities.get(bed_uid, {})''',
'''		if ok and is_fixed_species(String(row["species_id"])) and zone_uid != int(row["zone_uid"]):
			var anchors := _free_anchor_cells(zone(zone_uid), int(row["uid"]))
			if not anchors.is_empty():
				row["anchor"] = String(anchors[0])
				_record("animal", "anchor", {"animal": int(row["uid"]), "cell": String(anchors[0])})
		if ok and mode != "work" and not is_fixed_species(String(row["species_id"])):
			var facility: Dictionary = world.facilities.get(bed_uid, {})''')

# 17. Bed rules: fixed species never hold beds.
sub('''func set_bed(animal_uid: int, bed_uid: int, bed_slot: int) -> Dictionary:
	var row := animal(animal_uid)
	if row.is_empty():
		return _error("未知动物")
	if String(row["mode"]) == "work":
		return _error("役使动物不占用全时床位")''',
'''func set_bed(animal_uid: int, bed_uid: int, bed_slot: int) -> Dictionary:
	var row := animal(animal_uid)
	if row.is_empty():
		return _error("未知动物")
	if String(row["mode"]) == "work":
		return _error("役使动物不占用全时床位")
	if is_fixed_species(String(row["species_id"])):
		return _error("固定物种的休息资格由其固定格提供")''')

# 18. Codec: extended animal shape, water modes, medium match, anchors.
sub('''	var pending := {}
	for key in row["pending"]:
		var value = row["pending"][key]
		pending[String(key)] = int(value) if String(key) in ["zone_uid", "bed_uid", "bed_slot"] else String(value)
	var account: Dictionary = row["account"]
	return {"uid": int(row["uid"]), "species_id": String(row["species_id"]), "stage": String(row["stage"]),''',
'''	var pending := {}
	for key in row["pending"]:
		var value = row["pending"][key]
		pending[String(key)] = int(value) if String(key) in ["zone_uid", "bed_uid", "bed_slot"] else String(value)
	var account: Dictionary = row["account"]
	return {"anchor": String(row.get("anchor", "")), "miss_streak": int(row.get("miss_streak", 0)),
		"bad_water_streak": int(row.get("bad_water_streak", 0)),
		"uid": int(row["uid"]), "species_id": String(row["species_id"]), "stage": String(row["stage"]),''')

sub('''		if String(row["mode"]) not in ["waiting", "nursery", "enclosure", "intensive", "work"]:
			return Scalars.fail("动物归属非法")
		if not zone_types.has(int(row["zone_uid"])):
			return Scalars.fail("动物指向未知功能区")
		var expected := "nursery" if String(row["mode"]) in ["nursery", "waiting"] else String(row["mode"])
		if zone_types[int(row["zone_uid"])] != expected:
			return Scalars.fail("动物归属与功能区类型不符")''',
'''		if String(row["mode"]) not in ["waiting", "nursery", "enclosure", "intensive", "work"] + WATER_MODES:
			return Scalars.fail("动物归属非法")
		if not zone_types.has(int(row["zone_uid"])):
			return Scalars.fail("动物指向未知功能区")
		var mode := String(row["mode"])
		var zone_type := String(zone_types[int(row["zone_uid"])])
		if mode == "waiting":
			if not ["nursery", "water_nursery"].has(zone_type):
				return Scalars.fail("动物归属与功能区类型不符")
		elif zone_type != mode:
			return Scalars.fail("动物归属与功能区类型不符")
		var is_water_zone: bool = WATER_MODES.has(zone_type)
		if (String(species_cfg.get("medium", "land")) == "water") != is_water_zone:
			return Scalars.fail("水陆物种与功能区介质不符")
		if not Scalars.whole(row["miss_streak"], 0, 3) or not Scalars.whole(row["bad_water_streak"], 0, 3):
			return Scalars.fail("水产生存计数非法")
		if is_fixed_species(sid):
			if not row["anchor"] is String or not zone_has_cell(zone_row_of(snapshot, int(row["zone_uid"])), String(row["anchor"])):
				return Scalars.fail("固定物种缺少合法锚点")
		elif not String(row["anchor"]).is_empty():
			return Scalars.fail("非固定物种不携带锚点")''')

# helper for zone cells lookup inside normalize (defined once, static).
sub('''static func normalize(value, snapshot: Dictionary, catalog) -> Dictionary:''',
'''static func zone_row_of(snapshot: Dictionary, zone_uid: int) -> Dictionary:
	for row in snapshot["world"]["ranch"]["zones"]:
		if int(row["uid"]) == zone_uid:
			return row
	return {}

static func zone_has_cell(zone_row: Dictionary, cell: String) -> bool:
	if zone_row.is_empty():
		return false
	return zone_row["cells"].has(cell)

static func normalize(value, snapshot: Dictionary, catalog) -> Dictionary:''')

# 19. Bed-block in codec: fixed species carry no bed.
sub('''			if int(row["bed_uid"]) > 0:
				if String(row["mode"]) == "work":
					return Scalars.fail("役使动物不持有全时床位")''',
'''			if int(row["bed_uid"]) > 0:
				if String(row["mode"]) == "work":
					return Scalars.fail("役使动物不持有全时床位")
				if is_fixed_species(sid):
					return Scalars.fail("固定物种不持有床位")''')

sub('''			elif String(row["mode"]) != "work" and int(row["bed_slot"]) != 0:
				return Scalars.fail("动物床位序号非法")''',
'''			elif String(row["mode"]) != "work" and not is_fixed_species(sid) and int(row["bed_slot"]) != 0:
				return Scalars.fail("动物床位序号非法")''')

# 20. Reservations: fixed species hold no bed row.
sub('''		var bed: Dictionary = facilities.get(int(row["bed_uid"]), {})
		if bed.is_empty() or not bed_capacity_map.has(String(bed["facility_id"])):
			return Scalars.fail("预约床位非法")
		if int(row["bed_slot"]) < 0 or int(row["bed_slot"]) >= int(bed_capacity_map[String(bed["facility_id"])]):
			return Scalars.fail("预约床位序号非法")
		if not trough_ids.has(int(row["trough_uid"])):
			return Scalars.fail("预约食槽非法")''',
'''		var bed: Dictionary = facilities.get(int(row["bed_uid"]), {})
		if int(row["bed_uid"]) == 0:
			if not animal_ids.has(int(row["animal_uid"])) or not is_fixed_species(String(animal_ids[int(row["animal_uid"])]["species_id"])):
				return Scalars.fail("预约床位非法")
		elif bed.is_empty() or not bed_capacity_map.has(String(bed["facility_id"])):
			return Scalars.fail("预约床位非法")
		if int(row["bed_uid"]) > 0 and (int(row["bed_slot"]) < 0 or int(row["bed_slot"]) >= int(bed_capacity_map[String(bed["facility_id"])])):
			return Scalars.fail("预约床位序号非法")
		if not trough_ids.has(int(row["trough_uid"])):
			return Scalars.fail("预约食槽非法")''')

# Bed overlap check: skip zero-bed rows.
sub('''			for other_index in range(index + 1, value["reservations"].size()):
				var other: Dictionary = value["reservations"][other_index]
				if _windows_overlap(int(other["start_t"]), int(row["start_t"])) and int(other["bed_uid"]) == int(row["bed_uid"]) and int(other["bed_slot"]) == int(row["bed_slot"]):
					return Scalars.fail("同一床位时段重叠")''',
'''			for other_index in range(index + 1, value["reservations"].size()):
				var other: Dictionary = value["reservations"][other_index]
				if int(row["bed_uid"]) == 0:
					continue
				if _windows_overlap(int(other["start_t"]), int(row["start_t"])) and int(other["bed_uid"]) == int(row["bed_uid"]) and int(other["bed_slot"]) == int(row["bed_slot"]):
					return Scalars.fail("同一床位时段重叠")''')

p.write_text(s, encoding='utf-8')
print('stage-c patch part 3 applied')
