`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: tb_spi_manual_kill
// Purpose: Prove MCU operator isolate path through real SPI → register_file →
//          isolation_controller (threat 0x7). No USB stimulus required.
// Cases:   reset clean; port0 kill/sticky/SPI status; clear; all-port decode;
//          re-arm after clear.
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module tb_spi_manual_kill;

    logic clk_48m = 1'b0;
    logic rst     = 1'b1;
    always #10.4167 clk_48m = ~clk_48m;

    // --- SPI master BFM ---
    logic sclk = 1'b0;
    logic cs_n = 1'b1;
    logic mosi = 1'b0;
    logic miso;

    // Idle J on all ports (no USB traffic for this TB)
    logic [`NUM_PORTS-1:0] dp = {`NUM_PORTS{1'b1}};
    logic [`NUM_PORTS-1:0] dm = {`NUM_PORTS{1'b0}};

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

    sniffer_wrapper u_sniff (
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
        .clear_fault (clear_fault),
        .manual_kill (manual_kill)
    );

    spi_slave u_spi (
        .clk      (clk_48m),
        .rst      (rst),
        .sclk     (sclk),
        .cs_n     (cs_n),
        .mosi     (mosi),
        .miso     (miso),
        .reg_we   (reg_we),
        .reg_waddr(reg_waddr),
        .reg_wdata(reg_wdata),
        .reg_raddr(reg_raddr),
        .reg_rdata(reg_rdata)
    );

    int errors;

    // SPI Mode 0, 16-bit frame (same pacing as tb_kill_e2e / tb_spi_enum_e2e)
    task automatic spi_transfer(input logic [15:0] mosibits, output logic [7:0] misobyte);
        int i;
        logic [7:0] rx;
        rx = 8'h00;
        cs_n = 1'b0;
        sclk = 1'b0;
        mosi = 1'b0;
        repeat (4) @(posedge clk_48m);

        // Mode 0: sample MISO before rising SCK (stable from prior falling update).
        for (i = 15; i >= 0; i = i - 1) begin
            mosi = mosibits[i];
            repeat (2) @(posedge clk_48m);
            if (i <= 7)
                rx = {rx[6:0], miso};
            sclk = 1'b1;
            repeat (3) @(posedge clk_48m);
            sclk = 1'b0;
            repeat (4) @(posedge clk_48m); // allow sclk_fall + MISO shift
        end

        cs_n = 1'b1;
        mosi = 1'b0;
        repeat (8) @(posedge clk_48m);
        misobyte = rx;
    endtask

    task automatic spi_write(input logic [6:0] addr, input logic [7:0] data);
        logic [7:0] dummy;
        spi_transfer({1'b1, addr, data}, dummy);
    endtask

    task automatic spi_read(input logic [6:0] addr, output logic [7:0] data);
        spi_transfer({1'b0, addr, 8'h00}, data);
    endtask

    function automatic [6:0] port_ctrl_addr(input int p);
        port_ctrl_addr = 7'h10 + (p[3:0] << 4);
    endfunction

    function automatic [6:0] port_stat_addr(input int p);
        port_stat_addr = 7'h11 + (p[3:0] << 4);
    endfunction

    // Clear is a one-cycle pulse from Pn_CONTROL[6]; drop stored control afterward.
    task automatic spi_clear_port(input int p);
        spi_write(port_ctrl_addr(p), 8'h40);
        repeat (16) @(posedge clk_48m);
        spi_write(port_ctrl_addr(p), 8'h00);
        repeat (8) @(posedge clk_48m);
    endtask

    task automatic check_ports(
        input logic [`NUM_PORTS-1:0] expect_kill,
        input logic [3:0]           expect_threat_if_killed
    );
        int p;
        for (p = 0; p < `NUM_PORTS; p = p + 1) begin
            if (kill[p] !== expect_kill[p]) begin
                $error("kill mismatch port%0d got=%0b expect=%0b (vec=%b)",
                       p, kill[p], expect_kill[p], kill);
                errors++;
            end
            if (expect_kill[p]) begin
                if (threat_code[p] !== expect_threat_if_killed) begin
                    $error("port%0d threat=0x%0h expect=0x%0h",
                           p, threat_code[p], expect_threat_if_killed);
                    errors++;
                end
            end else if (threat_code[p] !== `THREAT_NO_FAULT) begin
                $error("port%0d unexpected threat=0x%0h", p, threat_code[p]);
                errors++;
            end
        end
    endtask

    task automatic check_spi_manual_status(input int p, input logic expect_killed);
        logic [7:0] rd;
        logic [7:0] sys;
        spi_read(port_stat_addr(p), rd);
        if (expect_killed) begin
            // Idle (no enum): not attached. pack: [7]=kill [6]=att [3:0]=threat → 0x87
            if (!rd[7] || rd[3:0] !== `THREAT_MANUAL_HOST_KILL) begin
                $error("port%0d SPI status while manual-killed=%02h", p, rd);
                errors++;
            end else
                $display("port%0d SPI status=%02h OK (isolated+threat 0x7)", p, rd);
        end else begin
            if (rd[7] || rd[3:0] !== `THREAT_NO_FAULT) begin
                $error("port%0d SPI status after clear=%02h", p, rd);
                errors++;
            end else
                $display("port%0d SPI status=%02h OK (clear)", p, rd);
        end

        spi_read(`ADDR_SYS_STATUS, sys);
        if (sys[p] !== expect_killed) begin
            $error("SYS_STATUS bit%0d=%0b expect=%0b (sys=%02h)",
                   p, sys[p], expect_killed, sys);
            errors++;
        end
    endtask

    task automatic spi_manual_kill_port(input int p);
        spi_write(port_ctrl_addr(p), 8'h80);
        repeat (8) @(posedge clk_48m);
    endtask

    integer p, q;
    logic [7:0] rd;
    logic [`NUM_PORTS-1:0] exp_kill;

    initial begin
        errors = 0;
        cs_n = 1'b1;
        sclk = 1'b0;
        mosi = 1'b0;

        $display("tb_spi_manual_kill: SPI Pn_CONTROL[7] → threat 0x7 + clear");
        repeat (32) @(posedge clk_48m);
        rst = 1'b0;
        repeat (16) @(posedge clk_48m);

        // ============================================================
        // 1) After reset: all clean
        // ============================================================
        check_ports({`NUM_PORTS{1'b0}}, `THREAT_NO_FAULT);
        spi_read(`ADDR_SYS_STATUS, rd);
        if (rd[3:0] !== 4'h0) begin
            $error("SYS_STATUS after reset=%02h", rd); errors++;
        end
        for (p = 0; p < `NUM_PORTS; p = p + 1) begin
            spi_read(port_stat_addr(p), rd);
            if (rd[7] || rd[3:0] !== `THREAT_NO_FAULT) begin
                $error("port%0d SPI status after reset=%02h", p, rd); errors++;
            end
        end
        if (errors == 0) $display("reset clean OK");

        // ============================================================
        // 2) Port0 manual kill via SPI 0x10 ← 0x80
        // ============================================================
        $display("--- port0 SPI manual kill ---");
        spi_manual_kill_port(0);

        exp_kill = {`NUM_PORTS{1'b0}};
        exp_kill[0] = 1'b1;
        check_ports(exp_kill, `THREAT_MANUAL_HOST_KILL);
        if (manual_kill[0] !== 1'b1) begin
            $error("manual_kill[0] not driven from register_file"); errors++;
        end

        // Sticky across many cycles (CONTROL still holds bit7)
        repeat (200) @(posedge clk_48m);
        check_ports(exp_kill, `THREAT_MANUAL_HOST_KILL);
        check_spi_manual_status(0, 1'b1);
        // Other ports stay clear over SPI
        for (p = 1; p < `NUM_PORTS; p = p + 1)
            check_spi_manual_status(p, 1'b0);
        if (errors == 0) $display("port0 sticky manual kill + SPI status OK");

        // ============================================================
        // 3) Clear port0 (pulse bit6, then drop CONTROL)
        // ============================================================
        spi_clear_port(0);
        check_ports({`NUM_PORTS{1'b0}}, `THREAT_NO_FAULT);
        check_spi_manual_status(0, 1'b0);
        if (errors == 0) $display("port0 SPI clear OK");

        // ============================================================
        // 4) Re-arm: second manual kill on port0 still works
        // ============================================================
        spi_manual_kill_port(0);
        check_ports(exp_kill, `THREAT_MANUAL_HOST_KILL);
        check_spi_manual_status(0, 1'b1);
        spi_clear_port(0);
        check_ports({`NUM_PORTS{1'b0}}, `THREAT_NO_FAULT);
        if (errors == 0) $display("port0 re-arm OK");

        // ============================================================
        // 5) Address decode: each port 0x10/0x20/0x30/0x40
        // ============================================================
        for (p = 0; p < `NUM_PORTS; p = p + 1) begin
            $display("--- sequential SPI manual kill port %0d ---", p);
            spi_manual_kill_port(p);
            exp_kill = {`NUM_PORTS{1'b0}};
            exp_kill[p] = 1'b1;
            check_ports(exp_kill, `THREAT_MANUAL_HOST_KILL);
            check_spi_manual_status(p, 1'b1);
            for (q = 0; q < `NUM_PORTS; q = q + 1) begin
                if (q != p)
                    check_spi_manual_status(q, 1'b0);
            end
            spi_clear_port(p);
            check_ports({`NUM_PORTS{1'b0}}, `THREAT_NO_FAULT);
            if (errors == 0)
                $display("port%0d SPI manual kill/clear OK", p);
        end

        if (errors == 0) $display("tb_spi_manual_kill: PASS");
        else             $display("tb_spi_manual_kill: FAIL (%0d errors)", errors);
        $finish;
    end

    initial begin
        #20ms;
        $error("global timeout");
        $finish;
    end

endmodule
