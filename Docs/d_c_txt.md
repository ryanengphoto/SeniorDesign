Project Description
Motivation and Background
In the current day, malicious cyber-attacks have become more prevalent than ever, contributing to the loss or theft of data, destruction of property, and compromise of important systems. One such system that malicious parties can exploit to cause such damage is via the Universal Serial Bus (USB) port, commonly used on many everyday personal computing devices. 
USB is one of the most widely used interfaces for connecting peripherals to computers, electronics, and many embedded systems. It is a simple and convenient connection, one that allows devices to be powered, programmed, and interfaced simply by plugging them in. However, its popularity and widespread use make it a prime target for attacks. USB peripherals cannot be assumed to be inherently trustworthy solely because they follow USB protocols. Hosts often communicate with devices for initialization before their behavior is fully evaluated, leaving them vulnerable to attack.
Many USB attacks can be adequately described as a "trojan horse" because they require an individual to connect a malicious device to their trusted host device to properly function. Examples of such attacks include “USB Killer” and “BadUSB” attacks. “USB Killer” attacks use the 5V connection to rapidly charge and discharge over 240V of power into the hardware [1]. This can cause permanent damage to a system and potentially render a system unusable. “BadUSB” attacks involve HID spoofing, a method in which a malicious USB device masquerades as a legitimate peripheral such as a keyboard. The device can then open sensitive applications such as the command prompt at quick speeds and cause damage to the system.  Users, however, cannot be trusted to properly verify a device before connecting it. One publication finds that an attack relying on users to pick up dropped USB devices has an estimated success rate of 45-98% [2]. Adequate hardware and software protection can provide the means to eliminate users from inadvertently compromising a system.
The USB protocol specification does not itself list security or device safety as a design goal or feature in the base USB 2.0/3.2 protocol [3]. Its core objective is designed almost exclusively for ease of peripheral connection, low overhead cost, power efficiency, and high performance. Security checks are often deferred to higher layers in communication; implemented in operating system (OS) software, upper layer protocols such as HTTPS, or internal host device hardware. While host-based security is sufficient for responding to certain threats, it places the trusted system in direct contact with potentially hostile hardware. This presents the need for hardware-level security boundaries that maintain a gateway between a potentially dangerous USB peripheral and the trusted host.
A typical USB hub provides an easy method of connectivity and basic electrical protection for a trusted host. Their intended purpose is to moderate and distribute USB communications to multiple devices; they do not analyze or enforce security measures. This leads to cases where a user may inadvertently connect to a malicious USB device which is given access to the trusted host and other USB peripherals [2]. An intentionally malicious device can leverage device impersonation, false enumeration, protocol abuse, and electrical faults to cause temporary or permanent damage to device hardware, inject malware into a host device, or compromise sensitive data within a system [4].
As security becomes a more prevalent concern in device hardware, more strategic means are required to defend devices from malicious attacks. This project proposes to combine the utility of a common USB hub with the defense of a hardware-based security gateway to create a four-port USB expansion hub capable of preventing electrical damage or malicious attacks via the USB port of a device. A Field Programmable Gate Array (FPGA) architecture will be leveraged to monitor USB communications and provide hardware-level mechanisms for identifying and responding to potentially malicious behavior. Additionally, each downstream port will feature independent power control and analog electrical protection circuitry to isolate and quarantine compromised peripherals, without disabling the remaining ports. 
This project proposes a system which demonstrates a hardware-centric approach to securing a ubiquitous and inherently vulnerable communication interface. Dedicated hardware boundaries can provide an additional layer of security that software environments are unable to implement. This project aims to demonstrate that a USB hub can serve not only as a connectivity device, but also as an active security boundary capable of monitoring, controlling, and isolating potentially untrusted peripherals.
Past Work
Several existing security systems have explored methods of protecting computers from malicious or unauthorized USB devices. These existing systems are useful for our project because they demonstrate different approaches to hardware isolation, USB device identification, and real-time traffic monitoring.
In our research, we found that USB Sentry is one of the closest existing products to our project. USB Sentry combines a four-port USB hub with a hardware firewall that monitors connected devices and can prevent unauthorized USB behavior from reaching the host. This is comparable to our project because both systems provide multiple downstream USB ports, with security hardware between the peripherals and the host. The main difference is that USB Sentry uses microcontrollers for its firewall functionality, while our project plans to use an FPGA for real-time USB monitoring [5].
Another relevant technology is USBGuard, a software framework for controlling which USB devices are allowed to communicate with the computer. USBGuard makes authorization decisions using information such as device identifiers and the classes of interfaces exposed by a USB device [6]. This is relevant to our requirement to monitor USB enumeration and identify the device and interface classes of each connected downstream device. However, our project places the security mechanism in external hardware before USB traffic reaches the host, while USBGuard operates as software on a host.
The USB Security Gateway (USG) provides another example of hardware-based USB protection. USG is placed between an untrusted USB peripheral and the host and uses separate processors to restrict the USB communication that is allowed to cross the security boundary [7]. Our project architecture follows the same general idea of physically isolating an untrusted USB device from the host. Unlike USG, our project will support four independently controlled downstream USB ports and will use an FPGA as part of the security path.
Reviewing these existing systems gives our team a better understanding of the different approaches that can be used to secure USB devices. USB Sentry demonstrates a multi-port hardware firewall; USBGuard shows how device information can be used for authorization, and USG demonstrates hardware isolation between a peripheral and host. Our project takes ideas from these approaches while using a four-port design with an FPGA for USB monitoring and a microcontroller for system control.
Goals and Objectives
In this section are the goals and objectives that were established for the Four-Port USB Hub Security Gateway. Our goals describe the broader idea and vision for the project and its outcome, while our objectives describe specific deliverables and demonstratable capabilities that define the systems' implementation. Each category is divided into basic, advanced, and stretched goals and objectives. Stretch goals and objectives are desired and beneficial to the project but may be beyond the scope of the project's boundaries and implementation.
Goals
Basic Goals:
	Create a compact and enclosed device capable of moderating four downstream USB ports into one upstream port
	Provide full USB 2.0 functionality to all downstream ports including power delivery and data communication
	Utilize an FPGA architecture as the primary method by which USB communications are monitored and filtered for potentially malicious attacks
	Provide analog circuit protection from electrical faults and electrical attacks
