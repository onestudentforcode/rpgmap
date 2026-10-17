extends RefCounted
## Test-only stage fixture for old visual/flower tests. These tests explicitly
## skip growth; record ZERO room-qualified work, never use this in business runs
## or as evidence for production/reward behavior. The strict save codec stays on.
const Rooms := preload("res://scripts/farming/p8/p102_rooms.gd")
static func progress(world, uid: int, points: int) -> void:
	var row: Dictionary=world.crops[uid]
	var definition: Dictionary=world.crop_defs[row["crop_id"]]
	var target:=int(definition["cycle_days"] if row["harvest_count"]>0 else definition["days"])*100
	row["progress"]=points
	row["state"]="mature" if points==target else ("regrowing" if row["harvest_count"]>0 else "growing")
	var before: Dictionary=world.rooms.state["plants"].get(str(uid),{})
	var data:=Rooms.round_state(target,int(row["harvest_count"]))
	data["growth"]=points;data["frozen"]=points==target
	if int(row["harvest_count"])>0:
		for field in ["seed_checked","seed_award","seed_claimed","seed_total","seed_eligible"]: data[field]=before[field]
	elif data["frozen"]:
		data["seed_checked"]=true;data["seed_total"]=target
	world.rooms.state["plants"][str(uid)]=data
