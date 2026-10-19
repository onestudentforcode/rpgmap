"""Deterministic P10.5 placeholders in the existing 35-degree render pipeline.

Five species yards (2x2, the rock_workyard visual language with a distinct
rim colour per craft) and four intensive stations (1x1 counters with a craft
emblem). Ground contact and hard alpha follow the P10.3/P10.4 conventions.
"""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw
from gen_p103_facility_art import iso_block

ROOT = Path(__file__).resolve().parents[2]

# 1x1 stations: (counter height, top, side, emblem colour)
STATIONS = {
    'wool_station': {'height': 52, 'top': '#cdb690', 'side': '#8b7355', 'emblem': '#c9d2d6'},
    'silkworm_rack': {'height': 88, 'top': '#cfe0a8', 'side': '#93a06b', 'emblem': '#e8f0d8'},
    'spirit_liquid_collector': {'height': 64, 'top': '#a8cbd8', 'side': '#6d93a2', 'emblem': '#cfeaf2'},
    'scale_station': {'height': 58, 'top': '#d3c391', 'side': '#97824f', 'emblem': '#d9b95c'},
}
# 2x2 yards: (block height, top, side, rim)
YARDS = {
    'rock_breaking_yard': {'height': 96, 'top': '#b7a58c', 'side': '#77664f', 'rim': '#8d8c86'},
    'ore_sorting_yard': {'height': 96, 'top': '#c2ab8b', 'side': '#7e6a51', 'rim': '#c99e5a'},
    'carbonization_nest': {'height': 78, 'top': '#6f625b', 'side': '#463c36', 'rim': '#e0985a'},
    'compost_mouse_den': {'height': 70, 'top': '#93775a', 'side': '#5e4a37', 'rim': '#7c9a5e'},
    'shell_forming_station': {'height': 84, 'top': '#b0a393', 'side': '#6f6455', 'rim': '#8fb0a0'},
}


def render_station(spec):
    im = Image.new('RGBA', (256, 256))
    d = ImageDraw.Draw(im)
    y = 158 - spec['height']
    iso_block(d, 128, y, 59, 28, spec['height'], spec['top'], spec['side'])
    # Raised emblem tablet on the front face.
    cx, cy = 100, 158 - spec['height'] // 2
    d.polygon([(cx - 14, cy - 7), (cx + 4, cy - 16), (cx + 18, cy - 8), (cx, cy + 1)], fill=spec['emblem'], outline='#3a3128', width=2)
    return im


def render_yard(spec):
    im = Image.new('RGBA', (512, 512))
    d = ImageDraw.Draw(im)
    y = 262 - spec['height']
    iso_block(d, 256, y, 118, 56, spec['height'], spec['top'], spec['side'])
    # Rim strip across the top face plus three craft stones.
    d.line([(256 - 118, y + 28), (256, y + 84), (256 + 118, y + 28)], fill=spec['rim'], width=6)
    for dx, dy, r in [(-46, 44, 9), (8, 62, 11), (52, 40, 8)]:
        d.ellipse((256 + dx - r, y + dy - r, 256 + dx + r, y + dy + r), fill=spec['rim'], outline='#3a3128', width=2)
    return im


def main():
    directory = ROOT / 'assets/farming/facilities'
    manifest_path = directory / 'facility_manifest.json'
    ground_path = ROOT / 'content/farming/p8/grounding.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    grounding = json.loads(ground_path.read_text(encoding='utf-8'))
    sheet = Image.new('RGBA', (1024, 512), '#ddd9c9')
    for index, (ident, spec) in enumerate({**STATIONS, **YARDS}.items()):
        big = ident in YARDS
        im = render_yard(spec) if big else render_station(spec)
        assert im.mode == 'RGBA'
        assert set(im.getchannel('A').get_flattened_data()) == {0, 255}, 'hard transparent edges required'
        bbox = im.getbbox()
        assert bbox and min(bbox[:2]) > 0 and max(bbox[2:]) < (512 if big else 256)
        path = directory / ident / 'body.png'
        path.parent.mkdir(parents=True, exist_ok=True)
        im.save(path)
        size = 512 if big else 256
        draw = 204.8 if big else 122.0
        shadow = [112, 45] if big else [58.0, 22.0]
        manifest['facilities'][ident] = {
            'footprint': [2, 2] if big else [1, 1], 'canvas_px': [size, size],
            'path': f'res://assets/farming/facilities/{ident}/body.png',
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'anchor_uv': [0.5, (262 if big else 158) / size], 'draw_size': [draw, draw],
            'scale_multiplier': 1.0, 'ground_placement': 'footprint_center',
            'shadow': {'size': shadow, 'offset': [0, 5 if big else 4], 'opacity': 0.21 if big else 0.18},
        }
        grounding['facilities'][ident] = {'size': shadow, 'offset': [0, 5 if big else 4]}
        sheet.alpha_composite(im, ((index % 4) * 256, (index // 4) * 256))
        ImageDraw.Draw(sheet).text(((index % 4) * 256 + 60, (index // 4) * 256 + 240), ident, fill='#302c27')
        print(f'P105 ART {ident}: {"2x2" if big else "1x1"} hard-alpha bbox={bbox}')
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    ground_path.write_text(json.dumps(grounding, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    output = ROOT / '.art-work/p105-art'
    output.mkdir(parents=True, exist_ok=True)
    sheet.save(output / 'p105_facilities.png')
    print('P105 ART OK')


if __name__ == '__main__':
    main()
