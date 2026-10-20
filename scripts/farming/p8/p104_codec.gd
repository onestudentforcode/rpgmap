extends RefCounted
## Reconstruct earned benefits from receipts before accepting mutable indexes.
const S:=preload("res://scripts/farming/v1/v1_world_state.gd")
const C:=preload("res://scripts/farming/p8/p10_logistics.gd")
const R:=preload("res://scripts/farming/p8/p102_rooms.gd")
const FIELDS:={
	"agriculture_link":["host","field"],"toy_install":["host","item","count"],"toy_remove":["host","item","count"],
	"system":["uid","name","zones"],"maintenance":["animal","zone","t"],
	"growth":["animal","before","after","target","t"],
	"activity":["animal","t","zone","activity"],"maintenance_fail":["animal","t"],
	"gu_service":["host","instance","rank","value","animal","t","effect","space"],
	"toy_service":["animal","t","host","zone","space","roll","extra"],
	"breed_progress":["identity","before","points","after","target","t","source"],
	"breed_contribution":["identity","target","points","total","bed","space","t","available","occupied"],
	"birth_bonus":["identity","parent","child","target","eligible","gift","growth_target","breed_target"],
	"work_progress":["animal","t","yard","post","batch","recipe","base","points","carry","before","after","target","overflow","source"],
	"pool_candidate":["key","recipe","points","animal","system","t","batch"],
	"pool_discard":["key","recipe","points","animal","system","t","batch"],
	"pool_credit":["key","recipe","points","animal","system","t","batch","credited","discarded"],
	"pool_use":["key","recipe","points","animal","t","batch"],"pool_drop":["key","recipe","points"],
	"contribution_drop":["identity"],"fatigue":["animal","open","w","r","fails","toy_extra","next"],
	"natural_wait":["animal","t"],"natural_stall":["animal","t","efficiency","station"],
	"natural_short":["animal","t","station"],
	"natural_progress":["identity","animal","before","points","after","target","t","efficiency","station","species"]}
const NUMBERS:=["host","field","count","uid","animal","zone","t","rank","value","space","roll","extra","before","points","after","target","total","available","occupied","parent","child","eligible","gift","growth_target","breed_target","yard","post","batch","base","carry","overflow","system","credited","discarded","open","w","r","fails","toy_extra","next","efficiency","station"]

static func fail() -> Dictionary: return S.fail("服务收据、贡献或余量不守恒")
static func identity(row: Dictionary) -> String:
	return "%d:%d:%d:%d" % [int(row["yard"]),int(row["post"]),int(row["batch"]),int(row["t"])]
static func pool_identity(row: Dictionary) -> String:
	return "%s:%d:%d" % [row["key"],int(row["batch"]),int(row["t"])]
static func same_source(source: Dictionary, service: Dictionary) -> bool:
	var copy:=service.duplicate()
	for key in ["kind","stage","day"]: copy.erase(key)
	return C._canonical(source)==C._canonical(copy)

