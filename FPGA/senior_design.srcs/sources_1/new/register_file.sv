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
//   Per-port CONTROL + STATUS (stride 2). SPI host bus plus parallel
//   sniffer status_in and control/pulse outputs. Does not drive switch_en
//   pads (isolation path owns those).
//
// Dependencies:  defines.svh
//
// Notes:
//   Ports per Agents/fpga_module_io_plan.md. confirm_hid / clear_fault
//   leave as one-cycle pulses on CONTROL writes; status_we updates STATUS
//   from sniffers. Switch side-effects remain outside this module.
//
// Revision:
// Revision 0.08 - Parallel status_in / control_out / kill-confirm pulses
//////////////////////////////////////////////////////////////////////////////////

module register_file (
    input  logic                       clk,
    input  logic                       rst,

    input  logic [`SPI_ADDR_WIDTH-1:0] addr,
    input  logic [`SPI_DATA_WIDTH-1:0] data_in,
    output logic [`SPI_DATA_WIDTH-1:0] data_out,
    input  logic                       write_en,
    input  logic                       read_en,

    input  status_reg_t                status_in  [`NUM_PORTS],
    input  logic [`NUM_PORTS-1:0]      status_we,

    output control_reg_t               control_out [`NUM_PORTS],
    output logic [`NUM_PORTS-1:0]      manual_kill,
    output logic [`NUM_PORTS-1:0]      clear_fault_pulse,
    output logic [`NUM_PORTS-1:0]      confirm_hid_pulse
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
            control_reg        <= '{default: '0};
            status_reg         <= '{default: '0};
            clear_fault_pulse  <= '0;
            confirm_hid_pulse  <= '0;
        end else begin
            clear_fault_pulse <= '0;
            confirm_hid_pulse <= '0;

            // Sniffer status sample (same fabric clk — no CDC)
            for (int i = 0; i < `NUM_PORTS; i++) begin
                if (status_we[i])
                    status_reg[i] <= status_in[i];
            end

            if (write_en && port_sel_valid &&
                (port_off == `PORT_OFF_CONTROL)) begin
                control_reg[port_idx] <= data_in;

                if (data_in[6])
                    clear_fault_pulse[port_idx] <= 1'b1;

                // confirm_hid strobe: operator confirmed keyboard in GUI
                if (data_in[5]) begin
                    confirm_hid_pulse[port_idx]   <= 1'b1;
                    status_reg[port_idx].hid_locked <= 1'b0;
                    status_reg[port_idx].isolated   <= 1'b0;
                end
            end
        end
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

    always_comb begin
        for (int i = 0; i < `NUM_PORTS; i++) begin
            control_out[i] = control_reg[i];
            manual_kill[i] = control_reg[i].manual_kill;
        end
    end

endmodule
