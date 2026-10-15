`timescale 1ns / 1ps
`include "defines.svh"

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
//   status / switch_en for the register file and top-level pads.
//
// Dependencies:  sniffer_block, defines.svh
//
// Notes:
//   Port list per Agents/fpga_module_io_plan.md. generate of sniffer_block
//   instances still TODO; outputs tied to safe defaults until then.
//
// Revision:
// Revision 0.02 - Ports: data_plus/minus, switch_en, control/status buses
//////////////////////////////////////////////////////////////////////////////////

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

    // Placeholder until sniffer_block generate is wired.
    assign switch_en  = {`NUM_PORTS{1'b1}};
    assign status_out = '{default: '0};

    // TODO: generate NUM_PORTS sniffer_block instances; fan control/line I/O.

endmodule
