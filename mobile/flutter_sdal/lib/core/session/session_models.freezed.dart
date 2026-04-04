// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

OAuthProviderLink _$OAuthProviderLinkFromJson(Map<String, dynamic> json) {
  return _OAuthProviderLink.fromJson(json);
}

/// @nodoc
mixin _$OAuthProviderLink {
  @JsonKey(fromJson: readRequiredText)
  String get provider => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get title => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get startUrl => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredBool)
  bool get enabled => throw _privateConstructorUsedError;

  /// Serializes this OAuthProviderLink to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OAuthProviderLink
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OAuthProviderLinkCopyWith<OAuthProviderLink> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OAuthProviderLinkCopyWith<$Res> {
  factory $OAuthProviderLinkCopyWith(
    OAuthProviderLink value,
    $Res Function(OAuthProviderLink) then,
  ) = _$OAuthProviderLinkCopyWithImpl<$Res, OAuthProviderLink>;
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredText) String provider,
    @JsonKey(fromJson: readRequiredText) String title,
    @JsonKey(fromJson: readRequiredText) String startUrl,
    @JsonKey(fromJson: readRequiredBool) bool enabled,
  });
}

/// @nodoc
class _$OAuthProviderLinkCopyWithImpl<$Res, $Val extends OAuthProviderLink>
    implements $OAuthProviderLinkCopyWith<$Res> {
  _$OAuthProviderLinkCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OAuthProviderLink
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? provider = null,
    Object? title = null,
    Object? startUrl = null,
    Object? enabled = null,
  }) {
    return _then(
      _value.copyWith(
            provider: null == provider
                ? _value.provider
                : provider // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            startUrl: null == startUrl
                ? _value.startUrl
                : startUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            enabled: null == enabled
                ? _value.enabled
                : enabled // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OAuthProviderLinkImplCopyWith<$Res>
    implements $OAuthProviderLinkCopyWith<$Res> {
  factory _$$OAuthProviderLinkImplCopyWith(
    _$OAuthProviderLinkImpl value,
    $Res Function(_$OAuthProviderLinkImpl) then,
  ) = __$$OAuthProviderLinkImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredText) String provider,
    @JsonKey(fromJson: readRequiredText) String title,
    @JsonKey(fromJson: readRequiredText) String startUrl,
    @JsonKey(fromJson: readRequiredBool) bool enabled,
  });
}

/// @nodoc
class __$$OAuthProviderLinkImplCopyWithImpl<$Res>
    extends _$OAuthProviderLinkCopyWithImpl<$Res, _$OAuthProviderLinkImpl>
    implements _$$OAuthProviderLinkImplCopyWith<$Res> {
  __$$OAuthProviderLinkImplCopyWithImpl(
    _$OAuthProviderLinkImpl _value,
    $Res Function(_$OAuthProviderLinkImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OAuthProviderLink
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? provider = null,
    Object? title = null,
    Object? startUrl = null,
    Object? enabled = null,
  }) {
    return _then(
      _$OAuthProviderLinkImpl(
        provider: null == provider
            ? _value.provider
            : provider // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        startUrl: null == startUrl
            ? _value.startUrl
            : startUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        enabled: null == enabled
            ? _value.enabled
            : enabled // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$OAuthProviderLinkImpl implements _OAuthProviderLink {
  const _$OAuthProviderLinkImpl({
    @JsonKey(fromJson: readRequiredText) required this.provider,
    @JsonKey(fromJson: readRequiredText) required this.title,
    @JsonKey(fromJson: readRequiredText) required this.startUrl,
    @JsonKey(fromJson: readRequiredBool) required this.enabled,
  });

  factory _$OAuthProviderLinkImpl.fromJson(Map<String, dynamic> json) =>
      _$$OAuthProviderLinkImplFromJson(json);

  @override
  @JsonKey(fromJson: readRequiredText)
  final String provider;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String title;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String startUrl;
  @override
  @JsonKey(fromJson: readRequiredBool)
  final bool enabled;

  @override
  String toString() {
    return 'OAuthProviderLink(provider: $provider, title: $title, startUrl: $startUrl, enabled: $enabled)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OAuthProviderLinkImpl &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.startUrl, startUrl) ||
                other.startUrl == startUrl) &&
            (identical(other.enabled, enabled) || other.enabled == enabled));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, provider, title, startUrl, enabled);

  /// Create a copy of OAuthProviderLink
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OAuthProviderLinkImplCopyWith<_$OAuthProviderLinkImpl> get copyWith =>
      __$$OAuthProviderLinkImplCopyWithImpl<_$OAuthProviderLinkImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$OAuthProviderLinkImplToJson(this);
  }
}

