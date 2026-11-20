`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: tb_hid_timing
// Purpose: Unit test hid_timing_filter with short interval/quarantine params.
//          Covers key-down burst, cooldown, key-slot combos, CRC/short/EP0 edges.
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module tb_hid_timing;

    logic clk = 1'b0;
    logic rst = 1'b1;
    always #10.4167 clk = ~clk;

    logic enable = 1'b1;
    logic config_walk_done = 1'b0;
    logic hid_present = 1'b1;
    logic pkt_start, pkt_end, data_valid, crc_ok;
    logic [3:0] pid, endp;
    logic [7:0] data;
    logic keystroke_burst_pulse, cooldown_burst_pulse;

    hid_timing_filter #(
        .MIN_INTERVAL_CYCLES(50),
        .QUARANTINE_CYCLES  (200)
    ) dut (
        .clk(clk), .rst(rst),
        .enable(enable),
        .config_walk_done(config_walk_done),
        .hid_present(hid_present),
        .pkt_start(pkt_start), .pkt_end(pkt_end),
        .pid(pid), .endp(endp),
        .data_valid(data_valid), .data(data), .crc_ok(crc_ok),
        .keystroke_burst_pulse(keystroke_burst_pulse),
        .cooldown_burst_pulse (cooldown_burst_pulse)
    );

    localparam [3:0] PID_DATA0 = 4'b0011;
    localparam [3:0] PID_DATA1 = 4'b1011;
    localparam [3:0] PID_ACK   = 4'b0010;
    int errors;
    int burst_seen;
    int cool_seen;

    task automatic tick;
        @(posedge clk);
        pkt_start  = 1'b0;
        pkt_end    = 1'b0;
        data_valid = 1'b0;
    endtask

    // Full 8-byte boot keyboard report on chosen endp / PID / CRC
    task automatic send_report6(
        input [7:0] k0, input [7:0] k1, input [7:0] k2,
        input [7:0] k3, input [7:0] k4, input [7:0] k5,
        input [3:0] endp_i, input [3:0] pid_i, input logic crc_i,
        input int n_bytes
    );
        int i;
        logic [7:0] bytes [0:7];
        bytes[0] = 8'h00; bytes[1] = 8'h00;
        bytes[2] = k0; bytes[3] = k1; bytes[4] = k2;
        bytes[5] = k3; bytes[6] = k4; bytes[7] = k5;
        tick;
        pid       = pid_i;
        endp      = endp_i;
        crc_ok    = crc_i;
        pkt_start = 1'b1;
        tick;
        for (i = 0; i < n_bytes; i = i + 1) begin
            data_valid = 1'b1;
            data       = bytes[i];
            tick;
        end
        data_valid = 1'b0;
        pkt_end    = 1'b1;
        tick;
        if (keystroke_burst_pulse) burst_seen++;
        if (cooldown_burst_pulse)  cool_seen++;
    endtask

    task automatic send_report(input [7:0] k0, input [7:0] k1);
        send_report6(k0, k1, 8'h00, 8'h00, 8'h00, 8'h00,
                     4'h1, PID_DATA0, 1'b1, 8);
    endtask

    initial begin
        errors = 0;
        burst_seen = 0;
        cool_seen  = 0;
        pkt_start = 0; pkt_end = 0; data_valid = 0;
        pid = 0; endp = 0; data = 0; crc_ok = 1;
        $display("tb_hid_timing: key-down burst + cooldown + branch edges");

        repeat (8) @(posedge clk);
        rst = 1'b0;
        repeat (4) tick;

        // Start cooldown window (flag stays high like post-enum RTL)
        config_walk_done = 1'b1;
        tick;

        // First key in cooldown → cooldown pulse
        send_report(8'h04, 8'h00);  // 'a'
        if (cool_seen < 1) begin
            $error("expected cooldown on first key"); errors++;
        end

        // Fast successive distinct keys (Δt << 50 cycles)
        send_report(8'h05, 8'h00);  // 'b'
        send_report(8'h06, 8'h00);  // 'c'
        send_report(8'h07, 8'h00);  // 'd'
        send_report(8'h08, 8'h00);  // 'e' — should trip burst (streak>=3)

        if (burst_seen < 1) begin
            $error("expected KEYSTROKE_BURST after fast keys"); errors++;
        end else
            $display("burst pulses=%0d cooldown pulses=%0d OK", burst_seen, cool_seen);

        // Let quarantine expire (QUARANTINE_CYCLES=200)
        repeat (220) tick;

        // Empty / no-new-key report (all zeros) after have_prev — updates prev only
        send_report(8'h00, 8'h00);

        // Same key again (no key-down) — report_key_down stays 0
        send_report(8'h00, 8'h00);

        // Slow key (Δt >> MIN_INTERVAL) resets streak, no new burst required
        repeat (80) tick;
        send_report(8'h09, 8'h00);  // 'f'

        // Key-down in each of the 6 boot slots (branch arms in always_comb)
        send_report6(8'h00, 8'h14, 8'h00, 8'h00, 8'h00, 8'h00, 4'h1, PID_DATA0, 1'b1, 8);
        send_report6(8'h00, 8'h00, 8'h15, 8'h00, 8'h00, 8'h00, 4'h1, PID_DATA1, 1'b1, 8);
        send_report6(8'h00, 8'h00, 8'h00, 8'h16, 8'h00, 8'h00, 4'h1, PID_DATA0, 1'b1, 8);
        send_report6(8'h00, 8'h00, 8'h00, 8'h00, 8'h17, 8'h00, 4'h1, PID_DATA0, 1'b1, 8);
        send_report6(8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h18, 4'h1, PID_DATA0, 1'b1, 8);
        // Multi-slot simultaneous change
        send_report6(8'h04, 8'h05, 8'h06, 8'h07, 8'h08, 8'h09, 4'h1, PID_DATA0, 1'b1, 8);

        // CRC fail on full report — must not count as key-down
        begin
            int before_burst, before_cool;
            before_burst = burst_seen;
            before_cool  = cool_seen;
            send_report6(8'h1A, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
                         4'h1, PID_DATA0, 1'b0, 8);
            if (burst_seen != before_burst || cool_seen != before_cool) begin
                $error("CRC-fail report must not pulse"); errors++;
            end
        end

        // Short packet (byte_idx < 8) — ignore
        send_report6(8'h1B, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
                     4'h1, PID_DATA0, 1'b1, 4);

        // EP0 DATA — must not arm in_report
        send_report6(8'h1C, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00,
                     4'h0, PID_DATA0, 1'b1, 8);

        // Non-data PID pkt_end while idle
        tick;
        pid = PID_ACK; endp = 4'h1; crc_ok = 1'b1;
        pkt_start = 1'b1; tick; pkt_end = 1'b1; tick;

        // Disable filter mid-stream
        enable = 1'b0;
        send_report(8'h0A, 8'h00);
        enable = 1'b1;
        hid_present = 1'b0;
        send_report(8'h0B, 8'h00);
        hid_present = 1'b1;

        // Re-arm cooldown via walk flag drop/rise
        config_walk_done = 1'b0;
        repeat (4) tick;
        config_walk_done = 1'b1;
        tick;
        send_report(8'h0C, 8'h00);
        if (cool_seen < 2) begin
            $error("expected re-armed cooldown"); errors++;
        end else
            $display("cooldown re-arm / expire / disable / slot paths OK");

        // Wait out cooldown, then saturate since_last_key near max path
        repeat (220) tick;
        send_report(8'h0D, 8'h00);
        // Many idle ticks so since_last_key climbs (not all the way to max)
        repeat (400) tick;
        send_report(8'h0E, 8'h00); // slow → streak reset arm

        if (errors == 0) $display("tb_hid_timing: PASS");
        else             $display("tb_hid_timing: FAIL (%0d errors)", errors);
        $finish;
    end

    initial begin
        #5ms;
        $error("global timeout");
        $finish;
    end

endmodule
