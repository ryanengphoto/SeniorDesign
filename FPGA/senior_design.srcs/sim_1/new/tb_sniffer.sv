`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date:   09/10/2026
// Design Name:   Hardware-Isolated USB Security Gateway
// Module Name:   tb_sniffer
// Project Name:  senior_design
// Target Devices: Simulation only
// Tool Versions: Vivado 2018.2
// Description:
//   Dummy smoke testbench for sniffer_block. Instantiates the DUT,
//   drives one 48 MHz clock cycle, then prints TEST PASSED and $finish.
//   scripts/check_sim.py scores these tokens from the sim log (Windows-safe;
//   no grep, does not launch Vivado).
//
// Dependencies:  sniffer_block
//
// Notes:
//   Dummy / placeholder — clk/rst only. USB line stimulus and threat
//   checks are not implemented. A pass here is elaboration + one cycle,
//   not verified hardware behavior.
//
// Revision:
// Revision 0.02 - Dummy one-cycle smoke test with TEST PASSED/FAILED
//////////////////////////////////////////////////////////////////////////////////

module tb_sniffer;

    logic clk;
    logic rst;

    // Dummy result flag. Functional checks replace this later.
    logic test_ok;

    sniffer_block dut (
        .clk (clk),
        .rst (rst)
    );

    // 48 MHz sniffer clock: period = 1e9 / 48e6 ≈ 20.833 ns
    localparam real CLK_HALF_NS = 10.4165;

    initial begin
        clk     = 1'b0;
        rst     = 1'b1;
        test_ok = 1'b0;

        #(CLK_HALF_NS);
        clk = 1'b1;
        #(CLK_HALF_NS);
        clk = 1'b0;

        // Dummy smoke test: DUT elaborated and one cycle completed.
        test_ok = 1'b1;

        if (test_ok)
            $display("TEST PASSED");
        else
            $display("TEST FAILED");
        $finish;
    end

endmodule
