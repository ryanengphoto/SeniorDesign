`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: sniffer_channel
// Purpose: One-port sim/RTL slice: packet frontend + CRC→isolation.
//          DPI / HID filters hook in later as additional threat sources.
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module sniffer_channel (
    input  logic       clk_48m,
    input  logic       rst,

    input  logic       dp,
    input  logic       dm,

    input  logic       clear_fault,
    input  logic       manual_kill,

    output logic       pkt_start,
    output logic       pkt_end,
    output logic [3:0] pid,
    output logic       data_valid,
    output logic [7:0] data,
    output logic       crc_ok,

    output logic       kill,
    output logic [3:0] threat_code
);

    logic [6:0]  addr;
    logic [3:0]  endp;
    logic [10:0] frame_num;
    logic        crc_fault;

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

    isolation_controller u_iso (
        .clk           (clk_48m),
        .rst           (rst),
        .threat_pulse  (crc_fault),
        .threat_code_in(`THREAT_CRC_TOKEN_FAULT),
        .manual_kill   (manual_kill),
        .clear_fault   (clear_fault),
        .kill          (kill),
        .threat_code   (threat_code)
    );

endmodule
