# FPGA — Agent notes

Vivado project for the hub’s FPGA fabric (RTL inspection/isolation). Distinct from `GUI/` and `PCB/`. Use repeatable Makefile workflows; develop with encapsulation. Goal: synthesizable RTL.

**Simulation, testbenches, Make/env knobs, coverage:** see [`testing.md`](testing.md) (do not duplicate long command lists here).  
**Cmod board bring-up (pins, LEDs, bitstream):** [`bringup.md`](bringup.md).

## Required reading (before any RTL / register-map change)

1. [`Docs/fabric_slop.md`](../Docs/fabric_slop.md) — hierarchy, clocks, SPI map, threat codes (**primary**)
2. [`Docs/d_c_txt.md`](../Docs/d_c_txt.md) — parallel-sniff architecture, latency/power specs, fabric block narrative
3. [`Docs/Board_slop.md`](../Docs/Board_slop.md) — pin roles (D+/D− taps, kill, SPI)
4. [`Docs/firmwmare_slop.md`](../Docs/firmwmare_slop.md) — MCU is SPI master; keep register contract aligned
5. Block diagram: [`Docs/BlockDiagrams/Rendered/fabric_bd.jpg`](../Docs/BlockDiagrams/Rendered/fabric_bd.jpg)
6. After RTL/sim changes: [`testing.md`](testing.md) — which TB to run and how

## Architecture reminders

- `main_wrapper` is the Cmod S7 board top (12→48 MHz MMCM, sniffer wrapper, `register_file`, SPI slave, kill LEDs). Identical `sniffer_block` instances per port.
- Constraints: `senior_design.srcs/constrs_1/new/cmod_s7_bringup.xdc` (Digilent onboard + PIO).
- Sniff **in parallel** with the hub IC; default is not in-line. Kill on threat; status is stateful each cycle.
- FPGA = SPI **slave**; sniffer clock **48 MHz**.
- Soft USB RX is TinyFPGA-derived (`usb_fs_rx` / `strobe`); Apache-2.0 copies under `third_party/tinyfpga/`.
  Per-port path: `usb_packet_frontend` → `isolation_controller` inside `sniffer_block`; `sniffer_wrapper` generates ×`NUM_PORTS`.
- Default sim top: `tb_sniffer`. Shared stimulus: `usb_fs_tx` (sim TBs + on-FPGA `usb_demo_selfstim`). Full TB list and knobs: [`testing.md`](testing.md).

## Layout

| Path | Role |
| --- | --- |
| `senior_design.xpr` | Vivado project (open this, not the folder alone) |
| `senior_design.srcs/` | HDL, constraints, sim sources (tracked) |
| `scripts/*.tcl` | Batch flows used by Make (`build`, `synth`, `sim`, `sim_all`) |
| `Makefile` | CLI entry points for agents and developers |
| `testing.md` | **Testbenches, how to run sims, overrides, coverage** |
| `bringup.md` | Cmod stand-alone bring-up checklist (LEDs/SPI/bitstream) |
| `.gitignore` | Ignores Vivado generated dirs (cache, runs, sim, hw, …) |

## Toolchain

- **Vivado** on PATH (project historically 2017.4 → **2018.2**). Smoke check: `vivado -version`.
- If `vivado` is missing:  
  `make build VIVADO="C:/Xilinx/Vivado/2018.2/bin/vivado.bat"`
- Prefer Make targets over ad-hoc `vivado` one-liners. Paths relative to the repo (`FPGA/…`).
- On Windows lab PCs, `Makefile` defaults `VIVADO` to `C:/Xilinx/Vivado/2018.2/bin/vivado.bat` when that file exists (GnuWin32 `make` uses `cmd.exe`).

## Commands (summary)

Full tables, TB inventory, `SIM_*` / `COV` / RTL parameters, and “add a TB” steps: **[`testing.md`](testing.md)**.

```bash
make -C FPGA help
make -C FPGA sim SIM_TOP=tb_sniffer
make -C FPGA sim-all
make -C FPGA cov-verilator
make -C FPGA synth
make -C FPGA build
make -C FPGA gui
```

## Agent conventions

1. Complete the **Required reading** list above before changing RTL or the register map.
2. Prefer **simulation** before claiming RTL works; follow [`testing.md`](testing.md). Add/extend testbenches under `senior_design.srcs/sim_1/`.
3. After RTL changes, run the relevant `make -C FPGA sim` / `sim-all` and/or `synth` and report what ran.
4. Keep protocol/register/threat definitions aligned with `Docs/fabric_slop.md` and (when present) `GUI/backend/src/protocol.py`.
5. Do not present empty stubs or unsimulated modules as verified hardware behavior.
6. Use `make -C FPGA gui` when interactive debug is needed; keep batch Make as the default CI-style path.
