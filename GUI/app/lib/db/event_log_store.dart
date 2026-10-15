import 'package:drift/drift.dart';

import '../protocol.dart';
import 'event_log_database.dart';

/// Persist / reload security events (last [maxEvents]).
class EventLogStore {
  EventLogStore({EventLogDatabase? database}) : _db = database;

  EventLogDatabase? _db;
  bool _opened = false;

  Future<void> open() async {
    if (_opened) {
      return;
    }
    _db ??= EventLogDatabase();
    _opened = true;
  }

  Future<List<SecurityEvent>> loadRecent(int limit) async {
    await open();
    final rows = await (_db!.select(_db!.securityEventRows)
          ..orderBy([(t) => OrderingTerm.desc(t.at)])
          ..limit(limit))
        .get();
    // Chronological for the UI ring (oldest → newest).
    return rows.reversed.map(_fromRow).toList(growable: false);
  }

  Future<void> append(SecurityEvent event) async {
    await open();
    await _db!.into(_db!.securityEventRows).insert(
          SecurityEventRowsCompanion.insert(
            at: event.at,
            port: event.port,
            threatCode: event.threatCode,
            threatName: event.threatName,
            state: event.state.wireName,
            message: event.message,
          ),
        );
  }

  /// Keep only the newest [max] rows.
  Future<void> trimTo(int max) async {
    await open();
    final newestFirst = await (_db!.select(_db!.securityEventRows)
          ..orderBy([(t) => OrderingTerm.desc(t.at)]))
        .get();
    if (newestFirst.length <= max) {
      return;
    }
    final ids = newestFirst.skip(max).map((r) => r.id).toList(growable: false);
    await (_db!.delete(_db!.securityEventRows)..where((t) => t.id.isIn(ids)))
        .go();
  }

  Future<void> close() async {
    if (!_opened || _db == null) {
      return;
    }
    await _db!.close();
    _db = null;
    _opened = false;
  }

  SecurityEvent _fromRow(SecurityEventRow row) {
    return SecurityEvent(
      at: row.at,
      port: row.port,
      threatCode: row.threatCode,
      threatName: row.threatName,
      state: PortState.fromWireName(row.state),
      message: row.message,
    );
  }
}
