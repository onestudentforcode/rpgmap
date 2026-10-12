extends RefCounted
## P8 flower sources: every flowering plant holds one daily share; hand picks
## and hive maintenance draw from the same pool, and real hive use marks the
## oilseed cycle pollinated. Shares never become tradeable stock.
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")
const FLOWER_CROPS := {"honeybell_bush": "perennial", "oilseed_flower": "window"}

var _owner: WeakRef
var world:
	get:
		return _owner.get_ref()
var state := {"shares": [], "pollinated": []}
var settings: Dictionary
## Clock advances before workers run. Their flower draws still belong to the
## completed day, including shares initialized by a UI preview on that day.
var _settle_day := -1

func _today() -> int:
	return _settle_day if _settle_day >= 0 else world.clock.total_days

func begin_settle(completed_day: int) -> void:
	_settle_day = completed_day

func finish_settle() -> void:
	_settle_day = -1

func _init(owner, flower_settings: Dictionary) -> void:
	_owner = weakref(owner)
	settings = flower_settings

func is_flower_crop(crop_id: String) -> bool:
	return FLOWER_CROPS.has(crop_id)

func share_contents() -> Dictionary:
	return settings["contents"].duplicate()

## Flowering condition from live state: growth phase plus a normal environment
## on every occupied cell. Species names alone never qualify a plant.
func eligible(crop_uid: int) -> bool:
	var crop: Dictionary = world.crops.get(crop_uid, {})
	if crop.is_empty():
		return false
	var crop_id := String(crop["crop_id"])
	if not FLOWER_CROPS.has(crop_id):
		return false
	if crop_id == "honeybell_bush" and String(crop["state"]) != "mature":
		return false
	if crop_id == "oilseed_flower":
		var window: Array = settings["oilseed_window"]
		if String(crop["state"]) == "mature" or int(crop["progress"]) < int(window[0]) or int(crop["progress"]) >= int(window[1]):
			return false
	var definition: Dictionary = world.crop_defs[crop_id]
	var origin := Vector2i(int(crop["origin"][0]), int(crop["origin"][1]))
	for dy in range(int(definition["footprint"][1])):
		for dx in range(int(definition["footprint"][0])):
			var env: Dictionary = world.environment_at(origin + Vector2i(dx, dy))
			if int(env["water"]) < int(settings["min_water"]) or int(env["fertility"]) < int(settings["min_fertility"]) \
					or absi(int(env["light"]) - int(definition["light"])) > int(settings["light_tolerance"]):
				return false
	return true

## One share per plant per day, initialized at the day's first eligibility;
## mid-day dryness only suspends the unused remainder, never reissues it.
func share_of(crop_uid: int) -> Dictionary:
	for row in state["shares"]:
		if int(row["uid"]) == crop_uid:
			if int(row["day"]) != _today():
				return {}
			return row
	if not eligible(crop_uid):
		return {}
	var row := {"uid": crop_uid, "day": _today(), "used": 0}
	state["shares"].append(row)
	return row

func share_available(crop_uid: int) -> bool:
	var row := share_of(crop_uid)
	return not row.is_empty() and int(row["used"]) < int(settings["share_capacity"]) and eligible(crop_uid)

## Atomic 0/1 draw. Hive consumers mark the oilseed cycle pollinated; hand
## picks never do. Returns {ok, pollinated} so a rollback can undo the mark.
func consume(crop_uid: int, consumer: String) -> Dictionary:
	if not share_available(crop_uid):
		return {"ok": false, "pollinated": false}
	var row := share_of(crop_uid)
	row["used"] = int(row["used"]) + 1
	var marked := false
	if consumer != "player" and String(world.crops[crop_uid]["crop_id"]) == "oilseed_flower" and not state["pollinated"].has(crop_uid):
		state["pollinated"].append(crop_uid)
		marked = true
	return {"ok": true, "pollinated": marked}

func release(crop_uid: int, undo_pollination: bool) -> void:
	for row in state["shares"]:
		if int(row["uid"]) == crop_uid and int(row["day"]) == _today():
			row["used"] = maxi(0, int(row["used"]) - 1)
	if undo_pollination:
		state["pollinated"].erase(crop_uid)

func pollinated(crop_uid: int) -> bool:
	return state["pollinated"].has(crop_uid)

