extends Node
## Demo shell owns the slot session. Farm never selects another save target.
const Slots := preload("res://scripts/farming/core/storage/farm_slot_store.gd")
const Snapshot := preload("res://scripts/farming/core/storage/farm_snapshot.gd")
const UI := preload("res://scripts/farming/rendering/farm_ui_style.gd")
const FarmScene := preload("res://scenes/farming/farm_main.tscn")
@export var route_cli := false
var store = Slots.new()
var legacy_path := "user://farm_phase02_save.json"
var farm
var _surface: Control
var _box: VBoxContainer
var _message: Label
var _screen := "main"
var _slot_mode := "new"
var _confirmation: Callable
var _exit_destination := "menu"
var _pending_snapshot: Dictionary = {}
var _retry_destination := ""
var _last_result: Dictionary = {"ok": true}
var _report_presented := false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if route_cli and Array(args).any(func(arg): return arg in ["--farmtest", "--selftest", "--fresh"] or arg.begins_with("--shots") or arg.begins_with("--farm-shots")):
		get_tree().change_scene_to_file.call_deferred("res://scenes/farming/farm_main.tscn")
		return
	DisplayServer.window_set_title("灵田 Demo")
	get_tree().auto_accept_quit = false
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_surface = Control.new()
	_surface.size = Vector2(640,360)
	_surface.theme = UI.theme()
	layer.add_child(_surface)
	_show_main()

func _page(title: String, screen: String) -> void:
	_screen = screen
	for child in _surface.get_children():
		_surface.remove_child(child)
		child.queue_free()
	var shade := ColorRect.new()
	shade.size = Vector2(640,360)
	shade.color = UI.INK if farm == null else Color(0.04,0.08,0.05,0.75)
	_surface.add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(24,18)
	panel.custom_minimum_size = Vector2(592,324)
	_surface.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	panel.add_child(_box)
	var header := UI.label(title)
	header.add_theme_font_size_override("font_size", 18)
	_box.add_child(header)
	_message = UI.label("")
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.x = 560
	_box.add_child(_message)
	_set_modal(true)

