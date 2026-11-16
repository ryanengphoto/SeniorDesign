`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: tb_usb_fs_rx
// Purpose: XSim bring-up for vendored TinyFPGA usb_fs_rx.
//          usb_fs_tx (sim-only) + free-running 12 Mb/s bit strobe emits FS
//          packets onto D+/D-; scoreboard checks PID, payload, valid_packet.
//
// Packets:
//   1) DATA0 with payload {8'h00, 8'hA5, 8'h5A}  (RX also shifts out CRC16)
//   2) ACK handshake
//
// Notes: Simulation only. TX must never drive board USB taps in hardware.
//////////////////////////////////////////////////////////////////////////////////

module tb_usb_fs_rx;

    logic clk_48mhz = 1'b0;
    logic reset     = 1'b1;
    logic clk;
    assign clk = clk_48mhz;

    always #10.4167 clk_48mhz = ~clk_48mhz;

    logic [1:0] bit_phase = 2'b00;
    logic       bit_strobe_stim;
    always @(posedge clk_48mhz) begin
        if (reset)
            bit_phase <= 2'b00;
        else
            bit_phase <= bit_phase + 2'b01;
    end
    assign bit_strobe_stim = (bit_phase == 2'b00) && !reset;

    logic tx_oe, tx_dp, tx_dn;
    logic dp, dn;
    assign dp = tx_oe ? tx_dp : 1'b1;
    assign dn = tx_oe ? tx_dn : 1'b0;

    logic        rx_bit_strobe;
    logic        pkt_start;
    logic        pkt_end;
    logic [3:0]  pid;
    logic [6:0]  addr;
    logic [3:0]  endp;
    logic [10:0] frame_num;
    logic        rx_data_put;
    logic [7:0]  rx_data;
    logic        valid_packet;

    usb_fs_rx dut (
        .clk_48mhz   (clk_48mhz),
        .clk         (clk),
        .reset       (reset),
        .dp          (dp),
        .dn          (dn),
        .bit_strobe  (rx_bit_strobe),
        .pkt_start   (pkt_start),
        .pkt_end     (pkt_end),
        .pid         (pid),
        .addr        (addr),
        .endp        (endp),
        .frame_num   (frame_num),
        .rx_data_put (rx_data_put),
        .rx_data     (rx_data),
        .valid_packet(valid_packet)
    );

    logic       tx_pkt_start;
    logic       tx_pkt_end;
    logic [3:0] tx_pid;
    logic       tx_data_avail;
    logic       tx_data_get;
    logic [7:0] tx_data;

    usb_fs_tx stim_tx (
        .clk_48mhz    (clk_48mhz),
        .clk          (clk),
        .reset        (reset),
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
    logic [7:0] payload [0:DATA0_LEN-1];
    int         payload_idx;
    logic       sending_data;

    assign tx_data_avail = sending_data && (payload_idx < DATA0_LEN);
    assign tx_data       = payload[payload_idx];

    always @(posedge clk) begin
        if (reset) begin
            payload_idx <= 0;
        end else if (tx_pkt_start) begin
            payload_idx <= 0;
        end else if (tx_data_get && tx_data_avail) begin
            payload_idx <= payload_idx + 1;
        end
    end

    // Fixed capture buffer (avoid 2018.2 dynamic-type compare limits)
    localparam int MAX_BYTES = 16;
    logic [7:0] cap_bytes [0:MAX_BYTES-1];
    int         cap_count;
    int         packets_seen;
    int         errors;
    logic [3:0] last_pid;
    logic       last_valid;

    always @(posedge clk) begin
        if (reset) begin
            cap_count    <= 0;
            packets_seen <= 0;
            last_pid     <= '0;
            last_valid   <= 1'b0;
        end else begin
            if (pkt_start)
                cap_count <= 0;
            if (rx_data_put && cap_count < MAX_BYTES) begin
                cap_bytes[cap_count] <= rx_data;
                cap_count            <= cap_count + 1;
            end
            if (pkt_end) begin
                packets_seen <= packets_seen + 1;
                last_pid     <= pid;
                last_valid   <= valid_packet;
                $display("%0t PACKET end pid=0x%0h valid=%0b nbytes=%0d",
                         $time, pid, valid_packet, cap_count);
            end
        end
    end

    localparam logic [3:0] PID_ACK   = 4'b0010;
    localparam logic [3:0] PID_DATA0 = 4'b0011;

    task automatic wait_idle_bits(int n);
        repeat (n) @(posedge bit_strobe_stim);
    endtask

    task automatic send_data0();
        sending_data = 1'b1;
        payload[0] = 8'h00;
        payload[1] = 8'hA5;
        payload[2] = 8'h5A;
        tx_pid = PID_DATA0;
        @(posedge clk);
        tx_pkt_start = 1'b1;
        @(posedge clk);
        tx_pkt_start = 1'b0;
        wait (tx_pkt_end === 1'b1);
        @(posedge clk);
        sending_data = 1'b0;
        wait_idle_bits(16);
    endtask

    task automatic send_ack();
        sending_data = 1'b0;
        tx_pid = PID_ACK;
        @(posedge clk);
        tx_pkt_start = 1'b1;
        @(posedge clk);
        tx_pkt_start = 1'b0;
        wait (tx_pkt_end === 1'b1);
        @(posedge clk);
        wait_idle_bits(16);
    endtask

    // usb_fs_rx shifts CRC16 bytes out on rx_data for DATA PIDs; valid_packet
    // still reflects CRC OK. Expect payload + 2 CRC bytes.
    task automatic expect_data0();
        int timeout;
        timeout = 0;
        while (packets_seen == 0 && timeout < 50000) begin
            @(posedge clk);
            timeout++;
        end
        if (packets_seen == 0) begin
            $error("timeout waiting for DATA0");
            errors++;
            return;
        end
        if (last_pid !== PID_DATA0) begin
            $error("DATA0 pid: got 0x%0h", last_pid);
            errors++;
        end
        if (!last_valid) begin
            $error("DATA0 valid_packet=0");
            errors++;
        end
        if (cap_count !== DATA0_LEN + 2) begin
            $error("DATA0 byte count: got %0d expected %0d (payload+CRC16)",
                   cap_count, DATA0_LEN + 2);
            errors++;
        end else begin
            if (cap_bytes[0] !== 8'h00 || cap_bytes[1] !== 8'hA5 ||
                cap_bytes[2] !== 8'h5A) begin
                $error("DATA0 payload mismatch: %02h %02h %02h",
                       cap_bytes[0], cap_bytes[1], cap_bytes[2]);
                errors++;
            end else begin
                $display("DATA0 OK payload=00 A5 5A crc=%02h %02h",
                         cap_bytes[3], cap_bytes[4]);
            end
        end
        packets_seen = 0;
    endtask

    task automatic expect_ack();
        int timeout;
        timeout = 0;
        while (packets_seen == 0 && timeout < 50000) begin
            @(posedge clk);
            timeout++;
        end
        if (packets_seen == 0) begin
            $error("timeout waiting for ACK");
            errors++;
            return;
        end
        if (last_pid !== PID_ACK) begin
            $error("ACK pid: got 0x%0h", last_pid);
            errors++;
        end
        if (!last_valid) begin
            $error("ACK valid_packet=0");
            errors++;
        end
        if (cap_count !== 0) begin
            $error("ACK unexpected data bytes: %0d", cap_count);
            errors++;
        end else begin
            $display("ACK OK");
        end
        packets_seen = 0;
    endtask

    initial begin
        tx_pkt_start = 1'b0;
        sending_data = 1'b0;
        errors       = 0;
        packets_seen = 0;

        $display("tb_usb_fs_rx: XSim DATA0 + ACK bring-up");
        repeat (32) @(posedge clk_48mhz);
        reset = 1'b0;
        wait_idle_bits(8);

        send_data0();
        repeat (20) @(posedge clk);
        expect_data0();

        send_ack();
        repeat (20) @(posedge clk);
        expect_ack();

        if (errors == 0)
            $display("tb_usb_fs_rx: PASS");
        else
            $display("tb_usb_fs_rx: FAIL (%0d errors)", errors);

        $finish;
    end

    initial begin
        #2ms;
        $error("global timeout");
        $finish;
    end

endmodule
