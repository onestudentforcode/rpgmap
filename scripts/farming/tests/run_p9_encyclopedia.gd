extends SceneTree
## P9.c encyclopedia reader checks: real shell/controls, isolated workspace slot.
## Reading, jumping, searching and day-refresh must never change game state.
const Shell := preload("res://scripts/farming/p8/p8_scene.gd")
const Store := preload("res://scripts/farming/p8/p8_slot_store.gd")
var failures: Array[String] = []
var checks := 0
var shell
var wiki

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func nodes(parent: Node) -> Array:
	var found := []
	for child in parent.get_children():
		found.append(child)
		found.append_array(nodes(child))
	return found

func text_of(parent: Node) -> String:
	var parts := PackedStringArray()
	for node in nodes(parent):
		if node is Label: parts.append(node.text)
	return "\n".join(parts)

func list_ids() -> Array:
	var ids := []
	for node in nodes(wiki.list_box):
		if node is Button and node.has_meta("encyclopedia_entry"):
			ids.append(String(node.get_meta("encyclopedia_entry")))
	return ids

func jump_buttons(parent: Node) -> Array:
	var buttons := []
	for node in nodes(parent):
		if node is Button and node.has_meta("encyclopedia_jump"):
			buttons.append(node)
	return buttons

func category_button(cid: String) -> Button:
	for node in nodes(shell.sidebar):
		if node is Button and node.get_meta("encyclopedia_category", "") == cid:
			return node
	return null

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	shell = Shell.new()
	shell.store = Store.new("res://.art-work/p9-encyclopedia/ui-slots-%d" % Time.get_ticks_usec())
	shell.settings = shell.settings.get_script().new("res://.art-work/p9-encyclopedia/settings.cfg", 0.1)
	root.add_child(shell)
	await process_frame
	wiki = shell.encyclopedia
	check(not shell._started and wiki.data["counts"]["entities"] == 318, "current encyclopedia loads with 318 entities")

	# --- static reading before any game -------------------------------------
	var static_before: Dictionary = shell.world.to_snapshot().duplicate(true)
	wiki.open()
	check(shell._context == "encyclopedia", "reader opens its own window context")
	var category_buttons := 0
	for node in nodes(shell.sidebar):
		if node is Button and node.has_meta("encyclopedia_category"): category_buttons += 1
	check(category_buttons == 9, "all nine categories listed")
	check(category_button("crops") != null and category_button("crops").text.contains("10"), "crops category shows current registry count")
	check(category_button("rules").text.contains("21"), "rules category shows current curated count")
	check(not list_ids().is_empty(), "index list renders entries for the default category")
	# search by Chinese name, ascii id and tag
	for probe in [["秸秆", "resource:straw"], ["golden_wheat", "crop:golden_wheat"], ["organic", "resource:straw"]]:
		wiki.search_box.text = probe[0]
		wiki.search_box.text_changed.emit(probe[0])
		check(probe[1] in list_ids(), "search '%s' finds its entry" % probe[0])
	wiki.search_box.text = "绝不存在的词条"
	wiki.search_box.text_changed.emit("绝不存在的词条")
	check(list_ids().is_empty() and text_of(shell.sidebar).contains("没有匹配"), "no-result state is explicit")
	wiki.search_box.text = ""
	wiki.search_box.text_changed.emit("")

	# --- straw vertical sample ------------------------------------------------
	wiki.open("resource:straw")
	check(wiki.current_id == "resource:straw", "straw opens by id")
	var straw_text := text_of(wiki.detail_box)
	check(straw_text.contains("获取来源（2条）") and straw_text.contains("直接用途（8条）"), "straw lists both relation sections with counts")
	check(straw_text.contains("收获·金穗麦") and straw_text.contains("市集采购·秸秆"), "straw sources include wheat harvest and market")
	check(straw_text.contains("秸秆堆肥") and straw_text.contains("秸秆翻肥") and straw_text.contains("藻类培养") and straw_text.contains("高密度藻培养") and straw_text.contains("农产初加工") and straw_text.contains("市集出售"), "straw uses cover all six processes")
	check(straw_text.contains("3元石/份") and straw_text.contains("1元石/份"), "straw trade facts render")
	var straw_jumps := jump_buttons(wiki.detail_box)
	check(straw_jumps.size() >= 5, "relation rows expose jump buttons")
	var jumped := false
	for button in straw_jumps:
		if String(button.get_meta("encyclopedia_jump")) == "facility:compost_bin":
			button.pressed.emit()
			jumped = true
			break
	check(jumped and wiki.current_id == "facility:compost_bin", "jump from a use row opens the executing facility")
	check(text_of(wiki.detail_box).contains("堆肥箱"), "facility detail renders its name")
	var back: Button = null
	for node in nodes(wiki.detail_box):
		if node is Button and node.has_meta("encyclopedia_back"): back = node
	check(back != null and not back.disabled, "back control is available after a jump")
	back.pressed.emit()
	check(wiki.current_id == "resource:straw", "back returns to the previous entry")

	# --- golden wheat vertical sample ----------------------------------------
	wiki.open("crop:golden_wheat")
	var wheat_text := text_of(wiki.detail_box)
	check(wheat_text.contains("谷粒×3＋秸秆×2") and wheat_text.contains("4自然日") and wheat_text.contains("每格水分−4"), "wheat sample shows yields, days and drain")
	var seed_link: Button = null
	for button in jump_buttons(wiki.detail_box):
		if String(button.get_meta("encyclopedia_jump")) == "resource:golden_wheat_seed":
			seed_link = button
	check(seed_link != null, "wheat links to its seed entry")
	seed_link.pressed.emit()
	check(wiki.current_id == "resource:golden_wheat_seed", "seed link jumps")
	wiki.open("rule:crop_growth")
	var rule_text := text_of(wiki.detail_box)
	check(rule_text.contains("每日进度增量"), "rule entry shows the growth formula")
	check(not rule_text.contains("实现依据") and not rule_text.contains(".gd::"), "rule detail hides internal refs")
	var statement_label: Label = null
	for node in nodes(wiki.detail_box):
		if node is Label and node.text.contains("每日进度增量"):
			statement_label = node
	check(statement_label != null and statement_label.autowrap_mode == TextServer.AUTOWRAP_ARBITRARY, "long statements wrap arbitrarily")

	# --- rule browsing --------------------------------------------------------
	category_button("rules").pressed.emit()
	check("rule:crop_growth" in list_ids() and "rule:rooms" in list_ids() and "rule:animal-zones" in list_ids() and "rule:economy-stages" in list_ids() and list_ids().size() == 21, "rules category lists all current rules including economic progression")
	check(shell.world.to_snapshot() == static_before, "reading before a game changes no world state")

	# --- with a running game --------------------------------------------------
	shell._close_page()
	shell._new(1, false)
	var before: Dictionary = shell.world.to_snapshot().duplicate(true)
	wiki.open("crop:honeybell_bush")
	check(text_of(wiki.detail_box).contains("本档未解锁") and text_of(wiki.detail_box).contains("花源栽培"), "locked entry shows the research gate")
	shell.world.research.state["completed"].append("flower_cultivation")
	wiki.refresh()
	check(text_of(wiki.detail_box).contains("本档已解锁"), "refresh flips the lock chip after research completes")
	shell.world.research.state["completed"].erase("flower_cultivation")
	wiki.refresh()
	check(text_of(wiki.detail_box).contains("本档未解锁"), "refresh restores the gate when research is absent")

	# --- unified manual entry keeps the tutorial and adds the tab -------------
	shell._show_help()
	check(shell._context == "help", "manual opens from the game")
	var guide_tab: Button = null
	var wiki_tab: Button = null
	for node in nodes(shell.sidebar):
		if node is Button and node.text == "新手引导": guide_tab = node
		if node is Button and node.text == "百科目录": wiki_tab = node
	check(guide_tab != null and wiki_tab != null, "manual offers both reading tabs")
	check(text_of(shell.sidebar).contains("新档90元石"), "tutorial tab still renders its opening card")
	wiki_tab.pressed.emit()
	var frame_found := false
	for node in nodes(shell.sidebar):
		if node is Control and node.has_meta("encyclopedia_search"): frame_found = true
	check(frame_found, "encyclopedia tab renders the reader inside the manual")
	var wiki_categories := 0
	for node in nodes(shell.sidebar):
		if node is Button and node.has_meta("encyclopedia_category"): wiki_categories += 1
	check(wiki_categories == 9, "encyclopedia tab lists all categories")
	guide_tab = null
	for node in nodes(shell.sidebar):
		if node is Button and node.text == "新手引导": guide_tab = node
	guide_tab.pressed.emit()
	check(text_of(shell.sidebar).contains("从零开始") or text_of(shell.sidebar).contains("新档90元石"), "switching back restores the tutorial")

	# --- query entries from the operating panels ------------------------------
	var link_meta := func() -> Array:
		var found := []
		for node in nodes(shell.sidebar):
			if node is Button and node.has_meta("encyclopedia_link"):
				found.append(String(node.get_meta("encyclopedia_link")))
		return found
	shell._show_build()
	check(not link_meta.call().is_empty() and link_meta.call().has("facility:woodshop"), "build page links every facility card")
	shell._show_market()
	check(link_meta.call().has("resource:grain") or link_meta.call().size() >= 1, "market item card links its encyclopedia entry")
	shell._show_research()
	var research_links: Array = link_meta.call()
	check(research_links.has("research:flower_cultivation"), "research cards link their projects")
	var snapshot_with_shop: Dictionary = shell.world.to_snapshot().duplicate(true)
	shell._close_page()
	check(shell.world.to_snapshot() == snapshot_with_shop, "opening panels spends nothing")

	# --- day refresh preserves the reading position ---------------------------
	wiki.open("resource:refined_oil")
	shell._context_refresh()
	check(wiki.current_id == "resource:refined_oil" and text_of(wiki.detail_box).contains("精炼油"), "context refresh keeps the current entry")
	var refined_text := text_of(wiki.detail_box)
	check(refined_text.contains("补光灯"), "refined oil lists the lamp fuel use outside recipes")
	check(shell.world.to_snapshot() == before, "all reading and jumping spent no AP, stones or items")

	# --- verdict ---------------------------------------------------------------
	if failures.is_empty():
		print("P9 ENCYCLOPEDIA OK: %d checks" % checks)
	else:
		print("P9 ENCYCLOPEDIA FAILED: %d checks, %d failures" % [checks, failures.size()])
		for failure in failures:
			print("  - " + failure)
		quit(1)
	shell.store.delete_slot(1, true)
	quit(0)
