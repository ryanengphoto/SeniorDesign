`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date:   09/10/2026
// Design Name:   Hardware-Isolated USB Security Gateway
// Module Name:   sniffer_wrapper
// Project Name:  senior_design
// Target Devices: XC7S25-CSGA225 (Digilent Cmod S7-25)
// Tool Versions: Vivado 2018.2
// Description:
//   Packet-sniffer wrapper. Instantiates NUM_PORTS identical sniffer_block
//   instances (one per downstream USB port) and aggregates per-port
//   threat, kill, and status into the register file every cycle so the
//   MCU-visible state stays current.
//
// Dependencies:  sniffer_block, defines.svh
//
// Notes:
//   Skeleton only — clk/rst ports. D+/D- taps, kill aggregation, and
//   register-file status buses will be added later.
//
// Revision:
// Revision 0.01 - File Created (skeleton)
//////////////////////////////////////////////////////////////////////////////////

module sniffer_wrapper (
    input logic clk,
    input logic rst
);

    // TODO: generate NUM_PORTS sniffer_block instances; pack status/kill.

endmodule
