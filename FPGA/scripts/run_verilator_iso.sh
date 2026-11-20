#!/usr/bin/env bash
# Build+run isolation feature TBs under Verilator (no coverage).
# Usage (from FPGA/): bash scripts/run_verilator_iso.sh
set -euo pipefail

export PATH="/ucrt64/bin:/usr/bin:$PATH"
export VERILATOR_BIN="${VERILATOR_BIN:-verilator_bin.exe}"
export VERILATOR_ROOT="${VERILATOR_ROOT:-/ucrt64/share/verilator}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/senior_design.srcs/sources_1/new"
SIM="$ROOT/senior_design.srcs/sim_1/new"
OBJ="$ROOT/verilator/obj_dir_iso"

mkdir -p "$OBJ"

COMMON_FLAGS=(
  --binary --timing
  -Wall -Wno-fatal
  -Wno-DECLFILENAME -Wno-UNUSED -Wno-UNUSEDSIGNAL
  -Wno-SYNCASYNCNET -Wno-BLKSEQ -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC
  -Wno-PINCONNECTEMPTY -Wno-PROCASSINIT -Wno-PINMISSING -Wno-COMBDLY
  -I"$SRC"
)

PHY=(
  "$SRC/usb_reset_det.v"
  "$SRC/usb_packet_frontend.sv"
  "$SRC/usb_fs_rx.v"
  "$SRC/usb_fs_tx.v"
  "$SRC/strobe.v"
)

run_one() {
  local top="$1"; shift
  local odir="$OBJ/$top"
  echo ""
  echo "==== build $top ===="
  rm -rf "$odir"
  mkdir -p "$odir"
  verilator "${COMMON_FLAGS[@]}" --top-module "$top" \
    --Mdir "$odir" -o "V${top}" "$@"
  echo "==== run $top ===="
  (
    cd "$odir"
    "./V${top}.exe" || "./V${top}"
  )
}

FAIL=0

run_one tb_hid_timing \
  "$SIM/tb_hid_timing.sv" "$SRC/hid_timing_filter.sv" || FAIL=1

run_one tb_suspicious_enum \
  "$SIM/tb_suspicious_enum.sv" "$SRC/enumeration_analysis.sv" || FAIL=1

run_one tb_hid_pending_approve \
  "$SIM/tb_hid_pending_approve.sv" \
  "$SRC/sniffer_wrapper.sv" "$SRC/sniffer_block.sv" \
  "$SRC/isolation_controller.sv" "$SRC/enumeration_analysis.sv" \
  "$SRC/hid_timing_filter.sv" "${PHY[@]}" || FAIL=1

run_one tb_cov_isolation \
  "$SIM/tb_cov_isolation.sv" "$SRC/isolation_controller.sv" || FAIL=1

run_one tb_bit_stuff \
  "$SIM/tb_bit_stuff.sv" \
  "$SRC/sniffer_block.sv" "$SRC/isolation_controller.sv" \
  "$SRC/enumeration_analysis.sv" "$SRC/hid_timing_filter.sv" \
  "${PHY[@]}" || FAIL=1

if [[ $FAIL -ne 0 ]]; then
  echo "iso-verilator: FAIL"
  exit 1
fi
echo "iso-verilator: all PASS"
