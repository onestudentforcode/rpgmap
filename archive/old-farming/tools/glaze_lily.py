# -*- coding: utf-8 -*-
# glaze_lily.py —— 琉璃百合（参考原神外观）高质量版
# 方法论移植自 lotus_flower.py：10x14 曲面网格花瓣（宽度轮廓+圆弧弯曲+杯状内凹+
# 尖端回勾）、顶点色 smoothstep 渐变、SSS/透光/清漆材质、雄蕊环+柱头、弯茎、
# 剑形曲面叶、Solidify 加厚度 + Subsurf 圆滑。
# 生成 "GlazeLilyPlant"（单株，原点在土面根部，高约 0.5m）并在耕地四象限种 4 株。
# 可重复运行；在 Blender Scripting 运行或由 MCP exec。

import bpy
import bmesh
import random
from math import sin, cos, pi, radians
from mathutils import Matrix, Vector, noise as mnoise

# ---------------------------------------------------------------- 参数 ----
LAYERS = [  # 三层百合瓣：内层近直立包合 -> 外层张开反卷
    dict(n=6, L=0.085, hw=0.021, tilt=14, bend=28, r0=0.011, z0=0.008, tint=0.30, cup=1.3),
    dict(n=6, L=0.105, hw=0.027, tilt=34, bend=60, r0=0.015, z0=0.004, tint=0.65, cup=1.0),
    dict(n=6, L=0.116, hw=0.031, tilt=52, bend=95, r0=0.019, z0=0.000, tint=1.00, cup=0.8),
]
PETAL_GRID = (10, 14)

STEM_H = 0.40
STEM_BEND = 0.05          # 茎顶水平偏移：优雅弯姿
HEAD_XY = (STEM_BEND, STEM_BEND * 0.4)
HEAD_Z = STEM_H - 0.004   # 花心（花托顶面）

BASE_WHITE = (1.00, 0.99, 0.985)
TIP_LILAC  = (0.38, 0.35, 0.68)   # 琉璃蓝紫
BASE_GREEN = (0.62, 0.80, 0.60)
LEAF_ROOT  = (0.05, 0.22, 0.06)
LEAF_TIP   = (0.26, 0.58, 0.22)
STEM_MAT   = (0.14, 0.38, 0.16)
GOLD_MAT   = (0.95, 0.62, 0.10)
STIGMA_MAT = (0.98, 0.72, 0.22)

# ---------------------------------------------------------------- 工具 ----
def set_in(owner, names, value):
    for n in names:
        if n in owner.inputs:
            owner.inputs[n].default_value = value
            return

def node_by_type(nt, t):
    for n in nt.nodes:
        if n.type == t:
            return n
    raise KeyError(t)

def purge():
    for obj in list(bpy.data.objects):
        if obj.name.startswith("GlazeLily") or obj.name.startswith("Crop_GlazeLily"):
            bpy.data.objects.remove(obj, do_unlink=True)
    for db in (bpy.data.meshes, bpy.data.materials):
        for item in list(db):
            if item.users == 0:
                db.remove(item)

