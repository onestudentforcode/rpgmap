"""Abandoned prototype, 2026-10-22: use the selected image + image-to-3D route.

This script stopped before saving/rendering and is not an approved production entry.
Retained only as a record of the interrupted experiment; do not continue this route.

Outputs a versioned .blend, transparent render setup and measured projection metadata.
The user reference is the image supplied in chat on 2026-10-22, not a file on disk.
"""
import bpy
import json
import math
import random
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / '.art-work/p109/models/steel_sheep'
REV = 1
while (BASE / f'v{REV:03d}').exists():
    REV += 1
OUT = BASE / f'v{REV:03d}'
OUT.mkdir(parents=True)
random.seed(109)
render_engine = bpy.context.scene.render.engine
scene = bpy.data.scenes.new(f'P109_SteelSheep_v{REV:03d}')
bpy.context.window.scene = scene
parts = bpy.data.collections.new('SteelSheep_Model')
scene.collection.children.link(parts)
studio = bpy.data.collections.new('SteelSheep_Studio')
scene.collection.children.link(studio)


def enum_value(owner, prop, preferred):
    values = [i.identifier for i in owner.bl_rna.properties[prop].enum_items]
    if preferred not in values:
        raise ValueError(f'{prop}: {preferred} unavailable; supported={values}')
    return next(i for i in values if i == preferred)


def srgb(v):
    return v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4


