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

    final statusLabel = isReconnecting
        ? 'Reconnecting…'
        : (isError
            ? 'Serial error'
            : (connected ? 'Connected' : 'Waiting…'));

    final portItems = <String>{
      for (final p in availablePorts) _normalizePort(p),
      if (detail != null && detail!.isNotEmpty) _normalizePort(detail!),
    }.toList()
      ..sort();

    final selected =
        detail != null && detail!.isNotEmpty ? _normalizePort(detail!) : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isError || isReconnecting
                ? HubColors.danger
                : (connected ? HubColors.ok : HubColors.muted),
          ),
        ),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                statusLabel,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 14,
                  color: HubColors.muted,
                ),
              ),
              if (supportsPortSelect && onPortSelected != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 32,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isDense: true,
                          value: selected != null && portItems.contains(selected)
                              ? selected
                              : null,
                          hint: Text(
                            'Select COM',
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 11,
                              color: HubColors.muted,
                            ),
                          ),
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 12,
                            color: HubColors.text,
                          ),
                          dropdownColor: HubColors.surfaceRaised,
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
                    if (onRefreshPorts != null)
                      IconButton(
                        tooltip: 'Refresh ports',
                        onPressed: onRefreshPorts,
                        iconSize: 18,
                        visualDensity: VisualDensity.compact,
                        color: HubColors.muted,
                        icon: const Icon(Icons.refresh),
                      ),
                  ],
                ),
              ] else if (detail != null && detail!.isNotEmpty)
                Text(
                  _portLabel(detail!),
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 11,
                    color: HubColors.muted,
                  ),
                ),
              if ((isError || isReconnecting) &&
                  errorMessage != null &&
                  errorMessage!.isNotEmpty)
                Text(
                  errorMessage!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 10,
                    color: HubColors.danger,
                  ),
                ),
            ],
          ),
        ),
        if (showRetry) ...[
          const SizedBox(width: 12),
          TextButton(
            onPressed: onReconnect,
            style: TextButton.styleFrom(
              foregroundColor: HubColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(
              'Retry',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: HubColors.border),
          ),
          child: Text(
            mode.toUpperCase(),
            style: GoogleFonts.ibmPlexMono(
              fontSize: 11,
              color: isError || isReconnecting
                  ? HubColors.danger
                  : HubColors.accent,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }
}
