// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notifications_repository.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

NotificationTarget _$NotificationTargetFromJson(Map<String, dynamic> json) {
  return _NotificationTarget.fromJson(json);
}

/// @nodoc
mixin _$NotificationTarget {
  @JsonKey(fromJson: readRequiredText)
  String get route => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get href => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get label => throw _privateConstructorUsedError;

  /// Serializes this NotificationTarget to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NotificationTarget
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NotificationTargetCopyWith<NotificationTarget> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NotificationTargetCopyWith<$Res> {
  factory $NotificationTargetCopyWith(
    NotificationTarget value,
    $Res Function(NotificationTarget) then,
  ) = _$NotificationTargetCopyWithImpl<$Res, NotificationTarget>;
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredText) String route,
    @JsonKey(fromJson: readRequiredText) String href,
    @JsonKey(fromJson: readRequiredText) String label,
  });
}

/// @nodoc
class _$NotificationTargetCopyWithImpl<$Res, $Val extends NotificationTarget>
    implements $NotificationTargetCopyWith<$Res> {
  _$NotificationTargetCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NotificationTarget
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? route = null, Object? href = null, Object? label = null}) {
    return _then(
      _value.copyWith(
            route: null == route
                ? _value.route
                : route // ignore: cast_nullable_to_non_nullable
                      as String,
            href: null == href
                ? _value.href
                : href // ignore: cast_nullable_to_non_nullable
                      as String,
            label: null == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NotificationTargetImplCopyWith<$Res>
    implements $NotificationTargetCopyWith<$Res> {
  factory _$$NotificationTargetImplCopyWith(
    _$NotificationTargetImpl value,
    $Res Function(_$NotificationTargetImpl) then,
  ) = __$$NotificationTargetImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredText) String route,
    @JsonKey(fromJson: readRequiredText) String href,
    @JsonKey(fromJson: readRequiredText) String label,
  });
}

/// @nodoc
class __$$NotificationTargetImplCopyWithImpl<$Res>
    extends _$NotificationTargetCopyWithImpl<$Res, _$NotificationTargetImpl>
    implements _$$NotificationTargetImplCopyWith<$Res> {
  __$$NotificationTargetImplCopyWithImpl(
    _$NotificationTargetImpl _value,
    $Res Function(_$NotificationTargetImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NotificationTarget
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? route = null, Object? href = null, Object? label = null}) {
    return _then(
      _$NotificationTargetImpl(
        route: null == route
            ? _value.route
            : route // ignore: cast_nullable_to_non_nullable
                  as String,
        href: null == href
            ? _value.href
            : href // ignore: cast_nullable_to_non_nullable
                  as String,
        label: null == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$NotificationTargetImpl implements _NotificationTarget {
  const _$NotificationTargetImpl({
    @JsonKey(fromJson: readRequiredText) required this.route,
    @JsonKey(fromJson: readRequiredText) required this.href,
    @JsonKey(fromJson: readRequiredText) required this.label,
  });

  factory _$NotificationTargetImpl.fromJson(Map<String, dynamic> json) =>
      _$$NotificationTargetImplFromJson(json);

  @override
  @JsonKey(fromJson: readRequiredText)
  final String route;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String href;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String label;

  @override
  String toString() {
    return 'NotificationTarget(route: $route, href: $href, label: $label)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NotificationTargetImpl &&
            (identical(other.route, route) || other.route == route) &&
            (identical(other.href, href) || other.href == href) &&
            (identical(other.label, label) || other.label == label));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, route, href, label);

  /// Create a copy of NotificationTarget
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NotificationTargetImplCopyWith<_$NotificationTargetImpl> get copyWith =>
      __$$NotificationTargetImplCopyWithImpl<_$NotificationTargetImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$NotificationTargetImplToJson(this);
  }
}

abstract class _NotificationTarget implements NotificationTarget {
  const factory _NotificationTarget({
    @JsonKey(fromJson: readRequiredText) required final String route,
    @JsonKey(fromJson: readRequiredText) required final String href,
    @JsonKey(fromJson: readRequiredText) required final String label,
  }) = _$NotificationTargetImpl;

  factory _NotificationTarget.fromJson(Map<String, dynamic> json) =
      _$NotificationTargetImpl.fromJson;

  @override
  @JsonKey(fromJson: readRequiredText)
  String get route;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get href;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get label;

  /// Create a copy of NotificationTarget
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NotificationTargetImplCopyWith<_$NotificationTargetImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

NotificationActionItem _$NotificationActionItemFromJson(
  Map<String, dynamic> json,
) {
  return _NotificationActionItem.fromJson(json);
}

/// @nodoc
mixin _$NotificationActionItem {
  @JsonKey(fromJson: readRequiredText)
  String get kind => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _readActionLabel)
  String get label => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get endpoint => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _readActionMethod)
  String get method => throw _privateConstructorUsedError;

  /// Serializes this NotificationActionItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NotificationActionItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NotificationActionItemCopyWith<NotificationActionItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NotificationActionItemCopyWith<$Res> {
  factory $NotificationActionItemCopyWith(
    NotificationActionItem value,
    $Res Function(NotificationActionItem) then,
  ) = _$NotificationActionItemCopyWithImpl<$Res, NotificationActionItem>;
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredText) String kind,
    @JsonKey(fromJson: _readActionLabel) String label,
    @JsonKey(fromJson: readRequiredText) String endpoint,
    @JsonKey(fromJson: _readActionMethod) String method,
  });
}

