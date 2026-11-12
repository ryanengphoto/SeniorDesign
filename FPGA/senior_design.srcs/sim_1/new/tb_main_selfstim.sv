`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: tb_main_selfstim
// Purpose: Board-top smoke — main_wrapper auto self-stim → LED kill → SPI
//          telemetry → btn_clear releases kill.
//          Uses SIM_CLK_BYPASS + short BOOT_STIM_CYCLES (no MMCM wait).
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module tb_main_selfstim;

    // With SIM_CLK_BYPASS, clk_12m is the fabric clock — run at 48 MHz.
    logic clk_12m = 1'b0;
    always #10.4167 clk_12m = ~clk_12m;

    logic btn_rst   = 1'b1;
    logic btn_clear = 1'b0;
    logic [3:0] led;
    logic       led_r, led_g, led_b;

    logic spi_sck = 1'b0;
    logic spi_mosi = 1'b0;
    logic spi_miso;
    logic spi_cs_n = 1'b1;

    // Idle J on taps (selfstim overrides port0 when OE)
    logic p0_dp_tap = 1'b1, p0_dm_tap = 1'b0;
    logic p1_dp_tap = 1'b1, p1_dm_tap = 1'b0;
    logic p2_dp_tap = 1'b1, p2_dm_tap = 1'b0;
    logic p3_dp_tap = 1'b1, p3_dm_tap = 1'b0;
    logic p0_mux_en_n, p0_efuse_en;
    logic p1_mux_en_n, p1_efuse_en;
    logic p2_mux_en_n, p2_efuse_en;
    logic p3_mux_en_n, p3_efuse_en;

    main_wrapper #(
        .SIM_CLK_BYPASS  (1'b1),
        .BOOT_STIM_CYCLES(2000)
    ) dut (
        .clk_12m    (clk_12m),
        .btn_rst    (btn_rst),
        .btn_clear  (btn_clear),
        .led        (led),
        .led_r      (led_r),
        .led_g      (led_g),
        .led_b      (led_b),
        .spi_sck    (spi_sck),
        .spi_mosi   (spi_mosi),
        .spi_miso   (spi_miso),
        .spi_cs_n   (spi_cs_n),
        .p0_dp_tap  (p0_dp_tap),
        .p0_dm_tap  (p0_dm_tap),
        .p0_mux_en_n(p0_mux_en_n),
        .p0_efuse_en(p0_efuse_en),
        .p1_dp_tap  (p1_dp_tap),
        .p1_dm_tap  (p1_dm_tap),
        .p1_mux_en_n(p1_mux_en_n),
        .p1_efuse_en(p1_efuse_en),
        .p2_dp_tap  (p2_dp_tap),
        .p2_dm_tap  (p2_dm_tap),
        .p2_mux_en_n(p2_mux_en_n),
        .p2_efuse_en(p2_efuse_en),
        .p3_dp_tap  (p3_dp_tap),
        .p3_dm_tap  (p3_dm_tap),
        .p3_mux_en_n(p3_mux_en_n),
        .p3_efuse_en(p3_efuse_en)
    );

    // SPI BFM paced on fabric clock (hierarchical)
    task automatic spi_transfer(input logic [15:0] mosibits, output logic [7:0] misobyte);
        int i;
        logic [7:0] rx;
        rx = 8'h00;
        spi_cs_n = 1'b0;
        spi_sck  = 1'b0;
        spi_mosi = 1'b0;
        repeat (4) @(posedge dut.clk_48m);
        // Mode 0: sample MISO before rising SCK (stable from prior falling update).
        for (i = 15; i >= 0; i = i - 1) begin
            spi_mosi = mosibits[i];
            repeat (2) @(posedge dut.clk_48m);
            if (i <= 7)
                rx = {rx[6:0], spi_miso};
            spi_sck = 1'b1;
            repeat (3) @(posedge dut.clk_48m);
            spi_sck = 1'b0;
            repeat (4) @(posedge dut.clk_48m); // allow sclk_fall + MISO shift
        end
        spi_cs_n = 1'b1;
        spi_mosi = 1'b0;
        repeat (8) @(posedge dut.clk_48m);
        misobyte = rx;
    endtask

    task automatic spi_write(input logic [6:0] addr, input logic [7:0] data);
        logic [7:0] dummy;
        spi_transfer({1'b1, addr, data}, dummy);
    endtask

    task automatic spi_read(input logic [6:0] addr, output logic [7:0] data);
        spi_transfer({1'b0, addr, 8'h00}, data);
    endtask

    int errors;
    logic [7:0] rd;
    int timeout;

    initial begin
        errors = 0;
        $display("tb_main_selfstim: main_wrapper auto HID stim → LED/SPI");

        repeat (64) @(posedge clk_12m);
        btn_rst = 1'b0;
        repeat (8) @(posedge dut.clk_48m);

        // Wait for port0 kill LED (selfstim finishes HID config)
        timeout = 0;
        while (led[0] !== 1'b1 && timeout < 500000) begin
            @(posedge clk_12m);
            timeout++;
        end
        if (led[0] !== 1'b1) begin
            $error("timeout waiting for led[0] kill");
            errors++;
        end else
            $display("led[0] kill OK (timeout_cnt=%0d)", timeout);

        if (led_r !== 1'b0) begin
            $error("led_r expected active (0), got %0b", led_r);
            errors++;
        end else
            $display("led_r (any-kill) OK");

        if (p0_mux_en_n !== 1'b1 || p0_efuse_en !== 1'b0) begin
            $error("kill outs mux_en_n=%0b efuse_en=%0b", p0_mux_en_n, p0_efuse_en);
            errors++;
        end else
            $display("p0 kill pins OK");

        // Other ports idle
        if (led[3:1] !== 3'b000) begin
            $error("unexpected kills on other LEDs %b", led);
            errors++;
        end

        // SPI telemetry through board top
        spi_read(`ADDR_P0_STATUS, rd);
        if (rd !== 8'hC1) begin
            $error("P0_STATUS=%02h expect C1", rd); errors++;
        end else
            $display("SPI P0_STATUS=%02h OK", rd);

        spi_read(`ADDR_P0_VID_HIGH, rd);
        if (rd !== 8'h12) begin
            $error("VIDH=%02h", rd); errors++;
        end else
            $display("SPI VIDH=%02h OK", rd);

        spi_read(`ADDR_P0_PID_LOW, rd);
        if (rd !== 8'h78) begin
            $error("PIDL=%02h", rd); errors++;
        end else
            $display("SPI PIDL=%02h OK", rd);

        spi_read(`ADDR_P0_INT_CLASS, rd);
        if (rd !== 8'h03) begin
            $error("INTCLASS=%02h", rd); errors++;
        end else
            $display("SPI INTCLASS=%02h OK", rd);

        // btn_clear releases kill
        btn_clear = 1'b1;
        repeat (32) @(posedge dut.clk_48m);
        btn_clear = 1'b0;
        repeat (16) @(posedge dut.clk_48m);

        if (led[0] !== 1'b0) begin
            $error("led[0] still set after btn_clear");
            errors++;
        end else
            $display("btn_clear cleared kill OK");

        spi_read(`ADDR_P0_STATUS, rd);
        if (rd[7] || rd[3:0] !== `THREAT_NO_FAULT) begin
            $error("P0_STATUS after clear=%02h", rd); errors++;
        end else
            $display("SPI P0_STATUS after clear=%02h OK", rd);

        // Telemetry retained
        spi_read(`ADDR_P0_VID_LOW, rd);
        if (rd !== 8'h34) begin
            $error("VIDL retained=%02h", rd); errors++;
        end else
            $display("SPI VIDL retained OK");

        if (errors == 0) $display("tb_main_selfstim: PASS");
        else             $display("tb_main_selfstim: FAIL (%0d errors)", errors);
        $finish;
    end

    initial begin
        #50ms;
        $error("global timeout");
        $finish;
    end

endmodule
