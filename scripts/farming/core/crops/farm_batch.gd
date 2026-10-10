extends RefCounted
const Grid := preload("res://scripts/farming/core/grid/land_grid.gd")
## All mutations finish before the single AP spend can emit day_changed.
static func cells(center: Vector2i, grid) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy in range(-1,2):
		for dx in range(-1,2):
			var cell := center + Vector2i(dx,dy)
			if grid.in_bounds(cell.x,cell.y): result.append(cell)
	return result

static func action(cell: Vector2i, kind: String, crop_id: String, grid, crops) -> String:
	if kind == "sower": return "plant" if crops.can_plant(cell,crop_id)["ok"] else ""
	if kind == "harvester": return "harvest" if crops.can_harvest(cell)["ok"] else ""
	if crops.can_clear(cell)["ok"]: return "clear"
	return "till" if grid.state_at(cell) == Grid.State.WILD else ""

static func run(center: Vector2i, kind: String, crop_id: String, grid, crops, inventory, clock) -> Dictionary:
	var targets := cells(center,grid)
	var successes := 0
	var raw_cost := 0
	var seen := {}
	var stopped := ""
	for cell in targets:
		var operation := action(cell,kind,crop_id,grid,crops)
		if operation.is_empty(): continue
		var inst: Dictionary = crops.instance_at(cell)
		if not inst.is_empty():
			if seen.has(inst["uid"]): continue
			seen[inst["uid"]] = true
		var cost: int = clock.cost_of(operation)
		if ceili((raw_cost + cost) / 2.0) > clock.ap:
			stopped = "行动点不足"
			break
		if operation == "plant" and not inventory.has(crop_id + "_seed",1):
			stopped = "种子不足"
			break
		var result: Dictionary
		match operation:
			"till": result = grid.till(cell)
			"clear": result = crops.clear(cell)
			"plant":
				result = crops.plant(cell,crop_id)
				if result["ok"]: inventory.remove(crop_id + "_seed",1)
			"harvest":
				result = crops.harvest(cell)
				if result["ok"]:
					for product in result["items"]: inventory.add(product["item_id"],int(product["qty"]))
		if result["ok"]:
			successes += 1
			raw_cost += cost
	var charged := ceili(raw_cost / 2.0)
	if charged > 0: clock.spend(charged)
	return {"ok": successes > 0, "successes": successes, "skipped": targets.size()-successes, "ap": charged, "stopped": stopped}