# ---------------------------------------------------------------- 材质 ----
def make_petal_material():
    mat = bpy.data.materials.new("LilyPetal")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = node_by_type(nt, 'BSDF_PRINCIPLED')
    out = node_by_type(nt, 'OUTPUT_MATERIAL')
    set_in(bsdf, ("Subsurface Weight", "Subsurface"), 0.12)
    set_in(bsdf, ("Subsurface Radius",), (0.10, 0.04, 0.06))
    set_in(bsdf, ("Specular IOR Level", "Specular"), 0.35)
    set_in(bsdf, ("Roughness",), 0.30)
    set_in(bsdf, ("Coat Weight", "Clearcoat"), 0.35)   # 琉璃感
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    trans = nt.nodes.new("ShaderNodeBsdfTranslucent")
    trans.inputs["Color"].default_value = (0.80, 0.80, 0.95, 1.0)
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.inputs["Fac"].default_value = 0.20
    nt.links.new(bsdf.outputs["BSDF"], mix.inputs[1])
    nt.links.new(trans.outputs["BSDF"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
    return mat

def make_vc_material(name, rough=0.7):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Col"
    nt.links.new(attr.outputs["Color"], node_by_type(nt, 'BSDF_PRINCIPLED').inputs["Base Color"])
    set_in(node_by_type(nt, 'BSDF_PRINCIPLED'), ("Roughness",), rough)
    return m

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

# ---------------------------------------------------------------- 曲面网格 ----
def shape_hw(t):
    """瓣半宽轮廓：基部收窄、中前部最宽、顶端钝圆。"""
    return max(sin(pi * (0.08 + 0.86 * t)), 0.0) ** 0.72

def build_curved_mesh(grid, length, half_w, bend_deg, cup=1.0, tip_curl=0.03,
                      colors_fn=None, rng=None):
    nvX, nvY = grid
    bend = radians(bend_deg)
    if rng is not None:
        bend *= rng.uniform(0.95, 1.05)
        length *= rng.uniform(0.97, 1.03)
    R = length / bend if bend > 0.05 else 0.0
    verts, colors = [], []
    for j in range(nvY + 1):
        t = j / nvY
        half = half_w * shape_hw(t)
        phi = t * bend
        zc, yc = (R * sin(phi), R * (1 - cos(phi))) if R > 0 else (t * length, 0.0)
        cupz = 0.09 * length * (1 - t) ** 1.6 * cup
        for i in range(nvX + 1):
            u = i / nvX
            x = (u - 0.5) * 2.0 * half
            z = zc + cupz * (2 * u - 1) ** 2
            if t > 0.88:
                z -= tip_curl * length * ((t - 0.88) / 0.12) ** 2
            verts.append((x, yc, z))
            colors.append(colors_fn(t, u) if colors_fn else (1, 1, 1, 1))
    faces = []
    for j in range(nvY):
        for i in range(nvX):
            a = i + j * (nvX + 1)
            faces.append((a, a + 1, a + nvX + 2, a + nvX + 1))
    me = bpy.data.meshes.new("LilyPart")
    me.from_pydata(verts, [], faces)
    ca = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for idx, c in enumerate(colors):
        ca.data[idx].color = c
    me.validate()
    me.update()
    return me

def place_part(me, tilt_deg, azimuth, r0, z0, rng=None):
    """绕 X 外倾 -> 绕 Z 方位 -> 平移到花心 (HEAD_XY, z0)。"""
    az = radians(azimuth + (rng.uniform(-3, 3) if rng else 0.0))
    M = (Matrix.Translation((HEAD_XY[0] + r0 * sin(az), HEAD_XY[1] + r0 * cos(az), z0))
         @ Matrix.Rotation(az, 4, 'Z') @ Matrix.Rotation(radians(-tilt_deg), 4, 'X'))
    me.transform(M)

# ---------------------------------------------------------------- 颜色函数 ----
def petal_color(tint):
    def fn(t, u):
        k = max(0.0, min(1.0, (t - 0.06) / 0.88))
        k = k * k * (3 - 2 * k) * tint
        col = [BASE_WHITE[c] + (TIP_LILAC[c] - BASE_WHITE[c]) * k for c in range(3)]
        g = max(0.0, 0.20 - t) * 1.2
        return (*[col[c] + (BASE_GREEN[c] - col[c]) * g for c in range(3)], 1.0)
    return fn

def leaf_color(t, u):
    k = t * t * (3 - 2 * t)
    return (*[LEAF_ROOT[c] + (LEAF_TIP[c] - LEAF_ROOT[c]) * k for c in range(3)], 1.0)

# ---------------------------------------------------------------- 部件 ----
def build_flower_head(parts, rng):
    for li, layer in enumerate(LAYERS):
        step = 2 * pi / layer["n"]
        for k in range(layer["n"]):
            me = build_curved_mesh(PETAL_GRID, layer["L"], layer["hw"], layer["bend"],
                                   cup=layer["cup"], tip_curl=0.035,
                                   colors_fn=petal_color(layer["tint"]), rng=rng)
            place_part(me, layer["tilt"], k * step + li * step * 0.5,
                       layer["r0"], HEAD_Z + layer["z0"], rng)
            parts.append((me, "petal"))

    bm = bmesh.new()
    for k in range(12):  # 雄蕊环
        az = k * 2 * pi / 12 + rng.uniform(-0.08, 0.08)
        lean = radians(24 + rng.uniform(-8, 8))
        h = 0.040 * rng.uniform(0.85, 1.15)
        base = Matrix.Translation((HEAD_XY[0] + 0.008 * sin(az), HEAD_XY[1] + 0.008 * cos(az), HEAD_Z))
        rot = Matrix.Rotation(az, 4, 'Z') @ Matrix.Rotation(-lean, 4, 'X')
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=5,
                              radius1=0.0022, radius2=0.0022, depth=h,
                              matrix=base @ rot @ Matrix.Translation((0, 0, h / 2)))
        bmesh.ops.create_uvsphere(bm, u_segments=6, v_segments=5, radius=0.006,
                                  matrix=base @ rot @ Matrix.Translation((0, 0, h + 0.006)))
    st = bpy.data.meshes.new("LilyStamens")
    bm.to_mesh(st); bm.free()
    parts.append((st, "gold"))

    bm = bmesh.new()  # 柱头：金柱 + 三叉球
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=8,
                          radius1=0.006, radius2=0.003, depth=0.045,
                          matrix=Matrix.Translation((HEAD_XY[0], HEAD_XY[1], HEAD_Z + 0.0225)))
    for az in (0, 2.1, 4.2):
        bmesh.ops.create_uvsphere(
            bm, u_segments=8, v_segments=6, radius=0.009,
            matrix=Matrix.Translation((HEAD_XY[0] + 0.007 * sin(az), HEAD_XY[1] + 0.007 * cos(az), HEAD_Z + 0.05)))
    sg = bpy.data.meshes.new("LilyStigma")
    bm.to_mesh(sg); bm.free()
    parts.append((sg, "stigma"))

