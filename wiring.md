# Bench wiring (quick glance)

Provisional **stand-alone** bring-up (no carrier PCB). Source of truth for Cmod pins:

- Constraints: `FPGA/senior_design.srcs/constrs_1/new/cmod_s7_bringup.xdc`
- UART MCU pins: `Firmware/include/protocol.h` / CubeIDE USART1 — both **PA9/PA10** → CP2102
- SPI MCU pins: `Firmware/include/fpga_spi.h` (Black Pill SPI1) / CubeIDE SPI2 (Nucleo)
- Narrative: `FPGA/bringup.md`

**3.3 V I/O only.** Do **not** cross VCC between USB-powered boards — **GND ↔ GND** only.

If the CP2102 COM stream dies when a USB device (e.g. Rubber Ducky) attaches:

1. **Soft-tap without mux/eFuse in series does not stop host USB.** Kill LEDs can light while the Ducky still fully enumerates on the PC — that bus traffic often browns out a CP2102 on the **same** USB hub. Put the CP2102 on a **different USB root/hub** than the host breakout, or wire `mux_en_n` / `efuse_en` so kill actually opens the data/power path.
2. Keep UART jumpers short and away from D+/D−; star GND (Nucleo ↔ CP2102 ↔ Cmod ↔ breakout).
3. After flashing CubeIDE, miniterm should show `{"mcu":"uart_bm6"}` at boot and keep streaming JSON indefinitely (no host ACK).

Pick **one** MCU for the bench: Black Pill (PlatformIO) **or** NUCLEO-F411RE (CubeIDE). Host UART is the same on both (**USART1 PA9/PA10 ↔ CP2102**). Cmod SPI harness is the same; only MCU SPI pins differ.

```
  PC ──USB──► MCU (power + flash)     Black Pill USB-C  |  Nucleo ST-LINK USB (SWD only)
  PC ──USB──► CP2102 ──UART──► MCU PA9/PA10 (USART1)   ← same on both MCUs
  PC ──USB──► Cmod S7 (power + JTAG)
  MCU SPI ──jumpers──► Cmod DIP PIO40–43
  PC host ↔ FS/LS device ──passthrough──► USB breakout
       └─ D+/D−/GND tap ──► Cmod port taps (PIO)
```

---

## Cmod S7 pin map (this project)

All FPGA I/O below is from `cmod_s7_bringup.xdc`. **Package** = Spartan-7 ball; **DIP / PIO** = silkscreen number on the Cmod 48-pin DIP (Digilent naming). This is the **bench** map — the final carrier PCB may differ.

### Clock, buttons, LEDs

| RTL port | Package | On-board / note |
| --- | --- | --- |
| `clk_12m` | **M9** | 12 MHz oscillator |
| `btn_rst` | **D2** | BTN0 — fabric reset (+ MMCM reset) |
| `btn_clear` | **D1** | BTN1 — clear faults (all ports) |
| `led[0]` | **E2** | LED0 — port 0 kill |
| `led[1]` | **K1** | LED1 — port 1 kill |
| `led[2]` | **J1** | LED2 — port 2 kill |
| `led[3]` | **E1** | LED3 — port 3 kill |
| `led_r` | **F2** | RGB red (active-low) — any kill |
| `led_g` | **D3** | RGB green (active-low) |
| `led_b` | **F1** | RGB blue (active-low) |

### SPI slave (MCU ↔ FPGA) — header J2

| RTL port | Package | DIP / PIO | Black Pill (SPI1) | NUCLEO-F411RE (SPI2) |
| --- | --- | --- | --- | --- |
| `spi_sck` | **C5** | **PIO40** | **PA5** | **PB13** (Morpho **CN10-30**) |
| `spi_mosi` | **A2** | **PIO41** | **PA7** | **PB15** (Morpho **CN10-26**) |
| `spi_miso` | **B2** | **PIO42** | **PA6** | **PB14** (Morpho **CN10-28**) |
| `spi_cs_n` | **B1** | **PIO43** | **PA4** | **PB12** (Morpho **CN10-16**) |
| GND | — | any Cmod GND | **GND** | **GND** |

Mode 0, ~1 MHz bring-up. Cmod PIO has Digilent series R — keep SPI ≤ a few MHz. **Not** Pmod JA.

**Why Nucleo differs:** On NUCLEO-F411RE, Arduino **D13 / PA5** is both SPI1_SCK *and* green user LED **LD2** (UM1724). CubeIDE firmware uses **SPI2 on PB12–PB15** so LD2 can pulse like the Black Pill status LED. Do **not** use Arduino D10–D13 for Nucleo SPI in this project (D10 CS is PB6; D13 is the LED).

