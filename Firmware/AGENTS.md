# Firmware — Agent notes

STM32F411 Black Pill management-plane firmware (PlatformIO). Distinct from FPGA HDL and the Flutter GUI.

## Required reading

- [`Docs/firmwmare_slop.md`](../Docs/firmwmare_slop.md) — MCU role, UART JSON, polling loop
- [`Docs/fabric_slop.md`](../Docs/fabric_slop.md) — SPI map + threat codes (for later SPI work)
- [`Docs/d_c_txt.md`](../Docs/d_c_txt.md) — system architecture
- [`Docs/Board_slop.md`](../Docs/Board_slop.md) — carrier buses (UART via CP2102)
- Host contract SoT for the console: [`GUI/app/lib/protocol.dart`](../GUI/app/lib/protocol.dart)
- Honesty / stub status: [`Firmware/README.md`](README.md), [`GUI/state.md`](../GUI/state.md)

## Tooling

| Command | Action |
| --- | --- |
| `make -C Firmware build` | Compile (`py -3 -m platformio run`) |
| `make -C Firmware upload` | DFU flash over USB-C |
| `make -C Firmware clean` | Clean `.pio` build |

Install once: `py -3 -m pip install -U platformio`. Do not commit `.pio/`.

**Bring-up wiring:** USB-C = power + DFU; host JSON = USART1 `PA9`/`PA10` → CP2102 (provisional pins in `include/protocol.h`).

## Conventions

1. Keep UART JSON aligned with `protocol.dart` / `firmwmare_slop.md`.
2. Baud, pin macros, port count, threat codes, and cmd strings live in `include/protocol.h` (or future config) — not scattered magic numbers.
3. Label mock/stub behavior in code comments and README. Never imply FPGA/sensor data is live until wired.
4. Prefer extending this PlatformIO tree over a parallel CubeIDE-only tree unless the team explicitly switches.
