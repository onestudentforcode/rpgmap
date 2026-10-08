# -*- coding: utf-8 -*-
# lotus_flower.py —— 在 Blender(4.x) 的 Scripting 工作区打开并运行
# 生成内容：四层包合的花瓣 + 莲蓬(含柱头盘/种子) + 雄蕊环 + 花托，
#           含渐变顶点色材质、三点布光、相机，运行后视口自动切到材质预览。
# 可重复运行：脚本会先清理上次生成的 "Lotus*" 物体再重建。

import bpy
import bmesh
import random
from math import sin, cos, pi, radians
from mathutils import Matrix

# ---------------------------------------------------------------- 参数 ----
# 每层花瓣：数量 / 长度 / 最大半宽 / 根部倾角 / 沿长度弯曲角 / 根部半径 / 根部高度 / 粉色强度
LAYERS = [
    dict(n=5,  L=0.62, hw=0.150, tilt=8,  bend=42,  r0=0.10, z0=0.02,  tint=0.22),
    dict(n=8,  L=0.82, hw=0.185, tilt=24, bend=70,  r0=0.13, z0=0.00,  tint=0.50),
    dict(n=10, L=0.98, hw=0.215, tilt=42, bend=95,  r0=0.16, z0=-0.02, tint=0.78),
    dict(n=13, L=1.08, hw=0.245, tilt=58, bend=112, r0=0.19, z0=-0.05, tint=1.00),
]
PETAL_GRID = (10, 14)          # 花瓣网格 (宽度段数, 长度段数)

BASE_WHITE = (1.00, 0.945, 0.92)   # 花瓣根部颜色(linear)
TIP_PINK   = (0.90, 0.26, 0.40)    # 花瓣尖端粉(linear)
BASE_GREEN = (0.72, 0.85, 0.62)    # 花瓣最根部的一抹绿(linear)

GREEN_MAT   = (0.055, 0.20, 0.045)   # 莲蓬/花托 嫩绿(linear)
YELLOW_MAT  = (0.95, 0.70, 0.10)     # 柱头盘/种子 黄(linear)
STAMEN_MAT  = (1.00, 0.72, 0.12)     # 雄蕊 黄(linear)

# ---------------------------------------------------------------- 工具 ----
def set_in(socket_owner, names, value):
    """按多个候选名给节点输入赋值(兼容 Blender 3.x/4.x 的输入改名)。"""
    for n in names:
        if n in socket_owner.inputs:
            socket_owner.inputs[n].default_value = value
            return


def node_by_type(nt, node_type):
    """按类型取节点。节点的默认名字会随界面语言本地化(如中文版叫"原理化 BSDF")，
    所以不能按名字查找，必须按类型遍历。"""
    for n in nt.nodes:
        if n.type == node_type:
            return n
    raise KeyError("node type not found: %s" % node_type)


def purge_lotus():
    """删除上次生成的所有 Lotus 物体/集合/孤立数据，保证脚本可重复运行。"""
    for obj in list(bpy.data.objects):
        if obj.name.startswith("Lotus"):
            bpy.data.objects.remove(obj, do_unlink=True)
    for coll in list(bpy.data.collections):
        if coll.name.startswith("Lotus"):
            bpy.data.collections.remove(coll)
    for db in (bpy.data.meshes, bpy.data.materials,
               bpy.data.lights, bpy.data.cameras, bpy.data.worlds):
        for item in list(db):
            if item.users == 0:
                db.remove(item)


def lotus_collection():
    coll = bpy.data.collections.new("LotusFlower")
    bpy.context.scene.collection.children.link(coll)
    return coll


def link(coll, obj):
    coll.objects.link(obj)
    return obj

