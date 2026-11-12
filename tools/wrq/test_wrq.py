#!/usr/bin/env python3
"""Public WRQ regression. See WRQ_TEST.md; fresh output required."""
import argparse,hashlib,json,re,subprocess,sys,time
from pathlib import Path
D=Path(__file__).resolve().parent
REFERENCE='77fae10e6da2f444bfbafc0551fdedcb77911c37'
FILES={'queue':'src/fpga/glue/wr_queue.sv','owner':'src/fpga/pocket_rtl/psram0_arb.sv','phy':'src/fpga/glue/psram_phy.sv','qsf':'src/fpga/ap_core.qsf'}
def sha(b):return hashlib.sha256(b).hexdigest()
def require(ok,msg):
 if not ok:raise RuntimeError(msg)
def once(s,a,b):
 require(s.count(a)==1,'anchor count: '+a);return s.replace(a,b)
def normalize_owner(source, name):
    declaration = "\tlocalparam bit          rhc_on  = 1'b1;\n"
    anchor = '\tlogic [31:0] dt_qa;              // (A8) the cache\'s longword at the live address\n'
    previous = '`else\n\tlocalparam bit [SL-1:0] rhc_msk'
    result = once(source, declaration, '')
    result = once(result, anchor, declaration + anchor)
    restored = once(result, declaration + anchor, anchor)
    restored = once(restored, previous, '`else\n' + declaration + previous[len('`else\n'):])
    require(restored == source, 'owner normalization inverse differs')
    return once(result, 'module psram0_arb #(', 'module ' + name + ' #(')

def normalize_queue(source):
    declarations = ''.join(re.findall(r'^.*\bwire\s+cfull_n\s*=.*\n|^.*\bwire\s+dfull_n\s*=.*\n', source, re.M))
    require(len(declarations.splitlines()) == 2, 'queue declaration count')
    anchor = '\tassign full      = full_r;\n'
    matches = re.findall(r'^\twire mv_n[^\n]*\n', source, re.M)
    require(len(matches) == 1, 'queue previous declaration anchor')
    previous = matches[0]
    result = once(source, declarations, '')
    result = once(result, anchor, declarations + anchor)
    restored = once(result, declarations + anchor, anchor)
    restored = once(restored, previous, previous + declarations)
    require(restored == source, 'queue normalization inverse differs')
    return result

