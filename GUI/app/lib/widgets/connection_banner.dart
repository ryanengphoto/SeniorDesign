import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

String _portLabel(String path) {
  final match =
      RegExp(r'^\\\\\.\\(COM\d+)$', caseSensitive: false).firstMatch(path.trim());
  if (match != null) {
    return match.group(1)!.toUpperCase();
  }
  return path.trim();
}

String _normalizePort(String path) {
  final trimmed = path.trim();
  final prefixed =
      RegExp(r'^\\\\\.\\(COM\d+)$', caseSensitive: false).firstMatch(trimmed);
  final bare = prefixed?.group(1) ?? trimmed;
  final match = RegExp(r'^COM(\d+)$', caseSensitive: false).firstMatch(bare);
  if (match == null) {
    return bare;
  }
  final n = int.parse(match.group(1)!);
  if (n >= 10) {
    return '\\\\.\\COM$n';
  }
  return 'COM$n';
}

class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({
    super.key,
    required this.connected,
    required this.mode,
    this.detail,
    this.errorMessage,
    this.supportsReconnect = false,
    this.onReconnect,
    this.supportsPortSelect = false,
    this.availablePorts = const [],
    this.onPortSelected,
    this.onRefreshPorts,
  });

  final bool connected;
  final String mode;
  final String? detail;
  final String? errorMessage;
  final bool supportsReconnect;
  final VoidCallback? onReconnect;
  final bool supportsPortSelect;
  final List<String> availablePorts;
  final ValueChanged<String>? onPortSelected;
  final VoidCallback? onRefreshPorts;

  @override
  Widget build(BuildContext context) {
    final lower = mode.toLowerCase();
    final isError = lower.contains('error');
    final isReconnecting = lower.contains('reconnect');
    final showRetry = supportsReconnect &&
        onReconnect != null &&
        (isError || isReconnecting);

    final portItems = <String>{
      for (final p in availablePorts) _normalizePort(p),
      if (detail != null && detail!.isNotEmpty) _normalizePort(detail!),
    }.toList()
      ..sort();

    final selected =
        detail != null && detail!.isNotEmpty ? _normalizePort(detail!) : null;

    final hasPortSelected =
        selected != null && selected.isNotEmpty && selected != 'No port selected';

    final portName = selected != null
        ? _portLabel(selected)
        : (detail != null && detail!.isNotEmpty
            ? _portLabel(detail!)
            : 'Port');

    final String statusLabel;
    final Color statusColor;
    if (isReconnecting) {
      statusLabel = 'Reconnecting…';
      statusColor = HubColors.warn;
    } else if (isError) {
      statusLabel = '$portName disconnected';
      statusColor = HubColors.danger;
    } else if (connected) {
      statusLabel = 'Connected';
      statusColor = HubColors.muted;
    } else if (supportsPortSelect && !hasPortSelected) {
      statusLabel = 'No port selected';
      statusColor = HubColors.muted;
    } else {
      statusLabel = 'Connecting…';
      statusColor = HubColors.warn;
    }

    final modeLabel = mode.toLowerCase().startsWith('serial')
        ? 'SERIAL'
        : mode.toUpperCase();

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isError
                ? HubColors.danger
                : (isReconnecting
                    ? HubColors.warn
                    : (connected
                        ? HubColors.ok
                        : (supportsPortSelect && !hasPortSelected
                            ? HubColors.muted.withValues(alpha: 0.4)
                            : HubColors.warn))),
          ),
        ),
        const SizedBox(width: 8),
        if (supportsPortSelect && onPortSelected != null) ...[
          SizedBox(
            height: 32,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isDense: true,
                focusColor: Colors.transparent,
                dropdownColor: HubColors.surfaceRaised,
                borderRadius: BorderRadius.circular(8),
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: HubColors.muted,
                ),
                value: selected != null && portItems.contains(selected)
                    ? selected
                    : null,
                hint: Text(
                  'Select COM',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    color: HubColors.muted,
                  ),
                ),
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  color: HubColors.text,
                ),
                items: portItems
                    .map(
                      (path) => DropdownMenuItem(
                        value: path,
                        child: Text(_portLabel(path)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    onPortSelected!(value);
                  }
                },
              ),
            ),
          ),
          if (onRefreshPorts != null) ...[
            const SizedBox(width: 2),
            IconButton(
              tooltip: 'Refresh ports',
              onPressed: onRefreshPorts,
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              splashRadius: 16,
              color: HubColors.muted,
              icon: const Icon(Icons.refresh),
            ),
          ],
          const SizedBox(width: 8),
        ] else if (detail != null && detail!.isNotEmpty) ...[
          Text(
            _portLabel(detail!),
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              color: HubColors.muted,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Tooltip(
          message: errorMessage != null && errorMessage!.isNotEmpty
              ? errorMessage!
              : statusLabel,
          waitDuration: const Duration(milliseconds: 300),
          child: Text(
            statusLabel,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              fontWeight: isError || isReconnecting
                  ? FontWeight.w500
                  : FontWeight.normal,
              color: statusColor,
            ),
          ),
        ),
        if (showRetry) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onReconnect,
            style: TextButton.styleFrom(
              foregroundColor: HubColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              'Retry',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: HubColors.border),
          ),
          child: Text(
            modeLabel,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 11,
              color: isError
                  ? HubColors.danger
                  : (isReconnecting ? HubColors.warn : HubColors.accent),
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }
}
