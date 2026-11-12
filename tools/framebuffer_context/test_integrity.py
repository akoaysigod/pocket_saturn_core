#!/usr/bin/env python3
"""Bounded runner integrity controls; mock execution is explicitly separate from RTL tests."""
import argparse,contextlib,hashlib,importlib.util,io,json,shutil,subprocess,sys
from pathlib import Path
from unittest.mock import patch

def main():
    if not __debug__:raise RuntimeError('OPTIMIZED_PYTHON_REJECTED')
    ap=argparse.ArgumentParser();ap.add_argument('--repo',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args();o=a.output.resolve();o.mkdir(parents=True,exist_ok=False);home=Path(__file__).resolve().parent
    summary=[]
    for case in ['generated','live_source','late_generated','artifact_read_error','pass_print_error','malformed_macro','pass_print_mutation']:
        root=o/case;pkg=root/'package';repo=root/'repo';pkg.mkdir(parents=True)
        for p in home.iterdir():
            if p.suffix in ['.py','.sv','.md'] or p.name=='LICENSE':shutil.copyfile(p,pkg/p.name)
        for rel in ['src/fpga/ap_core.qsf']+['src/fpga/glue/'+n for n in ['fb_queue.sv','vdp1fb_ext.sv','psram_phy.sv','fb_sram.sv']]:
            p=repo/rel;p.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(a.repo/rel,p)
        if case=='malformed_macro':
            q=repo/'src/fpga/ap_core.qsf';q.write_bytes(q.read_bytes()+b'\nset_global_assignment -name VERILOG_MACRO "IGNORED_EXTRA=1" -definitely_invalid_option\n');
        out=root/'run';spec=importlib.util.spec_from_file_location('tested_runner',pkg/'test_framebuffer.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
        fired=['malformed_macro'] if case=='malformed_macro' else [];original_rglob=Path.rglob;original_print=print
        def mutate(p):p.chmod(0o644);p.write_bytes(p.read_bytes()+b'\n// injected mutation\n');fired.append(case)
        def fake_run(args,**kw):
            log=Path(kw['stdout'].name).name
            markers={'miter_tb.log':'PASS_CONTEXT_MITER checks=8192 unknown_identical=2048','api_positional.log':'PASS framebuffer attributes','api_named.log':'PASS framebuffer attributes','queue_scoreboard.log':'PASS_FB_DIRECTED','native_tb.log':'PASS_CONTEXT','ternary.log':'** Fatal: CONTEXT_MITER queue=0 slot=0 pattern=1 code=512','wrongblock.log':'** Fatal: FB_CONTEXT_ADDRESS queue=1'}
            kw['stdout'].write((markers.get(log,'mock tool response')+'\n').encode())
            if log=='version.log' and case in ['generated','live_source']:
                mutate(out/'queue_dut.sv' if case=='generated' else repo/'src/fpga/glue/fb_queue.sv')
            return subprocess.CompletedProcess(args,0)
        def injected_rglob(p,pattern):
            if p==out and not fired:
                if case=='late_generated':mutate(out/'queue_dut.sv')
                if case=='artifact_read_error':fired.append(case);raise OSError('INJECTED_ARTIFACT_READ_ERROR')
            return original_rglob(p,pattern)
        def injected_print(*args,**kw):
            if case=='pass_print_mutation' and args==('PASS FRAMEBUFFER CONTEXT',):mutate(out/'queue_dut.sv')
            if case=='pass_print_error' and args==('PASS FRAMEBUFFER CONTEXT',):fired.append(case);raise OSError('INJECTED_PASS_PRINT_ERROR')
            return original_print(*args,**kw)
        stream=io.StringIO();raised=None
        with patch.object(sys,'argv',['test_framebuffer.py','--repo',str(repo),'--output',str(out)]),patch.object(m.subprocess,'run',fake_run),patch.object(Path,'rglob',injected_rglob),patch('builtins.print',injected_print),contextlib.redirect_stdout(stream):
            try:m.main()
            except Exception as error:raised=repr(error)
        receipt=json.loads((out/'result.json').read_text());expected={'generated':'GENERATED_OR_LOG_CHANGED','live_source':'LIVE_CHANGED','late_generated':'GENERATED_OR_LOG_CHANGED','artifact_read_error':'INJECTED_ARTIFACT_READ_ERROR','pass_print_error':'INJECTED_PASS_PRINT_ERROR','malformed_macro':'MALFORMED_MACRO_LINE','pass_print_mutation':'GENERATED_OR_LOG_CHANGED'}[case]
        if not(fired and raised and receipt['status']=='FAIL' and expected in str(receipt['errors']) and (case=='pass_print_mutation' or 'PASS FRAMEBUFFER CONTEXT' not in stream.getvalue())):raise RuntimeError('CONTROL_FAILED '+case)
        summary.append({'case':case,'status':'PASS_REJECTED','error':raised,'receipt_sha256':hashlib.sha256((out/'result.json').read_bytes()).hexdigest()})
    (o/'result.json').write_text(json.dumps({'status':'PASS','scope':'mocked child tools, real runner source/snapshot/generated/finalization checks; not RTL simulation','runner_sha256':hashlib.sha256((home/'test_framebuffer.py').read_bytes()).hexdigest(),'cases':summary},indent=2)+'\n');print('PASS integrity controls')
if __name__=='__main__':main()
