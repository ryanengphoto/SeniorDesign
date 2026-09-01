# MCU Embedded Firmware Requirements Specification
**Project:** Hardware-Isolated USB Security Gateway  
**Target Device:** STMicroelectronics STM32F411CEU6 (ARM Cortex-M4 @ 100 MHz)  
**Document Version:** 1.0  
**Target Toolchain:** STM32CubeIDE / GCC ARM Embedded Toolchain  
**Framework:** STM32 HAL / LL Drivers + FreeRTOS (Optional)  

---

## 1. System Role & Core Purpose

The STM32 microcontroller operates exclusively on the out-of-band management plane. It does not handle, buffer, or route USB data packets between peripherals and the host computer. 

### Primary Responsibilities
* **Telemetry & State Bridge:** Bridges internal hardware status (FPGA threat flags, parsed descriptors, and I2C power metrics) to the Host PC via an emulated USB-CDC Virtual COM Port.
* **Host Command Processing:** Decodes JSON or binary commands from the Host Web Dashboard (e.g., policy mode changes, manual port isolation, fault clearing) and translates them into SPI register writes to the FPGA.
* **Analog Power Monitoring:** Acts as the I2C master polling the 4x INA219/INA226 current and voltage sensors to detect electrical overstress and track power consumption.
* **Dynamic Policy Engine:** Evaluates multi-attribute whitelists and executes staging sequences (such as 100 mA to 500 mA power negotiation) that are too complex or memory-intensive for pure FPGA logic.

---

## 2. Resource Allocation & Hardware Peripheral Mapping

| Peripheral Block | Instance | Target Device / Bus Role | Operational Parameters |
|---|---|---|---|
| **USB OTG FS** | `USB_OTG_FS` | Host PC Management Link | USB Device Mode, CDC-ACM Class (Virtual COM Port @ 12 Mbps Full-Speed) |
| **SPI Master** | `SPI1` | FPGA Register Interface | 4-Wire Master, Mode 0 (CPOL=0, CPHA=0), 12.5 MHz to 25 MHz, DMA-enabled |
| **I2C Master** | `I2C1` | INA219/226 Power Monitors | Fast-Mode (400 kHz), Non-blocking DMA or Interrupt polling |
| **External Interrupt** | `EXTI_Line0` | FPGA Hardware IRQ Line | Falling-edge trigger on active-low `IRQ_N` pin from Cmod S7 |
| **Hardware Timers** | `TIM2` / `TIM3` | Telemetry Cadence & Debounce | 50 Hz periodic sensor scheduler; 10 ms debouncing and cooldown timers |
| **UART (Optional)** | `USART1` | Aux / Debug Serial Port | 115200 Baud, 8-N-1 (Used for low-level board bringup/debug) |

---

## 3. Firmware Architecture & Software Tasks

The firmware is structured into four non-blocking functional tasks (running in a super-loop with SysTick/timers or via FreeRTOS threads):

### 3.1. Interrupt Service Routine & FPGA Synchronizer (`fpga_bridge.c`)
* **Interrupt Handler (`EXTI0_IRQHandler`):** Triggered immediately when the FPGA pulls `IRQ_N` low.
* **Burst Register Read:** Initiates an SPI DMA read to fetch the 16-byte status block from the FPGA:
  * Port IRQ flags and active threat codes.
  * Extracted `VID:PID`, `bDeviceClass`, and `bInterfaceClass`.
* **IRQ Clear:** Automatically writes to the FPGA `PORT_IRQ_STATUS` register upon successful read to re-arm the interrupt line.

### 3.2. I2C Sensor Acquisition Engine (`power_monitor.c`)
* **Cadence:** Executes every 20 ms (50 Hz rate) across all 4 sensor addresses (`0x40`, `0x41`, `0x42`, `0x43`).
* **Acquisition Data:**
  * Shunt Voltage ($\text{mV}$) and calculated Bus Current ($\text{mA}$).
  * Bus Voltage ($V_{\text{BUS}}$ in $\text{mV}$).
* **Overcurrent Threshold Check:** If measured current exceeds the negotiated threshold (e.g., $>120\text{ mA}$ in unconfigured state or $>550\text{ mA}$ in active state), flags an alert to both the host dashboard and the FPGA control registers.

### 3.3. Policy & State Management (`policy_engine.c`)
* Maintains the active operational state for each of the 4 ports: `DISCONNECTED`, `ENUMERATING`, `AUTHORIZED`, `QUARANTINED`, `MANUAL_BLOCKED`.
* Evaluates parsed device attributes against an internal RAM-based whitelist table.
* Manages the interactive challenge mode (holding the FPGA MUX open until the host dashboard sends a matching PIN confirmation).

### 3.4. Host Communications & Serialization (`telemetry_proto.c`)
* **Outbound Streaming:** Formats sensor data and port security states into structured JSON telemetry frames streamed over USB-CDC to the host.
* **Inbound Command Parser:** Buffers incoming bytes from the Virtual COM port, validates packet framing/checksums, and executes matching command handlers.

---

## 4. Host Communication Protocol (USB-CDC Interface)

The STM32 exchanges human-readable, newline-delimited JSON packets with the host Python/Web backend over the USB-CDC serial interface.

### Outbound Telemetry Frame (MCU to Host PC @ 10 Hz – 50 Hz)
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