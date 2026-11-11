# FPGA simulation & verification

Source of truth for **testbenches, how to run them, Make/env overrides, and coverage**.  
Board bring-up (LEDs, pins, bitstream) stays in [`bringup.md`](bringup.md). Specs: [`Docs/sniffer_block_spec.md`](../Docs/sniffer_block_spec.md), [`Docs/fabric_slop.md`](../Docs/fabric_slop.md).

Toolchain: **Vivado / XSim 2018.2** (lab default). Prefer Make from `FPGA/` or `make -C FPGA …` from the repo root.

---

## Quick start

```bat
cd FPGA
make help
make sim SIM_TOP=tb_sniffer
make sim-all
make cov-verilator
```

Windows lab: Makefile picks `C:/Xilinx/Vivado/2018.2/bin/vivado.bat` when present. Override with `VIVADO=…` if needed.  
`make cov-verilator` needs MSYS2 ucrt64 Verilator (`pacman -S mingw-w64-ucrt-x86_64-verilator`).

Pass/fail: each TB must `$display("tb_…: PASS")` (or `FAIL`). `scripts/sim.tcl` / `sim_all.tcl` scrape `simulate.log` after `close_sim` and exit ≠0 on failure or missing PASS. Isolation checker `$error("isolation_controller SVA: …")` also fails the scrape.

---

## Make targets

| Target | Action | Script |
| --- | --- | --- |
| `make help` | List targets + overrides | — |
| `make sim` | One behavioral XSim run | `scripts/sim.tcl` |
| `make sim-all` | Full sniffer TB regression (one Vivado process) | `scripts/sim_all.tcl` |
| `make cov-verilator` | Line/branch/toggle coverage (Verilator sidecar) | `scripts/run_verilator_cov.sh` |
| `make synth` | Synthesis only | `scripts/synth.tcl` |
| `make build` | Synth + implement + bitstream | `scripts/build.tcl` |
| `make gui` | Open `senior_design.xpr` | — |
| `make clean` | Remove generated Vivado dirs + `cov/` + `verilator/obj_dir` | — |

Add new RTL/sim files to the `.xpr` with:

```bat
vivado -mode batch -source scripts/add_sniffer_sources.tcl -nojournal -nolog
```

(`Makefile` does not wrap this yet; keep `SIM_ALL_TOPS` in the Makefile and `tops` in `sim_all.tcl` in sync.)

---

## Config / overrides

| Variable | Used by | Purpose | Default |
| --- | --- | --- | --- |
| `VIVADO` | all | Path to `vivado` / `vivado.bat` | `vivado`, or lab `…/2018.2/bin/vivado.bat` on Windows |
| `VIVADO_JOBS` | `build` / `synth` | Parallel jobs for runs | `4` |
| `SIM_TOP` | `sim` | Override `sim_1` top module | project default (`tb_sniffer`) |
| `SIM_TIME` | `sim` / `sim-all` | Fixed XSim runtime (e.g. `10us`) instead of `run all` | empty → `all` |
| `COV` | `sim-all` | Try native XSim line/branch/condition/toggle coverage | `0` |
| `MSYS_BASH` | `cov-verilator` | Path to MSYS2 bash for Verilator on Windows | `C:/msys64/usr/bin/bash.exe` |

Examples:

```bat
make sim SIM_TOP=tb_kill_e2e
make sim SIM_TOP=tb_main_selfstim SIM_TIME=2ms
make sim-all COV=1
make build VIVADO="C:/Xilinx/Vivado/2018.2/bin/vivado.bat" VIVADO_JOBS=8
```

### RTL sim knobs (`main_wrapper` parameters)

Board bitstream leaves defaults. TBs that instantiate the board top override them.

| Parameter | Meaning | Board default |
| --- | --- | --- |
| `SIM_CLK_BYPASS` | Skip MMCM; TB drives `clk_12m` at 48 MHz | `0` |
| `BOOT_STIM_CYCLES` | Cycles after MMCM lock before `usb_demo_selfstim` | `1_000_000` (~20 ms @ 48 MHz) |

Used by `tb_main_selfstim` (bypass + short boot delay).

---

## Testbench inventory

