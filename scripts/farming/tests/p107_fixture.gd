extends RefCounted
## Explicit model-fixture bootstrap. Grants are declared fixture inputs, never
## business earnings. Milestones still use actual orders and public submissions.
static func unlock(world, level := 3) -> void:
	if world.progress.stage() >= level: return
	var supply := {}
	var original := {}
	for item in world._items:
		if world._items[item]["supply_allowed"]:
			supply[item] = 200
			original[item] = world.inventory.count(item)
	world.grant_scaffold(supply)
	for _day in range(16):
		if world.progress.stage() >= mini(level, 2): break
		for row in world.daily_orders():
			if row["status"] != "open": continue
			for item in world._items:
				var quote: Dictionary = world.order_quote(int(row["id"]), String(item))
				if quote.get("ok") and world.inventory.has(item, int(quote["quantity"])):
					assert(world.deliver_order(int(row["id"]), item)["ok"])
					break
		var event: Dictionary = world.progress.event_quote()
		if event["ok"]:
			assert(world.progress.complete_event(event["id"])["ok"])
		elif world.progress.stage() < mini(level, 2):
			assert(world.end_day()["ok"] and world.daily_save_error.is_empty())
	assert(world.progress.stage() == mini(level, 2), "bounded stage fixture failed to reach its milestone")
	# Restore the caller's stock after the declared milestone scaffold. In
	# particular this must not leave wool/silk from the bootstrap in a test
	# that is about to verify real animal production quantities.
	var removed := {}
	for item in original:
		var excess: int = world.inventory.count(item) - int(original[item])
		assert(excess >= 0)
		world.inventory.remove(item, excess)
		if excess > 0: removed[item] = excess
	world._record_flow({}, removed, "清除阶段测试供货余料")
	if level == 3 and world.progress.stage() == 2:
		world.grant_scaffold(world.progress.config["events"][2]["inputs"])
		assert(world.progress.complete_event("integrated_estate")["ok"])
