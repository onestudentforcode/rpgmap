"""Pure render-cache utilities and reversible, organ-specific Blender overrides.

Geometry layouts are pinned to the approved plant builder helpers: a closed leaf
has ten vertices per station, a tube has one ring per station, and each resin
needle has five four-vertex rings followed by its tip. Unexpected layouts fail
closed instead of deforming a different organ. No source .blend is saved.
"""
import hashlib
import json
import math
import re
from pathlib import Path


PARAMETERS = {
    'height_scale', 'leaf_width_scale', 'leaf_thickness_scale',
    'stem_radius_scale', 'needle_width_scale', 'leaf_fan_xy_scale', 'colony_xy_scale',
}
SUPPORTED_PLANTS = {'golden_wheat', 'pasture_grass', 'resin_tree', 'fast_fir',
                    'oilseed_flower', 'honeybell_bush', 'wood_decay_mushroom'}


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def fingerprint(value):
    payload = json.dumps(value, sort_keys=True, separators=(',', ':'),
                         ensure_ascii=False, allow_nan=False).encode('utf-8')
    return hashlib.sha256(payload).hexdigest()


def selection(values):
    """Accept both comma-separated and space-separated CLI lists."""
    return {part.strip() for value in values or [] for part in value.split(',')
            if part.strip()}


def load_recipe(path):
    if path is None:
        return {'schema_version': 1, 'plants': {}}
    recipe = json.loads(Path(path).read_text(encoding='utf-8'))
    if recipe.get('schema_version') != 1 or not isinstance(recipe.get('plants'), dict):
        raise ValueError('recipe requires schema_version=1 and a plants mapping')
    for ident, stages in recipe['plants'].items():
        if ident not in SUPPORTED_PLANTS or not isinstance(stages, dict):
            raise ValueError(f'unsupported seedling recipe plant: {ident}')
        for state, parameters in stages.items():
            if state not in {'stage_0', 'stage_1'} or not isinstance(parameters, dict):
                raise ValueError(f'{ident}/{state}: only seedling stages 0/1 are supported')
            if set(parameters) - PARAMETERS:
                raise ValueError(f'{ident}/{state}: unknown recipe parameters')
            for name, value in parameters.items():
                if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or not 0 < value <= 4:
                    raise ValueError(f'{ident}/{state}/{name}: expected a finite scale in (0,4]')
            invalid = ({'leaf_width_scale', 'leaf_thickness_scale', 'leaf_fan_xy_scale'} if ident in {'resin_tree','fast_fir'}
                       else {'needle_width_scale'}) & set(parameters)
            if ident != 'wood_decay_mushroom' and 'colony_xy_scale' in parameters:
                invalid.add('colony_xy_scale')
            if invalid:
                raise ValueError(f'{ident}/{state}: unsupported organ parameters {sorted(invalid)}')
    return recipe


def can_resume(record, digest, recipe_fingerprint, size, destination):
    """Old records without a complete recipe fingerprint deliberately miss."""
    return bool(record and record.get('source_blend_sha256') == digest
                and record.get('recipe_fingerprint') == recipe_fingerprint
                and record.get('canvas_px') == size and destination.is_file()
                and record.get('sha256') == sha256(destination))


def _mean(points):
    return tuple(sum(point[axis] for point in points) / len(points) for axis in range(3))


def widen_rings(points, ring_size, factor):
    """Increase cross sections around their centerlines, preserving attachments."""
    if len(points) < ring_size * 2 or len(points) % ring_size:
        raise ValueError(f'unexpected tube layout: {len(points)} vertices / {ring_size}')
    result = []
    for offset in range(0, len(points), ring_size):
        ring = points[offset:offset + ring_size]
        center = _mean(ring)
        result.extend(tuple(center[a] + (point[a] - center[a]) * factor for a in range(3))
                      for point in ring)
    return result


