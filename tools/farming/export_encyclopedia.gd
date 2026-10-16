extends SceneTree
## P9.d same-source manual export: renders the complete encyclopedia (the same
## baked content layer the in-game reader shows) into a Markdown document with
## a category table of contents, per-entry field tables, relation rows and the
## curated rules. --check fails when the document is stale.
const SOURCE := "res://content/farming/baked/encyclopedia/encyclopedia.json"
const TARGET := "res://docs/farming/demo-p8-百科全书.md"

var entities_by_id: Dictionary = {}

func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if data.is_empty():
		printerr("P8 ENCYCLOPEDIA DOC FAIL: baked encyclopedia missing; run bake_encyclopedia.py")
		quit(1)
		return
	for entity in data["entities"]:
		entities_by_id[String(entity["id"])] = entity
	var expected := render(data)
	if OS.get_cmdline_user_args().has("--check"):
		if not FileAccess.file_exists(TARGET) or FileAccess.get_file_as_string(TARGET).replace("\r\n", "\n") != expected:
			printerr("P8 ENCYCLOPEDIA DOC FAIL: regenerate the player document")
			quit(1)
			return
	else:
		var file := FileAccess.open(TARGET, FileAccess.WRITE)
		if file == null:
			printerr("P8 ENCYCLOPEDIA DOC FAIL: cannot write the player document")
			quit(1)
			return
		file.store_string(expected)
		file.close()
	var counts: Dictionary = data["counts"]
	print("P8 ENCYCLOPEDIA DOC OK: %d entities / %d rules" % [counts["entities"], counts["rules"]])
	quit(0)

## GitHub-style anchor: keep CJK words, ascii letters/digits, dash and
## underscore; spaces become dashes; everything else (backticks, colons,
## punctuation) is dropped.
func slug(text: String) -> String:
	var cleaned := ""
	for character in text.to_lower():
		if character == " ":
			cleaned += "-"
		elif (character >= "a" and character <= "z") or (character >= "0" and character <= "9") or character == "-" or character == "_":
			cleaned += character
		elif character.unicode_at(0) >= 0x4e00 and character.unicode_at(0) <= 0x9fff:
			cleaned += character
	return cleaned

func anchor(entity_id: String) -> String:
	var entity: Dictionary = entities_by_id[entity_id]
	return slug("%s `%s`" % [String(entity["name"]), entity_id])

func link_to(entity_id: String) -> String:
	if not entities_by_id.has(entity_id):
		return entity_id
	return "[%s](#%s)" % [String(entities_by_id[entity_id]["name"]), anchor(entity_id)]

func cell(text: String) -> String:
	return text.replace("|", "／").replace("\n", "；")

## Rules keep their statements verbatim (the pipes are content, not table
## syntax) and skip the truncated UI summary; the internal refs stay in the
## curated source, never in the player-facing document.
func render_rule(entity: Dictionary) -> String:
	var out := ""
	for field in entity.get("fields", []):
		if String(field["key"]) == "statements":
			out += "%s\n\n" % String(field["text"])
	return out

func render(data: Dictionary) -> String:
	var entities: Array = data["entities"]
	var category_title := {}
	for category in data["categories"]:
		category_title[String(category["id"])] = String(category["title"])
	var out := "# 灵田P8 · 百科全书\n\n"
	out += "本手册由 `tools/farming/export_encyclopedia.gd` 从游戏内同一份百科内容层（`content/farming/baked/encyclopedia/`）导出，与游戏内“手册 → 百科目录”阅读的内容一致；百科格式版本 %d。数值与条件以当前P8注册表为准，不混入历史版本内容。\n\n" % int(data["encyclopedia_format"])
	out += "使用提示：先按分类目录查找条目；材料页的“获取来源/直接用途”逐条给出数量、执行设施或物种、研究门槛、时间与AP，链接可跳到对应条目。以下易混淆口径在“基础玩法”规则中有完整说明：完工与成熟不等于入仓；成熟待收作物照常扣水肥；缺水低肥只降速不停滞（每日最低1点）；研究与养殖按“有效日”推进而非自然日；在制与待收产物不能出售；订单数量按供养值计算。\n\n"
	out += "## 目录\n\n"
	for category in data["categories"]:
		var cid := String(category["id"])
		var titles := PackedStringArray()
		for entity in entities:
			if String(entity["category"]) == cid:
				titles.append("[%s](#%s)" % [String(entity["name"]), anchor(String(entity["id"]))])
		if titles.is_empty():
			continue
		out += "- **%s（%d）**：%s\n" % [category_title[cid], titles.size(), "、".join(titles)]
	out += "\n---\n\n"
	for category in data["categories"]:
		var cid := String(category["id"])
		var section: Array = []
		for entity in entities:
			if String(entity["category"]) == cid:
				section.append(entity)
		if section.is_empty():
			continue
		out += "## %s（%d）\n\n" % [category_title[cid], section.size()]
		for entity in section:
			out += render_entity(entity)
		out += "\n"
	return out

func render_entity(entity: Dictionary) -> String:
	var out := "### %s `%s`\n\n" % [String(entity["name"]), String(entity["id"])]
	if String(entity["kind"]) == "rule":
		return out + render_rule(entity)
	if not String(entity.get("summary", "")).is_empty():
		out += "%s\n\n" % String(entity["summary"])
	var locks = entity.get("locks")
	if locks is Dictionary and not (locks as Dictionary).is_empty():
		var lock: Dictionary = locks
		out += "> 解锁条件：需完成研究 %s；未解锁时仍可阅读本条目，阅读不解锁玩法。\n\n" % link_to(String(lock["research"]))
	var fields: Array = entity.get("fields", [])
	if not fields.is_empty():
		out += "| 字段 | 内容 |\n|---|---|\n"
		for field in fields:
			out += "| %s | %s |\n" % [cell(String(field["label"])), cell(String(field["text"]))]
		out += "\n"
	for section in [["获取来源", "sources"], ["直接用途", "uses"]]:
		var rows = entity.get(section[1])
		if not (rows is Array) or (rows as Array).is_empty():
			continue
		out += "**%s（%d条）**\n\n" % [section[0], (rows as Array).size()]
		out += "| 过程 | 本条目数量 | 说明 | 同批 |\n|---|---|---|---|\n"
		for row in rows:
			var raw_quantity = row["quantity"]
			var quantity := "按订单/库存"
			if raw_quantity != null:
				# JSON numbers arrive as floats; registry quantities are integers.
				quantity = str(int(raw_quantity)) if float(raw_quantity) == floor(float(raw_quantity)) else str(raw_quantity)
			var others := cell(str(row.get("others", "")))
			var others_cell := others if not others.is_empty() else "—"
			out += "| %s | ×%s | %s | %s |\n" % [cell(str(row["name"])), quantity, cell(str(row["detail"])), others_cell]
		out += "\n"
	var links: Array = entity.get("links", [])
	if not links.is_empty():
		var parts := PackedStringArray()
		for link in links:
			parts.append("%s：%s" % [String(link["label"]), link_to(String(link["entity"]))])
		out += "关联条目：" + "；".join(parts) + "\n\n"
	var rules: Array = entity.get("related_rules", [])
	if not rules.is_empty():
		var parts := PackedStringArray()
		for rid in rules:
			parts.append(link_to(String(rid)))
		out += "相关规则：" + "、".join(parts) + "\n\n"
	return out
