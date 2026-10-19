"""P10.3 placeholder facility renders: simple deterministic 35-degree blocks
with distinct silhouettes per structural facility. Formal Blender renders
replace these files later under the same manifest entries.
"""
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
ASSET_DIR = ROOT / 'assets/farming/facilities'
CANVAS = 256

# id -> (top colour, side colour, height px, accent patch)
SPECS = {
    'dispatch_station': ('#8f7a55', '#6d5c3e', 34, 'flag'),
    'feed_trough': ('#a98150', '#7d5f3a', 18, 'trough'),
    'small_bed': ('#b58f6a', '#8a6a4d', 14, 'mattress'),
    'medium_bed': ('#c09a70', '#93724f', 16, 'mattress'),
    'large_bed': ('#caa87e', '#9d7c56', 20, 'mattress'),
    'care_table': ('#9a8f7a', '#746a58', 30, 'tools'),
}


def iso_block(draw, cx, cy, half_w, half_h, height, top, side):
    # Top diamond plus two front faces of a 35-degree block.
    top_pts = [(cx, cy - half_h), (cx + half_w, cy), (cx, cy + half_h), (cx - half_w, cy)]
    left_pts = [(cx - half_w, cy), (cx, cy + half_h), (cx, cy + half_h + height), (cx - half_w, cy + height)]
    right_pts = [(cx + half_w, cy), (cx, cy + half_h), (cx, cy + half_h + height), (cx + half_w, cy + height)]
    draw.polygon(left_pts, fill=side)
    draw.polygon(right_pts, fill=_shade(side, 0.82))
    draw.polygon(top_pts, fill=top)
    for pts in (top_pts, left_pts, right_pts):
        draw.polygon(pts, outline='#3a3128', width=3)


def _shade(hex_color, factor):
    value = int(hex_color[1:], 16)
    r, g, b = (value >> 16) & 255, (value >> 8) & 255, value & 255
    return '#%02x%02x%02x' % (int(r * factor), int(g * factor), int(b * factor))


def accent(draw, cx, cy, kind, top):
    if kind == 'flag':
        draw.line([(cx, cy - 8), (cx, cy - 46)], fill='#3a3128', width=4)
        draw.polygon([(cx, cy - 46), (cx + 26, cy - 39), (cx, cy - 32)], fill='#c85f45')
    elif kind == 'trough':
        draw.polygon([(cx - 24, cy), (cx + 24, cy), (cx + 18, cy + 9), (cx - 18, cy + 9)], fill='#5d8a5a', outline='#3a3128')
    elif kind == 'mattress':
        draw.polygon([(cx - 26, cy + 2), (cx + 26, cy + 2), (cx + 20, cy + 11), (cx - 20, cy + 11)], fill=_shade(top, 1.25), outline='#3a3128')
    elif kind == 'tools':
        draw.line([(cx - 14, cy + 2), (cx - 2, cy - 10)], fill='#d9c9a0', width=3)
        draw.line([(cx + 4, cy + 3), (cx + 16, cy - 6)], fill='#d9c9a0', width=3)


def render(spec):
    top, side, height, patch = spec
    image = Image.new('RGBA', (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    cx, cy = CANVAS // 2, 96
    iso_block(draw, cx, cy, 74, 34, height, top, side)
    accent(draw, cx, cy, patch, top)
    return image


def main():
    manifest_path = ASSET_DIR / 'facility_manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    grounding_path = ROOT / 'content/farming/p8/grounding.json'
    grounding = json.loads(grounding_path.read_text(encoding='utf-8'))
    for ident, spec in SPECS.items():
        target_dir = ASSET_DIR / ident
        target_dir.mkdir(parents=True, exist_ok=True)
        body_path = target_dir / 'body.png'
        render(spec).save(body_path)
        data = body_path.read_bytes()
        entry = {
            'footprint': [1, 1],
            'canvas_px': [CANVAS, CANVAS],
            'path': 'res://assets/farming/facilities/%s/body.png' % ident,
            'sha256': hashlib.sha256(data).hexdigest(),
            'anchor_uv': [0.5, 0.62],
            'draw_size': [122.0, 122.0],
            'scale_multiplier': 1.0,
            'ground_placement': 'footprint_center',
            'shadow': {'size': [58.0, 22.0], 'offset': [0, 4], 'opacity': 0.18},
        }
        manifest['facilities'][ident] = entry
        grounding.setdefault('facilities', {})[ident] = {'size': [58.0, 22.0], 'offset': [0, 4]}
        print('P103 ART %s -> %s' % (ident, entry['path']))
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    grounding_path.write_text(json.dumps(grounding, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('P103 ART OK: %d placeholder facility renders' % len(SPECS))


if __name__ == '__main__':
    main()
