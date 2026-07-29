// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Discovered {

 String? get os; ServiceKind? get serviceKind; String? get worldsPath;/// The user the game server runs as, for `chown` on systemd targets.
 String? get steamUser; String? get launchScript;/// ISO-8601 / RFC-3339 UTC timestamp of the probe.
 String get probedAt;
/// Create a copy of Discovered
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiscoveredCopyWith<Discovered> get copyWith => _$DiscoveredCopyWithImpl<Discovered>(this as Discovered, _$identity);

  /// Serializes this Discovered to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Discovered&&(identical(other.os, os) || other.os == os)&&(identical(other.serviceKind, serviceKind) || other.serviceKind == serviceKind)&&(identical(other.worldsPath, worldsPath) || other.worldsPath == worldsPath)&&(identical(other.steamUser, steamUser) || other.steamUser == steamUser)&&(identical(other.launchScript, launchScript) || other.launchScript == launchScript)&&(identical(other.probedAt, probedAt) || other.probedAt == probedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,os,serviceKind,worldsPath,steamUser,launchScript,probedAt);

@override
String toString() {
  return 'Discovered(os: $os, serviceKind: $serviceKind, worldsPath: $worldsPath, steamUser: $steamUser, launchScript: $launchScript, probedAt: $probedAt)';
}


}

