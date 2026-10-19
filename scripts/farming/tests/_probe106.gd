extends SceneTree
const World := preload("res://scripts/farming/p8/p8_world.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
func _initialize() -> void:
	var w := World.new(Store.new("res://.art-work/p106-tests/probe-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]))
	w.start_new(1)
	w.grant_scaffold({"twig": 200, "wood_plank": 60, "raw_stone": 120, "raw_wood": 60, "clean_water": 300,
		"algae_feed": 400, "grain": 100, "stone_powder": 200, "water_feed": 100})
	w.primeval_stones += 3000
	w._cash("sales_revenue", 3000)
	w.research.state["completed"] = w.research.project_defs().keys()
	w.water.build_fence([Vector2i(2,14), Vector2i(3,14), Vector2i(4,14), Vector2i(2,15), Vector2i(3,15), Vector2i(4,15), Vector2i(2,16), Vector2i(3,16), Vector2i(4,16), Vector2i(2,17), Vector2i(3,17), Vector2i(4,17)], 0)
	w.end_day()
	w.build_facility(Vector2i(2,14), "pen"); w.build_facility(Vector2i(2,16), "feed_trough")
	w.build_facility(Vector2i(3,16), "small_bed"); w.build_facility(Vector2i(4,16), "medium_bed")
	var cells := []
	for y in range(14,18):
		for x in range(2,5):
			cells.append("%d,%d" % [x,y])
	var z: Dictionary = w.ranch.create_zone("water_nursery", cells, "pool")
	w.end_day()
	w.water.build_fence([Vector2i(6,14), Vector2i(7,14), Vector2i(8,14), Vector2i(9,14), Vector2i(6,15), Vector2i(7,15), Vector2i(8,15), Vector2i(9,15), Vector2i(6,16), Vector2i(7,16), Vector2i(8,16), Vector2i(9,16), Vector2i(6,17), Vector2i(7,17), Vector2i(8,17), Vector2i(9,17)], 0)
	w.build_facility(Vector2i(6,14), "pen"); w.build_facility(Vector2i(8,14), "feed_trough")
	w.build_facility(Vector2i(9,14), "small_bed"); w.build_facility(Vector2i(9,15), "medium_bed")
	w.build_facility(Vector2i(6,16), "gel_station")
	var cells2 := []
	for y in range(14,18):
		for x in range(6,10):
			cells2.append("%d,%d" % [x,y])
	var z2: Dictionary = w.ranch.create_zone("water_production", cells2, "pool2")
	print("zones: ", z["ok"], " ", z2["ok"])
	var p: Dictionary = w.ranch.purchase(int(z["zone_uid"]), "gel_jellyfish", 1)
	print("buy: ", p["ok"])
	for i in range(10):
		w.end_day()
		if not w.daily_save_error.is_empty():
			print("SAVE ERROR day ", i, ": ", w.daily_save_error)
			break
		var a: Dictionary = w.ranch.state["animals"][0]
		print("day ", i, " growth ", int(a["growth"]), " miss ", int(a["miss_streak"]), " bad ", int(a["bad_water_streak"]))
	quit()
