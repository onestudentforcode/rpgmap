extends SceneTree
const World := preload("res://scripts/farming/v2/v2_world.gd")
const Store := preload("res://scripts/farming/v2/v2_slot_store.gd")
const Playthrough := preload("res://scripts/farming/validation/v2_playthrough.gd")

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var outcomes := []
	var success := true
	for route in ["A","B"]:
		var directory := "user://v2_playtest_%s_%d" % [route,Time.get_ticks_usec()]
		var store := Store.new(directory)
		var world := World.new(store)
		if not world.start_new(1)["ok"]: quit(1); return
		var result: Dictionary = Playthrough.new().run(world,route,"res://.art-work/phase07f-route"+route)
		outcomes.append(result)
		print("P7.f ROUTE ",route," ",result["status"]," cash=",result["final"]["cash"]," wages=",result["final"]["labour"]," delegation=",result["milestones"])
		for failure in result["failures"]: printerr(route+": "+failure)
		success = success and result["status"] == "passed"
		for slot in [1,2,3]:
			if store.occupied(slot): store.delete_slot(slot,true)
		DirAccess.remove_absolute(directory)
	var output := "res://.art-work/phase07f-playtest.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ledger="): output = arg.trim_prefix("--ledger=")
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null: printerr("cannot write ledger"); quit(1); return
	file.store_string(JSON.stringify({"status":"passed" if success else "failed","no_injection":true,"routes":outcomes},"\t"))
	print("V2 TWO45 PLAYTEST ","OK" if success else "FAIL")
	quit(0 if success else 1)