/// @nodoc
abstract mixin class $DiscoveredCopyWith<$Res>  {
  factory $DiscoveredCopyWith(Discovered value, $Res Function(Discovered) _then) = _$DiscoveredCopyWithImpl;
@useResult
$Res call({
 String? os, ServiceKind? serviceKind, String? worldsPath, String? steamUser, String? launchScript, String probedAt
});




}
/// @nodoc
class _$DiscoveredCopyWithImpl<$Res>
    implements $DiscoveredCopyWith<$Res> {
  _$DiscoveredCopyWithImpl(this._self, this._then);

  final Discovered _self;
  final $Res Function(Discovered) _then;

/// Create a copy of Discovered
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? os = freezed,Object? serviceKind = freezed,Object? worldsPath = freezed,Object? steamUser = freezed,Object? launchScript = freezed,Object? probedAt = null,}) {
  return _then(_self.copyWith(
os: freezed == os ? _self.os : os // ignore: cast_nullable_to_non_nullable
as String?,serviceKind: freezed == serviceKind ? _self.serviceKind : serviceKind // ignore: cast_nullable_to_non_nullable
as ServiceKind?,worldsPath: freezed == worldsPath ? _self.worldsPath : worldsPath // ignore: cast_nullable_to_non_nullable
as String?,steamUser: freezed == steamUser ? _self.steamUser : steamUser // ignore: cast_nullable_to_non_nullable
as String?,launchScript: freezed == launchScript ? _self.launchScript : launchScript // ignore: cast_nullable_to_non_nullable
as String?,probedAt: null == probedAt ? _self.probedAt : probedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Discovered].
extension DiscoveredPatterns on Discovered {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Discovered value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Discovered() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Discovered value)  $default,){
final _that = this;
switch (_that) {
case _Discovered():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Discovered value)?  $default,){
final _that = this;
switch (_that) {
case _Discovered() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? os,  ServiceKind? serviceKind,  String? worldsPath,  String? steamUser,  String? launchScript,  String probedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Discovered() when $default != null:
return $default(_that.os,_that.serviceKind,_that.worldsPath,_that.steamUser,_that.launchScript,_that.probedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? os,  ServiceKind? serviceKind,  String? worldsPath,  String? steamUser,  String? launchScript,  String probedAt)  $default,) {final _that = this;
switch (_that) {
case _Discovered():
return $default(_that.os,_that.serviceKind,_that.worldsPath,_that.steamUser,_that.launchScript,_that.probedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? os,  ServiceKind? serviceKind,  String? worldsPath,  String? steamUser,  String? launchScript,  String probedAt)?  $default,) {final _that = this;
switch (_that) {
case _Discovered() when $default != null:
return $default(_that.os,_that.serviceKind,_that.worldsPath,_that.steamUser,_that.launchScript,_that.probedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Discovered implements Discovered {
  const _Discovered({this.os, this.serviceKind, this.worldsPath, this.steamUser, this.launchScript, required this.probedAt});
  factory _Discovered.fromJson(Map<String, dynamic> json) => _$DiscoveredFromJson(json);

@override final  String? os;
@override final  ServiceKind? serviceKind;
@override final  String? worldsPath;
/// The user the game server runs as, for `chown` on systemd targets.
@override final  String? steamUser;
@override final  String? launchScript;
/// ISO-8601 / RFC-3339 UTC timestamp of the probe.
@override final  String probedAt;

/// Create a copy of Discovered
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiscoveredCopyWith<_Discovered> get copyWith => __$DiscoveredCopyWithImpl<_Discovered>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DiscoveredToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Discovered&&(identical(other.os, os) || other.os == os)&&(identical(other.serviceKind, serviceKind) || other.serviceKind == serviceKind)&&(identical(other.worldsPath, worldsPath) || other.worldsPath == worldsPath)&&(identical(other.steamUser, steamUser) || other.steamUser == steamUser)&&(identical(other.launchScript, launchScript) || other.launchScript == launchScript)&&(identical(other.probedAt, probedAt) || other.probedAt == probedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,os,serviceKind,worldsPath,steamUser,launchScript,probedAt);

@override
String toString() {
  return 'Discovered(os: $os, serviceKind: $serviceKind, worldsPath: $worldsPath, steamUser: $steamUser, launchScript: $launchScript, probedAt: $probedAt)';
}


}

/// @nodoc
abstract mixin class _$DiscoveredCopyWith<$Res> implements $DiscoveredCopyWith<$Res> {
  factory _$DiscoveredCopyWith(_Discovered value, $Res Function(_Discovered) _then) = __$DiscoveredCopyWithImpl;
@override @useResult
$Res call({
 String? os, ServiceKind? serviceKind, String? worldsPath, String? steamUser, String? launchScript, String probedAt
});




}
/// @nodoc
class __$DiscoveredCopyWithImpl<$Res>
    implements _$DiscoveredCopyWith<$Res> {
  __$DiscoveredCopyWithImpl(this._self, this._then);

  final _Discovered _self;
  final $Res Function(_Discovered) _then;

/// Create a copy of Discovered
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? os = freezed,Object? serviceKind = freezed,Object? worldsPath = freezed,Object? steamUser = freezed,Object? launchScript = freezed,Object? probedAt = null,}) {
  return _then(_Discovered(
os: freezed == os ? _self.os : os // ignore: cast_nullable_to_non_nullable
as String?,serviceKind: freezed == serviceKind ? _self.serviceKind : serviceKind // ignore: cast_nullable_to_non_nullable
as ServiceKind?,worldsPath: freezed == worldsPath ? _self.worldsPath : worldsPath // ignore: cast_nullable_to_non_nullable
as String?,steamUser: freezed == steamUser ? _self.steamUser : steamUser // ignore: cast_nullable_to_non_nullable
as String?,launchScript: freezed == launchScript ? _self.launchScript : launchScript // ignore: cast_nullable_to_non_nullable
as String?,probedAt: null == probedAt ? _self.probedAt : probedAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$Profile {

 String get id; String get name; String get host;/// Rust: `#[serde(default = "default_port")]`.
 int get port; String get user; AuthMethod get auth;/// Rust: `skip_serializing_if = "Option::is_none"` — omitted, not null.
@JsonKey(includeIfNull: false) String? get keyPath;/// Rust: `#[serde(default)]`.
 bool get savePassword;/// Rust: `skip_serializing_if = "Option::is_none"` — omitted, not null.
@JsonKey(includeIfNull: false) Discovered? get discovered;
/// Create a copy of Profile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileCopyWith<Profile> get copyWith => _$ProfileCopyWithImpl<Profile>(this as Profile, _$identity);

  /// Serializes this Profile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Profile&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.host, host) || other.host == host)&&(identical(other.port, port) || other.port == port)&&(identical(other.user, user) || other.user == user)&&(identical(other.auth, auth) || other.auth == auth)&&(identical(other.keyPath, keyPath) || other.keyPath == keyPath)&&(identical(other.savePassword, savePassword) || other.savePassword == savePassword)&&(identical(other.discovered, discovered) || other.discovered == discovered));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,host,port,user,auth,keyPath,savePassword,discovered);

@override
String toString() {
  return 'Profile(id: $id, name: $name, host: $host, port: $port, user: $user, auth: $auth, keyPath: $keyPath, savePassword: $savePassword, discovered: $discovered)';
}


}

/// @nodoc
abstract mixin class $ProfileCopyWith<$Res>  {
  factory $ProfileCopyWith(Profile value, $Res Function(Profile) _then) = _$ProfileCopyWithImpl;
@useResult
$Res call({
 String id, String name, String host, int port, String user, AuthMethod auth,@JsonKey(includeIfNull: false) String? keyPath, bool savePassword,@JsonKey(includeIfNull: false) Discovered? discovered
});


$DiscoveredCopyWith<$Res>? get discovered;

}
/// @nodoc
class _$ProfileCopyWithImpl<$Res>
    implements $ProfileCopyWith<$Res> {
  _$ProfileCopyWithImpl(this._self, this._then);

  final Profile _self;
  final $Res Function(Profile) _then;

/// Create a copy of Profile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? host = null,Object? port = null,Object? user = null,Object? auth = null,Object? keyPath = freezed,Object? savePassword = null,Object? discovered = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as String,auth: null == auth ? _self.auth : auth // ignore: cast_nullable_to_non_nullable
as AuthMethod,keyPath: freezed == keyPath ? _self.keyPath : keyPath // ignore: cast_nullable_to_non_nullable
as String?,savePassword: null == savePassword ? _self.savePassword : savePassword // ignore: cast_nullable_to_non_nullable
as bool,discovered: freezed == discovered ? _self.discovered : discovered // ignore: cast_nullable_to_non_nullable
as Discovered?,
  ));
}
/// Create a copy of Profile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DiscoveredCopyWith<$Res>? get discovered {
    if (_self.discovered == null) {
    return null;
  }

  return $DiscoveredCopyWith<$Res>(_self.discovered!, (value) {
    return _then(_self.copyWith(discovered: value));
  });
}
}


/// Adds pattern-matching-related methods to [Profile].
extension ProfilePatterns on Profile {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Profile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Profile() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Profile value)  $default,){
final _that = this;
switch (_that) {
case _Profile():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Profile value)?  $default,){
final _that = this;
switch (_that) {
case _Profile() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String host,  int port,  String user,  AuthMethod auth, @JsonKey(includeIfNull: false)  String? keyPath,  bool savePassword, @JsonKey(includeIfNull: false)  Discovered? discovered)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Profile() when $default != null:
return $default(_that.id,_that.name,_that.host,_that.port,_that.user,_that.auth,_that.keyPath,_that.savePassword,_that.discovered);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String host,  int port,  String user,  AuthMethod auth, @JsonKey(includeIfNull: false)  String? keyPath,  bool savePassword, @JsonKey(includeIfNull: false)  Discovered? discovered)  $default,) {final _that = this;
switch (_that) {
case _Profile():
return $default(_that.id,_that.name,_that.host,_that.port,_that.user,_that.auth,_that.keyPath,_that.savePassword,_that.discovered);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String host,  int port,  String user,  AuthMethod auth, @JsonKey(includeIfNull: false)  String? keyPath,  bool savePassword, @JsonKey(includeIfNull: false)  Discovered? discovered)?  $default,) {final _that = this;
switch (_that) {
case _Profile() when $default != null:
return $default(_that.id,_that.name,_that.host,_that.port,_that.user,_that.auth,_that.keyPath,_that.savePassword,_that.discovered);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Profile implements Profile {
  const _Profile({required this.id, required this.name, required this.host, this.port = 22, required this.user, required this.auth, @JsonKey(includeIfNull: false) this.keyPath, this.savePassword = false, @JsonKey(includeIfNull: false) this.discovered});
  factory _Profile.fromJson(Map<String, dynamic> json) => _$ProfileFromJson(json);

@override final  String id;
@override final  String name;
@override final  String host;
/// Rust: `#[serde(default = "default_port")]`.
@override@JsonKey() final  int port;
@override final  String user;
@override final  AuthMethod auth;
/// Rust: `skip_serializing_if = "Option::is_none"` — omitted, not null.
@override@JsonKey(includeIfNull: false) final  String? keyPath;
/// Rust: `#[serde(default)]`.
@override@JsonKey() final  bool savePassword;
/// Rust: `skip_serializing_if = "Option::is_none"` — omitted, not null.
@override@JsonKey(includeIfNull: false) final  Discovered? discovered;

/// Create a copy of Profile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileCopyWith<_Profile> get copyWith => __$ProfileCopyWithImpl<_Profile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Profile&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.host, host) || other.host == host)&&(identical(other.port, port) || other.port == port)&&(identical(other.user, user) || other.user == user)&&(identical(other.auth, auth) || other.auth == auth)&&(identical(other.keyPath, keyPath) || other.keyPath == keyPath)&&(identical(other.savePassword, savePassword) || other.savePassword == savePassword)&&(identical(other.discovered, discovered) || other.discovered == discovered));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,host,port,user,auth,keyPath,savePassword,discovered);

@override
String toString() {
  return 'Profile(id: $id, name: $name, host: $host, port: $port, user: $user, auth: $auth, keyPath: $keyPath, savePassword: $savePassword, discovered: $discovered)';
}


}

/// @nodoc
abstract mixin class _$ProfileCopyWith<$Res> implements $ProfileCopyWith<$Res> {
  factory _$ProfileCopyWith(_Profile value, $Res Function(_Profile) _then) = __$ProfileCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String host, int port, String user, AuthMethod auth,@JsonKey(includeIfNull: false) String? keyPath, bool savePassword,@JsonKey(includeIfNull: false) Discovered? discovered
});


@override $DiscoveredCopyWith<$Res>? get discovered;

}
/// @nodoc
class __$ProfileCopyWithImpl<$Res>
    implements _$ProfileCopyWith<$Res> {
  __$ProfileCopyWithImpl(this._self, this._then);

  final _Profile _self;
  final $Res Function(_Profile) _then;

/// Create a copy of Profile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? host = null,Object? port = null,Object? user = null,Object? auth = null,Object? keyPath = freezed,Object? savePassword = null,Object? discovered = freezed,}) {
  return _then(_Profile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,user: null == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as String,auth: null == auth ? _self.auth : auth // ignore: cast_nullable_to_non_nullable
as AuthMethod,keyPath: freezed == keyPath ? _self.keyPath : keyPath // ignore: cast_nullable_to_non_nullable
as String?,savePassword: null == savePassword ? _self.savePassword : savePassword // ignore: cast_nullable_to_non_nullable
as bool,discovered: freezed == discovered ? _self.discovered : discovered // ignore: cast_nullable_to_non_nullable
as Discovered?,
  ));
}

/// Create a copy of Profile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DiscoveredCopyWith<$Res>? get discovered {
    if (_self.discovered == null) {
    return null;
  }

  return $DiscoveredCopyWith<$Res>(_self.discovered!, (value) {
    return _then(_self.copyWith(discovered: value));
  });
}
}


