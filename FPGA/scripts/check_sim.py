#!/usr/bin/env python3
"""Score XSim logs for TEST PASSED / TEST FAILED. Does not launch Vivado.

Used by `make sim` after the batch run, or standalone on an existing log:
  python scripts/check_sim.py
  python scripts/check_sim.py sim_last.log

Looks at any paths given on the command line, plus (if present)
sim_last.log and senior_design.sim/**/simulate.log.

Exit codes:
  0  TEST PASSED found and TEST FAILED not found
  1  TEST FAILED, neither token, or no log text to read
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

PASS_TOKEN = "TEST PASSED"
FAIL_TOKEN = "TEST FAILED"
TAIL_LINES = 40
DEFAULT_LOGS = (
    Path("sim_last.log"),
    Path("senior_design.sim/sim_1/behav/xsim/simulate.log"),
)


def read_file(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def gather_text(paths: list[Path]) -> tuple[str, list[Path]]:
    chunks: list[str] = []
    used: list[Path] = []
    seen: set[Path] = set()

    for path in paths:
        if not path.is_file():
            continue
        resolved = path.resolve()
        if resolved in seen:
            continue
        seen.add(resolved)
        used.append(path)
        chunks.append(read_file(path))

    sim_dir = Path("senior_design.sim")
    if sim_dir.is_dir():
        for log in sorted(sim_dir.rglob("simulate.log")):
            resolved = log.resolve()
            if resolved in seen:
                continue
            seen.add(resolved)
            used.append(log)
            chunks.append(read_file(log))

    return "\n".join(chunks), used


def print_tail(text: str) -> None:
    lines = text.splitlines()
    if not lines:
        return
    print("--- log tail ---")
    for line in lines[-TAIL_LINES:]:
        print(line)


def score(text: str, used: list[Path], looked_at: list[Path]) -> int:
    if not text.strip():
        print("SIM RESULT: TEST FAILED (no simulation log text found)", file=sys.stderr)
        print("Looked at: " + ", ".join(str(p) for p in looked_at), file=sys.stderr)
        return 1

    has_fail = FAIL_TOKEN in text
    has_pass = PASS_TOKEN in text

    if has_fail:
        print("SIM RESULT: TEST FAILED")
        print_tail(text)
        return 1
    if has_pass:
        print("SIM RESULT: TEST PASSED")
        return 0

    print("SIM RESULT: TEST FAILED (no TEST PASSED / TEST FAILED token in log)")
    print("Scanned:")
    for path in used:
        print(f"  {path}")
    print_tail(text)
    return 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "logs",
        nargs="*",
        type=Path,
        help="Log files to scan (default: sim_last.log and XSim simulate.log)",
    )
    args = parser.parse_args()
    paths = list(args.logs) if args.logs else list(DEFAULT_LOGS)
    text, used = gather_text(paths)
    return score(text, used, paths)


if __name__ == "__main__":
    sys.exit(main())
