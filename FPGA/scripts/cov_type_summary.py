#!/usr/bin/env python3
"""Summarize Verilator lcov coverage.info by metric kind + per-DUT file."""
from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    info = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "cov/verilator/coverage.info"
    text = info.read_text(encoding="utf-8", errors="replace")

    # lcov from verilator_coverage:
    #   DA:line,hits          -> line
    #   BRDA:line,block,branch,hits -> branch (hits can be '-' )
    # Toggle often appears as separate records; Verilator also emits
    # custom TN or notes. Parse BRDA + DA first; scan annotate for toggle if needed.

    cur = None
    line = defaultdict(lambda: {"hit": 0, "tot": 0})
    branch = defaultdict(lambda: {"hit": 0, "tot": 0})

    for raw in text.splitlines():
        if raw.startswith("SF:"):
            cur = raw[3:].replace("\\", "/")
        elif raw.startswith("DA:") and cur:
            _, hits = raw[3:].split(",")[:2]
            line[cur]["tot"] += 1
            if int(hits) > 0:
                line[cur]["hit"] += 1
        elif raw.startswith("BRDA:") and cur:
            # BRDA:line,block,branch,taken
            parts = raw[3:].split(",")
            if len(parts) < 4:
                continue
            taken = parts[3]
            branch[cur]["tot"] += 1
            if taken not in ("-", "0"):
                branch[cur]["hit"] += 1

    def pct(h, t):
        return 100.0 * h / t if t else 0.0

    def roll(d):
        h = sum(v["hit"] for v in d.values())
        t = sum(v["tot"] for v in d.values())
        return h, t

    def is_dut(p: str) -> bool:
        return "sources_1" in p

    line_dut = {k: v for k, v in line.items() if is_dut(k)}
    br_dut = {k: v for k, v in branch.items() if is_dut(k)}

    lh, lt = roll(line_dut)
    bh, bt = roll(br_dut)
    print(f"From {info}")
    print(f"DUT LINE:   {lh}/{lt} = {pct(lh, lt):.1f}%")
    print(f"DUT BRANCH: {bh}/{bt} = {pct(bh, bt):.1f}%")
    print()
    print("Per DUT file (branch):")
    for k, v in sorted(br_dut.items(), key=lambda kv: -kv[1]["tot"]):
        name = Path(k).name
        print(f"  {name:28s} {v['hit']:4d}/{v['tot']:<4d} {pct(v['hit'], v['tot']):5.1f}%")

    # Uncovered branches sample
    print()
    print("Files with most missed branches:")
    missed = []
    for k, v in br_dut.items():
        missed.append((Path(k).name, v["tot"] - v["hit"], v["tot"]))
    for name, m, t in sorted(missed, key=lambda x: -x[1])[:8]:
        print(f"  {name}: {m} missed / {t} total")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
