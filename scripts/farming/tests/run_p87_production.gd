extends SceneTree
const Scene := preload("res://scenes/farming/farm_p87.tscn")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _run() -> void:
	var shell = Scene.instantiate()
	var path := "res://.art-work/p87-production-tests/%d" % Time.get_ticks_usec()
	shell.store = Store.new(path)
	shell.settings = shell.settings.get_script().new(path+".cfg",0.1)
	root.add_child(shell)
	await process_frame
	shell._new(1,false)
	shell.set_process(false)
	check(shell.projection.enabled and not shell.show_rulers,"production projection with no development rulers")
	check(shell.store._directory == path,"production test uses isolated storage")
	var original: Dictionary = shell.world.to_snapshot().duplicate(true)
	var uid := 1
	for ident in shell.world.crop_defs:
		var definition: Dictionary = shell.world.crop_defs[ident]
		for stage in range(4):
			var crop := {"uid":uid,"crop_id":ident,"origin":[2,2],"state":"mature" if stage==3 else "growing","progress":ceili(float(int(definition["days"])*100)*stage/3.0),"harvest_count":0}
			shell.world.crops[uid] = crop
			uid += 1
			var visual: Dictionary = shell.plant_visuals.visual(crop,definition,shell.world.flowers.settings["oilseed_window"])
			var ground: Rect2 = shell.projection.footprint(crop["origin"],definition["footprint"])
			var body: Rect2 = shell.projection.body_rect(visual,ground.get_center())
			check(not visual.is_empty() and body.size==visual["rect"].size,"whole body unchanged %s/%d"%[ident,stage])
			check(not shell.contact_visual({"kind":"crop","ident":ident,"root":ground.get_center(),"visual":visual}).is_empty(),"stage contact %s/%d"%[ident,stage])
	for ident in shell.world.facility_defs:
		var definition: Dictionary = shell.world.facility_defs[ident]
		var ground: Rect2 = shell.projection.footprint([6,5],definition["footprint"])
		var visual: Dictionary = shell.facility_visuals.visual(ident,ground)
		var body: Rect2 = shell.projection.body_rect(visual,ground.get_center())
		check(body.size==visual["rect"].size,"facility canvas retained "+ident)
		check(shell.facility_thumbnail(ident) is AtlasTexture,"facility UI thumbnail retained "+ident)
	for entity in shell.collect_entities():
		if entity["kind"] != "source": continue
		var body: Rect2 = shell.projection.body_rect(entity["visual"],entity["root"],entity["body_scale"])
		check(body.size.is_equal_approx(Vector2(108.8,108.8)),"resource calibrated to same world ruler "+entity["ident"])
	var all_entities: Array = shell.collect_entities()
	for index in range(1,all_entities.size()): check(all_entities[index-1]["root"].y<=all_entities[index]["root"].y,"ground depth order independent of sprite height")
	for i in range(2):
		check(shell.configure_visual_trial("baseline")["ok"],"restore legacy visual material")
		check(shell.configure_visual_trial("integrated")["ok"],"reapply production scenery")
		check(is_equal_approx(shell.trial_environment._shore.scale.y,shell.projection.depth),"shore projection survives environment lifecycle")
		check(shell.terrain.layers["grass"].material.get_shader_parameter("ground_view_scale").is_equal_approx(Vector2(1,shell.projection.depth)),"material stays in logical coordinates")
	shell.world.crops.clear()
	check(shell.world.apply_snapshot(original)["ok"],"schema17 original snapshot restored")
	check(shell.world.to_snapshot()==original,"rendering never modifies restored gameplay")
	shell.world.primeval_stones = 1000
	check(shell.world.land.buy("west_water")["ok"],"negative-x water bought normally")
	check(shell.trial_environment._mask_texture.get_image().get_pixel(0,14).g>0.9,"projected shoreline still refreshes ownership mask")
	check(shell.view_bounds().position.x < 0,"camera bounds include negative parcels")
	# Actual missing texture cache follows the visible fallback without corrupting state.
	var path_key: String = shell.plant_visuals.plants["golden_wheat"]["stages"]["stage_0"]
	var texture: Texture2D = shell.plant_visuals.textures[path_key]
	shell.plant_visuals.textures.erase(path_key)
	shell.world.crops[1] = {"uid":1,"crop_id":"golden_wheat","origin":[2,2],"state":"growing","progress":0,"harvest_count":0}
	var item: Dictionary = shell.collect_entities().filter(func(e: Dictionary): return e["kind"]=="crop")[0]
	check(item["visual"].is_empty(),"missing plant keeps ground fallback")
	shell.plant_visuals.textures[path_key] = texture
	check(not shell.collect_entities().filter(func(e: Dictionary): return e["kind"]=="crop")[0]["visual"].is_empty(),"texture recovery after fallback")
	for failure in failures: printerr(failure)
	print("P87 PRODUCTION %s: %d checks"%["OK" if failures.is_empty() else "FAILED",checks])
	quit(0 if failures.is_empty() else 1)
