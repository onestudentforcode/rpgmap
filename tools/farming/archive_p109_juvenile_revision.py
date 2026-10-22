"""Archive one age-corrected juvenile source and retain earlier revisions."""
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
    request_path = DEST / 'juvenile_revision_requests.json'
    requests = json.loads(request_path.read_text(encoding='utf-8'))
    req = next(r for r in requests['requests'] if r['id'] == args.id)
    rel = f"{req['category']}/{args.id}/{args.id}_juvenile_view35_{req['version']}.png"
    target = (DEST / rel).resolve()
    if not target.is_relative_to(DEST.resolve()):
        raise ValueError('Destination outside source directory')
    source = Path(args.source).resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() and target.read_bytes() != source.read_bytes():
        raise FileExistsError(f'Preserve existing revision: {target}')
    if not target.exists():
        shutil.copy2(source, target)
    with Image.open(target) as im:
        alpha = im.getchannel('A') if 'A' in im.getbands() else None
        bbox = alpha.point(lambda v: 255 if v >= 16 else 0).getbbox() if alpha else None
        facts = dict(sha256=hashlib.sha256(target.read_bytes()).hexdigest(), canvas_px=list(im.size), mode=im.mode,
                     alpha_extrema=list(alpha.getextrema()) if alpha else None,
                     main_bbox_alpha_ge_16=list(bbox) if bbox else None,
                     main_subject_within_canvas=bool(bbox and bbox[0] > 0 and bbox[1] > 0 and bbox[2] < im.width and bbox[3] < im.height))
    mp = DEST / 'states_manifest.json'
    manifest = json.loads(mp.read_text(encoding='utf-8'))
    old = next((r for r in manifest['assets'] if r['id'] == args.id and r['state'] == 'juvenile'), None)
    history = old.get('previous_revisions', []) if old else []
    if old and old['file'] != rel:
        history.append({k: v for k, v in old.items() if k != 'previous_revisions'})
    row = dict(id=args.id, category=req['category'], state='juvenile', version=req['version'], file=rel,
               source_file=str(source), reference_file=req['reference_file'], prompt=req['prompt'],
               status='age_corrected_source_awaiting_user_acceptance', visual_acceptance='pending',
               runtime_integrated=False, camera_calibrated=False, previous_revisions=history, **facts)
    if old:
        old.clear()
        old.update(row)
    else:
        manifest['assets'].append(row)
    manifest['production_summary']['registered_states'] = len(manifest['assets'])
    req.update(status='produced_awaiting_user_acceptance', output_file=rel, source_file=str(source), **facts)
    request_path.write_text(json.dumps(requests, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    mp.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(dict(id=args.id, file=rel, **facts), ensure_ascii=True))


if __name__ == '__main__':
    main()
