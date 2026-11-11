# Verilator coverage sidecar

Coverage TBs are shared with XSim and live in:

- `senior_design.srcs/sim_1/new/tb_cov_isolation.sv`
- `senior_design.srcs/sim_1/new/tb_cov_sniffer.sv`

`make cov-verilator` builds them with `--coverage` (SVA stripped via `` `ifndef VERILATOR `` in `isolation_controller`).
`make sim SIM_TOP=tb_cov_*` / `make sim-all` runs the same TBs under XSim **with** `isolation_controller_sva`.
