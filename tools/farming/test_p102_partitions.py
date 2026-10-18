"""Failure isolation, cache provenance, archiving and local/full gate boundaries."""
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from assemble_p10_playtest import assemble
import run_p102_business as p


class Partitions(unittest.TestCase):
    def setUp(self):
        parent=p.ROOT/'.art-work/p102-partition-tests'
        parent.mkdir(parents=True,exist_ok=True)
        temporary=tempfile.TemporaryDirectory(dir=parent)
        self.base=p.inside_workspace(Path(temporary.name))
        self.addCleanup(temporary.cleanup)
        self.workspace=self.base/'workspace';self.workspace.mkdir()
        self.root=self.workspace/'evidence';self.root.mkdir()

    def fixture(self,case):
        folder,prefix=p.paths(self.root,case);folder.mkdir(parents=True,exist_ok=True)
        mode,route=case.split('/')
        names=['scripts/farming/tests/run_p102_playtest.gd','scripts/farming/tests/run_p8_playtest.gd','scripts/farming/p8/p102_rooms.gd']
        for name in names:
            path=self.workspace/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text('unchanged',encoding='utf-8')
        manifest={name:p.sha(self.workspace/name) for name in names}
        p.write(folder/'manifest.json',manifest)
        p.write(folder/'summary.json',{'checks':1,'failures':[], 'settings':{'days':120,'room_mode':mode},'routes':{route:{'research_order':[route]}}})
        p.write(folder/'run-process.json',{'pid':0,'start_ticks':'dead','status':'exited','exit_code':0})
        (folder/(route+'-rooms.jsonl')).write_text('{"original":true}\n',encoding='utf-8')
        Path(str(prefix)+'.stdout.log').write_text('P8 OPERATIONS PLAYTEST OK\n',encoding='utf-8')
        Path(str(prefix)+'.stderr.log').write_text('',encoding='utf-8')
        return folder,prefix

    def inspect(self,case,is_live=lambda _:False):
        return p.inspect_case(self.root,case,self.workspace,is_live)

    def test_case_selection_rejects_typo_and_deduplicates(self):
        self.assertEqual(p.selected_cases('compound/B,seed/A,compound/B'),('compound/B','seed/A'))
        with self.assertRaises(ValueError): p.selected_cases('compound/C')
        with self.assertRaises(ValueError): p.selected_cases('')

    def test_ready_case_survives_auditor_only_change(self):
        self.fixture('compound/A')
        (self.workspace/'auditor.py').write_text('changed auditor',encoding='utf-8')
        self.assertEqual(self.inspect('compound/A')['status'],'ready')

    def test_shared_operator_change_invalidates_both_routes(self):
        self.fixture('compound/A');self.fixture('compound/B')
        (self.workspace/'scripts/farming/tests/run_p8_playtest.gd').write_text('changed strategy',encoding='utf-8')
        for case in ('compound/A','compound/B'):
            state=self.inspect(case)
            self.assertEqual(state['status'],'stale')
            self.assertIn('scripts/farming/tests/run_p8_playtest.gd',state['changed_files'])

    def test_live_process_never_becomes_rerunnable(self):
        self.fixture('compound/B')
        self.assertEqual(self.inspect('compound/B',lambda _:True)['status'],'running')

    def test_failed_process_and_interrupted_books_are_distinguished(self):
        folder,_=self.fixture('compound/B')
        p.write(folder/'run-process.json',{'status':'exited','exit_code':1})
        self.assertEqual(self.inspect('compound/B')['status'],'failed')
        p.write(folder/'run-process.json',{'status':'running'})
        self.assertEqual(self.inspect('compound/B')['status'],'interrupted')

    def test_engine_error_overrides_success_marker(self):
        _,prefix=self.fixture('compound/B')
        Path(str(prefix)+'.stderr.log').write_text('SCRIPT ERROR: broken\n',encoding='utf-8')
        self.assertEqual(self.inspect('compound/B')['status'],'failed')

    def test_orphan_logs_are_preserved_not_treated_as_empty_case(self):
        _,prefix=p.paths(self.root,'compound/B')
        Path(str(prefix)+'.stdout.log').write_text('incomplete',encoding='utf-8')
        self.assertEqual(self.inspect('compound/B')['status'],'incomplete')

    def test_retry_archives_only_selected_case_and_keeps_original_bytes(self):
        a,_=self.fixture('compound/A');b,log=self.fixture('compound/B')
        before={x.name:x.read_bytes() for x in b.iterdir()}
        old_log=Path(str(log)+'.stdout.log').read_bytes()
        archived=p.archive_case(self.root,'compound/B',self.workspace)
        self.assertTrue(a.is_dir());self.assertFalse(b.exists())
        self.assertEqual(before,{x.name:x.read_bytes() for x in (archived/'B').iterdir()})
        self.assertEqual((archived/'compound-B.stdout.log').read_bytes(),old_log)

    def test_archive_rejects_outside_workspace_before_any_move(self):
        self.fixture('compound/B')
        with self.assertRaises(ValueError): p.archive_case(self.root,'compound/B',self.workspace/'different')
        self.assertTrue((self.root/'compound-parts/B/summary.json').exists())

    def test_new_raw_attempt_invalidates_old_assembly(self):
        self.fixture('compound/A');b,_=self.fixture('compound/B')
        with contextlib.redirect_stdout(io.StringIO()): assemble(self.root/'compound-parts',self.root/'compound')
        self.assertTrue(p.assembly_matches(self.root,'compound'))
        (b/'B-rooms.jsonl').write_text('{"new_attempt":true}\n',encoding='utf-8')
        self.assertFalse(p.assembly_matches(self.root,'compound'))

    def test_incompatible_pair_cannot_be_assembled(self):
        self.fixture('compound/A');b,_=self.fixture('compound/B')
        manifest=p.read(b/'manifest.json');manifest['extra']='different';p.write(b/'manifest.json',manifest)
        with self.assertRaisesRegex(AssertionError,'manifests differ'):
            assemble(self.root/'compound-parts',self.root/'compound')

    def test_failure_does_not_cancel_unstarted_cases(self):
        started=[];steps=[]
        class Process:
            def __init__(self,code): self.code=code
            def poll(self): return self.code
            def wait(self): return self.code
        runner=p.Runner(self.root,'unused',1)
        def start(case,rerun):
            started.append(case)
            return dict(case=case,process=Process(1 if case.endswith('/A') else 0),prefix='log',folder='folder',started=0)
        runner.start=start;runner.finish=lambda *args:None;runner.step=lambda name,args:steps.append(name)
        with patch.object(p,'inspect_case',return_value={'status':'missing'}),patch.object(p,'logs_ok',return_value=True),contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(RuntimeError): runner.run(('compound/A','compound/B'))
        self.assertEqual(started,['compound/A','compound/B'])
        self.assertIn('case-compound-B',steps)

    def test_reaudit_failure_does_not_silently_replay_game(self):
        runner=p.Runner(self.root,'unused')
        runner.start=lambda *args:self.fail('ready case must never replay on audit failure')
        def step(name,args):
            if name.startswith('reuse-'): raise RuntimeError('audit format problem')
        runner.step=step
        with patch.object(p,'inspect_case',return_value={'status':'ready'}),contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(RuntimeError,'audit format problem'): runner.run(('compound/B',))

    def test_pid_identity_matches_a_real_live_process(self):
        process=subprocess.Popen([sys.executable,'-c','import time; time.sleep(10)'],creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        try:
            identity,alive=p.process_identity(process.pid)
            self.assertTrue(alive);self.assertIsNotNone(identity)
            self.assertTrue(p.live({'pid':process.pid,'start_ticks':identity}))
            self.assertFalse(p.live({'pid':process.pid,'start_ticks':'reused-pid'}))
        finally: process.terminate();process.wait()

    def test_missing_partner_refuses_partial_pair_audit(self):
        runner=p.Runner(self.root,'unused')
        with self.assertRaisesRegex(RuntimeError,'compound/A'):
            runner.require_pair('compound')

    def test_os_locks_block_same_case_but_allow_other_cases_and_release(self):
        with self.assertRaises(ValueError):
            with p.CaseLock(self.root,'compound/A'):
                with self.assertRaisesRegex(RuntimeError,'another supervisor'):
                    with p.CaseLock(self.root,'compound/A'): self.fail('same case must be locked')
                with p.CaseLock(self.root,'compound/B'): pass
                raise ValueError('interrupted supervisor')
        with p.CaseLock(self.root,'compound/A'): pass

    def test_start_selects_one_case_and_finishes_with_actual_process_code(self):
        class Process:
            pid=0
            def poll(self): return 7
        runner=p.Runner(self.root,'fake-godot.exe')
        with patch.object(p.subprocess,'Popen',return_value=Process()) as popen,contextlib.redirect_stdout(io.StringIO()):
            job=runner.start('compound/B',False)
        try:
            command=popen.call_args.args[0]
            self.assertIn('--route=B',command);self.assertIn('--room-mode=compound',command)
            self.assertFalse((self.root/'compound-parts/A').exists())
            runner.finish(job,7,'exited')
            self.assertEqual(p.read(job['folder']/'run-process.json')['exit_code'],7)
        finally:
            for stream in job['streams']: stream.close()
            job['lock'].__exit__()


if __name__=='__main__': unittest.main()
