`ifndef DEFINES_SVH
`define DEFINES_SVH

//////////////////////////////////////////////////////////////////////////////////
// File:          defines.svh
// Project:       Hardware-Isolated USB Security Gateway
// Target Devices: XC7S25-CSGA225 (Digilent Cmod S7-25)
// Tool Versions: Vivado 2018.2
// Description:
//   Shared constants for the FPGA fabric: port count, clock rates, SPI
//   register addresses, and threat classification codes. Include this
//   header from RTL modules; do not scatter magic numbers in the design.
//   Values must stay aligned with Docs/fabric_slop.md (and GUI protocol
//   when present).
//
// Notes:
//   Skeleton header — macros below document the contract. Functional
//   RTL that consumes them has not been implemented yet.
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
`define HID_MIN_INTERVAL_MS 20
`define HID_QUARANTINE_MS   2000

// -----------------------------------------------------------------------------
// SPI register map (7-bit addresses; see Docs/fabric_slop.md section 5)
// -----------------------------------------------------------------------------
`define ADDR_SYS_STATUS     7'h00
`define ADDR_SYS_CONTROL    7'h01
`define ADDR_PORT_IRQ       7'h02
`define ADDR_P0_CONTROL     7'h10
`define ADDR_P0_STATUS      7'h11
`define ADDR_P0_VID_HIGH    7'h12
`define ADDR_P0_VID_LOW     7'h13
`define ADDR_P0_PID_HIGH    7'h14
`define ADDR_P0_PID_LOW     7'h15
`define ADDR_P0_DEV_CLASS   7'h16
`define ADDR_P0_INT_CLASS   7'h17
// Ports 1–3 mirror P0 at 0x20, 0x30, 0x40.

// -----------------------------------------------------------------------------
// Threat classification codes (4-bit; Docs/fabric_slop.md section 6)
// -----------------------------------------------------------------------------
`define THREAT_NO_FAULT             4'h0
`define THREAT_UNAUTHORIZED_HID     4'h1
`define THREAT_KEYSTROKE_BURST      4'h2
`define THREAT_COOLDOWN_BURST       4'h3
`define THREAT_DESCRIPTOR_OVERFLOW  4'h4
`define THREAT_CRC_TOKEN_FAULT      4'h5
`define THREAT_BIT_STUFF_ERROR      4'h6
`define THREAT_MANUAL_HOST_KILL     4'h7

`endif // DEFINES_SVH
