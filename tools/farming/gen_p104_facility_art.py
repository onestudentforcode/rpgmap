"""Deterministic P10.4 placeholders in the existing 35-degree render pipeline.

The machine has a glass cabinet, suspended claw, balls and a control panel.
Ground contact is (128,158); transparent padding never changes placement.
"""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw
from gen_p103_facility_art import iso_block

ROOT = Path(__file__).resolve().parents[2]
SPECS = {
    'soothing_station': {'height': 60, 'top': '#d0ad74', 'side': '#886346'},
    'toy_station': {'height': 104, 'top': '#debd7d', 'side': '#947350'},
}


def render(ident, spec):
    im = Image.new('RGBA', (256, 256))
    d = ImageDraw.Draw(im)
    y = 158-spec['height']
    iso_block(d, 128, y, 59, 28, spec['height'], spec['top'], spec['side'])
    if ident == 'toy_station':
        # Left front face: opaque glass, interior toys, suspended claw.
        d.polygon([(77,65),(122,87),(122,149),(77,127)], fill='#a6c8bb', outline='#3a3128', width=3)
        d.line([(99,79),(99,103)], fill='#3a3128', width=3)
        d.line([(99,103),(90,109),(94,116)], fill='#3a3128', width=3)
        d.line([(99,103),(108,117),(104,121)], fill='#3a3128', width=3)
        for x, cy, color in [(86,123,'#b17b54'),(108,134,'#79966a'),(97,128,'#cfa776')]:
            d.ellipse((x-7,cy-6,x+7,cy+6), fill=color, outline='#3a3128', width=2)
        d.polygon([(130,91),(179,68),(179,132),(130,155)], fill='#8eb1a4', outline='#3a3128', width=3)
        d.line([(137,101),(171,84)], fill='#dbe4cf', width=4)
        d.polygon([(130,158),(179,135),(179,150),(130,173)], fill='#cba468', outline='#3a3128', width=2)
        d.ellipse((145,147,153,155), fill='#b95645', outline='#3a3128', width=2)
        d.line([(163,143),(171,139)], fill='#3a3128', width=3)
        d.polygon([(86,143),(113,156),(113,172),(86,159)], fill='#3a3128')
    else:
        # Two large speaker cones and a raised tuning crystal.
        for x, cy in [(96,131),(158,132)]:
            d.ellipse((x-17,cy-24,x+17,cy+24), fill='#483d33', outline='#d0ad74', width=3)
            d.ellipse((x-7,cy-12,x+7,cy+12), fill='#9c7857', outline='#302c27', width=2)
        d.polygon([(128,58),(141,77),(128,95),(115,77)], fill='#9bb893', outline='#3a3128', width=3)
        for x in [48,194]:
            d.arc((x,89,x+16,120), -65,65, fill='#84996b', width=3)
    return im


def main():
    directory=ROOT/'assets/farming/facilities'
    manifest_path=directory/'facility_manifest.json'
    ground_path=ROOT/'content/farming/p8/grounding.json'
    manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
    grounding=json.loads(ground_path.read_text(encoding='utf-8'))
    sheet=Image.new('RGBA',(512,288),'#ddd9c9')
    for index,(ident,spec) in enumerate(SPECS.items()):
        im=render(ident,spec)
        assert im.mode=='RGBA' and im.size==(256,256)
        assert set(im.getchannel('A').get_flattened_data())=={0,255}, 'hard transparent edges required'
        bbox=im.getbbox()
        assert bbox and min(bbox[:2])>0 and max(bbox[2:])<256
        path=directory/ident/'body.png'
        path.parent.mkdir(parents=True,exist_ok=True)
        im.save(path)
        manifest['facilities'][ident]={
            'footprint':[1,1], 'canvas_px':[256,256],
            'path':f'res://assets/farming/facilities/{ident}/body.png',
            'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            'anchor_uv':[0.5,158/256], 'draw_size':[122.0,122.0],
            'scale_multiplier':1.0, 'ground_placement':'footprint_center',
            'shadow':{'size':[58.0,22.0],'offset':[0,4],'opacity':0.18},
        }
        grounding['facilities'][ident]={'size':[58.0,22.0],'offset':[0,4]}
        sheet.alpha_composite(im,(index*256,0))
        ImageDraw.Draw(sheet).text((index*256+50,262),ident,fill='#302c27')
        print(f'P104 ART {ident}: RGBA256 hard-alpha bbox={bbox}')
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    ground_path.write_text(json.dumps(grounding,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    output=ROOT/'.art-work/p104-art'
    output.mkdir(parents=True,exist_ok=True)
    (output/'parameters.json').write_text(json.dumps(SPECS,indent=2)+'\n',encoding='utf-8')
    sheet.save(output/'contact.png')


if __name__=='__main__': main()
