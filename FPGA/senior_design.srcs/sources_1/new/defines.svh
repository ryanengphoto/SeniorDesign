`ifndef DEFINES_SVH
`define DEFINES_SVH

//////////////////////////////////////////////////////////////////////////////////
// File:          defines.svh
// Project:       Hardware-Isolated USB Security Gateway
// Target Devices: XC7S25-CSGA225 (Digilent Cmod S7-25)
// Tool Versions: Vivado 2018.2
// Description:
//   Shared constants for the FPGA fabric: port count, clock rates, SPI
//   widths/addressing, threat codes, and register structs. Include from
//   RTL; keep aligned with Docs/fabric_slop.md.
//
// Notes:
//   Per-port map: CONTROL + STATUS only. Addresses are
//   BASE + port*STRIDE + offset — do not hardcode per-port addrs.
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
`define CLK_100M_HZ         100_000_000  // optional fast domain (not required)

// -----------------------------------------------------------------------------
// HID timing filter (48 MHz ticks)
// -----------------------------------------------------------------------------
// Human typing bound: 50 chars/s -> 20 ms minimum interval (Docs/d_c_txt.md).
`define HID_MIN_INTERVAL_MS 20
`define HID_QUARANTINE_MS   2000

// -----------------------------------------------------------------------------
// SPI framing (Docs/fabric_slop.md section 5)
// -----------------------------------------------------------------------------
`define SPI_ADDR_WIDTH      7
`define SPI_DATA_WIDTH      8

// -----------------------------------------------------------------------------
// SPI register map — dynamic per-port addressing
//   addr = PORT_REG_BASE + port * PORT_REG_STRIDE + offset
//   port 0: CONTROL 0x00, STATUS 0x01
//   port 1: CONTROL 0x02, STATUS 0x03
// -----------------------------------------------------------------------------
`define PORT_REG_BASE       7'h00
`define PORT_REG_STRIDE     7'h02
`define PORT_OFF_CONTROL    1'b0
`define PORT_OFF_STATUS     1'b1
`define PORT_REG_ADDR(port, off) \
    ((`PORT_REG_BASE) + ((port) * (`PORT_REG_STRIDE)) + (off))

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

// -----------------------------------------------------------------------------
// Per-port CONTROL (offset 0)
// [7] Manual Kill, [6] Clear Fault, [5] Confirm HID (GUI click unlock),
// [4:3] reserved, [2:0] Policy Mode
// -----------------------------------------------------------------------------
typedef struct packed {
    logic       manual_kill;  // [7] force isolate (open analog switch)
    logic       clear_fault;  // [6]
    logic       confirm_hid;  // [5] strobe: operator confirmed keyboard in GUI
    logic [1:0] reserved;     // [4:3]
    logic [2:0] policy_mode;  // [2:0]
} control_reg_t;

// -----------------------------------------------------------------------------
// Per-port STATUS (offset 1)
// [7] Isolated, [6] Attached, [5] Configured, [4] HID locked (awaiting confirm),
// [3:0] Threat Code
// -----------------------------------------------------------------------------
typedef struct packed {
    logic       isolated;    // [7] analog switch open / path cut
    logic       attached;    // [6]
    logic       configured;  // [5]
    logic       hid_locked;  // [4] 1 = HID seen, waiting for GUI confirm
    logic [3:0] threat_code; // [3:0]
} status_reg_t;

`endif // DEFINES_SVH
