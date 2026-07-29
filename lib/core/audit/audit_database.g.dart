// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_database.dart';

// ignore_for_file: type=lint
class $AuditSessionsTable extends AuditSessions
    with TableInfo<$AuditSessionsTable, AuditSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditSessionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<String> startedAt = GeneratedColumn<String>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _appVersionMeta = const VerificationMeta(
    'appVersion',
  );
  @override
  late final GeneratedColumn<String> appVersion = GeneratedColumn<String>(
    'app_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sshUserMeta = const VerificationMeta(
    'sshUser',
  );
  @override
  late final GeneratedColumn<String> sshUser = GeneratedColumn<String>(
    'ssh_user',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authMethodMeta = const VerificationMeta(
    'authMethod',
  );
  @override
  late final GeneratedColumn<String> authMethod = GeneratedColumn<String>(
    'auth_method',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    appVersion,
    profileId,
    host,
    sshUser,
    authMethod,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<AuditSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('app_version')) {
      context.handle(
        _appVersionMeta,
        appVersion.isAcceptableOrUnknown(data['app_version']!, _appVersionMeta),
      );
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    }
    if (data.containsKey('host')) {
      context.handle(
        _hostMeta,
        host.isAcceptableOrUnknown(data['host']!, _hostMeta),
      );
    }
    if (data.containsKey('ssh_user')) {
      context.handle(
        _sshUserMeta,
        sshUser.isAcceptableOrUnknown(data['ssh_user']!, _sshUserMeta),
      );
    }
    if (data.containsKey('auth_method')) {
      context.handle(
        _authMethodMeta,
        authMethod.isAcceptableOrUnknown(data['auth_method']!, _authMethodMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}started_at'],
      )!,
      appVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}app_version'],
      ),
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      ),
      host: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host'],
      ),
      sshUser: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ssh_user'],
      ),
      authMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}auth_method'],
      ),
    );
  }

  @override
  $AuditSessionsTable createAlias(String alias) {
    return $AuditSessionsTable(attachedDatabase, alias);
  }
}

class AuditSession extends DataClass implements Insertable<AuditSession> {
  final int id;

  /// RFC-3339 UTC.
  final String startedAt;
  final String? appVersion;
  final String? profileId;
  final String? host;
  final String? sshUser;

  /// `key` | `password`.
  final String? authMethod;
  const AuditSession({
    required this.id,
    required this.startedAt,
    this.appVersion,
    this.profileId,
    this.host,
    this.sshUser,
    this.authMethod,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['started_at'] = Variable<String>(startedAt);
    if (!nullToAbsent || appVersion != null) {
      map['app_version'] = Variable<String>(appVersion);
    }
    if (!nullToAbsent || profileId != null) {
      map['profile_id'] = Variable<String>(profileId);
    }
    if (!nullToAbsent || host != null) {
      map['host'] = Variable<String>(host);
    }
    if (!nullToAbsent || sshUser != null) {
      map['ssh_user'] = Variable<String>(sshUser);
    }
    if (!nullToAbsent || authMethod != null) {
      map['auth_method'] = Variable<String>(authMethod);
    }
    return map;
  }

  AuditSessionsCompanion toCompanion(bool nullToAbsent) {
    return AuditSessionsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      appVersion: appVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(appVersion),
      profileId: profileId == null && nullToAbsent
          ? const Value.absent()
          : Value(profileId),
      host: host == null && nullToAbsent ? const Value.absent() : Value(host),
      sshUser: sshUser == null && nullToAbsent
          ? const Value.absent()
          : Value(sshUser),
      authMethod: authMethod == null && nullToAbsent
          ? const Value.absent()
          : Value(authMethod),
    );
  }

  factory AuditSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditSession(
      id: serializer.fromJson<int>(json['id']),
      startedAt: serializer.fromJson<String>(json['startedAt']),
      appVersion: serializer.fromJson<String?>(json['appVersion']),
      profileId: serializer.fromJson<String?>(json['profileId']),
      host: serializer.fromJson<String?>(json['host']),
      sshUser: serializer.fromJson<String?>(json['sshUser']),
      authMethod: serializer.fromJson<String?>(json['authMethod']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'startedAt': serializer.toJson<String>(startedAt),
      'appVersion': serializer.toJson<String?>(appVersion),
      'profileId': serializer.toJson<String?>(profileId),
      'host': serializer.toJson<String?>(host),
      'sshUser': serializer.toJson<String?>(sshUser),
      'authMethod': serializer.toJson<String?>(authMethod),
    };
  }

  AuditSession copyWith({
    int? id,
    String? startedAt,
    Value<String?> appVersion = const Value.absent(),
    Value<String?> profileId = const Value.absent(),
    Value<String?> host = const Value.absent(),
    Value<String?> sshUser = const Value.absent(),
    Value<String?> authMethod = const Value.absent(),
  }) => AuditSession(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    appVersion: appVersion.present ? appVersion.value : this.appVersion,
    profileId: profileId.present ? profileId.value : this.profileId,
    host: host.present ? host.value : this.host,
    sshUser: sshUser.present ? sshUser.value : this.sshUser,
    authMethod: authMethod.present ? authMethod.value : this.authMethod,
  );
  AuditSession copyWithCompanion(AuditSessionsCompanion data) {
    return AuditSession(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      appVersion: data.appVersion.present
          ? data.appVersion.value
          : this.appVersion,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      host: data.host.present ? data.host.value : this.host,
      sshUser: data.sshUser.present ? data.sshUser.value : this.sshUser,
      authMethod: data.authMethod.present
          ? data.authMethod.value
          : this.authMethod,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditSession(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('appVersion: $appVersion, ')
          ..write('profileId: $profileId, ')
          ..write('host: $host, ')
          ..write('sshUser: $sshUser, ')
          ..write('authMethod: $authMethod')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    startedAt,
    appVersion,
    profileId,
    host,
    sshUser,
    authMethod,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditSession &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.appVersion == this.appVersion &&
          other.profileId == this.profileId &&
          other.host == this.host &&
          other.sshUser == this.sshUser &&
          other.authMethod == this.authMethod);
}

class AuditSessionsCompanion extends UpdateCompanion<AuditSession> {
  final Value<int> id;
  final Value<String> startedAt;
  final Value<String?> appVersion;
  final Value<String?> profileId;
  final Value<String?> host;
  final Value<String?> sshUser;
  final Value<String?> authMethod;
  const AuditSessionsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.appVersion = const Value.absent(),
    this.profileId = const Value.absent(),
    this.host = const Value.absent(),
    this.sshUser = const Value.absent(),
    this.authMethod = const Value.absent(),
  });
  AuditSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String startedAt,
    this.appVersion = const Value.absent(),
    this.profileId = const Value.absent(),
    this.host = const Value.absent(),
    this.sshUser = const Value.absent(),
    this.authMethod = const Value.absent(),
  }) : startedAt = Value(startedAt);
  static Insertable<AuditSession> custom({
    Expression<int>? id,
    Expression<String>? startedAt,
    Expression<String>? appVersion,
    Expression<String>? profileId,
    Expression<String>? host,
    Expression<String>? sshUser,
    Expression<String>? authMethod,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (appVersion != null) 'app_version': appVersion,
      if (profileId != null) 'profile_id': profileId,
      if (host != null) 'host': host,
      if (sshUser != null) 'ssh_user': sshUser,
      if (authMethod != null) 'auth_method': authMethod,
    });
  }

  AuditSessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? startedAt,
    Value<String?>? appVersion,
    Value<String?>? profileId,
    Value<String?>? host,
    Value<String?>? sshUser,
    Value<String?>? authMethod,
  }) {
    return AuditSessionsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      appVersion: appVersion ?? this.appVersion,
      profileId: profileId ?? this.profileId,
      host: host ?? this.host,
      sshUser: sshUser ?? this.sshUser,
      authMethod: authMethod ?? this.authMethod,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<String>(startedAt.value);
    }
    if (appVersion.present) {
      map['app_version'] = Variable<String>(appVersion.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (sshUser.present) {
      map['ssh_user'] = Variable<String>(sshUser.value);
    }
    if (authMethod.present) {
      map['auth_method'] = Variable<String>(authMethod.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditSessionsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('appVersion: $appVersion, ')
          ..write('profileId: $profileId, ')
          ..write('host: $host, ')
          ..write('sshUser: $sshUser, ')
          ..write('authMethod: $authMethod')
          ..write(')'))
        .toString();
  }
}

class $AuditEventsTable extends AuditEvents
    with TableInfo<$AuditEventsTable, AuditEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditEventsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id)',
    ),
  );
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<String> ts = GeneratedColumn<String>(
    'ts',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailJsonMeta = const VerificationMeta(
    'detailJson',
  );
  @override
  late final GeneratedColumn<String> detailJson = GeneratedColumn<String>(
    'detail_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _okMeta = const VerificationMeta('ok');
  @override
  late final GeneratedColumn<int> ok = GeneratedColumn<int>(
    'ok',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    ts,
    kind,
    state,
    detailJson,
    ok,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(
    Insertable<AuditEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('detail_json')) {
      context.handle(
        _detailJsonMeta,
        detailJson.isAcceptableOrUnknown(data['detail_json']!, _detailJsonMeta),
      );
    }
    if (data.containsKey('ok')) {
      context.handle(_okMeta, ok.isAcceptableOrUnknown(data['ok']!, _okMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      ),
      ts: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ts'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      ),
      detailJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail_json'],
      ),
      ok: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ok'],
      ),
    );
  }

  @override
  $AuditEventsTable createAlias(String alias) {
    return $AuditEventsTable(attachedDatabase, alias);
  }
}

class AuditEvent extends DataClass implements Insertable<AuditEvent> {
  final int id;
  final int? sessionId;
  final String ts;

  /// `app_start`, `connect`, `disconnect`, `discover`, `discover_confirmed`,
  /// `key_auth_setup`, `push_begin`, `push_done`, `pull_begin`, `pull_done`,
  /// `restore_begin`, `restore_done`, `state_enter`, `error`, `audit_cleared`.
  final String kind;

  /// The envelope state, when [kind] is `state_enter`.
  final String? state;

  /// Structured payload, stored as a JSON string.
  final String? detailJson;

