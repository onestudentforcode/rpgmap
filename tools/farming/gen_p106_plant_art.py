"""Deterministic P10.6 water-crop placeholders in the plant pipeline.

Duckweed (floating pads) and reed (straight stalks) in four growth stages on
the shared 512x768 canvas with hard alpha. Manifest and grounding entries
follow the resin_tree reference numbers.
"""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUTLINE = '#3a3128'
WATER = '#6f9fb8'
WATER_DARK = '#567f96'
PAD = '#79a85c'
PAD_DARK = '#59824a'
STALK = '#8a9e5a'
STALK_DARK = '#64803f'
HEAD = '#b8a86a'


def water_line(d):
    # A calm strip under the plants: every stage shares the same waterline.
    d.polygon([(96, 702), (416, 702), (372, 730), (140, 730)], fill=WATER, outline=WATER_DARK, width=3)
    for x in (176, 256, 336):
        d.line([(x - 22, 716), (x + 22, 716)], fill=WATER_DARK, width=3)


def duckweed(stage):
    im = Image.new('RGBA', (512, 768))
    d = ImageDraw.Draw(im)
    water_line(d)
    counts = [3, 6, 10, 14][stage]
    sizes = [10, 13, 16, 19][stage]
    spots = [(206, 692), (244, 678), (286, 690), (318, 672), (178, 672),
             (256, 700), (300, 654), (216, 652), (168, 690), (336, 694),
             (150, 660), (280, 668), (190, 704), (312, 640)]
    for index in range(counts):
        cx, cy = spots[index % len(spots)]
        r = sizes - (2 if index % 3 == 2 else 0)
        d.ellipse((cx - r, cy - int(r * 0.45), cx + r, cy + int(r * 0.45)), fill=PAD, outline=OUTLINE, width=2)
        d.ellipse((cx - r // 2, cy - r // 5, cx, cy), fill=PAD_DARK)
    return im


def reed(stage):
    im = Image.new('RGBA', (512, 768))
    d = ImageDraw.Draw(im)
    water_line(d)
    stalks = [2, 3, 4, 5][stage]
    heights = [120, 210, 300, 390][stage]
    positions = [(196, -8), (232, 6), (272, -6), (312, 4), (168, 2)]
    for index in range(stalks):
        bx, lean = positions[index % len(positions)]
        top_y = 700 - heights + index * 16
        d.line([(bx, 700), (bx + lean * 3, top_y)], fill=STALK, width=7 if stage < 2 else 9)
        d.line([(bx, 700), (bx + lean * 3, top_y + 26)], fill=STALK_DARK, width=3)
        # Two blade leaves per stalk.
        d.line([(bx, 690), (bx - 26, top_y + 66)], fill=STALK_DARK, width=4)
        d.line([(bx, 676), (bx + 28, top_y + 90)], fill=STALK_DARK, width=4)
        if stage >= 2:
            # Seed head appears from the third stage on.
            d.ellipse((bx + lean * 3 - 7, top_y - 22, bx + lean * 3 + 7, top_y), fill=HEAD, outline=OUTLINE, width=2)
    return im


PLANTS = {'duckweed': duckweed, 'reed': reed}


def main():
    manifest_path = ROOT / 'assets/farming/crops/plant_manifest.json'
    ground_path = ROOT / 'content/farming/p8/grounding.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    grounding = json.loads(ground_path.read_text(encoding='utf-8'))
    reference = manifest['plants']['resin_tree']
    out = ROOT / '.art-work/p106-art'
    out.mkdir(parents=True, exist_ok=True)
    for ident, painter in PLANTS.items():
        crop_dir = ROOT / 'assets/farming/crops' / ident
        crop_dir.mkdir(parents=True, exist_ok=True)
        stages = {}
        hashes = {}
        for stage in range(4):
            im = painter(stage)
            assert set(im.getchannel('A').get_flattened_data()) == {0, 255}, 'hard alpha required'
            path = crop_dir / f'stage_{stage}.png'
            im.save(path)
            key = f'stage_{stage}'
            stages[key] = f'res://assets/farming/crops/{ident}/stage_{stage}.png'
            hashes[key] = hashlib.sha256(path.read_bytes()).hexdigest()
        manifest['plants'][ident] = {
            'footprint': [1, 1], 'canvas_px': reference['canvas_px'],
            'anchor_uv': reference['anchor_uv'], 'draw_size': reference['draw_size'],
            'scale_multiplier': 1.0, 'stages': stages, 'sha256': hashes,
        }
        grounding['plants'][ident] = grounding['plants']['resin_tree']
        sheet = Image.new('RGBA', (2048, 768), '#ddd9c9')
        for stage in range(4):
            sheet.alpha_composite(painter(stage), (stage * 512, 0))
        sheet.save(out / f'{ident}_stages.png')
        print(f'P106 PLANT OK: {ident} 4 stages, manifest+grounding wired')
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    ground_path.write_text(json.dumps(grounding, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
