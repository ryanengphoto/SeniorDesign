`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: tb_hid_pending_approve
// Purpose: HID-allowed default → HID config → kill 0x3 hold → approve releases;
//          clear without approve re-arms hold.
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module tb_hid_pending_approve;

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
    logic [`NUM_PORTS-1:0] dp, dm;
    assign dp = { {(`NUM_PORTS-1){1'b1}}, (tx_oe ? tx_dp : 1'b1) };
    assign dm = { {(`NUM_PORTS-1){1'b0}}, (tx_oe ? tx_dn : 1'b0) };

    logic [`NUM_PORTS-1:0] clear_fault = '0;
    logic [`NUM_PORTS-1:0] manual_kill = '0;
    logic [`NUM_PORTS-1:0] approve = '0;
    logic [2:0]            policy_mode [`NUM_PORTS-1:0];
    logic [`NUM_PORTS-1:0] kill;
    logic [3:0]            threat_code [`NUM_PORTS-1:0];
    logic [3:0]            threat_detail [`NUM_PORTS-1:0];
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

    initial begin : init_policy
        for (int pi = 0; pi < `NUM_PORTS; pi++) policy_mode[pi] = `POLICY_HID_ALLOWED;
    end

    sniffer_wrapper #(
        .POLICY_STORAGE_ONLY(1'b0)
    ) dut (
        .clk_48m           (clk_48m),
        .rst               (rst),
        .dp                (dp),
        .dm                (dm),
        .clear_fault       (clear_fault),
        .manual_kill       (manual_kill),
        .approve           (approve),
        .policy_mode       (policy_mode),
        .kill              (kill),
        .threat_code       (threat_code),
        .threat_detail     (threat_detail),
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

    localparam [3:0] PID_SETUP = 4'b1101;
    localparam [3:0] PID_DATA0 = 4'b0011;
    localparam [3:0] PID_DATA1 = 4'b1011;

    logic [7:0] tx_buf [0:63];
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

    int packets_seen;
    logic [3:0] last_pid;
    logic       last_crc_ok;
    int         errors;

    always @(posedge clk_48m) begin
        if (rst) begin
            packets_seen <= 0;
            last_pid     <= '0;
            last_crc_ok  <= 1'b0;
        end else if (pkt_end[0]) begin
            packets_seen <= packets_seen + 1;
            last_pid     <= pid[0];
            last_crc_ok  <= crc_ok[0];
        end
    end

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
        while (packets_seen == base && timeout < 80000) begin
            @(posedge clk_48m);
            timeout++;
        end
        if (packets_seen == base) begin
            $error("timeout waiting for RX packet");
            errors++;
        end
    endtask

    task automatic send_packet(input [3:0] pid_i, input int nbytes);
        int base;
        base = packets_seen;
        sending = (nbytes > 0);
        tx_n = nbytes;
        tx_pid = pid_i;
        @(posedge clk_48m);
        tx_pkt_start = 1'b1;
        @(posedge clk_48m);
        tx_pkt_start = 1'b0;
        wait (tx_pkt_end === 1'b1);
        @(posedge clk_48m);
        sending = 1'b0;
        wait_idle_bits(16);
        wait_rx_packet(base);
    endtask

    task automatic send_setup_token();
        logic [10:0] field;
        logic [4:0]  c5;
        field = {4'h0, 7'd0};
        c5 = usb_crc5(field);
        tx_buf[0] = {1'b0, 7'd0};
        tx_buf[1] = {c5, 3'b000};
        send_packet(PID_SETUP, 2);
    endtask

    task automatic send_data_bytes(input [3:0] pid_i, input int n);
        send_packet(pid_i, n);
    endtask

    initial begin
        tx_pkt_start = 1'b0;
        sending      = 1'b0;
        tx_pid       = 4'h0;
        tx_n         = 0;
        errors       = 0;
        packets_seen = 0;

        $display("tb_hid_pending_approve: HID hold 0x3 → approve");
        repeat (32) @(posedge clk_48m);
        rst = 1'b0;
        wait_idle_bits(8);

        send_setup_token();
        tx_buf[0]=8'h80; tx_buf[1]=8'h06; tx_buf[2]=8'h00; tx_buf[3]=8'h01;
        tx_buf[4]=8'h00; tx_buf[5]=8'h00; tx_buf[6]=8'h12; tx_buf[7]=8'h00;
        send_data_bytes(PID_DATA0, 8);
        tx_buf[0]=8'h12; tx_buf[1]=8'h01; tx_buf[2]=8'h00; tx_buf[3]=8'h02;
        tx_buf[4]=8'h00; tx_buf[5]=8'h00; tx_buf[6]=8'h00; tx_buf[7]=8'h40;
        tx_buf[8]=8'h34; tx_buf[9]=8'h12; tx_buf[10]=8'h78; tx_buf[11]=8'h56;
        tx_buf[12]=8'h00; tx_buf[13]=8'h01; tx_buf[14]=8'h00; tx_buf[15]=8'h00;
        tx_buf[16]=8'h00; tx_buf[17]=8'h01;
        send_data_bytes(PID_DATA1, 18);

        send_setup_token();
        tx_buf[0]=8'h80; tx_buf[1]=8'h06; tx_buf[2]=8'h00; tx_buf[3]=8'h02;
        tx_buf[4]=8'h00; tx_buf[5]=8'h00; tx_buf[6]=8'h12; tx_buf[7]=8'h00;
        send_data_bytes(PID_DATA0, 8);
        tx_buf[0]=8'h09; tx_buf[1]=8'h02; tx_buf[2]=8'h12; tx_buf[3]=8'h00;
        tx_buf[4]=8'h01; tx_buf[5]=8'h01; tx_buf[6]=8'h00; tx_buf[7]=8'hA0;
        tx_buf[8]=8'h32;
        tx_buf[9]=8'h09; tx_buf[10]=8'h04; tx_buf[11]=8'h00; tx_buf[12]=8'h00;
        tx_buf[13]=8'h01; tx_buf[14]=8'h03; tx_buf[15]=8'h01; tx_buf[16]=8'h01;
        tx_buf[17]=8'h00;
        send_data_bytes(PID_DATA1, 18);
        repeat (16) @(posedge clk_48m);

        if (!kill[0] || threat_code[0] !== `THREAT_COOLDOWN_BURST) begin
            $error("expected HID hold 0x3, kill=%0b threat=%0h", kill[0], threat_code[0]);
            errors++;
        end else if (!port_status[0][`PORT_STATUS_PENDING_BIT]) begin
            $error("pending bit not set"); errors++;
        end else
            $display("HID hold OK threat=%0h status=%02h", threat_code[0], port_status[0]);

        clear_fault[0] = 1'b1;
        @(posedge clk_48m);
        clear_fault[0] = 1'b0;
        repeat (8) @(posedge clk_48m);
        if (!kill[0] || threat_code[0] !== `THREAT_COOLDOWN_BURST) begin
            $error("expected re-arm after clear-only"); errors++;
        end else
            $display("re-arm after clear-only OK");

        approve[0] = 1'b1;
        clear_fault[0] = 1'b1;
        @(posedge clk_48m);
        approve[0] = 1'b0;
        clear_fault[0] = 1'b0;
        repeat (8) @(posedge clk_48m);
        if (kill[0] || threat_code[0] !== `THREAT_NO_FAULT) begin
            $error("approve failed kill=%0b threat=%0h", kill[0], threat_code[0]);
            errors++;
        end else if (port_status[0][`PORT_STATUS_PENDING_BIT]) begin
            $error("pending still set after approve"); errors++;
        end else
            $display("approve OK");

        // --------------------------------------------------------------
        // Storage-only + vendor-then-HID: HID is NOT the first interface,
        // so first-intf-edge logic would miss it; must still trip 0x1.
        // (MSC+HID is composite → 0x4, tested in tb_suspicious_enum.)
        // --------------------------------------------------------------
        rst = 1'b1;
        repeat (8) @(posedge clk_48m);
        rst = 1'b0;
        policy_mode[0] = `POLICY_STORAGE_ONLY;
        wait_idle_bits(8);

        send_setup_token();
        tx_buf[0]=8'h80; tx_buf[1]=8'h06; tx_buf[2]=8'h00; tx_buf[3]=8'h02;
        tx_buf[4]=8'h00; tx_buf[5]=8'h00; tx_buf[6]=8'h1B; tx_buf[7]=8'h00;
        send_data_bytes(PID_DATA0, 8);
        tx_buf[0]=8'h09; tx_buf[1]=8'h02; tx_buf[2]=8'h1B; tx_buf[3]=8'h00;
        tx_buf[4]=8'h02; tx_buf[5]=8'h01; tx_buf[6]=8'h00; tx_buf[7]=8'hA0; tx_buf[8]=8'h32;
        // Vendor class first (0xFF) — latches as first intf, not HID
        tx_buf[9]=8'h09; tx_buf[10]=8'h04; tx_buf[11]=8'h00; tx_buf[12]=8'h00;
        tx_buf[13]=8'h01; tx_buf[14]=8'hFF; tx_buf[15]=8'h00; tx_buf[16]=8'h00; tx_buf[17]=8'h00;
        // HID second
        tx_buf[18]=8'h09; tx_buf[19]=8'h04; tx_buf[20]=8'h01; tx_buf[21]=8'h00;
        tx_buf[22]=8'h01; tx_buf[23]=8'h03; tx_buf[24]=8'h01; tx_buf[25]=8'h01; tx_buf[26]=8'h00;
        send_data_bytes(PID_DATA1, 27);
        repeat (24) @(posedge clk_48m);

        if (!kill[0] || threat_code[0] !== `THREAT_UNAUTHORIZED_HID) begin
            $error("vendor-then-HID storage expect 0x1 kill=%0b threat=%0h",
                   kill[0], threat_code[0]);
            errors++;
        end else
            $display("storage vendor-then-HID → 0x1 OK");

        if (errors == 0) $display("tb_hid_pending_approve: PASS");
        else             $display("tb_hid_pending_approve: FAIL (%0d errors)", errors);
        $finish;
    end

    initial begin
        #30ms;
        $error("global timeout");
        $finish;
    end

endmodule
