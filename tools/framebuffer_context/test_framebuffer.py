#!/usr/bin/env python3
"""Public producer-context regression; only --repo public RTL/QSF and local fixtures."""
import argparse,hashlib,json,os,re,shutil,subprocess,sys,time
from pathlib import Path

def need(ok,message):
    if not ok: raise RuntimeError(message)
def digest(raw): return hashlib.sha256(raw).hexdigest()
def normalize(source):
    lines=''.join(re.findall(r'^\twire\s+pa_(?:req|clr)\s*=[^\n]*\n',source,re.M))
    need(len(lines.splitlines())==2,'NORMALIZATION_DECLARATIONS')
    before='\t// slots in use: queued commands + the burst being popped (or its last word not yet cleared)\n'
    after="\t// lanes to zero); read port: the next word of the burst (the burst's first word at the take)\n"
    out=source.replace(lines,'').replace(before,lines+before)
    need(out.replace(lines+before,before).replace(after,after+lines)==source,'NORMALIZATION_INVERSE')
    return out

def main():
    need(__debug__,'OPTIMIZED_PYTHON_REJECTED')
    parser=argparse.ArgumentParser();parser.add_argument('--repo',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);a=parser.parse_args()
    repo=a.repo.resolve();out=a.output.resolve();home=Path(__file__).resolve().parent
    need(not out.exists(),'FRESH_OUTPUT_REQUIRED');out.mkdir(parents=True)
    record={'status':'RUNNING','commands':[]};live={};expected={};logs={};errors=[]
    def save():
        tmp=out/'result.tmp';tmp.write_text(json.dumps(record,indent=2)+'\n');tmp.replace(out/'result.json')
    def read(p):
        raw=p.read_bytes();live[p]=raw;return raw
    def stage(name,raw):
        need(name not in expected,'DUPLICATE_GENERATED '+name)
        expected[name]=digest(raw) # intended content BEFORE write
        p=out/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(raw);p.chmod(0o444)
    def verify():
        for p,raw in live.items():need(p.read_bytes()==raw,'LIVE_CHANGED '+str(p))
        for name,h in (expected|logs).items():need(digest((out/name).read_bytes())==h,'GENERATED_OR_LOG_CHANGED '+name)
    def run(args,label,marker=None,negative=False):
        verify();start=time.monotonic()
        # Record the actual invocation/environment before starting the child.
        command={'args':args,'cwd':str(out),'executable':shutil.which(args[0]),'environment':{k:os.environ[k] for k in ['PATH','LM_LICENSE_FILE','MGLS_LICENSE_FILE','QUESTA_HOME','MODELSIM'] if k in os.environ},'log':label+'.log'}
        record['commands'].append(command);save()
        with (out/command['log']).open('xb') as f:
            cp=subprocess.run(args,cwd=out,stdout=f,stderr=subprocess.STDOUT,timeout=600)
        raw=(out/command['log']).read_bytes();logs[command['log']]=digest(raw);text=raw.decode(errors='replace')
        command.update(exit=cp.returncode,seconds=time.monotonic()-start,sha256=digest(raw));save();verify()
        if negative:
            need(cp.returncode>=0 and text.count('** Fatal: '+marker)==1 and '** Error' not in text and 'PASS_' not in text,'NEGATIVE_ATTRIBUTION '+label)
        else:need(cp.returncode==0 and '** Fatal' not in text and '** Error' not in text and (marker is None or text.count(marker)==1),'COMMAND_FAILED '+label)
    try:
        package=['test_framebuffer.py','reference_queue.sv','reference_producer.sv','native_tb.sv','miter_tb.sv','api_positional.sv','api_named.sv','queue_scoreboard.sv','LICENSE','README.md']
        pbytes={n:read(home/n) for n in package}
        paths={n:repo/'src/fpga'/rel for n,rel in [('queue','glue/fb_queue.sv'),('producer','glue/vdp1fb_ext.sv'),('phy','glue/psram_phy.sv'),('sram','glue/fb_sram.sv'),('qsf','ap_core.qsf')]}
        source={n:read(p) for n,p in paths.items()}
        pins={'queue':'5e087a8c1e29ad52238eba1b68408d588aecf2c1104b5f50cd3c2e58649599ed','producer':'ca0da9f344323e967bec9ce458be28bd53aaedf2e092a1e929ef1d336d9ac67e','phy':'e44090e5043b9b64be5c1dc14335c345971754cb99d90d366a33684dec322742','sram':'2e329f54edf4df040a76ffcf04833bcb1a94ad15ea88311c38415683cf83f9a4'}
        for n,h in pins.items():need(digest(source[n])==h,'SOURCE_REVISION '+n)
        need(digest(pbytes['reference_queue.sv'])=='f5501947080dbb887775f28f67acb6bd427cb9713766ac778726d982c7fd29cf','REFERENCE_QUEUE')
        need(digest(pbytes['reference_producer.sv'])=='aeeb36c76b707223f5d8a531848904232d09301c9b27db52a260109a3c53e19c','REFERENCE_PRODUCER')
        for n,b in pbytes.items():stage('snapshot/package/'+n,b)
        for n,b in source.items():stage('snapshot/source/'+n,b)
        q=source['queue'].decode();p=source['producer'].decode()
        bad=q.replace('ctx_draw_block == oblk[1]','ctx_draw_block[AW-6:3] == oblk[1][BW-1:3]').replace('ctx_draw_block == oblk[0]','ctx_draw_block[AW-6:3] == oblk[0][BW-1:3]')
        tern=q.replace('ctx_pref_equal[k][ctx_pref_sel]','(ctx_pref_sel ? ctx_eq_pref1[k] : ctx_eq_pref0[k])')
        need(bad!=q and tern!=q,'MUTATION_NOT_APPLIED')
        for name,queue,producer in [('ref',pbytes['reference_queue.sv'].decode(),pbytes['reference_producer.sv'].decode()),('dut',q,p),('bad',bad,p),('tern',tern,p)]:
            stage('queue_'+name+'.sv',normalize(queue).replace('module fb_queue #(','module queue_'+name+' #(').encode())
            stage('producer_'+name+'.sv',producer.replace('module vdp1fb_ext #(','module producer_'+name+' #(').replace('fb_queue #(','queue_'+name+' #(').encode())
        for n in ['native_tb.sv','miter_tb.sv','api_positional.sv','api_named.sv','queue_scoreboard.sv']:stage(n,pbytes[n])
        stage('psram_phy.sv',source['phy']);stage('fb_sram.sv',source['sram'])
        macros=[]
        for line in source['qsf'].decode().splitlines():
            if 'VERILOG_MACRO' not in line:continue
            match=re.fullmatch(r'set_global_assignment -name VERILOG_MACRO "([A-Za-z_][A-Za-z_0-9]*=[A-Za-z_0-9]+)"',line)
            need(match is not None,'MALFORMED_MACRO_LINE '+line)
            macros.append(match.group(1))
        need(len(macros)==71 and len(set(macros))==71,'PRODUCTION_MACROS');record['macros']=macros
        flags=['vlog','-sv']+['+define+'+m for m in macros]
        run(['vlog','-version'],'version');run(['vlib','work'],'library')
        run(flags+[n for n in expected if '/' not in n and n.endswith('.sv')],'compile')
        for top,marker in [('miter_tb','PASS_CONTEXT_MITER checks=8192 unknown_identical=2048'),('api_positional','PASS framebuffer attributes'),('api_named','PASS framebuffer attributes'),('queue_scoreboard','PASS_FB_DIRECTED'),('native_tb','PASS_CONTEXT')]:
            run(['vsim','-c','work.'+top,'+seed=17','-do','run -all; quit -f'],top,marker)
        run(flags+['+define+WRONG_TERNARY','miter_tb.sv'],'ternary_compile')
        run(['vsim','-c','work.miter_tb','-do','run -all; quit -f'],'ternary','CONTEXT_MITER queue=0 slot=0 pattern=1 code=512',True)
        run(flags+['+define+WRONG_BLOCK','native_tb.sv'],'wrongblock_compile')
        run(['vsim','-c','work.native_tb','+seed=17','-do','run -all; quit -f'],'wrongblock','FB_CONTEXT_ADDRESS queue=1',True)
        record['completed']=True
    except BaseException as error:errors.append(repr(error))
    finally:
        try:
            verify();record['artifacts']={str(p.relative_to(out)):digest(p.read_bytes()) for p in out.rglob('*') if p.is_file() and p.name not in ['result.json','result.tmp']};verify()
        except BaseException as error:errors.append(repr(error))
        record.update(status='FAIL' if errors or not record.get('completed') else 'VERIFIED_PENDING_OUTPUT',errors=errors,live_sha256={str(p):digest(b) for p,b in live.items()},generated_expected=expected,log_expected=logs)
        save()
    need(record['status']=='VERIFIED_PENDING_OUTPUT','REGRESSION_FAILED '+repr(errors))
    try:
        print('PASS FRAMEBUFFER CONTEXT')
        # Printing may invoke external hooks: no terminal PASS receipt until closure.
        verify()
        for name,h in record['artifacts'].items():
            need(digest((out/name).read_bytes())==h,'ARTIFACT_CHANGED '+name)
        verify()
        record['status']='PASS';save()
    except BaseException as error:
        record.update(status='FAIL',errors=[repr(error)]);save();raise
if __name__=='__main__':main()
