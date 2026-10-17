extends SceneTree
const Shell := preload("res://scripts/farming/p8/p8_scene.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var shell := Shell.new()
	var path := "res://.art-work/p86-production-tests/%d" % Time.get_ticks_usec()
	shell.store = Store.new(path)
	shell.settings = shell.settings.get_script().new(path+".cfg",0.1)
	root.add_child(shell)
	await process_frame
	shell._new(1,false)
	check(shell.visual_trial_profile == "integrated","P8.6 active in default game")
	check(shell.trial_environment.diagnostics.is_empty(),"production resources decode")
	var before: Dictionary = shell.world.to_snapshot().duplicate(true)
	for ident in shell.world.crop_defs:
		for stage in range(4):
			var contact: Dictionary = shell._trial_grounding.crop_shadow(ident,"stage_%d"%stage,Vector2.ZERO)
			check(not contact.is_empty() and contact["color"].a>0,"contact %s/%d"%[ident,stage])
	for ident in shell.world.facility_defs:
		check(not shell._trial_grounding.facility_shadow(ident,Vector2.ZERO).is_empty(),"facility contact "+ident)
		var picture: Texture2D = shell.facility_thumbnail(ident)
		check(picture is AtlasTexture and picture.get_size().x>0,"facility thumbnail "+ident)
		check(picture == shell.facility_thumbnail(ident),"thumbnail cached "+ident)
	for ident in shell.world.source_defs:
		var rect := Rect2(Vector2(-128,64),Vector2(64,64))
		var visual: Dictionary = shell.trial_environment.source_visual(ident,rect)
		check(not visual.is_empty() and visual["root"]==rect.get_center(),"resource root "+ident)
		check(not shell._trial_grounding.source_shadow(ident,rect.get_center()).is_empty(),"resource contact "+ident)
	var mask: Image = shell.trial_environment._mask_texture.get_image()
	check(mask.get_size()==shell.world.grid.bounds().size,"shore mask matches complete grid")
	check(mask.get_pixel(4,14).r>0.9 and mask.get_pixel(4,13).r<0.1,"water/land cells distinguished")
	check(mask.get_pixel(0,14).g<0.1,"unbought negative water not decorated")
	shell.world.primeval_stones=1000
	check(shell.world.land.buy("west_water")["ok"],"real negative water purchase")
	mask=shell.trial_environment._mask_texture.get_image()
	check(mask.get_pixel(0,14).g>0.9,"shore mask refreshes on parcel purchase")
	var bought: Dictionary = shell.world.to_snapshot().duplicate(true)
	for i in range(3):
		check(shell.configure_visual_trial("baseline")["ok"],"restore baseline")
		check(shell.configure_visual_trial("integrated")["ok"],"restore production")
	check(shell.world.to_snapshot()==bought,"visual switches never mutate purchased world")
	check(shell.world.apply_snapshot(before)["ok"],"schema17 original snapshot remains readable")
	check(shell.world.to_snapshot()==before,"exact snapshot restore")
	for failure in failures: printerr(failure)
	print("P86 PRODUCTION %s: %d checks"%["OK" if failures.is_empty() else "FAILED",checks])
	quit(0 if failures.is_empty() else 1)
