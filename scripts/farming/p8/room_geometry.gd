extends RefCounted
## Membership is explicit. Adjacency validates one selected identity; it never
## discovers ownership by flooding neighboring floor tiles.
const STEPS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

static func key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

static func cell(text: String) -> Vector2i:
	var parts := text.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

static func connected(cells: Array) -> bool:
	if cells.is_empty(): return false
	var members := {}
	for text in cells:
		if not text is String or text.split(",").size() != 2: return false
		if key(cell(text)) != text or members.has(text): return false
		members[text] = true
	var seen := {cells[0]: true}
	var queue := [cells[0]]
	var cursor := 0
	while cursor < queue.size():
		var at := cell(String(queue[cursor]))
		cursor += 1
		for step in STEPS:
			var next := key(at + step)
			if members.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen.size() == members.size()
