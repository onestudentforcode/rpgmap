extends RefCounted
## P10.10 动物视野叠层：可开关的地图四分区缩略图 + 地格内容支持。
## 纯显示层：不修改动物空间权重、区域承载、床位或每格逻辑容量；
## 展示槽位按稳定规则分配，不写成新的实际移动或占地规则。
const MANIFEST_PATH := "res://assets/farming/p109/runtime/animal_manifest.json"
const SLOTS_PER_CELL := 4

var shell
var enabled := true
var _manifest: Dictionary = {}
var _textures: Dictionary = {}

func _init(owner) -> void:
	shell = owner
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if parsed is Dictionary and parsed.get("species") is Dictionary:
		_manifest = parsed["species"]
	else:
		push_warning("P10.10 animal view: invalid manifest " + MANIFEST_PATH)

func _diagnose(key: String, message: String) -> void:
	push_warning("P10.10 animal view %s: %s" % [key, message])

## 稳定展示槽位：固定物种用真实锚点；游走动物按uid序在其区域地格间轮转填充。
## 返回 [{cell:Vector2i, zone_uid:int, animals:Array[int uid]}]；单格超出四只
## 时槽位照常持有全部uid（绘制层显示前四只＋计数，不隐藏个体）。
func display_slots(world) -> Array:
	if _manifest.is_empty():
		return []
	var rows: Array = world.ranch.state["animals"]
	if rows.is_empty():
		return []
	var by_cell: Dictionary = {}
	var zone_cache: Dictionary = {}
	# 固定锚点物种：先占锚点格（空锚点回退到区域首格）
	var roaming: Array = []
	for row in rows:
		var uid := int(row["uid"])
		var zone_row: Dictionary = world.ranch.zone(int(row["zone_uid"]))
		if zone_row.is_empty():
			continue
		var anchor: String = String(row.get("anchor", ""))
		var cell := Vector2i(-1, -1)
		if world.ranch.is_fixed_species(String(row["species_id"])) and not anchor.is_empty():
			var parts := anchor.split(",")
			if parts.size() == 2:
				cell = Vector2i(int(parts[0]), int(parts[1]))
		if cell.x < 0 and not zone_row["cells"].is_empty():
			if world.ranch.is_fixed_species(String(row["species_id"])):
				var first: String = zone_row["cells"][0]
				var fp := first.split(",")
				cell = Vector2i(int(fp[0]), int(fp[1]))
			else:
				roaming.append(row)
				continue
		_add_to_slot(by_cell, cell, int(zone_row["uid"]), uid)
	# 游走动物：按uid稳定排序，区域内地格按存储序、优先无设施格，四只一格轮转
	roaming.sort_custom(func(a, b): return int(a["uid"]) < int(b["uid"]))
	for row in roaming:
		var zone_uid := int(row["zone_uid"])
		if not zone_cache.has(zone_uid):
			zone_cache[zone_uid] = _zone_display_cells(world, world.ranch.zone(zone_uid))
		var cells: Array = zone_cache[zone_uid]
		if cells.is_empty():
			continue
		var placed := false
		for cell in cells:
			var key := "%d,%d" % [cell.x, cell.y]
			var current: int = by_cell[key]["animals"].size() if by_cell.has(key) else 0
			if current < SLOTS_PER_CELL:
				_add_to_slot(by_cell, cell, zone_uid, int(row["uid"]))
				placed = true
				break
		if not placed:
			# 区域地格全满：并入最后一格（计数标注），不隐藏个体
			var last: Vector2i = cells[cells.size() - 1]
			_add_to_slot(by_cell, last, zone_uid, int(row["uid"]))
	var result: Array = []
	for key in by_cell:
		result.append(by_cell[key])
	result.sort_custom(func(a, b): return a["cell"].x < b["cell"].x or (a["cell"].x == b["cell"].x and a["cell"].y < b["cell"].y))
	return result

func _zone_display_cells(world, zone_row: Dictionary) -> Array:
	var free_cells: Array = []
	var busy_cells: Array = []
	for text in zone_row["cells"]:
		var parts: String = String(text).split(",")[0]
		var coords := String(text).split(",")
		var cell := Vector2i(int(coords[0]), int(coords[1]))
		if world.facility_at(cell).is_empty():
			free_cells.append(cell)
		else:
			busy_cells.append(cell)
	free_cells.append_array(busy_cells)
	return free_cells

func _add_to_slot(by_cell: Dictionary, cell: Vector2i, zone_uid: int, uid: int) -> void:
	var key := "%d,%d" % [cell.x, cell.y]
	if not by_cell.has(key):
		by_cell[key] = {"cell": cell, "zone_uid": zone_uid, "animals": []}
	if not by_cell[key]["animals"].has(uid):
		by_cell[key]["animals"].append(uid)

## 指定地格上的展示动物uid（供地格内容列表）。
func animals_at(world, cell: Vector2i) -> Array:
	var uids: Array = []
	for slot in display_slots(world):
		if slot["cell"] == cell:
			uids.append_array(slot["animals"])
	return uids

