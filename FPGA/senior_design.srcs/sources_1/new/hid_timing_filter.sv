`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: hid_timing_filter
// Purpose: Detect BadUSB-style keystroke injection after operator approve.
//          Key-down = new nonzero boot-keyboard key code in an IN report
//          (endp != 0 DATA packet). Emits KEYSTROKE_BURST / COOLDOWN_BURST.
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module hid_timing_filter #(
    parameter int MIN_INTERVAL_CYCLES = `HID_MIN_INTERVAL_CYCLES,
    parameter int QUARANTINE_CYCLES   = `HID_QUARANTINE_CYCLES
) (
    input  logic       clk,
    input  logic       rst,

    input  logic       enable,            // approved && HID-allowed policy
    input  logic       config_walk_done,  // starts post-enum cooldown window
    input  logic       hid_present,

    input  logic       pkt_start,
    input  logic       pkt_end,
    input  logic [3:0] pid,
    input  logic [3:0] endp,
    input  logic       data_valid,
    input  logic [7:0] data,
    input  logic       crc_ok,

    output logic       keystroke_burst_pulse,
    output logic       cooldown_burst_pulse
);

    localparam [3:0] PID_DATA0 = 4'b0011;
    localparam [3:0] PID_DATA1 = 4'b1011;
    localparam [2:0] BURST_NEED = 3'd3;  // pulse when streak reaches >3 fast keys

    wire is_data = (pid == PID_DATA0) || (pid == PID_DATA1);

    logic        in_report;
    logic [3:0]  byte_idx;
    logic [7:0]  report [0:7];
    logic [7:0]  prev_keys [0:5];
    logic        have_prev;
    logic [31:0] since_last_key;
    logic [31:0] since_config;
    logic        cooldown_active;
    logic [2:0]  fast_streak;
    logic        saw_config;

    // Combinational key-down detect from assembled 8-byte boot report
    logic report_key_down;
    always_comb begin
        report_key_down = 1'b0;
        for (int kc = 0; kc < 6; kc++) begin
            if (report[kc + 2] != 8'd0) begin
                if (!have_prev)
                    report_key_down = 1'b1;
                else if (report[kc + 2] != prev_keys[kc])
                    report_key_down = 1'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            in_report              <= 1'b0;
            byte_idx               <= 4'd0;
            have_prev              <= 1'b0;
            since_last_key         <= 32'hFFFF_FFFF;
            since_config           <= 32'd0;
            cooldown_active        <= 1'b0;
            saw_config             <= 1'b0;
            fast_streak            <= 3'd0;
            keystroke_burst_pulse  <= 1'b0;
            cooldown_burst_pulse   <= 1'b0;
            for (int kf = 0; kf < 6; kf++)
                prev_keys[kf] <= 8'd0;
            for (int kr = 0; kr < 8; kr++)
                report[kr] <= 8'd0;
        end else begin
            keystroke_burst_pulse <= 1'b0;
            cooldown_burst_pulse  <= 1'b0;

            // Cooldown window after config walk completes. Drop saw_config when
            // the walk flag clears (bus reset / new GET_CONFIG) so a re-enum
            // re-arms the 2s quarantine.
            if (!config_walk_done) begin
                saw_config <= 1'b0;
            end else if (!saw_config) begin
                saw_config      <= 1'b1;
                since_config    <= 32'd0;
                cooldown_active <= 1'b1;
            end else if (cooldown_active) begin
                if (since_config >= QUARANTINE_CYCLES)
                    cooldown_active <= 1'b0;
                else
                    since_config <= since_config + 32'd1;
            end

            if (since_last_key != 32'hFFFF_FFFF &&
                since_last_key < 32'hFFFF_FFFE)
                since_last_key <= since_last_key + 32'd1;

            if (!enable || !hid_present) begin
                in_report   <= 1'b0;
                byte_idx    <= 4'd0;
                fast_streak <= 3'd0;
            end else begin
                // usb_packet_frontend / usb_fs_rx update pid+endp at pkt_end, so
                // at pkt_start those ports still hold the *previous* packet.
                // After an IN token, endp is already the interrupt EP; do not
                // require is_data here (PID is still the token until pkt_end).
                if (pkt_start && (endp != 4'h0)) begin
                    in_report <= 1'b1;
                    byte_idx  <= 4'd0;
                end

                if (in_report && data_valid && byte_idx < 4'd8) begin
                    report[byte_idx[2:0]] <= data;
                    byte_idx              <= byte_idx + 4'd1;
                end

                if (in_report && pkt_end) begin
                    in_report <= 1'b0;
                    // Confirm DATA PID now that pkt_end has updated `pid`.
                    if (is_data && crc_ok && byte_idx >= 4'd8 && report_key_down) begin
                        if (cooldown_active)
                            cooldown_burst_pulse <= 1'b1;

                        if (since_last_key < MIN_INTERVAL_CYCLES) begin
                            if (fast_streak >= BURST_NEED)
                                keystroke_burst_pulse <= 1'b1;
                            else
                                fast_streak <= fast_streak + 3'd1;
                        end else begin
                            fast_streak <= 3'd1;
                        end
                        since_last_key <= 32'd0;

                        for (int kf = 0; kf < 6; kf++)
                            prev_keys[kf] <= report[kf + 2];
                        have_prev <= 1'b1;
                    end else if (is_data && crc_ok && byte_idx >= 4'd8) begin
                        for (int kf = 0; kf < 6; kf++)
                            prev_keys[kf] <= report[kf + 2];
                        have_prev <= 1'b1;
                    end
                end
            end
        end
    end

endmodule
