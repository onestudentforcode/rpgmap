"""Read-only source inventory; generated report does not approve facility assets."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image
from import_p8_plants import ROOT, encoded


def inventory(source):
    production = json.loads((ROOT / 'content/farming/p8/production.json').read_text(encoding='utf-8'))
    rows = []
    for definition in production['facilities']:
        ident = definition['id']
        folder = source / 'facilities' / ident
        files = []
        for path in sorted(folder.glob('*.png')):
            with Image.open(path) as image:
                alpha = image.getchannel('A') if image.mode == 'RGBA' else None
                files.append({'source': path.relative_to(source).as_posix(), 'size': list(image.size),
                              'mode': image.mode, 'alpha_bbox': list(alpha.getbbox()) if alpha and alpha.getbbox() else None,
                              'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
        rows.append({'id': ident, 'name': definition['name'], 'footprint': definition['footprint'],
                     'status': 'needs_render_metadata' if files else 'no_matching_source_directory',
                     'files': files, 'blend': [p.relative_to(source).as_posix() for p in sorted(folder.glob('*.blend'))],
                     'missing': ['verified per-layer camera and projected root', 'world-calibrated draw size',
                                 'approved source version and state mapping']})
    return {'status': 'inventory_only_not_approved', 'facilities': rows,
            'unmapped_source_directories': sorted(p.name for p in (source / 'facilities').iterdir()
                                                 if p.is_dir() and p.name not in {r['id'] for r in rows}),
            'notes': ['Body/foundation/fx layers require separate metadata; foundation camera is top-down.',
                      'Root-level water well/mine/lumber and full-map previews are not auto-mapped.',
                      'Kit camera values are clues, not verified metadata from saved scene/render.']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    args = parser.parse_args()
    report = inventory(args.source)
    destination = ROOT / 'docs/farming/art/facility-inventory.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(encoded(report))
    print('P8 FACILITY INVENTORY OK:', len(report['facilities']), 'game IDs;',
          sum(bool(r['files']) for r in report['facilities']), 'matching source directories')
