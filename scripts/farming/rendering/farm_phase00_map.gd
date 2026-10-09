extends RefCounted
## Phase 0.4 验证地图：10×10 网格，草地满铺 + 泥土区块（直边/外角/内角/阶梯边/孤立泥岛）。
## 负责 master-plan §2.2 六层结构中世界侧四层：Ground / TerrainTransition / Farmland（预留）/ YSort。
## 纹理运行时直读 assets/farming/（Image.load_from_file），不走 .import——
## 占位资产可随时重新生成；Phase 3 起 AI 素材迁入导入管线时只改本文件的加载方式。
##
## 位序与 tools/farming/gen_phase00_textures.py 的 BITS 一致；置位 = 该方向邻格为泥土。

const TILE := 64
const MAP_W := 10
const MAP_H := 10
## '.' 草地  '#' 泥土；(6,8) 为孤立 1×1 泥岛（验全草邻位掩码 0）
const MAP := [
	"..........",
	"..........",
	"...####...",
	"...####...",
	"..######..",
	"...#####..",
	"....###...",
	"..........",
	"......#...",
	"..........",
]

const BIT := {
	"N": 1, "E": 2, "S": 4, "W": 8, "NE": 16, "SE": 32, "SW": 64, "NW": 128,
}


static func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < MAP_W and y < MAP_H


static func is_dirt(x: int, y: int) -> bool:
	return in_bounds(x, y) and MAP[y][x] == "#"


static func bitmask(x: int, y: int) -> int:
	var b := 0
	if is_dirt(x, y - 1): b |= BIT.N
	if is_dirt(x + 1, y): b |= BIT.E
	if is_dirt(x, y + 1): b |= BIT.S
	if is_dirt(x - 1, y): b |= BIT.W
	if is_dirt(x + 1, y - 1): b |= BIT.NE
	if is_dirt(x + 1, y + 1): b |= BIT.SE
	if is_dirt(x - 1, y + 1): b |= BIT.SW
	if is_dirt(x - 1, y - 1): b |= BIT.NW
	return b


static func atlas_of(bm: int) -> Vector2i:
	return Vector2i(bm & 15, bm >> 4)


static func cell_center(x: int, y: int) -> Vector2:
	return Vector2((x + 0.5) * TILE, (y + 0.5) * TILE)


static func cell_bottom_center(x: int, y: int) -> Vector2:
	return Vector2((x + 0.5) * TILE, (y + 1.0) * TILE)


static func world_to_cell(w: Vector2) -> Vector2i:
	return Vector2i(floori(w.x / float(TILE)), floori(w.y / float(TILE)))


static func load_texture(rel: String) -> Texture2D:
	var img := Image.load_from_file("res://" + rel)
	if img == null or img.is_empty():
		push_error("[farm] 无法加载纹理 res://" + rel + "（先运行 python tools/farming/gen_phase00_textures.py）")
		return null
	return ImageTexture.create_from_image(img)


## 构建世界侧图层，挂到 root 下；失败（纹理缺失）返回空字典。
static func build(root: Node2D) -> Dictionary:
	var grass := load_texture("assets/farming/ground/ground_grass.png")
	var trans := load_texture("assets/farming/transitions/trans_grass_dirt.png")
	if grass == null or trans == null:
		return {}

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)

	var src_grass := TileSetAtlasSource.new()
	src_grass.texture = grass
	src_grass.texture_region_size = Vector2i(TILE, TILE)
	src_grass.create_tile(Vector2i.ZERO)
	ts.add_source(src_grass, 0)

	var src_trans := TileSetAtlasSource.new()
	src_trans.texture = trans
	src_trans.texture_region_size = Vector2i(TILE, TILE)
	for row in range(16):
		for col in range(16):
			src_trans.create_tile(Vector2i(col, row))
	ts.add_source(src_trans, 1)

	# Ground：草地满铺，垫底不参与 Y-sort
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.z_index = -10
	ground.tile_set = ts
	root.add_child(ground)
	for y in range(MAP_H):
		for x in range(MAP_W):
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)

	# TerrainTransition：泥土格按 8 邻域位掩码选过渡 tile
	var transition := TileMapLayer.new()
	transition.name = "TerrainTransition"
	transition.z_index = -9
	transition.tile_set = ts
	root.add_child(transition)
	for y in range(MAP_H):
		for x in range(MAP_W):
			if is_dirt(x, y):
				transition.set_cell(Vector2i(x, y), 1, atlas_of(bitmask(x, y)))

	# Farmland：预留空层（Phase 1 耕地落位）
	var farmland := TileMapLayer.new()
	farmland.name = "Farmland"
	farmland.z_index = -8
	farmland.tile_set = ts
	root.add_child(farmland)

	# YSort：作物/物件伪深度层（Phase 0 规模小，Crop/Object 合并排序）
	var ysort := Node2D.new()
	ysort.name = "YSort"
	ysort.y_sort_enabled = true
	root.add_child(ysort)

	return {
		"ground": ground, "transition": transition, "farmland": farmland,
		"ysort": ysort, "tileset": ts,
	}
