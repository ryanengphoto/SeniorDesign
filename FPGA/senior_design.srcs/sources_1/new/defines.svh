`ifndef DEFINES_SVH
`define DEFINES_SVH

//////////////////////////////////////////////////////////////////////////////////
// File:          defines.svh
// Project:       Hardware-Isolated USB Security Gateway
// Target Devices: XC7S25-CSGA225 (Digilent Cmod S7-25)
// Tool Versions: Vivado 2018.2
// Description:
//   Shared constants for the FPGA fabric: port count, clock rates, SPI
//   register addresses, policy/approve bits, and threat classification codes.
//   Values must stay aligned with Docs/fabric_slop.md (and GUI protocol
//   when present).
//////////////////////////////////////////////////////////////////////////////////

// -----------------------------------------------------------------------------
// Topology
// -----------------------------------------------------------------------------
`define NUM_PORTS           4

// -----------------------------------------------------------------------------
// Clock rates (Hz)
// -----------------------------------------------------------------------------
`define CLK_12M_HZ          12_000_000   // Cmod S7 onboard oscillator
`define CLK_48M_HZ          48_000_000   // USB FS 4x oversample (sniffer)
`define CLK_100M_HZ         100_000_000  // SPI slave / register file domain

// -----------------------------------------------------------------------------
// HID timing filter (48 MHz ticks)
// -----------------------------------------------------------------------------
// Human typing bound: 50 chars/s -> 20 ms minimum interval (Docs/d_c_txt.md).
`define HID_MIN_INTERVAL_MS       20
`define HID_QUARANTINE_MS         2000
`define HID_MIN_INTERVAL_CYCLES   32'd960_000      // 20 ms @ 48 MHz
`define HID_QUARANTINE_CYCLES     32'd96_000_000   // 2.0 s @ 48 MHz
`define HID_BURST_KEY_THRESHOLD   3                // >3 sub-interval key-downs

// Rapid bus-reset / re-enumeration storm
`define REENUM_WINDOW_CYCLES      32'd4_800_000    // 100 ms @ 48 MHz
`define REENUM_STORM_THRESHOLD    3                // >=3 resets in window

// -----------------------------------------------------------------------------
// Policy modes (Pn_CONTROL[2:0])
// -----------------------------------------------------------------------------
`define POLICY_HID_ALLOWED        3'h0
`define POLICY_STORAGE_ONLY       3'h1

// Pn_CONTROL bit fields
`define PCTL_POLICY_LO            0
`define PCTL_POLICY_HI            2
`define PCTL_APPROVE_BIT          5
`define PCTL_CLEAR_FAULT_BIT      6
`define PCTL_MANUAL_KILL_BIT      7

// -----------------------------------------------------------------------------
// SPI register map (7-bit addresses; see Docs/fabric_slop.md section 5)
// -----------------------------------------------------------------------------
`define ADDR_SYS_STATUS     7'h00
`define ADDR_SYS_CONTROL    7'h01
// 0x02 reserved (unused)
`define ADDR_P0_CONTROL     7'h10
`define ADDR_P0_STATUS      7'h11
`define ADDR_P0_VID_HIGH    7'h12
`define ADDR_P0_VID_LOW     7'h13
`define ADDR_P0_PID_HIGH    7'h14
`define ADDR_P0_PID_LOW     7'h15
`define ADDR_P0_DEV_CLASS   7'h16
`define ADDR_P0_INT_CLASS   7'h17
`define ADDR_P0_THREAT_DETAIL 7'h18
// Ports 1–3 mirror P0 at 0x20, 0x30, 0x40 (+0x08 for detail).

// -----------------------------------------------------------------------------
// Threat classification codes (4-bit; Docs/fabric_slop.md section 6)
// -----------------------------------------------------------------------------
`define THREAT_NO_FAULT             4'h0
`define THREAT_UNAUTHORIZED_HID     4'h1
`define THREAT_KEYSTROKE_BURST      4'h2
`define THREAT_COOLDOWN_BURST       4'h3  // HID hold / post-approve cooldown
`define THREAT_DESCRIPTOR_OVERFLOW  4'h4  // umbrella suspicious-enum family
`define THREAT_CRC_TOKEN_FAULT      4'h5
`define THREAT_BIT_STUFF_ERROR      4'h6
`define THREAT_MANUAL_HOST_KILL     4'h7

// Pn_THREAT_DETAIL nibble (when threat_code == 0x4)
`define DETAIL_NONE                 4'h0
`define DETAIL_OVERFLOW             4'h1
`define DETAIL_COMPOSITE_HID_MSC    4'h2
`define DETAIL_MULTI_HID            4'h3
`define DETAIL_REENUM_STORM         4'h4

// USB class codes used by enum / policy
`define USB_CLASS_HID               8'h03
`define USB_CLASS_MSC               8'h08
`define HID_PROTOCOL_KEYBOARD       8'h01

// -----------------------------------------------------------------------------
// Midterm UART port-status byte (Fig. 19 example 0xC1)
// Text: attached + isolated high, plus a threat-present flag.
// Exact figure callouts are image-only; bits below reproduce 0xC1 when all set.
// -----------------------------------------------------------------------------
`define PORT_STATUS_ATTACHED_BIT       0
`define PORT_STATUS_PENDING_BIT        1  // HID awaiting operator approve
`define PORT_STATUS_ISOLATED_BIT       6
`define PORT_STATUS_THREAT_PRESENT_BIT 7
`define PORT_STATUS_EXAMPLE_C1         8'hC1

`endif // DEFINES_SVH
