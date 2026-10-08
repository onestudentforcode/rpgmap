# -*- coding: utf-8 -*-
# apple_tree.py —— Q版苹果树（程序化建模，可重复运行）
# 方法论移植自 glaze_lily.py / lotus_flower.py：bmesh 管状放样（树干/枝）、
# 多球簇+噪声径向位移的蓬松树冠、曲面网格叶（苹果叶/草叶）、顶点色
# smoothstep 渐变 + Principled 材质。
# 生成 "AppleTree" 集合：TreeTrunk / TreeCanopy / TreeMound / TreeGrass /
# Apple_00..07（挂树，共享 mesh 实例）/ Apple_Ground_0..1（掉落）。
# 原点在树根地面（z=0），整树高约 2.55m。另布 Sun / 世界色 / 预览地面 / 相机。

import bpy
import bmesh
import random
from math import sin, cos, pi, radians, atan2
from mathutils import Matrix, Vector, noise as mnoise, Quaternion, Euler

# ---------------------------------------------------------------- 参数 ----
TRUNK_H = 0.95
TRUNK_R0 = 0.155            # 根部半径（含根展前）
TRUNK_R1 = 0.085
TRUNK_BEND = (0.06, -0.03)  # 树干顶端水平偏移：微 S 弯
FLARE_T = 0.22              # 根展区间（占干高比例）
FLARE_K = 0.55

# 树冠球簇：(cx, cy, cz, r, tint) —— 不对称但均衡的云朵构图
BLOBS = [
    ( 0.00,  0.02, 1.62, 0.80, 1.00),   # 主冠
    (-0.70,  0.22, 1.38, 0.55, 0.94),   # 左后
    ( 0.66, -0.18, 1.34, 0.56, 1.03),   # 右前
    ( 0.10,  0.55, 1.52, 0.46, 0.97),   # 后
    ( 0.14, -0.34, 1.55, 0.44, 1.05),   # 前小
    (-0.18, -0.10, 2.12, 0.42, 1.08),   # 顶
    ( 0.40,  0.30, 1.44, 0.36, 1.02),   # 接缝填充：右后
    (-0.32, -0.30, 1.50, 0.34, 1.04),   # 接缝填充：左前
]
CANOPY_SEGS = (40, 28)
CANOPY_NOISE = 0.055       # 径向噪声幅度（蓬松感）
CROWN_Z0, CROWN_Z1 = 1.02, 2.52   # 顶点色高度渐变区间

# 主枝：指向的球簇索引、出发点高度、基/尖半径
BRANCHES = [
    (1, 0.70, 0.062, 0.030),
    (2, 0.66, 0.066, 0.032),
    (5, 0.78, 0.052, 0.026),
]

# 挂果：(球簇索引, 方位角°, 仰角°(负=下垂), 缩放)
APPLES_HANG = [
    (0,   35, -18, 1.00),
    (0,  150, -22, 0.92),
    (0,  262, -15, 1.05),
    (2,   10, -12, 0.95),
    (2,  185, -28, 1.00),
    (1,  300, -20, 0.98),
    (3,  315, -25, 0.90),
    (5,  210,  10, 0.85),
    (1,  215, -38, 0.90),   # 下半球补充
    (2,  305, -40, 0.95),   # 下半球补充
    (4,   35, -42, 0.92),   # 下半球补充
]
APPLES_GROUND = [   # 掉落的苹果：(x, y, rot_euler度, scale)
    ( 0.76,  0.30, ( 0,  0,  40), 1.00),
    (-0.60, -0.52, (78, 15,   0), 0.92),
]
APPLE_R = 0.092

