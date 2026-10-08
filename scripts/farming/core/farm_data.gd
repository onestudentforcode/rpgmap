extends RefCounted
## 烘焙产物加载（运行时唯一数据入口）。
## 纪律：禁止读 content/farming/ 源文件；改源 JSON 后先 python tools/farming/bake_farm.py。
## 消费方以 preload 引用（不依赖全局类缓存）。


const BAKED_DIR := "res://content/farming/baked"


static func load_terrains() -> Dictionary:
	return _load(BAKED_DIR + "/terrains.json")


static func load_index() -> Dictionary:
	return _load(BAKED_DIR + "/index.json")


static func load_map(map_id: String) -> Dictionary:
	return _load(BAKED_DIR + "/maps/%s.json" % map_id)


static func terrain_by_id(terrains: Dictionary) -> Dictionary:
	var out := {}
	for t in terrains.get("terrains", []):
		out[t["id"]] = t
	return out


static func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("[farm] 缺少烘焙产物 %s（先运行 python tools/farming/bake_farm.py）" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null or not (parsed is Dictionary):
		push_error("[farm] 烘焙产物解析失败: %s" % path)
		return {}
	return parsed
