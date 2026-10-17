"""Meaningful cache-invalidations, subset compatibility and organ-layout checks."""
import copy
import json
import math
import tempfile
import unittest
from pathlib import Path

from p85_render_support import (can_resume, fingerprint, load_recipe, selection,
                                sha256, spread_leaf_centerline_xy, widen_leaf,
                                widen_needles, widen_rings)
from render_p85_runtime import ROOT, arguments, build_jobs


class RenderSupportTests(unittest.TestCase):
    def test_legacy_arguments_and_sample_selection(self):
        args = arguments(['--source', 'source', '--sample', '--resume'])
        self.assertEqual(args.out, ROOT / '.art-work/p85-runtime')
        self.assertEqual(selection(['wheat,grass', 'tree']), {'wheat', 'grass', 'tree'})
        handoff = {'assets': [{'id': ident, 'canvas_small_px': size}
                             for ident, size in [('golden_wheat', [64, 64]),
                                                 ('pasture_grass', [64, 64]),
                                                 ('resin_tree', [128, 192])]]}
        # Only base-size lookups for selected jobs are needed by the builder.
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder)
            (source / 'UPSTREAM_PLANT_ASSETS.json').write_text(json.dumps(handoff), encoding='utf-8')
            jobs = build_jobs(source, set(), set(), sample=True)
            self.assertEqual([(job['id'], job['state']) for job in jobs],
                             [('golden_wheat', 'stage_3'), ('woodshop', 'body')])
            jobs = build_jobs(source, {'golden_wheat', 'resin_tree'}, {'stage_0', 'stage_1'})
            self.assertEqual(len(jobs), 4)
            self.assertTrue(all(job['size'] == ([512, 768] if job['id'] == 'resin_tree' else [256, 256]) for job in jobs))
            with self.assertRaises(ValueError): build_jobs(source, {'no_such_id'}, set())
            with self.assertRaises(ValueError): build_jobs(source, {'woodshop'}, {'stage_0'})

    def test_resume_requires_complete_recipe_and_intact_output(self):
        signature = {'source': 'sourcehash', 'camera': {'ortho': 3.6}, 'samples': 128,
                     'scripts': {'driver': 'v1'}, 'geometry': {'leaf_width_scale': 1.5}}
        with tempfile.TemporaryDirectory() as folder:
            png = Path(folder) / 'sample.png'
            png.write_bytes(b'original png bytes')
            key = fingerprint(signature)
            record = {'source_blend_sha256': 'sourcehash', 'recipe_fingerprint': key,
                      'canvas_px': [256, 256], 'sha256': sha256(png)}
            self.assertTrue(can_resume(record, 'sourcehash', key, [256, 256], png))
            for field, changed in [('samples', 64), ('camera', {'ortho': 4.0}),
                                   ('scripts', {'driver': 'v2'}), ('geometry', {'leaf_width_scale': 2.0})]:
                variant = copy.deepcopy(signature)
                variant[field] = changed
                self.assertFalse(can_resume(record, 'sourcehash', fingerprint(variant), [256, 256], png))
            self.assertFalse(can_resume(record, 'changed-source', key, [256, 256], png))
            self.assertFalse(can_resume({k: v for k, v in record.items() if k != 'recipe_fingerprint'}, 'sourcehash', key, [256, 256], png))
            png.write_bytes(b'corrupt')
            self.assertFalse(can_resume(record, 'sourcehash', key, [256, 256], png))
            self.assertEqual(fingerprint({'b': 2, 'a': 1}), fingerprint({'a': 1, 'b': 2}))

    def test_recipe_rejects_unsafe_or_irrelevant_scales(self):
        recipe = load_recipe(ROOT / 'content/farming/p8/seedling_recipe.json')
        self.assertEqual(set(recipe['plants']), {'golden_wheat', 'pasture_grass', 'resin_tree'})
        release = load_recipe(ROOT / 'content/farming/p8/seedling_release_recipe.json')
        self.assertEqual(len(release['plants']),7)
        self.assertEqual(release['plants']['golden_wheat'],recipe['plants']['golden_wheat'])
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'recipe.json'
            for parameters in ({'height_scale': 0}, {'height_scale': True},
                               {'height_scale': math.nan}, {'opacity': .8}, {'needle_width_scale': 2}):
                path.write_text(json.dumps({'schema_version': 1, 'plants': {
                    'golden_wheat': {'stage_0': parameters}}}), encoding='utf-8')
                with self.assertRaises(ValueError): load_recipe(path)

    def test_organ_cross_sections_preserve_centerlines_and_tips(self):
        rings = [(x, y, z) for z in (0, 1) for x, y in ((1, 0), (0, 1), (-1, 0), (0, -1))]
        wide = widen_rings(rings, 4, 2)
        self.assertEqual(wide[0], (2, 0, 0))
        self.assertEqual(wide[4], (2, 0, 1))
        with self.assertRaises(ValueError): widen_rings(rings[:-1], 4, 2)
        needles = rings[:4] * 5 + [(0, 0, 4)]
        self.assertEqual(widen_needles(needles, 2)[-1], (0, 0, 4))
        with self.assertRaises(ValueError): widen_needles(needles[:-1], 2)
        leaf = [(q, (1 - abs(q)) * .3 + level * .05, z)
                for z in (0, 1) for level in (1, -1) for q in (-1, -.5, 0, .5, 1)]
        widened = widen_leaf(leaf, 2, 1.5)
        self.assertEqual(widened[0], (-2, .07500000000000001, 0))
        self.assertAlmostEqual((widened[2][1] + widened[7][1]) / 2, .6)
        self.assertAlmostEqual(widened[2][1] - widened[7][1], .15)
        self.assertEqual(widened[10][2], 1)
        with self.assertRaises(ValueError): widen_leaf(leaf[:-1], 2, 1)

    def test_leaf_fan_moves_path_and_midrib_station_not_cross_section(self):
        leaf = [(center_x + q, center_y + (1 - abs(q)) * .3 + level * .05, z)
                for center_x, center_y, z in ((2, 3, 0), (3, 5, 1))
                for level in (1, -1) for q in (-1, -.5, 0, .5, 1)]
        expanded = spread_leaf_centerline_xy(leaf, 4)
        self.assertEqual(expanded[:10], leaf[:10])  # Attachment ring is fixed.
        for before, after in zip(leaf[10:], expanded[10:]):
            self.assertAlmostEqual(after[0] - before[0], 3)
            self.assertAlmostEqual(after[1] - before[1], 6)
            self.assertEqual(after[2], before[2])
        # Upper center is exactly the new midrib station; section width is fixed.
        self.assertAlmostEqual(expanded[12][0], 6)
        self.assertAlmostEqual(expanded[12][1], 11.35)
        self.assertEqual(expanded[14][0] - expanded[10][0], 2)
        with self.assertRaises(ValueError): spread_leaf_centerline_xy(leaf[:-1], 4)


if __name__ == '__main__':
    unittest.main()
