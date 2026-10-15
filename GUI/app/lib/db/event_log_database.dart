import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'event_log_database.g.dart';

/// Persisted security events (wall-clock time, not session ms).
class SecurityEventRows extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get at => dateTime()();
  IntColumn get port => integer()();
  IntColumn get threatCode => integer()();
  TextColumn get threatName => text()();
  TextColumn get state => text()();
  TextColumn get message => text()();
}

@DriftDatabase(tables: [SecurityEventRows])
class EventLogDatabase extends _$EventLogDatabase {
  EventLogDatabase() : super(_openExecutor());

  /// Injectable executor (e.g. in-memory for VM tests).
  EventLogDatabase.executor(super.executor);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openExecutor() {
    return driftDatabase(name: 'hub_security_events');
  }
}
