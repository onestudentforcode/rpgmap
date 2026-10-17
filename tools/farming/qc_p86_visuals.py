"""Production resource integrity, approved roots and actual GPU viewport evidence."""
import argparse, hashlib, json, io
from pathlib import Path
from PIL import Image, ImageStat
from import_p8_plants import ROOT, encoded, image_check

def read(path):return json.loads(path.read_text(encoding='utf-8'))
def digest(data):return hashlib.sha256(data).hexdigest()

def check(shots, freeze_baseline=False):
    checks=[];entries=[]
    plants=read(ROOT/'assets/farming/crops/plant_manifest.json')
    facilities=read(ROOT/'assets/farming/facilities/facility_manifest.json')
    sources=read(ROOT/'assets/farming/p86/resource_manifest.json')
    for ident,data in plants['plants'].items():
        for state,path in data['stages'].items():entries.append((ident,state,path,data['sha256'][state],data))
    for ident,data in facilities['facilities'].items():entries.append((ident,'body',data['path'],data['sha256'],data))
    for ident,data in sources['resources'].items():entries.append((ident,'resource',data['path'],data['sha256'],data))
    entries.append(('transition','atlas',sources['transition']['path'],sources['transition']['sha256'],sources['transition']))
    contracts={}
    for ident,state,path,expected,visual in entries:
        contracts[path]={key:visual[key] for key in ('canvas_px','anchor_uv','draw_size') if key in visual}
        contracts[path]['sha256']=expected
        raw=(ROOT/path.removeprefix('res://')).read_bytes()
        if digest(raw)!=expected:raise ValueError('manifest hash '+path)
        if state!='atlas':
            spec=image_check(raw,visual['canvas_px'],path)
            anchor=visual['anchor_uv']
            if any(not 0<=value<=1 for value in anchor):raise ValueError('root out of canvas '+path)
            if state in ('stage_0','stage_1'):
                record=visual['runtime_variant']['renders'][state]
                if max(abs(a-b) for a,b in zip(record['anchor_uv'],anchor))>1e-5:raise ValueError('changed root '+path)
            checks.append({'id':ident,'state':state,'sha256':expected,**spec})
        else:
            image=Image.open(io.BytesIO(raw))
            if image.size!=(1024,1024) or image.mode!='RGBA':raise ValueError('transition format')
            checks.append({'id':ident,'state':state,'sha256':expected,'size':list(image.size)})
    baseline_path=ROOT/'docs/farming/art/p86-visual-baseline.json'
    if freeze_baseline:
        baseline_path.write_bytes(encoded({'visual_revision':'p86','sample_user_accepted':True,
          'rollout_local_reviewed':True,'full_scene_user_acceptance_not_claimed':True,'contracts':contracts}))
    elif not baseline_path.exists() or read(baseline_path)['contracts']!=contracts:
        raise ValueError('P8.6 visual baseline differs; review intentional asset/root changes before updating it')
    profiles=[]
    expected_names={'pilot','all-plants','all-facilities','negative-land','build-preview-0','build-preview-14',
       'dense-0.1','dense-1.0','dense-3.0','dense-pan','resources','facility-catalog','shore-topology-1.0','shore-topology-3.0'}
    for size in ('2560x1440','1920x1080','960x540'):
        folder=shots/size;frames=list(folder.glob('*.png'));expected=tuple(map(int,size.split('x')))
        if {p.stem for p in frames}!=expected_names:raise ValueError(size+' screenshot matrix incomplete')
        dimensions=read(folder/'dimensions.json')
        if tuple(dimensions['viewport'])!=expected:raise ValueError(size+' actual viewport')
        for frame in frames:
            if Image.open(frame).size!=expected:raise ValueError(str(frame)+' PNG dimensions')
        text=(shots/(size+'.log')).read_text(encoding='utf-8')
        if 'P86 FULL VISUAL PREVIEW OK' not in text or 'ERROR:' in text:raise ValueError(size+' GPU errors')
        profiles.append({'viewport':list(expected),'frames':len(frames),'gpu_log':'passed'})
    return {'visual_revision':'p86','png_count':len(checks),'checks':checks,'viewports':profiles,
      'gpu_frames':sum(profile['frames'] for profile in profiles),
      'sample_user_accepted':True,'final_all_scene_user_review':'not separately claimed',
      'metrics_policy':'per-asset integrity and viewport checks; no universal colorfulness threshold'}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--shots',type=Path,default=ROOT/'.art-work/p86-final-visual')
    parser.add_argument('--freeze-baseline',action='store_true',help='explicitly record the reviewed rollout; normal checks never update its baseline')
    args=parser.parse_args()
    report=check(args.shots,args.freeze_baseline)
    (ROOT/'docs/farming/art/p86-asset-qc.json').write_bytes(encoded(report))
    print(f"P86 VISUAL QC OK: {report['png_count']} PNGs, {report['gpu_frames']} actual GPU frames")
