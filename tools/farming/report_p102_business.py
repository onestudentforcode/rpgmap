"""Re-audit all four P10.2 comparisons and export a traceable cost/return table."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

from audit_p8_playtest import reconcile
from audit_p102_playtest import lines, MODULE_HOSTS

ROOT = Path(__file__).resolve().parents[2]
LABELS = {'ordinary':'普通田', 'seed':'一级育种', 'material':'一级丰产', 'compound':'二级复合'}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def export(evidence, output):
    source = json.loads((ROOT/'content/farming/p8/production.json').read_text(encoding='utf-8'))
    station = next(f for f in source['facilities'] if f['id']=='field_service_station')
    results = {}
    for mode in LABELS:
        folder = evidence/mode
        checked = reconcile(folder)
        assert checked['mode']=='complete', 'diagnostic audit cannot authorize a report'
        summary = json.loads((folder/'summary.json').read_text(encoding='utf-8'))
        assert summary['settings']['room_mode']==mode
        horizon=int(summary['settings']['days'])
        for route in ('A','B'):
            room = checked['rooms'][route]
            stats = room['stats']
            actions = lines(folder/f'{route}-actions.jsonl')
            receipts = lines(folder/f'{route}-receipts.jsonl')
            days = lines(folder/f'{route}-days.jsonl')
            hosts = {int(f['uid']) for f in days[-1]['facilities'] if tuple(f['origin']) in MODULE_HOSTS}
            room_days = [r for r in lines(folder/f'{route}-rooms.jsonl') if r['stage']=='day']
            gu_ids = {r['instance_id'] for r in room_days[-1]['logistics']['instances'] if int(r['host_uid']) in hosts}
            assert len(gu_ids)==len(hosts), 'module host has no admitted gu'
            maintenance = sum(int(r['fee']) for r in receipts if r['kind']=='logistics' and r['stage']=='maintenance' and r['instance_id'] in gu_ids and r['day']<=horizon)
            service=Counter()
            for r in receipts:
                if r['kind']=='device' and r['stage'] in ('irrigate','fertilize') and int(r['uid']) in hosts and r['day']<=horizon:
                    service.update({item:int(n) for item,n in r['inputs'].items()})
            builds = sum(1 for a in actions if a['action']=='room host build' and a['result'].get('ok'))
            assert builds==stats['room_host_cells']
            # The independent replay already authenticates floor inputs and
            # the ordinary audit checks construction receipts/material flows.
            inputs = Counter({item:int(n)*builds for item,n in station['materials'].items()})
            inputs['raw_wood'] += stats.get('floor_actions',0)
            results[f'{mode}/{route}'] = {
                'configuration':mode, 'route':route, 'days':int(summary['settings']['days']),
                'farm_cash':checked['routes'][route]['cash'],
                'field_cells':9, 'host_cells':builds,
                'construction_cash':int(station['cash'])*builds,
                'construction_inputs':dict(inputs), 'host_gu_maintenance_cash':maintenance,
                'module_plantings':stats['module_plantings'], 'module_harvests':stats['module_harvests'],
                'farm_seed_awards':stats.get('seed_awards',0),
                'farm_reused_seeds':stats.get('reused_seeds',0),
                'farm_extra_primary':stats.get('material_awards',0),
                'farm_wheat_seeds_bought':stats.get('wheat_seeds_bought',0),
                'room_player_ap':stats.get('room_player_ap',0),
                'host_clean_water':service['clean_water'],
                'host_humus':service['humus'],
                'audit_expected_awards_including_continuation':room['expected_awards'],
                'evidence_sha256':checked['evidence_sha256'],
            }
    negative = json.loads((evidence/'room-negative/results.json').read_text(encoding='utf-8'))
    compound = reconcile(evidence/'compound')
    assert negative['count']==len(negative['rejected'])==16
    assert all(negative['rejected'].values()), 'tamper rejection must have a meaningful reason'
    assert negative['baseline_evidence_sha256']==compound['evidence_sha256'], 'negative probes used different evidence'
    assert negative['baseline_room_stats']==compound['rooms']
    report = {'status':'complete', 'evidence_root':evidence.relative_to(ROOT).as_posix(),
              'scope':'four normal-economy configurations, independent A/B, eight 120-day routes',
              'notes':[
                  'Same nine-cell module; other industries, research order and actual randomness also affect whole-farm cash.',
                  'Seed, reuse, purchases and extra-primary counts cover the whole farm; module counts are explicitly separate.',
                  'Room AP includes successful room operator actions; host services consume real water/humus independently of gu fees.',
                  'Gu are obtained through the existing once-per-save trial provision; their future upstream acquisition cost is not modeled.',
                  'Cash is the clock=120 snapshot, including that opening. Cost totals include receipts through day=120; continuation opening=121 is audited but excluded from costs.',
                  'No causal profit or guaranteed 25% realized success claim is inferred from eight routes.'],
              'auditors_sha256':{p:digest(ROOT/p) for p in ('tools/farming/audit_p8_playtest.py','tools/farming/audit_p102_playtest.py','tools/farming/test_p102_audit.py')},
              'negative_probes':{'count':16,'sha256':digest(evidence/'room-negative/results.json')},
              'routes':results}
    output.parent.mkdir(parents=True,exist_ok=True)
    output.with_suffix('.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    text = ['# P10.2 正常经营对照', '', '四种配置各执行独立 A/B 两条120日路线。正常初始90元石、24AP，使用实际购买、研究、建设、维护和收获；独立审计重建贡献与奖励，16类账本篡改全部拒绝。', '',
            '各路线使用同一块9格农业模块。现金、购种、回用与奖励为全场口径，模块播种/收获单独列出。其他产业、研究顺序与实际随机结果也影响现金，以下不能作为农业区净利润或严格因果对照。', '',
            '| 配置/路线 | 期末现金 | 模块播种/收获 | 额外种子/回用 | 额外主产物 | 购入麦种 | 站占地 | 建设元石 | 蛊维护元石 | 模块操作AP | 站补水/肥 |',
            '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|']
    for r in results.values():
        text.append(f"| {LABELS[r['configuration']]}/{r['route']} | {r['farm_cash']} | {r['module_plantings']}/{r['module_harvests']} | {r['farm_seed_awards']}/{r['farm_reused_seeds']} | {r['farm_extra_primary']} | {r['farm_wheat_seeds_bought']} | {r['host_cells']} | {r['construction_cash']} | {r['host_gu_maintenance_cash']} | {r['room_player_ap']} | {r['host_clean_water']}/{r['host_humus']} |")
    text += ['', '现金采用clock=120终态快照，包含该开日已扣费用；维护与补水/肥成本只累计至day=120，续跑开日121单独审计、不混入表内成本。每座维护站另耗木板3、铁锭1；站脚普通地板耗原木1，详见同名JSON逐路线成本及证据SHA256。蛊来自现有每档一次的试用配给，上游获取成本尚未接入。普通维护实际消耗清水/腐殖土，蛊的环境点节约不记实物收入。JSON中的奖励期望保留审计含续跑过程的口径，实际结果不要求恰好25%。', '',
             f"原始证据：`{report['evidence_root']}`；各配置目录中的 `audit.json` 保留完整配方、真实后续消费、库存、现金、工费、后勤与农业房间审计。第45日回顾与第121日继续运行记录均保留。", '',
             '复核命令：', '', '```powershell', f'python tools/farming/report_p102_business.py {report["evidence_root"]}', '```', '']
    output.with_suffix('.md').write_text('\n'.join(text),encoding='utf-8')
    print('P102 BUSINESS REPORT OK:',output)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence',type=Path)
    parser.add_argument('--output',type=Path,default=ROOT/'docs/farming/phase102-business')
    args=parser.parse_args()
    export(args.evidence.resolve(),args.output)