def build_stem(parts):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=10,
                          radius1=0.008, radius2=0.013, depth=STEM_H)
    for v in bm.verts:  # 逐顶点弯出弧度
        t = max(0.0, (v.co.z + STEM_H / 2) / STEM_H)
        v.co.x += STEM_BEND * t * t
        v.co.y += STEM_BEND * 0.4 * t * t
        v.co.z += STEM_H / 2
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=12,
                          radius1=0.020, radius2=0.006, depth=0.030,
                          matrix=Matrix.Translation((HEAD_XY[0], HEAD_XY[1], STEM_H - 0.008)))
    me = bpy.data.meshes.new("LilyStem")
    bm.to_mesh(me); bm.free()
    parts.append((me, "stem"))

def build_leaves(parts, rng):
    for az in (20, 150, 265):
        me = build_curved_mesh((8, 12), 0.30, 0.033, 18, cup=0.7, tip_curl=0.10,
                               colors_fn=leaf_color, rng=rng)
        place_part(me, 74, az + rng.uniform(-8, 8), 0.012, 0.0, rng)
        parts.append((me, "leaf"))

def build_bud(parts, rng):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6,
                          radius1=0.005, radius2=0.008, depth=0.22,
                          matrix=Matrix.Rotation(radians(16), 4, 'X')
                          @ Matrix.Translation((0.035, 0.015, 0.11)))
    me = bpy.data.meshes.new("LilyBudStem")
    bm.to_mesh(me); bm.free()
    parts.append((me, "stem"))
    bud_base = (Matrix.Translation((0.095, 0.045, 0.205))
                @ Matrix.Rotation(radians(16), 4, 'X'))
    for li, (L, hw, tilt, tint) in enumerate(((0.055, 0.014, 4, 0.25), (0.062, 0.017, 10, 0.5))):
        step = 2 * pi / 6
        for k in range(6):
            me = build_curved_mesh((8, 10), L, hw, 10, cup=1.5, tip_curl=0.0,
                                   colors_fn=petal_color(tint), rng=rng)
            M = bud_base @ Matrix.Rotation(radians(k * step + li * step * 0.5), 4, 'Z') \
                @ Matrix.Rotation(radians(-tilt), 4, 'X')
            me.transform(M)
            parts.append((me, "petal"))

