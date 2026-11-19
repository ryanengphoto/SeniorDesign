import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../protocol.dart';
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
    this.supportsBaudSelect = false,
    this.baudRate = SerialBaud.defaultRate,
    this.baudChoices = SerialBaud.choices,
    this.onBaudSelected,
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
  final bool supportsBaudSelect;
  final int baudRate;
  final List<int> baudChoices;
  final ValueChanged<int>? onBaudSelected;

  @override
  Widget build(BuildContext context) {
    final lower = mode.toLowerCase();
    final isError = lower.contains('error');
    final isReconnecting = lower.contains('reconnect');
    final showRetry = supportsReconnect &&
        onReconnect != null &&
        (isError || isReconnecting);
    final isSerialMode = lower.startsWith('serial');
    final showBaud =
        supportsBaudSelect && onBaudSelected != null && isSerialMode;

    final portItems = <String>{
      for (final p in availablePorts) _normalizePort(p),
      if (detail != null &&
          detail!.isNotEmpty &&
          detail != 'No port selected')
        _normalizePort(detail!),
    }.toList()
      ..sort();

    final selected = (detail != null &&
            detail!.isNotEmpty &&
            detail != 'No port selected')
        ? _normalizePort(detail!)
        : null;

    final hasPortSelected = selected != null && selected.isNotEmpty;

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
      statusLabel = 'Disconnected';
      statusColor = HubColors.muted;
    } else {
      statusLabel = 'Connecting…';
      statusColor = HubColors.warn;
    }

    final baudItems = <int>{
      ...baudChoices,
      baudRate,
    }.toList()
      ..sort();

    final statusDot = Container(
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
    );

    final statusLabelText = Text(
      statusLabel,
      style: GoogleFonts.ibmPlexSans(
        fontSize: 13,
        fontWeight:
            isError || isReconnecting ? FontWeight.w500 : FontWeight.normal,
        color: statusColor,
      ),
    );
    // Only tooltip when there is extra detail (errors); don't echo "Connected".
    final statusText = (errorMessage != null && errorMessage!.isNotEmpty)
        ? Tooltip(
            message: errorMessage!,
            waitDuration: const Duration(milliseconds: 300),
            child: statusLabelText,
          )
        : statusLabelText;

    final retryButton = showRetry
        ? TextButton(
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
          )
        : null;

    final mockPill = !isSerialMode
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: HubColors.border),
            ),
            child: Text(
              mode.toUpperCase(),
              style: GoogleFonts.ibmPlexMono(
                fontSize: 11,
                color: HubColors.accent,
                letterSpacing: 0.8,
              ),
            ),
          )
        : null;

    Widget? portControls;
    if (supportsPortSelect && onPortSelected != null) {
      portControls = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 28,
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
          if (onRefreshPorts != null)
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
      );
    } else if (detail != null && detail!.isNotEmpty) {
      portControls = Text(
        _portLabel(detail!),
        style: GoogleFonts.ibmPlexSans(
          fontSize: 12,
          color: HubColors.muted,
        ),
      );
    }

    final baudControls = showBaud
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Baud rate',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 11,
                  color: HubColors.muted,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 28,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isDense: true,
                    focusColor: Colors.transparent,
                    dropdownColor: HubColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(8),
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: HubColors.muted,
                    ),
                    value: baudRate,
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 12,
                      color: HubColors.text,
                    ),
                    items: baudItems
                        .map(
                          (rate) => DropdownMenuItem(
                            value: rate,
                            child: Text('$rate'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        onBaudSelected!(value);
                      }
                    },
                  ),
                ),
              ),
            ],
          )
        : null;

    // Status sits left of the indicator + COM/baud so longer warnings
    // (and Retry) don't shove the dropdowns.
    final statusCluster = SizedBox(
      width: 168,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (retryButton != null) ...[
              retryButton,
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: statusText,
              ),
            ),
          ],
        ),
      ),
    );

    // Serial: status | ● COM ; baud under COM.
    // Mock: status | ● MOCK.
    if (showBaud || portControls != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          statusCluster,
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: statusDot,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (portControls != null) portControls,
                  if (mockPill != null) ...[
                    if (portControls != null) const SizedBox(width: 8),
                    mockPill,
                  ],
                ],
              ),
              if (baudControls != null) ...[
                const SizedBox(height: 2),
                baudControls,
              ],
            ],
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        statusCluster,
        const SizedBox(width: 10),
        statusDot,
        if (mockPill != null) ...[
          const SizedBox(width: 8),
          mockPill,
        ],
      ],
    );
  }
}
