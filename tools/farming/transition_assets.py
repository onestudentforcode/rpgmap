"""Texture-driven transition builder. Geometry defaults preserve Phase 0 masks."""
from PIL import Image
from asset_common import load_palette
from gen_phase00_textures import BITS, SIZE


def make_mask(bm, config):
    mask = [[255] * SIZE for _ in range(SIZE)]
    specs = [(0, 0, "N", "W", "NW", -.5, -.5),
             (63, 0, "N", "E", "NE", 63.5, -.5),
             (63, 63, "S", "E", "SE", 63.5, 63.5),
             (0, 63, "S", "W", "SW", -.5, 63.5)]
    for cx, cy, ev, eh, diagonal, ox, oy in specs:
        if bm & BITS[ev] or bm & BITS[eh]:
            continue
        radius = config["diagonal_radius"] if bm & BITS[diagonal] else config["outer_radius"]
        for y in range(max(0, cy-radius+1), min(SIZE, cy+radius)):
            for x in range(max(0, cx-radius+1), min(SIZE, cx+radius)):
                if (x-ox)**2 + (y-oy)**2 > radius**2:
                    mask[y][x] = 0
    for direction in ("N", "S", "W", "E"):
        if bm & BITS[direction]:
            continue
        for depth in range(config["dither_rows"]):
            fixed = depth if direction in ("N", "W") else SIZE-1-depth
            period = config["dither_periods"][depth]
            for variable in range(SIZE):
                x, y = (variable, fixed) if direction in ("N", "S") else (fixed, variable)
                if (x+y) % period == 0:
                    mask[y][x] = 0
    return mask


def validate_config(config):
    for key in ("outer_radius", "diagonal_radius", "dither_rows", "rim_width"):
        value = config[key]
        if not isinstance(value, int) or not 0 <= value <= 32:
            raise ValueError(f"{key} must be an integer in 0..32")
    periods = config["dither_periods"]
    if len(periods) < config["dither_rows"] or any(not isinstance(p, int) or p <= 0 or SIZE % p for p in periods):
        raise ValueError("dither periods must divide 64 and cover every dither row")
    for key in ("rim_dark_factor", "rim_deep_factor"):
        if not 0 <= config[key] <= 1:
            raise ValueError(f"{key} must be in 0..1")


def make_atlas(texture, config=None):
    config = dict(config or load_palette()["transition"])
    validate_config(config)
    if texture.size != (64, 64) or texture.mode != "RGB":
        raise ValueError("transition input must be 64x64 RGB")
    # Most frequent input color; ties are lexicographic so output is deterministic.
    counts = texture.getcolors(4096)
    base = sorted(counts, key=lambda item: (-item[0], item[1]))[0][1]
    dark = tuple(round(c * config["rim_dark_factor"]) for c in base)
    deep = tuple(round(c * config["rim_deep_factor"]) for c in base)
    atlas = Image.new("RGBA", (1024, 1024))
    for bm in range(256):
        mask = make_mask(bm, config)
        tile = texture.convert("RGBA")
        px = tile.load()
        for y in range(64):
            for x in range(64):
                on_rim = ((not bm & BITS["N"] and y < config["rim_width"]) or
                          (not bm & BITS["S"] and y >= 64-config["rim_width"]) or
                          (not bm & BITS["W"] and x < config["rim_width"]) or
                          (not bm & BITS["E"] and x >= 64-config["rim_width"]))
                color = (dark if (x+y) % 3 else deep) if on_rim else px[x, y][:3]
                px[x, y] = (*color, mask[y][x])
        atlas.paste(tile, ((bm & 15)*64, (bm >> 4)*64))
    return atlas
