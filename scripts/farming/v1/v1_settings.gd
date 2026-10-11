extends RefCounted
## V1 global preferences, independent of all game slots and V0 settings.
const RESOLUTIONS := [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]
const FRAME_MODES := ["vsync", "60", "120", "unlimited"]
var path: String
var minimum_zoom := 0.25
var data := defaults()
var warning := ""

func _init(file_path: String = "user://farm_demo_v1_settings.cfg", zoom_floor: float = 0.25) -> void:
	path = file_path
	minimum_zoom = zoom_floor

static func defaults() -> Dictionary:
	return {"fullscreen":false,"resolution":3,"frame_mode":"vsync","show_fps":false,"ui_scale":100,"map_zoom":1.0}

static func valid(value, zoom_floor: float = 0.25) -> bool:
	return value is Dictionary and value.size() == 6 and value.get("fullscreen") is bool \
		and value.get("show_fps") is bool and value.get("resolution") is int and value["resolution"] in range(4) \
		and value.get("frame_mode") in FRAME_MODES and value.get("ui_scale") is int and value["ui_scale"] in [100,125,150] \
		and (value.get("map_zoom") is float or value.get("map_zoom") is int) \
		and is_finite(float(value["map_zoom"])) and float(value["map_zoom"]) >= zoom_floor and float(value["map_zoom"]) <= 3.0

func load_settings() -> bool:
	data = defaults()
	warning = ""
	var config := ConfigFile.new()
	var source := path if FileAccess.file_exists(path) else path+".bak"
	if not FileAccess.file_exists(source): return true
	if config.load(source) != OK or config.get_value("settings","schema",0) != 1 or not valid(config.get_value("settings","data",null),minimum_zoom):
		warning = "设置文件无法读取，已使用默认设置。"
		return false
	data = config.get_value("settings","data").duplicate(true)
	return true

func save_settings(value: Dictionary) -> Dictionary:
	if not valid(value,minimum_zoom): return {"ok":false,"reason":"设置值非法"}
	var config := ConfigFile.new()
	config.set_value("settings","schema",1)
	config.set_value("settings","data",value)
	if config.save(path+".tmp") != OK: return {"ok":false,"reason":"无法写入设置"}
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path+".bak") and DirAccess.remove_absolute(path+".bak") != OK:
			return {"ok":false,"reason":"无法替换设置备份"}
		if DirAccess.rename_absolute(path,path+".bak") != OK: return {"ok":false,"reason":"无法备份设置"}
	if DirAccess.rename_absolute(path+".tmp",path) != OK:
		if FileAccess.file_exists(path+".bak"): DirAccess.rename_absolute(path+".bak",path)
		return {"ok":false,"reason":"无法保存设置"}
	data = value.duplicate(true)
	warning = ""
	return {"ok":true}

func apply_display() -> void:
	if DisplayServer.get_name() == "headless": return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if data["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)
	if not data["fullscreen"]:
		var resolution: Vector2i = RESOLUTIONS[int(data["resolution"])]
		resolution = resolution.min(DisplayServer.screen_get_usable_rect().size)
		DisplayServer.window_set_size(resolution)
		DisplayServer.window_set_position(DisplayServer.screen_get_usable_rect().position+(DisplayServer.screen_get_usable_rect().size-resolution)/2)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if data["frame_mode"] == "vsync" else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0 if data["frame_mode"] in ["vsync","unlimited"] else int(data["frame_mode"])
