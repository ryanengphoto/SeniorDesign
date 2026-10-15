# FPGA Module I/O Port Plan (scratch)

**Status:** DRAFT — not signed off  
**Goal:** Agree port lists for every fabric module before changing RTL.  
**Sources:** `Docs/fabric_slop.md`, `Docs/Board_slop.md`, `FPGA/.../defines.svh`, current skeletons under `FPGA/senior_design.srcs/sources_1/new/`  
**Sign-off:** fill §10 when ready; **do not implement** until then.

---

## How to use this file

1. Edit proposed ports / open decisions below.
2. Mark each module `Agreed` / `Needs discussion` / `Deferred`.
3. When the whole plan is good, set **Status** to `SIGNED OFF` and date it in §10.
4. Only after that: update RTL + docs / XDC to match. (Legacy `clk_12m` / `mux_en` / eFuse-from-FPGA / interrupt language in `Docs/` is out of date vs this plan — scrub on sign-off.)

**Conventions (working):**

| Item | Decision |
| --- | --- |
| Clock | Every module takes fabric `clk`. One synchronous fabric. Optional MMCM only to raise the *rate* of that same clock — not a second management domain. |
| Reset | Every module takes active-high `rst`. |
| USB lines | `data_plus` / `data_minus` (top: `pN_data_plus` / `pN_data_minus`). |
| Isolation | `switch_en` only (data path). No eFuse / VBUS / power ports anywhere in the FPGA hierarchy. |
| Interrupts | None. No IRQ ports at any level. |
| Packing | Expanded `pN_*` at top for XDC; packed `[NUM_PORTS-1:0]` buses inside `main_wrapper` ↔ `sniffer_wrapper` / `register_file`. |
| Widths | Threat = 4 bits; SPI addr = 7; SPI data = 8 (`defines.svh`). |

---

## 1. Hierarchy (target)

```
main_wrapper                          [board pins]
├── (optional) MMCM / BUFG            [same fabric clk, higher rate if needed]
├── sniffer_wrapper
│   └── sniffer_block × NUM_PORTS
│       ├── usb_rx_phy
│       ├── usb_packet_checker
│       ├── usb_dpi_engine
│       ├── hid_timing_filter
│       └── isolation_controller      [sole driver of switch_en]
├── register_file                     [SPI-visible CONTROL/STATUS]
└── spi_slave                         [MCU ↔ register_file]
```

**Exists today (skeleton / partial):** `main_wrapper`, `sniffer_wrapper`, `sniffer_block`, `register_file`  
**Not in tree yet:** `usb_rx_phy`, `usb_packet_checker`, `usb_dpi_engine`, `hid_timing_filter`, `isolation_controller`, `spi_slave`

### Internal interconnect (logical)

```
                    ┌─────────────────────────────────────────┐
  clk, rst ────────►│              main_wrapper               │
                    │                                         │
  spi_* ───────────►│  spi_slave ◄──► register_file           │
                    │       │              │                  │
                    │       │         control buses           │
                    │       │         status buses            │
                    │       ▼              ▼                  │
  data_plus/minus ─►│         sniffer_wrapper                 │
  switch_en ◄───────│              │                          │
                    │              ▼                          │
                    │         sniffer_block ×4                │
                    └─────────────────────────────────────────┘
```

All children share the same `clk` / `rst`. No fabric CDC ports between sniffer and register_file.

---

## 2. Top / board pins — `main_wrapper`

### Current

```sv
input logic clk,
input logic rst
```

### Decisions from review (2026-09-15)

#### Why not `clk_12m`?
The board oscillator happens to be 12 MHz, but the **port name should describe the role (`clk`), not the frequency**. Frequency belongs in the constraints / MMCM config.

**Clock domains:** one fabric clock for sniffers, register file, and SPI core. If USB oversampling needs a higher rate, derive it from `clk` and run the fabric there — still one synchronous fabric.

#### Why not active-low reset?
**No good reason here.** Use active-high `rst`.

#### No interrupt pin
MCU polls SPI. **No interrupt ports at any hierarchy level.**

#### USB tap names
`pN_data_plus`, `pN_data_minus`.

#### Kill / switch naming (not “mux”)
`pN_switch_en` — data-path switch enable. Logical intent: `1 = path connected`; invert at the pad if the part needs it (**polarity TBD**).

#### No eFuse / VBUS from FPGA
Isolation = data switch only. No `efuse_*` anywhere in this hierarchy.

---

### Proposed `main_wrapper` ports