C_GREEN_DEEP = (0.06, 0.24, 0.09)
C_GREEN_LT   = (0.55, 0.78, 0.22)
C_BARK_DK    = (0.23, 0.15, 0.095)
C_BARK_LT    = (0.40, 0.28, 0.17)
C_MOUND_IN   = (0.11, 0.28, 0.07)
C_MOUND_OUT  = (0.38, 0.58, 0.20)
C_APPLE_RED  = (0.88, 0.05, 0.04)
C_APPLE_SUN  = (1.00, 0.45, 0.10)
C_STEM_BROWN = (0.35, 0.22, 0.12)
C_LEAF_DK    = (0.12, 0.40, 0.10)
C_LEAF_LT    = (0.30, 0.62, 0.20)

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
        if obj.name.startswith("AppleTree") or obj.name.startswith("Apple_") \
           or obj.name in ("PreviewGround", "AppleTreeFocus"):
            bpy.data.objects.remove(obj, do_unlink=True)
    for db in (bpy.data.meshes, bpy.data.materials, bpy.data.lights, bpy.data.cameras):
        for item in list(db):
            if item.users == 0:
                db.remove(item)

def nz3(x, y, z, s=1.0):
    return mnoise.noise(Vector((x * s, y * s, z * s)))

def smoothstep(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3.0 - 2.0 * x)

def mix3(a, b, k):
    return tuple(a[c] + (b[c] - a[c]) * k for c in range(3))

def apply_colors(me, colors):
    ca = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for idx, c in enumerate(colors):
        ca.data[idx].color = (*c, 1.0)

def shade_smooth(ob, subsurf=0, render_levels=None):
    for p in ob.data.polygons:
        p.use_smooth = True
    if subsurf:
        sub = ob.modifiers.new("Subsurf", 'SUBSURF')
        sub.levels = subsurf
        sub.render_levels = render_levels if render_levels is not None else subsurf

