"""Deterministic, premultiplied-alpha runtime export; never changes source art.

Run from the repository root: python tools/farming/export_p109_plants.py
Root coordinates are hand marked at the root crown / floating leaf plane.
Alpha bounds measure size and padding only; they do not define ground contact.
"""
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'assets/farming/p109/source'
OUTPUT = ROOT / 'assets/farming/p109/runtime'
DENSITY = 4
# draw canvas, root in view units, height above root (duckweed: width), source roots UV.
RECIPES = {
    'golden_wheat': ([88, 88], [44, 80], [10, 24, 42, 60], [( .51,.82),(.52,.86),(.52,.925),(.50,.94)]),
    'fast_fir': ([176, 192], [88, 176], [14, 46, 93, 140], [(.52,.80),(.50,.88),(.51,.95),(.52,.95)]),
    'resin_tree': ([176, 192], [88, 176], [14, 42, 84, 135], [(.54,.86),(.54,.855),(.52,.925),(.51,.94)]),
    'wood_decay_mushroom': ([80, 72], [40, 65], [9, 18, 29, 42], [(.51,.80),(.51,.86),(.51,.92),(.51,.93)]),
    'pasture_grass': ([88, 72], [44, 65], [8, 17, 30, 42], [(.50,.735),(.50,.865),(.50,.88),(.50,.90)]),
    'honeybell_bush': ([88, 88], [44, 80], [10, 22, 38, 56], [(.51,.79),(.51,.85),(.50,.935),(.50,.95)]),
    'oilseed_flower': ([88, 96], [44, 88], [10, 22, 42, 61], [(.50,.68),(.52,.79),(.50,.915),(.50,.885)]),
    'mulberry_tree': ([176, 192], [88, 176], [14, 44, 88, 135], [(.51,.78),(.51,.84),(.50,.925),(.50,.92)]),
    'duckweed': ([80, 64], [40, 26], [15, 28, 44, 59], [(.50,.47),(.50,.46),(.50,.45),(.50,.43)]),
    'reed': ([96, 112], [48, 104], [12, 27, 47, 67], [(.50,.79),(.50,.84),(.50,.92),(.50,.93)]),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def main():
    selected = {}
    for manifest in ['manifest.json', 'states_manifest.json']:
        for asset in json.loads((SOURCE / manifest).read_text(encoding='utf-8'))['assets']:
            if asset['category'] == 'plants':
                key = 'stage_3' if asset['state'] == 'mature' else asset['state']
                assert (asset['id'], key) not in selected
                selected[asset['id'], key] = asset
    legacy = json.loads((ROOT / 'assets/farming/crops/plant_manifest.json').read_text(encoding='utf-8'))
    manifest = {'schema_version': 1, 'profile': 'p109', 'logical_cell_size': 64,
                'texture_filter': 'linear_with_mipmaps', 'pixels_per_view_unit': DENSITY,
                'camera_calibrated': False, 'visual_acceptance': 'in_game_preview_pending', 'plants': {}}
    sheet = Image.new('RGB', (1100, len(RECIPES)*220), '#8d9d83')
    pen = ImageDraw.Draw(sheet)
    for row, (ident, (draw, root, sizes, roots)) in enumerate(RECIPES.items()):
        canvas = [v*DENSITY for v in draw]
        anchor_px = [v*DENSITY for v in root]
        plant = {'footprint': legacy['plants'][ident]['footprint'], 'canvas_px': canvas,
                 'anchor_uv': [root[i]/draw[i] for i in range(2)], 'draw_size': draw,
                 'scale_multiplier': 1.0, 'stages': {}, 'sha256': {}, 'exports': {}}
        keys = ['stage_0','stage_1','stage_2','stage_3'] + (['flowering'] if ident == 'oilseed_flower' else [])
        for column, key in enumerate(keys):
            asset = selected[ident, key]
            source = SOURCE / asset['file']
            assert sha(source) == asset['sha256'], source
            image = Image.open(source).convert('RGBA')
            index = int(key[-1]) if key.startswith('stage_') else 3
            root_uv = roots[index] if key != 'flowering' else (.50,.915)
            source_root = [image.width*root_uv[0], image.height*root_uv[1]]
            bounds = image.getchannel('A').point(lambda a: 255 if a >= 8 else 0).getbbox()
            assert bounds
            crop = (max(0,bounds[0]-3), max(0,bounds[1]-3), min(image.width,bounds[2]+3), min(image.height,bounds[3]+3))
            measurement = bounds[2]-bounds[0] if ident == 'duckweed' else source_root[1]-bounds[1]
            scale = sizes[index]*DENSITY/measurement
            patch = image.crop(crop)
            resized_size = [max(1,round(v*scale)) for v in patch.size]
            actual_scale = [resized_size[i]/patch.size[i] for i in range(2)]
            # Filter premultiplied channels so invisible RGB cannot bleed into edges.
            patch = patch.convert('RGBa').resize(resized_size, Image.Resampling.LANCZOS).convert('RGBA')
            offset = [round(anchor_px[i]-(source_root[i]-crop[i])*actual_scale[i]) for i in range(2)]
            assert min(offset) >= 0 and all(offset[i]+resized_size[i] <= canvas[i] for i in range(2)), (ident,key,offset,resized_size,canvas)
            result = Image.new('RGBA', canvas)
            result.paste(patch, offset)
            target = OUTPUT / 'plants' / ident / (key+'.png')
            target.parent.mkdir(parents=True, exist_ok=True)
            result.save(target, optimize=True)
            assert result.getpixel((0,0))[3] == 0
            relative = target.relative_to(ROOT).as_posix()
            plant['stages'][key] = 'res://'+relative
            plant['sha256'][key] = sha(target)
            plant['exports'][key] = {'source_file': source.relative_to(ROOT).as_posix(), 'source_sha256': asset['sha256'],
                'source_root_uv': root_uv, 'root_annotation': 'floating_leaf_plane' if ident == 'duckweed' else 'root_crown',
                'source_crop_px': crop, 'resized_px': resized_size, 'paste_px': offset,
                'root_error_px': [offset[i]+(source_root[i]-crop[i])*actual_scale[i]-anchor_px[i] for i in range(2)],
                'size_axis': 'width' if ident == 'duckweed' else 'height_above_root', 'target_view_units': sizes[index],
                'source_acceptance': 'mature_user_accepted' if key == 'stage_3' else 'growth_state_review_pending'}
            # Consistent per-row zoom, no per-stage fit: shows real growth ratios.
            thumb = result.resize((draw[0],draw[1]), Image.Resampling.LANCZOS)
            x, y = column*220+110-root[0], row*220+202-root[1]
            sheet.paste(thumb, (x,y), thumb)
            pen.line((column*220+100,row*220+202,column*220+120,row*220+202),fill='#ffe5a8')
            pen.text((column*220+6,row*220+4),ident+' / '+key,fill='white')
        manifest['plants'][ident] = plant
    assert sum(len(p['stages']) for p in manifest['plants'].values()) == 41
    save_json(OUTPUT/'plant_manifest.json',manifest)
    inventory_path = ROOT/'docs/farming/art/p109-replacement-inventory.json'
    inventory = json.loads(inventory_path.read_text(encoding='utf-8'))
    inventory['kind'] = 'source_inventory_with_runtime_progress'
    inventory['runtime_changes_made'] = True
    inventory['plant_runtime_manifest'] = 'assets/farming/p109/runtime/plant_manifest.json'
    inventory['summary'].update({'plant_runtime_images':41, 'living_runtime_images':0,
        'remaining_plant_images':0, 'remaining_living_images':34, 'R1':'plant_subset_exported_living_subset_pending',
        'R2':'all_plants_integrated_preview_pending_user_review',
        'R4':'all_plants_integrated_preview_pending_user_review'})
    for asset in inventory['assets']:
        if asset['category'] != 'plants': continue
        data = manifest['plants'][asset['id']]
        key = asset['runtime_state_key']
        assert asset['source_sha256'] == data['exports'][key]['source_sha256']
        asset.update({'status':'runtime_preview_integrated_pending_user_review', 'runtime_integrated':True,
            'runtime_file': data['stages'][key].removeprefix('res://'), 'runtime_sha256':data['sha256'][key],
            'runtime_metadata':{field:data[field] for field in ['canvas_px','anchor_uv','draw_size']}})
        asset['runtime_metadata'].update({'camera_verified':False, 'root_annotation':data['exports'][key]['root_annotation'],
            'source_root_uv':data['exports'][key]['source_root_uv'], 'export':data['exports'][key]})
    save_json(inventory_path,inventory)
    qc = ROOT/'.art-work/p109/plant-preview'
    qc.mkdir(parents=True,exist_ok=True)
    sheet.save(qc/'runtime-contact-sheet.jpg',quality=94)
    print('Exported 41 plant textures; sources verified; fixed species canvases and root anchors.')


if __name__ == '__main__':
    main()
