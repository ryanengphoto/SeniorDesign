// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_log_database.dart';

// ignore_for_file: type=lint
class $SecurityEventRowsTable extends SecurityEventRows
    with TableInfo<$SecurityEventRowsTable, SecurityEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SecurityEventRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _portMeta = const VerificationMeta('port');
  @override
  late final GeneratedColumn<int> port = GeneratedColumn<int>(
    'port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _threatCodeMeta = const VerificationMeta(
    'threatCode',
  );
  @override
  late final GeneratedColumn<int> threatCode = GeneratedColumn<int>(
    'threat_code',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _threatNameMeta = const VerificationMeta(
    'threatName',
  );
  @override
  late final GeneratedColumn<String> threatName = GeneratedColumn<String>(
    'threat_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    at,
    port,
    threatCode,
    threatName,
    state,
    message,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'security_event_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<SecurityEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('port')) {
      context.handle(
        _portMeta,
        port.isAcceptableOrUnknown(data['port']!, _portMeta),
      );
    } else if (isInserting) {
      context.missing(_portMeta);
    }
    if (data.containsKey('threat_code')) {
      context.handle(
        _threatCodeMeta,
        threatCode.isAcceptableOrUnknown(data['threat_code']!, _threatCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_threatCodeMeta);
    }
    if (data.containsKey('threat_name')) {
      context.handle(
        _threatNameMeta,
        threatName.isAcceptableOrUnknown(data['threat_name']!, _threatNameMeta),
      );
    } else if (isInserting) {
      context.missing(_threatNameMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SecurityEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SecurityEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
      port: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}port'],
      )!,
      threatCode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}threat_code'],
      )!,
      threatName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}threat_name'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      )!,
    );
  }

  @override
  $SecurityEventRowsTable createAlias(String alias) {
    return $SecurityEventRowsTable(attachedDatabase, alias);
  }
}

