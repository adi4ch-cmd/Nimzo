"""The combined task must stay blocked before any package/compiler operation."""
import importlib.util
import json
from pathlib import Path
import subprocess
import unittest
import yaml
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('acceptance', ROOT/'tools/verify_prebuild_acceptance.py')
gate = importlib.util.module_from_spec(spec); spec.loader.exec_module(gate)

class BuildHoldTests(unittest.TestCase):
    def ready(self):
        return {'schema_version':1,'build_authorized':True,'voice_enabled':True,
            'app_source_sha256':'test-source','open_blockers':[],
            'checks':{k:{'status':'PASS','evidence':['verified fixture']} for k in gate.REQUIRED}}
    def test_unfinished_or_stale_or_voiceless_acceptance_cannot_unlock(self):
        gate.validate(self.ready(),'test-source')
        for change in [{'build_authorized':False},{'voice_enabled':False},
                       {'app_source_sha256':'older-source'},{'open_blockers':['voice missing']}]:
            record=self.ready();record.update(change)
            with self.assertRaises(ValueError):gate.validate(record,'test-source')
        for key in gate.REQUIRED:
            record=self.ready();record['checks'][key]['status']='BLOCKED'
            with self.assertRaises(ValueError):gate.validate(record,'test-source')
    def test_dynamic_qa_requires_dynamic_acceptance_and_explicit_deferral(self):
        record=self.ready()
        record['qa_checks']=json.loads(json.dumps(record['checks']))
        record.update(qa_build_authorized=True,qa_open_blockers=[],voice_enabled=False,
                      voice_status='OWNER_DEFERRED')
        record['checks']['vivox_sdk']['status']='OWNER_DEFERRED'
        gate.validate(record,'test-source',dynamic_qa=True)
        with self.assertRaises(ValueError):gate.validate(record,'test-source')
        for change in [{'qa_build_authorized':False},{'qa_open_blockers':['missing sync']},
                       {'voice_status':'UNKNOWN'},{'app_source_sha256':'stale'}]:
            modified={**record,**change}
            with self.assertRaises(ValueError):gate.validate(modified,'test-source',dynamic_qa=True)
        for key in gate.QA_REQUIRED:
            modified=json.loads(json.dumps(record));modified['qa_checks'][key]['status']='BLOCKED'
            with self.assertRaises(ValueError):gate.validate(modified,'test-source',dynamic_qa=True)

    def test_repository_and_old_voiceless_workflow_remain_held(self):
        record=json.loads((ROOT/'release/acceptance.json').read_text())
        self.assertFalse(record['build_authorized'])
        result=subprocess.run(['python3',str(ROOT/'tools/verify_prebuild_acceptance.py'),
            '--voice-disabled-workflow'],capture_output=True,text=True)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('voice-disabled',result.stderr)
    def test_every_package_job_has_earlier_gate(self):
        import re
        for path in (ROOT/'.github/workflows').glob('*.yml'):
            workflow=yaml.safe_load(path.read_text())
            for job in workflow.get('jobs',{}).values():
                steps=job.get('steps',[])
                builds=[i for i,s in enumerate(steps) if re.search(r'flutter\s+build\s+(apk|appbundle|ipa)',s.get('run',''))]
                for build in builds:
                    self.assertTrue(any('tools/verify_prebuild_acceptance.py' in s.get('run','') for s in steps[:build]),str(path))

    def test_workflow_service_context_only_uses_runtime_step_env(self):
        import re
        for path in (ROOT/'.github/workflows').glob('*.yml'):
            workflow=yaml.safe_load(path.read_text())
            scopes=[workflow.get('env',{})]+[j.get('env',{}) for j in workflow.get('jobs',{}).values()]
            for scope in scopes:
                self.assertFalse(any(re.search(r'\bjob\.',str(v)) for v in scope.values()),
                    f'{path}: job.services context is unavailable in workflow/job env; use step env')
