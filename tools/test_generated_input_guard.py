#!/usr/bin/env python3
"""Adversarial compiler-wrapper controls for generated-input integrity."""
import argparse, hashlib, json, os
from pathlib import Path
import shutil, subprocess, sys

ap=argparse.ArgumentParser(description=__doc__)
ap.add_argument('--source-dir',required=True,type=Path)
ap.add_argument('--out',required=True,type=Path)
a=ap.parse_args(); out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
runner=Path(__file__).with_name('test_counter.py').resolve()
cc=shutil.which('clang')
if not cc: raise RuntimeError('clang required')
wrapper=out/'compiler_wrapper.py'
wrapper.write_text('''#!/usr/bin/env python3
import os,subprocess,sys
from pathlib import Path
p=subprocess.run([os.environ['COUNTER_REAL_CC']]+sys.argv[1:])
if p.returncode==0 and '-o' in sys.argv:
 h=next((Path(x) for x in sys.argv[1:] if x.endswith('/wide/harness.c')),None)
 if h:
  target=h.parent/os.environ['COUNTER_MUTATE_FILE']
  with target.open('a') as f:f.write('\\n/* injected generated-input race */\\n')
  if os.environ.get('COUNTER_COMPILE_FAILURE')=='1':sys.exit(7)
sys.exit(p.returncode)
''')
wrapper.chmod(0o755)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
result={'status':'RUNNING','runner_sha256':sha(runner),'control_sha256':sha(Path(__file__)),'wrapper_sha256':sha(wrapper),'cases':[]}
for name,target,fail in [('controller_after_success','controller.c',False),('harness_during_failure','harness.c',True)]:
 env=os.environ.copy();env.update(COUNTER_REAL_CC=cc,COUNTER_MUTATE_FILE=target,COUNTER_COMPILE_FAILURE='1' if fail else '0')
 args=[sys.executable,'-O',str(runner),'--source-dir',str(a.source_dir.resolve()),'--out',str(out/name),'--cc',str(wrapper)]
 with (out/(name+'.log')).open('w') as f:p=subprocess.run(args,stdout=f,stderr=subprocess.STDOUT,env=env,timeout=180)
 r=json.loads((out/name/'result.json').read_text());key='wide/'+target
 ok=p.returncode!=0 and r['status']=='FAIL' and r.get('error','').startswith('SOURCE_CHANGED:') and r['generated_input_expected_sha256'][key]!=r['generated_input_end_sha256'][key]
 if not fail:ok=ok and any(c['log']=='wide_6_0.log' and c['exit']==0 for c in r['commands'])
 else:ok=ok and any(c['log']=='wide_compile.log' and c['exit']==7 for c in r['commands'])
 result['cases'].append({'case':name,'argv':args,'exit':p.returncode,'precise_source_change_rejected':ok,'receipt_sha256':sha(out/name/'result.json'),'log_sha256':sha(out/(name+'.log'))})
 if not ok:result['status']='FAIL';(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');raise RuntimeError(name+' did not reject exact source change')
result['status']='PASS_GENERATED_INPUT_CHANGE_REJECTED';(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'])
