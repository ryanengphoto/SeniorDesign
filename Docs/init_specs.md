# USB 4-1 Initial Design Specification

The initial design is for a hardware secure 4 to 1 USB hub

**Possible Committee**
Dr. Mike
Dr. Fan Yao
Dr. Ianello
Dr. Mingjie Lin

## General Requirment/Specs

**Basic**
1. The system shall provide USB hub functionality between the host and all enabled downstream USB ports.
2. The system shall independently disconnect power from/restore power to any downstream USB port.
3. The security gateway shall monitor USB enumeration and identify the device descriptor, configuration descriptor, device class, and interface classes of each connected downstream device.
4. The FPGA shall monitor HID traffic and identify abnormal keyboard/mouse input behavior based on configurable timing and/or report-rate thresholds.
5. Upon detection of a configurable security violation, the system shall be capable of: disabling the affected port's 5 V supply, preventing/restricting further communication where architecturally possible, and generating an alert to the host/MCU.
6. A fault or security event on any downstream USB port shall not disable or compromise the operation of the remaining downstream USB ports.
7. Each downstream USB port shall incorporate overvoltage, overcurrent, ESD, and transient protection capable of protecting the hub electronics from specified malicious electrical events.

Possible Security Responses:
Power disconnect
Data disconnect
Alert
Logging
Reset/re-enumeration

**Advanced**

1. The initial implementation shall support a minimum of two downstream USB 2.0 ports, with four downstream USB 2.0 ports as the target configuration.
2. The system shall support configurable security policies for identifying and responding to prohibited or anomalous USB device behavior.
3. The system shall record security events including the affected port, event type, and timestamp. (MCU)


## Security Attacks
**Basic**

Electrical attacks:
USB Killer / malicious overvoltage
Overcurrent / short-circuit conditions
ESD/transient events

Device-class attacks:
Unauthorized or unexpected USB device classes
Composite devices presenting unexpected interfaces
Storage devices presenting HID/network interfaces

**Advanced**

HID injection:
Abnormally rapid keyboard/mouse input
Automated command injection
Unexpected HID report behavior

**Stretch**
Malicious firmware behavior
Descriptor manipulation/anomalies
Mass-storage/file-system-based attacks
USB worms

## Board Requirements/Specs

**Basic**
1. The board shall support USB 2.0 signaling on the host and downstream ports.
2. Each downstream USB port shall provide the USB-specified maximum current to a compliant downstream device under normal operating conditions.
3. The downstream USB port protection circuit shall prevent a specified transient voltage from exceeding the maximum rated voltage of protected components.
4. The protection circuit shall disconnect or clamp the downstream USB power path within <=3 microsecond of detecting a specified transient event.
5. The board shall operate within the available power budget provided by the host USB connection under bus-powered operation.
6. The board shall provide independent fault containment for each downstream USB port such that electrical faults on one port cannot propagate to the host supply or other downstream ports.
7. USB inputs shall still function in the event one input has been isolated from the system.
8. The system shall have the ability to switch off any USB input's power rail.
9. All inputs USBs should have a form of basic ESD protection.
10. The board shall have an output for data monitoring from the MCU.
11. The board shall have a method of external reset.
12. The board shall have a method of powering on/off.

**Advanced**
1. The board shall have an option for external additional USB 5V power
2. When external 5 V power is available, the system shall support increased downstream power availability without back-feeding the host.
3. The power architecture shall prevent reverse current from a downstream port or external power source from entering the host supply.
4. The protection circuit shall disconnect or clamp the downstream USB power path within <=1 microsecond of detecting a specified transient event.
5. The board shall be able to physically indicate whether a downstream port has been disconnected or allowed

**Stretch**
1. 

### Electrical Stress Tests
Basic:
Transient voltage: 240 V
Transient type: ?
Pulse duration: ?
Source impedance: ?
Maximum voltage at protected node: ?
Maximum damage: none


## FPGA Requirements/Specs

FPGA utilizes a timer to check keyboard input rate.
**Basic**
1. The system architecture shall provide the FPGA with sufficient access to USB protocol information to implement the specified security monitoring functions.
2. The FPGA shall provide independent security monitoring for each downstream USB port.
3. The FPGA shall implement configurable HID traffic-rate monitoring.
4. The FPGA shall generate a security event when configured anomalous USB behavior is detected.
5. The FPGA shall interface with the per-port power-control circuitry to disconnect a downstream USB port.
6. The FPGA shall maintain independent security state for each downstream port.
7. The FPGA shall be capable of transitioning an affected port to an isolated state in response to a security event.

**Advanced**
1. The FPGA shall support configurable thresholds for HID traffic-rate detection.
2. In the event of FPGA reset or loss of FPGA control, the system shall transition downstream ports to a predefined safe state.

**Stretch**

## MCU Requirements/Specs

**Basic**
1. The MCU shall receive security events from the FPGA.
2. The MCU shall relay security events and system status to an external host via UART.
3. The MCU shall provide system status information including the operational state of each downstream port.
4. The MCU shall provide an external reset interface.

**Advanced**
1. The MCU shall allow configuration of FPGA security thresholds.
2. The MCU shall allow configuration of USB device security policies.
3. The MCU shall maintain a security event log.

**Stretch**

Basic verification requirements (from chatGPT)

The system shall demonstrate:

Normal operation

2-port USB hub functionality
4-port USB hub functionality
simultaneous operation of downstream devices

Fault isolation

Short/fault one port
Remaining ports continue operating

Power control

Disable individual port
Re-enable individual port

Electrical protection

ESD test
Overcurrent test
Specified transient test

Security

Connect normal keyboard
Connect high-rate HID device
Trigger detection
Isolate malicious port
Remaining ports continue operating

Telemetry

Security event generated
MCU receives event
UART reports event