`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: usb_packet_frontend
// Purpose: Project wrapper around TinyFPGA usb_fs_rx for the USB sniffer.
//          - Single-clock early bring-up (clk_48m used for both RX domains)
//          - Strips trailing CRC16 bytes from DATA packet payloads
//          - Pulses crc_fault on pkt_end when valid_packet is low
//
// Notes:   Sim / RTL bring-up. Do not drive board taps from TX.
//////////////////////////////////////////////////////////////////////////////////

module usb_packet_frontend (
    input  logic       clk_48m,
    input  logic       rst,

    input  logic       dp,
    input  logic       dm,

    output logic       pkt_start,
    output logic       pkt_end,
    output logic [3:0] pid,
    output logic [6:0] addr,
    output logic [3:0] endp,
    output logic [10:0] frame_num,

    // Payload only (CRC16 removed for DATA PIDs)
    output logic       data_valid,
    output logic [7:0] data,

    output logic       crc_ok,
    output logic       crc_fault
);

    logic        rx_bit_strobe;
    logic        rx_pkt_start;
    logic        rx_pkt_end;
    logic [3:0]  rx_pid;
    logic [6:0]  rx_addr;
    logic [3:0]  rx_endp;
    logic [10:0] rx_frame_num;
    logic        rx_data_put;
    logic [7:0]  rx_data;
    logic        rx_valid_packet;

    usb_fs_rx u_rx (
        .clk_48mhz   (clk_48m),
        .clk         (clk_48m),
        .reset       (rst),
        .dp          (dp),
        .dn          (dm),
        .bit_strobe  (rx_bit_strobe),
        .pkt_start   (rx_pkt_start),
        .pkt_end     (rx_pkt_end),
        .pid         (rx_pid),
        .addr        (rx_addr),
        .endp        (rx_endp),
        .frame_num   (rx_frame_num),
        .rx_data_put (rx_data_put),
        .rx_data     (rx_data),
        .valid_packet(rx_valid_packet)
    );

    assign pkt_start = rx_pkt_start;
    assign pkt_end   = rx_pkt_end;
    assign pid       = rx_pid;
    assign addr      = rx_addr;
    assign endp      = rx_endp;
    assign frame_num = rx_frame_num;
    assign crc_ok    = rx_valid_packet;

    // 2-deep skid: DATA PIDs append CRC16 on rx_data; emit only payload.
    logic [7:0] hold0, hold1;
    logic [1:0] fill;

    always_ff @(posedge clk_48m) begin
        if (rst) begin
            fill       <= 2'd0;
            hold0      <= 8'h00;
            hold1      <= 8'h00;
            data_valid <= 1'b0;
            data       <= 8'h00;
            crc_fault  <= 1'b0;
        end else begin
            data_valid <= 1'b0;
            crc_fault  <= 1'b0;

            if (rx_pkt_start) begin
                fill <= 2'd0;
            end

            if (rx_data_put) begin
                unique case (fill)
                    2'd0: begin
                        hold0 <= rx_data;
                        fill  <= 2'd1;
                    end
                    2'd1: begin
                        hold1 <= rx_data;
                        fill  <= 2'd2;
                    end
                    default: begin
                        data_valid <= 1'b1;
                        data       <= hold0;
                        hold0      <= hold1;
                        hold1      <= rx_data;
                    end
                endcase
            end

            if (rx_pkt_end) begin
                // Drop residual CRC bytes (fill==2) or short residuals.
                fill <= 2'd0;
                if (!rx_valid_packet)
                    crc_fault <= 1'b1;
            end
        end
    end

endmodule
