# MCU firmware (Black Pill STM32F411)

Management-plane firmware for the hardware-secure USB hub. Speaks newline-delimited JSON over UART to the Flutter operator console ([`GUI/`](../GUI/), contract in [`Docs/firmwmare_slop.md`](../Docs/firmwmare_slop.md)). SPI master talks to the Cmod S7 FPGA slave ([`Docs/fabric_slop.md`](../Docs/fabric_slop.md) §5, [`FPGA/bringup.md`](../FPGA/bringup.md)).

## Honesty — what is live vs mock

| Field / path | Default build (`blackpill_f411ce`, `FPGA_SPI_BRINGUP`) | Mock build (`blackpill_uart_mock`) |
| --- | --- | --- |
| Port0 `state` / `threat_code` / VID / PID / classes | **LIVE** SPI from FPGA | **MOCK** scripted |
| Port0 `vbus_mv` / `current_ma` | **MOCK** (zeros; no INA219) | **MOCK** |
| Ports 1–3 | Idle / disconnected (**MOCK**) | Timed port-1 demo (**MOCK**) |
| GUI `isolate` / `clear_fault` on port0 | **LIVE** SPI `P0_CONTROL` | Local mock only |
| Human-readable `SPI LIVE …` UART lines | Yes (~5 Hz) | No |

Do not treat a SERIAL GUI badge as “full carrier / sensors / 4-port policy.”

## Hardware paths

| Link | Use |
| --- | --- |
| Black Pill **USB-C** | Power + DFU flash |
| **CP2102** (second PC COM) | Host UART @ 115200 8-N-1 |
| **Cmod S7** USB | FPGA power + JTAG program (`make -C FPGA prog`) |
| SPI jumpers | MCU SPI1 ↔ Cmod Pmod JA |

### Provisional UART jumpers (`include/protocol.h`)

| Black Pill | Direction | CP2102 |
| --- | --- | --- |
| `PA9` (USART1_TX) | → | **RX** |
| `PA10` (USART1_RX) | ← | **TX** |
| `GND` | ↔ | `GND` |

Do **not** cross VCC when both ends are USB-powered.

### Provisional SPI jumpers (`include/fpga_spi.h`) — Cmod stand-alone

| Black Pill (SPI1) | Direction | Cmod Pmod JA (FPGA) |
| --- | --- | --- |
| `PA5` SCK | → | `spi_sck` **J2** |
| `PA7` MOSI | → | `spi_mosi` **H2** |
| `PA6` MISO | ← | `spi_miso` **H4** |
| `PA4` CS_n | → | `spi_cs_n` **F3** |
| `GND` | ↔ | `GND` |

3.3 V I/O only. SPI Mode 0, 1 MHz bring-up clock, 16-bit frames.

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

Prereq: Cmod programmed with `main_wrapper.bit` (`make -C FPGA build && make -C FPGA prog`). After ~20 ms selfstim, port0 should be sticky-killed (LED0 / RGB red).

Wire SPI table above + UART to CP2102. Open the CP2102 COM:

```powershell
py -3 -m serial.tools.miniterm COMx 115200
```

**Expected while killed (selfstim):**

- Human lines like: `SPI LIVE … P0_STATUS=0xC1 kill=1 att=1 threat=0x1 VID=0x1234 PID=0x5678 … intf=0x03`
- Then a one-shot: `pulsing P0_CONTROL clear_fault` → `kill=0` (board RGB should go green / LED0 off if clear worked)
- JSON frames still stream; port0 threat/VID/PID reflect SPI (**power fields remain mock**)

GUI (optional):

```powershell
cd GUI
.\scripts\run_windows_serial.ps1 -Port COMx
```

Host commands on port0 in SPI bring-up mode write FPGA `P0_CONTROL` (`isolate_port` → manual kill bit7; `clear_fault` / `restore_port` → clear pulse).

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
