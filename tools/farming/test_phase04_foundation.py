"""Phase 4 schema/canvas contract tests; no production image generation."""
import copy
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from PIL import Image, ImageDraw
from asset_common import ROOT
from bake_farm import validate_crops, validate_config
from gen_asset_manifest import build_manifest
from gen_farm_crops import outputs_for, _draw_crop
from build_art_handoff import build
from postprocess_assets import process
from qc_assets import check_image


class Phase04Tests(unittest.TestCase):
    def setUp(self):
        self.crop = json.loads((ROOT/'content/farming/crops.json').read_text(encoding='utf-8'))['crops'][1]
        self.crop.update(crop_id='test_tree',category='tree',footprint=[2,2],sprite_size=[128,192])
        self.ids = {e['item_id'] for e in self.crop['harvest_items']}

    def validate(self, crop):
        errors=[]
        validate_crops({'schema':1,'crops':[crop]},self.ids,errors,{'soil','fungal_bed','rotten_log'})
        return errors

    def test_categories_medium_and_canvas_contract(self):
        self.assertEqual(self.validate(self.crop),[])
        for changes in ({'sprite_size':[100,192]},{'planting_medium':'unknown'},{'category':'unknown'}):
            self.assertTrue(self.validate(dict(self.crop,**changes)))
        fungus=dict(self.crop,category='fungus',footprint=[1,1],sprite_size=[64,64],planting_medium='fungal_bed')
        self.assertEqual(self.validate(fungus),[])

    def test_medium_registry_validation(self):
        config=json.loads((ROOT/'content/farming/config.json').read_text(encoding='utf-8'))
        items=set(config['start_inventory'])
        for media in ([],[{'id':'fungal_bed','name':'bed'}],[{'id':'soil','name':'soil'},{'id':'soil','name':'duplicate'}],None):
            errors=[]
            validate_config(dict(config,planting_media=media),items,errors)
            self.assertTrue(errors)

    def test_large_rectangular_postprocess_and_qc(self):
        source=Image.new('RGBA',(256,384))
        ImageDraw.Draw(source).rectangle((64,120,191,379),fill=(78,123,78,255))
        output=process(source,'crop_stage',target_size=(128,192))
        self.assertEqual(output.size,(128,192))
        self.assertEqual(output.getchannel('A').getbbox(),(32,60,96,190))
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'stage_3.png';output.save(path)
            self.assertEqual(check_image(path,{'type':'crop_stage','size':[128,192],'stage':'mature'}),([],[]))
        with self.assertRaises(ValueError):
            process(Image.new('RGBA',(256,256)),'crop_stage',target_size=(128,192))
        with self.assertRaises(ValueError):
            process(Image.new('RGBA',(256,384)),'crop_stage',target_size=(128,192))

    def test_manifest_size_and_stage_names_come_from_data(self):
        def source(name):
            return {'terrains':[]} if name=='terrains.json' else {'crops':[self.crop]}
        with patch('gen_asset_manifest._load',side_effect=source):
            entries=[e for e in build_manifest()['assets'] if e['type']=='crop_stage']
        self.assertEqual(len(entries),6)
        self.assertTrue(all(e['size']==[128,192] and e['constraints'][0].startswith('128×192') for e in entries))
        crop=copy.deepcopy(self.crop)
        crop['growth_stages'][1]['sprite']='stage_5'
        self.assertIn(('stage_5',1),outputs_for(crop))

    def test_tree_and_fungus_placeholder_stages(self):
        crops=json.loads((ROOT/'content/farming/baked/crops.json').read_text(encoding='utf-8'))['crops']
        with tempfile.TemporaryDirectory() as temp:
            for crop in crops:
                if crop['crop_id'] not in ('jade_fruit_tree','moon_cap'):
                    continue
                heights=[]
                for name,kind in outputs_for(crop):
                    image=_draw_crop(crop['crop_id'],kind)
                    path=Path(temp)/name;image.save(path,format='PNG')
                    errors,warnings=check_image(path,{'type':'crop_stage','size':crop['sprite_size'],
                                                     'stage':'mature' if kind==3 else name})
                    self.assertEqual((errors,warnings),([],[]))
                    if isinstance(kind,int):
                        box=image.getchannel('A').getbbox();heights.append(box[3]-box[1])
                self.assertEqual(heights,sorted(set(heights)))
            self.assertNotEqual(_draw_crop('jade_fruit_tree',3).tobytes(),
                                _draw_crop('jade_fruit_tree','harvested').tobytes())

    def test_new_art_prompts_have_canvas_identity_and_master_reference(self):
        with tempfile.TemporaryDirectory() as temp:
            package=Path(temp)/'tree'
            build('jade_fruit_tree',package)
            prompts=json.loads((package/'prompts.json').read_text(encoding='utf-8'))
            self.assertEqual(len(prompts),5)
            self.assertTrue(all('256x384' in p['prompt'] and 'twisted old trunk' in p['prompt'] for p in prompts))
            self.assertTrue(all(p['reference_required'].endswith('jade_fruit_tree/stage_3.png') for p in prompts))


if __name__=='__main__':
    unittest.main()
