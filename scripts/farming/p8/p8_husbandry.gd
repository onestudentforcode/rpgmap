extends "res://scripts/farming/v2/v2_husbandry.gd"
## P8 water habitats turn real water maintenance into a limited daily water
## change that also produces wastewater stock (the T04 research sample source),
## and research-gated optional diets stay unselectable until unlocked.

## P8 ownership lives in the operations registry, not on the worker row.
func caretaker_of(facility_uid: int) -> Dictionary:
	var owner: int = world.operations.owner_of(facility_uid)
	return world.workforce._worker(owner) if owner > 0 else {}

func ensure(facility_uid: int) -> Dictionary:
	var habitat: Dictionary = super(facility_uid)
	if habitat.has("water") and not habitat.has("water_change_day"):
		habitat["water_change_day"] = -1
	return habitat

## Read-only change quote; one real change per habitat per service day.
func quote_water(facility_uid: int) -> Dictionary:
	var base: Dictionary = super(facility_uid)
	if not base["ok"]:
		return base
	var habitat := habitat_of(facility_uid)
	if int(habitat.get("water_change_day", -1)) == _today():
		return _error("今日已换过水，每场每天最多一次换水")
	var change: Dictionary = settings["water"]["change"]
	base["inputs"] = change["inputs"].duplicate()
	base["gain"] = int(change["gain"])
	base["wastewater"] = int(change["wastewater"])
	return base

## Real water change: consumes clean water, raises the metric and issues the
## matching wastewater stock. Manual and caretaker runs share the day marker.
func maintain_water(facility_uid: int, operator: String = "player") -> Dictionary:
	var checked: Dictionary = world._can_act(int(settings["water"]["maintenance_ap"]))
	if not checked["ok"]:
		return checked
	var quote := quote_water(facility_uid)
	if not quote["ok"]:
		return quote
	var habitat := habitat_of(facility_uid)
	var inputs: Dictionary = quote["inputs"]
	var sewage := int(quote["wastewater"])
	if not Scalars.whole(world.inventory.count("wastewater") + sewage):
		return _error("输出库存越界：污水")
	for ident in inputs:
		world.inventory.remove(ident, int(inputs[ident]))
	world.inventory.add("wastewater", sewage)
	world._record_flow({"wastewater": sewage}, inputs, "水场换水")
	habitat["water"] = mini(int(settings["water"]["maximum"]), int(habitat["water"]) + int(quote["gain"]))
	habitat["water_change_day"] = _today()
	world._report_event({"category": "maintenance", "facility_uid": facility_uid, "kind": "水场换水",
		"count": 1, "items": inputs, "note": "水体+%d，产出污水%d" % [int(quote["gain"]), sewage]})
	return world._finish(int(quote["ap"]), {"ok": true, "water": int(habitat["water"]),
		"inputs": inputs, "wastewater": sewage, "operator": operator})

## Optional diets unlocked by research stay unselectable until P8.c tracks it.
func set_diet(facility_uid: int, diet_kind: String, slot: String, diet_id: String) -> Dictionary:
	var blocked := _diet_block(facility_uid, diet_kind, diet_id)
	if not blocked.is_empty():
		return _error(blocked)
	return super(facility_uid, diet_kind, slot, diet_id)

func _diet_block(facility_uid: int, diet_kind: String, diet_id: String) -> String:
	if diet_kind == "special_diets" and diet_id.is_empty():
		return ""
	if not world.facilities.has(facility_uid):
		return ""
	var habitat := habitat_of(facility_uid)
	if habitat.is_empty():
		return ""
	var species: Dictionary = species_def(habitat["species_id"])
	for diet in species[diet_kind]:
		if String(diet["id"]) == diet_id:
			return world.research_block(String(diet.get("research", "")))
	return ""
