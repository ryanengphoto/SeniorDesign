# Sniffer block — rough draft (owner decisions in progress)

**Status:** Decisions through 2026-11-10 (incl. midterm-as-SoT for status bits / naming).  
**Owner:** FPGA sniffer / USB parse + triggers  
**Source of truth (owner):** [`Official_SD_docs/grp_19_midterm_milestone.pdf`](Official_SD_docs/grp_19_midterm_milestone.pdf) over [`fabric_slop.md`](fabric_slop.md) when they disagree — update fabric to match midterm.  
**Also:** [`firmwmare_slop.md`](firmwmare_slop.md) / GUI for living host encoding; current RTL under `FPGA/senior_design.srcs/sources_1/new/`

---

## 1. Role (context)

`sniffer_block` is the **per-port** inspection unit. `sniffer_wrapper` instantiates several of them. The block sees that port’s D+/D− tap (parallel with the hub path) and can request isolation for that port.

---

## 2. What is already in the tree

| Piece | File(s) | Rough job today |
| --- | --- | --- |
| Soft RX + framing front-end | `usb_packet_frontend` → TinyFPGA `usb_fs_rx` | Line → PID / bytes / CRC OK; CRC strip; `crc_fault` pulse |
| Isolation latch | `isolation_controller` | Sticky `kill` + `threat_code` until clear / manual |
| Wiring | `sniffer_block.sv` | Soft RX + `enumeration_analysis` + isolation. CRC fault → kill `0x5`. Storage-only policy: HID intf class `0x03` → kill `0x1`. |
| Enumeration analysis | `enumeration_analysis.sv` | SETUP/GET_DESCRIPTOR FSM → device + first interface fields |

Sim:
- `tb_sniffer` — port0 CRC/kill smoke
- `tb_enumeration_analysis` — direct-event device+config telemetry
- `tb_kill_e2e` — all ports sequential + concurrent: line → decode → CRC kill → sticky until SPI `Pn_CONTROL[6]` clear
- `tb_enum_e2e` — wire SETUP + descriptors → VID/PID/MSC class telemetry (no kill)
- `tb_demo_threat` — wire HID interface on storage-only port → kill `0x1`, clear_fault
- `tb_spi_enum_e2e` — wire enum → SPI-read `Pn_STATUS`/VID/PID/class; HID kill threat `0x1` + SPI clear
- `tb_main_selfstim` — `main_wrapper` auto self-stim → LED kill → SPI telemetry → `btn_clear`
- `tb_spi_manual_kill` — SPI `Pn_CONTROL[7]` operator isolate → threat `0x7` + SPI clear (all ports; no USB)
- `tb_kill_manual_cross` — CRC kill then SPI manual overwrite to `0x7`; manual sticky ignores CRC; re-arm
- `isolation_controller_sva` — sim-only checker under `synthesis translate_off`: sticky / manual `0x7` / clear / threat-pulse latch (+ cover counters). Procedural (XSim 2018.2 ignores concurrent `assert property`).
- Regression: `make -C FPGA sim-all` (`scripts/sim_all.tcl`); `COV=1` tries native XSim code coverage when supported; always writes `FPGA/cov/scenario_matrix.txt`

Board bring-up (`main_wrapper` + `cmod_s7_bringup.xdc`):
- 12→48 MHz MMCM, kill LEDs, btn_rst / btn_clear
- `usb_demo_selfstim` auto-plays HID enum on port0 after lock (~20 ms) for demo without carrier taps
- Sim knobs: `SIM_CLK_BYPASS`, `BOOT_STIM_CYCLES`

Bring-up also has `spi_slave` + `register_file` (fabric map); clear_fault only from SPI/register writes (not a free side-door in the E2E TB).

---

## 3. Evidence from midterm (grp_19) — background

See prior draft notes: parallel sniff, 48 MHz, FS/LS goals, midterm module list (SIE → FIFO → enum → HID → policy → port FSM), sticky block until MCU re-enable, UART status fields in §4.

---

## 4. Telemetry contract (FPGA regs → MCU → UART/GUI)

Owner direction: status registers must support the **port fields the software story needs**, sourced from FPGA and forwarded by the MCU.

### 4.1 Midterm binary UART status update (§7.2.3.1.1)

MCU→PC status frame (30 bytes @ 115200): start `0xAA` + **4×7 bytes** + CRC.

