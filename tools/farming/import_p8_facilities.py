"""Import verified facility body renders; foundation/fx stay deferred."""
import argparse
import hashlib
import json
from pathlib import Path

from import_p8_plants import ROOT, encoded, image_check, install, safe_path


def prepare(source):
    metadata = json.loads((ROOT / 'docs/farming/art/facility-render-metadata.json').read_text(encoding='utf-8'))
    inventory = json.loads((ROOT / 'docs/farming/art/facility-inventory.json').read_text(encoding='utf-8'))
    production = json.loads((ROOT / 'content/farming/p8/production.json').read_text(encoding='utf-8'))
    definitions = {d['id']: d for d in production['facilities']}
    inspected = {r['id']: r for r in inventory['facilities']}
    records = metadata['facilities']
    if {r['id'] for r in records} != set(definitions) or len(records) != len(definitions):
        raise ValueError('facility metadata IDs differ from game definitions')
    pending, visuals = {}, {}
    for record in records:
        ident = record['id']
        if record['footprint'] != definitions[ident]['footprint']:
            raise ValueError(f'{ident}: footprint mismatch')
        blend_data = safe_path(source, record['source_blend']).read_bytes()
        if hashlib.sha256(blend_data).hexdigest() != record['source_blend_sha256']:
            raise ValueError(f'{ident}: saved blend changed since metadata inspection')
        layer = record['layers']['body']
        filename = f'facilities/{ident}/{ident}_body_{64 if record["footprint"] == [1, 1] else 128}.png'
        source_entry = next(f for f in inspected[ident]['files'] if f['source'] == filename)
        data = safe_path(source, filename).read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        if digest != source_entry['sha256']:
            raise ValueError(f'{ident}: source render changed since inventory')
        image_check(data, source_entry['size'], ident)
        relative = f'assets/farming/facilities/{ident}/body.png'
        pending[relative] = data
        visuals[ident] = {'footprint': record['footprint'], 'canvas_px': source_entry['size'],
                          'path': 'res://' + relative, 'sha256': digest,
                          'anchor_uv': layer['anchor_uv'], 'draw_size': layer['draw_size'],
                          'scale_multiplier': 1.0, 'ground_placement': 'footprint_center',
                          'source_blend_sha256': record['source_blend_sha256'],
                          'source_png': filename, 'deferred_layers': ['found', 'fx']}
    pending['assets/farming/facilities/facility_manifest.json'] = encoded({
        'schema_version': 1, 'texture_filter': 'linear', 'facilities': visuals})
    return pending


def inspect_installed(root=ROOT):
    path = root / 'assets/farming/facilities/facility_manifest.json'
    if not path.exists(): return []
    results = []
    try:
        manifest = json.loads(path.read_text(encoding='utf-8'))['facilities']
        definitions = json.loads((root / 'content/farming/p8/production.json').read_text(encoding='utf-8'))['facilities']
        if set(manifest) != {r['id'] for r in definitions}: raise ValueError('installed facility IDs mismatch')
        for definition in definitions:
            ident = definition['id']
            visual = manifest[ident]
            relative = f'assets/farming/facilities/{ident}/body.png'
            errors = []
            try:
                if visual['footprint'] != definition['footprint']: raise ValueError('footprint mismatch')
                if visual['path'] != 'res://' + relative: raise ValueError('resource path mismatch')
                data = safe_path(root, relative).read_bytes()
                if hashlib.sha256(data).hexdigest() != visual['sha256']: raise ValueError('SHA256 mismatch')
                image_check(data, visual['canvas_px'], ident)
            except (ValueError, OSError, KeyError) as exc: errors.append(str(exc))
            results.append({'path': relative, 'errors': errors, 'warnings': []})
    except (ValueError, OSError, KeyError) as exc:
        results.append({'path': 'assets/farming/facilities/facility_manifest.json', 'errors': [str(exc)], 'warnings': []})
    return results


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    try:
        pending = prepare(args.source)
        changed = 0 if args.check else install(pending)
        print(f'P85 FACILITY IMPORT OK: 15 bodies; {changed} files written')
    except (ValueError, OSError, KeyError, StopIteration) as exc:
        parser.exit(1, f'P85 FACILITY IMPORT ERROR: {exc}\n')
