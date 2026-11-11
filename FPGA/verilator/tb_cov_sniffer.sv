// Coverage TB for sniffer_block: manual, CRC, SETUP/enum/HID, handshake,
// and enumeration_analysis edge paths (dead-code / line coverage).

`timescale 1ns / 1ps
`include "defines.svh"

module tb_cov_sniffer;
    logic clk_48m = 1'b0;
    logic rst     = 1'b1;
    always #10.4167 clk_48m = ~clk_48m;

    logic [1:0] bit_phase = 2'b00;
    logic       bit_strobe;
    always @(posedge clk_48m) begin
        if (rst) bit_phase <= 2'b00;
        else     bit_phase <= bit_phase + 2'b01;
    end
    assign bit_strobe = (bit_phase == 2'b00) && !rst;

    logic tx_oe, tx_dp, tx_dn, corrupt;
    logic dp, dm;
    assign dp = ((tx_oe ? tx_dp : 1'b1) ^ corrupt);
    assign dm = (tx_oe ? tx_dn : 1'b0);

    logic clear_fault = 1'b0;
    logic clear_fault_np = 1'b0;
    logic manual_kill = 1'b0;
    logic kill;
    logic [3:0] threat_code;
    logic [7:0] port_status;
    logic [15:0] vid, pid_dev;
    logic [7:0]  dev_class, intf_class;
    logic device_desc_valid, intf_class_valid;
    logic pkt_start, pkt_end, data_valid, crc_ok;
    logic [3:0] pid, endp;
    logic [6:0] addr;
    logic [7:0] data;

    sniffer_block #(
        .POLICY_STORAGE_ONLY(1'b1)
    ) dut (
        .clk_48m           (clk_48m),
        .rst               (rst),
        .dp                (dp),
        .dm                (dm),
        .clear_fault       (clear_fault),
        .manual_kill       (manual_kill),
        .pkt_start         (pkt_start),
        .pkt_end           (pkt_end),
        .pid               (pid),
        .addr              (addr),
        .endp              (endp),
        .data_valid        (data_valid),
        .data              (data),
        .crc_ok            (crc_ok),
        .port_status       (port_status),
        .vid               (vid),
        .pid_dev           (pid_dev),
        .dev_class         (dev_class),
        .intf_class        (intf_class),
        .device_desc_valid (device_desc_valid),
        .intf_class_valid  (intf_class_valid),
        .kill              (kill),
        .threat_code       (threat_code)
    );

    // Second instance: storage-only off so HID class does not assert threat 0x1
    // (exercises POLICY_STORAGE_ONLY=0 side of sniffer_block assigns).
    logic kill_np;
    logic [3:0] threat_np;
    logic [7:0] intf_np;
    logic intf_np_valid;
    logic [7:0] ps_np;
    logic [15:0] vid_np, piddev_np;
    logic [7:0]  devc_np;
    logic ddv_np;
    logic ps_np_s, pe_np, dv_np, cok_np;
    logic [3:0] upid_np, endp_np;
    logic [6:0] addr_np;
    logic [7:0] data_np;

    sniffer_block #(
        .POLICY_STORAGE_ONLY(1'b0)
    ) dut_no_policy (
        .clk_48m           (clk_48m),
        .rst               (rst),
        .dp                (dp),
        .dm                (dm),
        .clear_fault       (clear_fault_np),
        .manual_kill       (1'b0),
        .pkt_start         (ps_np_s),
        .pkt_end           (pe_np),
        .pid               (upid_np),
        .addr              (addr_np),
        .endp              (endp_np),
        .data_valid        (dv_np),
        .data              (data_np),
        .crc_ok            (cok_np),
        .port_status       (ps_np),
        .vid               (vid_np),
        .pid_dev           (piddev_np),
        .dev_class         (devc_np),
        .intf_class        (intf_np),
        .device_desc_valid (ddv_np),
        .intf_class_valid  (intf_np_valid),
        .kill              (kill_np),
        .threat_code       (threat_np)
    );

    localparam [3:0] PID_SETUP = 4'b1101;
    localparam [3:0] PID_DATA0 = 4'b0011;
    localparam [3:0] PID_DATA1 = 4'b1011;
    localparam [3:0] PID_ACK   = 4'b0010;
    localparam [3:0] PID_IN    = 4'b1001;

    logic [7:0] tx_buf [0:63];
    int         tx_n;
    int         tx_idx;
    logic       sending;

    logic       tx_pkt_start = 1'b0;
    logic       tx_pkt_end;
    logic [3:0] tx_pid = 4'h0;
    logic       tx_data_avail;
    logic       tx_data_get;
    logic [7:0] tx_data;

    usb_fs_tx stim_tx (
        .clk_48mhz    (clk_48m),
        .clk          (clk_48m),
        .reset        (rst),
        .bit_strobe   (bit_strobe),
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

    assign tx_data_avail = sending && (tx_idx < tx_n);
    assign tx_data       = tx_buf[tx_idx];

    always @(posedge clk_48m) begin
        if (rst) tx_idx <= 0;
        else if (tx_pkt_start) tx_idx <= 0;
        else if (tx_data_get && tx_data_avail) tx_idx <= tx_idx + 1;
    end

    int packets_seen = 0;
    logic [3:0] last_pid = '0;
    logic       last_crc_ok = 1'b0;
    always @(posedge clk_48m) begin
        if (rst) begin
            packets_seen <= 0;
            last_pid     <= '0;
            last_crc_ok  <= 1'b0;
        end else if (pkt_end) begin
            packets_seen <= packets_seen + 1;
            last_pid     <= pid;
            last_crc_ok  <= crc_ok;
        end
    end

    int errors;

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
        repeat (n) @(posedge bit_strobe);
    endtask

    task automatic wait_packet(input int base);
        int timeout;
        timeout = 0;
        while (packets_seen == base && timeout < 80000) begin
            @(posedge clk_48m);
            timeout++;
        end
        if (packets_seen == base) begin
            $error("timeout waiting for packet");
            errors++;
        end
    endtask

    task automatic send_packet(input [3:0] pid_i, input int nbytes, input logic do_corrupt);
        int base;
        base = packets_seen;
        sending = (nbytes > 0);
        tx_n = nbytes;
        tx_pid = pid_i;
        corrupt = 1'b0;
        @(posedge clk_48m);
        tx_pkt_start = 1'b1;
        @(posedge clk_48m);
        tx_pkt_start = 1'b0;
        if (do_corrupt) begin
            repeat (40) @(posedge bit_strobe);
            corrupt = 1'b1;
            @(posedge bit_strobe);
            corrupt = 1'b0;
        end
        wait (tx_pkt_end === 1'b1);
        @(posedge clk_48m);
        sending = 1'b0;
        wait_idle_bits(16);
        wait_packet(base);
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
            $error("SETUP token pid=%h crc=%0b", last_pid, last_crc_ok);
            errors++;
        end
    endtask

    task automatic send_data_bytes(input [3:0] pid_i, input int n, input logic do_corrupt);
        send_packet(pid_i, n, do_corrupt);
    endtask

    task automatic send_handshake(input [3:0] pid_i);
        send_packet(pid_i, 0, 1'b0);
    endtask

    task automatic clear_both();
        clear_fault = 1'b1;
        clear_fault_np = 1'b1;
        @(posedge clk_48m);
        clear_fault = 1'b0;
        clear_fault_np = 1'b0;
        repeat (4) @(posedge clk_48m);
    endtask

    task automatic send_in_token(input [6:0] addr_i, input [3:0] endp_i);
        logic [10:0] field;
        logic [4:0]  c5;
        field = {endp_i, addr_i};
        c5 = usb_crc5(field);
        tx_buf[0] = {endp_i[0], addr_i};
        tx_buf[1] = {c5, endp_i[3:1]};
        send_packet(PID_IN, 2, 1'b0);
    endtask

    initial begin
        int base;
        errors = 0;
        corrupt = 1'b0;
        sending = 1'b0;
        tx_n = 0;
        tx_pkt_start = 1'b0;

        repeat (32) @(posedge clk_48m);
        rst = 1'b0;
        wait_idle_bits(8);

        // ----------------------------------------------------------
        // Manual kill + clear
        // ----------------------------------------------------------
        manual_kill = 1'b1;
        repeat (8) @(posedge clk_48m);
        if (!kill || threat_code !== `THREAT_MANUAL_HOST_KILL) begin
            $error("manual kill"); errors++;
        end
        manual_kill = 1'b0;
        clear_both();

        // Handshake (ACK) — usb_fs_tx EOP-only path
        send_handshake(PID_ACK);
        if (last_pid !== PID_ACK || !last_crc_ok) begin
            $error("ACK"); errors++;
        end

        // IN token — another TOKEN_DATA path
        send_in_token(7'd0, 4'h0);

        // Good short DATA0
        tx_buf[0] = 8'h00; tx_buf[1] = 8'hA5; tx_buf[2] = 8'h5A;
        send_data_bytes(PID_DATA0, 3, 1'b0);
        if (!last_crc_ok) begin
            $error("good CRC"); errors++;
        end

        // Corrupt DATA0 → CRC kill 0x5
        tx_buf[0] = 8'h00; tx_buf[1] = 8'hA5; tx_buf[2] = 8'h5A;
        send_data_bytes(PID_DATA0, 3, 1'b1);
        repeat (8) @(posedge clk_48m);
        if (!kill || threat_code !== `THREAT_CRC_TOKEN_FAULT) begin
            $error("CRC kill"); errors++;
        end
        clear_both();

        // ----------------------------------------------------------
        // Enum edge: non-GET_DESCRIPTOR SETUP → ST_IDLE
        // ----------------------------------------------------------
        send_setup_token(7'd0, 4'h0);
        tx_buf[0] = 8'h00; tx_buf[1] = 8'h09; // SET_CONFIGURATION
        tx_buf[2] = 8'h01; tx_buf[3] = 8'h00;
        tx_buf[4] = 8'h00; tx_buf[5] = 8'h00;
        tx_buf[6] = 8'h00; tx_buf[7] = 8'h00;
        send_data_bytes(PID_DATA0, 8, 1'b0);

        // Enum edge: GET_DESCRIPTOR string (0x03) → idle (unsupported dtype)
        send_setup_token(7'd0, 4'h0);
        tx_buf[0] = 8'h80; tx_buf[1] = 8'h06;
        tx_buf[2] = 8'h00; tx_buf[3] = 8'h03;
        tx_buf[4] = 8'h00; tx_buf[5] = 8'h00;
        tx_buf[6] = 8'hFF; tx_buf[7] = 8'h00;
        send_data_bytes(PID_DATA0, 8, 1'b0);

        // ----------------------------------------------------------
        // Device descriptor (telemetry)
        // ----------------------------------------------------------
        send_setup_token(7'd0, 4'h0);
        tx_buf[0] = 8'h80; tx_buf[1] = 8'h06;
        tx_buf[2] = 8'h00; tx_buf[3] = 8'h01;
        tx_buf[4] = 8'h00; tx_buf[5] = 8'h00;
        tx_buf[6] = 8'h12; tx_buf[7] = 8'h00;
        send_data_bytes(PID_DATA0, 8, 1'b0);

        // Abort mid-desc with CRC fail on device DATA1
        tx_buf[0]  = 8'h12; tx_buf[1]  = 8'h01;
        tx_buf[2]  = 8'h00; tx_buf[3]  = 8'h02;
        tx_buf[4]  = 8'h00; tx_buf[5]  = 8'h00; tx_buf[6] = 8'h00;
        tx_buf[7]  = 8'h40;
        tx_buf[8]  = 8'h34; tx_buf[9]  = 8'h12;
        tx_buf[10] = 8'h78; tx_buf[11] = 8'h56;
        tx_buf[12] = 8'h00; tx_buf[13] = 8'h01;
        tx_buf[14] = 8'h00; tx_buf[15] = 8'h00;
        tx_buf[16] = 8'h00; tx_buf[17] = 8'h01;
        send_data_bytes(PID_DATA1, 18, 1'b1);
        repeat (8) @(posedge clk_48m);
        // May have killed on CRC — clear for clean enum
        clear_both();

        // Good device descriptor
        send_setup_token(7'd0, 4'h0);
        tx_buf[0] = 8'h80; tx_buf[1] = 8'h06;
        tx_buf[2] = 8'h00; tx_buf[3] = 8'h01;
        tx_buf[4] = 8'h00; tx_buf[5] = 8'h00;
        tx_buf[6] = 8'h12; tx_buf[7] = 8'h00;
        send_data_bytes(PID_DATA0, 8, 1'b0);

        tx_buf[0]  = 8'h12; tx_buf[1]  = 8'h01;
        tx_buf[2]  = 8'h00; tx_buf[3]  = 8'h02;
        tx_buf[4]  = 8'h00; tx_buf[5]  = 8'h00; tx_buf[6] = 8'h00;
        tx_buf[7]  = 8'h40;
        tx_buf[8]  = 8'h34; tx_buf[9]  = 8'h12;
        tx_buf[10] = 8'h78; tx_buf[11] = 8'h56;
        tx_buf[12] = 8'h00; tx_buf[13] = 8'h01;
        tx_buf[14] = 8'h00; tx_buf[15] = 8'h00;
        tx_buf[16] = 8'h00; tx_buf[17] = 8'h01;
        send_data_bytes(PID_DATA1, 18, 1'b0);
        repeat (4) @(posedge clk_48m);
        if (!device_desc_valid || vid !== 16'h1234 || pid_dev !== 16'h5678) begin
            $error("device_desc vid=%h pid=%h valid=%0b", vid, pid_dev, device_desc_valid);
            errors++;
        end

        // ----------------------------------------------------------
        // Config w/ endpoint desc then HID interface (scan skip + hit)
        // want_len from wLength (0x20) — exercises setup[6] path
        // ----------------------------------------------------------
        send_setup_token(7'd0, 4'h0);
        tx_buf[0] = 8'h80; tx_buf[1] = 8'h06;
        tx_buf[2] = 8'h00; tx_buf[3] = 8'h02;
        tx_buf[4] = 8'h00; tx_buf[5] = 8'h00;
        tx_buf[6] = 8'h20; tx_buf[7] = 8'h00; // wLength=32
        send_data_bytes(PID_DATA0, 8, 1'b0);

        // config(9) + endpoint(7) + interface HID(9) + pad
        tx_buf[0] = 8'h09; tx_buf[1] = 8'h02;
        tx_buf[2] = 8'h20; tx_buf[3] = 8'h00;
        tx_buf[4] = 8'h01; tx_buf[5] = 8'h01;
        tx_buf[6] = 8'h00; tx_buf[7] = 8'hA0;
        tx_buf[8] = 8'h32;
        // endpoint descriptor (type 0x05) — skipped by scan
        tx_buf[9]  = 8'h07; tx_buf[10] = 8'h05;
        tx_buf[11] = 8'h81; tx_buf[12] = 8'h03;
        tx_buf[13] = 8'h08; tx_buf[14] = 8'h00; tx_buf[15] = 8'h0A;
        // interface HID
        tx_buf[16] = 8'h09; tx_buf[17] = 8'h04;
        tx_buf[18] = 8'h00; tx_buf[19] = 8'h00;
        tx_buf[20] = 8'h01; tx_buf[21] = 8'h03;
        tx_buf[22] = 8'h01; tx_buf[23] = 8'h02;
        tx_buf[24] = 8'h00;
        tx_buf[25] = 8'h00; tx_buf[26] = 8'h00; tx_buf[27] = 8'h00;
        tx_buf[28] = 8'h00; tx_buf[29] = 8'h00; tx_buf[30] = 8'h00;
        tx_buf[31] = 8'h00;
        send_data_bytes(PID_DATA1, 32, 1'b0);
        repeat (16) @(posedge clk_48m);

        if (!intf_class_valid || intf_class !== 8'h03) begin
            $error("intf_class=%h valid=%0b", intf_class, intf_class_valid);
            errors++;
        end
        if (!kill || threat_code !== `THREAT_UNAUTHORIZED_HID) begin
            $error("HID kill expect 0x1 got kill=%0b threat=%0h", kill, threat_code);
            errors++;
        end
        // Policy-off instance latches HID class but must not isolate for 0x1
        if (!intf_np_valid || intf_np !== 8'h03) begin
            $error("no-policy intf=%h valid=%0b", intf_np, intf_np_valid);
            errors++;
        end
        if (kill_np && threat_np === `THREAT_UNAUTHORIZED_HID) begin
            $error("no-policy must not HID-kill"); errors++;
        end
        if (kill_np) begin
            $error("no-policy unexpected kill threat=%0h", threat_np); errors++;
        end

        clear_both();

        // ----------------------------------------------------------
        // Config with dlen==0 after config header → ST_SCAN_INTF abort
        // ----------------------------------------------------------
        send_setup_token(7'd0, 4'h0);
        tx_buf[0] = 8'h80; tx_buf[1] = 8'h06;
        tx_buf[2] = 8'h00; tx_buf[3] = 8'h02;
        tx_buf[4] = 8'h00; tx_buf[5] = 8'h00;
        tx_buf[6] = 8'h0A; tx_buf[7] = 8'h00;
        send_data_bytes(PID_DATA0, 8, 1'b0);

        tx_buf[0] = 8'h09; tx_buf[1] = 8'h02;
        tx_buf[2] = 8'h0A; tx_buf[3] = 8'h00;
        tx_buf[4] = 8'h01; tx_buf[5] = 8'h01;
        tx_buf[6] = 8'h00; tx_buf[7] = 8'hA0;
        tx_buf[8] = 8'h32;
        tx_buf[9] = 8'h00; // zero-length next desc → scan abort
        send_data_bytes(PID_DATA1, 10, 1'b0);
        repeat (16) @(posedge clk_48m);

        // Config wLength=0 → clamp want_len to 64 (edge of setup decode)
        send_setup_token(7'd0, 4'h0);
        tx_buf[0] = 8'h80; tx_buf[1] = 8'h06;
        tx_buf[2] = 8'h00; tx_buf[3] = 8'h02;
        tx_buf[4] = 8'h00; tx_buf[5] = 8'h00;
        tx_buf[6] = 8'h00; tx_buf[7] = 8'h00; // wLength=0 → want_len=64
        send_data_bytes(PID_DATA0, 8, 1'b0);
        // Short DATA then stop — stays in WAIT_DESC / partial; next SETUP aborts
        tx_buf[0] = 8'h09; tx_buf[1] = 8'h02;
        tx_buf[2] = 8'h09; tx_buf[3] = 8'h00;
        tx_buf[4] = 8'h01; tx_buf[5] = 8'h01;
        tx_buf[6] = 8'h00; tx_buf[7] = 8'hA0;
        tx_buf[8] = 8'h32;
        send_data_bytes(PID_DATA1, 9, 1'b0);
        // Abort with new SETUP
        send_setup_token(7'd0, 4'h0);
        tx_buf[0] = 8'h80; tx_buf[1] = 8'h06;
        tx_buf[2] = 8'h00; tx_buf[3] = 8'h01;
        tx_buf[4] = 8'h00; tx_buf[5] = 8'h00;
        tx_buf[6] = 8'h12; tx_buf[7] = 8'h00;
        send_data_bytes(PID_DATA0, 8, 1'b0);
        // Incomplete setup data (only 4 bytes) → not 8 → ST_IDLE
        tx_buf[0] = 8'h12; tx_buf[1] = 8'h01;
        tx_buf[2] = 8'h00; tx_buf[3] = 8'h02;
        send_data_bytes(PID_DATA1, 4, 1'b0);
        repeat (8) @(posedge clk_48m);

        if (errors == 0) $display("tb_cov_sniffer: PASS");
        else             $display("tb_cov_sniffer: FAIL (%0d errors)", errors);
        $finish;
    end

    initial begin
        #100ms;
        $error("global timeout");
        $finish;
    end
endmodule
