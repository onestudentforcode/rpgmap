extends RefCounted
## Deterministic read-only planner. Execution always calls the existing world
## action for each approved target.
const Workforce := preload("res://scripts/farming/v1/v1_workforce.gd")

static func cells(rect: Rect2i) -> Array:
	var result := []
	for y in range(rect.position.y,rect.position.y+rect.size.y):
		for x in range(rect.position.x,rect.position.x+rect.size.x): result.append(Vector2i(x,y))
	return result

static func preview(world, rect: Rect2i, kind: String, crop_id := "") -> Dictionary:
	var out := {"actions":[],"invalid":[],"blocked":"","ap":0,"inputs":{},"targets":0,"unplanned":0}
	if rect.size.x<=0 or rect.size.y<=0 or rect.size.x>world.grid.width or rect.size.y>world.grid.height:
		out["blocked"]="框选范围无效";return out
	var candidates:=cells(rect)
	var seen_uids:={}
	var occupied_rects: Array[Rect2i]=[]
	if kind in ["harvest","fell","clear"]:
		var origins:=[]
		for cell in candidates:
			var crop: Dictionary=world.instance_at(cell)
			if crop.is_empty(): continue
			var uid:=int(crop["uid"])
			if seen_uids.has(uid): continue
			seen_uids[uid]=true
			origins.append(Vector2i(int(crop["origin"][0]),int(crop["origin"][1])))
		candidates=origins
	var shadow: Dictionary=world.inventory.to_save()
	var planned:=0
	for cell in candidates:
		var quote: Dictionary
		var action_crop:=crop_id
		if kind=="plant":
			if not world.crop_defs.has(crop_id): quote={"ok":false,"reason":"请先选择作物"}
			else:
				var shape: Array=world.crop_defs[crop_id]["footprint"]
				var footprint:=Rect2i(cell,Vector2i(int(shape[0]),int(shape[1])))
				if rect.get_area()>1 and not rect.encloses(footprint):
					out["invalid"].append({"cell":cell,"reason":"作物完整占地超出框选范围"});continue
				var overlaps:=false
				for used in occupied_rects:
					if used.intersects(footprint): overlaps=true;break
				if overlaps:
					out["invalid"].append({"cell":cell,"reason":"与本次已安排作物重叠"});continue
				quote=world.plant_quote(cell,crop_id)
				if quote["ok"]:
					for plan in world.workforce.state["seed_plans"]:
						if plan["cell"]==[cell.x,cell.y]: continue
						var other: Dictionary=world.crop_defs[String(plan["crop_id"])]
						var prior:=Rect2i(Vector2i(int(plan["cell"][0]),int(plan["cell"][1])),Vector2i(int(other["footprint"][0]),int(other["footprint"][1])))
						if prior.intersects(footprint): quote={"ok":false,"reason":"与已有选种计划重叠"};break
				if quote["ok"]: occupied_rects.append(footprint)
		else:
			quote=world.action_quote(cell,kind)
		if not quote.get("ok",false):
			out["invalid"].append({"cell":cell,"reason":String(quote.get("reason","目标不可用"))});continue
		var need: Dictionary=quote.get("inputs",{})
		var missing: String=""
		for item in need:
			if int(shadow.get(item,0))<int(need[item]):
				missing="缺少投入："+String(world._items[String(item)]["name"]);break
		if not missing.is_empty(): out["blocked"]=missing;out["unplanned"]+=1;continue
		var cost:=int(quote.get("ap",1))
		if int(world.clock.ap)-int(out["ap"])<cost:
			out["blocked"]="行动点不足";out["unplanned"]+=1;continue
		for item in need:
			shadow[item]=int(shadow.get(item,0))-int(need[item])
			out["inputs"][item]=int(out["inputs"].get(item,0))+int(need[item])
		out["actions"].append({"cell":cell,"crop_id":action_crop,"inputs":need.duplicate()})
		out["ap"]=int(out["ap"])+cost
		planned+=1
	out["targets"]=planned
	return out
