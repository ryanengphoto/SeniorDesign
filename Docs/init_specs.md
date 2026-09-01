# USB 4-1 Initial Design Specification

The initial design is for a hardware secure 4 to 1 USB hub

**Possible Committee**
Dr. Mike
Dr. Fan Yao
Dr. Ianello
Dr. Mingjie Lin

## General Requirment/Specs

At a minimum we want a 2-1 USB hub, in general 4-1 USB hub is the goal

**General Function**
Basic:
2-1 USB hub functionality

Advanced:
4-1 USB hub functionality


**Security Function**
Basic:
USB Killer - Overvoltage/current protection
BadUSB - flash drive emulates a keyboard or network card to download malware or steal data

Advanced:
HID Injection - flash drive emulates a human interface device (keyboard or mouse) to execute backdoor commands at fast speeds
USB Worms - USBs with self-replicating malware infect a computer upon being connected 

Stretch:
Other Firmware Based Attacks

## Board Requirements/Specs

**Basic**
1. Each USB input should be supplied 5V delivered from the host
2. Each USB input should be capable of withstanding a 240V surge.
3. The voltage protection mechanism shall trigger in less than ~1 microsecond
4. The board shall be capable of isolating USB inputs from the host and other USB inputs.
5. USB inputs shall still function in the event one input has been isolated from the system.
6. The system shall have the ability to switch off any USB input's power rail.
7. All inputs USBs should have a form of basic ESD protection.
8. The board shall have an output for data monitoring from the MCU.
9. The board shall have a method of external reset.
10. The board shall have a method of powering on/off.

**Advanced**
1. Each USB input should be capable of withstanding a 500V surge
2. The board should have an option for external additional USB 5V power
3. 

**Stretch**
1. 


## FPGA Requirements/Specs

FPGA utilizes a timer to check keyboard input rate.
**Basic**
1. The FPGA shall be capable of switching off the 5V rails for isolated/powered off USB inputs.
2. The FPGA shall be capable of implementing USB security features.
3. 

**Advanced**


## MCU Requirements/Specs

**Basic**
1. The MCU shall be capable of relaying data to a host computer via UART