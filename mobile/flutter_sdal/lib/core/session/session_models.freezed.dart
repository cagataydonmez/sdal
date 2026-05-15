// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OAuthProviderLink {

@JsonKey(fromJson: readRequiredText) String get provider;@JsonKey(fromJson: readRequiredText) String get title;@JsonKey(fromJson: readRequiredText) String get startUrl;@JsonKey(fromJson: readRequiredBool) bool get enabled;
/// Create a copy of OAuthProviderLink
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OAuthProviderLinkCopyWith<OAuthProviderLink> get copyWith => _$OAuthProviderLinkCopyWithImpl<OAuthProviderLink>(this as OAuthProviderLink, _$identity);

  /// Serializes this OAuthProviderLink to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OAuthProviderLink&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.title, title) || other.title == title)&&(identical(other.startUrl, startUrl) || other.startUrl == startUrl)&&(identical(other.enabled, enabled) || other.enabled == enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,provider,title,startUrl,enabled);

@override
String toString() {
  return 'OAuthProviderLink(provider: $provider, title: $title, startUrl: $startUrl, enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class $OAuthProviderLinkCopyWith<$Res>  {
  factory $OAuthProviderLinkCopyWith(OAuthProviderLink value, $Res Function(OAuthProviderLink) _then) = _$OAuthProviderLinkCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: readRequiredText) String provider,@JsonKey(fromJson: readRequiredText) String title,@JsonKey(fromJson: readRequiredText) String startUrl,@JsonKey(fromJson: readRequiredBool) bool enabled
});




}
/// @nodoc
class _$OAuthProviderLinkCopyWithImpl<$Res>
    implements $OAuthProviderLinkCopyWith<$Res> {
  _$OAuthProviderLinkCopyWithImpl(this._self, this._then);

  final OAuthProviderLink _self;
  final $Res Function(OAuthProviderLink) _then;

/// Create a copy of OAuthProviderLink
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? provider = null,Object? title = null,Object? startUrl = null,Object? enabled = null,}) {
  return _then(_self.copyWith(
provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,startUrl: null == startUrl ? _self.startUrl : startUrl // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [OAuthProviderLink].
extension OAuthProviderLinkPatterns on OAuthProviderLink {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OAuthProviderLink value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OAuthProviderLink() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OAuthProviderLink value)  $default,){
final _that = this;
switch (_that) {
case _OAuthProviderLink():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OAuthProviderLink value)?  $default,){
final _that = this;
switch (_that) {
case _OAuthProviderLink() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredText)  String provider, @JsonKey(fromJson: readRequiredText)  String title, @JsonKey(fromJson: readRequiredText)  String startUrl, @JsonKey(fromJson: readRequiredBool)  bool enabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OAuthProviderLink() when $default != null:
return $default(_that.provider,_that.title,_that.startUrl,_that.enabled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredText)  String provider, @JsonKey(fromJson: readRequiredText)  String title, @JsonKey(fromJson: readRequiredText)  String startUrl, @JsonKey(fromJson: readRequiredBool)  bool enabled)  $default,) {final _that = this;
switch (_that) {
case _OAuthProviderLink():
return $default(_that.provider,_that.title,_that.startUrl,_that.enabled);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: readRequiredText)  String provider, @JsonKey(fromJson: readRequiredText)  String title, @JsonKey(fromJson: readRequiredText)  String startUrl, @JsonKey(fromJson: readRequiredBool)  bool enabled)?  $default,) {final _that = this;
switch (_that) {
case _OAuthProviderLink() when $default != null:
return $default(_that.provider,_that.title,_that.startUrl,_that.enabled);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OAuthProviderLink implements OAuthProviderLink {
  const _OAuthProviderLink({@JsonKey(fromJson: readRequiredText) required this.provider, @JsonKey(fromJson: readRequiredText) required this.title, @JsonKey(fromJson: readRequiredText) required this.startUrl, @JsonKey(fromJson: readRequiredBool) required this.enabled});
  factory _OAuthProviderLink.fromJson(Map<String, dynamic> json) => _$OAuthProviderLinkFromJson(json);

@override@JsonKey(fromJson: readRequiredText) final  String provider;
@override@JsonKey(fromJson: readRequiredText) final  String title;
@override@JsonKey(fromJson: readRequiredText) final  String startUrl;
@override@JsonKey(fromJson: readRequiredBool) final  bool enabled;

/// Create a copy of OAuthProviderLink
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OAuthProviderLinkCopyWith<_OAuthProviderLink> get copyWith => __$OAuthProviderLinkCopyWithImpl<_OAuthProviderLink>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OAuthProviderLinkToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OAuthProviderLink&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.title, title) || other.title == title)&&(identical(other.startUrl, startUrl) || other.startUrl == startUrl)&&(identical(other.enabled, enabled) || other.enabled == enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,provider,title,startUrl,enabled);

@override
String toString() {
  return 'OAuthProviderLink(provider: $provider, title: $title, startUrl: $startUrl, enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class _$OAuthProviderLinkCopyWith<$Res> implements $OAuthProviderLinkCopyWith<$Res> {
  factory _$OAuthProviderLinkCopyWith(_OAuthProviderLink value, $Res Function(_OAuthProviderLink) _then) = __$OAuthProviderLinkCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: readRequiredText) String provider,@JsonKey(fromJson: readRequiredText) String title,@JsonKey(fromJson: readRequiredText) String startUrl,@JsonKey(fromJson: readRequiredBool) bool enabled
});




}
/// @nodoc
class __$OAuthProviderLinkCopyWithImpl<$Res>
    implements _$OAuthProviderLinkCopyWith<$Res> {
  __$OAuthProviderLinkCopyWithImpl(this._self, this._then);

  final _OAuthProviderLink _self;
  final $Res Function(_OAuthProviderLink) _then;

/// Create a copy of OAuthProviderLink
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? provider = null,Object? title = null,Object? startUrl = null,Object? enabled = null,}) {
  return _then(_OAuthProviderLink(
provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,startUrl: null == startUrl ? _self.startUrl : startUrl // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$SessionUser {

@JsonKey(fromJson: readRequiredInt) int get id;@JsonKey(fromJson: readRequiredText) String get kadi;@JsonKey(fromJson: readRequiredText) String get isim;@JsonKey(fromJson: readRequiredText) String get soyisim;@JsonKey(fromJson: readRequiredText) String get photo;@JsonKey(fromJson: readRequiredText) String get role;@JsonKey(name: 'admin', fromJson: readRequiredBool) bool get isAdmin;@JsonKey(name: 'verified', fromJson: readRequiredBool) bool get isVerified;@JsonKey(name: 'banned', fromJson: readRequiredBool) bool get isBanned;@JsonKey(fromJson: readRequiredText) String get state;@JsonKey(fromJson: readOptionalText) String? get graduationYear;@JsonKey(fromJson: readOptionalText) String? get oauthProvider;
/// Create a copy of SessionUser
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionUserCopyWith<SessionUser> get copyWith => _$SessionUserCopyWithImpl<SessionUser>(this as SessionUser, _$identity);

  /// Serializes this SessionUser to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionUser&&(identical(other.id, id) || other.id == id)&&(identical(other.kadi, kadi) || other.kadi == kadi)&&(identical(other.isim, isim) || other.isim == isim)&&(identical(other.soyisim, soyisim) || other.soyisim == soyisim)&&(identical(other.photo, photo) || other.photo == photo)&&(identical(other.role, role) || other.role == role)&&(identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.isBanned, isBanned) || other.isBanned == isBanned)&&(identical(other.state, state) || other.state == state)&&(identical(other.graduationYear, graduationYear) || other.graduationYear == graduationYear)&&(identical(other.oauthProvider, oauthProvider) || other.oauthProvider == oauthProvider));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kadi,isim,soyisim,photo,role,isAdmin,isVerified,isBanned,state,graduationYear,oauthProvider);

@override
String toString() {
  return 'SessionUser(id: $id, kadi: $kadi, isim: $isim, soyisim: $soyisim, photo: $photo, role: $role, isAdmin: $isAdmin, isVerified: $isVerified, isBanned: $isBanned, state: $state, graduationYear: $graduationYear, oauthProvider: $oauthProvider)';
}


}

/// @nodoc
abstract mixin class $SessionUserCopyWith<$Res>  {
  factory $SessionUserCopyWith(SessionUser value, $Res Function(SessionUser) _then) = _$SessionUserCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: readRequiredInt) int id,@JsonKey(fromJson: readRequiredText) String kadi,@JsonKey(fromJson: readRequiredText) String isim,@JsonKey(fromJson: readRequiredText) String soyisim,@JsonKey(fromJson: readRequiredText) String photo,@JsonKey(fromJson: readRequiredText) String role,@JsonKey(name: 'admin', fromJson: readRequiredBool) bool isAdmin,@JsonKey(name: 'verified', fromJson: readRequiredBool) bool isVerified,@JsonKey(name: 'banned', fromJson: readRequiredBool) bool isBanned,@JsonKey(fromJson: readRequiredText) String state,@JsonKey(fromJson: readOptionalText) String? graduationYear,@JsonKey(fromJson: readOptionalText) String? oauthProvider
});




}
/// @nodoc
class _$SessionUserCopyWithImpl<$Res>
    implements $SessionUserCopyWith<$Res> {
  _$SessionUserCopyWithImpl(this._self, this._then);

  final SessionUser _self;
  final $Res Function(SessionUser) _then;

/// Create a copy of SessionUser
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kadi = null,Object? isim = null,Object? soyisim = null,Object? photo = null,Object? role = null,Object? isAdmin = null,Object? isVerified = null,Object? isBanned = null,Object? state = null,Object? graduationYear = freezed,Object? oauthProvider = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,kadi: null == kadi ? _self.kadi : kadi // ignore: cast_nullable_to_non_nullable
as String,isim: null == isim ? _self.isim : isim // ignore: cast_nullable_to_non_nullable
as String,soyisim: null == soyisim ? _self.soyisim : soyisim // ignore: cast_nullable_to_non_nullable
as String,photo: null == photo ? _self.photo : photo // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,isAdmin: null == isAdmin ? _self.isAdmin : isAdmin // ignore: cast_nullable_to_non_nullable
as bool,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,isBanned: null == isBanned ? _self.isBanned : isBanned // ignore: cast_nullable_to_non_nullable
as bool,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,graduationYear: freezed == graduationYear ? _self.graduationYear : graduationYear // ignore: cast_nullable_to_non_nullable
as String?,oauthProvider: freezed == oauthProvider ? _self.oauthProvider : oauthProvider // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SessionUser].
extension SessionUserPatterns on SessionUser {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionUser value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionUser() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionUser value)  $default,){
final _that = this;
switch (_that) {
case _SessionUser():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionUser value)?  $default,){
final _that = this;
switch (_that) {
case _SessionUser() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredInt)  int id, @JsonKey(fromJson: readRequiredText)  String kadi, @JsonKey(fromJson: readRequiredText)  String isim, @JsonKey(fromJson: readRequiredText)  String soyisim, @JsonKey(fromJson: readRequiredText)  String photo, @JsonKey(fromJson: readRequiredText)  String role, @JsonKey(name: 'admin', fromJson: readRequiredBool)  bool isAdmin, @JsonKey(name: 'verified', fromJson: readRequiredBool)  bool isVerified, @JsonKey(name: 'banned', fromJson: readRequiredBool)  bool isBanned, @JsonKey(fromJson: readRequiredText)  String state, @JsonKey(fromJson: readOptionalText)  String? graduationYear, @JsonKey(fromJson: readOptionalText)  String? oauthProvider)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionUser() when $default != null:
return $default(_that.id,_that.kadi,_that.isim,_that.soyisim,_that.photo,_that.role,_that.isAdmin,_that.isVerified,_that.isBanned,_that.state,_that.graduationYear,_that.oauthProvider);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredInt)  int id, @JsonKey(fromJson: readRequiredText)  String kadi, @JsonKey(fromJson: readRequiredText)  String isim, @JsonKey(fromJson: readRequiredText)  String soyisim, @JsonKey(fromJson: readRequiredText)  String photo, @JsonKey(fromJson: readRequiredText)  String role, @JsonKey(name: 'admin', fromJson: readRequiredBool)  bool isAdmin, @JsonKey(name: 'verified', fromJson: readRequiredBool)  bool isVerified, @JsonKey(name: 'banned', fromJson: readRequiredBool)  bool isBanned, @JsonKey(fromJson: readRequiredText)  String state, @JsonKey(fromJson: readOptionalText)  String? graduationYear, @JsonKey(fromJson: readOptionalText)  String? oauthProvider)  $default,) {final _that = this;
switch (_that) {
case _SessionUser():
return $default(_that.id,_that.kadi,_that.isim,_that.soyisim,_that.photo,_that.role,_that.isAdmin,_that.isVerified,_that.isBanned,_that.state,_that.graduationYear,_that.oauthProvider);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: readRequiredInt)  int id, @JsonKey(fromJson: readRequiredText)  String kadi, @JsonKey(fromJson: readRequiredText)  String isim, @JsonKey(fromJson: readRequiredText)  String soyisim, @JsonKey(fromJson: readRequiredText)  String photo, @JsonKey(fromJson: readRequiredText)  String role, @JsonKey(name: 'admin', fromJson: readRequiredBool)  bool isAdmin, @JsonKey(name: 'verified', fromJson: readRequiredBool)  bool isVerified, @JsonKey(name: 'banned', fromJson: readRequiredBool)  bool isBanned, @JsonKey(fromJson: readRequiredText)  String state, @JsonKey(fromJson: readOptionalText)  String? graduationYear, @JsonKey(fromJson: readOptionalText)  String? oauthProvider)?  $default,) {final _that = this;
switch (_that) {
case _SessionUser() when $default != null:
return $default(_that.id,_that.kadi,_that.isim,_that.soyisim,_that.photo,_that.role,_that.isAdmin,_that.isVerified,_that.isBanned,_that.state,_that.graduationYear,_that.oauthProvider);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SessionUser extends SessionUser {
  const _SessionUser({@JsonKey(fromJson: readRequiredInt) required this.id, @JsonKey(fromJson: readRequiredText) required this.kadi, @JsonKey(fromJson: readRequiredText) required this.isim, @JsonKey(fromJson: readRequiredText) required this.soyisim, @JsonKey(fromJson: readRequiredText) required this.photo, @JsonKey(fromJson: readRequiredText) required this.role, @JsonKey(name: 'admin', fromJson: readRequiredBool) required this.isAdmin, @JsonKey(name: 'verified', fromJson: readRequiredBool) required this.isVerified, @JsonKey(name: 'banned', fromJson: readRequiredBool) required this.isBanned, @JsonKey(fromJson: readRequiredText) required this.state, @JsonKey(fromJson: readOptionalText) this.graduationYear, @JsonKey(fromJson: readOptionalText) this.oauthProvider}): super._();
  factory _SessionUser.fromJson(Map<String, dynamic> json) => _$SessionUserFromJson(json);

@override@JsonKey(fromJson: readRequiredInt) final  int id;
@override@JsonKey(fromJson: readRequiredText) final  String kadi;
@override@JsonKey(fromJson: readRequiredText) final  String isim;
@override@JsonKey(fromJson: readRequiredText) final  String soyisim;
@override@JsonKey(fromJson: readRequiredText) final  String photo;
@override@JsonKey(fromJson: readRequiredText) final  String role;
@override@JsonKey(name: 'admin', fromJson: readRequiredBool) final  bool isAdmin;
@override@JsonKey(name: 'verified', fromJson: readRequiredBool) final  bool isVerified;
@override@JsonKey(name: 'banned', fromJson: readRequiredBool) final  bool isBanned;
@override@JsonKey(fromJson: readRequiredText) final  String state;
@override@JsonKey(fromJson: readOptionalText) final  String? graduationYear;
@override@JsonKey(fromJson: readOptionalText) final  String? oauthProvider;

/// Create a copy of SessionUser
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionUserCopyWith<_SessionUser> get copyWith => __$SessionUserCopyWithImpl<_SessionUser>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionUserToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionUser&&(identical(other.id, id) || other.id == id)&&(identical(other.kadi, kadi) || other.kadi == kadi)&&(identical(other.isim, isim) || other.isim == isim)&&(identical(other.soyisim, soyisim) || other.soyisim == soyisim)&&(identical(other.photo, photo) || other.photo == photo)&&(identical(other.role, role) || other.role == role)&&(identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin)&&(identical(other.isVerified, isVerified) || other.isVerified == isVerified)&&(identical(other.isBanned, isBanned) || other.isBanned == isBanned)&&(identical(other.state, state) || other.state == state)&&(identical(other.graduationYear, graduationYear) || other.graduationYear == graduationYear)&&(identical(other.oauthProvider, oauthProvider) || other.oauthProvider == oauthProvider));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kadi,isim,soyisim,photo,role,isAdmin,isVerified,isBanned,state,graduationYear,oauthProvider);

@override
String toString() {
  return 'SessionUser(id: $id, kadi: $kadi, isim: $isim, soyisim: $soyisim, photo: $photo, role: $role, isAdmin: $isAdmin, isVerified: $isVerified, isBanned: $isBanned, state: $state, graduationYear: $graduationYear, oauthProvider: $oauthProvider)';
}


}

