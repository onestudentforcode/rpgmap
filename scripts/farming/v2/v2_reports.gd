extends RefCounted
## Husbandry fact ledger for P7.e: per-day entries, three cumulative terms and the
## frozen first-45-day recap. Facts come from successful model transactions only.
const Scalars := preload("res://scripts/farming/v1/v1_world_state.gd")
const HISTORY_LIMIT := 15
const CATEGORIES := ["purchase", "maintenance", "growth", "claim", "pause", "cull", "labour"]

var _owner: WeakRef
var world:
	get:
		return _owner.get_ref()
var state: Dictionary

func _init(owner) -> void:
	_owner = weakref(owner)
	state = fresh(0)

static func fresh(day: int) -> Dictionary:
	return {"pending": {"day": day, "entries": []}, "history": [],
		"terms": [_bucket(), _bucket(), _bucket()], "recap": {}}

static func _bucket() -> Dictionary:
	var out := {}
	for category in CATEGORIES:
		out[category] = {}
	return out

static func _bucket_has_counts(bucket) -> bool:
	if not bucket is Dictionary:
		return true
	for category in bucket:
		if bucket[category] is Dictionary and not bucket[category].is_empty():
			return true
	return false

## One fact per successful event; entries stay plain and small.
func record(entry: Dictionary) -> void:
	var pending: Dictionary = state["pending"]
	var merged := false
	# Same-day same-facility same-category facts aggregate instead of stacking rows.
	for existing in pending["entries"]:
		if existing.get("category") == entry.get("category") and existing.get("facility_uid") == entry.get("facility_uid", -1) and existing.get("kind") == entry.get("kind", ""):
			for key in entry:
				if key in ["category", "facility_uid", "kind"]:
					continue
				if entry[key] is int:
					existing[key] = int(existing.get(key, 0)) + int(entry[key])
				elif entry[key] is Dictionary:
					var target: Dictionary = existing.get(key, {})
					for item in entry[key]:
						target[item] = int(target.get(item, 0)) + int(entry[key][item])
					existing[key] = target
			merged = true
			if entry["category"] == "purchase":
				var species: Dictionary = world.husbandry.species_def(String(entry["kind"]))
				existing["note"] = "购入%d个体，花费%d元石" % [int(existing["count"]), int(existing["count"])*int(species["juvenile_price"])]
			break
	if not merged:
		pending["entries"].append(entry.duplicate(true))

func _term_counts(entry: Dictionary) -> Dictionary:
	# Term buckets keep a compact projection: counts and quantities per category.
	var out := {}
	for key in entry:
		if key in ["category", "facility_uid", "kind"]:
			continue
		if entry[key] is int:
			out[key] = int(entry[key])
		elif entry[key] is Dictionary:
			for item in entry[key]:
				out[item] = int(entry[key][item])
	if int(entry.get("count", 0)) > 0:
		out[String(entry["kind"])] = int(entry["count"])
	return out

func recap_totals() -> Dictionary:
	var out := _bucket()
	var terms: Array = state["recap"]["terms"] if recap_active() else state["terms"]
	for term in terms:
		for category in CATEGORIES:
			for key in term[category]:
				out[category][key] = int(out[category].get(key, 0)) + int(term[category][key])
	return out

## Runs inside the day settle, after patrols and husbandry settlement: the day's
## entries roll into the term and history, and day 45 freezes the recap.
func settle(completed_day: int) -> void:
	var pending: Dictionary = state["pending"]
	if int(pending["day"]) != completed_day:
		return
	if not pending["entries"].is_empty():
		var term_index: int = clampi(int(completed_day / 15), 0, 2)
		var bucket: Dictionary = state["terms"][term_index]
		if completed_day < 45:
			for entry in pending["entries"]:
				var category: String = entry["category"]
				var counts := _term_counts(entry)
				for key in counts:
					bucket[category][key] = int(bucket[category].get(key, 0)) + int(counts[key])
		state["history"].append({"day": int(pending["day"]), "entries": pending["entries"].duplicate(true)})
		while state["history"].size() > HISTORY_LIMIT:
			state["history"].pop_front()
	state["pending"] = {"day": completed_day + 1, "entries": []}
	if completed_day == 44 and state["recap"].is_empty():
		_freeze_recap()

