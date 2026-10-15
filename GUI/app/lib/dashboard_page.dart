import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'hub_service.dart';
import 'protocol.dart';
import 'theme.dart';
import 'widgets/connection_banner.dart';
import 'widgets/event_log.dart';
import 'widgets/port_card.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.hub});

  final HubService hub;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  TelemetryFrame? _telemetry;
  List<SecurityEvent> _events = const [];

  @override
  void initState() {
    super.initState();
    _telemetry = widget.hub.latestTelemetry;
    _events = widget.hub.events;
    widget.hub.telemetryStream.listen((frame) {
      if (!mounted) {
        return;
      }
      setState(() => _telemetry = frame);
    });
    widget.hub.eventsStream.listen((events) {
      if (!mounted) {
        return;
      }
      setState(() => _events = events);
    });
    unawaited(
      widget.hub.start().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _telemetry = widget.hub.latestTelemetry;
          _events = widget.hub.events;
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ports = _telemetry?.ports ??
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

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: HubColors.surface.withValues(alpha: 0.85),
              border: const Border(
                bottom: BorderSide(color: HubColors.border),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OPERATOR CONSOLE',
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 11,
                            letterSpacing: 2,
                            color: HubColors.accent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hardware-secure USB Hub',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ConnectionBanner(
                    connected: _telemetry != null &&
                        !widget.hub.mode.toLowerCase().contains('error') &&
                        !widget.hub.mode
                            .toLowerCase()
                            .contains('reconnect'),
                    mode: widget.hub.mode,
                    detail: widget.hub.detail,
                    errorMessage: widget.hub.errorMessage,
                    supportsReconnect: widget.hub.supportsReconnect,
                    onReconnect: widget.hub.supportsReconnect
                        ? () {
                            widget.hub.reconnect();
                            setState(() {});
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
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
                            _telemetrySubtitle(widget.hub.mode),
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 13,
                              color: HubColors.muted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, gridConstraints) {
                                final cols = wide ? 2 : 1;
                                const gap = 16.0;
                                final cardWidth =
                                    (gridConstraints.maxWidth -
                                        gap * (cols - 1)) /
                                    cols;
                                return SingleChildScrollView(
                                  child: Wrap(
                                    spacing: gap,
                                    runSpacing: gap,
                                    children: [
                                      for (final port in ports)
                                        SizedBox(
                                          width: cardWidth,
                                          child: PortCard(
                                            port: port,
                                            onCommand:
                                                widget.hub.handleCommand,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );

                      if (!wide) {
                        return Column(
                          children: [
                            SizedBox(
                              height: constraints.maxHeight * 0.58,
                              child: portsPane,
                            ),
                            const SizedBox(height: 16),
                            Expanded(child: EventLogPanel(events: _events)),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 2, child: portsPane),
                          const SizedBox(width: 24),
                          Expanded(
                            child: EventLogPanel(events: _events),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
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

