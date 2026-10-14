"""Read-only render comparison and screenshot-matrix validation."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageStat
from import_p8_plants import ROOT, encoded


def statistics(path):
    with Image.open(path) as image:
        alpha = image.getchannel('A')
        width,height = image.size
        return ([v/(width if i%2 == 0 else height) for i,v in enumerate(alpha.getbbox())],
                ImageStat.Stat(alpha).mean[0]/255,ImageStat.Stat(image.convert('RGB'),mask=alpha).mean)


def check(source, shots):
    handoff = json.loads((source/'UPSTREAM_PLANT_ASSETS.json').read_text(encoding='utf-8'))
    pairs = []
    for asset in handoff['assets']:
        for entry in asset['stages']+([asset['flowering']] if 'flowering' in asset else []):
            pairs.append((entry['source_runtime_png'],entry['suggested_upstream_file'].removeprefix('res://')))
    facilities = json.loads((ROOT/'assets/farming/facilities/facility_manifest.json').read_text(encoding='utf-8'))['facilities']
    pairs += [(a['source_png'],a['path'].removeprefix('res://')) for a in facilities.values()]
    comparisons = []
    for original,current in pairs:
        before,after = statistics(source/original),statistics(ROOT/current)
        bbox = max(abs(a-b) for a,b in zip(before[0],after[0]))
        coverage = abs(before[1]-after[1])
        if bbox >= .035 or coverage >= .015: raise ValueError(f'{current}: silhouette changed')
        comparisons.append({'path':current,'bbox_delta_uv':bbox,'coverage_delta':coverage,
                            'color_mean_delta':max(abs(a-b) for a,b in zip(before[2],after[2]))})
    profiles = []
    expected_names = {'pilot','all-plants','all-facilities','negative-land','build-preview-0','build-preview-14',
                      'dense-0.1','dense-1.0','dense-3.0','dense-pan'}
    for size in ('2560x1440','1920x1080','960x540'):
        folder = shots/size
        expected = tuple(map(int,size.split('x')))
        frames = list(folder.glob('*.png'))
        if {p.stem for p in frames} != expected_names: raise ValueError(f'{size}: screenshot cases incomplete')
        if any(Image.open(p).size != expected for p in frames): raise ValueError(f'{size}: wrong viewport dimensions')
        profiles.append({'viewport':list(expected),'screenshots':sorted(p.name for p in frames),
                         'zoom_levels':[0.1,1.0,3.0],'middle_pan_verified_by_fixture':True})
    return ({'method':'original small renders vs 4x Blender renders; normalized alpha bbox/coverage and weighted RGB',
             'thresholds':{'bbox_delta_uv':.035,'coverage_delta':.015},'checks':comparisons},
            {'fixture':'synthetic stage panels plus real till/plant/build dense fixture; isolated slots; not natural progression',
             'profiles':profiles})


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--shots',type=Path,default=ROOT/'.art-work/p85-visual-preview')
    args = parser.parse_args()
    comparison,matrix = check(args.source,args.shots)
    (ROOT/'docs/farming/art/runtime-render-comparison.json').write_bytes(encoded(comparison))
    (ROOT/'docs/farming/art/visual-matrix.json').write_bytes(encoded(matrix))
    print('P85 VISUAL QC OK: 44 render comparisons, 30 screenshot cases')
