"""Assemble verified P10.4 evidence without replaying a game day."""
import argparse
import hashlib
import json
import re
from pathlib import Path
from PIL import Image
from audit_p104_playtest import audit
from qc_p104_assets import check as art_check
from report_p104_costs import report

ROOT=Path(__file__).resolve().parents[2]


def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def log_check(paths,marker):
    raw='\n'.join(path.read_text(encoding='utf-8') for path in paths)
    clean=re.sub(r'ERROR: Failed to read the root certificate store\.\s+at: get_system_ca_certificates \(platform/windows/os_windows.cpp:2582\)','',raw)
    assert marker in clean and not re.search(r'SCRIPT ERROR:|ERROR:',clean),str(paths)
    return {str(path.relative_to(ROOT)).replace('\\','/'):digest(path) for path in paths}


def collect(folder,smoke):
    modules=[audit(folder/name/'scenario.json') for name in ['structure','hosts','toy','breeding','work','compound','breeding-base','work-base']]
    assert sum(r['checks'] for r in modules)==900
    integration=audit(smoke)
    model_folder=ROOT/'.art-work/p104-playtest/final-v2/logs'
    logs={}
    for name,marker in [('model','P104 MODEL OK (261)'),('agriculture','P102 MODEL OK (317)'),('ranch','P103 MODEL OK (555)')]:
        logs.update(log_check([model_folder/(name+'.stdout.log'),model_folder/(name+'.stderr.log')],marker))
    logs.update(log_check([ROOT/'.art-work/p104-tests/capacity.log'],'P104 CAPACITY OK (342)'))
    logs.update(log_check([ROOT/'.art-work/p104-tests/ui-gpu-reviewed.stdout.log',ROOT/'.art-work/p104-tests/ui-gpu-reviewed.stderr.log'],'P104 UI OK (31)'))
    logs.update(log_check([ROOT/'.art-work/p104-tests/smoke-v7.log'],'P104 SMOKE OK'))
    shots=[]
    for path in sorted((ROOT/'.art-work/p104-ui/reviewed-shots').glob('*.png')):
        with Image.open(path) as im: size=list(im.size)
        shots.append({'path':str(path.relative_to(ROOT)).replace('\\','/'),'size':size,'sha256':digest(path)})
    assert len(shots)==10
    assert {tuple(row['size']) for row in shots}=={(960,540),(1400,900),(1920,1080)}
    paths=[]
    for directory in ['scripts/farming/p8','scripts/farming/v1','scripts/farming/v2','scripts/farming/core']:
        paths.extend((ROOT/directory).rglob('*.gd'))
    paths.extend((ROOT/'scripts/farming/tests').glob('*p104*.gd'))
    paths.extend((ROOT/'scripts/farming/tests').glob('*phase104*.gd'))
    paths.extend((ROOT/'tools/farming').glob('*p104*.py'))
    paths.extend(ROOT/path for path in ['content/farming/p8/production.json','content/farming/baked/p8/production.json',
        'content/farming/encyclopedia/encyclopedia.json','content/farming/baked/encyclopedia/encyclopedia.json',
        'scripts/farming/tests/run_phase102.gd','scripts/farming/tests/run_phase103.gd','tools/farming/test_p104.ps1',
        'assets/farming/facilities/facility_manifest.json','content/farming/p8/grounding.json'])
    sources={str(path.relative_to(ROOT)).replace('\\','/'):digest(path) for path in sorted(set(paths))}
    raw=[folder/name/'scenario.json' for name in [row['route'] for row in modules]]+[smoke]
    artifact_hashes={str(path.relative_to(ROOT)).replace('\\','/'):digest(path) for path in raw}
    (ROOT/'docs/farming/phase104-costs.json').write_text(json.dumps(report(folder),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return {'phase':'10.4','status':'implemented-and-technically-verified','date':'2026-10-19','schema':22,
            'model_checks':{'p104':261,'allocation_and_fractional_work':342,'agriculture_regression':317,'ranch_regression':555},
            'count_note':'Assertion counts include repeated explicit fixture setup; these are not unique feature counts.',
            'modules':modules,'integration':integration,'art':art_check(),'gpu_checks':31,'gpu_frames':shots,
            'python_contract_tests':2,'independent_audit_tests':2,'audit_tamper_categories':8,
            'source_sha256':sources,'artifact_sha256':artifact_hashes,'log_sha256':logs,
            'limitations':['Subjective player acceptance is not signed by the agent.',
                           'New facility art is deterministic placeholder art, not final production art.',
                           'Only the toy crafting route starts with the real 90-stone budget. Other modules and the 60-day smoke are labelled scaffolds, not profit tests.',
                           'Unlimited cheap juvenile purchases still make breeding economically unattractive; no price changes were included.',
                           'Historical P10.1-10.3 and boundary validation records are preserved. Early interrupted harness/debug attempts are not acceptance evidence.',
                           'The smoke independently audits 60 days of service history and the retained final 15 inventory-ledger days. Earlier inventory days passed runtime reconciliation and strict per-day codec checks; their external ledger rows were not retained.',
                           'Service histories are retained in saves; longer-horizon storage/performance optimization is a later task.']}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--root',type=Path,default=ROOT/'.art-work/p104-playtest/final-v3')
    parser.add_argument('--smoke',type=Path,default=ROOT/'.art-work/p104-smoke/final-v1.json')
    args=parser.parse_args()
    data=collect(args.root.resolve(),args.smoke.resolve())
    (ROOT/'docs/farming/phase104-validation.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('P104 EVIDENCE OK: eight short modules, 60-day smoke, model/UI/art and receipt audits')


if __name__=='__main__': main()
