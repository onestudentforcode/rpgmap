"""Assemble independent A/B route evidence without modifying any raw books.

Both subprocesses run the original --route operator. Manifests and settings
must match, each raw result must pass, and research histories must differ.
"""
import argparse
import json
import shutil
from pathlib import Path

def assemble(parts, output):
    output.mkdir(parents=True,exist_ok=True)
    results=[]; manifest=None; settings=None
    for route in ('A','B'):
        directory=parts/route
        summary=json.loads((directory/'summary.json').read_text(encoding='utf-8'))
        current_manifest=(directory/'manifest.json').read_bytes()
        assert not summary['failures'] and set(summary['routes'])=={route},'raw route did not pass'
        assert manifest is None or manifest==current_manifest,'route source manifests differ'
        assert settings is None or settings==summary['settings'],'route settings differ'
        manifest=current_manifest; settings=summary['settings']
        results.append(summary)
        for path in directory.iterdir():
            if path.is_file() and path.name.startswith(route+'-'):
                shutil.copyfile(path,output/path.name)
        shutil.copyfile(directory/'summary.json',output/(route+'-run-summary.json'))
    assert results[0]['routes']['A']['research_order']!=results[1]['routes']['B']['research_order'],'routes not independent strategies'
    merged={'settings':settings,'routes':{**results[0]['routes'],**results[1]['routes']},
            'failures':[],'checks':sum(s['checks'] for s in results),
            'assembly':{'source_parts':str(parts),'method':'unchanged independent --route A/B outputs; identical manifests and settings'}}
    (output/'manifest.json').write_bytes(manifest)
    (output/'summary.json').write_text(json.dumps(merged,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('P10 ROUTES ASSEMBLED:',output,'checks=',merged['checks'])

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('parts',type=Path)
    parser.add_argument('output',type=Path)
    args=parser.parse_args()
    assemble(args.parts,args.output)
