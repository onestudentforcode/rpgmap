extends SceneTree
const World := preload("res://scripts/farming/p8/p8_world.gd")
const Codec := preload("res://scripts/farming/p8/p8_snapshot.gd")
var checks := 0
var failures := []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr(label)
func _initialize() -> void: call_deferred("run")
func cells(rect: Rect2i) -> Array:
	var out := []
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x): out.append("%d,%d" % [x,y])
	return out
func run() -> void:
	var w := World.new()
	w.grant_scaffold({"raw_wood":200,"fast_fir_seed":10})
	for y in range(1,4):
		for x in range(4,8): check(w.till(Vector2i(x,y))["ok"],"till")
	check(w.rooms.regions(0).is_empty(),"unassigned farmland has no automatic room")
	var a: Dictionary = w.rooms.create_field(cells(Rect2i(4,1,2,2)),"A")
	var b: Dictionary = w.rooms.create_field(cells(Rect2i(6,1,2,2)),"B")
	check(a["ok"] and b["ok"] and a["uid"] != b["uid"],"touching fields have independent identity")
	check(w.rooms.regions(0).size()==2,"bridge farmland never merges identities")
	check(w.rooms.field_at(Vector2i(5,3)).is_empty(),"extra farmland stays unassigned")
	check(not w.rooms.edit_field(a["uid"],["4,1","5,1","6,1"])["ok"],"cannot absorb neighbor identity")
	check(not w.rooms.edit_field(a["uid"],["4,1","5,2"])["ok"],"cannot split internal connectivity")
	check(not w.rooms.create_field(["4,3","4,3"])["ok"],"duplicate selected cells reject")
	check(not w.rooms.create_field(["4,3","04,3"])["ok"],"coordinate aliases reject")
	check(not w.plant(Vector2i(5,1),"fast_fir")["ok"],"large crop cannot straddle A and B")
	check(w.plant(Vector2i(4,1),"fast_fir")["ok"],"whole large crop belongs to A")
	check(not w.rooms.edit_field(a["uid"],["4,1","5,1"])["ok"],"cannot cut live crop footprint")
	var before: Dictionary = w.to_snapshot()
	w.rooms.regions(w.clock.total_days)
	w.rooms.preview_field(cells(Rect2i(4,1,2,2)),a["uid"])
	check(w.to_snapshot()==before,"queries preserve ownership and rewards")
	var valid: Dictionary = Codec.normalize(before)
	check(valid["ok"],"declared fields save valid: "+str(valid.get("reason","")))
	check(w.apply_snapshot(JSON.parse_string(JSON.stringify(before)))["ok"],"JSON reload retains identity")
	check(w.rooms.regions(w.clock.total_days).size()==2,"reload never floods neighbors")
	for mode in ["overlap","disconnected","uid","crop_split"]:
		var bad: Dictionary = before.duplicate(true)
		var rows: Array = bad["world"]["rooms"]["fields"]
		match mode:
			"overlap": rows[1]["cells"] = rows[0]["cells"].duplicate()
			"disconnected": rows[1]["cells"] = ["6,1","7,2"]
			"uid": rows[1]["uid"] = rows[0]["uid"]
			"crop_split": rows[0]["cells"] = ["4,1","5,1"]
		check(not Codec.normalize(bad)["ok"],"corrupt boundary rejects "+mode)
	check(w.rooms.set_floor(Vector2i(6,1),"natural")["ok"],"floor removal does not erase identity")
	check(w.rooms.field_at(Vector2i(6,1))["uid"]==b["uid"],"floor and membership independent")
	check(not w.rooms.regions(w.clock.total_days)[1]["structural"],"missing floor suspends room")
	check(Codec.normalize(w.to_snapshot())["ok"],"legitimate suspended room reloads")
	check(w.rooms.set_floor(Vector2i(6,1),"ordinary")["ok"],"change floor without changing owner")
	check(not w.ranch._zone_cells_free(["6,1"]).is_empty(),"ordinary floor still owned by farm cannot enter ranch")
	check(w.rooms.set_floor(Vector2i(6,1),"farmland")["ok"],"repair floor")
	check(w.rooms.regions(w.clock.total_days)[1]["structural"],"repair restores same room")
	check(w.rooms.erase_field(a["uid"])["ok"],"unregister identity without deleting crop")
	check(not w.instance_at(Vector2i(4,1)).is_empty(),"unregister preserves crop and earned reward record")
	check(w.rooms.field_at(Vector2i(4,1)).is_empty(),"unregister does not transfer to adjacent B")
	for y in range(7,9):
		for x in range(4,12): w.rooms.set_floor(Vector2i(x,y),"ordinary")
	var za: Dictionary = w.ranch.create_zone("pasture",cells(Rect2i(4,7,4,2)))
	var zb: Dictionary = w.ranch.create_zone("pasture",cells(Rect2i(8,7,4,2)))
	check(za["ok"] and zb["ok"],"touching ranch rooms independently created")
	check(not w.ranch.paint_cell(za["zone_uid"],Vector2i(8,7))["ok"],"ranch ownership cannot be stolen")
	check(w.ranch.state["zones"].size()==2,"ranch retains separate identity")
	check(Codec.normalize(w.to_snapshot())["ok"],"combined agriculture and ranch save valid")
	print("ROOM BOUNDARIES %s (%d)" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
