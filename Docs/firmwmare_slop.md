# MCU Embedded Firmware Requirements Specification
**Project:** Hardware-Isolated USB Security Gateway  
**Target Device:** STMicroelectronics STM32F411CEU6 (ARM Cortex-M4 @ ≥ 50 MHz; Black Pill typically 100 MHz)  
**Document Version:** 1.1  
**Target Toolchain:** STM32CubeIDE / GCC ARM Embedded Toolchain  
**Framework:** STM32 HAL / LL Drivers; **baseline = simple polling super-loop** (FreeRTOS optional later)

**Related docs (read with this file):**
- Product context / engineering specs: [`Docs/d_c_txt.md`](d_c_txt.md)
- Requirements: [`Docs/init_specs.md`](init_specs.md)
- Carrier PCB / buses: [`Docs/Board_slop.md`](Board_slop.md)
- FPGA SPI register map & threat codes: [`Docs/fabric_slop.md`](fabric_slop.md)
- Software flowchart: [`Docs/BlockDiagrams/Rendered/code2flow_fTOuz1.png`](BlockDiagrams/Rendered/code2flow_fTOuz1.png)
- Host GUI contract consumers: `GUI/` (`GUI/state.md`, `GUI/backend/src/protocol.py`)

---

## 1. System Role & Core Purpose

The STM32 runs exclusively on the **out-of-band management plane**. It does not handle, buffer, or route USB data packets between peripherals and the host. Packet inspection and kill decisions live in the FPGA; electrical clamping lives on the PCB.

### Primary responsibilities
* **Poll FPGA status:** SPI master → FPGA slave; refresh per-port status / threat / descriptor registers.
* **Poll analog sensors:** I²C master to per-port INA219 (or equivalent) current/voltage monitors.
* **Forward telemetry to GUI:** Stream structured frames over **UART** to the host (via onboard USB–UART bridge). Target end-to-end telemetry freshness **≤ 100 ms** ([`Docs/d_c_txt.md`](d_c_txt.md)).
* **Accept operator commands:** Decode host commands (JSON) and translate to SPI writes (manual kill, clear fault, re-enable, policy).

### Baseline architecture (from `d_c_txt.md`)

The firmware follows a **simple polling loop**: continually refresh FPGA register and sensor readings and forward them to the GUI over UART. Interrupt-driven FPGA IRQ and RTOS threading are **optional enhancements**, not required for the baseline management plane (only four ports + a handful of sensors).

```
init clocks, SPI, I2C, UART
loop forever:
  read FPGA status block over SPI
  read INA219 sensors over I2C
  merge into port state model
  emit newline-delimited JSON telemetry on UART
  parse any pending host commands → SPI writes
```

---

## 2. Resource Allocation & Hardware Peripheral Mapping

| Peripheral Block | Instance | Target Device / Bus Role | Operational Parameters |
|---|---|---|---|
| **UART** | `USART1` (or board-assigned) | Host GUI via CP2102 USB–UART | 115200 8-N-1 (or project baud in config); primary management link |
| **SPI Master** | `SPI1` | FPGA register interface | 4-wire master, Mode 0 (CPOL=0, CPHA=0), ≤ 25 MHz |
| **I2C Master** | `I2C1` | INA219 power monitors | Fast-Mode (400 kHz) |
| **External Interrupt** | `EXTI` (optional) | FPGA `IRQ_N` | Falling-edge; not required for baseline poll loop |
| **Hardware Timers** | `TIMx` | Telemetry cadence | Enough to hit ≤ 100 ms GUI update (e.g. 10–50 Hz poll) |
| **USB OTG FS** | Optional | Alternate CDC-ACM | Prefer UART+bridge on this carrier; CDC only if redesign drops CP2102 |

MCU clock requirement: **≥ 50 MHz** ([`Docs/d_c_txt.md`](d_c_txt.md)).

---

## 3. Firmware Structure

Baseline is one non-blocking super-loop. Logical modules (files) below may be separate compilation units without introducing RTOS unless needed.

### 3.1. FPGA bridge (`fpga_bridge.c`)
* SPI transactions matching [`Docs/fabric_slop.md`](fabric_slop.md) §5 (16-bit framing, register map `0x00`–`0x47`).
* Periodic burst read of `SYS_STATUS`, per-port `Pn_STATUS`, VID/PID/class bytes.
* Write path for `Pn_CONTROL` (manual kill, clear fault, policy) and soft reset.
* Optional: if `IRQ_N` is wired, an EXTI ISR may set a “service FPGA now” flag; the loop still owns SPI.

### 3.2. Power monitor (`power_monitor.c`)
* Poll addresses `0x40`–`0x43` (see board doc).
* Shunt / bus voltage → current (mA), VBUS (mV).
* Overcurrent vs negotiated threshold → alert in telemetry and optional FPGA kill request.

### 3.3. Port state (`policy_engine.c`)
* Per-port states: `DISCONNECTED`, `ENUMERATING`, `AUTHORIZED`, `QUARANTINED`, `MANUAL_BLOCKED`.
* Map FPGA threat codes 0–7 ([`Docs/fabric_slop.md`](fabric_slop.md) §6) into those states.
* Whitelist / challenge / staging power are **advanced**; stub clearly if unimplemented.

### 3.4. Host link (`telemetry_proto.c`)
* Outbound: newline-delimited JSON on UART @ a rate that meets ≤ 100 ms freshness.
* Inbound: buffer host JSON commands; validate; issue SPI writes.

---

## 4. Host Communication Protocol (UART Interface)

The STM32 exchanges human-readable, newline-delimited JSON with the host Python/Web backend over the management UART (USB–UART bridge). Keep this contract aligned with `GUI/backend/src/protocol.py`.

### Outbound Telemetry Frame (MCU → Host @ ~10 Hz–50 Hz)
```json
{
  "timestamp_ms": 14820,
  "ports": [
    {
      "port": 0,
      "state": "AUTHORIZED",
      "threat_code": 0,
      "vbus_mv": 5020,
      "current_ma": 42,
      "vid": "0x0781",
      "pid": "0x5583",
      "dev_class": "0x00",
      "int_class": "0x08"
    },
    {
      "port": 1,
      "state": "QUARANTINED",
      "threat_code": 1,
      "vbus_mv": 0,
      "current_ma": 0,
      "vid": "0x046D",
      "pid": "0xC31C",
      "dev_class": "0x00",
      "int_class": "0x03"
    }
  ]
}
```

Threat codes and register fields must match [`Docs/fabric_slop.md`](fabric_slop.md). Do not present simulated telemetry as live hardware without documenting it as mock (see `GUI/state.md`).

### Inbound commands (Host → MCU)
Minimum set (names may match GUI protocol enums):
* Manual isolate / re-enable port
* Clear fault latch on FPGA
* Soft policy mode change (when implemented)

Exact JSON schemas live with the GUI protocol module; update both sides together.

---

## 5. Agent / implementation notes

1. Read this file, [`Docs/d_c_txt.md`](d_c_txt.md), and [`Docs/fabric_slop.md`](fabric_slop.md) before changing protocol or SPI usage.
2. Prefer the **polling loop** until measurements show the ≤ 100 ms telemetry bound cannot be met.
3. Keep magic numbers (baud, poll rate, I²C addresses, threat codes) in shared config / headers aligned with board and fabric docs.
4. When firmware sources land in-repo, add a `Firmware/` tree and Make targets; until then this document is the firmware source of truth.
