#!/usr/bin/env python3
"""Portable actual-controller regression; see COUNTER_TEST.md."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


def digest(data):
    return hashlib.sha256(data).hexdigest()


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source-dir', type=Path, required=True, help='repository src/fw/cdb containing widened cdb_hle.c')
    ap.add_argument('--out', type=Path, required=True, help='new, nonexistent result directory')
    ap.add_argument('--cc', default='clang')
    args = ap.parse_args()
    source = args.source_dir.resolve()
    out = args.out.resolve()
    tool = Path(__file__).resolve()
    paths = {n: source / n for n in ['cdb_hle.c', 'hw.h', 'rt.h', 'smpc.h', 'cd_src.h']}
    paths.update({'test_counter.py': tool, 'counter_harness.c': tool.with_name('counter_harness.c')})
    blobs = {n: p.read_bytes() for n, p in paths.items()}
    start = {n: digest(b) for n, b in blobs.items()}
    c = blobs['cdb_hle.c'].decode()
    require(c.count('static int64_t DriveCounter;') == 1, 'requires exactly one int64_t DriveCounter declaration')
    require(c.count('  DriveCounter -= clocks;') == 1, 'ambiguous counter subtraction mutation site')
    require('smpc_cd_deadline = last + (uint32_t)DriveCounter;' in c, 'requires PR18 deadline-anchor parent')
    out.mkdir(parents=True, exist_ok=False)
    snapshot = out / 'snapshot'
    snapshot.mkdir()
    for n, b in blobs.items():
        p = snapshot / n
        p.write_bytes(b)
        p.chmod(0o444)
    snapshot.chmod(0o555)
    receipt = {'status': 'RUNNING', 'scope': 'actual repository C with explicit MMIO/source/SMPC adapters; native integration NOT_RUN',
               'input_paths': {n: str(p) for n, p in paths.items()}, 'live_start_sha256': start,
               'snapshot_sha256': start.copy(), 'generated_input_expected_sha256': {}, 'commands': [], 'python': sys.version,
               'macros': ['SMPC_FW', 'CD_SRC_FW', 'TEST_WIDE (wide and saturation only)']}
    def save():
        (out / 'result.json').write_text(json.dumps(receipt, indent=2) + '\n')
    def command(argv, label, negative=None):
        log = out / (label + '.log')
        try:
            with log.open('w') as f:
                proc = subprocess.run(argv, cwd=out, stdout=f, stderr=subprocess.STDOUT, timeout=60)
        except subprocess.TimeoutExpired:
            raise RuntimeError(label + ': timeout is not an accepted control result')
        text = log.read_text(errors='replace')
        receipt['commands'].append({'argv': argv, 'exit': proc.returncode, 'log': log.name, 'sha256': digest(log.read_bytes())})
        save()
        if negative:
            require(proc.returncode > 0 and re.search(negative, text), label + ': missing precise expected failure')
        else:
            require(proc.returncode == 0 and 'runtime error:' not in text and 'FAIL ' not in text, label + ': failed; see log')
        return text
    save()
    try:
        cc = shutil.which(args.cc)
        require(cc is not None, 'compiler not found')
        receipt['compiler_path'] = cc
        receipt['compiler_version'] = command([cc, '--version'], 'compiler_version')
        header = blobs['hw.h'].decode()
        adapters = {'#define IO(o)        (*(volatile uint32_t*)(0x20000000u + (o)))': '#define IO(o)        (*test_io(o))',
                    '#define CDRAM(w)     (*(volatile uint32_t*)(0x10000000u + 4u * (w)))': '#define CDRAM(w)     (cdmem[(w)])',
                    '*(volatile uint16_t*)(0x10000000u + 4u * w) = v;': 'cdmem[w] = v;'}
        for a, b in adapters.items():
            require(header.count(a) == 1, 'ambiguous MMIO adapter: ' + a)
            header = header.replace(a, b)
        receipt['adapter_substitutions'] = adapters
        variants = {'wide': c, 'narrow': c.replace('static int64_t DriveCounter;', 'static int32_t DriveCounter;'),
                    'saturation': c.replace('  DriveCounter -= clocks;', '  DriveCounter -= clocks;\n  if(DriveCounter < INT32_MIN) DriveCounter = INT32_MIN;')}
        receipt['variant_source_sha256'] = {n: digest(s.encode()) for n, s in variants.items()}
        for name, code in variants.items():
            w = out / name
            w.mkdir()
            for n in ['rt.h', 'smpc.h', 'cd_src.h']:
                (w / n).write_bytes(blobs[n])
            (w / 'hw.h').write_text(header)
            (w / 'controller.c').write_text(code)
            (w / 'harness.c').write_bytes(blobs['counter_harness.c'])
            intended = {n: blobs[n] for n in ['rt.h', 'smpc.h', 'cd_src.h']}
            intended.update({'hw.h': header.encode(), 'controller.c': code.encode(), 'harness.c': blobs['counter_harness.c']})
            for n, data in intended.items():
                receipt['generated_input_expected_sha256'][str((w / n).relative_to(out))] = digest(data)
            save()
            flags = ['-std=c11', '-O2', '-DSMPC_FW', '-DCD_SRC_FW', '-fsanitize=undefined', '-fno-sanitize-recover=undefined', '-Werror=format']
            if name != 'narrow':
                flags += ['-DTEST_WIDE']
            command([cc] + flags + [str(w / 'harness.c'), '-o', str(w / 'test')], name + '_compile')
        def case(name, n, tick=0):
            return command([str(out / name / 'test'), str(n), str(tick), '84', '10000'], f'{name}_{n}_{tick}')
        a, b = case('narrow', 7), case('wide', 7)
        require(a == b and a.count('TRACE normal') == 11, 'normal representable trace mismatch or missing checkpoints')
        for n in [8, 9, 10, 11, 13, 14, 15]:
            text = case('wide', n)
            require(bool(text.strip()), 'missing scenario output')
        command([str(out / 'narrow/test'), '8', '0', '84', '10000'], 'narrow_overflow',
                r'controller\.c:\d+:\d+: runtime error: signed integer overflow: -2147394815 - 112896 cannot be represented')
        command([str(out / 'saturation/test'), '8', '0', '84', '10000'], 'saturation_rejected',
                r'FAIL FULL_DEBT_ORACLE step=19022 got=-2147483648 expected=-2147507711')
        for n in range(5):
            for tick in [0, 123456, 4294967168, 4294967280]:
                a, b = case('narrow', n, tick), case('wide', n, tick)
                require(a == b and len(a.splitlines()) == 3 and a.count('failures=0') == 3,
                        f'normal/wrap case {n}/{tick} trace mismatch or incomplete')
        text = case('wide', 6)
        require('reset gate active=0 failures=0' in text, 'restart deadline gate missing')
        receipt['status'] = 'PASS'
    except Exception as exc:
        receipt['status'] = 'FAIL'
        receipt['error'] = str(exc)
        raise
    finally:
        end = {n: digest(p.read_bytes()) if p.exists() else None for n, p in paths.items()}
        snap_end = {n: digest((snapshot / n).read_bytes()) if (snapshot / n).is_file() else None for n in blobs}
        generated_end = {n: digest((out / n).read_bytes()) if (out / n).is_file() else None
                         for n in receipt['generated_input_expected_sha256']}
        receipt['generated_input_end_sha256'] = generated_end
        receipt['live_end_sha256'] = end
        receipt['snapshot_end_sha256'] = snap_end
        if end != start or snap_end != start or generated_end != receipt['generated_input_expected_sha256']:
            receipt['status'] = 'FAIL'
            receipt['error'] = 'SOURCE_CHANGED: live input, immutable snapshot, or generated compiler input changed during run'
        receipt['artifact_sha256'] = {str(p.relative_to(out)): digest(p.read_bytes()) for p in sorted(out.rglob('*')) if p.is_file() and p.name != 'result.json'}
        save()
    require(receipt['status'] == 'PASS', receipt.get('error', 'failed'))
    print('PASS actual-C widened debt regression:', out / 'result.json')


if __name__ == '__main__':
    main()
