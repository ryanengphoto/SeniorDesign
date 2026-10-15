import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../protocol.dart';
import '../theme.dart';
import 'threat_badge.dart';

class PortCard extends StatelessWidget {
  const PortCard({
    super.key,
    required this.port,
    required this.onCommand,
  });

  final PortStatus port;
  final void Function(CommandType cmd, int port) onCommand;

  @override
  Widget build(BuildContext context) {
    final canIsolate = port.state != PortState.disconnected &&
        port.state != PortState.manualBlocked;
    final canRestore = port.state == PortState.manualBlocked ||
        port.state == PortState.quarantined;
    final canClearFault = port.threatCode > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HubColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HubColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PORT ${port.port + 1}',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 11,
                        letterSpacing: 1.6,
                        color: HubColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: stateBackground(port.state),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: stateBorder(port.state)),
                      ),
                      child: Text(
                        port.state.label,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: stateForeground(port.state),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ThreatBadge(threatCode: port.threatCode),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'VID / PID',
                  value: '${port.vid} / ${port.pid}',
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Classes',
                  value: '${port.devClass} / ${port.intClass}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'VBUS',
                  value: '${(port.vbusMv / 1000).toStringAsFixed(2)} V',
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Current',
                  value: '${port.currentMa} mA',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton(
                label: 'Isolate',
                enabled: canIsolate,
                foreground: HubColors.danger,
                onPressed: () => onCommand(CommandType.isolatePort, port.port),
              ),
              _ActionButton(
                label: 'Restore',
                enabled: canRestore,
                foreground: HubColors.ok,
                onPressed: () => onCommand(CommandType.restorePort, port.port),
              ),
              _ActionButton(
                label: 'Clear fault',
                enabled: canClearFault,
                foreground: HubColors.muted,
                onPressed: () => onCommand(CommandType.clearFault, port.port),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 11,
            color: HubColors.muted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.ibmPlexMono(
            fontSize: 13,
            color: HubColors.text,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.enabled,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        disabledForegroundColor: foreground.withValues(alpha: 0.35),
        side: BorderSide(
          color: enabled
              ? foreground.withValues(alpha: 0.4)
              : HubColors.border,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: GoogleFonts.ibmPlexSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: Text(label),
    );
  }
}
