# TinyFPGA sandbox (superseded)

Working sniffer RTL has been **migrated into the real Vivado project**:

- Design: `FPGA/senior_design.srcs/sources_1/new/`
  (`usb_fs_rx.v`, `strobe.v`, `usb_packet_frontend.sv`, `isolation_controller.sv`,
  `sniffer_block.sv`, `sniffer_wrapper.sv`, …)
- Sim: `FPGA/senior_design.srcs/sim_1/new/tb_sniffer.sv` (+ `usb_fs_tx.v` stimulus)
- License copies: `FPGA/third_party/tinyfpga/`

Simulate from `FPGA/`:

```bat
make sim VIVADO="C:/Xilinx/Vivado/2018.2/bin/vivado.bat"
```

This folder is kept only as a historical sandbox / Apache source pointer.
Prefer editing files under `senior_design.srcs/`.
