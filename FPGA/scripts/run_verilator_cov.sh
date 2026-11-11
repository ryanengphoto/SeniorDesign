#!/usr/bin/env bash
# Build + run Verilator coverage TBs; write annotated sources + lcov info.
# Usage (from FPGA/): bash scripts/run_verilator_cov.sh
# Or: make cov-verilator
set -euo pipefail

export PATH="/ucrt64/bin:/usr/bin:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/senior_design.srcs/sources_1/new"
SIM="$ROOT/senior_design.srcs/sim_1/new"
VTB="$ROOT/verilator"
OUT="$ROOT/cov/verilator"
OBJ="$ROOT/verilator/obj_dir"

mkdir -p "$OUT" "$OBJ"

if ! command -v verilator >/dev/null 2>&1; then
  echo "ERROR: verilator not on PATH (expected MSYS2 ucrt64)." >&2
  echo "  pacman -S mingw-w64-ucrt-x86_64-verilator" >&2
  exit 1
fi

echo "==== Verilator $(verilator --version | head -1) ===="

COMMON_FLAGS=(
  --binary
  --timing
  --coverage
  --trace-fst
  -Wall
  -Wno-fatal
  -Wno-DECLFILENAME
  -Wno-UNUSED
  -Wno-UNUSEDSIGNAL
  -Wno-SYNCASYNCNET
  -Wno-BLKSEQ
  -Wno-WIDTHEXPAND
  -Wno-WIDTHTRUNC
  -Wno-PINCONNECTEMPTY
  -Wno-PROCASSINIT
  -Wno-PINMISSING
  -Wno-COMBDLY
  -I"$SRC"
  --top-module
)

run_one() {
  local top="$1"
  shift
  local files=("$@")
  local dat="$OUT/${top}.dat"
  local odir="$OBJ/$top"

  echo ""
  echo "==== build $top ===="
  rm -rf "$odir"
  mkdir -p "$odir"

  verilator "${COMMON_FLAGS[@]}" "$top" \
    --Mdir "$odir" \
    -o "V${top}" \
    "${files[@]}"

  echo "==== run $top ===="
  # Mingw binaries want a Windows-style path for the coverage file.
  local dat_win
  dat_win="$(cygpath -w "$dat" 2>/dev/null || echo "$dat")"
  (
    cd "$odir"
    "./V${top}" "+verilator+coverage+file+${dat_win}"
  )

  if [[ ! -f "$dat" ]]; then
    if [[ -f "$odir/coverage.dat" ]]; then
      mv "$odir/coverage.dat" "$dat"
    elif [[ -f coverage.dat ]]; then
      mv coverage.dat "$dat"
    else
      echo "ERROR: no coverage data for $top" >&2
      exit 1
    fi
  fi
  echo "coverage data → $dat"
}

# --- isolation_controller (tight, high branch focus) ---
run_one tb_cov_isolation \
  "$VTB/tb_cov_isolation.sv" \
  "$SRC/isolation_controller.sv"

# --- sniffer_block + TinyFPGA RX/TX path ---
run_one tb_cov_sniffer \
  "$VTB/tb_cov_sniffer.sv" \
  "$SRC/sniffer_block.sv" \
  "$SRC/isolation_controller.sv" \
  "$SRC/enumeration_analysis.sv" \
  "$SRC/usb_packet_frontend.sv" \
  "$SRC/usb_fs_rx.v" \
  "$SRC/usb_fs_tx.v" \
  "$SRC/strobe.v"

echo ""
echo "==== merge + annotate ===="
MERGED="$OUT/merged.dat"
INFO="$OUT/coverage.info"
ANN="$OUT/annotate"
SUM="$OUT/summary.txt"

rm -rf "$ANN"
mkdir -p "$ANN"

# Capture "Total coverage (hit/total) pct%" from verilator_coverage.
set +e
COV_LOG=$(perl "$(which verilator_coverage)" \
  --write "$MERGED" \
  --write-info "$INFO" \
  --annotate "$ANN" \
  --annotate-all \
  "$OUT"/tb_cov_isolation.dat \
  "$OUT"/tb_cov_sniffer.dat 2>&1)
COV_RC=$?
set -e
printf '%s\n' "$COV_LOG"

{
  echo "Verilator coverage summary"
  echo "TBs: tb_cov_isolation PASS, tb_cov_sniffer PASS (see run log)"
  echo "$COV_LOG" | sed -n '/Total coverage/p'
  echo ""
  echo "Annotated sources: cov/verilator/annotate/  (lines with %00 are uncovered)"
  echo "lcov info:          cov/verilator/coverage.info"
  echo "Merged DB:          cov/verilator/merged.dat"
  echo ""
  echo "Note: XSim acceptance gate remains make sim-all. This is a coverage sidecar."
} | tee "$SUM"

if [[ $COV_RC -ne 0 ]]; then
  echo "ERROR: verilator_coverage failed (rc=$COV_RC)" >&2
  exit "$COV_RC"
fi

echo ""
echo "==== line coverage (DUT) ===="
python3 scripts/line_cov_summary.py | tee -a "$SUM"

echo ""
echo "cov-verilator: done → $SUM"
