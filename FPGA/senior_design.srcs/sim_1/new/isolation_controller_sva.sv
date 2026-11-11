`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: isolation_controller_sva
// Purpose: Sticky / manual / clear / threat-latch monitors for isolation_controller.
//
// Note: Vivado XSim 2018.2 ignores concurrent `assert property` / `cover property`
// (XSIM 43-4127). This checker uses clocked procedural checks with 1-cycle
// sample flops so the same intent is enforced on the lab toolchain.
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module isolation_controller_sva (
    input logic       clk,
    input logic       rst,
    input logic       threat_pulse,
    input logic [3:0] threat_code_in,
    input logic       manual_kill,
    input logic       clear_fault,
    input logic       kill,
    input logic [3:0] threat_code
);

    // Previous-cycle samples (antecedent side of |=> ).
    logic       kill_d, clear_d, manual_d, pulse_d;
    logic [3:0] threat_in_d;
    logic       sample_valid; // high after first post-reset cycle

    // Lightweight cover tallies (printed once if non-zero would need end-of-test;
    // incremented here for waveform / future $display hooks).
    int unsigned cov_manual;
    int unsigned cov_clear;
    int unsigned cov_sticky;

    always_ff @(posedge clk) begin
        if (rst) begin
            kill_d       <= 1'b0;
            clear_d      <= 1'b0;
            manual_d     <= 1'b0;
            pulse_d      <= 1'b0;
            threat_in_d  <= 4'h0;
            sample_valid <= 1'b0;
            cov_manual   <= 0;
            cov_clear    <= 0;
            cov_sticky   <= 0;
        end else begin
            if (sample_valid) begin
                // Sticky: kill held without clear must remain.
                if (kill_d && !clear_d && !kill)
                    $error("isolation_controller SVA: kill dropped without clear_fault");

                // Manual isolate → threat 0x7 (clear wins over manual).
                if (manual_d && !clear_d &&
                    !(kill && (threat_code == `THREAT_MANUAL_HOST_KILL)))
                    $error("isolation_controller SVA: manual_kill did not force threat 0x7");

                // Clear releases kill + threat.
                if (clear_d && (kill || (threat_code != `THREAT_NO_FAULT)))
                    $error("isolation_controller SVA: clear_fault did not release kill");

                // First threat pulse while idle latches offered code.
                if (pulse_d && !kill_d && !manual_d && !clear_d &&
                    !(kill && (threat_code == threat_in_d)))
                    $error("isolation_controller SVA: threat_pulse did not latch threat_code_in");

                // Cover tallies (functional stand-in for cover property).
                if (manual_d && !clear_d && kill &&
                    (threat_code == `THREAT_MANUAL_HOST_KILL))
                    cov_manual <= cov_manual + 1;
                if (clear_d && !kill)
                    cov_clear <= cov_clear + 1;
                if (kill_d && !clear_d && !manual_d && kill)
                    cov_sticky <= cov_sticky + 1;
            end

            kill_d       <= kill;
            clear_d      <= clear_fault;
            manual_d     <= manual_kill;
            pulse_d      <= threat_pulse;
            threat_in_d  <= threat_code_in;
            sample_valid <= 1'b1;
        end
    end

endmodule
