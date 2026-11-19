// MCU management-plane firmware (Black Pill F411).
//
// Modes (platformio.ini build_flags):
//   Default / -UFPGA_SPI_BRINGUP : MOCK UART JSON + timed port-1 demo (no SPI).
//   -DFPGA_SPI_BRINGUP=1         : LIVE SPI reads/writes to Cmod FPGA; human-readable
//                                  UART lines + JSON for all 4 ports from SPI (prototype).
//                                  Power sensors remain MOCK (no INA219).
//
// Power + DFU: USB-C. Host UART: USART1 PA9/PA10 → CP2102.
// See Firmware/README.md.

#include <Arduino.h>
#include <stdio.h>
#include <string.h>

#include "protocol.h"

#if defined(FPGA_SPI_BRINGUP) && FPGA_SPI_BRINGUP
#include "fpga_bridge.h"
#endif

struct PortState {
  uint8_t port;
  const char *state;
  uint8_t threat_code;
  char vid[8];
  char pid[8];
  char dev_class[8];
  char int_class[8];
  bool manually_blocked;
};

static PortState ports[PORT_COUNT];
static char line_buf[256];
static size_t line_len = 0;
static uint32_t last_telemetry_ms = 0;
static uint32_t led_until_ms = 0;

#if !defined(FPGA_SPI_BRINGUP) || !FPGA_SPI_BRINGUP
static uint8_t demo_stage = 0;
static uint8_t jitter_phase = 0;
#endif

#if defined(FPGA_SPI_BRINGUP) && FPGA_SPI_BRINGUP
static uint32_t last_spi_poll_ms = 0;
#endif

static void led_on() {
  digitalWrite(STATUS_LED_PIN, LOW);  // active low
}

static void led_off() {
  digitalWrite(STATUS_LED_PIN, HIGH);
}

static void led_pulse(uint32_t ms) {
  led_on();
  led_until_ms = millis() + ms;
}

static void service_led() {
  if (led_until_ms != 0 && (int32_t)(millis() - led_until_ms) >= 0) {
    led_off();
    led_until_ms = 0;
  }
}

static void set_hex4(char *out, size_t out_len, uint16_t value) {
  snprintf(out, out_len, "0x%04X", (unsigned)value);
}

static void set_hex2(char *out, size_t out_len, uint8_t value) {
  snprintf(out, out_len, "0x%02X", (unsigned)value);
}

static void init_ports() {
  for (uint8_t i = 0; i < PORT_COUNT; i++) {
    ports[i].port = i;
    ports[i].state = STATE_DISCONNECTED;
    ports[i].threat_code = THREAT_NO_FAULT;
    set_hex4(ports[i].vid, sizeof(ports[i].vid), 0);
    set_hex4(ports[i].pid, sizeof(ports[i].pid), 0);
    set_hex2(ports[i].dev_class, sizeof(ports[i].dev_class), 0);
    set_hex2(ports[i].int_class, sizeof(ports[i].int_class), 0);
    ports[i].manually_blocked = false;
  }

#if !defined(FPGA_SPI_BRINGUP) || !FPGA_SPI_BRINGUP
  // MOCK: port 0 looks like an authorized flash drive.
  ports[0].state = STATE_AUTHORIZED;
  set_hex4(ports[0].vid, sizeof(ports[0].vid), 0x0781);
  set_hex4(ports[0].pid, sizeof(ports[0].pid), 0x5583);
  set_hex2(ports[0].dev_class, sizeof(ports[0].dev_class), 0x00);
  set_hex2(ports[0].int_class, sizeof(ports[0].int_class), 0x08);
#endif
}

static void isolate_port_local(PortState &p) {
  p.manually_blocked = true;
  p.state = STATE_MANUAL_BLOCKED;
  p.threat_code = THREAT_MANUAL_HOST_KILL;
}

