class_name GameState
## 演示级运行时状态：消费型交互跨图持久（进程内，重启即重置）。
## 接缝注释：正式实现应接引擎存档（写即存快照），消费时 erase/置位——
## 移植时把本类替换为快照字段读写，接口形状保持即可。

var _consumed := {}             # map_id -> { "x,y": true }
var _battle_cooldown_until := {}  # "map_id|x,y" -> Time.get_ticks_msec() 上限


func is_consumed(map_id: String, cell: Vector2i) -> bool:
	var m: Dictionary = _consumed.get(map_id, {})
	return m.has("%d,%d" % [cell.x, cell.y])


func consume(map_id: String, cell: Vector2i) -> void:
	if not _consumed.has(map_id):
		_consumed[map_id] = {}
	_consumed[map_id]["%d,%d" % [cell.x, cell.y]] = true


func map_consumed(map_id: String) -> Dictionary:
	return _consumed.get(map_id, {})


func battle_ready(map_id: String, cell: Vector2i, cooldown_s: int) -> bool:
	var key := "%s|%d,%d" % [map_id, cell.x, cell.y]
	return Time.get_ticks_msec() >= int(_battle_cooldown_until.get(key, 0))


func set_battle_cooldown(map_id: String, cell: Vector2i, cooldown_s: int) -> void:
	var key := "%s|%d,%d" % [map_id, cell.x, cell.y]
	_battle_cooldown_until[key] = Time.get_ticks_msec() + cooldown_s * 1000
