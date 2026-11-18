`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name:   sniffer_block
// Description:
//   Per-port USB packet sniffer (48 MHz domain). Soft RX via usb_packet_frontend,
//   enumeration_analysis telemetry (VID/PID/classes), isolation latch on CRC
//   fault (threat 0x5) and policy-gated HID handling:
//     policy 0 STORAGE_ONLY  → sticky UNAUTHORIZED_HID (0x1)
//     policy 1 HID_CONFIRM   → pending hold until APPROVE_HID (status bit)
//     policy 2 HID_ALLOW     → no auto HID hold
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module sniffer_block #(
    // usb_line_attach: 0=auto FS/LS from J, 1=force FS, 2=force LS (not HS)
    parameter int SPEED_MODE = 0
) (
    input  logic       clk_48m,
    input  logic       rst,

    input  logic       dp,
    input  logic       dm,

    input  logic       clear_fault,
    input  logic       manual_kill,
    input  logic [2:0] policy_mode,
    input  logic       approve_hid,

    output logic       pkt_start,
    output logic       pkt_end,
    output logic [3:0] pid,
    output logic [6:0] addr,
    output logic [3:0] endp,
    output logic       data_valid,
    output logic [7:0] data,
    output logic       crc_ok,

    output logic [7:0]  port_status,
    output logic [15:0] vid,
    output logic [15:0] pid_dev,
    output logic [7:0]  dev_class,
    output logic [7:0]  intf_class,
    output logic        device_desc_valid,
    output logic        intf_class_valid,

    output logic       kill,
    output logic [3:0] threat_code
);

    logic [10:0] frame_num;
    logic        crc_fault;
    logic        attached;
    logic        enum_attached; // mirror of line_attached inside enum (for SVA)
    logic        disconnect_stb;
    logic        speed_is_ls;
    logic        speed_valid;
    logic        intf_class_valid_d;
    logic        hid_threat_pulse;
    logic        hid_pending_set;
    logic        hid_pending;
    logic        hid_approved;
    logic        iso_kill;
    logic [3:0]  iso_threat;
    logic        threat_pulse;
    logic [3:0]  threat_code_in;

    usb_line_attach #(
        .SPEED_MODE(SPEED_MODE)
    ) u_attach (
        .clk            (clk_48m),
        .rst            (rst),
        .dp             (dp),
        .dm             (dm),
        .attached       (attached),
        .speed_is_ls    (speed_is_ls),
        .speed_valid    (speed_valid),
        .disconnect_stb (disconnect_stb)
    );

    usb_packet_frontend u_fe (
        .clk_48m     (clk_48m),
        .rst         (rst),
        .is_ls       (speed_is_ls),
        .speed_valid (speed_valid),
        .dp          (dp),
        .dm          (dm),
        .pkt_start   (pkt_start),
        .pkt_end     (pkt_end),
        .pid         (pid),
        .addr        (addr),
        .endp        (endp),
        .frame_num   (frame_num),
        .data_valid  (data_valid),
        .data        (data),
        .crc_ok      (crc_ok),
        .crc_fault   (crc_fault)
    );

    enumeration_analysis u_enum (
        .clk              (clk_48m),
        .rst              (rst),
        .line_attached    (attached),
        .clear_telemetry  (disconnect_stb),
        .pkt_start        (pkt_start),
        .pkt_end          (pkt_end),
        .pid              (pid),
        .addr             (addr),
        .endp             (endp),
        .data_valid       (data_valid),
        .data             (data),
        .crc_ok           (crc_ok),
        .vid              (vid),
        .pid_dev          (pid_dev),
        .dev_class        (dev_class),
        .intf_class       (intf_class),
        .device_desc_valid(device_desc_valid),
        .intf_class_valid (intf_class_valid),
        .attached         (enum_attached)
    );

    // Rising edge of latched HID interface class.
    always_ff @(posedge clk_48m) begin
        if (rst) intf_class_valid_d <= 1'b0;
        else     intf_class_valid_d <= intf_class_valid;
    end

    wire hid_rise = speed_valid &&
                    intf_class_valid && !intf_class_valid_d &&
                    (intf_class == 8'h03);

    // Mute policy until attach speed is locked (avoids LS false CRC on FS RX).
    assign hid_threat_pulse = hid_rise &&
                              (policy_mode == `CTRL_POLICY_STORAGE_ONLY);
    assign hid_pending_set  = hid_rise &&
                              (policy_mode == `CTRL_POLICY_HID_CONFIRM) &&
                              !hid_approved;

    // HID-after-confirm session latch. Disconnect clears pending + approval so
    // the next plug must confirm again. clear_fault does NOT release pending.
    always_ff @(posedge clk_48m) begin
        if (rst || disconnect_stb) begin
            hid_pending  <= 1'b0;
            hid_approved <= 1'b0;
        end else if (approve_hid) begin
            hid_pending  <= 1'b0;
            hid_approved <= 1'b1;
        end else if (hid_pending_set) begin
            hid_pending  <= 1'b1;
        end
    end

    wire crc_threat = speed_valid & crc_fault;

    assign threat_pulse   = crc_threat | hid_threat_pulse;
    assign threat_code_in = crc_threat       ? `THREAT_CRC_TOKEN_FAULT :
                            hid_threat_pulse ? `THREAT_UNAUTHORIZED_HID :
                                               `THREAT_NO_FAULT;

    isolation_controller u_iso (
        .clk           (clk_48m),
        .rst           (rst),
        .threat_pulse  (threat_pulse),
        .threat_code_in(threat_code_in),
        .manual_kill   (manual_kill),
        .clear_fault   (clear_fault),
        .kill          (iso_kill),
        .threat_code   (iso_threat)
    );

    // Pending HID hold ORs into kill; threat_code stays the sticky ISO code
    // (0 while only pending) — GUI keys off STATUS HID-pending bit / UART state.
    assign kill        = iso_kill | hid_pending;
    assign threat_code = iso_threat;

    // Midterm Table 26 / Fig. 19 port-status byte (provisional bit map).
    always_comb begin
        port_status = 8'h00;
        port_status[`PORT_STATUS_ATTACHED_BIT]        = attached;
        port_status[`PORT_STATUS_HID_PENDING_BIT]     = hid_pending;
        port_status[`PORT_STATUS_ISOLATED_BIT]        = kill;
        port_status[`PORT_STATUS_THREAT_PRESENT_BIT]  =
            (iso_threat != `THREAT_NO_FAULT) | hid_pending;
    end

`ifndef VERILATOR
    // synthesis translate_off
    sniffer_block_sva u_sniff_sva (
        .clk               (clk_48m),
        .rst               (rst),
        .speed_valid       (speed_valid),
        .crc_fault         (crc_fault),
        .policy_mode       (policy_mode),
        .intf_class_valid  (intf_class_valid),
        .intf_class_valid_d(intf_class_valid_d),
        .intf_class        (intf_class),
        .hid_threat_pulse  (hid_threat_pulse),
        .hid_pending       (hid_pending),
        .threat_pulse      (threat_pulse),
        .threat_code_in    (threat_code_in),
        .attached          (attached),
        .kill              (kill),
        .threat_code       (threat_code),
        .port_status       (port_status)
    );
    // synthesis translate_on
`endif

endmodule