  /// 1 success / 0 failure / NULL not applicable.
  final int? ok;
  const AuditEvent({
    required this.id,
    this.sessionId,
    required this.ts,
    required this.kind,
    this.state,
    this.detailJson,
    this.ok,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<int>(sessionId);
    }
    map['ts'] = Variable<String>(ts);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || state != null) {
      map['state'] = Variable<String>(state);
    }
    if (!nullToAbsent || detailJson != null) {
      map['detail_json'] = Variable<String>(detailJson);
    }
    if (!nullToAbsent || ok != null) {
      map['ok'] = Variable<int>(ok);
    }
    return map;
  }

  AuditEventsCompanion toCompanion(bool nullToAbsent) {
    return AuditEventsCompanion(
      id: Value(id),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      ts: Value(ts),
      kind: Value(kind),
      state: state == null && nullToAbsent
          ? const Value.absent()
          : Value(state),
      detailJson: detailJson == null && nullToAbsent
          ? const Value.absent()
          : Value(detailJson),
      ok: ok == null && nullToAbsent ? const Value.absent() : Value(ok),
    );
  }

  factory AuditEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditEvent(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int?>(json['sessionId']),
      ts: serializer.fromJson<String>(json['ts']),
      kind: serializer.fromJson<String>(json['kind']),
      state: serializer.fromJson<String?>(json['state']),
      detailJson: serializer.fromJson<String?>(json['detailJson']),
      ok: serializer.fromJson<int?>(json['ok']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int?>(sessionId),
      'ts': serializer.toJson<String>(ts),
      'kind': serializer.toJson<String>(kind),
      'state': serializer.toJson<String?>(state),
      'detailJson': serializer.toJson<String?>(detailJson),
      'ok': serializer.toJson<int?>(ok),
    };
  }

  AuditEvent copyWith({
    int? id,
    Value<int?> sessionId = const Value.absent(),
    String? ts,
    String? kind,
    Value<String?> state = const Value.absent(),
    Value<String?> detailJson = const Value.absent(),
    Value<int?> ok = const Value.absent(),
  }) => AuditEvent(
    id: id ?? this.id,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    ts: ts ?? this.ts,
    kind: kind ?? this.kind,
    state: state.present ? state.value : this.state,
    detailJson: detailJson.present ? detailJson.value : this.detailJson,
    ok: ok.present ? ok.value : this.ok,
  );
  AuditEvent copyWithCompanion(AuditEventsCompanion data) {
    return AuditEvent(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      ts: data.ts.present ? data.ts.value : this.ts,
      kind: data.kind.present ? data.kind.value : this.kind,
      state: data.state.present ? data.state.value : this.state,
      detailJson: data.detailJson.present
          ? data.detailJson.value
          : this.detailJson,
      ok: data.ok.present ? data.ok.value : this.ok,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditEvent(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('ts: $ts, ')
          ..write('kind: $kind, ')
          ..write('state: $state, ')
          ..write('detailJson: $detailJson, ')
          ..write('ok: $ok')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sessionId, ts, kind, state, detailJson, ok);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditEvent &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.ts == this.ts &&
          other.kind == this.kind &&
          other.state == this.state &&
          other.detailJson == this.detailJson &&
          other.ok == this.ok);
}

class AuditEventsCompanion extends UpdateCompanion<AuditEvent> {
  final Value<int> id;
  final Value<int?> sessionId;
  final Value<String> ts;
  final Value<String> kind;
  final Value<String?> state;
  final Value<String?> detailJson;
  final Value<int?> ok;
  const AuditEventsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.ts = const Value.absent(),
    this.kind = const Value.absent(),
    this.state = const Value.absent(),
    this.detailJson = const Value.absent(),
    this.ok = const Value.absent(),
  });
  AuditEventsCompanion.insert({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    required String ts,
    required String kind,
    this.state = const Value.absent(),
    this.detailJson = const Value.absent(),
    this.ok = const Value.absent(),
  }) : ts = Value(ts),
       kind = Value(kind);
  static Insertable<AuditEvent> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<String>? ts,
    Expression<String>? kind,
    Expression<String>? state,
    Expression<String>? detailJson,
    Expression<int>? ok,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (ts != null) 'ts': ts,
      if (kind != null) 'kind': kind,
      if (state != null) 'state': state,
      if (detailJson != null) 'detail_json': detailJson,
      if (ok != null) 'ok': ok,
    });
  }

  AuditEventsCompanion copyWith({
    Value<int>? id,
    Value<int?>? sessionId,
    Value<String>? ts,
    Value<String>? kind,
    Value<String?>? state,
    Value<String?>? detailJson,
    Value<int?>? ok,
  }) {
    return AuditEventsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      ts: ts ?? this.ts,
      kind: kind ?? this.kind,
      state: state ?? this.state,
      detailJson: detailJson ?? this.detailJson,
      ok: ok ?? this.ok,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (ts.present) {
      map['ts'] = Variable<String>(ts.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (detailJson.present) {
      map['detail_json'] = Variable<String>(detailJson.value);
    }
    if (ok.present) {
      map['ok'] = Variable<int>(ok.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditEventsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('ts: $ts, ')
          ..write('kind: $kind, ')
          ..write('state: $state, ')
          ..write('detailJson: $detailJson, ')
          ..write('ok: $ok')
          ..write(')'))
        .toString();
  }
}

class $AuditFileOpsTable extends AuditFileOps
    with TableInfo<$AuditFileOpsTable, AuditFileOp> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditFileOpsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<int> eventId = GeneratedColumn<int>(
    'event_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES events (id)',
    ),
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _srcMeta = const VerificationMeta('src');
  @override
  late final GeneratedColumn<String> src = GeneratedColumn<String>(
    'src',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dstMeta = const VerificationMeta('dst');
  @override
  late final GeneratedColumn<String> dst = GeneratedColumn<String>(
    'dst',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<int> slot = GeneratedColumn<int>(
    'slot',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventId,
    op,
    src,
    dst,
    bytes,
    slot,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'file_ops';
  @override
  VerificationContext validateIntegrity(
    Insertable<AuditFileOp> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    }
    if (data.containsKey('src')) {
      context.handle(
        _srcMeta,
        src.isAcceptableOrUnknown(data['src']!, _srcMeta),
      );
    }
    if (data.containsKey('dst')) {
      context.handle(
        _dstMeta,
        dst.isAcceptableOrUnknown(data['dst']!, _dstMeta),
      );
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    }
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditFileOp map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditFileOp(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}event_id'],
      ),
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      ),
      src: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}src'],
      ),
      dst: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dst'],
      ),
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      ),
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}slot'],
      ),
    );
  }

  @override
  $AuditFileOpsTable createAlias(String alias) {
    return $AuditFileOpsTable(attachedDatabase, alias);
  }
}

class AuditFileOp extends DataClass implements Insertable<AuditFileOp> {
  final int id;
  final int? eventId;

  /// `upload`, `download`, `backup`, `copy`, `chown`, `delete`.
  final String? op;
  final String? src;
  final String? dst;
  final int? bytes;
  final int? slot;
  const AuditFileOp({
    required this.id,
    this.eventId,
    this.op,
    this.src,
    this.dst,
    this.bytes,
    this.slot,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || eventId != null) {
      map['event_id'] = Variable<int>(eventId);
    }
    if (!nullToAbsent || op != null) {
      map['op'] = Variable<String>(op);
    }
    if (!nullToAbsent || src != null) {
      map['src'] = Variable<String>(src);
    }
    if (!nullToAbsent || dst != null) {
      map['dst'] = Variable<String>(dst);
    }
    if (!nullToAbsent || bytes != null) {
      map['bytes'] = Variable<int>(bytes);
    }
    if (!nullToAbsent || slot != null) {
      map['slot'] = Variable<int>(slot);
    }
    return map;
  }

  AuditFileOpsCompanion toCompanion(bool nullToAbsent) {
    return AuditFileOpsCompanion(
      id: Value(id),
      eventId: eventId == null && nullToAbsent
          ? const Value.absent()
          : Value(eventId),
      op: op == null && nullToAbsent ? const Value.absent() : Value(op),
      src: src == null && nullToAbsent ? const Value.absent() : Value(src),
      dst: dst == null && nullToAbsent ? const Value.absent() : Value(dst),
      bytes: bytes == null && nullToAbsent
          ? const Value.absent()
          : Value(bytes),
      slot: slot == null && nullToAbsent ? const Value.absent() : Value(slot),
    );
  }

  factory AuditFileOp.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditFileOp(
      id: serializer.fromJson<int>(json['id']),
      eventId: serializer.fromJson<int?>(json['eventId']),
      op: serializer.fromJson<String?>(json['op']),
      src: serializer.fromJson<String?>(json['src']),
      dst: serializer.fromJson<String?>(json['dst']),
      bytes: serializer.fromJson<int?>(json['bytes']),
      slot: serializer.fromJson<int?>(json['slot']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'eventId': serializer.toJson<int?>(eventId),
      'op': serializer.toJson<String?>(op),
      'src': serializer.toJson<String?>(src),
      'dst': serializer.toJson<String?>(dst),
      'bytes': serializer.toJson<int?>(bytes),
      'slot': serializer.toJson<int?>(slot),
    };
  }

  AuditFileOp copyWith({
    int? id,
    Value<int?> eventId = const Value.absent(),
    Value<String?> op = const Value.absent(),
    Value<String?> src = const Value.absent(),
    Value<String?> dst = const Value.absent(),
    Value<int?> bytes = const Value.absent(),
    Value<int?> slot = const Value.absent(),
  }) => AuditFileOp(
    id: id ?? this.id,
    eventId: eventId.present ? eventId.value : this.eventId,
    op: op.present ? op.value : this.op,
    src: src.present ? src.value : this.src,
    dst: dst.present ? dst.value : this.dst,
    bytes: bytes.present ? bytes.value : this.bytes,
    slot: slot.present ? slot.value : this.slot,
  );
  AuditFileOp copyWithCompanion(AuditFileOpsCompanion data) {
    return AuditFileOp(
      id: data.id.present ? data.id.value : this.id,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      op: data.op.present ? data.op.value : this.op,
      src: data.src.present ? data.src.value : this.src,
      dst: data.dst.present ? data.dst.value : this.dst,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      slot: data.slot.present ? data.slot.value : this.slot,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditFileOp(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('op: $op, ')
          ..write('src: $src, ')
          ..write('dst: $dst, ')
          ..write('bytes: $bytes, ')
          ..write('slot: $slot')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, eventId, op, src, dst, bytes, slot);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditFileOp &&
          other.id == this.id &&
          other.eventId == this.eventId &&
          other.op == this.op &&
          other.src == this.src &&
          other.dst == this.dst &&
          other.bytes == this.bytes &&
          other.slot == this.slot);
}

class AuditFileOpsCompanion extends UpdateCompanion<AuditFileOp> {
  final Value<int> id;
  final Value<int?> eventId;
  final Value<String?> op;
  final Value<String?> src;
  final Value<String?> dst;
  final Value<int?> bytes;
  final Value<int?> slot;
  const AuditFileOpsCompanion({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.op = const Value.absent(),
    this.src = const Value.absent(),
    this.dst = const Value.absent(),
    this.bytes = const Value.absent(),
    this.slot = const Value.absent(),
  });
  AuditFileOpsCompanion.insert({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.op = const Value.absent(),
    this.src = const Value.absent(),
    this.dst = const Value.absent(),
    this.bytes = const Value.absent(),
    this.slot = const Value.absent(),
  });
  static Insertable<AuditFileOp> custom({
    Expression<int>? id,
    Expression<int>? eventId,
    Expression<String>? op,
    Expression<String>? src,
    Expression<String>? dst,
    Expression<int>? bytes,
    Expression<int>? slot,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (op != null) 'op': op,
      if (src != null) 'src': src,
      if (dst != null) 'dst': dst,
      if (bytes != null) 'bytes': bytes,
      if (slot != null) 'slot': slot,
    });
  }

