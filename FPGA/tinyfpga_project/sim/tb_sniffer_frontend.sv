`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: tb_sniffer_frontend
// Purpose: XSim checks for steps 1–2:
//   - usb_packet_frontend strips CRC16 and forwards payload
//   - isolation_controller latches kill on CRC fault (threat 0x5)
//   - good DATA0 / ACK do not kill; corrupted DATA0 does; clear_fault releases
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module tb_sniffer_frontend;

    logic clk_48m = 1'b0;
    logic rst     = 1'b1;

    always #10.4167 clk_48m = ~clk_48m;

    logic [1:0] bit_phase = 2'b00;
    logic       bit_strobe_stim;
    always @(posedge clk_48m) begin
        if (rst) bit_phase <= 2'b00;
        else     bit_phase <= bit_phase + 2'b01;
    end
    assign bit_strobe_stim = (bit_phase == 2'b00) && !rst;

    logic tx_oe, tx_dp, tx_dn;
    logic corrupt;
    logic dp, dn;
    assign dp = ((tx_oe ? tx_dp : 1'b1) ^ corrupt);
    assign dn = (tx_oe ? tx_dn : 1'b0);

    logic clear_fault;
    logic manual_kill;

    logic       pkt_start, pkt_end;
    logic [3:0] pid;
    logic       data_valid;
    logic [7:0] data;
    logic       crc_ok;
    logic       kill;
    logic [3:0] threat_code;

    sniffer_channel dut (
        .clk_48m    (clk_48m),
        .rst        (rst),
        .dp         (dp),
        .dm         (dn),
        .clear_fault(clear_fault),
        .manual_kill(manual_kill),
        .pkt_start  (pkt_start),
        .pkt_end    (pkt_end),
        .pid        (pid),
        .data_valid (data_valid),
        .data       (data),
        .crc_ok     (crc_ok),
        .kill       (kill),
        .threat_code(threat_code)
    );

    logic       tx_pkt_start;
    logic       tx_pkt_end;
    logic [3:0] tx_pid;
    logic       tx_data_avail;
    logic       tx_data_get;
    logic [7:0] tx_data;

    usb_fs_tx stim_tx (
        .clk_48mhz    (clk_48m),
        .clk          (clk_48m),
        .reset        (rst),
        .bit_strobe   (bit_strobe_stim),
        .oe           (tx_oe),
        .dp           (tx_dp),
        .dn           (tx_dn),
        .pkt_start    (tx_pkt_start),
        .pkt_end      (tx_pkt_end),
        .pid          (tx_pid),
        .tx_data_avail(tx_data_avail),
        .tx_data_get  (tx_data_get),
        .tx_data      (tx_data)
    );

    localparam int DATA0_LEN = 3;
    localparam logic [3:0] PID_ACK   = 4'b0010;
    localparam logic [3:0] PID_DATA0 = 4'b0011;

    logic [7:0] payload [0:DATA0_LEN-1];
    int         payload_idx;
    logic       sending_data;

    assign tx_data_avail = sending_data && (payload_idx < DATA0_LEN);
    assign tx_data       = payload[payload_idx];

    always @(posedge clk_48m) begin
        if (rst) payload_idx <= 0;
        else if (tx_pkt_start) payload_idx <= 0;
        else if (tx_data_get && tx_data_avail) payload_idx <= payload_idx + 1;
    end

    localparam int MAX_BYTES = 16;
    logic [7:0] cap_bytes [0:MAX_BYTES-1];
    int         cap_count;
    int         packets_seen;
    int         errors;
    logic [3:0] last_pid;
    logic       last_crc_ok;

    always @(posedge clk_48m) begin
        if (rst) begin
            cap_count    <= 0;
            packets_seen <= 0;
            last_pid     <= '0;
            last_crc_ok  <= 1'b0;
        end else begin
            if (pkt_start)
                cap_count <= 0;
            if (data_valid && cap_count < MAX_BYTES) begin
                cap_bytes[cap_count] <= data;
                cap_count            <= cap_count + 1;
            end
            if (pkt_end) begin
                packets_seen <= packets_seen + 1;
                last_pid     <= pid;
                last_crc_ok  <= crc_ok;
                $display("%0t pkt_end pid=0x%0h crc_ok=%0b nbytes=%0d kill=%0b threat=0x%0h",
                         $time, pid, crc_ok, cap_count, kill, threat_code);
            end
        end
    end

    task automatic wait_idle_bits(int n);
        repeat (n) @(posedge bit_strobe_stim);
    endtask

    task automatic send_data0(input logic do_corrupt);
        sending_data = 1'b1;
        payload[0] = 8'h00;
        payload[1] = 8'hA5;
        payload[2] = 8'h5A;
        tx_pid = PID_DATA0;
        corrupt = 1'b0;
        @(posedge clk_48m);
        tx_pkt_start = 1'b1;
        @(posedge clk_48m);
        tx_pkt_start = 1'b0;

        if (do_corrupt) begin
            // Flip one bit time mid-packet to break CRC.
            repeat (40) @(posedge bit_strobe_stim);
            corrupt = 1'b1;
            @(posedge bit_strobe_stim);
            corrupt = 1'b0;
        end

        wait (tx_pkt_end === 1'b1);
        @(posedge clk_48m);
        sending_data = 1'b0;
        wait_idle_bits(16);
    endtask

    task automatic send_ack();
        sending_data = 1'b0;
        corrupt = 1'b0;
        tx_pid = PID_ACK;
        @(posedge clk_48m);
        tx_pkt_start = 1'b1;
        @(posedge clk_48m);
        tx_pkt_start = 1'b0;
        wait (tx_pkt_end === 1'b1);
        @(posedge clk_48m);
        wait_idle_bits(16);
    endtask

    task automatic wait_packet();
        int timeout;
        timeout = 0;
        while (packets_seen == 0 && timeout < 50000) begin
            @(posedge clk_48m);
            timeout++;
        end
        if (packets_seen == 0) begin
            $error("timeout waiting for packet");
            errors++;
        end
    endtask

    initial begin
        tx_pkt_start = 1'b0;
        sending_data = 1'b0;
        corrupt      = 1'b0;
        clear_fault  = 1'b0;
        manual_kill  = 1'b0;
        errors       = 0;
        packets_seen = 0;

        $display("tb_sniffer_frontend: frontend + isolation");
        repeat (32) @(posedge clk_48m);
        rst = 1'b0;
        wait_idle_bits(8);

        // --- Good DATA0: payload stripped of CRC, no kill ---
        send_data0(1'b0);
        repeat (20) @(posedge clk_48m);
        wait_packet();
        if (last_pid !== PID_DATA0) begin
            $error("good DATA0 pid"); errors++;
        end
        if (!last_crc_ok) begin
            $error("good DATA0 crc_ok"); errors++;
        end
        if (cap_count !== DATA0_LEN) begin
            $error("good DATA0 nbytes got %0d", cap_count); errors++;
        end else if (cap_bytes[0] !== 8'h00 || cap_bytes[1] !== 8'hA5 ||
                     cap_bytes[2] !== 8'h5A) begin
            $error("good DATA0 payload"); errors++;
        end
        if (kill) begin
            $error("good DATA0 should not kill"); errors++;
        end else $display("good DATA0 OK (no kill)");
        packets_seen = 0;

        // --- ACK: no kill ---
        send_ack();
        repeat (20) @(posedge clk_48m);
        wait_packet();
        if (last_pid !== PID_ACK || !last_crc_ok) begin
            $error("ACK check"); errors++;
        end
        if (kill) begin
            $error("ACK should not kill"); errors++;
        end else $display("ACK OK (no kill)");
        packets_seen = 0;

        // --- Corrupted DATA0: crc_fault → kill + threat 0x5 ---
        send_data0(1'b1);
        repeat (20) @(posedge clk_48m);
        wait_packet();
        if (last_crc_ok) begin
            $error("corrupt DATA0 expected crc fail"); errors++;
        end
        // Allow iso latch a cycle after crc_fault
        repeat (4) @(posedge clk_48m);
        if (!kill) begin
            $error("corrupt DATA0 should kill"); errors++;
        end
        if (threat_code !== `THREAT_CRC_TOKEN_FAULT) begin
            $error("threat_code got 0x%0h", threat_code); errors++;
        end else $display("corrupt DATA0 OK kill threat=0x%0h", threat_code);
        packets_seen = 0;

        // --- clear_fault releases ---
        @(posedge clk_48m);
        clear_fault = 1'b1;
        @(posedge clk_48m);
        clear_fault = 1'b0;
        @(posedge clk_48m);
        if (kill || threat_code !== `THREAT_NO_FAULT) begin
            $error("clear_fault failed"); errors++;
        end else $display("clear_fault OK");

        if (errors == 0)
            $display("tb_sniffer_frontend: PASS");
        else
            $display("tb_sniffer_frontend: FAIL (%0d errors)", errors);

        $finish;
    end

    initial begin
        #5ms;
        $error("global timeout");
        $finish;
    end

endmodule