def main():
 require(__debug__,'Optimized Python unsupported')
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--repo',type=Path,required=True);ap.add_argument('--out',type=Path,required=True)
 args=ap.parse_args();repo=args.repo.resolve();O=args.out.resolve()

 O.mkdir(parents=True,exist_ok=False);receipt={'status':'RUNNING','commands':[],'reference_revision':REFERENCE,'repository':str(repo),'python':sys.version};tracked={};expected={};errors=[]
 def save(): (O/'result.json').write_text(json.dumps(receipt,indent=2)+'\n')
 def capture(p):
  b=p.read_bytes();tracked[p]=sha(b);return b
 def stage(name,b):
  expected[name]=sha(b);p=O/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b);p.chmod(0o444)
 def verify():
  for p,h in list(tracked.items())+[(O/n,h) for n,h in expected.items()]:
   try:require(sha(p.read_bytes())==h,'INPUT_CHANGED '+str(p))
   except Exception as e:errors.append(str(e))
 def run(argv,name,marker='',negative=False):
  verify();require(not errors,';'.join(errors));start=time.monotonic();log=O/(name+'.log')
  with log.open('w') as f:p=subprocess.run(argv,cwd=O,stdout=f,stderr=subprocess.STDOUT,timeout=300)
  raw=log.read_bytes();tracked[log]=sha(raw);text=raw.decode(errors='replace');receipt['commands'].append({'argv':argv,'exit':p.returncode,'log':log.name,'sha256':sha(raw),'seconds':round(time.monotonic()-start,2)});save()
  if negative:require(text.count('** Fatal: '+marker)==1 and not re.search(r'PASS_|\*\* Error',text) and p.returncode>=0,'wrong negative diagnostic '+name)
  else:require(p.returncode==0 and (not marker or text.count(marker)==1) and not re.search(r'\*\* (?:Error|Fatal)|FATAL:',text),'tool/test failed '+name)
  print(name,'EXPECTED_REJECTION' if negative else 'PASS',flush=True)
 save()
 try:
  capture(Path(__file__))
  inputs={k:capture(repo/n) for k,n in FILES.items()}
  inputs.update({k:capture(D/n) for k,n in {'queue_tb':'wrq_queue_tb.sv','fourstate_tb':'wrq_fourstate_tb.sv','native_tb':'wrq_native_tb.sv'}.items()})
  reference={}
  for k,n in FILES.items():
   proc=subprocess.run(['git','-C',str(repo),'show',REFERENCE+':'+n],capture_output=True,timeout=30)
   require(proc.returncode==0,'Missing local Git reference '+REFERENCE+':'+n);reference[k]=proc.stdout
   stage('snapshot/reference/'+k,proc.stdout)
  for k,b in inputs.items():stage('snapshot/live/'+k,b)
  receipt['reference_sha256']={k:sha(b) for k,b in reference.items()}
  require(sha(reference['queue'])=='36b6e33f29879acf0f7013d06b4dfb6e4221396819b6407690bd5b1eb68539f5','pinned77 queue')
  for k in ['owner','phy']:require(inputs[k]==reference[k],'Unexpected shared source change: '+k)
  hold_append=b'\nset_global_assignment -name SDC_FILE pocket_hold_margin.sdc\n'
  lite=b'set_global_assignment -name LAST_QUARTUS_VERSION "25.1std.0 Lite Edition"'
  standard=b'set_global_assignment -name LAST_QUARTUS_VERSION "25.1std.0 Standard Edition"'
  require(reference['qsf'].count(lite)==1,'Full-build QSF metadata anchor')
  full_qsf=reference['qsf'].replace(lite,standard)+b'\nset_global_assignment -name NUM_PARALLEL_PROCESSORS 8\n'+hold_append
  require(sha(full_qsf)=='a19c6fd3233f146ab8ef5d5c5046e143dc0f11f4d5df3f5871424997043c199b','Full-build QSF recipe hash')
  require(inputs['qsf'] in [reference['qsf'],reference['qsf']+hold_append,full_qsf],'Unexpected shared source change: qsf')
  receipt['qsf_admission']='baseline'
  if inputs['qsf']!=reference['qsf']:
   hold=capture(repo/'src/fpga/pocket_hold_margin.sdc')
   require(sha(hold)=='06abbc75b6843127901e3c007487502c7ef813284bf1ed00a281ef6bc162312b','Unexpected hold SDC bytes')
   stage('snapshot/live/hold_sdc',hold)
   receipt['qsf_admission']='frozen_full_build_recipe' if inputs['qsf']==full_qsf else 'exact_baseline_plus_hold_sdc'
   receipt['hold_sdc_sha256']=sha(hold)
  old="{o_len + 5'd1, o_next[AW-1:5], o_lo}";new="{o_len + 5'd1, req_addr[AW-1:5], o_lo}"
  source=reference['queue'].decode();candidate=inputs['queue'].decode();require(candidate==once(source,old,new),'Checkout must contain exact reviewed one-expression WRQ change')
  require(once(candidate,new,old)==source,'exact inverse')
  receipt['candidate_sha256']=sha(inputs['queue']);receipt['one_expression_inverse']=True
  # Known-true merge implies logical equality returned1, including all address bits.
  bad=once(candidate,new,"{o_len + 5'd1, (req_addr[AW-1:5] ^ {{(AW-6){1'b0}},1'b1}), o_lo}")
  for name,t in [('ref',source),('dut',candidate),('bad',bad)]:
   norm=normalize_queue(t);stage('queue_'+name+'.sv',once(norm,'module wr_queue #(','module queue_'+name+' #(').encode())
   owner=normalize_owner(inputs['owner'].decode(),'owner_'+name).replace('wr_queue #(','queue_'+name+' #(')
   stage('owner_'+name+'.sv',owner.encode())
  stage('psram_phy.sv',inputs['phy']);stage('tb.sv',inputs['native_tb']);stage('fourstate_tb.sv',inputs['fourstate_tb'])
  tb=inputs['queue_tb'].decode();start=tb.index('task check;');end=tb.index('endtask',start)+len('endtask')
  original=tb[start:end]
  observable='''task check;
 checks++;
 if (rv === 1'b1 && dv === 1'b1 && ra !== da)
   $fatal(1,"WRQ_OBSERVABLE_ADDRESS check=%0d ref=%h dut=%h",checks,ra,da);
endtask'''
  adapted=tb[:start]+'`ifdef OBSERVABLE_ONLY\n'+observable+'\n`else\n'+original+'\n`endif\n'+tb[end:]
  require(adapted.replace('`ifdef OBSERVABLE_ONLY\n'+observable+'\n`else\n'+original+'\n`endif\n',original)==tb,'bench adapter inverse')
  stage('queue_tb.sv',adapted.encode())
  qsf=inputs['qsf'].decode();macros=re.findall(r'^\s*set_global_assignment\s+-name\s+VERILOG_MACRO\s+"([^"\n]+)"\s*$',qsf,re.M)
  require(len(macros)==71==len(re.findall(r'^\s*set_global_assignment\s+-name\s+VERILOG_MACRO\b',qsf,re.M)) and len({m.split('=')[0] for m in macros})==71,'macro set');receipt['macros']=macros
  receipt['scope']='Public queue plus arbiter/PHY simulation, no physical timing/hardware qualification'
  run(['vlog','-version'],'vlog_version');run(['vsim','-version'],'vsim_version');run(['vlib','work'],'vlib')
  flags=['vlog','-sv','-timescale','1ns/1ps']+['+define+'+m for m in macros]
  run(flags+[n for n in expected if n.endswith('.sv')],'compile')
  run(['vsim','-c','work.fourstate_tb','-do','run -all; quit -f'],'fourstate','PASS_FOURSTATE')
  for seed in [1,17,981]:run(['vsim','-c','work.queue_tb','+seed='+str(seed),'-do','run -all; quit -f'],'queue_'+str(seed),'PASS_QUEUE')
  run(['vsim','-c','work.queue_tb','-gCD=4','-gDD=6','-do','run -all; quit -f'],'queue_large','PASS_QUEUE')
  for seed in [1,17,981]:run(['vsim','-c','work.tb','+seed='+str(seed),'-do','run -all; quit -f'],'native_'+str(seed),'PASS native owner')
  run(flags+['+define+MUTANT','+define+OBSERVABLE_ONLY','queue_tb.sv'],'mutant_compile')
  run(['vsim','-c','work.queue_tb','-do','run -all; quit -f'],'mutant','WRQ_OBSERVABLE_ADDRESS',True)
  run(['vlog','-sv','-timescale','1ns/1ps','queue_ref.sv','queue_dut.sv','queue_bad.sv','queue_tb.sv'],'legacy_compile')
  run(['vsim','-c','work.queue_tb','-do','run -all; quit -f'],'queue_legacy','PASS_QUEUE')
  receipt['semantic_checks_complete']=True
 except Exception as e:errors.append(str(e))
 finally:
  verify()
  try:receipt['artifacts']={str(p.relative_to(O)):sha(p.read_bytes()) for p in O.rglob('*') if p.is_file() and p.name!='result.json'}
  except Exception as e:errors.append(str(e))
  verify();receipt['live_expected_sha256']={str(p):h for p,h in tracked.items()};receipt['generated_expected_sha256']=expected;receipt['errors']=errors
  receipt['status']='FAIL' if errors or not receipt.get('semantic_checks_complete') else 'VERIFIED_PENDING_OUTPUT'
  save()
 require(receipt['status']=='VERIFIED_PENDING_OUTPUT',str(errors))
 try:
  print('PASS PUBLIC WRQ',flush=True)
  verify();require(not errors,str(errors))
  for name,h in receipt['artifacts'].items():require(sha((O/name).read_bytes())==h,'ARTIFACT_CHANGED '+name)
  verify();require(not errors,str(errors))
  receipt['status']='PASS';save()
  terminal=(O/'result.json').read_bytes()
  require(json.loads(terminal)==receipt,'RECEIPT_CHANGED')
  verify();require(not errors,str(errors))
 except BaseException as error:
  receipt['status']='FAIL';receipt['errors'].append('Terminal output failure: '+str(error));save();raise
if __name__=='__main__':main()
