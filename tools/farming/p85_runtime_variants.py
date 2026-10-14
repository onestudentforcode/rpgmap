"""Validate and apply a complete higher-resolution render subset before installation."""
import hashlib
import json
from import_p8_plants import encoded, image_check, safe_path


def apply_variants(pending, render_root, manifest_path, collection):
    report = json.loads((render_root/'render-report.json').read_text(encoding='utf-8'))
    manifest = json.loads(pending[manifest_path])
    for ident, visual in manifest[collection].items():
        states = visual['stages'] if collection == 'plants' else {'body':visual['path']}
        original_size = visual['canvas_px']
        expected = [v*4 for v in original_size]
        variants = {}
        for key, path in states.items():
            relative = path.removeprefix('res://')
            record = report[relative]
            if record['canvas_px'] != expected:
                raise ValueError(f'{relative}: expected 4x canvas {expected}')
            if max(abs(a-b) for a,b in zip(record['anchor_uv'],visual['anchor_uv'])) > 1e-5:
                raise ValueError(f'{relative}: render root changed')
            data = safe_path(render_root,relative).read_bytes()
            digest = hashlib.sha256(data).hexdigest()
            if digest != record['sha256']: raise ValueError(f'{relative}: render hash mismatch')
            image_check(data,expected,relative)
            pending[relative] = data
            variants[key] = record
            if collection == 'plants': visual['sha256'][key] = digest
            else: visual['sha256'] = digest
        visual['canvas_px'] = expected
        visual['handoff_canvas_px'] = original_size
        visual['runtime_variant'] = {'method':'Blender rerender at 4x canvas; display scale unchanged',
                                     'renders':variants}
    pending[manifest_path] = encoded(manifest)
    return pending
