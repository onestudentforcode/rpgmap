extends "res://scripts/farming/v2/v2_world.gd"
## P8 development world: independent namespace, candidate day settlement with
## full rollback, real water changes and research-gated content registration.
const P8Data := preload("res://scripts/farming/p8/p8_data.gd")
const P8Snapshot := preload("res://scripts/farming/p8/p8_snapshot.gd")
const P8Husbandry := preload("res://scripts/farming/p8/p8_husbandry.gd")
const P8Operations := preload("res://scripts/farming/p8/p8_operations.gd")
const P8Workforce := preload("res://scripts/farming/p8/p8_workforce.gd")
const P8Research := preload("res://scripts/farming/p8/p8_research.gd")
const P8Flowers := preload("res://scripts/farming/p8/p8_flowers.gd")
const P8Devices := preload("res://scripts/farming/p8/p8_devices.gd")

## Session-only transaction state: the settled candidate awaiting a successful
## write, and the pre-action state a failed commit restores. Never persisted.
var _pending_day := {}
var _day_checkpoint := {}
## Facility ownership, production strategies, reserves and the scheduler.
var operations
## Research benches, farm-wide completed knowledge and daily receipts.
var research
## Flower shares, hand picks and pollination marks.
var flowers
## Field stations and growth lamps; they run inside the opening-day step.
var devices

func _init(slot_store = null) -> void:
	operations = P8Operations.new(self)
	research = P8Research.new(self)
	flowers = P8Flowers.new(self, P8Data.load_data()["flowers"])
	devices = P8Devices.new(self, P8Data.load_data()["devices"])
	super(slot_store)

func _catalog():
	return P8Data

func _codec():
	return P8Snapshot

func _make_husbandry():
	return P8Husbandry.new(self, P8Data.load_data())

func _make_workforce():
	return P8Workforce.new(self)

func _settle_workforce(completed_day: int) -> void:
	# The unified P8 scheduler replaces the V1/V2 settle: facilities, research
	# and opted-in farm duty share one quota and budget per worker.
	operations.settle(completed_day)

## Research advances from today's receipts after husbandry and before the
## reports archive, so unlock events land on the completed day; unused flower
## shares expire with the completed day.
func _settle_husbandry(completed_day: int) -> void:
	husbandry.settle(completed_day)
	research.settle(completed_day)
	flowers.settle(completed_day)
	reports.settle(completed_day)

func begin_research_settle(completed_day: int) -> void:
	research.begin_settle(completed_day)

func finish_research_settle() -> void:
	research.finish_settle()

## Scheduler seam: owned research benches with an open receipt slot today.
func _research_candidates(worker: Dictionary) -> Array:
	var out := []
	for uid in operations.facilities_of(int(worker["id"])):
		var facility: Dictionary = facilities.get(uid, {})
		if facility.is_empty() or facility_defs[String(facility["facility_id"])].get("kind") != "research":
			continue
		if research.work_quote(int(uid))["ok"]:
			out.append(operations._candidate(_tier_of(String(operations.state["facilities"][uid]["priority"])), 3, int(uid), "研究",
				"研究台#%d推进" % uid, "research:%d" % uid,
				func(): return research.work(int(uid), "worker")))
	return out

func _tier_of(level: String) -> int:
	return {"high": 0, "normal": 1, "low": 2}[level]

func demolish_facility(uid: int) -> Dictionary:
	if research != null and not research.active_project(uid).is_empty():
		return _error("研究台有在研项目，完成或处理后才能拆除")
	var result: Dictionary = super.demolish_facility(uid)
	if result["ok"] and facilities.get(uid, {}).is_empty() and research != null:
		research.forget_bench(uid)
	return result

func _facility_removed(uid: int) -> void:
	super(uid)
	operations.forget_facility(uid)
	devices.forget(uid)

func to_snapshot() -> Dictionary:
	var snapshot := super.to_snapshot()
	snapshot["world"]["p8"] = operations.to_save()
	snapshot["world"]["research"] = research.to_save()
	snapshot["world"]["flowers"] = flowers.to_save()
	snapshot["world"]["devices"] = devices.to_save()
	return snapshot

