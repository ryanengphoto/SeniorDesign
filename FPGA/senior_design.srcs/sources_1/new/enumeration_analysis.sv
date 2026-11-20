`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: enumeration_analysis
// Purpose: EP0 GET_DESCRIPTOR parse → VID/PID/classes + suspicious-enum pulses.
//          Walks all interface descriptors in a config blob (sequential).
//          Tracks bus-reset storms for re-enumeration DoS.
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module enumeration_analysis #(
    parameter int REENUM_WINDOW_CYCLES_P = `REENUM_WINDOW_CYCLES,
    parameter int REENUM_STORM_THRESH_P  = `REENUM_STORM_THRESHOLD
) (
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
    input  logic        bus_reset,   // level from usb_reset_det (sticky while SE0)

    output logic [15:0] vid,
    output logic [15:0] pid_dev,
    output logic [7:0]  dev_class,
    output logic [7:0]  intf_class,
    output logic [7:0]  intf_subclass,
    output logic [7:0]  intf_protocol,
    output logic        device_desc_valid,
    output logic        intf_class_valid,
    output logic        config_walk_done,
    output logic        hid_keyboard_seen,
    output logic [3:0]  hid_iface_count,
    output logic [3:0]  msc_iface_count,
    output logic        attached,

    // One-cycle threat pulses
    output logic        desc_overflow_pulse,
    output logic        composite_hid_msc_pulse,
    output logic        multi_hid_pulse,
    output logic        hid_keyboard_pulse,
    output logic        reenum_storm_pulse
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
    logic [15:0] w_total_length;
    logic        overflow_latched;

    logic        bus_reset_d;
    logic [31:0] reenum_window_cnt;
    logic [3:0]  reenum_count;
    logic        reenum_storm_latched;

    wire is_data = (pid == PID_DATA0) || (pid == PID_DATA1);

    logic [7:0] dlen;
    logic [7:0] dtype;
    logic [7:0] iface_class_b;
    logic [7:0] iface_sub_b;
    logic [7:0] iface_proto_b;

    assign dlen          = mem[scan_i];
    assign dtype         = mem[scan_i + 6'd1];
    assign iface_class_b = mem[scan_i + 6'd5];
    assign iface_sub_b   = mem[scan_i + 6'd6];
    assign iface_proto_b = mem[scan_i + 6'd7];

    wire bus_reset_rise = bus_reset && !bus_reset_d;

    always_ff @(posedge clk) begin
        if (rst) begin
            state                 <= ST_IDLE;
            setup_count           <= 4'd0;
            want_dtype            <= 8'd0;
            want_len              <= 8'd0;
            got_len               <= 8'd0;
            scan_i                <= 6'd0;
            scan_guard            <= 4'd0;
            w_total_length        <= 16'd0;
            overflow_latched      <= 1'b0;
            vid                   <= 16'd0;
            pid_dev               <= 16'd0;
            dev_class             <= 8'd0;
            intf_class            <= 8'd0;
            intf_subclass         <= 8'd0;
            intf_protocol         <= 8'd0;
            device_desc_valid     <= 1'b0;
            intf_class_valid      <= 1'b0;
            config_walk_done      <= 1'b0;
            hid_keyboard_seen     <= 1'b0;
            hid_iface_count       <= 4'd0;
            msc_iface_count       <= 4'd0;
            attached              <= 1'b0;
            desc_overflow_pulse   <= 1'b0;
            composite_hid_msc_pulse <= 1'b0;
            multi_hid_pulse       <= 1'b0;
            hid_keyboard_pulse    <= 1'b0;
            reenum_storm_pulse    <= 1'b0;
            bus_reset_d           <= 1'b0;
            reenum_window_cnt     <= 32'd0;
            reenum_count          <= 4'd0;
            reenum_storm_latched  <= 1'b0;
        end else begin
            // Default: pulses are one-cycle
            desc_overflow_pulse     <= 1'b0;
            composite_hid_msc_pulse <= 1'b0;
            multi_hid_pulse         <= 1'b0;
            hid_keyboard_pulse      <= 1'b0;
            reenum_storm_pulse      <= 1'b0;

            if (pkt_start || data_valid || pkt_end)
                attached <= 1'b1;

            // ---- Re-enumeration storm tracker ----
            bus_reset_d <= bus_reset;
            if (reenum_window_cnt != 32'd0)
                reenum_window_cnt <= reenum_window_cnt - 32'd1;
            else
                reenum_count <= 4'd0;

            if (bus_reset_rise) begin
                // New bus reset → drop sticky enum/attach so the next device
                // starts clean (also clears sniffer `approved` via !attached).
                state                 <= ST_IDLE;
                setup_count           <= 4'd0;
                got_len               <= 8'd0;
                scan_i                <= 6'd0;
                scan_guard            <= 4'd0;
                overflow_latched      <= 1'b0;
                vid                   <= 16'd0;
                pid_dev               <= 16'd0;
                dev_class             <= 8'd0;
                intf_class            <= 8'd0;
                intf_subclass         <= 8'd0;
                intf_protocol         <= 8'd0;
                device_desc_valid     <= 1'b0;
                intf_class_valid      <= 1'b0;
                config_walk_done      <= 1'b0;
                hid_keyboard_seen     <= 1'b0;
                hid_iface_count       <= 4'd0;
                msc_iface_count       <= 4'd0;
                attached              <= 1'b0;

                if (reenum_window_cnt == 32'd0) begin
                    reenum_window_cnt <= REENUM_WINDOW_CYCLES_P;
                    reenum_count      <= 4'd1;
                end else begin
                    reenum_count <= reenum_count + 4'd1;
                    if ((reenum_count + 4'd1) >= REENUM_STORM_THRESH_P &&
                        !reenum_storm_latched) begin
                        reenum_storm_latched <= 1'b1;
                        reenum_storm_pulse   <= 1'b1;
                    end
                end
            end

            // New SETUP on EP0 aborts any in-flight descriptor collection
            // (skipped on the bus_reset rising cycle — reset owns that beat).
            if (!bus_reset_rise &&
                pkt_end && crc_ok && (pid == PID_SETUP) && (endp == 4'h0)) begin
                state       <= ST_SETUP_DATA;
                setup_count <= 4'd0;
            end else if (!bus_reset_rise) begin
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
                                    // Overflow if host asks for >512
                                    if ({setup[7], setup[6]} > 16'd512) begin
                                        desc_overflow_pulse <= 1'b1;
                                        overflow_latched    <= 1'b1;
                                    end
                                    if ((setup[7] != 8'd0) || (setup[6] == 8'd0) ||
                                        (setup[6] > 8'd64))
                                        want_len <= 8'd64;
                                    else
                                        want_len <= setup[6];
                                    got_len <= 8'd0;
                                    // Fresh config walk — drop prior HID/intf latch
                                    // so MSC-then-HID / re-config is re-evaluated.
                                    hid_iface_count   <= 4'd0;
                                    msc_iface_count   <= 4'd0;
                                    hid_keyboard_seen <= 1'b0;
                                    intf_class_valid  <= 1'b0;
                                    intf_class        <= 8'd0;
                                    intf_subclass     <= 8'd0;
                                    intf_protocol     <= 8'd0;
                                    config_walk_done  <= 1'b0;
                                    state             <= ST_WAIT_DESC;
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
                            // Host wLength met, or config short-packet that already
                            // carries the full device wTotalLength (≤64B buffer).
                            end else if ((got_len >= want_len) ||
                                         ((want_dtype == DT_CONFIGURATION) &&
                                          (got_len >= 8'd4) &&
                                          ({mem[3], mem[2]} <= 16'd64) &&
                                          (got_len >= {mem[3], mem[2]}))) begin
                                if (want_dtype == DT_DEVICE) begin
                                    dev_class         <= mem[4];
                                    vid               <= {mem[9], mem[8]};
                                    pid_dev           <= {mem[11], mem[10]};
                                    device_desc_valid <= 1'b1;
                                    state             <= ST_IDLE;
                                end else if (want_dtype == DT_CONFIGURATION) begin
                                    w_total_length <= {mem[3], mem[2]};
                                    if ({mem[3], mem[2]} > 16'd512 && !overflow_latched) begin
                                        desc_overflow_pulse <= 1'b1;
                                        overflow_latched    <= 1'b1;
                                    end
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
                            // Finished (or aborted) walk — emit composite / multi-HID
                            config_walk_done  <= 1'b1;
                            if ((hid_iface_count > 4'd0) && (msc_iface_count > 4'd0))
                                composite_hid_msc_pulse <= 1'b1;
                            if (hid_iface_count > 4'd1)
                                multi_hid_pulse <= 1'b1;
                            state <= ST_IDLE;
                        end else if (dlen == 8'd0) begin
                            config_walk_done  <= 1'b1;
                            if ((hid_iface_count > 4'd0) && (msc_iface_count > 4'd0))
                                composite_hid_msc_pulse <= 1'b1;
                            if (hid_iface_count > 4'd1)
                                multi_hid_pulse <= 1'b1;
                            state <= ST_IDLE;
                        end else if (dtype == DT_INTERFACE) begin
                            // Latch first interface fields
                            if (!intf_class_valid) begin
                                intf_class       <= iface_class_b;
                                intf_subclass    <= iface_sub_b;
                                intf_protocol    <= iface_proto_b;
                                intf_class_valid <= 1'b1;
                            end
                            if (iface_class_b == `USB_CLASS_HID) begin
                                hid_iface_count <= hid_iface_count + 4'd1;
                                // Any HID interface requires operator approve (keyboard,
                                // mouse, or boot-protocol unknown). Timing filter still
                                // looks for boot-keyboard reports after approve.
                                if (!hid_keyboard_seen) begin
                                    hid_keyboard_seen  <= 1'b1;
                                    hid_keyboard_pulse <= 1'b1;
                                end
                            end else if (iface_class_b == `USB_CLASS_MSC) begin
                                msc_iface_count <= msc_iface_count + 4'd1;
                            end
                            scan_i <= scan_i + dlen[5:0];
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
