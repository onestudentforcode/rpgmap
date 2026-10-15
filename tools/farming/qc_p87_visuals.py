"""P8.7 production contracts and actual GPU evidence. Baseline updates are explicit."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check(shots, freeze=False):
    entries = []
    for ident, item in read(ROOT/'assets/farming/crops/plant_manifest.json')['plants'].items():
        for state,path in item['stages'].items():
            entries.append((ident,state,path,item['sha256'][state],item))
    for ident,item in read(ROOT/'assets/farming/facilities/facility_manifest.json')['facilities'].items():
        entries.append((ident,'body',item['path'],item['sha256'],item))
    scenery = read(ROOT/'assets/farming/p86/resource_manifest.json')
    for ident,item in scenery['resources'].items():
        entries.append((ident,'resource',item['path'],item['sha256'],item))
    item = scenery['transition']
    entries.append(('transition','atlas',item['path'],item['sha256'],item))
    contracts = {}
    for ident,state,path,expected,visual in entries:
        file = ROOT/path.removeprefix('res://')
        assert digest(file)==expected, path
        with Image.open(file) as image:
            assert image.mode=='RGBA' and list(image.size)==visual['canvas_px'], path
        contracts[path] = {key:visual[key] for key in ('canvas_px','anchor_uv','draw_size','scale_multiplier') if key in visual}
        contracts[path]['sha256'] = expected
    projection_files = ('content/farming/p8/p87_projection.json','scripts/farming/p8/p87_projection.gd',
        'scripts/farming/p8/p87_scene.gd','scripts/farming/p8/p87_grounding.gd','content/farming/p8/p87_shadows.json',
        'assets/farming/shaders/p87_surface.gdshader','assets/farming/shaders/p87_shore.gdshader')
    baseline = {'revision':'p87','assets':contracts,'projection_files':{name:digest(ROOT/name) for name in projection_files}}
    baseline_path = ROOT/'docs/farming/art/p87-visual-baseline.json'
    if freeze:
        baseline_path.write_text(json.dumps(baseline,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    else:
        assert baseline_path.exists() and read(baseline_path)==baseline,'P8.7 contract changed; review and explicitly freeze intentional changes'
    names = {'pilot','all-plants','all-facilities','negative-land','build-preview-0','build-preview-14',
        'dense-0.1','dense-1.0','dense-3.0','dense-pan','resources','facility-catalog','shore-topology-1.0','shore-topology-3.0'}
    names.update(f'ui-{scale}-side-{side}' for scale in (100,125,150) for side in ('false','true'))
    profiles = []
    for size in ('2560x1440','1920x1080','960x540'):
        folder = shots/size
        expected = tuple(map(int,size.split('x')))
        report = read(folder/'frames.json')
        assert {Path(frame['file']).stem for frame in report['frames']}==names
        assert {p.stem for p in folder.glob('*.png')}==names
        records = []
        for frame in report['frames']:
            file = folder/frame['file']
            with Image.open(file) as image:
                assert image.size==expected, str(file)
            assert tuple(frame['size'])==expected and abs(frame['depth']-0.573576436)<1e-5
            assert 0 < frame['ui_scale_effective'] <= frame['ui_scale_requested']
            records.append({**frame,'sha256':digest(file)})
        log_path = shots/(size+'.log')
        log = log_path.read_text(encoding='utf-8')
        assert 'P87 FULL VISUAL PREVIEW OK' in log and 'ERROR:' not in log
        profiles.append({'viewport':list(expected),'frames':records,'gpu_log_sha256':digest(log_path)})
    return {'revision':'p87','png_count':len(contracts),'gpu_frames':sum(len(p['frames']) for p in profiles),
        'viewports':profiles,'sample_user_accepted':True,'final_user_acceptance':'recorded separately from technical QC',
        'baseline':'p87-visual-baseline.json','baseline_sha256':digest(baseline_path)}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--shots',type=Path,default=ROOT/'.art-work/p87-final-visual')
    parser.add_argument('--freeze-baseline',action='store_true')
    args=parser.parse_args()
    report=check(args.shots,args.freeze_baseline)
    (ROOT/'docs/farming/art/p87-asset-qc.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    pictures=''.join(f'<figure><figcaption>{name}</figcaption><a href="1920x1080/{name}.png"><img src="1920x1080/{name}.png"></a></figure>' for name in ('all-plants','all-facilities','dense-1.0','negative-land','resources','shore-topology-1.0','ui-100-side-true','ui-150-side-true'))
    (args.shots/'review.html').write_text('<!doctype html><meta charset="utf-8"><title>P8.7 final review</title><style>body{font:16px sans-serif;background:#f6f4eb;color:#33443a;margin:24px}figure{margin:24px 0}img{max-width:100%}</style><h1>P8.7 final production review</h1><p>35 degree projection. Synthetic fixture scenes; no screenshot retouching. Click images for originals.</p>'+pictures,encoding='utf-8')
    print(f"P87 VISUAL QC OK: {report['png_count']} PNGs, {report['gpu_frames']} actual GPU frames")


if __name__=='__main__':
    main()
