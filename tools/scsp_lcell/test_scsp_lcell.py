#!/usr/bin/env python3
"""Questa regression for the exact two-lcell SDRAM1 capture change."""
import sys
if not __debug__:raise SystemExit('OPTIMIZED_PYTHON_REJECTED')
import argparse,hashlib,json,os,re,shutil,subprocess,time
from pathlib import Path
REV='77fae10e6da2f444bfbafc0551fdedcb77911c37'
PARENT='fd7b442a70f80328b9933e60e843f7cf8f62ee7fb091f87fc228ed94683d010b'
CANDIDATE='79904fccedad6e89a7dcaa9498ecba1c132c29eb2c081ca31cbfb9e9dd9a73aa'
def digest(b):return hashlib.sha256(b).hexdigest()
def need(ok,why):
 if not ok:raise RuntimeError(why)
def adapt(data,reference=False):
 edits=[(b'\talways @(posedge clk) begin\n\t\treg sync_old;',b'\talways @(posedge clk) begin : ch2_seq\n\t\treg sync_old;',1),
 (b"reg [4:0] reset = 5'h1f;",b"static reg [4:0] reset = 5'h1f;",1),
 (b'reg init_old = 0;',b'static reg init_old = 0;',1),
 (b'inout  reg [15:0] SDRAM_DQ',b'inout wire [15:0] SDRAM_DQ',1),
 (b'output            SDRAM_nCS',b'output reg        SDRAM_nCS',1),
 (b'\t// initialization ',b'\treg [15:0] SDRAM_DQ_OUT;\n\tassign SDRAM_DQ = SDRAM_DQ_OUT;\n\t// initialization ',1),
 (b'SDRAM_DQ <=',b'SDRAM_DQ_OUT <=',2)]
 fixed=data
 for old,new,count in edits:need(fixed.count(old)==count,'ADAPTER_ANCHOR');fixed=fixed.replace(old,new)
 inverse=fixed
 for old,new,count in reversed(edits):inverse=inverse.replace(new,old)
 need(inverse==data,'ADAPTER_INVERSE')
 if reference:
  need(fixed.count(b'module sdram1\n')==1,'MODULE_ANCHOR');fixed=fixed.replace(b'module sdram1\n',b'module sdram1_ref\n')
 return fixed

