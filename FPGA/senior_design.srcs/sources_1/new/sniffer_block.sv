`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name:   sniffer_block
// Description:
//   Per-port USB packet sniffer (48 MHz domain). Soft RX, enumeration analysis,
//   HID timing filter, and isolation latch with policy mux:
//     bit-stuff → 0x6; CRC → 0x5; suspicious enum → 0x4; storage-only HID → 0x1;
//     keystroke burst → 0x2; HID hold / cooldown → 0x3.
//
//   Policy: POLICY_STORAGE_ONLY parameter OR SPI policy_mode==STORAGE_ONLY.
//   Board default param=0 (HID allowed). Demo TBs set param=1 for 0x1 path.
//////////////////////////////////////////////////////////////////////////////////

`include "defines.svh"

module sniffer_block #(
    parameter bit POLICY_STORAGE_ONLY = 1'b0,
    // Sim overrides (board / wrapper leave defaults = fabric_slop timing).
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
    input  logic       approve,
    input  logic [2:0] policy_mode,

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
    logic        bit_stuff_fault;
    logic        attached;
    logic        bus_reset;

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

    logic        approved;
    logic        storage_only;
    logic        hid_allowed;
    logic        pending_hid;

    logic        suspicious_pulse;
    logic [3:0]  suspicious_detail;
    logic        suspicious_sticky;
    logic        suspicious_hold;
    logic        unauthorized_hid_pulse;
    logic        hid_hold_pulse;
    logic        threat_pulse;
    logic [3:0]  threat_code_in;
    logic [3:0]  detail_sticky;
    logic        bus_reset_d;
    logic        bus_reset_rise;

    // SPI STORAGE_ONLY wins; else bitstream/TB parameter.
    // Explicit SPI HID_ALLOWED (0) on a storage-param build still allows HID
    // only when parameter is 0 — TBs that need 0x1 set POLICY_STORAGE_ONLY=1.
    assign storage_only = (policy_mode == `POLICY_STORAGE_ONLY) || POLICY_STORAGE_ONLY;
    assign hid_allowed  = !storage_only;

    usb_reset_det u_reset (
        .clk     (clk_48m),
        .reset   (bus_reset),
        .usb_p_rx(dp),
        .usb_n_rx(dm)
    );

    usb_packet_frontend u_fe (
        .clk_48m         (clk_48m),
        .rst             (rst),
        .dp              (dp),
        .dm              (dm),
        .pkt_start       (pkt_start),
        .pkt_end         (pkt_end),
        .pid             (pid),
        .addr            (addr),
        .endp            (endp),
        .frame_num       (frame_num),
        .data_valid      (data_valid),
        .data            (data),
        .crc_ok          (crc_ok),
        .crc_fault       (crc_fault),
        .bit_stuff_fault (bit_stuff_fault)
    );

    enumeration_analysis #(
        .REENUM_WINDOW_CYCLES_P(REENUM_WINDOW_CYCLES_P),
        .REENUM_STORM_THRESH_P (REENUM_STORM_THRESH_P)
    ) u_enum (
        .clk                    (clk_48m),
        .rst                    (rst),
        .pkt_start              (pkt_start),
        .pkt_end                (pkt_end),
        .pid                    (pid),
        .addr                   (addr),
        .endp                   (endp),
        .data_valid             (data_valid),
        .data                   (data),
        .crc_ok                 (crc_ok),
        .bus_reset              (bus_reset),
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
        .attached               (attached),
        .desc_overflow_pulse    (desc_overflow_pulse),
        .composite_hid_msc_pulse(composite_hid_msc_pulse),
        .multi_hid_pulse        (multi_hid_pulse),
        .hid_keyboard_pulse     (hid_keyboard_pulse),
        .reenum_storm_pulse     (reenum_storm_pulse)
    );

    always_ff @(posedge clk_48m) begin
        if (rst)
            approved <= 1'b0;
        else if (!attached)
            approved <= 1'b0;
        else if (approve)
            approved <= 1'b1;
    end

    hid_timing_filter #(
        .MIN_INTERVAL_CYCLES(HID_MIN_INTERVAL_CYCLES_P),
        .QUARANTINE_CYCLES  (HID_QUARANTINE_CYCLES_P)
    ) u_hid (
        .clk                   (clk_48m),
        .rst                   (rst),
        .enable                (approved && hid_allowed),
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

    assign bus_reset_rise = bus_reset && !bus_reset_d;

    // Sticky suspicious family: clear_fault releases kill but re-arms (like HID
    // hold) until bus reset / soft rst drops the latch.
    always_ff @(posedge clk_48m) begin
        if (rst) begin
            suspicious_sticky <= 1'b0;
            detail_sticky     <= `DETAIL_NONE;
            bus_reset_d       <= 1'b0;
        end else begin
            bus_reset_d <= bus_reset;
            // Bus reset drops prior sticky threats, except a storm pulse that
            // arrives on the same rising edge (reenum_storm_pulse).
            if (suspicious_pulse) begin
                suspicious_sticky <= 1'b1;
                detail_sticky     <= suspicious_detail;
            end else if (bus_reset_rise) begin
                suspicious_sticky <= 1'b0;
                detail_sticky     <= `DETAIL_NONE;
            end
        end
    end

    assign suspicious_hold = suspicious_sticky && !kill;

    // Storage-only: any HID after config walk (not just first-intf rising edge).
    // MSC-then-HID configs must still trip 0x1; composite/multi stay on 0x4 via
    // suspicious_* priority above this arm.
    assign unauthorized_hid_pulse =
        storage_only && hid_keyboard_seen && config_walk_done &&
        !suspicious_sticky && !kill;

    // Wait until config walk finishes so composite/multi-HID (0x4) can win
    // over HID-hold (0x3) on the same cycle.
    assign pending_hid    = hid_allowed && hid_keyboard_seen && !approved &&
                            config_walk_done && !suspicious_sticky;
    assign hid_hold_pulse = pending_hid && !kill;

    assign threat_pulse =
        bit_stuff_fault | crc_fault | suspicious_pulse | suspicious_hold |
        unauthorized_hid_pulse |
        keystroke_burst_pulse | cooldown_burst_pulse | hid_hold_pulse;

    always_comb begin
        if (bit_stuff_fault)
            threat_code_in = `THREAT_BIT_STUFF_ERROR;
        else if (crc_fault)
            threat_code_in = `THREAT_CRC_TOKEN_FAULT;
        else if (suspicious_pulse || suspicious_hold)
            threat_code_in = `THREAT_DESCRIPTOR_OVERFLOW;
        else if (unauthorized_hid_pulse)
            threat_code_in = `THREAT_UNAUTHORIZED_HID;
        else if (keystroke_burst_pulse)
            threat_code_in = `THREAT_KEYSTROKE_BURST;
        else if (cooldown_burst_pulse || hid_hold_pulse)
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
        .kill          (kill),
        .threat_code   (threat_code)
    );

    always_comb begin
        port_status = 8'h00;
        port_status[`PORT_STATUS_ATTACHED_BIT]       = attached;
        port_status[`PORT_STATUS_PENDING_BIT]        = pending_hid;
        port_status[`PORT_STATUS_ISOLATED_BIT]       = kill;
        port_status[`PORT_STATUS_THREAT_PRESENT_BIT] = (threat_code != `THREAT_NO_FAULT);
    end

`ifndef VERILATOR
    // synthesis translate_off
    sniffer_block_sva #(
        .POLICY_STORAGE_ONLY(POLICY_STORAGE_ONLY)
    ) u_sniff_sva (
        .clk                   (clk_48m),
        .rst                   (rst),
        .crc_fault             (crc_fault),
        .bit_stuff_fault       (bit_stuff_fault),
        .storage_only          (storage_only),
        .unauthorized_hid_pulse(unauthorized_hid_pulse),
        .hid_keyboard_seen     (hid_keyboard_seen),
        .config_walk_done      (config_walk_done),
        .suspicious_sticky     (suspicious_sticky),
        .suspicious_pulse      (suspicious_pulse),
        .suspicious_hold       (suspicious_hold),
        .keystroke_burst_pulse (keystroke_burst_pulse),
        .cooldown_burst_pulse  (cooldown_burst_pulse),
        .hid_hold_pulse        (hid_hold_pulse),
        .threat_pulse          (threat_pulse),
        .threat_code_in        (threat_code_in),
        .attached              (attached),
        .pending_hid           (pending_hid),
        .kill                  (kill),
        .threat_code           (threat_code),
        .port_status           (port_status)
    );
    // synthesis translate_on
`endif

endmodule
