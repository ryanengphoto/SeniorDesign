#pragma once

// Host ↔ MCU UART contract (align with Docs/firmwmare_slop.md + GUI/app/lib/protocol.dart).
// Telemetry and commands are newline-delimited JSON @ HOST_UART_BAUD.

#include <Arduino.h>

// Provisional WeAct Black Pill F411 pins — override when carrier pinout locks.
#ifndef HOST_UART_TX_PIN
#define HOST_UART_TX_PIN PA9
#endif
#ifndef HOST_UART_RX_PIN
#define HOST_UART_RX_PIN PA10
#endif

#ifndef HOST_UART_BAUD
#define HOST_UART_BAUD 115200
#endif

#ifndef TELEMETRY_PERIOD_MS
#define TELEMETRY_PERIOD_MS 100
#endif

#ifndef PORT_COUNT
#define PORT_COUNT 4
#endif

// Threat codes per Docs/fabric_slop.md §6
#define THREAT_NO_FAULT 0
#define THREAT_UNAUTHORIZED_HID 1
#define THREAT_KEYSTROKE_BURST 2
#define THREAT_MANUAL_HOST_KILL 7

// WeAct Black Pill user LED (active low).
#ifndef STATUS_LED_PIN
#define STATUS_LED_PIN PC13
#endif

// GUI-visible stub demo (matches GUI mock / mcu_sim cadence).
#ifndef DEMO_AUTHORIZE_MS
#define DEMO_AUTHORIZE_MS 5000
#endif
#ifndef DEMO_QUARANTINE_MS
#define DEMO_QUARANTINE_MS 15000
#endif

#define STATE_DISCONNECTED "DISCONNECTED"
#define STATE_AUTHORIZED "AUTHORIZED"
#define STATE_QUARANTINED "QUARANTINED"
#define STATE_MANUAL_BLOCKED "MANUAL_BLOCKED"
#define STATE_PENDING_HID_CONFIRM "PENDING_HID_CONFIRM"

#define CMD_ISOLATE_PORT "isolate_port"
#define CMD_RESTORE_PORT "restore_port"
#define CMD_CLEAR_FAULT "clear_fault"
#define CMD_CONFIRM_HID "confirm_hid"
