#!/usr/bin/env python3
"""Natural-raster VDP2 display admission regression; seeded pixels, public sources only."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile


def sha(data):
    return hashlib.sha256(data).hexdigest()


def macros(text):
    values = []
    names = set()
    for line in text.splitlines():
        if line.lstrip().startswith('#') or 'VERILOG_MACRO' not in line:
            continue
        match = re.fullmatch(r'\s*set_global_assignment -name VERILOG_MACRO "([A-Za-z_]\w*(?:=[A-Za-z0-9_]+)?)"\s*', line)
        if not match:
            raise ValueError('Unsupported QSF macro syntax: '+line)
        value = match[1]
        name = value.split('=')[0]
        if name in names:
            raise ValueError('Duplicate QSF macro: '+name)
        names.add(name)
        values.append(value)
    if not values:
        raise ValueError('No QSF macros')
    return values


def normalize(text):
    # Exact known PR20 repair, exclusively inside existing synthesis exclusions.
    block = re.compile(r'// synopsys translate_off\b.*?// synopsys translate_on\b', re.S)
    edits = []
    def repair(m):
        old = m[0]
        new = old.replace("VA_PIPE <= '{4{'0}};", "VA_PIPE <= '{default:VRAMAccessState_t'{default:'0}};")
        new = re.sub(r"^\t\t\t(?:NBG_CDL\[[0-3]\]|RBG_CDL\[[01]\]) <= '\{8\{'0\}\};\n", '', new, flags=re.M)
        new = re.sub(r'^\t\t\t(?:R0DOT|N[0-3]DOT) <= DD_NULL;\n', '', new, flags=re.M)
        if old != new:
            edits.append((m.start(), old, new))
        return new
    output = block.sub(repair, text)
    # Stronger than token equality: all bytes outside excluded blocks unchanged.
    if block.sub('', output) != block.sub('', text):
        raise ValueError('Normalization changed hardware-visible source')
    restored = output
    before = list(block.finditer(text)); after = list(block.finditer(output))
    if len(before) != len(after):
        raise ValueError('Normalization changed block boundaries')
    for a, b in reversed(list(zip(before, after))):
        restored = restored[:b.start()] + a[0] + restored[b.end():]
    if restored != text:
        raise ValueError('Normalization inverse failed')
    if output.count("VA_PIPE <= '{default:VRAMAccessState_t'{default:'0}};") != 1:
        raise ValueError('Unsupported VA_PIPE simulation reset shape')
    return output, len(edits)


def main():
    script = Path(__file__).resolve(); root = script.parents[1]
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source', type=Path, default=root/'src/fpga/rtl/Saturn/VDP2/VDP2.sv')
    ap.add_argument('--package', type=Path)
    ap.add_argument('--qsf', type=Path, default=root/'src/fpga/ap_core.qsf')
    ap.add_argument('--out', type=Path)
    a = ap.parse_args()
    out = a.out.resolve() if a.out else Path(tempfile.mkdtemp(prefix='vdp2-display-'))
    if a.out: out.mkdir(parents=True, exist_ok=False)
    source = a.source.resolve()
    inputs = {'source.sv': source, 'VDP2_pkg.sv': (a.package or source.with_name('VDP2_pkg.sv')).resolve(),
              'ap_core.qsf': a.qsf.resolve(), 'runner.py': script,
              'probe.sv': script.parent/'vdp2_display/probe.sv',
              'memory_model.sv': script.parent/'vdp2_display/memory_model.sv'}
    receipt = {'passed': False, 'commands': [], 'results': []}
    snapshots = {}; generated = {}
    def unchanged():
        for name, data in generated.items():
            if (out/name).read_bytes() != data:
                raise RuntimeError('Generated source changed: '+name)
        for name, data in snapshots.items():
            if inputs[name].read_bytes() != data:
                raise RuntimeError('Live input changed: '+name)
            if (out/name).read_bytes() != data:
                raise RuntimeError('Snapshot changed: '+name)
    def run(cmd, name, seconds):
        unchanged()
        receipt['commands'].append(dict(argv=cmd, timeout_seconds=seconds))
        with (out/name).open('w') as f:
            r = subprocess.run(cmd, cwd=out, stdout=f, stderr=subprocess.STDOUT, timeout=seconds)
        unchanged()
        return r.returncode, (out/name).read_text()
    try:
        for name, path in inputs.items():
            snapshots[name] = path.read_bytes()
            (out/name).write_bytes(snapshots[name])
        receipt['inputs'] = {n: dict(path=str(inputs[n]), sha256=sha(b)) for n,b in snapshots.items()}
        definitions = macros(snapshots['ap_core.qsf'].decode())
        receipt['macros'] = definitions
        text = snapshots['source.sv'].decode()
        repaired, edits = normalize(text)
        receipt['normalization'] = dict(changed_blocks=edits, hardware_visible_bytes_identical=True, inverse_exact=True)
        (out/'normalization.patch').write_text(''.join(difflib.unified_diff(text.splitlines(True), repaired.splitlines(True), fromfile='source.sv', tofile='simulation.sv')))
        control, count = re.subn(r'(LV\[(?:1|2|3\+k)\] = )DISP_INT( &&)', r'\1DISP\2', repaired)
        # Original source is allowed to reach the semantic test, never auto-fixed.
        if count not in (0, 3): raise RuntimeError('Partial or unsupported LV guard adaptation')
        if count == 0 and len(re.findall(r'LV\[(?:1|2|3\+k)\] = DISP &&', repaired)) != 3:
            raise RuntimeError('Unsupported LV guards')
        generated = {'simulation.sv': repaired.encode(), 'old_guard.sv': control.encode()}
        for name, data in generated.items():
            (out/name).write_bytes(data)
        rc, version = run(['verilator','--version'], 'version.log', 15)
        if rc or not re.search(r'Verilator 5\.', version): raise RuntimeError('Requires Verilator 5.x')
        for name, rtl in [('positive','simulation.sv'),('old_guard','old_guard.sv')]:
            cmd = ['verilator','--binary','--timing','-Wno-fatal','--top-module','probe','-j','2','--Mdir','obj_'+name]
            cmd += ['-D'+m for m in definitions] + ['VDP2_pkg.sv',rtl,'memory_model.sv','probe.sv']
            rc, _ = run(cmd, name+'.compile.log', 240)
            if rc: raise RuntimeError('Compile failure: '+name+' (not a semantic control PASS)')
            for pal in [0,1]:
                for lsmd in [0,3]:
                    rc, log = run([str(out/('obj_'+name)/'Vprobe'),f'+PAL={pal}',f'+LSMD={lsmd}'], f'{name}_pal{pal}_lsmd{lsmd}.log', 120)
                    ok = (rc == 0 and log.count('PASS NATURAL_DISPLAY ')==1 and 'checks=22 ' in log and '%Error' not in log) if name=='positive' else (rc != 0 and log.count('DISPLAY_ADMISSION layer=0 admitted=0')==1 and 'PASS ' not in log)
                    if name=='positive' and lsmd==3: ok = ok and 'field_edges=2' in log
                    receipt['results'].append(dict(name=name,pal=pal,lsmd=lsmd,returncode=rc,accepted=ok))
                    if not ok: raise RuntimeError(f'Unexpected semantic result: {name} PAL={pal} LSMD={lsmd}')
        unchanged()
        if any((out/n).read_bytes()!=b for n,b in generated.items()): raise RuntimeError('Generated source changed')
        receipt['passed'] = True
        print('PASS: four natural-raster cases (22 checks each), four compiled old-guard rejections')
    except Exception as exc:
        receipt['passed'] = False
        receipt['error'] = str(exc)
        raise
    finally:
        final_error = None
        try:
            unchanged()
            receipt['artifacts'] = {str(p.relative_to(out)):sha(p.read_bytes()) for p in out.rglob('*') if p.is_file() and p.name!='results.json'}
            unchanged()
        except Exception as exc:
            receipt['passed'] = False
            receipt['error'] = str(exc)
            final_error = exc
        (out/'results.json').write_text(json.dumps(receipt, indent=2)+'\n')
        print('Artifacts:', out)
        if final_error is not None:
            raise RuntimeError('Final input validation failed: '+str(final_error)) from final_error


if __name__ == '__main__':
    main()
