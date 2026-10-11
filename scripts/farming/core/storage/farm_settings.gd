extends RefCounted
const RESOLUTIONS := [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]
const FRAME_MODES := ["vsync", "60", "120", "unlimited"]
var path := "user://farm_demo_settings.cfg"
var data := defaults()
var warning := ""

func _init(file_path: String = "user://farm_demo_settings.cfg") -> void: path = file_path

static func defaults() -> Dictionary:
	return {"fullscreen": false,"resolution": 1,"frame_mode": "vsync","show_fps": false,"volume": 80}

static func valid(value) -> bool:
	if not value is Dictionary or value.size() != 5: return false
	if not value.get("fullscreen") is bool or not value.get("show_fps") is bool: return false
	if value.get("frame_mode") not in FRAME_MODES: return false
	for key in ["resolution","volume"]:
		var number = value.get(key)
		if not number is int or number < 0 or number > (3 if key == "resolution" else 100): return false
	return true

func load_settings() -> bool:
	data = defaults()
	warning = ""
	var source := path
	if not FileAccess.file_exists(source) and FileAccess.file_exists(path+".bak"): source = path+".bak"
	if not FileAccess.file_exists(source): return true
	var config := ConfigFile.new()
	if config.load(source) != OK or config.get_value("settings","schema",0) != 1:
		warning = "设置文件无法读取，当前使用默认显示设置。"
		return false
	var saved = config.get_value("settings","data",null)
	if not valid(saved):
		warning = "设置数据非法，当前使用默认显示设置。"
		return false
	data = saved.duplicate(true)
	return true

func save_settings(value: Dictionary) -> Dictionary:
	if not valid(value): return {"ok": false,"reason": "设置值非法"}
	var config := ConfigFile.new()
	config.set_value("settings","schema",1)
	config.set_value("settings","data",value)
	if config.save(path+".tmp") != OK: return {"ok": false,"reason": "无法写入设置临时文件"}
	var old := FileAccess.file_exists(path)
	if old and FileAccess.file_exists(path+".bak") and DirAccess.remove_absolute(path+".bak") != OK:
		DirAccess.remove_absolute(path+".tmp")
		return {"ok": false,"reason": "无法替换设置备份"}
	if old and DirAccess.rename_absolute(path,path+".bak") != OK:
		DirAccess.remove_absolute(path+".tmp")
		return {"ok": false,"reason": "无法备份原设置"}
	if DirAccess.rename_absolute(path+".tmp",path) != OK:
		if old: DirAccess.rename_absolute(path+".bak",path)
		return {"ok": false,"reason": "无法替换设置文件"}
	data = value.duplicate(true)
	warning = ""
	return {"ok": true}

func apply_display() -> void:
	if DisplayServer.get_name() == "headless": return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if data["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)
	if not data["fullscreen"]:
		DisplayServer.window_set_size(RESOLUTIONS[int(data["resolution"])])
		DisplayServer.window_set_position((DisplayServer.screen_get_size()-RESOLUTIONS[int(data["resolution"])])/2)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if data["frame_mode"] == "vsync" else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0 if data["frame_mode"] in ["vsync","unlimited"] else int(data["frame_mode"])