def widen_leaf(points, width_scale, thickness_scale):
    if len(points) < 20 or len(points) % 10:
        raise ValueError(f'unexpected leaf layout: {len(points)} vertices')
    result = []
    for offset in range(0, len(points), 10):
        ring = points[offset:offset + 10]
        center = _mean([ring[0], ring[4], ring[5], ring[9]])
        pairs = [_mean([ring[q], ring[q + 5]]) for q in range(5)]
        for q, point in enumerate(ring):
            pair = pairs[q % 5]
            result.append(tuple(center[a] + (pair[a] - center[a]) * width_scale
                                + (point[a] - pair[a]) * thickness_scale for a in range(3)))
    return result


def widen_needles(points, factor):
    if not points or len(points) % 21:
        raise ValueError(f'unexpected resin needle layout: {len(points)} vertices')
    result = []
    for offset in range(0, len(points), 21):
        result.extend(widen_rings(points[offset:offset + 20], 4, factor))
        result.append(tuple(points[offset + 20]))  # Do not move the pointed tip.
    return result


def spread_leaf_centerline_xy(points, factor):
    """Open the leaf path around its first attachment without scaling sections.

    Each source station's edge midpoint is its path center. Move that center in
    XY relative to the first station, preserving the cross section, attachment
    and Z coordinates. The paired midrib is rebuilt from these same stations.
    """
    if len(points) < 20 or len(points) % 10:
        raise ValueError(f'unexpected leaf layout: {len(points)} vertices')
    attachment = _mean([points[index] for index in (0, 4, 5, 9)])
    result = []
    for offset in range(0, len(points), 10):
        ring = points[offset:offset + 10]
        center = _mean([ring[index] for index in (0, 4, 5, 9)])
        delta = [(center[axis] - attachment[axis]) * (factor - 1) for axis in range(2)]
        result.extend((point[0] + delta[0], point[1] + delta[1], point[2]) for point in ring)
    return result


def _write_vertices(obj, points):
    if len(points) != len(obj.data.vertices):
        raise ValueError(f'{obj.name}: vertex count changed')
    for vertex, point in zip(obj.data.vertices, points):
        vertex.co = point
    obj.data.update()


