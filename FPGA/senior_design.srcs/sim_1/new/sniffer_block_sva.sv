`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: sniffer_block_sva
// Purpose: Policy / status / threat-mux monitors for sniffer_block (XSim procedural).
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module sniffer_block_sva #(
    parameter bit POLICY_STORAGE_ONLY = 1'b1
) (
    input logic       clk,
    input logic       rst,
    input logic       crc_fault,
    input logic       intf_class_valid,
    input logic       intf_class_valid_d,
    input logic [7:0] intf_class,
    input logic       hid_threat_pulse,
    input logic       threat_pulse,
    input logic [3:0] threat_code_in,
    input logic       attached,
    input logic       kill,
    input logic [3:0] threat_code,
    input logic [7:0] port_status
);

    logic sample_valid;

    always_ff @(posedge clk) begin
        if (rst) begin
            sample_valid <= 1'b0;
        end else begin
            if (sample_valid) begin
                if (hid_threat_pulse !==
                    (POLICY_STORAGE_ONLY && intf_class_valid && !intf_class_valid_d &&
                     (intf_class == 8'h03)))
                    $error("sniffer_block SVA: hid_threat_pulse decode mismatch");

                if (!POLICY_STORAGE_ONLY && hid_threat_pulse)
                    $error("sniffer_block SVA: HID pulse with POLICY_STORAGE_ONLY=0");

                if (threat_pulse !== (crc_fault | hid_threat_pulse))
                    $error("sniffer_block SVA: threat_pulse mux mismatch");

                // CRC wins over HID when both true (matches sniffer_block assign).
                if (threat_code_in !==
                    (crc_fault        ? `THREAT_CRC_TOKEN_FAULT :
                     hid_threat_pulse ? `THREAT_UNAUTHORIZED_HID :
                                        `THREAT_NO_FAULT))
                    $error("sniffer_block SVA: threat_code_in mux mismatch");

                if (port_status[`PORT_STATUS_ATTACHED_BIT] !== attached)
                    $error("sniffer_block SVA: ATTACHED bit mismatch");
                if (port_status[`PORT_STATUS_ISOLATED_BIT] !== kill)
                    $error("sniffer_block SVA: ISOLATED bit mismatch");
                if (port_status[`PORT_STATUS_THREAT_PRESENT_BIT] !==
                    (threat_code != `THREAT_NO_FAULT))
                    $error("sniffer_block SVA: THREAT_PRESENT bit mismatch");
                if ((port_status & 8'h3E) != 8'h00)
                    $error("sniffer_block SVA: reserved port_status bits nonzero");
            end
            sample_valid <= 1'b1;
        end
    end

endmodule
