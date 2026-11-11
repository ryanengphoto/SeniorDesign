`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name:   sniffer_wrapper
// Description:
//   Instantiates NUM_PORTS identical sniffer_block instances and exposes
//   per-port tap / kill / threat / enum status / packet debug buses.
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module sniffer_wrapper #(
    // fabric_slop: storage-only ports kill unauthorized HID (bInterfaceClass 0x03)
    parameter bit POLICY_STORAGE_ONLY = 1'b1
) (
    input  logic       clk_48m,
    input  logic       rst,

    input  logic [`NUM_PORTS-1:0] dp,
    input  logic [`NUM_PORTS-1:0] dm,

    input  logic [`NUM_PORTS-1:0] clear_fault,
    input  logic [`NUM_PORTS-1:0] manual_kill,

    output logic [`NUM_PORTS-1:0] kill,
    output logic [3:0]            threat_code [`NUM_PORTS-1:0],

    output logic [7:0]  port_status [`NUM_PORTS-1:0],
    output logic [15:0] vid         [`NUM_PORTS-1:0],
    output logic [15:0] pid_dev     [`NUM_PORTS-1:0],
    output logic [7:0]  dev_class   [`NUM_PORTS-1:0],
    output logic [7:0]  intf_class  [`NUM_PORTS-1:0],
    output logic        device_desc_valid [`NUM_PORTS-1:0],
    output logic        intf_class_valid  [`NUM_PORTS-1:0],

    // Per-port packet debug (E2E scoreboard / bring-up)
    output logic       pkt_start  [`NUM_PORTS-1:0],
    output logic       pkt_end    [`NUM_PORTS-1:0],
    output logic [3:0] pid        [`NUM_PORTS-1:0],
    output logic [3:0] endp       [`NUM_PORTS-1:0],
    output logic       data_valid [`NUM_PORTS-1:0],
    output logic [7:0] data       [`NUM_PORTS-1:0],
    output logic       crc_ok     [`NUM_PORTS-1:0]
);

    logic [6:0] addr [`NUM_PORTS-1:0];

    genvar i;
    generate
        for (i = 0; i < `NUM_PORTS; i = i + 1) begin : g_port
            sniffer_block #(
                .POLICY_STORAGE_ONLY(POLICY_STORAGE_ONLY)
            ) u_sniffer (
                .clk_48m          (clk_48m),
                .rst              (rst),
                .dp               (dp[i]),
                .dm               (dm[i]),
                .clear_fault      (clear_fault[i]),
                .manual_kill      (manual_kill[i]),
                .pkt_start         (pkt_start[i]),
                .pkt_end           (pkt_end[i]),
                .pid               (pid[i]),
                .addr              (addr[i]),
                .endp              (endp[i]),
                .data_valid        (data_valid[i]),
                .data              (data[i]),
                .crc_ok            (crc_ok[i]),
                .port_status       (port_status[i]),
                .vid               (vid[i]),
                .pid_dev           (pid_dev[i]),
                .dev_class         (dev_class[i]),
                .intf_class        (intf_class[i]),
                .device_desc_valid (device_desc_valid[i]),
                .intf_class_valid  (intf_class_valid[i]),
                .kill              (kill[i]),
                .threat_code       (threat_code[i])
            );
        end
    endgenerate

endmodule