Per port (7 bytes), midterm Table 30:

| Byte | Name | Content |
| --- | --- | --- |
| 1 | Port status | Connection, switch/isolate, FPGA-related flags, threat-present (example fig. shows attached+isolated) |
| 2 | Threat ID | Threat type if present |
| 3 | Device class | 1-byte device class |
| 4–5 | Vendor ID | Low then high |
| 6–7 | Product ID | Low then high |

Host→MCU: isolate / re-enable (1-byte commands).

### 4.2 Living firmware / GUI contract (may differ in *encoding*)

[`firmwmare_slop.md`](firmwmare_slop.md) + `GUI/app/lib/protocol.dart` currently use **newline JSON**, not the midterm binary frame, but the **semantic fields** still need FPGA backing:

- `threat_code` (0–7)  
- `vid` / `pid`  
- `dev_class` / `int_class` (GUI JSON; midterm table lists device class; interface class if you keep it for GUI)  
- port **state** / connection / switch (MCU maps FPGA flags into host states)

**Implication for FPGA status outputs:** implement **midterm** port fields/bits. Update `fabric_slop.md` to match; do not prefer fabric over midterm.

Host UART **encoding** (JSON vs midterm binary) is MCU/GUI; FPGA only needs to store the midterm field set.

### 4.3 Packet errors (CRC / bit-stuff / malformed)

Midterm: SIE detects these; policy engine takes error counts and can **info / warn / critical immediate block**. Owner: follow midterm — v1 **may kill** when that path says block (not “CRC log-only”). Exact “first error vs N errors” still open in §9 if midterm is vague.

---

## 5. Locked direction (summary)

