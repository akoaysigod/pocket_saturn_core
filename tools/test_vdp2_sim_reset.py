#!/usr/bin/env python3
"""Compile actual VDP2 and check seeded bus/latch/sorter behavior (not full frames)."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    script = Path(__file__).resolve()
    root = script.parents[1]
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source', type=Path, default=root/'src/fpga/rtl/Saturn/VDP2/VDP2.sv')
    ap.add_argument('--package', type=Path, help='Default: VDP2_pkg.sv beside --source')
    ap.add_argument('--qsf', type=Path, default=root/'src/fpga/ap_core.qsf')
    ap.add_argument('--out', type=Path, help='Fresh artifact directory (default: temporary)')
    args = ap.parse_args()
    out = args.out.resolve() if args.out else Path(tempfile.mkdtemp(prefix='vdp2-sim-'))
    if args.out:
        out.mkdir(parents=True, exist_ok=False)
    source = args.source.resolve()
    package = (args.package or source.with_name('VDP2_pkg.sv')).resolve()
    qsf = args.qsf.resolve()
    fixture = script.parent/'vdp2_sim_reset'
    inputs = {'VDP2.sv': source, 'VDP2_pkg.sv': package, 'ap_core.qsf': qsf,
              'probe.sv': fixture/'probe.sv', 'memory_stub.sv': fixture/'memory_stub.sv'}
    receipt = {'passed': False, 'scope': 'Seeded checkpoints; not native frame/video qualification',
               'runner_sha256': digest(script), 'commands': [], 'results': []}
    print(f'Artifacts: {out}', flush=True)

    def run(cmd, name, limit):
        receipt['commands'].append({'argv': cmd, 'cwd': str(out), 'timeout_seconds': limit})
        with (out/name).open('w') as log:
            try:
                result = subprocess.run(cmd, cwd=out, stdout=log, stderr=subprocess.STDOUT,
                                        timeout=limit)
            except subprocess.TimeoutExpired as exc:
                raise RuntimeError(f'Timeout: {name}') from exc
        return result.returncode, (out/name).read_text()

    try:
        snapshots = {name: path.read_bytes() for name, path in inputs.items()}
        receipt['inputs'] = {name: {'path': str(inputs[name]),
                                   'sha256': hashlib.sha256(data).hexdigest()}
                             for name, data in snapshots.items()}
        for name, data in snapshots.items():
            (out/name).write_bytes(data)
        rc, version = run(['verilator', '--version'], 'verilator.version.log', 15)
        if rc or not re.search(r'Verilator 5\.', version):
            raise RuntimeError('Requires Verilator 5.x')
        macros = re.findall(r'^set_global_assignment -name VERILOG_MACRO "([^"]+)"',
                            snapshots['ap_core.qsf'].decode(), re.M)
        macro_lines = [line for line in snapshots['ap_core.qsf'].decode().splitlines()
                       if re.match(r'^\s*set_global_assignment\b', line)
                       and re.search(r'\bVERILOG_MACRO\b', line)]
        if len(macros) != len(macro_lines):
            raise RuntimeError('Unsupported QSF macro assignment syntax')
        if not macros or len(macros) != len({macro.split('=', 1)[0] for macro in macros}):
            raise RuntimeError('Missing or duplicate QSF macro definitions')
        receipt['macros'] = macros
        text = snapshots['VDP2.sv'].decode()
        mutant, count = re.subn(
            r'(if\s*\(!REGS\.TVMD\.DISP\s*&&\s*DISP_INT\)\s*DISP_INT\s*<=\s*)0;',
            r'\g<1>1;', text)
        if count != 1:
            raise RuntimeError('Expected exactly one display-disable latch mutation anchor')
        (out/'VDP2_disable_mutant.sv').write_text(mutant)
        for name, rtl in [('positive', 'VDP2.sv'), ('disable_mutant', 'VDP2_disable_mutant.sv')]:
            cmd = ['verilator', '--binary', '--timing', '-Wno-fatal', '--top-module', 'probe',
                   '-j', '2', '--Mdir', 'obj_'+name] + ['-D'+m for m in macros] + [
                       'VDP2_pkg.sv', rtl, 'memory_stub.sv', 'probe.sv']
            rc, _ = run(cmd, name+'.compile.log', 240)
            if rc:
                raise RuntimeError(f'Compile failed ({rc}): {name}; not a successful control')
            rc, log = run([str(out/('obj_'+name)/'Vprobe')], name+'.simulation.log', 30)
            passed = (rc == 0 and log.count('PASS checkpoint probe checks=21;') == 1
                      and '%Error' not in log) if name == 'positive' else (
                          rc != 0 and log.count('DISABLE_LATCH') == 1 and 'PASS ' not in log)
            receipt['results'].append({'name': name, 'returncode': rc, 'accepted': passed})
            if not passed:
                raise RuntimeError(f'Unexpected simulation result: {name}')
        if any(digest(path) != receipt['inputs'][name]['sha256'] for name, path in inputs.items()):
            raise RuntimeError('Inputs changed during test')
        if digest(script) != receipt['runner_sha256']:
            raise RuntimeError('Runner changed during test')
        receipt['passed'] = True
        print('PASS: 21 enabled-layer/tie checks plus bus/latch assertions; disable mutant rejected')
    except Exception as exc:
        receipt['error'] = str(exc)
        raise
    finally:
        receipt['artifacts'] = {p.name: digest(p) for p in sorted(out.iterdir())
                                if p.is_file() and p.name != 'results.json'}
        (out/'results.json').write_text(json.dumps(receipt, indent=2)+'\n')


if __name__ == '__main__':
    main()
