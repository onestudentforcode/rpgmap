"""Verify P8.7 source, regression, GPU and Windows artifacts before recording delivery."""
import hashlib
import json
import re
import zipfile
from pathlib import Path
from PIL import Image
from qc_p87_visuals import check

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def checked_log(relative, marker):
    path = ROOT/relative
    text = path.read_text(encoding='utf-8')
    assert marker in text and 'SCRIPT ERROR:' not in text and 'FARMING TEST SUITE FAILED' not in text, relative
    return {'path':relative,'sha256':digest(path),'completion_marker':marker}


def main():
    qc = check(ROOT/'.art-work/p87-final-visual')
    projection = read(ROOT/'content/farming/p8/p87_projection.json')
    assert projection['default_enabled'] and projection['elevation_degrees']==35
    assert (ROOT/'scenes/farming/farm_p8.tscn').read_bytes()==(ROOT/'scenes/farming/farm_p87.tscn').read_bytes()
    assert 'p8/p87_scene.gd' in (ROOT/'scenes/farming/farm_p8.tscn').read_text(encoding='utf-8')
    suite = checked_log('.art-work/p87-full-regression.log','FARMING TEST SUITE OK')
    suite['exit_code'] = 0
    suite['command'] = 'test.bat'
    suite['final_shadow_delta_verification'] = '146 production / 89 projection / 324 interactions, final 60 GPU frames and packaged probes rerun after requested shadows; full suite gameplay coverage retained'
    tests = {}
    for name,marker in [('projection-tests','P87 PROJECTION OK: 89 checks'),('production-tests','P87 PRODUCTION OK: 146 checks'),
        ('interaction-tests','P87 INTERACTIONS OK: 324 checks'),('v1-ui-compatibility','V1 PHASE65 UI TEST OK: 79 checks'),
        ('p85-lifecycle','PHASE085 VISUALS OK: 209 checks'),('p86-production','P86 PRODUCTION OK: 95 checks')]:
        tests[name] = checked_log('.art-work/p87-trial/'+name+'.engine.log',marker)
    default = checked_log('.art-work/p87-default-entry.log','P8 RELEASE SMOKE OK (20 checks)')
    manifest = read(ROOT/'dist/lingtian-p87-demo/manifest.json')
    assert manifest['schema']==17 and manifest['raw_png_count']==qc['png_count']
    runtime = []
    for item in manifest['source_files']:
        name = item['name']
        if name.endswith(('.gd','.gdshader')) or name in ('content/farming/p8/p87_projection.json','content/farming/p8/p87_shadows.json','scenes/farming/farm_p8.tscn'):
            assert (ROOT/name).exists() and digest(ROOT/name)==item['sha256'], 'packaged source differs: '+name
            runtime.append(name)
    archive = ROOT/'dist/LingTianDemoP87-Windows-x64.zip'
    with zipfile.ZipFile(archive) as zipped:
        assert set(zipped.namelist()) == {'LingTianDemoP87.exe','README.txt','README.md','manifest.json'}
        archived_manifest = json.loads(zipped.read('manifest.json').decode('utf-8-sig'))
        assert archived_manifest==manifest
        for item in manifest['files']:
            assert hashlib.sha256(zipped.read(item['name'])).hexdigest()==item['sha256']
    probes = {}
    for name,number in [('standalone',91),('unpacked',91),('unpacked-gpu',93)]:
        probes[name] = {**checked_log('.art-work/p87-release-logs/'+name+'.log',f'P87 RELEASE SMOKE OK: {number} checks'),'checks':number}
    gpu_path = ROOT/'.art-work/p87-release-logs/packaged-render.png'
    with Image.open(gpu_path) as image: assert image.size==(1920,1080)
    report = {'date':'2026-10-15','phase':'P8.7','status':'completed_default_switched_and_packaged','save_schema':17,
        'user_visual_acceptance':{'sample_accepted':True,'sample_quote':'接受35°样板，继续B～D',
            'final_quote':'适当补充一些阴影，最终画面基本上接受','final_acceptance_kind':'qualified acceptance with a requested minor shadow refinement',
            'requested_shadows_implemented':True,'post_shadow_agent_gpu_review':True,'separate_post_shadow_user_review_not_claimed':True},
        'projection':{'elevation_degrees':35,'logical_cell':[64,64],'view_cell':[64,64*0.573576436351046],
            'body_pngs_resquashed':False,'root_policy':'actual model origin at footprint center','default_scene_sha256':digest(ROOT/'scenes/farming/farm_p8.tscn')},
        'artifacts':{'asset_qc':'p87-asset-qc.json','visual_baseline':'p87-visual-baseline.json','camera_calibration':'p87-camera-calibration.json',
            'pngs':qc['png_count'],'gpu_frames':qc['gpu_frames'],'gpu_directory':'.art-work/p87-final-visual'},
        'full_suite':suite,'final_specialized_checks':tests,'default_entry':default,
        'package':{'path':archive.relative_to(ROOT).as_posix(),'bytes':archive.stat().st_size,'sha256':digest(archive),
            'source_revision':manifest['source_revision'],'source_dirty':manifest['source_dirty'],'runtime_config_and_scene_hashes_matched':len(runtime),
            'verified_runtime_files':runtime,'probes':probes,'gpu_frame_sha256':digest(gpu_path),'gpu_viewport':[1920,1080]},
        'commits_before_final_delivery':['3ebc64e','75b735f','74c4565','1eef1d9'],
        'deferred':['real-time 3D and free camera rotation','animal models','facility work effects','post-harvest shapes','gameplay expansion']}
    (ROOT/'docs/farming/art/p87-final-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('P87 FINAL DELIVERY OK:',qc['gpu_frames'],'GPU frames,',len(runtime),'packaged source hashes matched, SHA256='+report['package']['sha256'])


if __name__=='__main__':
    main()