/// @nodoc
mixin _$WorldDetection {

 List<String> get patterns;
/// Create a copy of WorldDetection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorldDetectionCopyWith<WorldDetection> get copyWith => _$WorldDetectionCopyWithImpl<WorldDetection>(this as WorldDetection, _$identity);

  /// Serializes this WorldDetection to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorldDetection&&const DeepCollectionEquality().equals(other.patterns, patterns));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(patterns));

@override
String toString() {
  return 'WorldDetection(patterns: $patterns)';
}


}

/// @nodoc
abstract mixin class $WorldDetectionCopyWith<$Res>  {
  factory $WorldDetectionCopyWith(WorldDetection value, $Res Function(WorldDetection) _then) = _$WorldDetectionCopyWithImpl;
@useResult
$Res call({
 List<String> patterns
});




}
/// @nodoc
class _$WorldDetectionCopyWithImpl<$Res>
    implements $WorldDetectionCopyWith<$Res> {
  _$WorldDetectionCopyWithImpl(this._self, this._then);

  final WorldDetection _self;
  final $Res Function(WorldDetection) _then;

/// Create a copy of WorldDetection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? patterns = null,}) {
  return _then(_self.copyWith(
patterns: null == patterns ? _self.patterns : patterns // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [WorldDetection].
extension WorldDetectionPatterns on WorldDetection {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorldDetection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorldDetection() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorldDetection value)  $default,){
final _that = this;
switch (_that) {
case _WorldDetection():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorldDetection value)?  $default,){
final _that = this;
switch (_that) {
case _WorldDetection() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String> patterns)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorldDetection() when $default != null:
return $default(_that.patterns);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String> patterns)  $default,) {final _that = this;
switch (_that) {
case _WorldDetection():
return $default(_that.patterns);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String> patterns)?  $default,) {final _that = this;
switch (_that) {
case _WorldDetection() when $default != null:
return $default(_that.patterns);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WorldDetection implements WorldDetection {
  const _WorldDetection({final  List<String> patterns = const <String>['*.world.gzip']}): _patterns = patterns;
  factory _WorldDetection.fromJson(Map<String, dynamic> json) => _$WorldDetectionFromJson(json);

 final  List<String> _patterns;
@override@JsonKey() List<String> get patterns {
  if (_patterns is EqualUnmodifiableListView) return _patterns;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_patterns);
}


/// Create a copy of WorldDetection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorldDetectionCopyWith<_WorldDetection> get copyWith => __$WorldDetectionCopyWithImpl<_WorldDetection>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WorldDetectionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorldDetection&&const DeepCollectionEquality().equals(other._patterns, _patterns));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_patterns));

@override
String toString() {
  return 'WorldDetection(patterns: $patterns)';
}


}

/// @nodoc
abstract mixin class _$WorldDetectionCopyWith<$Res> implements $WorldDetectionCopyWith<$Res> {
  factory _$WorldDetectionCopyWith(_WorldDetection value, $Res Function(_WorldDetection) _then) = __$WorldDetectionCopyWithImpl;
@override @useResult
$Res call({
 List<String> patterns
});




}
/// @nodoc
class __$WorldDetectionCopyWithImpl<$Res>
    implements _$WorldDetectionCopyWith<$Res> {
  __$WorldDetectionCopyWithImpl(this._self, this._then);

  final _WorldDetection _self;
  final $Res Function(_WorldDetection) _then;

/// Create a copy of WorldDetection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? patterns = null,}) {
  return _then(_WorldDetection(
patterns: null == patterns ? _self._patterns : patterns // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$AppConfig {

/// Rust: `#[serde(default)]`.
 List<Profile> get profiles;/// Rust: `#[serde(default)]`.
 WorldDetection get worldDetection;/// No skip-if-none in Rust, so this is written as an explicit `null`.
 String? get activeProfileId;
/// Create a copy of AppConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppConfigCopyWith<AppConfig> get copyWith => _$AppConfigCopyWithImpl<AppConfig>(this as AppConfig, _$identity);

  /// Serializes this AppConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppConfig&&const DeepCollectionEquality().equals(other.profiles, profiles)&&(identical(other.worldDetection, worldDetection) || other.worldDetection == worldDetection)&&(identical(other.activeProfileId, activeProfileId) || other.activeProfileId == activeProfileId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(profiles),worldDetection,activeProfileId);

@override
String toString() {
  return 'AppConfig(profiles: $profiles, worldDetection: $worldDetection, activeProfileId: $activeProfileId)';
}


}

/// @nodoc
abstract mixin class $AppConfigCopyWith<$Res>  {
  factory $AppConfigCopyWith(AppConfig value, $Res Function(AppConfig) _then) = _$AppConfigCopyWithImpl;
@useResult
$Res call({
 List<Profile> profiles, WorldDetection worldDetection, String? activeProfileId
});


$WorldDetectionCopyWith<$Res> get worldDetection;

}
/// @nodoc
class _$AppConfigCopyWithImpl<$Res>
    implements $AppConfigCopyWith<$Res> {
  _$AppConfigCopyWithImpl(this._self, this._then);

  final AppConfig _self;
  final $Res Function(AppConfig) _then;

/// Create a copy of AppConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? profiles = null,Object? worldDetection = null,Object? activeProfileId = freezed,}) {
  return _then(_self.copyWith(
profiles: null == profiles ? _self.profiles : profiles // ignore: cast_nullable_to_non_nullable
as List<Profile>,worldDetection: null == worldDetection ? _self.worldDetection : worldDetection // ignore: cast_nullable_to_non_nullable
as WorldDetection,activeProfileId: freezed == activeProfileId ? _self.activeProfileId : activeProfileId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of AppConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorldDetectionCopyWith<$Res> get worldDetection {
  
  return $WorldDetectionCopyWith<$Res>(_self.worldDetection, (value) {
    return _then(_self.copyWith(worldDetection: value));
  });
}
}


/// Adds pattern-matching-related methods to [AppConfig].
extension AppConfigPatterns on AppConfig {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppConfig() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppConfig value)  $default,){
final _that = this;
switch (_that) {
case _AppConfig():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppConfig value)?  $default,){
final _that = this;
switch (_that) {
case _AppConfig() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Profile> profiles,  WorldDetection worldDetection,  String? activeProfileId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppConfig() when $default != null:
return $default(_that.profiles,_that.worldDetection,_that.activeProfileId);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Profile> profiles,  WorldDetection worldDetection,  String? activeProfileId)  $default,) {final _that = this;
switch (_that) {
case _AppConfig():
return $default(_that.profiles,_that.worldDetection,_that.activeProfileId);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Profile> profiles,  WorldDetection worldDetection,  String? activeProfileId)?  $default,) {final _that = this;
switch (_that) {
case _AppConfig() when $default != null:
return $default(_that.profiles,_that.worldDetection,_that.activeProfileId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppConfig extends AppConfig {
  const _AppConfig({final  List<Profile> profiles = const <Profile>[], this.worldDetection = const WorldDetection(), this.activeProfileId}): _profiles = profiles,super._();
  factory _AppConfig.fromJson(Map<String, dynamic> json) => _$AppConfigFromJson(json);

/// Rust: `#[serde(default)]`.
 final  List<Profile> _profiles;
/// Rust: `#[serde(default)]`.
@override@JsonKey() List<Profile> get profiles {
  if (_profiles is EqualUnmodifiableListView) return _profiles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_profiles);
}

/// Rust: `#[serde(default)]`.
@override@JsonKey() final  WorldDetection worldDetection;
/// No skip-if-none in Rust, so this is written as an explicit `null`.
@override final  String? activeProfileId;

/// Create a copy of AppConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppConfigCopyWith<_AppConfig> get copyWith => __$AppConfigCopyWithImpl<_AppConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppConfig&&const DeepCollectionEquality().equals(other._profiles, _profiles)&&(identical(other.worldDetection, worldDetection) || other.worldDetection == worldDetection)&&(identical(other.activeProfileId, activeProfileId) || other.activeProfileId == activeProfileId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_profiles),worldDetection,activeProfileId);

@override
String toString() {
  return 'AppConfig(profiles: $profiles, worldDetection: $worldDetection, activeProfileId: $activeProfileId)';
}


}

/// @nodoc
abstract mixin class _$AppConfigCopyWith<$Res> implements $AppConfigCopyWith<$Res> {
  factory _$AppConfigCopyWith(_AppConfig value, $Res Function(_AppConfig) _then) = __$AppConfigCopyWithImpl;
@override @useResult
$Res call({
 List<Profile> profiles, WorldDetection worldDetection, String? activeProfileId
});


@override $WorldDetectionCopyWith<$Res> get worldDetection;

}
/// @nodoc
class __$AppConfigCopyWithImpl<$Res>
    implements _$AppConfigCopyWith<$Res> {
  __$AppConfigCopyWithImpl(this._self, this._then);

  final _AppConfig _self;
  final $Res Function(_AppConfig) _then;

/// Create a copy of AppConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? profiles = null,Object? worldDetection = null,Object? activeProfileId = freezed,}) {
  return _then(_AppConfig(
profiles: null == profiles ? _self._profiles : profiles // ignore: cast_nullable_to_non_nullable
as List<Profile>,worldDetection: null == worldDetection ? _self.worldDetection : worldDetection // ignore: cast_nullable_to_non_nullable
as WorldDetection,activeProfileId: freezed == activeProfileId ? _self.activeProfileId : activeProfileId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of AppConfig
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WorldDetectionCopyWith<$Res> get worldDetection {
  
  return $WorldDetectionCopyWith<$Res>(_self.worldDetection, (value) {
    return _then(_self.copyWith(worldDetection: value));
  });
}
}

// dart format on
