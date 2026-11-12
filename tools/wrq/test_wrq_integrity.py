#!/usr/bin/env python3
"""Mock-tool integrity tests, using real public checkout/Git snapshots; no semantic claim."""
import argparse,contextlib,hashlib,importlib.util,io,json,shutil,subprocess,sys,tempfile
from pathlib import Path

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--repo',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);args=ap.parse_args()
 out=args.out.resolve();out.mkdir(parents=True,exist_ok=False);repo=args.repo.resolve();home=Path(__file__).resolve().parent;cases=[]
 for mode in ['generated_write','late_generated','late_snapshot','late_log','generated_read_error','log_read_error','terminal_print_error','terminal_print_mutation']:
  with tempfile.TemporaryDirectory(dir=out,prefix=mode+'_') as temp:
   d=Path(temp)
   for n in ['test_wrq.py','wrq_queue_tb.sv','wrq_fourstate_tb.sv','wrq_native_tb.sv']:shutil.copyfile(home/n,d/n)
   spec=importlib.util.spec_from_file_location('tested',d/'test_wrq.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);o=d/'result'
   rr=subprocess.run;rg=Path.rglob;rb=Path.read_bytes;wb=Path.write_bytes;argv=sys.argv;late=False;error=None;stream=io.StringIO()
   def run(cmd,**kw):
    if cmd[0]=='git':return rr(cmd,**kw)
    text=' '.join(cmd)
    if 'work.fourstate_tb' in text:msg='PASS_FOURSTATE'
    elif 'work.tb' in text:msg='PASS native owner'
    elif 'work.queue_tb' in text:msg='** Fatal: WRQ_OBSERVABLE_ADDRESS' if (o/'mutant_compile.log').exists() and not (o/'legacy_compile.log').exists() else 'PASS_QUEUE'
    else:msg='mock tool success'
    kw['stdout'].write(msg+'\n');return subprocess.CompletedProcess(cmd,0)
   def write(p,b):
    if mode=='generated_write' and p==o/'queue_dut.sv':b+=b'\n// injected generated input mutation\n'
    return wb(p,b)
   def glob(p,pattern):
    nonlocal late
    if p==o:
     late=True
     n={'late_generated':'queue_dut.sv','late_snapshot':'snapshot/reference/queue','late_log':'native_1.log'}.get(mode)
     if n:
      f=o/n;f.chmod(0o644);wb(f,rb(f)+b'\n// injected late mutation\n')
    return rg(p,pattern)
   def read(p):
    if late and ((mode=='generated_read_error' and p==o/'queue_dut.sv') or (mode=='log_read_error' and p==o/'native_1.log')):raise OSError('INJECTED_READ_ERROR')
    return rb(p)
   def printing(*values,**kw):
    if mode=='terminal_print_error' and values and values[0]=='PASS PUBLIC WRQ':raise OSError('INJECTED_TERMINAL_ERROR')
    if mode=='terminal_print_mutation' and values and values[0]=='PASS PUBLIC WRQ':
     target=o/'queue_dut.sv';target.chmod(0o644);wb(target,rb(target)+b'\n// terminal mutation\n')
    print(*values,**kw)
   try:
    subprocess.run=run;Path.rglob=glob;Path.read_bytes=read;Path.write_bytes=write;sys.argv=[str(d/'test_wrq.py'),'--repo',str(repo),'--out',str(o)];m.print=printing
    with contextlib.redirect_stdout(stream):m.main()
   except Exception as exc:error=str(exc)
   finally:subprocess.run=rr;Path.rglob=rg;Path.read_bytes=rb;Path.write_bytes=wb;sys.argv=argv
   rec=json.loads((o/'result.json').read_text());expect='INJECTED_READ_ERROR' if 'read_error' in mode else ('INJECTED_TERMINAL_ERROR' if mode=='terminal_print_error' else 'INPUT_CHANGED')
   good=error is not None and expect in error and rec['status']=='FAIL' and (mode=='terminal_print_mutation' or 'PASS PUBLIC WRQ' not in stream.getvalue())
   cases.append({'case':mode,'passed':good,'error':error,'receipt':rec})
 status='PASS' if all(c['passed'] for c in cases) else 'FAIL'
 result={'status':status,'scope':'Mock tools; real staging, Git reference bytes, intended-input hashes and terminal closure. No functional simulation claim.','runner_sha256':hashlib.sha256((home/'test_wrq.py').read_bytes()).hexdigest(),'cases':cases}
 (out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(status)
 if status!='PASS':raise SystemExit(1)
if __name__=='__main__':main()
