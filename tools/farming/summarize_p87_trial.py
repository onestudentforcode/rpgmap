"""Validate P8.7 GPU evidence and build a gallery of untouched screenshots."""
import hashlib
import html
import json
import re
import argparse
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SHOTS = ROOT/'.art-work/p87-trial'
NAMES = ('scene-1.0','plants-1.0','seedlings-3.0','shore-1.0','shore-3.0',
         'resources-3.0','overview-0.1','fit-to-play','clean-fit-to-play','sidebar-1.0','build-preview')


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def checked_log(path, marker):
    text = path.read_text(encoding='utf-8')
    checked = re.sub(r'ERROR: Failed to read the root certificate store\.\s+at: get_system_ca_certificates \(platform/windows/os_windows.cpp:2582\)\s*','',text)
    assert marker in checked and not re.search(r'SCRIPT ERROR:|ERROR:',checked), str(path)
    return {'path':path.relative_to(ROOT).as_posix(),'sha256':digest(path),
            'os_certificate_diagnostic_present':'Failed to read the root certificate store.' in text}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--record-acceptance', action='store_true',help='record the user confirmation received after reviewing A; never infer it from QC')
    args = parser.parse_args()
    calibration_path = ROOT/'docs/farming/art/p87-camera-calibration.json'
    calibration = read(calibration_path)
    assert calibration['body_renders_checked'] == 44 and len(calibration['resources']) == 3
    tests = checked_log(SHOTS/'projection-tests.engine.log','P87 PROJECTION OK:')
    tests['checks'] = int(re.search(r'P87 PROJECTION OK: (\d+) checks',(SHOTS/'projection-tests.engine.log').read_text(encoding='utf-8'))[1])
    profiles = []
    expected = {profile+'-'+name+'.png' for profile in ('p86','matched35') for name in NAMES}
    for size in ('2560x1440','1920x1080','960x540'):
        folder = SHOTS/size
        dimensions = tuple(map(int,size.split('x')))
        trial = read(folder/'trial.json')
        assert not trial['failures'] and not trial['sample_user_accepted']
        assert trial['world_hash_before'] == trial['world_hash_after']
        assert set(frame['file'] for frame in trial['frames']) == expected
        assert set(p.name for p in folder.glob('*.png')) == expected
        assert tuple(read(folder/'dimensions.json')['viewport']) == dimensions
        entries = []
        for frame in trial['frames']:
            path = folder/frame['file']
            with Image.open(path) as image:
                assert image.size == dimensions
                assert image.convert('L').getextrema()[0] < image.convert('L').getextrema()[1]
            entries.append({**frame,'sha256':digest(path)})
        profiles.append({'viewport':list(dimensions),'frames':entries,
            'world_snapshot_sha256':trial['world_hash_before'],
            'gpu_log':checked_log(SHOTS/(size+'.engine.log'),'P87 VISUAL PREVIEW OK: 22 frames')})
    # Existing PNGs must still agree with P8.6 manifests; the trial renders no replacement art.
    installed = []
    plants = read(ROOT/'assets/farming/crops/plant_manifest.json')['plants']
    for item in plants.values():
        installed.extend((path,item['sha256'][state]) for state,path in item['stages'].items())
    for item in read(ROOT/'assets/farming/facilities/facility_manifest.json')['facilities'].values():
        installed.append((item['path'],item['sha256']))
    scenery = read(ROOT/'assets/farming/p86/resource_manifest.json')
    installed.extend((item['path'],item['sha256']) for item in [*scenery['resources'].values(),scenery['transition']])
    for path, expected_hash in installed:
        assert digest(ROOT/path.removeprefix('res://')) == expected_hash, path
    target = ROOT/'docs/farming/art/p87-trial-validation.json'
    accepted = args.record_acceptance or (target.exists() and read(target).get('sample_user_accepted') is True)
    regression = {}
    for name,marker in [('p85-lifecycle','PHASE085 VISUALS OK: 209 checks'),('p86-production','P86 PRODUCTION OK: 95 checks')]:
        regression[name] = checked_log(SHOTS/(name+'.engine.log'),marker)
    report = {'date':'2026-10-15','phase':'P8.7 A','status':'sample_user_accepted' if accepted else 'implemented_local_checks_passed_awaiting_sample_acceptance',
        'sample_user_accepted':accepted,'sample_confirmation':'接受35°样板，继续B～D' if accepted else None,'default_game':'P8.6 unchanged at A delivery',
        'calibration':{'path':calibration_path.relative_to(ROOT).as_posix(),'sha256':digest(calibration_path),
            'body_renders':44,'resource_rigs':3,'unchanged_source_files':calibration['source_files_checked_unchanged']},
        'projection_tests':tests,'existing_visual_regressions':regression,'p86_png_hashes_verified':len(installed),
        'gpu_frames':sum(len(p['frames']) for p in profiles),'viewports':profiles,
        'remaining':([] if accepted else ['user A sample acceptance'])+['B production integration','C complete interaction/camera audit','D full regression and Windows delivery']}
    target.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    sections = []
    for name in ('clean-fit-to-play','scene-1.0','plants-1.0','seedlings-3.0','shore-3.0','resources-3.0','sidebar-1.0','build-preview'):
        pictures = ''.join(f'<figure><figcaption>{label}</figcaption><a href="1920x1080/{profile}-{name}.png"><img src="1920x1080/{profile}-{name}.png"></a></figure>' for profile,label in (('p86','P8.6 ground projection'),('matched35','35 degree matched ground')))
        sections.append(f'<h2>{html.escape(name)}</h2><div>{pictures}</div>')
    (SHOTS/'review.html').write_text('<!doctype html><meta charset="utf-8"><title>P8.7 A projection review</title><style>body{background:#f6f4eb;color:#33443a;font:16px sans-serif;margin:24px}div{display:flex;gap:16px}figure{margin:0;width:50%}img{width:100%}figcaption{padding:8px}h2{margin-top:32px}</style><h1>P8.7 A: projection review</h1><p>Same world snapshot; synthetic stock, research, growth and L-shore. Full-size originals open on click. Fit-to-play images use their own labelled zoom; all other pairs share horizontal scale. No screenshot retouching. User sample acceptance pending.</p>'+''.join(sections),encoding='utf-8')
    print(f"P87 TRIAL QC OK: {report['gpu_frames']} GPU frames, {tests['checks']} projection checks, {len(installed)} unchanged P8.6 PNGs")


if __name__ == '__main__':
    main()
