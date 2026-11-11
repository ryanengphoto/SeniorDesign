`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: register_file
// Purpose: MCU-visible status/control map (Docs/fabric_slop.md §5).
//          Sniffer state is mirrored every cycle. Pn_CONTROL[6] pulses
//          clear_fault; [7] drives manual_kill level.
// Notes:   Bring-up uses one clock (same as sniffers). 48↔100 CDC later.
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module register_file (
    input  logic clk,
    input  logic rst,

    input  logic       reg_we,
    input  logic [6:0] reg_waddr,
    input  logic [7:0] reg_wdata,
    input  logic [6:0] reg_raddr,
    output logic [7:0] reg_rdata,

    input  logic [`NUM_PORTS-1:0] kill,
    input  logic [3:0]            threat_code [`NUM_PORTS-1:0],
    input  logic [7:0]            port_status [`NUM_PORTS-1:0],
    input  logic [15:0]           vid         [`NUM_PORTS-1:0],
    input  logic [15:0]           pid_dev     [`NUM_PORTS-1:0],
    input  logic [7:0]            dev_class   [`NUM_PORTS-1:0],
    input  logic [7:0]            intf_class  [`NUM_PORTS-1:0],

    output logic [`NUM_PORTS-1:0] clear_fault,
    output logic [`NUM_PORTS-1:0] manual_kill
);

    logic [7:0] sys_control;
    logic [7:0] p_control [0:`NUM_PORTS-1];

    wire [2:0] w_port = reg_waddr[6:4] - 3'h1;
    wire [2:0] r_port = reg_raddr[6:4] - 3'h1;
    wire w_is_port = (reg_waddr[6:4] >= 3'h1) && (reg_waddr[6:4] <= 3'h4);
    wire r_is_port = (reg_raddr[6:4] >= 3'h1) && (reg_raddr[6:4] <= 3'h4);

    function automatic [7:0] pack_spi_status(
        input logic       kill_i,
        input logic [3:0] threat_i,
        input logic [7:0] mid_status
    );
        pack_spi_status = 8'h00;
        pack_spi_status[7]   = kill_i;
        pack_spi_status[6]   = mid_status[`PORT_STATUS_ATTACHED_BIT];
        pack_spi_status[5]   = 1'b0;
        pack_spi_status[3:0] = threat_i;
    endfunction

    integer i;

    always_ff @(posedge clk) begin
        if (rst) begin
            sys_control <= 8'h00;
            clear_fault <= {`NUM_PORTS{1'b0}};
            for (i = 0; i < `NUM_PORTS; i = i + 1)
                p_control[i] <= 8'h00;
        end else begin
            clear_fault <= {`NUM_PORTS{1'b0}};

            if (reg_we) begin
                if (reg_waddr == `ADDR_SYS_CONTROL)
                    sys_control <= reg_wdata;

                // Pn_CONTROL at 0x10 / 0x20 / 0x30 / 0x40
                if (w_is_port && reg_waddr[3:0] == 4'h0) begin
                    p_control[w_port] <= reg_wdata;
                    if (reg_wdata[6])
                        clear_fault[w_port] <= 1'b1;
                end
            end
        end
    end

    assign manual_kill[0] = p_control[0][7];
    assign manual_kill[1] = p_control[1][7];
    assign manual_kill[2] = p_control[2][7];
    assign manual_kill[3] = p_control[3][7];

    always_comb begin
        reg_rdata = 8'h00;
        if (reg_raddr == `ADDR_SYS_STATUS)
            reg_rdata = {4'h0, kill};
        else if (reg_raddr == `ADDR_SYS_CONTROL)
            reg_rdata = sys_control;
        else if (reg_raddr == `ADDR_PORT_IRQ)
            reg_rdata = {4'h0, kill};
        else if (r_is_port) begin
            case (reg_raddr[3:0])
                4'h0: reg_rdata = p_control[r_port];
                4'h1: reg_rdata = pack_spi_status(
                          kill[r_port], threat_code[r_port], port_status[r_port]);
                4'h2: reg_rdata = vid[r_port][15:8];
                4'h3: reg_rdata = vid[r_port][7:0];
                4'h4: reg_rdata = pid_dev[r_port][15:8];
                4'h5: reg_rdata = pid_dev[r_port][7:0];
                4'h6: reg_rdata = dev_class[r_port];
                4'h7: reg_rdata = intf_class[r_port];
                default: reg_rdata = 8'h00;
            endcase
        end
    end

endmodule
