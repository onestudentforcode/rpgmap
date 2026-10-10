extends RefCounted
signal changed()
const EVENTS := ["select", "till", "plant", "grow", "harvest", "trade", "feed"]
const HINTS := [
	"选择工具：点击下方锄头。左键作用于鼠标格，不需要控制人物。",
	"开垦：用锄头点击一格荒地。普通工具单格操作，高级档需从M工具页购买。",
	"播种：下方选择凝露草，再点击空耕地。每株消耗一份对应种子。",
	"生长：点击休息结束当天。AP用完也会自动过日；每日结束自动保存，饱食度减1。",
	"采收：继续经营或休息，出现金色成熟标记后点击植株采收。凝露草约需4天。",
	"集市：点击行囊/集市，出售收获或购入种子。交易不扣AP，元石用于再生产。",
	"喂养：饱食度为0时在喂养页用木属性食材喂一餐恢复6。现在可继续自由经营，无需强制休息。"
]
var data := fresh()

static func fresh() -> Dictionary: return {"step": 0, "skipped": false}

static func valid(value) -> bool:
	if not value is Dictionary or not value.get("skipped") is bool: return false
	var step = value.get("step")
	return (step is int or step is float) and is_finite(float(step)) and step == floor(float(step)) and step >= 0 and step <= EVENTS.size()

func active() -> bool: return not data["skipped"] and int(data["step"]) < EVENTS.size()

func observe(event: String) -> void:
	if active() and EVENTS[int(data["step"])] == event:
		data["step"] = int(data["step"]) + 1
		changed.emit()

func skip() -> void:
	data["skipped"] = true
	changed.emit()

func restart() -> void:
	data = fresh()
	changed.emit()

func traded(_id: String, _quantity: int, buying: bool, _amount: int, kind: String) -> void:
	if (buying and kind == "seed") or not buying: observe("trade")

func fed(_id: String, _quantity: int) -> void: observe("feed")

func planted(_id: String) -> void: observe("plant")

func harvested(_id: String, _products: Array) -> void: observe("harvest")

func cultivated(_cell: Vector2i) -> void: observe("till")