# ---------------------------------------------------------------- 材质 ----
def make_vc_material(name, rough=0.7, sss=0.0, coat=0.0, spec=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = node_by_type(nt, 'BSDF_PRINCIPLED')
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    set_in(bsdf, ("Roughness",), rough)
    set_in(bsdf, ("Specular IOR Level", "Specular"), spec)
    if sss:
        set_in(bsdf, ("Subsurface Weight", "Subsurface"), sss)
        set_in(bsdf, ("Subsurface Radius",), (0.5, 0.2, 0.1))
    if coat:
        set_in(bsdf, ("Coat Weight", "Clearcoat"), coat)
    return m

# ---------------------------------------------------------------- 管状放样（树干/枝） ----
def ring_frames(center_fn, rings, up_ref=Vector((1.0, 0.0, 0.0))):
    """沿中心线取流动标架：返回每环 (center, x轴, y轴)。"""
    frames = []
    for i in range(rings + 1):
        t = i / rings
        dt = 0.5 / rings
        c = center_fn(t)
        tan = (center_fn(min(1.0, t + dt)) - center_fn(max(0.0, t - dt))).normalized()
        xax = up_ref.cross(tan)
        if xax.length < 1e-6:
            xax = Vector((0.0, 1.0, 0.0)).cross(tan)
        xax.normalize()
        yax = tan.cross(xax).normalized()
        frames.append((c, xax, yax))
    return frames

# ---------------------------------------------------------------- 曲面网格叶 ----
def leaf_hw(t, power=0.72):
    return max(sin(pi * (0.10 + 0.82 * t)), 0.0) ** power

def add_strip(bm, nvX, nvY, length, half_w, bend_deg, cup, tip_curl,
              color_fn, matrix=None, colors=None, hw_power=0.72):
    """在 bm 中加一片弯曲叶面（局部：沿 +Y 伸展、向 +Z 弯），返回顶点起始索引。"""
    start = len(bm.verts)
    bend = radians(bend_deg)
    R = length / bend if bend > 0.02 else 0.0
    base = len(colors) if colors is not None else 0
    for j in range(nvY + 1):
        t = j / nvY
        half = half_w * leaf_hw(t, hw_power)
        phi = t * bend
        yc = R * sin(phi) if R else t * length
        zc = R * (1 - cos(phi)) if R else 0.0
        cupz = 0.10 * length * (1 - t) ** 1.6 * cup
        for i in range(nvX + 1):
            u = i / nvX
            x = (u - 0.5) * 2.0 * half
            z = zc + cupz * (2 * u - 1) ** 2
            if t > 0.86 and tip_curl:
                z -= tip_curl * length * ((t - 0.86) / 0.14) ** 2
            co = Vector((x, yc, z))
            if matrix is not None:
                co = matrix @ co
            bm.verts.new(co)
            if colors is not None:
                colors.append(color_fn(t, u))
    for j in range(nvY):
        bm.verts.ensure_lookup_table()
        for i in range(nvX):
            a = start + i + j * (nvX + 1)
            bm.faces.new((bm.verts[a], bm.verts[a + 1],
                          bm.verts[a + nvX + 2], bm.verts[a + nvX + 1]))
    return start

# ---------------------------------------------------------------- 树干与主枝 ----
def build_trunk(rng):
    colors = []
    parts = []  # (frames, radius_fn)

    def trunk_center(t):
        s = smoothstep(t)
        return Vector((TRUNK_BEND[0] * s, TRUNK_BEND[1] * s, TRUNK_H * t))

    def trunk_radius(t):
        r = TRUNK_R0 + (TRUNK_R1 - TRUNK_R0) * smoothstep(t)
        if t < FLARE_T:                      # 根部展开
            k = (1.0 - t / FLARE_T) ** 1.8
            r *= 1.0 + FLARE_K * k
        return r

    parts.append((trunk_center, trunk_radius))

    for bi, (blob_i, z0, r0, r1) in enumerate(BRANCHES):
        cx, cy, cz, cr, _ = BLOBS[blob_i]
        p0 = trunk_center(z0 / TRUNK_H)
        target = Vector((cx * 0.72, cy * 0.72, cz - cr * 0.28))   # 插入冠内
        d = target - p0
        ln = d.length
        dv = d.normalized()

        def br_center(t, p0=p0, dv=dv, ln=ln, seed=bi * 3.7):
            c = p0 + dv * (ln * t)
            c.z += 0.10 * ln * sin(pi * t) * 0.5          # 上拱弧线
            c.x += 0.03 * nz3(t, seed, 0.0, 2.0)
            return c

        def br_radius(t, r0=r0, r1=r1):
            return r0 + (r1 - r0) * t

        parts.append((br_center, br_radius))

    meshes = []
    for center_fn, radius_fn in parts:
        frames = ring_frames(center_fn, 10)
        cols = []
        bm = bmesh.new()
        # 先放样再统一取色：顶点顺序 = 环*seg
        seg = 20
        rings = []
        for i, (c, xax, yax) in enumerate(frames):
            t = i / (len(frames) - 1)
            r = radius_fn(t)
            ring = []
            for k in range(seg):
                a = k * 2 * pi / seg
                ring.append(bm.verts.new(c + xax * (r * cos(a)) + yax * (r * sin(a))))
            rings.append(ring)
        for i in range(len(rings) - 1):
            for k in range(seg):
                bm.faces.new((rings[i][k], rings[i][(k + 1) % seg],
                              rings[i + 1][(k + 1) % seg], rings[i + 1][k]))
        bm.faces.new(rings[0])
        for v in bm.verts:                       # 表面噪声起伏（轻微，不写实）
            ns = nz3(v.co.x * 5.0, v.co.y * 5.0, v.co.z * 6.0)
            k = smoothstep(max(0.0, min(1.0, v.co.z / TRUNK_H)))
            col = mix3(C_BARK_DK, C_BARK_LT, k)
            g = 1.0 + 0.05 * ns
            cols.append((col[0] * g, col[1] * g, col[2] * g))
        me = bpy.data.meshes.new("AppleTreeTrunkPart")
        bm.to_mesh(me)
        bm.free()
        apply_colors(me, cols)
        meshes.append(me)

    # 合并多段
    bm = bmesh.new()
    for m in meshes:
        bm.from_mesh(m)
        bpy.data.meshes.remove(m)
    me = bpy.data.meshes.new("AppleTreeTrunk")
    bm.to_mesh(me)
    bm.free()
    cols = []
    for v in me.vertices:
        k = smoothstep(max(0.0, min(1.0, v.co.z / (TRUNK_H + 0.2))))
        col = mix3(C_BARK_DK, C_BARK_LT, k)
        g = 1.0 + 0.05 * nz3(v.co.x * 5.0, v.co.y * 5.0, v.co.z * 6.0)
        cols.append((col[0] * g, col[1] * g, col[2] * g))
    apply_colors(me, cols)
    return me

# ---------------------------------------------------------------- 树冠 ----
def build_canopy(rng):
    """Metaball 隐式融合生成无缝树冠，转网格后加噪声径向位移 + 顶点色渐变。
    相比多球叠加，接缝由融合场自然圆滑，蓬松云朵感更强。"""
    mb = bpy.data.metaballs.new("AppleTreeCanopyMB")
    mb.resolution = 0.055          # 体素分辨率（影响最终网格密度）
    mb.threshold = 0.6
    for bi, (cx, cy, cz, r, _tint) in enumerate(BLOBS):
        el = mb.elements.new(type='BALL')
        el.co = (cx, cy, cz)
        el.radius = r
    mb_ob = bpy.data.objects.new("AppleTreeCanopyMB", mb)
    bpy.context.scene.collection.objects.link(mb_ob)
    # 生成预览网格（depsgraph 求值）并拷贝成普通 mesh
    dg = bpy.context.evaluated_depsgraph_get()
    mb_ob_eval = mb_ob.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(mb_ob_eval, preserve_all_data_layers=False,
                                         depsgraph=dg)
    me.name = "AppleTreeCanopy"
    bpy.data.objects.remove(mb_ob, do_unlink=True)
    bpy.data.metaballs.remove(mb)

    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    # 转网格可能留下重复顶点/乱向面，先清理再做位移与着色，保证顶点色对齐
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0004)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.verts.ensure_lookup_table()
    colors = []
    # 融合表面上"最近球簇"会在球间突变，噪声径向缩放统一改相对冠质心，
    # 保证位移场连续无缝（否则融合带上会出现折痕/鼓包）
    wsum = sum(b[3] ** 2 for b in BLOBS)
    centroid = Vector((sum(b[0] * b[3] ** 2 for b in BLOBS) / wsum,
                       sum(b[1] * b[3] ** 2 for b in BLOBS) / wsum,
                       sum(b[2] * b[3] ** 2 for b in BLOBS) / wsum))
    for v in bm.verts:
        n1 = nz3(v.co.x * 1.6 + 4.2, v.co.y * 1.6 + 1.1, v.co.z * 1.6 + 9.7)
        n2 = nz3(v.co.x * 6.0 + 9.7, v.co.y * 6.0 + 4.2, v.co.z * 6.0 + 1.1)
        amp = 1.0 + CANOPY_NOISE * n1 + 0.014 * n2
        v.co = centroid + (v.co - centroid) * amp
        h = smoothstep((v.co.z - CROWN_Z0) / (CROWN_Z1 - CROWN_Z0))
        col = mix3(C_GREEN_DEEP, C_GREEN_LT, h)
        m = 1.0 + 0.04 * nz3(v.co.x * 3.5, v.co.y * 3.5, v.co.z * 3.5)
        m *= 1.0 - 0.15 * (1.0 - h)          # 底部压暗
        colors.append((col[0] * m, col[1] * m, col[2] * m))
    bm.to_mesh(me)
    bm.free()
    apply_colors(me, colors)
    return me

