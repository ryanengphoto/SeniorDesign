#!/usr/bin/env python3
"""Summarize Verilator toggle points from verilator_coverage --annotate-points."""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "merged_dat",
        nargs="?",
        default="cov/verilator/merged.dat",
        help="Merged verilator_coverage DB",
    )
    args = ap.parse_args()
    root = Path(__file__).resolve().parents[1]
    dat = Path(args.merged_dat)
    if not dat.is_absolute():
        dat = root / dat
    if not dat.is_file():
        print(f"ERROR: missing {dat}", file=sys.stderr)
        return 1

    with tempfile.TemporaryDirectory(prefix="vlt_tog_") as td:
        ann = Path(td) / "ann"
        ann.mkdir()
        cmd = [
            "perl",
            subprocess.check_output(["which", "verilator_coverage"], text=True).strip(),
            "--annotate-points",
            "--annotate",
            str(ann),
            str(dat),
        ]
        subprocess.run(cmd, check=True, capture_output=True, text=True)

        by: dict[str, list[int]] = {}
        hit = tot = 0
        for f in ann.rglob("*"):
            if not f.is_file() or f.name.startswith("tb_"):
                continue
            if not f.name.endswith((".sv", ".v")):
                continue
            h = t = 0
            for line in f.read_text(encoding="utf-8", errors="replace").splitlines():
                if " point: comment=" not in line:
                    continue
                if "0->1" not in line and "1->0" not in line:
                    continue
                t += 1
                m = re.match(r"\s*[+~%]?(\d+)", line)
                if m and int(m.group(1)) > 0:
                    h += 1
            if t:
                by[f.name] = [h, t]
                hit += h
                tot += t

    pct = (100.0 * hit / tot) if tot else 0.0
    print(f"DUT TOGGLE (annotate-points): {hit}/{tot} = {pct:.1f}%")
    for name, (h, t) in sorted(by.items(), key=lambda kv: -kv[1][1]):
        print(f"  {name:28s} {h:4d}/{t:<4d} {100.0 * h / t:5.1f}%")
    return 0


if __name__ == "__main__":
    sys.exit(main())
