import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:hub_console/db/event_log_database.dart';
import 'package:hub_console/db/event_log_store.dart';

/// In-memory Drift store for VM tests (not used on Flutter web).
EventLogStore memoryEventLogStore() {
  // Each test opens its own memory DB; suppress the multi-instance debug warning.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return EventLogStore(
    database: EventLogDatabase.executor(NativeDatabase.memory()),
  );
}