```sv
module main_wrapper (
    input  logic clk,
    input  logic rst,

    input  logic spi_sck,
    input  logic spi_mosi,
    output logic spi_miso,
    input  logic spi_cs_n,

    input  logic p0_data_plus,
    input  logic p0_data_minus,
    output logic p0_switch_en,

    input  logic p1_data_plus,
    input  logic p1_data_minus,
    output logic p1_switch_en,

    input  logic p2_data_plus,
    input  logic p2_data_minus,
    output logic p2_switch_en,

    input  logic p3_data_plus,
    input  logic p3_data_minus,
    output logic p3_switch_en
);
```

**Pin count:** 18 I/Os.  
**Module status:** Lean **Agreed** pending `switch_en` polarity and whether `rst` is a real board pin.

**Children wired inside (not top ports):** `sniffer_wrapper`, `register_file`, `spi_slave`, optional MMCM.

---

## 3. Clocking (optional MMCM inside `main_wrapper`)

Not a separate RTL module unless extracted later. If present:

| Net | Role |
| --- | --- |
| `clk` (pad) | Board oscillator into MMCM / BUFG |
| `clk` (fabric) | Single clock distributed to all modules below |
| `rst` | Held asserted until MMCM `locked` (if MMCM used) |

No `clk_12m` / `clk_48m` / `clk_100m` module ports. No dual-domain reset pair.

---

## 4. Direct children of `main_wrapper`

### 4.1 `spi_slave`

Bridges MCU SPI pins ↔ register_file host bus. Same `clk` as the rest of the fabric; SPI SCK is sampled / shifted with sync into `clk` as needed (implementation detail, not a second fabric domain port).