func _snapshot_applied(snapshot: Dictionary) -> void:
	super(snapshot)
	if snapshot["world"].has("p8"):
		operations.apply_save(snapshot["world"]["p8"])
	if snapshot["world"].has("research"):
		research.apply_save(snapshot["world"]["research"])
	if snapshot["world"].has("flowers"):
		flowers.apply_save(snapshot["world"]["flowers"])
	if snapshot["world"].has("devices"):
		devices.apply_save(snapshot["world"]["devices"])

## Pollination bonus: one extra oilseed per pollinated cycle at harvest.
func _harvest_bonus(instance: Dictionary) -> Dictionary:
	var uid := int(instance["uid"])
	if String(instance["crop_id"]) == "oilseed_flower" and flowers.pollinated(uid):
		flowers.forget_crop(uid)
		return {"oilseed": 1}
	return {}

func clear_crop(cell: Vector2i) -> Dictionary:
	var crop := instance_at(cell)
	var result: Dictionary = super(cell)
	if result["ok"] and not crop.is_empty():
		flowers.forget_crop(int(crop["uid"]))
	return result

## Hand pick: one AP draws the plant's remaining share into real stock.
func pick_flower(cell: Vector2i) -> Dictionary:
	var checked: Dictionary = _can_act(1)
	if not checked["ok"]:
		return checked
	var crop := instance_at(cell)
	if crop.is_empty() or not flowers.is_flower_crop(String(crop["crop_id"])):
		return _error("这里没有可采花植物")
	var uid := int(crop["uid"])
	var drawn: Dictionary = flowers.consume(uid, "player")
	if not bool(drawn["ok"]):
		return _error("今日无可用花源份额（花期未到、环境不足或已用尽）")
	var contents: Dictionary = flowers.share_contents()
	for item in contents:
		inventory.add(item, int(contents[item]))
	_record_flow(contents, {}, "采花收获")
	return _finish(1, {"ok": true, "items": contents.duplicate(), "crop_uid": uid})

# --- Research gating -------------------------------------------------------

## Completed research is farm-wide knowledge; every gated def reads it live.
func _research_done(research_id: String) -> bool:
	return research.is_completed(research_id)

func research_block(research_id: String) -> String:
	if research_id.is_empty() or _research_done(research_id):
		return ""
	return "需先完成研究「%s」（研究台功能后续阶段接入）" % _research_name(research_id)

func _research_name(research_id: String) -> String:
	for row in P8Data.load_data()["research"]:
		if String(row["id"]) == research_id:
			return String(row["name"])
	return research_id

## Explicit construction substitutes for the plain-stone part of a build:
## composite panels 1:1 or reclaimed fill 2:1; special materials never swap.
var build_substitute := ""

func _substituted_materials(facility_id: String) -> Dictionary:
	var materials: Dictionary = facility_defs[facility_id]["materials"].duplicate()
	if build_substitute.is_empty() or not materials.has("raw_stone"):
		return materials
	var stones := int(materials["raw_stone"])
	materials.erase("raw_stone")
	if build_substitute == "panel":
		materials["composite_stone_panel"] = int(materials.get("composite_stone_panel", 0)) + stones
	elif build_substitute == "fill":
		materials["reclaimed_fill"] = int(materials.get("reclaimed_fill", 0)) + stones * 2
	return materials

## Swap the facility's material group for the substituted one around the shared
## validation/build so the plain-stone part is replaced as one whole group.
func _with_substituted(facility_id: String, action: Callable) -> Dictionary:
	var definition: Dictionary = facility_defs[facility_id]
	var original: Dictionary = definition["materials"]
	definition["materials"] = _substituted_materials(facility_id)
	var result: Dictionary = action.call()
	definition["materials"] = original
	return result

func can_build_facility(cell: Vector2i, facility_id: String) -> Dictionary:
	if facility_defs.has(facility_id):
		var blocked := research_block(String(facility_defs[facility_id].get("research", "")))
		if not blocked.is_empty():
			return _error(blocked)
	if not build_substitute.is_empty() and facility_defs[facility_id]["materials"].has("raw_stone"):
		return _with_substituted(facility_id, func(): return super.can_build_facility(cell, facility_id))
	return super(cell, facility_id)

