extends PanelContainer
## Farm inventory, market and feeding UI; no domain rules in this panel.
signal changed(message: String, ok: bool)
var _farm
var _rows: VBoxContainer
var _summary: Label
var _quantity: SpinBox


func build(farm) -> void:
	_farm = farm
	custom_minimum_size = Vector2(660, 430)
	position = Vector2(28, 128)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	_summary = farm._make_label()
	_summary.custom_minimum_size.x = 530
	header.add_child(_summary)
	var close := Button.new()
	close.text = "关闭"
	close.pressed.connect(hide)
	header.add_child(close)
	var controls := HBoxContainer.new()
	box.add_child(controls)
	var label: Label = farm._make_label()
	label.text = "交易数量"
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	controls.add_child(label)
	_quantity = SpinBox.new()
	_quantity.min_value = 1
	_quantity.max_value = 999
	_quantity.step = 1
	_quantity.value = 1
	controls.add_child(_quantity)
	var hint: Label = farm._make_label()
	hint.text = "喂养按一餐数量扣除，仅饱食度为0时可喂。"
	box.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 310
	box.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	refresh()
	hide()


func refresh() -> void:
	_summary.text = "灵田集市 · 元石 %d枚 · 木蛊饱食度 %d/6 · 喂养 %d次" % [
		_farm.economy.primeval_stones, _farm.economy.gu["satiety"], _farm.economy.gu["feeding_count"]]
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for iid in _farm._items_by_id:
		var item: Dictionary = _farm._items_by_id[iid]
		var row := HBoxContainer.new()
		_rows.add_child(row)
		var label: Label = _farm._make_label()
		label.custom_minimum_size.x = 260
		label.text = "%s ×%d" % [item["name"], _farm.inventory.count(iid)]
		row.add_child(label)
		if int(item.get("buy_price", 0)) > 0:
			_button(row, "购入 %d元石/份" % item["buy_price"], _trade.bind(iid, true))
		if int(item.get("sell_price", 0)) > 0:
			_button(row, "出售 %d元石/份" % item["sell_price"], _trade.bind(iid, false))
		if item.get("kind", "") == "food":
			var button := _button(row, "喂养 ×%d" % _farm.economy.feed_quantity(iid), _feed.bind(iid))
			button.disabled = _farm.economy.gu["satiety"] != 0 or _farm.inventory.count(iid) < _farm.economy.feed_quantity(iid)


func _button(row: HBoxContainer, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	row.add_child(button)
	return button


func _trade(iid: String, buying: bool) -> void:
	var result: Dictionary = _farm.economy.trade(iid, int(_quantity.value), buying)
	refresh()
	changed.emit("交易完成" if result["ok"] else result["reason"], result["ok"])


func _feed(iid: String) -> void:
	var result: Dictionary = _farm.economy.feed(iid)
	refresh()
	changed.emit("喂养完成，饱食度恢复至6" if result["ok"] else result["reason"], result["ok"])
