"""QC for the new vector UI, independent of the historical pixel art QC."""
import json
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'assets/farming/ui'

class UIAssetsTests(unittest.TestCase):
    def test_configured_ids_and_tools_are_covered(self):
        data = json.loads((ROOT/'content/farming/v1/production.json').read_text(encoding='utf-8'))
        manifest = json.loads((ART/'manifest.json').read_text(encoding='utf-8'))
        required = {x['id'] for section in ['resources','crops','facilities'] for x in data[section]}
        required |= {'wood','fire','earth','water','gold','inspect','till','plant','harvest','irrigate','fertilize','fell','clear','cancel','area'}
        self.assertTrue(required <= set(manifest['icons']))
        self.assertEqual(set(manifest['icons']), {p.stem for p in ART.glob('*.svg')})

    def test_svg_geometry_and_safe_local_content(self):
        for file in ART.glob('*.svg'):
            with self.subTest(icon=file.stem):
                source = file.read_text(encoding='utf-8')
                svg = ET.fromstring(source)
                self.assertEqual(svg.attrib['viewBox'], '0 0 64 64')
                self.assertEqual((svg.attrib['width'], svg.attrib['height']), ('64','64'))
                self.assertNotIn('<script', source)
                self.assertNotIn('href=', source)
                self.assertGreater(len(list(svg.iter())), 2)

    def test_high_frequency_tools_have_distinct_shapes(self):
        tools = ['inspect','till','plant','harvest','irrigate','fertilize','fell','clear','cancel','area']
        shapes = [ET.tostring(ET.parse(ART/f'{name}.svg').getroot()[0]) for name in tools]
        self.assertEqual(len(set(shapes)), len(tools))

if __name__ == '__main__': unittest.main()
