import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'hub_service.dart';
import 'protocol.dart';
import 'theme.dart';
import 'widgets/event_log.dart';
import 'widgets/port_card.dart';

/// Live port console (no chrome — [ConsoleShell] owns the header).
class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.hub,
    required this.telemetry,
    required this.events,
  });

  final HubService hub;
  final TelemetryFrame? telemetry;
  final List<SecurityEvent> events;

  @override
  Widget build(BuildContext context) {
    final ports = telemetry?.ports ??
        List.generate(
          4,
          (i) => PortStatus(
            port: i,
            state: PortState.disconnected,
            threatCode: 0,
            vbusMv: 0,
            currentMa: 0,
            vid: '0x0000',
            pid: '0x0000',
            devClass: '0x00',
            intClass: '0x00',
          ),
        );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 960;
              final portsPane = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Downstream ports',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _telemetrySubtitle(hub.mode),
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      color: HubColors.muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: ports.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return PortCard(
                          port: ports[index],
                          onCommand: hub.handleCommand,
                        );
                      },
                    ),
                  ),
                ],
              );

              final logPane = EventLogPanel(
                events: events,
                onClearAll: hub.clearAllEvents,
                onDeleteEvent: hub.deleteEvent,
              );

              if (!wide) {
                return Column(
                  children: [
                    SizedBox(
                      height: constraints.maxHeight * 0.58,
                      child: portsPane,
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: logPane),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 2, child: portsPane),
                  const SizedBox(width: 24),
                  Expanded(child: logPane),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

String _telemetrySubtitle(String mode) {
  switch (mode.toLowerCase()) {
    case 'serial':
      return 'Live telemetry over UART (peer may be mcu_sim — not the PCB).';
    case 'serial_error':
      return 'Serial link down — auto-retrying; use Retry or check cable/power.';
    case 'serial_reconnecting':
      return 'Reconnecting to UART — waiting for peer / hub power.';
    default:
      return 'Live telemetry from the hub management plane (mock).';
  }
}