| Topic | Choice |
| --- | --- |
| Block shape | Midterm-style hierarchy: RX/SIE → (FIFO later) → enum + HID → policy → port FSM |
| Soft RX | Keep TinyFPGA / `usb_packet_frontend` as real RX path |
| Naming | **Rename RTL toward midterm module names** (SIE, enumeration analysis, …); update fabric_slop to match midterm |
| Clock (next work) | Single **48 MHz** domain in-block |
| Speed v1 | **FS only**; plan LS later |
| Parse style | Real **control-transfer / SETUP state machine** |
| Endpoints | **All endpoints** in scope (for the architecture); milestone work may still prioritize EP0 data paths first when coding |
| Packet FIFO | **Skip for v1**; add after sim of enum path is working |
| Enum / DPI v1 | Milestone 1: EP0 enum far enough for **device + config/interface** → latch VID/PID/device class/**interface class** into status (**telemetry**; DPI policy kills later). Packet-error kill already on first bad CRC/etc. |
| Hub vs device | Care about **device→host** for policy/timing |
| HID timing | **After** enum telemetry works |
| Keystroke definition | HID report content (new key down), not raw packet rate |
| Kill sources | Manual + midterm policy path (incl. packet errors that warrant immediate block); DPI/HID kills when those analyzers are enabled |
| Packet-error kill | **Follow midterm**; **v1 = kill on first** CRC / bit-stuff / clearly malformed packet |
| Latch clear | **MCU / clear_fault only** (sticky) |
| Policy | **Both**: bitstream defaults + MCU runtime override |
| Telemetry richness | **Full midterm port status story**; **midterm bit definitions** win over fabric_slop |
| Status bit SoT | **Midterm PDF**; update fabric_slop afterward |
| Next sim gate | Descriptor / enum path updates **status/telemetry** first (Q18); kills for enum threats still deferred until you enable them |

---

## 6. Target module map (midterm names → intent)

Evolve toward (per port unless noted):

| Midterm-oriented name | Role | v1 intent |
| --- | --- | --- |
| Input sampling + line decode + SIE | RX-only parse | Covered initially by existing soft RX; rename/split over time toward midterm names |
| Packet event FIFO | Structured events | **Later** |
| Enumeration analysis | SETUP/enum FSM; device + config/interface | **Milestone 1**: latch VID/PID/dev_class/intf_class into status; **no DPI kill yet** |
| HID behavior analyzer | Report-aware timing | **After** enum telemetry |
| Security policy engine | Severity / block decisions | Bitstream defaults + MCU override; DPI/HID kills when enabled |
| Port state manager | Enabled / blocked FSM | Sticky block; MCU re-enable |
| Status register bank + SPI | MCU-visible snapshot | Must match §4 field set |

Shared vs per-port placement of “policy engine” can still be refined while keeping midterm-style **logical** split.

---

## 7. Decision log

| Date | # | Decision |
| --- | --- | --- |
| 2026-11-10 | 1 | **A** — Midterm-style block: RX/SIE → FIFO → enum/HID → policy → port FSM |
| 2026-11-10 | 2 | **A** — Soft RX permanent |
| 2026-11-10 | 3 | **A** — Prefer midterm module names; **rename RTL** toward them |
| 2026-11-10 | 4 | **A** — Single 48 MHz for next milestone |
| 2026-11-10 | 5 | **A** — FS only now; **plan LS later** |
| 2026-11-10 | 6 | **B** — Real control-transfer / SETUP state machine |
| 2026-11-10 | 7 | **C** — All endpoints in architectural scope |
| 2026-11-10 | 8 | **B** — No FIFO in v1; **plan after sim working** |
| 2026-11-10 | 9 | **D** — Enum/DPI: update status/telemetry only (no kill); regs must match paper software fields (and living GUI/firmware semantics) |
| 2026-11-10 | 10 | **C** — Device→host focus for policy |
| 2026-11-10 | 11 | **B** — HID after DPI/enum telemetry |
| 2026-11-10 | 12 | **B** — Keystroke = HID report key-down semantics |
| 2026-11-10 | 13–14 | Midterm policy path; **2026-11-10 later: kill on first** CRC/bit-stuff/malformed |
| 2026-11-10 | 15 | **A** — Clear only via MCU / clear_fault |
| 2026-11-10 | 16 | **C** — Policy: bitstream defaults + MCU override |
| 2026-11-10 | 17 | **D** — Full midterm-style status telemetry from regs |
| 2026-11-10 | 18 | **B** — Next XSim: descriptor path → telemetry/status, no new kills |
| 2026-11-10 | SoT | Status / register **bits match midterm**; fabric_slop to be updated |
| 2026-11-10 | Names | Rename modules toward midterm names |
| 2026-11-10 | Enum M1 | **B** — parse device + config/interface for status telemetry |

---

## 8. Glossary (plain language)

**EP0 (endpoint 0)**  
Every USB device has a control endpoint numbered **0**. Plug-in setup (“enumeration”) uses **control transfers** on EP0: the host asks “what are you?” and the device answers with **descriptors** (VID, PID, class, etc.).  
“Start with EP0 device descriptor” means: first teach the FPGA to follow that setup conversation far enough to copy those ID bytes into status registers — before worrying about keyboards on other endpoints.

**Latch / “latched”**  
Hardware memory that **holds a value until cleared**. Example: once VID is parsed, keep showing it in the status register even after that USB packet is gone. Same idea for **kill**: once blocked, stay blocked until the MCU clears it — not a one-cycle pulse that disappears.

---

## 9. Still open (only what still needs a call)

- [x] **Enum coding order (milestone 1):** **B** — device **and** config/interface (VID/PID/dev class/intf class)  
- [x] **Packet-error threshold:** **first** bad CRC/bit-stuff/malformed → kill  
- [x] **Port status byte bits (provisional):** Fig. 19 is image-only; example value `0xC1` + text (“attached and isolated… threat…”) → RTL macros in `defines.svh`: bit0 attached, bit6 isolated, bit7 threat_present. Revisit if a clearer midterm callout appears.  
- [ ] **Host UART encoding:** JSON vs midterm binary — does **not** block FPGA RTL if registers hold midterm fields  
- [x] **Line-level SETUP tokens in XSim:** sim `usb_fs_tx` TOKEN_DATA path; `tb_enum_e2e` / `tb_demo_threat` pass

### What “item 5” was asking (explained — no action required to start)

Those were *optional later* board/firmware details, not blockers:

| Phrase | Meaning |
| --- | --- |
| UART JSON vs binary | How the **MCU talks to the PC**. FPGA only fills registers; MCU formats UART. |
| Kill pin polarity | Whether “isolated” means drive the switch pin **0** or **1**. Board schematic decides; can default and fix when wiring XDC. |
| Multi-threat priority | If two bad things happen the same clock, which threat ID is stored. Only matters once several kill sources are live. |

---

## 10. Out of scope for this draft

Pinout/XDC, MMCM details, SPI frame bits, PCB SI — unless pulled into §9.
