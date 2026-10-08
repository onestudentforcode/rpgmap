extends RefCounted
## 作物实例管理（phase-02 §4）：生命周期 + 有限次再生 + 多素材产出。
## 纯逻辑零渲染依赖；地格联动走 LandGrid（播种=原子占格置 PLANTED，holder="crop:<uid>"，
## 移除/清理=release 回 TILLED）。生长只按 day_changed 推进（离散事件制）。
##
## 原子约定（master-plan 任务 2.4）：播种的完整链路由调用方按
## can_plant → inventory.has(seed) → plant() → inventory.remove(seed) 顺序组合；
## plant() 内部再经 LandGrid.reserve 原子落格，任一步失败则种子与地格均不变。
## 消费方以 preload 引用。

signal crops_changed()

const LandGrid := preload("res://scripts/farming/core/grid/land_grid.gd")

enum CropState { GROWING, MATURE, REGROWING, EXHAUSTED }

const STATE_NAMES := {
	CropState.GROWING: "GROWING",
	CropState.MATURE: "MATURE",
	CropState.REGROWING: "REGROWING",
	CropState.EXHAUSTED: "EXHAUSTED",
}

var grid: LandGrid  # preload 类型标注（保证方法调用可推断）
var defs: Dictionary = {}   # crop_id -> 定义
var crops: Dictionary = {}  # uid -> 实例
var _next_uid := 1


func setup(g: LandGrid, crops_data: Dictionary) -> void:
	grid = g
	defs = {}
	for c in crops_data.get("crops", []):
		defs[c["crop_id"]] = c


func reset_all() -> void:
	crops.clear()
	_next_uid = 1
	crops_changed.emit()


func def_of(crop_id: String) -> Dictionary:
	return defs.get(crop_id, {})


## 到达成熟所需天数（不含 mature 段；由配置求和，不硬编码阶段数）。
func mature_day_threshold(def: Dictionary) -> int:
	var total := 0
	var stages: Array = def.get("growth_stages", [])
	for i in stages.size() - 1:
		total += int(stages[i]["days"])
	return total


## GROWING 期的显示阶段序号（按配置天数累进；MRO：阶段数由配置决定）。
func stage_index(inst: Dictionary) -> int:
	var stages: Array = def_of(inst["crop_id"]).get("growth_stages", [])
	var acc := 0
	for i in stages.size() - 1:
		acc += int(stages[i]["days"])
		if int(inst["growth_days"]) < acc:
			return i
	return stages.size() - 1


func instance_at(cell: Vector2i) -> Dictionary:
	for uid in crops:
		var inst: Dictionary = crops[uid]
		var o: Vector2i = inst["origin"]
		var f: Array = inst["footprint"]
		if o.x <= cell.x and cell.x < o.x + int(f[0]) and o.y <= cell.y and cell.y < o.y + int(f[1]):
			return inst
	return {}


func holder_of(uid: int) -> String:
	return "crop:%d" % uid


# ------------------------------------------------------------ 播种

func can_plant(cell: Vector2i, crop_id: String) -> Dictionary:
	var def := def_of(crop_id)
	if def.is_empty():
		return {"ok": false, "reason": "unknown_crop"}
	var fw := int(def["footprint"][0])
	var fh := int(def["footprint"][1])
	for dy in range(fh):
		for dx in range(fw):
			var c := cell + Vector2i(dx, dy)
			if not grid.in_bounds(c.x, c.y):
				return {"ok": false, "reason": "out_of_bounds"}
			var st := grid.state_at(c)
			if st == LandGrid.State.UNAVAILABLE:
				return {"ok": false, "reason": "terrain_not_tillable:" + grid.terrain_at(c)}
			if st == LandGrid.State.WILD:
				return {"ok": false, "reason": "not_tilled"}
			if st != LandGrid.State.TILLED:
				return {"ok": false, "reason": "cell_busy:" + LandGrid.STATE_NAMES[st]}
	return {"ok": true, "reason": ""}


func plant(cell: Vector2i, crop_id: String) -> Dictionary:
	var chk := can_plant(cell, crop_id)
	if not chk["ok"]:
		return chk
	var def := def_of(crop_id)
	var fw := int(def["footprint"][0])
	var fh := int(def["footprint"][1])
	var uid := _next_uid
	var r := grid.reserve(cell, fw, fh, holder_of(uid), LandGrid.State.PLANTED)
	if not r["ok"]:
		return r
	_next_uid += 1
	crops[uid] = {
		"uid": uid, "crop_id": crop_id, "origin": cell, "footprint": [fw, fh],
		"growth_days": 0, "regrow_days": 0, "harvest_count": 0,
		"state": CropState.GROWING,
	}
	crops_changed.emit()
	return {"ok": true, "uid": uid, "reason": ""}


# ------------------------------------------------------------ 按天推进