/// @nodoc
class _$NotificationActionItemCopyWithImpl<
  $Res,
  $Val extends NotificationActionItem
>
    implements $NotificationActionItemCopyWith<$Res> {
  _$NotificationActionItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NotificationActionItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? kind = null,
    Object? label = null,
    Object? endpoint = null,
    Object? method = null,
  }) {
    return _then(
      _value.copyWith(
            kind: null == kind
                ? _value.kind
                : kind // ignore: cast_nullable_to_non_nullable
                      as String,
            label: null == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                      as String,
            endpoint: null == endpoint
                ? _value.endpoint
                : endpoint // ignore: cast_nullable_to_non_nullable
                      as String,
            method: null == method
                ? _value.method
                : method // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NotificationActionItemImplCopyWith<$Res>
    implements $NotificationActionItemCopyWith<$Res> {
  factory _$$NotificationActionItemImplCopyWith(
    _$NotificationActionItemImpl value,
    $Res Function(_$NotificationActionItemImpl) then,
  ) = __$$NotificationActionItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredText) String kind,
    @JsonKey(fromJson: _readActionLabel) String label,
    @JsonKey(fromJson: readRequiredText) String endpoint,
    @JsonKey(fromJson: _readActionMethod) String method,
  });
}

/// @nodoc
class __$$NotificationActionItemImplCopyWithImpl<$Res>
    extends
        _$NotificationActionItemCopyWithImpl<$Res, _$NotificationActionItemImpl>
    implements _$$NotificationActionItemImplCopyWith<$Res> {
  __$$NotificationActionItemImplCopyWithImpl(
    _$NotificationActionItemImpl _value,
    $Res Function(_$NotificationActionItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NotificationActionItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? kind = null,
    Object? label = null,
    Object? endpoint = null,
    Object? method = null,
  }) {
    return _then(
      _$NotificationActionItemImpl(
        kind: null == kind
            ? _value.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as String,
        label: null == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
                  as String,
        endpoint: null == endpoint
            ? _value.endpoint
            : endpoint // ignore: cast_nullable_to_non_nullable
                  as String,
        method: null == method
            ? _value.method
            : method // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$NotificationActionItemImpl implements _NotificationActionItem {
  const _$NotificationActionItemImpl({
    @JsonKey(fromJson: readRequiredText) required this.kind,
    @JsonKey(fromJson: _readActionLabel) required this.label,
    @JsonKey(fromJson: readRequiredText) required this.endpoint,
    @JsonKey(fromJson: _readActionMethod) required this.method,
  });

  factory _$NotificationActionItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$NotificationActionItemImplFromJson(json);

  @override
  @JsonKey(fromJson: readRequiredText)
  final String kind;
  @override
  @JsonKey(fromJson: _readActionLabel)
  final String label;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String endpoint;
  @override
  @JsonKey(fromJson: _readActionMethod)
  final String method;

  @override
  String toString() {
    return 'NotificationActionItem(kind: $kind, label: $label, endpoint: $endpoint, method: $method)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NotificationActionItemImpl &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.endpoint, endpoint) ||
                other.endpoint == endpoint) &&
            (identical(other.method, method) || other.method == method));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, kind, label, endpoint, method);

  /// Create a copy of NotificationActionItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NotificationActionItemImplCopyWith<_$NotificationActionItemImpl>
  get copyWith =>
      __$$NotificationActionItemImplCopyWithImpl<_$NotificationActionItemImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$NotificationActionItemImplToJson(this);
  }
}

