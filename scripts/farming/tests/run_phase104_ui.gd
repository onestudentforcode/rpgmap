extends "res://scripts/farming/tests/run_phase102_ui.gd"
const ServiceModel=preload("res://scripts/farming/tests/run_phase104.gd")

func all_text() -> String:
	var out:=""
	for child in nodes(shell.sidebar):
		if child is Label or child is Button: out+=child.text+"\n"
	return out

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="): shots=arg.trim_prefix("--shots=")
	if not shots.is_empty(): DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shots))
	root.size=Vector2i(1400,900)
	shell=Scene.instantiate()
	var folder:="res://.art-work/p104-ui/slots-%d" % Time.get_ticks_usec()
	shell.store=Store.new(folder)
	shell.settings=shell.settings.get_script().new(folder+".cfg",0.1)
	root.add_child(shell)
	await process_frame
	shell._new(1,false)
	var model=ServiceModel.new()
	var fixture=model.service_fixture()
	check(shell.world.apply_snapshot(fixture.to_snapshot())["ok"],"UI applies strict real-service fixture")
	model.free()
	var before: Dictionary=shell.world.to_snapshot()
	for size in [Vector2i(960,540),Vector2i(1400,900),Vector2i(1920,1080)]:
		await resize_window(size)
		shell.ranch_ui.open()
		await process_frame
		check(all_text().contains("二级") and all_text().contains("三级畜牧系统"),"tier explanations visible")
		check(button("卸下藤球")!=null and button("提交组合")!=null,"toy and explicit-system actions exposed")
		check(shell.window_panel.get_global_rect().end.y<=size.y and shell.window_panel.size.x<=size.x,"scrolling manager fits viewport "+str(size))
		check(shell.world.to_snapshot()==before,"manager reading does not change state")
		await capture("manager-%d" % size.x)
		shell.window_scroll.scroll_vertical=100000
		await capture("system-controls-%d" % size.x)
	button("编辑组合").pressed.emit()
	check(shell.world.to_snapshot()==before,"editing system opens draft only")
	var checkbox: CheckBox=null
	for child in nodes(shell.sidebar):
		if child is CheckBox and not child.disabled: checkbox=child;break
	check(checkbox!=null,"membership checkbox reachable")
	checkbox.button_pressed=not checkbox.button_pressed
	check(shell.world.to_snapshot()==before,"membership draft has no side effects")
	button("取消编辑").pressed.emit()
	shell._close_page()
	shell.selected=Vector2i(4,9)
	shell._show_cell()
	check(button("卸下藤球")!=null,"map-selected toy station exposes item controls")
	await capture("toy-controls")
	button("卸下藤球").pressed.emit()
	check(shell.world.inventory.count("vine_ball")==1,"UI unload transfers durable item once")
	button("装入藤球").pressed.emit()
	check(shell.world.inventory.count("vine_ball")==0,"UI install removes one inventory item")
	check(shell.encyclopedia.has("rule:animal-services"),"same-source service rule is accessible")
	before=shell.world.to_snapshot()
	shell.encyclopedia.open("rule:animal-services")
	check(shell.world.to_snapshot()==before,"service encyclopedia read is pure")
	await capture("service-rule")
	shell._close_page()
	shell._fit_map()
	shell._locate(Vector2i(6,8))
	shell.camera.zoom=Vector2(2,2)
	shell.camera.force_update_scroll()
	await capture("new-stations-grounding")
	shell._locate(Vector2i(8,3))
	await capture("soothing-station-grounding")
	print("P104 UI %s (%d)" % ["OK" if failures.is_empty() else "FAIL",checks])
	quit(0 if failures.is_empty() else 1)
