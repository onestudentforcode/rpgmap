"""Validate the accepted six-image sample plus eight family extensions, then install atomically."""
import argparse, json, hashlib
from pathlib import Path
from PIL import Image
from import_p8_plants import ROOT, encoded, image_check, install

def read(path):return json.loads(path.read_text(encoding='utf-8'))

def prepare(render_roots=None):
    pending={};manifest=read(ROOT/'assets/farming/crops/plant_manifest.json');checks=[]
    roots=render_roots or [ROOT/'.art-work/p86-runtime',ROOT/'.art-work/p86-expanded']
    reports=[read(root/'render-report.json') for root in roots]
    grounding=read(ROOT/'content/farming/p8/p86_grounding_trial.json')
    grounding['purpose']='P8.6 production contacts, seven plants and fifteen facilities'
    grounding['sources'].update({
        'ore_source':{'size':[48,18],'offset':[0,4],'opacity':.21},
        'spring_source':{'size':[49,23],'offset':[0,3],'opacity':.17}})
    for ident,visual in manifest['plants'].items():
        for state in ('stage_0','stage_1'):
            relative=visual['stages'][state].removeprefix('res://')
            selected=next((i for i,report in enumerate(reports) if relative in report),None)
            if selected is None:raise ValueError('missing juvenile '+relative)
            record=reports[selected][relative];data=(roots[selected]/relative).read_bytes()
            if hashlib.sha256(data).hexdigest()!=record['sha256']:raise ValueError('candidate hash '+relative)
            if record['canvas_px']!=visual['canvas_px'] or max(abs(a-b) for a,b in zip(record['anchor_uv'],visual['anchor_uv']))>1e-5:
                raise ValueError('candidate geometry '+relative)
            check=image_check(data,visual['canvas_px'],relative)
            pending[relative]=data;visual['sha256'][state]=record['sha256']
            visual['runtime_variant']['renders'][state]=record
            checks.append({'id':ident,'state':state,'sha256':record['sha256'],**check})
        visual['shadow']=grounding['plants'][ident]
    manifest['visual_revision']='p86';manifest['user_accepted_sample']='2026-10-15'
    pending['assets/farming/crops/plant_manifest.json']=encoded(manifest)
    facilities=read(ROOT/'assets/farming/facilities/facility_manifest.json')
    for ident,visual in facilities['facilities'].items():visual['shadow']=grounding['facilities'][ident]
    pending['assets/farming/facilities/facility_manifest.json']=encoded(facilities)
    resources={}
    for ident in ('stone_source','ore_source','spring_source'):
        parent=ROOT/('.art-work/p86-assets' if ident=='stone_source' else '.art-work/p86-resources')
        metadata=read(parent/('stone-source-report.json' if ident=='stone_source' else ident+'.json'))
        data=(parent/(ident+'.png')).read_bytes();digest=hashlib.sha256(data).hexdigest()
        if digest!=metadata['sha256']:raise ValueError('resource hash '+ident)
        image_check(data,[256,256],ident)
        path='assets/farming/p86/'+ident+'.png';pending[path]=data
        resources[ident]={'path':'res://'+path,'sha256':digest,'canvas_px':[256,256],
          'anchor_uv':metadata['anchor_uv'],'draw_size':metadata['draw_size'],'shadow':grounding['sources'][ident],
          'provenance':metadata}
    transition=(ROOT/'.art-work/p86-assets/transition_soft.png').read_bytes()
    with Image.open(ROOT/'.art-work/p86-assets/transition_soft.png') as image:
        if image.mode!='RGBA' or image.size!=(1024,1024):raise ValueError('invalid transition atlas')
    path='assets/farming/p86/transition_soft.png';pending[path]=transition
    scenery={'schema_version':1,'visual_revision':'p86','resources':resources,
      'transition':{'path':'res://'+path,'sha256':hashlib.sha256(transition).hexdigest(),'canvas_px':[1024,1024]}}
    pending['assets/farming/p86/resource_manifest.json']=encoded(scenery)
    pending['content/farming/p8/grounding.json']=encoded(grounding)
    style=read(ROOT/'content/farming/p8/world_visuals.json')
    style.update({'visual_revision':'p86','production_visuals':True,'terrain_tones':{
        'grass':'94ad7f','dirt':'b0987a','stone':'a9af9e','tilled':'8c795f','water':'8fb7ae'}})
    style['terrain_surface_kinds']['water']=4
    pending['content/farming/p8/world_visuals.json']=encoded(style)
    terrains=read(ROOT/'content/farming/p8/terrains.json')
    for terrain in terrains['terrains']:
        if 'trans' in terrain['textures']:terrain['textures']['trans']='assets/farming/p86/transition_soft.png'
    pending['content/farming/p8/terrains.json']=encoded(terrains)
    report={'visual_revision':'p86','sample_user_accepted':True,'juveniles':checks,'resources':resources,
            'canvas_and_roots_preserved':True,'mature_and_flowering_pngs_retained':True}
    pending['docs/farming/art/p86-install-report.json']=encoded(report)
    return pending

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--renders',type=Path,nargs='+',help='complete batch or accepted/extension batch directories')
    writes=install(prepare(parser.parse_args().renders))
    print('P86 VISUAL INSTALL OK',writes)