abstract class _OAuthProviderLink implements OAuthProviderLink {
  const factory _OAuthProviderLink({
    @JsonKey(fromJson: readRequiredText) required final String provider,
    @JsonKey(fromJson: readRequiredText) required final String title,
    @JsonKey(fromJson: readRequiredText) required final String startUrl,
    @JsonKey(fromJson: readRequiredBool) required final bool enabled,
  }) = _$OAuthProviderLinkImpl;

  factory _OAuthProviderLink.fromJson(Map<String, dynamic> json) =
      _$OAuthProviderLinkImpl.fromJson;

  @override
  @JsonKey(fromJson: readRequiredText)
  String get provider;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get title;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get startUrl;
  @override
  @JsonKey(fromJson: readRequiredBool)
  bool get enabled;

  /// Create a copy of OAuthProviderLink
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OAuthProviderLinkImplCopyWith<_$OAuthProviderLinkImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SessionUser _$SessionUserFromJson(Map<String, dynamic> json) {
  return _SessionUser.fromJson(json);
}

/// @nodoc
mixin _$SessionUser {
  @JsonKey(fromJson: readRequiredInt)
  int get id => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get kadi => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get isim => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get soyisim => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get photo => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get role => throw _privateConstructorUsedError;
  @JsonKey(name: 'admin', fromJson: readRequiredBool)
  bool get isAdmin => throw _privateConstructorUsedError;
  @JsonKey(name: 'verified', fromJson: readRequiredBool)
  bool get isVerified => throw _privateConstructorUsedError;
  @JsonKey(name: 'banned', fromJson: readRequiredBool)
  bool get isBanned => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get state => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readOptionalText)
  String? get graduationYear => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readOptionalText)
  String? get oauthProvider => throw _privateConstructorUsedError;

  /// Serializes this SessionUser to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SessionUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SessionUserCopyWith<SessionUser> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SessionUserCopyWith<$Res> {
  factory $SessionUserCopyWith(
    SessionUser value,
    $Res Function(SessionUser) then,
  ) = _$SessionUserCopyWithImpl<$Res, SessionUser>;
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredInt) int id,
    @JsonKey(fromJson: readRequiredText) String kadi,
    @JsonKey(fromJson: readRequiredText) String isim,
    @JsonKey(fromJson: readRequiredText) String soyisim,
    @JsonKey(fromJson: readRequiredText) String photo,
    @JsonKey(fromJson: readRequiredText) String role,
    @JsonKey(name: 'admin', fromJson: readRequiredBool) bool isAdmin,
    @JsonKey(name: 'verified', fromJson: readRequiredBool) bool isVerified,
    @JsonKey(name: 'banned', fromJson: readRequiredBool) bool isBanned,
    @JsonKey(fromJson: readRequiredText) String state,
    @JsonKey(fromJson: readOptionalText) String? graduationYear,
    @JsonKey(fromJson: readOptionalText) String? oauthProvider,
  });
}

