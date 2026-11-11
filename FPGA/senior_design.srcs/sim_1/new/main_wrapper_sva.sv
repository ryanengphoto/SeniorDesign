`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: main_wrapper_sva
// Purpose: Board kill → mux/eFuse/LED polarity monitors.
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module main_wrapper_sva (
    input logic                  clk,
    input logic                  rst,
    input logic [`NUM_PORTS-1:0] kill,
    input logic                  p0_mux_en_n,
    input logic                  p1_mux_en_n,
    input logic                  p2_mux_en_n,
    input logic                  p3_mux_en_n,
    input logic                  p0_efuse_en,
    input logic                  p1_efuse_en,
    input logic                  p2_efuse_en,
    input logic                  p3_efuse_en,
    input logic [3:0]            led,
    input logic                  led_r
);

    logic sample_valid;

    always_ff @(posedge clk) begin
        if (rst) begin
            sample_valid <= 1'b0;
        end else begin
            if (sample_valid) begin
                if (p0_mux_en_n !== kill[0] || p1_mux_en_n !== kill[1] ||
                    p2_mux_en_n !== kill[2] || p3_mux_en_n !== kill[3])
                    $error("main_wrapper SVA: mux_en_n != kill");

                if (p0_efuse_en !== ~kill[0] || p1_efuse_en !== ~kill[1] ||
                    p2_efuse_en !== ~kill[2] || p3_efuse_en !== ~kill[3])
                    $error("main_wrapper SVA: efuse_en != ~kill");

                if (led !== kill)
                    $error("main_wrapper SVA: led != kill");

                if (led_r !== ~(|kill))
                    $error("main_wrapper SVA: led_r polarity");
            end
            sample_valid <= 1'b1;
        end
    end

endmodule
