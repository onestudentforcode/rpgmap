extends RefCounted
## 土地模型（phase-01 §2.3）：静态地形 + 动态农业状态 + 多格占用。
## 纯逻辑，零渲染/资源依赖——素材替换零影响（phase-01 §2.6 契约）。
## 消费方以 preload 引用（不依赖全局类缓存，headless/CLI 可直接运行）。
##
## 状态迁移（本阶段）：
##   WILD → TILLED（开垦）｜TILLED → WILD（恢复）
##   可用格 → OCCUPIED（原子多格占用，记 prev）｜OCCUPIED → prev（释放）
## PLANTED 为 Phase 2 预埋，本阶段不产生（占用判定预留拒绝）。
##
## 变更通知：cells_changed(cells) 携带「变更格 ∪ 8 邻」（去重），
## 渲染层据此增量更新，禁止整图重建。

signal cells_changed(cells: Array[Vector2i])

enum State { WILD, TILLED, PLANTED, OCCUPIED, UNAVAILABLE }

const STATE_NAMES := {
	State.WILD: "WILD",
	State.TILLED: "TILLED",
	State.PLANTED: "PLANTED",
	State.OCCUPIED: "OCCUPIED",
	State.UNAVAILABLE: "UNAVAILABLE",
}

## 位序与 tools/farming/gen_* 的 BITS 一致：N,E,S,W,NE,SE,SW,NW
const DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
	Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1),
]
const DIR_BITS: Array[int] = [1, 2, 4, 8, 16, 32, 64, 128]

var width := 0
var height := 0
var terrain: Array = []         # [y][x] -> terrain_id（静态，来自烘焙地图）
var _state: Array = []          # [y][x] -> State
var _tillable: Dictionary = {}  # terrain_id -> bool（注册表快照）
var _prev: Dictionary = {}      # Vector2i -> State（占用前状态）
var _holders: Dictionary = {}   # holder -> {origin,fw,fh,cells}


func setup(w: int, h: int, terrain_grid: Array, tillable_map: Dictionary) -> void:
	width = w
	height = h
	terrain = terrain_grid
	_tillable = tillable_map
	_state = []
	for y in range(h):
		var row := []
		for x in range(w):
			row.append(State.UNAVAILABLE if not tillable_map.get(terrain_grid[y][x], false) else State.WILD)
		_state.append(row)


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func terrain_at(cell: Vector2i) -> String:
	return terrain[cell.y][cell.x]


func state_at(cell: Vector2i) -> int:
	return _state[cell.y][cell.x]


func default_state_at(cell: Vector2i) -> int:
	return State.UNAVAILABLE if not _tillable.get(terrain_at(cell), false) else State.WILD


func is_terrain_tillable(cell: Vector2i) -> bool:
	return _tillable.get(terrain_at(cell), false)


## 8 邻位掩码：pred.call(x, y) 为真的方向置位（渲染层按层传入判定）。
func bitmask_if(cell: Vector2i, pred: Callable) -> int:
	var b := 0
	for i in DIRS.size():
		var n: Vector2i = cell + DIRS[i]
		if in_bounds(n.x, n.y) and pred.call(n.x, n.y):
			b |= DIR_BITS[i]
	return b


# ------------------------------------------------------------ 开垦 / 恢复

func can_till(cell: Vector2i) -> Dictionary:
	if not in_bounds(cell.x, cell.y):
		return {"ok": false, "reason": "out_of_bounds"}
	if not is_terrain_tillable(cell):
		return {"ok": false, "reason": "terrain_not_tillable:" + terrain_at(cell)}
	var st := state_at(cell)
	if st == State.OCCUPIED:
		return {"ok": false, "reason": "occupied"}
	if st == State.PLANTED:
		return {"ok": false, "reason": "planted"}
	if st != State.WILD:
		return {"ok": false, "reason": "not_wild:" + STATE_NAMES[st]}
	return {"ok": true, "reason": ""}


func till(cell: Vector2i) -> Dictionary:
	var chk := can_till(cell)
	if not chk["ok"]:
		return chk
	_state[cell.y][cell.x] = State.TILLED
	_emit_around([cell])
	return chk


func untill(cell: Vector2i) -> Dictionary:
	if not in_bounds(cell.x, cell.y):
		return {"ok": false, "reason": "out_of_bounds"}
	if state_at(cell) != State.TILLED:
		return {"ok": false, "reason": "not_tilled:" + STATE_NAMES[state_at(cell)]}
	_state[cell.y][cell.x] = State.WILD
	_emit_around([cell])
	return {"ok": true, "reason": ""}


