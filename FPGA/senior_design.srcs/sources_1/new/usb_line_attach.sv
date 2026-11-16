`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: usb_line_attach
// Purpose: Soft-tap USB connect / disconnect from D+/D− line state (not packet
//          activity). Idle devices keep the pull-up → stay "attached".
//
// Full-Speed J: D+=1, D−=0 (pull-up on D+)
// Low-Speed  J: D+=0, D−=1 (pull-up on D−)
// SE0:        D+=0, D−=0  (EOP / reset / disconnect)
//
// SPEED_MODE: 0 = auto (latch FS/LS from first J after reset/disconnect)
//             1 = force Full-Speed
//             2 = force Low-Speed
// High-Speed (480 Mbps) is not supported by this soft tap.
//
// Disconnect: non-J (typically SE0) for DISCONNECT_CYCLES @ clk (~4 µs default
// at 48 MHz) → clear attached + pulse disconnect_stb. Brief EOP SE0 is ignored.
//////////////////////////////////////////////////////////////////////////////////

module usb_line_attach #(
    parameter int DISCONNECT_CYCLES = 200,
    parameter int SPEED_MODE        = 0   // 0 auto, 1 FS, 2 LS
) (
    input  logic clk,
    input  logic rst,

    input  logic dp,
    input  logic dm,

    output logic attached,
    output logic speed_is_ls,     // 0 = FS, 1 = LS (valid once speed_valid)
    output logic speed_valid,
    output logic disconnect_stb   // 1-cycle pulse when disconnect commits
);

    // Sync raw taps
    logic [2:0] dp_sync, dm_sync;
    always_ff @(posedge clk) begin
        if (rst) begin
            dp_sync <= 3'b000;
            dm_sync <= 3'b000;
        end else begin
            dp_sync <= {dp_sync[1:0], dp};
            dm_sync <= {dm_sync[1:0], dm};
        end
    end

    wire dp_s = dp_sync[2];
    wire dm_s = dm_sync[2];

    wire j_fs =  dp_s & ~dm_s;
    wire j_ls = ~dp_s &  dm_s;
    wire se0  = ~dp_s & ~dm_s;

    logic        speed_is_ls_r;
    logic        speed_valid_r;
    logic        attached_r;
    logic [15:0] se0_cnt;

    wire force_fs = (SPEED_MODE == 1);
    wire force_ls = (SPEED_MODE == 2);

    wire j_for_mode = force_fs ? j_fs :
                      force_ls ? j_ls :
                      (!speed_valid_r ? (j_fs | j_ls) :
                       (speed_is_ls_r ? j_ls : j_fs));

    assign attached       = attached_r;
    assign speed_is_ls    = force_ls ? 1'b1 : force_fs ? 1'b0 : speed_is_ls_r;
    assign speed_valid    = force_fs || force_ls || speed_valid_r;

    always_ff @(posedge clk) begin
        if (rst) begin
            speed_is_ls_r  <= 1'b0;
            speed_valid_r  <= 1'b0;
            attached_r     <= 1'b0;
            se0_cnt        <= 16'd0;
            disconnect_stb <= 1'b0;
        end else begin
            disconnect_stb <= 1'b0;

            // Latch speed from first J when auto
            if (SPEED_MODE == 0 && !speed_valid_r) begin
                if (j_fs) begin
                    speed_is_ls_r <= 1'b0;
                    speed_valid_r <= 1'b1;
                end else if (j_ls) begin
                    speed_is_ls_r <= 1'b1;
                    speed_valid_r <= 1'b1;
                end
            end

            if (j_for_mode) begin
                attached_r <= 1'b1;
                se0_cnt    <= 16'd0;
            end else if (se0 || (!j_fs && !j_ls)) begin
                // Counting toward disconnect while not seeing the expected J
                if (attached_r) begin
                    if (se0_cnt >= 16'(DISCONNECT_CYCLES)) begin
                        attached_r     <= 1'b0;
                        se0_cnt        <= 16'd0;
                        disconnect_stb <= 1'b1;
                        // Allow next plug to be the other speed
                        if (SPEED_MODE == 0) begin
                            speed_valid_r <= 1'b0;
                            speed_is_ls_r <= 1'b0;
                        end
                    end else begin
                        se0_cnt <= se0_cnt + 16'd1;
                    end
                end else begin
                    se0_cnt <= 16'd0;
                end
            end else begin
                // Differential noise / K while attached: don't immediately drop,
                // but don't accumulate SE0 either.
                se0_cnt <= 16'd0;
            end
        end
    end

endmodule