## The frozen recap snapshots cumulative terms plus the real end-of-period state.
func _freeze_recap() -> void:
	var animals := {}
	var ready := 0
	var running := 0
	for habitat in world.husbandry.state["habitats"]:
		var species: String = habitat["species_id"]
		if not animals.has(species):
			animals[species] = {"juvenile": 0, "adult": 0}
		for individual in habitat["individuals"]:
			animals[species]["adult" if individual["stage"] == "adult" else "juvenile"] += 1
			var cycle: Dictionary = individual.get("cycle", {})
			if cycle.is_empty():
				continue
			if cycle["status"] == "ready":
				ready += 1
			else:
				running += 1
	state["recap"] = {"terms": state["terms"].duplicate(true), "labour": int(world.workforce.state["spent"]),
		"cash": world.primeval_stones, "inventory": world.inventory.to_save(),
		"animals": animals, "ready": ready, "running": running}

func to_save() -> Dictionary:
	return state.duplicate(true)

func apply_save(value: Dictionary) -> void:
	state = value.duplicate(true)

func day_entries(day: int) -> Array:
	for row in state["history"]:
		if int(row["day"]) == day:
			return row["entries"]
	return state["pending"]["entries"] if int(state["pending"]["day"]) == day else []

func term_bucket(index: int) -> Dictionary:
	return state["recap"]["terms"][index] if not state["recap"].is_empty() and index >= 0 else state["terms"][index]

func recap_active() -> bool:
	return not state["recap"].is_empty()

static func _normalize_entry(value, items, species_defs) -> Dictionary:
	if not Scalars.exact(value, ["category", "facility_uid", "kind", "count", "items", "note"]):
		return Scalars.fail("养殖条目字段非法")
	if not value["category"] is String or not CATEGORIES.has(value["category"]) or not value["kind"] is String or value["kind"].length() > 24:
		return Scalars.fail("养殖条目类别非法")
	if not Scalars.whole(value["facility_uid"], 0) or not Scalars.whole(value["count"], 0) or not value["note"] is String or value["note"].length() > 120:
		return Scalars.fail("养殖条目数值或说明非法")
	if not value["items"] is Dictionary:
		return Scalars.fail("养殖条目物品非法")
	var packed_items := {}
	for item in value["items"]:
		if not items.has(item) or not Scalars.whole(value["items"][item], 0):
			return Scalars.fail("养殖条目物品非法")
		if int(value["items"][item]) > 0:
			packed_items[item] = int(value["items"][item])
	return {"ok": true, "entry": {"category": value["category"], "facility_uid": int(value["facility_uid"]),
		"kind": value["kind"], "count": int(value["count"]), "items": packed_items, "note": value["note"]}}