```sv
module spi_slave (
    input  logic                       clk,
    input  logic                       rst,

    input  logic                       spi_sck,
    input  logic                       spi_mosi,
    output logic                       spi_miso,
    input  logic                       spi_cs_n,

    output logic [`SPI_ADDR_WIDTH-1:0] addr,
    output logic [`SPI_DATA_WIDTH-1:0] data_out,   // write data → regfile data_in
    input  logic [`SPI_DATA_WIDTH-1:0] data_in,    // read data  ← regfile data_out
    output logic                       write_en,
    output logic                       read_en
);
```

Frame: 16-bit Mode 0; bit15 = R/W, [14:8] addr, [7:0] data (`Docs/fabric_slop.md` §5).

**Status:** Draft — naming/clock rules locked to top.

---

### 4.2 `register_file`

SPI-visible CONTROL/STATUS. Does **not** drive `switch_en`. Publishes control levels/pulses to sniffers; consumes status from sniffers.

```sv
module register_file (
    input  logic                       clk,
    input  logic                       rst,

    // Host bus from spi_slave
    input  logic [`SPI_ADDR_WIDTH-1:0] addr,
    input  logic [`SPI_DATA_WIDTH-1:0] data_in,
    output logic [`SPI_DATA_WIDTH-1:0] data_out,
    input  logic                       write_en,
    input  logic                       read_en,

    // From sniffer_wrapper (same clock — no CDC ports)
    input  status_reg_t                status_in  [`NUM_PORTS],
    input  logic [`NUM_PORTS-1:0]      status_we,   // optional; or continuous sample

    // To sniffer_wrapper
    output control_reg_t               control_out [`NUM_PORTS],
    output logic [`NUM_PORTS-1:0]      manual_kill,         // CONTROL[7] level
    output logic [`NUM_PORTS-1:0]      clear_fault_pulse,   // CONTROL[6] one-cycle
    output logic [`NUM_PORTS-1:0]      confirm_hid_pulse    // CONTROL[5] one-cycle
);
```

| Port group | Notes |
| --- | --- |
| SPI host bus | Unchanged vs current skeleton |
| `status_in` | Packed `status_reg_t` per port from sniffers |
| `control_out` | Full CONTROL struct (policy_mode etc.) |
| Pulses | `clear_fault` / `confirm_hid` decoded as one-cycle strobes so sniffer edge-detect is simple |
| **Not present** | `switch_en`, eFuse, IRQ |

**Lean:** pulses for [6]/[5]; level for `manual_kill` (**D6**).  
**Status:** Draft — rippled; handshake for `status_we` still open (**continuous vs strobe**).

---

### 4.3 `sniffer_wrapper`

Instantiates `NUM_PORTS` identical `sniffer_block`s. Aggregates status up; fans control / line I/O down.

```sv
module sniffer_wrapper (
    input  logic                       clk,
    input  logic                       rst,

    input  logic [`NUM_PORTS-1:0]      data_plus,
    input  logic [`NUM_PORTS-1:0]      data_minus,
    output logic [`NUM_PORTS-1:0]      switch_en,

    input  control_reg_t               control_in [`NUM_PORTS],
    input  logic [`NUM_PORTS-1:0]      manual_kill,
    input  logic [`NUM_PORTS-1:0]      clear_fault_pulse,
    input  logic [`NUM_PORTS-1:0]      confirm_hid_pulse,

    output status_reg_t                status_out [`NUM_PORTS]
);
```

`main_wrapper` packs `p0_data_plus`… into `data_plus[0]`… and unpacks `switch_en[N]` → `pN_switch_en`.

**Status:** Draft — rippled from top (no mux/eFuse/IRQ/multi-clock).

---

## 5. `sniffer_block` (one port)

Per-port shell. Same naming as top, scalar.

```sv
module sniffer_block (
    input  logic         clk,
    input  logic         rst,

    input  logic         data_plus,
    input  logic         data_minus,
    output logic         switch_en,

    input  logic [2:0]   policy_mode,          // from control_in.policy_mode
    input  logic         manual_kill,
    input  logic         clear_fault_pulse,
    input  logic         confirm_hid_pulse,

    output status_reg_t  status
);
```

Internal pipeline (all on `clk` / `rst`):

```
data_plus/minus
    → usb_rx_phy
    → usb_packet_checker
    → usb_dpi_engine ──► hid_timing_filter
            │                    │
            └──── threats ───────┴──► isolation_controller → switch_en
                                              │
                                              └── status fields
```

`status` assembly (proposed): `attached` / related from PHY; `configured` / `hid_locked` seed from DPI; threat codes from PHY/checker/DPI/HID; `isolated` + latched `threat_code` + `hid_locked` + `switch_en` from `isolation_controller`.

**Status:** Draft

---

## 6. Sub-blocks inside `sniffer_block`

All: `clk`, `rst` only for timing. No power, mux, or interrupt ports.

### 6.1 `usb_rx_phy`

Line sample → NRZI → bit unstuff → line state.

```sv
module usb_rx_phy (
    input  logic clk,
    input  logic rst,

    input  logic data_plus,
    input  logic data_minus,

    output logic bit_valid,
    output logic bit_data,
    output logic se0,
    output logic bus_reset,
    output logic eop,
    output logic rx_active,
    output logic bit_stuff_error,   // → threat 0x6
    output logic attached           // optional; else derived in sniffer_block
);
```

**Status:** Draft

---

### 6.2 `usb_packet_checker`

SYNC/PID lock, CRC-5/CRC-16, byte stream.

```sv
module usb_packet_checker (
    input  logic       clk,
    input  logic       rst,

    input  logic       bit_valid,
    input  logic       bit_data,
    input  logic       eop,
    input  logic       bus_reset,

    output logic [7:0] pid,
    output logic       pid_valid,
    output logic [6:0] token_addr,
    output logic [3:0] token_endp,
    output logic       crc_ok,
    output logic       crc_error,     // → threat 0x5
    output logic [7:0] byte_data,
    output logic       byte_valid,
    output logic       pkt_done
);
```

**Status:** Draft — exact token vs data timing still TBD at implement time.

---

### 6.3 `usb_dpi_engine`

Descriptor / class inspection on EP0 (and HID report detect as needed).

```sv
module usb_dpi_engine (
    input  logic       clk,
    input  logic       rst,

    input  logic [7:0] pid,
    input  logic       pid_valid,
    input  logic [6:0] token_addr,
    input  logic [3:0] token_endp,
    input  logic [7:0] byte_data,
    input  logic       byte_valid,
    input  logic       pkt_done,
    input  logic [2:0] policy_mode,

    output logic       configured,            // STATUS[5]
    output logic       hid_keyboard,          // seeds hid_locked path
    output logic       hid_report_pulse,      // → hid_timing_filter
    output logic       unauthorized_hid,      // threat 0x1
    output logic       descriptor_overflow,   // threat 0x4

    // Optional debug / future SPI map — not required for v1 top
    output logic [15:0] vid,
    output logic [15:0] pid_dev,
    output logic [7:0]  dev_class,
    output logic [7:0]  iface_class
);
```

**Open:** export VID/PID over SPI in v1, or keep internal only (**D5**).  
**Status:** Draft

---

### 6.4 `hid_timing_filter`

Keystroke interval + post-enum cooldown.

```sv
module hid_timing_filter (
    input  logic clk,
    input  logic rst,

    input  logic hid_report_pulse,
    input  logic hid_armed,           // after confirm_hid; rate filter active
    input  logic in_cooldown,         // post-enum window (source TBD: DPI or isolation)

    output logic keystroke_burst,     // threat 0x2
    output logic cooldown_burst       // threat 0x3
);
```

**Status:** Draft — who owns `in_cooldown` / `hid_armed` wiring inside `sniffer_block` still open.

---

### 6.5 `isolation_controller`

**Sole** driver of `switch_en` for that port. Latches isolation / threat / hid_locked.

```sv
module isolation_controller (
    input  logic       clk,
    input  logic       rst,

    input  logic [3:0] threat_code_req,   // priority-encoded in sniffer_block
    input  logic       hid_locked_req,    // from DPI hid_keyboard (first layer)
    input  logic       manual_kill,
    input  logic       clear_fault_pulse,
    input  logic       confirm_hid_pulse,

    output logic       switch_en,         // data path only
    output logic       isolated,          // STATUS[7]
    output logic       hid_locked,        // STATUS[4]
    output logic [3:0] threat_code        // STATUS[3:0] latched
);
```

Logical intent: `switch_en == 1` → path connected; `0` → isolated (pad invert if needed).

**Not present:** eFuse, mux, IRQ.  
**Status:** Draft — threat priority order TBD.

---

### 6.6 Threat combine (inside `sniffer_block`, not necessarily a module)

Suggested priority into `threat_code_req` (high → low), open to edit:

1. `manual_kill` → `0x7` (may also be handled only as level inside isolation)  
2. `unauthorized_hid` → `0x1`  
3. `keystroke_burst` → `0x2`  
4. `cooldown_burst` → `0x3`  
5. `descriptor_overflow` → `0x4`  
6. `crc_error` → `0x5`  
7. `bit_stuff_error` → `0x6`  
8. else `0x0`

---

## 7. Name / signal ripple checklist

| Old (reject) | New |
| --- | --- |
| `clk_12m`, `clk_48m`, `clk_100m` as module ports | `clk` |
| `rst_n`, `rst_48`, `rst_100` | `rst` |
| `fpga_irq_n`, `irq_n`, any IRQ | *(deleted)* |
| `pN_dp_tap`, `dp`, `dm_tap` | `data_plus` / `data_minus` (`pN_` at top) |
| `mux_en`, `mux_en_n` | `switch_en` |
| `efuse_en`, any VBUS/power FPGA out | *(deleted)* |
| CDC ports between sniffer ↔ regfile | *(deleted — same `clk`)* |

---

## 8. Open decisions (remaining)

| # | Decision | Options | Lean |
| --- | --- | --- | --- |
| D1 | `switch_en` pad polarity | High = path on vs part OE polarity | Logical `1` = connected; invert at pad if needed |
| D2 | Is `rst` a real pin? | Board / MCU GPIO / tie-off | TBD |
| D3 | Sample clock rate | Raw board `clk` vs MMCM-up | TBD with PHY |
| D4 | `status_we` | Continuous assign vs per-port strobe | Continuous OK on same clock? |
| D5 | VID/PID in SPI map v1 | Yes / No | No — keep DPI outputs internal |
| D6 | clear/confirm | Already leaned pulse | Keep pulses |
| D7 | `attached` source | PHY heuristic vs none in v1 | PHY `attached` |
| D8 | Threat priority | Order in §6.6 | TBD |

**Closed:** no IRQ; no eFuse; `clk`/`rst`; `data_plus`/`data_minus`; `switch_en`; single fabric clock rippled through all modules below `main_wrapper`.

---

## 9. Sign-off

| Field | Value |
| --- | --- |
| Plan status | DRAFT |
| Owner review | _pending_ (hierarchy rippled; review children next) |
| Date signed off | _—_ |
| Notes | |

When signed off, implementation order suggestion:

1. Freeze this plan; scrub conflicting names in `Docs/` / XDC drafts  
2. `main_wrapper` + child port lists (`spi_slave`, `register_file`, `sniffer_wrapper`)  
3. `sniffer_block` shell + `isolation_controller`  
4. PHY → checker → DPI → HID filter  
5. Constraints match top ports; `make -C FPGA sim` / `synth`

---

## 10. Change log (scratch)

| Date | Change |
| --- | --- |
| 2026-09-15 | Initial draft from fabric/board specs + current skeletons |
| 2026-09-15 | `main_wrapper` review: `clk`; active-high `rst`; no IRQ; `data_plus`/`data_minus`; `switch_en`; no eFuse |
| 2026-09-15 | Ripple to `spi_slave`, `register_file`, `sniffer_wrapper`, `sniffer_block`, and all inner sub-blocks; full SV port sketches; interconnect diagram; reject-list table; remove multi-clock/CDC/IRQ/eFuse from lower levels |
| 2026-09-15 | Propagated ports into existing RTL only: `main_wrapper`, `sniffer_wrapper`, `sniffer_block`, `register_file` (+ `tb_sniffer` tie-offs). No new modules. Internals still placeholders. |
