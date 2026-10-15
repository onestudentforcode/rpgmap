"""Add raw PNG byte files and delivery aliases only in an isolated export stage."""
import argparse
import json
from pathlib import Path
from import_p8_plants import ROOT, encoded, safe_path


def stage_pngs(stage):
    count = 0
    for kind,filename in [('plants','assets/farming/crops/plant_manifest.json'),
                          ('facilities','assets/farming/facilities/facility_manifest.json')]:
        manifest = json.loads((ROOT/filename).read_text(encoding='utf-8'))
        for visual in manifest[kind].values():
            paths = visual['stages'] if kind == 'plants' else {'body':visual['path']}
            aliases = {}
            for key,path in paths.items():
                relative = path.removeprefix('res://')
                destination = safe_path(stage,relative+'.bin')
                destination.parent.mkdir(parents=True,exist_ok=True)
                destination.write_bytes(safe_path(ROOT,relative).read_bytes())
                aliases[key] = 'res://'+relative+'.bin'
                count += 1
            if kind == 'plants': visual['data_files'] = aliases
            else: visual['data_file'] = aliases['body']
        destination = stage/filename
        destination.parent.mkdir(parents=True,exist_ok=True)
        destination.write_bytes(encoded(manifest))
    scenery_path = 'assets/farming/p86/resource_manifest.json'
    if (ROOT/scenery_path).exists():
        scenery = json.loads((ROOT/scenery_path).read_text(encoding='utf-8'))
        for visual in list(scenery['resources'].values())+[scenery['transition']]:
            relative = visual['path'].removeprefix('res://')
            destination = safe_path(stage,relative+'.bin')
            destination.parent.mkdir(parents=True,exist_ok=True)
            destination.write_bytes(safe_path(ROOT,relative).read_bytes())
            visual['data_file'] = 'res://'+relative+'.bin'
            count += 1
        (stage/scenery_path).parent.mkdir(parents=True,exist_ok=True)
        (stage/scenery_path).write_bytes(encoded(scenery))
    (stage/'png-data-count.json').write_bytes(encoded({'raw_png_count':count}))
    print(f'P8 STAGE PNG DATA OK: {count} original PNG byte streams')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage',type=Path,required=True)
    target = parser.parse_args().stage.resolve()
    if not target.is_relative_to(ROOT/'.art-work'):
        parser.error('stage must be inside project .art-work')
    stage_pngs(target)