func _button(parent: Container, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _set_modal(visible: bool) -> void:
	_surface.visible = visible
	if farm != null and is_instance_valid(farm):
		farm.refresh_camera_lock()

func is_modal() -> bool:
	return _surface != null and _surface.visible

func _show_main() -> void:
	_page("灵田 Demo", "main")
	_message.text = "自由经营四类灵植，出售收获或留作食材。每日结束自动保存。"
	_button(_box, "新游戏", _show_slots.bind("new"))
	_button(_box, "继续游戏", _show_slots.bind("continue"))
	var settings := _button(_box, "设置", _show_help)
	settings.disabled = true
	settings.tooltip_text = "显示和音量设置暂未开放"
	_button(_box, "操作说明", _show_help)
	if FileAccess.file_exists(legacy_path):
		_button(_box, "导入旧农场存档", _show_slots.bind("import"))
	_button(_box, "退出", func(): get_tree().quit())
	_box.add_child(UI.label("提示：离开农场时可结束当天保存，也可放弃当天进度。", true))

func _show_slots(mode: String) -> void:
	_slot_mode = mode
	_page({"new":"选择新游戏存档槽", "continue":"选择继续的存档槽", "import":"选择旧档导入目标槽"}[mode], "slots")
	_message.text = "三个槽独立保存。覆盖和删除均需确认。" if mode != "import" else "复制旧档，不删除源文件；不会补发资源，后续统计从导入日开始。"
	for info in store.list_slots():
		var slot := int(info["slot_id"])
		var row := HBoxContainer.new()
		_box.add_child(row)
		var description := "槽%d · 空槽" % slot
		if info["status"] == "ready":
			description = "槽%d · 第%d天 · %d元石" % [slot, int(info["total_days"])+1, info["primeval_stones"]]
		elif info["status"] == "corrupt":
			description = "槽%d · 存档损坏" % slot
		var label := UI.label(description)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var choose := _button(row, {"new":"新建", "continue":"继续", "import":"导入"}[mode], _select_slot.bind(mode,slot))
		choose.disabled = mode == "continue" and info["status"] != "ready"
		if info["status"] != "empty":
			_button(row, "删除", _confirm_delete.bind(slot))
		if info["status"] == "ready":
			var local_time := int(info["saved_at"]) + int(Time.get_time_zone_from_system()["bias"]) * 60
			_box.add_child(UI.label("最近保存：" + Time.get_datetime_string_from_unix_time(local_time).replace("T", " ")
				+ ("（从中断备份恢复）" if info.get("recovered", false) else ""), true))
		elif info["status"] == "corrupt":
			_box.add_child(UI.label(info["reason"], true))
	_button(_box, "返回", _show_main)

func _select_slot(mode: String, slot: int) -> void:
	if mode != "continue" and store.occupied(slot):
		_confirm("确认覆盖槽%d" % slot, "该槽现有进度将被替换，其他槽不受影响。", _start_slot.bind(mode,slot,true))
	else:
		_start_slot(mode,slot,false)

func _confirm(title: String, message: String, action: Callable) -> void:
	_confirmation = action
	_page(title, "confirm")
	_message.text = message
	_button(_box, "确认", _accept_confirmation)
	_button(_box, "取消", _show_slots.bind(_slot_mode))

func _accept_confirmation() -> void:
	var action := _confirmation
	_confirmation = Callable()
	if action.is_valid():
		action.call()

func _confirm_delete(slot: int) -> void:
	_confirm("删除槽%d" % slot, "删除该槽快照及备份。此操作无法撤销。", _delete_slot.bind(slot))

func _delete_slot(slot: int) -> void:
	var result: Dictionary = store.delete_slot(slot,true)
	_show_slots(_slot_mode)
	if not result["ok"]:
		_message.text = result["reason"]

func _start_slot(mode: String, slot: int, confirmed: bool) -> void:
	var result: Dictionary
	if mode == "continue":
		result = store.open_slot(slot)
	elif mode == "import":
		result = store.import_legacy(slot,legacy_path,confirmed)
	else:
		result = store.create_slot(slot,Snapshot.fresh(),confirmed)
	if not result["ok"]:
		_show_slots(mode)
		_message.text = result["reason"]
		return
	_launch(result["snapshot"])

func _launch(snapshot: Dictionary) -> void:
	_pending_snapshot = {}
	_retry_destination = ""
	_report_presented = not snapshot.get("records", {}).get("report", {}).is_empty()
	farm = FarmScene.instantiate()
	farm.demo_controller = self
	farm.demo_snapshot = snapshot
	_set_modal(false)
	add_child(farm)

func save_world(snapshot: Dictionary) -> Dictionary:
	_last_result = store.commit(snapshot)
	if _last_result["ok"]:
		_pending_snapshot = {}
		farm._flash("每日自动保存完成 · 槽%d" % store.active_slot(),true)
		if _retry_destination.is_empty():
			_offer_report()
	else:
		_pending_snapshot = snapshot.duplicate(true)
		_show_save_error()
	return _last_result

func _show_save_error() -> void:
	_page("自动保存未完成", "save_error")
	_message.text = String(_last_result.get("reason","无法保存")) + "。上一份可读存档保留；重试不会再次推进日期。"
	_button(_box,"重试本次自动保存", retry_save)
	var destination := "menu" if _retry_destination.is_empty() else _retry_destination
	_button(_box,"放弃未保存进度并退出游戏" if destination == "quit" else "放弃未保存进度并返回菜单", _leave.bind(destination))

func retry_save() -> void:
	var snapshot := _pending_snapshot.duplicate(true)
	if snapshot.is_empty():
		return
	var result := save_world(snapshot)
	if result["ok"]:
		if not _retry_destination.is_empty():
			_leave(_retry_destination)
		else:
			if _screen != "records":
				_set_modal(false)
			_offer_report()

func _offer_report() -> void:
	if not _report_presented and not farm.records.data["report"].is_empty():
		_report_presented = true
		show_records()

func show_records() -> void:
	_page("灵田 · 经营记录", "records")
	var data: Dictionary = farm.records.data
	var report: Dictionary = data["report"]
	var totals: Dictionary = data if report.is_empty() else report
	var start := int(data["start_day"]) + 1
	_message.text = "首次45天回顾 · 第%d～%d天 · 已保存，可继续经营" % [start,start+44] if not report.is_empty() else "首轮记录 · 第%d～%d天 · 已完成%d/45天" % [start,start+44,maxi(0,farm.clock.total_days-start+1)]
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 180
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var spending: Dictionary = totals["spending"]
	var net := int(totals["revenue"]) - int(spending["seed"]) - int(spending["production"]) - int(spending["tool"])
	rows.add_child(UI.label("出售收入 %d · 净收入 %d 元石" % [totals["revenue"], net]))
	rows.add_child(UI.label("支出：种子 %d · 材料 %d · 工具 %d 元石" % [spending["seed"],spending["production"],spending["tool"]]))
	rows.add_child(UI.label(("期末余额" if not report.is_empty() else "当前余额") + "：%d 元石（初始元石不计收入）" % int(totals.get("balance",farm.economy.primeval_stones))))
	rows.add_child(UI.label("种植与收获", true))
	for id in farm._crops_by_id:
		rows.add_child(UI.label("%s：播种 %d 株 · 收获 %d 次" % [farm._crop_name(id),totals["planted"].get(id,0),totals["harvests"].get(id,0)]))
	for key in ["yield", "feeding"]:
		rows.add_child(UI.label("实际产量（含返种）" if key == "yield" else "喂养材料消耗", true))
		if totals[key].is_empty(): rows.add_child(UI.label("暂无"))
		for id in totals[key]: rows.add_child(UI.label("%s × %d" % [farm._item_name(id),totals[key][id]]))
	_button(_box,"继续经营", _set_modal.bind(false))

func show_pause() -> void:
	if not _pending_snapshot.is_empty():
		_show_save_error()
		return
	_page("灵田 · 游戏菜单", "pause")
	_message.text = "当前槽%d · 当天进度将在每日结束时保存。" % store.active_slot()
	_button(_box,"继续经营", _set_modal.bind(false))
	_button(_box,"经营记录 / 首轮回顾", show_records)
	_button(_box,"操作说明", _show_help)
	_button(_box,"返回主菜单", request_exit.bind("menu"))
	_button(_box,"退出游戏", request_exit.bind("quit"))

func _show_help() -> void:
	_page("操作说明", "help")
	_message.text = "左键：开垦、播种、采收或清理\n1～4：选种子 · H：轮换锄头/播种/采收 · B：准备介质\nR：结束当天 · M：库存、集市和喂养\nWASD / 方向键：平移 · 滚轮：缩放 · Esc：菜单\n\n每天结束自动存入当前槽，不提供手动存读档。\nM中工具页购买高级档；工具栏普/高切换。高级范围3×3，成功AP合计折半取整。\n本版本暂未开放显示与音量设置。"
	_button(_box,"返回", show_pause if farm != null else _show_main)

func request_exit(destination: String) -> void:
	_exit_destination = destination
	if not _pending_snapshot.is_empty():
		_retry_destination = destination
		_show_save_error()
		return
	if farm == null:
		_leave(destination)
		return
	farm.economy_panel.hide()
	_page("离开农场", "exit")
	_message.text = "当天进度尚未保存。结束当天会推进生长与饱食度，并保存到槽%d。" % store.active_slot()
	_button(_box,"结束当天并保存离开", choose_exit.bind("save"))
	_button(_box,"放弃当天进度离开", choose_exit.bind("discard"))
	_button(_box,"取消", choose_exit.bind("cancel"))

func choose_exit(choice: String) -> void:
	if choice == "cancel":
		_set_modal(false)
	elif choice == "discard":
		_leave(_exit_destination)
	elif choice == "save":
		_retry_destination = _exit_destination
		farm.clock.end_day()
		if _last_result["ok"]:
			_leave(_exit_destination)

func _leave(destination: String) -> void:
	if farm != null:
		remove_child(farm)
		farm.queue_free()
		farm = null
	store.close_session()
	_pending_snapshot = {}
	_retry_destination = ""
	if destination == "quit":
		get_tree().quit()
	else:
		_show_main()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _surface != null:
		request_exit("quit")

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	if not is_modal():
		return # Farm handles economy-panel close before opening this menu.
	match _screen:
		"pause": _set_modal(false)
		"records": _set_modal(false)
		"exit": choose_exit("cancel")
		"help":
			if farm != null: show_pause()
			else: _show_main()
		"slots", "confirm": _show_main()
	get_viewport().set_input_as_handled()
