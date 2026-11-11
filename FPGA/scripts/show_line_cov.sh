#!/usr/bin/env bash
set -euo pipefail
export PATH="/ucrt64/bin:/usr/bin:$PATH"
cd "$(dirname "$0")/.."
python3 scripts/line_cov_summary.py
echo ""
perl "$(which verilator_coverage)" --filter-type line cov/verilator/merged.dat 2>&1 | head -5