/// @nodoc
class _$SessionUserCopyWithImpl<$Res, $Val extends SessionUser>
    implements $SessionUserCopyWith<$Res> {
  _$SessionUserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SessionUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? kadi = null,
    Object? isim = null,
    Object? soyisim = null,
    Object? photo = null,
    Object? role = null,
    Object? isAdmin = null,
    Object? isVerified = null,
    Object? isBanned = null,
    Object? state = null,
    Object? graduationYear = freezed,
    Object? oauthProvider = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            kadi: null == kadi
                ? _value.kadi
                : kadi // ignore: cast_nullable_to_non_nullable
                      as String,
            isim: null == isim
                ? _value.isim
                : isim // ignore: cast_nullable_to_non_nullable
                      as String,
            soyisim: null == soyisim
                ? _value.soyisim
                : soyisim // ignore: cast_nullable_to_non_nullable
                      as String,
            photo: null == photo
                ? _value.photo
                : photo // ignore: cast_nullable_to_non_nullable
                      as String,
            role: null == role
                ? _value.role
                : role // ignore: cast_nullable_to_non_nullable
                      as String,
            isAdmin: null == isAdmin
                ? _value.isAdmin
                : isAdmin // ignore: cast_nullable_to_non_nullable
                      as bool,
            isVerified: null == isVerified
                ? _value.isVerified
                : isVerified // ignore: cast_nullable_to_non_nullable
                      as bool,
            isBanned: null == isBanned
                ? _value.isBanned
                : isBanned // ignore: cast_nullable_to_non_nullable
                      as bool,
            state: null == state
                ? _value.state
                : state // ignore: cast_nullable_to_non_nullable
                      as String,
            graduationYear: freezed == graduationYear
                ? _value.graduationYear
                : graduationYear // ignore: cast_nullable_to_non_nullable
                      as String?,
            oauthProvider: freezed == oauthProvider
                ? _value.oauthProvider
                : oauthProvider // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SessionUserImplCopyWith<$Res>
    implements $SessionUserCopyWith<$Res> {
  factory _$$SessionUserImplCopyWith(
    _$SessionUserImpl value,
    $Res Function(_$SessionUserImpl) then,
  ) = __$$SessionUserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredInt) int id,
    @JsonKey(fromJson: readRequiredText) String kadi,
    @JsonKey(fromJson: readRequiredText) String isim,
    @JsonKey(fromJson: readRequiredText) String soyisim,
    @JsonKey(fromJson: readRequiredText) String photo,
    @JsonKey(fromJson: readRequiredText) String role,
    @JsonKey(name: 'admin', fromJson: readRequiredBool) bool isAdmin,
    @JsonKey(name: 'verified', fromJson: readRequiredBool) bool isVerified,
    @JsonKey(name: 'banned', fromJson: readRequiredBool) bool isBanned,
    @JsonKey(fromJson: readRequiredText) String state,
    @JsonKey(fromJson: readOptionalText) String? graduationYear,
    @JsonKey(fromJson: readOptionalText) String? oauthProvider,
  });
}

