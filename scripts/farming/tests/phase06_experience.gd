extends RefCounted
const Snapshot := preload("res://scripts/farming/core/storage/farm_snapshot.gd")
const Settings := preload("res://scripts/farming/core/storage/farm_settings.gd")
var completed := false

func check(ok: bool, message: String, fails: Array[String]) -> void:
	if ok: print("[ok] P6.e: " + message)
	else: fails.append("P6.e: " + message)

func button(node: Node, text: String):
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found = button(child,text)
		if found != null: return found
	return null

func run(tree: SceneTree) -> Array[String]:
	var fails: Array[String] = []
	var directory := "user://farm_phase06_experience_tests_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var preferences := Settings.new(directory + "/settings.cfg")
	check(preferences.load_settings() and preferences.data == Settings.defaults(),"无设置文件使用默认值，不生成游戏存档",fails)
	var desired := {"fullscreen": true,"resolution": 2,"frame_mode": "120","show_fps": true,"volume": 20}
	check(preferences.save_settings(desired)["ok"],"有效显示设置可保存",fails)
	var restarted := Settings.new(preferences.path)
	check(restarted.load_settings() and restarted.data == desired,"模拟重启恢复全屏、窗口尺寸、帧率和FPS偏好",fails)
	var original := FileAccess.get_file_as_string(preferences.path)
	var bad := desired.duplicate()
	bad["resolution"] = 99
	check(not preferences.save_settings(bad)["ok"] and FileAccess.get_file_as_string(preferences.path) == original,"非法设置拒绝且原文件不变",fails)
	bad = desired.duplicate()
	bad["frame_mode"] = "garbage"
	check(not Settings.valid(bad),"未知帧率模式拒绝",fails)
	var blocked := Settings.new(directory + "/missing/subdir/settings.cfg")
	check(not blocked.save_settings(desired)["ok"] and blocked.data == Settings.defaults(),"写入失败不改变活设置",fails)
	check(preferences.save_settings(Settings.defaults())["ok"] and preferences.save_settings(desired)["ok"],"多次替换设置保留可读主文件与备份",fails)
	var corrupt := Settings.new(directory+"/corrupt.cfg")
	var file := FileAccess.open(corrupt.path,FileAccess.WRITE)
	file.store_string("broken config")
	file.close()
	check(not corrupt.load_settings() and not corrupt.warning.is_empty() and corrupt.data == Settings.defaults(),"损坏设置明确告警并使用默认显示",fails)
	var shell = load("res://scripts/farming/rendering/farm_demo.gd").new()
	shell.store = load("res://scripts/farming/core/storage/farm_slot_store.gd").new(directory+"/slots")
	shell.settings = preferences
	shell.legacy_path = directory+"/absent.json"
	tree.root.add_child(shell)
	button(shell._surface,"设置").pressed.emit()
	check(shell._screen == "settings" and shell._settings_draft == desired,"主菜单设置入口可用并展示当前全局值",fails)
	shell._box.get_child(5).button_pressed = false
	button(shell._surface,"应用并保存").pressed.emit()
	check(not shell.settings.data["show_fps"] and not shell._fps.visible,"设置页实际应用按钮保存偏好并更新FPS显示",fails)
	shell._box.get_child(5).button_pressed = true
	button(shell._surface,"应用并保存").pressed.emit()
	shell._start_slot("new",1,false)
	await tree.process_frame
	var farm = shell.farm
	check(farm.tutorial.active() and farm.tutorial.data["step"] == 0 and farm._tutorial_panel.visible and not shell.is_modal(),"新档教学可见且不锁住自由经营",fails)
	var before: Dictionary = farm.capture_snapshot()
	farm._act_on(Vector2i(-1,-1))
	check(farm.tutorial.data["step"] == 0 and farm.capture_snapshot() == before,"失败农事不推进教学",fails)
	farm._tool_buttons[0].pressed.emit()
	check(farm.tutorial.data["step"] == 1,"鼠标选择锄头推进工具教学",fails)
	farm._act_on(Vector2i(1,1))
	check(farm.tutorial.data["step"] == 2,"成功开垦推进、没有自动开地或奖励",fails)
	farm._crop_choice.item_selected.emit(0)
	farm._act_on(Vector2i(1,1))
	check(farm.tutorial.data["step"] == 3 and farm.inventory.count("dew_grass_seed") == 9,"鼠标选种和实际播种推进、按正常成本扣种",fails)
	button(farm,"休息 R").pressed.emit()
	check(farm.tutorial.data["step"] == 4 and shell.store.read_slot(1)["snapshot"]["tutorial"]["step"] == 4,"鼠标休息推进生长教学，日存档包含最新步骤",fails)
	var baseline: Dictionary = farm.capture_snapshot()
	shell._show_help()
	button(shell._surface,"重看新手教学").pressed.emit()
	check(farm.tutorial.data["step"] == 0 and not shell.is_modal() and farm.inventory.to_save() == baseline["inventory"] and farm.economy.to_save() == baseline["economy"],"帮助重看仅重置教学、不赠物或扣资源",fails)
	button(farm,"跳过教学").pressed.emit()
	check(not farm.tutorial.active() and not farm._tutorial_panel.visible,"提示栏可用鼠标跳过，恢复地图区域",fails)
	shell.request_exit("menu")
	shell.choose_exit("discard")
	shell._start_slot("continue",1,false)
	await tree.process_frame
	farm = shell.farm
	check(farm.tutorial.data["step"] == 4 and not farm.tutorial.data["skipped"],"放弃当天同步回退教学，继续恢复日存档步骤",fails)
	for day in range(3): button(farm,"休息 R").pressed.emit()
	farm._act_on(Vector2i(1,1))
	check(farm.tutorial.data["step"] == 5,"成熟后实际采收推进教学",fails)
	button(farm,"行囊 / 集市 M").pressed.emit()
	farm.economy_panel.select_tab(1)
	button(farm.economy_panel,"出售×1 · 8元石").pressed.emit()
	check(farm.tutorial.data["step"] == 6,"面板真实出售推进经济教学",fails)
	farm.economy_panel.hide()
	var step_before: int = farm.tutorial.data["step"]
	farm.economy.feed("dew_leaf")
	check(farm.tutorial.data["step"] == step_before,"未饥饿或缺食材喂养失败不推进",fails)
	farm._crop_choice.item_selected.emit(0)
	farm._act_on(Vector2i(1,1))
	for day in range(4): button(farm,"休息 R").pressed.emit()
	farm._act_on(Vector2i(1,1))
	farm.economy_panel.select_tab(2)
	farm.economy_panel.show()
	button(farm.economy_panel,"喂一餐 · 1份").pressed.emit()
	check(farm.tutorial.data["step"] == 7 and not farm._tutorial_panel.visible and farm.economy.gu["satiety"] == 6,"鼠标完成饥饿喂养后结束教学，不强制额外任务",fails)
	farm.economy_panel.hide()
	button(farm,"休息 R").pressed.emit()
	var persisted: Dictionary = shell.store.read_slot(1)["snapshot"]
	check(persisted["tutorial"]["step"] == 7 and not persisted.has("settings"),"教学随槽保存、全局设置不混入槽",fails)
	shell.show_settings()
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_ESCAPE
	shell._unhandled_input(key)
	shell._unhandled_input(key)
	check(not shell.is_modal() and farm._cam_ctrl.is_processing(),"Esc退出设置和菜单后恢复相机输入",fails)
	var bad_snapshot: Dictionary = farm.capture_snapshot()
	bad_snapshot["tutorial"]["step"] = 8
	before = farm.capture_snapshot()
	check(not farm.apply_snapshot(bad_snapshot) and farm.capture_snapshot() == before,"非法教学步骤在修改世界前拒绝",fails)
	shell._leave("menu")
	shell._start_slot("new",2,false)
	await tree.process_frame
	check(shell.farm.tutorial.data["step"] == 0 and shell.settings.data == desired,"不同槽教学独立，设置全局共享",fails)
	shell.skip_tutorial()
	shell.farm.clock.end_day()
	shell._leave("menu")
	shell._start_slot("continue",2,false)
	await tree.process_frame
	check(shell.farm.tutorial.data["skipped"] and not shell.farm._tutorial_panel.visible,"跳过状态日存档与重载持久化",fails)
	shell._leave("menu")
	for slot in [1,2,3]: shell.store.delete_slot(slot,true)
	DirAccess.remove_absolute(directory+"/slots")
	for path in [preferences.path,preferences.path+".bak",corrupt.path]: DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(directory)
	shell.queue_free()
	await tree.process_frame
	completed = true
	return fails