/// @nodoc
abstract mixin class _$SessionUserCopyWith<$Res> implements $SessionUserCopyWith<$Res> {
  factory _$SessionUserCopyWith(_SessionUser value, $Res Function(_SessionUser) _then) = __$SessionUserCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: readRequiredInt) int id,@JsonKey(fromJson: readRequiredText) String kadi,@JsonKey(fromJson: readRequiredText) String isim,@JsonKey(fromJson: readRequiredText) String soyisim,@JsonKey(fromJson: readRequiredText) String photo,@JsonKey(fromJson: readRequiredText) String role,@JsonKey(name: 'admin', fromJson: readRequiredBool) bool isAdmin,@JsonKey(name: 'verified', fromJson: readRequiredBool) bool isVerified,@JsonKey(name: 'banned', fromJson: readRequiredBool) bool isBanned,@JsonKey(fromJson: readRequiredText) String state,@JsonKey(fromJson: readOptionalText) String? graduationYear,@JsonKey(fromJson: readOptionalText) String? oauthProvider
});




}
/// @nodoc
class __$SessionUserCopyWithImpl<$Res>
    implements _$SessionUserCopyWith<$Res> {
  __$SessionUserCopyWithImpl(this._self, this._then);

  final _SessionUser _self;
  final $Res Function(_SessionUser) _then;

/// Create a copy of SessionUser
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kadi = null,Object? isim = null,Object? soyisim = null,Object? photo = null,Object? role = null,Object? isAdmin = null,Object? isVerified = null,Object? isBanned = null,Object? state = null,Object? graduationYear = freezed,Object? oauthProvider = freezed,}) {
  return _then(_SessionUser(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,kadi: null == kadi ? _self.kadi : kadi // ignore: cast_nullable_to_non_nullable
as String,isim: null == isim ? _self.isim : isim // ignore: cast_nullable_to_non_nullable
as String,soyisim: null == soyisim ? _self.soyisim : soyisim // ignore: cast_nullable_to_non_nullable
as String,photo: null == photo ? _self.photo : photo // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,isAdmin: null == isAdmin ? _self.isAdmin : isAdmin // ignore: cast_nullable_to_non_nullable
as bool,isVerified: null == isVerified ? _self.isVerified : isVerified // ignore: cast_nullable_to_non_nullable
as bool,isBanned: null == isBanned ? _self.isBanned : isBanned // ignore: cast_nullable_to_non_nullable
as bool,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,graduationYear: freezed == graduationYear ? _self.graduationYear : graduationYear // ignore: cast_nullable_to_non_nullable
as String?,oauthProvider: freezed == oauthProvider ? _self.oauthProvider : oauthProvider // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$SiteAccessSnapshot {

@JsonKey(fromJson: readRequiredBool) bool get siteOpen;@JsonKey(fromJson: readRequiredText) String get maintenanceMessage;@SiteModulesConverter() Map<String, bool> get modules;@JsonKey(fromJson: readRequiredText) String get defaultLandingPage;@JsonKey(fromJson: _themeFromJson) SdalAppTheme get activeTheme;
/// Create a copy of SiteAccessSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SiteAccessSnapshotCopyWith<SiteAccessSnapshot> get copyWith => _$SiteAccessSnapshotCopyWithImpl<SiteAccessSnapshot>(this as SiteAccessSnapshot, _$identity);

  /// Serializes this SiteAccessSnapshot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SiteAccessSnapshot&&(identical(other.siteOpen, siteOpen) || other.siteOpen == siteOpen)&&(identical(other.maintenanceMessage, maintenanceMessage) || other.maintenanceMessage == maintenanceMessage)&&const DeepCollectionEquality().equals(other.modules, modules)&&(identical(other.defaultLandingPage, defaultLandingPage) || other.defaultLandingPage == defaultLandingPage)&&(identical(other.activeTheme, activeTheme) || other.activeTheme == activeTheme));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,siteOpen,maintenanceMessage,const DeepCollectionEquality().hash(modules),defaultLandingPage,activeTheme);

@override
String toString() {
  return 'SiteAccessSnapshot(siteOpen: $siteOpen, maintenanceMessage: $maintenanceMessage, modules: $modules, defaultLandingPage: $defaultLandingPage, activeTheme: $activeTheme)';
}


}

/// @nodoc
abstract mixin class $SiteAccessSnapshotCopyWith<$Res>  {
  factory $SiteAccessSnapshotCopyWith(SiteAccessSnapshot value, $Res Function(SiteAccessSnapshot) _then) = _$SiteAccessSnapshotCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: readRequiredBool) bool siteOpen,@JsonKey(fromJson: readRequiredText) String maintenanceMessage,@SiteModulesConverter() Map<String, bool> modules,@JsonKey(fromJson: readRequiredText) String defaultLandingPage,@JsonKey(fromJson: _themeFromJson) SdalAppTheme activeTheme
});




}
/// @nodoc
class _$SiteAccessSnapshotCopyWithImpl<$Res>
    implements $SiteAccessSnapshotCopyWith<$Res> {
  _$SiteAccessSnapshotCopyWithImpl(this._self, this._then);

  final SiteAccessSnapshot _self;
  final $Res Function(SiteAccessSnapshot) _then;

/// Create a copy of SiteAccessSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? siteOpen = null,Object? maintenanceMessage = null,Object? modules = null,Object? defaultLandingPage = null,Object? activeTheme = null,}) {
  return _then(_self.copyWith(
siteOpen: null == siteOpen ? _self.siteOpen : siteOpen // ignore: cast_nullable_to_non_nullable
as bool,maintenanceMessage: null == maintenanceMessage ? _self.maintenanceMessage : maintenanceMessage // ignore: cast_nullable_to_non_nullable
as String,modules: null == modules ? _self.modules : modules // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,defaultLandingPage: null == defaultLandingPage ? _self.defaultLandingPage : defaultLandingPage // ignore: cast_nullable_to_non_nullable
as String,activeTheme: null == activeTheme ? _self.activeTheme : activeTheme // ignore: cast_nullable_to_non_nullable
as SdalAppTheme,
  ));
}

}


