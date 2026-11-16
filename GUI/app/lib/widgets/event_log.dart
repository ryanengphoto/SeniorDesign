import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../db/event_export.dart';
import '../protocol.dart';
import '../theme.dart';

class EventLogPanel extends StatefulWidget {
  const EventLogPanel({
    super.key,
    required this.events,
    required this.onClearAll,
    required this.onDeleteEvent,
  });

  final List<SecurityEvent> events;
  final Future<void> Function() onClearAll;
  final Future<void> Function(int id) onDeleteEvent;

  @override
  State<EventLogPanel> createState() => _EventLogPanelState();
}

class _EventLogPanelState extends State<EventLogPanel> {
  final _controller = ScrollController();
  bool _paused = false;

  /// null = all ports; otherwise 0–3.
  int? _portFilter;

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

  List<SecurityEvent> get _visible {
    final filter = _portFilter;
    if (filter == null) {
      return widget.events;
    }
    return widget.events.where((e) => e.port == filter).toList(growable: false);
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HubColors.surface,
        title: Text(
          'Clear database?',
          style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Deletes all persisted security events from the local database.',
          style: GoogleFonts.ibmPlexSans(color: HubColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: HubColors.danger),
            child: const Text('Clear database'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.onClearAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event database cleared')),
        );
      }
    }
  }

  Future<void> _exportDatabase() async {
    try {
      final message = await saveEventExport(widget.events);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on Object catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = _visible;
    final total = widget.events.length;

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
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
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
                              _portFilter == null
                                  ? '$total event${total == 1 ? '' : 's'}'
                                  : '${events.length} of $total'
                                      ' (port ${_portFilter! + 1})',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 12,
                                color: HubColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_paused)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            'Auto-scroll paused',
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 11,
                              color: HubColors.warn,
                            ),
                          ),
                        ),
                      MenuAnchor(
                        style: MenuStyle(
                          backgroundColor: WidgetStatePropertyAll(
                            HubColors.surfaceRaised,
                          ),
                        ),
                        builder: (context, controller, child) {
                          return TextButton.icon(
                            onPressed: () {
                              if (controller.isOpen) {
                                controller.close();
                              } else {
                                controller.open();
                              }
                            },
                            icon: const Icon(Icons.menu, size: 18),
                            label: Text(
                              'Menu',
                              style: GoogleFonts.ibmPlexSans(fontSize: 12),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: HubColors.text,
                              visualDensity: VisualDensity.compact,
                            ),
                          );
                        },
                        menuChildren: [
                          SubmenuButton(
                            style: ButtonStyle(
                              foregroundColor: WidgetStatePropertyAll(
                                HubColors.text,
                              ),
                            ),
                            menuStyle: MenuStyle(
                              backgroundColor: WidgetStatePropertyAll(
                                HubColors.surfaceRaised,
                              ),
                            ),
                            menuChildren: [
                              MenuItemButton(
                                onPressed: total == 0
                                    ? null
                                    : () {
                                        _exportDatabase();
                                      },
                                leadingIcon: const Icon(
                                  Icons.file_download_outlined,
                                  size: 18,
                                ),
                                child: const Text('Export database'),
                              ),
                              MenuItemButton(
                                onPressed: total == 0
                                    ? null
                                    : () {
                                        _confirmClearAll();
                                      },
                                leadingIcon: Icon(
                                  Icons.delete_sweep_outlined,
                                  size: 18,
                                  color: total == 0
                                      ? HubColors.muted
                                      : HubColors.danger,
                                ),
                                child: Text(
                                  'Clear database',
                                  style: TextStyle(
                                    color: total == 0
                                        ? HubColors.muted
                                        : HubColors.danger,
                                  ),
                                ),
                              ),
                            ],
                            leadingIcon: const Icon(
                              Icons.storage_outlined,
                              size: 18,
                            ),
                            child: const Text('Database'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Filter',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 12,
                          color: HubColors.muted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownMenu<int?>(
                          initialSelection: _portFilter,
                          expandedInsets: EdgeInsets.zero,
                          textStyle: GoogleFonts.ibmPlexMono(
                            fontSize: 12,
                            color: HubColors.text,
                          ),
                          inputDecorationTheme: InputDecorationTheme(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: HubColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: HubColors.border),
                            ),
                          ),
                          dropdownMenuEntries: const [
                            DropdownMenuEntry<int?>(
                              value: null,
                              label: 'All ports',
                            ),
                            DropdownMenuEntry<int?>(
                              value: 0,
                              label: 'Port 1',
                            ),
                            DropdownMenuEntry<int?>(
                              value: 1,
                              label: 'Port 2',
                            ),
                            DropdownMenuEntry<int?>(
                              value: 2,
                              label: 'Port 3',
                            ),
                            DropdownMenuEntry<int?>(
                              value: 3,
                              label: 'Port 4',
                            ),
                          ],
                          onSelected: (value) {
                            setState(() => _portFilter = value);
                          },
                        ),
                      ),
                    ],
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
                        total == 0
                            ? 'Waiting for security events…'
                            : 'No events for this port filter.',
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
                          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                          decoration: BoxDecoration(
                            color: HubColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: HubColors.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
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
                              ),
                              IconButton(
                                tooltip: 'Delete event',
                                onPressed: event.id == null
                                    ? null
                                    : () => widget.onDeleteEvent(event.id!),
                                icon: const Icon(Icons.close, size: 18),
                                color: HubColors.muted,
                                disabledColor:
                                    HubColors.muted.withValues(alpha: 0.25),
                                visualDensity: VisualDensity.compact,
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