def mat(name, rgb, roughness=.65, metal=0):
    m = bpy.data.materials.new('P109_' + name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value = (*[srgb(c) for c in rgb], 1)
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Metallic'].default_value = metal
    return m


cream = mat('Warm_Ivory_Wool', (.89, .855, .765), .82)
cream_light = mat('Soft_Wool_Crests', (.96, .925, .84), .8)
silver = mat('Silver_Grey_Wool_Tips', (.63, .69, .73), .42, .22)
skin = mat('Face_Ivory', (.91, .86, .77), .64)
horn = mat('Warm_Stone_Horn', (.49, .46, .42), .57)
horn_band = mat('Horn_Ridges', (.57, .54, .49), .65)
hoof_mat = mat('Dark_Hoof', (.25, .24, .23), .55)
ear_mat = mat('Muted_Ear_Inner', (.66, .43, .38), .8)
nose_mat = mat('Nose', (.30, .235, .22), .6)
eye_mat = mat('Warm_Amber_Eye', (.43, .28, .115), .31)
black = mat('Pupil', (.055, .045, .035), .28)
glint = mat('Eye_Glint', (.98, .96, .90), .22)


def own(obj, collection=parts):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    collection.objects.link(obj)
    return obj


def uv(name, loc, scale, material, segments=24, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    o = own(bpy.context.object)
    o.name = name
    o.scale = scale
    o.data.materials.append(material)
    for f in o.data.polygons:
        f.use_smooth = True
    return o


def tube(name, points, radii, material, sides=10, squash=1., accent=None, accent_start=.7):
    verts, faces = [], []
    for i, point in enumerate(points):
        p = Vector(point)
        tangent = Vector(points[min(i+1, len(points)-1)]) - Vector(points[max(0, i-1)])
        tangent.normalize()
        axis = Vector((0, 1, 0))
        if abs(axis.dot(tangent)) > .95:
            axis = Vector((1, 0, 0))
        a = tangent.cross(axis).normalized()
        b = tangent.cross(a).normalized()
        for j in range(sides):
            ang = j * math.tau / sides
            verts.append(tuple(p + radii[i] * (a*math.cos(ang) + b*math.sin(ang)*squash)))
    for i in range(len(points)-1):
        for j in range(sides):
            faces.append((i*sides+j, i*sides+(j+1)%sides,
                          (i+1)*sides+(j+1)%sides, (i+1)*sides+j))
    faces.extend([tuple(reversed(range(sides))), tuple((len(points)-1)*sides+j for j in range(sides))])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    ob = bpy.data.objects.new(name, mesh)
    parts.objects.link(ob)
    mesh.materials.append(material)
    if accent:
        mesh.materials.append(accent)
    for face in mesh.polygons:
        face.use_smooth = True
        if accent and face.index < (len(points)-1)*sides:
            face.material_index = int(face.index//sides >= (len(points)-2)*accent_start)
    return ob


def line(name, points, radius, material):
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions = '3D'
    curve.resolution_u = 12
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    sp = curve.splines.new('BEZIER')
    sp.bezier_points.add(len(points)-1)
    for b, p in zip(sp.bezier_points, points):
        b.co = p
        b.handle_left_type = b.handle_right_type = 'AUTO'
    ob = bpy.data.objects.new(name, curve)
    parts.objects.link(ob)
    curve.materials.append(material)
    return ob


def wool_lock(name, pos, normal, length=.36, width=.15, tipped=False):
    p, n = Vector(pos), Vector(normal).normalized()
    down = Vector((.15, 0, -1))
    down = down - n*down.dot(n)
    if down.length < .2:
        down = Vector((.9, .15, -.2))
    down.normalize()
    points, radii = [], []
    for i in range(13):
        t = i/12
        # Fat root, flowing middle, softly hooked tip: no individual hair geometry.
        points.append(p + down*(length*t) + n*(.025+.115*math.sin(math.pi*t)+.065*t**5))
        radii.append(max(.006, width*(math.sin(math.pi*(.12+.88*t))**.65)))
    return tube(name, points, radii, cream_light, 12, .75,
                silver if tipped else None, .67)


# Main masses: head points along -X (screen right with the production camera).
uv('Body_Core', (0, 0, 1.06), (.91, .43, .56), cream)
uv('Shoulder_Core', (-.58, 0, 1.19), (.49, .43, .64), cream)
uv('Upright_Wool_Neck', (-.79, 0, 1.51), (.40, .36, .56), cream)

# Four legs and split hooves with a grounded common sole plane.
for label, x, y in [('FrontNear', -.61, .285), ('FrontFar', -.67, -.285),
                    ('BackNear', .58, .30), ('BackFar', .64, -.30)]:
    uv(label+'_UpperLeg', (x, y, .61), (.19, .17, .38), cream)
    uv(label+'_Shank', (x-.02, y, .29), (.115, .105, .23), skin)
    uv(label+'_WoolCuff', (x, y, .47), (.17, .15, .19), cream_light)
    for k in [-1, 1]:
        uv(label+f'_HoofToe_{k}', (x-.055, y+k*.058, .10), (.16, .055, .10), hoof_mat, 20, 12)
    for k in [-1, 1]:
        wool_lock(label+f'_CuffLock_{k}', (x-.045, y+k*.105, .48), (0, k, .05), .18, .075, k==1)

# Broad wool locks arranged in overlapping rows around the body.
for ix, x in enumerate([-.60, -.28, .06, .40, .71]):
    for j in range(9):
        theta = math.tau*j/9 + (ix%2)*.13
        cy, sz = math.cos(theta), math.sin(theta)
        p = (x+random.uniform(-.035, .035), .415*cy, 1.07+.50*sz)
        wool_lock(f'Body_Wool_{ix}_{j}', p, (x*.25, cy, sz),
                  .32+random.random()*.07, .17+random.random()*.025,
                  (ix+j)%3 != 0)

# Neck/chest locks, larger and slightly longer to echo the reference ruff.
for level in range(3):
    for j in range(7):
        theta = j*math.tau/7
        n = Vector((math.cos(theta), math.sin(theta), .10))
        z = 1.20+level*.26
        p = Vector((-.78, 0, z)) + Vector((n.x*.30, n.y*.31, 0))
        wool_lock(f'Ruff_{level}_{j}', p, n, .37, .17, (level+j)%3==0)

uv('Tail_Base', (.87, .04, 1.02), (.22, .17, .23), cream)
wool_lock('Tail_Curl', (.98, .07, 1.07), (1, 0, .1), .31, .14, True)

# Face and gentle expression.
uv('Head', (-1.00, 0, 1.91), (.31, .235, .38), skin)
uv('Cheeks', (-1.13, 0, 1.76), (.28, .21, .235), skin)
uv('Muzzle', (-1.32, 0, 1.73), (.22, .165, .14), skin)
uv('Nose', (-1.505, 0, 1.76), (.055, .11, .061), nose_mat)
for sign in [-1, 1]:
    uv(f'Nostril_{sign}', (-1.536, sign*.057, 1.77), (.015, .022, .013), black, 16, 10)
    uv(f'EyeSocket_{sign}', (-1.18, sign*.197, 1.99), (.083, .035, .064), horn)
    uv(f'EyeAmber_{sign}', (-1.195, sign*.222, 1.99), (.053, .018, .043), eye_mat)
    uv(f'EyePupil_{sign}', (-1.204, sign*.238, 1.994), (.030, .009, .023), black, 20, 12)
    uv(f'EyeGlint_{sign}', (-1.22, sign*.246, 2.008), (.009, .004, .009), glint, 12, 8)
    ear = uv(f'Ear_{sign}', (-.98, sign*.34, 1.97), (.20, .245, .072), skin)
    ear.rotation_euler[2] = sign*.30
    inner = uv(f'EarInner_{sign}', (-1.01, sign*.37, 2.021), (.14, .155, .016), ear_mat)
    inner.rotation_euler[2] = sign*.30
    line(f'Mouth_{sign}', [(-1.48, sign*.06, 1.66), (-1.38, sign*.133, 1.635),
                          (-1.24, sign*.16, 1.66)], .009, nose_mat)
    line(f'UpperLid_{sign}', [(-1.26, sign*.218, 2.036), (-1.19, sign*.235, 2.049),
                             (-1.12, sign*.209, 2.026)], .018, skin)

# A few large forehead locks, avoiding a tiny sphere/particle fur treatment.
for j in range(4):
    wool_lock(f'ForeheadLock_{j}', (-1.08+j*.105, -.07+(j%2)*.14, 2.16),
              (-.6, .05, .8), .22, .105, j==3)

# Two ram horns: broad spiral, tapered end, only sparse ring relief.
for sign in [-1, 1]:
    points, radii = [], []
    count = 65
    for i in range(count):
        t = i/(count-1)
        ang = math.radians(40)+t*math.radians(300)
        r = .355*(1-.70*t)
        points.append((-.80-r*math.cos(ang), sign*(.255+.085*math.sin(math.pi*t)),
                       2.065+r*math.sin(ang)))
        radii.append(.125*(1-t)**.72+.008)
    tube(f'CurledHorn_{sign}', points, radii, horn, 14)
    # Geometry rings accentuate the curl without detailed sculpting.
    for i in range(4, 53, 7):
        p = Vector(points[i])
        direction = (Vector(points[i+1])-Vector(points[i-1])).normalized()
        a = direction.cross(Vector((0, 1, 0))).normalized()
        b = direction.cross(a).normalized()
        loop = [p+(a*math.cos(j*math.tau/20)+b*math.sin(j*math.tau/20))*radii[i]*1.005 for j in range(21)]
        tube(f'HornRing_{sign}_{i}', loop, [.007]*21, horn_band, 6)

# One root object provides clean selection and future asset reuse.
root = bpy.data.objects.new('SteelSheep_ROOT', None)
parts.objects.link(root)
root['asset_id'] = 'steel_sheep'
root['reference'] = 'User supplied image in chat, 2026-10-22'
root['status'] = 'simple_model_candidate_not_user_accepted'
for ob in list(parts.objects):
    if ob != root:
        ob.parent = root

world = bpy.data.worlds.new('P109_SoftStudio')
world.use_nodes = True
next(n for n in world.node_tree.nodes if n.type=='BACKGROUND').inputs['Color'].default_value = (.68,.73,.80,1)
next(n for n in world.node_tree.nodes if n.type=='BACKGROUND').inputs['Strength'].default_value = .38
scene.world = world


def aim(obj, target):
    obj.rotation_euler = (Vector(target)-obj.location).to_track_quat('-Z', 'Y').to_euler()


def light(name, pos, energy, size, color):
    data = bpy.data.lights.new(name, enum_value(bpy.types.Light, 'type', 'AREA'))
    data.energy, data.shape, data.size, data.color = energy, enum_value(data, 'shape', 'DISK'), size, color
    ob = bpy.data.objects.new(name, data)
    studio.objects.link(ob)
    ob.location = pos
    aim(ob, (0,0,1.1))


light('Key_UpperLeft', ( -0.0+3.5, 4.5, 6), 480, 4.5, (1., .91, .79))
light('Soft_Fill', (-4, 1, 3), 150, 5., (.81, .88, 1.))
light('Back_Fill', (1, -3, 4.5), 230, 4., (1., .96, .88))
cam_data = bpy.data.cameras.new('P109_Production35')
cam_data.type = enum_value(cam_data, 'type', 'ORTHO')
cam_data.ortho_scale = 3.35
cam = bpy.data.objects.new('P109_Production35', cam_data)
studio.objects.link(cam)
elev = math.radians(35)
target = Vector((-.15, 0, 1.23))
cam.location = target+Vector((0, 8*math.cos(elev), 8*math.sin(elev)))
aim(cam, target)
scene.camera = cam
scene.render.engine = render_engine
scene.render.resolution_x = scene.render.resolution_y = 1024
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = enum_value(scene.render.image_settings, 'file_format', 'PNG')
scene.render.image_settings.color_mode = enum_value(scene.render.image_settings, 'color_mode', 'RGBA')
scene.render.filepath = str(OUT/'steel_sheep_35deg.png')
scene.view_settings.view_transform = enum_value(scene.view_settings, 'view_transform', 'AgX')
scene.view_settings.exposure = .5
bpy.context.view_layer.update()

# Make the new asset immediately useful in the live Blender viewport.
for ob in bpy.context.selected_objects:
    ob.select_set(False)
root.select_set(True)
bpy.context.view_layer.objects.active = root
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.region_3d.view_perspective = enum_value(area.spaces.active.region_3d, 'view_perspective', 'CAMERA')
            area.spaces.active.shading.type = enum_value(area.spaces.active.shading, 'type', 'MATERIAL')

uv_origin = world_to_camera_view(scene, cam, Vector((0,0,0)))
test_points = {}
for key, co in {'origin':(0,0,0), 'right':(-1,0,0), 'depth':(0,1,0), 'up':(0,0,1)}.items():
    p = world_to_camera_view(scene, cam, Vector(co))
    test_points[key] = [p.x*1024, (1-p.y)*1024]
mesh_objects = [o for o in parts.objects if o.type=='MESH']
meta = {
    'asset_id':'steel_sheep', 'revision':f'v{REV:03d}',
    'status':'simple_reference_model_pending_user_review',
    'reference':'user image supplied 2026-10-22; simplified cream wool, silver tips and curled horns',
    'blender_version':bpy.app.version_string,
    'scene':scene.name, 'root':root.name, 'camera_elevation_degrees':35,
    'camera_matrix':[list(row) for row in cam.matrix_world],
    'ortho_scale':cam_data.ortho_scale, 'canvas_px':[1024,1024],
    'draw_size':[cam_data.ortho_scale*32]*2,
    'anchor_uv':[uv_origin.x,1-uv_origin.y],
    'projection_test_px':test_points,
    'mesh_count':len(mesh_objects), 'mesh_faces':sum(len(o.data.polygons) for o in mesh_objects),
    'animation':False, 'body_shadow':'self shading only, no floor',
    'script':str(Path(__file__).resolve()), 'blend':str(OUT/'steel_sheep.blend'),
    'render':scene.render.filepath,
}
(OUT/'metadata.json').write_text(json.dumps(meta,indent=2),encoding='utf-8')
scene['p109_output_dir'] = str(OUT)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'steel_sheep.blend'), copy=True)
print('P109_BUILD_COMPLETE '+json.dumps(meta))
