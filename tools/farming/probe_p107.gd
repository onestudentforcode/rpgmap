extends SceneTree
## One-shot research probe. In-memory fixtures only; no save slots or game data writes.
const Data := preload("res://scripts/farming/p8/p8_data.gd")
const World := preload("res://scripts/farming/p8/p8_world.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var out := {"quotes": [], "live_recipe_without_animals": {}}
	var data := Data.load_data()
	var items := Data.resources(data)
	for iid in ["mineral_scale", "silk", "spirit_liquid"]:
		for rank in [1, 5]:
			var quote := Data.supply_quote(String(items[iid]["element"]), rank, iid)
			out["quotes"].append(quote)
	var w := World.new()
	w.grant_scaffold({"raw_wood": 20, "wood_plank": 20, "raw_stone": 20, "twig": 20})
	w.research.state["completed"] = ["flower_cultivation", "farm_preparation"]
	for y in range(1, 3):
		for x in range(4, 6):
			w.rooms.set_floor(Vector2i(x, y), "ordinary")
	var built: Dictionary = w.build_facility(Vector2i(4, 1), "carbonization_nest")
	if built.get("ok"):
		var uid := int(built.get("uid", built.get("facility_uid", 0)))
		if uid == 0:
			for candidate in w.facilities:
				if String(w.facilities[candidate]["facility_id"]) == "carbonization_nest":
					uid = int(candidate)
		out["live_recipe_without_animals"] = {
			"animals": w.ranch.state["animals"].size(),
			"built": built,
			"start_result": w.start_batch(uid, "bug_char_twigs"),
			"batch": w.facilities[uid]["batch"].duplicate(true),
		}
		out["live_recipe_without_animals"]["end_day"] = w.end_day()
		out["live_recipe_without_animals"]["claim"] = w.claim_batch(uid, 1)
		out["live_recipe_without_animals"]["stock"] = {
			"charcoal": w.inventory.count("charcoal"), "humus": w.inventory.count("humus")}
	else:
		out["live_recipe_without_animals"] = {"built": built}
	print("P107_PROBE_JSON=" + JSON.stringify(out))
	quit()
