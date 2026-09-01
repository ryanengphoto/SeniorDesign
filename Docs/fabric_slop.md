# FPGA RTL & Fabric Requirements Specification
**Project:** Hardware-Isolated USB Security Gateway  
**Target Device:** Xilinx Spartan-7 XC7S25-CSGA225 (Digilent Cmod S7-25)  
**Document Version:** 1.1  
**Target Toolchain:** AMD/Xilinx Vivado ML Standard (2024.1+)  
**Primary Language:** SystemVerilog / Verilog-2001  

---

## 1. System Overview

The FPGA fabric operates as a 4-channel, line-rate USB protocol inspection engine and hardware firewall. It performs oversampled digital demodulation, packet framing, CRC validation, deep packet inspection (DPI), and nanosecond isolation control across all four downstream USB channels concurrently.

### Primary Operational Domains
* **Clock Management Block:** Synthesizes internal timing references from the onboard 12 MHz oscillator.
* **4x Parallel USB Inspection Channels:** Dedicated, identical RTL pipelines for each physical USB port.
* **Central Register File:** Memory-mapped register array holding status flags, parsed descriptors, and policy settings.
* **SPI Slave Interface:** Dedicated 5-wire management bus connecting to the external STM32 MCU.

---

## 2. Resource Budget & Utilization Targets

The architecture fits within the Spartan-7 XC7S25 envelope with low routing congestion.

| Silicon Resource | Available on XC7S25 | Allocated per Port (x4) | Common Logic | Total Estimated | Target Utilization |
|---|---|---|---|---|---|
| **Logic Cells / LUTs** | 14,600 LUTs | ~600 LUTs (2,400 total) | ~800 LUTs | ~3,200 LUTs | **< 25%** |
| **Flip-Flops (FFs)** | 29,200 FFs | ~750 FFs (3,000 total) | ~900 FFs | ~3,900 FFs | **< 15%** |
| **Block RAM (BRAM)** | 45 Blocks (1,620 Kb) | 0 Blocks | 2–4 Blocks (FIFOs) | 4 Blocks | **< 10%** |
| **DSP Slices** | 80 Slices | 0 Slices | 0 Slices | 0 Slices | **0%** |
| **Clock Tiles (MMCM)** | 3 Tiles | — | 1 MMCM Tile | 1 Tile | **33%** |
| **User I/O Pins** | 32 (Cmod S7 headers) | 4 pins (16 total) | 7 pins | 23 Pins | **71.8%** |

---

## 3. Clocking & Domain Strategy

The design uses three internal clock domains derived from a single `MMCME2_BASE` primitive:

* **`CLK_100M` (100.0 MHz):** System core clock driving the SPI Slave, internal register file, and host communications.
* **`CLK_48M` (48.0 MHz):** Digital receiver clock providing 4x oversampling for 12 Mbps Full-Speed USB data.
* **`CLK_12M` (12.0 MHz):** Base reference clock matching the USB 2.0 Full-Speed bit period.

### Clock Domain Crossing (CDC) Rules
* Status and threat flags crossing from 48 MHz to 100 MHz pass through 2-stage flip-flop synchronizers with `ASYNC_REG = "TRUE"` attributes.
* Multi-byte words (such as VID, PID, and Device Class) are written to shadow registers and latched via a single-bit toggle handshake before the 100 MHz domain reads them.
* Static configuration bits crossing from 100 MHz to 48 MHz use standard 2-stage synchronizers.

---

## 4. Module-Level Functional Specifications

### 4.1. USB Receiver & Line Demodulator (`usb_rx_phy.sv`)
* Samples single-ended D+ and D- lines at 48.0 MHz.
* Decodes Single-Ended Zero (SE0), J-State, and K-State to detect End-of-Packet (EOP) and Bus Reset conditions.
* Converts NRZI line encoding to standard binary.
* Strips stuffed zero bits following runs of six consecutive ones.
* Flags a `BIT_STUFF_ERROR` if seven consecutive ones appear without a transition.

