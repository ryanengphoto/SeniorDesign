# FPGA RTL & Fabric Requirements Specification
**Project:** Hardware-Isolated USB Security Gateway  
**Target Device:** Xilinx Spartan-7 XC7S25-CSGA225 (Digilent Cmod S7-25)  
**Document Version:** 1.2  
**Target Toolchain:** AMD/Xilinx Vivado ML Standard (project historically 2017.4 → 2018.2; newer OK if compatible)  
**Primary Language:** SystemVerilog / Verilog-2001  

**Related docs (read with this file):**
- Product context / engineering specs: [`Docs/d_c_txt.md`](d_c_txt.md)
- Requirements: [`Docs/init_specs.md`](init_specs.md)
- Carrier PCB / pin roles: [`Docs/Board_slop.md`](Board_slop.md)
- MCU firmware (SPI master + UART GUI): [`Docs/firmwmare_slop.md`](firmwmare_slop.md)
- Fabric block diagram: [`Docs/BlockDiagrams/Rendered/fabric_bd.jpg`](BlockDiagrams/Rendered/fabric_bd.jpg)
- Agent workflow: [`FPGA/AGENTS.md`](../FPGA/AGENTS.md)

---

## 1. System Overview

The FPGA fabric is a **4-channel parallel USB packet sniffer and isolation controller**, not the USB hub itself. Downstream D+/D− are tapped into the FPGA **in parallel** with the hub IC so the inspection path does not extend the USB critical path (target added latency ≤ 1 ns; in-line FPGA placement is a stretch goal — see [`Docs/d_c_txt.md`](d_c_txt.md)).

On each clock, per-port sniffers inspect traffic, update **stateful status registers**, and can assert **kill** lines to the board analog switches / eFuses. The fabric is an **SPI slave**; the MCU is master and reads/writes the register file for telemetry and policy.

### RTL hierarchy (matches Vivado sources under `FPGA/senior_design.srcs/`)

| Module | Role |
| --- | --- |
| `main_wrapper` | Top: clocking, sniffer wrapper, register file, SPI slave |
| Packet sniffer wrapper | Instantiates **identical** `sniffer_block` × 4; aggregates threat/kill/status into the register file every cycle |
| `sniffer_block` | Per-port PHY/demod, framing, DPI / timing filters, local kill request |
| `register_file` | Stateful status + control visible to the MCU over SPI |
| SPI slave | Mode 0 slave; serves MCU read/write transactions |

Example behavior: a HID keystroke-rate filter uses a time-delta counter; exceeding the human typing bound (50 chars/s → ≈ 20 ms minimum interval; see threat table) isolates that channel and sets the corresponding status bits (e.g. overspeed / `KEYSTROKE_BURST`).

### Primary operational domains
* **Clock management:** From the Cmod S7 12 MHz oscillator; **48 MHz** is the sniffer oversampling clock (USB FS 4×).
* **4× parallel sniff channels:** One `sniffer_block` per physical port.
* **Central register file:** Status flags, descriptors, policy; updated each cycle from sniffers.
* **SPI slave:** Management bus to the STM32 MCU.

### Fabric-relevant engineering bounds (from `d_c_txt.md`)

| Spec | Requirement |
| --- | --- |
| Sniffer clock | 48 MHz |
| FPGA area | > 8,000 LUTs available (use XC7S25 headroom; keep congestion low) |
| USB shutoff latency | ≤ 1 µs upper bound, ≤ 100 ns target |
| Critical-path added latency | ≤ 1 ns (parallel tap) |
| HID packets to host during quarantine | 0 (after kill) |
| Post-quarantine attack leakage | ≤ 1 packet |
| Device enumeration capture window | ≤ 5 ms intent for descriptor-side checks |

Agents changing RTL must keep threat codes and the SPI register map aligned with this document and `GUI/backend/src/protocol.py` when present.

---

## 2. Resource Budget & Utilization Targets

The architecture fits within the Spartan-7 XC7S25 envelope with low routing congestion. Spec floor is **> 8,000 LUTs** available on-device; estimated usage below stays well under that.

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
* Flags a `KEYSTROKE_BURST` / overspeed violation if consecutive keystrokes arrive faster than the human bound (**50 chars/s** → $\Delta t < 20\text{ ms}$).
* **HID confirm (first layer, parallel-tap):** after descriptors show an HID keyboard, set `hid_locked` and **open the high-speed analog switch** so the device is cut off from the hub/host (no further packets). GUI prompts the operator to click confirm (“keyboard plugged in”). MCU pulses `CONTROL.confirm_hid` → clear `hid_locked`, **close the analog switch**, traffic resumes. Then enforce cooldown / rate checks.
* On trip: assert channel kill (open analog switch) and update status (e.g. threat code `0x2`).