/// @nodoc
class __$$SessionUserImplCopyWithImpl<$Res>
    extends _$SessionUserCopyWithImpl<$Res, _$SessionUserImpl>
    implements _$$SessionUserImplCopyWith<$Res> {
  __$$SessionUserImplCopyWithImpl(
    _$SessionUserImpl _value,
    $Res Function(_$SessionUserImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SessionUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? kadi = null,
    Object? isim = null,
    Object? soyisim = null,
    Object? photo = null,
    Object? role = null,
    Object? isAdmin = null,
    Object? isVerified = null,
    Object? isBanned = null,
    Object? state = null,
    Object? graduationYear = freezed,
    Object? oauthProvider = freezed,
  }) {
    return _then(
      _$SessionUserImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        kadi: null == kadi
            ? _value.kadi
            : kadi // ignore: cast_nullable_to_non_nullable
                  as String,
        isim: null == isim
            ? _value.isim
            : isim // ignore: cast_nullable_to_non_nullable
                  as String,
        soyisim: null == soyisim
            ? _value.soyisim
            : soyisim // ignore: cast_nullable_to_non_nullable
                  as String,
        photo: null == photo
            ? _value.photo
            : photo // ignore: cast_nullable_to_non_nullable
                  as String,
        role: null == role
            ? _value.role
            : role // ignore: cast_nullable_to_non_nullable
                  as String,
        isAdmin: null == isAdmin
            ? _value.isAdmin
            : isAdmin // ignore: cast_nullable_to_non_nullable
                  as bool,
        isVerified: null == isVerified
            ? _value.isVerified
            : isVerified // ignore: cast_nullable_to_non_nullable
                  as bool,
        isBanned: null == isBanned
            ? _value.isBanned
            : isBanned // ignore: cast_nullable_to_non_nullable
                  as bool,
        state: null == state
            ? _value.state
            : state // ignore: cast_nullable_to_non_nullable
                  as String,
        graduationYear: freezed == graduationYear
            ? _value.graduationYear
            : graduationYear // ignore: cast_nullable_to_non_nullable
                  as String?,
        oauthProvider: freezed == oauthProvider
            ? _value.oauthProvider
            : oauthProvider // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SessionUserImpl extends _SessionUser {
  const _$SessionUserImpl({
    @JsonKey(fromJson: readRequiredInt) required this.id,
    @JsonKey(fromJson: readRequiredText) required this.kadi,
    @JsonKey(fromJson: readRequiredText) required this.isim,
    @JsonKey(fromJson: readRequiredText) required this.soyisim,
    @JsonKey(fromJson: readRequiredText) required this.photo,
    @JsonKey(fromJson: readRequiredText) required this.role,
    @JsonKey(name: 'admin', fromJson: readRequiredBool) required this.isAdmin,
    @JsonKey(name: 'verified', fromJson: readRequiredBool)
    required this.isVerified,
    @JsonKey(name: 'banned', fromJson: readRequiredBool) required this.isBanned,
    @JsonKey(fromJson: readRequiredText) required this.state,
    @JsonKey(fromJson: readOptionalText) this.graduationYear,
    @JsonKey(fromJson: readOptionalText) this.oauthProvider,
  }) : super._();

  factory _$SessionUserImpl.fromJson(Map<String, dynamic> json) =>
      _$$SessionUserImplFromJson(json);

  @override
  @JsonKey(fromJson: readRequiredInt)
  final int id;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String kadi;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String isim;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String soyisim;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String photo;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String role;
  @override
  @JsonKey(name: 'admin', fromJson: readRequiredBool)
  final bool isAdmin;
  @override
  @JsonKey(name: 'verified', fromJson: readRequiredBool)
  final bool isVerified;
  @override
  @JsonKey(name: 'banned', fromJson: readRequiredBool)
  final bool isBanned;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String state;
  @override
  @JsonKey(fromJson: readOptionalText)
  final String? graduationYear;
  @override
  @JsonKey(fromJson: readOptionalText)
  final String? oauthProvider;

  @override
  String toString() {
    return 'SessionUser(id: $id, kadi: $kadi, isim: $isim, soyisim: $soyisim, photo: $photo, role: $role, isAdmin: $isAdmin, isVerified: $isVerified, isBanned: $isBanned, state: $state, graduationYear: $graduationYear, oauthProvider: $oauthProvider)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SessionUserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.kadi, kadi) || other.kadi == kadi) &&
            (identical(other.isim, isim) || other.isim == isim) &&
            (identical(other.soyisim, soyisim) || other.soyisim == soyisim) &&
            (identical(other.photo, photo) || other.photo == photo) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.isAdmin, isAdmin) || other.isAdmin == isAdmin) &&
            (identical(other.isVerified, isVerified) ||
                other.isVerified == isVerified) &&
            (identical(other.isBanned, isBanned) ||
                other.isBanned == isBanned) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.graduationYear, graduationYear) ||
                other.graduationYear == graduationYear) &&
            (identical(other.oauthProvider, oauthProvider) ||
                other.oauthProvider == oauthProvider));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    kadi,
    isim,
    soyisim,
    photo,
    role,
    isAdmin,
    isVerified,
    isBanned,
    state,
    graduationYear,
    oauthProvider,
  );

  /// Create a copy of SessionUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SessionUserImplCopyWith<_$SessionUserImpl> get copyWith =>
      __$$SessionUserImplCopyWithImpl<_$SessionUserImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SessionUserImplToJson(this);
  }
}

abstract class _SessionUser extends SessionUser {
  const factory _SessionUser({
    @JsonKey(fromJson: readRequiredInt) required final int id,
    @JsonKey(fromJson: readRequiredText) required final String kadi,
    @JsonKey(fromJson: readRequiredText) required final String isim,
    @JsonKey(fromJson: readRequiredText) required final String soyisim,
    @JsonKey(fromJson: readRequiredText) required final String photo,
    @JsonKey(fromJson: readRequiredText) required final String role,
    @JsonKey(name: 'admin', fromJson: readRequiredBool)
    required final bool isAdmin,
    @JsonKey(name: 'verified', fromJson: readRequiredBool)
    required final bool isVerified,
    @JsonKey(name: 'banned', fromJson: readRequiredBool)
    required final bool isBanned,
    @JsonKey(fromJson: readRequiredText) required final String state,
    @JsonKey(fromJson: readOptionalText) final String? graduationYear,
    @JsonKey(fromJson: readOptionalText) final String? oauthProvider,
  }) = _$SessionUserImpl;
  const _SessionUser._() : super._();