func on_day_changed() -> void:
	var changed := false
	for uid in crops:
		var inst: Dictionary = crops[uid]
		var st: int = inst["state"]
		if st == CropState.GROWING:
			var thr := mature_day_threshold(def_of(inst["crop_id"]))
			if int(inst["growth_days"]) < thr:
				inst["growth_days"] = int(inst["growth_days"]) + 1
				if int(inst["growth_days"]) >= thr:
					inst["state"] = CropState.MATURE
				changed = true
		elif st == CropState.REGROWING:
			inst["regrow_days"] = int(inst["regrow_days"]) + 1
			var rd := int(def_of(inst["crop_id"])["regrowth_duration"])
			if int(inst["regrow_days"]) >= rd:
				inst["state"] = CropState.MATURE
			changed = true
	if changed:
		crops_changed.emit()


# ------------------------------------------------------------ 收获 / 清理

func can_harvest(cell: Vector2i) -> Dictionary:
	var inst := instance_at(cell)
	if inst.is_empty():
		return {"ok": false, "reason": "no_crop"}
	if int(inst["state"]) != CropState.MATURE:
		return {"ok": false, "reason": "not_mature:" + STATE_NAMES[inst["state"]]}
	return {"ok": true, "reason": "", "inst": inst}


## 采收：多素材逐项在 min–max 掷量；RNG 以 (uid, harvest_count) 播种——
## 同存档重放结果一致（确定性，自测按同公式复算断言）。
func harvest(cell: Vector2i) -> Dictionary:
	var chk := can_harvest(cell)
	if not chk["ok"]:
		return chk
	var inst: Dictionary = chk["inst"]
	var def := def_of(inst["crop_id"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d" % [int(inst["uid"]), int(inst["harvest_count"])])
	var items := []
	for e in def["harvest_items"]:
		var q := rng.randi_range(int(e["min"]), int(e["max"]))
		if q > 0:
			items.append({"item_id": e["item_id"], "qty": q})
	inst["harvest_count"] = int(inst["harvest_count"]) + 1
	if def["harvest_type"] == "remove":
		_remove(inst)
		return {"ok": true, "items": items, "removed": true, "exhausted": false}
	if int(inst["harvest_count"]) >= int(def["max_harvests"]):
		inst["state"] = CropState.EXHAUSTED
		crops_changed.emit()
		return {"ok": true, "items": items, "removed": false, "exhausted": true}
	inst["state"] = CropState.REGROWING
	inst["regrow_days"] = 0
	crops_changed.emit()
	return {"ok": true, "items": items, "removed": false, "exhausted": false}


func can_clear(cell: Vector2i) -> Dictionary:
	var inst := instance_at(cell)
	if inst.is_empty():
		return {"ok": false, "reason": "no_crop"}
	if int(inst["state"]) != CropState.EXHAUSTED:
		return {"ok": false, "reason": "not_exhausted:" + STATE_NAMES[inst["state"]]}
	return {"ok": true, "reason": "", "inst": inst}


## 清理枯竭植株：地格回 TILLED，实例销毁（master-plan v1.1 任务 2.2）。
func clear(cell: Vector2i) -> Dictionary:
	var chk := can_clear(cell)
	if not chk["ok"]:
		return chk
	_remove(chk["inst"])
	return {"ok": true, "reason": ""}


func _remove(inst: Dictionary) -> void:
	grid.release(holder_of(int(inst["uid"])))
	crops.erase(int(inst["uid"]))
	crops_changed.emit()


# ------------------------------------------------------------ 查询（Overlay/HUD）

func mature_cells() -> Array[Vector2i]:
	return _cells_in_state(CropState.MATURE)


func exhausted_cells() -> Array[Vector2i]:
	return _cells_in_state(CropState.EXHAUSTED)


func _cells_in_state(s: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for uid in crops:
		var inst: Dictionary = crops[uid]
		if int(inst["state"]) == s:
			var o: Vector2i = inst["origin"]
			var f: Array = inst["footprint"]
			for dy in range(int(f[1])):
				for dx in range(int(f[0])):
					out.append(o + Vector2i(dx, dy))
	return out


# ------------------------------------------------------------ 存档（逻辑数据 only）

func to_save() -> Dictionary:
	var list := []
	for uid in crops:
		var inst: Dictionary = crops[uid]
		list.append({
			"uid": int(inst["uid"]), "crop_id": inst["crop_id"],
			"origin": [inst["origin"].x, inst["origin"].y],
			"growth_days": int(inst["growth_days"]), "regrow_days": int(inst["regrow_days"]),
			"harvest_count": int(inst["harvest_count"]), "state": STATE_NAMES[inst["state"]],
		})
	return {"next_uid": _next_uid, "crops": list}


func apply_save(d: Dictionary) -> bool:
	var by_name := {}
	for k in STATE_NAMES:
		by_name[STATE_NAMES[k]] = k
	crops.clear()
	_next_uid = int(d.get("next_uid", 1))
	for e in d.get("crops", []):
		var cid: String = e["crop_id"]
		if not defs.has(cid):
			return false
		var inst := {
			"uid": int(e["uid"]), "crop_id": cid,
			"origin": Vector2i(int(e["origin"][0]), int(e["origin"][1])),
			"footprint": defs[cid]["footprint"],
			"growth_days": int(e["growth_days"]), "regrow_days": int(e["regrow_days"]),
			"harvest_count": int(e["harvest_count"]),
			"state": int(by_name.get(e["state"], CropState.GROWING)),
		}
		crops[int(inst["uid"])] = inst
	crops_changed.emit()
	return true
