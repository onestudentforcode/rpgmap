extends RefCounted
## Ground plane only: body-local PNG offsets are already camera projected.
const CONFIG := "res://content/farming/p8/p87_projection.json"
var config: Dictionary
var enabled := false
var depth := 1.0
var scale_factor := 1.0
var origin := Vector2.ZERO

func _init() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	scale_factor = float(config["view_units_per_ground_unit"])
	origin = Vector2(config["view_origin"][0], config["view_origin"][1])

func configure(active: bool) -> void:
	enabled = active
	depth = sin(deg_to_rad(float(config["elevation_degrees"]))) if active else 1.0

func ground_to_view(point: Vector2) -> Vector2:
	return origin + point * Vector2(scale_factor, scale_factor * depth)

func view_to_ground(point: Vector2) -> Vector2:
	return (point - origin) / Vector2(scale_factor, scale_factor * depth)

func ground_rect(rect: Rect2) -> Rect2:
	return Rect2(ground_to_view(rect.position), rect.size * Vector2(scale_factor, scale_factor * depth))

func cell_at(view_point: Vector2) -> Vector2i:
	var point := view_to_ground(view_point) / float(config["logical_tile_units"])
	return Vector2i(floori(point.x), floori(point.y))

func footprint(origin_cell: Array, shape: Array) -> Rect2:
	var tile := float(config["logical_tile_units"])
	return Rect2(Vector2(origin_cell[0],origin_cell[1])*tile,Vector2(shape[0],shape[1])*tile)

func body_rect(visual: Dictionary, logical_root: Vector2, body_scale: float = 1.0) -> Rect2:
	var local: Vector2 = visual["rect"].position - visual["root"]
	return Rect2(ground_to_view(logical_root) + local * body_scale, visual["rect"].size * body_scale)