# ---------------------------------------------------------------- 苹果（共享组件） ----
def build_apple(rng):
    bm = bmesh.new()
    colors = []
    before = len(bm.verts)
    bmesh.ops.create_uvsphere(bm, u_segments=26, v_segments=20, radius=APPLE_R)
    bm.verts.ensure_lookup_table()
    for idx in range(before, len(bm.verts)):
        v = bm.verts[idx]
        ny = v.co.z / APPLE_R                                   # -1..1
        k_top = max(0.0, (ny - 0.55) / 0.45)
        k_bot = max(0.0, (-ny - 0.70) / 0.30)
        prof = (1.0 + 0.10 * sin(pi * (ny + 1.0) / 2.0))        # 中段微鼓
        prof *= 1.0 - 0.28 * max(0.0, (abs(ny) - 0.62) / 0.38) ** 1.5
        v.co.x *= prof
        v.co.y *= prof
        v.co.z = v.co.z * 0.94 - 0.10 * k_top * k_top * APPLE_R + 0.045 * k_bot * k_bot * APPLE_R
        # 顶点色：主体红、向光顶橙黄、底部暗红、侧面淡条纹
        col = mix3(C_APPLE_RED, C_APPLE_SUN, smoothstep((ny - 0.25) / 0.75))
        dk = 1.0 - 0.22 * max(0.0, -ny)
        stripe = 1.0
        if abs(ny) < 0.6:
            stripe += 0.06 * 0.5 * (1.0 + sin(6.0 * atan2(v.co.y, v.co.x)
                                               + nz3(v.co.x * 20.0, v.co.y * 20.0, 0.0) * 3.0))
        colors.append((col[0] * dk * stripe, col[1] * dk * stripe, col[2] * dk * stripe))
    # 果柄
    before = len(bm.verts)
    stem_m = (Matrix.Translation((0.0, 0.0, APPLE_R * 0.78))
              @ Matrix.Rotation(radians(9.0), 4, 'X'))
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=7,
                          radius1=0.0045, radius2=0.008, depth=0.055, matrix=stem_m)
    for idx in range(before, len(bm.verts)):
        colors.append(C_STEM_BROWN)
    # 一片苹果叶：接在柄旁，外倾下垂
    def leaf_col(t, u):
        return mix3(C_LEAF_DK, C_LEAF_LT, t * t * (3.0 - 2.0 * t))
    leaf_m = (Matrix.Translation((0.004, 0.0, APPLE_R * 0.84))
              @ Matrix.Rotation(radians(140.0), 4, 'Z')
              @ Matrix.Rotation(radians(48.0), 4, 'X'))
    add_strip(bm, 5, 8, 0.065, 0.017, 34, 0.8, 0.05, leaf_col,
              matrix=leaf_m, colors=colors)
    me = bpy.data.meshes.new("AppleTreeApple")
    bm.to_mesh(me)
    bm.free()
    apply_colors(me, colors)
    return me