# ------------------------------------------------------------ 占用（多格原子）

func reserve(origin: Vector2i, fw: int, fh: int, holder: String) -> Dictionary:
	if _holders.has(holder):
		return {"ok": false, "reason": "holder_exists"}
	if fw <= 0 or fh <= 0:
		return {"ok": false, "reason": "bad_footprint"}
	var cells: Array[Vector2i] = []
	for dy in range(fh):
		for dx in range(fw):
			var c := origin + Vector2i(dx, dy)
			if not in_bounds(c.x, c.y):
				return {"ok": false, "reason": "out_of_bounds"}  # 原子：先全查
			var st := state_at(c)
			if st == State.OCCUPIED:
				return {"ok": false, "reason": "occupied"}
			if st == State.UNAVAILABLE:
				return {"ok": false, "reason": "terrain_not_tillable:" + terrain_at(c)}
			if st == State.PLANTED:
				return {"ok": false, "reason": "planted"}
			cells.append(c)
	for c in cells:  # 后落：全部合法才整体生效
		_prev[c] = _state[c.y][c.x]
		_state[c.y][c.x] = State.OCCUPIED
	_holders[holder] = {"origin": origin, "fw": fw, "fh": fh, "cells": cells}
	_emit_around(cells)
	return {"ok": true, "reason": ""}


func release(holder: String) -> bool:
	if not _holders.has(holder):
		return false
	var cells: Array[Vector2i] = _holders[holder]["cells"]
	for c in cells:
		_state[c.y][c.x] = _prev.get(c, State.WILD)
		_prev.erase(c)
	_holders.erase(holder)
	_emit_around(cells)
	return true


func holder_cells(holder: String) -> Array:
	if not _holders.has(holder):
		return []
	return _holders[holder]["cells"]


func occupied_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for h in _holders:
		out.append_array(_holders[h]["cells"])
	return out


func cells_with_state(s: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			if _state[y][x] == s:
				out.append(Vector2i(x, y))
	return out


# ------------------------------------------------------------ 存档（逻辑数据 only）

func to_save() -> Dictionary:
	var name_of := func(st: int) -> String: return STATE_NAMES[st]
	var cells := []
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			var st := state_at(cell)
			if st == default_state_at(cell):
				continue
			var e := {"x": x, "y": y, "s": name_of.call(st)}
			if st == State.OCCUPIED:
				e["p"] = name_of.call(_prev.get(cell, State.WILD))
			cells.append(e)
	var holders := {}
	for h in _holders:
		var r: Dictionary = _holders[h]
		holders[h] = {"o": [r["origin"].x, r["origin"].y], "f": [r["fw"], r["fh"]]}
	return {"schema": 1, "cells": cells, "holders": holders}


func apply_save(data: Dictionary) -> bool:
	if data.get("schema") != 1:
		return false
	var by_name := {}
	for k in STATE_NAMES:
		by_name[STATE_NAMES[k]] = k
	reset()
	for e in data.get("cells", []):
		var cell := Vector2i(int(e["x"]), int(e["y"]))
		if not in_bounds(cell.x, cell.y) or not by_name.has(e["s"]):
			return false
		var st: int = by_name[e["s"]]
		_state[cell.y][cell.x] = st
		if st == State.OCCUPIED:
			_prev[cell] = by_name.get(e.get("p", "WILD"), State.WILD)
	for h in data.get("holders", {}):
		var meta: Dictionary = data["holders"][h]
		var origin := Vector2i(int(meta["o"][0]), int(meta["o"][1]))
		var fw := int(meta["f"][0])
		var fh := int(meta["f"][1])
		var cells: Array[Vector2i] = []
		for dy in range(fh):
			for dx in range(fw):
				cells.append(origin + Vector2i(dx, dy))
		_holders[h] = {"origin": origin, "fw": fw, "fh": fh, "cells": cells}
	return true


## 复位到「按地图默认」（首次进入 / 读档前）。
func reset() -> void:
	for y in range(height):
		for x in range(width):
			_state[y][x] = default_state_at(Vector2i(x, y))
	_prev.clear()
	_holders.clear()


# ------------------------------------------------------------ 变更通知

func _emit_around(cells: Array[Vector2i]) -> void:
	var seen := {}
	var affected: Array[Vector2i] = []
	for c in cells:
		for dc in [Vector2i.ZERO] + DIRS:
			var n: Vector2i = c + dc
			if in_bounds(n.x, n.y) and not seen.has(n):
				seen[n] = true
				affected.append(n)
	cells_changed.emit(affected)