static func normalize(value, day: int, catalog) -> Dictionary:
	var species_defs := {}
	for row in catalog.load_data()["livestock"]:
		species_defs[row["id"]] = row
	if not Scalars.exact(value, ["pending", "history", "terms", "recap"]):
		return Scalars.fail("养殖报表字段非法")
	var items = catalog.resources(catalog.load_data())
	var pending = value["pending"]
	# The slot envelope already bounds file bytes. Valid farm activity must not
	# become unsaveable merely because it produced more than 64 facts.
	if not Scalars.exact(pending, ["day", "entries"]) or not Scalars.whole(pending["day"], day, day) or not pending["entries"] is Array:
		return Scalars.fail("养殖当日条目非法")
	var out := fresh(day)
	for entry in pending["entries"]:
		var checked := _normalize_entry(entry, items, species_defs)
		if not checked["ok"]:
			return checked
		out["pending"]["entries"].append(checked["entry"])
	if not value["history"] is Array or value["history"].size() > HISTORY_LIMIT or value["history"].size() > day:
		return Scalars.fail("养殖报表历史非法")
	# Only days with husbandry facts are archived: strictly increasing, bounded by
	# the latest settled day, never dense-contiguous.
	var previous_day := -1
	for index in range(value["history"].size()):
		var row = value["history"][index]
		if not Scalars.exact(row, ["day", "entries"]) or not Scalars.whole(row["day"], previous_day + 1, day - 1) or not row["entries"] is Array or row["entries"].is_empty():
			return Scalars.fail("养殖报表历史日期非法")
		previous_day = int(row["day"])
		var entries := []
		for entry in row["entries"]:
			var checked := _normalize_entry(entry, items, species_defs)
			if not checked["ok"]:
				return checked
			entries.append(checked["entry"])
		out["history"].append({"day": int(row["day"]), "entries": entries})
	if not value["terms"] is Array or value["terms"].size() != 3:
		return Scalars.fail("养殖时节账非法")
	for index in range(3):
		if not value["terms"][index] is Dictionary:
			return Scalars.fail("养殖时节账非法")
		if index * 15 >= day and _bucket_has_counts(value["terms"][index]):
			return Scalars.fail("未经历时节不能有养殖统计")
		var bucket: Dictionary = _normalize_bucket(value["terms"][index], items)
		if not bucket["ok"]:
			return bucket
		out["terms"][index] = bucket["bucket"]
	var recap = value["recap"]
	if not recap is Dictionary: return Scalars.fail("养殖回顾冻结结构非法")
	if day >= 45 and recap.is_empty(): return Scalars.fail("第45天之后必须保留养殖回顾")
	if not recap.is_empty():
		if not Scalars.exact(recap, ["terms", "labour", "cash", "inventory", "animals", "ready", "running"]) or not Scalars.whole(recap["labour"]) or not Scalars.whole(recap["cash"]) or not Scalars.whole(recap["ready"]) or not Scalars.whole(recap["running"]) or day < 45:
			return Scalars.fail("养殖回顾冻结字段非法")
		if not recap["terms"] is Array or recap["terms"].size() != 3 or not recap["inventory"] is Dictionary or not recap["animals"] is Dictionary:
			return Scalars.fail("养殖回顾冻结结构非法")
		var frozen_terms := []
		for index in range(3):
			var bucket: Dictionary = _normalize_bucket(recap["terms"][index], items)
			if not bucket["ok"]:
				return bucket
			frozen_terms.append(bucket["bucket"])
		var inventory := {}
		for item in recap["inventory"]:
			if not items.has(item) or not Scalars.whole(recap["inventory"][item], 0):
				return Scalars.fail("养殖回顾期末库存非法")
			inventory[item] = int(recap["inventory"][item])
		var animals := {}
		for species in recap["animals"]:
			var row = recap["animals"][species]
			if not species_defs.has(species) or not Scalars.exact(row, ["juvenile", "adult"]) or not Scalars.whole(row["juvenile"], 0) or not Scalars.whole(row["adult"], 0):
				return Scalars.fail("养殖回顾期末个体非法")
			animals[species] = {"juvenile": int(row["juvenile"]), "adult": int(row["adult"])}
		out["recap"] = {"terms": frozen_terms, "labour": int(recap["labour"]), "cash": int(recap["cash"]),
			"inventory": inventory, "animals": animals, "ready": int(recap["ready"]), "running": int(recap["running"])}
	return {"ok": true, "reports": out}

static func _normalize_bucket(value, items) -> Dictionary:
	if not value is Dictionary:
		return Scalars.fail("养殖时节桶非法")
	var out := {}
	for category in value:
		if not CATEGORIES.has(category) or not value[category] is Dictionary:
			return Scalars.fail("养殖时节类别非法")
		var counts := {}
		for key in value[category]:
			if not key is String or key.length() > 32 or not Scalars.whole(value[category][key], 0):
				return Scalars.fail("养殖时节计数非法")
			if int(value[category][key]) > 0:
				counts[key] = int(value[category][key])
		out[category] = counts
	for category in CATEGORIES:
		if not out.has(category):
			out[category] = {}
	return {"ok": true, "bucket": out}