# ---------------------------------------------------------------- 草丘与草 ----
def build_mound(rng):
    bm = bmesh.new()
    colors = []
    before = len(bm.verts)
    r = 0.72
    bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=20, radius=r,
                              matrix=Matrix.Translation((0.0, 0.0, 0.0)))
    bm.verts.ensure_lookup_table()
    for idx in range(before, len(bm.verts)):
        v = bm.verts[idx]
        v.co.z *= 0.42                                          # 压成缓坡草丘
        az = atan2(v.co.y, v.co.x)
        rr = (v.co.x * v.co.x + v.co.y * v.co.y) ** 0.5
        edge = 1.0 + 0.12 * nz3(cos(az) * 2.4, sin(az) * 2.4, 3.0, 1.0)
        k = min(1.0, rr / r)
        v.co.x *= 1.0 + 0.08 * (1.0 - k) * nz3(v.co.x * 3.0, v.co.y * 3.0, 1.0)  # 丘面起伏
        v.co.y *= 1.0 + 0.08 * (1.0 - k) * nz3(v.co.x * 3.0, v.co.y * 3.0, 5.0)
        if rr > 0.3 * r:
            sc = 1.0 + (edge - 1.0) * smoothstep((rr - 0.3 * r) / (0.7 * r))
            v.co.x *= sc
            v.co.y *= sc
        col = mix3(C_MOUND_IN, C_MOUND_OUT, smoothstep(rr / r))
        colors.append(col)
    me = bpy.data.meshes.new("AppleTreeMound")
    bm.to_mesh(me)
    bm.free()
    apply_colors(me, colors)
    return me