### USB port taps + kill outs — all four channels

Each channel: **D+ tap**, **D− tap**, **`mux_en_n`** (high when killed), **`efuse_en`** (low when killed). For soft-tap listen-only, wire **D+/D−/GND** only; leave mux/efuse unconnected until you have switches.

| Port | Signal | Package | DIP / PIO | SPI register bank |
| --- | --- | --- | --- | --- |
| **0** | `p0_dp_tap` | **L1** | **PIO01** | `0x10`–`0x17` |
| **0** | `p0_dm_tap` | **M4** | **PIO02** | |
| **0** | `p0_mux_en_n` | **M3** | **PIO03** | |
| **0** | `p0_efuse_en` | **N2** | **PIO04** | |
| **1** | `p1_dp_tap` | **M2** | **PIO05** | `0x20`–`0x27` |
| **1** | `p1_dm_tap` | **P3** | **PIO06** | |
| **1** | `p1_mux_en_n` | **N3** | **PIO07** | |
| **1** | `p1_efuse_en` | **P1** | **PIO08** | |
| **2** | `p2_dp_tap` | **N1** | **PIO09** | `0x30`–`0x37` |
| **2** | `p2_dm_tap` | **P14** | **PIO16** | |
| **2** | `p2_mux_en_n` | **P15** | **PIO17** | |
| **2** | `p2_efuse_en` | **N13** | **PIO18** | |
| **3** | `p3_dp_tap` | **N15** | **PIO19** | `0x40`–`0x47` |
| **3** | `p3_dm_tap` | **N14** | **PIO20** | |
| **3** | `p3_mux_en_n` | **M15** | **PIO21** | |
| **3** | `p3_efuse_en` | **M14** | **PIO22** | |

FPGA fabric instantiates all four sniffers. **SPI bring-up firmware polls ports 0–3** and sets HID-after-confirm on each; wire D+/D−/GND to the PIO pins above and the matching GUI port card should update.

---

## MCU option A — Black Pill (PlatformIO)

```
  PC ──USB-C──► Black Pill (power + DFU)
  PC ──USB────► CP2102 ──UART──► Black Pill PA9/PA10
  PC ──USB────► Cmod S7 (power + JTAG)
  Black Pill SPI1 ──jumpers──► Cmod DIP PIO40–43
```

Tree: `Firmware/` (`make -C Firmware build` / `upload`). Status LED: **PC13** (active-low).

### Host UART (Black Pill ↔ CP2102 ↔ PC)

115200 8-N-1. CP2102 shows up as a COM port (often `COM3`).

| Signal | Black Pill | Wire to CP2102 |
| --- | --- | --- |
| TX | **PA9** (USART1_TX) | **RX** |
| RX | **PA10** (USART1_RX) | **TX** |
| GND | **GND** | **GND** |
| VCC | — | leave disconnected if both USB-powered |

TX/RX are **crossed** (MCU TX → dongle RX).

### SPI jumpers (Black Pill)

| Black Pill (SPI1) | Direction | Cmod DIP |
| --- | --- | --- |
| **PA5** SCK | → | **PIO40** |
| **PA7** MOSI | → | **PIO41** |
| **PA6** MISO | ← | **PIO42** |
| **PA4** CS_n | → | **PIO43** |
| **GND** | ↔ | **GND** |

---

## MCU option B — NUCLEO-F411RE (CubeIDE)

```
  PC ──USB────► Nucleo ST-LINK (power + SWD only — not used for GUI UART)
  PC ──USB────► CP2102 ──UART──► Nucleo PA9/PA10 (USART1)
  PC ──USB────► Cmod S7 (power + JTAG)
  Nucleo SPI2 ──jumpers──► Cmod DIP PIO40–43
```

Tree: `CubeIDEProject/Group19_MCU_Demo/`. Status LED: onboard **LD2** on **PA5** (active-high). Host UART matches Black Pill / carrier: **USART1 PA9/PA10 ↔ CP2102** (do **not** use ST-LINK VCP for the GUI).

### Host UART (Nucleo ↔ CP2102)

Same crossing as Black Pill. 115200 8-N-1. Pick the **CP2102** COM port in the GUI (not the ST-LINK COM).

