`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: tb_suspicious_enum
// Purpose: Direct-event tests for suspicious enumeration pulses:
//          overflow, composite HID+MSC, multi-HID, re-enum storm.
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module tb_suspicious_enum;

    logic clk = 1'b0;
    logic rst = 1'b1;
    always #10.4167 clk = ~clk;

    logic        pkt_start, pkt_end, data_valid, crc_ok;
    logic [3:0]  pid, endp;
    logic [6:0]  addr;
    logic [7:0]  data;
    logic        clear_telemetry;

    logic [15:0] vid, pid_dev;
    logic [7:0]  dev_class, intf_class, intf_subclass, intf_protocol;
    logic        device_desc_valid, intf_class_valid, config_walk_done;
    logic        hid_keyboard_seen;
    logic [3:0]  hid_iface_count, msc_iface_count;
    logic        attached;
    logic        desc_overflow_pulse, composite_hid_msc_pulse;
    logic        multi_hid_pulse, hid_keyboard_pulse, reenum_storm_pulse;

    enumeration_analysis #(
        .REENUM_WINDOW_CYCLES_P(200),
        .REENUM_STORM_THRESH_P (3)
    ) dut (
        .clk(clk), .rst(rst),
        .line_attached(1'b1),
        .clear_telemetry(clear_telemetry),
        .pkt_start(pkt_start), .pkt_end(pkt_end),
        .pid(pid), .addr(addr), .endp(endp),
        .data_valid(data_valid), .data(data), .crc_ok(crc_ok),
        .vid(vid), .pid_dev(pid_dev),
        .dev_class(dev_class), .intf_class(intf_class),
        .intf_subclass(intf_subclass), .intf_protocol(intf_protocol),
        .device_desc_valid(device_desc_valid),
        .intf_class_valid(intf_class_valid),
        .config_walk_done(config_walk_done),
        .hid_keyboard_seen(hid_keyboard_seen),
        .hid_iface_count(hid_iface_count),
        .msc_iface_count(msc_iface_count),
        .attached(attached),
        .desc_overflow_pulse(desc_overflow_pulse),
        .composite_hid_msc_pulse(composite_hid_msc_pulse),
        .multi_hid_pulse(multi_hid_pulse),
        .hid_keyboard_pulse(hid_keyboard_pulse),
        .reenum_storm_pulse(reenum_storm_pulse)
    );

    localparam [3:0] PID_SETUP = 4'b1101;
    localparam [3:0] PID_DATA0 = 4'b0011;
    localparam [3:0] PID_DATA1 = 4'b1011;

    logic [7:0] tx_buf [0:63];
    int         tx_n;
    int         errors;
    int         saw_overflow, saw_composite, saw_multi, saw_storm;

    task automatic tick;
        @(posedge clk);
        pkt_start  = 1'b0;
        pkt_end    = 1'b0;
        data_valid = 1'b0;
        if (desc_overflow_pulse)     saw_overflow++;
        if (composite_hid_msc_pulse) saw_composite++;
        if (multi_hid_pulse)         saw_multi++;
        if (reenum_storm_pulse)      saw_storm++;
    endtask

    task automatic send_token(input [3:0] pid_i);
        tick;
        pid = pid_i; addr = 7'd0; endp = 4'h0; crc_ok = 1'b1;
        pkt_start = 1'b1; tick; pkt_end = 1'b1; tick;
    endtask

    task automatic send_data(input [3:0] pid_i);
        int i;
        tick;
        pid = pid_i; addr = 7'd0; endp = 4'h0; crc_ok = 1'b1;
        pkt_start = 1'b1; tick;
        for (i = 0; i < tx_n; i = i + 1) begin
            data_valid = 1'b1; data = tx_buf[i]; tick;
        end
        data_valid = 1'b0; pkt_end = 1'b1; tick;
    endtask

    task automatic get_config(input int n_bytes);
        // SETUP GET_DESCRIPTOR(CONFIGURATION)
        send_token(PID_SETUP);
        tx_n = 8;
        tx_buf[0]=8'h80; tx_buf[1]=8'h06; tx_buf[2]=8'h00; tx_buf[3]=8'h02;
        tx_buf[4]=8'h00; tx_buf[5]=8'h00;
        tx_buf[6]=n_bytes & 8'hFF;
        tx_buf[7]=(n_bytes >> 8) & 8'hFF;
        send_data(PID_DATA0);
    endtask

    initial begin
        errors = 0;
        saw_overflow = 0; saw_composite = 0; saw_multi = 0; saw_storm = 0;
        pkt_start=0; pkt_end=0; data_valid=0; crc_ok=1;
        pid=0; addr=0; endp=0; data=0; clear_telemetry=0;
        $display("tb_suspicious_enum: overflow/composite/multi/storm");

        repeat (8) @(posedge clk);
        rst = 1'b0;
        repeat (4) tick;

        // ---- Overflow: host asks for wLength > 512 ----
        send_token(PID_SETUP);
        tx_n = 8;
        tx_buf[0]=8'h80; tx_buf[1]=8'h06; tx_buf[2]=8'h00; tx_buf[3]=8'h02;
        tx_buf[4]=8'h00; tx_buf[5]=8'h00; tx_buf[6]=8'h01; tx_buf[7]=8'h02; // 0x0201=513
        send_data(PID_DATA0);
        repeat (4) tick;
        if (saw_overflow < 1) begin
            $error("expected desc_overflow_pulse"); errors++;
        end else $display("overflow OK");

        // Reset DUT for next scenario
        rst = 1'b1; repeat (4) @(posedge clk); rst = 1'b0;
        saw_composite = 0; saw_multi = 0; repeat (4) tick;

        // ---- Composite HID + MSC ----
        get_config(36);
        // config(9) + HID iface(9) + MSC iface(9) + pad
        tx_n = 27;
        tx_buf[0]=8'h09; tx_buf[1]=8'h02; tx_buf[2]=8'h1B; tx_buf[3]=8'h00;
        tx_buf[4]=8'h02; tx_buf[5]=8'h01; tx_buf[6]=8'h00; tx_buf[7]=8'hA0; tx_buf[8]=8'h32;
        // HID interface
        tx_buf[9]=8'h09; tx_buf[10]=8'h04; tx_buf[11]=8'h00; tx_buf[12]=8'h00;
        tx_buf[13]=8'h01; tx_buf[14]=8'h03; tx_buf[15]=8'h01; tx_buf[16]=8'h01; tx_buf[17]=8'h00;
        // MSC interface
        tx_buf[18]=8'h09; tx_buf[19]=8'h04; tx_buf[20]=8'h01; tx_buf[21]=8'h00;
        tx_buf[22]=8'h02; tx_buf[23]=8'h08; tx_buf[24]=8'h06; tx_buf[25]=8'h50; tx_buf[26]=8'h00;
        send_data(PID_DATA1);
        repeat (20) tick;
        if (saw_composite < 1) begin
            $error("expected composite_hid_msc_pulse"); errors++;
        end else $display("composite HID+MSC OK counts HID=%0d MSC=%0d",
                          hid_iface_count, msc_iface_count);

        rst = 1'b1; repeat (4) @(posedge clk); rst = 1'b0;
        saw_multi = 0; repeat (4) tick;

        // ---- Multi-HID ----
        get_config(36);
        tx_n = 27;
        tx_buf[0]=8'h09; tx_buf[1]=8'h02; tx_buf[2]=8'h1B; tx_buf[3]=8'h00;
        tx_buf[4]=8'h02; tx_buf[5]=8'h01; tx_buf[6]=8'h00; tx_buf[7]=8'hA0; tx_buf[8]=8'h32;
        tx_buf[9]=8'h09; tx_buf[10]=8'h04; tx_buf[11]=8'h00; tx_buf[12]=8'h00;
        tx_buf[13]=8'h01; tx_buf[14]=8'h03; tx_buf[15]=8'h01; tx_buf[16]=8'h01; tx_buf[17]=8'h00;
        tx_buf[18]=8'h09; tx_buf[19]=8'h04; tx_buf[20]=8'h01; tx_buf[21]=8'h00;
        tx_buf[22]=8'h01; tx_buf[23]=8'h03; tx_buf[24]=8'h01; tx_buf[25]=8'h02; tx_buf[26]=8'h00;
        send_data(PID_DATA1);
        repeat (20) tick;
        if (saw_multi < 1) begin
            $error("expected multi_hid_pulse"); errors++;
        end else $display("multi-HID OK count=%0d", hid_iface_count);

        rst = 1'b1; repeat (4) @(posedge clk); rst = 1'b0;
        saw_storm = 0; repeat (4) tick;

        // ---- Re-enum storm: 3 rising edges within window ----
        clear_telemetry = 1'b1; tick; clear_telemetry = 1'b0; repeat (5) tick;
        clear_telemetry = 1'b1; tick; clear_telemetry = 1'b0; repeat (5) tick;
        clear_telemetry = 1'b1; tick; clear_telemetry = 1'b0; repeat (5) tick;
        if (saw_storm < 1) begin
            $error("expected reenum_storm_pulse"); errors++;
        end else $display("re-enum storm OK");

        // Sticky storm: further resets in-window must not re-pulse
        begin
            int storm_before;
            storm_before = saw_storm;
            clear_telemetry = 1'b1; tick; clear_telemetry = 1'b0; repeat (5) tick;
            if (saw_storm != storm_before) begin
                $error("storm must latch (no re-pulse)"); errors++;
            end
        end

        rst = 1'b1; repeat (4) @(posedge clk); rst = 1'b0;
        saw_overflow = 0; saw_composite = 0; repeat (4) tick;

        // ---- Body wTotalLength > 512 (host wLength ok) ----
        get_config(9);
        tx_n = 9;
        tx_buf[0]=8'h09; tx_buf[1]=8'h02; tx_buf[2]=8'h01; tx_buf[3]=8'h02; // 513
        tx_buf[4]=8'h01; tx_buf[5]=8'h01; tx_buf[6]=8'h00; tx_buf[7]=8'hA0; tx_buf[8]=8'h32;
        send_data(PID_DATA1);
        repeat (20) tick;
        if (saw_overflow < 1) begin
            $error("expected body wTotalLength overflow"); errors++;
        end else $display("body overflow OK");

        rst = 1'b1; repeat (4) @(posedge clk); rst = 1'b0;
        saw_composite = 0; saw_multi = 0; repeat (4) tick;

        // ---- dlen==0 after HID+MSC (zero-length scan arm) ----
        get_config(36);
        tx_n = 36;
        tx_buf[0]=8'h09; tx_buf[1]=8'h02; tx_buf[2]=8'h24; tx_buf[3]=8'h00;
        tx_buf[4]=8'h02; tx_buf[5]=8'h01; tx_buf[6]=8'h00; tx_buf[7]=8'hA0; tx_buf[8]=8'h32;
        tx_buf[9]=8'h09; tx_buf[10]=8'h04; tx_buf[11]=8'h00; tx_buf[12]=8'h00;
        tx_buf[13]=8'h01; tx_buf[14]=8'h03; tx_buf[15]=8'h01; tx_buf[16]=8'h01; tx_buf[17]=8'h00;
        tx_buf[18]=8'h09; tx_buf[19]=8'h04; tx_buf[20]=8'h01; tx_buf[21]=8'h00;
        tx_buf[22]=8'h02; tx_buf[23]=8'h08; tx_buf[24]=8'h06; tx_buf[25]=8'h50; tx_buf[26]=8'h00;
        tx_buf[27]=8'h00;
        begin
            int zi;
            for (zi = 28; zi < 36; zi++) tx_buf[zi] = 8'h5A;
        end
        send_data(PID_DATA1);
        repeat (24) tick;
        if (saw_composite < 1) begin
            $error("expected composite via dlen==0"); errors++;
        end else $display("dlen0 composite OK");

        rst = 1'b1; repeat (4) @(posedge clk); rst = 1'b0;
        saw_multi = 0; repeat (4) tick;

        // ---- dlen==0 after 2× HID (multi via zero-length arm) ----
        get_config(36);
        tx_n = 36;
        tx_buf[0]=8'h09; tx_buf[1]=8'h02; tx_buf[2]=8'h24; tx_buf[3]=8'h00;
        tx_buf[4]=8'h02; tx_buf[5]=8'h01; tx_buf[6]=8'h00; tx_buf[7]=8'hA0; tx_buf[8]=8'h32;
        tx_buf[9]=8'h09; tx_buf[10]=8'h04; tx_buf[11]=8'h00; tx_buf[12]=8'h00;
        tx_buf[13]=8'h01; tx_buf[14]=8'h03; tx_buf[15]=8'h01; tx_buf[16]=8'h01; tx_buf[17]=8'h00;
        tx_buf[18]=8'h09; tx_buf[19]=8'h04; tx_buf[20]=8'h01; tx_buf[21]=8'h00;
        tx_buf[22]=8'h01; tx_buf[23]=8'h03; tx_buf[24]=8'h01; tx_buf[25]=8'h02; tx_buf[26]=8'h00;
        tx_buf[27]=8'h00;
        begin
            int zi;
            for (zi = 28; zi < 36; zi++) tx_buf[zi] = 8'hA5;
        end
        send_data(PID_DATA1);
        repeat (24) tick;
        if (saw_multi < 1) begin
            $error("expected multi-HID via dlen==0"); errors++;
        end else $display("dlen0 multi-HID OK");

        // Window expiry: one reset, then wait out window → count clears
        rst = 1'b1; repeat (4) @(posedge clk); rst = 1'b0;
        saw_storm = 0; repeat (4) tick;
        clear_telemetry = 1'b1; tick; clear_telemetry = 1'b0;
        repeat (220) tick; // REENUM_WINDOW_CYCLES_P=200
        clear_telemetry = 1'b1; tick; clear_telemetry = 1'b0; repeat (5) tick;
        clear_telemetry = 1'b1; tick; clear_telemetry = 1'b0; repeat (5) tick;
        // Only 2 in new window — no storm
        if (saw_storm != 0) begin
            $error("storm must not fire after window expiry"); errors++;
        end else $display("reenum window expiry OK");

        // Illegal state → default case (force/release)
        force dut.state = 3'd7;
        @(posedge clk);
        release dut.state;
        @(posedge clk);
        @(posedge clk);
        if (dut.state !== 3'd0) begin
            $error("default case should return ST_IDLE got %0d", dut.state); errors++;
        end else $display("default state arm OK");

        // SETUP with bad CRC → stay out of GET_DESCRIPTOR decode
        send_token(PID_SETUP);
        tx_n = 8;
        tx_buf[0]=8'h80; tx_buf[1]=8'h06; tx_buf[2]=8'h00; tx_buf[3]=8'h01;
        tx_buf[4]=8'h00; tx_buf[5]=8'h00; tx_buf[6]=8'h12; tx_buf[7]=8'h00;
        tick;
        pid = PID_DATA0; addr = 7'd0; endp = 4'h0; crc_ok = 1'b0;
        pkt_start = 1'b1; tick;
        begin
            int i;
            for (i = 0; i < 8; i = i + 1) begin
                data_valid = 1'b1; data = tx_buf[i]; tick;
            end
        end
        data_valid = 1'b0; pkt_end = 1'b1; tick;
        crc_ok = 1'b1;

        // Fill more of mem[] with a 64-byte config scan (toggle array BRDAs)
        get_config(64);
        tx_n = 64;
        tx_buf[0]=8'h09; tx_buf[1]=8'h02; tx_buf[2]=8'h40; tx_buf[3]=8'h00;
        tx_buf[4]=8'h01; tx_buf[5]=8'h01; tx_buf[6]=8'h00; tx_buf[7]=8'hA0; tx_buf[8]=8'h32;
        begin
            int fi;
            for (fi = 9; fi < 64; fi++) tx_buf[fi] = fi[7:0] ^ 8'h5A;
        end
        // Plant one HID iface early so walk does real work
        tx_buf[9]=8'h09; tx_buf[10]=8'h04; tx_buf[11]=8'h00; tx_buf[12]=8'h00;
        tx_buf[13]=8'h01; tx_buf[14]=8'h03; tx_buf[15]=8'h01; tx_buf[16]=8'h01; tx_buf[17]=8'h00;
        send_data(PID_DATA1);
        repeat (40) tick;

        if (errors == 0) $display("tb_suspicious_enum: PASS");
        else             $display("tb_suspicious_enum: FAIL (%0d errors)", errors);
        $finish;
    end

    initial begin
        #20ms;
        $error("global timeout");
        $finish;
    end

endmodule
