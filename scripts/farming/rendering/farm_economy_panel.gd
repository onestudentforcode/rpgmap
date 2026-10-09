extends PanelContainer
## Farm inventory, market and feeding UI; no domain rules in this panel.
signal changed(message: String, ok: bool)
const UI := preload("res://scripts/farming/rendering/farm_ui_style.gd")
var _farm
var _rows: VBoxContainer
var _summary: Label
var _quantity: SpinBox
var _tabs: TabBar
var _controls: HBoxContainer
var _hint: Label
var _feedback: Label
var _scroll: ScrollContainer


func build(farm) -> void:
	_farm = farm
	# The game renders at 640x360 before the window is scaled to 1280x720.
	custom_minimum_size = Vector2(608, 308)
	position = Vector2(16, 38)
	theme = UI.theme()
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := UI.label("灵田 · 行囊与集市")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "关闭 Esc"
	close.pressed.connect(hide)
	header.add_child(close)
	_summary = UI.label("")
	box.add_child(_summary)
	_tabs = TabBar.new()
	for title_text in ["库存", "集市", "喂养"]:
		_tabs.add_tab(title_text)
	box.add_child(_tabs)
	_controls = HBoxContainer.new()
	box.add_child(_controls)
	var label := UI.label("")
	label.text = "交易数量"
	label.custom_minimum_size.x = 64
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_controls.add_child(label)
	_quantity = SpinBox.new()
	_quantity.min_value = 1
	_quantity.max_value = 999
	_quantity.step = 1
	_quantity.value = 1
	_quantity.custom_minimum_size.x = 76
	_controls.add_child(_quantity)
	for amount in [1, 5, 10]:
		_button(_controls, "×%d" % amount, func(): _quantity.value = amount)
	_hint = UI.label("", true)
	box.add_child(_hint)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size.y = 150
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 4)
	_scroll.add_child(_rows)
	_feedback = UI.label("交易与喂养不消耗行动点。", true)
	box.add_child(_feedback)
	_quantity.value_changed.connect(func(_value): refresh())
	_tabs.tab_changed.connect(func(_index):
		_feedback.text = "交易与喂养不消耗行动点。"
		_scroll.scroll_vertical = 0
		refresh())
	refresh()
	hide()


func select_tab(index: int) -> void:
	_tabs.current_tab = index
	refresh()


func refresh() -> void:
	var view := _tabs.current_tab
	_controls.visible = view == 1
	_hint.text = ["种子用于播种，生产材料用于准备介质，食材可出售或喂养。",
		"按钮显示本次数量与总价。出售食材可换取新种子。",
		"饱食度为0时喂一餐恢复至6；每天与指定成功行为各减1。"][view]
	_summary.text = "元石 %d枚    |    木蛊饱食度 %d/6    |    喂养 %d次" % [
		_farm.economy.primeval_stones, _farm.economy.gu["satiety"], _farm.economy.gu["feeding_count"]]
	var scroll_position := _scroll.scroll_vertical
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for kind in (["seed", "production", "food"] if view != 2 else ["food"]):
		_rows.add_child(UI.label({"seed":"种子", "production":"生产材料", "food":"木属性食材"}[kind], true))
		for iid in _farm._items_by_id:
			var item: Dictionary = _farm._items_by_id[iid]
			if item.get("kind", "") == kind:
				_add_item(iid, item, view)
	_scroll.set_deferred("scroll_vertical", scroll_position)


func _add_item(iid: String, item: Dictionary, view: int) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.box(UI.SURFACE, UI.SURFACE))
	_rows.add_child(card)
	var row := HBoxContainer.new()
	card.add_child(row)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(details)
	details.add_child(UI.label("%s  ×%d" % [item["name"], _farm.inventory.count(iid)]))
	var detail := ""
	if item["kind"] == "food":
		detail = "木 · 营养%d/份 · 一餐%d份" % [_farm.economy.nutrition[iid], _farm.economy.feed_quantity(iid)]
	else:
		detail = "播种消耗1份" if item["kind"] == "seed" else "准备对应介质消耗1份，可重复种植"
	details.add_child(UI.label(detail, true))
	if view == 1:
		var buying := int(item.get("buy_price", 0)) > 0
		var unit := int(item["buy_price"] if buying else item["sell_price"])
		var qty := int(_quantity.value)
		var available: int = _farm.economy.primeval_stones / unit if buying else _farm.inventory.count(iid)
		var button := _button(row, "%s×%d · %d元石" % ["购入" if buying else "出售", qty, qty * unit], _trade.bind(iid, buying))
		button.disabled = available < qty
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.tooltip_text = "单价 %d元石/份" % unit
		if button.disabled:
			details.add_child(UI.label("元石不足" if buying else "库存不足", true))
	elif view == 2:
		var required: int = _farm.economy.feed_quantity(iid)
		var reason := ""
		if _farm.economy.gu["satiety"] != 0:
			reason = "尚未饥饿"
		elif _farm.inventory.count(iid) < required:
			reason = "食材不足，需%d份" % required
		var button := _button(row, "喂一餐 · %d份" % required, _feed.bind(iid))
		button.disabled = not reason.is_empty()
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.tooltip_text = reason if button.disabled else "恢复至6"
		if button.disabled:
			button.text = reason


func _button(row: Container, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	row.add_child(button)
	return button


func _trade(iid: String, buying: bool) -> void:
	var result: Dictionary = _farm.economy.trade(iid, int(_quantity.value), buying)
	refresh()
	_feedback.text = "%s%s×%d，%s%d元石" % ["购入" if buying else "出售", _farm._item_name(iid), int(_quantity.value),
		"花费" if buying else "获得", int(result.get("amount", 0))] if result["ok"] else String(result["reason"])
	_feedback.add_theme_color_override("font_color", UI.JADE if result["ok"] else UI.ERROR)
	changed.emit(_feedback.text, result["ok"])


func _feed(iid: String) -> void:
	var result: Dictionary = _farm.economy.feed(iid)
	refresh()
	_feedback.text = "消耗%s×%d，饱食度恢复至6" % [_farm._item_name(iid), int(result.get("quantity", 0))] if result["ok"] else String(result["reason"])
	_feedback.add_theme_color_override("font_color", UI.JADE if result["ok"] else UI.ERROR)
	changed.emit(_feedback.text, result["ok"])