  AuditFileOpsCompanion copyWith({
    Value<int>? id,
    Value<int?>? eventId,
    Value<String?>? op,
    Value<String?>? src,
    Value<String?>? dst,
    Value<int?>? bytes,
    Value<int?>? slot,
  }) {
    return AuditFileOpsCompanion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      op: op ?? this.op,
      src: src ?? this.src,
      dst: dst ?? this.dst,
      bytes: bytes ?? this.bytes,
      slot: slot ?? this.slot,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<int>(eventId.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (src.present) {
      map['src'] = Variable<String>(src.value);
    }
    if (dst.present) {
      map['dst'] = Variable<String>(dst.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (slot.present) {
      map['slot'] = Variable<int>(slot.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditFileOpsCompanion(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('op: $op, ')
          ..write('src: $src, ')
          ..write('dst: $dst, ')
          ..write('bytes: $bytes, ')
          ..write('slot: $slot')
          ..write(')'))
        .toString();
  }
}

class $AuditBackupsTable extends AuditBackups
    with TableInfo<$AuditBackupsTable, AuditBackup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditBackupsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id)',
    ),
  );
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<String> ts = GeneratedColumn<String>(
    'ts',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<int> slot = GeneratedColumn<int>(
    'slot',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lxcPathMeta = const VerificationMeta(
    'lxcPath',
  );
  @override
  late final GeneratedColumn<String> lxcPath = GeneratedColumn<String>(
    'lxc_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gameIdBeforeMeta = const VerificationMeta(
    'gameIdBefore',
  );
  @override
  late final GeneratedColumn<String> gameIdBefore = GeneratedColumn<String>(
    'game_id_before',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    ts,
    slot,
    lxcPath,
    bytes,
    gameIdBefore,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'backups';
  @override
  VerificationContext validateIntegrity(
    Insertable<AuditBackup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    }
    if (data.containsKey('lxc_path')) {
      context.handle(
        _lxcPathMeta,
        lxcPath.isAcceptableOrUnknown(data['lxc_path']!, _lxcPathMeta),
      );
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    }
    if (data.containsKey('game_id_before')) {
      context.handle(
        _gameIdBeforeMeta,
        gameIdBefore.isAcceptableOrUnknown(
          data['game_id_before']!,
          _gameIdBeforeMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditBackup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditBackup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      ),
      ts: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ts'],
      )!,
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}slot'],
      ),
      lxcPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lxc_path'],
      ),
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      ),
      gameIdBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_id_before'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $AuditBackupsTable createAlias(String alias) {
    return $AuditBackupsTable(attachedDatabase, alias);
  }
}

class AuditBackup extends DataClass implements Insertable<AuditBackup> {
  final int id;
  final int? sessionId;
  final String ts;
  final int? slot;

