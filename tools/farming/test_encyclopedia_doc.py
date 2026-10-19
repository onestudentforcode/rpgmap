# -*- coding: utf-8 -*-
"""P9.d full-manual verification (runs inside the tools unittest suite).

Checks the exported encyclopedia manual (docs/farming/demo-p8-百科全书.md)
against the same baked content layer and the live registries: every registered
entity has a section, every relation row appears in both directions, all rule
statements are present verbatim, and the tutorial handbook and the manual quote
the same current numbers. Fails on any drift between game data and documents.
"""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BAK = json.loads((ROOT / 'content/farming/baked/encyclopedia/encyclopedia.json').read_text(encoding='utf-8'))
SRC = json.loads((ROOT / 'content/farming/p8/production.json').read_text(encoding='utf-8'))
MANUAL = (ROOT / 'docs/farming/demo-p8-百科全书.md').read_text(encoding='utf-8')
TUTORIAL = (ROOT / 'docs/farming/demo-p8-新手手册.md').read_text(encoding='utf-8')


class EncyclopediaManual(unittest.TestCase):

    def test_layer_shape(self):
        self.assertEqual(BAK['encyclopedia_format'], 1)
        counts = BAK['counts']
        self.assertEqual(counts['resources'], 84)
        self.assertEqual(counts['crops'], 10)
        self.assertEqual(counts['facilities'], 39)
        self.assertEqual(counts['recipes'], 64)
        self.assertEqual(counts['livestock'], 17)
        self.assertEqual(counts['diets'], 49)
        self.assertEqual(counts['research'], 13)
        self.assertEqual(counts['parcels'], 6)
        self.assertEqual(counts['entities'], 316)
        self.assertEqual(counts['rules'], 19)

    def test_every_entity_has_a_section(self):
        missing = []
        for entity in BAK['entities']:
            heading = '### %s `%s`' % (entity['name'], entity['id'])
            if heading not in MANUAL:
                missing.append(entity['id'])
        self.assertEqual(missing, [], 'manual sections missing: %s' % missing)

    def test_registry_coverage_matches_layer(self):
        for section, kind in (('resources', 'resource'), ('crops', 'crop'), ('sources', 'source'),
                              ('facilities', 'facility'), ('recipes', 'recipe'),
                              ('livestock', 'species'), ('research', 'research')):
            registry_ids = {row['id'] for row in SRC[section]}
            layer_ids = {e['source_id'] for e in BAK['entities'] if e['kind'] == kind}
            self.assertEqual(registry_ids, layer_ids, '%s registry coverage drift' % section)

    def test_relation_sections_both_directions(self):
        resource_entities = [e for e in BAK['entities'] if e['kind'] == 'resource']
        for entity in resource_entities:
            section = self._section_of(entity['id'])
            for label, key in (('获取来源', 'sources'), ('直接用途', 'uses')):
                rows = entity.get(key, [])
                if not rows:
                    continue
                marker = '**%s（%d条）**' % (label, len(rows))
                self.assertIn(marker, section, '%s %s count marker' % (entity['id'], label))
                for row in rows:
                    self.assertIn('| %s |' % row['name'], section,
                                  '%s %s missing process %s' % (entity['id'], label, row['process']))
        # two-way: every batch recipe input/output row resolves to its item's section
        for recipe in SRC['recipes']:
            for item in list(recipe['inputs']) + list(recipe['outputs']):
                direction = '直接用途' if item in recipe['inputs'] else '获取来源'
                section = self._section_of('resource:' + item)
                self.assertIn('| 加工·', section, 'recipe rows missing on %s' % item)

    def test_rules_verbatim(self):
        for entity in BAK['entities']:
            if entity['kind'] != 'rule':
                continue
            section = self._section_of(entity['id'])
            for field in entity['fields']:
                if field['key'] == 'statements':
                    for line in field['text'].split('\n'):
                        self.assertIn(line, section, 'rule statement drift: %s' % entity['id'])

    def test_toc_anchors(self):
        toc = MANUAL[MANUAL.index('## 目录'):MANUAL.index('\n---\n')]
        anchors = re.findall(r'\]\(#([^)]+)\)', toc)
        self.assertEqual(len(anchors), len(BAK['entities']), 'TOC anchor count')

    def test_tutorial_and_manual_share_current_numbers(self):
        """The tutorial handbook and the manual must quote the same live values."""
        config = SRC['config']
        change = SRC['husbandry']['water']['change']
        change_inputs = sum(change['inputs'].values())
        shared = [
            ('初始元石', str(config['initial_primeval_stones'])),
            ('每日AP', str(config['ap_per_day'])),
            ('换水清水', '清水×%d' % change_inputs),
            ('换水污水', '污水×%d' % change['wastewater']),
        ]
        for label, needle in shared:
            self.assertIn(needle, MANUAL, 'manual missing %s (%s)' % (label, needle))
        self.assertIn('清水%d份' % change_inputs, TUTORIAL, 'tutorial water-change inputs')
        self.assertIn('污水%d份' % change['wastewater'], TUTORIAL, 'tutorial water-change output')
        self.assertIn(str(config['initial_primeval_stones']), TUTORIAL, 'tutorial initial stones')
        # stale-history guard: V1-era numbers must not appear as current facts
        for stale in ('初始60元石', '每人每日最多12次·设施专属'):
            self.assertNotIn(stale, MANUAL, 'manual leaks stale wording: %s' % stale)

    def test_no_unresolved_placeholders(self):
        for bad in ('TODO', 'FIXME', 'None', '按订单/库存×None', '实现依据'):
            self.assertNotIn(bad, MANUAL, 'manual contains placeholder %r' % bad)

    def _section_of(self, entity_id):
        entity = next(e for e in BAK['entities'] if e['id'] == entity_id)
        heading = '### %s `%s`' % (entity['name'], entity_id)
        start = MANUAL.index(heading)
        next_heading = MANUAL.find('\n### ', start + 1)
        end = next_heading if next_heading != -1 else len(MANUAL)
        return MANUAL[start:end]


if __name__ == '__main__':
    unittest.main()
