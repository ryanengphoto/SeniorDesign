# FPGA — Agent notes

Vivado project for the hub’s FPGA fabric (RTL inspection/isolation). Distinct from `GUI/` and `PCB/`. Use repeatable Makefile workflows; develop with encapsulation. Goal: synthesizable RTL.

## Required reading (before any RTL / register-map change)

1. [`Docs/fabric_slop.md`](../Docs/fabric_slop.md) — hierarchy, clocks, SPI map, threat codes (**primary**)
2. [`Docs/d_c_txt.md`](../Docs/d_c_txt.md) — parallel-sniff architecture, latency/power specs, fabric block narrative
3. [`Docs/Board_slop.md`](../Docs/Board_slop.md) — pin roles (D+/D− taps, kill, SPI)
4. [`Docs/firmwmare_slop.md`](../Docs/firmwmare_slop.md) — MCU is SPI master; keep register contract aligned
5. Block diagram: [`Docs/BlockDiagrams/Rendered/fabric_bd.jpg`](../Docs/BlockDiagrams/Rendered/fabric_bd.jpg)

## Architecture reminders

- `main_wrapper` holds sniffer wrapper, `register_file`, and SPI slave; identical `sniffer_block` instances per port.
- Sniff **in parallel** with the hub IC; default is not in-line. Kill on threat; status is stateful each cycle.
- FPGA = SPI **slave**; sniffer clock **48 MHz**.

## Layout

| Path | Role |
| --- | --- |
| `senior_design.xpr` | Vivado project (open this, not the folder alone) |
| `senior_design.srcs/` | HDL, constraints, sim sources (tracked) |
| `scripts/*.tcl` | Batch flows used by Make (`build`, `synth`, `sim`) |
| `Makefile` | CLI entry points for agents and developers |
| `.gitignore` | Ignores Vivado generated dirs (cache, runs, sim, hw, …) |

## Toolchain

- **Vivado** on PATH (project historically 2017.4 → **2018.2**). Smoke check: `vivado -version`.
- If `vivado` is missing:  
  `make build VIVADO="C:/Xilinx/Vivado/2018.2/bin/vivado.bat"`
- Prefer Make targets over ad-hoc `vivado` one-liners. Paths relative to the repo (`FPGA/…`).

## Commands

Run from `FPGA/` or `make -C FPGA <target>` from the repo root.

| Target | Action |
| --- | --- |
| `make help` | List targets and overrides |
| `make synth` | Synthesis only (`scripts/synth.tcl`) |
| `make build` | Synth + implement + bitstream (`scripts/build.tcl`) |
| `make sim` | Behavioral XSim (`scripts/sim.tcl`); needs a testbench as sim top |
| `make gui` | Open `senior_design.xpr` in the Vivado GUI |
| `make clean` | Remove generated Vivado dirs/logs (keeps sources + `.xpr`) |

Overrides:

| Variable | Purpose |
| --- | --- |
| `VIVADO=…` | Path to `vivado` / `vivado.bat` if not on PATH |
| `VIVADO_JOBS=N` | Parallel jobs for runs (default 4) |
| `SIM_TOP=module` | Override `sim_1` top module |
| `SIM_TIME=10us` | Fixed sim runtime instead of `run all` |

Examples:

```bash
make -C FPGA synth
make -C FPGA build
make -C FPGA sim SIM_TOP=tb_sniffer
make -C FPGA gui
```

## Agent conventions

1. Complete the **Required reading** list above before changing RTL or the register map.
2. Prefer **simulation** before claiming RTL works; add/extend testbenches under `senior_design.srcs/sim_1/`.
3. After RTL changes, run `make -C FPGA sim` and/or `make -C FPGA synth` as appropriate and report what ran.
4. Keep protocol/register/threat definitions aligned with `Docs/fabric_slop.md` and (when present) `GUI/backend/src/protocol.py`.
5. Do not present empty stubs or unsimulated modules as verified hardware behavior.
6. Use `make -C FPGA gui` when interactive debug is needed; keep batch Make as the default CI-style path.
