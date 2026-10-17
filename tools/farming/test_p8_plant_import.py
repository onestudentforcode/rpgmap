"""Check that a late corrupt source cannot partially install a plant batch."""
import json
import tempfile
from pathlib import Path
from unittest import mock

from import_p8_plants import ROOT, install, prepare, inspect_installed


def run(source):
    pending = prepare(source)
    assert len([p for p in pending if p.endswith('.png')]) == 29
    with tempfile.TemporaryDirectory(dir=ROOT / '.art-work') as folder:
        target = Path(folder)
        assert install(pending, target) == 31
        assert install(pending, target) == 0
        production = target / 'content/farming/p8/production.json'
        production.parent.mkdir(parents=True)
        production.write_bytes((ROOT / 'content/farming/p8/production.json').read_bytes())
        assert len(inspect_installed(target)) == 29
        assert not any(r['errors'] for r in inspect_installed(target))
        before = {key: (target / key).read_bytes() for key in pending}
        first_png = next(key for key in pending if key.endswith('.png'))
        (target / first_png).write_bytes(b'corrupt installed resource')
        assert any(r['errors'] for r in inspect_installed(target))
        (target / first_png).write_bytes(before[first_png])
        original = Path.write_bytes
        calls = 0

        def fail_once(path, data):
            nonlocal calls
            calls += 1
            if calls == 3:
                raise OSError('simulated destination failure')
            return original(path, data)

        with mock.patch.object(Path, 'write_bytes', fail_once):
            try:
                install({key: data + b'changed' for key, data in pending.items()}, target)
            except OSError:
                pass
            else:
                raise AssertionError('write failure must propagate')
        assert all((target / key).read_bytes() == data for key, data in before.items())
        source_copy = target / 'source'
        source_copy.mkdir()
        handoff = json.loads((source / 'UPSTREAM_PLANT_ASSETS.json').read_text(encoding='utf-8'))
        for asset in handoff['assets']:
            entries = asset['stages'] + ([asset['flowering']] if 'flowering' in asset else [])
            for entry in entries:
                path = source_copy / entry['source_runtime_png']
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes((source / entry['source_runtime_png']).read_bytes())
        last = handoff['assets'][-1]['flowering']
        (source_copy / last['source_runtime_png']).write_bytes(b'corrupt late file')
        (source_copy / 'UPSTREAM_PLANT_ASSETS.json').write_text(json.dumps(handoff), encoding='utf-8')
        try:
            prepare(source_copy)
        except ValueError as exc:
            assert 'SHA256 mismatch' in str(exc)
        else:
            raise AssertionError('corrupt source accepted')
        assert all((target / key).read_bytes() == data for key, data in before.items())
    print('P8 PLANT IMPORT TEST OK: idempotence, late corruption, write rollback, installed QC')


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, required=True)
    run(parser.parse_args().source)
