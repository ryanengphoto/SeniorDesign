`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: spi_slave
// Purpose: SPI Mode 0 slave, 16-bit frames (Docs/fabric_slop.md §5).
//          Write: {1, addr[6:0], data[7:0]}
//          Read:  {0, addr[6:0], dummy} → MISO returns data on clocks 8..15
//////////////////////////////////////////////////////////////////////////////////

module spi_slave (
    input  logic       clk,
    input  logic       rst,

    input  logic       sclk,
    input  logic       cs_n,
    input  logic       mosi,
    output logic       miso,

    output logic       reg_we,
    output logic [6:0] reg_waddr,
    output logic [7:0] reg_wdata,
    output logic [6:0] reg_raddr,
    input  logic [7:0] reg_rdata
);

    // --- sync SPI pins into clk ---
    logic [2:0] sclk_sync, cs_sync, mosi_sync;
    always_ff @(posedge clk) begin
        if (rst) begin
            sclk_sync <= 3'b000;
            cs_sync   <= 3'b111;
            mosi_sync <= 3'b000;
        end else begin
            sclk_sync <= {sclk_sync[1:0], sclk};
            cs_sync   <= {cs_sync[1:0], cs_n};
            mosi_sync <= {mosi_sync[1:0], mosi};
        end
    end

    wire sclk_rise = (sclk_sync[1:0] == 2'b01);
    wire cs_active = ~cs_sync[1];
    wire mosi_s    = mosi_sync[1];

    logic [4:0]  bit_cnt; // bits captured so far
    logic [15:0] shreg;
    logic        is_write;
    logic [7:0]  rd_byte;
    logic [2:0]  rd_idx;

    // Combinational address while capturing the 8th bit
    wire [6:0] addr_form = {shreg[5:0], mosi_s};
    assign reg_raddr = (cs_active && bit_cnt == 5'd7) ? addr_form :
                       (cs_active ? shreg[14:8] : 7'h00);

    always_ff @(posedge clk) begin
        if (rst) begin
            bit_cnt   <= 5'd0;
            shreg     <= 16'h0;
            is_write  <= 1'b0;
            rd_byte   <= 8'h0;
            rd_idx    <= 3'd7;
            miso      <= 1'b0;
            reg_we    <= 1'b0;
            reg_waddr <= 7'h0;
            reg_wdata <= 8'h0;
        end else begin
            reg_we <= 1'b0;

            if (!cs_active) begin
                bit_cnt <= 5'd0;
                shreg   <= 16'h0;
                miso    <= 1'b0;
                rd_idx  <= 3'd7;
            end else if (sclk_rise) begin
                shreg   <= {shreg[14:0], mosi_s};
                bit_cnt <= bit_cnt + 5'd1;

                if (bit_cnt == 5'd7) begin
                    is_write <= shreg[6];
                    if (!shreg[6]) begin
                        rd_byte <= reg_rdata;
                        rd_idx  <= 3'd7;
                    end
                    miso <= 1'b0;
                end else if (bit_cnt >= 5'd8 && bit_cnt <= 5'd15 && !is_write) begin
                    miso   <= rd_byte[rd_idx];
                    rd_idx <= rd_idx - 3'd1;
                end else begin
                    miso <= 1'b0;
                end

                if (bit_cnt == 5'd15) begin
                    if (shreg[14]) begin
                        reg_we    <= 1'b1;
                        reg_waddr <= shreg[13:7];
                        reg_wdata <= {shreg[6:0], mosi_s};
                        miso      <= 1'b0;
                    end
                    // reads: keep miso as final data LSB through this edge
                end
            end
        end
    end

endmodule
