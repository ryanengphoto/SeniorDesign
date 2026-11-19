# Nucleo CubeIDE MCU demo

**NUCLEO-F411RE** management-plane firmware (STM32CubeIDE / HAL). Intended as a Nucleo bench twin of the Black Pill PlatformIO SPI bring-up in `Firmware/`.

## Honesty

| Path | Status |
| --- | --- |
| Ports 0–3 telemetry | **LIVE** SPI from Cmod FPGA (~200 ms), JSON-only UART |
| Host commands | **LIVE** SPI: `isolate_port`, `restore_port`, `clear_fault`, `confirm_hid` (policy bits preserved) |
| Boot policy | Writes `HID_CONFIRM` on all four ports (same as PlatformIO) |
| Power sensors | Not present (no `vbus_mv` / `current_ma` fields) |
| Dummy seeded VIDs | Removed — idle ports should show disconnected / zeros until FPGA attach |
| UART RX | Polled only (USART1 IRQ off — USB couple must not preempt TX) |
| UART TX | Fire-and-forget polled TX; 768B JSON (`uart_bm6`); RX ring filled during TX (confirm not dropped) |
| HID re-arm | If FPGA shows HID AUTHORIZED without MCU confirm, pulse isolate to re-arm pending |
| Alive LED | LD2 pulses ~30 ms every 200 ms poll (can blink even if TX wedged) |
| SPI fail-fast | 5 ms xfer timeout; abort rest of poll, still emit UART JSON |

**Bench note:** If UART/COM goes quiet while a Rubber Ducky (or other USB device) is plugged into the tap path and returns on unplug, that is usually **electrical / host USB** (shared GND bounce, D+/D− coupling into UART jumpers, or CP2102 on the same flaky hub) — not an MCU hard lock. Confirm with LD2: blinking during the “drop” means firmware is still running.

Not production carrier firmware. Black Pill PlatformIO remains the primary `Firmware/` tree.

## Pins / wiring

See **MCU option B** in [`wiring.md`](../wiring.md):

- USART1 **PA9/PA10** ↔ CP2102 (not ST-LINK VCP)
- SPI2 **PB12–15** ↔ Cmod PIO40–43
- LD2 **PA5** status LED (active-high)

## Build / flash

Open `Group19_MCU_Demo/` in STM32CubeIDE → Build → Run/Debug (ST-LINK SWD).
