"""Render approved rigs without saving the source .blend files.

Legacy calls render the full 4x handoff batch into .art-work/p85-runtime.
Use --ids/--states/--out/--recipe for isolated seedling trials.
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from p85_render_support import (apply_geometry_recipe, can_resume, fingerprint,
                                load_recipe, selection, sha256)


def arguments(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--sample', action='store_true', help='legacy wheat stage_3 and woodshop sample')
    parser.add_argument('--resume', action='store_true', help='reuse exact source/recipe/output matches')
    parser.add_argument('--ids', nargs='+', help='asset IDs, separated by spaces or commas')
    parser.add_argument('--states', nargs='+', help='stage_0..3, flowering, or body; spaces or commas')
    parser.add_argument('--out', type=Path, default=ROOT / '.art-work/p85-runtime',
                        help='staging directory within this project .art-work')
    parser.add_argument('--recipe', type=Path, help='seedling organ overrides JSON; never saved to source')
    return parser.parse_args(argv)


def build_jobs(source_root, ids, states, sample=False):
    plants = json.loads((ROOT / 'assets/farming/crops/plant_manifest.json').read_text(encoding='utf-8'))['plants']
    facilities = json.loads((ROOT / 'assets/farming/facilities/facility_manifest.json').read_text(encoding='utf-8'))['facilities']
    handoff = json.loads((source_root / 'UPSTREAM_PLANT_ASSETS.json').read_text(encoding='utf-8'))
    base_sizes = {asset['id']: asset['canvas_small_px'] for asset in handoff['assets']}
    unknown = ids - (set(plants) | set(facilities))
    if unknown:
        raise ValueError(f'unknown asset IDs: {sorted(unknown)}')
    valid_states = {'stage_0', 'stage_1', 'stage_2', 'stage_3', 'flowering', 'body'}
    if states - valid_states:
        raise ValueError(f'unknown render states: {sorted(states - valid_states)}')
    jobs = []
    for ident, visual in plants.items():
        if ids and ident not in ids:
            continue
        for key, path in visual['stages'].items():
            if states and key not in states:
                continue
            if sample and (ident != 'golden_wheat' or key != 'stage_3'):
                continue
            if ident == 'resin_tree':
                source = source_root / 'plants/植物全阶段总工程.blend'
                scene = 'RT_ResinTree_Stage3' if key == 'stage_3' else 'RF_ResinTree_Stage' + key[-1]
            else:
                source = source_root / 'plants' / ident / (key + '.blend')
                scene = ('PM_' + ident + '_Flowering' if key == 'flowering' else
                         ('PM_' if key == 'stage_3' else 'PG_') + ident + '_Stage' + key[-1])
            jobs.append({'id': ident, 'state': key, 'relative': path.removeprefix('res://'),
                         'source': source, 'scene': scene, 'visual': visual,
                         'size': [int(value) * 4 for value in base_sizes[ident]], 'facility': False})
    for ident, visual in facilities.items():
        if (ids and ident not in ids) or (states and 'body' not in states):
            continue
        if sample and ident != 'woodshop':
            continue
        base_size = [64, 64] if visual['footprint'] == [1, 1] else [128, 128]
        jobs.append({'id': ident, 'state': 'body', 'relative': visual['path'].removeprefix('res://'),
                     'source': source_root / 'facilities' / ident / (ident + '.blend'),
                     'scene': None, 'visual': visual,
                     'size': [value * 4 for value in base_size], 'facility': True})
    if not jobs:
        raise ValueError('asset/state selection produced no render jobs')
    missing = ids - {job['id'] for job in jobs}
    if missing:
        raise ValueError(f'no selected states for asset IDs: {sorted(missing)}')
    return jobs


def main(argv=None):
    import bpy
    from bpy_extras.object_utils import world_to_camera_view
    from mathutils import Vector

    args = arguments(argv if argv is not None else sys.argv[sys.argv.index('--') + 1:])
    source_root = args.source.resolve()
    out = args.out.resolve()
    if not out.is_relative_to((ROOT / '.art-work').resolve()):
        raise ValueError('--out must stay inside the project .art-work staging directory')
    recipe = load_recipe(args.recipe)
    jobs = build_jobs(source_root, selection(args.ids), selection(args.states), args.sample)
    out.mkdir(parents=True, exist_ok=True)
    report_path = out / 'render-report.json'
    report = json.loads(report_path.read_text(encoding='utf-8')) if report_path.exists() else {}
    scripts = {Path(__file__).name: sha256(__file__),
               'p85_render_support.py': sha256(Path(__file__).with_name('p85_render_support.py'))}
    rendered = reused = 0
    for job in jobs:
        relative, source, visual, size = job['relative'], job['source'], job['visual'], job['size']
        destination = (out / relative).resolve()
        if not destination.is_relative_to(out):
            raise ValueError(f'render output escapes staging directory: {relative}')
        digest = sha256(source)
        bpy.ops.wm.open_mainfile(filepath=str(source))
        scene = bpy.data.scenes[job['scene']] if job['scene'] else bpy.context.scene
        if job['facility']:
            suffix = '1' if visual['footprint'] == [1, 1] else '2'
            scene.camera = bpy.data.objects['FCam_Body' + suffix]
            body = set(bpy.data.collections['FC_' + job['id'] + '_body'].all_objects)
            for obj in scene.objects:
                if obj.type not in {'LIGHT', 'CAMERA', 'EMPTY'}:
                    obj.hide_render = obj not in body
        if bpy.context.window:
            bpy.context.window.scene = scene
        scene.render.resolution_x, scene.render.resolution_y = size
        scene.render.resolution_percentage = 100
        scene.view_layers[0].update()
        if scene.camera.data.type != 'ORTHO':
            raise ValueError(f'{relative}: approved orthographic camera required')
        point = world_to_camera_view(scene, scene.camera, Vector((0, 0, 0)))
        uv = [point.x, 1 - point.y]
        if max(abs(a - b) for a, b in zip(uv, visual['anchor_uv'])) > 1e-5:
            raise ValueError(f'{relative}: camera root differs from approved render: {uv}')
        scene.render.film_transparent = True
        scene.render.image_settings.file_format = 'PNG'
        scene.render.image_settings.color_mode = 'RGBA'
        scene.render.engine = 'CYCLES'
        scene.cycles.device = 'CPU'
        scene.cycles.samples = 128
        scene.cycles.use_denoising = True
        parameters = recipe['plants'].get(job['id'], {}).get(job['state'], {})
        render_recipe = {
            'schema_version': 1, 'scripts': scripts, 'blender_version': bpy.app.version_string,
            'source_blend_sha256': digest, 'scene': scene.name, 'id': job['id'], 'state': job['state'],
            'canvas_px': size, 'anchor_uv': uv, 'geometry_overrides': parameters,
            'recipe_sha256': fingerprint(recipe),
            'camera': {'name': scene.camera.name, 'type': scene.camera.data.type,
                       'matrix_world': [list(row) for row in scene.camera.matrix_world],
                       'ortho_scale': scene.camera.data.ortho_scale,
                       'sensor_fit': scene.camera.data.sensor_fit},
            'render': {'engine': scene.render.engine, 'device': scene.cycles.device,
                       'samples': scene.cycles.samples, 'denoising': scene.cycles.use_denoising,
                       'film_transparent': True, 'format': 'PNG', 'color_mode': 'RGBA',
                       'color_depth': scene.render.image_settings.color_depth,
                       'view_transform': scene.view_settings.view_transform,
                       'look': scene.view_settings.look, 'exposure': scene.view_settings.exposure,
                       'gamma': scene.view_settings.gamma},
        }
        recipe_fingerprint = fingerprint(render_recipe)
        if args.resume and can_resume(report.get(relative), digest, recipe_fingerprint, size, destination):
            reused += 1
            print('P85 RUNTIME REUSE OK', relative, flush=True)
            continue
        geometry = apply_geometry_recipe(scene, job['id'], job['state'], parameters)
        point_after = world_to_camera_view(scene, scene.camera, Vector((0, 0, 0)))
        if max(abs(a - b) for a, b in zip([point_after.x, 1 - point_after.y], uv)) > 1e-7:
            raise ValueError(f'{relative}: geometry override moved the projected root')
        destination.parent.mkdir(parents=True, exist_ok=True)
        scene.render.filepath = str(destination)
        bpy.ops.render.render(write_still=True, scene=scene.name)
        if sha256(source) != digest:
            raise ValueError(f'{relative}: source .blend changed during rendering')
        report[relative] = {
            'source_blend': source.relative_to(source_root).as_posix(), 'source_blend_sha256': digest,
            'scene': scene.name, 'canvas_px': size, 'anchor_uv': uv, 'samples': 128,
            'sha256': sha256(destination), 'recipe_fingerprint': recipe_fingerprint,
            'render_recipe': render_recipe, 'geometry_overrides': geometry,
        }
        temporary = report_path.with_suffix('.json.tmp')
        temporary.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        temporary.replace(report_path)
        rendered += 1
        print('P85 RUNTIME RENDER OK', relative, flush=True)
    print(f'P85 RUNTIME BATCH OK: {len(jobs)} selected; {rendered} rendered; {reused} reused; {len(report)} recorded', flush=True)


if __name__ == '__main__':
    main()