## Stable-ordered plants with an available share inside the hive coverage.
func hive_candidates(hive_uid: int) -> Array:
	var facility: Dictionary = world.facilities.get(hive_uid, {})
	if facility.is_empty():
		return []
	var footprint: Array = world.facility_defs[String(facility["facility_id"])]["footprint"]
	var origin := Vector2i(int(facility["origin"][0]), int(facility["origin"][1]))
	var margin := int(settings["range"])
	var rect := Rect2i(origin.x - margin, origin.y - margin,
		int(footprint[0]) + margin * 2, int(footprint[1]) + margin * 2)
	var out := []
	for uid in world.crops:
		if not FLOWER_CROPS.has(String(world.crops[uid]["crop_id"])):
			continue
		var anchor := Vector2i(int(world.crops[uid]["origin"][0]), int(world.crops[uid]["origin"][1]))
		if rect.has_point(anchor) and share_available(int(uid)):
			out.append(int(uid))
	out.sort()
	return out

func hive_coverage(hive_uid: int) -> Dictionary:
	var candidates := hive_candidates(hive_uid)
	var facility: Dictionary = world.facilities.get(hive_uid, {})
	var total := 0
	var rect := Rect2i()
	if not facility.is_empty():
		var footprint: Array = world.facility_defs[String(facility["facility_id"])]["footprint"]
		var origin := Vector2i(int(facility["origin"][0]), int(facility["origin"][1]))
		var margin := int(settings["range"])
		rect = Rect2i(origin.x - margin, origin.y - margin,
			int(footprint[0]) + margin * 2, int(footprint[1]) + margin * 2)
		for uid in world.crops:
			if FLOWER_CROPS.has(String(world.crops[uid]["crop_id"])):
				var anchor := Vector2i(int(world.crops[uid]["origin"][0]), int(world.crops[uid]["origin"][1]))
				if rect.has_point(anchor):
					total += 1
	return {"available": candidates.size(), "plants": total, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]}

## Remove a harvested or cleared plant's records; ledger history stays as-is.
func forget_crop(crop_uid: int) -> void:
	for row in state["shares"].duplicate():
		if int(row["uid"]) == crop_uid:
			state["shares"].erase(row)
	state["pollinated"].erase(crop_uid)

## Unused shares expire with the day; pollination marks live until harvest.
func settle(_completed_day: int) -> void:
	state["shares"] = []

func to_save() -> Dictionary:
	return state.duplicate(true)

func apply_save(value: Dictionary) -> void:
	_settle_day = -1
	state = value.duplicate(true)

## Detached validation: current-day shares reference living flower crops and
## stay within capacity; pollination only ever marks oilseed plants.
static func normalize(value, day: int, world: Dictionary, catalog) -> Dictionary:
	if not value is Dictionary or not Scalars.exact(value, ["shares", "pollinated"]):
		return Scalars.fail("花源快照字段非法")
	var settings: Dictionary = catalog.load_data()["flowers"]
	var crop_defs: Dictionary = catalog.definitions("crops")
	var crops := {}
	for row in world["crops"]:
		crops[int(row["uid"])] = row
	var out := {"shares": [], "pollinated": []}
	var seen := {}
	for row in value["shares"]:
		if not row is Dictionary or not Scalars.exact(row, ["uid", "day", "used"]):
			return Scalars.fail("花源份额字段非法")
		var uid := int(row["uid"])
		if not crops.has(uid) or not String(crops[uid]["crop_id"]) in FLOWER_CROPS or seen.has(uid):
			return Scalars.fail("花源份额指向非法作物")
		seen[uid] = true
		if int(row["day"]) != day or not Scalars.whole(row["used"], 0, int(settings["share_capacity"])):
			return Scalars.fail("花源份额日期或数量非法")
		out["shares"].append({"uid": uid, "day": int(row["day"]), "used": int(row["used"])})
	var seen_poll := {}
	for uid in value["pollinated"]:
		if not Scalars.whole(uid, 1) or not crops.has(int(uid)) or seen_poll.has(int(uid)):
			return Scalars.fail("授粉标记非法")
		if String(crops[int(uid)]["crop_id"]) != "oilseed_flower":
			return Scalars.fail("授粉标记只能属于油籽花")
		seen_poll[int(uid)] = true
		out["pollinated"].append(int(uid))
	return {"ok": true, "flowers": out}
