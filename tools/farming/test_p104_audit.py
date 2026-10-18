import copy
import json
import os
import tempfile
import unittest
from pathlib import Path
from audit_p104_playtest import audit

ROOT=Path(__file__).resolve().parents[2]
EVIDENCE=ROOT/os.environ.get('P104_EVIDENCE','.art-work/p104-playtest/final-v3')


class ServicesAudit(unittest.TestCase):
    def setUp(self):
        self.data=json.loads((EVIDENCE/'compound/scenario.json').read_text(encoding='utf-8'))

    def verify(self,data):
        with tempfile.TemporaryDirectory(dir=ROOT/'.art-work') as folder:
            path=Path(folder)/'scenario.json'
            path.write_text(json.dumps(data),encoding='utf-8')
            return audit(path)

    def test_honest(self): self.assertTrue(self.verify(self.data)['ok'])

    def test_tamper(self):
        for kind in ['stock','toy','roll','contribution','gift','pool','work','fatigue']:
            data=copy.deepcopy(self.data)
            history=data['closing']['world']['services']['history']
            def event(stage): return next(r for r in history if r['stage']==stage)
            if kind=='stock': data['closing']['inventory']['vine_ball']=99
            elif kind=='toy': history.append(copy.deepcopy(event('toy_install')))
            elif kind=='roll': event('toy_service')['roll']=(event('toy_service')['roll']+1)%100
            elif kind=='contribution': event('breed_contribution')['points']+=1
            elif kind=='gift': event('birth_bonus')['gift']+=1
            elif kind=='pool': event('pool_credit')['credited']+=1
            elif kind=='work': event('work_progress')['points']+=1
            else: event('fatigue')['next']+=1
            # Also alter the public event stream: test arithmetic, not just prefix equality.
            prefix=len(data['opening']['world']['services']['history'])
            data['receipts']=[r for r in data['receipts'] if r.get('kind')!='service']+copy.deepcopy(history[prefix:])
            with self.subTest(kind=kind),self.assertRaises((ValueError,KeyError)):
                self.verify(data)


if __name__=='__main__': unittest.main()
