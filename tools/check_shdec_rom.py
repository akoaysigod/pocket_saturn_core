#!/usr/bin/env python3
"""Check the properties of the SH-2 decoder ROM (shdec_rom.hex) that SH_core_cs.sv relies on, so a regenerated ROM
cannot break them silently. The row layout is read from the DecRow_t struct in SH_core_cs.sv and IMMT's VECT code
from SH_pkg.sv, so the check follows the RTL.

  1. SRS[2] == VECR in every row: the decoded CTRL.SRS[2] is taken from the VECR column.
  2. No row with IMMT == VECT has SB = 1: there is no ALU_B vector-number flag (EXOP.VB).
  3. Every row with IMMT == VECT has BI = 0 and SZ = 2: VECT_SH is the fixed {VECT_IN,2'b00}.

usage: check_shdec_rom.py [--core-dir src/fpga/rtl/SH/core]   (exit status 1 if a property does not hold)
"""
import argparse
import os
import re
import sys


def row_layout(sv_text):
    m = re.search(r'typedef\s+struct\s+packed\s*\{(.*?)\}\s*DecRow_t\s*;', sv_text, re.S)
    if not m:
        sys.exit('DecRow_t not found')
    fields = []
    for decl in m.group(1).split(';'):
        decl = decl.strip()
        if not decl:
            continue
        d = re.fullmatch(r'bit\s*(?:\[\s*(\d+)\s*:\s*(\d+)\s*\])?\s*(\w+)', decl)
        if not d:
            sys.exit('cannot parse DecRow_t field: ' + decl)
        width = int(d.group(1)) - int(d.group(2)) + 1 if d.group(1) else 1
        fields.append((d.group(3), width))
    return fields


def vect_code(pkg_text):
    m = re.search(r'\bVECT\s*=\s*3\'b([01]{3})', pkg_text)
    if not m:
        sys.exit('VECT not found in SH_pkg.sv')
    return int(m.group(1), 2)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--core-dir', default=os.path.join(os.path.dirname(__file__), '..', 'src/fpga/rtl/SH/core'))
    ap.add_argument('--rom', help='ROM file to check (default: <core-dir>/shdec_rom.hex)')
    args = ap.parse_args()

    with open(os.path.join(args.core_dir, 'SH_core_cs.sv')) as f:
        fields = row_layout(f.read())
    with open(os.path.join(args.core_dir, 'SH_pkg.sv')) as f:
        vect = vect_code(f.read())
    total = sum(w for _, w in fields)

    with open(args.rom or os.path.join(args.core_dir, 'shdec_rom.hex')) as f:
        rows = [int(line, 16) for line in (l.strip() for l in f) if line]

    def decode(value):
        row, pos = {}, total
        for name, width in fields:
            pos -= width
            row[name] = (value >> pos) & ((1 << width) - 1)
        return row

    errors = []
    for i, row in enumerate(decode(v) for v in rows):
        if (row['SRS'] >> 2) & 1 != row['VECR']:
            errors.append(f'row {i}: SRS[2] = {(row["SRS"] >> 2) & 1}, VECR = {row["VECR"]} (property 1)')
        if row['IMMT'] == vect:
            if row['SB']:
                errors.append(f'row {i}: IMMT = VECT with SB = 1 (property 2)')
            if row['BI'] != 0 or row['SZ'] != 2:
                errors.append(f'row {i}: IMMT = VECT with BI = {row["BI"]}, SZ = {row["SZ"]} (property 3)')

    if errors:
        print('\n'.join(errors))
        print(f'{len(errors)} violation(s) in {len(rows)} rows: SH_core_cs.sv\'s SRS[2] / EXOP.VB / VECT_SH '
              'simplifications no longer hold for this ROM')
        return 1
    print(f'ok: {len(rows)} rows of {total} bits, SRS[2] == VECR, VECT rows have SB = 0, BI = 0, SZ = 2')
    return 0


if __name__ == '__main__':
    sys.exit(main())
