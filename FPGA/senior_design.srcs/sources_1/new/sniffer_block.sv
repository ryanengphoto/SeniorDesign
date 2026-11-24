`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Per-port USB sniffer (48 MHz): attach/PHY, enum analysis, HID timing, kill.
// Policies: 0 storage-only, 1 HID-confirm, 2 HID-allow.
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module sniffer_block #(
    // 0 = auto FS/LS, 1 = FS, 2 = LS
    parameter int SPEED_MODE = 0,
    // Sim overrides
    parameter int HID_MIN_INTERVAL_CYCLES_P = `HID_MIN_INTERVAL_CYCLES,
    parameter int HID_QUARANTINE_CYCLES_P   = `HID_QUARANTINE_CYCLES,
    parameter int REENUM_WINDOW_CYCLES_P    = `REENUM_WINDOW_CYCLES,
    parameter int REENUM_STORM_THRESH_P     = `REENUM_STORM_THRESHOLD
) (
    input  logic       clk_48m,
    input  logic       rst,

    input  logic       dp,
    input  logic       dm,

    input  logic       clear_fault,
    input  logic       manual_kill,
    input  logic [2:0] policy_mode,
    input  logic       approve_hid,

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
    output logic [3:0]  threat_detail,

    output logic       kill,
    output logic [3:0] threat_code
);

    logic [10:0] frame_num;
    logic        crc_fault;
    logic        attached;
    logic        enum_attached;
    logic        disconnect_stb;
    logic        speed_is_ls;
    logic        speed_valid;

    logic [7:0]  intf_subclass;
    logic [7:0]  intf_protocol;
    logic        config_walk_done;
    logic        hid_keyboard_seen;
    logic [3:0]  hid_iface_count;
    logic [3:0]  msc_iface_count;

    logic        desc_overflow_pulse;
    logic        composite_hid_msc_pulse;
    logic        multi_hid_pulse;
    logic        hid_keyboard_pulse;
    logic        reenum_storm_pulse;

    logic        keystroke_burst_pulse;
    logic        cooldown_burst_pulse;

    logic        hid_pending;
    logic        hid_approved;
    logic        iso_kill;
    logic [3:0]  iso_threat;

    logic        suspicious_pulse;
    logic [3:0]  suspicious_detail;
    logic        suspicious_sticky;
    logic        suspicious_hold;
    logic        unauthorized_hid_pulse;
    logic        threat_pulse;
    logic [3:0]  threat_code_in;
    logic [3:0]  detail_sticky;

    usb_line_attach #(
        .SPEED_MODE(SPEED_MODE)
    ) u_attach (
        .clk            (clk_48m),
        .rst            (rst),
        .dp             (dp),
        .dm             (dm),
        .attached       (attached),
        .speed_is_ls    (speed_is_ls),
        .speed_valid    (speed_valid),
        .disconnect_stb (disconnect_stb)
    );

    usb_packet_frontend u_fe (
        .clk_48m     (clk_48m),
        .rst         (rst),
        .is_ls       (speed_is_ls),
        .speed_valid (speed_valid),
        .dp          (dp),
        .dm          (dm),
        .pkt_start   (pkt_start),
        .pkt_end     (pkt_end),
        .pid         (pid),
        .addr        (addr),
        .endp        (endp),
        .frame_num   (frame_num),
        .data_valid  (data_valid),
        .data        (data),
        .crc_ok      (crc_ok),
        .crc_fault   (crc_fault)
    );

    enumeration_analysis #(
        .REENUM_WINDOW_CYCLES_P(REENUM_WINDOW_CYCLES_P),
        .REENUM_STORM_THRESH_P (REENUM_STORM_THRESH_P)
    ) u_enum (
        .clk                    (clk_48m),
        .rst                    (rst),
        .line_attached          (attached),
        .clear_telemetry        (disconnect_stb),
        .pkt_start              (pkt_start),
        .pkt_end                (pkt_end),
        .pid                    (pid),
        .addr                   (addr),
        .endp                   (endp),
        .data_valid             (data_valid),
        .data                   (data),
        .crc_ok                 (crc_ok),
        .vid                    (vid),
        .pid_dev                (pid_dev),
        .dev_class              (dev_class),
        .intf_class             (intf_class),
        .intf_subclass          (intf_subclass),
        .intf_protocol          (intf_protocol),
        .device_desc_valid      (device_desc_valid),
        .intf_class_valid       (intf_class_valid),
        .config_walk_done       (config_walk_done),
        .hid_keyboard_seen      (hid_keyboard_seen),
        .hid_iface_count        (hid_iface_count),
        .msc_iface_count        (msc_iface_count),
        .attached               (enum_attached),
        .desc_overflow_pulse    (desc_overflow_pulse),
        .composite_hid_msc_pulse(composite_hid_msc_pulse),
        .multi_hid_pulse        (multi_hid_pulse),
        .hid_keyboard_pulse     (hid_keyboard_pulse),
        .reenum_storm_pulse     (reenum_storm_pulse)
    );

    // HID-confirm session
    wire hid_class_now = speed_valid && intf_class_valid && (intf_class == 8'h03);

    always_ff @(posedge clk_48m) begin
        if (rst || disconnect_stb || manual_kill) begin
            hid_pending  <= 1'b0;
            hid_approved <= 1'b0;
        end else if (approve_hid) begin
            hid_pending  <= 1'b0;
            hid_approved <= 1'b1;
        end else if ((policy_mode == `CTRL_POLICY_HID_CONFIRM) &&
                     !hid_approved &&
                     (hid_keyboard_seen || hid_class_now)) begin
            hid_pending <= 1'b1;
        end
    end

    // Hold kill until class is known non-HID, or host approves HID.
    wire hid_confirm_hold =
        (policy_mode == `CTRL_POLICY_HID_CONFIRM) &&
        attached && speed_valid &&
        !hid_approved &&
        !manual_kill &&
        (!intf_class_valid || (intf_class == 8'h03) || hid_keyboard_seen);

    // Arm keystroke filter after approve (confirm) or immediately (allow).
    wire hid_filter_en = speed_valid && hid_keyboard_seen &&
        (policy_mode != `CTRL_POLICY_STORAGE_ONLY) &&
        ((policy_mode == `CTRL_POLICY_HID_ALLOW) || hid_approved);

    hid_timing_filter #(
        .MIN_INTERVAL_CYCLES(HID_MIN_INTERVAL_CYCLES_P),
        .QUARANTINE_CYCLES  (HID_QUARANTINE_CYCLES_P)
    ) u_hid (
        .clk                   (clk_48m),
        .rst                   (rst),
        .enable                (hid_filter_en),
        .config_walk_done      (config_walk_done),
        .hid_present           (hid_keyboard_seen),
        .pkt_start             (pkt_start),
        .pkt_end               (pkt_end),
        .pid                   (pid),
        .endp                  (endp),
        .data_valid            (data_valid),
        .data                  (data),
        .crc_ok                (crc_ok),
        .keystroke_burst_pulse (keystroke_burst_pulse),
        .cooldown_burst_pulse  (cooldown_burst_pulse)
    );

    assign suspicious_pulse =
        desc_overflow_pulse | composite_hid_msc_pulse |
        multi_hid_pulse | reenum_storm_pulse;

    always_comb begin
        if (desc_overflow_pulse)
            suspicious_detail = `DETAIL_OVERFLOW;
        else if (composite_hid_msc_pulse)
            suspicious_detail = `DETAIL_COMPOSITE_HID_MSC;
        else if (multi_hid_pulse)
            suspicious_detail = `DETAIL_MULTI_HID;
        else if (reenum_storm_pulse)
            suspicious_detail = `DETAIL_REENUM_STORM;
        else
            suspicious_detail = `DETAIL_NONE;
    end

    // Sticky suspicious-enum flag; pulse wins over disconnect on the same cycle.
    always_ff @(posedge clk_48m) begin
        if (rst) begin
            suspicious_sticky <= 1'b0;
            detail_sticky     <= `DETAIL_NONE;
        end else if (suspicious_pulse) begin
            suspicious_sticky <= 1'b1;
            detail_sticky     <= suspicious_detail;
        end else if (disconnect_stb) begin
            suspicious_sticky <= 1'b0;
            detail_sticky     <= `DETAIL_NONE;
        end
    end

    assign suspicious_hold = suspicious_sticky && !kill;

    // Storage-only policy.
    assign unauthorized_hid_pulse =
        speed_valid &&
        (policy_mode == `CTRL_POLICY_STORAGE_ONLY) &&
        hid_keyboard_seen && config_walk_done &&
        !suspicious_sticky && !kill;

    wire crc_threat = speed_valid & crc_fault;

    assign threat_pulse =
        crc_threat | suspicious_pulse | suspicious_hold |
        unauthorized_hid_pulse |
        keystroke_burst_pulse | cooldown_burst_pulse;

    always_comb begin
        if (crc_threat)
            threat_code_in = `THREAT_CRC_TOKEN_FAULT;
        else if (suspicious_pulse || suspicious_hold)
            threat_code_in = `THREAT_DESCRIPTOR_OVERFLOW;
        else if (unauthorized_hid_pulse)
            threat_code_in = `THREAT_UNAUTHORIZED_HID;
        else if (keystroke_burst_pulse)
            threat_code_in = `THREAT_KEYSTROKE_BURST;
        else if (cooldown_burst_pulse)
            threat_code_in = `THREAT_COOLDOWN_BURST;
        else
            threat_code_in = `THREAT_NO_FAULT;
    end

    assign threat_detail = detail_sticky;

    isolation_controller u_iso (
        .clk           (clk_48m),
        .rst           (rst),
        .threat_pulse  (threat_pulse),
        .threat_code_in(threat_code_in),
        .manual_kill   (manual_kill),
        .clear_fault   (clear_fault),
        .kill          (iso_kill),
        .threat_code   (iso_threat)
    );

    // Pending HID also asserts kill; threat_code stays isolation sticky code.
    assign kill        = iso_kill | hid_pending | hid_confirm_hold;
    assign threat_code = iso_threat;

    always_comb begin
        port_status = 8'h00;
        port_status[`PORT_STATUS_ATTACHED_BIT]       = attached;
        port_status[`PORT_STATUS_HID_PENDING_BIT]    =
            hid_pending | hid_confirm_hold;
        port_status[`PORT_STATUS_ISOLATED_BIT]       = kill;
        port_status[`PORT_STATUS_THREAT_PRESENT_BIT] =
            (iso_threat != `THREAT_NO_FAULT) | hid_pending | hid_confirm_hold;
    end

`ifndef VERILATOR
    // synthesis translate_off
    sniffer_block_sva u_sniff_sva (
        .clk                    (clk_48m),
        .rst                    (rst),
        .speed_valid            (speed_valid),
        .crc_fault              (crc_fault),
        .policy_mode            (policy_mode),
        .unauthorized_hid_pulse (unauthorized_hid_pulse),
        .suspicious_pulse       (suspicious_pulse),
        .suspicious_hold        (suspicious_hold),
        .keystroke_burst_pulse  (keystroke_burst_pulse),
        .cooldown_burst_pulse   (cooldown_burst_pulse),
        .hid_pending            (hid_pending),
        .hid_confirm_hold       (hid_confirm_hold),
        .threat_pulse           (threat_pulse),
        .threat_code_in         (threat_code_in),
        .attached               (attached),
        .kill                   (kill),
        .threat_code            (threat_code),
        .port_status            (port_status)
    );
    // synthesis translate_on
`endif

endmodule