abstract class _NotificationActionItem implements NotificationActionItem {
  const factory _NotificationActionItem({
    @JsonKey(fromJson: readRequiredText) required final String kind,
    @JsonKey(fromJson: _readActionLabel) required final String label,
    @JsonKey(fromJson: readRequiredText) required final String endpoint,
    @JsonKey(fromJson: _readActionMethod) required final String method,
  }) = _$NotificationActionItemImpl;

  factory _NotificationActionItem.fromJson(Map<String, dynamic> json) =
      _$NotificationActionItemImpl.fromJson;

  @override
  @JsonKey(fromJson: readRequiredText)
  String get kind;
  @override
  @JsonKey(fromJson: _readActionLabel)
  String get label;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get endpoint;
  @override
  @JsonKey(fromJson: _readActionMethod)
  String get method;

  /// Create a copy of NotificationActionItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NotificationActionItemImplCopyWith<_$NotificationActionItemImpl>
  get copyWith => throw _privateConstructorUsedError;
}

AppNotification _$AppNotificationFromJson(Map<String, dynamic> json) {
  return _AppNotification.fromJson(json);
}

/// @nodoc
mixin _$AppNotification {
  @JsonKey(fromJson: readRequiredInt)
  int get id => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get type => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get message => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get createdAt => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get readAt => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get category => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get priority => throw _privateConstructorUsedError;
  NotificationTarget? get target => throw _privateConstructorUsedError;
  List<NotificationActionItem> get actions =>
      throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get sourceName => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get sourcePhoto => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get sourceInitials => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get imageUrl => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get imageShape => throw _privateConstructorUsedError;

  /// Serializes this AppNotification to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AppNotification
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppNotificationCopyWith<AppNotification> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppNotificationCopyWith<$Res> {
  factory $AppNotificationCopyWith(
    AppNotification value,
    $Res Function(AppNotification) then,
  ) = _$AppNotificationCopyWithImpl<$Res, AppNotification>;
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredInt) int id,
    @JsonKey(fromJson: readRequiredText) String type,
    @JsonKey(fromJson: readRequiredText) String message,
    @JsonKey(fromJson: readRequiredText) String createdAt,
    @JsonKey(fromJson: readRequiredText) String readAt,
    @JsonKey(fromJson: readRequiredText) String category,
    @JsonKey(fromJson: readRequiredText) String priority,
    NotificationTarget? target,
    List<NotificationActionItem> actions,
    @JsonKey(fromJson: readRequiredText) String sourceName,
    @JsonKey(fromJson: readRequiredText) String sourcePhoto,
    @JsonKey(fromJson: readRequiredText) String sourceInitials,
    @JsonKey(fromJson: readRequiredText) String imageUrl,
    @JsonKey(fromJson: readRequiredText) String imageShape,
  });

  $NotificationTargetCopyWith<$Res>? get target;
}

