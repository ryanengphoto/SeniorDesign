import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dashboard_page.dart';
import 'database_page.dart';
import 'hub_service.dart';
import 'protocol.dart';
import 'theme.dart';
import 'widgets/connection_banner.dart';
import 'widgets/keyboard_confirm_dialog.dart';

enum ConsoleSection { dashboard, database }

/// Top-level chrome: logo, product name, Dashboard / Database nav.
class ConsoleShell extends StatefulWidget {
  const ConsoleShell({super.key, required this.hub});

  final HubService hub;

  @override
  State<ConsoleShell> createState() => _ConsoleShellState();
}

class _ConsoleShellState extends State<ConsoleShell> {
  ConsoleSection _section = ConsoleSection.dashboard;
  TelemetryFrame? _telemetry;
  List<SecurityEvent> _events = const [];
  List<String> _serialPorts = const [];
  final Set<int> _promptedPendingPorts = {};
  int? _activeDialogPort;
  BuildContext? _activeDialogContext;

  void _refreshSerialPorts() {
    if (!widget.hub.supportsPortSelect) {
      return;
    }
    setState(() => _serialPorts = widget.hub.listSerialPorts());
  }

  void _showKeyboardConfirmDialog(PortStatus port) {
    if (!mounted || _activeDialogPort == port.port) {
      return;
    }
    _activeDialogPort = port.port;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      KeyboardConfirmDialog.show(
        context,
        port: port,
        onContextReady: (dialogCtx) {
          _activeDialogContext = dialogCtx;
        },
        onConfirm: () =>
            widget.hub.handleCommand(CommandType.confirmHid, port.port),
        onIsolate: () =>
            widget.hub.handleCommand(CommandType.isolatePort, port.port),
      ).then((_) {
        if (_activeDialogPort == port.port) {
          _activeDialogPort = null;
          _activeDialogContext = null;
        }
      });
    });
  }

  void _checkPendingHidConfirm(TelemetryFrame frame) {
    final currentPending = <int>{};
    for (final p in frame.ports) {
      if (p.state == PortState.pendingHidConfirm) {
        currentPending.add(p.port);
        if (!_promptedPendingPorts.contains(p.port)) {
          _promptedPendingPorts.add(p.port);
          _showKeyboardConfirmDialog(p);
        }
      } else if (p.state == PortState.manualBlocked ||
          p.state == PortState.disconnected ||
          p.state == PortState.authorized) {
        // Isolate / unplug / confirm ends the prior prompt session so a later
        // PENDING (restore re-arm or new plug) can show the dialog again.
        _promptedPendingPorts.remove(p.port);
      }
    }

    _promptedPendingPorts
        .removeWhere((portId) => !currentPending.contains(portId));

    if (_activeDialogPort != null &&
        !currentPending.contains(_activeDialogPort)) {
      if (_activeDialogContext != null && _activeDialogContext!.mounted) {
        Navigator.of(_activeDialogContext!).pop();
      }
      _activeDialogPort = null;
      _activeDialogContext = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _telemetry = widget.hub.latestTelemetry;
    _events = widget.hub.events;
    _serialPorts = widget.hub.supportsPortSelect
        ? widget.hub.listSerialPorts()
        : const [];
    widget.hub.telemetryStream.listen((frame) {
      if (!mounted) {
        return;
      }
      setState(() => _telemetry = frame);
      _checkPendingHidConfirm(frame);
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
          if (widget.hub.supportsPortSelect) {
            _serialPorts = widget.hub.listSerialPorts();
          }
        });
        if (_telemetry != null) {
          _checkPendingHidConfirm(_telemetry!);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = _telemetry != null &&
        !widget.hub.mode.toLowerCase().contains('error') &&
        !widget.hub.mode.toLowerCase().contains('reconnect');

    return Scaffold(
      body: Column(
        children: [
          _ConsoleHeader(
            section: _section,
            onSectionChanged: (section) => setState(() => _section = section),
            connected: connected,
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
            supportsPortSelect: widget.hub.supportsPortSelect,
            availablePorts: _serialPorts,
            onPortSelected: widget.hub.supportsPortSelect
                ? (port) {
                    widget.hub.setSerialPort(port);
                    setState(() {
                      _telemetry = widget.hub.latestTelemetry;
                      _serialPorts = widget.hub.listSerialPorts();
                    });
                  }
                : null,
            onRefreshPorts:
                widget.hub.supportsPortSelect ? _refreshSerialPorts : null,
            supportsBaudSelect: widget.hub.supportsBaudSelect,
            baudRate: widget.hub.baudRate,
            onBaudSelected: widget.hub.supportsBaudSelect
                ? (baud) {
                    widget.hub.setBaudRate(baud);
                    setState(() {
                      _telemetry = widget.hub.latestTelemetry;
                    });
                  }
                : null,
          ),
          Expanded(
            child: IndexedStack(
              index: _section.index,
              children: [
                DashboardPage(
                  hub: widget.hub,
                  telemetry: _telemetry,
                  events: _events,
                  onRequestConfirmKeyboard: _showKeyboardConfirmDialog,
                ),
                DatabasePage(
                  liveEvents: _events,
                  onClearAll: widget.hub.clearAllEvents,
                  onDeleteEvent: widget.hub.deleteEvent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsoleHeader extends StatelessWidget {
  const _ConsoleHeader({
    required this.section,
    required this.onSectionChanged,
    required this.connected,
    required this.mode,
    required this.detail,
    required this.errorMessage,
    required this.supportsReconnect,
    required this.onReconnect,
    this.supportsPortSelect = false,
    this.availablePorts = const [],
    this.onPortSelected,
    this.onRefreshPorts,
    this.supportsBaudSelect = false,
    this.baudRate = SerialBaud.defaultRate,
    this.onBaudSelected,
  });

  final ConsoleSection section;
  final ValueChanged<ConsoleSection> onSectionChanged;
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
  final ValueChanged<int>? onBaudSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: HubColors.surface.withValues(alpha: 0.85),
        border: const Border(
          bottom: BorderSide(color: HubColors.border),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipOval(
              child: Image.asset(
                'assets/branding/logo.png',
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 96,
                  height: 96,
                  color: HubColors.surfaceRaised,
                  alignment: Alignment.center,
                  child: Icon(Icons.lock_outline, color: HubColors.accent),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                    'Peripheral Interface Security System',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _NavChip(
                        label: 'Dashboard',
                        selected: section == ConsoleSection.dashboard,
                        onTap: () =>
                            onSectionChanged(ConsoleSection.dashboard),
                      ),
                      _NavChip(
                        label: 'Database',
                        selected: section == ConsoleSection.database,
                        onTap: () =>
                            onSectionChanged(ConsoleSection.database),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ConnectionBanner(
              connected: connected,
              mode: mode,
              detail: detail,
              errorMessage: errorMessage,
              supportsReconnect: supportsReconnect,
              onReconnect: onReconnect,
              supportsPortSelect: supportsPortSelect,
              availablePorts: availablePorts,
              onPortSelected: onPortSelected,
              onRefreshPorts: onRefreshPorts,
              supportsBaudSelect: supportsBaudSelect,
              baudRate: baudRate,
              onBaudSelected: onBaudSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? HubColors.accent.withValues(alpha: 0.15)
          : HubColors.surfaceRaised,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? HubColors.accent.withValues(alpha: 0.5)
                  : HubColors.border,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? HubColors.accent : HubColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
