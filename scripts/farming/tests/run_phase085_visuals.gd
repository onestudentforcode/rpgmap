extends SceneTree
const Visuals := preload("res://scripts/farming/p8/p8_plant_visuals.gd")
const Shell := preload("res://scripts/farming/p8/p8_scene.gd")
const World := preload("res://scripts/farming/p8/p8_world.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	var visuals := Visuals.new()
	check(visuals.textures.size() == 29, "29 textures cached")
	check(visuals.diagnostics.is_empty(), "no missing textures")
	var definitions: Dictionary = {}
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/farming/p8/production.json"))
	for definition in config["crops"]: definitions[definition["id"]] = definition
	var wheat := {"crop_id":"golden_wheat", "origin":[-2,3], "state":"growing", "progress":0}
	var first := visuals.visual(wheat, definitions["golden_wheat"], [300,500])
	check(first["root"] == Vector2(-96,256), "negative x root")
	for progress in [0,134,267]:
		wheat["progress"] = progress
		var image := visuals.visual(wheat, definitions["golden_wheat"], [300,500])
		check(image["rect"] == first["rect"], "fixed canvas across wheat growth")
	wheat["state"] = "mature"
	check(visuals.visual(wheat, definitions["golden_wheat"], [300,500])["key"] == "stage_3", "mature wheat")
	var mature_path := String(visuals.plants["golden_wheat"]["stages"]["stage_3"])
	var mature_texture = visuals.textures[mature_path]
	visuals.textures.erase(mature_path)
	check(visuals.visual(wheat, definitions["golden_wheat"], [300,500]).is_empty(), "missing image uses fallback")
	visuals.visual(wheat, definitions["golden_wheat"], [300,500])
	check(visuals.diagnostics.size() == 1, "missing image warning deduplicated")
	visuals.textures[mature_path] = mature_texture
	var tree := {"crop_id":"resin_tree", "origin":[1,2], "state":"regrowing", "progress":0}
	var tree_visual := visuals.visual(tree, definitions["resin_tree"], [300,500])
	check(tree_visual["key"] == "stage_3", "harvested tree remains mature")
	check(is_equal_approx(tree_visual["rect"].size.y/tree_visual["rect"].size.x,1.5), "tree aspect")
	var oil := {"crop_id":"oilseed_flower", "origin":[0,0], "state":"growing", "progress":299}
	for progress in [299,300,499,500]:
		oil["progress"] = progress
		check((visuals.state_key(oil,definitions["oilseed_flower"],[300,500]) == "flowering") == (progress >= 300 and progress < 500), "flower boundary %d" % progress)
	oil["state"] = "mature"
	check(visuals.state_key(oil,definitions["oilseed_flower"],[300,500]) == "stage_3", "mature oilseed")
	var shell := Shell.new()
	check(shell.plant_visuals.enabled_ids.size() == 7, "all seven plants enabled")
	check(shell.facility_visuals.textures.size() == 15,"all facility bodies cached")
	for ident in shell.facility_visuals.facilities:
		var data: Dictionary = shell.facility_visuals.facilities[ident]
		var shape: Array = data["footprint"]
		var rect := Rect2(Vector2(-128,64),Vector2(shape[0],shape[1])*64.0)
		var placed: Dictionary = shell.facility_visuals.visual(ident,rect)
		check(not placed.is_empty() and placed["root"] == rect.get_center(),"facility center %s" % ident)
		check(is_equal_approx(placed["rect"].size.x,placed["rect"].size.y),"facility aspect %s" % ident)
		check(shell.facility_visuals.visual(ident,rect) == placed,"preview/placed geometry %s" % ident)
	shell.free()
	_lifecycle(visuals)
	for failure in failures: printerr(failure)
	print("PHASE085 VISUALS OK: %d checks" % checks) if failures.is_empty() else print("PHASE085 VISUALS FAILED")
	quit(0 if failures.is_empty() else 1)

func _lifecycle(visuals) -> void:
	var world := World.new(Store.new("res://.art-work/p85-life/slots-%d" % Time.get_ticks_usec()))
	check(world.start_new(1)["ok"], "new schema17 world")
	# Fixture unlocks/materials; operations below use the real model.
	for project in world.research.project_defs(): world.research.state["completed"].append(project)
	var inputs := {"clean_water":100,"raw_wood":100,"humus":100}
	for definition in world.crop_defs.values():
		inputs[definition["seed"]] = 10
		for ingredient in definition["inputs"]: inputs[ingredient] = 100
	world.grant_scaffold(inputs)
	for ident in world.crop_defs:
		var definition: Dictionary = world.crop_defs[ident]
		var shape: Array = definition["footprint"]
		var cell := Vector2i(-999,-999)
		for y in range(0,14):
			for x in range(0,20):
				var candidate := Vector2i(x,y)
				var valid := true
				for dy in range(int(shape[1])):
					for dx in range(int(shape[0])):
						if not world.grid.can_till(candidate+Vector2i(dx,dy))["ok"]: valid = false
				if valid:
					cell = candidate
					break
			if cell.x != -999: break
		check(cell.x != -999,"plantable footprint %s" % ident)
		if cell.x == -999: continue
		world.clock.ap = 24
		for dy in range(int(shape[1])):
			for dx in range(int(shape[0])): world.till(cell+Vector2i(dx,dy))
		var planted: Dictionary = world.plant(cell,ident)
		check(planted["ok"],"real plant %s" % ident)
		if not planted["ok"]: continue
		var uid := int(planted["uid"])
		var flower_window: Array = world.flowers.settings["oilseed_window"]
		var initial: Dictionary = visuals.visual(world.crops[uid],definition,flower_window)
		check(not initial.is_empty() and initial["key"] == "stage_0", "new seed visual %s" % ident)
		for stage in range(3):
			world.crops[uid]["progress"] = ceili(float(int(definition["days"])*100)*stage/3.0)
			var result: Dictionary = visuals.visual(world.crops[uid],definition,flower_window)
			check(not result.is_empty() and result["rect"] == initial["rect"],"canvas %s/%d" % [ident,stage])
		if ident == "oilseed_flower":
			for progress in [299,300,499,500]:
				world.crops[uid]["progress"] = progress
				world.environment[world.grid.index_of(cell)][0] = 0
				check(not world.flowers.eligible(uid),"dry flower production blocked")
				check((visuals.visual(world.crops[uid],definition,flower_window)["key"] == "flowering") == (progress >= 300 and progress < 500),"dry flower morphology %d" % progress)
		world.crops[uid]["progress"] = int(definition["days"])*100
		world.crops[uid]["state"] = "mature"
		var before := world.to_snapshot()
		for i in range(10): visuals.visual(world.crops[uid],definition,flower_window)
		check(world.to_snapshot() == before,"visual reads do not mutate model %s" % ident)
		check(visuals.visual(world.crops[uid],definition,flower_window)["key"] == "stage_3","mature %s" % ident)
		var restored := World.new(Store.new("res://.art-work/p85-life/restored-%d" % Time.get_ticks_usec()))
		check(restored.apply_snapshot(before)["ok"],"schema17 restore %s" % ident)
		check(visuals.visual(restored.crops[uid],restored.crop_defs[ident],restored.flowers.settings["oilseed_window"])["key"] == "stage_3","restored visual %s" % ident)
		check(world._store.commit(before)["ok"],"real save %s" % ident)
		var reopened := World.new(world._store)
		check(reopened.open_game(1)["ok"],"real reopen %s" % ident)
		check(visuals.visual(reopened.crops[uid],reopened.crop_defs[ident],reopened.flowers.settings["oilseed_window"])["key"] == "stage_3","disk-loaded visual %s" % ident)
		world.clock.ap = 24
		var harvest: Dictionary = world.harvest(cell)
		check(harvest["ok"],"real harvest %s" % ident)
		if definition["mode"] == "tap_or_fell":
			check(world.crops.has(uid) and visuals.visual(world.crops[uid],definition,flower_window)["key"] == "stage_3","perennial regrow body %s" % ident)
			world.crops[uid]["state"] = "mature"
			check(world.harvest(cell,"fell")["ok"] and not world.crops.has(uid),"real fell removes %s" % ident)
		else:
			check(not world.crops.has(uid),"real harvest removes %s" % ident)
		world.clock.ap = 24
		var replanted: Dictionary = world.plant(cell,ident)
		check(replanted["ok"],"real replant %s" % ident)
		if replanted["ok"]:
			check(visuals.visual(world.crops[int(replanted["uid"])],definition,flower_window)["key"] == "stage_0","replant new visual %s" % ident)
			check(world.end_day()["ok"],"real day settlement %s" % ident)
			check(not visuals.visual(world.crops[int(replanted["uid"])],definition,flower_window).is_empty(),"next-day visual %s" % ident)
			world.clear_crop(cell)
