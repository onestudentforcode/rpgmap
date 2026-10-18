import copy
import json
import tempfile
import unittest
from pathlib import Path

from audit_room_boundaries import audit

ROOT = Path(__file__).resolve().parents[2]


class BoundaryAudit(unittest.TestCase):
    def setUp(self):
        self.data = json.loads((ROOT / '.art-work/p104-boundary/scenario.json').read_text(encoding='utf-8'))

    def verify(self, data):
        with tempfile.TemporaryDirectory(dir=ROOT / '.art-work') as directory:
            path = Path(directory) / 'scenario.json'
            path.write_text(json.dumps(data), encoding='utf-8')
            return audit(path)

    def test_honest(self):
        self.assertTrue(self.verify(self.data)['ok'])

    def test_tampered_receipts_and_inventory(self):
        for kind in ['qualification', 'warehouse', 'identity', 'claim']:
            data = copy.deepcopy(self.data)
            if kind == 'qualification':
                row = next(r for r in data['receipts'] if r.get('stage') == 'growth')
                row['seed_qualified'] = not row['seed_qualified']
            elif kind == 'warehouse':
                data['closing']['inventory']['grain'] += 1
            elif kind == 'identity':
                data['closing']['world']['rooms']['fields'][1]['uid'] = 1
            else:
                row = next(r for r in data['receipts'] if r.get('stage') == 'claim')
                data['receipts'].append(copy.deepcopy(row))
            with self.subTest(kind=kind), self.assertRaises(AssertionError):
                self.verify(data)


if __name__ == '__main__':
    unittest.main()
