`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: tb_kill_e2e
// Purpose: End-to-end acceptance:
//   line packet → frontend decode → CRC fault → kill on correct port(s) →
//   sticky until MCU clears via SPI write to Pn_CONTROL[6].
// Cases: each port sequential; then all ports concurrent; SPI clear per-port.
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module tb_kill_e2e;

    logic clk_48m = 1'b0;
    logic rst     = 1'b1;
    always #10.4167 clk_48m = ~clk_48m;

    // --- SPI master BFMs ---
    logic sclk = 1'b0;
    logic cs_n = 1'b1;
    logic mosi = 1'b0;
    logic miso;

    // --- USB line stimulus (one TX per port) ---
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
        .clk_48m    (clk_48m),
        .rst        (rst),
        .dp         (dp),
        .dm         (dm),
        .clear_fault(clear_fault),
        .manual_kill(manual_kill),
        .kill       (kill),
        .threat_code(threat_code),
        .port_status(port_status),
        .vid        (vid),
        .pid_dev    (pid_dev),
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

    // --- Per-port TX ---
    localparam int DATA0_LEN = 3;
    localparam logic [3:0] PID_DATA0 = 4'b0011;
    localparam logic [3:0] PID_ACK   = 4'b0010;

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

    // --- Capture ---
    localparam int MAX_BYTES = 16;
    logic [7:0] cap_bytes [`NUM_PORTS-1:0][0:MAX_BYTES-1];
    int         cap_count [`NUM_PORTS-1:0];
    int         packets_seen [`NUM_PORTS-1:0];
    logic [3:0] last_pid     [`NUM_PORTS-1:0];
    logic       last_crc_ok  [`NUM_PORTS-1:0];
    int         errors;

    generate
        for (gi = 0; gi < `NUM_PORTS; gi = gi + 1) begin : g_cap
            always @(posedge clk_48m) begin
                if (rst) begin
                    cap_count[gi]    <= 0;
                    packets_seen[gi] <= 0;
                    last_pid[gi]     <= '0;
                    last_crc_ok[gi]  <= 1'b0;
                end else begin
                    if (pkt_start[gi])
                        cap_count[gi] <= 0;
                    if (data_valid[gi] && cap_count[gi] < MAX_BYTES) begin
                        cap_bytes[gi][cap_count[gi]] <= data[gi];
                        cap_count[gi]                <= cap_count[gi] + 1;
                    end
                    if (pkt_end[gi]) begin
                        packets_seen[gi] <= packets_seen[gi] + 1;
                        last_pid[gi]     <= pid[gi];
                        last_crc_ok[gi]  <= crc_ok[gi];
                        $display("%0t port%0d pkt_end pid=0x%0h crc_ok=%0b nbytes=%0d kill=%b threat=0x%0h",
                                 $time, gi, pid[gi], crc_ok[gi], cap_count[gi],
                                 kill, threat_code[gi]);
                    end
                end
            end
        end
    endgenerate

    // --- Helpers ---
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

    task automatic send_ack_port(input int p);
        sending_data[p] = 1'b0;
        corrupt[p] = 1'b0;
        tx_pid[p] = PID_ACK;
        @(posedge clk_48m);
        tx_pkt_start[p] = 1'b1;
        @(posedge clk_48m);
        tx_pkt_start[p] = 1'b0;
        wait (tx_pkt_end[p] === 1'b1);
        @(posedge clk_48m);
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

    // SPI Mode 0, 16-bit frame. Sample MISO after slave reacts to rising SCLK.
    task automatic spi_transfer(input logic [15:0] mosibits, output logic [7:0] misobyte);
        int i;
        logic [7:0] rx;
        rx = 8'h00;
        cs_n = 1'b0;
        sclk = 1'b0;
        mosi = 1'b0;
        repeat (4) @(posedge clk_48m);

        for (i = 15; i >= 0; i = i - 1) begin
            mosi = mosibits[i];
            repeat (2) @(posedge clk_48m);
            sclk = 1'b1;
            repeat (3) @(posedge clk_48m); // allow slave sclk_rise + miso update
            if (i <= 7)
                rx = {rx[6:0], miso};
            sclk = 1'b0;
            repeat (2) @(posedge clk_48m);
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
        // Pn_CONTROL bit6 = Clear Fault
        spi_write(port_ctrl_addr(p), 8'h40);
    endtask

    task automatic check_only_ports_killed(input logic [`NUM_PORTS-1:0] expect_kill);
        int p;
        for (p = 0; p < `NUM_PORTS; p = p + 1) begin
            if (kill[p] !== expect_kill[p]) begin
                $error("kill mismatch port%0d got=%0b expect=%0b (vec=%b)",
                       p, kill[p], expect_kill[p], kill);
                errors++;
            end
            if (expect_kill[p] && threat_code[p] !== `THREAT_CRC_TOKEN_FAULT) begin
                $error("port%0d threat=0x%0h", p, threat_code[p]);
                errors++;
            end
            if (!expect_kill[p] && threat_code[p] !== `THREAT_NO_FAULT) begin
                $error("port%0d unexpected threat=0x%0h", p, threat_code[p]);
                errors++;
            end
        end
    endtask

    task automatic check_good_decode(input int p);
        if (last_pid[p] !== PID_DATA0 || !last_crc_ok[p] || cap_count[p] !== DATA0_LEN) begin
            $error("port%0d good decode pid/crc/len", p);
            errors++;
        end else if (cap_bytes[p][0] !== 8'h00 || cap_bytes[p][1] !== 8'hA5 ||
                     cap_bytes[p][2] !== 8'h5A) begin
            $error("port%0d good payload", p);
            errors++;
        end
    endtask

    integer p;
    integer base_pkt;
    integer base0, base1, base2, base3;
    logic [7:0] rd;
    logic [`NUM_PORTS-1:0] exp_kill;

    initial begin
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

        $display("tb_kill_e2e: sequential + concurrent CRC kill, SPI clear");
        repeat (32) @(posedge clk_48m);
        rst = 1'b0;
        wait_idle_bits(8);

        // ============================================================
        // Phase A: each port sequential — good decode, then corrupt kill
        // ============================================================
        for (p = 0; p < `NUM_PORTS; p = p + 1) begin
            $display("--- sequential port %0d ---", p);

            base_pkt = packets_seen[p];
            send_data0_port(p, 1'b0);
            wait_packet_port(p, base_pkt);
            check_good_decode(p);
            check_only_ports_killed({`NUM_PORTS{1'b0}});
            if (errors == 0) $display("port%0d good DATA0 OK", p);

            base_pkt = packets_seen[p];
            send_ack_port(p);
            wait_packet_port(p, base_pkt);
            if (last_pid[p] !== PID_ACK || !last_crc_ok[p]) begin
                $error("port%0d ACK", p); errors++;
            end else $display("port%0d ACK OK", p);

            base_pkt = packets_seen[p];
            send_data0_port(p, 1'b1);
            wait_packet_port(p, base_pkt);
            if (last_crc_ok[p]) begin
                $error("port%0d corrupt expected fail", p); errors++;
            end
            repeat (8) @(posedge clk_48m);
            exp_kill = {`NUM_PORTS{1'b0}};
            exp_kill[p] = 1'b1;
            check_only_ports_killed(exp_kill);
            if (errors == 0) $display("port%0d corrupt → kill OK", p);

            // Sticky: wait with no clear — kill must remain
            repeat (200) @(posedge clk_48m);
            if (!kill[p]) begin
                $error("port%0d kill not sticky", p); errors++;
            end else $display("port%0d sticky kill OK", p);

            // Clear via SPI register (not a side-door wire)
            spi_read(port_stat_addr(p), rd);
            if (!rd[7] || rd[3:0] !== `THREAT_CRC_TOKEN_FAULT) begin
                $error("port%0d SPI status before clear=%h", p, rd); errors++;
            end

            spi_clear_port(p);
            repeat (16) @(posedge clk_48m);
            check_only_ports_killed({`NUM_PORTS{1'b0}});
            // Clear bit is W1C pulse; CONTROL may still read back prior write data.
            // Status must show not isolated / no threat.
            spi_write(port_ctrl_addr(p), 8'h00); // drop stored clear/manual bits
            repeat (8) @(posedge clk_48m);
            spi_read(port_stat_addr(p), rd);
            if (rd[7] || rd[3:0] !== `THREAT_NO_FAULT) begin
                $error("port%0d SPI status after clear=%h", p, rd); errors++;
            end else $display("port%0d SPI clear OK (status=%h)", p, rd);
        end

        // ============================================================
        // Phase B: all ports concurrent corrupt → all kill; clear one-by-one
        // ============================================================
        $display("--- concurrent corrupt all ports ---");
        base0 = packets_seen[0];
        base1 = packets_seen[1];
        base2 = packets_seen[2];
        base3 = packets_seen[3];

        fork
            send_data0_port(0, 1'b1);
            send_data0_port(1, 1'b1);
            send_data0_port(2, 1'b1);
            send_data0_port(3, 1'b1);
        join

        wait_packet_port(0, base0);
        wait_packet_port(1, base1);
        wait_packet_port(2, base2);
        wait_packet_port(3, base3);

        repeat (8) @(posedge clk_48m);
        check_only_ports_killed({`NUM_PORTS{1'b1}});
        if (errors == 0) $display("concurrent all-kill OK");

        // Sticky while clearing: clear port 1 only via SPI
        spi_clear_port(1);
        repeat (16) @(posedge clk_48m);
        check_only_ports_killed(4'b1101); // ports 0,2,3 still high
        if (errors == 0) $display("SPI clear port1 only OK (kill=%b)", kill);

        spi_clear_port(0);
        spi_clear_port(2);
        spi_clear_port(3);
        repeat (16) @(posedge clk_48m);
        check_only_ports_killed({`NUM_PORTS{1'b0}});
        if (errors == 0) $display("SPI clear remaining OK");

        base2 = packets_seen[2];
        send_data0_port(2, 1'b0);
        wait_packet_port(2, base2);
        check_good_decode(2);
        check_only_ports_killed({`NUM_PORTS{1'b0}});

        if (errors == 0) $display("tb_kill_e2e: PASS");
        else             $display("tb_kill_e2e: FAIL (%0d errors)", errors);
        $finish;
    end

    initial begin
        #50ms;
        $error("global timeout");
        $finish;
    end

endmodule