# ---------------------------------------------------------------- 材质 ----
def make_petal_material():
    mat = bpy.data.materials.new("LotusPetal")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = node_by_type(nt, 'BSDF_PRINCIPLED')
    out = node_by_type(nt, 'OUTPUT_MATERIAL')

    set_in(bsdf, ("Subsurface Weight", "Subsurface"), 0.10)
    set_in(bsdf, ("Subsurface Radius",), (0.12, 0.05, 0.06))
    set_in(bsdf, ("Specular IOR Level", "Specular"), 0.25)
    set_in(bsdf, ("Roughness",), 0.45)
    set_in(bsdf, ("Coat Weight", "Clearcoat"), 0.15)

    # 顶点色 'Col'(根部白 -> 尖端粉) 接到 Base Color
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])

    # 混一点透光，让花瓣有薄瓣透光的质感
    trans = nt.nodes.new("ShaderNodeBsdfTranslucent")
    trans.inputs["Color"].default_value = (0.9, 0.55, 0.6, 1.0)
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.inputs["Fac"].default_value = 0.15
    nt.links.new(bsdf.outputs["BSDF"], mix.inputs[1])
    nt.links.new(trans.outputs["BSDF"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
    return mat


def make_solid_material(name, color, rough=0.5, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = node_by_type(mat.node_tree, 'BSDF_PRINCIPLED')
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    set_in(bsdf, ("Roughness",), rough)
    if emission > 0.0:
        set_in(bsdf, ("Emission Color", "Emission"), (*color, 1.0))
        set_in(bsdf, ("Emission Strength",), emission)
    return mat

# ---------------------------------------------------------------- 花瓣 ----
def petal_shape(t):
    """花瓣半宽轮廓：基部收窄，中部最宽，顶端钝圆收窄。t=0 根部, 1 尖端。"""
    return max(sin(pi * (0.10 + 0.83 * t)), 0.0) ** 0.75


def build_petal_mesh(layer, rng):
    """生成一片花瓣 mesh(含 'Col' 顶点色)。局部坐标：根部在原点，沿 +Z 直立并向 +Y 外弯。"""
    nvX, nvY = PETAL_GRID
    L, hw = layer["L"], layer["hw"]
    bend = radians(layer["bend"])
    tilt = radians(layer["tilt"])
    r0, z0, tint = layer["r0"], layer["z0"], layer["tint"]

    # 少量随机扰动，避免花瓣排列过于机械
    az = radians(rng.uniform(-3.0, 3.0))
    L *= rng.uniform(0.97, 1.03)

    R = L / bend if bend > 0.05 else 0.0
    verts, colors = [], []
    for j in range(nvY + 1):
        t = j / nvY
        half = hw * petal_shape(t)
        phi = t * bend
        if R > 0.0:
            zc = R * sin(phi)          # 沿高度
            yc = R * (1.0 - cos(phi))  # 向外弯
        else:
            zc, yc = t * L, 0.0
        cup = 0.09 * L * (1.0 - t) ** 1.6 * layer.get("cup", 1.0)
        for i in range(nvX + 1):
            u = i / nvX
            x = (u - 0.5) * 2.0 * half
            z = zc + cup * (2.0 * u - 1.0) ** 2          # 杯状内凹(边缘上抬)
            if t > 0.88:                                   # 尖端微微回勾
                z -= 0.03 * L * ((t - 0.88) / 0.12) ** 2
            verts.append((x, yc, z))
            # 颜色：白 -> 粉 smoothstep 渐变，最根部带一点绿
            k = max(0.0, min(1.0, (t - 0.06) / 0.88))
            k = k * k * (3.0 - 2.0 * k)
            k *= tint
            col = [BASE_WHITE[c] + (TIP_PINK[c] - BASE_WHITE[c]) * k for c in range(3)]
            g = max(0.0, 0.22 - t) * 1.2
            col = [col[c] + (BASE_GREEN[c] - col[c]) * g for c in range(3)]
            colors.append((*col, 1.0))

    faces = []
    for j in range(nvY):
        for i in range(nvX):
            a = i + j * (nvX + 1)
            faces.append((a, a + 1, a + nvX + 2, a + nvX + 1))

    me = bpy.data.meshes.new("LotusPetal")
    me.from_pydata(verts, [], faces)
    ca = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for idx, c in enumerate(colors):
        ca.data[idx].color = c
    me.validate()
    me.update()

    # 摆放：局部直立 -> 绕X向外倾 tilt -> 绕Z转到方位角 -> 平移到花心周围
    az_total = az + layer["azimuth"]
    M = (Matrix.Translation((r0 * sin(az_total), r0 * cos(az_total), z0))
         @ Matrix.Rotation(az_total, 4, 'Z')
         @ Matrix.Rotation(-tilt, 4, 'X'))
    me.transform(M)
    return me


def build_petals(coll, petal_mat, rng):
    objs = []
    for li, layer in enumerate(LAYERS):
        step = 2.0 * pi / layer["n"]
        for k in range(layer["n"]):
            layer["azimuth"] = k * step + li * step * 0.5  # 层间错位
            me = build_petal_mesh(layer, rng)
            ob = bpy.data.objects.new("LotusPetal", me)
            link(coll, ob)
            objs.append(ob)

    with bpy.context.temp_override(
            selected_objects=objs, active_object=objs[0],
            selected_editable_objects=objs):
        bpy.ops.object.join()
    petals = objs[0]
    petals.name = "LotusPetals"

    me = petals.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True

    solid = petals.modifiers.new("Solidify", 'SOLIDIFY')
    solid.thickness = 0.006
    solid.offset = 0.0
    sub = petals.modifiers.new("Subsurf", 'SUBSURF')
    sub.levels = 2
    sub.render_levels = 3
    petals.data.materials.append(petal_mat)
    return petals

# ------------------------------------------------------- 莲蓬/花蕊/花托 ----
def new_faces(bm, start):
    return bm.faces[start:]


def bm_uvsphere(bm, u_segments, v_segments, radius, matrix, calc_uvs=True):
    """创建 UV 球。Blender 4.0 起 create_uvsphere 的参数从 diameter 改名为 radius。"""
    if bpy.app.version >= (4, 0, 0):
        bmesh.ops.create_uvsphere(bm, u_segments=u_segments, v_segments=v_segments,
                                  radius=radius, matrix=matrix, calc_uvs=calc_uvs)
    else:
        bmesh.ops.create_uvsphere(bm, u_segments=u_segments, v_segments=v_segments,
                                  diameter=radius, matrix=matrix, calc_uvs=calc_uvs)


def build_seedpod(coll, green_mat, yellow_mat):
    """莲蓬：绿色倒锥 + 顶部黄色柱头盘 + 6 颗种子球。"""
    bm = bmesh.new()
    n0 = len(bm.faces)
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=40,
                          radius1=0.30, radius2=0.17, depth=0.26,
                          matrix=Matrix.Translation((0, 0, 0.15)), calc_uvs=True)
    for f in new_faces(bm, n0):
        f.material_index = 0
    n0 = len(bm.faces)
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=32,
                          radius1=0.20, radius2=0.20, depth=0.035,
                          matrix=Matrix.Translation((0, 0, 0.285)), calc_uvs=True)
    for f in new_faces(bm, n0):
        f.material_index = 1
    for k in range(6):
        az = k * pi / 3.0 + 0.3
        n0 = len(bm.faces)
        bm_uvsphere(bm, 12, 8, 0.05,
                    matrix=Matrix.Translation(
                        (0.10 * sin(az), 0.10 * cos(az), 0.30)))
        for f in new_faces(bm, n0):
            f.material_index = 1

    me = bpy.data.meshes.new("LotusSeedpod")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(green_mat)
    me.materials.append(yellow_mat)
    return link(coll, bpy.data.objects.new("LotusSeedpod", me))


def build_stamens(coll, stamen_mat, rng):
    """雄蕊环：围绕莲蓬底部一圈细丝+顶端药球，带随机扰动。"""
    bm = bmesh.new()
    n = 26
    for k in range(n):
        az = k * 2.0 * pi / n + rng.uniform(-0.06, 0.06)
        lean = radians(30.0 + rng.uniform(-8.0, 8.0))
        h = 0.22 * rng.uniform(0.85, 1.15)
        base = Matrix.Translation((0.20 * sin(az), 0.20 * cos(az), 0.06))
        rot = Matrix.Rotation(az, 4, 'Z') @ Matrix.Rotation(-lean, 4, 'X')
        n0 = len(bm.faces)
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6,
                              radius1=0.008, radius2=0.008, depth=h,
                              matrix=base @ rot @ Matrix.Translation((0, 0, h / 2)),
                              calc_uvs=True)
        bm_uvsphere(bm, 8, 6, 0.017,
                    matrix=base @ rot @ Matrix.Translation((0, 0, h + 0.012)))
        for f in bm.faces[n0:]:
            f.smooth = True
    me = bpy.data.meshes.new("LotusStamens")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(stamen_mat)
    return link(coll, bpy.data.objects.new("LotusStamens", me))