def build_grass(rng):
    bm = bmesh.new()
    colors = []

    def grass_col(t, u):
        return mix3((0.10, 0.32, 0.08), (0.42, 0.68, 0.22), t)

    for ci in range(12):                      # 12 簇绕根部
        az = ci * 2 * pi / 12 + rng.uniform(-0.25, 0.25)
        rad = rng.uniform(0.34, 0.60)
        n_leaf = rng.randint(4, 6)
        for li in range(n_leaf):
            la = az + rng.uniform(-0.5, 0.5)
            px, py = cos(la) * rad, sin(la) * rad
            pz = 0.42 * max(0.0, 0.72 ** 2 - rad ** 2) ** 0.5 - 0.01   # 丘面高度
            M = (Matrix.Translation((px, py, pz))
                 @ Matrix.Rotation(radians(la * 57.3 + rng.uniform(-20, 20)), 4, 'Z')
                 @ Matrix.Rotation(radians(rng.uniform(45, 72)), 4, 'X'))
            L = rng.uniform(0.10, 0.19)
            add_strip(bm, 4, 6, L, L * 0.085, rng.uniform(26, 44), 0.5, 0.12,
                      grass_col, matrix=M, colors=colors, hw_power=1.1)
    me = bpy.data.meshes.new("AppleTreeGrass")
    bm.to_mesh(me)
    bm.free()
    apply_colors(me, colors)
    return me

# ---------------------------------------------------------------- 灯光/环境/相机 ----
def setup_env():
    # 太阳 + 追踪目标（幂等）
    focus = bpy.data.objects.get("AppleTreeFocus")
    if focus is None:
        focus = bpy.data.objects.new("AppleTreeFocus", None)
        bpy.context.scene.collection.objects.link(focus)
    focus.location = (0.0, 0.05, 1.30)
    focus.hide_render = True

    sun_ob = bpy.data.objects.get("AppleTreeSun")
    if sun_ob is None:
        light = bpy.data.lights.new("AppleTreeSun", 'SUN')
        sun_ob = bpy.data.objects.new("AppleTreeSun", light)
        bpy.context.scene.collection.objects.link(sun_ob)
    sun_ob.data.energy = 3.6
    sun_ob.data.color = (1.0, 0.95, 0.87)
    sun_ob.data.angle = radians(1.5)
    sun_ob.location = (4.2, -4.6, 5.4)
    if not any(c.type == 'TRACK_TO' for c in sun_ob.constraints):
        c = sun_ob.constraints.new('TRACK_TO')
        c.target = focus
        c.track_axis = 'TRACK_NEGATIVE_Z'
        c.up_axis = 'UP_Y'

    world = bpy.context.scene.world
    if world is None:
        world = bpy.data.worlds.new("World")
        bpy.context.scene.world = world
    world.use_nodes = True
    bg = node_by_type(world.node_tree, 'BACKGROUND')
    bg.inputs["Color"].default_value = (0.42, 0.58, 0.85, 1.0)
    bg.inputs["Strength"].default_value = 0.7

    # 预览地面
    gnd = bpy.data.objects.get("PreviewGround")
    if gnd is None:
        me = bpy.data.meshes.new("PreviewGround")
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=8.0)
        bm.to_mesh(me)
        bm.free()
        gnd = bpy.data.objects.new("PreviewGround", me)
        bpy.context.scene.collection.objects.link(gnd)
        mat = bpy.data.materials.new("PreviewGroundM")
        mat.use_nodes = True
        bsdf = node_by_type(mat.node_tree, 'BSDF_PRINCIPLED')
        bsdf.inputs["Base Color"].default_value = (0.40, 0.52, 0.28, 1.0)
        set_in(bsdf, ("Roughness",), 1.0)
        me.materials.append(mat)

    # 相机对准树
    cam = bpy.data.objects.get("Camera")
    if cam is not None:
        cam.location = (3.0, -2.85, 1.58)
        cam.data.lens = 48
        if not any(c.type == 'TRACK_TO' for c in cam.constraints):
            c = cam.constraints.new('TRACK_TO')
            c.target = focus
            c.track_axis = 'TRACK_NEGATIVE_Z'
            c.up_axis = 'UP_Y'
        bpy.context.scene.camera = cam
        bpy.context.scene.render.resolution_x = 1600
        bpy.context.scene.render.resolution_y = 1920

    # 清掉默认 Cube / 默认点光（仅当还是未改动的默认件）
    cube = bpy.data.objects.get("Cube")
    if cube is not None and len(cube.data.polygons) == 6:
        bpy.data.objects.remove(cube, do_unlink=True)
    lite = bpy.data.objects.get("Light")
    if lite is not None and lite.data.type == 'POINT':
        bpy.data.objects.remove(lite, do_unlink=True)

