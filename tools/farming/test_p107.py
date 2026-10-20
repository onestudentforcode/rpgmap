"""Partitioned P10.7 checks with source/output-bound reuse and archived replays.

Every job owns a log and manifest. --stage Run --cases barter reruns only that
case; Audit and Probes reuse recorded inputs without operating the game again.
All stages and required evidence are checked again by Accept.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import threading
import time

from audit_p107_playtest import CASES, ROOT

LOGS = ROOT / '.art-work/p107-tests/runner'
EVIDENCE = ROOT / '.art-work/p107-playtest'
CERT = re.compile(r'ERROR: Failed to read the root certificate store\.\s+at: get_system_ca_certificates \(platform/windows/os_windows.cpp:2582\)\s*')
MODELS = {
	'contracts': ('scripts/farming/tests/run_p107_contract.gd', 'P107 CONTRACT OK'),
    'model': ('scripts/farming/tests/run_phase107.gd', 'P107 MODEL OK'),
    'transactions': ('scripts/farming/tests/run_phase107_transactions.gd', 'P107 TRANSACTION OK'),
    'agriculture': ('scripts/farming/tests/run_phase102.gd', 'P102 MODEL OK'),
    'land': ('scripts/farming/tests/run_phase103.gd', 'P103 MODEL OK'),
    'services': ('scripts/farming/tests/run_phase104.gd', 'P104 MODEL OK'),
    'species': ('scripts/farming/tests/run_phase105.gd', 'P105 MODEL OK'),
    'water': ('scripts/farming/tests/run_phase106.gd', 'P106 MODEL OK'),
    'fixtures': ('scripts/farming/tests/run_fixture_lint.gd', 'FIXTURE LINT OK'),
    'minerals': ('scripts/farming/tests/run_phase08f.gd', 'PHASE08F TEST OK'),
    'living': ('scripts/farming/tests/run_phase08h_living.gd', 'PHASE08H LIVING OK'),
    'encyclopedia-ui': ('scripts/farming/tests/run_p9_encyclopedia.gd', 'P9 ENCYCLOPEDIA OK'),
    'handbook-ui': ('scripts/farming/tests/run_p8_handbook.gd', 'P8 HANDBOOK UI OK'),
}


def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def atomic_json(path, value):
    temporary = path.with_name(path.name + '.tmp-%d-%d-%d' % (os.getpid(), threading.get_ident(), time.time_ns()))
    temporary.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')
    for attempt in range(10):
        try:
            os.replace(temporary, path)
            return
        except PermissionError:
            if attempt == 9: raise
            time.sleep(0.01)


def dependencies(extra=(), ui=False, evidence=False):
    paths = set()
    for folder in ('scripts/farming/core', 'scripts/farming/v1', 'scripts/farming/v2', 'scripts/farming/p8'):
        for p in (ROOT / folder).rglob('*.gd'):
            if ui or not any(word in p.name for word in ('_scene', '_ui', 'handbook', 'encyclopedia')):
                paths.add(p)
    for folder in ('content/farming/p8', 'content/farming/maps', 'content/farming/baked/p8'):
        paths.update((ROOT / folder).glob('*.json'))
    paths.add(ROOT / 'scripts/farming/tests/p107_fixture.gd')
    # Test inheritance/preloads must be included, especially P104 -> P103.
    pending = [ROOT / p for p in extra]
    while pending:
        p = pending.pop()
        if p in paths or not p.exists(): continue
        paths.add(p)
        if p.suffix == '.gd':
            for item in re.findall(r'(?:preload|load)\("res://([^\"]+)"\)|extends "res://([^\"]+)"', p.read_text(encoding='utf-8')):
                pending.append(ROOT / (item[0] or item[1]))
    if ui:
        paths.add(ROOT / 'project.godot')
        paths.update((ROOT / 'scenes/farming').glob('*.tscn'))
        paths.update((ROOT / 'assets/farming/ui').glob('*.svg'))
        paths.add(ROOT / 'content/farming/baked/encyclopedia/encyclopedia.json')
    if evidence:
        for case in CASES:
            paths.update((EVIDENCE / case).glob('*.json'))
            paths.update((EVIDENCE / case).glob('*.jsonl'))
    return {p.relative_to(ROOT).as_posix(): digest(p) for p in sorted(paths) if p.is_file()}


def outputs(files):
    return {p.relative_to(ROOT).as_posix(): digest(p) for p in files if p.is_file()}


class Runner:
    def __init__(self, args):
        self.args = args
        self.godot = args.godot or os.environ.get('GODOT_EXE_CONSOLE') or r'C:\Users\88445\Desktop\code\daoyan\.tools\godot-4.7.2\engine\Godot_v4.7.2-stable_win64_console.exe'
        engine = Path(self.godot)
        actual = engine.with_name(engine.name.replace('_console.exe', '.exe'))
        self.engine_paths = list(dict.fromkeys([engine, actual]))
        self.engine = {str(p): digest(p) for p in self.engine_paths if p.is_file()}
        LOGS.mkdir(parents=True, exist_ok=True)

    def valid(self, name, deps):
        path = LOGS / (name + '.json')
        if not path.exists(): return None
        record = json.loads(path.read_text(encoding='utf-8'))
        if not record.get('passed') or record['inputs'] != deps: return None
        if not all((ROOT / p).is_file() and digest(ROOT / p) == h for p, h in record['outputs'].items()): return None
        if record.get('command', [None])[0] == self.godot:
            if 'engine' not in record:
                # Upgrade records produced earlier in this same execution:
                # bind only when the exact command path is unchanged and both
                # binaries predate the original log. Future runs compare hashes.
                launched = (ROOT / record['log']).stat().st_birthtime
                if not all(p.stat().st_mtime <= launched for p in self.engine_paths if p.is_file()): return None
                record['engine'] = self.engine
                atomic_json(path, record)
            elif record['engine'] != self.engine:
                return None
        elif record.get('engine') is not None:
            return None
        return record

    def job(self, name, command, marker, deps, artifacts=(), timeout=2400, prepare=None):
        record = None if self.args.fresh else self.valid(name, deps)
        if record:
            print('P107 REUSE ' + name, flush=True)
            return record
        accepted = ROOT / 'docs/farming/phase107-validation.json'
        if accepted.exists():
            prior = json.loads(accepted.read_text(encoding='utf-8'))
            if prior.get('technical_gates_passed'):
                archive = LOGS / ('acceptance-' + datetime.now().strftime('%Y%m%d-%H%M%S-%f') + '.json')
                archive.write_text(json.dumps(prior, indent=2) + '\n', encoding='utf-8')
                prior['technical_gates_passed'] = False
                prior['invalidated_by'] = name
                atomic_json(accepted, prior)
        if prepare: prepare()
        stamp = datetime.now().strftime('%Y%m%d-%H%M%S-%f')
        path = LOGS / (name + '-' + stamp + '.log')
        print('P107 START ' + name, flush=True)
        flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
        with path.open('w', encoding='utf-8') as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                    creationflags=flags, timeout=timeout)
        text = path.read_text(encoding='utf-8', errors='replace')
        clean = CERT.sub('', text)
        if result.returncode or 'SCRIPT ERROR:' in clean or 'ERROR:' in clean or marker not in clean:
            print(text[-6000:], flush=True)
            raise RuntimeError(f'P107 failed: {name}; inspect {path}')
        if deps != dependencies_for_job(name):
            raise RuntimeError('Source changed during ' + name + '; do not accept mixed-version evidence')
        files = [path, *artifacts]
        if not all(p.is_file() for p in files): raise RuntimeError('Missing output for ' + name)
        record = {'job': name, 'passed': True, 'command': command, 'marker': marker,
                  'log': path.relative_to(ROOT).as_posix(), 'inputs': deps, 'outputs': outputs(files)}
        if command[0] == self.godot: record['engine'] = self.engine
        atomic_json(LOGS / (name + '.json'), record)
        print('P107 PASS ' + name + ': ' + marker, flush=True)
        return record

    def python(self, name, arguments, marker, artifacts=()):
        return self.job(name, [sys.executable, *arguments], marker, dependencies_for_job(name), artifacts)

    def game(self, name, script, marker, arguments=(), artifacts=(), gpu=False):
        command = [self.godot, '--path', str(ROOT), '--script', script,
                   '--log-file', str(LOGS / (name + '.engine.log'))]
        command += ['--rendering-method', 'mobile'] if gpu else ['--headless']
        if arguments: command += ['--', *arguments]
        return self.job(name, command, marker, dependencies_for_job(name), artifacts,
                        prepare=(lambda: archive_case(name[4:])) if name.startswith('run-') else (archive_smoke if name == 'smoke' else None))

    def stage(self, stage):
        if stage == 'Plan':
            self.python('production', ['tools/farming/bake_p8.py', '--check'], 'P8 BAKE OK')
            self.python('encyclopedia', ['tools/farming/bake_encyclopedia.py', '--check'], 'ENCYCLOPEDIA CHECK OK')
            self.game('handbook-export', 'tools/farming/export_p8_handbook.gd', 'P8 HANDBOOK DOC OK', ['--check'])
        elif stage == 'Model':
            names = list(MODELS)
            if self.args.models: names = self.args.models
            def run(name):
                script, marker = MODELS[name]
                artifacts = [ROOT / '.art-work/p107-tests' / p for p in ['contract-quotes.json', 'capture-costs.json']] if name == 'contracts' else ()
                return self.game(name, script, marker, artifacts=artifacts)
            with ThreadPoolExecutor(max_workers=3) as pool:
                list(pool.map(run, names))
        elif stage == 'Run':
            for case in self.args.cases:
                folder = EVIDENCE / case
                artifacts = [folder / p for p in ['initial.json', 'final.json', 'case.json', 'commands.jsonl', 'result.json']]
                self.game('run-' + case, 'scripts/farming/tests/run_p107_playtest.gd', 'P107 PLAYTEST OK',
                          ['--case=' + case], artifacts)
        elif stage == 'Audit':
            for case in self.args.cases:
                self.python('audit-' + case, ['tools/farming/audit_p107_playtest.py', '--cases', case], 'P107 AUDIT OK')
        elif stage == 'Probes':
            self.python('config-probes', ['-m', 'unittest', 'discover', '-s', 'tools/farming', '-p', 'test_p107_config.py', '-v'], 'OK')
            self.python('audit-probes', ['-m', 'unittest', 'discover', '-s', 'tools/farming', '-p', 'test_p107_audit.py', '-v'], 'OK')
        elif stage == 'Report':
            artifacts = [ROOT / 'docs/farming/phase107-economy.json', ROOT / 'docs/farming/phase107-economy.md']
            self.python('economy', ['tools/farming/report_p107_economy.py'], 'P107 ECONOMY OK', artifacts)
        elif stage == 'UI':
            self.game('ui', 'scripts/farming/tests/run_phase107_ui.gd', 'P107 UI OK')
            if not self.args.skip_gpu:
                shots = ROOT / '.art-work/p107-ui/runner'
                with shader_override():
                    self.game('gpu', 'scripts/farming/tests/run_phase107_ui.gd', 'P107 UI OK',
                              ['--shots=res://.art-work/p107-ui/runner'], [shots / ('economy-' + str(w) + '.png') for w in [960, 1400, 1920]], gpu=True)
        elif stage == 'Smoke':
            self.game('smoke', 'scripts/farming/tests/run_p107_smoke.gd', 'P106 SMOKE OK',
                      artifacts=[ROOT / '.art-work/p107-smoke/summary.json', ROOT / '.art-work/p107-smoke/final.json'])
        elif stage == 'Accept':
            names = ['production', 'encyclopedia', 'handbook-export', *MODELS, 'ui', 'gpu', 'smoke',
                     'config-probes', 'audit-probes', 'economy', *['run-' + c for c in CASES], *['audit-' + c for c in CASES]]
            records = {}
            all_inputs = dependencies(ui=True)
            for name in names:
                record = self.valid(name, dependencies_for_job(name))
                if not record: raise RuntimeError('Missing/stale P107 proof: ' + name)
                records[name] = {'log': record['log'], 'marker': record['marker'], 'outputs': record['outputs']}
                all_inputs.update(record['inputs'])
            all_inputs['tools/farming/test_p107.py'] = digest(Path(__file__))
            report = {'phase': 'P10.7', 'technical_gates_passed': True, 'schema': 25,
                      'scope': 'model, partial-module replays, independent audit/probes, report, UI/GPU and integration smoke',
                      'user_subjective_playtest': 'not claimed', 'evidence': records,
                      'source_sha256': {p: h for p, h in all_inputs.items() if not p.startswith('.art-work/')},
                      'dependency_sha256': all_inputs, 'godot_binaries': self.engine}
            atomic_json(ROOT / 'docs/farming/phase107-validation.json', report)
            print('P107 ACCEPT OK: all required evidence current and intact', flush=True)


def archive_case(case):
    folder = EVIDENCE / case
    if folder.exists():
        target = EVIDENCE / '_archive' / (case + '-' + datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
        # Native one-shell filesystem operation, with explicit absolute bounds.
        assert folder.resolve().is_relative_to(EVIDENCE.resolve()) and target.resolve().is_relative_to(EVIDENCE.resolve())
        target.parent.mkdir(parents=True, exist_ok=True)
        folder.rename(target)


def archive_smoke():
    folder = ROOT / '.art-work/p107-smoke'
    target = ROOT / '.art-work/p107-smoke-archive' / datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    if folder.exists():
        assert folder.resolve().is_relative_to((ROOT / '.art-work').resolve()) and target.resolve().is_relative_to((ROOT / '.art-work').resolve())
        target.parent.mkdir(parents=True, exist_ok=True)
        folder.rename(target)


@contextmanager
def shader_override():
    path = ROOT / 'override.cfg'
    content = '; P107 temporary GPU verification: no writable user cache required.\n[rendering]\nshader_compiler/shader_cache/enabled=false\n'
    owned = not path.exists()
    if owned: path.write_text(content, encoding='utf-8')
    try:
        yield
    finally:
        if owned and path.is_file() and path.read_text(encoding='utf-8') == content: path.unlink()


def dependencies_for_job(name):
    if name in MODELS:
        return dependencies([MODELS[name][0]], ui=name.endswith('-ui'))
    if name.startswith('run-'):
        return dependencies(['scripts/farming/tests/run_p107_playtest.gd'])
    if name.startswith('audit-') and name != 'audit-probes':
        case = name.removeprefix('audit-')
        extra = ['tools/farming/audit_p107_playtest.py', *[p.relative_to(ROOT).as_posix() for p in (EVIDENCE / case).glob('*') if p.is_file()]]
        return dependencies(extra)
    extra = {'production': ['tools/farming/bake_p8.py', 'tools/farming/validate_p107.py'],
             'encyclopedia': ['tools/farming/bake_encyclopedia.py', 'content/farming/encyclopedia/encyclopedia.json', 'content/farming/baked/encyclopedia/encyclopedia.json'],
             'handbook-export': ['tools/farming/export_p8_handbook.gd', 'docs/farming/demo-p8-新手手册.md'],
             'config-probes': ['tools/farming/test_p107_config.py', 'tools/farming/validate_p107.py'],
             'audit-probes': ['tools/farming/test_p107_audit.py', 'tools/farming/audit_p107_playtest.py'],
             'economy': ['tools/farming/report_p107_economy.py', 'tools/farming/bake_p8.py', 'tools/farming/audit_p107_playtest.py', '.art-work/p107-tests/contract-quotes.json', '.art-work/p107-tests/capture-costs.json'],
             'ui': ['scripts/farming/tests/run_phase107_ui.gd'], 'gpu': ['scripts/farming/tests/run_phase107_ui.gd'],
             'smoke': ['scripts/farming/tests/run_p107_smoke.gd']}[name]
    return dependencies(extra, ui=name in ['encyclopedia', 'handbook-export', 'ui', 'gpu'], evidence=name in ['audit-probes', 'economy'])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--stage', choices=['All', 'Plan', 'Model', 'Run', 'Audit', 'Probes', 'Report', 'UI', 'Smoke', 'Accept'], default='All')
    parser.add_argument('--cases', nargs='+', choices=CASES, default=list(CASES))
    parser.add_argument('--models', nargs='+', choices=list(MODELS))
    parser.add_argument('--godot')
    parser.add_argument('--fresh', action='store_true')
    parser.add_argument('--skip-gpu', action='store_true')
    args = parser.parse_args()
    runner = Runner(args)
    for stage in ['Plan', 'Model', 'Run', 'Audit', 'Probes', 'Report', 'UI', 'Smoke', 'Accept'] if args.stage == 'All' else [args.stage]:
        runner.stage(stage)


if __name__ == '__main__':
    main()