Advanced Goals:
	Develop FPGA-based mechanisms for identifying suspicious USB behavior based on predefined rules
	Allow for supplemental auxiliary power to be delivered in the event more current is required than the host can provide in downstream ports.
	Provide a method of viewing security status and logs via embedded software
	Provide fast responsiveness to potential threats
	Detect and respond to threats automatically without need of manual intervention
	Notify users if a device has been cleared or flagged as potentially malicious
	Allow for individual downstream ports to be isolated from one another
Stretch Goals:
	Place FPGA in-line with USB 2.0 communications 
	Allow for redefining of security parameters within the FPGA security architecture
	Allow users to manually whitelist/blacklist specific devices
	Create fully interactable GUI showing connected devices, security status, and event logging
Objectives
Basic Objectives:
	Support 4 downstream USB 2.0 ports simultaneously
	Detect and respond to downstream overcurrent/overvoltage
	Include appropriate protection on each USB port
	Detect when a device has been attached or detached
	Report power, fault, and connection status via the use of an MCU
	Operate with common USB peripherals
Advanced Objectives:
	FPGA monitors USB 2.0 traffic
	Independently switch 5 V power to each port
	Disconnect a faulted port while remaining ports continue operating
	Capture and analyze enumeration transactions
	Evaluate device descriptors
	Log detailed events
	Embedded software communicates with FPGA
	Allow authorized re-enabling of isolated ports
	Monitor traffic without causing disconnects
	Automatically disable suspicious ports
Stretch Objectives:
	Implement a configurable hardware security-rule engine.
	Implement USB device whitelisting/blacklisting.
	Develop a graphical user interface to be displayed on a separate PC
