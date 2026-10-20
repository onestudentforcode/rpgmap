"""Deterministic P10.5 mulberry placeholder art in the plant pipeline.

Four growth stages on the shared 512x768 canvas with hard alpha: sapling,
young bush, spreading crown and the harvestable leafy tree. Manifest and
grounding entries follow the resin_tree reference numbers.
"""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
TRUNK = '#7a5a3d'
LEAF = '#6f9e56'
LEAF_DARK = '#4f7a3e'
BERRY = '#8f5f8f'
OUTLINE = '#3a3128'


def tree(stage):
    im = Image.new('RGBA', (512, 768))
    d = ImageDraw.Draw(im)
    scale = [0.35, 0.6, 0.85, 1.0][stage]
    base_x, ground_y = 256, 700
    trunk_w = int(26 * scale) + 6
    trunk_h = int(210 * scale)
    d.polygon([(base_x - trunk_w // 2, ground_y), (base_x - trunk_w // 3, ground_y - trunk_h),
               (base_x + trunk_w // 3, ground_y - trunk_h), (base_x + trunk_w // 2, ground_y)],
              fill=TRUNK, outline=OUTLINE, width=3)
    if stage >= 1:
        d.line([(base_x, ground_y - trunk_h + 40), (base_x - int(70 * scale), ground_y - trunk_h - int(40 * scale))], fill=TRUNK, width=8)
        d.line([(base_x, ground_y - trunk_h + 10), (base_x + int(66 * scale), ground_y - trunk_h - int(52 * scale))], fill=TRUNK, width=8)
    blobs = [(0, -trunk_h - int(30 * scale), int(92 * scale))]
    if stage >= 2:
        blobs += [(-int(74 * scale), -trunk_h - int(6 * scale), int(60 * scale)),
                  (int(74 * scale), -trunk_h - int(14 * scale), int(58 * scale))]
    if stage >= 3:
        blobs += [(0, -trunk_h - int(102 * scale), int(58 * scale)),
                  (-int(46 * scale), -trunk_h - int(72 * scale), int(46 * scale)),
                  (int(48 * scale), -trunk_h - int(78 * scale), int(46 * scale))]
    for dx, dy, r in blobs:
        cx, cy = base_x + dx, ground_y + dy
        d.ellipse((cx - r, cy - int(r * 0.8), cx + r, cy + int(r * 0.8)), fill=LEAF, outline=OUTLINE, width=3)
        d.ellipse((cx - r // 2, cy - int(r * 0.55), cx + r // 2 - r // 6, cy - int(r * 0.2)), fill=LEAF_DARK)
    if stage >= 3:
        for bx, by in [(-52, -trunk_h - 34), (38, -trunk_h - 66), (8, -trunk_h - 128), (-14, -trunk_h + 8)]:
            cx, cy = base_x + bx, ground_y + by
            for off in [(-5, 0), (5, 0), (0, -5), (0, 5), (0, 0)]:
                d.ellipse((cx + off[0] - 3, cy + off[1] - 3, cx + off[0] + 3, cy + off[1] + 3), fill=BERRY, outline=OUTLINE, width=1)
    return im


def main():
    crop_dir = ROOT / 'assets/farming/crops/mulberry_tree'
    crop_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = ROOT / 'assets/farming/crops/plant_manifest.json'
    ground_path = ROOT / 'content/farming/p8/grounding.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    grounding = json.loads(ground_path.read_text(encoding='utf-8'))
    reference = manifest['plants']['resin_tree']
    stages = {}
    hashes = {}
    for stage in range(4):
        im = tree(stage)
        assert set(im.getchannel('A').get_flattened_data()) == {0, 255}, 'hard alpha required'
        path = crop_dir / f'stage_{stage}.png'
        im.save(path)
        key = f'stage_{stage}'
        stages[key] = f'res://assets/farming/crops/mulberry_tree/stage_{stage}.png'
        hashes[key] = hashlib.sha256(path.read_bytes()).hexdigest()
    manifest['plants']['mulberry_tree'] = {
        'footprint': reference['footprint'], 'canvas_px': reference['canvas_px'],
        'anchor_uv': reference['anchor_uv'], 'draw_size': reference['draw_size'],
        'scale_multiplier': 1.0, 'stages': stages, 'sha256': hashes,
    }
    grounding['plants']['mulberry_tree'] = grounding['plants']['resin_tree']
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    ground_path.write_text(json.dumps(grounding, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    out = ROOT / '.art-work/p105-art'
    out.mkdir(parents=True, exist_ok=True)
    sheet = Image.new('RGBA', (2048, 768), '#ddd9c9')
    for stage in range(4):
        sheet.alpha_composite(tree(stage), (stage * 512, 0))
    sheet.save(out / 'mulberry_stages.png')
    print('P105 PLANT OK: mulberry_tree 4 stages, manifest+grounding wired')


if __name__ == '__main__':
    main()
