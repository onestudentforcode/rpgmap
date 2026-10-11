extends SceneTree
## P7.e checks: husbandry overview, watch preferences and the reporting pipeline.
const Scene := preload("res://scenes/farming/farm_v2.tscn")
const World := preload("res://scripts/farming/v2/v2_world.gd")
const Snapshot := preload("res://scripts/farming/v2/v2_snapshot.gd")
const Store := preload("res://scripts/farming/v2/v2_slot_store.gd")
var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func has_text(node: Node, text: String) -> bool:
	if node is Label and String(node.text).contains(text): return true
	if node is Button and (String(node.text).contains(text) or String(node.tooltip_text).contains(text)): return true
	for child in node.get_children():
		if has_text(child,text): return true
	return false

func adult(habitat: Dictionary, growth_target: int) -> void:
	for individual in habitat["individuals"]:
		individual["stage"] = "adult"
		individual["growth"] = growth_target

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	_reports_checks()
	_recap_checks()
	_snapshot_checks()
	await _ui_checks()
	for label in failures: printerr(label)
	print("PHASE07E TEST %s: %d checks" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)

## Pen and pond with fed adults and running cycles on day 0.
func _prepared() -> World:
	var world := World.new()
	world.grant_scaffold({"raw_wood":6,"raw_stone":12})
	world.build_facility(Vector2i(7,1),"pen")
	world.build_facility(Vector2i(0,14),"fish_pond")
	# Journal-tracked cash only: sell scaffolded ore instead of mutating stones so
	# the day-45 cash reconciliation holds.
	world.grant_scaffold({"iron_ore":10})
	world.sell("iron_ore",5)
	world.husbandry.purchase(1,2)
	world.husbandry.purchase(2,2)
	world.grant_scaffold({"fodder_grass":8,"clean_water":8,"algae_feed":8,"iron_ore":4,"grain":4})
	adult(world.husbandry.habitat_of(1),600)
	adult(world.husbandry.habitat_of(2),400)
	world.husbandry.maintain(1)
	world.husbandry.maintain(2)
	return world

func _reports_checks() -> void:
	var world := _prepared()
	world.end_day()
	var reports = world.reports
	var day0: Array = reports.day_entries(0)
	var purchase_count := 0
	var basic_count := 0
	for entry in day0:
		if String(entry["category"]) == "purchase": purchase_count += 1
		if String(entry["category"]) == "maintenance" and String(entry["kind"]) == "基础服务": basic_count += 1
	check(purchase_count == 2 and basic_count == 2,"purchase and basic-service events record per facility")
	var merged := 0
	for entry in day0:
		if String(entry["category"]) == "maintenance" and String(entry["kind"]) == "基础服务" and int(entry["count"]) == 2:
			merged += 1
	check(merged == 2,"same-day same-facility basic services aggregate into one entry")
	world.grant_scaffold({"fodder_grass":4,"clean_water":4,"algae_feed":4})
	world.husbandry.maintain(1)
	world.husbandry.maintain(2)
	world.end_day()
	var ready_events := 0
	for entry in reports.day_entries(1):
		if String(entry["category"]) == "growth" and String(entry["kind"]) == "就绪待收": ready_events += 1
	check(ready_events == 1,"carp readiness lands as one growth event, sheep progress stays silent")
	world.grant_scaffold({"fodder_grass":4,"clean_water":4,"algae_feed":4})
	world.husbandry.maintain(1)
	world.husbandry.maintain(2)
	world.end_day()
	var claims: Array = world.husbandry.quote_claim(2)["ids"]
	world.husbandry.claim(2,claims)
	var pending: Array = reports.state["pending"]["entries"]
	var claim_found := false
	for entry in pending:
		if String(entry["category"]) == "claim" and int(entry["count"]) == 2:
			claim_found = String(entry["note"]).contains("移除2只")
	check(claim_found,"claim events keep removed counts and notes")
	world.workforce.hire("羊倌")
	world.husbandry.assign_caretaker(1,1)
	world.grant_scaffold({"fodder_grass":4,"clean_water":4,"iron_ore":2})
	world.end_day()
	var labour_fee := 0
	for entry in reports.day_entries(3):
		if String(entry["category"]) == "labour": labour_fee += int(entry["count"])
	check(labour_fee >= 1,"patrol steps record as labour events")
	var term0: Dictionary = reports.state["terms"][0]
	check(not term0["purchase"].is_empty() and int(term0["purchase"].get("count",0)) == 4,"term buckets accumulate counts across days")
	check(reports.state["terms"][1]["purchase"].is_empty(),"untouched terms stay empty")

