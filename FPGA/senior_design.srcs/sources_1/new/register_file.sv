`timescale 1ns / 1ps
`include "defines.svh"

//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date:   09/10/2026
// Design Name:   Hardware-Isolated USB Security Gateway
// Module Name:   register_file
// Project Name:  senior_design
// Target Devices: XC7S25-CSGA225 (Digilent Cmod S7-25)
// Tool Versions: Vivado 2018.2
// Description:
//   Per-port CONTROL + STATUS (stride 2). HID keyboard detect sets
//   hid_locked and opens the high-speed analog switch (host blocked).
//   GUI confirm → MCU pulses CONTROL.confirm_hid → clear hid_locked and
//   close the switch so traffic can resume; timing filter runs after.
//
// Dependencies:  defines.svh
//
// Notes:
//   Partial — SPI R/W of CONTROL/STATUS; sniffer status write and switch
//   side-effects not fully wired yet.
//
// Revision:
// Revision 0.07 - GUI confirm HID; analog-switch quarantine (no PIN)
//////////////////////////////////////////////////////////////////////////////////

module register_file (
    input  logic                         clk,
    input  logic                         rst,
    input  logic [`SPI_ADDR_WIDTH-1:0]   addr,
    input  logic [`SPI_DATA_WIDTH-1:0]   data_in,
    output logic [`SPI_DATA_WIDTH-1:0]   data_out,
    input  logic                         write_en,
    input  logic                         read_en
    // TODO: parallel control_out / status_in; analog-switch kill per port
);

    control_reg_t control_reg [`NUM_PORTS];
    status_reg_t  status_reg  [`NUM_PORTS];

    // addr = port * 2 + offset → port = addr>>1, offset = addr[0]
    logic       port_sel_valid;
    logic [5:0] port_idx_u;
    logic [1:0] port_idx;
    logic       port_off;

    always_comb begin
        port_off       = addr[0];
        port_idx_u     = addr[`SPI_ADDR_WIDTH-1:1];
        port_idx       = port_idx_u[1:0];
        port_sel_valid = (port_idx_u < `NUM_PORTS);
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            control_reg <= '{default: '0};
            status_reg  <= '{default: '0};
        end else if (write_en && port_sel_valid &&
                     (port_off == `PORT_OFF_CONTROL)) begin
            control_reg[port_idx] <= data_in;
            // confirm_hid strobe: operator clicked "this is a keyboard"
            if (data_in[5]) begin
                status_reg[port_idx].hid_locked <= 1'b0;
                status_reg[port_idx].isolated  <= 1'b0;
                // TODO: close high-speed analog switch (reconnect to hub)
            end
            // TODO: manual_kill / clear_fault → switch / threat side-effects
        end
        // TODO: sniffer sets hid_locked + opens analog switch on HID detect
    end

    always_comb begin
        data_out = '0;
        if (read_en && port_sel_valid) begin
            unique case (port_off)
                `PORT_OFF_CONTROL: data_out = control_reg[port_idx];
                `PORT_OFF_STATUS:  data_out = status_reg[port_idx];
            endcase
        end
    end

endmodule
