`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name:   main_wrapper
// Description:
//   Cmod S7 board top: 12→48 MHz MMCM, sniffer_wrapper, register_file, SPI
//   slave. LEDs show per-port kill; btn_rst / btn_clear for demo control.
//   USB D+/D− taps and mux/efuse kills on PIO headers.
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module main_wrapper #(
    // Sim: skip MMCM (drive clk_12m at 48 MHz in the TB). Board: leave 0.
    parameter bit SIM_CLK_BYPASS    = 1'b0,
    // Cycles after lock before auto HID self-stim (~20 ms @ 48 MHz on board).
    parameter int BOOT_STIM_CYCLES  = 1_000_000
) (
    input  logic clk_12m,
    input  logic btn_rst,
    input  logic btn_clear,

    output logic [3:0] led,
    output logic       led_r,
    output logic       led_g,
    output logic       led_b,

    input  logic spi_sck,
    input  logic spi_mosi,
    output logic spi_miso,
    input  logic spi_cs_n,

    input  logic p0_dp_tap,
    input  logic p0_dm_tap,
    output logic p0_mux_en_n,
    output logic p0_efuse_en,

    input  logic p1_dp_tap,
    input  logic p1_dm_tap,
    output logic p1_mux_en_n,
    output logic p1_efuse_en,

    input  logic p2_dp_tap,
    input  logic p2_dm_tap,
    output logic p2_mux_en_n,
    output logic p2_efuse_en,

    input  logic p3_dp_tap,
    input  logic p3_dm_tap,
    output logic p3_mux_en_n,
    output logic p3_efuse_en
);

    logic clk_48m;
    logic mmcm_locked;
    logic rst_btn_sync0, rst_btn_sync1;
    logic clr_btn_sync0, clr_btn_sync1;
    logic rst;

    generate
        if (SIM_CLK_BYPASS) begin : g_sim_clk
            assign clk_48m     = clk_12m;
            assign mmcm_locked = 1'b1;
        end else begin : g_mmcm
            clk_wiz_12_to_48 u_clk (
                .clk_12m(clk_12m),
                .rst    (btn_rst),
                .clk_48m(clk_48m),
                .locked (mmcm_locked)
            );
        end
    endgenerate

    // Async buttons → 48 MHz domain (btn high when pressed)
    always_ff @(posedge clk_48m) begin
        rst_btn_sync0 <= btn_rst;
        rst_btn_sync1 <= rst_btn_sync0;
        clr_btn_sync0 <= btn_clear;
        clr_btn_sync1 <= clr_btn_sync0;
    end

    assign rst = rst_btn_sync1 || !mmcm_locked;

    logic [`NUM_PORTS-1:0] dp;
    logic [`NUM_PORTS-1:0] dm;
    logic [`NUM_PORTS-1:0] clear_fault;
    logic [`NUM_PORTS-1:0] manual_kill;
    logic [`NUM_PORTS-1:0] kill;
    logic [3:0]            threat_code [`NUM_PORTS-1:0];
    logic [7:0]            port_status [`NUM_PORTS-1:0];
    logic [15:0]           vid         [`NUM_PORTS-1:0];
    logic [15:0]           pid_dev     [`NUM_PORTS-1:0];
    logic [7:0]            dev_class   [`NUM_PORTS-1:0];
    logic [7:0]            intf_class  [`NUM_PORTS-1:0];
    logic                  device_desc_valid [`NUM_PORTS-1:0];
    logic                  intf_class_valid  [`NUM_PORTS-1:0];

    logic       pkt_start  [`NUM_PORTS-1:0];
    logic       pkt_end    [`NUM_PORTS-1:0];
    logic [3:0] pid        [`NUM_PORTS-1:0];
    logic [3:0] endp       [`NUM_PORTS-1:0];
    logic       data_valid [`NUM_PORTS-1:0];
    logic [7:0] data       [`NUM_PORTS-1:0];
    logic       crc_ok     [`NUM_PORTS-1:0];

    logic       reg_we;
    logic [6:0] reg_waddr, reg_raddr;
    logic [7:0] reg_wdata, reg_rdata;
    logic [`NUM_PORTS-1:0] clear_fault_spi;
    logic [`NUM_PORTS-1:0] manual_kill_spi;

    // On-FPGA demo stimulus (no carrier required): drive port0 after lock.
    logic        stim_oe, stim_dp, stim_dn;
    logic        stim_busy, stim_done;
    logic        stim_start;
    logic [23:0] boot_cnt;
    logic        boot_fired;

    always_ff @(posedge clk_48m) begin
        if (rst) begin
            boot_cnt   <= 24'd0;
            boot_fired <= 1'b0;
            stim_start <= 1'b0;
        end else begin
            stim_start <= 1'b0;
            if (!boot_fired) begin
                if (boot_cnt >= 24'(BOOT_STIM_CYCLES)) begin
                    boot_fired <= 1'b1;
                    stim_start <= 1'b1;
                end else
                    boot_cnt <= boot_cnt + 24'd1;
            end
        end
    end

    usb_demo_selfstim u_selfstim (
        .clk_48m(clk_48m),
        .rst    (rst),
        .start  (stim_start),
        .busy   (stim_busy),
        .done   (stim_done),
        .tx_oe  (stim_oe),
        .tx_dp  (stim_dp),
        .tx_dn  (stim_dn)
    );

    assign dp[0] = stim_oe ? stim_dp : p0_dp_tap;
    assign dm[0] = stim_oe ? stim_dn : p0_dm_tap;
    assign dp[3:1] = {p3_dp_tap, p2_dp_tap, p1_dp_tap};
    assign dm[3:1] = {p3_dm_tap, p2_dm_tap, p1_dm_tap};

    // btn_clear clears faults (OR with SPI clear)
    assign clear_fault = clear_fault_spi | {`NUM_PORTS{clr_btn_sync1}};
    assign manual_kill = manual_kill_spi;

    // Isolate: mux enable active-low → high when killed; cut eFuse when killed
    assign p0_mux_en_n = kill[0];
    assign p1_mux_en_n = kill[1];
    assign p2_mux_en_n = kill[2];
    assign p3_mux_en_n = kill[3];
    assign p0_efuse_en = ~kill[0];
    assign p1_efuse_en = ~kill[1];
    assign p2_efuse_en = ~kill[2];
    assign p3_efuse_en = ~kill[3];

    assign led   = kill;
    assign led_r = ~(|kill);                 // red = any kill (active-low)
    assign led_g = ~(stim_busy || stim_done); // green while demo stim runs/done
    assign led_b = 1'b1;

    sniffer_wrapper u_sniffers (
        .clk_48m           (clk_48m),
        .rst               (rst),
        .dp                (dp),
        .dm                (dm),
        .clear_fault       (clear_fault),
        .manual_kill       (manual_kill),
        .kill              (kill),
        .threat_code       (threat_code),
        .port_status       (port_status),
        .vid               (vid),
        .pid_dev           (pid_dev),
        .dev_class         (dev_class),
        .intf_class        (intf_class),
        .device_desc_valid (device_desc_valid),
        .intf_class_valid  (intf_class_valid),
        .pkt_start         (pkt_start),
        .pkt_end           (pkt_end),
        .pid               (pid),
        .endp              (endp),
        .data_valid        (data_valid),
        .data              (data),
        .crc_ok            (crc_ok)
    );

    register_file u_regs (
        .clk         (clk_48m),
        .rst         (rst),
        .reg_we      (reg_we),
        .reg_waddr   (reg_waddr),
        .reg_wdata   (reg_wdata),
        .reg_raddr   (reg_raddr),
        .reg_rdata   (reg_rdata),
        .kill        (kill),
        .threat_code (threat_code),
        .port_status (port_status),
        .vid         (vid),
        .pid_dev     (pid_dev),
        .dev_class   (dev_class),
        .intf_class  (intf_class),
        .clear_fault (clear_fault_spi),
        .manual_kill (manual_kill_spi)
    );

    spi_slave u_spi (
        .clk      (clk_48m),
        .rst      (rst),
        .sclk     (spi_sck),
        .cs_n     (spi_cs_n),
        .mosi     (spi_mosi),
        .miso     (spi_miso),
        .reg_we   (reg_we),
        .reg_waddr(reg_waddr),
        .reg_wdata(reg_wdata),
        .reg_raddr(reg_raddr),
        .reg_rdata(reg_rdata)
    );

`ifndef VERILATOR
    // synthesis translate_off
    main_wrapper_sva u_main_sva (
        .clk         (clk_48m),
        .rst         (rst),
        .kill        (kill),
        .p0_mux_en_n (p0_mux_en_n),
        .p1_mux_en_n (p1_mux_en_n),
        .p2_mux_en_n (p2_mux_en_n),
        .p3_mux_en_n (p3_mux_en_n),
        .p0_efuse_en (p0_efuse_en),
        .p1_efuse_en (p1_efuse_en),
        .p2_efuse_en (p2_efuse_en),
        .p3_efuse_en (p3_efuse_en),
        .led         (led),
        .led_r       (led_r)
    );
    // synthesis translate_on
`endif

endmodule