func _recap_checks() -> void:
	var world := _prepared()
	# Walk to day 45 with daily feeding; scale rations by scaffold per day.
	for day in range(44):
		world.grant_scaffold({"fodder_grass":2,"clean_water":2,"algae_feed":2})
		world.husbandry.maintain(1)
		world.husbandry.maintain(2)
		world.end_day()
	check(world.clock.total_days == 44,"timeline reaches day 44 before the freeze")
	world.grant_scaffold({"fodder_grass":2,"clean_water":2,"algae_feed":2})
	world.husbandry.maintain(1)
	world.husbandry.maintain(2)
	world.end_day()
	check(world.clock.total_days == 45 and world.reports.recap_active(),"day 45 settle freezes the recap")
	var frozen: Dictionary = world.reports.state["recap"]
	check(int(frozen["cash"]) == world.primeval_stones and frozen["animals"].has("steel_sheep"),"recap snapshots cash and animals")
	world.husbandry.purchase(1,1)
	check(world.reports.state["recap"] == frozen,"post-freeze purchases never rewrite the recap")
	var reloaded := World.new()
	check(reloaded.apply_snapshot(world.to_snapshot())["ok"] and reloaded.reports.state["recap"] == frozen,"frozen recap round trips unchanged")

func _snapshot_checks() -> void:
	var world := _prepared()
	world.toggle_watch("fodder_grass")
	world.toggle_watch("clean_water")
	world.toggle_watch("clean_water")
	var good: Dictionary = world.to_snapshot()
	check(good["preferences"]["watched"] == ["fodder_grass"],"watch toggles keep order and dropping the last item")
	check(Snapshot.normalize(good)["ok"],"preferences and reports validate")
	var old: Dictionary = good.duplicate(true)
	old["schema"] = 10
	check(not Snapshot.normalize(old)["ok"],"schema10 rejected without migration")
	for case in [
		["duplicate watch", func(s): s["preferences"]["watched"] = ["humus","humus"]],
		["unknown watch", func(s): s["preferences"]["watched"] = ["wizard_dust"]],
		["bad category", func(s): s["reports"]["pending"]["entries"] = [{"category":"magic","facility_uid":1,"kind":"x","count":1,"items":{},"note":""}]],
		["negative count", func(s): s["reports"]["pending"]["entries"] = [{"category":"claim","facility_uid":1,"kind":"x","count":-1,"items":{},"note":""}]],
		["dense history", func(s): s["reports"]["history"] = [{"day":1,"entries":[{"category":"cull","facility_uid":1,"kind":"清退","count":1,"items":{},"note":""}]},{"day":2,"entries":[{"category":"cull","facility_uid":1,"kind":"清退","count":1,"items":{},"note":""}]}]],
		["future recap", func(s): s["reports"]["recap"] = {"terms":[{},{},{}],"labour":0,"cash":0,"inventory":{},"animals":{},"ready":0,"running":0}],
	]:
		var damaged: Dictionary = good.duplicate(true)
		case[1].call(damaged)
		check(not Snapshot.normalize(damaged)["ok"],"damaged snapshot rejects: "+String(case[0]))