Features and Functionalities
The four-port USB hub security gateway features an on-board hardware security solution to the common attacks seen leveraging USB ports. The gateway will allow a user to connect four downstream USB devices into their personal computer via one upstream USB port. The user will have normal functionality for any device that is connected via the USB hub. The USB hub will actively monitor USB 2.0 communication between the host device and all downstream devices. If any downstream device begins exhibiting suspicious behavior that resembles a USB attack within the threat model, the USB hub will isolate and disconnect that device from the host. This will prevent the host from experiencing a disruption or attack that a malicious USB device may be trying to enact. The USB Hub will also feature a method of allowing extra current among the 5V rail, should the connected peripherals require it. An alternative port connected via barrel jack or USB-C/micro/USB to an appropriate power source (AC Wall outlet) will allow for extra current to be delivered among the four downstream ports.
Similar forms of USB security, such as USB Sentry, leverage microcontrollers to implement security checks [5]. Our security gateway instead features a hardware-based solution driven by an FPGA architecture. Hardware based security solutions can often work in quicker time frames than a microcontroller, allowing the security gateway to catch threats more responsively. Software forms of USB protection, such as USBGuard, are unable to protect against threats exclusive to hardware [6]. Threats such as “USB Killer” attacks directly damage hardware, our system being primarily hardware security focused features analog circuitry methods of preventing electrical damage that software is unable to implement.
Threat Model
The assets the Four-Port USB Hub Security Gateway will protect include: the host computer, host USB data, host USB power, data from legitimate USB peripherals, gateway monitoring FPGA, USB hub/PPHY hardware, power distribution circuitry, connect USB devices, and the gateway configuration parameters. The attacker is assumed to have physical access to a downstream USB port and can connect to a maliciously programmed USB device, electrically dangerous device, or a device that exploits weakness in USB communication protocols. The attacker is not assumed to have access to the internal hardware of the host device or user access to the software of the host device.
The USB Hub will protect against Malicious HID threats. These types of attacks include keyboard injections, which can lead to the compromise of the host system. The security gateway will monitor USB device communications and explicitly cut off keyboards typing at humanly impossible speeds. Device impersonation attacks (BadUSB) which lead to host compromise will be handled by descriptor and class validation within the FPGA architecture. Unauthorized devices with ambiguous descriptors will be blocked and require a manual override to be allowed through the gateway. Excessive current draw, overvoltage, ESD, and “USB Killer” events will be prevented by analog electrical circuitry present within each USB port capable of preventing electrical damage from occurring to sensitive internal circuitry. Devices causing excessive USB traffic or repeated enumeration intended to create a Denial of Service (DoS) will be blocked by the FPGA security gateway. 
Engineering Specifications and Requirements
System Specifications and Requirements
The following table outlines the core engineering specifications of the project. The specifications highlighted in green are those that are chosen as the three demonstrable specifications. The requirements relate to the speed and performance targets of the device in terms of processing packets, making decisions, and reporting telemetry, as well as the qualifications for threat detection, the standards to be followed, and the key power and area requirements.
#	Specification	Requirement	Justification
1	USB Shutoff Latency	<= 1us upper bound, <= 100ns target	The hub must cut off connection to a port before damage occurs.
2	USB Telemetry Latency	<= 100 ms
	Data must be read and reported in a timely manner.
