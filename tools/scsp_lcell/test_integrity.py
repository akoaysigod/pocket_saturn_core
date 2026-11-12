#!/usr/bin/env python3
"""Mocked tool execution; real public-source and terminal closure controls."""
import argparse,contextlib,hashlib,importlib.util,io,json,shutil,subprocess,sys
from pathlib import Path
from unittest.mock import patch

def main():
 if not __debug__:raise RuntimeError('OPTIMIZED_PYTHON_REJECTED')
 ap=argparse.ArgumentParser();ap.add_argument('--repo',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);a=ap.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False);home=Path(__file__).resolve().parent;results=[]
 for case in ['generated','live_source','late_generated','parsed_log','artifact_read_error','terminal_read_error','pass_print_error','pass_print_mutation','malformed_macro','reference_change']:
  root=out/case;pkg=root/'tools/scsp_lcell';repo=root/'repo';pkg.mkdir(parents=True)
  for n in ['test_scsp_lcell.py','test_integrity.py','scsp_tb.sv','lcell_identity.sv','README.md']:shutil.copyfile(home/n,pkg/n)
  for rel in ['src/fpga/ap_core.qsf','src/fpga/rtl/sdram1.sv']:
   p=repo/rel;p.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(a.repo/rel,p)
  gitdir=subprocess.run(['git','-C',str(a.repo.resolve()),'rev-parse','--absolute-git-dir'],check=True,stdout=subprocess.PIPE).stdout.decode().strip();(repo/'.git').write_text('gitdir: '+gitdir+'\n')
  if case=='malformed_macro':
   q=repo/'src/fpga/ap_core.qsf';q.write_bytes(q.read_bytes()+b'\nset_global_assignment -name VERILOG_MACRO "EXTRA=1" -definitely_invalid_option\n')
  runout=root/'run';spec=importlib.util.spec_from_file_location('tested_scsp',pkg/'test_scsp_lcell.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
  fired=[];original_run=subprocess.run;original_rglob=Path.rglob;original_read=Path.read_bytes;original_print=print;git_calls=[0]
  def mutate(p):p.chmod(0o644);p.write_bytes(original_read(p)+b'\n// mutation\n');fired.append(case)
  def fake_run(args,**kw):
   if args[0]=='git':
    cp=original_run(args,**kw);git_calls[0]+=1
    if case=='reference_change' and git_calls[0]>1:fired.append(case);cp.stdout+=b'\n'
    return cp
   label=Path(kw['stdout'].name).name
   markers={'seed_1.log':'COVER_ALL16_DATA_01XZ\nPASS cycles=200000','seed_764089157.log':'COVER_ALL16_DATA_01XZ\nPASS cycles=200000','mutant.log':'** Fatal: CAPTURE_MISMATCH cycle=265','observable_mutant.log':'** Fatal: OBSERVABLE_MISMATCH cycle=270'}
   kw['stdout'].write((markers.get(label,'mock simulator')+'\n').encode())
   if label=='version.log' and case in ['generated','live_source']:mutate(runout/'candidate.sv' if case=='generated' else repo/'src/fpga/rtl/sdram1.sv')
   return subprocess.CompletedProcess(args,0)
  def rglob(p,pattern):
   if p==runout and not fired:
    if case=='late_generated':mutate(runout/'candidate.sv')
    if case=='parsed_log':mutate(runout/'seed_1.log')
    if case=='artifact_read_error':fired.append(case);raise OSError('INJECTED_ARTIFACT_READ_ERROR')
    if case=='terminal_read_error':fired.append(case)
   return original_rglob(p,pattern)
  def read(p):
   if case=='terminal_read_error' and fired and p==runout/'candidate.sv':raise OSError('INJECTED_TERMINAL_READ_ERROR')
   return original_read(p)
  def emit(*args,**kw):
   if args==('PASS SCSP LCELL',):
    if case=='pass_print_error':fired.append(case);raise OSError('INJECTED_PASS_PRINT_ERROR')
    if case=='pass_print_mutation':mutate(runout/'candidate.sv')
   return original_print(*args,**kw)
  stream=io.StringIO();raised=None
  with patch.object(sys,'argv',['test_scsp_lcell.py','--repo',str(repo),'--out',str(runout)]),patch.object(m.subprocess,'run',fake_run),patch.object(Path,'rglob',rglob),patch.object(Path,'read_bytes',read),patch('builtins.print',emit),contextlib.redirect_stdout(stream):
   try:m.main()
   except BaseException as e:raised=repr(e)
  receipt=json.loads((runout/'result.json').read_text());expected={'generated':'GENERATED_OR_LOG_CHANGED','live_source':'LIVE_CHANGED','late_generated':'GENERATED_OR_LOG_CHANGED','parsed_log':'GENERATED_OR_LOG_CHANGED','artifact_read_error':'INJECTED_ARTIFACT_READ_ERROR','terminal_read_error':'INJECTED_TERMINAL_READ_ERROR','pass_print_error':'INJECTED_PASS_PRINT_ERROR','pass_print_mutation':'GENERATED_OR_LOG_CHANGED','malformed_macro':'MALFORMED_MACRO_LINE','reference_change':'REFERENCE_CHANGED'}[case]
  if case=='malformed_macro':fired.append(case)
  if not(fired and raised and receipt['status']=='FAIL' and expected in str(receipt['errors']) and (case=='pass_print_mutation' or 'PASS SCSP LCELL' not in stream.getvalue())):raise RuntimeError('CONTROL_FAILED '+case+' '+str(receipt))
  results.append({'case':case,'status':'PASS_REJECTED','error':raised,'receipt_sha256':hashlib.sha256((runout/'result.json').read_bytes()).hexdigest()})
 cp=subprocess.run([sys.executable,'-O',str(home/'test_scsp_lcell.py')],capture_output=True,text=True)
 if cp.returncode==0 or 'OPTIMIZED_PYTHON_REJECTED' not in cp.stderr:raise RuntimeError('OPTIMIZED_ACCEPTED')
 results.append({'case':'optimized_python','status':'PASS_REJECTED'})
 (out/'result.json').write_text(json.dumps({'status':'PASS','scope':'mocked simulator, real Git/source/snapshot/terminal checks; not RTL proof','runner_sha256':hashlib.sha256((home/'test_scsp_lcell.py').read_bytes()).hexdigest(),'cases':results},indent=2)+'\n');print('PASS integrity controls')
if __name__=='__main__':main()