/// Adds pattern-matching-related methods to [SiteAccessSnapshot].
extension SiteAccessSnapshotPatterns on SiteAccessSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SiteAccessSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SiteAccessSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SiteAccessSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _SiteAccessSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SiteAccessSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _SiteAccessSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredBool)  bool siteOpen, @JsonKey(fromJson: readRequiredText)  String maintenanceMessage, @SiteModulesConverter()  Map<String, bool> modules, @JsonKey(fromJson: readRequiredText)  String defaultLandingPage, @JsonKey(fromJson: _themeFromJson)  SdalAppTheme activeTheme)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SiteAccessSnapshot() when $default != null:
return $default(_that.siteOpen,_that.maintenanceMessage,_that.modules,_that.defaultLandingPage,_that.activeTheme);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredBool)  bool siteOpen, @JsonKey(fromJson: readRequiredText)  String maintenanceMessage, @SiteModulesConverter()  Map<String, bool> modules, @JsonKey(fromJson: readRequiredText)  String defaultLandingPage, @JsonKey(fromJson: _themeFromJson)  SdalAppTheme activeTheme)  $default,) {final _that = this;
switch (_that) {
case _SiteAccessSnapshot():
return $default(_that.siteOpen,_that.maintenanceMessage,_that.modules,_that.defaultLandingPage,_that.activeTheme);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: readRequiredBool)  bool siteOpen, @JsonKey(fromJson: readRequiredText)  String maintenanceMessage, @SiteModulesConverter()  Map<String, bool> modules, @JsonKey(fromJson: readRequiredText)  String defaultLandingPage, @JsonKey(fromJson: _themeFromJson)  SdalAppTheme activeTheme)?  $default,) {final _that = this;
switch (_that) {
case _SiteAccessSnapshot() when $default != null:
return $default(_that.siteOpen,_that.maintenanceMessage,_that.modules,_that.defaultLandingPage,_that.activeTheme);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SiteAccessSnapshot extends SiteAccessSnapshot {
  const _SiteAccessSnapshot({@JsonKey(fromJson: readRequiredBool) required this.siteOpen, @JsonKey(fromJson: readRequiredText) required this.maintenanceMessage, @SiteModulesConverter() required final  Map<String, bool> modules, @JsonKey(fromJson: readRequiredText) required this.defaultLandingPage, @JsonKey(fromJson: _themeFromJson) this.activeTheme = SdalAppTheme.kor}): _modules = modules,super._();
  factory _SiteAccessSnapshot.fromJson(Map<String, dynamic> json) => _$SiteAccessSnapshotFromJson(json);

@override@JsonKey(fromJson: readRequiredBool) final  bool siteOpen;
@override@JsonKey(fromJson: readRequiredText) final  String maintenanceMessage;
 final  Map<String, bool> _modules;
@override@SiteModulesConverter() Map<String, bool> get modules {
  if (_modules is EqualUnmodifiableMapView) return _modules;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_modules);
}

@override@JsonKey(fromJson: readRequiredText) final  String defaultLandingPage;
@override@JsonKey(fromJson: _themeFromJson) final  SdalAppTheme activeTheme;

/// Create a copy of SiteAccessSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SiteAccessSnapshotCopyWith<_SiteAccessSnapshot> get copyWith => __$SiteAccessSnapshotCopyWithImpl<_SiteAccessSnapshot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SiteAccessSnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SiteAccessSnapshot&&(identical(other.siteOpen, siteOpen) || other.siteOpen == siteOpen)&&(identical(other.maintenanceMessage, maintenanceMessage) || other.maintenanceMessage == maintenanceMessage)&&const DeepCollectionEquality().equals(other._modules, _modules)&&(identical(other.defaultLandingPage, defaultLandingPage) || other.defaultLandingPage == defaultLandingPage)&&(identical(other.activeTheme, activeTheme) || other.activeTheme == activeTheme));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,siteOpen,maintenanceMessage,const DeepCollectionEquality().hash(_modules),defaultLandingPage,activeTheme);

@override
String toString() {
  return 'SiteAccessSnapshot(siteOpen: $siteOpen, maintenanceMessage: $maintenanceMessage, modules: $modules, defaultLandingPage: $defaultLandingPage, activeTheme: $activeTheme)';
}


}

/// @nodoc
abstract mixin class _$SiteAccessSnapshotCopyWith<$Res> implements $SiteAccessSnapshotCopyWith<$Res> {
  factory _$SiteAccessSnapshotCopyWith(_SiteAccessSnapshot value, $Res Function(_SiteAccessSnapshot) _then) = __$SiteAccessSnapshotCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: readRequiredBool) bool siteOpen,@JsonKey(fromJson: readRequiredText) String maintenanceMessage,@SiteModulesConverter() Map<String, bool> modules,@JsonKey(fromJson: readRequiredText) String defaultLandingPage,@JsonKey(fromJson: _themeFromJson) SdalAppTheme activeTheme
});




}
/// @nodoc
class __$SiteAccessSnapshotCopyWithImpl<$Res>
    implements _$SiteAccessSnapshotCopyWith<$Res> {
  __$SiteAccessSnapshotCopyWithImpl(this._self, this._then);

  final _SiteAccessSnapshot _self;
  final $Res Function(_SiteAccessSnapshot) _then;

/// Create a copy of SiteAccessSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? siteOpen = null,Object? maintenanceMessage = null,Object? modules = null,Object? defaultLandingPage = null,Object? activeTheme = null,}) {
  return _then(_SiteAccessSnapshot(
siteOpen: null == siteOpen ? _self.siteOpen : siteOpen // ignore: cast_nullable_to_non_nullable
as bool,maintenanceMessage: null == maintenanceMessage ? _self.maintenanceMessage : maintenanceMessage // ignore: cast_nullable_to_non_nullable
as String,modules: null == modules ? _self._modules : modules // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,defaultLandingPage: null == defaultLandingPage ? _self.defaultLandingPage : defaultLandingPage // ignore: cast_nullable_to_non_nullable
as String,activeTheme: null == activeTheme ? _self.activeTheme : activeTheme // ignore: cast_nullable_to_non_nullable
as SdalAppTheme,
  ));
}


}

// dart format on
