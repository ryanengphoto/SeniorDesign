`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: tb_kill_manual_cross
// Purpose: Cross-path isolation semantics on port0:
//   A) CRC kill (0x5) then SPI manual → overwrite to 0x7 → clear
//   B) SPI manual (0x7), drop CONTROL[7] without clear → sticky 0x7;
//      CRC while killed ignored; clear; CRC kill again → 0x5
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module tb_kill_manual_cross;

    logic clk_48m = 1'b0;
    logic rst     = 1'b1;
    always #10.4167 clk_48m = ~clk_48m;

    logic sclk = 1'b0;
    logic cs_n = 1'b1;
    logic mosi = 1'b0;
    logic miso;

    logic [1:0] bit_phase = 2'b00;
    logic       bit_strobe_stim;
    always @(posedge clk_48m) begin
        if (rst) bit_phase <= 2'b00;
        else     bit_phase <= bit_phase + 2'b01;
    end
    assign bit_strobe_stim = (bit_phase == 2'b00) && !rst;

    logic [`NUM_PORTS-1:0] tx_oe, tx_dp, tx_dn, corrupt;
    logic [`NUM_PORTS-1:0] dp, dm;

    genvar gi;
    generate
        for (gi = 0; gi < `NUM_PORTS; gi = gi + 1) begin : g_line
            assign dp[gi] = ((tx_oe[gi] ? tx_dp[gi] : 1'b1) ^ corrupt[gi]);
            assign dm[gi] = (tx_oe[gi] ? tx_dn[gi] : 1'b0);
        end
    endgenerate

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

    localparam int DATA0_LEN = 3;
    localparam logic [3:0] PID_DATA0 = 4'b0011;

    logic       tx_pkt_start [`NUM_PORTS-1:0];
    logic       tx_pkt_end   [`NUM_PORTS-1:0];
    logic [3:0] tx_pid       [`NUM_PORTS-1:0];
    logic       tx_data_avail[`NUM_PORTS-1:0];
    logic       tx_data_get  [`NUM_PORTS-1:0];
    logic [7:0] tx_data      [`NUM_PORTS-1:0];
    logic [7:0] payload      [`NUM_PORTS-1:0][0:DATA0_LEN-1];
    int         payload_idx  [`NUM_PORTS-1:0];
    logic       sending_data [`NUM_PORTS-1:0];

    generate
        for (gi = 0; gi < `NUM_PORTS; gi = gi + 1) begin : g_tx
            usb_fs_tx stim_tx (
                .clk_48mhz    (clk_48m),
                .clk          (clk_48m),
                .reset        (rst),
                .bit_strobe   (bit_strobe_stim),
                .oe           (tx_oe[gi]),
                .dp           (tx_dp[gi]),
                .dn           (tx_dn[gi]),
                .pkt_start    (tx_pkt_start[gi]),
                .pkt_end      (tx_pkt_end[gi]),
                .pid          (tx_pid[gi]),
                .tx_data_avail(tx_data_avail[gi]),
                .tx_data_get  (tx_data_get[gi]),
                .tx_data      (tx_data[gi])
            );

            assign tx_data_avail[gi] = sending_data[gi] && (payload_idx[gi] < DATA0_LEN);
            assign tx_data[gi]       = payload[gi][payload_idx[gi]];

            always @(posedge clk_48m) begin
                if (rst) payload_idx[gi] <= 0;
                else if (tx_pkt_start[gi]) payload_idx[gi] <= 0;
                else if (tx_data_get[gi] && tx_data_avail[gi])
                    payload_idx[gi] <= payload_idx[gi] + 1;
            end
        end
    endgenerate

    int packets_seen [`NUM_PORTS-1:0];
    logic last_crc_ok [`NUM_PORTS-1:0];
    int errors;

    generate
        for (gi = 0; gi < `NUM_PORTS; gi = gi + 1) begin : g_cap
            always @(posedge clk_48m) begin
                if (rst) begin
                    packets_seen[gi] <= 0;
                    last_crc_ok[gi]  <= 1'b0;
                end else if (pkt_end[gi]) begin
                    packets_seen[gi] <= packets_seen[gi] + 1;
                    last_crc_ok[gi]  <= crc_ok[gi];
                end
            end
        end
    endgenerate

    task automatic wait_idle_bits(int n);
        repeat (n) @(posedge bit_strobe_stim);
    endtask

    task automatic send_data0_port(input int p, input logic do_corrupt);
        sending_data[p] = 1'b1;
        payload[p][0] = 8'h00;
        payload[p][1] = 8'hA5;
        payload[p][2] = 8'h5A;
        tx_pid[p] = PID_DATA0;
        corrupt[p] = 1'b0;
        @(posedge clk_48m);
        tx_pkt_start[p] = 1'b1;
        @(posedge clk_48m);
        tx_pkt_start[p] = 1'b0;
        if (do_corrupt) begin
            repeat (40) @(posedge bit_strobe_stim);
            corrupt[p] = 1'b1;
            @(posedge bit_strobe_stim);
            corrupt[p] = 1'b0;
        end
        wait (tx_pkt_end[p] === 1'b1);
        @(posedge clk_48m);
        sending_data[p] = 1'b0;
        wait_idle_bits(8);
    endtask

    task automatic wait_packet_port(input int p, input int base);
        int timeout;
        timeout = 0;
        while (packets_seen[p] == base && timeout < 50000) begin
            @(posedge clk_48m);
            timeout++;
        end
        if (packets_seen[p] == base) begin
            $error("port%0d timeout waiting for packet", p);
            errors++;
        end
    endtask

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

    task automatic spi_clear_port(input int p);
        spi_write(port_ctrl_addr(p), 8'h40);
        repeat (16) @(posedge clk_48m);
        spi_write(port_ctrl_addr(p), 8'h00);
        repeat (8) @(posedge clk_48m);
    endtask

    task automatic spi_manual_kill_port(input int p);
        spi_write(port_ctrl_addr(p), 8'h80);
        repeat (8) @(posedge clk_48m);
    endtask

    task automatic expect_port0(input logic expect_kill, input logic [3:0] expect_threat);
        if (kill[0] !== expect_kill) begin
            $error("kill[0]=%0b expect=%0b", kill[0], expect_kill); errors++;
        end
        if (threat_code[0] !== expect_threat) begin
            $error("threat[0]=0x%0h expect=0x%0h", threat_code[0], expect_threat); errors++;
        end
        begin : other_ports_clean
            int q;
            for (q = 1; q < `NUM_PORTS; q = q + 1) begin
                if (kill[q] || threat_code[q] !== `THREAT_NO_FAULT) begin
                    $error("port%0d unexpectedly active kill=%0b threat=0x%0h",
                           q, kill[q], threat_code[q]);
                    errors++;
                end
            end
        end
    endtask

    task automatic check_spi_status(input logic [3:0] expect_threat, input logic expect_kill);
        logic [7:0] rd;
        spi_read(port_stat_addr(0), rd);
        if (rd[7] !== expect_kill || rd[3:0] !== expect_threat) begin
            $error("SPI P0_STATUS=%02h expect kill=%0b threat=0x%0h",
                   rd, expect_kill, expect_threat);
            errors++;
        end else
            $display("SPI P0_STATUS=%02h OK", rd);
    endtask

    integer base_pkt;
    logic [7:0] rd;

    initial begin
        int p;
        for (p = 0; p < `NUM_PORTS; p = p + 1) begin
            tx_pkt_start[p] = 1'b0;
            sending_data[p] = 1'b0;
            corrupt[p]      = 1'b0;
            tx_pid[p]       = 4'h0;
        end
        errors = 0;
        cs_n = 1'b1;
        sclk = 1'b0;
        mosi = 1'b0;

        $display("tb_kill_manual_cross: CRC↔manual interaction on port0");
        repeat (32) @(posedge clk_48m);
        rst = 1'b0;
        wait_idle_bits(8);

        // ============================================================
        // A) CRC sticky 0x5 → SPI manual overwrites to 0x7 → clear
        // ============================================================
        $display("--- A: CRC then SPI manual overwrite ---");
        base_pkt = packets_seen[0];
        send_data0_port(0, 1'b1);
        wait_packet_port(0, base_pkt);
        if (last_crc_ok[0]) begin
            $error("A: corrupt expected CRC fail"); errors++;
        end
        repeat (8) @(posedge clk_48m);
        expect_port0(1'b1, `THREAT_CRC_TOKEN_FAULT);
        check_spi_status(`THREAT_CRC_TOKEN_FAULT, 1'b1);
        if (errors == 0) $display("A: CRC kill 0x5 OK");

        spi_manual_kill_port(0);
        expect_port0(1'b1, `THREAT_MANUAL_HOST_KILL);
        check_spi_status(`THREAT_MANUAL_HOST_KILL, 1'b1);
        if (errors == 0) $display("A: manual overwrite → 0x7 OK");

        spi_clear_port(0);
        expect_port0(1'b0, `THREAT_NO_FAULT);
        check_spi_status(`THREAT_NO_FAULT, 1'b0);
        if (errors == 0) $display("A: clear OK");

        // ============================================================
        // B) Manual sticky; CRC while killed ignored; re-arm CRC
        // ============================================================
        $display("--- B: manual sticky ignores CRC; clear then CRC ---");
        spi_manual_kill_port(0);
        expect_port0(1'b1, `THREAT_MANUAL_HOST_KILL);

        // Drop CONTROL[7] without clear_fault — kill must remain sticky 0x7
        spi_write(port_ctrl_addr(0), 8'h00);
        repeat (16) @(posedge clk_48m);
        if (manual_kill[0] !== 1'b0) begin
            $error("B: manual_kill still high after CONTROL clear"); errors++;
        end
        expect_port0(1'b1, `THREAT_MANUAL_HOST_KILL);
        if (errors == 0) $display("B: sticky after dropping CONTROL[7] OK");

        base_pkt = packets_seen[0];
        send_data0_port(0, 1'b1);
        wait_packet_port(0, base_pkt);
        repeat (8) @(posedge clk_48m);
        // Still isolated as manual threat — first-sticky ignores new CRC code
        expect_port0(1'b1, `THREAT_MANUAL_HOST_KILL);
        check_spi_status(`THREAT_MANUAL_HOST_KILL, 1'b1);
        if (errors == 0) $display("B: CRC while killed ignored (stay 0x7) OK");

        spi_clear_port(0);
        expect_port0(1'b0, `THREAT_NO_FAULT);

        base_pkt = packets_seen[0];
        send_data0_port(0, 1'b1);
        wait_packet_port(0, base_pkt);
        repeat (8) @(posedge clk_48m);
        expect_port0(1'b1, `THREAT_CRC_TOKEN_FAULT);
        check_spi_status(`THREAT_CRC_TOKEN_FAULT, 1'b1);
        if (errors == 0) $display("B: re-arm CRC kill 0x5 OK");

        spi_clear_port(0);
        expect_port0(1'b0, `THREAT_NO_FAULT);

        if (errors == 0) $display("tb_kill_manual_cross: PASS");
        else             $display("tb_kill_manual_cross: FAIL (%0d errors)", errors);
        $finish;
    end

    initial begin
        #30ms;
        $error("global timeout");
        $finish;
    end

endmodule
