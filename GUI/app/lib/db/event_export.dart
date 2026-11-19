import '../protocol.dart';
import 'event_export_save.dart';

/// Build a CSV dump of persisted security events (database export).
String eventsToCsv(List<SecurityEvent> events) {
  final buf = StringBuffer('id,at,port,threat_code,threat_name,state,message\n');
  for (final e in events) {
    buf.writeln(
      [
        e.id?.toString() ?? '',
        e.formattedAt,
        e.isSystem ? '0' : (e.port + 1).toString(),
        e.threatCode.toString(),
        _csv(e.threatName),
        _csv(e.state.wireName),
        _csv(e.message),
      ].join(','),
    );
  }
  return buf.toString();
}

String _csv(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

/// Parse CSV produced by [eventsToCsv] (or compatible). View-only load —
/// rows get null ids unless the CSV includes a numeric id column.
List<SecurityEvent> eventsFromCsv(String csv) {
  final lines = csv
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList(growable: false);
  if (lines.isEmpty) {
    return const [];
  }

  var start = 0;
  final header = lines.first.toLowerCase();
  if (header.contains('threat') || header.startsWith('id,')) {
    start = 1;
  }

  final out = <SecurityEvent>[];
  for (var i = start; i < lines.length; i++) {
    try {
      final cols = _parseCsvLine(lines[i]);
      if (cols.length < 6) {
        continue;
      }
      // id,at,port,threat_code,threat_name,state,message
      final hasId = cols.length >= 7;
      final idRaw = hasId ? cols[0] : '';
      final atRaw = hasId ? cols[1] : cols[0];
      final portRaw = hasId ? cols[2] : cols[1];
      final codeRaw = hasId ? cols[3] : cols[2];
      final name = hasId ? cols[4] : cols[3];
      final stateRaw = hasId ? cols[5] : cols[4];
      final message = hasId ? cols[6] : cols[5];

      final portDisplay = int.tryParse(portRaw.trim()) ?? 1;
      // CSV uses 1–4 for hub ports; 0 (or negative) means system/UART events.
      final port = portDisplay <= 0
          ? SecurityEvent.systemPort
          : (portDisplay - 1).clamp(0, 3);
      final threatCode = int.tryParse(codeRaw.trim()) ?? 0;
      final id = int.tryParse(idRaw.trim());
      final at = DateTime.tryParse(atRaw.trim().replaceFirst(' ', 'T')) ??
          DateTime.now();

      out.add(
        SecurityEvent(
          id: id,
          at: at,
          port: port,
          threatCode: threatCode,
          threatName: name.trim().isEmpty
              ? ThreatCode.nameFor(threatCode)
              : name.trim(),
          state: PortState.fromWireName(stateRaw.trim().replaceAll(' ', '_')),
          message: message,
        ),
      );
    } on Object {
      // Skip corrupt rows — never fail the whole import.
      continue;
    }
  }
  return out;
}

List<String> _parseCsvLine(String line) {
  final result = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        buf.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      result.add(buf.toString());
      buf.clear();
    } else {
      buf.write(c);
    }
  }
  result.add(buf.toString());
  return result;
}

/// Writes CSV to disk (desktop) or copies to clipboard (web). Returns a
/// short status string for a snackbar.
Future<String> saveEventExport(List<SecurityEvent> events) {
  return saveEventExportContents(eventsToCsv(events));
}
