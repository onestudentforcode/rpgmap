class_name Player
extends CharacterBody2D
## 行走精灵：键盘自由移动 + 四向动画；原点在脚底（Y-sort 锚），自带相机/交互检测/E 提示。
## 美术规格由主题配置注入（setup），换主题时角色与提示气泡随之整体换肤。

const SPEED := 120.0

var facing := "down"
var frozen := false          # 对话/切图中锁定
var main: Node = null        # 由 Main 注入

var _texture: Texture2D
var _frame_size := Vector2i(32, 48)
var _prompt_region := Rect2(160, 0, 16, 16)
var _prompt_texture: Texture2D

var _sprite: AnimatedSprite2D
var _camera: Camera2D
var _reach: Area2D
var _prompt: Sprite2D


## cfg 来自烘焙 theme.json 的 player 段
func setup(cfg: Dictionary) -> void:
	_texture = load(cfg["texture"])
	_frame_size = Vector2i(int(cfg["frame"][0]), int(cfg["frame"][1]))
	_prompt_region = Rect2(cfg["prompt_region"][0], cfg["prompt_region"][1],
			cfg["prompt_region"][2], cfg["prompt_region"][3])
	_prompt_texture = load(cfg["prompt_texture"])


func _ready() -> void:
	collision_layer = MapHost.PLAYER_LAYER
	collision_mask = MapHost.WORLD_LAYER
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 7.0
	cs.shape = shape
	cs.position = Vector2(0, -6)
	add_child(cs)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _build_frames()
	_sprite.offset = Vector2(0, -_frame_size.y / 2.0)  # 原点=脚底
	add_child(_sprite)
	_sprite.play("idle_down")

	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	_camera.offset = Vector2(0, -16)
	add_child(_camera)
	_camera.make_current()

	_reach = Area2D.new()
	_reach.collision_layer = 0
	_reach.collision_mask = 4  # Interactable
	var rcs := CollisionShape2D.new()
	var rshape := CircleShape2D.new()
	rshape.radius = 30.0
	rcs.shape = rshape
	rcs.position = Vector2(0, -8)
	_reach.add_child(rcs)
	add_child(_reach)

	_prompt = Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = _prompt_texture
	at.region = _prompt_region
	_prompt.texture = at
	_prompt.position = Vector2(0, -_frame_size.y - 10)
	_prompt.visible = false
	add_child(_prompt)


func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	var rows := {"down": 0, "left": 1, "right": 2, "up": 3}
	for dir: String in rows:
		var row: int = rows[dir]
		sf.add_animation("idle_" + dir)
		sf.add_frame("idle_" + dir, _frame(0, row))
		sf.add_animation("walk_" + dir)
		for col in [1, 2, 3, 2]:
			sf.add_frame("walk_" + dir, _frame(col, row))
		sf.set_animation_speed("walk_" + dir, 8.0)
		sf.set_animation_loop("walk_" + dir, true)
	return sf


func _frame(col: int, row: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = _texture
	at.region = Rect2(col * _frame_size.x, row * _frame_size.y,
			_frame_size.x, _frame_size.y)
	return at


func _physics_process(_delta: float) -> void:
	if frozen:
		velocity = Vector2.ZERO
		_sprite.play("idle_" + facing)
		_prompt.visible = false
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input * SPEED
	move_and_slide()
	if input.length() > 0.01:
		if absf(input.x) >= absf(input.y):
			facing = "right" if input.x > 0 else "left"
		else:
			facing = "down" if input.y > 0 else "up"
	if velocity.length() > 2.0:
		_sprite.play("walk_" + facing)
	else:
		_sprite.play("idle_" + facing)
	_update_interaction()


func _update_interaction() -> void:
	var nearest := nearest_interactable()
	var still := velocity.length() < 5.0
	_prompt.visible = nearest != null and still
	if nearest != null and still and Input.is_action_just_pressed("interact") and main:
		main.activate_zone(nearest)


func nearest_interactable() -> Interactable:
	var best: Interactable = null
	var best_d := INF
	for a in _reach.get_overlapping_areas():
		if a is Interactable:
			var d := global_position.distance_squared_to(a.global_position)
			if d < best_d:
				best_d = d
				best = a
	return best


func teleport(pos: Vector2, face: String) -> void:
	global_position = pos
	facing = face
	velocity = Vector2.ZERO
	_sprite.play("idle_" + face)
	_camera.reset_smoothing()


func set_camera_limits(rect: Rect2) -> void:
	# limit 钳制的是相机节点位置，不含 offset；按 offset 反向平移，
	# 使「渲染视口」而非节点被夹在地图矩形内（否则出现地图外灰边）。
	_camera.limit_left = int(rect.position.x) - int(_camera.offset.x)
	_camera.limit_top = int(rect.position.y) - int(_camera.offset.y)
	_camera.limit_right = int(rect.end.x) - int(_camera.offset.x)
	_camera.limit_bottom = int(rect.end.y) - int(_camera.offset.y)