static void restore_port_local(PortState &p) {
  p.manually_blocked = false;
  p.threat_code = THREAT_NO_FAULT;
  p.state = STATE_AUTHORIZED;
  set_hex4(p.vid, sizeof(p.vid), 0x046D);
  set_hex4(p.pid, sizeof(p.pid), 0xC31C);
  set_hex2(p.dev_class, sizeof(p.dev_class), 0x00);
  set_hex2(p.int_class, sizeof(p.int_class), 0x03);
}

static void clear_fault_local(PortState &p) {
  if (p.threat_code == THREAT_NO_FAULT) {
    return;
  }
  p.threat_code = THREAT_NO_FAULT;
  if (p.manually_blocked) {
    p.state = STATE_MANUAL_BLOCKED;
  } else if (p.state == STATE_PENDING_HID_CONFIRM) {
    // clear_fault is not HID confirm — leave pending hold.
    return;
  } else {
    p.state = STATE_AUTHORIZED;
  }
}

static void confirm_hid_local(PortState &p) {
  if (p.state != STATE_PENDING_HID_CONFIRM) {
    return;
  }
  p.manually_blocked = false;
  p.threat_code = THREAT_NO_FAULT;
  p.state = STATE_AUTHORIZED;
}

#if !defined(FPGA_SPI_BRINGUP) || !FPGA_SPI_BRINGUP
// MOCK GUI cadence: port 1 plugs as HID → PENDING_HID_CONFIRM (operator confirm_hid).
static void advance_demo() {
  PortState &p1 = ports[1];
  if (p1.manually_blocked || p1.state == STATE_QUARANTINED ||
      p1.state == STATE_PENDING_HID_CONFIRM || p1.state == STATE_AUTHORIZED) {
    return;
  }

  const uint32_t elapsed = millis();
  if (demo_stage == 0 && elapsed >= DEMO_AUTHORIZE_MS) {
    p1.state = STATE_PENDING_HID_CONFIRM;
    p1.threat_code = THREAT_NO_FAULT;
    set_hex4(p1.vid, sizeof(p1.vid), 0x046D);
    set_hex4(p1.pid, sizeof(p1.pid), 0xC31C);
    set_hex2(p1.dev_class, sizeof(p1.dev_class), 0x00);
    set_hex2(p1.int_class, sizeof(p1.int_class), 0x03);
    demo_stage = 1;
    led_pulse(80);
  }
}

static void jitter_readings() {
}
#endif

#if defined(FPGA_SPI_BRINGUP) && FPGA_SPI_BRINGUP
// LIVE FPGA → per-port UART/JSON fields (prototype; all four sniffers).
static void apply_fpga_port_to_state(uint8_t port, const FpgaPortBlock &b) {
  if (port >= PORT_COUNT) {
    return;
  }
  PortState &p = ports[port];
  const uint8_t threat = (uint8_t)FPGA_STATUS_THREAT(b.status);
  const bool killed = FPGA_STATUS_KILL(b.status) != 0;
  const bool attached = FPGA_STATUS_ATTACHED(b.status) != 0;
  const bool hid_pending = FPGA_STATUS_HID_PENDING(b.status) != 0;

  p.threat_code = threat;
  p.manually_blocked = (threat == THREAT_MANUAL_HOST_KILL);
  set_hex4(p.vid, sizeof(p.vid), fpga_port_vid(b));
  set_hex4(p.pid, sizeof(p.pid), fpga_port_pid(b));
  set_hex2(p.dev_class, sizeof(p.dev_class), b.dev_class);
  set_hex2(p.int_class, sizeof(p.int_class), b.int_class);

  // Disconnect (no FS/LS J) wins over sticky kill so the GUI can go idle.
  if (!attached) {
    p.state = STATE_DISCONNECTED;
  } else if (hid_pending) {
    p.state = STATE_PENDING_HID_CONFIRM;
  } else if (killed) {
    p.state = p.manually_blocked ? STATE_MANUAL_BLOCKED : STATE_QUARANTINED;
  } else {
    p.state = STATE_AUTHORIZED;
  }
}

static void print_hex2(uint8_t v) {
  if (v < 0x10) {
    Serial1.print('0');
  }
  Serial1.print(v, HEX);
}

