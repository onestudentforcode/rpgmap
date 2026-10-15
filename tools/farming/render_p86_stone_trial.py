"""Create one opt-in stone-source render; never opens or changes upstream .blend files."""
import hashlib
import json
import math
import random
import struct
from pathlib import Path
import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / '.art-work/p86-assets'
OUT.mkdir(parents=True, exist_ok=True)
rng = random.Random(8601)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = 'P86_StoneSource_Trial'


def material(name, color):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1)
    result.use_nodes = True
    shader = result.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Roughness'].default_value = .88
    return result


materials = [material('Stone Warm Grey', (.40, .42, .35)),
             material('Stone Light Warm Grey', (.52, .53, .43)),
             material('Stone Taupe', (.43, .42, .34))]
stones = [(-.50, .12, .00, (.56, .43, .37), 0),
          (.33, .14, .00, (.62, .46, .43), 1),
          (.02, -.20, .39, (.45, .37, .37), 1),
          (-.58, -.31, .00, (.31, .25, .22), 2),
          (.63, -.24, .00, (.29, .25, .20), 0),
          (.03, .53, .00, (.28, .23, .19), 2)]
for index, (x, y, base, scale, mi) in enumerate(stones):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=(x,y,base+scale[2]))
    rock = bpy.context.object
    rock.name = 'P86_Stone_%02d' % index
    for vertex in rock.data.vertices:
        vertex.co *= rng.uniform(.91, 1.07)
    rock.scale = scale
    rock.rotation_euler.z = rng.uniform(-.8, .8)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = rock.modifiers.new('Softened stone edges', 'BEVEL')
    bevel.width = .035
    bevel.segments = 2
    bevel.affect = 'EDGES'
    rock.data.materials.append(materials[mi])
    normals = rock.modifiers.new('Weighted broad faces', 'WEIGHTED_NORMAL')
    normals.keep_sharp = True

bpy.ops.object.camera_add()
camera = bpy.context.object
camera.name = 'P86_Camera_35deg'
target = Vector((0,0,.60))
camera.location = target + Vector((0,math.cos(math.radians(35))*10,math.sin(math.radians(35))*10))
camera.rotation_euler = (target-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 3.4
scene.camera = camera
bpy.ops.object.light_add(type='AREA', location=(4,1,7))
key = bpy.context.object
key.name = 'P86_UpperLeft_SoftKey'
key.data.energy = 500
key.data.shape = 'DISK'
key.data.size = 4.5
key.rotation_euler = (-key.location).to_track_quat('-Z','Y').to_euler()
world = bpy.data.worlds.new('P86_Neutral_SoftFill')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (.68,.73,.68,1)
world.node_tree.nodes['Background'].inputs[1].default_value = .65
scene.world = world
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 96
scene.cycles.use_denoising = True
scene.render.resolution_x = 256
scene.render.resolution_y = 256
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.view_settings.view_transform = 'AgX'
scene.view_settings.look = 'AgX - Medium High Contrast'
destination = OUT/'stone_source.png'
scene.render.filepath = str(destination)
scene.view_layers[0].update()
projected = world_to_camera_view(scene,camera,Vector((0,0,0)))
bpy.ops.render.render(write_still=True)
# Blender embeds render time/date in PNG text chunks. Strip those ancillary
# chunks without decoding/changing any pixels so repeated builds are byte stable.
raw = destination.read_bytes()
stable = bytearray(raw[:8])
offset = 8
while offset < len(raw):
    length = struct.unpack('>I',raw[offset:offset+4])[0]
    kind = raw[offset+4:offset+8]
    chunk = raw[offset:offset+12+length]
    if kind in {b'IHDR',b'IDAT',b'IEND',b'sRGB',b'gAMA',b'cHRM',b'pHYs'}:
        stable.extend(chunk)
    offset += 12+length
destination.write_bytes(stable)
report = {'schema_version':1, 'purpose':'P8.6 optional representative scene stone_source only',
          'generator':Path(__file__).relative_to(ROOT).as_posix(),
          'generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'blender_version':bpy.app.version_string,
          'generated_from':'procedural Blender geometry; no external source read or write',
          'volatile_png_metadata_removed':True,
          'camera_type':'ORTHO', 'elevation_degrees':35, 'ortho_width':3.4,
          'canvas_px':[256,256], 'draw_size':[83.2,83.2],
          'anchor_uv':[projected.x,1-projected.y], 'samples':96,
          'camera_matrix_world':[[float(value) for value in row] for row in camera.matrix_world],
          'light':'upper left, broad area light', 'ground_or_shadow_baked':False,
          'sha256':hashlib.sha256(destination.read_bytes()).hexdigest()}
(OUT/'stone-source-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('P86 STONE TRIAL OK',destination,flush=True)
