`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: spi_slave_sva
// Purpose: Mode-0 frame hygiene — reg_we only while CS active, single-cycle.
//////////////////////////////////////////////////////////////////////////////////

module spi_slave_sva (
    input logic clk,
    input logic rst,
    input logic cs_active,
    input logic reg_we
);

    logic sample_valid;
    logic reg_we_d;

    always_ff @(posedge clk) begin
        if (rst) begin
            sample_valid <= 1'b0;
            reg_we_d     <= 1'b0;
        end else begin
            if (sample_valid) begin
                if (reg_we && !cs_active)
                    $error("spi_slave SVA: reg_we while CS inactive");
                if (reg_we && reg_we_d)
                    $error("spi_slave SVA: reg_we held more than one cycle");
            end
            sample_valid <= 1'b1;
            reg_we_d     <= reg_we;
        end
    end

endmodule
