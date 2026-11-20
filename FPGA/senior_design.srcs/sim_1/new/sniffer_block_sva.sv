`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: sniffer_block_sva
// Purpose: Policy / status / threat-mux monitors for sniffer_block (XSim procedural).
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module sniffer_block_sva #(
    parameter bit POLICY_STORAGE_ONLY = 1'b0
) (
    input logic       clk,
    input logic       rst,
    input logic       crc_fault,
    input logic       bit_stuff_fault,
    input logic       storage_only,
    input logic       unauthorized_hid_pulse,
    input logic       hid_keyboard_seen,
    input logic       config_walk_done,
    input logic       suspicious_sticky,
    input logic       suspicious_pulse,
    input logic       suspicious_hold,
    input logic       keystroke_burst_pulse,
    input logic       cooldown_burst_pulse,
    input logic       hid_hold_pulse,
    input logic       threat_pulse,
    input logic [3:0] threat_code_in,
    input logic       attached,
    input logic       pending_hid,
    input logic       kill,
    input logic [3:0] threat_code,
    input logic [7:0] port_status
);

    logic sample_valid;

    wire expected_unauth =
        storage_only && hid_keyboard_seen && config_walk_done &&
        !suspicious_sticky && !kill;

    wire expected_pulse =
        bit_stuff_fault | crc_fault | suspicious_pulse | suspicious_hold |
        unauthorized_hid_pulse |
        keystroke_burst_pulse | cooldown_burst_pulse | hid_hold_pulse;

    logic [3:0] expected_code;
    always_comb begin
        if (bit_stuff_fault)
            expected_code = `THREAT_BIT_STUFF_ERROR;
        else if (crc_fault)
            expected_code = `THREAT_CRC_TOKEN_FAULT;
        else if (suspicious_pulse || suspicious_hold)
            expected_code = `THREAT_DESCRIPTOR_OVERFLOW;
        else if (unauthorized_hid_pulse)
            expected_code = `THREAT_UNAUTHORIZED_HID;
        else if (keystroke_burst_pulse)
            expected_code = `THREAT_KEYSTROKE_BURST;
        else if (cooldown_burst_pulse || hid_hold_pulse)
            expected_code = `THREAT_COOLDOWN_BURST;
        else
            expected_code = `THREAT_NO_FAULT;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            sample_valid <= 1'b0;
        end else begin
            if (sample_valid) begin
                if (unauthorized_hid_pulse !== expected_unauth)
                    $error("sniffer_block SVA: unauthorized_hid_pulse decode mismatch");

                if (threat_pulse !== expected_pulse)
                    $error("sniffer_block SVA: threat_pulse mux mismatch");

                if (threat_code_in !== expected_code)
                    $error("sniffer_block SVA: threat_code_in mux mismatch");

                if (port_status[`PORT_STATUS_ATTACHED_BIT] !== attached)
                    $error("sniffer_block SVA: ATTACHED bit mismatch");
                if (port_status[`PORT_STATUS_PENDING_BIT] !== pending_hid)
                    $error("sniffer_block SVA: PENDING bit mismatch");
                if (port_status[`PORT_STATUS_ISOLATED_BIT] !== kill)
                    $error("sniffer_block SVA: ISOLATED bit mismatch");
                if (port_status[`PORT_STATUS_THREAT_PRESENT_BIT] !==
                    (threat_code != `THREAT_NO_FAULT))
                    $error("sniffer_block SVA: THREAT_PRESENT bit mismatch");
                if ((port_status & 8'h3C) != 8'h00)
                    $error("sniffer_block SVA: reserved port_status bits nonzero");
            end
            sample_valid <= 1'b1;
        end
    end

endmodule
