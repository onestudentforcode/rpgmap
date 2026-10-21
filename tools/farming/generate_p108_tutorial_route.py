"""Create the authored daily guide from the no-injection P8 A replay."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_INPUT = ROOT / '.art-work/p108-playthrough'
DEFAULT_OUTPUT = ROOT / 'content/farming/p8/tutorial_route.json'
EXCLUDED_RUNTIME_ONLY = {'scripts/farming/p8/p8_scene.gd'}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def categorize(action: str) -> set[str]:
    result = set()
    if 'world.collect(' in action: result.add('collect')
    if 'deliver_order' in action: result.add('order')
    if 'complete_event' in action: result.add('stage_submit')
    if action == 'field_gu_effect': result.add('field_gu_effect')
    if 'world.till(' in action or 'ranch pave' in action: result.add('expand')
    if 'world.plant(' in action: result.add('plant')
    if 'world.harvest(' in action or 'pick_flower' in action: result.add('harvest')
    if 'research.start(' in action: result.add('research_start')
    if 'research.work(' in action: result.add('research_work')
    if 'start_batch' in action: result.add('batch_start')
    if 'claim_batch' in action: result.add('batch_claim')
    if 'build [' in action: result.add('build')
    if 'irrigate(' in action or 'fertilize(' in action or 'water tree' in action: result.add('field_care')
    if 'world.sell(' in action or 'world.buy(' in action or ' purchase' in action: result.add('market')
    return result


def advice(codes: set[str], crops: set[str], facilities: set[str]) -> list[str]:
    result = []
    if 'expand' in codes: result.append('\u5f00\u57a6\u53ef\u7528\u8015\u5730\u6216\u6574\u7406\u4e0b\u4e00\u5757\u751f\u4ea7\u7a7a\u95f4\uff0c\u4e0d\u5fc5\u4e00\u6b21\u94fa\u6ee1\u3002')
    if 'plant' in codes:
        selected = '\u3001'.join(sorted(crops))
        result.append('\u8865\u79cd%s\uff1b\u6309\u5730\u5757\u7a7a\u95f4\u548c\u73b0\u6709\u79cd\u5b50\u5b89\u6392\u3002' % (selected or '\u5f53\u524d\u9700\u8981\u7684\u4f5c\u7269'))
    if 'harvest' in codes: result.append('\u68c0\u67e5\u6210\u719f\u4f5c\u7269\u5e76\u6536\u83b7\uff0c\u6838\u5bf9\u5165\u5e93\u540e\u518d\u51b3\u5b9a\u662f\u5426\u8865\u79cd\u3002')
    if 'build' in codes: result.append('\u6309\u5f53\u524d\u9636\u6bb5\u6761\u4ef6\u6269\u5efa\u6240\u9700\u8bbe\u65bd\uff0c\u5efa\u9020\u524d\u6838\u5bf9\u6750\u6599\u3002')
    if 'research_start' in codes or 'research_work' in codes: result.append('\u67e5\u770b\u7814\u7a76\u524d\u7f6e\u4e0e\u6837\u672c\uff1b\u6761\u4ef6\u6ee1\u8db3\u65f6\u542f\u52a8\u7814\u7a76\u5e76\u6295\u5165\u6709\u6548\u5de5\u65f6\u3002')
    if 'batch_claim' in codes: result.append('\u68c0\u67e5\u52a0\u5de5\u8bbe\u65bd\uff0c\u9886\u53d6\u5df2\u5b8c\u6210\u6279\u6b21\u3002')
    if 'batch_start' in codes: result.append('\u67e5\u770b\u539f\u6599\u5e93\u5b58\uff0c\u542f\u52a8\u5f53\u524d\u53ef\u8d1f\u62c5\u7684\u52a0\u5de5\u6279\u6b21\u3002')
    if 'field_care' in codes: result.append('\u67e5\u770b\u4f5c\u7269\u6c34\u80a5\u72b6\u6001\uff0c\u53ea\u5728\u786e\u6709\u9700\u8981\u65f6\u7ef4\u62a4\u3002')
    if 'order' in codes: result.append('\u67e5\u770b\u8ba2\u5355\uff1b\u7559\u8db3\u7ecf\u8425\u5e93\u5b58\u540e\u518d\u4ea4\u4ed8\u4f59\u91cf\u3002')
    if 'collect' in codes: result.append('\u6309\u9700\u91c7\u96c6\u6c34\u3001\u77f3\u6599\u6216\u77ff\u7269\uff0c\u5148\u7559\u8db3\u8ba2\u5355\u548c\u5efa\u8bbe\u7528\u91cf\u3002')
    if 'market' in codes: result.append('\u68c0\u67e5\u4e70\u5356\u4ef7\u683c\u4e0e\u7ecf\u8425\u6240\u9700\u5e93\u5b58\uff0c\u518d\u51b3\u5b9a\u662f\u5426\u4ea4\u6613\u3002')
    if 'stage_submit' in codes: result.append('\u4f9b\u8d27\u6b21\u6570\u8fbe\u5230\u8981\u6c42\u65f6\uff0c\u63d0\u4ea4\u5f53\u524d\u9636\u6bb5\u4e8b\u4ef6\u4ee5\u5f00\u653e\u540e\u7eed\u5185\u5bb9\u3002')
    if 'field_gu_service' in codes: result.append('\u786e\u8ba4\u519c\u4e1a\u86ca\u5df2\u670d\u52a1\u7530\u5757\uff1b\u670d\u52a1\u8bb0\u5f55\u672c\u8eab\u4e0d\u7b49\u4e8e\u4f5c\u7269\u83b7\u5f97\u52a0\u901f\u3002')
    if 'field_gu_effect' in codes: result.append('\u519c\u4e1a\u86ca\u5df2\u8ba9\u4f5c\u7269\u53d6\u5f97\u989d\u5916\u751f\u957f\u8fdb\u5ea6\uff1b\u4ee5\u5b9e\u9645\u751f\u957f\u8bb0\u5f55\u4e3a\u51c6\u3002')
    return result[:3]


def build(source: Path) -> dict:
    summary = json.loads((source / 'summary.json').read_text(encoding='utf-8'))
    assert summary['settings']['days'] == 90 and 'A' in summary['routes']
    rows = [json.loads(line) for line in (source / 'A-actions.jsonl').read_text(encoding='utf-8').splitlines()]
    receipts = [json.loads(line) for line in (source / 'A-receipts.jsonl').read_text(encoding='utf-8').splitlines()]
    production = json.loads((ROOT / 'content/farming/baked/p8/production.json').read_text(encoding='utf-8'))
    day_rows = [json.loads(line) for line in (source / 'A-days.jsonl').read_text(encoding='utf-8').splitlines()]
    assert len(day_rows) == 91 and [row['day'] for row in day_rows] == list(range(1, 92))
    grouped = defaultdict(list)
    for row in rows:
        if row['day'] < 90 and row['result'].get('ok'):
            grouped[row['day'] + 1].append(row['action'])
    provisioned = {f'trial-{index:03d}': ident for index, ident in enumerate(production['logistics']['provision'], 1)}
    for row in receipts:
        if row.get('kind') == 'logistics' and row.get('stage') == 'maintenance' \
            and provisioned.get(row.get('instance_id')) == 'growth_gu' and row['day'] < 90:
            grouped[row['day'] + 1].append('field_gu_service')
    effective_gu_day = next((row['day'] for row in day_rows if 'active_field_gu' in row.get('tutorial_completed', [])), None)
    assert effective_gu_day is not None, 'replay did not reach actual field-gu growth milestone'
    grouped[effective_gu_day].append('field_gu_effect')
    timeline = []
    for day in range(1, 91):
        actions = grouped[day]
        codes = set().union(*(categorize(action) for action in actions))
        assert actions and codes, f'no successful routed actions for day {day}'
        crops = set()
        facilities = set()
        for action in actions:
            crops.update(re.findall(r'world\.plant\([^,]+,\s*"([^"]+)"', action))
            facilities.update(re.findall(r'build \["([^"]+)"', action))
        timeline.append({'day':day,'advice':advice(codes,crops,facilities),
                         'evidence_codes':sorted(codes),'action_count':len(actions)})
    manifest = json.loads((source / 'manifest.json').read_text(encoding='utf-8'))
    relevant = {name: value for name, value in manifest.items() if name not in EXCLUDED_RUNTIME_ONLY}
    for name, expected in relevant.items():
        assert digest(ROOT / name) == expected, f'replay source changed: {name}'
    return {'route_id':'p8_a_replay_90d_v1','title':'A路线前45日参考安排',
            'source_kind':'fresh_no_injection_replay','source_run':'run_p8_playtest.gd --days=90 --route=A',
            'reference_days':90,'replay_days':90,'initial_currency':summary['settings']['initial_currency'],
            'effective_field_gu_day':effective_gu_day,
            'source_hashes':relevant,'timeline':timeline,
            'note':'来自真实公开动作回放；这是可顺延的参考节奏。长线回放尚有未通过的目标，不作为新手目标或验收结论。'}


def main() -> None:
    parser=argparse.ArgumentParser()
    parser.add_argument('--input',type=Path,default=DEFAULT_INPUT)
    parser.add_argument('--output',type=Path,default=DEFAULT_OUTPUT)
    args=parser.parse_args()
    route=build(args.input)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(route,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f"P108 ROUTE DATA OK: {len(route['timeline'])} days from {route['source_run']}")


if __name__=='__main__': main()
