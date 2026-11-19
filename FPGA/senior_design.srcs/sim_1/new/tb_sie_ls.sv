`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: tb_sie_ls
// Purpose: Directed Low-Speed path through selectable soft RX (is_ls=1):
//   - mute kills until line attach / speed lock
//   - good DATA0 / ACK (no kill)
//   - corrupted DATA0 → kill threat 0x5 + clear
//   - SETUP + config HID interface → kill threat 0x1
// Stimulus: usb_fs_tx bit_strobe @ 32× + D+/D− wire-swap for LS J/K polarity.
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module tb_sie_ls;

    logic clk_48m = 1'b0;
    logic rst     = 1'b1;
    always #10.4167 clk_48m = ~clk_48m;

    // LS bit time = 32 clocks @ 48 MHz
    logic [4:0] bit_phase = 5'd0;
    logic       bit_strobe_stim;
    always @(posedge clk_48m) begin
        if (rst) bit_phase <= 5'd0;
        else     bit_phase <= bit_phase + 5'd1;
    end
    assign bit_strobe_stim = (bit_phase == 5'd0) && !rst;

    logic tx_oe, tx_dp, tx_dn;
    logic corrupt;
    logic line_attached; // 0 = SE0 (unplugged), 1 = LS idle J when bus free

    // usb_fs_tx drives FS polarity; swap D+/D− so idle J is LS (01).
    logic dp0, dm0;
    always_comb begin
        if (tx_oe) begin
            dp0 = tx_dn ^ corrupt;
            dm0 = tx_dp;
        end else if (line_attached) begin
            dp0 = 1'b0;
            dm0 = 1'b1;
        end else begin
            dp0 = 1'b0;
            dm0 = 1'b0;
        end
    end

    logic [`NUM_PORTS-1:0] dp;
    logic [`NUM_PORTS-1:0] dm;
    logic [`NUM_PORTS-1:0] clear_fault;
    logic [`NUM_PORTS-1:0] manual_kill;
    logic [2:0]            policy_mode [`NUM_PORTS-1:0];
    logic [`NUM_PORTS-1:0] approve_hid;

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

    assign dp = { {(`NUM_PORTS-1){1'b0}}, dp0 };
    assign dm = { {(`NUM_PORTS-1){1'b0}}, dm0 };

    sniffer_wrapper dut (
        .clk_48m           (clk_48m),
        .rst               (rst),
        .dp                (dp),
        .dm                (dm),
        .clear_fault       (clear_fault),
        .manual_kill       (manual_kill),
        .policy_mode       (policy_mode),
        .approve_hid       (approve_hid),
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

    localparam logic [3:0] PID_ACK   = 4'b0010;
    localparam logic [3:0] PID_DATA0 = 4'b0011;
    localparam logic [3:0] PID_DATA1 = 4'b1011;
    localparam logic [3:0] PID_SETUP = 4'b1101;
    localparam int DATA0_LEN = 3;
    localparam int MAX_TX    = 64;

    logic [7:0] tx_buf [0:MAX_TX-1];
    int         tx_n;
    int         tx_idx;
    logic       sending;

    assign tx_data_avail = sending && (tx_idx < tx_n);
    assign tx_data       = tx_buf[tx_idx];

    always @(posedge clk_48m) begin
        if (rst) tx_idx <= 0;
        else if (tx_pkt_start) tx_idx <= 0;
        else if (tx_data_get && tx_data_avail) tx_idx <= tx_idx + 1;
    end

    int         packets_seen;
    int         errors;
    logic [3:0] last_pid;
    logic       last_crc_ok;
    int         cap_count;
    logic [7:0] cap_bytes [0:31];

    always @(posedge clk_48m) begin
        if (rst) begin
            packets_seen <= 0;
            last_pid     <= '0;
            last_crc_ok  <= 1'b0;
            cap_count    <= 0;
        end else begin
            if (pkt_start[0])
                cap_count <= 0;
            if (data_valid[0] && cap_count < 32) begin
                cap_bytes[cap_count] <= data[0];
                cap_count            <= cap_count + 1;
            end
            if (pkt_end[0]) begin
                packets_seen <= packets_seen + 1;
                last_pid     <= pid[0];
                last_crc_ok  <= crc_ok[0];
                $display("%0t LS pkt_end pid=0x%0h crc_ok=%0b nbytes=%0d kill=%0b threat=0x%0h",
                         $time, pid[0], crc_ok[0], cap_count, kill[0], threat_code[0]);
            end
        end
    end

    // Same residue search as tb_enum_e2e / tb_demo_threat (RX expects final 5'b01100).
    function automatic [4:0] usb_crc5(input [10:0] din);
        logic [4:0] crc;
        logic [4:0] try_c;
        logic       inv;
        logic       found;
        integer     i, c;
        found = 1'b0;
        usb_crc5 = 5'h00;
        for (c = 0; c < 32; c = c + 1) begin
            if (!found) begin
                crc = 5'b11111;
                for (i = 0; i < 11; i = i + 1) begin
                    inv    = din[i] ^ crc[4];
                    crc[4] = crc[3];
                    crc[3] = crc[2];
                    crc[2] = crc[1] ^ inv;
                    crc[1] = crc[0];
                    crc[0] = inv;
                end
                try_c = c[4:0];
                for (i = 0; i < 5; i = i + 1) begin
                    inv    = try_c[i] ^ crc[4];
                    crc[4] = crc[3];
                    crc[3] = crc[2];
                    crc[2] = crc[1] ^ inv;
                    crc[1] = crc[0];
                    crc[0] = inv;
                end
                if (crc == 5'b01100) begin
                    usb_crc5 = try_c;
                    found    = 1'b1;
                end
            end
        end
    endfunction

    task automatic wait_idle_bits(int n);
        repeat (n) @(posedge bit_strobe_stim);
    endtask

    task automatic wait_rx_packet(input int base);
        int timeout;
        timeout = 0;
        while (packets_seen == base && timeout < 200000) begin
            @(posedge clk_48m);
            timeout++;
        end
        if (packets_seen == base) begin
            $error("timeout waiting for LS packet");
            errors++;
        end
    endtask

    task automatic send_packet(input [3:0] pid_i, input int nbytes, input logic do_corrupt);
        int base;
        base = packets_seen;
        sending = 1'b1;
        tx_n    = nbytes;
        tx_pid  = pid_i;
        corrupt = 1'b0;
        @(posedge clk_48m);
        tx_pkt_start = 1'b1;
        @(posedge clk_48m);
        tx_pkt_start = 1'b0;
        if (do_corrupt) begin
            repeat (40) @(posedge bit_strobe_stim);
            corrupt = 1'b1;
            @(posedge bit_strobe_stim);
            corrupt = 1'b0;
        end
        wait (tx_pkt_end === 1'b1);
        @(posedge clk_48m);
        sending = 1'b0;
        wait_idle_bits(16);
        wait_rx_packet(base);
    endtask

    task automatic send_data0(input logic do_corrupt);
        tx_buf[0] = 8'h00;
        tx_buf[1] = 8'hA5;
        tx_buf[2] = 8'h5A;
        send_packet(PID_DATA0, DATA0_LEN, do_corrupt);
    endtask

    task automatic send_ack();
        send_packet(PID_ACK, 0, 1'b0);
    endtask

    task automatic send_setup_token(input [6:0] addr_i, input [3:0] endp_i);
        logic [10:0] field;
        logic [4:0]  c5;
        field = {endp_i, addr_i};
        c5 = usb_crc5(field);
        tx_buf[0] = {endp_i[0], addr_i};
        tx_buf[1] = {c5, endp_i[3:1]};
        send_packet(PID_SETUP, 2, 1'b0);
        if (last_pid !== PID_SETUP || !last_crc_ok) begin
            $error("SETUP token decode pid=%h crc=%0b", last_pid, last_crc_ok);
            errors++;
        end
    endtask

    task automatic send_data_bytes(input [3:0] pid_i, input int n);
        send_packet(pid_i, n, 1'b0);
        if (last_pid !== pid_i || !last_crc_ok) begin
            $error("DATA pid=%h crc_ok=%0b", last_pid, last_crc_ok);
            errors++;
        end
    endtask

    initial begin

        begin : __hid_policy_init
            integer __pi;
            for (__pi = 0; __pi < `NUM_PORTS; __pi = __pi + 1)
                policy_mode[__pi] = 3'd0;
            approve_hid = '0;
        end
        tx_pkt_start  = 1'b0;
        sending       = 1'b0;
        corrupt       = 1'b0;
        line_attached = 1'b0;
        clear_fault   = '0;
        manual_kill   = '0;
        errors        = 0;
        packets_seen  = 0;
        tx_n          = 0;

        $display("tb_sie_ls: selectable soft RX Low-Speed directed");
        repeat (32) @(posedge clk_48m);
        rst = 1'b0;

        // Mute until attach/speed lock
        repeat (2000) @(posedge clk_48m);
        if (kill[0] || packets_seen != 0) begin
            $error("activity before LS attach kill=%0b pkts=%0d", kill[0], packets_seen);
            errors++;
        end else
            $display("mute-before-lock OK");

        line_attached = 1'b1;
        wait_idle_bits(16);

        // Good DATA0
        send_data0(1'b0);
        if (last_pid !== PID_DATA0 || !last_crc_ok || cap_count !== DATA0_LEN) begin
            $error("good LS DATA0"); errors++;
        end else if (cap_bytes[0] !== 8'h00 || cap_bytes[1] !== 8'hA5 ||
                     cap_bytes[2] !== 8'h5A) begin
            $error("good LS DATA0 payload"); errors++;
        end
        if (kill[0]) begin $error("good LS DATA0 kill"); errors++; end
        else $display("good LS DATA0 OK");

        send_ack();
        if (last_pid !== PID_ACK || !last_crc_ok || kill[0]) begin
            $error("LS ACK"); errors++;
        end else
            $display("LS ACK OK");

        // Corrupt → CRC kill
        send_data0(1'b1);
        repeat (8) @(posedge clk_48m);
        if (last_crc_ok) begin $error("corrupt expected fail"); errors++; end
        if (!kill[0] || threat_code[0] !== `THREAT_CRC_TOKEN_FAULT) begin
            $error("corrupt LS kill/threat"); errors++;
        end else
            $display("corrupt LS DATA0 OK threat=0x%0h", threat_code[0]);

        clear_fault[0] = 1'b1;
        @(posedge clk_48m);
        clear_fault[0] = 1'b0;
        repeat (4) @(posedge clk_48m);
        if (kill[0] || threat_code[0] !== `THREAT_NO_FAULT) begin
            $error("clear after CRC"); errors++;
        end else
            $display("clear after CRC OK");

        // HID class on storage-only → 0x1 (LS mouse/demo path)
        send_setup_token(7'd0, 4'h0);
        tx_buf[0] = 8'h80; tx_buf[1] = 8'h06;
        tx_buf[2] = 8'h00; tx_buf[3] = 8'h01;
        tx_buf[4] = 8'h00; tx_buf[5] = 8'h00;
        tx_buf[6] = 8'h12; tx_buf[7] = 8'h00;
        send_data_bytes(PID_DATA0, 8);

        tx_buf[0]  = 8'h12; tx_buf[1]  = 8'h01;
        tx_buf[2]  = 8'h00; tx_buf[3]  = 8'h02;
        tx_buf[4]  = 8'h00; tx_buf[5]  = 8'h00; tx_buf[6] = 8'h00;
        tx_buf[7]  = 8'h08;
        tx_buf[8]  = 8'h34; tx_buf[9]  = 8'h12;
        tx_buf[10] = 8'h78; tx_buf[11] = 8'h56;
        tx_buf[12] = 8'h00; tx_buf[13] = 8'h01;
        tx_buf[14] = 8'h00; tx_buf[15] = 8'h00;
        tx_buf[16] = 8'h00; tx_buf[17] = 8'h01;
        send_data_bytes(PID_DATA1, 18);
        repeat (4) @(posedge clk_48m);

        if (!device_desc_valid[0] || kill[0]) begin
            $error("LS device path: valid=%0b kill=%0b", device_desc_valid[0], kill[0]);
            errors++;
        end

        send_setup_token(7'd0, 4'h0);
        tx_buf[0] = 8'h80; tx_buf[1] = 8'h06;
        tx_buf[2] = 8'h00; tx_buf[3] = 8'h02;
        tx_buf[4] = 8'h00; tx_buf[5] = 8'h00;
        tx_buf[6] = 8'h12; tx_buf[7] = 8'h00;
        send_data_bytes(PID_DATA0, 8);

        tx_buf[0] = 8'h09; tx_buf[1] = 8'h02;
        tx_buf[2] = 8'h12; tx_buf[3] = 8'h00;
        tx_buf[4] = 8'h01; tx_buf[5] = 8'h01;
        tx_buf[6] = 8'h00; tx_buf[7] = 8'hA0;
        tx_buf[8] = 8'h32;
        tx_buf[9]  = 8'h09; tx_buf[10] = 8'h04;
        tx_buf[11] = 8'h00; tx_buf[12] = 8'h00;
        tx_buf[13] = 8'h01; tx_buf[14] = 8'h03; // HID
        tx_buf[15] = 8'h01; tx_buf[16] = 8'h02;
        tx_buf[17] = 8'h00;
        send_data_bytes(PID_DATA1, 18);
        repeat (8) @(posedge clk_48m);

        if (!intf_class_valid[0] || intf_class[0] !== 8'h03) begin
            $error("LS intf_class=%h valid=%0b", intf_class[0], intf_class_valid[0]);
            errors++;
        end
        if (!kill[0] || threat_code[0] !== `THREAT_UNAUTHORIZED_HID) begin
            $error("expected LS HID kill 0x1, got kill=%0b threat=%0h",
                   kill[0], threat_code[0]);
            errors++;
        end else
            $display("LS HID kill OK threat=%0h", threat_code[0]);

        if (errors == 0) $display("tb_sie_ls: PASS");
        else             $display("tb_sie_ls: FAIL (%0d errors)", errors);
        $finish;
    end

    initial begin
        #80ms;
        $error("global timeout");
        $finish;
    end

endmodule
