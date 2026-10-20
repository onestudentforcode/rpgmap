extends RefCounted
## Uses the existing market/scrolling page. No new currency or daily merchant.
var _owner: WeakRef
var shell:
	get: return _owner.get_ref()
var batches := 1

func _init(owner) -> void: _owner = weakref(owner)

func materials(items: Dictionary) -> String:
	var parts := PackedStringArray()
	for id in items: parts.append("%s×%d" % [shell.world._items[id]["name"], int(items[id])])
	return "、".join(parts) if not parts.is_empty() else "无需额外材料"

func open() -> void:
	shell._context = "economy"
	shell._page("产业成长与以物换物")
	var economy = shell.world.progress
	shell._heading(shell.sidebar, "阶段%d · %s" % [economy.stage(), economy.stage_name()])
	shell._label(shell.sidebar, "累计成功供货%d次。各产业房间独立发展，事件完成后永久开放后续内容。" % economy.deliveries())
	var quote: Dictionary = economy.event_quote()
	var card: VBoxContainer = shell._card(shell.sidebar)
	if quote.has("id"):
		shell._heading(card, "下一事件 · " + String(quote["name"]))
		if int(quote["orders"]) > 0:
			shell._label(card, "累计供货%d/%d次；不再扣除已交付货物。" % [int(quote["completed_orders"]), int(quote["orders"])])
		else:
			shell._label(card, "提交：" + materials(quote["inputs"]))
			shell._label(card, "允许交付换来的材料，不要求建设所有产业。")
		var button: Button = shell._button(card, "完成阶段事件", func():
			shell._result(economy.complete_event(quote["id"]))
			open())
		button.disabled = not quote["ok"]
		button.set_meta("p107_event", quote["id"])
		if not quote["ok"]: shell._label(card, String(quote["reason"]))
	else:
		shell._heading(card, "产业进阶已完成")
		shell._label(card, "继续扩大生产、供应关键材料，按喜好选择产业。")
	shell._heading(shell.sidebar, "常驻交换")
	shell._label(shell.sidebar, "固定比例，随阶段开放；不收元石，不耗AP，不限每日次数。交换不计供货次数。")
	var selector := OptionButton.new()
	selector.name = "ExchangeBatchCount"
	for n in [1, 5, 10, 50]:
		selector.add_item("每次兑换%d批" % n)
		selector.set_item_metadata(selector.item_count - 1, n)
		if n == batches: selector.select(selector.item_count - 1)
	selector.item_selected.connect(func(index):
		batches = int(selector.get_item_metadata(index))
		open())
	shell.sidebar.add_child(selector)
	for row in economy.config["offers"]:
		var offer_id: String = row["id"]
		var offer_quote: Dictionary = economy.exchange_quote(offer_id, batches)
		var exchange_card: VBoxContainer = shell._card(shell.sidebar)
		shell._label(exchange_card, materials(offer_quote["give"]) + "\n↓\n" + materials(offer_quote["receive"]))
		var stock := PackedStringArray()
		for id in offer_quote["give"]: stock.append("%s现有%d" % [shell.world._items[id]["name"], shell.world.inventory.count(id)])
		shell._label(exchange_card, "、".join(stock))
		var exchange: Button = shell._button(exchange_card, "交换", func():
			shell._result(economy.exchange(offer_id, batches))
			open())
		exchange.set_meta("p107_offer", offer_id)
		exchange.disabled = not offer_quote["ok"]
		if not offer_quote["ok"]: shell._label(exchange_card, String(offer_quote["reason"]))
