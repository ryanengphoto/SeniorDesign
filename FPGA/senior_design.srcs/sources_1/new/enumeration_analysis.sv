`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: enumeration_analysis  (midterm §6.3.4)
// Milestone 1 (spec B): latch VID/PID/dev_class from the device descriptor and
// intf_class from the first interface descriptor in a configuration blob.
// Config walk is sequential (one descriptor/cycle) so synth stays within S7-25.
//////////////////////////////////////////////////////////////////////////////////

module enumeration_analysis (
    input  logic        clk,
    input  logic        rst,

    input  logic        pkt_start,
    input  logic        pkt_end,
    input  logic [3:0]  pid,
    input  logic [6:0]  addr,
    input  logic [3:0]  endp,
    input  logic        data_valid,
    input  logic [7:0]  data,
    input  logic        crc_ok,

    output logic [15:0] vid,
    output logic [15:0] pid_dev,
    output logic [7:0]  dev_class,
    output logic [7:0]  intf_class,
    output logic        device_desc_valid,
    output logic        intf_class_valid,
    output logic        attached
);

    localparam [3:0] PID_SETUP = 4'b1101;
    localparam [3:0] PID_DATA0 = 4'b0011;
    localparam [3:0] PID_DATA1 = 4'b1011;

    localparam [7:0] REQ_GET_DESCRIPTOR = 8'h06;
    localparam [7:0] DT_DEVICE          = 8'h01;
    localparam [7:0] DT_CONFIGURATION   = 8'h02;
    localparam [7:0] DT_INTERFACE       = 8'h04;

    localparam [2:0] ST_IDLE       = 3'd0;
    localparam [2:0] ST_SETUP_DATA = 3'd1;
    localparam [2:0] ST_WAIT_DESC  = 3'd2;
    localparam [2:0] ST_DESC_DATA  = 3'd3;
    localparam [2:0] ST_SCAN_INTF  = 3'd4;

    logic [2:0] state;
    logic [3:0] setup_count;
    logic [7:0] setup [0:7];
    logic [7:0] want_dtype;
    logic [7:0] want_len;
    logic [7:0] got_len;
    logic [7:0] mem [0:63];
    logic [5:0] scan_i;
    logic [3:0] scan_guard;

    wire is_data = (pid == PID_DATA0) || (pid == PID_DATA1);

    logic [7:0] dlen;
    logic [7:0] dtype;

    assign dlen  = mem[scan_i];
    assign dtype = mem[scan_i + 6'd1];

    always_ff @(posedge clk) begin
        if (rst) begin
            state             <= ST_IDLE;
            setup_count       <= 4'd0;
            want_dtype        <= 8'd0;
            want_len          <= 8'd0;
            got_len           <= 8'd0;
            scan_i            <= 6'd0;
            scan_guard        <= 4'd0;
            vid               <= 16'd0;
            pid_dev           <= 16'd0;
            dev_class         <= 8'd0;
            intf_class        <= 8'd0;
            device_desc_valid <= 1'b0;
            intf_class_valid  <= 1'b0;
            attached          <= 1'b0;
        end else begin
            if (pkt_start || data_valid || pkt_end)
                attached <= 1'b1;

            // New SETUP on EP0 aborts any in-flight descriptor collection
            if (pkt_end && crc_ok && (pid == PID_SETUP) && (endp == 4'h0)) begin
                state       <= ST_SETUP_DATA;
                setup_count <= 4'd0;
            end else begin
                case (state)
                    ST_IDLE: ;

                    ST_SETUP_DATA: begin
                        if (pkt_start && is_data)
                            setup_count <= 4'd0;

                        if (data_valid && setup_count < 4'd8) begin
                            setup[setup_count[2:0]] <= data;
                            setup_count             <= setup_count + 4'd1;
                        end

                        if (pkt_end && is_data) begin
                            if (crc_ok && setup_count == 4'd8 &&
                                setup[1] == REQ_GET_DESCRIPTOR) begin
                                want_dtype <= setup[3];
                                if (setup[3] == DT_DEVICE) begin
                                    want_len <= 8'd18;
                                    got_len  <= 8'd0;
                                    state    <= ST_WAIT_DESC;
                                end else if (setup[3] == DT_CONFIGURATION) begin
                                    if ((setup[7] != 8'd0) || (setup[6] == 8'd0) ||
                                        (setup[6] > 8'd64))
                                        want_len <= 8'd64;
                                    else
                                        want_len <= setup[6];
                                    got_len <= 8'd0;
                                    state   <= ST_WAIT_DESC;
                                end else
                                    state <= ST_IDLE;
                            end else
                                state <= ST_IDLE;
                        end
                    end

                    ST_WAIT_DESC: begin
                        if (pkt_start && is_data)
                            state <= ST_DESC_DATA;
                    end

                    ST_DESC_DATA: begin
                        if (data_valid && got_len < 8'd64) begin
                            mem[got_len[5:0]] <= data;
                            got_len           <= got_len + 8'd1;
                        end

                        if (pkt_end && is_data) begin
                            if (!crc_ok) begin
                                state <= ST_IDLE;
                            end else if (got_len >= want_len) begin
                                if (want_dtype == DT_DEVICE) begin
                                    dev_class         <= mem[4];
                                    vid               <= {mem[9], mem[8]};
                                    pid_dev           <= {mem[11], mem[10]};
                                    device_desc_valid <= 1'b1;
                                    state             <= ST_IDLE;
                                end else if (want_dtype == DT_CONFIGURATION) begin
                                    scan_i     <= 6'd0;
                                    scan_guard <= 4'd0;
                                    state      <= ST_SCAN_INTF;
                                end else
                                    state <= ST_IDLE;
                            end else begin
                                state <= ST_WAIT_DESC;
                            end
                        end
                    end

                    ST_SCAN_INTF: begin
                        scan_guard <= scan_guard + 4'd1;
                        if ((scan_i + 6'd5) >= got_len[5:0] || scan_guard == 4'd15) begin
                            state <= ST_IDLE;
                        end else if (dlen == 8'd0) begin
                            state <= ST_IDLE;
                        end else if (dtype == DT_INTERFACE) begin
                            intf_class       <= mem[scan_i + 6'd5];
                            intf_class_valid <= 1'b1;
                            state            <= ST_IDLE;
                        end else begin
                            scan_i <= scan_i + dlen[5:0];
                        end
                    end

                    default: state <= ST_IDLE;
                endcase
            end
        end
    end

`ifndef VERILATOR
    // synthesis translate_off
    enumeration_analysis_sva u_enum_sva (
        .clk               (clk),
        .rst               (rst),
        .state             (state),
        .attached          (attached),
        .device_desc_valid (device_desc_valid),
        .intf_class_valid  (intf_class_valid)
    );
    // synthesis translate_on
`endif

endmodule
