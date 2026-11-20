#include "fpga_bridge.h"

#include <SPI.h>

void fpga_bridge_begin() {
  pinMode(FPGA_SPI_CS_PIN, OUTPUT);
  digitalWrite(FPGA_SPI_CS_PIN, HIGH);

  SPI.setSCLK(FPGA_SPI_SCK_PIN);
  SPI.setMISO(FPGA_SPI_MISO_PIN);
  SPI.setMOSI(FPGA_SPI_MOSI_PIN);
  SPI.begin();
}

uint8_t fpga_spi_read8(uint8_t addr) {
  const uint16_t frame = (uint16_t)(((uint16_t)(addr & 0x7Fu)) << 8);  // bit15=0 read
  SPI.beginTransaction(SPISettings(FPGA_SPI_HZ, MSBFIRST, SPI_MODE0));
  digitalWrite(FPGA_SPI_CS_PIN, LOW);
  // Small setup before first SCK — helps slow wire / sync on FPGA.
  delayMicroseconds(2);
  const uint16_t rx = SPI.transfer16(frame);
  digitalWrite(FPGA_SPI_CS_PIN, HIGH);
  SPI.endTransaction();
  delayMicroseconds(2);
  return (uint8_t)(rx & 0xFFu);
}

void fpga_spi_write8(uint8_t addr, uint8_t data) {
  const uint16_t frame =
      (uint16_t)(0x8000u | (((uint16_t)(addr & 0x7Fu)) << 8) | (uint16_t)data);
  SPI.beginTransaction(SPISettings(FPGA_SPI_HZ, MSBFIRST, SPI_MODE0));
  digitalWrite(FPGA_SPI_CS_PIN, LOW);
  delayMicroseconds(2);
  (void)SPI.transfer16(frame);
  digitalWrite(FPGA_SPI_CS_PIN, HIGH);
  SPI.endTransaction();
  delayMicroseconds(2);
}

uint8_t fpga_read_sys_status() {
  return fpga_spi_read8(FPGA_ADDR_SYS_STATUS);
}

void fpga_read_port(uint8_t port, FpgaPortBlock *out) {
  if (out == nullptr || port >= 4) {
    return;
  }
  const uint8_t base = FPGA_PORT_REG_BASE(port);
  out->control = fpga_spi_read8((uint8_t)(base + 0x0));
  out->status = fpga_spi_read8((uint8_t)(base + 0x1));
  out->vid_h = fpga_spi_read8((uint8_t)(base + 0x2));
  out->vid_l = fpga_spi_read8((uint8_t)(base + 0x3));
  out->pid_h = fpga_spi_read8((uint8_t)(base + 0x4));
  out->pid_l = fpga_spi_read8((uint8_t)(base + 0x5));
  out->dev_class = fpga_spi_read8((uint8_t)(base + 0x6));
  out->int_class = fpga_spi_read8((uint8_t)(base + 0x7));
}

void fpga_read_port0(FpgaPortBlock *out) {
  fpga_read_port(0, out);
}

static uint8_t fpga_policy_bits(uint8_t port) {
  if (port >= 4) {
    return FPGA_POLICY_STORAGE_ONLY;
  }
  const uint8_t addr = FPGA_PORT_REG_BASE(port);
  return (uint8_t)(fpga_spi_read8(addr) & FPGA_CTRL_POLICY_MASK);
}

void fpga_clear_fault(uint8_t port) {
  if (port >= 4) {
    return;
  }
  const uint8_t addr = FPGA_PORT_REG_BASE(port);
  const uint8_t policy = fpga_policy_bits(port);
  // Pulse bit6; preserve policy; leave manual_kill cleared.
  fpga_spi_write8(addr, (uint8_t)(FPGA_CTRL_CLEAR_FAULT | policy));
  fpga_spi_write8(addr, policy);
}

void fpga_approve_hid(uint8_t port) {
  if (port >= 4) {
    return;
  }
  const uint8_t addr = FPGA_PORT_REG_BASE(port);
  const uint8_t policy = fpga_policy_bits(port);
  fpga_spi_write8(addr, (uint8_t)(FPGA_CTRL_APPROVE_HID | policy));
  fpga_spi_write8(addr, policy);
}

void fpga_set_policy(uint8_t port, uint8_t policy) {
  if (port >= 4) {
    return;
  }
  const uint8_t addr = FPGA_PORT_REG_BASE(port);
  const uint8_t cur = fpga_spi_read8(addr);
  const uint8_t next =
      (uint8_t)((cur & (uint8_t)~FPGA_CTRL_POLICY_MASK) | (policy & FPGA_CTRL_POLICY_MASK));
  fpga_spi_write8(addr, next);
}

void fpga_set_manual_kill(uint8_t port, bool enable) {
  if (port >= 4) {
    return;
  }
  const uint8_t addr = FPGA_PORT_REG_BASE(port);
  const uint8_t policy = fpga_policy_bits(port);
  fpga_spi_write8(addr, enable ? (uint8_t)(FPGA_CTRL_MANUAL_KILL | policy) : policy);
}
