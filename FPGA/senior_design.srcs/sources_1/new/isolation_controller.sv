`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: isolation_controller
// Purpose: Fast-path kill latch for one sniffer channel.
//          Latches kill + threat_code on threat_pulse until clear_fault
//          (or rst). manual_kill forces THREAT_MANUAL_HOST_KILL.
//
// Threat codes: Docs/fabric_slop.md §6 / senior_design defines.svh
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module isolation_controller (
    input  logic       clk,
    input  logic       rst,

    input  logic       threat_pulse,
    input  logic [3:0] threat_code_in,

    input  logic       manual_kill,
    input  logic       clear_fault,

    output logic       kill,
    output logic [3:0] threat_code
);

    always_ff @(posedge clk) begin
        if (rst) begin
            kill        <= 1'b0;
            threat_code <= `THREAT_NO_FAULT;
        end else if (clear_fault) begin
            kill        <= 1'b0;
            threat_code <= `THREAT_NO_FAULT;
        end else if (manual_kill) begin
            kill        <= 1'b1;
            threat_code <= `THREAT_MANUAL_HOST_KILL;
        end else if (threat_pulse && !kill) begin
            // Sticky until cleared; ignore further codes while isolated.
            kill        <= 1'b1;
            threat_code <= threat_code_in;
        end
    end

    // Sim-only SVA checker (XSim 2018.2: file-scope bind is broken / VRFC 10-946).
    // Guard VERILATOR: coverage sidecar skips this; XSim still sees translate_off block.
`ifndef VERILATOR
    // synthesis translate_off
    isolation_controller_sva u_isol_sva (
        .clk           (clk),
        .rst           (rst),
        .threat_pulse  (threat_pulse),
        .threat_code_in(threat_code_in),
        .manual_kill   (manual_kill),
        .clear_fault   (clear_fault),
        .kill          (kill),
        .threat_code   (threat_code)
    );
    // synthesis translate_on
`endif

endmodule
