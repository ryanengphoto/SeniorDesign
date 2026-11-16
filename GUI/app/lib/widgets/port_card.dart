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
    // Isolate is operator-only; system quarantine already cut the port.
    final canIsolate = port.state == PortState.authorized;
    final canRestore = port.state == PortState.manualBlocked ||
        port.state == PortState.quarantined;
    final canClearFault = port.threatCode > 0;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: HubColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HubColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final identity = _Identity(port: port);
          final metrics = _MetricsRow(port: port);
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton(
                label: 'Isolate',
                enabled: canIsolate,
                foreground: HubColors.danger,
                onPressed: () =>
                    onCommand(CommandType.isolatePort, port.port),
              ),
              _ActionButton(
                label: 'Restore',
                enabled: canRestore,
                foreground: HubColors.ok,
                onPressed: () =>
                    onCommand(CommandType.restorePort, port.port),
              ),
              _ActionButton(
                label: 'Clear fault',
                enabled: canClearFault,
                foreground: HubColors.muted,
                onPressed: () =>
                    onCommand(CommandType.clearFault, port.port),
              ),
            ],
          );

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 240, child: identity),
                const SizedBox(width: 20),
                Expanded(child: metrics),
                const SizedBox(width: 20),
                actions,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              identity,
              const SizedBox(height: 14),
              metrics,
              const SizedBox(height: 14),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.port});

  final PortStatus port;

  @override
  Widget build(BuildContext context) {
    final showReason = port.threatCode > 0 ||
        port.state == PortState.quarantined ||
        port.state == PortState.manualBlocked;

    return Column(
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
        const SizedBox(height: 10),
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
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: stateForeground(port.state),
            ),
          ),
        ),
        if (showReason) ...[
          const SizedBox(height: 8),
          Text(
            port.threatCode > 0
                ? ThreatCode.nameFor(port.threatCode)
                : 'MANUAL_HOST_KILL',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: HubColors.danger,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.port});

  final PortStatus port;

  @override
  Widget build(BuildContext context) {
    // VBUS / current omitted until INA219 (or equivalent) is wired for real.
    // Separate labeled columns so VID/PID don't visually collide with Classes.
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            _MetricHeader('VID'),
            _MetricHeader('PID'),
            _MetricHeader('Dev class'),
            _MetricHeader('Int class'),
          ],
        ),
        TableRow(
          children: [
            _MetricValue(port.vid),
            _MetricValue(port.pid),
            _MetricValue(port.devClass),
            _MetricValue(port.intClass),
          ],
        ),
      ],
    );
  }
}

class _MetricHeader extends StatelessWidget {
  const _MetricHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 28, bottom: 4),
      child: Text(
        label,
        style: GoogleFonts.ibmPlexSans(
          fontSize: 11,
          color: HubColors.muted,
        ),
      ),
    );
  }
}

class _MetricValue extends StatelessWidget {
  const _MetricValue(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 28),
      child: Text(
        value,
        style: GoogleFonts.ibmPlexMono(
          fontSize: 13,
          color: HubColors.text,
        ),
      ),
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