func _ui_checks() -> void:
	var ui = Scene.instantiate()
	var directory := "user://phase07e_%d" % Time.get_ticks_usec()
	ui.store = Store.new(directory)
	root.add_child(ui)
	await process_frame
	ui._new(1,false)
	# Empty overview state.
	ui._show_husbandry_overview()
	check(has_text(ui.sidebar,"建造圈舍或水场后"),"empty overview explains itself and links the catalogue")
	# Watch strip empty state.
	check(has_text(ui.watch_panel,"关注资源：在资源一览中勾选材料"),"empty watch strip keeps its purpose note")
	ui.world.grant_scaffold({"raw_wood":4,"raw_stone":8,"fodder_grass":4,"clean_water":4})
	ui.world.build_facility(Vector2i(7,1),"pen")
	ui.world.husbandry.purchase(1,2)
	ui._show_husbandry_overview()
	check(has_text(ui.sidebar,"圈舍#1") and has_text(ui.sidebar,"幼体2 / 成体0"),"overview shows one row per facility with mixed stages")
	check(has_text(ui.sidebar,"负责人：无人"),"overview distinguishes the unassigned caretaker")
	var ap: int = ui.world.clock.ap
	ui._locate_facility(1)
	check(ui.selected == Vector2i(7,1) and ui.world.clock.ap == ap,"locate opens the detail without spending AP")
	ui._show_husbandry_overview()
	ui.world.inventory.remove("fodder_grass",4)
	ui.world.inventory.remove("clean_water",4)
	ui.overview_filter = "需处理"
	ui._show_husbandry_overview()
	check(has_text(ui.sidebar,"需处理：缺少基础食物"),"attention filter lists the blocked reason")
	ui.overview_filter = "全部"
	# Watch toggles and the strip.
	ui.world.toggle_watch("fodder_grass")
	ui.world.toggle_watch("clean_water")
	ui._refresh_watch()
	check(has_text(ui.watch_panel,"牧草") and has_text(ui.watch_panel,"清水"),"watch strip lists checked items")
	for item in ["grain","straw","humus","iron_ore","algae_feed"]:
		ui.world.toggle_watch(item)
	ui._refresh_watch()
	check(has_text(ui.watch_panel,"更多("),"overflow collapses into a more entry")
	ui.world.toggle_watch("grain")
	ui.world.toggle_watch("straw")
	ui.world.toggle_watch("humus")
	ui.world.toggle_watch("iron_ore")
	ui.world.toggle_watch("algae_feed")
	ui.world.toggle_watch("clean_water")
	ui.world.toggle_watch("fodder_grass")
	ui._refresh_watch()
	check(has_text(ui.watch_panel,"关注资源：在资源一览中勾选材料"),"removing the last item restores the purpose note")
	# Resource page exposes the checkbox and watched-only view.
	ui._show_resources()
	check(has_text(ui.sidebar,"勾选“关注”后"),"resource page explains the watch column")
	ui.world.toggle_watch("fodder_grass")
	ui.resource_watched_only = true
	ui._show_resources()
	check(has_text(ui.sidebar,"仅关注"),"resource filter offers the watched-only view")
	# Report page shows husbandry entries after a settle with facts.
	ui._close_page()
	ui.world.grant_scaffold({"clean_water":2})
	ui.world.husbandry.maintain(1)
	ui.world.end_day()
	ui._show_report()
	check(has_text(ui.sidebar,"养殖条目"),"daily report lists husbandry entries")
	ui._show_history()
	check(has_text(ui.sidebar,"[养殖]"),"history cards include husbandry lines")
	ui._show_help()
	check(has_text(ui.sidebar,"养殖与负责人"),"manual covers husbandry and caretakers")
	ui._close_page()
	for slot in [1,2,3]:
		if ui.store.occupied(slot): ui.store.delete_slot(slot,true)
	DirAccess.remove_absolute(directory)
	ui.queue_free()
	await process_frame
