#!/usr/bin/env python3
"""Compare ISS trace vs RTL simulation trace for ISS↔RTL cross-check.

ISS  line format : "PC=XXXXXXXX | XXXXXXXX | mnemonic"
RTL  line format : "RTL PC=XXXXXXXX | XXXXXXXX"
"""

import sys
import re

ISS_PAT = re.compile(r'^PC=([0-9A-Fa-f]{8})\s*\|\s*([0-9A-Fa-f]{8})')
RTL_PAT = re.compile(r'^RTL PC=([0-9A-Fa-f]{8})\s*\|\s*([0-9A-Fa-f]{8})')


def parse_trace(path, pattern):
    entries = []
    with open(path) as f:
        for line in f:
            m = pattern.match(line.strip())
            if m:
                entries.append((m.group(1).upper(), m.group(2).upper()))
    return entries


def main():
    if len(sys.argv) != 3:
        print("Usage: compare_trace.py iss.trace rtl.trace")
        sys.exit(1)

    iss_path, rtl_path = sys.argv[1], sys.argv[2]
    iss = parse_trace(iss_path, ISS_PAT)
    rtl = parse_trace(rtl_path, RTL_PAT)

    print(f"ISS trace : {len(iss)} instructions  ({iss_path})")
    print(f"RTL trace : {len(rtl)} instructions  ({rtl_path})")
    print()

    if not iss:
        print("ERROR: no ISS trace lines found — check the file format / path.")
        sys.exit(1)
    if not rtl:
        print("ERROR: no RTL trace lines found — check the file format / path.")
        sys.exit(1)

    n = min(len(iss), len(rtl))
    mismatches = 0
    print(f"{'#':>4}  {'ISS PC':>10}  {'ISS INSTR':>10}  {'RTL PC':>10}  {'RTL INSTR':>10}  STATUS")
    print("-" * 68)
    for i in range(n):
        iss_pc,  iss_ir  = iss[i]
        rtl_pc,  rtl_ir  = rtl[i]
        pc_ok  = (iss_pc == rtl_pc)
        ir_ok  = (iss_ir == rtl_ir)
        ok     = pc_ok and ir_ok
        status = "OK" if ok else ("PC MISMATCH" if not pc_ok else "INSTR MISMATCH")
        if not ok:
            mismatches += 1
        print(f"{i+1:>4}  {iss_pc:>10}  {iss_ir:>10}  {rtl_pc:>10}  {rtl_ir:>10}  {status}")

    if len(iss) != len(rtl):
        print(f"\nWARNING: trace length mismatch (ISS={len(iss)}, RTL={len(rtl)})")
        mismatches += abs(len(iss) - len(rtl))

    print()
    if mismatches == 0:
        print("PASS✅ — ISS and RTL traces match perfectly.")
    else:
        print(f"FAIL❌ — {mismatches} mismatch(es) found.")
        sys.exit(1)


if __name__ == "__main__":
    main()
