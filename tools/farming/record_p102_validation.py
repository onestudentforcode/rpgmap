"""Record completed P10.2 gates only after checking their retained evidence."""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[2]
CERT=re.compile(r'ERROR: Failed to read the root certificate store\.\s+at: get_system_ca_certificates \(platform/windows/os_windows.cpp:2582\)\s*')


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def entry(path): return {'path':path.relative_to(ROOT).as_posix(),'sha256':sha(path)}


def log(path,marker):
    value=path.read_text(encoding='utf-8-sig')
    assert marker in value,(path,marker)
    assert not re.search(r'SCRIPT ERROR:|ERROR:|\bFAIL(?:ED)?\b',CERT.sub('',value)),path
    return {**entry(path),'marker':marker}


def record(evidence):
    business=read(ROOT/'docs/farming/phase102-business.json')
    assert business['status']=='complete' and business['evidence_root']==evidence.relative_to(ROOT).as_posix()
    assert len(business['routes'])==8
    for name,digest in business['auditors_sha256'].items(): assert sha(ROOT/name)==digest,('auditor changed',name)
    manifests=[]
    for mode in ('ordinary','seed','material','compound'):
        folder=evidence/mode
        manifest=read(folder/'manifest.json')
        for name,digest in manifest.items(): assert sha(ROOT/name)==digest,('game source changed',name)
        manifests.append(manifest)
        for route in ('A','B'):
            for name,digest in business['routes'][f'{mode}/{route}']['evidence_sha256'].items():
                assert sha(folder/name)==digest,('evidence changed',mode,route,name)
            status=read(evidence/f'{mode}-parts'/route/'run-process.json')
            assert status['status']=='exited' and status['exit_code']==0,(mode,route,status)
            log(evidence/f'{mode}-{route}.stdout.log','P8 OPERATIONS PLAYTEST OK')
            stderr=(evidence/f'{mode}-{route}.stderr.log').read_text(encoding='utf-8-sig')
            assert not re.search(r'SCRIPT ERROR:|ERROR:',CERT.sub('',stderr))
    assert all(m==manifests[0] for m in manifests),'comparison source manifests differ'
    assert sha(evidence/'room-negative/results.json')==business['negative_probes']['sha256']
    tests=ROOT/'.art-work/p102-tests'
    checks={}
    for name,marker in {
        'model':'P102 MODEL OK (209)','ui':'P102 UI OK (30)',
        'logistics-model':'PHASE10 TEST OK (181)','logistics-ui':'PHASE10 UI OK (21)',
        'agriculture-model':'PHASE101 TEST OK (154)','agriculture-ui':'PHASE101 UI OK (28)',
        'handbook-ui':'P8 HANDBOOK UI OK: 89 checks','encyclopedia-ui':'P9 ENCYCLOPEDIA OK: 44 checks',
        'handbook-doc':'P8 HANDBOOK DOC OK: 14 chapters',
        'encyclopedia-doc':'P8 ENCYCLOPEDIA DOC OK: 200 entities / 17 rules',
        'business-layout':'P102 BUSINESS LAYOUT OK (49)',
    }.items():
        checks[name]=log(tests/f'{name}.stdout.log',marker)
        error=(tests/f'{name}.stderr.log').read_text(encoding='utf-8-sig')
        assert not re.search(r'SCRIPT ERROR:|ERROR:',CERT.sub('',error)),name
    checks['gpu']=log(ROOT/'.art-work/p102-gpu.engine.log','P102 UI OK (37)')
    checks['python']=log(ROOT/'.art-work/p102-python-final.log','Ran 129 tests')
    assert '\nOK' in (ROOT/'.art-work/p102-python-final.log').read_text(encoding='utf-8-sig')
    for name,root,count in [('full_p8',ROOT/'.art-work/p8-tests',26),('historical_v1_v2',ROOT/'.art-work/p102-historical',22)]:
        files=sorted(root.glob('*.stdout.log'))
        assert len(files)==count,(name,len(files),count)
        gates=[]
        for path in files:
            value=path.read_text(encoding='utf-8-sig')
            markers=[line for line in value.splitlines() if re.search(r'\bOK\b',line)]
            assert markers,('no successful terminal marker',path)
            gates.append(log(path,markers[-1]))
            if name=='full_p8':
                # test_p8.ps1 captures native stderr into the stdout evidence.
                gates[-1]['combined_stdout_stderr']=True
            else:
                error=path.with_name(path.name.replace('.stdout.log','.stderr.log')).read_text(encoding='utf-8-sig')
                assert not re.search(r'SCRIPT ERROR:|ERROR:',CERT.sub('',error)),path
        checks[name]={'isolated_workspace_stores':True,'gates':gates}
    qc=ROOT/'.art-work/p102-asset-qc.json';items=read(qc)
    assert len(items)==75 and not any(i['errors'] for i in items)
    checks['assets']={**entry(qc),'checked':75,'failed':0,'historical_palette_warnings_retained':True}
    shots=sorted((ROOT/'.shots/p102').glob('*.png'));assert len(shots)==7
    from PIL import Image
    screenshots=[]
    for path in shots:
        with Image.open(path) as im:
            assert im.size in ((1920,1080),(960,540)),(path,im.size)
            screenshots.append({**entry(path),'size':list(im.size)})
    tools=sorted((ROOT/'tools/farming').glob('*p102*'))
    extra=[
        'assets/farming/facilities/facility_manifest.json','content/farming/p8/grounding.json',
        'content/farming/encyclopedia/encyclopedia.json','content/farming/baked/encyclopedia/encyclopedia.json',
        'scripts/farming/p8/p102_ui.gd','scripts/farming/p8/p87_scene.gd','scripts/farming/p8/p8_handbook.gd',
        'scripts/farming/tests/run_phase102.gd','scripts/farming/tests/run_phase102_ui.gd',
        'scripts/farming/tests/p8_crop_fixture.gd','scripts/farming/tests/run_phase08h_living.gd',
        'tools/farming/validate_rooms.py','tools/farming/bake_p8.py','tools/farming/bake_encyclopedia.py',
        'tools/farming/test_p8.ps1','test-p10-2.bat',
    ]
    source={**manifests[0],**{p.relative_to(ROOT).as_posix():sha(p) for p in tools if p.is_file()},
            **{p:sha(ROOT/p) for p in extra}}
    result={'phase':'10.2','date':'2026-10-18','status':'development_complete',
            'schema':{'current':20,'old_p8_rejected':[17,18,19],'old_files_preserved':True},
            'checks':checks,'business':entry(ROOT/'docs/farming/phase102-business.json'),
            'screenshots':screenshots,'source_sha256':source,
            'limits':['User subjective playtest is not signed off by the agent.',
                      'No development Windows package; hard floors, pipes, funnels, transmission, gu upgrades and hunger redesign remain deferred.',
                      'Historical P10/P10.1 evidence is preserved without rewriting its manifests.',
                      'Whole-farm cash comparisons do not isolate causal agricultural profit.']}
    output=ROOT/'docs/farming/phase102-validation.json'
    output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('P102 VALIDATION RECORD OK:',output)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('evidence',type=Path)
    record(parser.parse_args().evidence.resolve())