class SecurityEventRow extends DataClass
    implements Insertable<SecurityEventRow> {
  final int id;
  final DateTime at;
  final int port;
  final int threatCode;
  final String threatName;
  final String state;
  final String message;
  const SecurityEventRow({
    required this.id,
    required this.at,
    required this.port,
    required this.threatCode,
    required this.threatName,
    required this.state,
    required this.message,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['at'] = Variable<DateTime>(at);
    map['port'] = Variable<int>(port);
    map['threat_code'] = Variable<int>(threatCode);
    map['threat_name'] = Variable<String>(threatName);
    map['state'] = Variable<String>(state);
    map['message'] = Variable<String>(message);
    return map;
  }

  SecurityEventRowsCompanion toCompanion(bool nullToAbsent) {
    return SecurityEventRowsCompanion(
      id: Value(id),
      at: Value(at),
      port: Value(port),
      threatCode: Value(threatCode),
      threatName: Value(threatName),
      state: Value(state),
      message: Value(message),
    );
  }

  factory SecurityEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SecurityEventRow(
      id: serializer.fromJson<int>(json['id']),
      at: serializer.fromJson<DateTime>(json['at']),
      port: serializer.fromJson<int>(json['port']),
      threatCode: serializer.fromJson<int>(json['threatCode']),
      threatName: serializer.fromJson<String>(json['threatName']),
      state: serializer.fromJson<String>(json['state']),
      message: serializer.fromJson<String>(json['message']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'at': serializer.toJson<DateTime>(at),
      'port': serializer.toJson<int>(port),
      'threatCode': serializer.toJson<int>(threatCode),
      'threatName': serializer.toJson<String>(threatName),
      'state': serializer.toJson<String>(state),
      'message': serializer.toJson<String>(message),
    };
  }

  SecurityEventRow copyWith({
    int? id,
    DateTime? at,
    int? port,
    int? threatCode,
    String? threatName,
    String? state,
    String? message,
  }) => SecurityEventRow(
    id: id ?? this.id,
    at: at ?? this.at,
    port: port ?? this.port,
    threatCode: threatCode ?? this.threatCode,
    threatName: threatName ?? this.threatName,
    state: state ?? this.state,
    message: message ?? this.message,
  );
  SecurityEventRow copyWithCompanion(SecurityEventRowsCompanion data) {
    return SecurityEventRow(
      id: data.id.present ? data.id.value : this.id,
      at: data.at.present ? data.at.value : this.at,
      port: data.port.present ? data.port.value : this.port,
      threatCode: data.threatCode.present
          ? data.threatCode.value
          : this.threatCode,
      threatName: data.threatName.present
          ? data.threatName.value
          : this.threatName,
      state: data.state.present ? data.state.value : this.state,
      message: data.message.present ? data.message.value : this.message,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SecurityEventRow(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('port: $port, ')
          ..write('threatCode: $threatCode, ')
          ..write('threatName: $threatName, ')
          ..write('state: $state, ')
          ..write('message: $message')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, at, port, threatCode, threatName, state, message);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SecurityEventRow &&
          other.id == this.id &&
          other.at == this.at &&
          other.port == this.port &&
          other.threatCode == this.threatCode &&
          other.threatName == this.threatName &&
          other.state == this.state &&
          other.message == this.message);
}

class SecurityEventRowsCompanion extends UpdateCompanion<SecurityEventRow> {
  final Value<int> id;
  final Value<DateTime> at;
  final Value<int> port;
  final Value<int> threatCode;
  final Value<String> threatName;
  final Value<String> state;
  final Value<String> message;
  const SecurityEventRowsCompanion({
    this.id = const Value.absent(),
    this.at = const Value.absent(),
    this.port = const Value.absent(),
    this.threatCode = const Value.absent(),
    this.threatName = const Value.absent(),
    this.state = const Value.absent(),
    this.message = const Value.absent(),
  });
  SecurityEventRowsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime at,
    required int port,
    required int threatCode,
    required String threatName,
    required String state,
    required String message,
  }) : at = Value(at),
       port = Value(port),
       threatCode = Value(threatCode),
       threatName = Value(threatName),
       state = Value(state),
       message = Value(message);
  static Insertable<SecurityEventRow> custom({
    Expression<int>? id,
    Expression<DateTime>? at,
    Expression<int>? port,
    Expression<int>? threatCode,
    Expression<String>? threatName,
    Expression<String>? state,
    Expression<String>? message,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (at != null) 'at': at,
      if (port != null) 'port': port,
      if (threatCode != null) 'threat_code': threatCode,
      if (threatName != null) 'threat_name': threatName,
      if (state != null) 'state': state,
      if (message != null) 'message': message,
    });
  }

  SecurityEventRowsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? at,
    Value<int>? port,
    Value<int>? threatCode,
    Value<String>? threatName,
    Value<String>? state,
    Value<String>? message,
  }) {
    return SecurityEventRowsCompanion(
      id: id ?? this.id,
      at: at ?? this.at,
      port: port ?? this.port,
      threatCode: threatCode ?? this.threatCode,
      threatName: threatName ?? this.threatName,
      state: state ?? this.state,
      message: message ?? this.message,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (port.present) {
      map['port'] = Variable<int>(port.value);
    }
    if (threatCode.present) {
      map['threat_code'] = Variable<int>(threatCode.value);
    }
    if (threatName.present) {
      map['threat_name'] = Variable<String>(threatName.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SecurityEventRowsCompanion(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('port: $port, ')
          ..write('threatCode: $threatCode, ')
          ..write('threatName: $threatName, ')
          ..write('state: $state, ')
          ..write('message: $message')
          ..write(')'))
        .toString();
  }
}

abstract class _$EventLogDatabase extends GeneratedDatabase {
  _$EventLogDatabase(QueryExecutor e) : super(e);
  $EventLogDatabaseManager get managers => $EventLogDatabaseManager(this);
  late final $SecurityEventRowsTable securityEventRows =
      $SecurityEventRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [securityEventRows];
}

typedef $$SecurityEventRowsTableCreateCompanionBuilder =
    SecurityEventRowsCompanion Function({
      Value<int> id,
      required DateTime at,
      required int port,
      required int threatCode,
      required String threatName,
      required String state,
      required String message,
    });
typedef $$SecurityEventRowsTableUpdateCompanionBuilder =
    SecurityEventRowsCompanion Function({
      Value<int> id,
      Value<DateTime> at,
      Value<int> port,
      Value<int> threatCode,
      Value<String> threatName,
      Value<String> state,
      Value<String> message,
    });

class $$SecurityEventRowsTableFilterComposer
    extends Composer<_$EventLogDatabase, $SecurityEventRowsTable> {
  $$SecurityEventRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get threatCode => $composableBuilder(
    column: $table.threatCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get threatName => $composableBuilder(
    column: $table.threatName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SecurityEventRowsTableOrderingComposer
    extends Composer<_$EventLogDatabase, $SecurityEventRowsTable> {
  $$SecurityEventRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get threatCode => $composableBuilder(
    column: $table.threatCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get threatName => $composableBuilder(
    column: $table.threatName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SecurityEventRowsTableAnnotationComposer
    extends Composer<_$EventLogDatabase, $SecurityEventRowsTable> {
  $$SecurityEventRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<int> get port =>
      $composableBuilder(column: $table.port, builder: (column) => column);

  GeneratedColumn<int> get threatCode => $composableBuilder(
    column: $table.threatCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get threatName => $composableBuilder(
    column: $table.threatName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);
}

class $$SecurityEventRowsTableTableManager
    extends
        RootTableManager<
          _$EventLogDatabase,
          $SecurityEventRowsTable,
          SecurityEventRow,
          $$SecurityEventRowsTableFilterComposer,
          $$SecurityEventRowsTableOrderingComposer,
          $$SecurityEventRowsTableAnnotationComposer,
          $$SecurityEventRowsTableCreateCompanionBuilder,
          $$SecurityEventRowsTableUpdateCompanionBuilder,
          (
            SecurityEventRow,
            BaseReferences<
              _$EventLogDatabase,
              $SecurityEventRowsTable,
              SecurityEventRow
            >,
          ),
          SecurityEventRow,
          PrefetchHooks Function()
        > {
  $$SecurityEventRowsTableTableManager(
    _$EventLogDatabase db,
    $SecurityEventRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SecurityEventRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SecurityEventRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SecurityEventRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<int> port = const Value.absent(),
                Value<int> threatCode = const Value.absent(),
                Value<String> threatName = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String> message = const Value.absent(),
              }) => SecurityEventRowsCompanion(
                id: id,
                at: at,
                port: port,
                threatCode: threatCode,
                threatName: threatName,
                state: state,
                message: message,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime at,
                required int port,
                required int threatCode,
                required String threatName,
                required String state,
                required String message,
              }) => SecurityEventRowsCompanion.insert(
                id: id,
                at: at,
                port: port,
                threatCode: threatCode,
                threatName: threatName,
                state: state,
                message: message,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SecurityEventRowsTable, SecurityEventRow>(table),
                  BaseReferences<
                    _$EventLogDatabase,
                    $SecurityEventRowsTable,
                    SecurityEventRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SecurityEventRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$EventLogDatabase,
      $SecurityEventRowsTable,
      SecurityEventRow,
      $$SecurityEventRowsTableFilterComposer,
      $$SecurityEventRowsTableOrderingComposer,
      $$SecurityEventRowsTableAnnotationComposer,
      $$SecurityEventRowsTableCreateCompanionBuilder,
      $$SecurityEventRowsTableUpdateCompanionBuilder,
      (
        SecurityEventRow,
        BaseReferences<
          _$EventLogDatabase,
          $SecurityEventRowsTable,
          SecurityEventRow
        >,
      ),
      SecurityEventRow,
      PrefetchHooks Function()
    >;

class $EventLogDatabaseManager {
  final _$EventLogDatabase _db;
  $EventLogDatabaseManager(this._db);
  $$SecurityEventRowsTableTableManager get securityEventRows =>
      $$SecurityEventRowsTableTableManager(_db, _db.securityEventRows);
}