def apply_geometry_recipe(scene, ident, state, parameters):
    """Modify only copied organ data in the currently opened Blender scene."""
    if not parameters:
        return {'parameters': {}, 'modified_organs': []}
    if ident not in SUPPORTED_PLANTS or state not in {'stage_0', 'stage_1'}:
        raise ValueError(f'{ident}/{state}: geometry overrides are not supported')
    stage = int(state[-1])
    prefix = f'RF_S{stage}_' if ident == 'resin_tree' else f'PG_{ident}_S{stage}_'
    organs = [obj for obj in scene.objects if obj.name.startswith(prefix)
              and obj.type in {'MESH', 'CURVE'}]
    if not organs:
        raise ValueError(f'{ident}/{state}: no expected juvenile organs')
    # Copy data blocks before edits, including any shared curve/mesh data.
    for obj in organs:
        obj.data = obj.data.copy()
    modified = set()
    width = parameters.get('leaf_width_scale', 1.0)
    thickness = parameters.get('leaf_thickness_scale', 1.0)
    fan = parameters.get('leaf_fan_xy_scale', 1.0)
    radius = parameters.get('stem_radius_scale', 1.0)
    needle_width = parameters.get('needle_width_scale', 1.0)
    expected = {'leaf': 0, 'stem': 0, 'needle': 0}
    for obj in organs:
        if obj.type != 'MESH':
            continue
        name = obj.name[len(prefix):]
        points = [tuple(vertex.co) for vertex in obj.data.vertices]
        if re.fullmatch(r'(GrassLeaf\d+_\d+|NewSpear\d+|ErectBlade\d+_\d+|CentralSpear\d+|Cotyledon\d+|ShovelLeaf\d+|FirstLeaf-?\d+|PairedLeaf\d+_\d+_-?\d+)', name):
            expected['leaf'] += 1
            points = widen_leaf(points, width, thickness)
            if fan != 1.0:
                points = spread_leaf_centerline_xy(points, fan)
            _write_vertices(obj, points)
            # The source midrib follows the folded upper center of each leaf.
            midrib = next((item for item in organs if item.name == obj.name + '_Midrib'), None)
            if midrib is not None:
                bezier = midrib.data.splines[0].bezier_points
                if len(bezier) != len(points) // 10:
                    raise ValueError(f'{midrib.name}: leaf/midrib stations differ')
                for i, point in enumerate(bezier):
                    upper, lower = points[i * 10 + 2], points[i * 10 + 7]
                    delta = [upper[a] - lower[a] for a in range(3)]
                    length = math.sqrt(sum(value * value for value in delta))
                    point.co = tuple(upper[a] + (delta[a] / length if length else 0) * .002 for a in range(3))
                    point.handle_left_type = point.handle_right_type = 'AUTO'
                modified.add(midrib.name)
            modified.add(obj.name)
        elif ident in {'resin_tree','fast_fir'} and re.fullmatch(r'(NeedleBud|ApicalNeedleBud|NeedleBrush_\d+)', name):
            expected['needle'] += 1
            _write_vertices(obj, widen_needles(points, needle_width))
            modified.add(obj.name)
        else:
            ring_size = None
            if ident == 'golden_wheat' and re.fullmatch(r'JuvenileCulm\d+', name):
                ring_size = 10
            elif ident == 'pasture_grass':
                if name == 'DenseYoungCrown': ring_size = 14
                elif re.fullmatch(r'ShortTiller\d+', name): ring_size = 10
                elif re.fullmatch(r'WrappedSheath\d+', name): ring_size = 12
            elif ident == 'resin_tree':
                if name == 'Trunk': ring_size = 48
                elif re.fullmatch(r'(Root\d+|ElbowBranch\d+)', name): ring_size = 12 if name.startswith('Root') else 16
                elif re.fullmatch(r'Twig\d+_\d+', name): ring_size = 8
            elif ident == 'fast_fir':
                if name == 'YoungCrookedSpine': ring_size = 14
                elif name.startswith(('Buttress','WhorlBranch')): ring_size = 10
                elif name.startswith('NeedleTwig'): ring_size = 6
            elif ident == 'oilseed_flower' and name == 'YoungBentStem': ring_size = 12
            elif ident == 'honeybell_bush':
                if name == 'SeedlingStem' or name == 'YoungRoot': ring_size = 10
                elif name.startswith('JuvenileBranch'): ring_size = 12
            elif ident == 'wood_decay_mushroom' and name.startswith('PrimordiumStipe'): ring_size = 12
            if ring_size:
                expected['stem'] += 1
                points = widen_rings(points, ring_size, radius)
                # The ground-clamped first ring must never sink after thickening.
                points = [(x, y, max(.003, z)) for x, y, z in points]
                _write_vertices(obj, points)
                modified.add(obj.name)
    if ident != 'wood_decay_mushroom' and (expected['stem'] == 0 or expected['needle' if ident in {'resin_tree','fast_fir'} else 'leaf'] == 0):
        raise ValueError(f'{ident}/{state}: expected organ selectors did not match: {expected}')
    height = parameters.get('height_scale', 1.0)
    colony = parameters.get('colony_xy_scale',1.0)
    for obj in organs:
        if obj.type == 'MESH':
            for vertex in obj.data.vertices:
                vertex.co.z *= height
                vertex.co.x *= colony
                vertex.co.y *= colony
            obj.data.update()
        else:
            for spline in obj.data.splines:
                if spline.type != 'BEZIER':
                    raise ValueError(f'{obj.name}: unsupported non-Bezier organ curve')
                for point in spline.bezier_points:
                    point.co.z *= height
                    point.handle_left.z *= height
                    point.handle_right.z *= height
                    for coord in (point.co,point.handle_left,point.handle_right):
                        coord.x *= colony
                        coord.y *= colony
            if ident == 'wood_decay_mushroom': obj.data.bevel_depth *= radius
        modified.add(obj.name)
    scene.view_layers[0].update()
    return {'parameters': parameters, 'modified_organs': sorted(modified), 'organ_counts': expected}