def build_receptacle(coll, green_mat):
    """花托：花朵底部的绿色倒锥，托住所有花瓣根部。"""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=32,
                          radius1=0.22, radius2=0.07, depth=0.18,
                          matrix=Matrix.Translation((0, 0, -0.09)), calc_uvs=True)
    me = bpy.data.meshes.new("LotusReceptacle")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(green_mat)
    return link(coll, bpy.data.objects.new("LotusReceptacle", me))

# ------------------------------------------------------------ 灯光相机 ----
def build_environment(coll):
    scene = bpy.context.scene

    sun_data = bpy.data.lights.new("LotusSun", 'SUN')
    sun_data.energy = 3.0
    sun_data.color = (1.0, 0.96, 0.90)
    sun = bpy.data.objects.new("LotusSun", sun_data)
    sun.rotation_euler = (radians(55), 0.0, radians(35))
    link(coll, sun)

    fill_data = bpy.data.lights.new("LotusFill", 'SUN')
    fill_data.energy = 0.7
    fill_data.color = (0.85, 0.90, 1.0)
    fill = bpy.data.objects.new("LotusFill", fill_data)
    fill.rotation_euler = (radians(20), 0.0, radians(150))
    link(coll, fill)

    target = bpy.data.objects.new("LotusTarget", None)
    target.location = (0.0, 0.0, 0.35)
    link(coll, target)

    cam_data = bpy.data.cameras.new("LotusCam")
    cam_data.lens = 60
    cam = bpy.data.objects.new("LotusCam", cam_data)
    cam.location = (2.7, -2.4, 2.0)
    con = cam.constraints.new('TRACK_TO')
    con.target = target
    con.track_axis = 'TRACK_NEGATIVE_Z'
    con.up_axis = 'UP_Y'
    link(coll, cam)
    scene.camera = cam

    world = bpy.data.worlds.new("LotusWorld")
    world.use_nodes = True
    bg = node_by_type(world.node_tree, 'BACKGROUND')
    bg.inputs[0].default_value = (0.88, 0.90, 0.93, 1.0)
    bg.inputs[1].default_value = 1.0
    scene.world = world

    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1600

# ---------------------------------------------------------------- 主流程 ----
def main():
    purge_lotus()
    rng = random.Random(7)
    coll = lotus_collection()

    petal_mat = make_petal_material()
    green_mat = make_solid_material("LotusGreen", GREEN_MAT, rough=0.55)
    yellow_mat = make_solid_material("LotusYellow", YELLOW_MAT, rough=0.4)
    stamen_mat = make_solid_material("LotusStamen", STAMEN_MAT, rough=0.4, emission=0.08)

    build_petals(coll, petal_mat, rng)
    build_seedpod(coll, green_mat, yellow_mat)
    build_stamens(coll, stamen_mat, rng)
    build_receptacle(coll, green_mat)
    build_environment(coll)

    # 视口切到材质预览，直接就能看到渐变效果
    for area in bpy.context.screen.areas:
        if area.type == 'VIEW_3D':
            for space in area.spaces:
                if space.type == 'VIEW_3D':
                    space.shading.type = 'MATERIAL'

    print("莲花生成完毕：花瓣 %d 片 / 莲蓬 / 雄蕊 / 花托，相机=LotusCam，F12 渲染。"
          % sum(l["n"] for l in LAYERS))


main()
