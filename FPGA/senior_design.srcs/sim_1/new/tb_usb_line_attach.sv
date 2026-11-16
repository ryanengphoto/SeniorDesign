`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: tb_usb_line_attach
// Purpose: FS J presence, idle stays attached, SE0 disconnect clears attach;
//          LS J auto-detect after disconnect.
//////////////////////////////////////////////////////////////////////////////////

module tb_usb_line_attach;

    logic clk = 1'b0;
    logic rst = 1'b1;
    always #10.4167 clk = ~clk; // ~48 MHz

    logic dp = 1'b0;
    logic dm = 1'b0;
    logic attached;
    logic speed_is_ls;
    logic speed_valid;
    logic disconnect_stb;

    // Short debounce for sim speed (still >> EOP)
    usb_line_attach #(
        .DISCONNECT_CYCLES(32),
        .SPEED_MODE(0)
    ) dut (
        .clk(clk),
        .rst(rst),
        .dp(dp),
        .dm(dm),
        .attached(attached),
        .speed_is_ls(speed_is_ls),
        .speed_valid(speed_valid),
        .disconnect_stb(disconnect_stb)
    );

    int errors;

    task automatic cycles(input int n);
        repeat (n) @(posedge clk);
    endtask

    initial begin
        errors = 0;
        dp = 0; dm = 0;
        cycles(4);
        rst = 1'b0;
        cycles(4);

        $display("tb_usb_line_attach: FS J attach / idle hold / SE0 disconnect / LS reattach");

        // SE0 idle → not attached
        if (attached) begin
            $display("ERROR: attached while SE0 at start");
            errors++;
        end

        // FS J
        dp = 1; dm = 0;
        cycles(8);
        if (!attached || !speed_valid || speed_is_ls) begin
            $display("ERROR: FS J should attach as FS (att=%0d valid=%0d ls=%0d)",
                     attached, speed_valid, speed_is_ls);
            errors++;
        end

        // Stay on J a long time (idle device) — must remain attached
        cycles(500);
        if (!attached) begin
            $display("ERROR: lost attach while still on FS J (idle)");
            errors++;
        end

        // Brief SE0 (EOP-like) shorter than debounce — stay attached
        dp = 0; dm = 0;
        cycles(8);
        dp = 1; dm = 0;
        cycles(4);
        if (!attached) begin
            $display("ERROR: brief SE0 dropped attach");
            errors++;
        end

        // Long SE0 → disconnect
        dp = 0; dm = 0;
        cycles(40);
        if (attached) begin
            $display("ERROR: still attached after long SE0");
            errors++;
        end

        // LS J after disconnect → auto LS
        dp = 0; dm = 1;
        cycles(8);
        if (!attached || !speed_valid || !speed_is_ls) begin
            $display("ERROR: LS J should attach as LS (att=%0d valid=%0d ls=%0d)",
                     attached, speed_valid, speed_is_ls);
            errors++;
        end

        if (errors == 0) $display("tb_usb_line_attach: PASS");
        else             $display("tb_usb_line_attach: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
