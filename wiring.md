# Bench wiring (quick glance)

Provisional **stand-alone** bring-up (no carrier PCB). Pins live in:

- UART: `Firmware/include/protocol.h`
- SPI: `Firmware/include/fpga_spi.h`
- Cmod SPI package pins: `FPGA/bringup.md` / `cmod_s7_bringup.xdc`

**3.3 V I/O only.** Do **not** cross VCC between USB-powered boards — **GND ↔ GND** only.

```
  PC ──USB-C──► Black Pill (power + DFU)
  PC ──USB────► CP2102 ──UART──► Black Pill PA9/PA10
  PC ──USB────► Cmod S7 (power + JTAG)
  Black Pill SPI1 ──jumpers──► Cmod DIP PIO40–43
  PC host ↔ FS device ──passthrough──► USB breakout
       └─ D+/D−/GND tap ──► Cmod port taps (PIO)
```

---

## Host UART (MCU ↔ CP2102 ↔ PC)

115200 8-N-1. CP2102 shows up as a COM port (often `COM3`).

| Signal | Black Pill | Wire to CP2102 |
| --- | --- | --- |
| TX | **PA9** (USART1_TX) | **RX** |
| RX | **PA10** (USART1_RX) | **TX** |
| GND | **GND** | **GND** |
| VCC | — | leave disconnected if both USB-powered |

TX/RX are **crossed** (MCU TX → dongle RX).

---

## SPI (MCU ↔ Cmod S7 FPGA)

Mode 0, ~1 MHz bring-up. MCU = master, FPGA = slave on **DIP PIO40–43** (not Pmod JA).

| Signal | Black Pill (SPI1) | Cmod package | DIP |
| --- | --- | --- | --- |
| SCK | **PA5** | **C5** (`spi_sck`) | **PIO40** |
| MOSI | **PA7** | **A2** (`spi_mosi`) | **PIO41** |
| MISO | **PA6** | **B2** (`spi_miso`) | **PIO42** |
| CS_n | **PA4** | **B1** (`spi_cs_n`) | **PIO43** |
| GND | **GND** | **GND** | — |

Cmod PIO pads have Digilent’s series R — keep SPI at bring-up rates (≤ a few MHz).

---

## USB breakout → FPGA (parallel FS tap)

FPGA **listens only** — same topology as the carrier: host↔device carries USB; FPGA taps D+/D− in parallel. **Do not** put the FPGA in series. **Do not** wire breakout **VCC/VBUS** to the Cmod.

```
  PC (USB host) ──► [breakout A] ── D+/D−/GND/VBUS wires ── [breakout B] ──► FS device
                         │              │
                         └─ D+ D− GND ──┘
                                  │
                                  ▼
                         Cmod pN_dp_tap / pN_dm_tap / GND
```

(Or one pass-through breakout with mid pins — same idea.)

### Recommended: port 1 (no boot selfstim mux)

| Breakout | Cmod signal | Package | DIP |
| --- | --- | --- | --- |
| **D+** | `p1_dp_tap` | **M2** | **PIO05** |
| **D−** | `p1_dm_tap` | **P3** | **PIO06** |
| **GND** | GND | any Cmod GND | — |
| **VCC** | — | leave on host↔device path only | — |

Watch **LED1** / SPI regs `0x20`–`0x27` (MCU UART bring-up is still port0-centric).

### Port 0 (works after selfstim; sticky demo state)

| Breakout | Cmod signal | Package | DIP |
| --- | --- | --- | --- |
| **D+** | `p0_dp_tap` | **L1** | **PIO01** |
| **D−** | `p0_dm_tap` | **M4** | **PIO02** |
| **GND** | GND | any Cmod GND | — |
| **VCC** | — | leave on host↔device path only | — |

Port0 boot selfstim still runs → sticky kill / VID·PID demo values. Press **`btn_clear`** (or SPI clear) before trusting live traffic; **`btn_rst`** re-fires selfstim. Kill LEDs can assert; without a MUX on the breadboard the USB link is not actually cut.

Short D+/D− jumpers; common GND with PC/device/Cmod. FS only.

**Attach / disconnect (FS + LS auto):** presence is USB **J** on D+/D− (idle device stays attached). Long **SE0** → disconnect, clears latched VID/PID so the GUI can go `DISCONNECTED` and re-enum a new device. Soft tap does **not** do High-Speed (480). Override with sniffer `SPEED_MODE` (0=auto, 1=FS, 2=LS).

**Know it’s not dummy data:** program a live-tap bit with no boot selfstim:

```powershell
make -C FPGA build ENABLE_SELFSTIM=0
make -C FPGA prog
```

Cold start should show no `0x1234`/`0x5678` / threat `0x1`. Anything that appears after plugging a real FS device (e.g. Rubber Ducky) is from the tap. Default `make -C FPGA build` restores the selfstim demo bit.

---

## USB plugs (PC)

| Cable | Board | Purpose |
| --- | --- | --- |
| USB-C | Black Pill | Power + DFU flash |
| USB-A/C | CP2102 | Host UART / GUI |
| USB micro | Cmod S7 | Power + Vivado JTAG / bitstream |

---

## Flash & view (cheat sheet)

```powershell
# MCU DFU: hold BOOT0, tap NRST, release BOOT0
make -C Firmware upload

# List COM, then watch UART
.\GUI\scripts\list_com_ports.ps1
py -3 -m serial.tools.miniterm COMx 115200

# Or GUI (pick COM in the header dropdown)
.\GUI\scripts\run_windows_serial.ps1
```

Cmod bitstream: `make -C FPGA prog` (after `make -C FPGA build`).

---

## Related docs

| Doc | Detail |
| --- | --- |
| `Firmware/README.md` | Firmware modes, expected SPI selfstim values |
| `FPGA/bringup.md` | LED demo, Cmod pin cheat sheet |
| `Docs/Board_slop.md` | Final carrier bus intent (may differ from this bench map) |
