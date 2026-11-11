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

        // ----------------------------------------------------------
        // Branch/toggle: sweep remaining threat codes + edge thrash
        // ----------------------------------------------------------
        begin
            automatic logic [3:0] codes [0:5];
            int ci;
            codes[0] = `THREAT_UNAUTHORIZED_HID;
            codes[1] = `THREAT_KEYSTROKE_BURST;
            codes[2] = `THREAT_COOLDOWN_BURST;
            codes[3] = `THREAT_DESCRIPTOR_OVERFLOW;
            codes[4] = `THREAT_CRC_TOKEN_FAULT;
            codes[5] = `THREAT_BIT_STUFF_ERROR;
            for (ci = 0; ci < 6; ci++) begin
                threat_code_in = codes[ci];
                threat_pulse   = 1'b1;
                tick(1);
                threat_pulse   = 1'b0;
                tick(1);
                expect_state(1'b1, codes[ci], "threat sweep");
                clear_fault = 1'b1;
                tick(1);
                clear_fault = 1'b0;
                tick(1);
                expect_state(1'b0, `THREAT_NO_FAULT, "sweep clear");
            end
        end

        // Pulse with NO_FAULT while idle (still latches kill + code 0)
        threat_code_in = `THREAT_NO_FAULT;
        threat_pulse   = 1'b1;
        tick(1);
        threat_pulse   = 1'b0;
        tick(1);
        expect_state(1'b1, `THREAT_NO_FAULT, "pulse no_fault");
        clear_fault = 1'b1;
        tick(1);
        clear_fault = 1'b0;
        tick(1);

        // Idle clear / manual edges (toggle thrash; clear while already clear)
        repeat (3) begin
            clear_fault = 1'b1;
            tick(1);
            clear_fault = 1'b0;
            tick(1);
        end
        repeat (2) begin
            manual_kill = 1'b1;
            tick(1);
            manual_kill = 1'b0;
            tick(1);
            clear_fault = 1'b1;
            tick(1);
            clear_fault = 1'b0;
            tick(1);
        end

        // Pulse ignored while already killed (branch !kill false)
        threat_code_in = `THREAT_CRC_TOKEN_FAULT;
        threat_pulse   = 1'b1;
        tick(1);
        threat_pulse   = 1'b0;
        tick(1);
        threat_code_in = `THREAT_BIT_STUFF_ERROR;
        threat_pulse   = 1'b1;
        tick(2);
        threat_pulse   = 1'b0;
        tick(1);
        expect_state(1'b1, `THREAT_CRC_TOKEN_FAULT, "sticky after sweep");
        clear_fault = 1'b1;
        tick(1);
        clear_fault = 1'b0;
        tick(1);

        if (errors == 0) $display("tb_cov_isolation: PASS");
        else             $display("tb_cov_isolation: FAIL (%0d errors)", errors);
        $finish;
    end
endmodule
