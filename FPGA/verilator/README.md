# Verilator coverage sidecar

Coverage TBs are shared with XSim and live in:

- `senior_design.srcs/sim_1/new/tb_cov_isolation.sv`
- `senior_design.srcs/sim_1/new/tb_cov_sniffer.sv`

`make cov-verilator` builds them with `--coverage` (SVA stripped via `` `ifndef VERILATOR `` in `isolation_controller`).
`make sim SIM_TOP=tb_cov_*` / `make sim-all` runs the same TBs under XSim **with** `isolation_controller_sva`.

**Windows install:** MSYS2 ucrt64 Verilator on PATH (`C:\msys64\ucrt64\bin`), plus user env `VERILATOR_BIN=verilator_bin.exe` and `VERILATOR_ROOT=C:\msys64\ucrt64\share\verilator`. `scripts/run_verilator_cov.sh` sets the same when invoked via `make cov-verilator`.