  factory _SessionUser.fromJson(Map<String, dynamic> json) =
      _$SessionUserImpl.fromJson;

  @override
  @JsonKey(fromJson: readRequiredInt)
  int get id;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get kadi;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get isim;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get soyisim;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get photo;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get role;
  @override
  @JsonKey(name: 'admin', fromJson: readRequiredBool)
  bool get isAdmin;
  @override
  @JsonKey(name: 'verified', fromJson: readRequiredBool)
  bool get isVerified;
  @override
  @JsonKey(name: 'banned', fromJson: readRequiredBool)
  bool get isBanned;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get state;
  @override
  @JsonKey(fromJson: readOptionalText)
  String? get graduationYear;
  @override
  @JsonKey(fromJson: readOptionalText)
  String? get oauthProvider;

  /// Create a copy of SessionUser
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SessionUserImplCopyWith<_$SessionUserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SiteAccessSnapshot _$SiteAccessSnapshotFromJson(Map<String, dynamic> json) {
  return _SiteAccessSnapshot.fromJson(json);
}

/// @nodoc
mixin _$SiteAccessSnapshot {
  @JsonKey(fromJson: readRequiredBool)
  bool get siteOpen => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get maintenanceMessage => throw _privateConstructorUsedError;
  @SiteModulesConverter()
  Map<String, bool> get modules => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get defaultLandingPage => throw _privateConstructorUsedError;

  /// Serializes this SiteAccessSnapshot to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SiteAccessSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SiteAccessSnapshotCopyWith<SiteAccessSnapshot> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SiteAccessSnapshotCopyWith<$Res> {
  factory $SiteAccessSnapshotCopyWith(
    SiteAccessSnapshot value,
    $Res Function(SiteAccessSnapshot) then,
  ) = _$SiteAccessSnapshotCopyWithImpl<$Res, SiteAccessSnapshot>;
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredBool) bool siteOpen,
    @JsonKey(fromJson: readRequiredText) String maintenanceMessage,
    @SiteModulesConverter() Map<String, bool> modules,
    @JsonKey(fromJson: readRequiredText) String defaultLandingPage,
  });
}

/// @nodoc
class _$SiteAccessSnapshotCopyWithImpl<$Res, $Val extends SiteAccessSnapshot>
    implements $SiteAccessSnapshotCopyWith<$Res> {
  _$SiteAccessSnapshotCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SiteAccessSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? siteOpen = null,
    Object? maintenanceMessage = null,
    Object? modules = null,
    Object? defaultLandingPage = null,
  }) {
    return _then(
      _value.copyWith(
            siteOpen: null == siteOpen
                ? _value.siteOpen
                : siteOpen // ignore: cast_nullable_to_non_nullable
                      as bool,
            maintenanceMessage: null == maintenanceMessage
                ? _value.maintenanceMessage
                : maintenanceMessage // ignore: cast_nullable_to_non_nullable
                      as String,
            modules: null == modules
                ? _value.modules
                : modules // ignore: cast_nullable_to_non_nullable
                      as Map<String, bool>,
            defaultLandingPage: null == defaultLandingPage
                ? _value.defaultLandingPage
                : defaultLandingPage // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SiteAccessSnapshotImplCopyWith<$Res>
    implements $SiteAccessSnapshotCopyWith<$Res> {
  factory _$$SiteAccessSnapshotImplCopyWith(
    _$SiteAccessSnapshotImpl value,
    $Res Function(_$SiteAccessSnapshotImpl) then,
  ) = __$$SiteAccessSnapshotImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredBool) bool siteOpen,
    @JsonKey(fromJson: readRequiredText) String maintenanceMessage,
    @SiteModulesConverter() Map<String, bool> modules,
    @JsonKey(fromJson: readRequiredText) String defaultLandingPage,
  });
}

