import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'db/event_export.dart';
import 'db/read_picked_file.dart';
import 'protocol.dart';
import 'theme.dart';

enum _EventSort {
  newestFirst,
  oldestFirst,
  portAsc,
  threatCodeAsc,
  threatNameAsc,
}

extension on _EventSort {
  String get label => switch (this) {
        _EventSort.newestFirst => 'Newest first',
        _EventSort.oldestFirst => 'Oldest first',
        _EventSort.portAsc => 'Port (1→4)',
        _EventSort.threatCodeAsc => 'Threat code',
        _EventSort.threatNameAsc => 'Threat name',
      };
}

/// Full-width security-event database viewer (no port cards).
class DatabasePage extends StatefulWidget {
  const DatabasePage({
    super.key,
    required this.liveEvents,
    required this.onClearAll,
    required this.onDeleteEvent,
  });

  final List<SecurityEvent> liveEvents;
  final Future<void> Function() onClearAll;
  final Future<void> Function(int id) onDeleteEvent;

  static const int pageSize = 50;

  @override
  State<DatabasePage> createState() => _DatabasePageState();
}

class _DatabasePageState extends State<DatabasePage> {
  int? _portFilter;
  _EventSort _sort = _EventSort.newestFirst;
  int _visibleLimit = DatabasePage.pageSize;
  List<SecurityEvent>? _loadedEvents;
  String? _loadedLabel;
  final ScrollController _verticalScroll = ScrollController();
  final ScrollController _horizontalScroll = ScrollController();

  @override
  void dispose() {
    _verticalScroll.dispose();
    _horizontalScroll.dispose();
    super.dispose();
  }

  List<SecurityEvent> get _source => _loadedEvents ?? widget.liveEvents;

  List<SecurityEvent> get _filteredSorted {
    final filter = _portFilter;
    final list = filter == null
        ? List<SecurityEvent>.from(_source)
        : _source.where((e) => e.port == filter).toList();

    int cmp(SecurityEvent a, SecurityEvent b) {
      switch (_sort) {
        case _EventSort.newestFirst:
          return b.at.compareTo(a.at);
        case _EventSort.oldestFirst:
          return a.at.compareTo(b.at);
        case _EventSort.portAsc:
          final byPort = a.port.compareTo(b.port);
          return byPort != 0 ? byPort : b.at.compareTo(a.at);
        case _EventSort.threatCodeAsc:
          final byCode = a.threatCode.compareTo(b.threatCode);
          return byCode != 0 ? byCode : b.at.compareTo(a.at);
        case _EventSort.threatNameAsc:
          final byName = a.threatName.compareTo(b.threatName);
          return byName != 0 ? byName : b.at.compareTo(a.at);
      }
    }

    list.sort(cmp);
    return list;
  }

  List<SecurityEvent> get _visible {
    final all = _filteredSorted;
    if (all.length <= _visibleLimit) {
      return all;
    }
    return all.take(_visibleLimit).toList(growable: false);
  }

  bool get _viewingFile => _loadedEvents != null;

  bool get _canShowMore => _filteredSorted.length > _visibleLimit;

  void _resetPaging() {
    _visibleLimit = DatabasePage.pageSize;
  }

