"""Deterministic P10.6 placeholders in the existing 35-degree render pipeline.

Eight 1x1 counters: five aquatic species stations and the silt processor on
the fence, the shared aquatic crop station, and the shore-side water change
station. Water-line bases distinguish the aquatic set; ground contact and
hard alpha follow the P10.3-P10.5 conventions.
"""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw
from gen_p103_facility_art import iso_block

ROOT = Path(__file__).resolve().parents[2]

# 1x1 stations: (counter height, top, side, emblem colour, water base)
STATIONS = {
    'carp_harvest_station': {'height': 56, 'top': '#c9b98e', 'side': '#8a744f', 'emblem': '#7fb2c9', 'water': True},
    'oilfish_harvest_station': {'height': 62, 'top': '#d8c08a', 'side': '#93794a', 'emblem': '#e0a95f', 'water': True},
    'pearl_station': {'height': 66, 'top': '#dcd4e0', 'side': '#948aa0', 'emblem': '#f2ecf4', 'water': True},
    'gel_station': {'height': 58, 'top': '#aecfe0', 'side': '#6f93a8', 'emblem': '#d7f0f8', 'water': True},
    'coral_station': {'height': 72, 'top': '#d8a9a0', 'side': '#9a6f66', 'emblem': '#e8b7ac', 'water': True},
    'silt_processing_station': {'height': 60, 'top': '#a89a7c', 'side': '#6d6248', 'emblem': '#8f7f5f', 'water': True},
    'aquatic_crop_station': {'height': 48, 'top': '#b9d0a0', 'side': '#7a9260', 'emblem': '#dcecc8', 'water': True},
    'water_change_station': {'height': 84, 'top': '#a8cbd8', 'side': '#64808f', 'emblem': '#e4f4fa', 'water': False},
}


def render_station(spec):
    im = Image.new('RGBA', (256, 256))
    d = ImageDraw.Draw(im)
    y = 158 - spec['height']
    iso_block(d, 128, y, 59, 28, spec['height'], spec['top'], spec['side'])
    # Raised emblem tablet on the front face.
    cx, cy = 100, 158 - spec['height'] // 2
    d.polygon([(cx - 14, cy - 7), (cx + 4, cy - 16), (cx + 18, cy - 8), (cx, cy + 1)], fill=spec['emblem'], outline='#3a3128', width=2)
    if spec['water']:
        # Aquatic counters stand on a fenced float: two rim posts and a
        # lighter water-line plank under the block.
        d.line([(128 - 66, 168), (128, 196), (128 + 66, 168)], fill='#7d6a4e', width=5)
        d.ellipse((128 - 70, 176, 128 - 52, 188), fill='#7d6a4e', outline='#3a3128', width=2)
        d.ellipse((128 + 52, 176, 128 + 70, 188), fill='#7d6a4e', outline='#3a3128', width=2)
    return im


def main():
    directory = ROOT / 'assets/farming/facilities'
    manifest_path = directory / 'facility_manifest.json'
    ground_path = ROOT / 'content/farming/p8/grounding.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    grounding = json.loads(ground_path.read_text(encoding='utf-8'))
    sheet = Image.new('RGBA', (1024, 512), '#ddd9c9')
    for index, (ident, spec) in enumerate(STATIONS.items()):
        im = render_station(spec)
        assert im.mode == 'RGBA'
        assert set(im.getchannel('A').get_flattened_data()) == {0, 255}, 'hard transparent edges required'
        bbox = im.getbbox()
        assert bbox and min(bbox[:2]) > 0 and max(bbox[2:]) < 256
        path = directory / ident / 'body.png'
        path.parent.mkdir(parents=True, exist_ok=True)
        im.save(path)
        manifest['facilities'][ident] = {
            'footprint': [1, 1], 'canvas_px': [256, 256],
            'path': f'res://assets/farming/facilities/{ident}/body.png',
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'anchor_uv': [0.5, 158 / 256], 'draw_size': [122.0, 122.0],
            'scale_multiplier': 1.0, 'ground_placement': 'footprint_center',
            'shadow': {'size': [58.0, 22.0], 'offset': [0, 4], 'opacity': 0.18 if not spec['water'] else 0.10},
        }
        grounding['facilities'][ident] = {'size': [58.0, 22.0], 'offset': [0, 4]}
        sheet.alpha_composite(im, ((index % 4) * 256, (index // 4) * 256))
        ImageDraw.Draw(sheet).text(((index % 4) * 256 + 52, (index // 4) * 256 + 240), ident, fill='#302c27')
        print(f'P106 ART {ident}: 1x1 hard-alpha bbox={bbox}')
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    ground_path.write_text(json.dumps(grounding, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    output = ROOT / '.art-work/p106-art'
    output.mkdir(parents=True, exist_ok=True)
    sheet.save(output / 'p106_facilities.png')
    print('P106 ART OK')


if __name__ == '__main__':
    main()
