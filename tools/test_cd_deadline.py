#!/usr/bin/env python3
"""Compile actual CD firmware on the host; exercise deadline publication and its stale-anchor control."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import tempfile


def sha(data):
    return hashlib.sha256(data).hexdigest()


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError(f"Expected exactly one adapter/mutation site: {old!r}")
    return text.replace(old, new, 1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path(__file__).resolve().parents[1] / 'src/fw/cdb')
    parser.add_argument('--cc', default=os.environ.get('CC', 'cc'), help='C compiler executable')
    parser.add_argument('--output', type=Path, required=True, help='New directory for source receipts and full logs')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    result = {'status': 'RUNNING', 'scope': 'Host C controller checkpoint regression; not native CPU, SMPC MCU, media or hardware qualification.', 'cases': []}
    def save():
        (args.output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    save()
    try:
        names = ('cdb_hle.c', 'hw.h', 'rt.h', 'smpc.h', 'cd_src.h')
        inputs = {name: (args.source / name).read_bytes() for name in names}
        harness = Path(__file__).with_name('cd_deadline_harness.c').read_bytes()
        result['input_sha256'] = {name: sha(data) for name, data in inputs.items()}
        result['harness_sha256'] = sha(harness)
        result['runner_sha256'] = sha(Path(__file__).read_bytes())
        fixed = 'smpc_cd_deadline = last + (uint32_t)DriveCounter;'
        stale = 'smpc_cd_deadline = now + (uint32_t)DriveCounter;'
        source = inputs['cdb_hle.c'].decode()
        if source.count(fixed) + source.count(stale) != 1:
            raise ValueError('Expected exactly one known deadline publication site')
        mutant = replace_once(source, fixed, stale) if fixed in source else source
        if fixed in source and replace_once(mutant, stale, fixed) != source:
            raise ValueError('Mutation failed round-trip validation')
        result['mutation'] = {'from': fixed, 'to': stale, 'candidate_sha256': sha(source.encode()), 'stale_sha256': sha(mutant.encode())}
        adapters = {
            '#define IO(o)        (*(volatile uint32_t*)(0x20000000u + (o)))': '#define IO(o)        (*test_io(o))',
            '#define CDRAM(w)     (*(volatile uint32_t*)(0x10000000u + 4u * (w)))': '#define CDRAM(w)     (cdmem[(w)])',
            '*(volatile uint16_t*)(0x10000000u + 4u * w) = v;': 'cdmem[w] = v;',
        }
        header = inputs['hw.h'].decode()
        for old, new in adapters.items():
            header = replace_once(header, old, new)
        result['adapter_substitutions'] = adapters
        result['adapted_hw_sha256'] = sha(header.encode())
        result['compiler'] = subprocess.check_output([args.cc, '--version'], text=True).splitlines()[0]

        with tempfile.TemporaryDirectory(prefix='build-', dir=args.output) as tmp:
            work = Path(tmp).resolve()
            for name, data in inputs.items():
                (work / name).write_bytes(data)
            (work / 'hw.h').write_text(header)
            (work / 'harness.c').write_bytes(harness)
            def build(label, code):
                (work / 'controller.c').write_text(code)
                command = [args.cc, '-std=c11', '-O2', '-DSMPC_FW', '-DCD_SRC_FW', str(work / 'harness.c'), '-o', str(work / label)]
                with (args.output / f'{label}_compile.log').open('w') as log:
                    subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=60)
                return work / label
            def run(binary, label, values, negative=False):
                proc = subprocess.run([str(binary), *map(str, values)], text=True, capture_output=True, timeout=5)
                output = proc.stdout + proc.stderr
                (args.output / f'{label}.log').write_text(output)
                record = {'name': label, 'arguments': values, 'exit': proc.returncode, 'log_sha256': sha(output.encode())}
                result['cases'].append(record)
                if values[0] == 6:
                    if output.strip() != 'native cd_restart reset gate active=0 failures=0':
                        raise AssertionError(f'{label}: missing successful restart checkpoint')
                else:
                    pattern = (r'^scenario=(\d+) initial=(\d+) elapsed=(\d+) pickup_wait=(\d+) '
                               r'phase=(\d+) counter=(-?\d+) deadline=(\d+) expected=(\d+) active=(\d+) failures=(\d+)$')
                    checkpoints = [tuple(map(int, match)) for match in re.findall(pattern, output, re.M)]
                    if len(checkpoints) != 3:
                        raise AssertionError(f'{label}: expected three actual controller checkpoints')
                    for index, checkpoint in enumerate(checkpoints):
                        scenario, initial, elapsed, wait, phase, counter, deadline, expected, active, failures = checkpoint
                        if (scenario, initial, elapsed) != (values[0], (values[1] - 16 * index) & 0xffffffff, values[2]):
                            raise AssertionError(f'{label}: checkpoint does not match requested controller case')
                        if negative:
                            if wait != 84 or failures == 0 or ((expected - deadline) & 0xffffffff) != 84:
                                raise AssertionError(f'{label}: stale control lacks the precise 84-tick discrepancy')
                        elif failures != 0 or deadline != expected:
                            raise AssertionError(f'{label}: controller checkpoint invariant failed')
                if negative:
                    failures = [line for line in output.splitlines() if line.startswith('FAIL ')]
                    allowed = {'FAIL deadline anchored to last actual CDB_Run sample', 'FAIL drive due invariant'}
                    if proc.returncode != 1 or not failures or not set(failures) <= allowed or 'pickup_wait=84' not in output:
                        raise AssertionError(f'{label}: stale-anchor control did not fail for the expected reason')
                elif proc.returncode != 0 or 'FAIL ' in output:
                    raise AssertionError(f'{label}: actual controller failed; see log')
            candidate = build('candidate', source)
            for tick in (0, 123456, 0xffffff80, 0xfffffff0):
                for elapsed in (0, 83, 84):
                    for scenario in range(5):
                        run(candidate, f's{scenario}_t{tick}_e{elapsed}', [scenario, tick, elapsed, 10000])
            run(candidate, 'restart_gate', [6, 0, 0, 10000])
            control = build('stale_anchor', mutant)
            run(control, 'stale_anchor_rejected', [0, 0, 0, 10000], negative=True)
        result['status'] = 'PASS'
    except Exception as error:
        result['status'] = 'FAIL'
        result['error'] = str(error)
        raise
    finally:
        save()
    print(f"PASS: 60 controller cases (3 entries each), restart gate, stale-anchor rejection; {args.output / 'result.json'}")


if __name__ == '__main__':
    main()
