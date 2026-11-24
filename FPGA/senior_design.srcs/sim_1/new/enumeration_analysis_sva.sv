`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: enumeration_analysis_sva
// Purpose: FSM encoding + sticky attached/valid monitors (XSim procedural).
//////////////////////////////////////////////////////////////////////////////////

module enumeration_analysis_sva (
    input logic       clk,
    input logic       rst,
    input logic       clear_telemetry,
    input logic [2:0] state,
    input logic       attached,
    input logic       device_desc_valid,
    input logic       intf_class_valid
);

    localparam [2:0] ST_IDLE  = 3'd0;
    localparam [2:0] ST_SETUP = 3'd1;
    localparam [2:0] ST_WAIT  = 3'd2;
    localparam [2:0] ST_DESC  = 3'd3;
    localparam [2:0] ST_SCAN  = 3'd4;

    logic sample_valid;
    logic attached_d, ddv_d, clear_d;

    wire state_ok = (state == ST_IDLE) || (state == ST_SETUP) ||
                    (state == ST_WAIT) || (state == ST_DESC) || (state == ST_SCAN);

    always_ff @(posedge clk) begin
        if (rst) begin
            sample_valid <= 1'b0;
            attached_d   <= 1'b0;
            ddv_d        <= 1'b0;
            clear_d      <= 1'b0;
        end else begin
            if (sample_valid) begin
                if (!state_ok)
                    $error("enumeration_analysis SVA: illegal FSM state %0d", state);

                // Device descriptor is sticky until rst or line disconnect.
                // The clear is NBA, so the following cycle still shows the old valid.
                // intf_class_valid is dropped at the start of a new config walk.
                if (!clear_telemetry && !clear_d) begin
                    if (ddv_d && !device_desc_valid)
                        $error("enumeration_analysis SVA: device_desc_valid cleared without rst/disconnect");
                end
            end

            sample_valid <= 1'b1;
            attached_d   <= attached; // line-backed; not sticky-checked
            ddv_d        <= device_desc_valid;
            clear_d      <= clear_telemetry;
        end
    end

endmodule
