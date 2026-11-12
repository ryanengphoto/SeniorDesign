# Cmod S7 FPGA bring-up

Stand-alone demo path for the sniffer fabric **without** the carrier PCB. Source of truth for board pins: `senior_design.srcs/constrs_1/new/cmod_s7_bringup.xdc`. Specs: `Docs/sniffer_block_spec.md`, `Docs/fabric_slop.md`.

## What the bitstream does

`main_wrapper` (top):

1. 12 MHz → 48 MHz MMCM (`clk_wiz_12_to_48`)
2. After lock, waits ~20 ms (`BOOT_STIM_CYCLES = 1_000_000` @ 48 MHz)
3. `usb_demo_selfstim` plays FS SETUP + device desc + HID config on **port 0**
4. Storage-only policy → HID interface class `0x03` → sticky kill threat `0x1`
5. LEDs / RGB show kill; `btn_clear` clears faults; `btn_rst` re-arms the demo

Bitstream (after `make build`):

`senior_design.runs/impl_1/main_wrapper.bit`

## Pre-board simulation

Gate before programming the Cmod: **`make sim-all`** must be green.

Full TB inventory, Make/env overrides (`SIM_TOP`, `SIM_TIME`, `COV`, …), RTL sim
knobs (`SIM_CLK_BYPASS`, `BOOT_STIM_CYCLES`), coverage, and how to add a TB:
**[`testing.md`](testing.md)** (also linked from [`AGENTS.md`](AGENTS.md)).

```bat
cd FPGA
make sim-all
```

## Hardware bring-up procedure (no carrier)

From a terminal on this PC (Vivado 2018.2 installed):

```bat
cd FPGA
make build
```

Plug the **Cmod S7 USB** into this machine (Digilent JTAG). Then:

```bat
make prog
```

(`make prog` runs `scripts/prog.tcl`: Hardware Manager → program `senior_design.runs/impl_1/*.bit`. Override with `make prog BIT=path\to\file.bit`.)

**Important (2018.2):** close the Vivado GUI Hardware Manager session (or disconnect the target) before `make prog`, or the batch job may not get the Digilent cable. You can also program from the GUI instead.

Manual GUI alternate: Vivado → Open Hardware Manager → Auto Connect → Program Device → select `main_wrapper.bit`.

### After programming — what you should see

1. After config (~20 ms): expect **LED0 on**, **RGB red** (active-low red), green during/after stim.
2. Press **btn_clear** (D1): LED0 / red off. Telemetry (VID/PID/class) remains in registers.
3. Press **btn_rst** (D2): MMCM re-lock / reset; sequence re-arms and repeats.
4. Optional: SPI master on **DIP PIO40–43** (`spi_sck/mosi/miso/cs_n`) — read `P0_STATUS` `0x11`, VID/PID `0x12`–`0x15`, classes `0x16`–`0x17`. Expect isolated+threat `0xC1` style status while killed.

### Pin cheat sheet (Digilent Cmod S7 bring-up XDC)

| Role | Port | Package |
| --- | --- | --- |
| Clock | `clk_12m` | M9 |
| Reset button | `btn_rst` | D2 |
| Clear button | `btn_clear` | D1 |
| Kill LEDs | `led[3:0]` | E2, K1, J1, E1 |
| RGB (active-low) | `led_r/g/b` | F2, D3, F1 |
| SPI | `spi_sck/mosi/miso/cs_n` | PIO40–43 (C5, A2, B2, B1) |
| Port0–3 taps / kill | `pN_dp_tap`, `pN_dm_tap`, `pN_mux_en_n`, `pN_efuse_en` | PIO headers |

Carrier/gateway pin map in `Docs/fabric_slop.md` may differ; this file is the **stand-alone Cmod** map.

## Agent / automated workflow (once board is plugged in)

Possible on the same PC if Vivado sees the Digilent cable:

1. Build bitstream (normal or debug/ILA variant).
2. Batch program via Hardware Manager TCL (`open_hw_manager` → `program_hw_devices`).
3. Operator watches LEDs / presses buttons per procedure above.
4. Optional: arm ILA, wait for trigger, export probe data for the agent to check.

Batch program: `make prog` (`scripts/prog.tcl`). Optional later: `DEBUG_ILA=1` debug bitstream. Regression: `make sim-all` (see above).

**Limits:** Agent cannot usefully “watch” the GUI waveform live; batch ILA dump + file check is the automation path. Board must be connected to **this** machine’s USB.

## ILA (optional debug bitstream)

Useful probes (keep set small — XC7S25 is LUT-tight):

- `kill[0]`, `threat_code[0]`
- `stim_start` / `stim_busy` / `stim_done` / `stim_oe`
- `pkt_end[0]`, `crc_ok[0]`
- Optional: SPI `reg_we` / `reg_raddr` around MCU reads

Suggested triggers:

- Rising `kill[0]` (HID or CRC isolation)
- Rising `stim_start` (demo sequence begin)

Normal release bitstream should stay ILA-free; use a separate debug build flag when added.

## Pass / fail criteria (bench demo)

| Check | Pass |
| --- | --- |
| After program | LED0 asserts without external USB traffic |
| RGB | Red active while port0 isolated |
| `btn_clear` | Kill releases |
| `btn_rst` | Demo re-runs |
| SPI (if used) | `P0_STATUS` shows threat `0x1` while killed; VID `0x1234` / PID `0x5678` / intf class `0x03` |

## Out of scope for this bring-up

- Real D+/D− from a USB device (needs taps / carrier)
- MCU firmware loop and GUI on live UART
- HID keystroke timing, LS USB, packet FIFO