# ---------------------------------------------------------------- 落位 ----
def nz(x, y, s, seed):
    return mnoise.noise(Vector((x * s + seed, y * s + seed, seed * 0.73)))

LAM = 2.0 / 6.0
def soil_z(x, y):  # 与耕地雕刻公式一致
    phase = 1.15 * nz(y, 0.0, 1.3, 7.0)
    amp = 0.095 * (0.80 + 0.30 * nz(y, 0.0, 0.9, 40.0))
    furrow = 0.5 * amp * sin(2 * pi * x / LAM + phase)
    clod = 0.030 * (0.5 + 0.5 * nz(x, y, 11.0, 3.7))
    fine = 0.012 * nz(x, y, 28.0, 9.2)
    e = max(0.0, min((1 - abs(x)) / 0.08, (1 - abs(y)) / 0.08, 1.0))
    e = e * e * (3 - 2 * e)
    return 1.0 + furrow + (clod + fine) * e

def plant_instances(plant):
    rng = random.Random(42)
    for i, (px, py) in enumerate(((-0.5, -0.5), (0.5, -0.5), (-0.5, 0.5), (0.5, 0.5))):
        ob = bpy.data.objects.new("GlazeLily_%d" % i, plant.data)
        ob.location = (px, py, soil_z(px, py) - 0.01)
        ob.rotation_euler[2] = radians(rng.uniform(0, 360))
        s = rng.uniform(0.92, 1.08)
        ob.scale = (s, s, s)
        solid = ob.modifiers.new("Solidify", 'SOLIDIFY')  # 实例不继承母物体修饰器
        solid.thickness = 0.0035
        solid.offset = 0.0
        sub = ob.modifiers.new("Subsurf", 'SUBSURF')
        sub.levels = 1
        sub.render_levels = 2
        plant.users_collection[0].objects.link(ob)
        print("planted GlazeLily_%d at (%.2f, %.2f, %.3f)" % (i, px, py, ob.location.z))

# ---------------------------------------------------------------- 主流程 ----
def main():
    purge()
    rng = random.Random(23)
    mats = {
        "petal":  make_petal_material(),
        "leaf":   make_vc_material("LilyLeaf", rough=0.7),
        "stem":   make_solid_material("LilyStem", STEM_MAT, rough=0.8),
        "gold":   make_solid_material("LilyGold", GOLD_MAT, rough=0.4, emission=0.10),
        "stigma": make_solid_material("LilyStigmaM", STIGMA_MAT, rough=0.35, emission=0.18),
    }

    parts = []
    build_stem(parts)
    build_flower_head(parts, rng)
    build_leaves(parts, rng)
    build_bud(parts, rng)

    coll = bpy.data.collections.get("Crops_Flowers")
    if coll is None:
        coll = bpy.data.collections.new("Crops_Flowers")
        bpy.context.scene.collection.children.link(coll)

    objs = []
    for me, kind in parts:
        me.materials.append(mats[kind])
        ob = bpy.data.objects.new("GlazeLilyTmp", me)
        coll.objects.link(ob)
        objs.append(ob)
    with bpy.context.temp_override(selected_objects=objs, active_object=objs[0],
                                   selected_editable_objects=objs):
        bpy.ops.object.join()
    plant = objs[0]
    plant.name = "GlazeLilyPlant"

    me = plant.data
    # 材质槽去重 + 重映射（join 会把各部件的槽直接串起来）
    old = list(me.materials)
    seen, new_mats, remap = {}, [], []
    for m in old:
        if m.name not in seen:
            seen[m.name] = len(new_mats)
            new_mats.append(m)
        remap.append(seen[m.name])
    for p in me.polygons:
        p.material_index = remap[p.material_index]
    me.materials.clear()
    for m in new_mats:
        me.materials.append(m)

    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True

    solid = plant.modifiers.new("Solidify", 'SOLIDIFY')
    solid.thickness = 0.0035
    solid.offset = 0.0
    sub = plant.modifiers.new("Subsurf", 'SUBSURF')
    sub.levels = 1
    sub.render_levels = 2

    plant_instances(plant)
    print("GlazeLilyPlant: verts=%d faces=%d slots=%s"
          % (len(me.vertices), len(me.polygons), [m.name for m in me.materials]))


main()
