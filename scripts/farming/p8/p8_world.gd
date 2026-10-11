extends "res://scripts/farming/v2/v2_world.gd"
## P8 development world: independent namespace, candidate day settlement with
## full rollback, real water changes and research-gated content registration.
const P8Data := preload("res://scripts/farming/p8/p8_data.gd")
const P8Snapshot := preload("res://scripts/farming/p8/p8_snapshot.gd")
const P8Husbandry := preload("res://scripts/farming/p8/p8_husbandry.gd")
const P8Operations := preload("res://scripts/farming/p8/p8_operations.gd")
const P8Workforce := preload("res://scripts/farming/p8/p8_workforce.gd")

## Session-only transaction state: the settled candidate awaiting a successful
## write, and the pre-action state a failed commit restores. Never persisted.
var _pending_day := {}
var _day_checkpoint := {}
## Facility ownership, production strategies, reserves and the scheduler.
var operations

func _init(slot_store = null) -> void:
	operations = P8Operations.new(self)
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
	# (P8.c) and opted-in farm duty share one quota and budget per worker.
	operations.settle(completed_day)

func _facility_removed(uid: int) -> void:
	super(uid)
	operations.forget_facility(uid)

func to_snapshot() -> Dictionary:
	var snapshot := super.to_snapshot()
	snapshot["world"]["p8"] = operations.to_save()
	return snapshot

func _snapshot_applied(snapshot: Dictionary) -> void:
	super(snapshot)
	if snapshot["world"].has("p8"):
		operations.apply_save(snapshot["world"]["p8"])

# --- Research gating -------------------------------------------------------

## P8.c owns real research progress; until it lands every gated item stays
## explicitly non-executable instead of silently open.
func _research_done(_research_id: String) -> bool:
	return false

func research_block(research_id: String) -> String:
	if research_id.is_empty() or _research_done(research_id):
		return ""
	return "需先完成研究「%s」（研究台功能后续阶段接入）" % _research_name(research_id)

func _research_name(research_id: String) -> String:
	for row in P8Data.load_data()["research"]:
		if String(row["id"]) == research_id:
			return String(row["name"])
	return research_id

func can_build_facility(cell: Vector2i, facility_id: String) -> Dictionary:
	if facility_defs.has(facility_id):
		var blocked := research_block(String(facility_defs[facility_id].get("research", "")))
		if not blocked.is_empty():
			return _error(blocked)
	return super(cell, facility_id)

func plant(cell: Vector2i, crop_id: String) -> Dictionary:
	if crop_defs.has(crop_id):
		var blocked := research_block(String(crop_defs[crop_id].get("research", "")))
		if not blocked.is_empty():
			return _error(blocked)
	return super(cell, crop_id)

func buy(item_id: String, quantity) -> Dictionary:
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

## Day D+1 opening devices run inside the settlement transaction, after day D is
## frozen; the foundation stage keeps the step empty and reloads never re-run it.
func _opening_devices(_day: int) -> void:
	pass

func start_new(slot: int, overwrite_confirmed: bool = false) -> Dictionary:
	var created: Dictionary = super(slot, overwrite_confirmed)
	if created["ok"]:
		_opening_devices(0)
	return created

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
