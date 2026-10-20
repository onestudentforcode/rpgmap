extends SceneTree
## Real disk transactions and edge cases. Explicit resource scaffolds are not
## business earnings; production/progression evidence is collected separately.
const World := preload("res://scripts/farming/p8/p8_world.gd")
const Codec := preload("res://scripts/farming/p8/p8_snapshot.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const Fixture := preload("res://scripts/farming/tests/p107_fixture.gd")
var checks := 0
var failures := []

class FailingStore extends RefCounted:
	var inner
	var failing := false
	func _init(value): inner = value
	func active_slot() -> int: return inner.active_slot()
	func create_slot(slot: int, value: Dictionary) -> Dictionary: return inner.create_slot(slot, value)
	func open_slot(slot: int) -> Dictionary: return inner.open_slot(slot)
	func commit(value: Dictionary) -> Dictionary:
		return {"ok": false, "reason": "P107 injected disk failure"} if failing else inner.commit(value)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("P107 TRANSACTION " + label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	_disk()
	_eligibility()
	_bounds()
	_construction()
	print("P107 TRANSACTION %s (%d)" % ["OK" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _disk() -> void:
	var w := World.new()
	Fixture.unlock(w, 2)
	w.grant_scaffold({"resin": 100})
	var store := FailingStore.new(Store.new("res://.art-work/p107-tests/transactions-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]))
	var baseline := w.to_snapshot()
	check(store.create_slot(1, baseline)["ok"], "create actual disk stage2 slot")
	w._store = store
	check(w.progress.exchange("resin_for_panels", 3)["ok"], "buy actual event panels")
	check(w.progress.exchange("resin_for_refined_oil", 2)["ok"], "buy actual event oil")
	check(w.progress.exchange("resin_for_matrix", 2)["ok"], "buy actual event matrix")
	var stock := w.inventory.to_save()
	var delivered: int = w.progress.deliveries()
	check(w.progress.complete_event("integrated_estate")["ok"], "resource event actual submission")
	for item in w.progress.config["events"][2]["inputs"]:
		check(w.inventory.count(item) == int(stock.get(item, 0)) - int(w.progress.config["events"][2]["inputs"][item]), "event debits once " + item)
	check(w.progress.deliveries() == delivered, "resource event does not count as supply")
	var before := w.to_snapshot()
	var json_roundtrip: Dictionary = Codec.normalize(JSON.parse_string(JSON.stringify(before)))
	check(json_roundtrip["ok"] and json_roundtrip["snapshot"] == before, "JSON normalization exact with interleaved event and barter receipts")
	store.failing = true
	w.end_day()
	check(not w.daily_save_error.is_empty() and w.to_snapshot() == before, "failed daily commit restores exact checkpoint including prior zero-AP trades")
	var candidate: Dictionary = w._pending_day.duplicate(true)
	check(not candidate.is_empty() and Codec.normalize(candidate)["ok"], "retry candidate contains valid stage3 and receipts")
	check(store.inner.read_slot(1)["snapshot"] == baseline, "failed commit leaves disk unchanged")
	check(not w.progress.exchange("resin_for_sludge")["ok"], "trading blocked during save failure")
	check(not w.progress.complete_event("integrated_estate")["ok"], "event blocked during save failure")
	check(not w.retry_day_save()["ok"] and w.to_snapshot() == before, "failed retry does not rerun transfers")
	store.failing = false
	check(w.retry_day_save()["ok"] and w.to_snapshot() == candidate, "retry publishes exact original candidate")
	check(not w.retry_day_save()["ok"], "second retry has nothing to publish")
	check(w.open_game(1)["ok"] and w.to_snapshot() == candidate, "actual disk reload preserves integers counts materials and stage")
	check(not w.progress.complete_event("integrated_estate")["ok"], "reload cannot repeat final event")
	check(store.create_slot(2, baseline)["ok"] and w.apply_snapshot(baseline)["ok"], "independent baseline for abandon test")
	check(w.progress.exchange("resin_for_panels", 1)["ok"], "unsaved exchange succeeds")
	check(w.abandon_day()["ok"] and w.to_snapshot() == baseline, "abandon restores both inventory and economic transaction sequence from disk")
	for schema in [23, 24]:
		var old := baseline.duplicate(true)
		old["schema"] = schema
		check(not Codec.normalize(old)["ok"], "explicit old schema refusal " + str(schema))

func _eligibility() -> void:
	var w := World.new()
	w.grant_scaffold({"raw_wood": 30, "raw_stone": 30, "wood_plank": 20, "wastewater": 4, "mushroom": 4})
	var built: Dictionary = w.build_facility(Vector2i(4, 1), "research_bench")
	check(built["ok"], "research bench remains constructible at stage0")
	if not built["ok"]: return
	var uid := int(built["facility_uid"])
	var before := w.to_snapshot()
	var quote: Dictionary = w.research.quote_start(uid, "biofiltration")
	check(not quote["ok"] and not w.research.start(uid, "biofiltration")["ok"], "valid bench and samples cannot bypass stage1")
	check(w.to_snapshot() == before, "locked research leaves stock cash and project unchanged")
	Fixture.unlock(w, 1)
	check(w.research.quote_start(uid, "biofiltration")["ok"], "same bench research opens after actual milestone")
	var removable: Dictionary = w.build_facility(Vector2i(8, 1), "research_bench")
	check(removable["ok"], "ordinary empty host for removal check")
	check(w.research.start(uid, "biofiltration")["ok"], "stage-open project starts normally")
	var progress: Dictionary = w.progress.to_save()
	check(w.demolish_facility(int(removable.get("facility_uid", 0)))["ok"], "remove idle host under ordinary rules")
	check(w.progress.to_save() == progress and w.progress.stage() == 1, "global milestone not recomputed from buildings")
	check(Codec.normalize(w.to_snapshot())["ok"], "stage remains savable after local removal")

func _bounds() -> void:
	var w := World.new()
	Fixture.unlock(w, 2)
	w.grant_scaffold({"resin": 10})
	var before := w.to_snapshot()
	for amount in [-1, 0, 1.25, 1000001, INF, NAN, "1", true]:
		check(not w.progress.exchange("resin_for_sludge", amount)["ok"], "invalid batch rejected " + str(amount))
	check(not w.progress.exchange("unknown")["ok"], "unknown offer refused")
	check(not w.progress.exchange("resin_for_sludge", 6)["ok"], "insufficient full batch stock refused")
	check(w.to_snapshot() == before, "all rejected exchanges leave world unchanged")
	w.inventory.add("sludge", 9000000000000)
	w._record_flow({"sludge": 9000000000000}, {}, "库存上限测试")
	before = w.to_snapshot()
	check(not w.progress.exchange("resin_for_sludge")["ok"] and w.to_snapshot() == before, "receive overflow refuses whole trade")

func _construction() -> void:
	var w := World.new()
	w.grant_scaffold({"raw_wood": 30, "reclaimed_fill": 30})
	w.build_substitute = "fill"
	var expected: Dictionary = w._substituted_materials("woodshop")
	var fill := w.inventory.count("reclaimed_fill")
	var stone := w.inventory.count("raw_stone")
	var built: Dictionary = w.build_facility(Vector2i(4, 1), "woodshop")
	check(expected.has("reclaimed_fill") and built["ok"], "existing fill substitute constructs real workshop")
	check(w.inventory.count("reclaimed_fill") == fill - int(expected.get("reclaimed_fill", 0)) and w.inventory.count("raw_stone") == stone,
		"construction consumes substituted fill rather than stone")
	check(Codec.normalize(w.to_snapshot())["ok"], "substitute construction persists")
