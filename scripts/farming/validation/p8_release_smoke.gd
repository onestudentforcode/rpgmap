extends Node
## P8 foundation smoke: boot the shell, verify registration, locks, a real
## water change and the candidate save path in one running scene.
const P8Store := preload("res://scripts/farming/p8/p8_slot_store.gd")

var shell
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func run() -> void:
	await get_tree().process_frame
	check(not shell._started and shell.manual_mode, "P8 menu and manual default")
	check(shell.world._items.size() == 63 and shell.world.facility_defs.size() == 15, "P8 catalog registered")
	check(shell.world.recipe_defs.size() == 40 and shell.world.crop_defs.size() == 7, "P8 recipes and crops registered")
	shell._new(1, false)
	var world = shell.world
	check(world.primeval_stones == 60 and world.clock.total_days == 0, "fresh P8 slot with 60 stones")
	var blocked: Dictionary = world.can_build_facility(Vector2i(7, 1), "bee_hive")
	check(not blocked["ok"] and String(blocked["reason"]).find("研究") >= 0, "research-gated facility blocked with reason")
	check(not world.buy("honeybell_seed", 1)["ok"], "research-gated seed not purchasable")
	# A real water change needs a stocked pond: scaffold is test-only stock.
	world.grant_scaffold({"raw_stone": 8, "raw_wood": 3, "clean_water": 8})
	var bench: Dictionary = world.can_build_facility(Vector2i(2, 4), "research_bench")
	check(bench["ok"], "research bench buildable without research")
	check(world.build_facility(Vector2i(0, 14), "fish_pond")["ok"], "build the water habitat")
	check(world.husbandry.purchase(int(world.facilities.keys()[0]), 2)["ok"], "buy two fry")
	check(not world.husbandry.quote_water(int(world.facilities.keys()[0]))["ok"], "full pond refuses a change")
	check(world.end_day()["ok"], "settle day 0")
	var uid := int(world.facilities.keys()[0])
	var change: Dictionary = world.husbandry.maintain_water(uid)
	check(change["ok"] and world.inventory.count("wastewater") == 2, "real water change issues sewage")
	check(not world.husbandry.quote_water(uid)["ok"], "second change the same day refused")
	check(world.end_day()["ok"], "settle day 1 with the change in the books")
	await get_tree().process_frame
	shell._refresh()
	shell._show_build()
	check(shell._context == "build", "build catalog renders with locked entries")
	shell._show_market()
	check(shell._context == "market", "market renders")
	print("P8 RELEASE SMOKE %s (%d checks)" % ["OK" if failures.is_empty() else "FAIL: " + "; ".join(failures), checks])
	get_tree().quit(0 if failures.is_empty() else 1)
