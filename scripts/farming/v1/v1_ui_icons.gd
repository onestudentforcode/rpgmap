extends RefCounted
const ROOT := "res://assets/farming/ui/"
static var cache: Dictionary = {}

static func get_icon(ident: String) -> Texture2D:
	if not cache.has(ident): cache[ident] = load(ROOT+ident+".svg")
	return cache[ident]
