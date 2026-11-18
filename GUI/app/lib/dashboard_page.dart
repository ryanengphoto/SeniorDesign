import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'hub_service.dart';
import 'protocol.dart';
import 'theme.dart';
import 'widgets/event_log.dart';
import 'widgets/port_card.dart';

/// Live port console (no chrome — [ConsoleShell] owns the header).
class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.hub,
    required this.telemetry,
    required this.events,
    this.onRequestConfirmKeyboard,
  });

  final HubService hub;
  final TelemetryFrame? telemetry;
  final List<SecurityEvent> events;
  final void Function(PortStatus port)? onRequestConfirmKeyboard;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _showLog = true;

  @override
  Widget build(BuildContext context) {
    final telemetry = widget.telemetry;
    final hub = widget.hub;
    final events = widget.events;
    final onRequestConfirmKeyboard = widget.onRequestConfirmKeyboard;
    final ports = telemetry?.ports ??
        List.generate(
          4,
          (i) => PortStatus(
            port: i,
            state: PortState.disconnected,
            threatCode: 0,
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
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 960;
              final portsPane = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Downstream ports',
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_telemetrySubtitle(hub.mode) case final subtitle?) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 13,
                                color: HubColors.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() => _showLog = !_showLog),
                        icon: Icon(
                          _showLog
                              ? Icons.view_sidebar_outlined
                              : Icons.view_sidebar,
                          size: 16,
                        ),
                        label: Text(_showLog ? 'Hide log' : 'Show log'),
                        style: TextButton.styleFrom(
                          foregroundColor: HubColors.muted,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          textStyle: GoogleFonts.ibmPlexSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      itemCount: ports.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final port = ports[index];
                        return PortCard(
                          port: port,
                          onCommand: hub.handleCommand,
                          onRequestConfirmKeyboard:
                              onRequestConfirmKeyboard != null
                                  ? () => onRequestConfirmKeyboard(port)
                                  : null,
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
                onClose: () => setState(() => _showLog = false),
              );

              if (!_showLog) {
                return portsPane;
              }

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

String? _telemetrySubtitle(String mode) {
  switch (mode.toLowerCase()) {
    case 'serial_error':
      return 'Serial link down — auto-retrying; use Retry or check cable/power.';
    case 'serial_reconnecting':
      return 'Reconnecting — waiting for peer / hub power.';
    default:
      return null;
  }
}
