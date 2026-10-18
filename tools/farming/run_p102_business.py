"""Run P10.2 by case/phase; retain failed attempts and strict source manifests."""
from __future__ import annotations
import argparse
from collections import deque
from contextlib import ExitStack
import ctypes
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid

ROOT=Path(__file__).resolve().parents[2]
MODES=('compound','ordinary','seed','material')
ALL_CASES=tuple(f'{m}/{r}' for m in MODES for r in ('A','B'))
CERT=re.compile(r'ERROR: Failed to read the root certificate store\.\s+at: get_system_ca_certificates \(platform/windows/os_windows.cpp:2582\)\s*')

def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def stamp(): return datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S')+'-'+uuid.uuid4().hex[:8]

def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    temporary=path.with_name(path.name+'.'+uuid.uuid4().hex+'.tmp')
    temporary.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    temporary.replace(path)

def process_identity(pid):
    """Return birth identity and liveness, compatible with old .NET ticks."""
    if os.name=='nt':
        from ctypes import wintypes
        kernel=ctypes.WinDLL('kernel32',use_last_error=True)
        kernel.OpenProcess.argtypes=(wintypes.DWORD,wintypes.BOOL,wintypes.DWORD)
        kernel.OpenProcess.restype=wintypes.HANDLE
        kernel.GetProcessTimes.argtypes=(wintypes.HANDLE,)+(ctypes.POINTER(wintypes.FILETIME),)*4
        kernel.GetExitCodeProcess.argtypes=(wintypes.HANDLE,ctypes.POINTER(wintypes.DWORD))
        kernel.CloseHandle.argtypes=(wintypes.HANDLE,)
        handle=kernel.OpenProcess(0x1000,False,pid)
        if not handle: return None,False
        try:
            times=[wintypes.FILETIME() for _ in range(4)];code=wintypes.DWORD()
            if not kernel.GetProcessTimes(handle,*(ctypes.byref(t) for t in times)): return None,False
            if not kernel.GetExitCodeProcess(handle,ctypes.byref(code)): return None,False
            ticks=(times[0].dwHighDateTime<<32)+times[0].dwLowDateTime+504911232000000000
            return str(ticks),code.value==259
        finally: kernel.CloseHandle(handle)
    try:
        fields=Path(f'/proc/{pid}/stat').read_text().split(') ',1)[1].split()
        return 'proc:'+fields[19],fields[0]!='Z'
    except (OSError,IndexError): return None,False

def live(record):
    identity,alive=process_identity(int(record.get('pid',0)))
    return alive and identity is not None and identity==record.get('start_ticks')

def selected_cases(value):
    if value=='all': return ALL_CASES
    result=tuple(dict.fromkeys(c.strip() for c in value.split(',') if c.strip()))
    if not result or any(c not in ALL_CASES for c in result):
        raise ValueError('Cases must be all or comma-separated mode/A,mode/B; modes: '+','.join(MODES))
    return result

def paths(root,case):
    mode,route=case.split('/')
    return root/f'{mode}-parts'/route,root/f'{mode}-{route}'

def logs_ok(prefix):
    try:
        text=Path(str(prefix)+'.stdout.log').read_text(encoding='utf-8-sig')+Path(str(prefix)+'.stderr.log').read_text(encoding='utf-8-sig')
    except OSError: return False
    return 'P8 OPERATIONS PLAYTEST OK' in text and not re.search(r'SCRIPT ERROR:|ERROR:',CERT.sub('',text))

def inspect_case(root,case,workspace=ROOT,is_live=live):
    folder,prefix=paths(root,case)
    result={'case':case,'status':'missing','reason':'no attempt','changed_files':[]}
    if not folder.exists() or not any(folder.iterdir()):
        if any(Path(str(prefix)+suffix).exists() for suffix in ('.stdout.log','.stderr.log','.engine.log')):
            return {**result,'status':'incomplete','reason':'orphan process logs exist; inspect before --rerun'}
        return result
    try:
        record=read(folder/'run-process.json')
        if is_live(record): return {**result,'status':'running','reason':f'PID {record["pid"]} is still running'}
        if record.get('status')!='exited':
            return {**result,'status':'interrupted','reason':'no terminal process exit; inspect logs and use --rerun'}
        if record.get('exit_code')!=0:
            return {**result,'status':'failed','reason':f'process exit {record.get("exit_code")}; inspect logs and use --rerun'}
        summary=read(folder/'summary.json');manifest=read(folder/'manifest.json')
        mode,route=case.split('/')
        if summary['failures'] or not logs_ok(prefix):
            return {**result,'status':'failed','reason':'operator assertions or process logs failed; inspect before --rerun'}
        if set(summary['routes'])!={route} or summary['settings'].get('room_mode')!=mode or summary['settings']['days']!=120:
            return {**result,'status':'invalid','reason':'case identity/settings do not match the directory'}
        required={'scripts/farming/tests/run_p102_playtest.gd','scripts/farming/tests/run_p8_playtest.gd','scripts/farming/p8/p102_rooms.gd'}
        if not required<=manifest.keys(): return {**result,'status':'invalid','reason':'incomplete source manifest'}
        changed=[]
        for name,digest in manifest.items():
            source=(workspace/name).resolve()
            if not source.is_relative_to(workspace.resolve()): return {**result,'status':'invalid','reason':'manifest leaves the workspace'}
            if not source.is_file() or sha(source)!=digest: changed.append(name)
        if changed: return {**result,'status':'stale','reason':'recorded source changed; rerun affected cases','changed_files':changed}
        return {**result,'status':'ready','reason':'terminal books match current source; can audit without replay'}
    except (OSError,ValueError,KeyError,TypeError) as error:
        return {**result,'status':'incomplete','reason':str(error)+'; inspect before --rerun'}

