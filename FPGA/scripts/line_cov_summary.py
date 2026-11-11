#!/usr/bin/env python3
"""Summarize line coverage from Verilator lcov coverage.info (DA: records)."""
from __future__ import annotations

import sys
from pathlib import Path


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    info_path = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "cov/verilator/coverage.info"
    if not info_path.is_file():
        print(f"missing {info_path}", file=sys.stderr)
        return 1

    text = info_path.read_text(encoding="utf-8", errors="replace")
    per: dict[str, dict[str, int]] = {}
    cur: str | None = None
    for line in text.splitlines():
        if line.startswith("SF:"):
            cur = line[3:].replace("\\", "/")
            per[cur] = {"hit": 0, "tot": 0}
        elif line.startswith("DA:") and cur is not None:
            parts = line[3:].split(",")
            if len(parts) >= 2:
                hits = int(parts[1])
                per[cur]["tot"] += 1
                if hits > 0:
                    per[cur]["hit"] += 1

    def norm(p: str) -> str:
        return p.replace("\\", "/")

    dut = {k: v for k, v in per.items() if "sources_1" in norm(k)}
    tb = {k: v for k, v in per.items() if "tb_cov" in norm(k)}

    def pct(h: int, t: int) -> float:
        return 100.0 * h / t if t else 0.0

    all_hit = sum(v["hit"] for v in per.values())
    all_tot = sum(v["tot"] for v in per.values())
    dut_hit = sum(v["hit"] for v in dut.values())
    dut_tot = sum(v["tot"] for v in dut.values())
    tb_hit = sum(v["hit"] for v in tb.values())
    tb_tot = sum(v["tot"] for v in tb.values())

    print(f"LINE coverage from {info_path}")
    print(f"  all files:     {all_hit}/{all_tot} = {pct(all_hit, all_tot):.1f}%")
    print(f"  DUT sources_1: {dut_hit}/{dut_tot} = {pct(dut_hit, dut_tot):.1f}%")
    print(f"  cov TBs:       {tb_hit}/{tb_tot} = {pct(tb_hit, tb_tot):.1f}%")
    print()
    print("Per DUT file (line):")
    for k, v in sorted(dut.items(), key=lambda kv: (-kv[1]["tot"], kv[0])):
        name = Path(k).name
        print(f"  {name:28s} {v['hit']:4d}/{v['tot']:<4d} {pct(v['hit'], v['tot']):5.1f}%")

    # Uncovered DA lines for worst DUT files
    print()
    print("Largest uncovered DUT files (line numbers with 0 hits):")
    uncovered: dict[str, list[int]] = {}
    cur = None
    for line in text.splitlines():
        if line.startswith("SF:"):
            cur = line[3:].replace("\\", "/")
            uncovered[cur] = []
        elif line.startswith("DA:") and cur and "sources_1" in cur:
            ln, hits = line[3:].split(",")[:2]
            if int(hits) == 0:
                uncovered[cur].append(int(ln))

    for k, lines in sorted(uncovered.items(), key=lambda kv: -len(kv[1])):
        if not lines:
            continue
        name = Path(k).name
        preview = ", ".join(str(x) for x in lines[:12])
        more = f" … (+{len(lines)-12})" if len(lines) > 12 else ""
        print(f"  {name}: {len(lines)} lines — e.g. {preview}{more}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
