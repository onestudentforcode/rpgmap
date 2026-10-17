"""Record completed P10 checks and independently reconciled business evidence.

Refuses missing/failed checks or stale runtime manifests. Raw trace files and
screenshots stay in the workspace; this compact report preserves their hashes.
"""
import hashlib
import json
from pathlib import Path

from PIL import Image
from audit_p8_playtest import reconcile
from audit_p10_playtest import audit

ROOT=Path(__file__).resolve().parents[2]


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8'))
def log(path):
    raw=path.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig',errors='replace')


def main():
    checks={
        'full_regression':('.art-work/p10-full-regression.log','FARMING TEST SUITE OK'),
        'python':('.art-work/p10-python-release.log','Ran 99 tests'),
        'model':('.art-work/p10-tests/model.log','PHASE10 TEST OK (181)'),
        'ui':('.art-work/p10-tests/ui.log','PHASE10 UI OK (21)'),
        'handbook':('.art-work/p10-tests/handbook.log','P8 HANDBOOK DOC OK: 12 chapters'),
        'encyclopedia':('.art-work/p10-tests/encyclopedia.log','P8 ENCYCLOPEDIA DOC OK: 196 entities / 15 rules'),
        'integrated_p10':('.art-work/p10-release-audited-suite.log','P10 DEVELOPMENT SUITE OK'),
        'gpu_ui':('.art-work/p10-gpu-release.stdout.log','PHASE10 UI OK (21)'),
    }
    evidence={}
    for name,(relative,marker) in checks.items():
        path=ROOT/relative
        assert marker in log(path),('missing success marker',relative)
        evidence[name]={'path':relative,'sha256':sha(path),'marker':marker}
    assert '\nOK' in log(ROOT/checks['python'][0]), 'Python suite not successful'
    gpu_errors=(ROOT/'.art-work/p10-gpu-release.stderr.log').read_text(encoding='utf-8')
    import re
    checked=re.sub(r'ERROR: Failed to read the root certificate store\.\s+at: get_system_ca_certificates \(platform/windows/os_windows.cpp:2582\)\s*','',gpu_errors)
    assert not checked.strip(),('unexpected GPU stderr',checked)
    assert 'Vulkan' in log(ROOT/checks['gpu_ui'][0]),'GPU renderer not verified'
    reports={}
    for group in ('control120','logistics120'):
        directory=ROOT/'.art-work/p10-tests'/group
        reports[group]=reconcile(directory)
    assert read(ROOT/'.art-work/p10-tests/control120/manifest.json')==read(ROOT/'.art-work/p10-tests/logistics120/manifest.json'),'control and treatment sources differ'
    logistics=audit(ROOT/'.art-work/p10-tests/logistics120')
    probes={}
    for group,count in (('control-negative',10),('logistics-negative',12)):
        path=ROOT/'.art-work/p10-tests'/group/'expected-rejections.json'
        values=read(path)
        assert len(values)==count and all(r['rejected'] for r in values.values()),'incomplete corruption probes'
        probes[group]=values
    shots=[]
    for path in sorted((ROOT/'.shots/p10-release').glob('*.png')):
        with Image.open(path) as picture: size=list(picture.size)
        shots.append({'path':path.relative_to(ROOT).as_posix(),'size':size,'sha256':sha(path)})
    assert len(shots)==7,'missing GPU screenshots'
    source=ROOT/'docs/farming/后勤蛊虫系统-v0.1-玩法设计.md'
    attachment=Path('C:/Users/88445/.codex/attachments/6ea15cd9-423f-4486-85dd-2f6f5019c90a/已粘贴的文本.txt')
    assert source.read_bytes()==attachment.read_bytes(),'user design copy changed'
    report={
        'phase':10,'date':'2026-10-16','status':'development_complete',
        'scope':'Five logistics prototypes, six one-time trial instances; source rules §13 of the Phase 10 document.',
        'schema':{'current':18,'reads_previous':17},
        'content':{'resources':65,'recipes':41,'gu_definitions':5,'trial_instances':6,'encyclopedia_entities':196,'encyclopedia_processes':253,'encyclopedia_rules':15,'handbook_chapters':12},
        'checks':evidence,'business':reports,'logistics':logistics,'negative_probes':probes,
        'runtime_manifest':read(ROOT/'.art-work/p10-tests/control120/manifest.json'),
        'screenshots':shots,'user_design_sha256':sha(source),
        'provenance':[
            'Four separate normal-source 120-day processes completed with no gameplay failures; 918 control and 926 logistics route checks.',
            'Original raw A/B books retained unchanged in .art-work/p10-tests/*120-parts; assembly verifies matching manifests/settings and distinct research histories.',
            'The first wrapper failed retrieving a process exit code after successful route completion. The handle is now retained; actual Godot exit-0 and exit-1 collection was verified. -AuditExisting rechecked original logs/books without rerunning or rewriting the routes.',
            'The old auditor was extended for paid gu lighting and exact reason-indexed gu inventory entries; both ordinary audits and the independent gu audit then passed.',
            'Full legacy suite passed before the final null-field/old-placement defensive fixes; final 181 model and 21 headless/GPU UI checks verify those fixes.',
            'Maintenance shown at day120 includes opening120; closed_maintenance excludes that next-day opening. The extra continuation day is separately present in raw gu summary totals.',
        ],
        'environment_note':'Only the exact Windows root-certificate-store warning is exempted. Legacy user:// test stores required an authorised full-suite run; P10 checks use workspace stores.',
        'review':{'gpu_images_inspected_by_agent':['01-manager','04-manager-960','06-light-range'],'user_subjective_playtest':'not claimed'},
        'deferred':['Real upstream acquisition/capture/refinement/rank growth','Condensation P1 and full high-rank catalogue','Final replacement art','New Windows distribution package (existing development-stage waiver)'],
        'reproduce':['test.bat','test-p10.bat','test-p10.bat -SkipPlaytest','test-p10.bat -AuditExisting','python tools/farming/record_p10_validation.py'],
    }
    path=ROOT/'docs/farming/phase10-validation.json'
    path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('P10 VALIDATION RECORD OK:',path)


if __name__=='__main__': main()