/// @nodoc
class __$$SiteAccessSnapshotImplCopyWithImpl<$Res>
    extends _$SiteAccessSnapshotCopyWithImpl<$Res, _$SiteAccessSnapshotImpl>
    implements _$$SiteAccessSnapshotImplCopyWith<$Res> {
  __$$SiteAccessSnapshotImplCopyWithImpl(
    _$SiteAccessSnapshotImpl _value,
    $Res Function(_$SiteAccessSnapshotImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SiteAccessSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? siteOpen = null,
    Object? maintenanceMessage = null,
    Object? modules = null,
    Object? defaultLandingPage = null,
  }) {
    return _then(
      _$SiteAccessSnapshotImpl(
        siteOpen: null == siteOpen
            ? _value.siteOpen
            : siteOpen // ignore: cast_nullable_to_non_nullable
                  as bool,
        maintenanceMessage: null == maintenanceMessage
            ? _value.maintenanceMessage
            : maintenanceMessage // ignore: cast_nullable_to_non_nullable
                  as String,
        modules: null == modules
            ? _value._modules
            : modules // ignore: cast_nullable_to_non_nullable
                  as Map<String, bool>,
        defaultLandingPage: null == defaultLandingPage
            ? _value.defaultLandingPage
            : defaultLandingPage // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SiteAccessSnapshotImpl extends _SiteAccessSnapshot {
  const _$SiteAccessSnapshotImpl({
    @JsonKey(fromJson: readRequiredBool) required this.siteOpen,
    @JsonKey(fromJson: readRequiredText) required this.maintenanceMessage,
    @SiteModulesConverter() required final Map<String, bool> modules,
    @JsonKey(fromJson: readRequiredText) required this.defaultLandingPage,
  }) : _modules = modules,
       super._();

  factory _$SiteAccessSnapshotImpl.fromJson(Map<String, dynamic> json) =>
      _$$SiteAccessSnapshotImplFromJson(json);

  @override
  @JsonKey(fromJson: readRequiredBool)
  final bool siteOpen;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String maintenanceMessage;
  final Map<String, bool> _modules;
  @override
  @SiteModulesConverter()
  Map<String, bool> get modules {
    if (_modules is EqualUnmodifiableMapView) return _modules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_modules);
  }

  @override
  @JsonKey(fromJson: readRequiredText)
  final String defaultLandingPage;

  @override
  String toString() {
    return 'SiteAccessSnapshot(siteOpen: $siteOpen, maintenanceMessage: $maintenanceMessage, modules: $modules, defaultLandingPage: $defaultLandingPage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SiteAccessSnapshotImpl &&
            (identical(other.siteOpen, siteOpen) ||
                other.siteOpen == siteOpen) &&
            (identical(other.maintenanceMessage, maintenanceMessage) ||
                other.maintenanceMessage == maintenanceMessage) &&
            const DeepCollectionEquality().equals(other._modules, _modules) &&
            (identical(other.defaultLandingPage, defaultLandingPage) ||
                other.defaultLandingPage == defaultLandingPage));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    siteOpen,
    maintenanceMessage,
    const DeepCollectionEquality().hash(_modules),
    defaultLandingPage,
  );

  /// Create a copy of SiteAccessSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SiteAccessSnapshotImplCopyWith<_$SiteAccessSnapshotImpl> get copyWith =>
      __$$SiteAccessSnapshotImplCopyWithImpl<_$SiteAccessSnapshotImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SiteAccessSnapshotImplToJson(this);
  }
}

abstract class _SiteAccessSnapshot extends SiteAccessSnapshot {
  const factory _SiteAccessSnapshot({
    @JsonKey(fromJson: readRequiredBool) required final bool siteOpen,
    @JsonKey(fromJson: readRequiredText)
    required final String maintenanceMessage,
    @SiteModulesConverter() required final Map<String, bool> modules,
    @JsonKey(fromJson: readRequiredText)
    required final String defaultLandingPage,
  }) = _$SiteAccessSnapshotImpl;
  const _SiteAccessSnapshot._() : super._();

  factory _SiteAccessSnapshot.fromJson(Map<String, dynamic> json) =
      _$SiteAccessSnapshotImpl.fromJson;

  @override
  @JsonKey(fromJson: readRequiredBool)
  bool get siteOpen;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get maintenanceMessage;
  @override
  @SiteModulesConverter()
  Map<String, bool> get modules;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get defaultLandingPage;

  /// Create a copy of SiteAccessSnapshot
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SiteAccessSnapshotImplCopyWith<_$SiteAccessSnapshotImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
