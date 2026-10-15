"""35-degree resource scenery; deterministic geometry, transparent PNGs, no upstream edits."""
import bpy, math, json, hashlib, struct
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'.art-work/p86-resources'
OUT.mkdir(parents=True,exist_ok=True)

def mat(name,color,metal=0):
    value=bpy.data.materials.new(name);value.use_nodes=True
    shader=value.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=(*color,1)
    shader.inputs['Roughness'].default_value=.78
    shader.inputs['Metallic'].default_value=metal
    return value

def rock(name,loc,scale,material):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=loc)
    obj=bpy.context.object;obj.name=name;obj.scale=scale;obj.data.materials.append(material)
    bevel=obj.modifiers.new('Soft broad edges','BEVEL');bevel.width=.02;bevel.segments=2
    return obj

for ident in ('ore_source','spring_source'):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene;scene.name='P86_'+ident
    grey=mat('warm grey rock',(.34,.37,.32))
    light=mat('light rock',(.48,.49,.39))
    if ident=='ore_source':
        metal=mat('iron seams',(.24,.31,.34),.35)
        rust=mat('warm iron oxide',(.43,.29,.16))
        rock('rock outcrop',(0,0,.29),(.78,.54,.34),grey)
        for i,(x,y,h) in enumerate([(-.42,.06,.58),(.02,0,.74),(.39,.12,.49)]):
            bpy.ops.mesh.primitive_cone_add(vertices=6,radius1=.19,radius2=.10,depth=h,location=(x,y,h/2+.08))
            obj=bpy.context.object;obj.name='iron bearing ridge';obj.rotation_euler.y=(i-1)*.18
            obj.data.materials.append(metal)
        for x,y in [(-.48,-.35),(.46,-.31),(.22,.34)]:
            rock('oxide fragment',(x,y,.10),(.16,.12,.10),rust)
    else:
        water=mat('spring jade water',(.21,.47,.44),.12)
        ripple=mat('water rim glint',(.57,.72,.61))
        for i in range(9):
            angle=i*math.tau/9
            rock('spring rim',(math.cos(angle)*.62,math.sin(angle)*.43,.12),(.24,.19,.15),light if i%3 else grey)
        rock('spring surface',(0,0,.12),(.60,.40,.055),water)
        for radius in (.19,.37):
            bpy.ops.mesh.primitive_torus_add(major_radius=radius,minor_radius=.011,major_segments=48,minor_segments=6,location=(0,0,.18))
            obj=bpy.context.object;obj.scale.y=.67;obj.data.materials.append(ripple)
        rock('source stone',(-.15,.28,.23),(.22,.18,.26),grey)
    bpy.ops.object.camera_add()
    camera=bpy.context.object;target=Vector((0,0,.60))
    camera.location=target+Vector((0,math.cos(math.radians(35))*10,math.sin(math.radians(35))*10))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO';camera.data.ortho_scale=3.4;scene.camera=camera
    bpy.ops.object.light_add(type='AREA',location=(4,1,7))
    light_obj=bpy.context.object;light_obj.data.energy=500;light_obj.data.shape='DISK';light_obj.data.size=4.5
    light_obj.rotation_euler=(-light_obj.location).to_track_quat('-Z','Y').to_euler()
    world=bpy.data.worlds.new('soft fill');world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.68,.73,.68,1)
    world.node_tree.nodes['Background'].inputs[1].default_value=.65;scene.world=world
    scene.render.engine='CYCLES';scene.cycles.samples=96;scene.cycles.use_denoising=True
    scene.render.resolution_x=256;scene.render.resolution_y=256;scene.render.resolution_percentage=100
    scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
    scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
    path=OUT/(ident+'.png');scene.render.filepath=str(path);scene.view_layers[0].update()
    uv=world_to_camera_view(scene,camera,Vector((0,0,0)))
    bpy.ops.render.render(write_still=True)
    raw=path.read_bytes();stable=bytearray(raw[:8]);offset=8
    while offset<len(raw):
        size=struct.unpack('>I',raw[offset:offset+4])[0];kind=raw[offset+4:offset+8]
        if kind in {b'IHDR',b'IDAT',b'IEND',b'sRGB',b'gAMA',b'cHRM',b'pHYs'}:stable.extend(raw[offset:offset+12+size])
        offset+=12+size
    path.write_bytes(stable)
    report={'id':ident,'path':'res://assets/farming/p86/'+ident+'.png','canvas_px':[256,256],
      'anchor_uv':[uv.x,1-uv.y],'draw_size':[83.2,83.2],'sha256':hashlib.sha256(stable).hexdigest(),
      'camera_type':'ORTHO','elevation_degrees':35,'samples':96,'generator':Path(__file__).relative_to(ROOT).as_posix(),
      'generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    (OUT/(ident+'.json')).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('P86 RESOURCE RENDER OK',ident,flush=True)
