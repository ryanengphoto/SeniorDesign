`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: sniffer_wrapper_sva
// Purpose: Cross-port clear/manual isolation — port i must not drop/force port j.
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module sniffer_wrapper_sva (
    input logic                   clk,
    input logic                   rst,
    input logic [`NUM_PORTS-1:0]  clear_fault,
    input logic [`NUM_PORTS-1:0]  manual_kill,
    input logic [`NUM_PORTS-1:0]  kill,
    input logic [3:0]             threat_code [`NUM_PORTS-1:0],
    input logic [7:0]             port_status [`NUM_PORTS-1:0]
);

    logic sample_valid;
    logic [`NUM_PORTS-1:0] kill_d, clear_d, manual_d;
    logic [3:0] threat_d [`NUM_PORTS-1:0];

    integer i, j;

    always_ff @(posedge clk) begin
        if (rst) begin
            sample_valid <= 1'b0;
            kill_d       <= '0;
            clear_d      <= '0;
            manual_d     <= '0;
            for (i = 0; i < `NUM_PORTS; i = i + 1)
                threat_d[i] <= 4'h0;
        end else begin
            if (sample_valid) begin
                for (i = 0; i < `NUM_PORTS; i = i + 1) begin
                    // Status mirror per port
                    if (port_status[i][`PORT_STATUS_ISOLATED_BIT] !== kill[i])
                        $error("sniffer_wrapper SVA: port%0d ISOLATED mismatch", i);
                    if (port_status[i][`PORT_STATUS_THREAT_PRESENT_BIT] !==
                        (threat_code[i] != `THREAT_NO_FAULT))
                        $error("sniffer_wrapper SVA: port%0d THREAT_PRESENT mismatch", i);

                    // Rising manual threat 0x7 requires that port's manual_kill
                    if (kill[i] && (threat_code[i] == `THREAT_MANUAL_HOST_KILL) &&
                        !(kill_d[i] && (threat_d[i] == `THREAT_MANUAL_HOST_KILL)) &&
                        !clear_d[i] && !manual_d[i])
                        $error("sniffer_wrapper SVA: port%0d got 0x7 without manual_kill", i);

                    // Cross-port: clear on i must not drop kill on j
                    for (j = 0; j < `NUM_PORTS; j = j + 1) begin
                        if (i != j) begin
                            if (clear_d[i] && !clear_d[j] && kill_d[j] && !kill[j] &&
                                !manual_d[j])
                                $error("sniffer_wrapper SVA: clear port%0d dropped kill port%0d",
                                       i, j);
                        end
                    end
                end
            end

            sample_valid <= 1'b1;
            kill_d       <= kill;
            clear_d      <= clear_fault;
            manual_d     <= manual_kill;
            for (i = 0; i < `NUM_PORTS; i = i + 1)
                threat_d[i] <= threat_code[i];
        end
    end

endmodule