| Signal | Nucleo | Header | Wire to CP2102 |
| --- | --- | --- | --- |
| TX | **PA9** (USART1_TX) | Arduino **D8** | **RX** |
| RX | **PA10** (USART1_RX) | Arduino **D2** | **TX** |
| GND | **GND** | any GND | **GND** |
| VCC | — | — | leave disconnected if both USB-powered |

### SPI jumpers (Nucleo) — use Morpho CN10

| Nucleo (SPI2) | Morpho pin | Direction | Cmod DIP |
| --- | --- | --- | --- |
| **PB13** SCK | **CN10-30** | → | **PIO40** |
| **PB15** MOSI | **CN10-26** | → | **PIO41** |
| **PB14** MISO | **CN10-28** | ← | **PIO42** |
| **PB12** CS_n | **CN10-16** | → | **PIO43** |
| **GND** | CN7/CN10 GND | ↔ | **GND** |

CN10 pin numbers: ST Morpho connector on the **right** edge of the board (UM1724 Fig. 18 / Table 16 family). Confirm silkscreen against the Nucleo pinout card if unsure.

---

## USB breakout → FPGA (parallel tap)

FPGA **listens only** — host↔device carries USB; FPGA taps D+/D− in parallel. **Do not** put the FPGA in series. **Do not** wire breakout **VCC/VBUS** to the Cmod.

```
  PC (USB host) ──► [breakout A] ── D+/D−/GND/VBUS wires ── [breakout B] ──► device
                         │              │
                         └─ D+ D− GND ──┘
                                  │
                                  ▼
                         Cmod pN_dp_tap / pN_dm_tap / GND
```

### Live-tap bitstream (required for a real keyboard)

```powershell
make -C FPGA build ENABLE_SELFSTIM=0
make -C FPGA prog
```

Default `ENABLE_SELFSTIM=1` drives **dummy** HID on port 0 and is for LED demo only.

### Recommended bench: port 0 (GUI / MCU live today)

| Breakout | Cmod signal | Package | DIP |
| --- | --- | --- | --- |
| **D+** | `p0_dp_tap` | **L1** | **PIO01** |
| **D−** | `p0_dm_tap` | **M4** | **PIO02** |
| **GND** | GND | any Cmod GND | — |
| **VCC** | — | host↔device path only | — |

Watch **LED0**. With SPI bring-up firmware, port0 policy is set to HID-after-confirm so a keyboard should go `PENDING_HID_CONFIRM` (popup). Storage-only policy → sticky threat `0x1` / quarantined (no confirm popup).

### Ports 1–3

Same breakout wiring (e.g. port 1 = **PIO05/06**). After flashing current SPI bring-up firmware, UART/GUI should mirror that port like port 0.

Short D+/D− jumpers; common GND with PC/device/Cmod. Soft RX auto-selects **FS or LS** from idle J. Long **SE0** → disconnect / clear latched VID·PID. Soft tap is **not** High-Speed (480).

---

## USB plugs (PC)

| Cable | Board | Purpose |
| --- | --- | --- |
| USB-C | Black Pill | Power + DFU flash |
| USB (Mini-B / ST-LINK) | NUCLEO-F411RE | Power + SWD + VCP |
| USB-A/C | CP2102 | Host UART / GUI (**Black Pill only**) |
| USB micro | Cmod S7 | Power + Vivado JTAG / bitstream |

---

## Flash & view (cheat sheet)

### Black Pill

```powershell
# MCU DFU: hold BOOT0, tap NRST, release BOOT0
make -C Firmware upload

# List COM, then watch UART (CP2102)
.\GUI\scripts\list_com_ports.ps1
py -3 -m serial.tools.miniterm COMx 115200

# Or GUI (pick COM in the header dropdown)
.\GUI\scripts\run_windows_serial.ps1
```

### Nucleo

Flash/debug from **STM32CubeIDE** (`CubeIDEProject/Group19_MCU_Demo`). Open the **CP2102** COM port @ 115200 (same as Black Pill), or pick that COM in the GUI — not the ST-LINK VCP port.

Cmod bitstream (either MCU): `make -C FPGA prog` (after `make -C FPGA build`).

---

## Related docs

| Doc | Detail |
| --- | --- |
| `Firmware/README.md` | Black Pill PlatformIO modes, expected SPI selfstim values |
| `CubeIDEProject/Group19_MCU_Demo/` | Nucleo CubeIDE project (SPI2 + LD2) |
| `FPGA/bringup.md` | LED demo, Cmod pin cheat sheet |
| `Docs/Board_slop.md` | Final carrier bus intent (may differ from this bench map) |
