"""Read-only source/hash/shape checks for the optional P8.6 environment assets."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT/'.art-work/p86-assets'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    provenance = []
    for report_name, image_name, canvas in (
            ('transition-report.json','transition_soft.png',(1024,1024)),
            ('stone-source-report.json','stone_source.png',(256,256))):
        report = json.loads((ASSETS/report_name).read_text(encoding='utf-8'))
        image_path = ASSETS/image_name
        source = ROOT/report['generator']
        assert source.is_relative_to(ROOT) and source.is_file(), source
        assert digest(source) == report['generator_sha256'], source
        assert digest(image_path) == report['sha256'], image_path
        image = Image.open(image_path)
        assert image.mode == 'RGBA' and image.size == canvas, image_path
        provenance.append({'asset':image_name,'generator':report['generator'],
                           'generator_sha256':digest(source),'png_sha256':digest(image_path),
                           'rgba_sha256':hashlib.sha256(image.tobytes()).hexdigest(),
                           'source_and_image_verified':True})
    alpha = Image.open(ASSETS/'transition_soft.png').getchannel('A')
    assert alpha.crop((960,960,1024,1024)).getextrema() == (255,255)
    assert alpha.getpixel((0,0)) == 0 and alpha.getpixel((32,32)) == 255
    stone_alpha = Image.open(ASSETS/'stone_source.png').getchannel('A')
    bounds = stone_alpha.getbbox()
    assert bounds and bounds[0] > 0 and bounds[1] > 0 and bounds[2] < 256 and bounds[3] < 256
    histogram = stone_alpha.histogram()
    qc = {'transition_full_variant_opaque':True,'isolated_corner_transparent':True,
          'stone_bbox':bounds,'stone_nonzero_alpha':sum(histogram[1:]),
          'stone_fraction_opaque_above_240':sum(histogram[241:])/sum(histogram[1:])}
    print(json.dumps({'provenance':provenance,'qc':qc},indent=2))
    print('P86 ENVIRONMENT ASSETS OK: 2 generated assets, source and output hashes verified')


if __name__ == '__main__':
    main()
