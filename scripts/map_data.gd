class_name MapData
## 全部静态游戏数据：图集区域、ASCII 地图布局、对话文案、传送注册表。
## 改地图 = 改这里的字符画；改文案 = 改 dialogues；资产替换不动本文件。

const TILE := 32

# ---- tileset.png（单行 7 块 32x32，列号即 x 坐标）----
const T_FLOOR_A := Vector2i(0, 0)  # 大厅地砖 A
const T_FLOOR_B := Vector2i(1, 0)  # 大厅地砖 B（点缀）
const T_CARPET := Vector2i(2, 0)   # 地毯
const T_CORR := Vector2i(3, 0)     # 后廊地面
const T_WALL := Vector2i(4, 0)     # 墙体（碰撞）
const T_DOOR := Vector2i(5, 0)     # 通道门洞（可行走，传送触发格）
const T_VOID := Vector2i(6, 0)     # 图外虚空（碰撞）

# ---- objects.png 图集区域 ----
const OBJ_COUNTER := Rect2(0, 0, 32, 32)
const OBJ_SHELF := Rect2(32, 0, 32, 32)
const OBJ_PLANT := Rect2(64, 0, 32, 32)
const OBJ_SIGN := Rect2(96, 0, 32, 32)
const OBJ_ELEVATOR := Rect2(128, 0, 32, 64)
const OBJ_PROMPT := Rect2(160, 0, 16, 16)
const OBJ_NPC0 := Rect2(176, 0, 32, 48)
const OBJ_NPC1 := Rect2(208, 0, 32, 48)

# 符号 → 固体物件（box 为脚底碰撞盒尺寸；npc=true 时播放两帧待机）
const SOLID_OBJECTS := {
	"C": {"region": OBJ_COUNTER, "box": Vector2(30, 14)},
	"S": {"region": OBJ_SHELF, "box": Vector2(30, 14)},
	"P": {"region": OBJ_PLANT, "box": Vector2(22, 12)},
	"i": {"region": OBJ_SIGN, "box": Vector2(20, 12)},
	"N": {"region": OBJ_NPC0, "npc": true, "box": Vector2(20, 12)},
	"n": {"region": OBJ_NPC0, "npc": true, "box": Vector2(20, 12)},
}

# ---- ASCII 地图 ----
# 图例：# 墙 | . 默认地面 | , 地面点缀 | ~ 地毯 | D 门洞(传送) | E 电梯(墙面)
#       C 柜台 | S 货架 | P 盆栽 | i 告示牌 | N/n NPC —— 固体物件均不可穿过
const MAPS := {
	"lobby": {
		"name": "西西弗百货・一层大厅",
		"spawn": Vector2i(2, 8),
		"spawn_face": "down",
		"floor_tiles": {".": T_FLOOR_A, ",": T_FLOOR_B, "~": T_CARPET},
		"layout": [
			"########################",
			"#..P........P..........#",
			"#.SSS....SSSS....SSS...#",
			"#......................#",
			"#......................#",
			"#.........CCCC.........#",
			"#.........,,,,N........#",
			"#..................~~..D",
			"#...i..............~~..D",
			"#..................~~..#",
			"#......................#",
			"#....P............P....#",
			"#........CCC...........#",
			"#......................#",
			"#......................#",
			"########################",
		],
		"dialogues": {
			"i": {
				"name": "一层导览牌",
				"pages": [
					"「西西弗百货・一层导览」",
					"运动服饰、家居杂货、餐饮特惠——本层应有尽有。",
					"友情提示：二层以上区域施工中，暂停开放。电梯位于东侧后廊。",
				],
			},
			"C": {
				"name": "收银台",
				"pages": [
					"收银台。台面上摆着一部老式电话，和一叠手写票据。",
					"票据的抬头都是同一家公司。日期栏里盖着的红章已经褪色：『长期有效』。",
				],
			},
			"S": {
				"name": "货架",
				"pages": [
					"货架。商品码放得整整齐齐，价格标签全是手写的。",
					"大部分标签上写着同一个词：『特价』。",
				],
			},
			"N": {
				"name": "百货店员",
				"pages": [
					"欢迎光临西西弗百货！今天全部商品参加『永远促销』活动——买一件，送一件的购物欲。",
					"您问电梯？穿过大厅东侧的门，沿走廊走到头就是。",
					"不过它已经『检修中』很久了。别担心，在西西弗，等待也是一种消费。",
				],
			},
		},
	},
	"corridor": {
		"name": "西西弗百货・一层后廊",
		"spawn": Vector2i(2, 5),
		"spawn_face": "down",
		"floor_tiles": {".": T_CORR, ",": T_FLOOR_B, "~": T_CARPET},
		"layout": [
			"####################",
			"############E#######",
			"#..................#",
			"#..................#",
			"#..................#",
			"D~~~~~~~~..........#",
			"D~~~~~~~~..........#",
			"#..................#",
			"#.....i............#",
			"#..............n...#",
			"#..................#",
			"####################",
		],
		"dialogues": {
			"i": {
				"name": "后廊告示",
				"pages": [
					"后廊安全守则・第一条：保持安静，不要惊动楼层。",
					"第二条：如果电梯门自己开了，请不要进去。",
					"第三条被撕掉了。撕口很新。",
				],
			},
			"E": {
				"name": "电梯",
				"pages": [
					"电梯门紧闭。按钮旁贴着一张手写告示：『检修中』。",
					"告示纸已经泛黄卷边，看起来这份『检修』相当彻底。",
					"门口的指示灯亮着红色，像是有什么东西在门后耐心地等着。",
				],
			},
			"n": {
				"name": "保洁员",
				"pages": [
					"保洁员慢悠悠地擦着墙，头也没抬。",
					"『地是干净的，路是绕的。走多了——总会到的。』",
				],
			},
		},
	},
}

# ---- 传送注册表：地图 → 触发格 → {目标图, 出生格, 出生朝向} ----
# 空间连贯：大厅东门(x=23) ↔ 后廊西门(x=0)，行号对应；出生格在门内侧一格，避免来回触发。
const TRANSITIONS := {
	"lobby": {
		Vector2i(23, 7): {"to": "corridor", "spawn": Vector2i(1, 5), "face": "right"},
		Vector2i(23, 8): {"to": "corridor", "spawn": Vector2i(1, 6), "face": "right"},
	},
	"corridor": {
		Vector2i(0, 5): {"to": "lobby", "spawn": Vector2i(22, 7), "face": "left"},
		Vector2i(0, 6): {"to": "lobby", "spawn": Vector2i(22, 8), "face": "left"},
	},
}


static func map_size(map_id: String) -> Vector2i:
	var layout: Array = MAPS[map_id]["layout"]
	return Vector2i((layout[0] as String).length(), layout.size())