/// @nodoc
class _$AppNotificationCopyWithImpl<$Res, $Val extends AppNotification>
    implements $AppNotificationCopyWith<$Res> {
  _$AppNotificationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppNotification
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? message = null,
    Object? createdAt = null,
    Object? readAt = null,
    Object? category = null,
    Object? priority = null,
    Object? target = freezed,
    Object? actions = null,
    Object? sourceName = null,
    Object? sourcePhoto = null,
    Object? sourceInitials = null,
    Object? imageUrl = null,
    Object? imageShape = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            message: null == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as String,
            readAt: null == readAt
                ? _value.readAt
                : readAt // ignore: cast_nullable_to_non_nullable
                      as String,
            category: null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as String,
            priority: null == priority
                ? _value.priority
                : priority // ignore: cast_nullable_to_non_nullable
                      as String,
            target: freezed == target
                ? _value.target
                : target // ignore: cast_nullable_to_non_nullable
                      as NotificationTarget?,
            actions: null == actions
                ? _value.actions
                : actions // ignore: cast_nullable_to_non_nullable
                      as List<NotificationActionItem>,
            sourceName: null == sourceName
                ? _value.sourceName
                : sourceName // ignore: cast_nullable_to_non_nullable
                      as String,
            sourcePhoto: null == sourcePhoto
                ? _value.sourcePhoto
                : sourcePhoto // ignore: cast_nullable_to_non_nullable
                      as String,
            sourceInitials: null == sourceInitials
                ? _value.sourceInitials
                : sourceInitials // ignore: cast_nullable_to_non_nullable
                      as String,
            imageUrl: null == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            imageShape: null == imageShape
                ? _value.imageShape
                : imageShape // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }

  /// Create a copy of AppNotification
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $NotificationTargetCopyWith<$Res>? get target {
    if (_value.target == null) {
      return null;
    }

    return $NotificationTargetCopyWith<$Res>(_value.target!, (value) {
      return _then(_value.copyWith(target: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AppNotificationImplCopyWith<$Res>
    implements $AppNotificationCopyWith<$Res> {
  factory _$$AppNotificationImplCopyWith(
    _$AppNotificationImpl value,
    $Res Function(_$AppNotificationImpl) then,
  ) = __$$AppNotificationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredInt) int id,
    @JsonKey(fromJson: readRequiredText) String type,
    @JsonKey(fromJson: readRequiredText) String message,
    @JsonKey(fromJson: readRequiredText) String createdAt,
    @JsonKey(fromJson: readRequiredText) String readAt,
    @JsonKey(fromJson: readRequiredText) String category,
    @JsonKey(fromJson: readRequiredText) String priority,
    NotificationTarget? target,
    List<NotificationActionItem> actions,
    @JsonKey(fromJson: readRequiredText) String sourceName,
    @JsonKey(fromJson: readRequiredText) String sourcePhoto,
    @JsonKey(fromJson: readRequiredText) String sourceInitials,
    @JsonKey(fromJson: readRequiredText) String imageUrl,
    @JsonKey(fromJson: readRequiredText) String imageShape,
  });

  @override
  $NotificationTargetCopyWith<$Res>? get target;
}

/// @nodoc
class __$$AppNotificationImplCopyWithImpl<$Res>
    extends _$AppNotificationCopyWithImpl<$Res, _$AppNotificationImpl>
    implements _$$AppNotificationImplCopyWith<$Res> {
  __$$AppNotificationImplCopyWithImpl(
    _$AppNotificationImpl _value,
    $Res Function(_$AppNotificationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppNotification
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? message = null,
    Object? createdAt = null,
    Object? readAt = null,
    Object? category = null,
    Object? priority = null,
    Object? target = freezed,
    Object? actions = null,
    Object? sourceName = null,
    Object? sourcePhoto = null,
    Object? sourceInitials = null,
    Object? imageUrl = null,
    Object? imageShape = null,
  }) {
    return _then(
      _$AppNotificationImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as String,
        readAt: null == readAt
            ? _value.readAt
            : readAt // ignore: cast_nullable_to_non_nullable
                  as String,
        category: null == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as String,
        priority: null == priority
            ? _value.priority
            : priority // ignore: cast_nullable_to_non_nullable
                  as String,
        target: freezed == target
            ? _value.target
            : target // ignore: cast_nullable_to_non_nullable
                  as NotificationTarget?,
        actions: null == actions
            ? _value._actions
            : actions // ignore: cast_nullable_to_non_nullable
                  as List<NotificationActionItem>,
        sourceName: null == sourceName
            ? _value.sourceName
            : sourceName // ignore: cast_nullable_to_non_nullable
                  as String,
        sourcePhoto: null == sourcePhoto
            ? _value.sourcePhoto
            : sourcePhoto // ignore: cast_nullable_to_non_nullable
                  as String,
        sourceInitials: null == sourceInitials
            ? _value.sourceInitials
            : sourceInitials // ignore: cast_nullable_to_non_nullable
                  as String,
        imageUrl: null == imageUrl
            ? _value.imageUrl
            : imageUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        imageShape: null == imageShape
            ? _value.imageShape
            : imageShape // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AppNotificationImpl extends _AppNotification {
  const _$AppNotificationImpl({
    @JsonKey(fromJson: readRequiredInt) required this.id,
    @JsonKey(fromJson: readRequiredText) required this.type,
    @JsonKey(fromJson: readRequiredText) required this.message,
    @JsonKey(fromJson: readRequiredText) required this.createdAt,
    @JsonKey(fromJson: readRequiredText) required this.readAt,
    @JsonKey(fromJson: readRequiredText) required this.category,
    @JsonKey(fromJson: readRequiredText) required this.priority,
    this.target,
    final List<NotificationActionItem> actions =
        const <NotificationActionItem>[],
    @JsonKey(fromJson: readRequiredText) required this.sourceName,
    @JsonKey(fromJson: readRequiredText) required this.sourcePhoto,
    @JsonKey(fromJson: readRequiredText) required this.sourceInitials,
    @JsonKey(fromJson: readRequiredText) required this.imageUrl,
    @JsonKey(fromJson: readRequiredText) required this.imageShape,
  }) : _actions = actions,
       super._();

  factory _$AppNotificationImpl.fromJson(Map<String, dynamic> json) =>
      _$$AppNotificationImplFromJson(json);

  @override
  @JsonKey(fromJson: readRequiredInt)
  final int id;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String type;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String message;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String createdAt;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String readAt;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String category;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String priority;
  @override
  final NotificationTarget? target;
  final List<NotificationActionItem> _actions;
  @override
  @JsonKey()
  List<NotificationActionItem> get actions {
    if (_actions is EqualUnmodifiableListView) return _actions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_actions);
  }

  @override
  @JsonKey(fromJson: readRequiredText)
  final String sourceName;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String sourcePhoto;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String sourceInitials;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String imageUrl;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String imageShape;

  @override
  String toString() {
    return 'AppNotification(id: $id, type: $type, message: $message, createdAt: $createdAt, readAt: $readAt, category: $category, priority: $priority, target: $target, actions: $actions, sourceName: $sourceName, sourcePhoto: $sourcePhoto, sourceInitials: $sourceInitials, imageUrl: $imageUrl, imageShape: $imageShape)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppNotificationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.readAt, readAt) || other.readAt == readAt) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.target, target) || other.target == target) &&
            const DeepCollectionEquality().equals(other._actions, _actions) &&
            (identical(other.sourceName, sourceName) ||
                other.sourceName == sourceName) &&
            (identical(other.sourcePhoto, sourcePhoto) ||
                other.sourcePhoto == sourcePhoto) &&
            (identical(other.sourceInitials, sourceInitials) ||
                other.sourceInitials == sourceInitials) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.imageShape, imageShape) ||
                other.imageShape == imageShape));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    type,
    message,
    createdAt,
    readAt,
    category,
    priority,
    target,
    const DeepCollectionEquality().hash(_actions),
    sourceName,
    sourcePhoto,
    sourceInitials,
    imageUrl,
    imageShape,
  );

  /// Create a copy of AppNotification
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppNotificationImplCopyWith<_$AppNotificationImpl> get copyWith =>
      __$$AppNotificationImplCopyWithImpl<_$AppNotificationImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AppNotificationImplToJson(this);
  }
}

