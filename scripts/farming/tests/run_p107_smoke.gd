extends "res://scripts/farming/tests/run_p106_smoke.gd"
## One integration smoke, reusing the land/water/services topology. It starts
## from an explicitly supplied stage3 rule fixture, not an economic endpoint.
var trades := 0

func _initialize() -> void:
	audit_root = "res://.art-work/p107-smoke"
	super._initialize()

func _world() -> World:
	var w: World = super._world()
	w.grant_scaffold({"resin": 100})
	check(w.progress.exchange("resin_for_sludge", 3)["ok"], "initial real exchange")
	trades = w.progress.state["exchanges"].size()
	return w

func _invariants(world: World, day: int) -> void:
	super._invariants(world, day)
	check(world.progress.state["exchanges"].size() == trades, "reloading/settling does not repeat trades day " + str(day))
	check(world.progress.stage() == 3, "completed milestones survive local production/room changes day " + str(day))
	if day == 35:
		var before: Dictionary = world.to_snapshot()
		check(not world.progress.complete_event("integrated_estate")["ok"] and world.to_snapshot() == before, "old resource event cannot run again after long wait")
		check(world.progress.exchange("resin_for_panels", 2)["ok"], "late real exchange with water and animal systems active")
		trades += 1
		coverage_check("late_economic_exchange")
	if day == 69:
		var f := FileAccess.open(audit_root.path_join("final.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(world.to_snapshot(), "\t"))
		f.close()
		print("P107 INTEGRATION WINDOW OK")
