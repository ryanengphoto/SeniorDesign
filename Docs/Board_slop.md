# Board Layout & Carrier PCB Physical Architecture Specification

**Project:** Hardware-Isolated USB Security Gateway (Modular Carrier PCB)  
**Target Form Factor:** Dual Daughterboard Carrier (FPGA SoM + MCU Module)  
**Dimensions:** 140.0 mm × 100.0 mm  
**Target EDA:** KiCad 8.0 / Altium Designer  
**Document Version:** 2.0  

---

## 1. PCB Stackup & Fabrication Rules

A 4-layer controlled-impedance stackup (standard JLCPCB JLC04161H-7628 / standard FR-4) is specified to guarantee signal integrity across all USB 2.0 High-Speed/Full-Speed differential pairs while maintaining continuous reference ground return paths.

- **Board Dimensions:** 140.0 mm (Width) × 100.0 mm (Height)
- **Layer Count:** 4 Layers (1.6 mm nominal thickness, 1 oz copper outer/inner)
- **Minimum Trace Width / Space:** 0.127 mm / 0.127 mm (5/5 mil)
- **Minimum Drill / Annular Ring:** 0.3 mm hole / 0.15 mm annular ring
- **Mounting Holes:** 4× M3 tooling holes ($3.2\text{ mm}$ drill, $6.0\text{ mm}$ pad) located $4.0\text{ mm}$ inset from each corner.



### Layer Stackup Table


| Layer            | Type           | Copper Thickness | Dielectric / Material                    | Nominal Thickness | Purpose / Primary Assignment                                                   |
| ---------------- | -------------- | ---------------- | ---------------------------------------- | ----------------- | ------------------------------------------------------------------------------ |
| **L1 (Top)**     | Signal / Mixed | 1.0 oz (35 µm)   | —                                        | 0.035 mm          | High-speed differential pairs ($90\Omega$), bypass caps, test points           |
| *Dielectric*     | Prepreg        | —                | 7628 (FR-4, $\varepsilon_r \approx 4.6$) | 0.210 mm          | Controlled impedance dielectric                                                |
| **L2 (Inner 1)** | Plane          | 1.0 oz (35 µm)   | —                                        | 0.035 mm          | **Solid Unbroken GND Plane** (Continuous reference return)                     |
| *Core*           | Core           | —                | FR-4 ($\varepsilon_r \approx 4.6$)       | 1.065 mm          | Structural core                                                                |
| **L3 (Inner 2)** | Power / Plane  | 1.0 oz (35 µm)   | —                                        | 0.035 mm          | Split Power Planes ($+5.0\text{V}$, $+3.3\text{V}$)                            |
| *Dielectric*     | Prepreg        | —                | 7628 (FR-4, $\varepsilon_r \approx 4.6$) | 0.210 mm          | Isolation dielectric                                                           |
| **L4 (Bottom)**  | Signal / Mixed | 1.0 oz (35 µm)   | —                                        | 0.035 mm          | Low-speed buses ($\text{I}^2\text{C}$, SPI, UART), LEDs, module socket headers |


---



## 2. Physical Footprints & Daughterboard Sizing

