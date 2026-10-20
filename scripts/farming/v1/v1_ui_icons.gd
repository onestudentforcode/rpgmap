extends RefCounted
const ROOT := "res://assets/farming/ui/"
static var cache: Dictionary = {}

static func get_icon(ident: String) -> Texture2D:
	if not cache.has(ident):
		var path := ROOT + ident + ".svg"
		# Some newer resources still use category icons until their formal art
		# batch. Do not issue ResourceLoader errors every time the market opens.
		if not ResourceLoader.exists(path):
			var group := "water" if ident in ["water_gel", "water_retaining_matrix", "duckweed", "duckweed_seed", "reed_stalk", "reed_seed"] else "gold" if ident == "pearl" else "wood"
			path = ROOT + group + ".svg"
		cache[ident] = load(path)
	return cache[ident]