abstract class _AppNotification extends AppNotification {
  const factory _AppNotification({
    @JsonKey(fromJson: readRequiredInt) required final int id,
    @JsonKey(fromJson: readRequiredText) required final String type,
    @JsonKey(fromJson: readRequiredText) required final String message,
    @JsonKey(fromJson: readRequiredText) required final String createdAt,
    @JsonKey(fromJson: readRequiredText) required final String readAt,
    @JsonKey(fromJson: readRequiredText) required final String category,
    @JsonKey(fromJson: readRequiredText) required final String priority,
    final NotificationTarget? target,
    final List<NotificationActionItem> actions,
    @JsonKey(fromJson: readRequiredText) required final String sourceName,
    @JsonKey(fromJson: readRequiredText) required final String sourcePhoto,
    @JsonKey(fromJson: readRequiredText) required final String sourceInitials,
    @JsonKey(fromJson: readRequiredText) required final String imageUrl,
    @JsonKey(fromJson: readRequiredText) required final String imageShape,
  }) = _$AppNotificationImpl;
  const _AppNotification._() : super._();

  factory _AppNotification.fromJson(Map<String, dynamic> json) =
      _$AppNotificationImpl.fromJson;

  @override
  @JsonKey(fromJson: readRequiredInt)
  int get id;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get type;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get message;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get createdAt;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get readAt;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get category;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get priority;
  @override
  NotificationTarget? get target;
  @override
  List<NotificationActionItem> get actions;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get sourceName;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get sourcePhoto;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get sourceInitials;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get imageUrl;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get imageShape;

