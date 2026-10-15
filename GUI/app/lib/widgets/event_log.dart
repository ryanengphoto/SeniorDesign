import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../protocol.dart';
import '../theme.dart';

class EventLogPanel extends StatefulWidget {
  const EventLogPanel({super.key, required this.events});

  final List<SecurityEvent> events;

  @override
  State<EventLogPanel> createState() => _EventLogPanelState();
}

class _EventLogPanelState extends State<EventLogPanel> {
  final _controller = ScrollController();
  bool _paused = false;

  @override
  void didUpdateWidget(covariant EventLogPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_paused && widget.events.length != oldWidget.events.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_controller.hasClients) {
          return;
        }
        _controller.animateTo(
          _controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final events = widget.events;

    return MouseRegion(
      onEnter: (_) => setState(() => _paused = true),
      onExit: (_) => setState(() => _paused = false),
      child: Container(
        decoration: BoxDecoration(
          color: HubColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HubColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Security event log',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${events.length} event${events.length == 1 ? '' : 's'}',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 12,
                            color: HubColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_paused)
                    Text(
                      'Auto-scroll paused',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 11,
                        color: HubColors.warn,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: HubColors.border),
            Expanded(
              child: events.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Waiting for security events…',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 14,
                          color: HubColors.muted,
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: _controller,
                      padding: const EdgeInsets.all(16),
                      itemCount: events.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: HubColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: HubColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    event.formattedAt,
                                    style: GoogleFonts.ibmPlexMono(
                                      fontSize: 11,
                                      color: HubColors.accent,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Port ${event.port + 1}',
                                    style: GoogleFonts.ibmPlexMono(
                                      fontSize: 11,
                                      color: HubColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                event.threatName,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                event.message,
                                style: GoogleFonts.ibmPlexSans(
                                  fontSize: 13,
                                  color: HubColors.muted,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