### 4.2. Packet Framing & CRC Validation (`usb_packet_checker.sv`)
* Locks onto the 8-bit USB SYNC field (`0x80`).
* Validates the 8-bit PID field by ensuring the upper 4 bits are the exact bitwise inverse of the lower 4 bits.
* Computes running CRC-5 checks on token address/endpoint fields using the polynomial $G(X) = X^5 + X^2 + 1$.
* Computes running CRC-16 checks on data packet payloads using the polynomial $G(X) = X^{16} + X^{15} + X^2 + 1$.

### 4.3. Deep Packet Inspection Engine (`usb_dpi_engine.sv`)
* Monitors Endpoint 0 control transfers and intercepts `GET_DESCRIPTOR` setup transactions.
* Parses Device Descriptors to extract `idVendor`, `idProduct`, and `bDeviceClass`.
* Parses Interface Descriptors to extract `bInterfaceClass`, `bInterfaceSubClass`, and `bInterfaceProtocol`.
* Flags configuration descriptors with `wTotalLength` values exceeding 512 bytes.
* Triggers an immediate hardware kill if an unauthorized HID class (`0x03`) appears on a port configured for storage only.

### 4.4. HID Keystroke Timing Filter (`hid_timing_filter.sv`)
* Uses a 24-bit down-counter running at 48 MHz to measure the time delta ($\Delta t$) between consecutive HID input reports.
* Flags a `KEYSTROKE_BURST` violation if consecutive keystrokes arrive with $\Delta t < 25\text{ ms}$.
* Enforces a 2.0-second post-enumeration quarantine window to detect automated scripts that fire immediately upon connection.

### 4.5. Fast-Path Isolation Controller (`isolation_controller.sv`)
* Routes threat trigger signals directly through combinatorial logic to the physical control pins.
* Deasserts the active-low MUX enable line in under 20 nanoseconds to place the TS3USB221 switch into high-impedance mode.
* Deasserts the eFuse enable line to cut downstream bus power.
* Latches the isolation state in hardware until cleared by an authenticated write from the MCU.

---

## 5. SPI Slave Register Map

The FPGA implements a 16-bit SPI slave interface operating up to 25 MHz (Mode 0: CPOL=0, CPHA=0, MSB first).

* **Write Frame:** Bit 15 = 1, Bits 14:8 = 7-bit Address, Bits 7:0 = 8-bit Data
* **Read Frame:** Bit 15 = 0, Bits 14:8 = 7-bit Address, Bits 7:0 = Dummy Byte (Data returned on next byte)

| Address (Hex) | Register Name | Access | Reset | Description / Bit Definitions |
|:---:|---|:---:|:---:|---|
| `0x00` | `SYS_STATUS` | RO | `0x00` | `[7:4]` Global Error Code, `[3:0]` Active IRQ flags for Ports 3 to 0 |
| `0x01` | `SYS_CONTROL` | RW | `0x00` | `[7]` Global Soft Reset, `[3:0]` Force Global MUX Enable Override |
| `0x02` | `PORT_IRQ_STATUS` | RO | `0x00` | `[7:4]` Reserved, `[3:0]` Unserviced IRQ per port (Cleared on read) |
| `0x10` | `P0_CONTROL` | RW | `0x00` | `[7]` Manual Kill, `[6]` Clear Fault, `[2:0]` Policy Mode |
| `0x11` | `P0_STATUS` | RO | `0x00` | `[7]` Isolated, `[6]` Attached, `[5]` Configured, `[3:0]` Threat Code |
| `0x12` | `P0_VID_HIGH` | RO | `0x00` | Parsed Vendor ID High Byte (`VID[15:8]`) |
| `0x13` | `P0_VID_LOW` | RO | `0x00` | Parsed Vendor ID Low Byte (`VID[7:0]`) |
| `0x14` | `P0_PID_HIGH` | RO | `0x00` | Parsed Product ID High Byte (`PID[15:8]`) |
| `0x15` | `P0_PID_LOW` | RO | `0x00` | Parsed Product ID Low Byte (`PID[7:0]`) |
| `0x16` | `P0_DEV_CLASS` | RO | `0x00` | Parsed `bDeviceClass` byte |
| `0x17` | `P0_INT_CLASS` | RO | `0x00` | Parsed `bInterfaceClass` byte |
| `0x20 – 0x27` | `P1_REGS[0:7]` | — | — | Channel 1 Mirror Registers (Offsets match `0x10–0x17`) |
| `0x30 – 0x37` | `P2_REGS[0:7]` | — | — | Channel 2 Mirror Registers (Offsets match `0x10–0x17`) |
| `0x40 – 0x47` | `P3_REGS[0:7]` | — | — | Channel 3 Mirror Registers (Offsets match `0x10–0x17`) |