### 4.5. Fast-Path Isolation Controller (`isolation_controller.sv`)
* Routes threat / `hid_locked` / manual-kill to the **high-speed analog switch** enable (and eFuse as specified).
* Meets system shutoff targets: **≤ 100 ns** preferred, **≤ 1 µs** hard upper bound; board analog switch turn-off budget **≤ 120 ns** ([`Docs/d_c_txt.md`](d_c_txt.md)).
* Latches isolation until MCU clear / HID confirm as applicable.
* Convention: **switch open** = path cut (isolated); **switch closed** = connected to hub (packets flow).

---

## 5. SPI Slave Register Map

The FPGA implements a 16-bit **SPI slave** (MCU master) operating up to 25 MHz (Mode 0: CPOL=0, CPHA=0, MSB first). Register contents are kept **stateful** as sniffers update them each cycle.

* **Write Frame:** Bit 15 = 1, Bits 14:8 = 7-bit Address, Bits 7:0 = 8-bit Data
* **Read Frame:** Bit 15 = 0, Bits 14:8 = 7-bit Address, Bits 7:0 = Dummy Byte (Data returned on next byte)

### Addressing (dynamic — do not hardcode per-port addresses)

```
addr = PORT_REG_BASE + port * PORT_REG_STRIDE + offset
```

| Constant | Value | Meaning |
|---|:---:|---|
| `PORT_REG_BASE` | `0x00` | First port bank |
| `PORT_REG_STRIDE` | `0x02` | Bytes per port |

| Offset | Name | Access | Bits / role |
|:---:|---|:---:|---|
| `0` | CONTROL | RW | `[7]` Manual Kill, `[6]` Clear Fault, `[5]` **Confirm HID** (GUI click strobe), `[2:0]` Policy Mode |
| `1` | STATUS | RO | `[7]` Isolated, `[6]` Attached, `[5]` Configured, `[4]` **HID locked**, `[3:0]` Threat Code |

| Port | CONTROL | STATUS |
|:---:|:---:|:---:|
| 0 | `0x00` | `0x01` |
| 1 | `0x02` | `0x03` |
| 2 | `0x04` | `0x05` |
| 3 | `0x06` | `0x07` |

### HID confirm flow (GUI click; analog-switch quarantine)

1. Device enumerates; sniffer sees HID keyboard → set `STATUS.hid_locked`, set `isolated`, **open high-speed analog switch** (host path cut; aim ≤1 packet leakage).
2. Telemetry shows `hid_locked: true` / `QUARANTINED`; **GUI prompts** “Keyboard detected — confirm?”
3. Operator **clicks confirm** → host command → MCU SPI-pulses `CONTROL.confirm_hid`.
4. FPGA clears `hid_locked` / `isolated` and **closes the analog switch** so packets can flow again.
5. Keystroke-rate / cooldown filters run as the second layer.

No unlock PIN in this baseline (parallel tap cannot block host while still capturing on-device keystrokes).

Out-of-range addresses read `0x00` and ignore writes.

---

## 6. Threat Classification Codes

| Threat Code (`4'h_`) | Threat Name | Trigger Condition | Hardware Action |
|:---:|---|---|---|
| `0x0` | `NO_FAULT` | Normal operation. | Analog switch closed (connected). |
| `0x1` | `UNAUTHORIZED_HID` | `bInterfaceClass == 0x03` on storage port. | Open analog switch (<20 ns), cut eFuse, assert IRQ. |
| `0x2` | `KEYSTROKE_BURST` | Keystroke interval $\Delta t < 20\text{ ms}$ (50 chars/s bound) for $>3$ reports. | Open analog switch (≤100 ns target), assert status / IRQ. |
| `0x3` | `COOLDOWN_BURST` | Keystroke during 2.0s post-enumeration window. | Isolate / open switch, assert IRQ. |
| `0x4` | `DESCRIPTOR_OVERFLOW` | `wTotalLength > 512` or length mismatch. | Isolate port, assert IRQ. |
| `0x5` | `CRC_TOKEN_FAULT` | Token CRC-5 or data CRC-16 failure. | Log error, isolate on repeat. |
| `0x6` | `BIT_STUFF_ERROR` | Seven consecutive ones with no transition. | Reset port receiver, isolate. |
| `0x7` | `MANUAL_HOST_KILL` | User command via GUI. | Open analog switch, cut eFuse. |

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