extends SceneTree
## GPU visual regression, separate from headless logic tests; actual CropRenderer.
## godot --path . --script scripts/farming/tests/phase04_depth.gd
const FarmData := preload("res://scripts/farming/core/farm_data.gd")
const LandGrid := preload("res://scripts/farming/core/grid/land_grid.gd")
const CropManager := preload("res://scripts/farming/core/crops/crop_manager.gd")
const CropRenderer := preload("res://scripts/farming/rendering/crop_renderer.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Depth pixel check needs a rendering window; do not use --headless")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size=Vector2i(256,224)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var ysort := Node2D.new()
	ysort.y_sort_enabled=true
	ysort.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(ysort)
	var grid := LandGrid.new()
	grid.setup(4,4,[["grass","grass","grass","grass"],["grass","grass","grass","grass"],
		["grass","grass","grass","grass"],["grass","grass","grass","grass"]],{"grass":true})
	for y in range(1,3):
		for x in range(1,3):
			grid.till(Vector2i(x,y))
	var manager := CropManager.new()
	manager.setup(grid,FarmData.load_crops())
	var planted := manager.plant(Vector2i(1,1),"jade_fruit_tree")
	if not planted["ok"]:
		quit(1)
		return
	for day in range(10):
		manager.on_day_changed()
	var renderer := CropRenderer.new()
	renderer.build(ysort,manager)
	var sprite: Sprite2D=renderer._sprites[planted["uid"]]
	var source := sprite.texture.get_image()
	var sample := Vector2i(-1,-1)
	for y in range(160,180):
		for x in range(58,70):
			if source.get_pixel(x,y).a>0.99:
				sample=Vector2i(x+64,y)
				break
		if sample.x>=0:
			break
	if sample.x<0:
		push_error("No opaque trunk pixel available for depth probe")
		quit(1)
		return
	var marker_image := Image.create(16,64,false,Image.FORMAT_RGBA8)
	var marker_color := Color(0.85,0.15,0.3,1)
	marker_image.fill(marker_color)
	var marker := Sprite2D.new()
	marker.texture=ImageTexture.create_from_image(marker_image)
	marker.offset=Vector2(0,-32) # Sorting anchor is the marker's foot.
	ysort.add_child(marker)
	var directory := "res://.shots/farm-phase04c-final"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	marker.position=Vector2(sample.x,182) # Behind tree foot at y=192.
	await process_frame
	await RenderingServer.frame_post_draw
	var behind := viewport.get_texture().get_image()
	behind.save_png(directory.path_join("depth-behind.png"))
	var expected := source.get_pixel(sample.x-64,sample.y)
	var actual := behind.get_pixel(sample.x,sample.y)
	var behind_ok := actual.a>0.99 and _same_color(actual,expected)
	marker.position.y=202 # In front, still overlaps the same trunk pixel.
	await process_frame
	await RenderingServer.frame_post_draw
	var front := viewport.get_texture().get_image()
	front.save_png(directory.path_join("depth-front.png"))
	var front_ok := _same_color(front.get_pixel(sample.x,sample.y),marker_color)
	print("DEPTH CHECK behind=%s front=%s sample=%s" % [behind_ok,front_ok,sample])
	quit(0 if behind_ok and front_ok else 1)


func _same_color(a: Color,b: Color) -> bool:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))<0.025 and absf(a.a-b.a)<0.025