  /// Remote path of the dated backup directory. Historical column name — see the class
  /// doc; the value is just a remote path, LXC or otherwise.
  final String? lxcPath;
  final int? bytes;
  final String? gameIdBefore;
  final String? note;
  const AuditBackup({
    required this.id,
    this.sessionId,
    required this.ts,
    this.slot,
    this.lxcPath,
    this.bytes,
    this.gameIdBefore,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<int>(sessionId);
    }
    map['ts'] = Variable<String>(ts);
    if (!nullToAbsent || slot != null) {
      map['slot'] = Variable<int>(slot);
    }
    if (!nullToAbsent || lxcPath != null) {
      map['lxc_path'] = Variable<String>(lxcPath);
    }
    if (!nullToAbsent || bytes != null) {
      map['bytes'] = Variable<int>(bytes);
    }
    if (!nullToAbsent || gameIdBefore != null) {
      map['game_id_before'] = Variable<String>(gameIdBefore);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  AuditBackupsCompanion toCompanion(bool nullToAbsent) {
    return AuditBackupsCompanion(
      id: Value(id),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      ts: Value(ts),
      slot: slot == null && nullToAbsent ? const Value.absent() : Value(slot),
      lxcPath: lxcPath == null && nullToAbsent
          ? const Value.absent()
          : Value(lxcPath),
      bytes: bytes == null && nullToAbsent
          ? const Value.absent()
          : Value(bytes),
      gameIdBefore: gameIdBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(gameIdBefore),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory AuditBackup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditBackup(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int?>(json['sessionId']),
      ts: serializer.fromJson<String>(json['ts']),
      slot: serializer.fromJson<int?>(json['slot']),
      lxcPath: serializer.fromJson<String?>(json['lxcPath']),
      bytes: serializer.fromJson<int?>(json['bytes']),
      gameIdBefore: serializer.fromJson<String?>(json['gameIdBefore']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int?>(sessionId),
      'ts': serializer.toJson<String>(ts),
      'slot': serializer.toJson<int?>(slot),
      'lxcPath': serializer.toJson<String?>(lxcPath),
      'bytes': serializer.toJson<int?>(bytes),
      'gameIdBefore': serializer.toJson<String?>(gameIdBefore),
      'note': serializer.toJson<String?>(note),
    };
  }

  AuditBackup copyWith({
    int? id,
    Value<int?> sessionId = const Value.absent(),
    String? ts,
    Value<int?> slot = const Value.absent(),
    Value<String?> lxcPath = const Value.absent(),
    Value<int?> bytes = const Value.absent(),
    Value<String?> gameIdBefore = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) => AuditBackup(
    id: id ?? this.id,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    ts: ts ?? this.ts,
    slot: slot.present ? slot.value : this.slot,
    lxcPath: lxcPath.present ? lxcPath.value : this.lxcPath,
    bytes: bytes.present ? bytes.value : this.bytes,
    gameIdBefore: gameIdBefore.present ? gameIdBefore.value : this.gameIdBefore,
    note: note.present ? note.value : this.note,
  );
  AuditBackup copyWithCompanion(AuditBackupsCompanion data) {
    return AuditBackup(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      ts: data.ts.present ? data.ts.value : this.ts,
      slot: data.slot.present ? data.slot.value : this.slot,
      lxcPath: data.lxcPath.present ? data.lxcPath.value : this.lxcPath,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      gameIdBefore: data.gameIdBefore.present
          ? data.gameIdBefore.value
          : this.gameIdBefore,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditBackup(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('ts: $ts, ')
          ..write('slot: $slot, ')
          ..write('lxcPath: $lxcPath, ')
          ..write('bytes: $bytes, ')
          ..write('gameIdBefore: $gameIdBefore, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sessionId, ts, slot, lxcPath, bytes, gameIdBefore, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditBackup &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.ts == this.ts &&
          other.slot == this.slot &&
          other.lxcPath == this.lxcPath &&
          other.bytes == this.bytes &&
          other.gameIdBefore == this.gameIdBefore &&
          other.note == this.note);
}

class AuditBackupsCompanion extends UpdateCompanion<AuditBackup> {
  final Value<int> id;
  final Value<int?> sessionId;
  final Value<String> ts;
  final Value<int?> slot;
  final Value<String?> lxcPath;
  final Value<int?> bytes;
  final Value<String?> gameIdBefore;
  final Value<String?> note;
  const AuditBackupsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.ts = const Value.absent(),
    this.slot = const Value.absent(),
    this.lxcPath = const Value.absent(),
    this.bytes = const Value.absent(),
    this.gameIdBefore = const Value.absent(),
    this.note = const Value.absent(),
  });
  AuditBackupsCompanion.insert({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    required String ts,
    this.slot = const Value.absent(),
    this.lxcPath = const Value.absent(),
    this.bytes = const Value.absent(),
    this.gameIdBefore = const Value.absent(),
    this.note = const Value.absent(),
  }) : ts = Value(ts);
  static Insertable<AuditBackup> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<String>? ts,
    Expression<int>? slot,
    Expression<String>? lxcPath,
    Expression<int>? bytes,
    Expression<String>? gameIdBefore,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (ts != null) 'ts': ts,
      if (slot != null) 'slot': slot,
      if (lxcPath != null) 'lxc_path': lxcPath,
      if (bytes != null) 'bytes': bytes,
      if (gameIdBefore != null) 'game_id_before': gameIdBefore,
      if (note != null) 'note': note,
    });
  }

  AuditBackupsCompanion copyWith({
    Value<int>? id,
    Value<int?>? sessionId,
    Value<String>? ts,
    Value<int?>? slot,
    Value<String?>? lxcPath,
    Value<int?>? bytes,
    Value<String?>? gameIdBefore,
    Value<String?>? note,
  }) {
    return AuditBackupsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      ts: ts ?? this.ts,
      slot: slot ?? this.slot,
      lxcPath: lxcPath ?? this.lxcPath,
      bytes: bytes ?? this.bytes,
      gameIdBefore: gameIdBefore ?? this.gameIdBefore,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (ts.present) {
      map['ts'] = Variable<String>(ts.value);
    }
    if (slot.present) {
      map['slot'] = Variable<int>(slot.value);
    }
    if (lxcPath.present) {
      map['lxc_path'] = Variable<String>(lxcPath.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (gameIdBefore.present) {
      map['game_id_before'] = Variable<String>(gameIdBefore.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditBackupsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('ts: $ts, ')
          ..write('slot: $slot, ')
          ..write('lxcPath: $lxcPath, ')
          ..write('bytes: $bytes, ')
          ..write('gameIdBefore: $gameIdBefore, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $AuditSshCommandsTable extends AuditSshCommands
    with TableInfo<$AuditSshCommandsTable, AuditSshCommand> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditSshCommandsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id)',
    ),
  );
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<String> ts = GeneratedColumn<String>(
    'ts',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandMeta = const VerificationMeta(
    'command',
  );
  @override
  late final GeneratedColumn<String> command = GeneratedColumn<String>(
    'command',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exitCodeMeta = const VerificationMeta(
    'exitCode',
  );
  @override
  late final GeneratedColumn<int> exitCode = GeneratedColumn<int>(
    'exit_code',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stdoutMeta = const VerificationMeta('stdout');
  @override
  late final GeneratedColumn<String> stdout = GeneratedColumn<String>(
    'stdout',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stderrMeta = const VerificationMeta('stderr');
  @override
  late final GeneratedColumn<String> stderr = GeneratedColumn<String>(
    'stderr',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    ts,
    command,
    exitCode,
    stdout,
    stderr,
    durationMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ssh_commands';
  @override
  VerificationContext validateIntegrity(
    Insertable<AuditSshCommand> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('command')) {
      context.handle(
        _commandMeta,
        command.isAcceptableOrUnknown(data['command']!, _commandMeta),
      );
    } else if (isInserting) {
      context.missing(_commandMeta);
    }
    if (data.containsKey('exit_code')) {
      context.handle(
        _exitCodeMeta,
        exitCode.isAcceptableOrUnknown(data['exit_code']!, _exitCodeMeta),
      );
    }
    if (data.containsKey('stdout')) {
      context.handle(
        _stdoutMeta,
        stdout.isAcceptableOrUnknown(data['stdout']!, _stdoutMeta),
      );
    }
    if (data.containsKey('stderr')) {
      context.handle(
        _stderrMeta,
        stderr.isAcceptableOrUnknown(data['stderr']!, _stderrMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditSshCommand map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditSshCommand(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      ),
      ts: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ts'],
      )!,
      command: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command'],
      )!,
      exitCode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exit_code'],
      ),
      stdout: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stdout'],
      ),
      stderr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stderr'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
    );
  }

  @override
  $AuditSshCommandsTable createAlias(String alias) {
    return $AuditSshCommandsTable(attachedDatabase, alias);
  }
}

class AuditSshCommand extends DataClass implements Insertable<AuditSshCommand> {
  final int id;
  final int? sessionId;
  final String ts;
  final String command;

  /// NULL when the command never returned an exit status (transport failure).
  final int? exitCode;

  /// Truncated — see `AuditDatabase.captureTruncateLength`.
  final String? stdout;
  final String? stderr;
  final int? durationMs;
  const AuditSshCommand({
    required this.id,
    this.sessionId,
    required this.ts,
    required this.command,
    this.exitCode,
    this.stdout,
    this.stderr,
    this.durationMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<int>(sessionId);
    }
    map['ts'] = Variable<String>(ts);
    map['command'] = Variable<String>(command);
    if (!nullToAbsent || exitCode != null) {
      map['exit_code'] = Variable<int>(exitCode);
    }
    if (!nullToAbsent || stdout != null) {
      map['stdout'] = Variable<String>(stdout);
    }
    if (!nullToAbsent || stderr != null) {
      map['stderr'] = Variable<String>(stderr);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    return map;
  }

  AuditSshCommandsCompanion toCompanion(bool nullToAbsent) {
    return AuditSshCommandsCompanion(
      id: Value(id),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      ts: Value(ts),
      command: Value(command),
      exitCode: exitCode == null && nullToAbsent
          ? const Value.absent()
          : Value(exitCode),
      stdout: stdout == null && nullToAbsent
          ? const Value.absent()
          : Value(stdout),
      stderr: stderr == null && nullToAbsent
          ? const Value.absent()
          : Value(stderr),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
    );
  }

  factory AuditSshCommand.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditSshCommand(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int?>(json['sessionId']),
      ts: serializer.fromJson<String>(json['ts']),
      command: serializer.fromJson<String>(json['command']),
      exitCode: serializer.fromJson<int?>(json['exitCode']),
      stdout: serializer.fromJson<String?>(json['stdout']),
      stderr: serializer.fromJson<String?>(json['stderr']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int?>(sessionId),
      'ts': serializer.toJson<String>(ts),
      'command': serializer.toJson<String>(command),
      'exitCode': serializer.toJson<int?>(exitCode),
      'stdout': serializer.toJson<String?>(stdout),
      'stderr': serializer.toJson<String?>(stderr),
      'durationMs': serializer.toJson<int?>(durationMs),
    };
  }

  AuditSshCommand copyWith({
    int? id,
    Value<int?> sessionId = const Value.absent(),
    String? ts,
    String? command,
    Value<int?> exitCode = const Value.absent(),
    Value<String?> stdout = const Value.absent(),
    Value<String?> stderr = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
  }) => AuditSshCommand(
    id: id ?? this.id,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    ts: ts ?? this.ts,
    command: command ?? this.command,
    exitCode: exitCode.present ? exitCode.value : this.exitCode,
    stdout: stdout.present ? stdout.value : this.stdout,
    stderr: stderr.present ? stderr.value : this.stderr,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
  );
  AuditSshCommand copyWithCompanion(AuditSshCommandsCompanion data) {
    return AuditSshCommand(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      ts: data.ts.present ? data.ts.value : this.ts,
      command: data.command.present ? data.command.value : this.command,
      exitCode: data.exitCode.present ? data.exitCode.value : this.exitCode,
      stdout: data.stdout.present ? data.stdout.value : this.stdout,
      stderr: data.stderr.present ? data.stderr.value : this.stderr,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditSshCommand(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('ts: $ts, ')
          ..write('command: $command, ')
          ..write('exitCode: $exitCode, ')
          ..write('stdout: $stdout, ')
          ..write('stderr: $stderr, ')
          ..write('durationMs: $durationMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    ts,
    command,
    exitCode,
    stdout,
    stderr,
    durationMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditSshCommand &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.ts == this.ts &&
          other.command == this.command &&
          other.exitCode == this.exitCode &&
          other.stdout == this.stdout &&
          other.stderr == this.stderr &&
          other.durationMs == this.durationMs);
}

class AuditSshCommandsCompanion extends UpdateCompanion<AuditSshCommand> {
  final Value<int> id;
  final Value<int?> sessionId;
  final Value<String> ts;
  final Value<String> command;
  final Value<int?> exitCode;
  final Value<String?> stdout;
  final Value<String?> stderr;
  final Value<int?> durationMs;
  const AuditSshCommandsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.ts = const Value.absent(),
    this.command = const Value.absent(),
    this.exitCode = const Value.absent(),
    this.stdout = const Value.absent(),
    this.stderr = const Value.absent(),
    this.durationMs = const Value.absent(),
  });
  AuditSshCommandsCompanion.insert({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    required String ts,
    required String command,
    this.exitCode = const Value.absent(),
    this.stdout = const Value.absent(),
    this.stderr = const Value.absent(),
    this.durationMs = const Value.absent(),
  }) : ts = Value(ts),
       command = Value(command);
  static Insertable<AuditSshCommand> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<String>? ts,
    Expression<String>? command,
    Expression<int>? exitCode,
    Expression<String>? stdout,
    Expression<String>? stderr,
    Expression<int>? durationMs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (ts != null) 'ts': ts,
      if (command != null) 'command': command,
      if (exitCode != null) 'exit_code': exitCode,
      if (stdout != null) 'stdout': stdout,
      if (stderr != null) 'stderr': stderr,
      if (durationMs != null) 'duration_ms': durationMs,
    });
  }

  AuditSshCommandsCompanion copyWith({
    Value<int>? id,
    Value<int?>? sessionId,
    Value<String>? ts,
    Value<String>? command,
    Value<int?>? exitCode,
    Value<String?>? stdout,
    Value<String?>? stderr,
    Value<int?>? durationMs,
  }) {
    return AuditSshCommandsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      ts: ts ?? this.ts,
      command: command ?? this.command,
      exitCode: exitCode ?? this.exitCode,
      stdout: stdout ?? this.stdout,
      stderr: stderr ?? this.stderr,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (ts.present) {
      map['ts'] = Variable<String>(ts.value);
    }
    if (command.present) {
      map['command'] = Variable<String>(command.value);
    }
    if (exitCode.present) {
      map['exit_code'] = Variable<int>(exitCode.value);
    }
    if (stdout.present) {
      map['stdout'] = Variable<String>(stdout.value);
    }
    if (stderr.present) {
      map['stderr'] = Variable<String>(stderr.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditSshCommandsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('ts: $ts, ')
          ..write('command: $command, ')
          ..write('exitCode: $exitCode, ')
          ..write('stdout: $stdout, ')
          ..write('stderr: $stderr, ')
          ..write('durationMs: $durationMs')
          ..write(')'))
        .toString();
  }
}

class $AuditErrorsTable extends AuditErrors
    with TableInfo<$AuditErrorsTable, AuditError> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditErrorsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id)',
    ),
  );
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<String> ts = GeneratedColumn<String>(
    'ts',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contextMeta = const VerificationMeta(
    'context',
  );
  @override
  late final GeneratedColumn<String> context = GeneratedColumn<String>(
    'context',
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
  static const VerificationMeta _detailJsonMeta = const VerificationMeta(
    'detailJson',
  );
  @override
  late final GeneratedColumn<String> detailJson = GeneratedColumn<String>(
    'detail_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    ts,
    context,
    message,
    detailJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'errors';
  @override
  VerificationContext validateIntegrity(
    Insertable<AuditError> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    if (data.containsKey('context')) {
      context.handle(
        _contextMeta,
        this.context.isAcceptableOrUnknown(data['context']!, _contextMeta),
      );
    } else if (isInserting) {
      context.missing(_contextMeta);
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    if (data.containsKey('detail_json')) {
      context.handle(
        _detailJsonMeta,
        detailJson.isAcceptableOrUnknown(data['detail_json']!, _detailJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditError map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditError(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      ),
      ts: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ts'],
      )!,
      context: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context'],
      )!,
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      )!,
      detailJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail_json'],
      ),
    );
  }

  @override
  $AuditErrorsTable createAlias(String alias) {
    return $AuditErrorsTable(attachedDatabase, alias);
  }
}

class AuditError extends DataClass implements Insertable<AuditError> {
  final int id;
  final int? sessionId;
  final String ts;

  /// Which operation failed: `connect`, `discovery`, `push`, `pull`, `restore`,
  /// `ssh_exec`, … — matches `WkException.context`.
  final String context;
  final String message;
  final String? detailJson;
  const AuditError({
    required this.id,
    this.sessionId,
    required this.ts,
    required this.context,
    required this.message,
    this.detailJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<int>(sessionId);
    }
    map['ts'] = Variable<String>(ts);
    map['context'] = Variable<String>(context);
    map['message'] = Variable<String>(message);
    if (!nullToAbsent || detailJson != null) {
      map['detail_json'] = Variable<String>(detailJson);
    }
    return map;
  }

  AuditErrorsCompanion toCompanion(bool nullToAbsent) {
    return AuditErrorsCompanion(
      id: Value(id),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      ts: Value(ts),
      context: Value(context),
      message: Value(message),
      detailJson: detailJson == null && nullToAbsent
          ? const Value.absent()
          : Value(detailJson),
    );
  }

  factory AuditError.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditError(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int?>(json['sessionId']),
      ts: serializer.fromJson<String>(json['ts']),
      context: serializer.fromJson<String>(json['context']),
      message: serializer.fromJson<String>(json['message']),
      detailJson: serializer.fromJson<String?>(json['detailJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int?>(sessionId),
      'ts': serializer.toJson<String>(ts),
      'context': serializer.toJson<String>(context),
      'message': serializer.toJson<String>(message),
      'detailJson': serializer.toJson<String?>(detailJson),
    };
  }

  AuditError copyWith({
    int? id,
    Value<int?> sessionId = const Value.absent(),
    String? ts,
    String? context,
    String? message,
    Value<String?> detailJson = const Value.absent(),
  }) => AuditError(
    id: id ?? this.id,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    ts: ts ?? this.ts,
    context: context ?? this.context,
    message: message ?? this.message,
    detailJson: detailJson.present ? detailJson.value : this.detailJson,
  );
  AuditError copyWithCompanion(AuditErrorsCompanion data) {
    return AuditError(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      ts: data.ts.present ? data.ts.value : this.ts,
      context: data.context.present ? data.context.value : this.context,
      message: data.message.present ? data.message.value : this.message,
      detailJson: data.detailJson.present
          ? data.detailJson.value
          : this.detailJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditError(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('ts: $ts, ')
          ..write('context: $context, ')
          ..write('message: $message, ')
          ..write('detailJson: $detailJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sessionId, ts, context, message, detailJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditError &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.ts == this.ts &&
          other.context == this.context &&
          other.message == this.message &&
          other.detailJson == this.detailJson);
}

class AuditErrorsCompanion extends UpdateCompanion<AuditError> {
  final Value<int> id;
  final Value<int?> sessionId;
  final Value<String> ts;
  final Value<String> context;
  final Value<String> message;
  final Value<String?> detailJson;
  const AuditErrorsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.ts = const Value.absent(),
    this.context = const Value.absent(),
    this.message = const Value.absent(),
    this.detailJson = const Value.absent(),
  });
  AuditErrorsCompanion.insert({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    required String ts,
    required String context,
    required String message,
    this.detailJson = const Value.absent(),
  }) : ts = Value(ts),
       context = Value(context),
       message = Value(message);
  static Insertable<AuditError> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<String>? ts,
    Expression<String>? context,
    Expression<String>? message,
    Expression<String>? detailJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (ts != null) 'ts': ts,
      if (context != null) 'context': context,
      if (message != null) 'message': message,
      if (detailJson != null) 'detail_json': detailJson,
    });
  }

  AuditErrorsCompanion copyWith({
    Value<int>? id,
    Value<int?>? sessionId,
    Value<String>? ts,
    Value<String>? context,
    Value<String>? message,
    Value<String?>? detailJson,
  }) {
    return AuditErrorsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      ts: ts ?? this.ts,
      context: context ?? this.context,
      message: message ?? this.message,
      detailJson: detailJson ?? this.detailJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (ts.present) {
      map['ts'] = Variable<String>(ts.value);
    }
    if (context.present) {
      map['context'] = Variable<String>(context.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (detailJson.present) {
      map['detail_json'] = Variable<String>(detailJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditErrorsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('ts: $ts, ')
          ..write('context: $context, ')
          ..write('message: $message, ')
          ..write('detailJson: $detailJson')
          ..write(')'))
        .toString();
  }
}

abstract class _$AuditDatabase extends GeneratedDatabase {
  _$AuditDatabase(QueryExecutor e) : super(e);
  $AuditDatabaseManager get managers => $AuditDatabaseManager(this);
  late final $AuditSessionsTable auditSessions = $AuditSessionsTable(this);
  late final $AuditEventsTable auditEvents = $AuditEventsTable(this);
  late final $AuditFileOpsTable auditFileOps = $AuditFileOpsTable(this);
  late final $AuditBackupsTable auditBackups = $AuditBackupsTable(this);
  late final $AuditSshCommandsTable auditSshCommands = $AuditSshCommandsTable(
    this,
  );
  late final $AuditErrorsTable auditErrors = $AuditErrorsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    auditSessions,
    auditEvents,
    auditFileOps,
    auditBackups,
    auditSshCommands,
    auditErrors,
  ];
}

typedef $$AuditSessionsTableCreateCompanionBuilder =
    AuditSessionsCompanion Function({
      Value<int> id,
      required String startedAt,
      Value<String?> appVersion,
      Value<String?> profileId,
      Value<String?> host,
      Value<String?> sshUser,
      Value<String?> authMethod,
    });
typedef $$AuditSessionsTableUpdateCompanionBuilder =
    AuditSessionsCompanion Function({
      Value<int> id,
      Value<String> startedAt,
      Value<String?> appVersion,
      Value<String?> profileId,
      Value<String?> host,
      Value<String?> sshUser,
      Value<String?> authMethod,
    });

final class $$AuditSessionsTableReferences
    extends BaseReferences<_$AuditDatabase, $AuditSessionsTable, AuditSession> {
  $$AuditSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$AuditEventsTable, List<AuditEvent>>
  _auditEventsRefsTable(_$AuditDatabase db) => MultiTypedResultKey.fromTable(
    db.auditEvents,
    aliasName: 'sessions__id__events__session_id',
  );

  $$AuditEventsTableProcessedTableManager get auditEventsRefs {
    final manager = $$AuditEventsTableTableManager(
      $_db,
      $_db.auditEvents,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_auditEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AuditBackupsTable, List<AuditBackup>>
  _auditBackupsRefsTable(_$AuditDatabase db) => MultiTypedResultKey.fromTable(
    db.auditBackups,
    aliasName: 'sessions__id__backups__session_id',
  );

  $$AuditBackupsTableProcessedTableManager get auditBackupsRefs {
    final manager = $$AuditBackupsTableTableManager(
      $_db,
      $_db.auditBackups,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_auditBackupsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AuditSshCommandsTable, List<AuditSshCommand>>
  _auditSshCommandsRefsTable(_$AuditDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.auditSshCommands,
        aliasName: 'sessions__id__ssh_commands__session_id',
      );

  $$AuditSshCommandsTableProcessedTableManager get auditSshCommandsRefs {
    final manager = $$AuditSshCommandsTableTableManager(
      $_db,
      $_db.auditSshCommands,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _auditSshCommandsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AuditErrorsTable, List<AuditError>>
  _auditErrorsRefsTable(_$AuditDatabase db) => MultiTypedResultKey.fromTable(
    db.auditErrors,
    aliasName: 'sessions__id__errors__session_id',
  );

  $$AuditErrorsTableProcessedTableManager get auditErrorsRefs {
    final manager = $$AuditErrorsTableTableManager(
      $_db,
      $_db.auditErrors,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_auditErrorsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AuditSessionsTableFilterComposer
    extends Composer<_$AuditDatabase, $AuditSessionsTable> {
  $$AuditSessionsTableFilterComposer({
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

  ColumnFilters<String> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sshUser => $composableBuilder(
    column: $table.sshUser,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authMethod => $composableBuilder(
    column: $table.authMethod,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> auditEventsRefs(
    Expression<bool> Function($$AuditEventsTableFilterComposer f) f,
  ) {
    final $$AuditEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.auditEvents,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditEventsTableFilterComposer(
            $db: $db,
            $table: $db.auditEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> auditBackupsRefs(
    Expression<bool> Function($$AuditBackupsTableFilterComposer f) f,
  ) {
    final $$AuditBackupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.auditBackups,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditBackupsTableFilterComposer(
            $db: $db,
            $table: $db.auditBackups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> auditSshCommandsRefs(
    Expression<bool> Function($$AuditSshCommandsTableFilterComposer f) f,
  ) {
    final $$AuditSshCommandsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.auditSshCommands,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditSshCommandsTableFilterComposer(
            $db: $db,
            $table: $db.auditSshCommands,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> auditErrorsRefs(
    Expression<bool> Function($$AuditErrorsTableFilterComposer f) f,
  ) {
    final $$AuditErrorsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.auditErrors,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditErrorsTableFilterComposer(
            $db: $db,
            $table: $db.auditErrors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AuditSessionsTableOrderingComposer
    extends Composer<_$AuditDatabase, $AuditSessionsTable> {
  $$AuditSessionsTableOrderingComposer({
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

  ColumnOrderings<String> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sshUser => $composableBuilder(
    column: $table.sshUser,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authMethod => $composableBuilder(
    column: $table.authMethod,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AuditSessionsTableAnnotationComposer
    extends Composer<_$AuditDatabase, $AuditSessionsTable> {
  $$AuditSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<String> get sshUser =>
      $composableBuilder(column: $table.sshUser, builder: (column) => column);

  GeneratedColumn<String> get authMethod => $composableBuilder(
    column: $table.authMethod,
    builder: (column) => column,
  );

  Expression<T> auditEventsRefs<T extends Object>(
    Expression<T> Function($$AuditEventsTableAnnotationComposer a) f,
  ) {
    final $$AuditEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.auditEvents,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.auditEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> auditBackupsRefs<T extends Object>(
    Expression<T> Function($$AuditBackupsTableAnnotationComposer a) f,
  ) {
    final $$AuditBackupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.auditBackups,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditBackupsTableAnnotationComposer(
            $db: $db,
            $table: $db.auditBackups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> auditSshCommandsRefs<T extends Object>(
    Expression<T> Function($$AuditSshCommandsTableAnnotationComposer a) f,
  ) {
    final $$AuditSshCommandsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.auditSshCommands,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditSshCommandsTableAnnotationComposer(
            $db: $db,
            $table: $db.auditSshCommands,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> auditErrorsRefs<T extends Object>(
    Expression<T> Function($$AuditErrorsTableAnnotationComposer a) f,
  ) {
    final $$AuditErrorsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.auditErrors,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditErrorsTableAnnotationComposer(
            $db: $db,
            $table: $db.auditErrors,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AuditSessionsTableTableManager
    extends
        RootTableManager<
          _$AuditDatabase,
          $AuditSessionsTable,
          AuditSession,
          $$AuditSessionsTableFilterComposer,
          $$AuditSessionsTableOrderingComposer,
          $$AuditSessionsTableAnnotationComposer,
          $$AuditSessionsTableCreateCompanionBuilder,
          $$AuditSessionsTableUpdateCompanionBuilder,
          (AuditSession, $$AuditSessionsTableReferences),
          AuditSession,
          PrefetchHooks Function({
            bool auditEventsRefs,
            bool auditBackupsRefs,
            bool auditSshCommandsRefs,
            bool auditErrorsRefs,
          })
        > {
  $$AuditSessionsTableTableManager(
    _$AuditDatabase db,
    $AuditSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> startedAt = const Value.absent(),
                Value<String?> appVersion = const Value.absent(),
                Value<String?> profileId = const Value.absent(),
                Value<String?> host = const Value.absent(),
                Value<String?> sshUser = const Value.absent(),
                Value<String?> authMethod = const Value.absent(),
              }) => AuditSessionsCompanion(
                id: id,
                startedAt: startedAt,
                appVersion: appVersion,
                profileId: profileId,
                host: host,
                sshUser: sshUser,
                authMethod: authMethod,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String startedAt,
                Value<String?> appVersion = const Value.absent(),
                Value<String?> profileId = const Value.absent(),
                Value<String?> host = const Value.absent(),
                Value<String?> sshUser = const Value.absent(),
                Value<String?> authMethod = const Value.absent(),
              }) => AuditSessionsCompanion.insert(
                id: id,
                startedAt: startedAt,
                appVersion: appVersion,
                profileId: profileId,
                host: host,
                sshUser: sshUser,
                authMethod: authMethod,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AuditSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                auditEventsRefs = false,
                auditBackupsRefs = false,
                auditSshCommandsRefs = false,
                auditErrorsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (auditEventsRefs) db.auditEvents,
                    if (auditBackupsRefs) db.auditBackups,
                    if (auditSshCommandsRefs) db.auditSshCommands,
                    if (auditErrorsRefs) db.auditErrors,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (auditEventsRefs)
                        await $_getPrefetchedData<
                          AuditSession,
                          $AuditSessionsTable,
                          AuditEvent
                        >(
                          currentTable: table,
                          referencedTable: $$AuditSessionsTableReferences
                              ._auditEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AuditSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).auditEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (auditBackupsRefs)
                        await $_getPrefetchedData<
                          AuditSession,
                          $AuditSessionsTable,
                          AuditBackup
                        >(
                          currentTable: table,
                          referencedTable: $$AuditSessionsTableReferences
                              ._auditBackupsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AuditSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).auditBackupsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (auditSshCommandsRefs)
                        await $_getPrefetchedData<
                          AuditSession,
                          $AuditSessionsTable,
                          AuditSshCommand
                        >(
                          currentTable: table,
                          referencedTable: $$AuditSessionsTableReferences
                              ._auditSshCommandsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AuditSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).auditSshCommandsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (auditErrorsRefs)
                        await $_getPrefetchedData<
                          AuditSession,
                          $AuditSessionsTable,
                          AuditError
                        >(
                          currentTable: table,
                          referencedTable: $$AuditSessionsTableReferences
                              ._auditErrorsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AuditSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).auditErrorsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AuditSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AuditDatabase,
      $AuditSessionsTable,
      AuditSession,
      $$AuditSessionsTableFilterComposer,
      $$AuditSessionsTableOrderingComposer,
      $$AuditSessionsTableAnnotationComposer,
      $$AuditSessionsTableCreateCompanionBuilder,
      $$AuditSessionsTableUpdateCompanionBuilder,
      (AuditSession, $$AuditSessionsTableReferences),
      AuditSession,
      PrefetchHooks Function({
        bool auditEventsRefs,
        bool auditBackupsRefs,
        bool auditSshCommandsRefs,
        bool auditErrorsRefs,
      })
    >;
typedef $$AuditEventsTableCreateCompanionBuilder =
    AuditEventsCompanion Function({
      Value<int> id,
      Value<int?> sessionId,
      required String ts,
      required String kind,
      Value<String?> state,
      Value<String?> detailJson,
      Value<int?> ok,
    });
typedef $$AuditEventsTableUpdateCompanionBuilder =
    AuditEventsCompanion Function({
      Value<int> id,
      Value<int?> sessionId,
      Value<String> ts,
      Value<String> kind,
      Value<String?> state,
      Value<String?> detailJson,
      Value<int?> ok,
    });

final class $$AuditEventsTableReferences
    extends BaseReferences<_$AuditDatabase, $AuditEventsTable, AuditEvent> {
  $$AuditEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AuditSessionsTable _sessionIdTable(_$AuditDatabase db) =>
      db.auditSessions.createAlias('events__session_id__sessions__id');

  $$AuditSessionsTableProcessedTableManager? get sessionId {
    final $_column = $_itemColumn<int>('session_id');
    if ($_column == null) return null;
    final manager = $$AuditSessionsTableTableManager(
      $_db,
      $_db.auditSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$AuditFileOpsTable, List<AuditFileOp>>
  _auditFileOpsRefsTable(_$AuditDatabase db) => MultiTypedResultKey.fromTable(
    db.auditFileOps,
    aliasName: 'events__id__file_ops__event_id',
  );

  $$AuditFileOpsTableProcessedTableManager get auditFileOpsRefs {
    final manager = $$AuditFileOpsTableTableManager(
      $_db,
      $_db.auditFileOps,
    ).filter((f) => f.eventId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_auditFileOpsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AuditEventsTableFilterComposer
    extends Composer<_$AuditDatabase, $AuditEventsTable> {
  $$AuditEventsTableFilterComposer({
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

  ColumnFilters<String> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailJson => $composableBuilder(
    column: $table.detailJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ok => $composableBuilder(
    column: $table.ok,
    builder: (column) => ColumnFilters(column),
  );

  $$AuditSessionsTableFilterComposer get sessionId {
    final $$AuditSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.auditSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditSessionsTableFilterComposer(
            $db: $db,
            $table: $db.auditSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> auditFileOpsRefs(
    Expression<bool> Function($$AuditFileOpsTableFilterComposer f) f,
  ) {
    final $$AuditFileOpsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.auditFileOps,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditFileOpsTableFilterComposer(
            $db: $db,
            $table: $db.auditFileOps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AuditEventsTableOrderingComposer
    extends Composer<_$AuditDatabase, $AuditEventsTable> {
  $$AuditEventsTableOrderingComposer({
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

  ColumnOrderings<String> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailJson => $composableBuilder(
    column: $table.detailJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ok => $composableBuilder(
    column: $table.ok,
    builder: (column) => ColumnOrderings(column),
  );

  $$AuditSessionsTableOrderingComposer get sessionId {
    final $$AuditSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.auditSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.auditSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AuditEventsTableAnnotationComposer
    extends Composer<_$AuditDatabase, $AuditEventsTable> {
  $$AuditEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get detailJson => $composableBuilder(
    column: $table.detailJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ok =>
      $composableBuilder(column: $table.ok, builder: (column) => column);

  $$AuditSessionsTableAnnotationComposer get sessionId {
    final $$AuditSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.auditSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.auditSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> auditFileOpsRefs<T extends Object>(
    Expression<T> Function($$AuditFileOpsTableAnnotationComposer a) f,
  ) {
    final $$AuditFileOpsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.auditFileOps,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditFileOpsTableAnnotationComposer(
            $db: $db,
            $table: $db.auditFileOps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AuditEventsTableTableManager
    extends
        RootTableManager<
          _$AuditDatabase,
          $AuditEventsTable,
          AuditEvent,
          $$AuditEventsTableFilterComposer,
          $$AuditEventsTableOrderingComposer,
          $$AuditEventsTableAnnotationComposer,
          $$AuditEventsTableCreateCompanionBuilder,
          $$AuditEventsTableUpdateCompanionBuilder,
          (AuditEvent, $$AuditEventsTableReferences),
          AuditEvent,
          PrefetchHooks Function({bool sessionId, bool auditFileOpsRefs})
        > {
  $$AuditEventsTableTableManager(_$AuditDatabase db, $AuditEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> sessionId = const Value.absent(),
                Value<String> ts = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> state = const Value.absent(),
                Value<String?> detailJson = const Value.absent(),
                Value<int?> ok = const Value.absent(),
              }) => AuditEventsCompanion(
                id: id,
                sessionId: sessionId,
                ts: ts,
                kind: kind,
                state: state,
                detailJson: detailJson,
                ok: ok,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> sessionId = const Value.absent(),
                required String ts,
                required String kind,
                Value<String?> state = const Value.absent(),
                Value<String?> detailJson = const Value.absent(),
                Value<int?> ok = const Value.absent(),
              }) => AuditEventsCompanion.insert(
                id: id,
                sessionId: sessionId,
                ts: ts,
                kind: kind,
                state: state,
                detailJson: detailJson,
                ok: ok,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AuditEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({sessionId = false, auditFileOpsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (auditFileOpsRefs) db.auditFileOps,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sessionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.sessionId,
                                    referencedTable:
                                        $$AuditEventsTableReferences
                                            ._sessionIdTable(db),
                                    referencedColumn:
                                        $$AuditEventsTableReferences
                                            ._sessionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (auditFileOpsRefs)
                        await $_getPrefetchedData<
                          AuditEvent,
                          $AuditEventsTable,
                          AuditFileOp
                        >(
                          currentTable: table,
                          referencedTable: $$AuditEventsTableReferences
                              ._auditFileOpsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AuditEventsTableReferences(
                                db,
                                table,
                                p0,
                              ).auditFileOpsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.eventId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AuditEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AuditDatabase,
      $AuditEventsTable,
      AuditEvent,
      $$AuditEventsTableFilterComposer,
      $$AuditEventsTableOrderingComposer,
      $$AuditEventsTableAnnotationComposer,
      $$AuditEventsTableCreateCompanionBuilder,
      $$AuditEventsTableUpdateCompanionBuilder,
      (AuditEvent, $$AuditEventsTableReferences),
      AuditEvent,
      PrefetchHooks Function({bool sessionId, bool auditFileOpsRefs})
    >;
typedef $$AuditFileOpsTableCreateCompanionBuilder =
    AuditFileOpsCompanion Function({
      Value<int> id,
      Value<int?> eventId,
      Value<String?> op,
      Value<String?> src,
      Value<String?> dst,
      Value<int?> bytes,
      Value<int?> slot,
    });
typedef $$AuditFileOpsTableUpdateCompanionBuilder =
    AuditFileOpsCompanion Function({
      Value<int> id,
      Value<int?> eventId,
      Value<String?> op,
      Value<String?> src,
      Value<String?> dst,
      Value<int?> bytes,
      Value<int?> slot,
    });

final class $$AuditFileOpsTableReferences
    extends BaseReferences<_$AuditDatabase, $AuditFileOpsTable, AuditFileOp> {
  $$AuditFileOpsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AuditEventsTable _eventIdTable(_$AuditDatabase db) =>
      db.auditEvents.createAlias('file_ops__event_id__events__id');

  $$AuditEventsTableProcessedTableManager? get eventId {
    final $_column = $_itemColumn<int>('event_id');
    if ($_column == null) return null;
    final manager = $$AuditEventsTableTableManager(
      $_db,
      $_db.auditEvents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_eventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AuditFileOpsTableFilterComposer
    extends Composer<_$AuditDatabase, $AuditFileOpsTable> {
  $$AuditFileOpsTableFilterComposer({
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

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get src => $composableBuilder(
    column: $table.src,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dst => $composableBuilder(
    column: $table.dst,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  $$AuditEventsTableFilterComposer get eventId {
    final $$AuditEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.auditEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditEventsTableFilterComposer(
            $db: $db,
            $table: $db.auditEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AuditFileOpsTableOrderingComposer
    extends Composer<_$AuditDatabase, $AuditFileOpsTable> {
  $$AuditFileOpsTableOrderingComposer({
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

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get src => $composableBuilder(
    column: $table.src,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dst => $composableBuilder(
    column: $table.dst,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  $$AuditEventsTableOrderingComposer get eventId {
    final $$AuditEventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.auditEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditEventsTableOrderingComposer(
            $db: $db,
            $table: $db.auditEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AuditFileOpsTableAnnotationComposer
    extends Composer<_$AuditDatabase, $AuditFileOpsTable> {
  $$AuditFileOpsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get src =>
      $composableBuilder(column: $table.src, builder: (column) => column);

  GeneratedColumn<String> get dst =>
      $composableBuilder(column: $table.dst, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<int> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  $$AuditEventsTableAnnotationComposer get eventId {
    final $$AuditEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.auditEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.auditEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AuditFileOpsTableTableManager
    extends
        RootTableManager<
          _$AuditDatabase,
          $AuditFileOpsTable,
          AuditFileOp,
          $$AuditFileOpsTableFilterComposer,
          $$AuditFileOpsTableOrderingComposer,
          $$AuditFileOpsTableAnnotationComposer,
          $$AuditFileOpsTableCreateCompanionBuilder,
          $$AuditFileOpsTableUpdateCompanionBuilder,
          (AuditFileOp, $$AuditFileOpsTableReferences),
          AuditFileOp,
          PrefetchHooks Function({bool eventId})
        > {
  $$AuditFileOpsTableTableManager(_$AuditDatabase db, $AuditFileOpsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditFileOpsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditFileOpsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditFileOpsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> eventId = const Value.absent(),
                Value<String?> op = const Value.absent(),
                Value<String?> src = const Value.absent(),
                Value<String?> dst = const Value.absent(),
                Value<int?> bytes = const Value.absent(),
                Value<int?> slot = const Value.absent(),
              }) => AuditFileOpsCompanion(
                id: id,
                eventId: eventId,
                op: op,
                src: src,
                dst: dst,
                bytes: bytes,
                slot: slot,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> eventId = const Value.absent(),
                Value<String?> op = const Value.absent(),
                Value<String?> src = const Value.absent(),
                Value<String?> dst = const Value.absent(),
                Value<int?> bytes = const Value.absent(),
                Value<int?> slot = const Value.absent(),
              }) => AuditFileOpsCompanion.insert(
                id: id,
                eventId: eventId,
                op: op,
                src: src,
                dst: dst,
                bytes: bytes,
                slot: slot,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AuditFileOpsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({eventId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (eventId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.eventId,
                                referencedTable: $$AuditFileOpsTableReferences
                                    ._eventIdTable(db),
                                referencedColumn: $$AuditFileOpsTableReferences
                                    ._eventIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AuditFileOpsTableProcessedTableManager =
    ProcessedTableManager<
      _$AuditDatabase,
      $AuditFileOpsTable,
      AuditFileOp,
      $$AuditFileOpsTableFilterComposer,
      $$AuditFileOpsTableOrderingComposer,
      $$AuditFileOpsTableAnnotationComposer,
      $$AuditFileOpsTableCreateCompanionBuilder,
      $$AuditFileOpsTableUpdateCompanionBuilder,
      (AuditFileOp, $$AuditFileOpsTableReferences),
      AuditFileOp,
      PrefetchHooks Function({bool eventId})
    >;
typedef $$AuditBackupsTableCreateCompanionBuilder =
    AuditBackupsCompanion Function({
      Value<int> id,
      Value<int?> sessionId,
      required String ts,
      Value<int?> slot,
      Value<String?> lxcPath,
      Value<int?> bytes,
      Value<String?> gameIdBefore,
      Value<String?> note,
    });
typedef $$AuditBackupsTableUpdateCompanionBuilder =
    AuditBackupsCompanion Function({
      Value<int> id,
      Value<int?> sessionId,
      Value<String> ts,
      Value<int?> slot,
      Value<String?> lxcPath,
      Value<int?> bytes,
      Value<String?> gameIdBefore,
      Value<String?> note,
    });

final class $$AuditBackupsTableReferences
    extends BaseReferences<_$AuditDatabase, $AuditBackupsTable, AuditBackup> {
  $$AuditBackupsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AuditSessionsTable _sessionIdTable(_$AuditDatabase db) =>
      db.auditSessions.createAlias('backups__session_id__sessions__id');

  $$AuditSessionsTableProcessedTableManager? get sessionId {
    final $_column = $_itemColumn<int>('session_id');
    if ($_column == null) return null;
    final manager = $$AuditSessionsTableTableManager(
      $_db,
      $_db.auditSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AuditBackupsTableFilterComposer
    extends Composer<_$AuditDatabase, $AuditBackupsTable> {
  $$AuditBackupsTableFilterComposer({
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

  ColumnFilters<String> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lxcPath => $composableBuilder(
    column: $table.lxcPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gameIdBefore => $composableBuilder(
    column: $table.gameIdBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  $$AuditSessionsTableFilterComposer get sessionId {
    final $$AuditSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.auditSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditSessionsTableFilterComposer(
            $db: $db,
            $table: $db.auditSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AuditBackupsTableOrderingComposer
    extends Composer<_$AuditDatabase, $AuditBackupsTable> {
  $$AuditBackupsTableOrderingComposer({
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

  ColumnOrderings<String> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lxcPath => $composableBuilder(
    column: $table.lxcPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gameIdBefore => $composableBuilder(
    column: $table.gameIdBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  $$AuditSessionsTableOrderingComposer get sessionId {
    final $$AuditSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.auditSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.auditSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AuditBackupsTableAnnotationComposer
    extends Composer<_$AuditDatabase, $AuditBackupsTable> {
  $$AuditBackupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<int> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<String> get lxcPath =>
      $composableBuilder(column: $table.lxcPath, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get gameIdBefore => $composableBuilder(
    column: $table.gameIdBefore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$AuditSessionsTableAnnotationComposer get sessionId {
    final $$AuditSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.auditSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.auditSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AuditBackupsTableTableManager
    extends
        RootTableManager<
          _$AuditDatabase,
          $AuditBackupsTable,
          AuditBackup,
          $$AuditBackupsTableFilterComposer,
          $$AuditBackupsTableOrderingComposer,
          $$AuditBackupsTableAnnotationComposer,
          $$AuditBackupsTableCreateCompanionBuilder,
          $$AuditBackupsTableUpdateCompanionBuilder,
          (AuditBackup, $$AuditBackupsTableReferences),
          AuditBackup,
          PrefetchHooks Function({bool sessionId})
        > {
  $$AuditBackupsTableTableManager(_$AuditDatabase db, $AuditBackupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditBackupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditBackupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditBackupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> sessionId = const Value.absent(),
                Value<String> ts = const Value.absent(),
                Value<int?> slot = const Value.absent(),
                Value<String?> lxcPath = const Value.absent(),
                Value<int?> bytes = const Value.absent(),
                Value<String?> gameIdBefore = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => AuditBackupsCompanion(
                id: id,
                sessionId: sessionId,
                ts: ts,
                slot: slot,
                lxcPath: lxcPath,
                bytes: bytes,
                gameIdBefore: gameIdBefore,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> sessionId = const Value.absent(),
                required String ts,
                Value<int?> slot = const Value.absent(),
                Value<String?> lxcPath = const Value.absent(),
                Value<int?> bytes = const Value.absent(),
                Value<String?> gameIdBefore = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => AuditBackupsCompanion.insert(
                id: id,
                sessionId: sessionId,
                ts: ts,
                slot: slot,
                lxcPath: lxcPath,
                bytes: bytes,
                gameIdBefore: gameIdBefore,
                note: note,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AuditBackupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$AuditBackupsTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $$AuditBackupsTableReferences
                                    ._sessionIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AuditBackupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AuditDatabase,
      $AuditBackupsTable,
      AuditBackup,
      $$AuditBackupsTableFilterComposer,
      $$AuditBackupsTableOrderingComposer,
      $$AuditBackupsTableAnnotationComposer,
      $$AuditBackupsTableCreateCompanionBuilder,
      $$AuditBackupsTableUpdateCompanionBuilder,
      (AuditBackup, $$AuditBackupsTableReferences),
      AuditBackup,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$AuditSshCommandsTableCreateCompanionBuilder =
    AuditSshCommandsCompanion Function({
      Value<int> id,
      Value<int?> sessionId,
      required String ts,
      required String command,
      Value<int?> exitCode,
      Value<String?> stdout,
      Value<String?> stderr,
      Value<int?> durationMs,
    });
typedef $$AuditSshCommandsTableUpdateCompanionBuilder =
    AuditSshCommandsCompanion Function({
      Value<int> id,
      Value<int?> sessionId,
      Value<String> ts,
      Value<String> command,
      Value<int?> exitCode,
      Value<String?> stdout,
      Value<String?> stderr,
      Value<int?> durationMs,
    });

final class $$AuditSshCommandsTableReferences
    extends
        BaseReferences<
          _$AuditDatabase,
          $AuditSshCommandsTable,
          AuditSshCommand
        > {
  $$AuditSshCommandsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AuditSessionsTable _sessionIdTable(_$AuditDatabase db) =>
      db.auditSessions.createAlias('ssh_commands__session_id__sessions__id');

  $$AuditSessionsTableProcessedTableManager? get sessionId {
    final $_column = $_itemColumn<int>('session_id');
    if ($_column == null) return null;
    final manager = $$AuditSessionsTableTableManager(
      $_db,
      $_db.auditSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AuditSshCommandsTableFilterComposer
    extends Composer<_$AuditDatabase, $AuditSshCommandsTable> {
  $$AuditSshCommandsTableFilterComposer({
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

  ColumnFilters<String> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get command => $composableBuilder(
    column: $table.command,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get exitCode => $composableBuilder(
    column: $table.exitCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stdout => $composableBuilder(
    column: $table.stdout,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stderr => $composableBuilder(
    column: $table.stderr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  $$AuditSessionsTableFilterComposer get sessionId {
    final $$AuditSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.auditSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditSessionsTableFilterComposer(
            $db: $db,
            $table: $db.auditSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AuditSshCommandsTableOrderingComposer
    extends Composer<_$AuditDatabase, $AuditSshCommandsTable> {
  $$AuditSshCommandsTableOrderingComposer({
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

  ColumnOrderings<String> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get command => $composableBuilder(
    column: $table.command,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get exitCode => $composableBuilder(
    column: $table.exitCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stdout => $composableBuilder(
    column: $table.stdout,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stderr => $composableBuilder(
    column: $table.stderr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$AuditSessionsTableOrderingComposer get sessionId {
    final $$AuditSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.auditSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.auditSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AuditSshCommandsTableAnnotationComposer
    extends Composer<_$AuditDatabase, $AuditSshCommandsTable> {
  $$AuditSshCommandsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<String> get command =>
      $composableBuilder(column: $table.command, builder: (column) => column);

  GeneratedColumn<int> get exitCode =>
      $composableBuilder(column: $table.exitCode, builder: (column) => column);

  GeneratedColumn<String> get stdout =>
      $composableBuilder(column: $table.stdout, builder: (column) => column);

  GeneratedColumn<String> get stderr =>
      $composableBuilder(column: $table.stderr, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  $$AuditSessionsTableAnnotationComposer get sessionId {
    final $$AuditSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.auditSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.auditSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AuditSshCommandsTableTableManager
    extends
        RootTableManager<
          _$AuditDatabase,
          $AuditSshCommandsTable,
          AuditSshCommand,
          $$AuditSshCommandsTableFilterComposer,
          $$AuditSshCommandsTableOrderingComposer,
          $$AuditSshCommandsTableAnnotationComposer,
          $$AuditSshCommandsTableCreateCompanionBuilder,
          $$AuditSshCommandsTableUpdateCompanionBuilder,
          (AuditSshCommand, $$AuditSshCommandsTableReferences),
          AuditSshCommand,
          PrefetchHooks Function({bool sessionId})
        > {
  $$AuditSshCommandsTableTableManager(
    _$AuditDatabase db,
    $AuditSshCommandsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditSshCommandsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditSshCommandsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditSshCommandsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> sessionId = const Value.absent(),
                Value<String> ts = const Value.absent(),
                Value<String> command = const Value.absent(),
                Value<int?> exitCode = const Value.absent(),
                Value<String?> stdout = const Value.absent(),
                Value<String?> stderr = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
              }) => AuditSshCommandsCompanion(
                id: id,
                sessionId: sessionId,
                ts: ts,
                command: command,
                exitCode: exitCode,
                stdout: stdout,
                stderr: stderr,
                durationMs: durationMs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> sessionId = const Value.absent(),
                required String ts,
                required String command,
                Value<int?> exitCode = const Value.absent(),
                Value<String?> stdout = const Value.absent(),
                Value<String?> stderr = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
              }) => AuditSshCommandsCompanion.insert(
                id: id,
                sessionId: sessionId,
                ts: ts,
                command: command,
                exitCode: exitCode,
                stdout: stdout,
                stderr: stderr,
                durationMs: durationMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AuditSshCommandsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable:
                                    $$AuditSshCommandsTableReferences
                                        ._sessionIdTable(db),
                                referencedColumn:
                                    $$AuditSshCommandsTableReferences
                                        ._sessionIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AuditSshCommandsTableProcessedTableManager =
    ProcessedTableManager<
      _$AuditDatabase,
      $AuditSshCommandsTable,
      AuditSshCommand,
      $$AuditSshCommandsTableFilterComposer,
      $$AuditSshCommandsTableOrderingComposer,
      $$AuditSshCommandsTableAnnotationComposer,
      $$AuditSshCommandsTableCreateCompanionBuilder,
      $$AuditSshCommandsTableUpdateCompanionBuilder,
      (AuditSshCommand, $$AuditSshCommandsTableReferences),
      AuditSshCommand,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$AuditErrorsTableCreateCompanionBuilder =
    AuditErrorsCompanion Function({
      Value<int> id,
      Value<int?> sessionId,
      required String ts,
      required String context,
      required String message,
      Value<String?> detailJson,
    });
typedef $$AuditErrorsTableUpdateCompanionBuilder =
    AuditErrorsCompanion Function({
      Value<int> id,
      Value<int?> sessionId,
      Value<String> ts,
      Value<String> context,
      Value<String> message,
      Value<String?> detailJson,
    });

final class $$AuditErrorsTableReferences
    extends BaseReferences<_$AuditDatabase, $AuditErrorsTable, AuditError> {
  $$AuditErrorsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AuditSessionsTable _sessionIdTable(_$AuditDatabase db) =>
      db.auditSessions.createAlias('errors__session_id__sessions__id');

  $$AuditSessionsTableProcessedTableManager? get sessionId {
    final $_column = $_itemColumn<int>('session_id');
    if ($_column == null) return null;
    final manager = $$AuditSessionsTableTableManager(
      $_db,
      $_db.auditSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AuditErrorsTableFilterComposer
    extends Composer<_$AuditDatabase, $AuditErrorsTable> {
  $$AuditErrorsTableFilterComposer({
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

  ColumnFilters<String> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailJson => $composableBuilder(
    column: $table.detailJson,
    builder: (column) => ColumnFilters(column),
  );

  $$AuditSessionsTableFilterComposer get sessionId {
    final $$AuditSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.auditSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditSessionsTableFilterComposer(
            $db: $db,
            $table: $db.auditSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AuditErrorsTableOrderingComposer
    extends Composer<_$AuditDatabase, $AuditErrorsTable> {
  $$AuditErrorsTableOrderingComposer({
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

  ColumnOrderings<String> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailJson => $composableBuilder(
    column: $table.detailJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$AuditSessionsTableOrderingComposer get sessionId {
    final $$AuditSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.auditSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.auditSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AuditErrorsTableAnnotationComposer
    extends Composer<_$AuditDatabase, $AuditErrorsTable> {
  $$AuditErrorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);

  GeneratedColumn<String> get context =>
      $composableBuilder(column: $table.context, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<String> get detailJson => $composableBuilder(
    column: $table.detailJson,
    builder: (column) => column,
  );

  $$AuditSessionsTableAnnotationComposer get sessionId {
    final $$AuditSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.auditSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AuditSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.auditSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AuditErrorsTableTableManager
    extends
        RootTableManager<
          _$AuditDatabase,
          $AuditErrorsTable,
          AuditError,
          $$AuditErrorsTableFilterComposer,
          $$AuditErrorsTableOrderingComposer,
          $$AuditErrorsTableAnnotationComposer,
          $$AuditErrorsTableCreateCompanionBuilder,
          $$AuditErrorsTableUpdateCompanionBuilder,
          (AuditError, $$AuditErrorsTableReferences),
          AuditError,
          PrefetchHooks Function({bool sessionId})
        > {
  $$AuditErrorsTableTableManager(_$AuditDatabase db, $AuditErrorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditErrorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditErrorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditErrorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> sessionId = const Value.absent(),
                Value<String> ts = const Value.absent(),
                Value<String> context = const Value.absent(),
                Value<String> message = const Value.absent(),
                Value<String?> detailJson = const Value.absent(),
              }) => AuditErrorsCompanion(
                id: id,
                sessionId: sessionId,
                ts: ts,
                context: context,
                message: message,
                detailJson: detailJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> sessionId = const Value.absent(),
                required String ts,
                required String context,
                required String message,
                Value<String?> detailJson = const Value.absent(),
              }) => AuditErrorsCompanion.insert(
                id: id,
                sessionId: sessionId,
                ts: ts,
                context: context,
                message: message,
                detailJson: detailJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AuditErrorsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$AuditErrorsTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $$AuditErrorsTableReferences
                                    ._sessionIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AuditErrorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AuditDatabase,
      $AuditErrorsTable,
      AuditError,
      $$AuditErrorsTableFilterComposer,
      $$AuditErrorsTableOrderingComposer,
      $$AuditErrorsTableAnnotationComposer,
      $$AuditErrorsTableCreateCompanionBuilder,
      $$AuditErrorsTableUpdateCompanionBuilder,
      (AuditError, $$AuditErrorsTableReferences),
      AuditError,
      PrefetchHooks Function({bool sessionId})
    >;

class $AuditDatabaseManager {
  final _$AuditDatabase _db;
  $AuditDatabaseManager(this._db);
  $$AuditSessionsTableTableManager get auditSessions =>
      $$AuditSessionsTableTableManager(_db, _db.auditSessions);
  $$AuditEventsTableTableManager get auditEvents =>
      $$AuditEventsTableTableManager(_db, _db.auditEvents);
  $$AuditFileOpsTableTableManager get auditFileOps =>
      $$AuditFileOpsTableTableManager(_db, _db.auditFileOps);
  $$AuditBackupsTableTableManager get auditBackups =>
      $$AuditBackupsTableTableManager(_db, _db.auditBackups);
  $$AuditSshCommandsTableTableManager get auditSshCommands =>
      $$AuditSshCommandsTableTableManager(_db, _db.auditSshCommands);
  $$AuditErrorsTableTableManager get auditErrors =>
      $$AuditErrorsTableTableManager(_db, _db.auditErrors);
}
