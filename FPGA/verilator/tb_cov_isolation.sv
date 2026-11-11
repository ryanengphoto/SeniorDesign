// Coverage TB for isolation_controller (directed; no USB).
// Build: scripts/run_verilator_cov.sh (make cov-verilator)

`timescale 1ns / 1ps
`include "defines.svh"

module tb_cov_isolation;
    logic clk = 1'b0;
    logic rst = 1'b1;
    always #5 clk = ~clk; // 100 MHz abstract; ratio irrelevant for this DUT

    logic       threat_pulse = 1'b0;
    logic [3:0] threat_code_in = `THREAT_NO_FAULT;
    logic       manual_kill = 1'b0;
    logic       clear_fault = 1'b0;
    logic       kill;
    logic [3:0] threat_code;

    isolation_controller dut (
        .clk           (clk),
        .rst           (rst),
        .threat_pulse  (threat_pulse),
        .threat_code_in(threat_code_in),
        .manual_kill   (manual_kill),
        .clear_fault   (clear_fault),
        .kill          (kill),
        .threat_code   (threat_code)
    );

    int errors;

    task automatic tick(int n = 1);
        repeat (n) @(posedge clk);
    endtask

    task automatic expect_state(input logic k, input logic [3:0] t, input string tag);
        if (kill !== k || threat_code !== t) begin
            $error("%s: kill=%0b threat=0x%0h expect kill=%0b threat=0x%0h",
                   tag, kill, threat_code, k, t);
            errors++;
        end
    endtask

    initial begin
        errors = 0;
        tick(4);
        rst = 1'b0;
        tick(2);
        expect_state(1'b0, `THREAT_NO_FAULT, "reset");

        // CRC-style threat pulse
        threat_code_in = `THREAT_CRC_TOKEN_FAULT;
        threat_pulse   = 1'b1;
        tick(1);
        threat_pulse   = 1'b0;
        tick(1);
        expect_state(1'b1, `THREAT_CRC_TOKEN_FAULT, "crc pulse");

        // Sticky: further pulse with different code ignored
        threat_code_in = `THREAT_UNAUTHORIZED_HID;
        threat_pulse   = 1'b1;
        tick(1);
        threat_pulse   = 1'b0;
        tick(2);
        expect_state(1'b1, `THREAT_CRC_TOKEN_FAULT, "sticky ignore");

        // Clear
        clear_fault = 1'b1;
        tick(1);
        clear_fault = 1'b0;
        tick(1);
        expect_state(1'b0, `THREAT_NO_FAULT, "clear");

        // Manual kill
        manual_kill = 1'b1;
        tick(2);
        expect_state(1'b1, `THREAT_MANUAL_HOST_KILL, "manual");

        // Drop manual without clear → sticky 0x7
        manual_kill = 1'b0;
        tick(4);
        expect_state(1'b1, `THREAT_MANUAL_HOST_KILL, "manual sticky");

        // Manual while already killed from CRC: after clear, manual again
        clear_fault = 1'b1;
        tick(1);
        clear_fault = 1'b0;
        tick(1);
        threat_code_in = `THREAT_CRC_TOKEN_FAULT;
        threat_pulse   = 1'b1;
        tick(1);
        threat_pulse   = 1'b0;
        tick(1);
        manual_kill = 1'b1;
        tick(2);
        expect_state(1'b1, `THREAT_MANUAL_HOST_KILL, "manual overwrite");
        manual_kill = 1'b0;
        clear_fault = 1'b1;
        tick(1);
        clear_fault = 1'b0;
        tick(1);

        // HID code path
        threat_code_in = `THREAT_UNAUTHORIZED_HID;
        threat_pulse   = 1'b1;
        tick(1);
        threat_pulse   = 1'b0;
        tick(1);
        expect_state(1'b1, `THREAT_UNAUTHORIZED_HID, "hid");
        clear_fault = 1'b1;
        tick(1);
        clear_fault = 1'b0;
        tick(1);

        // Clear wins over simultaneous manual (same cycle)
        manual_kill = 1'b1;
        clear_fault = 1'b1;
        tick(1);
        manual_kill = 1'b0;
        clear_fault = 1'b0;
        tick(1);
        expect_state(1'b0, `THREAT_NO_FAULT, "clear vs manual");

        if (errors == 0) $display("tb_cov_isolation: PASS");
        else             $display("tb_cov_isolation: FAIL (%0d errors)", errors);
        $finish;
    end
endmodule
