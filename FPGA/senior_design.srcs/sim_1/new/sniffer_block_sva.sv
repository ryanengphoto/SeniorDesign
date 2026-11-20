`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: sniffer_block_sva
// Purpose: Policy / status / threat-mux monitors for sniffer_block (XSim procedural).
//          Bit-stuff 0x6 is not part of the mux (SIE does not export it).
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module sniffer_block_sva (
    input logic       clk,
    input logic       rst,
    input logic       speed_valid,
    input logic       crc_fault,
    input logic [2:0] policy_mode,
    input logic       unauthorized_hid_pulse,
    input logic       suspicious_pulse,
    input logic       suspicious_hold,
    input logic       keystroke_burst_pulse,
    input logic       cooldown_burst_pulse,
    input logic       hid_pending,
    input logic       hid_confirm_hold,
    input logic       threat_pulse,
    input logic [3:0] threat_code_in,
    input logic       attached,
    input logic       kill,
    input logic [3:0] threat_code,
    input logic [7:0] port_status
);

    logic sample_valid;
    wire  crc_threat = speed_valid & crc_fault;

    wire expected_pulse =
        crc_threat | suspicious_pulse | suspicious_hold |
        unauthorized_hid_pulse |
        keystroke_burst_pulse | cooldown_burst_pulse;

    logic [3:0] expected_code;
    always_comb begin
        if (crc_threat)
            expected_code = `THREAT_CRC_TOKEN_FAULT;
        else if (suspicious_pulse || suspicious_hold)
            expected_code = `THREAT_DESCRIPTOR_OVERFLOW;
        else if (unauthorized_hid_pulse)
            expected_code = `THREAT_UNAUTHORIZED_HID;
        else if (keystroke_burst_pulse)
            expected_code = `THREAT_KEYSTROKE_BURST;
        else if (cooldown_burst_pulse)
            expected_code = `THREAT_COOLDOWN_BURST;
        else
            expected_code = `THREAT_NO_FAULT;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            sample_valid <= 1'b0;
        end else begin
            if (sample_valid) begin
                if ((policy_mode != `CTRL_POLICY_STORAGE_ONLY) && unauthorized_hid_pulse)
                    $error("sniffer_block SVA: HID 0x1 pulse outside storage-only policy");

                if (!speed_valid && crc_fault)
                    $error("sniffer_block SVA: crc_fault before speed lock");

                if (threat_pulse !== expected_pulse)
                    $error("sniffer_block SVA: threat_pulse mux mismatch");

                if (threat_code_in !== expected_code)
                    $error("sniffer_block SVA: threat_code_in mux mismatch");

                if (port_status[`PORT_STATUS_ATTACHED_BIT] !== attached)
                    $error("sniffer_block SVA: ATTACHED bit mismatch");
                if (port_status[`PORT_STATUS_HID_PENDING_BIT] !==
                    (hid_pending | hid_confirm_hold))
                    $error("sniffer_block SVA: HID_PENDING bit mismatch");
                if (port_status[`PORT_STATUS_ISOLATED_BIT] !== kill)
                    $error("sniffer_block SVA: ISOLATED bit mismatch");
                if (port_status[`PORT_STATUS_THREAT_PRESENT_BIT] !==
                    ((threat_code != `THREAT_NO_FAULT) | hid_pending |
                     hid_confirm_hold))
                    $error("sniffer_block SVA: THREAT_PRESENT bit mismatch");
                // Reserved mid bits except HID pending (bit 4)
                if ((port_status & 8'h2E) != 8'h00)
                    $error("sniffer_block SVA: reserved port_status bits nonzero");
            end
            sample_valid <= 1'b1;
        end
    end

endmodule
