`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module: usb_demo_selfstim
// Purpose: On-FPGA FS packet player for Cmod demo without carrier USB taps.
//          Plays SETUP + device desc + SETUP + HID config → storage-only kill.
//////////////////////////////////////////////////////////////////////////////////

module usb_demo_selfstim (
    input  logic       clk_48m,
    input  logic       rst,
    input  logic       start,       // rising edge starts sequence when idle
    output logic       busy,
    output logic       done,
    output logic       tx_oe,
    output logic       tx_dp,
    output logic       tx_dn
);

    localparam [3:0] PID_SETUP = 4'b1101;
    localparam [3:0] PID_DATA0 = 4'b0011;
    localparam [3:0] PID_DATA1 = 4'b1011;
    localparam int   NUM_PKTS  = 6;

    logic [1:0] bit_phase;
    logic       bit_strobe;
    always_ff @(posedge clk_48m) begin
        if (rst) bit_phase <= 2'b00;
        else     bit_phase <= bit_phase + 2'b01;
    end
    assign bit_strobe = (bit_phase == 2'b00) && !rst;

    logic       pkt_start;
    logic       pkt_end;
    logic [3:0] pid;
    logic       tx_data_avail;
    logic       tx_data_get;
    logic [7:0] tx_data;

    usb_fs_tx u_tx (
        .clk_48mhz    (clk_48m),
        .clk          (clk_48m),
        .reset        (rst),
        .bit_strobe   (bit_strobe),
        .oe           (tx_oe),
        .dp           (tx_dp),
        .dn           (tx_dn),
        .pkt_start    (pkt_start),
        .pkt_end      (pkt_end),
        .pid          (pid),
        .tx_data_avail(tx_data_avail),
        .tx_data_get  (tx_data_get),
        .tx_data      (tx_data)
    );

    logic [3:0] pkt_pid_rom [0:5];
    logic [4:0] pkt_len_rom [0:5];
    logic [5:0] pkt_base   [0:5];
    logic [7:0] payload    [0:55];

    initial begin
        pkt_pid_rom[0] = PID_SETUP; pkt_len_rom[0] = 5'd2;  pkt_base[0] = 6'd0;
        pkt_pid_rom[1] = PID_DATA0; pkt_len_rom[1] = 5'd8;  pkt_base[1] = 6'd2;
        pkt_pid_rom[2] = PID_DATA1; pkt_len_rom[2] = 5'd18; pkt_base[2] = 6'd10;
        pkt_pid_rom[3] = PID_SETUP; pkt_len_rom[3] = 5'd2;  pkt_base[3] = 6'd28;
        pkt_pid_rom[4] = PID_DATA0; pkt_len_rom[4] = 5'd8;  pkt_base[4] = 6'd30;
        pkt_pid_rom[5] = PID_DATA1; pkt_len_rom[5] = 5'd18; pkt_base[5] = 6'd38;

        payload[0] = 8'h00; payload[1] = 8'h10;

        payload[2] = 8'h80; payload[3] = 8'h06; payload[4] = 8'h00; payload[5] = 8'h01;
        payload[6] = 8'h00; payload[7] = 8'h00; payload[8] = 8'h12; payload[9] = 8'h00;

        payload[10] = 8'h12; payload[11] = 8'h01; payload[12] = 8'h00; payload[13] = 8'h02;
        payload[14] = 8'h00; payload[15] = 8'h00; payload[16] = 8'h00; payload[17] = 8'h40;
        payload[18] = 8'h34; payload[19] = 8'h12; payload[20] = 8'h78; payload[21] = 8'h56;
        payload[22] = 8'h00; payload[23] = 8'h01; payload[24] = 8'h00; payload[25] = 8'h00;
        payload[26] = 8'h00; payload[27] = 8'h01;

        payload[28] = 8'h00; payload[29] = 8'h10;

        payload[30] = 8'h80; payload[31] = 8'h06; payload[32] = 8'h00; payload[33] = 8'h02;
        payload[34] = 8'h00; payload[35] = 8'h00; payload[36] = 8'h12; payload[37] = 8'h00;

        payload[38] = 8'h09; payload[39] = 8'h02; payload[40] = 8'h12; payload[41] = 8'h00;
        payload[42] = 8'h01; payload[43] = 8'h01; payload[44] = 8'h00; payload[45] = 8'hA0;
        payload[46] = 8'h32;
        payload[47] = 8'h09; payload[48] = 8'h04; payload[49] = 8'h00; payload[50] = 8'h00;
        payload[51] = 8'h01; payload[52] = 8'h03; payload[53] = 8'h01; payload[54] = 8'h02;
        payload[55] = 8'h00;
    end

    localparam [2:0] S_IDLE  = 3'd0;
    localparam [2:0] S_GAP   = 3'd1;
    localparam [2:0] S_ARM   = 3'd2;
    localparam [2:0] S_START = 3'd3;
    localparam [2:0] S_WAIT  = 3'd4;
    localparam [2:0] S_DONE  = 3'd5;

    logic [2:0] state;
    logic [2:0] pkt_i;
    logic [4:0] byte_i;
    logic [7:0] gap_cnt;
    logic       start_d;
    logic [5:0] pay_idx;

    assign busy = (state != S_IDLE) && (state != S_DONE);
    assign done = (state == S_DONE);
    assign pay_idx = pkt_base[pkt_i] + {1'b0, byte_i};
    assign tx_data_avail = ((state == S_WAIT) || (state == S_START) || (state == S_ARM)) &&
                           (byte_i < pkt_len_rom[pkt_i]);
    assign tx_data = payload[pay_idx];

    always_ff @(posedge clk_48m) begin
        if (rst) begin
            state     <= S_IDLE;
            pkt_i     <= 3'd0;
            byte_i    <= 5'd0;
            gap_cnt   <= 8'd0;
            pkt_start <= 1'b0;
            pid       <= 4'h0;
            start_d   <= 1'b0;
        end else begin
            start_d   <= start;
            pkt_start <= 1'b0;

            if (tx_data_get && tx_data_avail)
                byte_i <= byte_i + 5'd1;

            case (state)
                S_IDLE: begin
                    if (start && !start_d) begin
                        pkt_i   <= 3'd0;
                        gap_cnt <= 8'd16;
                        state   <= S_GAP;
                    end
                end

                S_GAP: begin
                    if (bit_strobe) begin
                        if (gap_cnt == 8'd0) state <= S_ARM;
                        else gap_cnt <= gap_cnt - 8'd1;
                    end
                end

                S_ARM: begin
                    byte_i <= 5'd0;
                    pid    <= pkt_pid_rom[pkt_i];
                    state  <= S_START;
                end

                S_START: begin
                    pkt_start <= 1'b1;
                    state     <= S_WAIT;
                end

                S_WAIT: begin
                    if (pkt_end) begin
                        if (pkt_i == 3'd5) begin
                            state <= S_DONE;
                        end else begin
                            pkt_i   <= pkt_i + 3'd1;
                            gap_cnt <= 8'd24;
                            state   <= S_GAP;
                        end
                    end
                end

                S_DONE: begin
                    // Hold until reset re-arms
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
