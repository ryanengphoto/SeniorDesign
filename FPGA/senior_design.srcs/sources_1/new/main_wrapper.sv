`timescale 1ns / 1ps
`include "defines.svh"

//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date:   09/10/2026
// Design Name:   Hardware-Isolated USB Security Gateway
// Module Name:   main_wrapper
// Project Name:  senior_design
// Target Devices: XC7S25-CSGA225 (Digilent Cmod S7-25)
// Tool Versions: Vivado 2018.2
// Description:
//   Top-level FPGA fabric wrapper. Board pins: fabric clk/rst, SPI slave
//   to MCU, per-port USB data taps, and per-port data-path switch enables.
//   Will instantiate sniffer_wrapper, register_file, and spi_slave (TBD).
//
//   Inspection is in parallel with the hub IC (not in-line). On threat,
//   per-port switch_en isolates the data path. FPGA = SPI slave; MCU master.
//
// Dependencies:  sniffer_wrapper, register_file, defines.svh
//                (spi_slave TBD — not in tree yet)
//
// Notes:
//   Port list locked to Agents/fpga_module_io_plan.md. Internal wiring
//   and spi_slave still TODO. switch_en placeholder: 1 = path connected.
//
// Revision:
// Revision 0.02 - Board I/O ports per IO plan (no IRQ / eFuse / mux names)
//////////////////////////////////////////////////////////////////////////////////

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

    // Placeholder until sniffer_wrapper / spi_slave are wired.
    // Logical intent: switch_en == 1 → data path connected.
    assign spi_miso     = 1'b0;
    assign p0_switch_en = 1'b1;
    assign p1_switch_en = 1'b1;
    assign p2_switch_en = 1'b1;
    assign p3_switch_en = 1'b1;

    // TODO: pack pN_data_* → sniffer_wrapper; unpack switch_en;
    //       instantiate register_file + spi_slave when present.

endmodule