static void print_spi_bringup_line(uint8_t sys, const FpgaPortBlock blocks[PORT_COUNT]) {
  Serial1.print("SPI LIVE sys=0x");
  print_hex2(sys);
  for (uint8_t i = 0; i < PORT_COUNT; i++) {
    const FpgaPortBlock &b = blocks[i];
    Serial1.print(" P");
    Serial1.print(i);
    Serial1.print("=0x");
    print_hex2(b.status);
    Serial1.print("(a=");
    Serial1.print(FPGA_STATUS_ATTACHED(b.status));
    Serial1.print(" k=");
    Serial1.print(FPGA_STATUS_KILL(b.status));
    Serial1.print(" h=");
    Serial1.print(FPGA_STATUS_HID_PENDING(b.status));
    Serial1.print(" t=");
    Serial1.print(FPGA_STATUS_THREAT(b.status), HEX);
    if (FPGA_STATUS_ATTACHED(b.status)) {
      Serial1.print(" vid=0x");
      Serial1.print(fpga_port_vid(b), HEX);
      Serial1.print(" pid=0x");
      Serial1.print(fpga_port_pid(b), HEX);
      Serial1.print(" if=0x");
      print_hex2(b.int_class);
    }
    Serial1.print(')');
  }
  Serial1.println();
}

static void spi_bringup_poll() {
  const uint8_t sys = fpga_read_sys_status();
  FpgaPortBlock blocks[PORT_COUNT];
  for (uint8_t i = 0; i < PORT_COUNT; i++) {
    fpga_read_port(i, &blocks[i]);
    apply_fpga_port_to_state(i, blocks[i]);
  }
  print_spi_bringup_line(sys, blocks);
}
#endif

static bool json_get_string(const char *json, const char *key, char *out, size_t out_len) {
  char pattern[48];
  snprintf(pattern, sizeof(pattern), "\"%s\"", key);
  const char *p = strstr(json, pattern);
  if (!p) {
    return false;
  }
  p = strchr(p + strlen(pattern), ':');
  if (!p) {
    return false;
  }
  p++;
  while (*p == ' ' || *p == '\t') {
    p++;
  }
  if (*p != '"') {
    return false;
  }
  p++;
  size_t i = 0;
  while (*p && *p != '"' && i + 1 < out_len) {
    out[i++] = *p++;
  }
  out[i] = '\0';
  return i > 0;
}

static bool json_get_int(const char *json, const char *key, int *out) {
  char pattern[48];
  snprintf(pattern, sizeof(pattern), "\"%s\"", key);
  const char *p = strstr(json, pattern);
  if (!p) {
    return false;
  }
  p = strchr(p + strlen(pattern), ':');
  if (!p) {
    return false;
  }
  p++;
  while (*p == ' ' || *p == '\t') {
    p++;
  }
  char *end = nullptr;
  long v = strtol(p, &end, 10);
  if (end == p) {
    return false;
  }
  *out = (int)v;
  return true;
}

static void apply_command_line(const char *line) {
  char type_buf[16] = {0};
  char cmd_buf[32] = {0};
  int port_id = -1;

  if (json_get_string(line, "type", type_buf, sizeof(type_buf))) {
    if (strcmp(type_buf, "command") != 0) {
      return;
    }
  }
  if (!json_get_string(line, "cmd", cmd_buf, sizeof(cmd_buf))) {
    return;
  }
  if (!json_get_int(line, "port", &port_id) || port_id < 0 || port_id >= PORT_COUNT) {
    return;
  }

  PortState &p = ports[port_id];
  if (strcmp(cmd_buf, CMD_ISOLATE_PORT) == 0) {
#if defined(FPGA_SPI_BRINGUP) && FPGA_SPI_BRINGUP
    fpga_set_manual_kill((uint8_t)port_id, true);
#else
    isolate_port_local(p);
#endif
    led_pulse(120);
  } else if (strcmp(cmd_buf, CMD_RESTORE_PORT) == 0) {
#if defined(FPGA_SPI_BRINGUP) && FPGA_SPI_BRINGUP
    fpga_set_manual_kill((uint8_t)port_id, false);
    fpga_clear_fault((uint8_t)port_id);
#else
    restore_port_local(p);
#endif
    led_pulse(120);
  } else if (strcmp(cmd_buf, CMD_CLEAR_FAULT) == 0) {
#if defined(FPGA_SPI_BRINGUP) && FPGA_SPI_BRINGUP
    fpga_clear_fault((uint8_t)port_id);
#else
    clear_fault_local(p);
#endif
    led_pulse(120);
  } else if (strcmp(cmd_buf, CMD_CONFIRM_HID) == 0) {
#if defined(FPGA_SPI_BRINGUP) && FPGA_SPI_BRINGUP
    fpga_approve_hid((uint8_t)port_id);
#else
    confirm_hid_local(p);
#endif
    led_pulse(120);
  }
}