  Future<void> _confirmClearAll() async {
    if (_viewingFile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Return to live database before clearing.'),
        ),
      );
      return;
    }
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
      final message = await saveEventExport(_source);
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

  Future<void> _loadDatabase() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      dialogTitle: 'Load security event database (CSV)',
    );
    if (file == null) {
      return;
    }
    final csv = await readPickedFileText(file);
    if (csv == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read selected file.')),
        );
      }
      return;
    }
    final parsed = eventsFromCsv(csv);
    setState(() {
      _loadedEvents = parsed;
      _loadedLabel = file.name;
      _resetPaging();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Loaded ${parsed.length} event${parsed.length == 1 ? '' : 's'} '
            'from ${file.name} (view only)',
          ),
        ),
      );
    }
  }

  void _returnToLive() {
    setState(() {
      _loadedEvents = null;
      _loadedLabel = null;
      _resetPaging();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSorted;
    final events = _visible;
    final total = _source.length;
    final filteredCount = filtered.length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Security event database',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _viewingFile
                              ? 'Viewing file “$_loadedLabel” — '
                                  'showing ${events.length} of $filteredCount'
                                  '${filteredCount != total ? ' (filtered from $total)' : ''}'
                              : 'Live local SQLite log — '
                                  'showing ${events.length} of $filteredCount'
                                  '${filteredCount != total ? ' (filtered from $total)' : ''}',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 13,
                            color: HubColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  MenuAnchor(
                    style: const MenuStyle(
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
                        ),
                      );
                    },
                    menuChildren: [
                      SubmenuButton(
                        style: const ButtonStyle(
                          foregroundColor: WidgetStatePropertyAll(
                            HubColors.text,
                          ),
                        ),
                        menuStyle: const MenuStyle(
                          backgroundColor: WidgetStatePropertyAll(
                            HubColors.surfaceRaised,
                          ),
                        ),
                        leadingIcon: const Icon(
                          Icons.storage_outlined,
                          size: 18,
                        ),
                        menuChildren: [
                          MenuItemButton(
                            onPressed: _loadDatabase,
                            leadingIcon: const Icon(
                              Icons.folder_open_outlined,
                              size: 18,
                            ),
                            child: const Text('Load database…'),
                          ),
                          MenuItemButton(
                            onPressed: total == 0 ? null : _exportDatabase,
                            leadingIcon: const Icon(
                              Icons.file_download_outlined,
                              size: 18,
                            ),
                            child: const Text('Export database'),
                          ),
                          MenuItemButton(
                            onPressed: (_viewingFile || total == 0)
                                ? null
                                : _confirmClearAll,
                            leadingIcon: Icon(
                              Icons.delete_sweep_outlined,
                              size: 18,
                              color: (_viewingFile || total == 0)
                                  ? HubColors.muted
                                  : HubColors.danger,
                            ),
                            child: Text(
                              'Clear database',
                              style: TextStyle(
                                color: (_viewingFile || total == 0)
                                    ? HubColors.muted
                                    : HubColors.danger,
                              ),
                            ),
                          ),
                        ],
                        child: const Text('Database'),
                      ),
                    ],
                  ),
                ],
              ),
              if (_viewingFile) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: HubColors.warn.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: HubColors.warn.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: HubColors.warn),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Offline file view — not writing to the live database.',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 13,
                            color: HubColors.text,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _returnToLive,
                        child: const Text('Return to live'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Filter',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      color: HubColors.muted,
                    ),
                  ),
                  SizedBox(
                    width: 180,
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
                          borderSide: const BorderSide(color: HubColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: HubColors.border),
                        ),
                      ),
                      dropdownMenuEntries: const [
                        DropdownMenuEntry(value: null, label: 'All ports'),
                        DropdownMenuEntry(value: 0, label: 'Port 1'),
                        DropdownMenuEntry(value: 1, label: 'Port 2'),
                        DropdownMenuEntry(value: 2, label: 'Port 3'),
                        DropdownMenuEntry(value: 3, label: 'Port 4'),
                      ],
                      onSelected: (value) {
                        setState(() {
                          _portFilter = value;
                          _resetPaging();
                        });
                      },
                    ),
                  ),
                  Text(
                    'Sort',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      color: HubColors.muted,
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: DropdownMenu<_EventSort>(
                      initialSelection: _sort,
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
                          borderSide: const BorderSide(color: HubColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: HubColors.border),
                        ),
                      ),
                      dropdownMenuEntries: [
                        for (final mode in _EventSort.values)
                          DropdownMenuEntry(value: mode, label: mode.label),
                      ],
                      onSelected: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _sort = value;
                          _resetPaging();
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: HubColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: HubColors.border),
                  ),
                  child: events.isEmpty
                      ? Center(
                          child: Text(
                            total == 0
                                ? 'No events in this database.'
                                : 'No events for this port filter.',
                            style: GoogleFonts.ibmPlexSans(
                              color: HubColors.muted,
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  // Fixed columns need ~520px; Message absorbs the rest
                                  // so the table can shrink with the window instead of
                                  // overflowing (DataTable does not flex columns).
                                  final messageWidth = (constraints.maxWidth -
                                          520)
                                      .clamp(140.0, 480.0);
                                  final narrow = constraints.maxWidth < 900;
                                  final table = DataTable(
                                    columnSpacing: narrow ? 16 : 24,
                                    horizontalMargin: narrow ? 12 : 16,
                                    headingRowColor:
                                        const WidgetStatePropertyAll(
                                      HubColors.surfaceRaised,
                                    ),
                                    dataTextStyle: GoogleFonts.ibmPlexSans(
                                      fontSize: 13,
                                      color: HubColors.text,
                                    ),
                                    headingTextStyle: GoogleFonts.ibmPlexMono(
                                      fontSize: 11,
                                      color: HubColors.muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    columns: const [
                                      DataColumn(label: Text('Time')),
                                      DataColumn(label: Text('Port')),
                                      DataColumn(label: Text('Threat')),
                                      DataColumn(label: Text('Code')),
                                      DataColumn(label: Text('State')),
                                      DataColumn(label: Text('Message')),
                                      DataColumn(label: Text('')),
                                    ],
                                    rows: [
                                      for (final event in events)
                                        DataRow(
                                          cells: [
                                            DataCell(
                                              Text(event.formattedAt),
                                            ),
                                            DataCell(
                                              Text('Port ${event.port + 1}'),
                                            ),
                                            DataCell(Text(event.threatName)),
                                            DataCell(
                                              Text('0x${event.threatCode}'),
                                            ),
                                            DataCell(Text(event.state.label)),
                                            DataCell(
                                              SizedBox(
                                                width: messageWidth,
                                                child: Text(
                                                  event.message,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              IconButton(
                                                tooltip: _viewingFile
                                                    ? 'Delete disabled for file view'
                                                    : 'Delete event',
                                                visualDensity:
                                                    VisualDensity.compact,
                                                onPressed: _viewingFile ||
                                                        event.id == null
                                                    ? null
                                                    : () =>
                                                        widget.onDeleteEvent(
                                                          event.id!,
                                                        ),
                                                icon: const Icon(
                                                  Icons.close,
                                                  size: 18,
                                                ),
                                                color: HubColors.muted,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  );

                                  // Vertical outside, horizontal inside: table may
                                  // grow past the viewport and scroll instead of
                                  // being force-fitted (which caused the overflow).
                                  return Scrollbar(
                                    controller: _verticalScroll,
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      controller: _verticalScroll,
                                      child: Scrollbar(
                                        controller: _horizontalScroll,
                                        thumbVisibility: true,
                                        notificationPredicate: (n) =>
                                            n.depth == 1,
                                        child: SingleChildScrollView(
                                          controller: _horizontalScroll,
                                          scrollDirection: Axis.horizontal,
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              minWidth: constraints.maxWidth,
                                            ),
                                            child: table,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (_canShowMore)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  12,
                                ),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: HubColors.border),
                                  ),
                                ),
                                child: Center(
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _visibleLimit += DatabasePage.pageSize;
                                      });
                                    },
                                    child: Text(
                                      'Show more '
                                      '(${filteredCount - events.length} remaining)',
                                      style: GoogleFonts.ibmPlexSans(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
