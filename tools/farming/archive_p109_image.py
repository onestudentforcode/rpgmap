"""Archive an original ImageGen PNG and its measured file facts, without editing pixels."""
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
    ap.add_argument('--source', required=True)
    args = ap.parse_args()
    manifest_path = DEST / 'manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    entry = next(e for e in manifest['assets'] if e['id'] == args.id)
    source = Path(args.source).resolve()
    destination = (DEST / entry['file']).resolve()
    if not destination.is_relative_to(DEST.resolve()):
        raise ValueError('Destination outside production source folder')
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        if hashlib.sha256(destination.read_bytes()).digest() != hashlib.sha256(source.read_bytes()).digest():
            raise FileExistsError(f'Preserve existing asset: {destination}')
    else:
        shutil.copy2(source, destination)
    with Image.open(destination) as im:
        mode, size = im.mode, list(im.size)
        alpha = im.getchannel('A') if 'A' in im.getbands() else None
        bbox = alpha.point(lambda a: 255 if a >= 16 else 0).getbbox() if alpha else None
        facts = {
            'sha256': hashlib.sha256(destination.read_bytes()).hexdigest(),
            'canvas_px': size, 'mode': mode,
            'alpha_extrema': list(alpha.getextrema()) if alpha else None,
            'main_bbox_alpha_ge_16': list(bbox) if bbox else None,
            'corner_alpha': [alpha.getpixel(p) for p in [(0, 0), (im.width-1, 0), (0, im.height-1), (im.width-1, im.height-1)]] if alpha else None,
            'main_subject_within_canvas': bool(bbox and bbox[0] > 0 and bbox[1] > 0 and bbox[2] < im.width and bbox[3] < im.height),
        }
    entry.update(facts)
    entry['source_file'] = str(source)
    entry['status'] = 'produced_adult_source'
    entry['camera_calibrated'] = False
    entry['runtime_integrated'] = False
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'id': entry['id'], 'file': str(destination), **facts}, ensure_ascii=True))


if __name__ == '__main__':
    main()
