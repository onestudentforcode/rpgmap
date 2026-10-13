extends SceneTree
## Money/access/negative-coordinate/save transaction boundaries, isolated slots.
const World := preload("res://scripts/farming/p8/p8_world.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
const Snapshot := preload("res://scripts/farming/p8/p8_snapshot.gd")
const Shell := preload("res://scripts/farming/p8/p8_scene.gd")
var checks := 0
var failures: Array[String] = []

class FlakyStore extends RefCounted:
	var inner
	var failing := false
	func _init(real): inner = real
	func active_slot() -> int: return inner.active_slot()
	func create_slot(slot, snapshot, overwrite = false): return inner.create_slot(slot, snapshot, overwrite)
	func open_slot(slot): return inner.open_slot(slot)
	func commit(snapshot): return {"ok": false, "reason": "模拟写盘失败"} if failing else inner.commit(snapshot)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func new_store(): return Store.new("res://.art-work/p8-expansion/test-%d" % Time.get_ticks_usec())
func new_world():
	var w := World.new(new_store())
	check(w.start_new(1)["ok"], "fresh slot")
	return w
func fund(w, amount: int):
	w.primeval_stones += amount
	w._sales_revenue += amount
	w._cash("sales_revenue", amount)

func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	_access_and_payment()
	_layout_and_saves()
	_retry_and_abandon()
	await _ui()
	for failure in failures: printerr(failure)
	print("P8 EXPANSION %s: %d checks" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

func _access_and_payment() -> void:
	var w = new_world()
	var before: Dictionary = w.to_snapshot().duplicate(true)
	check(w.grid.bounds() == Rect2i(-4,0,32,22), "stable original coordinates, reserved west/east envelope")
	check(w.grid.in_bounds(0,0) and w.grid.in_bounds(19,21), "base ownership")
	for cell in [Vector2i(20,0), Vector2i(-4,14), Vector2i(20,14)]:
		check(not w.grid.in_bounds(cell.x,cell.y), "locked access " + str(cell))
		check(not w.till(cell)["ok"], "locked till denied")
		check(not w.build_facility(cell,"fish_pond")["ok"], "locked footprint denied")
	check(not w.workforce.set_seed(Vector2i(20,0),"golden_wheat")["ok"], "locked seed plan denied")
	check(w.workforce.mark(Rect2i(19,0,2,1),"till")["added"] == 1, "designation skips locked part")
	w.workforce.cancel(Rect2i(19,0,2,1))
	# mark/cancel intentionally allocates its own ID; no failed action spends money/AP.
	check(w.primeval_stones == 90 and w.clock.ap == 24, "blocked operations spend nothing")
	check(not w.land.buy("east_far")["ok"] and not w.land.buy("unknown")["ok"], "prerequisite/unknown purchase denied")
	check(w.land.buy("east_near")["ok"] and w.primeval_stones == 10 and w.clock.ap == 24, "real first purchase exactly80, zeroAP")
	check(w.grid.in_bounds(20,0) and w.grid.state_at(Vector2i(20,0)) == w.Grid.State.WILD, "purchase unlocks raw, untended land")
	check(not w.land.buy("east_near")["ok"] and w.primeval_stones == 10, "duplicate purchase is free of side effects")
	check(not w.land.buy("east_far")["ok"], "insufficient money denied")
	check(w.inventory.to_save() == before["inventory"], "no free stock")
	check(w.journal["pending"]["construction_spend"] == 80, "purchase enters cash accounts")
	check(w.end_day()["saved"] and w.open_game(1)["ok"] and w.land.purchased == ["east_near"], "normal day-save/reopen restores ownership")
	var exact = new_world()
	exact.primeval_stones = 80
	check(exact.land.buy("west_water")["ok"] and exact.primeval_stones == 0, "exact balance purchase")
	check(not exact.grid.in_bounds(-4,0), "west upper strip never unlocks accidentally")
	check(exact.grid.in_bounds(-4,14) and not exact.grid.in_bounds(20,14), "water axes independently purchased")

func _layout_and_saves() -> void:
	var w = new_world()
	fund(w,2000)
	w.grant_scaffold({"raw_stone":100,"raw_wood":100,"wood_plank":30,"clean_water":30,"humus":20})
	check(w.till(Vector2i(6,8))["ok"] and w.plant(Vector2i(6,8),"golden_wheat")["ok"], "original crop exists")
	var original: Dictionary = w.instance_at(Vector2i(6,8)).duplicate(true)
	var environment: Dictionary = w.environment_at(Vector2i(6,8)).duplicate(true)
	check(not w.build_facility(Vector2i(19,12),"pen")["ok"], "cross-parcel full footprint blocked")
	for id in ["east_near","east_far","east_lower","west_water","east_water_near","east_water_far"]:
		check(w.land.buy(id)["ok"], "buy " + id)
	check(w.instance_at(Vector2i(6,8)) == original and w.environment_at(Vector2i(6,8)) == environment, "purchase preserves old crop/light/environment")
	check(w.environment_at(Vector2i(-4,14))["water"] == 60 and w.environment_at(Vector2i(20,0))["light"] == w.config["light"]["default"], "negative index and new land light")
	check(w.build_facility(Vector2i(-4,14),"fish_pond")["ok"], "west bank water habitat")
	check(w.build_facility(Vector2i(20,14),"fish_pond")["ok"], "east bank water habitat")
	check(w.build_facility(Vector2i(19,12),"pen")["ok"], "owned cross-parcel footprint accepted")
	check(w.till(Vector2i(20,0))["ok"] and w.workforce.set_seed(Vector2i(20,0),"golden_wheat")["ok"], "new land cultivation/planning")
	var worker: Dictionary = w.workforce.hire("扩地检查")
	var person: Dictionary = w.workforce._worker(int(worker["worker_id"]))
	check(w.workforce.configure(int(person["id"]),6,false,person["priorities"],[[20,0,4,8]])["ok"], "new parcel responsible area")
	check(w.workforce.set_farm_duty(int(person["id"]),true,"normal")["ok"], "explicit duty")
	var settled: Dictionary = w.end_day()
	check(settled["saved"] and w.instance_at(Vector2i(20,0)).get("crop_id") == "golden_wheat", "paid worker plants on purchased land: " + String(settled.get("save_error","")))
	check(w.open_game(1)["ok"] and w.facility_at(Vector2i(-4,14)).get("facility_id") == "fish_pond", "negative facility restored")
	var snapshot: Dictionary = w.to_snapshot().duplicate(true)
	for bad in ["duplicate","unknown","prerequisite","locked_water"]:
		var corrupt: Dictionary = snapshot.duplicate(true)
		match bad:
			"duplicate": corrupt["world"]["land"]["purchased"].append("west_water")
			"unknown": corrupt["world"]["land"]["purchased"].append("fake")
			"prerequisite": corrupt["world"]["land"]["purchased"].erase("east_near")
			"locked_water": corrupt["world"]["land"]["purchased"].erase("west_water")
		check(not w.apply_snapshot(corrupt)["ok"] and w.to_snapshot() == snapshot, "bad snapshot rejects atomically " + bad)
	var old: Dictionary = snapshot.duplicate(true)
	old["schema"] = 16
	check(not Snapshot.normalize(old)["ok"], "old development schema explicitly rejected")

func _retry_and_abandon() -> void:
	var wrapper := FlakyStore.new(new_store())
	var w := World.new(wrapper)
	check(w.start_new(1)["ok"], "flaky isolated slot")
	check(w.land.buy("east_near")["ok"], "unsaved purchase")
	wrapper.failing = true
	w.clock.ap = 1
	check(not w.till(Vector2i(20,0))["saved"], "lastAP save fails")
	check(w.land.purchased == ["east_near"] and w.grid.state_at(Vector2i(20,0)) == w.Grid.State.WILD and w.primeval_stones == 10, "rollback preserves purchase but undoes triggering till")
	check(not w.land.buy("west_water")["ok"], "pending save blocks all purchases")
	wrapper.failing = false
	check(w.retry_day_save()["ok"] and w.clock.total_days == 1 and w.grid.state_at(Vector2i(20,0)) == w.Grid.State.TILLED and w.primeval_stones == 10, "retry publishes same ownership/till/cash once")
	check(w.open_game(1)["ok"], "retry file reopens")
	var other = new_world()
	check(other.land.buy("west_water")["ok"] and other.abandon_day()["ok"], "abandon unsaved purchase")
	check(other.land.purchased.is_empty() and other.primeval_stones == 90 and not other.grid.in_bounds(-4,14), "abandon returns original rights/cash")

func descendants(node: Node) -> Array:
	var out := []
	for child in node.get_children(): out.append(child); out.append_array(descendants(child))
	return out

func _ui() -> void:
	var shell := Shell.new()
	shell.store = new_store()
	shell.settings = shell.settings.get_script().new("res://.art-work/p8-expansion/settings.cfg",0.1)
	root.add_child(shell)
	await process_frame
	shell._new(1,false)
	var initial_grass := shell.terrain.used_count("grass")
	shell._apply_manual(Vector2i(20,0))
	check(shell._context == "land" and shell.world.primeval_stones == 90, "clicking locked parcel opens review, no purchase")
	var button: Button
	for node in descendants(shell.sidebar):
		if node is Button and node.get_meta("land_buy","") == "east_near": button = node
	check(button != null and not button.disabled, "actual purchase button")
	if button != null: button.pressed.emit()
	check(is_instance_valid(shell.confirmation) and shell.world.primeval_stones == 90, "review confirmation before cash changes")
	if is_instance_valid(shell.confirmation): shell.confirmation.confirmed.emit()
	await process_frame
	check(shell.world.primeval_stones == 10 and shell.world.clock.ap == 24, "actual confirm event buys0AP")
	check(shell.terrain.used_count("grass") == initial_grass+32, "purchased terrain displayed")
	shell._fit_map()
	check(is_finite(shell.camera.position.x) and shell.camera.position.x < shell.world.grid.width*32.0, "camera includes western extent")
	shell._show_land("west_water")
	var before: Dictionary = shell.world.to_snapshot().duplicate(true)
	shell._locate_land("west_water")
	check(shell.camera.position.x < 0 and shell.world.to_snapshot() == before, "west preview read-only, negative coordinates")
	check(shell.world.abandon_day()["ok"] and shell.terrain.used_count("grass") == initial_grass, "rollback removes unlocked terrain visually")
	shell.queue_free()