  /// Create a copy of AppNotification
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppNotificationImplCopyWith<_$AppNotificationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

NotificationPreferences _$NotificationPreferencesFromJson(
  Map<String, dynamic> json,
) {
  return _NotificationPreferences.fromJson(json);
}

/// @nodoc
mixin _$NotificationPreferences {
  @NotificationCategoryConverter()
  Map<String, bool> get categories => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredBool)
  bool get quietModeEnabled => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get quietModeStart => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get quietModeEnd => throw _privateConstructorUsedError;

  /// Serializes this NotificationPreferences to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NotificationPreferences
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NotificationPreferencesCopyWith<NotificationPreferences> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NotificationPreferencesCopyWith<$Res> {
  factory $NotificationPreferencesCopyWith(
    NotificationPreferences value,
    $Res Function(NotificationPreferences) then,
  ) = _$NotificationPreferencesCopyWithImpl<$Res, NotificationPreferences>;
  @useResult
  $Res call({
    @NotificationCategoryConverter() Map<String, bool> categories,
    @JsonKey(fromJson: readRequiredBool) bool quietModeEnabled,
    @JsonKey(fromJson: readRequiredText) String quietModeStart,
    @JsonKey(fromJson: readRequiredText) String quietModeEnd,
  });
}

/// @nodoc
class _$NotificationPreferencesCopyWithImpl<
  $Res,
  $Val extends NotificationPreferences
>
    implements $NotificationPreferencesCopyWith<$Res> {
  _$NotificationPreferencesCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NotificationPreferences
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? categories = null,
    Object? quietModeEnabled = null,
    Object? quietModeStart = null,
    Object? quietModeEnd = null,
  }) {
    return _then(
      _value.copyWith(
            categories: null == categories
                ? _value.categories
                : categories // ignore: cast_nullable_to_non_nullable
                      as Map<String, bool>,
            quietModeEnabled: null == quietModeEnabled
                ? _value.quietModeEnabled
                : quietModeEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            quietModeStart: null == quietModeStart
                ? _value.quietModeStart
                : quietModeStart // ignore: cast_nullable_to_non_nullable
                      as String,
            quietModeEnd: null == quietModeEnd
                ? _value.quietModeEnd
                : quietModeEnd // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NotificationPreferencesImplCopyWith<$Res>
    implements $NotificationPreferencesCopyWith<$Res> {
  factory _$$NotificationPreferencesImplCopyWith(
    _$NotificationPreferencesImpl value,
    $Res Function(_$NotificationPreferencesImpl) then,
  ) = __$$NotificationPreferencesImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @NotificationCategoryConverter() Map<String, bool> categories,
    @JsonKey(fromJson: readRequiredBool) bool quietModeEnabled,
    @JsonKey(fromJson: readRequiredText) String quietModeStart,
    @JsonKey(fromJson: readRequiredText) String quietModeEnd,
  });
}

/// @nodoc
class __$$NotificationPreferencesImplCopyWithImpl<$Res>
    extends
        _$NotificationPreferencesCopyWithImpl<
          $Res,
          _$NotificationPreferencesImpl
        >
    implements _$$NotificationPreferencesImplCopyWith<$Res> {
  __$$NotificationPreferencesImplCopyWithImpl(
    _$NotificationPreferencesImpl _value,
    $Res Function(_$NotificationPreferencesImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NotificationPreferences
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? categories = null,
    Object? quietModeEnabled = null,
    Object? quietModeStart = null,
    Object? quietModeEnd = null,
  }) {
    return _then(
      _$NotificationPreferencesImpl(
        categories: null == categories
            ? _value._categories
            : categories // ignore: cast_nullable_to_non_nullable
                  as Map<String, bool>,
        quietModeEnabled: null == quietModeEnabled
            ? _value.quietModeEnabled
            : quietModeEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        quietModeStart: null == quietModeStart
            ? _value.quietModeStart
            : quietModeStart // ignore: cast_nullable_to_non_nullable
                  as String,
        quietModeEnd: null == quietModeEnd
            ? _value.quietModeEnd
            : quietModeEnd // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$NotificationPreferencesImpl implements _NotificationPreferences {
  const _$NotificationPreferencesImpl({
    @NotificationCategoryConverter()
    required final Map<String, bool> categories,
    @JsonKey(fromJson: readRequiredBool) required this.quietModeEnabled,
    @JsonKey(fromJson: readRequiredText) required this.quietModeStart,
    @JsonKey(fromJson: readRequiredText) required this.quietModeEnd,
  }) : _categories = categories;

  factory _$NotificationPreferencesImpl.fromJson(Map<String, dynamic> json) =>
      _$$NotificationPreferencesImplFromJson(json);

  final Map<String, bool> _categories;
  @override
  @NotificationCategoryConverter()
  Map<String, bool> get categories {
    if (_categories is EqualUnmodifiableMapView) return _categories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_categories);
  }

  @override
  @JsonKey(fromJson: readRequiredBool)
  final bool quietModeEnabled;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String quietModeStart;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String quietModeEnd;

  @override
  String toString() {
    return 'NotificationPreferences(categories: $categories, quietModeEnabled: $quietModeEnabled, quietModeStart: $quietModeStart, quietModeEnd: $quietModeEnd)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NotificationPreferencesImpl &&
            const DeepCollectionEquality().equals(
              other._categories,
              _categories,
            ) &&
            (identical(other.quietModeEnabled, quietModeEnabled) ||
                other.quietModeEnabled == quietModeEnabled) &&
            (identical(other.quietModeStart, quietModeStart) ||
                other.quietModeStart == quietModeStart) &&
            (identical(other.quietModeEnd, quietModeEnd) ||
                other.quietModeEnd == quietModeEnd));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_categories),
    quietModeEnabled,
    quietModeStart,
    quietModeEnd,
  );

  /// Create a copy of NotificationPreferences
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NotificationPreferencesImplCopyWith<_$NotificationPreferencesImpl>
  get copyWith =>
      __$$NotificationPreferencesImplCopyWithImpl<
        _$NotificationPreferencesImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NotificationPreferencesImplToJson(this);
  }
}

abstract class _NotificationPreferences implements NotificationPreferences {
  const factory _NotificationPreferences({
    @NotificationCategoryConverter()
    required final Map<String, bool> categories,
    @JsonKey(fromJson: readRequiredBool) required final bool quietModeEnabled,
    @JsonKey(fromJson: readRequiredText) required final String quietModeStart,
    @JsonKey(fromJson: readRequiredText) required final String quietModeEnd,
  }) = _$NotificationPreferencesImpl;

  factory _NotificationPreferences.fromJson(Map<String, dynamic> json) =
      _$NotificationPreferencesImpl.fromJson;

  @override
  @NotificationCategoryConverter()
  Map<String, bool> get categories;
  @override
  @JsonKey(fromJson: readRequiredBool)
  bool get quietModeEnabled;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get quietModeStart;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get quietModeEnd;

  /// Create a copy of NotificationPreferences
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NotificationPreferencesImplCopyWith<_$NotificationPreferencesImpl>
  get copyWith => throw _privateConstructorUsedError;
}
