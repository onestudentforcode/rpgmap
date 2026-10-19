"""Additive QC; never rewrites the historical P8.7 visual baseline."""
import hashlib
import json
from pathlib import Path
from PIL import Image
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[2]


def check():
    manifest=json.loads((ROOT/'assets/farming/facilities/facility_manifest.json').read_text(encoding='utf-8'))
    for ident,row in manifest['facilities'].items():
        path=ROOT/row['path'].removeprefix('res://')
        assert hashlib.sha256(path.read_bytes()).hexdigest()==row['sha256'],ident
        with Image.open(path) as im:
            assert im.mode=='RGBA' and list(im.size)==row['canvas_px'],ident
            if ident in ('soothing_station','toy_station'):
                assert set(im.getchannel('A').get_flattened_data())=={0,255}
                assert row['footprint']==[1,1] and row['anchor_uv']==[0.5,158/256]
                assert row['shadow']['size']==[58,22]
    for ident in ('soothing_station','toy_station','vine_ball','soothe_gu','command_gu'):
        root=ET.parse(ROOT/f'assets/farming/ui/{ident}.svg').getroot()
        assert root.attrib['viewBox']=='0 0 64 64',ident
    return {'facility_textures':len(manifest['facilities']),'new_facilities':2,'new_icons':5,'historical_visual_baseline_modified':False}


if __name__=='__main__': print(json.dumps(check(),indent=2))