def inside_workspace(path,workspace=ROOT):
    value=path.resolve();base=workspace.resolve()
    if value==base or not value.is_relative_to(base) or value.relative_to(base).parts[0] in ('.git','.agents','.codex'):
        raise ValueError('Evidence/archive must be inside the workspace: '+str(path))
    return value

class CaseLock:
    """OS locks survive PID reuse and release automatically on supervisor exit."""
    def __init__(self,root,case):
        self.path=inside_workspace(root/'.locks'/(case.replace('/','-')+'.json'))
        self.case=case;self.stream=None

    def __enter__(self):
        self.path.parent.mkdir(parents=True,exist_ok=True)
        self.stream=self.path.open('a+b')
        try:
            self.stream.seek(0)
            if os.name=='nt':
                import msvcrt
                msvcrt.locking(self.stream.fileno(),msvcrt.LK_NBLCK,1)
            else:
                import fcntl
                fcntl.flock(self.stream.fileno(),fcntl.LOCK_EX|fcntl.LOCK_NB)
        except OSError:
            self.stream.close();self.stream=None
            raise RuntimeError('another supervisor owns '+self.case)
        try:
            identity,_=process_identity(os.getpid())
            self.stream.seek(0);self.stream.truncate()
            self.stream.write(json.dumps({'pid':os.getpid(),'start_ticks':identity}).encode('utf-8'));self.stream.flush()
        except BaseException:
            self.__exit__();raise
        return self

    def __exit__(self,*args):
        if self.stream is None: return
        try:
            self.stream.seek(0)
            if os.name=='nt':
                import msvcrt
                msvcrt.locking(self.stream.fileno(),msvcrt.LK_UNLCK,1)
            else:
                import fcntl
                fcntl.flock(self.stream.fileno(),fcntl.LOCK_UN)
        finally: self.stream.close();self.stream=None

def archive_case(root,case,workspace=ROOT):
    """Move only this case and its logs after checking absolute source/targets."""
    folder,prefix=paths(root,case)
    candidates=[folder]+[Path(str(prefix)+suffix) for suffix in ('.stdout.log','.stderr.log','.engine.log')]
    existing=[p for p in candidates if p.exists()]
    if not existing: return None
    destination=inside_workspace(root/'.history'/case/stamp(),workspace)
    for path in existing: inside_workspace(path,workspace)
    destination.mkdir(parents=True)
    for path in existing: path.rename(inside_workspace(destination/path.name,workspace))
    return destination

def assembly_matches(root,mode):
    output=root/mode
    try:
        merged=read(output/'summary.json');summaries=[]
        for route in ('A','B'):
            folder,_=paths(root,f'{mode}/{route}');summary=read(folder/'summary.json');summaries.append(summary)
            if (output/'manifest.json').read_bytes()!=(folder/'manifest.json').read_bytes(): return False
            if (output/f'{route}-run-summary.json').read_bytes()!=(folder/'summary.json').read_bytes(): return False
            for p in folder.iterdir():
                if p.is_file() and p.name.startswith(route+'-') and (not (output/p.name).is_file() or sha(p)!=sha(output/p.name)): return False
        return (merged['routes']=={**summaries[0]['routes'],**summaries[1]['routes']}
                and not merged['failures'] and merged['checks']==sum(s['checks'] for s in summaries)
                and all(merged['settings']==s['settings'] for s in summaries))
    except (OSError,ValueError,KeyError,TypeError): return False

