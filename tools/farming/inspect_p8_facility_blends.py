"""Run in background Blender; read saved scenes and write game-side provenance only.

blender --background --factory-startup --disable-autoexec --python SCRIPT -- --source PATH
Never saves or rebuilds any source .blend.
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
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
production = json.loads((ROOT / 'content/farming/p8/production.json').read_text(encoding='utf-8'))
records = []
for definition in production['facilities']:
    ident = definition['id']
    source = args.source / 'facilities' / ident / (ident + '.blend')
    bpy.ops.wm.open_mainfile(filepath=str(source.resolve()))
    scene = bpy.context.scene
    dimensions = definition['footprint']
    suffix = '1' if dimensions == [1, 1] else '2'
    layers = {}
    for part in ('body', 'found', 'fx'):
        camera_name = 'FCam_' + ('Found' if part == 'found' else 'Body') + suffix
        camera = bpy.data.objects.get(camera_name)
        if camera is None or camera.data.type != 'ORTHO' or camera.data.sensor_fit != 'HORIZONTAL':
            raise ValueError(f'{ident}/{part}: required horizontal orthographic camera missing')
        scene.render.resolution_x = scene.render.resolution_y = 1280
        point = world_to_camera_view(scene, camera, Vector((0, 0, 0)))
        collection_name = 'FC_' + ident + '_' + part
        collection = bpy.data.collections.get(collection_name)
        if collection is None:
            raise ValueError(f'{ident}: missing collection {collection_name}')
        layers[part] = {'camera': camera_name, 'camera_type': camera.data.type,
                        'camera_matrix_world': [list(row) for row in camera.matrix_world],
                        'camera_ortho_width_blender': camera.data.ortho_scale,
                        'anchor_uv': [point.x, 1-point.y], 'collection': collection_name,
                        'objects': len(collection.all_objects),
                        'draw_size': [camera.data.ortho_scale*32]*2}
    records.append({'id': ident, 'footprint': dimensions,
                    'source_blend': source.relative_to(args.source).as_posix(),
                    'source_blend_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                    'saved_render_transparent': scene.render.film_transparent,
                    'layers': layers})
destination = ROOT / 'docs/farming/art/facility-render-metadata.json'
destination.write_text(json.dumps({'schema_version': 1, 'blender_version': bpy.app.version_string,
                                   'method': 'read saved scenes; project world origin; never save sources',
                                   'facilities': records}, indent=2)+'\n', encoding='utf-8')
print('P85 FACILITY METADATA OK:', len(records), 'saved scenes')