Sources live under `senior_design.srcs/sim_1/new/`. DUT RTL under `sources_1/new/`. Shared USB TX stimulus: `usb_fs_tx` (also used by on-FPGA `usb_demo_selfstim`).

### Regression tops (`make sim-all`)

Must match `SIM_ALL_TOPS` in `Makefile` and `tops` in `scripts/sim_all.tcl`.

| Top | What it proves |
| --- | --- |
| `tb_sniffer` | Port0 CRC → kill threat `0x5` (smoke) |
| `tb_enumeration_analysis` | Direct-event device + config descriptor telemetry |
| `tb_kill_e2e` | All ports sequential + concurrent CRC kill; sticky until SPI `Pn_CONTROL[6]` clear |
| `tb_enum_e2e` | Wire SETUP + descriptors → VID/PID/class latch (no kill) |
| `tb_demo_threat` | Wire HID interface on storage-only policy → kill `0x1` |
| `tb_spi_enum_e2e` | Wire enum → SPI-read `Pn_STATUS`/VID/PID/class; HID kill `0x1` + SPI clear |
| `tb_main_selfstim` | `main_wrapper` auto self-stim → LED kill → SPI telemetry → `btn_clear` |
| `tb_spi_manual_kill` | SPI `Pn_CONTROL[7]` → threat `0x7` + clear (all ports; no USB) |
| `tb_kill_manual_cross` | CRC↔SPI-manual: overwrite to `0x7`, sticky ignore of CRC, re-arm |
| `tb_cov_isolation` | Directed isolation paths + threat sweep; XSim runs `isolation_controller_sva` |
| `tb_cov_sniffer` | Broad sniffer/enum/HID/CRC stimulus for coverage; XSim runs SVA on both DUT instances |

### Sim-only checkers (not a sim top)

All are procedural (XSim 2018.2 ignores concurrent `assert property` / XSIM 43-4127). Instantiated under `synthesis translate_off` + `` `ifndef VERILATOR ``. Any `$error("… SVA: …")` fails `sim` / `sim-all`.

| File | Attached to | Checks |
| --- | --- | --- |
| `isolation_controller_sva.sv` | `isolation_controller` | Sticky kill; manual→`0x7`; clear releases; threat latch; sticky threat ignore |
| `sniffer_block_sva.sv` | `sniffer_block` | HID/CRC threat mux; `POLICY_STORAGE_ONLY`; `port_status` bits |
| `enumeration_analysis_sva.sv` | `enumeration_analysis` | Legal `ST_*`; sticky `attached` / desc / intf valid |
| `usb_packet_frontend_sva.sv` | `usb_packet_frontend` | `crc_fault`↔`pkt_end`; no orphan end; `data_valid` in-packet |
| `sniffer_wrapper_sva.sv` | `sniffer_wrapper` | Per-port status mirror; cross-port clear isolation; `0x7` needs manual |
| `register_file_sva.sv` | `register_file` | CONTROL[6/7]→clear/manual; RO VID/PID/class/status mirrors |
| `spi_slave_sva.sv` | `spi_slave` | `reg_we` only while CS active; single-cycle we |
| `main_wrapper_sva.sv` | `main_wrapper` | `mux_en_n`/`efuse_en`/`led`/`led_r` polarity vs `kill` |

**XSim 2018.2 limits:** concurrent `assert property` / `cover property` ignored; file-scope `bind` can hit VRFC 10-946.

### Assertions — depth and scope

DUT-attached checkers cover Priority-1/2 fabric contracts continuously on XSim. Still **not** property-checked (TB scoreboards only): HID timing `0x2`/`0x3`, descriptor overflow `0x4`, bit-stuff `0x6`, deep TinyFPGA line-state FSM.

### Common TB patterns

- Clock: 48 MHz (`#10.4167` half-period) unless noted.
- SPI: Mode 0, 16-bit frames (same BFM pacing across SPI TBs).
- USB line: `usb_fs_tx` + optional bit corrupt for CRC faults.
- Clear path: SPI write `Pn_CONTROL[6]` (pulse), then often drop CONTROL to `0x00`.
- Manual isolate: SPI write `Pn_CONTROL[7]` (`0x80`).

