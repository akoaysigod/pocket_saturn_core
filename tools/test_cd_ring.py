#!/usr/bin/env python3
"""Standalone six-slot cd_ring RTL regression with a byte-array oracle."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

TB = r'''
`timescale 1ns/1ps
module tb;
parameter LE=1;
parameter PHASE=0.5;
parameter WPER=13.468, RPER=8.730;
reg wc=0, rc=0;
always #(WPER/2) wc=~wc;
initial begin #(PHASE); forever #(RPER/2) rc=~rc; end
reg [31:0] addr=0, data=0;
reg wr=0;
reg [13:0] ra=8190;
wire [15:0] q;
cd_ring #(.BRIDGE_LE(LE)) dut(wc,addr,wr,data,rc,ra,q);
// Independent byte-addressed oracle. Integer division/modulo expresses the
// public window and truncation aliases without mirroring the bank organization.
reg [7:0] bytes [0:14111];
integer wi, wb, k;
integer writes=0, rejects=0, oobwrites=0, reads=0, oobreads=0;
integer upperwrites=0, aliasreads=0;
always @(posedge wc) begin
 if(wr) begin
  if ((addr / 268435456 == 4) && (addr % 268435456 < 32768)) begin
   wi = ((addr % 268435456) / 4) % 4096;
   if(wi < 3528) begin
    for(k=0;k<4;k=k+1) bytes[wi*4+k] = LE ? ((data >> (k*8)) & 255) : ((data >> ((3-k)*8)) & 255);
    writes=writes+1;
    if(addr % 268435456 >= 16384) upperwrites=upperwrites+1;
   end else oobwrites=oobwrites+1;
  end else rejects=rejects+1;
 end
end
reg [15:0] expected;
integer ri;
realtime readedge=-100;
always @(posedge rc) begin
 readedge=$realtime;
 ri=ra % 8192;
 expected=16'hxxxx;
 if(ri < 7056) expected={bytes[ri*2+1],bytes[ri*2]};
 else oobreads=oobreads+1;
 if(ra>=8192)aliasreads=aliasreads+1;
 #0.001;
 reads=reads+1;
 if(q !== expected) $fatal(1,"EXPECT_DATA halfword=%0d word=%0d got=%h expected=%h LE=%0d",ra,ri/2,q,expected,LE);
end
always @(q) begin
 if($realtime>0 && $realtime!=readedge) $fatal(1,"READ_LATENCY output changed outside read edge");
end
function [31:0] pattern(input integer n);
 pattern=(32'h9e3779b9*n)^32'hd36a91c5;
endfunction
task put(input [31:0] a,input [31:0] d);
 begin @(negedge wc); addr=a;data=d;wr=1; @(negedge wc);wr=0; end
endtask
task get(input integer a);
 begin @(negedge rc);ra=a;@(posedge rc);#0.002; end
endtask
integer i,j;
initial begin
 // No defined read/write collision: leave reads at an invalid address while filling.
 for(i=0;i<3528;i=i+1) put(32'h40000000+4*i,pattern(i));
 // Unknown bank writes must touch neither array; baseline unknown index
 // also ignores the write. The following exhaustive scan checks preservation.
 put(32'b010000000000000000x0000000001000,32'hdeadbeef);
 // Unknown read-bank bit must produce full X, not merge matching data bits.
 get(14'b0x000000000100);
 // Every valid halfword, including both sides of bank/sector/end boundaries.
 for(i=0;i<7056;i=i+1)get(i);
 // Upper half of accepted bridge window aliases; low byte bits are ignored.
 ra=8190;
 for(i=0;i<3528;i=i+1)put(32'h40004000+4*i+(i%4),~pattern(i));
 // Entire out-of-range tail in both bridge aliases must not corrupt valid data.
 for(i=3528;i<4096;i=i+1)begin
  put(32'h40000000+4*i,32'hdeadbeef);
  put(32'h40004000+4*i,32'hbad0cafe);
 end
 // Rejected windows: wrong BASE, first address above32KB, high internal bit.
 for(i=0;i<32;i=i+1)begin
  put(32'h50000000+4*i,0);put(32'h40008000+4*i,0);put(32'h41000000+4*i,0);
 end
 // All 14-bit read addresses: valid, upper alias, invalid tail (RTL X only).
 for(i=0;i<16384;i=i+1)get(i);
 // Genuine concurrent ports with independent clocks, deliberately disjoint
 // addresses: writes0..511 while reading bank1; then check written bank0.
 fork
  begin for(i=0;i<512;i=i+1)put(32'h40000000+4*i,pattern(i+9000));end
  begin for(j=0;j<1024;j=j+1)get(4096+j);end
 join
 for(i=0;i<1024;i=i+1)get(i);
 #30;
 $display("PASS LE=%0d phase=%0.1f reads=%0d writes=%0d upper=%0d rejected=%0d out_of_range_writes=%0d out_of_range_reads=%0d read_aliases=%0d",LE,PHASE,reads,writes,upperwrites,rejects,oobwrites,oobreads,aliasreads);
 $finish;
end
initial begin #3000000;$fatal(1,"TIMEOUT");end
endmodule
'''

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source', type=Path,
                    default=Path(__file__).resolve().parents[1] / 'src/fpga/glue/cd_ring.sv')
    ap.add_argument('--out', type=Path, help='Fresh directory; existing paths are rejected')
    args = ap.parse_args()
    source = args.source.resolve()
    rtl = source.read_text()
    out = args.out.resolve() if args.out else Path(tempfile.mkdtemp(prefix='cd-ring-'))
    if args.out:
        out.mkdir(parents=True, exist_ok=False)
    results = []
    receipt = dict(source=str(source), source_sha256=sha(source),
                   script_sha256=sha(Path(__file__)), results=results, passed=False)
    print(f'Artifacts: {out}', flush=True)

    def run(command, name):
        try:
            p = subprocess.run(command, cwd=out, text=True, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, timeout=120)
            (out / name).write_text(p.stdout)
            return p
        except subprocess.TimeoutExpired as exc:
            (out / name).write_text(str(exc))
            raise RuntimeError(f'Timeout: {name}') from exc

    try:
        (out / 'source.sv').write_text(rtl)
        (out / 'tb.sv').write_text(TB)
        # Mutation anchors deliberately fail closed on unsupported source shapes.
        # Mutate actual public source, not the stimulus or expected-byte oracle.
        drop, count = re.subn(r'(\bwire\s+we\s*=\s*)([^;]+);',
            r"\1(\2) && (bridge_addr[13:2] != 12'd3527);", rtl)
        if count != 1:
            raise RuntimeError('Expected exactly one write-enable mutation anchor')
        swap, count = re.subn(
            r'assign\s+q\s*=\s*half\s*\?\s*q32\[31:16\]\s*:\s*q32\[15:0\]\s*;',
            'assign q = half ? q32[15:0] : q32[31:16];', rtl)
        if count not in (1, 2):
            raise RuntimeError('Expected one/two half-select mutation anchors')
        (out / 'drop_last.sv').write_text(drop)
        (out / 'swap_halves.sv').write_text(swap)
        configurations = [('positive', le, wp, rp, phase)
                          for le in (0, 1) for wp, rp in ((13.468, 8.730), (14, 22),
                              (13.468, 18.605274), (13.468, 17.460295),
                              (13.468, 18.735363), (13.468, 17.582418))
                          for phase in (0.5, 2.5)]
        configurations += [(kind, le, 13.468, 8.730, 0.5)
                           for kind in ('drop_last', 'swap_halves') for le in (0, 1)]
        for index, (kind, le, wp, rp, phase) in enumerate(configurations):
            name = f'{index:02d}_{kind}_le{le}_w{wp}_r{rp}_p{phase}'
            src = 'source.sv' if kind == 'positive' else kind + '.sv'
            compile_cmd = ['iverilog', '-g2012', '-s', 'tb', f'-Ptb.LE={le}',
                           f'-Ptb.WPER={wp}', f'-Ptb.RPER={rp}', f'-Ptb.PHASE={phase}',
                           '-o', name + '.vvp', src, 'tb.sv']
            cp = run(compile_cmd, name + '.compile.log')
            if cp.returncode:
                raise RuntimeError(f'Compile failed: {name}')
            rp_result = run(['vvp', name + '.vvp'], name + '.log')
            output = rp_result.stdout
            marker = {'drop_last': 'EXPECT_DATA halfword=7054 word=3527',
                      'swap_halves': 'EXPECT_DATA halfword=0 word=0'}.get(kind)
            passed = (rp_result.returncode == 0 and output.count('PASS ') == 1
                      and 'FATAL:' not in output) if marker is None else (
                          rp_result.returncode != 0 and output.count('FATAL:') == 1
                          and marker in output and 'PASS ' not in output)
            results.append(dict(name=name, compile_command=compile_cmd,
                                run_command=['vvp', name + '.vvp'],
                                returncode=rp_result.returncode, accepted=passed,
                                expected_diagnostic=marker, output=output.strip()))
            if not passed:
                raise RuntimeError(f'Unexpected result: {name}\n{output}')
        if sha(source) != receipt['source_sha256']:
            raise RuntimeError('Source changed during test')
        receipt['passed'] = True
        print('PASS: 24 positive configurations; 4 precise mutation rejections')
    finally:
        receipt['artifact_sha256'] = {p.name: sha(p) for p in sorted(out.iterdir())
                                      if p.is_file() and p.name != 'results.json'}
        (out / 'results.json').write_text(json.dumps(receipt, indent=2) + '\n')


if __name__ == '__main__':
    main()