## 覆盖该格的功能区（所属区域入口）。
func zone_at(world, cell: Vector2i) -> Dictionary:
	for zone_row in world.ranch.state["zones"]:
		for text in zone_row["cells"]:
			var coords := String(text).split(",")
			if Vector2i(int(coords[0]), int(coords[1])) == cell:
				return zone_row
	return {}

func thumbnail(species_id: String, stage: String) -> Texture2D:
	var key := "%s/%s" % [species_id, stage]
	if _textures.has(key):
		return _textures[key]
	if not _manifest.has(species_id):
		return null
	var stages: Dictionary = _manifest[species_id]["stages"]
	var meta: Dictionary = stages.get(stage, stages.get("adult", {}))
	if meta.is_empty():
		return null
	var path := String(meta["path"])
	var image := Image.new()
	var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) if FileAccess.file_exists(path) else ERR_FILE_NOT_FOUND
	if error != OK or image.is_empty():
		_diagnose(species_id, "cannot load %s (%d)" % [path, error])
		return null
	image.fix_alpha_edges()
	image.generate_mipmaps()
	_textures[key] = ImageTexture.create_from_image(image)
	return _textures[key]

## 地图叠层绘制：35°扁椭圆底盘＋四分区缩略图（保持原比例），多余个体计数标注。
func draw_overlay(world, target: Node2D, projection, readable: float) -> void:
	if not enabled or _manifest.is_empty():
		return
	var font := ThemeDB.fallback_font
	for slot in display_slots(world):
		var ground: Vector2 = Vector2(slot["cell"]) * 64.0 + Vector2(32.0, 32.0)
		var center: Vector2 = projection.ground_to_view(ground)
		var disc: PackedVector2Array = PackedVector2Array()
		for i in range(20):
			var angle := TAU * i / 20.0
			disc.append(center + Vector2(cos(angle) * 24.0, sin(angle) * 11.0) * readable)
		target.draw_colored_polygon(disc, Color(0.16, 0.20, 0.16, 0.30))
		var offsets := [Vector2(-11, -6), Vector2(11, -6), Vector2(-11, 5), Vector2(11, 5)]
		var uids: Array = slot["animals"]
		for index in range(mini(SLOTS_PER_CELL, uids.size())):
			var row: Dictionary = world.ranch.animal(int(uids[index]))
			if row.is_empty():
				continue
			var texture: Texture2D = thumbnail(String(row["species_id"]), String(row["stage"]))
			if texture == null:
				continue
			var size: Vector2 = texture.get_size()
			var height := 17.0 * readable
			var width: float = height * size.x / maxf(size.y, 1.0)
			var point: Vector2 = center + offsets[index] * readable
			target.draw_texture_rect(texture, Rect2(point - Vector2(width * 0.5, height), Vector2(width, height)), false)
		if uids.size() > SLOTS_PER_CELL:
			var badge := "+%d" % (uids.size() - SLOTS_PER_CELL)
			target.draw_string(font, center + Vector2(20.0, 14.0) * readable, badge,
				HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * readable), Color(0.95, 0.92, 0.82, 0.9))

## 个体详情页：右侧信息区呈现身份、阶段、区域/床位与状态标记（只读）。
func show_detail(world, uid: int) -> void:
	var row: Dictionary = world.ranch.animal(uid)
	if row.is_empty():
		return
	var species: Dictionary = world.husbandry.species_def(String(row["species_id"]))
	shell._page("动物 #%d" % uid)
	var card = shell._card(shell.sidebar)
	shell._heading(card, "#%d %s · %s" % [uid, String(species["name"]), "成体" if String(row["stage"]) == "adult" else "幼体"])
	var zone_row: Dictionary = world.ranch.zone(int(row["zone_uid"]))
	var zone_name := "未入区" if zone_row.is_empty() else String(zone_row["name"])
	shell._label(card, "所属区域：%s（%s）" % [zone_name, "本格为展示槽位" if not zone_row.is_empty() else ""])
	if int(row["bed_uid"]) > 0:
		shell._label(card, "床位设施#%d 槽位%d" % [int(row["bed_uid"]), int(row["bed_slot"])])
	if not String(row["anchor"]).is_empty():
		shell._label(card, "固定锚点：%s" % String(row["anchor"]))
	var fatigue: Dictionary = world.ranch.fatigue_tier(int(row["fatigue"]))
	shell._label(card, "开日疲劳%d（%s，效率%d%%）" % [int(row["fatigue"]), String(fatigue["label"]), int(fatigue["efficiency"])])
	if String(row["stage"]) == "juvenile":
		shell._label(card, "幼体成长%.2f照料单位" % (float(row["growth"]) / 100.0))
	var texture: Texture2D = thumbnail(String(row["species_id"]), String(row["stage"]))
	if texture != null:
		var preview := TextureRect.new()
		preview.texture = texture
		preview.custom_minimum_size = Vector2(96, 96)
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(preview)
	shell._button(card, "返回地格", func(): shell._show_cell())
	shell._button(card, "打开畜牧名册", func(): shell.ranch_ui.open())
