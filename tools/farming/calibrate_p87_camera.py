"""Blender read-only camera audit; project known world basis, not PNG silhouettes."""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_p85_runtime import build_jobs


def main():
    import bpy
    from bpy_extras.object_utils import world_to_camera_view
    from mathutils import Vector
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path('C:/Users/88445/Desktop/blender_assest'))
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    records = []
    sources = {}
    expected = math.sin(math.radians(35))
    for job in build_jobs(args.source, set(), set()):
        path = job['source']
        before = hashlib.sha256(path.read_bytes()).hexdigest()
        sources[str(path)] = before
        bpy.ops.wm.open_mainfile(filepath=str(path), load_ui=False, use_scripts=False)
        scene = bpy.data.scenes[job['scene']] if job['scene'] else bpy.context.scene
        if job['facility']:
            suffix = '1' if job['visual']['footprint'] == [1, 1] else '2'
            scene.camera = bpy.data.objects['FCam_Body'+suffix]
        if bpy.context.window:
            bpy.context.window.scene = scene
        scene.view_layers[0].update()
        camera = scene.camera
        assert camera.data.type == 'ORTHO', str(path)
        visual = job['visual']
        size = visual['draw_size']
        # Use the actual output aspect ratio; this also audits non-square tree canvases.
        scene.render.resolution_x, scene.render.resolution_y = job['size']
        scene.render.resolution_percentage = 100
        def project(point):
            uv = world_to_camera_view(scene, camera, Vector(point))
            return Vector((uv.x*size[0], (1-uv.y)*size[1]))
        base = project((0,0,0))
        axes = [project(point)-base for point in ((1,0,0),(0,1,0),(0,0,1))]
        horizontal = abs(axes[0].x)
        depth_ratio = abs(axes[1].y)/horizontal
        assert abs(horizontal-32) < 0.002, (job['id'],horizontal)
        assert abs(depth_ratio-expected) < 1e-5, (job['id'],depth_ratio)
        assert abs(axes[0].y) < 1e-4 and abs(axes[1].x) < 1e-4
        uv = [base.x/size[0],base.y/size[1]]
        assert max(abs(a-b) for a,b in zip(uv,visual['anchor_uv'])) < 1e-5
        assert before == hashlib.sha256(path.read_bytes()).hexdigest()
        records.append({'id':job['id'],'state':job['state'],
            'source_blend':str(path.relative_to(args.source)).replace('\\','/'),
            'source_sha256':before,'camera':camera.name,'camera_type':camera.data.type,
            'matrix_world':[list(row) for row in camera.matrix_world],
            'ortho_scale':camera.data.ortho_scale,'display_canvas':size,
            'ground_origin_uv':uv,'view_basis_per_blender_unit':[list(axis) for axis in axes],
            'view_units_per_blender_unit':horizontal,'depth_ratio':depth_ratio})
    for path, before in sources.items():
        assert hashlib.sha256(Path(path).read_bytes()).hexdigest() == before
    resource_manifest = json.loads((ROOT/'assets/farming/p86/resource_manifest.json').read_text(encoding='utf-8'))
    resources = []
    for ident, entry in resource_manifest['resources'].items():
        info = entry['provenance']
        generator = ROOT/info['generator']
        assert hashlib.sha256(generator.read_bytes()).hexdigest() == info['generator_sha256']
        assert info['camera_type'] == 'ORTHO' and info['elevation_degrees'] == 35
        # P8.6 generators are procedural; audit their explicit rig instead of claiming a .blend.
        source = generator.read_text(encoding='utf-8')
        assert ('ortho_scale = 3.4' in source or 'ortho_scale=3.4' in source)
        resources.append({'id':ident,'elevation_degrees':35,'ortho_width':3.4,
            'generator':info['generator'],'generator_sha256':info['generator_sha256'],
            'audit_method':'verified generator hash and explicit orthographic rig; no saved source blend',
            'old_display_units_per_blender_unit':entry['draw_size'][0]/3.4,
            'trial_display_units_per_blender_unit':32,
            'trial_canvas_size':[3.4*32,3.4*32]})
    report = {'revision':'p87-a-35deg','status':'camera_calibrated_not_user_accepted',
        'blender_version':bpy.app.version_string,'body_renders_checked':len(records),
        'source_files_checked_unchanged':len(sources),'source_write_policy':'open read-only; never save sources',
        'logical_tile_units':64,'blender_units_per_tile':2,
        'logical_axes_in_blender':['-X','+Y'],'elevation_degrees':35,
        'depth_ratio':expected,'projected_cell_size':[64,64*expected],
        'root_policy':'model origin at logical footprint center; old crop bottom-edge placement is display offset',
        'records':records,'resources':resources}
    target = ROOT/'docs/farming/art/p87-camera-calibration.json'
    target.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('P87 CAMERA CALIBRATION OK:',len(records),'body renders,',len(resources),'resource rigs')


if __name__ == '__main__':
    main()
