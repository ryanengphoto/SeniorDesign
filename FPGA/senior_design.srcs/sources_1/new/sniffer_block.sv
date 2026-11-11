`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name:   sniffer_block
// Description:
//   Per-port USB packet sniffer (48 MHz domain). Soft RX via usb_packet_frontend,
//   enumeration_analysis telemetry (VID/PID/classes), isolation latch on CRC
//   fault (threat 0x5) and optional storage-only HID class kill (threat 0x1).
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module sniffer_block #(
    parameter bit POLICY_STORAGE_ONLY = 1'b1
) (
    input  logic       clk_48m,
    input  logic       rst,

    input  logic       dp,
    input  logic       dm,

    input  logic       clear_fault,
    input  logic       manual_kill,

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
    logic        intf_class_valid_d;
    logic        hid_threat_pulse;
    logic        threat_pulse;
    logic [3:0]  threat_code_in;

    usb_packet_frontend u_fe (
        .clk_48m   (clk_48m),
        .rst       (rst),
        .dp        (dp),
        .dm        (dm),
        .pkt_start (pkt_start),
        .pkt_end   (pkt_end),
        .pid       (pid),
        .addr      (addr),
        .endp      (endp),
        .frame_num (frame_num),
        .data_valid(data_valid),
        .data      (data),
        .crc_ok    (crc_ok),
        .crc_fault (crc_fault)
    );

    enumeration_analysis u_enum (
        .clk              (clk_48m),
        .rst              (rst),
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
        .attached         (attached)
    );

    // Rising edge of latched HID interface class on a storage-only port.
    always_ff @(posedge clk_48m) begin
        if (rst) intf_class_valid_d <= 1'b0;
        else     intf_class_valid_d <= intf_class_valid;
    end

    assign hid_threat_pulse = POLICY_STORAGE_ONLY &&
                              intf_class_valid && !intf_class_valid_d &&
                              (intf_class == 8'h03);

    assign threat_pulse   = crc_fault | hid_threat_pulse;
    assign threat_code_in = crc_fault        ? `THREAT_CRC_TOKEN_FAULT :
                            hid_threat_pulse ? `THREAT_UNAUTHORIZED_HID :
                                               `THREAT_NO_FAULT;

    isolation_controller u_iso (
        .clk           (clk_48m),
        .rst           (rst),
        .threat_pulse  (threat_pulse),
        .threat_code_in(threat_code_in),
        .manual_kill   (manual_kill),
        .clear_fault   (clear_fault),
        .kill          (kill),
        .threat_code   (threat_code)
    );

    // Midterm Table 26 / Fig. 19 port-status byte (provisional bit map).
    always_comb begin
        port_status = 8'h00;
        port_status[`PORT_STATUS_ATTACHED_BIT]       = attached;
        port_status[`PORT_STATUS_ISOLATED_BIT]       = kill;
        port_status[`PORT_STATUS_THREAT_PRESENT_BIT] = (threat_code != `THREAT_NO_FAULT);
    end

endmodule
