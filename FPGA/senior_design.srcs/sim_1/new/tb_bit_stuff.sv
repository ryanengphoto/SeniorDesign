`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: tb_bit_stuff
// Purpose: Raw FS line stimulus with seven consecutive NRZI 1s after SYNC →
//          sniffer isolates with THREAT_BIT_STUFF_ERROR (0x6).
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module tb_bit_stuff;

    logic clk_48m = 1'b0;
    logic rst     = 1'b1;
    always #10.4167 clk_48m = ~clk_48m;

    logic dp = 1'b1;
    logic dm = 1'b0;

    logic clear_fault = 1'b0;
    logic manual_kill = 1'b0;
    logic approve     = 1'b0;
    logic [2:0] policy_mode = `POLICY_HID_ALLOWED;

    logic       pkt_start, pkt_end, data_valid, crc_ok;
    logic [3:0] pid, endp;
    logic [6:0] addr;
    logic [7:0] data;
    logic [7:0] port_status;
    logic [15:0] vid, pid_dev;
    logic [7:0]  dev_class, intf_class;
    logic        device_desc_valid, intf_class_valid;
    logic [3:0]  threat_detail;
    logic        kill;
    logic [3:0]  threat_code;

    sniffer_block #(
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
        .threat_detail     (threat_detail),
        .kill              (kill),
        .threat_code       (threat_code)
    );

    int errors;

    // One FS bit time = 4 cycles @ 48 MHz
    task automatic hold_pair(input logic dp_i, input logic dm_i, input int bits);
        dp = dp_i;
        dm = dm_i;
        repeat (bits * 4) @(posedge clk_48m);
    endtask

    task automatic idle_j(input int bits);
        hold_pair(1'b1, 1'b0, bits);
    endtask

    task automatic drive_k(input int bits);
        hold_pair(1'b0, 1'b1, bits);
    endtask

    task automatic drive_j(input int bits);
        hold_pair(1'b1, 1'b0, bits);
    endtask

    task automatic drive_se0(input int bits);
        hold_pair(1'b0, 1'b0, bits);
    endtask

    initial begin
        errors = 0;
        $display("tb_bit_stuff: SYNC + seven NRZI 1s → threat 0x6");

        repeat (32) @(posedge clk_48m);
        rst = 1'b0;
        idle_j(20);

        // SYNC: KJKJKJKK
        drive_k(1); drive_j(1);
        drive_k(1); drive_j(1);
        drive_k(1); drive_j(1);
        drive_k(1); drive_k(1);

        // Seven+ consecutive NRZI ones (no transitions) → bit-stuff error
        drive_k(8);

        // EOP: SE0 SE0 + J
        drive_se0(2);
        idle_j(16);

        repeat (32) @(posedge clk_48m);

        if (!kill || threat_code !== `THREAT_BIT_STUFF_ERROR) begin
            $error("expected bit-stuff kill 0x6, kill=%0b threat=%0h",
                   kill, threat_code);
            errors++;
        end else
            $display("bit-stuff isolate OK threat=%0h", threat_code);

        // clear releases; no sticky re-arm for PHY faults
        clear_fault = 1'b1;
        @(posedge clk_48m);
        clear_fault = 1'b0;
        repeat (8) @(posedge clk_48m);
        if (kill || threat_code !== `THREAT_NO_FAULT) begin
            $error("clear after bit-stuff failed kill=%0b threat=%0h",
                   kill, threat_code);
            errors++;
        end else
            $display("clear after bit-stuff OK");

        if (errors == 0) $display("tb_bit_stuff: PASS");
        else             $display("tb_bit_stuff: FAIL (%0d errors)", errors);
        $finish;
    end

    initial begin
        #5ms;
        $error("global timeout");
        $finish;
    end

endmodule
