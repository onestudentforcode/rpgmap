extends RefCounted
## 作物渲染（phase-02 §6）：实例 ↔ Sprite2D 同步（YSort 层、底部中心锚点=脚印底边
## 总宽中心、独立接触阴影贴片）。状态→贴图按命名契约
## assets/farming/crops/<crop_id>/stage_<i>|stage_harvested|stage_exhausted.png；
## 贴图缺失时隐藏不崩（素材替换契约：逻辑零像素依赖）。
## 消费方以 preload 引用。

const LandGrid := preload("res://scripts/farming/core/grid/land_grid.gd")
const CropManager := preload("res://scripts/farming/core/crops/crop_manager.gd")

const TILE := 64

var _root: Node2D            # YSort 容器
var _mgr                     # CropManager 实例
var _sprites: Dictionary = {}  # uid -> Sprite2D
var _tex_cache: Dictionary = {}
var _shadow_tex: Texture2D


func build(ysort: Node2D, mgr) -> void:
	_root = ysort
	_mgr = mgr
	_shadow_tex = _try_load("res://assets/farming/crops/_placeholder/shadow_ellipse.png")
	mgr.crops_changed.connect(sync_all)
	sync_all()


func sync_all() -> void:
	var alive := {}
	for uid in _mgr.crops:
		alive[uid] = true
		_sync_one(_mgr.crops[uid])
	for uid in _sprites.keys():
		if not alive.has(uid):
			_sprites[uid].queue_free()
			_sprites.erase(uid)


func sprite_count() -> int:
	return _sprites.size()


func _sync_one(inst: Dictionary) -> void:
	var uid := int(inst["uid"])
	var s: Sprite2D = _sprites.get(uid)
	if s == null:
		s = Sprite2D.new()
		s.name = "Crop_%d" % uid
		_root.add_child(s)
		if _shadow_tex != null:
			var sh := Sprite2D.new()
			sh.texture = _shadow_tex
			sh.position = Vector2(0.0, -4.0)
			sh.z_index = -1  # 接触阴影独立贴片，垫在植株下
			s.add_child(sh)
		_sprites[uid] = s
	var f: Array = inst["footprint"]
	var o: Vector2i = inst["origin"]
	s.position = Vector2((o.x + int(f[0]) * 0.5) * TILE, (o.y + int(f[1])) * TILE)
	var tex := _tex_for(inst)
	if tex != null:
		s.texture = tex
		s.offset = Vector2(0.0, -tex.get_height() * 0.5)  # 底部中心锚点
		s.visible = true
	else:
		s.visible = false  # 占位图缺失：隐藏但逻辑照常


func _tex_for(inst: Dictionary) -> Texture2D:
	var cid: String = inst["crop_id"]
	var def: Dictionary = _mgr.def_of(cid)
	var stages: Array = def.get("growth_stages", [])
	var key := ""
	match int(inst["state"]):
		CropManager.CropState.MATURE:
			key = String(stages[stages.size() - 1]["sprite"])
		CropManager.CropState.REGROWING:
			key = "stage_harvested"
		CropManager.CropState.EXHAUSTED:
			key = "stage_exhausted"
		_:
			key = String(stages[clampi(_mgr.stage_index(inst), 0, stages.size() - 1)]["sprite"])
	var path := "res://assets/farming/crops/%s/%s.png" % [cid, key]
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex := _try_load(path)
	# 回退链：专用态缺失 → 成熟图 → 首阶段图（保证任何配置都能显示）
	if tex == null and (key == "stage_harvested" or key == "stage_exhausted"):
		var fallback := String(stages[stages.size() - 1]["sprite"])
		if key == "stage_exhausted":
			fallback = String(stages[0]["sprite"])
		tex = _try_load("res://assets/farming/crops/%s/%s.png" % [cid, fallback])
	if tex != null:
		_tex_cache[path] = tex
	return tex


func _try_load(path: String) -> Texture2D:
	if OS.has_feature("farm_demo_release"):
		return load(path) as Texture2D if ResourceLoader.exists(path) else null
	if not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK: return null
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)
