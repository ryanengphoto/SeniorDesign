`timescale 1ns / 1ps
`include "defines.svh"

//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date:   09/10/2026
// Design Name:   Hardware-Isolated USB Security Gateway
// Module Name:   sniffer_block
// Project Name:  senior_design
// Target Devices: XC7S25-CSGA225 (Digilent Cmod S7-25)
// Tool Versions: Vivado 2018.2
// Description:
//   Per-port USB packet sniffer. Samples that port's data_plus/data_minus
//   tap in parallel with the hub IC and decides whether traffic is
//   malicious. Drives data-path switch_en (1 = connected).
//   Intended sub-blocks (Docs/fabric_slop.md section 4) — not in tree yet:
//     - usb_rx_phy, usb_packet_checker, usb_dpi_engine,
//       hid_timing_filter, isolation_controller
//
// Dependencies:  defines.svh
//
// Notes:
//   Port list per Agents/fpga_module_io_plan.md. Internals still TODO;
//   switch_en/status tied to safe defaults for elaboration.
//
// Revision:
// Revision 0.02 - Ports: data lines, switch_en, policy/control, status
//////////////////////////////////////////////////////////////////////////////////

module sniffer_block (
    input  logic         clk,
    input  logic         rst,

    input  logic         data_plus,
    input  logic         data_minus,
    output logic         switch_en,

    input  logic [2:0]   policy_mode,
    input  logic         manual_kill,
    input  logic         clear_fault_pulse,
    input  logic         confirm_hid_pulse,

    output status_reg_t  status
);

    // Placeholder until PHY / isolation path is implemented.
    assign switch_en = 1'b1;
    assign status    = '0;

    // TODO: PHY, framer, DPI, HID timing filter, isolation_controller.

endmodule