---

## Coverage

| Mechanism | When | Output |
| --- | --- | --- |
| **Verilator code coverage** (preferred on lab PCs) | `make cov-verilator` | `FPGA/cov/verilator/summary.txt`, annotated RTL under `annotate/`, `coverage.info` (lcov) |
| Scenario matrix | Every `sim-all` | `FPGA/cov/scenario_matrix.txt` (gitignored) |
| Native XSim code coverage (`sbct`) | `COV=1` **and** Vivado ≈2020.1+ with `xcrg` | `FPGA/cov/xsim_db/` (unavailable on 2018.2) |
| Procedural `*_sva` checkers | XSim DUT sims | `$error("… SVA: …")` (see checker table) |

### Verilator sidecar

Acceptance remains **`make sim-all` (XSim)** — that is where `isolation_controller_sva` runs. Verilator is for **code-coverage metrics only**; it does **not** replace assertion regression.

| Piece | Path / note |
| --- | --- |
| Tool | MSYS2 ucrt64 **Verilator 5.040** (`pacman -S mingw-w64-ucrt-x86_64-verilator`) |
| Run | `make cov-verilator` → `scripts/run_verilator_cov.sh` (Windows: `MSYS_BASH`) |
| Shared TBs | `sim_1/new/tb_cov_isolation.sv`, `tb_cov_sniffer.sv` (same files XSim uses) |
| Notes | `verilator/README.md`; build trees under `verilator/obj_dir/` (gitignored) |
| Flags | `--binary --timing --coverage` (line + branch/expr + toggle; no native FSM on 5.040) |
| SVA | Stripped via `` `ifndef VERILATOR `` on all `*_sva` instantiations |
| DUT scope | `isolation_controller` + `sniffer_block` + enum + TinyFPGA RX/TX/`strobe`. **Not** `main_wrapper` / MMCM / SPI RF |
| Outputs | `cov/verilator/summary.txt`, `annotate/`, `coverage.info` (lcov), `merged.dat` |
| Helpers | `scripts/line_cov_summary.py`, `cov_type_summary.py`, `toggle_cov_summary.py` |

**Workflow:** improve stimulus in `tb_cov_*` → `make cov-verilator` for metrics → `make sim SIM_TOP=tb_cov_isolation` / `tb_cov_sniffer` (or `sim-all`) to confirm SVA + TB `$error` still PASS.

Recent DUT ballpark (`tb_cov_*`): **~99% line**, **~84% branch**, **~41% toggle**. Toggle is dominated by wide `mem[]` / `setup[]` / PHY flops — do not chase bit-complete toggle for midterm.

Remaining `%00` in `enumeration_analysis` are mostly defensive/unreachable (`default`, `want_dtype` else) or `setup_count` reset when `pid` may not yet be DATA at `pkt_start`. No separate FSM coverage on 5.040 (`fsm_state`/`fsm_arc` need a newer Verilator); treat FSM quality as those case arms + BRDA.

---

## Adding a testbench

1. Add `senior_design.srcs/sim_1/new/tb_foo.sv` that ends with `tb_foo: PASS` / `FAIL`.
2. Register it in `scripts/add_sniffer_sources.tcl`, run that script once.
3. Append to `SIM_ALL_TOPS` (`Makefile`) and `tops` (`scripts/sim_all.tcl`).
4. Extend PASS/FAIL regexes in `scripts/sim.tcl` if the name is new.
5. Document the row in this file (and a one-liner in `Docs/sniffer_block_spec.md` if it is a fabric acceptance path).
6. Run `make sim SIM_TOP=tb_foo` then `make sim-all`.

---

## Logs & cleanup

| Path | Contents |
| --- | --- |
| `senior_design.sim/sim_1/behav/xsim/simulate.log` | Last TB transcript (PASS/FAIL) |
| `senior_design.sim/sim_1/behav/xsim/elaborate.log` | Elab warnings (e.g. ignored SVA) |
| `FPGA/cov/` | Scenario matrix + optional native CC DB |

`make clean` removes `senior_design.{cache,runs,sim,hw,…}` and `cov/`.