static void poll_host_commands() {
  while (Serial1.available() > 0) {
    char c = (char)Serial1.read();
    if (c == '\r') {
      continue;
    }
    if (c == '\n') {
      if (line_len > 0) {
        line_buf[line_len] = '\0';
        apply_command_line(line_buf);
        line_len = 0;
      }
      continue;
    }
    if (line_len + 1 < sizeof(line_buf)) {
      line_buf[line_len++] = c;
    } else {
      line_len = 0;
    }
  }
}

static void emit_telemetry_json() {
  Serial1.print("{\"timestamp_ms\":");
  Serial1.print(millis());
  Serial1.print(",\"ports\":[");
  for (uint8_t i = 0; i < PORT_COUNT; i++) {
    const PortState &p = ports[i];
    if (i > 0) {
      Serial1.print(',');
    }
    Serial1.print("{\"port\":");
    Serial1.print(p.port);
    Serial1.print(",\"state\":\"");
    Serial1.print(p.state);
    Serial1.print("\",\"threat_code\":");
    Serial1.print(p.threat_code);
    Serial1.print(",\"vid\":\"");
    Serial1.print(p.vid);
    Serial1.print("\",\"pid\":\"");
    Serial1.print(p.pid);
    Serial1.print("\",\"dev_class\":\"");
    Serial1.print(p.dev_class);
    Serial1.print("\",\"int_class\":\"");
    Serial1.print(p.int_class);
    Serial1.print("\"}");
  }
  Serial1.println("]}");
}

void setup() {
  pinMode(STATUS_LED_PIN, OUTPUT);
  led_off();

  init_ports();
  Serial1.setRx(HOST_UART_RX_PIN);
  Serial1.setTx(HOST_UART_TX_PIN);
  Serial1.begin(HOST_UART_BAUD);

#if defined(FPGA_SPI_BRINGUP) && FPGA_SPI_BRINGUP
  fpga_bridge_begin();
  // Soft-tap prototype: HID-after-confirm on every sniffer channel.
  for (uint8_t i = 0; i < PORT_COUNT; i++) {
    fpga_set_policy(i, FPGA_POLICY_HID_CONFIRM);
  }
  Serial1.println("MCU: FPGA_SPI_BRINGUP — ports 0-3 LIVE SPI; policy=HID_CONFIRM");
#else
  Serial1.println("MCU: UART MOCK stub (no SPI) — see Firmware/README.md");
#endif

  last_telemetry_ms = millis();
  led_pulse(250);
}

void loop() {
  poll_host_commands();
  service_led();

#if defined(FPGA_SPI_BRINGUP) && FPGA_SPI_BRINGUP
  const uint32_t now = millis();
  if ((now - last_spi_poll_ms) >= FPGA_SPI_POLL_MS) {
    last_spi_poll_ms = now;
    spi_bringup_poll();
    // JSON for all four ports from SPI (power sensors still absent / mock).
    emit_telemetry_json();
  }
#else
  advance_demo();
  const uint32_t now = millis();
  if ((now - last_telemetry_ms) >= TELEMETRY_PERIOD_MS) {
    last_telemetry_ms = now;
    jitter_readings();
    emit_telemetry_json();
  }
#endif
}