3	HID Packets sent to host during quarantine	0 packets 	Keystroke HIDs must be verified before transmitting.
4	Post-Quarantine Attack Leakage Bound	<= 1 Packet	1 packet at a max can leak through a verified device before a threat is detected.
5	Maximum Keystroke Speed	50 chars/s	A human can only type so fast, any faster is not human.
6	Device Enumeration Latency	<= 5ms	To verify keystroke input devices, the attack vector must be identified in sufficient time.
7	USB Critical Path Added Latency	<= 1ns	Added latency to a USB path can cause timing issues and missed ACKS, the architecture shall add little latency.
8	Per-port delivered Power	2.5W 	Standard non power delivery USB, 5V @ 500mA.
9	USB Speed and Standard	USB 2.0 Full Speed (12 Mbps) and Low Speed (1.5 Mbps)	Support contemporary standards without significant added complexity of higher speeds like 480 Mbps or even higher in USB 3.0+. 
10	Device Size	<= 165 x 115 x 40 mm (L x W x H)	The device should be reasonable in terms of a USB hub but must fit in the Spartan-7 dev-board as a daughter board. This is the size for the container.
11	Total Power Draw	<= 15W	The device shall not consume unnecessary power, even though power draw is not the main focus. It must be able to deliver 10W (4 x 2.5) for the 4 ports and must power the FPGA, MCU, and additional circuitry. 
Figure 1: Overall System Specifications
Component Specifications and Requirements
The following table outlines the component requirements for the project. These specifications are chosen as either reasonable bounds or as standards derived from common implementations. The speed requirement for the analog switch is derived from what is calculated as a maximum delay to prevent a second malicious packet from making its way to the USB hub, which could happen if the switch took too long to shut off. That is calculated as t_"switch_max" =T_"packet_gap" -(t_"FPGA_logic"  ). T_"packet_gap"  is the minimum gap between 2 packets of 2 bits at 12Mbps, which works out to (2×83.33" ns"=166.7" ns" ), t_"FPGA_logic"  is the 2-clock-cycle detection pipeline delay at 48" MHz"  (41.7" ns" ), which gives an allowable turn-off threshold of approximately t_"switch_max"   ≤120" ns" .
#	Specification	Requirement	Justification
1	Analog Switch Turn-off Speed	<= 120ns	Derived from max delay, notes above
2	USB Port Speed and Generation	USB 2.0 Full-Speed	Derived from goals of supporting contemporary standard that is feasible.
3	FPGA Clock Speed for Sniffer	48 MHz	Standard USB oversampling rate [9]. 
4	MCU Clock Speed	>= 50MHz	Provides ample room for processing inputs at 10Hz to update GUI.
6	FPGA Area	> 8,000 LUTs	Plenty of room for architecture without significant congestion.
Figure 2: Component Specifications
Hardware Block Diagram
 
Figure 3: Main Hardware Block Diagram
Shown above is the block diagram for the hardware components of the system. It illustrates the flow from USB inputs to a clean USB output from the USB Hub integrated circuit (IC) to the external host computer with its associated GUI for monitoring the status across each channel. The flow starts at the left where USB inputs enter the USB ports soldered onto the main PCB. The signals exit the ports and enter analog circuitry which will perform the electrical protection against malicious USB devices which execute electrical based attacks rather than firmware-based attacks with overcurrent or overvoltage inputs. These circuitry blocks also encompass the high-speed analog switches which the FPGA controls via its kill signals (red arrows) and the current sensors which will be inputs to the MCU. After leaving the analog circuitry, the USB packets enter the FPGA at the same time they enter the USB Hub IC. To avoid extending the critical path, the FPGA performs packet sniffing in parallel and kills further packets from entering, should a malicious pattern be detected. In some cases, this of course can let through the first packet, but attacks almost always comprise of more than one packet (TODO cite). Along with the kill signals, the FPGA interfaces with the MCU over SPI for telemetry. The MCU reads status registers inside the FPGA over that SPI interface and sends the important info over UART to the host computer, where a GUI monitors the UART bus and displays the important data to the user.
FPGA Fabric Block Diagram 
 
Figure 4: FPGA Block Diagram
	The FPGA has its own separate diagram, since it is neither a PCB level diagram nor a software diagram. The architecture is shown above, where a main wrapper block will hold the packet sniffer part of the logic, as well as the status registers and the SPI interface logic to connect to the MCU. The packet sniffer will also have its own wrapper, where per port sniffer blocks (all the same) will be instantiated. The packet sniffer wrapper will connect those per port sniffer outputs to the status registers and continually update them on each clock cycle so they are stateful. The sniffers themselves will look at incoming USB packets and their properties to search for malicious patterns, an example of which would be keystrokes that are too fast to be human. The sniffer block will include a counter to see how far apart in time each packet is, and being over a certain speed threshold will result in a channel being shut off and the status register updating to specify why (e.g. status[6] = overspeed = 1). The SPI interface will be crucial to facilitate clean communication with the MCU, where the FPGA will be the SPI slave and will serve requests from the MCU as the master.  
Embedded Software Diagram
 
Figure 5: Software Flowchart
The MCU firmware will follow a simple polling loop, since it only needs to read the data from 4 ports and from related power sensors in the analog frontend, there is not a significant need to introduce interrupt complexity. It will follow the flowchart above, where it continually refreshes register and sensor readings in an infinite loop and forwards that info to the GUI over UART. 