def main():
 home=Path(__file__).resolve().parent
 ap=argparse.ArgumentParser(__doc__);ap.add_argument('--repo',type=Path,default=home.parents[1]);ap.add_argument('--out',type=Path,required=True);ap.add_argument('--questa-bin',type=Path);a=ap.parse_args()
 repo=a.repo.resolve();out=a.out.resolve();need(not out.exists(),'FRESH_OUTPUT_REQUIRED');out.mkdir(parents=True)
 env=os.environ.copy();bindir=a.questa_bin.resolve() if a.questa_bin else None
 if bindir:env['PATH']=str(bindir)+os.pathsep+env.get('PATH','')
 live={};expected={};logs={};errors=[];record={'status':'RUNNING','reference_revision':REV,'commands':[]};reference=None
 def save():
  raw=(json.dumps(record,indent=2)+'\n').encode();tmp=out/'result.tmp';tmp.write_bytes(raw);tmp.replace(out/'result.json');return raw
 def read(p):
  raw=p.read_bytes();need(p not in live or live[p]==raw,'LIVE_CHANGED '+str(p));live[p]=raw;return raw
 def stage(name,b):
  need(name not in expected,'DUPLICATE_GENERATED');expected[name]=digest(b);p=out/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b);p.chmod(0o444)
 def git_reference():
  return subprocess.run(['git','-C',str(repo),'show',REV+':src/fpga/rtl/sdram1.sv'],check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30).stdout
 def verify():
  for p,b in live.items():need(p.read_bytes()==b,'LIVE_CHANGED '+str(p))
  for n,h in (expected|logs).items():need(digest((out/n).read_bytes())==h,'GENERATED_OR_LOG_CHANGED '+n)
  if reference is not None:need(git_reference()==reference,'REFERENCE_CHANGED')
 def run(tool,args,label,marker=None,negative=False):
  verify();exe=str(bindir/tool) if bindir else tool;cmd=[exe]+args
  rec={'args':cmd,'cwd':str(out),'executable':shutil.which(exe,path=env['PATH']),'log':label+'.log','environment':{k:env[k] for k in ['PATH','LM_LICENSE_FILE','MGLS_LICENSE_FILE','QUESTA_HOME','MODELSIM'] if k in env}}
  record['commands'].append(rec);save();start=time.monotonic()
  with (out/rec['log']).open('xb') as f:cp=subprocess.run(cmd,cwd=out,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=180)
  raw=(out/rec['log']).read_bytes();logs[rec['log']]=digest(raw);text=raw.decode(errors='replace');rec.update(exit=cp.returncode,seconds=time.monotonic()-start,sha256=digest(raw));save();verify()
  if negative:need(cp.returncode>=0 and re.findall(r'\*\* Fatal:[ \t]*([^\r\n]*)',text)==[marker] and '** Error' not in text and 'PASS cycles=' not in text,'NEGATIVE_ATTRIBUTION '+label)
  else:need(cp.returncode==0 and '** Fatal' not in text and '** Error' not in text and (marker is None or text.count(marker)==1),'COMMAND_FAILED '+label)
  return text
 try:
  package={n:read(home/n) for n in ['test_scsp_lcell.py','test_integrity.py','scsp_tb.sv','lcell_identity.sv','README.md']}
  source=read(repo/'src/fpga/rtl/sdram1.sv');qsf=read(repo/'src/fpga/ap_core.qsf');reference=git_reference()
  need(digest(reference)==PARENT,'REFERENCE_BINDING');need(digest(source)==CANDIDATE,'CANDIDATE_BINDING')
  # Independently invert exactly the two identities and capture RHS substitution.
  start=source.index(b'\n\t// Two explicit');end=source.index(b'\n\tend endgenerate',start)+len(b'\n\tend endgenerate\n');block=source[start:end]
  need(block.count(b'lcell ')==2 and b'hold_bit < 16' in block,'BUFFER_BLOCK')
  need(source.count(b'din2 <= ch2din_hold1;')==1 and (source[:start]+source[end:]).replace(b'din2 <= ch2din_hold1;',b'din2 <= ch2din;')==reference,'SOURCE_INVERSE')
  need(package['lcell_identity.sv']==b'// Local four-state identity model for Intel lcell; no vendor source copied.\nmodule lcell(input wire in, output wire out);\nassign out = in;\nendmodule\n','MODEL_IDENTITY')
  macros=[]
  for line in qsf.decode().splitlines():
   if 'VERILOG_MACRO' not in line:continue
   match=re.fullmatch(r'\s*set_global_assignment\s+-name\s+VERILOG_MACRO\s+"([A-Za-z_][A-Za-z_0-9]*=[A-Za-z_0-9]+)"\s*',line);need(match is not None,'MALFORMED_MACRO_LINE');macros.append(match[1])
  need(len({m.split('=')[0] for m in macros})==len(macros),'DUPLICATE_MACRO')
  relevant=set(re.findall(rb'`ifn?def\s+(\w+)',reference));need(relevant=={b'FRESH_SDRAM1_DIN',b'SDRAM1_RFC_SPACE'},'PREPROCESSOR_SCOPE')
  need(all(macros.count(m.decode()+'=1')==1 for m in relevant),'PRODUCTION_MACROS');record['production_macros']=sorted(m.decode()+'=1' for m in relevant)
  for n,b in package.items():stage('snapshot/package/'+n,b)
  stage('snapshot/source.sv',source);stage('snapshot/reference.sv',reference);stage('snapshot/production.qsf',qsf)
  stage('reference.sv',adapt(reference,True));candidate=adapt(source);stage('candidate.sv',candidate)
  stage('scsp_tb.sv',package['scsp_tb.sv']);stage('lcell_identity.sv',package['lcell_identity.sv'])
  record.update(source_sha256=digest(source),reference_sha256=digest(reference),source_inverse=True)
  run('vlog',['-version'],'version');run('vmap',['-c'],'vmap');run('vlib',['work'],'vlib')
  flags=['-sv']+['+define+'+m for m in record['production_macros']]
  run('vlog',flags+['lcell_identity.sv','reference.sv','candidate.sv','scsp_tb.sv'],'compile')
  for seed in [1,764089157]:
   text=run('vsim',['-c','work.tb',f'+seed={seed}','-do','run -all; quit -f'],'seed_'+str(seed),'PASS cycles=200000')
   need(text.count('COVER_ALL16_DATA_01XZ')==1,'FOURSTATE_COVERAGE')
  old=b'din2 <= ch2din_hold1;';new=b'din2 <= {ch2din_hold1[15:9],ch2din_hold1[9],ch2din_hold1[7:0]};'
  need(candidate.count(old)==1,'MUTANT_ANCHOR');stage('wrong_bit.sv',candidate.replace(old,new))
  run('vlib',['mutant'],'mutant_vlib');run('vlog',['-work','mutant']+flags+['lcell_identity.sv','reference.sv','wrong_bit.sv','scsp_tb.sv'],'mutant_compile')
  run('vsim',['-c','mutant.tb','-do','run -all; quit -f'],'mutant','CAPTURE_MISMATCH cycle=265',True)
  stage('wrong_observable.sv',candidate.replace(old,b"din2 <= ch2din_hold1 ^ 16'h0100;"))
  run('vlib',['observable'],'observable_vlib');run('vlog',['-work','observable']+flags+['lcell_identity.sv','reference.sv','wrong_observable.sv','scsp_tb.sv'],'observable_compile')
  run('vsim',['-c','observable.tb','+observable_only','-do','run -all; quit -f'],'observable_mutant','OBSERVABLE_MISMATCH cycle=270',True)
  record['completed']=True
 except BaseException as e:errors.append(repr(e))
 finally:
  try:
   verify();record['artifacts']={str(p.relative_to(out)):digest(p.read_bytes()) for p in out.rglob('*') if p.is_file() and p.name not in ['result.json','result.tmp']};verify()
  except BaseException as e:errors.append(repr(e))
  record.update(status='FAIL' if errors or not record.get('completed') else 'VERIFIED_PENDING_OUTPUT',errors=errors,live_sha256={str(p):digest(b) for p,b in live.items()},generated_expected=expected,log_expected=logs);save()
 need(record['status']=='VERIFIED_PENDING_OUTPUT','REGRESSION_FAILED '+repr(errors))
 try:
  print('PASS SCSP LCELL',flush=True)
  verify()
  for n,h in record['artifacts'].items():need(digest((out/n).read_bytes())==h,'ARTIFACT_CHANGED '+n)
  verify();record['status']='PASS';terminal=save()
  need((out/'result.json').read_bytes()==terminal,'RECEIPT_CHANGED');verify()
 except BaseException as e:
  record.update(status='FAIL',errors=[repr(e)]);save();raise
if __name__=='__main__':main()
