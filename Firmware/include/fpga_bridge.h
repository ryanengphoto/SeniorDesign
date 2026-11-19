#pragma once

// SPI master bridge to Cmod FPGA slave (Mode 0, 16-bit frames).
// Framing: Write {1, addr[6:0], data[7:0]} ; Read {0, addr[6:0], dummy} → data on clocks 8..15.

#include <Arduino.h>
#include <stdint.h>

#include "fpga_spi.h"

struct FpgaPortBlock {
  uint8_t control;
  uint8_t status;
  uint8_t vid_h;
  uint8_t vid_l;
  uint8_t pid_h;
  uint8_t pid_l;
  uint8_t dev_class;
  uint8_t int_class;
};

void fpga_bridge_begin();

uint8_t fpga_spi_read8(uint8_t addr);
void fpga_spi_write8(uint8_t addr, uint8_t data);

uint8_t fpga_read_sys_status();
void fpga_read_port(uint8_t port, FpgaPortBlock *out);
void fpga_read_port0(FpgaPortBlock *out);

// Pulse Pn_CONTROL[6] clear_fault (preserves policy[2:0]).
void fpga_clear_fault(uint8_t port);

// Pulse Pn_CONTROL[5] approve_hid (HID-after-confirm release; preserves policy).
void fpga_approve_hid(uint8_t port);

// Set Pn_CONTROL[2:0] policy mode (storage-only / hid-confirm / hid-allow).
void fpga_set_policy(uint8_t port, uint8_t policy);

// Level Pn_CONTROL[7] manual_kill (preserves policy[2:0]).
void fpga_set_manual_kill(uint8_t port, bool enable);

static inline uint16_t fpga_port_vid(const FpgaPortBlock &b) {
  return (uint16_t)(((uint16_t)b.vid_h << 8) | b.vid_l);
}

static inline uint16_t fpga_port_pid(const FpgaPortBlock &b) {
  return (uint16_t)(((uint16_t)b.pid_h << 8) | b.pid_l);
}
