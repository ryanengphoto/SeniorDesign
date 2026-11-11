`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: tb_enumeration_analysis
// Purpose: Direct packet-event stimulus for enumeration_analysis (no PHY).
//          Proves GET_DESCRIPTOR device + config/interface → status fields.
//          usb_fs_tx cannot emit SETUP tokens; line-level enum comes later.
//////////////////////////////////////////////////////////////////////////////////

module tb_enumeration_analysis;

    logic clk = 1'b0;
    logic rst = 1'b1;
    always #10.4167 clk = ~clk;

    logic        pkt_start;
    logic        pkt_end;
    logic [3:0]  pid;
    logic [6:0]  addr;
    logic [3:0]  endp;
    logic        data_valid;
    logic [7:0]  data;
    logic        crc_ok;

    logic [15:0] vid;
    logic [15:0] pid_dev;
    logic [7:0]  dev_class;
    logic [7:0]  intf_class;
    logic        device_desc_valid;
    logic        intf_class_valid;
    logic        attached;

    enumeration_analysis dut (
        .clk(clk), .rst(rst),
        .pkt_start(pkt_start), .pkt_end(pkt_end),
        .pid(pid), .addr(addr), .endp(endp),
        .data_valid(data_valid), .data(data), .crc_ok(crc_ok),
        .vid(vid), .pid_dev(pid_dev),
        .dev_class(dev_class), .intf_class(intf_class),
        .device_desc_valid(device_desc_valid),
        .intf_class_valid(intf_class_valid),
        .attached(attached)
    );

    localparam [3:0] PID_SETUP = 4'b1101;
    localparam [3:0] PID_DATA0 = 4'b0011;
    localparam [3:0] PID_DATA1 = 4'b1011;

    logic [7:0] tx_buf [0:63];
    int         tx_n;
    int         errors;

    task automatic tick;
        @(posedge clk);
        pkt_start  = 1'b0;
        pkt_end    = 1'b0;
        data_valid = 1'b0;
    endtask

    task automatic send_token(input [3:0] pid_i, input [3:0] endp_i);
        tick;
        pid       = pid_i;
        addr      = 7'd0;
        endp      = endp_i;
        crc_ok    = 1'b1;
        pkt_start = 1'b1;
        tick;
        pkt_end = 1'b1;
        tick;
    endtask

    task automatic send_data_packet(input [3:0] pid_i);
        int i;
        tick;
        pid       = pid_i;
        addr      = 7'd0;
        endp      = 4'h0;
        crc_ok    = 1'b1;
        pkt_start = 1'b1;
        tick;
        for (i = 0; i < tx_n; i = i + 1) begin
            data_valid = 1'b1;
            data       = tx_buf[i];
            tick;
        end
        pkt_end = 1'b1;
        tick;
    endtask

    initial begin
        pkt_start  = 1'b0;
        pkt_end    = 1'b0;
        pid        = 4'h0;
        addr       = 7'd0;
        endp       = 4'h0;
        data_valid = 1'b0;
        data       = 8'h00;
        crc_ok     = 1'b1;
        errors     = 0;

        $display("tb_enumeration_analysis: device + config/interface telemetry");
        repeat (8) @(posedge clk);
        rst = 1'b0;
        repeat (4) tick;

        // ---- GET_DESCRIPTOR(DEVICE) ----
        tx_buf[0] = 8'h80;
        tx_buf[1] = 8'h06;
        tx_buf[2] = 8'h00;
        tx_buf[3] = 8'h01;
        tx_buf[4] = 8'h00;
        tx_buf[5] = 8'h00;
        tx_buf[6] = 8'h12;
        tx_buf[7] = 8'h00;
        tx_n = 8;
        send_token(PID_SETUP, 4'h0);
        send_data_packet(PID_DATA0);

        tx_buf[0]  = 8'h12;
        tx_buf[1]  = 8'h01;
        tx_buf[2]  = 8'h00; tx_buf[3] = 8'h02;
        tx_buf[4]  = 8'h00;
        tx_buf[5]  = 8'h00; tx_buf[6] = 8'h00;
        tx_buf[7]  = 8'h40;
        tx_buf[8]  = 8'h34; tx_buf[9]  = 8'h12; // VID 0x1234
        tx_buf[10] = 8'h78; tx_buf[11] = 8'h56; // PID 0x5678
        tx_buf[12] = 8'h00; tx_buf[13] = 8'h01;
        tx_buf[14] = 8'h00; tx_buf[15] = 8'h00;
        tx_buf[16] = 8'h00; tx_buf[17] = 8'h01;
        tx_n = 18;
        send_data_packet(PID_DATA1);
        repeat (4) tick;

        if (!device_desc_valid) begin $error("device_desc_valid"); errors++; end
        if (vid !== 16'h1234) begin $error("vid=%h", vid); errors++; end
        if (pid_dev !== 16'h5678) begin $error("pid_dev=%h", pid_dev); errors++; end
        if (dev_class !== 8'h00) begin $error("dev_class=%h", dev_class); errors++; end
        if (!attached) begin $error("attached"); errors++; end
        if (errors == 0)
            $display("device descriptor OK vid=%h pid=%h class=%h",
                     vid, pid_dev, dev_class);

        // ---- GET_DESCRIPTOR(CONFIGURATION) with interface ----
        tx_buf[0] = 8'h80;
        tx_buf[1] = 8'h06;
        tx_buf[2] = 8'h00;
        tx_buf[3] = 8'h02;
        tx_buf[4] = 8'h00;
        tx_buf[5] = 8'h00;
        tx_buf[6] = 8'h12;
        tx_buf[7] = 8'h00;
        tx_n = 8;
        send_token(PID_SETUP, 4'h0);
        send_data_packet(PID_DATA0);

        tx_buf[0] = 8'h09; tx_buf[1] = 8'h02;
        tx_buf[2] = 8'h12; tx_buf[3] = 8'h00;
        tx_buf[4] = 8'h01; tx_buf[5] = 8'h01;
        tx_buf[6] = 8'h00; tx_buf[7] = 8'hA0;
        tx_buf[8] = 8'h32;
        tx_buf[9]  = 8'h09; tx_buf[10] = 8'h04;
        tx_buf[11] = 8'h00; tx_buf[12] = 8'h00;
        tx_buf[13] = 8'h01; tx_buf[14] = 8'h03; // HID intf class
        tx_buf[15] = 8'h01; tx_buf[16] = 8'h02;
        tx_buf[17] = 8'h00;
        tx_n = 18;
        send_data_packet(PID_DATA1);
        repeat (4) tick;

        if (!intf_class_valid) begin $error("intf_class_valid"); errors++; end
        if (intf_class !== 8'h03) begin $error("intf_class=%h", intf_class); errors++; end
        if (errors == 0)
            $display("config/interface OK intf_class=%h", intf_class);

        if (errors == 0) $display("tb_enumeration_analysis: PASS");
        else             $display("tb_enumeration_analysis: FAIL (%0d errors)", errors);
        $finish;
    end

    initial begin
        #2ms;
        $error("global timeout");
        $finish;
    end

endmodule
