`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: usb_packet_frontend_sva
// Purpose: CRC-fault / in-packet monitors for usb_packet_frontend.
//          crc_fault is a registered pulse aligned to the pkt_end cycle in RTL
//          NBA terms — observe with a 1-cycle delayed pkt_end sample.
//////////////////////////////////////////////////////////////////////////////////

module usb_packet_frontend_sva (
    input logic clk,
    input logic rst,
    input logic pkt_start,
    input logic pkt_end,
    input logic data_valid,
    input logic crc_ok,
    input logic crc_fault
);

    logic sample_valid;
    logic in_pkt;
    logic pkt_end_d;
    logic crc_ok_d;

    always_ff @(posedge clk) begin
        if (rst) begin
            sample_valid <= 1'b0;
            in_pkt       <= 1'b0;
            pkt_end_d    <= 1'b0;
            crc_ok_d     <= 1'b1;
        end else begin
            if (sample_valid) begin
                // crc_fault NBA from prior edge when pkt_end was high
                if (crc_fault && !pkt_end_d)
                    $error("usb_packet_frontend SVA: crc_fault without prior pkt_end");

                if (crc_fault && crc_ok_d)
                    $error("usb_packet_frontend SVA: crc_fault after crc_ok packet");

                if (pkt_end && !in_pkt && !pkt_start)
                    $error("usb_packet_frontend SVA: pkt_end without in-packet");

                if (data_valid && !in_pkt && !pkt_start)
                    $error("usb_packet_frontend SVA: data_valid outside packet");
            end

            sample_valid <= 1'b1;
            pkt_end_d    <= pkt_end;
            crc_ok_d     <= crc_ok;

            if (pkt_start)
                in_pkt <= 1'b1;
            else if (pkt_end)
                in_pkt <= 1'b0;
        end
    end

endmodule
