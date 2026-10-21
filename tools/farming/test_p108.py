"""Partitioned P10.8 checks with source- and artifact-bound evidence."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
LOGS=ROOT/'.art-work/p108-tests/runner'
REPLAY=ROOT/'.art-work/p108-playthrough'
GODOT_DEFAULT=Path(r'C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe')
REGRESSIONS={'p102':'scripts/farming/tests/run_phase102.gd','p103':'scripts/farming/tests/run_phase103.gd','p107':'scripts/farming/tests/run_phase107.gd'}
HANDBOOK=ROOT/'docs/farming/demo-p8-新手手册.md'


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_set(ui=False):
    paths=set()
    for folder in ('scripts/farming/core','scripts/farming/v1','scripts/farming/v2','scripts/farming/p8','scripts/farming/tests'):
        paths.update((ROOT/folder).rglob('*.gd'))
    for folder in ('content/farming/p8','content/farming/baked/p8','content/farming/baked/maps'):
        paths.update((ROOT/folder).glob('*.json'))
    paths.update([ROOT/'tools/farming/generate_p108_tutorial_route.py',ROOT/'tools/farming/audit_p108_tutorial_route.py',ROOT/'tools/farming/test_p108.py'])
    if ui:
        paths.add(ROOT/'project.godot')
        paths.update((ROOT/'scenes/farming').glob('*.tscn'))
        paths.update((ROOT/'assets/farming/ui').glob('*.svg'))
    return sorted(p for p in paths if p.is_file())


def hashes(paths):
    return {p.relative_to(ROOT).as_posix():sha(p) for p in paths}


def atomic_json(path, value):
    temporary=path.with_suffix(path.suffix+'.tmp')
    temporary.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    os.replace(temporary,path)


class Runner:
    def __init__(self,args):
        self.args=args
        self.godot=Path(args.godot or os.environ.get('GODOT_EXE_CONSOLE','') or GODOT_DEFAULT)
        if not self.godot.is_file(): raise FileNotFoundError(f'Godot executable not found: {self.godot}')
        LOGS.mkdir(parents=True,exist_ok=True)

    def command(self,script,extra=(),headless=True):
        args=[str(self.godot)]
        if headless: args.append('--headless')
        args += ['--path','.', '--script','res://'+script]
        if extra: args += ['--',*extra]
        return args

    def job(self,name,command,inputs,outputs=(),marker=None,timeout=1200):
        input_hashes=hashes(inputs)
        print(f'P108 START {name}',flush=True)
        started=time.time()
        try:
            proc=subprocess.run(command,cwd=ROOT,text=True,encoding='utf-8',errors='replace',
                                stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
            output=proc.stdout
            clean=re.sub(r"ERROR: Failed to open 'user://logs/godot[^']*'\.\s+at: copy \(core/io/dir_access\.cpp:429\)\s*",'',output)
            clean=re.sub(r"ERROR: Failed to open log file for writing: user://logs/godot\.log\s+at: rotate_file \(core/io/logger\.cpp:169\)\s*",'',clean)
            clean=re.sub(r"ERROR: Failed to read the root certificate store\.\s+at: get_system_ca_certificates \(platform/windows/os_windows\.cpp:2582\)\s*",'',clean)
            unexpected=bool(re.search(r'^(?:ERROR|SCRIPT ERROR):',clean,re.MULTILINE))
            passed=proc.returncode==0 and (marker is None or marker in output) and not unexpected
            error=None if passed else f'exit={proc.returncode}; marker={marker!r}'
        except subprocess.TimeoutExpired as exc:
            output=(exc.stdout or '')+'\nP108 timeout\n';passed=False;error=f'timed out after {timeout}s'
        log=LOGS/f'{name}.log'
        log.write_text(output,encoding='utf-8')
        record={'partition':name,'passed':passed,'error':error,'command':command,'started_utc':datetime.now(timezone.utc).isoformat(),
                'duration_seconds':round(time.time()-started,3),'inputs':input_hashes,
                'outputs':{p.relative_to(ROOT).as_posix():sha(p) for p in outputs if p.is_file()},'log':log.relative_to(ROOT).as_posix()}
        atomic_json(LOGS/f'{name}.json',record)
        print(output,end='' if output.endswith('\n') else '\n')
        print(f'P108 {"PASS" if passed else "FAIL"} {name}',flush=True)
        if not passed: raise RuntimeError(f'P108 partition failed: {name}; see {record["log"]}')
        return record

    def model(self):
        return self.job('model',self.command('scripts/farming/tests/run_phase108.gd'),source_set(),
                        marker='P108 MODEL OK')

    def ui(self,gpu=False):
        marker='P108 UI OK'
        if gpu:
            gui=self.godot.with_name(self.godot.name.replace('_console.exe','.exe'))
            if not gui.is_file(): raise FileNotFoundError(f'Godot GUI executable not found: {gui}')
            shots=ROOT/'.art-work/p108-ui/gpu'
            shots.mkdir(parents=True,exist_ok=True)
            cmd=[str(gui),'--path','.', '--script','res://scripts/farming/tests/run_phase108_ui.gd','--',f'--shots=res://.art-work/p108-ui/gpu']
            return self.job('gpu',cmd,source_set(ui=True),list(shots.glob('*.png')),marker,timeout=600)
        return self.job('ui',self.command('scripts/farming/tests/run_phase108_ui.gd'),source_set(ui=True),marker=marker,timeout=600)

    def route_replay(self):
        inputs=source_set()
        outputs=[]
        cmd=self.command('scripts/farming/tests/run_p8_playtest.gd',
                         ['--days=90','--route=A','--tutorial-only','--audit-root=res://.art-work/p108-playthrough'])
        return self.job('route-replay',cmd,inputs,outputs,marker='P8 TUTORIAL PLAYTEST',timeout=1800)

    def route(self):
        inputs=source_set()
        for path in REPLAY.glob('*'):
            if path.is_file(): inputs.append(path)
        self.job('route-generate',[sys.executable,'tools/farming/generate_p108_tutorial_route.py'],inputs,
                 [ROOT/'content/farming/p8/tutorial_route.json'],'P108 ROUTE DATA OK')
        audit_inputs=source_set()
        audit_inputs += [ROOT/'content/farming/p8/tutorial_route.json']
        audit_inputs += [p for p in REPLAY.glob('*') if p.is_file()]
        return self.job('route-audit',[sys.executable,'tools/farming/audit_p108_tutorial_route.py'],audit_inputs,
                        marker='P108 ROUTE AUDIT OK')

    def regression(self,names):
        for name in names:
            script=REGRESSIONS[name]
            marker={'p102':'P102 MODEL OK','p103':'P103 MODEL OK','p107':'P107 MODEL OK'}[name]
            self.job(name,self.command(script),source_set(),marker=marker,timeout=900)

    def handbook(self):
        script='tools/farming/export_p8_handbook.gd'
        inputs=source_set(ui=True)
        self.job('handbook-export',self.command(script),inputs,[HANDBOOK],'P8 HANDBOOK DOC OK',timeout=300)
        check_inputs=inputs+[HANDBOOK]
        self.job('handbook-check',self.command(script,['--check']),check_inputs,[HANDBOOK],'P8 HANDBOOK DOC OK',timeout=300)

    def accept(self,required=('model','ui','gpu','route-replay','route-generate','route-audit','p102','p103','p107')):
        required=tuple(required)+('handbook-export','handbook-check')
        missing=[]
        for name in required:
            path=LOGS/f'{name}.json'
            if not path.exists(): missing.append(name);continue
            record=json.loads(path.read_text(encoding='utf-8'))
            if not record.get('passed'): missing.append(name);continue
            for relative,digest in record['inputs'].items():
                if relative=='tools/farming/test_p108.py':
                    # The harness records/replays jobs; it is not loaded by Godot.
                    continue
                if relative=='tools/farming/audit_p108_tutorial_route.py' and name!='route-audit':
                    # Only route-audit executes this validator.
                    continue
                if relative=='content/farming/p8/tutorial_route.json' and name in {
                        'route-generate','p102','p103','p107','handbook-export','handbook-check'}:
                    # Route generation writes this artifact; model/UI/GPU and
                    # route-audit bind it where it is behaviorally consumed.
                    continue
                if name=='route-replay' and relative in {
                        'content/farming/p8/tutorial_route.json',
                        'tools/farming/generate_p108_tutorial_route.py',
                        'tools/farming/audit_p108_tutorial_route.py'}:
                    # These are independently hashed by route-generate and
                    # route-audit. They do not change the simulation itself.
                    continue
                source=ROOT/relative
                if not source.is_file() or sha(source)!=digest:
                    missing.append(name+':stale:'+relative);break
            for relative,digest in record.get('outputs',{}).items():
                artifact=ROOT/relative
                if not artifact.is_file() or sha(artifact)!=digest:
                    missing.append(name+':stale-output:'+relative);break
        if missing: raise RuntimeError('Missing, failed or stale P10.8 evidence: '+', '.join(missing))
        route_summary=json.loads((REPLAY/'summary.json').read_text(encoding='utf-8'))
        route_data=json.loads((ROOT/'content/farming/p8/tutorial_route.json').read_text(encoding='utf-8'))
        if not route_summary['settings'].get('tutorial_only') or route_summary['failures']:
            raise RuntimeError('Tutorial replay summary is not a clean tutorial-only run')
        full_run_log=LOGS/'p8-economy-long-run.log'
        if not full_run_log.is_file(): raise RuntimeError('Missing archived full P8 economy run evidence')
        full_output=full_run_log.read_text(encoding='utf-8',errors='replace')
        known_gaps=[line.strip() for line in full_output.splitlines() if line.startswith('A ')]
        expected_gaps=['A research biofiltration','A research water_recirculation','A research basic_spirit_cooking',
                       'A research mineral_materials','A research composite_spirit_food',
                       'A purification and sludge reuse produced real batches','A supplied element gold',
                       'A actually claimed T12 spirit food']
        if known_gaps!=expected_gaps: raise RuntimeError('Archived full P8 economic gaps differ from the reviewed result')
        report={'phase':'P10.8','schema':26,'technical_gates_passed':True,
                'required_partitions':list(required),'evidence_directory':LOGS.relative_to(ROOT).as_posix(),
                'route_replay':{'partition_passed':True,'tutorial_only':True,'days':90,
                                'effective_field_gu_day':route_data['effective_field_gu_day'],
                                'tutorial_milestone_failures':0,
                                'full_p8_economy_run':{'passed':False,'failure_count':len(known_gaps),
                                    'failures':known_gaps,'log':full_run_log.relative_to(ROOT).as_posix(),
                                    'sha256':sha(full_run_log),
                                    'scope':'P8 late-horizon economic objectives are outside the P10.8 tutorial contract and remain visible here.'}},
                'note':'All P10.8 technical acceptance partitions passed and their source/output hashes match. The separate full P8 economic long run retains eight failed economic objectives; they are disclosed and are not counted as tutorial-route failures.'}
        atomic_json(ROOT/'docs/farming/phase108-validation.json',report)
        print('P108 ACCEPT PASS: all required P10.8 partitions and hashes verified',flush=True)

    def run(self):
        stage=self.args.stage.lower()
        if stage=='plan':
            print('P108 partitions: model, ui, route-replay (90d), route, regression, handbook, gpu, accept')
        elif stage=='model': self.model()
        elif stage=='ui': self.ui()
        elif stage=='route-replay': self.route_replay()
        elif stage=='route': self.route()
        elif stage=='regression': self.regression(self.args.models or list(REGRESSIONS))
        elif stage=='handbook': self.handbook()
        elif stage=='gpu': self.ui(gpu=True)
        elif stage=='accept': self.accept()
        elif stage=='all':
            self.model();self.ui();self.route_replay();self.route();self.regression(self.args.models or list(REGRESSIONS));self.handbook();self.ui(gpu=True);self.accept()
        else: raise ValueError(stage)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--stage',choices=['Plan','Model','UI','Route-Replay','Route','Regression','Handbook','GPU','Accept','All'],default='All')
    parser.add_argument('--models',nargs='+',choices=sorted(REGRESSIONS))
    parser.add_argument('--godot')
    args=parser.parse_args()
    try: Runner(args).run()
    except Exception as exc:
        print(f'P108 ERROR: {exc}',file=sys.stderr)
        return 1
    return 0


if __name__=='__main__': raise SystemExit(main())
