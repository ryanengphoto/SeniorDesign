#pragma once

// FPGA SPI master pinout + register map (Docs/fabric_slop.md §5, live RTL in register_file.sv).
// Cmod stand-alone Pmod JA pins: FPGA/bringup.md / cmod_s7_bringup.xdc.

#include <Arduino.h>

// --- Black Pill SPI1 (provisional; does not clash with USART1 PA9/PA10) ---
#ifndef FPGA_SPI_SCK_PIN
#define FPGA_SPI_SCK_PIN PA5
#endif
#ifndef FPGA_SPI_MISO_PIN
#define FPGA_SPI_MISO_PIN PA6
#endif
#ifndef FPGA_SPI_MOSI_PIN
#define FPGA_SPI_MOSI_PIN PA7
#endif
#ifndef FPGA_SPI_CS_PIN
#define FPGA_SPI_CS_PIN PA4
#endif

// Bring-up clock: keep well under the 25 MHz map limit; FPGA SPI domain is 48 MHz.
#ifndef FPGA_SPI_HZ
#define FPGA_SPI_HZ 1000000
#endif

#ifndef FPGA_SPI_POLL_MS
#define FPGA_SPI_POLL_MS 200
#endif

// --- Register addresses ---
#define FPGA_ADDR_SYS_STATUS 0x00
#define FPGA_ADDR_SYS_CONTROL 0x01

#define FPGA_ADDR_P0_CONTROL 0x10
#define FPGA_ADDR_P0_STATUS 0x11
#define FPGA_ADDR_P0_VID_HIGH 0x12
#define FPGA_ADDR_P0_VID_LOW 0x13
#define FPGA_ADDR_P0_PID_HIGH 0x14
#define FPGA_ADDR_P0_PID_LOW 0x15
#define FPGA_ADDR_P0_DEV_CLASS 0x16
#define FPGA_ADDR_P0_INT_CLASS 0x17

// Ports 1–3 mirror at 0x20 / 0x30 / 0x40 (+ offsets match 0x10–0x17).
#define FPGA_PORT_REG_BASE(port) (uint8_t)(0x10u + (uint8_t)(port) * 0x10u)

// Pn_CONTROL bits (fabric_slop + register_file)
#define FPGA_CTRL_MANUAL_KILL (1u << 7)
#define FPGA_CTRL_CLEAR_FAULT (1u << 6)
#define FPGA_CTRL_APPROVE_HID (1u << 5)
#define FPGA_CTRL_POLICY_MASK 0x07u
#define FPGA_POLICY_STORAGE_ONLY 0x0u
#define FPGA_POLICY_HID_CONFIRM 0x1u
#define FPGA_POLICY_HID_ALLOW 0x2u

// Live RTL pack_spi_status (register_file.sv):
//   [7] kill/isolated
//   [6] attached
//   [5] 0 (configured unused)
//   [4] HID pending confirm
//   [3:0] threat code
#define FPGA_STATUS_KILL_BIT 7
#define FPGA_STATUS_ATTACHED_BIT 6
#define FPGA_STATUS_HID_PENDING_BIT 4
#define FPGA_STATUS_THREAT_MASK 0x0Fu

#define FPGA_STATUS_KILL(s) (((s) >> FPGA_STATUS_KILL_BIT) & 0x1u)
#define FPGA_STATUS_ATTACHED(s) (((s) >> FPGA_STATUS_ATTACHED_BIT) & 0x1u)
#define FPGA_STATUS_HID_PENDING(s) (((s) >> FPGA_STATUS_HID_PENDING_BIT) & 0x1u)
#define FPGA_STATUS_THREAT(s) ((s)&FPGA_STATUS_THREAT_MASK)

// Selfstim demo expectations (FPGA/bringup.md)
#define FPGA_SELFSTIM_VID 0x1234u
#define FPGA_SELFSTIM_PID 0x5678u
#define FPGA_SELFSTIM_INT_CLASS 0x03u
#define FPGA_SELFSTIM_THREAT 0x1u
