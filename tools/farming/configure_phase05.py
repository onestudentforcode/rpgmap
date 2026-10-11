"""One-time Phase 5 content migration; no art or save files touched."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main():
    root = ROOT / 'content/farming'
    items = json.loads((root / 'items.json').read_text(encoding='utf-8'))
    for item in items['items']:
        seed = item['item_id'].endswith('_seed')
        item.update(kind='seed' if seed else 'food', path_ids=['wood'],
                    buy_price=item['base_price'] if seed else 0,
                    sell_price=0 if seed else item['base_price'])
    items['items'] = [i for i in items['items'] if i['item_id'] not in {'fungal_bed_material', 'rotten_log'}]
    for iid, name, price in [('fungal_bed_material', '菌床材料', 6), ('rotten_log', '朽木', 4)]:
        items['items'].append(dict(item_id=iid, name=name, base_price=price,
                                   feed_tags=[], source='farming', kind='production',
                                   path_ids=['wood'], buy_price=price, sell_price=0))
    crops = json.loads((root / 'crops.json').read_text(encoding='utf-8'))
    for crop in crops['crops']:
        crop['path_id'] = 'wood'
    config = json.loads((root / 'config.json').read_text(encoding='utf-8'))
    config['economy'] = dict(initial_primeval_stones=60, ap_weight=1, day_weight=1,
                             use_behaviors=['battle'],
                             medium_materials={'fungal_bed': 'fungal_bed_material', 'rotten_log': 'rotten_log'})
    for name, data in [('items', items), ('crops', crops), ('config', config)]:
        (root / f'{name}.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