static func validate(value: Dictionary,snapshot: Dictionary,catalog) -> Dictionary:
	var events: Array=value["history"]
	var works:={}
	for event in events:
		if not event is Dictionary or not FIELDS.has(event.get("stage")): return fail()
		var expected: Array=FIELDS[event["stage"]].duplicate()
		expected.append_array(["kind","stage","day"])
		if not S.exact(event,expected) or event["kind"]!="service" or not S.whole(event["day"],0,int(snapshot["clock"]["total_days"])): return fail()
		for field in NUMBERS:
			if event.has(field) and not S.whole(event[field]): return fail()
		if event.has("source"):
			if not event["source"] is Dictionary: return fail()
			if not event["source"].is_empty():
				if not S.exact(event["source"],FIELDS["gu_service"]): return fail()
				for field in NUMBERS:
					if event["source"].has(field) and not S.whole(event["source"][field]): return fail()
		if event["stage"]=="work_progress":
			var key:=identity(event)
			if works.has(key): return fail()
			works[key]=C._canonical(event)
	events=C._canonical(events)
	for targets in value["contributions"].values():
		if not targets is Dictionary: return fail()
		for amount in targets.values():
			if not S.whole(amount): return fail()
	var gu:={}
	var capacity:={}
	var toy_events:={}
	var toys:={}
	var systems:={}
	var maintenance:={}
	var toy_zones:={}
	var progress:={}
	var contributions:={}
	var beds:={}
	var nursery_space:={}
	var candidates:={}
	var resolved:={}
	var used:={}
	var pools:={}
	var births:={}
	var children:={}
	var growth:={}
	var fatigue:={}
	var extras:={}
	var counts:={}
	var bans:={}
	var definitions:={}
	var species_space:={}
	var station_species:={}
	var station_capacity:={}
	for sid in catalog.load_data()["p103"]["species"]:
		species_space[sid]=int(catalog.load_data()["p103"]["species"][sid]["space"])
	for fid in catalog.load_data()["p103"]["stations"]:
		station_species[fid]=String(catalog.load_data()["p103"]["stations"][fid]["species"])
		station_capacity[fid]=int(catalog.load_data()["p103"]["stations"][fid]["capacity"])
	var natural_rounds:={}
	var natural_waits:={}
	var station_load:={}
	for d in catalog.load_data()["logistics"]["definitions"]: definitions[d["id"]]=d
	var instances:={}
	for instance in snapshot["world"]["logistics"]["instances"]: instances[instance["instance_id"]]=instance
	for e in events:
		var stage:=String(e["stage"])
		if e.has("animal"):
			var daily:="%d:%d" % [e["animal"],e["day"]]
			if not counts.has(daily): counts[daily]={"w":0,"r":0,"fails":0}
			if stage=="work_progress": counts[daily]["w"]+=1
			if stage=="activity":
				if e["activity"] not in ["roam","care"]: return fail()
				counts[daily]["r"]+=1
			if stage=="maintenance_fail":
				counts[daily]["fails"]+=1
				bans[int(e["animal"])]=maxi(int(bans.get(int(e["animal"]),-1)),int(e["t"])+8)
		match stage:
			"system":
				if not e["zones"] is Array or not e["name"] is String: return fail()
				systems[int(e["uid"])]=e["zones"].duplicate()
			"toy_install":
				if toys.has(str(int(e["host"]))) or e["item"]!="vine_ball" or e["count"]!=1: return fail()
				toys[str(int(e["host"]))]="vine_ball"
			"toy_remove":
				if not toys.has(str(int(e["host"]))) or e["item"]!="vine_ball" or e["count"]!=1: return fail()
				toys.erase(str(int(e["host"])))
			"maintenance":
				var key:="%d:%d" % [e["animal"],e["day"]]
				if not maintenance.has(key): maintenance[key]=[]
				maintenance[key].append(int(e["zone"]))
			"growth":
				var before:=int(growth.get(int(e["animal"]),children.get(int(e["animal"]),0)))
				if e["before"]!=before or e["after"]!=mini(int(e["target"]),before+100): return fail()
				growth[int(e["animal"])]=int(e["after"])
			"gu_service":
				if not instances.has(e["instance"]): return fail()
				var d: Dictionary=definitions[instances[e["instance"]]["definition_id"]]
				if e["effect"]!=d["effect"] or e["value"]!=d["value"] or e["rank"]!=instances[e["instance"]]["rank"] or e["space"] not in [1,2]: return fail()
				var key:="%s:%d:%d" % [e["effect"],e["animal"],e["t"]]
				if gu.has(key): return fail()
				gu[key]=e
				var cap:="%d:%d" % [e["host"],e["t"]]
				capacity[cap]=int(capacity.get(cap,0))+int(e["space"])
				if int(capacity[cap])>4: return fail()
			"toy_service":
				var key:="%d:%d" % [e["animal"],e["t"]]
				var roll:=R.draw(int(value["random_seed"]),"animal:"+str(int(e["animal"])),int(e["t"]),"toy")%100
				if toy_events.has(key) or not toys.has(str(int(e["host"]))) or e["roll"]!=roll or e["extra"]!=(1 if roll<10 else 0) or e["space"] not in [1,2] or int(e["t"])/8!=int(e["day"]): return fail()
				toy_events[key]=true
				var cap:="%d:%d" % [e["host"],e["t"]]
				capacity[cap]=int(capacity.get(cap,0))+int(e["space"])
				if int(capacity[cap])>4: return fail()
				var daily:="%d:%d" % [e["animal"],e["day"]]
				if not toy_zones.has(daily): toy_zones[daily]=[]
				toy_zones[daily].append(int(e["zone"]))
				extras[daily]=int(extras.get(daily,0))+int(e["extra"])
			"breed_progress":
				var key:=String(e["identity"])
				var parts:=key.split(":")
				if parts.size()!=2: return fail()
				var source_key:="breed_speed:%d:%d" % [int(parts[0]),e["t"]]
				var rate:=100
				if not e["source"].is_empty():
					if not gu.has(source_key) or not same_source(e["source"],gu[source_key]): return fail()
					rate=int(gu[source_key]["value"])
				if progress.has(key) and int(progress[key]["after"])!=int(e["before"]): return fail()
				if e["before"]>e["target"] or e["points"]!=mini(rate,int(e["target"])-int(e["before"])) or e["after"]!=int(e["before"])+int(e["points"]): return fail()
				progress[key]=e
			"breed_contribution":
				var key:=String(e["identity"])
				if not progress.has(key) or progress[key]["source"].is_empty() or e["t"]!=progress[key]["t"] or e["points"]!=progress[key]["points"]: return fail()
				if not contributions.has(key): contributions[key]={}
				var target:=str(int(e["target"]))
				contributions[key][target]=int(contributions[key].get(target,0))+int(e["points"])
				var total:=0
				for amount in contributions[key].values(): total+=int(amount)
				if e["total"]!=contributions[key][target] or total>int(progress[key]["target"]): return fail()
				var bed:="%s:%d" % [e["bed"],e["t"]]
				if beds.has(bed): return fail()
				beds[bed]=true
				var slot:="%d:%d" % [e["target"],e["t"]]
				nursery_space[slot]=int(nursery_space.get(slot,0))+int(e["space"])
				if int(nursery_space[slot])+int(e["occupied"])>int(e["available"]): return fail()
			"birth_bonus":
				var key:=String(e["identity"])
				if births.has(key) or children.has(int(e["child"])) or e["breed_target"]<=0: return fail()
				if e["eligible"]!=int(contributions.get(key,{}).get(str(int(e["target"])),0)): return fail()
				if e["eligible"]>e["breed_target"] or e["gift"]!=int(int(e["growth_target"])*int(e["eligible"])/(10*int(e["breed_target"]))): return fail()
				births[key]=true;children[int(e["child"])]=int(e["gift"]);contributions.erase(key)
			"contribution_drop": contributions.erase(e["identity"])
			"work_progress":
				var recipe: Dictionary=catalog.load_data()["p103"]["work"]["recipes"].get(e["recipe"],{})
				if recipe.is_empty() or e["target"]!=recipe["target"] or e["before"]>e["target"]: return fail()
				var source_key:="work_speed:%d:%d" % [e["animal"],e["t"]]
				var rate:=100
				if not e["source"].is_empty():
					if not gu.has(source_key) or not same_source(e["source"],gu[source_key]): return fail()
					rate=int(gu[source_key]["value"])
				var raw:=int(e["before"])+int(e["points"])+int(e["carry"])
				if e["base"] not in [10000,7500,5000] or e["points"]!=int(int(e["base"])*rate/100) or e["after"]!=mini(int(e["target"]),raw) or e["overflow"]!=maxi(0,raw-int(e["target"])): return fail()
				if int(e["carry"])>0 and not used.has(identity(e)): return fail()
			"pool_candidate":
				var key:=pool_identity(e)
				if candidates.has(key) or not works.has(key) or works[key]["overflow"]!=e["points"] or works[key]["source"].is_empty(): return fail()
				candidates[key]=e
			"pool_credit", "pool_discard":
				var key:=pool_identity(e)
				if not candidates.has(key) or resolved.has(key): return fail()
				resolved[key]=true
				if stage=="pool_discard": continue
				var daily:="%d:%d" % [e["animal"],e["day"]]
				var members: Array=systems.get(int(e["system"]),[])
				var maintained:=false
				var played:=false
				for uid in maintenance.get(daily,[]):
					if uid in members: maintained=true
				for uid in toy_zones.get(daily,[]):
					if uid in members: played=true
				if not maintained or not played: return fail()
				var pool: Dictionary=pools.get(e["key"],{"points":0,"recipe":e["recipe"]})
				if pool["recipe"]!=e["recipe"] or e["points"]!=candidates[key]["points"] or e["credited"]!=mini(int(e["points"]),10000-int(pool["points"])) or e["discarded"]!=int(e["points"])-int(e["credited"]): return fail()
				pool["points"]=int(pool["points"])+int(e["credited"]);pools[e["key"]]=pool
			"pool_use", "pool_drop":
				var pool: Dictionary=pools.get(e["key"],{"points":0,"recipe":e["recipe"]})
				if pool["recipe"]!=e["recipe"] or e["points"]!=pool["points"]: return fail()
				if stage=="pool_use":
					var key:=pool_identity(e)
					if used.has(key) or not works.has(key) or works[key]["carry"]!=e["points"] or works[key]["before"]!=0: return fail()
					used[key]=true
				pool["points"]=0
				pools[e["key"]]=pool
			"fatigue":
				var daily:="%d:%d" % [e["animal"],e["day"]]
				if e["w"]!=counts[daily]["w"] or e["r"]!=counts[daily]["r"] or e["fails"]!=counts[daily]["fails"]: return fail()
				if e["toy_extra"]!=int(extras.get(daily,0)) or e["next"]!=clampi(int(e["open"])+int(e["w"])-2*int(e["r"])+12*int(e["fails"])-int(e["toy_extra"]),0,100): return fail()
				fatigue[int(e["animal"])]=e
			"natural_wait":
				var key:="%d:%d" % [int(e["animal"]),int(e["t"])]
				if natural_waits.has(key): return fail()
				natural_waits[key]=true
			"natural_stall":
				if e["efficiency"]!=0 or int(e["station"])<=0: return fail()
			"natural_short":
				if int(e["station"])<=0: return fail()
			"natural_progress":
				# Body-material rounds: the opening-day efficiency is the only rate;
				# soothing gu never multiplies intensive progress and one station
				# serves at most its capacity of animal space per care unit.
				var identity:=String(e["identity"])
				# A first-round credit (P10.6 §16.2.11) or a near-full round may
				# truncate the last fill to the remaining headroom.
				if e["points"]!=mini(int(e["efficiency"]),int(e["target"])-int(e["before"])) or e["efficiency"] not in [100,75,50]: return fail()
				var before:=int(natural_rounds[identity]["after"]) if natural_rounds.has(identity) else int(e["before"])
				if before!=int(e["before"]) or int(e["before"])>int(e["target"]): return fail()
				if int(e["after"])!=mini(int(e["target"]),before+int(e["points"])): return fail()
				natural_rounds[identity]=e
				var animal_row:={}
				for row in snapshot["world"]["ranch"]["animals"]:
					if int(row["uid"])==int(e["animal"]): animal_row=row
				# Capture rounds and deaths remove animals; their receipts stay
				# auditable because the species rides on the receipt itself.
				var receipt_species:=String(e["species"])
				if not animal_row.is_empty() and String(animal_row["species_id"])!=receipt_species: return fail()
				var station_id:=""
				for fid in station_species:
					if station_species[fid]==receipt_species: station_id=fid
				var facility:={}
				for row in snapshot["world"]["facilities"]:
					if int(row["uid"])==int(e["station"]): facility=row
				if facility.is_empty() or String(facility["facility_id"])!=station_id: return fail()
				var load_key:="%d:%d" % [int(e["station"]),int(e["t"])]
				station_load[load_key]=int(station_load.get(load_key,0))+int(species_space[receipt_species])
				if int(station_load[load_key])>int(station_capacity[station_id]): return fail()
	if C._canonical(toys)!=C._canonical(value["toys"]) or C._canonical(contributions)!=C._canonical(value["contributions"]): return fail()
	for key in pools:
		if int(pools[key]["points"])!=int(value["pools"].get(key,{}).get("points",0)): return fail()
	for row in snapshot["world"]["ranch"]["animals"]:
		if bans.has(int(row["uid"])) and int(row["ban_until"])!=int(bans[int(row["uid"])]): return fail()
		if fatigue.has(int(row["uid"])) and int(row["fatigue"])!=int(fatigue[int(row["uid"])]["next"]): return fail()
		if growth.has(int(row["uid"])) or children.has(int(row["uid"])):
			if int(row["growth"])!=int(growth.get(int(row["uid"]),children.get(int(row["uid"]),0))): return fail()
	return {"ok":true}
