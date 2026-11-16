# Firmware — Agent notes

STM32F411 Black Pill management-plane firmware (PlatformIO). Distinct from FPGA HDL and the Flutter GUI.

## Required reading

- [`Docs/firmwmare_slop.md`](../Docs/firmwmare_slop.md) — MCU role, UART JSON, polling loop
- [`Docs/fabric_slop.md`](../Docs/fabric_slop.md) — SPI map + threat codes (**SoT for addresses/framing**)
- [`FPGA/bringup.md`](../FPGA/bringup.md) — Cmod SPI pin cheat sheet + selfstim expected values
- Live packing: `FPGA/.../register_file.sv` `pack_spi_status` / `spi_slave.sv`
- [`Docs/d_c_txt.md`](../Docs/d_c_txt.md), [`Docs/Board_slop.md`](../Docs/Board_slop.md)
- Host UART SoT: [`GUI/app/lib/protocol.dart`](../GUI/app/lib/protocol.dart)
- Honesty: [`Firmware/README.md`](README.md)

## Tooling

| Command | Action |
| --- | --- |
| `make -C Firmware build` | Compile SPI bring-up env (`FPGA_SPI_BRINGUP`) |
| `make -C Firmware upload` | DFU flash bring-up build |
| `make -C Firmware build-mock` / `upload-mock` | UART mock only (no SPI) |
| `make -C Firmware clean` | Clean `.pio` |

Install once: `py -3 -m pip install -U platformio`. Do not commit `.pio/`.

**Wiring:** USB-C = power/DFU; USART1 `PA9`/`PA10` → CP2102; SPI1 `PA5/6/7` + `PA4` CS → Cmod Pmod JA (see README).

## Conventions

1. Keep UART JSON aligned with `protocol.dart` / `firmwmare_slop.md`.
2. Baud, pins, register addresses, threat codes live in `include/protocol.h` / `include/fpga_spi.h`.
3. Label **LIVE SPI** vs **MOCK** in comments and README. Port0 descriptors may be live while `vbus`/`current` stay mock until INA219.
4. Prefer extending this PlatformIO tree — no parallel CubeIDE-only tree unless the team switches.
5. SPI Mode 0, 16-bit frames; start ≤ few MHz on the bench.
