// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Discovered _$DiscoveredFromJson(Map<String, dynamic> json) => _Discovered(
  os: json['os'] as String?,
  serviceKind: json['serviceKind'] == null
      ? null
      : ServiceKind.fromJson(json['serviceKind'] as Map<String, dynamic>),
  worldsPath: json['worldsPath'] as String?,
  steamUser: json['steamUser'] as String?,
  launchScript: json['launchScript'] as String?,
  probedAt: json['probedAt'] as String,
);

Map<String, dynamic> _$DiscoveredToJson(_Discovered instance) =>
    <String, dynamic>{
      'os': instance.os,
      'serviceKind': instance.serviceKind?.toJson(),
      'worldsPath': instance.worldsPath,
      'steamUser': instance.steamUser,
      'launchScript': instance.launchScript,
      'probedAt': instance.probedAt,
    };

_Profile _$ProfileFromJson(Map<String, dynamic> json) => _Profile(
  id: json['id'] as String,
  name: json['name'] as String,
  host: json['host'] as String,
  port: (json['port'] as num?)?.toInt() ?? 22,
  user: json['user'] as String,
  auth: $enumDecode(_$AuthMethodEnumMap, json['auth']),
  keyPath: json['keyPath'] as String?,
  savePassword: json['savePassword'] as bool? ?? false,
  discovered: json['discovered'] == null
      ? null
      : Discovered.fromJson(json['discovered'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ProfileToJson(_Profile instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'host': instance.host,
  'port': instance.port,
  'user': instance.user,
  'auth': _$AuthMethodEnumMap[instance.auth]!,
  'keyPath': ?instance.keyPath,
  'savePassword': instance.savePassword,
  'discovered': ?instance.discovered?.toJson(),
};

const _$AuthMethodEnumMap = {
  AuthMethod.key: 'key',
  AuthMethod.password: 'password',
};

_WorldDetection _$WorldDetectionFromJson(Map<String, dynamic> json) =>
    _WorldDetection(
      patterns:
          (json['patterns'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>['*.world.gzip'],
    );

Map<String, dynamic> _$WorldDetectionToJson(_WorldDetection instance) =>
    <String, dynamic>{'patterns': instance.patterns};

_AppConfig _$AppConfigFromJson(Map<String, dynamic> json) => _AppConfig(
  profiles:
      (json['profiles'] as List<dynamic>?)
          ?.map((e) => Profile.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Profile>[],
  worldDetection: json['worldDetection'] == null
      ? const WorldDetection()
      : WorldDetection.fromJson(json['worldDetection'] as Map<String, dynamic>),
  activeProfileId: json['activeProfileId'] as String?,
);

Map<String, dynamic> _$AppConfigToJson(_AppConfig instance) =>
    <String, dynamic>{
      'profiles': instance.profiles.map((e) => e.toJson()).toList(),
      'worldDetection': instance.worldDetection.toJson(),
      'activeProfileId': instance.activeProfileId,
    };