func build_facility(cell: Vector2i, facility_id: String) -> Dictionary:
	if not build_substitute.is_empty() and facility_defs[facility_id]["materials"].has("raw_stone"):
		return _with_substituted(facility_id, func(): return super.build_facility(cell, facility_id))
	return super(cell, facility_id)

func plant(cell: Vector2i, crop_id: String) -> Dictionary:
	if crop_defs.has(crop_id):
		var blocked := research_block(String(crop_defs[crop_id].get("research", "")))
		if not blocked.is_empty():
			return _error(blocked)
	return super(cell, crop_id)

func buy(item_id: String, quantity) -> Dictionary:
	if item_id == "purifying_mat_culture":
		return _error("培养单位请在净水菌床面板直接购入：扣款即占位，不入仓库")
	if _items.has(item_id):
		var blocked := research_block(String(_items[item_id].get("research", "")))
		if not blocked.is_empty():
			return _error(blocked)
	return super(item_id, quantity)

func start_batch(facility_uid: int, recipe_id: String) -> Dictionary:
	if recipe_defs.has(recipe_id):
		var blocked := research_block(String(recipe_defs[recipe_id].get("research", "")))
		if not blocked.is_empty():
			return _error(blocked)
	return super(facility_uid, recipe_id)

# --- Candidate day settlement ----------------------------------------------

func _can_act(ap: int = 1) -> Dictionary:
	# Capture the pre-action state whenever this action may trigger the day end;
	# a failed commit then restores the exact pre-operation world, keeping the
	# settled result only as a retryable candidate.
	if ap > 0 and not _labour_action and daily_save_error.is_empty() and clock.ap - ap <= 0:
		_day_checkpoint = to_snapshot()
	return super(ap)

func end_day() -> Dictionary:
	if daily_save_error.is_empty():
		_day_checkpoint = to_snapshot()
	return super()

## Day D+1 opening: lamps light first, then station services, all on real
## stock; a reload or replayed candidate never triggers a second opening.
func _opening_devices(day: int) -> void:
	devices.run_opening(day)

func start_new(slot: int, overwrite_confirmed: bool = false) -> Dictionary:
	var created: Dictionary = super(slot, overwrite_confirmed)
	if created["ok"]:
		_opening_devices(0)
	return created

## Effective light: the day's active lamps lift covered cells to the lamp
## value; everything (growth, flowers, UI) reads this one query.
func environment_at(cell: Vector2i) -> Dictionary:
	var env := super(cell)
	if env.is_empty() or not devices.lamp_active_at(cell):
		return env
	env["light"] = maxi(int(env["light"]), int(P8Data.load_data()["devices"]["lamp"]["light"]))
	return env

func _light_at(cell: Vector2i) -> int:
	var natural := super(cell)
	if devices.lamp_active_at(cell):
		return maxi(natural, int(P8Data.load_data()["devices"]["lamp"]["light"]))
	return natural

func _commit_day(_day: int, ledger_error: String) -> void:
	if _store == null:
		return
	if not ledger_error.is_empty():
		_fail_day(ledger_error, {})
		return
	var candidate := to_snapshot()
	var saved: Dictionary = _store.commit(candidate)
	if saved["ok"]:
		_pending_day = {}
		_day_checkpoint = {}
		daily_save_error = ""
	else:
		_fail_day(String(saved["reason"]), candidate)

func _fail_day(reason: String, candidate: Dictionary) -> void:
	_pending_day = candidate
	if not _day_checkpoint.is_empty():
		var restore: Dictionary = _day_checkpoint
		_day_checkpoint = {}
		apply_snapshot(restore)
	daily_save_error = reason
	changed.emit()

## Retrying writes the retained candidate exactly once and publishes it; it
## never re-runs workers, ecology or the opening step.
func retry_day_save() -> Dictionary:
	if daily_save_error.is_empty() or _store == null or _store.active_slot() == 0:
		return _error("没有待重试的日存档")
	if _pending_day.is_empty():
		return _error("本日结未通过校验，无法重试；请放弃当天")
	var saved: Dictionary = _store.commit(_pending_day)
	if saved["ok"]:
		var publish: Dictionary = _pending_day
		_pending_day = {}
		_day_checkpoint = {}
		apply_snapshot(publish)
	return saved

func abandon_day() -> Dictionary:
	_pending_day = {}
	_day_checkpoint = {}
	return super()