# ---------------------------------------------------------------- 主流程 ----
def main():
    purge()
    rng = random.Random(42)

    mats = {
        "trunk":  make_vc_material("AppleTreeBark", rough=0.85),
        "canopy": make_vc_material("AppleTreeCanopyM", rough=0.65, sss=0.06),
        "apple":  make_vc_material("AppleTreeFruit", rough=0.18, coat=0.7, spec=0.7),
        "mound":  make_vc_material("AppleTreeMoundM", rough=0.9),
        "grass":  make_vc_material("AppleTreeGrassM", rough=0.75),
    }

    coll = bpy.data.collections.get("AppleTree")
    if coll is None:
        coll = bpy.data.collections.new("AppleTree")
        bpy.context.scene.collection.children.link(coll)

    def add_ob(name, me, mat_key, subsurf=0, render_levels=None):
        me.materials.append(mats[mat_key])
        ob = bpy.data.objects.new(name, me)
        coll.objects.link(ob)
        shade_smooth(ob, subsurf, render_levels)
        return ob

    add_ob("AppleTreeTrunk", build_trunk(rng), "trunk", subsurf=1)
    canopy_ob = add_ob("AppleTreeCanopy", build_canopy(rng), "canopy", subsurf=1, render_levels=2)
    mound_ob = add_ob("AppleTreeMound", build_mound(rng), "mound", subsurf=1)

    apple_me = build_apple(rng)
    apple_me.materials.append(mats["apple"])
    for p in apple_me.polygons:
        p.use_smooth = True

    def app_instance(name):
        ob = bpy.data.objects.new(name, apple_me)
        coll.objects.link(ob)
        sub = ob.modifiers.new("Subsurf", 'SUBSURF')
        sub.levels = 1
        sub.render_levels = 2
        return ob

    for i, (bi, az, elev, s) in enumerate(APPLES_HANG):
        cx, cy, cz, r, _ = BLOBS[bi]
        d = Vector((cos(radians(az)) * cos(radians(elev)),
                    sin(radians(az)) * cos(radians(elev)),
                    sin(radians(elev)))).normalized()
        ob = app_instance("Apple_%02d" % i)
        # 射线从球簇中心向外找树冠真实表面（含噪声起伏），命中后外推 ~45% 果径
        ok, loc, _n, _idx = canopy_ob.ray_cast(Vector((cx, cy, cz)), d)
        s *= rng.uniform(0.94, 1.06)
        if ok:
            ob.location = loc + d * (APPLE_R * s * 0.45)
        else:
            ob.location = Vector((cx, cy, cz)) + d * (r * 0.95)
        q = Vector((0.0, 0.0, 1.0)).rotation_difference(-d)      # 果顶朝冠心
        q = q @ Quaternion((0.0, 0.0, 1.0), radians(rng.uniform(0, 360)))
        ob.rotation_mode = 'QUATERNION'
        ob.rotation_quaternion = q
        ob.scale = (s, s, s)

    for i, (px, py, rot, s) in enumerate(APPLES_GROUND):
        ob = app_instance("Apple_Ground_%d" % i)
        # 从高处垂直向下投射，落到草丘或地面上
        ok, loc, _n, _idx = mound_ob.ray_cast(Vector((px, py, 2.0)), Vector((0.0, 0.0, -1.0)))
        z = loc.z if ok else 0.0
        ob.location = (px, py, z + APPLE_R * s * 0.80)
        ob.rotation_euler = Euler((radians(rot[0]), radians(rot[1]), radians(rot[2])))
        ob.scale = (s, s, s)

    add_ob("AppleTreeGrass", build_grass(rng), "grass")

    setup_env()

    total_v = sum(len(o.data.vertices) for o in coll.objects if o.type == 'MESH')
    total_f = sum(len(o.data.polygons) for o in coll.objects if o.type == 'MESH')
    print("AppleTree done: objects=%d verts=%d faces=%d"
          % (len(coll.objects), total_v, total_f))


main()
