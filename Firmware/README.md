# MCU firmware (Black Pill STM32F411)

Management-plane firmware for the hardware-secure USB hub. Speaks newline-delimited JSON over UART to the Flutter operator console ([`GUI/`](../GUI/), contract in [`Docs/firmwmare_slop.md`](../Docs/firmwmare_slop.md)). SPI master talks to the Cmod S7 FPGA slave ([`Docs/fabric_slop.md`](../Docs/fabric_slop.md) §5, [`FPGA/bringup.md`](../FPGA/bringup.md)).

## Honesty — what is live vs mock

| Field / path | Default build (`blackpill_f411ce`, `FPGA_SPI_BRINGUP`) | Mock build (`blackpill_uart_mock`) |
| --- | --- | --- |
| Ports 0–3 `state` / `threat_code` / VID / PID / classes | **LIVE** SPI from FPGA (prototype) | Port0 scripted; timed port-1 HID demo |
| `vbus_mv` / `current_ma` | Omitted / no INA219 | Omitted |
| GUI `isolate` / `clear_fault` / `confirm_hid` | **LIVE** SPI `Pn_CONTROL` (all ports; policy preserved) | Local mock only |
| Human-readable `SPI LIVE …` UART lines | Yes (~5 Hz), compact 4-port status | No |

Prototype soft-tap bring-up — not production carrier firmware. No power sensors yet.

## Hardware paths

| Link | Use |
| --- | --- |
| Black Pill **USB-C** | Power + DFU flash |
| **CP2102** (second PC COM) | Host UART @ 115200 8-N-1 |
| **Cmod S7** USB | FPGA power + JTAG program (`make -C FPGA prog`) |
| SPI jumpers | MCU SPI1 ↔ Cmod DIP **PIO40–43** (see `wiring.md`) |

**Nucleo alternate:** `CubeIDEProject/Group19_MCU_Demo/` targets **NUCLEO-F411RE** with **SPI2 (PB12–15)** + **LD2 on PA5** and **USART1 PA9/PA10 ↔ CP2102** (same UART pins as Black Pill). See **MCU option B** in [`wiring.md`](../wiring.md).

### Provisional UART jumpers (`include/protocol.h`)

| Black Pill | Direction | CP2102 |
| --- | --- | --- |
| `PA9` (USART1_TX) | → | **RX** |
| `PA10` (USART1_RX) | ← | **TX** |
| `GND` | ↔ | `GND` |

Do **not** cross VCC when both ends are USB-powered.

### Provisional SPI jumpers (`include/fpga_spi.h`) — Cmod stand-alone

| Black Pill (SPI1) | Direction | Cmod DIP (FPGA) |
| --- | --- | --- |
| `PA5` SCK | → | `spi_sck` **PIO40** (C5) |
| `PA7` MOSI | → | `spi_mosi` **PIO41** (A2) |
| `PA6` MISO | ← | `spi_miso` **PIO42** (B2) |
| `PA4` CS_n | → | `spi_cs_n` **PIO43** (B1) |
| `GND` | ↔ | `GND` |

3.3 V I/O only. SPI Mode 0, 1 MHz bring-up clock, 16-bit frames. Full port pin map: [`wiring.md`](../wiring.md).

## Tools

- Python 3 + PlatformIO: `py -3 -m pip install -U platformio`
- Invoke via `py -3 -m platformio` if `pio` is not on `PATH`
- CP210x VCP drivers; Windows DFU: Zadig WinUSB on `STM32 BOOTLOADER` (see below)

## Build / flash

```bash
make -C Firmware build          # SPI bring-up (default env)
make -C Firmware upload

make -C Firmware build-mock     # UART mock only
make -C Firmware upload-mock
```

**DFU upload (USB-C):**

1. Hold **BOOT0**, tap **NRST**, release **BOOT0** → `STM32 BOOTLOADER`.
2. First Windows install: Zadig → WinUSB for that device.
3. `make -C Firmware upload`
4. Reset with BOOT0 released if needed.

## FPGA SPI bring-up (default firmware)

Prereq: live-tap bitstream (`make -C FPGA build ENABLE_SELFSTIM=0 && make -C FPGA prog`).

Wire SPI + UART (see `wiring.md`). Open the CP2102 COM:

```powershell
py -3 -m serial.tools.miniterm COMx 115200
```

**Expected:**

- Boot: `MCU: FPGA_SPI_BRINGUP — ports 0-3 LIVE SPI; policy=HID_CONFIRM`
- Lines like: `SPI LIVE sys=0x.. P0=0x..(a=.. k=.. h=.. t=..) P1=... P2=... P3=...`
- Plug a keyboard on **PIO01/02** (port 0) or **PIO05/06** (port 1): that port’s `a=1`, HID → `h=1`, JSON `PENDING_HID_CONFIRM`
- JSON streams all four ports from SPI

GUI:

```powershell
cd GUI
.\scripts\run_windows_serial.ps1 -Port COMx
```

Host commands on any port write that channel’s `Pn_CONTROL` (`isolate_port` → bit7; `clear_fault` / `restore_port` → clear pulse; `confirm_hid` → approve bit5). Soft-tap cannot physically mute USB until carrier MUX exists.

## Mock-only UART (no Cmod)

```bash
make -C Firmware upload-mock
```

Port 0 starts authorized; port 1 auto-authorizes ~5 s then `KEYSTROKE_BURST` ~15 s. PC13 LED pulses on demo/commands.

```powershell
py -3 Firmware\tools\uart_smoke.py --port COMx
```

## Make targets

| Target | Action |
| --- | --- |
| `make build` / `upload` | Default SPI bring-up env |
| `make build-mock` / `upload-mock` | UART mock env |
| `make clean` | Remove PlatformIO build products |
| `make monitor` | PlatformIO monitor (prefer miniterm on CP2102 COM) |

## Layout

| Path | Role |
| --- | --- |
| `platformio.ini` | `blackpill_f411ce` (SPI bring-up) + `blackpill_uart_mock` |
| `include/protocol.h` | UART baud/pins, threat/state/cmd strings |
| `include/fpga_spi.h` | SPI pins + FPGA register/bit constants |
| `include/fpga_bridge.h` / `src/fpga_bridge.cpp` | `spi_read8` / `spi_write8` + port helpers |
| `src/main.cpp` | Mock UART loop **or** SPI bring-up loop |
| `Makefile` | `pio` wrappers |

## Next

- I²C → INA219 for live `vbus_mv` / `current_ma`
- Poll ports 1–3; lock pins to carrier schematic
- Drop dual-mode once SPI+sensors are default
