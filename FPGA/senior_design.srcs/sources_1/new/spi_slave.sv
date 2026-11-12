`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: spi_slave
// Purpose: SPI Mode 0 slave, 16-bit frames (Docs/fabric_slop.md §5).
//          Write: {1, addr[6:0], data[7:0]}
//          Read:  {0, addr[6:0], dummy} → MISO returns data on clocks 8..15
//
// Mode 0 (CPOL=0, CPHA=0): master samples MOSI/MISO on rising SCK.
// Capture MOSI on rising; change MISO on falling so data is stable before
// the next rising edge (STM32 hardware SPI). Updating MISO on rising caused
// a 1-bit right shift on the wire (e.g. 0xC1 → 0x60).
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
    wire sclk_fall = (sclk_sync[1:0] == 2'b10);
    wire cs_active = ~cs_sync[1];
    wire mosi_s    = mosi_sync[1];

    logic [4:0]  bit_cnt; // bits captured so far (increments on rise)
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
                is_write <= 1'b0;
            end else begin
                // Rising SCK: sample MOSI (Mode 0), advance bit count, writes, latch read byte
                if (sclk_rise) begin
                    shreg   <= {shreg[14:0], mosi_s};
                    bit_cnt <= bit_cnt + 5'd1;

                    if (bit_cnt == 5'd7) begin
                        // 8th bit completing — R/W is already in shreg[6] (frame bit15)
                        is_write <= shreg[6];
                        if (!shreg[6]) begin
                            rd_byte <= reg_rdata;
                            rd_idx  <= 3'd7;
                        end
                    end

                    if (bit_cnt == 5'd15) begin
                        if (shreg[14]) begin
                            reg_we    <= 1'b1;
                            reg_waddr <= shreg[13:7];
                            reg_wdata <= {shreg[6:0], mosi_s};
                        end
                    end
                end

                // Falling SCK: present next MISO bit for the upcoming rising sample
                // After 8th rise bit_cnt==8 → drive MSB before 9th rise; … through bit_cnt==15 → LSB
                if (sclk_fall) begin
                    if (!is_write && bit_cnt >= 5'd8 && bit_cnt <= 5'd15) begin
                        miso   <= rd_byte[rd_idx];
                        rd_idx <= rd_idx - 3'd1;
                    end else begin
                        miso <= 1'b0;
                    end
                end
            end
        end
    end

`ifndef VERILATOR
    // synthesis translate_off
    spi_slave_sva u_spi_sva (
        .clk      (clk),
        .rst      (rst),
        .cs_active(cs_active),
        .reg_we   (reg_we)
    );
    // synthesis translate_on
`endif

endmodule
