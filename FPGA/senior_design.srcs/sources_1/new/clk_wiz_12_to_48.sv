`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: clk_wiz_12_to_48
// Purpose: Cmod S7 12 MHz oscillator → 48 MHz sniffer clock (MMCME2_BASE).
//////////////////////////////////////////////////////////////////////////////////

module clk_wiz_12_to_48 (
    input  logic clk_12m,
    input  logic rst,
    output logic clk_48m,
    output logic locked
);

    logic clk_fb;
    logic clk_48_mmcm;

    // 12 MHz * 64.0 / 16.0 = 48 MHz
    MMCME2_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKFBOUT_MULT_F    (64.0),
        .CLKFBOUT_PHASE     (0.0),
        .CLKIN1_PERIOD      (83.333),
        .CLKOUT0_DIVIDE_F   (16.0),
        .CLKOUT0_DUTY_CYCLE (0.5),
        .CLKOUT0_PHASE      (0.0),
        .DIVCLK_DIVIDE      (1),
        .REF_JITTER1        (0.010),
        .STARTUP_WAIT       ("FALSE")
    ) u_mmcm (
        .CLKOUT0  (clk_48_mmcm),
        .CLKOUT0B (),
        .CLKOUT1  (),
        .CLKOUT1B (),
        .CLKOUT2  (),
        .CLKOUT2B (),
        .CLKOUT3  (),
        .CLKOUT3B (),
        .CLKOUT4  (),
        .CLKOUT5  (),
        .CLKOUT6  (),
        .CLKFBOUT (clk_fb),
        .CLKFBOUTB(),
        .LOCKED   (locked),
        .CLKIN1   (clk_12m),
        .PWRDWN   (1'b0),
        .RST      (rst),
        .CLKFBIN  (clk_fb)
    );

    BUFG u_bufg_48 (
        .I(clk_48_mmcm),
        .O(clk_48m)
    );

endmodule
