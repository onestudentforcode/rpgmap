extends "res://scripts/farming/v1/v1_scene.gd"
const V2World := preload("res://scripts/farming/v2/v2_world.gd")
const V2Store := preload("res://scripts/farming/v2/v2_slot_store.gd")
func _init() -> void:
	store = V2Store.new()
	manual_mode = true
	minimum_map_zoom = 0.1
	settings = Settings.new("user://farm_demo_v2_settings.cfg", minimum_map_zoom)
	product_title = "灵田 Demo V2 · P7.a"
	terrain_path = "res://content/farming/baked/v2/terrains.json"
	preview_prefix = "v2"
func _make_store(directory: String = ""):
	return V2Store.new() if directory.is_empty() else V2Store.new(directory)
func _make_world(slot_store):
	return V2World.new(slot_store)

func _fit_map() -> void:
	var extent := Vector2(world.grid.width,world.grid.height)*64.0
	# Leave room for the expanded toolbar, including at the compatibility window.
	var bottom := _camera_bottom_margin()
	var zoom := clampf(minf(board.size.x/extent.x,maxf(64,board.size.y-bottom)/extent.y)*0.94,minimum_map_zoom,3.0)
	camera.zoom = Vector2.ONE*zoom
	camera.position = extent*0.5+Vector2(0,bottom*0.5/zoom)

func _camera_bottom_margin() -> float:
	return 128.0 if tool_grid.columns == 10 else 176.0

func _preview(directory: String) -> void:
	await _prepare_preview(directory)
	await _shot(directory,"slots")
	_new(1,false)
	world.buy("grass_seed",4)
	world.workforce.set_seed(Vector2i(2,2),"pasture_grass")
	world.till(Vector2i(2,2))
	world.plant(Vector2i(2,2),"pasture_grass")
	selected = Vector2i(2,2)
	_show_cell()
	expanded = true
	_select_tool("irrigate")
	_hover = selected
	_update_hover()
	_layout()
	_fit_map()
	await _shot(directory,"manual")
	_set_manual(false)
	_select_tool("till")
	_drag = true
	_drag_start = Vector2i(3,2)
	_drag_end = Vector2i(7,4)
	_hover = _drag_end
	_update_hover()
	await _shot(directory,"delegated")
	_set_manual(true)
	# Screenshot fixture only. The separate startup ledger never injects materials.
	world.inventory.add("raw_wood",6)
	world.inventory.add("raw_stone",10)
	world.build_facility(Vector2i(0,14),"fish_pond")
	world.build_facility(Vector2i(7,1),"pen")
	selected = Vector2i(0,14)
	_show_cell()
	await _shot(directory,"reservoir")
	_show_build()
	await _shot(directory,"construction")
	var preview_directory: String = store.slot_path(1).get_base_dir()
	store.delete_slot(1,true)
	DirAccess.remove_absolute(preview_directory)
	get_tree().quit()