---

## 6. Threat Classification Codes

| Threat Code (`4'h_`) | Threat Name | Trigger Condition | Hardware Action |
|:---:|---|---|---|
| `0x0` | `NO_FAULT` | Normal operation. | Normal passthrough (MUX closed). |
| `0x1` | `UNAUTHORIZED_HID` | `bInterfaceClass == 0x03` on storage port. | Open MUX (<20 ns), cut eFuse, assert IRQ. |
| `0x2` | `KEYSTROKE_BURST` | Keystroke interval $\Delta t < 25\text{ ms}$ for $>3$ reports. | Open MUX (<20 ns), assert IRQ. |
| `0x3` | `COOLDOWN_BURST` | Keystroke during 2.0s post-enumeration window. | Drop packets, assert IRQ. |
| `0x4` | `DESCRIPTOR_OVERFLOW` | `wTotalLength > 512` or length mismatch. | Isolate port, assert IRQ. |
| `0x5` | `CRC_TOKEN_FAULT` | Token CRC-5 or data CRC-16 failure. | Log error, isolate on repeat. |
| `0x6` | `BIT_STUFF_ERROR` | Seven consecutive ones with no transition. | Reset port receiver, isolate. |
| `0x7` | `MANUAL_HOST_KILL` | User command via GUI. | Open MUX, cut eFuse. |

---

## 7. Cmod S7 Physical Pin Constraints (`gateway_pins.xdc`)

```tcl
## 12 MHz Onboard Oscillator
set_property -dict { PACKAGE_PIN M9  IOSTANDARD LVCMOS33 } [get_ports { clk_12m }];
create_clock -add -name sys_clk_pin -period 83.333 -waveform {0 41.666} [get_ports { clk_12m }];

## SPI Slave Interface to STM32F411 MCU
set_property -dict { PACKAGE_PIN J1  IOSTANDARD LVCMOS33 } [get_ports { spi_sck }];
set_property -dict { PACKAGE_PIN J2  IOSTANDARD LVCMOS33 } [get_ports { spi_mosi }];
set_property -dict { PACKAGE_PIN K1  IOSTANDARD LVCMOS33 } [get_ports { spi_miso }];
set_property -dict { PACKAGE_PIN K2  IOSTANDARD LVCMOS33 } [get_ports { spi_cs_n }];
set_property -dict { PACKAGE_PIN L1  IOSTANDARD LVCMOS33 } [get_ports { fpga_irq_n }];

## Channel 0 (Port 1)
set_property -dict { PACKAGE_PIN M1  IOSTANDARD LVCMOS33 } [get_ports { p0_dp_tap }];
set_property -dict { PACKAGE_PIN M2  IOSTANDARD LVCMOS33 } [get_ports { p0_dm_tap }];
set_property -dict { PACKAGE_PIN N1  IOSTANDARD LVCMOS33 } [get_ports { p0_mux_en_n }];
set_property -dict { PACKAGE_PIN N2  IOSTANDARD LVCMOS33 } [get_ports { p0_efuse_en }];

## Channel 1 (Port 2)
set_property -dict { PACKAGE_PIN P1  IOSTANDARD LVCMOS33 } [get_ports { p1_dp_tap }];
set_property -dict { PACKAGE_PIN P2  IOSTANDARD LVCMOS33 } [get_ports { p1_dm_tap }];
set_property -dict { PACKAGE_PIN R1  IOSTANDARD LVCMOS33 } [get_ports { p1_mux_en_n }];
set_property -dict { PACKAGE_PIN R2  IOSTANDARD LVCMOS33 } [get_ports { p1_efuse_en }];

## Channel 2 (Port 3)
set_property -dict { PACKAGE_PIN A2  IOSTANDARD LVCMOS33 } [get_ports { p2_dp_tap }];
set_property -dict { PACKAGE_PIN B2  IOSTANDARD LVCMOS33 } [get_ports { p2_dm_tap }];
set_property -dict