class Runner:
    def __init__(self,root,godot,parallel=4):
        self.root=root;self.godot=godot;self.parallel=parallel
        self.report={'stage':'','cases':[],'steps':[],'acceptance_complete':False}
        self.step_root=root/'.steps'/stamp()

    def step(self,name,arguments):
        self.step_root.mkdir(parents=True,exist_ok=True)
        log=self.step_root/(name+'.log')
        with log.open('wb') as stream:
            result=subprocess.run([sys.executable,*map(str,arguments)],cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,env={**os.environ,'PYTHONUTF8':'1'})
        self.report['steps'].append({'name':name,'exit_code':result.returncode,'log':str(log.relative_to(ROOT))})
        print(log.read_text(encoding='utf-8',errors='replace').strip(),flush=True)
        if result.returncode: raise RuntimeError(f'{name} failed; books retained. Log: {log}')

    def require_pair(self,mode):
        for route in ('A','B'):
            state=inspect_case(self.root,f'{mode}/{route}')
            if state['status']!='ready': raise RuntimeError(f'{state["case"]}: {state["status"]}: {state["reason"]}')

    def assemble(self,mode):
        with ExitStack() as locks:
            for route in ('A','B'): locks.enter_context(CaseLock(self.root,f'{mode}/{route}'))
            self._assemble(mode)

    def _assemble(self,mode):
        self.require_pair(mode)
        self.step('assemble-'+mode,['tools/farming/assemble_p10_playtest.py',self.root/f'{mode}-parts',self.root/mode])

    def audit(self,mode):
        with ExitStack() as locks:
            for route in ('A','B'): locks.enter_context(CaseLock(self.root,f'{mode}/{route}'))
            self.require_pair(mode)
            if not assembly_matches(self.root,mode): self._assemble(mode)
            self.step('audit-'+mode,['tools/farming/audit_p8_playtest.py',self.root/mode])
            self.require_pair(mode)

    def probes(self):
        with ExitStack() as locks:
            for route in ('A','B'): locks.enter_context(CaseLock(self.root,f'compound/{route}'))
            self.require_pair('compound')
            if not assembly_matches(self.root,'compound'):
                raise RuntimeError('Compound assembly is stale; run --stage Audit --cases compound/A,compound/B first')
            self.step('probes',['tools/farming/test_p102_audit.py','--evidence',self.root/'compound'])
            self.require_pair('compound')

    def run(self,cases,rerun=False):
        self.step('bake',['tools/farming/bake_p8.py','--check'])
        pending=deque(cases);running=[];errors=[]
        try:
            while pending or running:
                while pending and len(running)<self.parallel:
                    case=pending.popleft()
                    try:
                        state=inspect_case(self.root,case)
                        if state['status']=='running': raise RuntimeError(state['reason'])
                        if not rerun and state['status']=='ready':
                            with CaseLock(self.root,case):
                                if inspect_case(self.root,case)['status']!='ready': raise RuntimeError('case changed before audit')
                                folder,_=paths(self.root,case)
                                self.step('reuse-'+case.replace('/','-'),['tools/farming/audit_p8_playtest.py',folder,'--allow-gaps'])
                            print('Reusing case: '+case,flush=True);continue
                        if not rerun and state['status']!='missing': raise RuntimeError(state['reason'])
                        running.append(self.start(case,rerun))
                    except (OSError,ValueError,RuntimeError) as error:
                        errors.append(f'{case}: {error}');print(errors[-1],flush=True)
                for job in running[:]:
                    process=job['process'];code=process.poll()
                    if code is None and time.monotonic()-job['started']<900: continue
                    timed_out=code is None
                    if timed_out: self.stop(job)
                    code=process.wait();self.finish(job,code,'timeout' if timed_out else 'exited');running.remove(job)
                    try:
                        if timed_out or code!=0 or not logs_ok(job['prefix']): raise RuntimeError(f'process/log failure; logs: {job["prefix"]}')
                        self.step('case-'+job['case'].replace('/','-'),['tools/farming/audit_p8_playtest.py',job['folder'],'--allow-gaps'])
                        print('Case OK: '+job['case'],flush=True)
                    except (OSError,RuntimeError) as error: errors.append(f'{job["case"]}: {error}');print(errors[-1],flush=True)
                    finally:
                        if job.get('lock'): job['lock'].__exit__()
                if running: time.sleep(.2)
        finally:
            for job in running:
                try: self.stop(job);self.finish(job,job['process'].wait(),'interrupted')
                finally:
                    if job.get('lock'): job['lock'].__exit__()
        if errors: raise RuntimeError('\n'.join(errors))

    def start(self,case,rerun):
        lock=CaseLock(self.root,case).__enter__()
        streams=[];process=None
        try:
            if inspect_case(self.root,case)['status']=='running': raise RuntimeError('case is already running')
            if rerun:
                archived=archive_case(self.root,case)
                if archived: print(f'Archived {case}: {archived}',flush=True)
            folder,prefix=paths(self.root,case)
            folder=inside_workspace(folder);prefix=inside_workspace(prefix)
            folder.mkdir(parents=True,exist_ok=True)
            if any(folder.iterdir()): raise RuntimeError('case directory is not empty; explicit --rerun required')
            streams=[Path(str(prefix)+'.stdout.log').open('wb'),Path(str(prefix)+'.stderr.log').open('wb')]
            mode,route=case.split('/')
            command=[self.godot,'--headless','--path',str(ROOT),'--log-file',str(prefix)+'.engine.log',
                     '--script','res://scripts/farming/tests/run_p102_playtest.gd','--','--route='+route,'--room-mode='+mode,
                     '--days=120','--audit-root=res://'+folder.relative_to(ROOT).as_posix()]
            process=subprocess.Popen(command,cwd=ROOT,stdout=streams[0],stderr=streams[1],creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
            birth,_=process_identity(process.pid)
            record={'pid':process.pid,'start_ticks':birth,'status':'running'}
            write(folder/'run-process.json',record)
            print('Running case: '+case+' (120 days)',flush=True)
            return dict(case=case,folder=folder,prefix=prefix,process=process,record=record,streams=streams,lock=lock,started=time.monotonic())
        except BaseException:
            if process is not None and process.poll() is None:
                self.stop({'process':process});process.wait()
            for stream in streams: stream.close()
            lock.__exit__()
            raise

    def stop(self,job):
        process=job['process']
        if process.poll() is not None: return
        if os.name=='nt': subprocess.run(['taskkill.exe','/PID',str(process.pid),'/T','/F'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        else: process.kill()

    def finish(self,job,code,status):
        for stream in job['streams']: stream.close()
        write(job['folder']/'run-process.json',{**job['record'],'status':status,'exit_code':code})

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence-root',type=Path,default=Path('.art-work/p102-playtest/business-v5'))
    parser.add_argument('--godot',default=os.environ.get('GODOT_EXE_CONSOLE',''))
    parser.add_argument('--parallel',type=int,choices=range(1,9),default=4)
    parser.add_argument('--stage',choices=('Plan','Run','Assemble','Audit','Probes','Accept'),default='Accept')
    parser.add_argument('--cases',default='all');parser.add_argument('--rerun',action='store_true');parser.add_argument('--audit-existing',action='store_true')
    args=parser.parse_args();cases=selected_cases(args.cases);root=inside_workspace(ROOT/args.evidence_root)
    if args.rerun and (args.audit_existing or args.stage not in ('Run','Accept')): parser.error('--rerun requires Run/Accept without --audit-existing')
    if args.audit_existing and args.stage not in ('Accept','Plan'): parser.error('--audit-existing means Accept without game runs')
    if args.stage=='Probes' and not any(c.startswith('compound/') for c in cases): parser.error('Probes requires a compound selection')
    if args.stage=='Plan':
        for case in cases: print(json.dumps(inspect_case(root,case),ensure_ascii=False))
        return
    root.mkdir(parents=True,exist_ok=True)
    runner=Runner(root,args.godot,args.parallel);runner.report.update(stage=args.stage,cases=list(cases))
    modes=tuple(m for m in MODES if any(c.startswith(m+'/') for c in cases))
    try:
        if args.stage in ('Run','Accept') and not args.audit_existing:
            needs_game=args.rerun or any(inspect_case(root,c)['status']=='missing' for c in cases)
            if needs_game and not Path(args.godot).is_file(): raise ValueError('Supply --godot / -GodotExe to start cases')
            runner.run(cases,args.rerun)
        if args.stage=='Assemble':
            for mode in modes: runner.assemble(mode)
        if args.stage in ('Audit','Accept'):
            for mode in modes: runner.audit(mode)
        if args.stage=='Probes' or (args.stage=='Accept' and 'compound' in modes): runner.probes()
        if args.stage=='Accept':
            for mode in modes:
                runner.require_pair(mode)
                if not assembly_matches(root,mode): raise RuntimeError('assembly changed during acceptance: '+mode)
        complete=args.stage=='Accept' and set(cases)==set(ALL_CASES)
        runner.report['acceptance_complete']=complete;runner.report['status']='passed'
        print('P102 BUSINESS ACCEPTANCE OK: four configurations, independent A/B, 8 x 120 days' if complete else 'P102 PARTITION CHECKS OK (partial scope; full acceptance not evaluated)',flush=True)
    except (OSError,ValueError,RuntimeError,KeyboardInterrupt) as error:
        runner.report.update(status='failed',error=str(error));print(str(error),file=sys.stderr,flush=True)
        raise SystemExit(1)
    finally: write(runner.step_root/'result.json',runner.report)

if __name__=='__main__': main()