The carrier baseboard mates two complete development modules via standard $2.54\text{ mm}$ (0.1") dual female pin headers:

- **FPGA Daughterboard (Digilent Cmod S7):**
  - Sockets: Dual $1 \times 24$ pin female headers ($2.54\text{ mm}$ pitch).
  - Row-to-Row Spacing: $15.24\text{ mm}$ ($0.600"$).
  - Physical Clearance Envelope: $70.0\text{ mm} \times 18.0\text{ mm}$.
- **MCU Daughterboard (STM32F411 "Black Pill"):**
  - Sockets: Dual $1 \times 20$ pin female headers ($2.54\text{ mm}$ pitch).
  - Row-to-Row Spacing: $15.24\text{ mm}$ ($0.600"$).
  - Physical Clearance Envelope: $53.0\text{ mm} \times 21.0\text{ mm}$.
- **Downstream USB Type-A Receptacles:**
  - 4× Right-angle through-hole / hybrid USB Type-A female jacks mounted on the front edge.
  - Spacing: $18.0\text{ mm}$ center-to-center pitch for thumb-drive clearance.



## 4. High-Speed Routing Guidelines ($D+ / D-$)

All USB $D+$ and $D-$ differential pairs must strictly follow the USB 2.0 transmission line parameters:

### Trace Geometry (Layer 1 over Layer 2 Solid GND)

- **Differential Impedance ($Z_{\text{diff}}$):** $90\Omega \pm 10$
- **Single-Ended Impedance ($Z_0$):** $45\Omega \pm 10$
- **Trace Width ($W$):** $0.19\text{ mm}$ ($7.5\text{ mil}$)
- **Intra-Pair Gap ($S$):** $0.15\text{ mm}$ ($6.0\text{ mil}$)
- **Height Above GND Plane ($H$):** $0.21\text{ mm}$ ($8.3\text{ mil}$)



### Critical Layout Rules

1. **Zero Reference Splits:** No USB differential pair shall cross split power plane boundaries in Layer 3. Layer 2 directly beneath every data pair must be continuous solid ground copper.
2. **Length Matching:** Match intra-pair trace lengths between $D+$ and $D-$ to within **$\pm 0.127\text{ mm}$ ($5.0\text{ mil}$)**. Place serpentine tuning bends immediately adjacent to where skew is introduced.
3. **Trace Clearance:** Maintain a minimum isolation spacing of **$3\times W$ ($0.57\text{ mm}$ / $22.5\text{ mil}$)** from high-speed pairs to any adjacent switching, clock, or power traces.
4. **Sniff Tap Lengths:** High-impedance tap traces branching from the MUX inputs into the Cmod S7 FPGA I/O pins must be kept under **$15.0\text{ mm}$** total trace length to eliminate transmission reflections.
5. **No Traces Under Modules:** Avoid routing high-speed differential pairs directly underneath the Cmod S7 or Black Pill modules on Layer 1 to prevent coupling switching noise from their onboard regulators.

---



## 5. Protection, Power & Surge Clamping Rules



### ESD & Anti-USB Killer Clamping

- **Placement Priority:** TVS diode arrays (`USBLC6-2SC6`) and `SMAJ5.0A` high-energy suppressors must be placed **directly behind the USB connector pins** before any downstream passive components, eFuses, or multiplexer ICs.
- **Feed-Through Routing:** The differential signal traces must route **through** the TVS package solder pads; avoid stub connections.
- **GND Return Path:** Tie the TVS ground pad to the ground plane with multiple stitching vias placed within $1.0\text{ mm}$.



### Power Distribution & Planes

- **5V Power Distribution (Layer 3):** Wide copper polygon ($> 2.5\text{ mm}$ width) routed from the external barrel jack directly to the input of each `TPS2553` eFuse.
- **Per-Port VBUS Traces:** Downstream $V_{\text{BUS}}$ traces from each eFuse to its respective USB receptacle must be sized for at least $1.0\text{A}$ continuous ($> 0.8\text{ mm}$ width).
- **Decoupling Capacitors:**
  - $0.1\mu\text{F}$ ceramic capacitors placed within $1.5\text{ mm}$ of every power pin on the `USB2514B` and `TS3USB221` ICs.
  - $100\mu\text{F}$ low-ESR bulk electrolytic capacitor at the main 5V barrel input.
  - $10\mu\text{F}$ ceramic bulk capacitor at each downstream USB $V_{\text{BUS}}$ pin.

---



## 6. Digital Control & Inter-Module Bus Mapping



### SPI + Interrupt Bus (Cmod S7 $\leftrightarrow$ STM32F411)

Routed on Layer 4 with series $22\Omega$ damping resistors:

- `SPI_SCK` (Clock, Master = STM32)
- `SPI_MOSI` (Commands / Address)
- `SPI_MISO` (Telemetry / Descriptors)
- `SPI_CS_N` (Active-Low Chip Select)
- `IRQ_N` (Active-Low Hardware Interrupt from FPGA to STM32 EXTI)



### $\text{I}^2\text{C}$ Sensor Bus (STM32 $\leftrightarrow$ INA219 Sensors)

$4.7\text{ k}\Omega$ pull-up resistors to $+3.3\text{V}$ with distinct hardware addresses:

- Port 1 INA219: `A0 = GND, A1 = GND` ($0x40$)
- Port 2 INA219: `A0 = VDD, A1 = GND` ($0x41$)
- Port 3 INA219: `A0 = SDA, A1 = GND` ($0x42$)
- Port 4 INA219: `A0 = SCL, A1 = GND` ($0x43$)

---



## 7. Manufacturing & Test Specifications

- **Fiducials:** 3× global optical fiducials ($1.0\text{ mm}$ copper dot, $2.0\text{ mm}$ soldermask opening) placed asymmetrically in board corners.
- **Thermal Relief:** 4-spoke thermal relief for all through-hole pins connecting to copper planes.
- **Exposed Test Points ($1.0\text{ mm}$ loops):**
  - `TP_GND`, `TP_5V_RAW`, `TP_3V3`
  - `TP_D+_IN[1:4]`, `TP_D-_IN[1:4]`
  - `TP_IRQ_N`, `TP_MUX_EN[1:4]`



# Bill of Materials (BOM): Hardware-Isolated USB Security Gateway

**Target Platform:** Modular 4-Layer Carrier PCB (Cmod S7 + STM32F411 Module)  
**Quantity:** 1 Prototype Unit  

---


| Item   | Subsystem / Function              | Manufacturer           | Part Number / Module       | Package / Footprint             | Description / Role                                                    | Qty       | Unit Price (USD) | Ext. Price (USD) |
| ------ | --------------------------------- | ---------------------- | -------------------------- | ------------------------------- | --------------------------------------------------------------------- | --------- | ---------------- | ---------------- |
| **1**  | **FPGA Module**                   | Digilent               | 410-376 (Cmod S7-25)       | 48-Pin DIP ($0.6"$ row spacing) | Spartan-7 (XC7S25) Module; line-rate NRZI, DPI, fast-path cut         | 1         | $99.00           | $99.00           |
| **2**  | **MCU Module**                    | WeAct Studio / Generic | STM32F411CEU6 "Black Pill" | 40-Pin DIP ($0.6"$ row spacing) | ARM Cortex-M4 @ 100 MHz; I2C monitor, policy engine, USB-CDC          | 1         | $5.50            | $5.50            |
| **3**  | **Custom PCB**                    | JLCPCB / PCBWay        | Custom 4-Layer Carrier     | 140 mm × 100 mm FR-4            | JLC04161H Stackup, 90Ω controlled differential pairs                  | 5 (batch) | $6.00            | $30.00           |
| **4**  | **USB Hub Controller**            | Microchip              | USB2514B-AEZG              | 36-VQFN (6×6 mm)                | 4-Port USB 2.0 High-Speed/Full-Speed Hub Controller IC                | 1         | $3.25            | $3.25            |
| **5**  | **Port Power-Cut eFuses**         | Texas Instruments      | TPS2553DBVR                | SOT-23-6                        | Adjustable precision current limiter & power switch (FPGA-controlled) | 4         | $1.20            | $4.80            |
| **6**  | **High-Speed Data MUX**           | Texas Instruments      | TS3USB221RSER              | 10-UQFN (1.5×2.0 mm)            | High-speed bidirectional USB 2.0 switch (>900 MHz bandwidth)          | 4         | $0.85            | $3.40            |
| **7**  | **USB-UART Bridge IC**            | Silicon Labs           | CP2102N-A02-GQFN24R        | 24-QFN (4×4 mm)                 | USB-to-UART bridge for MCU management telemetry                       | 1         | $2.65            | $2.65            |
| **8**  | **DC Barrel Jack**                | CUI Devices / Wurth    | PJ-002AH-SMT-TR            | R/A Surface Mount (2.1×5.5 mm)  | Main 5V DC input power port (Rated 5A)                                | 1         | $1.15            | $1.15            |
| **9**  | **Screw Terminal (Aux Power)**    | Phoenix Contact        | 1984617 (PTSA 0.5/2-2.5-Z) | Through-Hole 2.5 mm pitch       | 2-pin screwless terminal block for optional bench power leads         | 1         | $1.40            | $1.40            |
| **10** | **Current / Voltage Sensors**     | Texas Instruments      | INA219AIDR                 | SOIC-8                          | I2C Digital high-side power & current monitor IC                      | 4         | $1.80            | $7.20            |
| **11** | **Current Shunt Resistors**       | Vishay / Susumu        | WSL1206R1000FEA            | 1206 SMD                        | 0.100 Ω, 1%, 0.5W precision current sensing shunts                    | 4         | $0.65            | $2.60            |
| **12** | **3.3V LDO Voltage Reg**          | Diodes Inc.            | AP2112K-3.3TRG1            | SOT-23-5                        | Ultra-low dropout 3.3V 600mA linear regulator (for Hub/Sensors)       | 1         | $0.55            | $0.55            |
| **13** | **ESD / Surge Protection**        | STMicroelectronics     | USBLC6-2SC6                | SOT-23-6                        | Low-capacitance (3.5 pF) TVS array for D+/D- and VBUS clamping        | 6         | $0.45            | $2.70            |
| **14** | **High-Energy Transient Diodes**  | Diodes Inc.            | SMAJ5.0A-13-F              | DO-214AC (SMA)                  | 5.0V 400W unidirectional TVS diode against USB Killer surges          | 4         | $0.35            | $1.40            |
| **15** | **Resettable PPTC Fuses**         | Bel Fuse / Littelfuse  | 0ZCJ0050FF2E               | 1206 SMD                        | 500 mA hold / 1.0A trip PTC resettable fuses for downstream VBUS      | 4         | $0.40            | $1.60            |
| **16** | **24 MHz Hub Crystal**            | Abracon                | ABM8G-24.000MHZ-18-D2Y-T   | 4-SMD (3.2×2.5 mm)              | 24.000 MHz fundamental crystal for USB2514B clocking                  | 1         | $0.60            | $0.60            |
| **17** | **Downstream USB Ports**          | Amphenol ICC           | 61729-0010BLF              | Through-Hole Right-Angle        | USB 2.0 Type-A female receptacles                                     | 4         | $0.95            | $3.80            |
| **18** | **Upstream & Management USB**     | Wurth Elektronik       | 632723300011               | Hybrid SMT/TH Right-Angle       | USB 2.0 Type-C receptacles (16-pin / 24-pin compatible)               | 2         | $1.25            | $2.50            |
| **19** | **Module Socket Headers**         | Sullins Connector      | PPTC241LFBN-RC             | 2.54 mm Pitch Through-Hole      | 1×24 Female socket headers (for Cmod S7 FPGA Module)                  | 2         | $0.85            | $1.70            |
| **20** | **Module Socket Headers**         | Sullins Connector      | PPTC201LFBN-RC             | 2.54 mm Pitch Through-Hole      | 1×20 Female socket headers (for STM32 Black Pill Module)              | 2         | $0.75            | $1.50            |
| **21** | **Passives Kit (Caps/Resistors)** | Yageo / Walsin         | Misc. 0603 / 0805 SMD      | Standard 0603 / 0805            | 0.1µF, 1µF, 10µF, 100µF bulk caps; 90Ω/12kΩ/10kΩ/4.7kΩ resistors      | 1 lot     | $15.00           | $15.00           |


---



### Cost Summary

- **Estimated Unit Prototype Cost (including module boards & custom PCB run):** **~$194.25**
- **Marginal Cost per Additional Carrier Board (Components only):** **~$65.25** (excluding reusable FPGA/MCU dev boards)

