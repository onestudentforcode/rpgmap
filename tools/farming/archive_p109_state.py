"""Archive a generated P10.9 non-adult state PNG without editing its pixels."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'assets/farming/p109/source'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--id', required=True)
    ap.add_argument('--category', required=True, choices=['plants', 'animals', 'aquatic', 'living'])
    ap.add_argument('--state', required=True)
    ap.add_argument('--source', required=True)
    ap.add_argument('--prompt', required=True)
    ap.add_argument('--reference', required=True)
    args = ap.parse_args()
    state = json.loads((DEST / 'states_manifest.json').read_text(encoding='utf-8'))
    rel = Path(args.category) / args.id / f'{args.id}_{args.state}_view35_v001.png'
    target = (DEST / rel).resolve()
    if not target.is_relative_to(DEST.resolve()):
        raise ValueError('Destination outside source folder')
    source = Path(args.source).resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        if hashlib.sha256(target.read_bytes()).digest() != hashlib.sha256(source.read_bytes()).digest():
            raise FileExistsError(f'Preserving existing state asset: {target}')
    else:
        shutil.copy2(source, target)
    with Image.open(target) as im:
        alpha = im.getchannel('A') if 'A' in im.getbands() else None
        bbox = alpha.point(lambda a: 255 if a >= 16 else 0).getbbox() if alpha else None
        facts = {
            'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
            'canvas_px': list(im.size), 'mode': im.mode,
            'alpha_extrema': list(alpha.getextrema()) if alpha else None,
            'main_bbox_alpha_ge_16': list(bbox) if bbox else None,
            'main_subject_within_canvas': bool(bbox and bbox[0] > 0 and bbox[1] > 0 and bbox[2] < im.width and bbox[3] < im.height),
        }
    row = {
        'id': args.id, 'category': args.category, 'state': args.state,
        'file': rel.as_posix(), 'source_file': str(source),
        'reference_file': args.reference, 'prompt': args.prompt,
        'status': 'produced_state_source', 'runtime_integrated': False,
        'camera_calibrated': False, **facts,
    }
    assets = state['assets']
    old = next((i for i, a in enumerate(assets) if a['id'] == args.id and a['state'] == args.state), None)
    if old is None:
        assets.append(row)
    else:
        assets[old] = row
    state['production_summary']['registered_states'] = len(assets)
    state['production_summary']['runtime_integrated'] = False
    (DEST / 'states_manifest.json').write_text(json.dumps(state, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'id': args.id, 'state': args.state, 'file': str(target), **facts}, ensure_ascii=True))


if __name__ == '__main__':
    main()
