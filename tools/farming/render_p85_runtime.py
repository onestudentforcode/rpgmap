"""Background Blender renders at 4x handoff sizes, without rebuilding/saving models.

Outputs stay in .art-work until the full batch has passed inspection.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path
import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, required=True)
parser.add_argument('--sample', action='store_true')
parser.add_argument('--resume', action='store_true')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
out = ROOT / '.art-work/p85-runtime'
out.mkdir(parents=True, exist_ok=True)
report_path = out / 'render-report.json'
report = json.loads(report_path.read_text(encoding='utf-8')) if args.resume and report_path.exists() else {}
plants = json.loads((ROOT/'assets/farming/crops/plant_manifest.json').read_text(encoding='utf-8'))['plants']
facilities = json.loads((ROOT/'assets/farming/facilities/facility_manifest.json').read_text(encoding='utf-8'))['facilities']
handoff = json.loads((args.source/'UPSTREAM_PLANT_ASSETS.json').read_text(encoding='utf-8'))
plant_base_sizes = {a['id']:a['canvas_small_px'] for a in handoff['assets']}
jobs = []
for ident, visual in plants.items():
    for key, path in visual['stages'].items():
        if args.sample and (ident != 'golden_wheat' or key != 'stage_3'): continue
        if ident == 'resin_tree':
            source = args.source/'plants/植物全阶段总工程.blend'
            scene = 'RT_ResinTree_Stage3' if key == 'stage_3' else 'RF_ResinTree_Stage'+key[-1]
        else:
            source = args.source/'plants'/ident/(key+'.blend')
            scene = ('PM_'+ident+'_Flowering' if key == 'flowering' else
                     ('PM_' if key == 'stage_3' else 'PG_')+ident+'_Stage'+key[-1])
        jobs.append((path.removeprefix('res://'),source,scene,visual,None))
for ident, visual in facilities.items():
    if args.sample and ident != 'woodshop': continue
    jobs.append((visual['path'].removeprefix('res://'),args.source/'facilities'/ident/(ident+'.blend'),
                 None,visual,ident))
for relative, source, scene_name, visual, facility in jobs:
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    destination = out/relative
    base_size = ([64,64] if visual['footprint'] == [1,1] else [128,128]) if facility else plant_base_sizes[relative.split('/')[-2]]
    size = [int(v)*4 for v in base_size]
    if args.resume and relative in report and report[relative]['source_blend_sha256'] == digest and destination.exists():
        if report[relative]['canvas_px'] == size and hashlib.sha256(destination.read_bytes()).hexdigest() == report[relative]['sha256']: continue
    bpy.ops.wm.open_mainfile(filepath=str(source))
    scene = bpy.data.scenes[scene_name] if scene_name else bpy.context.scene
    if facility:
        suffix = '1' if visual['footprint'] == [1,1] else '2'
        scene.camera = bpy.data.objects['FCam_Body'+suffix]
        body = set(bpy.data.collections['FC_'+facility+'_body'].all_objects)
        for obj in scene.objects:
            if obj.type not in {'LIGHT','CAMERA','EMPTY'}: obj.hide_render = obj not in body
    if bpy.context.window: bpy.context.window.scene = scene
    scene.view_layers[0].update()
    scene.render.resolution_x,scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    point = world_to_camera_view(scene,scene.camera,Vector((0,0,0)))
    uv = [point.x,1-point.y]
    if max(abs(a-b) for a,b in zip(uv,visual['anchor_uv'])) > 1e-5:
        raise ValueError(f'{relative}: camera root differs from approved render: {uv}')
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 128
    scene.cycles.use_denoising = True
    destination.parent.mkdir(parents=True,exist_ok=True)
    scene.render.filepath = str(destination)
    bpy.ops.render.render(write_still=True,scene=scene.name)
    report[relative] = {'source_blend':source.relative_to(args.source).as_posix(),
                        'source_blend_sha256':digest,'scene':scene.name,'canvas_px':size,
                        'anchor_uv':uv,'samples':128,'sha256':hashlib.sha256(destination.read_bytes()).hexdigest()}
    report_path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('P85 RUNTIME RENDER OK',relative,flush=True)
print('P85 RUNTIME BATCH OK',len(report),flush=True)
