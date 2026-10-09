extends RefCounted
## 最简库存（item_id → 数量）。
## 接缝：Phase 5 换主游戏道具体系适配层（master-plan 任务 5.1），本类只做闭环验证。
## 消费方以 preload 引用。


var _items: Dictionary = {}


func setup(start_inventory: Dictionary) -> void:
	_items = {}
	for iid in start_inventory:
		var n := int(start_inventory[iid])
		if n > 0:
			_items[iid] = n


func count(item_id: String) -> int:
	return int(_items.get(item_id, 0))


func has(item_id: String, n: int = 1) -> bool:
	return count(item_id) >= n


func add(item_id: String, n: int) -> void:
	var c := count(item_id) + n
	if c > 0:
		_items[item_id] = c
	else:
		_items.erase(item_id)


func remove(item_id: String, n: int) -> bool:
	if not has(item_id, n):
		return false
	add(item_id, -n)
	return true


func entries() -> Array:
	var out := []
	for iid in _items:
		out.append({"item_id": iid, "count": int(_items[iid])})
	return out


func to_save() -> Dictionary:
	return _items.duplicate()


func apply_save(d: Dictionary) -> bool:
	_items = {}
	for iid in d:
		var n := int(d[iid])
		if n > 0:
			_items[iid] = n
	return true
