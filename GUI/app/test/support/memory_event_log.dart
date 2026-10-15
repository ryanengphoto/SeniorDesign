import 'package:drift/native.dart';
import 'package:hub_console/db/event_log_database.dart';
import 'package:hub_console/db/event_log_store.dart';

/// In-memory Drift store for VM tests (not used on Flutter web).
EventLogStore memoryEventLogStore() {
  return EventLogStore(database: EventLogDatabase.executor(NativeDatabase.memory()));
}
