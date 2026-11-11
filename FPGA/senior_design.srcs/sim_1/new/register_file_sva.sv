`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: register_file_sva
// Purpose: Per-port CONTROL → clear/manual; RO mirror of sniffer telemetry.
//          clear_fault pulses the cycle after reg_we (both clocked).
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module register_file_sva (
    input logic                   clk,
    input logic                   rst,
    input logic                   reg_we,
    input logic [6:0]             reg_waddr,
    input logic [7:0]             reg_wdata,
    input logic [6:0]             reg_raddr,
    input logic [7:0]             reg_rdata,
    input logic [`NUM_PORTS-1:0]  kill,
    input logic [3:0]             threat_code [`NUM_PORTS-1:0],
    input logic [7:0]             port_status [`NUM_PORTS-1:0],
    input logic [15:0]            vid         [`NUM_PORTS-1:0],
    input logic [15:0]            pid_dev     [`NUM_PORTS-1:0],
    input logic [7:0]             dev_class   [`NUM_PORTS-1:0],
    input logic [7:0]             intf_class  [`NUM_PORTS-1:0],
    input logic [`NUM_PORTS-1:0]  clear_fault,
    input logic [`NUM_PORTS-1:0]  manual_kill,
    input logic [7:0]             p_control [0:`NUM_PORTS-1]
);

    logic        sample_valid;
    logic        we_d;
    logic [6:0]  waddr_d;
    logic [7:0]  wdata_d;
    integer      i;

    wire [2:0] wp_d = waddr_d[6:4] - 3'h1;
    wire       w_is_port_d = (waddr_d[6:4] >= 3'h1) && (waddr_d[6:4] <= 3'h4);
    wire [2:0] r_port = reg_raddr[6:4] - 3'h1;
    wire       r_is_port = (reg_raddr[6:4] >= 3'h1) && (reg_raddr[6:4] <= 3'h4);

    function automatic [7:0] pack_spi_status(
        input logic       kill_i,
        input logic [3:0] threat_i,
        input logic [7:0] mid_status
    );
        pack_spi_status = 8'h00;
        pack_spi_status[7]   = kill_i;
        pack_spi_status[6]   = mid_status[`PORT_STATUS_ATTACHED_BIT];
        pack_spi_status[3:0] = threat_i;
    endfunction

    always_ff @(posedge clk) begin
        if (rst) begin
            sample_valid <= 1'b0;
            we_d         <= 1'b0;
            waddr_d      <= 7'h0;
            wdata_d      <= 8'h0;
        end else begin
            if (sample_valid) begin
                for (i = 0; i < `NUM_PORTS; i = i + 1) begin
                    if (manual_kill[i] !== p_control[i][7])
                        $error("register_file SVA: manual_kill[%0d] != CONTROL[7]", i);
                end

                // clear_fault is registered from prior-cycle CONTROL[6] write
                if (we_d && w_is_port_d && (waddr_d[3:0] == 4'h0) && wdata_d[6]) begin
                    if (!clear_fault[wp_d])
                        $error("register_file SVA: CONTROL[6] did not pulse clear_fault[%0d]",
                               wp_d);
                    for (i = 0; i < `NUM_PORTS; i = i + 1) begin
                        if (i != wp_d && clear_fault[i])
                            $error("register_file SVA: clear spilled to port%0d", i);
                    end
                end else if (clear_fault != {`NUM_PORTS{1'b0}}) begin
                    $error("register_file SVA: clear_fault without prior CONTROL[6] write");
                end

                if (reg_raddr == `ADDR_SYS_STATUS) begin
                    if (reg_rdata[3:0] !== kill)
                        $error("register_file SVA: SYS_STATUS kill mirror mismatch");
                end else if (r_is_port) begin
                    case (reg_raddr[3:0])
                        4'h1: if (reg_rdata !==
                                  pack_spi_status(kill[r_port], threat_code[r_port],
                                                  port_status[r_port]))
                                  $error("register_file SVA: STATUS pack mismatch port%0d",
                                         r_port);
                        4'h2: if (reg_rdata !== vid[r_port][15:8])
                                  $error("register_file SVA: VIDH mismatch");
                        4'h3: if (reg_rdata !== vid[r_port][7:0])
                                  $error("register_file SVA: VIDL mismatch");
                        4'h4: if (reg_rdata !== pid_dev[r_port][15:8])
                                  $error("register_file SVA: PIDH mismatch");
                        4'h5: if (reg_rdata !== pid_dev[r_port][7:0])
                                  $error("register_file SVA: PIDL mismatch");
                        4'h6: if (reg_rdata !== dev_class[r_port])
                                  $error("register_file SVA: DEV_CLASS mismatch");
                        4'h7: if (reg_rdata !== intf_class[r_port])
                                  $error("register_file SVA: INT_CLASS mismatch");
                        default: ;
                    endcase
                end
            end
            sample_valid <= 1'b1;
            we_d         <= reg_we;
            waddr_d      <= reg_waddr;
            wdata_d      <= reg_wdata;
        end
    end

endmodule
