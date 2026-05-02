// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notifications_repository.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NotificationTarget {

@JsonKey(fromJson: readRequiredText) String get route;@JsonKey(fromJson: readRequiredText) String get href;@JsonKey(fromJson: readRequiredText) String get label;
/// Create a copy of NotificationTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationTargetCopyWith<NotificationTarget> get copyWith => _$NotificationTargetCopyWithImpl<NotificationTarget>(this as NotificationTarget, _$identity);

  /// Serializes this NotificationTarget to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationTarget&&(identical(other.route, route) || other.route == route)&&(identical(other.href, href) || other.href == href)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,route,href,label);

@override
String toString() {
  return 'NotificationTarget(route: $route, href: $href, label: $label)';
}


}

/// @nodoc
abstract mixin class $NotificationTargetCopyWith<$Res>  {
  factory $NotificationTargetCopyWith(NotificationTarget value, $Res Function(NotificationTarget) _then) = _$NotificationTargetCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: readRequiredText) String route,@JsonKey(fromJson: readRequiredText) String href,@JsonKey(fromJson: readRequiredText) String label
});




}
/// @nodoc
class _$NotificationTargetCopyWithImpl<$Res>
    implements $NotificationTargetCopyWith<$Res> {
  _$NotificationTargetCopyWithImpl(this._self, this._then);

  final NotificationTarget _self;
  final $Res Function(NotificationTarget) _then;

/// Create a copy of NotificationTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? route = null,Object? href = null,Object? label = null,}) {
  return _then(_self.copyWith(
route: null == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as String,href: null == href ? _self.href : href // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationTarget].
extension NotificationTargetPatterns on NotificationTarget {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationTarget value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationTarget() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationTarget value)  $default,){
final _that = this;
switch (_that) {
case _NotificationTarget():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationTarget value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationTarget() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredText)  String route, @JsonKey(fromJson: readRequiredText)  String href, @JsonKey(fromJson: readRequiredText)  String label)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationTarget() when $default != null:
return $default(_that.route,_that.href,_that.label);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredText)  String route, @JsonKey(fromJson: readRequiredText)  String href, @JsonKey(fromJson: readRequiredText)  String label)  $default,) {final _that = this;
switch (_that) {
case _NotificationTarget():
return $default(_that.route,_that.href,_that.label);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: readRequiredText)  String route, @JsonKey(fromJson: readRequiredText)  String href, @JsonKey(fromJson: readRequiredText)  String label)?  $default,) {final _that = this;
switch (_that) {
case _NotificationTarget() when $default != null:
return $default(_that.route,_that.href,_that.label);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NotificationTarget implements NotificationTarget {
  const _NotificationTarget({@JsonKey(fromJson: readRequiredText) required this.route, @JsonKey(fromJson: readRequiredText) required this.href, @JsonKey(fromJson: readRequiredText) required this.label});
  factory _NotificationTarget.fromJson(Map<String, dynamic> json) => _$NotificationTargetFromJson(json);

@override@JsonKey(fromJson: readRequiredText) final  String route;
@override@JsonKey(fromJson: readRequiredText) final  String href;
@override@JsonKey(fromJson: readRequiredText) final  String label;

/// Create a copy of NotificationTarget
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationTargetCopyWith<_NotificationTarget> get copyWith => __$NotificationTargetCopyWithImpl<_NotificationTarget>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationTargetToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationTarget&&(identical(other.route, route) || other.route == route)&&(identical(other.href, href) || other.href == href)&&(identical(other.label, label) || other.label == label));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,route,href,label);

@override
String toString() {
  return 'NotificationTarget(route: $route, href: $href, label: $label)';
}


}

/// @nodoc
abstract mixin class _$NotificationTargetCopyWith<$Res> implements $NotificationTargetCopyWith<$Res> {
  factory _$NotificationTargetCopyWith(_NotificationTarget value, $Res Function(_NotificationTarget) _then) = __$NotificationTargetCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: readRequiredText) String route,@JsonKey(fromJson: readRequiredText) String href,@JsonKey(fromJson: readRequiredText) String label
});




}
/// @nodoc
class __$NotificationTargetCopyWithImpl<$Res>
    implements _$NotificationTargetCopyWith<$Res> {
  __$NotificationTargetCopyWithImpl(this._self, this._then);

  final _NotificationTarget _self;
  final $Res Function(_NotificationTarget) _then;

/// Create a copy of NotificationTarget
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? route = null,Object? href = null,Object? label = null,}) {
  return _then(_NotificationTarget(
route: null == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as String,href: null == href ? _self.href : href // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$NotificationActionItem {

@JsonKey(fromJson: readRequiredText) String get kind;@JsonKey(fromJson: _readActionLabel) String get label;@JsonKey(fromJson: readRequiredText) String get endpoint;@JsonKey(fromJson: _readActionMethod) String get method;
/// Create a copy of NotificationActionItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationActionItemCopyWith<NotificationActionItem> get copyWith => _$NotificationActionItemCopyWithImpl<NotificationActionItem>(this as NotificationActionItem, _$identity);

  /// Serializes this NotificationActionItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationActionItem&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.label, label) || other.label == label)&&(identical(other.endpoint, endpoint) || other.endpoint == endpoint)&&(identical(other.method, method) || other.method == method));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,label,endpoint,method);

@override
String toString() {
  return 'NotificationActionItem(kind: $kind, label: $label, endpoint: $endpoint, method: $method)';
}


}

/// @nodoc
abstract mixin class $NotificationActionItemCopyWith<$Res>  {
  factory $NotificationActionItemCopyWith(NotificationActionItem value, $Res Function(NotificationActionItem) _then) = _$NotificationActionItemCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: readRequiredText) String kind,@JsonKey(fromJson: _readActionLabel) String label,@JsonKey(fromJson: readRequiredText) String endpoint,@JsonKey(fromJson: _readActionMethod) String method
});




}
/// @nodoc
class _$NotificationActionItemCopyWithImpl<$Res>
    implements $NotificationActionItemCopyWith<$Res> {
  _$NotificationActionItemCopyWithImpl(this._self, this._then);

  final NotificationActionItem _self;
  final $Res Function(NotificationActionItem) _then;

/// Create a copy of NotificationActionItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? label = null,Object? endpoint = null,Object? method = null,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,endpoint: null == endpoint ? _self.endpoint : endpoint // ignore: cast_nullable_to_non_nullable
as String,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationActionItem].
extension NotificationActionItemPatterns on NotificationActionItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationActionItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationActionItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationActionItem value)  $default,){
final _that = this;
switch (_that) {
case _NotificationActionItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationActionItem value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationActionItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredText)  String kind, @JsonKey(fromJson: _readActionLabel)  String label, @JsonKey(fromJson: readRequiredText)  String endpoint, @JsonKey(fromJson: _readActionMethod)  String method)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationActionItem() when $default != null:
return $default(_that.kind,_that.label,_that.endpoint,_that.method);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredText)  String kind, @JsonKey(fromJson: _readActionLabel)  String label, @JsonKey(fromJson: readRequiredText)  String endpoint, @JsonKey(fromJson: _readActionMethod)  String method)  $default,) {final _that = this;
switch (_that) {
case _NotificationActionItem():
return $default(_that.kind,_that.label,_that.endpoint,_that.method);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: readRequiredText)  String kind, @JsonKey(fromJson: _readActionLabel)  String label, @JsonKey(fromJson: readRequiredText)  String endpoint, @JsonKey(fromJson: _readActionMethod)  String method)?  $default,) {final _that = this;
switch (_that) {
case _NotificationActionItem() when $default != null:
return $default(_that.kind,_that.label,_that.endpoint,_that.method);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NotificationActionItem implements NotificationActionItem {
  const _NotificationActionItem({@JsonKey(fromJson: readRequiredText) required this.kind, @JsonKey(fromJson: _readActionLabel) required this.label, @JsonKey(fromJson: readRequiredText) required this.endpoint, @JsonKey(fromJson: _readActionMethod) required this.method});
  factory _NotificationActionItem.fromJson(Map<String, dynamic> json) => _$NotificationActionItemFromJson(json);

@override@JsonKey(fromJson: readRequiredText) final  String kind;
@override@JsonKey(fromJson: _readActionLabel) final  String label;
@override@JsonKey(fromJson: readRequiredText) final  String endpoint;
@override@JsonKey(fromJson: _readActionMethod) final  String method;

/// Create a copy of NotificationActionItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationActionItemCopyWith<_NotificationActionItem> get copyWith => __$NotificationActionItemCopyWithImpl<_NotificationActionItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationActionItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationActionItem&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.label, label) || other.label == label)&&(identical(other.endpoint, endpoint) || other.endpoint == endpoint)&&(identical(other.method, method) || other.method == method));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,label,endpoint,method);

@override
String toString() {
  return 'NotificationActionItem(kind: $kind, label: $label, endpoint: $endpoint, method: $method)';
}


}

/// @nodoc
abstract mixin class _$NotificationActionItemCopyWith<$Res> implements $NotificationActionItemCopyWith<$Res> {
  factory _$NotificationActionItemCopyWith(_NotificationActionItem value, $Res Function(_NotificationActionItem) _then) = __$NotificationActionItemCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: readRequiredText) String kind,@JsonKey(fromJson: _readActionLabel) String label,@JsonKey(fromJson: readRequiredText) String endpoint,@JsonKey(fromJson: _readActionMethod) String method
});




}
/// @nodoc
class __$NotificationActionItemCopyWithImpl<$Res>
    implements _$NotificationActionItemCopyWith<$Res> {
  __$NotificationActionItemCopyWithImpl(this._self, this._then);

  final _NotificationActionItem _self;
  final $Res Function(_NotificationActionItem) _then;

/// Create a copy of NotificationActionItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? label = null,Object? endpoint = null,Object? method = null,}) {
  return _then(_NotificationActionItem(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,endpoint: null == endpoint ? _self.endpoint : endpoint // ignore: cast_nullable_to_non_nullable
as String,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$AppNotification {

@JsonKey(fromJson: readRequiredInt) int get id;@JsonKey(fromJson: readRequiredText) String get type;@JsonKey(fromJson: readRequiredText) String get message;@JsonKey(fromJson: readRequiredText) String get createdAt;@JsonKey(fromJson: readRequiredText) String get readAt;@JsonKey(fromJson: readRequiredText) String get category;@JsonKey(fromJson: readRequiredText) String get priority; NotificationTarget? get target; List<NotificationActionItem> get actions;@JsonKey(fromJson: readRequiredText) String get sourceName;@JsonKey(fromJson: readRequiredText) String get sourcePhoto;@JsonKey(fromJson: readRequiredText) String get sourceInitials;@JsonKey(fromJson: readRequiredText) String get imageUrl;@JsonKey(fromJson: readRequiredText) String get imageShape;
/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppNotificationCopyWith<AppNotification> get copyWith => _$AppNotificationCopyWithImpl<AppNotification>(this as AppNotification, _$identity);

  /// Serializes this AppNotification to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppNotification&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.message, message) || other.message == message)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&(identical(other.category, category) || other.category == category)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.target, target) || other.target == target)&&const DeepCollectionEquality().equals(other.actions, actions)&&(identical(other.sourceName, sourceName) || other.sourceName == sourceName)&&(identical(other.sourcePhoto, sourcePhoto) || other.sourcePhoto == sourcePhoto)&&(identical(other.sourceInitials, sourceInitials) || other.sourceInitials == sourceInitials)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.imageShape, imageShape) || other.imageShape == imageShape));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,message,createdAt,readAt,category,priority,target,const DeepCollectionEquality().hash(actions),sourceName,sourcePhoto,sourceInitials,imageUrl,imageShape);

@override
String toString() {
  return 'AppNotification(id: $id, type: $type, message: $message, createdAt: $createdAt, readAt: $readAt, category: $category, priority: $priority, target: $target, actions: $actions, sourceName: $sourceName, sourcePhoto: $sourcePhoto, sourceInitials: $sourceInitials, imageUrl: $imageUrl, imageShape: $imageShape)';
}


}

/// @nodoc
abstract mixin class $AppNotificationCopyWith<$Res>  {
  factory $AppNotificationCopyWith(AppNotification value, $Res Function(AppNotification) _then) = _$AppNotificationCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: readRequiredInt) int id,@JsonKey(fromJson: readRequiredText) String type,@JsonKey(fromJson: readRequiredText) String message,@JsonKey(fromJson: readRequiredText) String createdAt,@JsonKey(fromJson: readRequiredText) String readAt,@JsonKey(fromJson: readRequiredText) String category,@JsonKey(fromJson: readRequiredText) String priority, NotificationTarget? target, List<NotificationActionItem> actions,@JsonKey(fromJson: readRequiredText) String sourceName,@JsonKey(fromJson: readRequiredText) String sourcePhoto,@JsonKey(fromJson: readRequiredText) String sourceInitials,@JsonKey(fromJson: readRequiredText) String imageUrl,@JsonKey(fromJson: readRequiredText) String imageShape
});


$NotificationTargetCopyWith<$Res>? get target;

}
/// @nodoc
class _$AppNotificationCopyWithImpl<$Res>
    implements $AppNotificationCopyWith<$Res> {
  _$AppNotificationCopyWithImpl(this._self, this._then);

  final AppNotification _self;
  final $Res Function(AppNotification) _then;

/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? message = null,Object? createdAt = null,Object? readAt = null,Object? category = null,Object? priority = null,Object? target = freezed,Object? actions = null,Object? sourceName = null,Object? sourcePhoto = null,Object? sourceInitials = null,Object? imageUrl = null,Object? imageShape = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,readAt: null == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as String,target: freezed == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as NotificationTarget?,actions: null == actions ? _self.actions : actions // ignore: cast_nullable_to_non_nullable
as List<NotificationActionItem>,sourceName: null == sourceName ? _self.sourceName : sourceName // ignore: cast_nullable_to_non_nullable
as String,sourcePhoto: null == sourcePhoto ? _self.sourcePhoto : sourcePhoto // ignore: cast_nullable_to_non_nullable
as String,sourceInitials: null == sourceInitials ? _self.sourceInitials : sourceInitials // ignore: cast_nullable_to_non_nullable
as String,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,imageShape: null == imageShape ? _self.imageShape : imageShape // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationTargetCopyWith<$Res>? get target {
    if (_self.target == null) {
    return null;
  }

  return $NotificationTargetCopyWith<$Res>(_self.target!, (value) {
    return _then(_self.copyWith(target: value));
  });
}
}


/// Adds pattern-matching-related methods to [AppNotification].
extension AppNotificationPatterns on AppNotification {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppNotification value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppNotification value)  $default,){
final _that = this;
switch (_that) {
case _AppNotification():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppNotification value)?  $default,){
final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredInt)  int id, @JsonKey(fromJson: readRequiredText)  String type, @JsonKey(fromJson: readRequiredText)  String message, @JsonKey(fromJson: readRequiredText)  String createdAt, @JsonKey(fromJson: readRequiredText)  String readAt, @JsonKey(fromJson: readRequiredText)  String category, @JsonKey(fromJson: readRequiredText)  String priority,  NotificationTarget? target,  List<NotificationActionItem> actions, @JsonKey(fromJson: readRequiredText)  String sourceName, @JsonKey(fromJson: readRequiredText)  String sourcePhoto, @JsonKey(fromJson: readRequiredText)  String sourceInitials, @JsonKey(fromJson: readRequiredText)  String imageUrl, @JsonKey(fromJson: readRequiredText)  String imageShape)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
return $default(_that.id,_that.type,_that.message,_that.createdAt,_that.readAt,_that.category,_that.priority,_that.target,_that.actions,_that.sourceName,_that.sourcePhoto,_that.sourceInitials,_that.imageUrl,_that.imageShape);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredInt)  int id, @JsonKey(fromJson: readRequiredText)  String type, @JsonKey(fromJson: readRequiredText)  String message, @JsonKey(fromJson: readRequiredText)  String createdAt, @JsonKey(fromJson: readRequiredText)  String readAt, @JsonKey(fromJson: readRequiredText)  String category, @JsonKey(fromJson: readRequiredText)  String priority,  NotificationTarget? target,  List<NotificationActionItem> actions, @JsonKey(fromJson: readRequiredText)  String sourceName, @JsonKey(fromJson: readRequiredText)  String sourcePhoto, @JsonKey(fromJson: readRequiredText)  String sourceInitials, @JsonKey(fromJson: readRequiredText)  String imageUrl, @JsonKey(fromJson: readRequiredText)  String imageShape)  $default,) {final _that = this;
switch (_that) {
case _AppNotification():
return $default(_that.id,_that.type,_that.message,_that.createdAt,_that.readAt,_that.category,_that.priority,_that.target,_that.actions,_that.sourceName,_that.sourcePhoto,_that.sourceInitials,_that.imageUrl,_that.imageShape);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: readRequiredInt)  int id, @JsonKey(fromJson: readRequiredText)  String type, @JsonKey(fromJson: readRequiredText)  String message, @JsonKey(fromJson: readRequiredText)  String createdAt, @JsonKey(fromJson: readRequiredText)  String readAt, @JsonKey(fromJson: readRequiredText)  String category, @JsonKey(fromJson: readRequiredText)  String priority,  NotificationTarget? target,  List<NotificationActionItem> actions, @JsonKey(fromJson: readRequiredText)  String sourceName, @JsonKey(fromJson: readRequiredText)  String sourcePhoto, @JsonKey(fromJson: readRequiredText)  String sourceInitials, @JsonKey(fromJson: readRequiredText)  String imageUrl, @JsonKey(fromJson: readRequiredText)  String imageShape)?  $default,) {final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
return $default(_that.id,_that.type,_that.message,_that.createdAt,_that.readAt,_that.category,_that.priority,_that.target,_that.actions,_that.sourceName,_that.sourcePhoto,_that.sourceInitials,_that.imageUrl,_that.imageShape);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppNotification extends AppNotification {
  const _AppNotification({@JsonKey(fromJson: readRequiredInt) required this.id, @JsonKey(fromJson: readRequiredText) required this.type, @JsonKey(fromJson: readRequiredText) required this.message, @JsonKey(fromJson: readRequiredText) required this.createdAt, @JsonKey(fromJson: readRequiredText) required this.readAt, @JsonKey(fromJson: readRequiredText) required this.category, @JsonKey(fromJson: readRequiredText) required this.priority, this.target, final  List<NotificationActionItem> actions = const <NotificationActionItem>[], @JsonKey(fromJson: readRequiredText) required this.sourceName, @JsonKey(fromJson: readRequiredText) required this.sourcePhoto, @JsonKey(fromJson: readRequiredText) required this.sourceInitials, @JsonKey(fromJson: readRequiredText) required this.imageUrl, @JsonKey(fromJson: readRequiredText) required this.imageShape}): _actions = actions,super._();
  factory _AppNotification.fromJson(Map<String, dynamic> json) => _$AppNotificationFromJson(json);

@override@JsonKey(fromJson: readRequiredInt) final  int id;
@override@JsonKey(fromJson: readRequiredText) final  String type;
@override@JsonKey(fromJson: readRequiredText) final  String message;
@override@JsonKey(fromJson: readRequiredText) final  String createdAt;
@override@JsonKey(fromJson: readRequiredText) final  String readAt;
@override@JsonKey(fromJson: readRequiredText) final  String category;
@override@JsonKey(fromJson: readRequiredText) final  String priority;
@override final  NotificationTarget? target;
 final  List<NotificationActionItem> _actions;
@override@JsonKey() List<NotificationActionItem> get actions {
  if (_actions is EqualUnmodifiableListView) return _actions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_actions);
}

@override@JsonKey(fromJson: readRequiredText) final  String sourceName;
@override@JsonKey(fromJson: readRequiredText) final  String sourcePhoto;
@override@JsonKey(fromJson: readRequiredText) final  String sourceInitials;
@override@JsonKey(fromJson: readRequiredText) final  String imageUrl;
@override@JsonKey(fromJson: readRequiredText) final  String imageShape;

/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppNotificationCopyWith<_AppNotification> get copyWith => __$AppNotificationCopyWithImpl<_AppNotification>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppNotificationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppNotification&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.message, message) || other.message == message)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&(identical(other.category, category) || other.category == category)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.target, target) || other.target == target)&&const DeepCollectionEquality().equals(other._actions, _actions)&&(identical(other.sourceName, sourceName) || other.sourceName == sourceName)&&(identical(other.sourcePhoto, sourcePhoto) || other.sourcePhoto == sourcePhoto)&&(identical(other.sourceInitials, sourceInitials) || other.sourceInitials == sourceInitials)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.imageShape, imageShape) || other.imageShape == imageShape));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,message,createdAt,readAt,category,priority,target,const DeepCollectionEquality().hash(_actions),sourceName,sourcePhoto,sourceInitials,imageUrl,imageShape);

@override
String toString() {
  return 'AppNotification(id: $id, type: $type, message: $message, createdAt: $createdAt, readAt: $readAt, category: $category, priority: $priority, target: $target, actions: $actions, sourceName: $sourceName, sourcePhoto: $sourcePhoto, sourceInitials: $sourceInitials, imageUrl: $imageUrl, imageShape: $imageShape)';
}


}

/// @nodoc
abstract mixin class _$AppNotificationCopyWith<$Res> implements $AppNotificationCopyWith<$Res> {
  factory _$AppNotificationCopyWith(_AppNotification value, $Res Function(_AppNotification) _then) = __$AppNotificationCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: readRequiredInt) int id,@JsonKey(fromJson: readRequiredText) String type,@JsonKey(fromJson: readRequiredText) String message,@JsonKey(fromJson: readRequiredText) String createdAt,@JsonKey(fromJson: readRequiredText) String readAt,@JsonKey(fromJson: readRequiredText) String category,@JsonKey(fromJson: readRequiredText) String priority, NotificationTarget? target, List<NotificationActionItem> actions,@JsonKey(fromJson: readRequiredText) String sourceName,@JsonKey(fromJson: readRequiredText) String sourcePhoto,@JsonKey(fromJson: readRequiredText) String sourceInitials,@JsonKey(fromJson: readRequiredText) String imageUrl,@JsonKey(fromJson: readRequiredText) String imageShape
});


@override $NotificationTargetCopyWith<$Res>? get target;

}
/// @nodoc
class __$AppNotificationCopyWithImpl<$Res>
    implements _$AppNotificationCopyWith<$Res> {
  __$AppNotificationCopyWithImpl(this._self, this._then);

  final _AppNotification _self;
  final $Res Function(_AppNotification) _then;

/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? message = null,Object? createdAt = null,Object? readAt = null,Object? category = null,Object? priority = null,Object? target = freezed,Object? actions = null,Object? sourceName = null,Object? sourcePhoto = null,Object? sourceInitials = null,Object? imageUrl = null,Object? imageShape = null,}) {
  return _then(_AppNotification(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,readAt: null == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as String,target: freezed == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as NotificationTarget?,actions: null == actions ? _self._actions : actions // ignore: cast_nullable_to_non_nullable
as List<NotificationActionItem>,sourceName: null == sourceName ? _self.sourceName : sourceName // ignore: cast_nullable_to_non_nullable
as String,sourcePhoto: null == sourcePhoto ? _self.sourcePhoto : sourcePhoto // ignore: cast_nullable_to_non_nullable
as String,sourceInitials: null == sourceInitials ? _self.sourceInitials : sourceInitials // ignore: cast_nullable_to_non_nullable
as String,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,imageShape: null == imageShape ? _self.imageShape : imageShape // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationTargetCopyWith<$Res>? get target {
    if (_self.target == null) {
    return null;
  }

  return $NotificationTargetCopyWith<$Res>(_self.target!, (value) {
    return _then(_self.copyWith(target: value));
  });
}
}


/// @nodoc
mixin _$NotificationPreferences {

@NotificationCategoryConverter() Map<String, bool> get categories;@JsonKey(fromJson: readRequiredBool) bool get quietModeEnabled;@JsonKey(fromJson: readRequiredText) String get quietModeStart;@JsonKey(fromJson: readRequiredText) String get quietModeEnd;
/// Create a copy of NotificationPreferences
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationPreferencesCopyWith<NotificationPreferences> get copyWith => _$NotificationPreferencesCopyWithImpl<NotificationPreferences>(this as NotificationPreferences, _$identity);

  /// Serializes this NotificationPreferences to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationPreferences&&const DeepCollectionEquality().equals(other.categories, categories)&&(identical(other.quietModeEnabled, quietModeEnabled) || other.quietModeEnabled == quietModeEnabled)&&(identical(other.quietModeStart, quietModeStart) || other.quietModeStart == quietModeStart)&&(identical(other.quietModeEnd, quietModeEnd) || other.quietModeEnd == quietModeEnd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(categories),quietModeEnabled,quietModeStart,quietModeEnd);

@override
String toString() {
  return 'NotificationPreferences(categories: $categories, quietModeEnabled: $quietModeEnabled, quietModeStart: $quietModeStart, quietModeEnd: $quietModeEnd)';
}


}

/// @nodoc
abstract mixin class $NotificationPreferencesCopyWith<$Res>  {
  factory $NotificationPreferencesCopyWith(NotificationPreferences value, $Res Function(NotificationPreferences) _then) = _$NotificationPreferencesCopyWithImpl;
@useResult
$Res call({
@NotificationCategoryConverter() Map<String, bool> categories,@JsonKey(fromJson: readRequiredBool) bool quietModeEnabled,@JsonKey(fromJson: readRequiredText) String quietModeStart,@JsonKey(fromJson: readRequiredText) String quietModeEnd
});




}
/// @nodoc
class _$NotificationPreferencesCopyWithImpl<$Res>
    implements $NotificationPreferencesCopyWith<$Res> {
  _$NotificationPreferencesCopyWithImpl(this._self, this._then);

  final NotificationPreferences _self;
  final $Res Function(NotificationPreferences) _then;

/// Create a copy of NotificationPreferences
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? categories = null,Object? quietModeEnabled = null,Object? quietModeStart = null,Object? quietModeEnd = null,}) {
  return _then(_self.copyWith(
categories: null == categories ? _self.categories : categories // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,quietModeEnabled: null == quietModeEnabled ? _self.quietModeEnabled : quietModeEnabled // ignore: cast_nullable_to_non_nullable
as bool,quietModeStart: null == quietModeStart ? _self.quietModeStart : quietModeStart // ignore: cast_nullable_to_non_nullable
as String,quietModeEnd: null == quietModeEnd ? _self.quietModeEnd : quietModeEnd // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationPreferences].
extension NotificationPreferencesPatterns on NotificationPreferences {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationPreferences value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationPreferences() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationPreferences value)  $default,){
final _that = this;
switch (_that) {
case _NotificationPreferences():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationPreferences value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationPreferences() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@NotificationCategoryConverter()  Map<String, bool> categories, @JsonKey(fromJson: readRequiredBool)  bool quietModeEnabled, @JsonKey(fromJson: readRequiredText)  String quietModeStart, @JsonKey(fromJson: readRequiredText)  String quietModeEnd)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationPreferences() when $default != null:
return $default(_that.categories,_that.quietModeEnabled,_that.quietModeStart,_that.quietModeEnd);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@NotificationCategoryConverter()  Map<String, bool> categories, @JsonKey(fromJson: readRequiredBool)  bool quietModeEnabled, @JsonKey(fromJson: readRequiredText)  String quietModeStart, @JsonKey(fromJson: readRequiredText)  String quietModeEnd)  $default,) {final _that = this;
switch (_that) {
case _NotificationPreferences():
return $default(_that.categories,_that.quietModeEnabled,_that.quietModeStart,_that.quietModeEnd);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@NotificationCategoryConverter()  Map<String, bool> categories, @JsonKey(fromJson: readRequiredBool)  bool quietModeEnabled, @JsonKey(fromJson: readRequiredText)  String quietModeStart, @JsonKey(fromJson: readRequiredText)  String quietModeEnd)?  $default,) {final _that = this;
switch (_that) {
case _NotificationPreferences() when $default != null:
return $default(_that.categories,_that.quietModeEnabled,_that.quietModeStart,_that.quietModeEnd);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NotificationPreferences implements NotificationPreferences {
  const _NotificationPreferences({@NotificationCategoryConverter() required final  Map<String, bool> categories, @JsonKey(fromJson: readRequiredBool) required this.quietModeEnabled, @JsonKey(fromJson: readRequiredText) required this.quietModeStart, @JsonKey(fromJson: readRequiredText) required this.quietModeEnd}): _categories = categories;
  factory _NotificationPreferences.fromJson(Map<String, dynamic> json) => _$NotificationPreferencesFromJson(json);

 final  Map<String, bool> _categories;
@override@NotificationCategoryConverter() Map<String, bool> get categories {
  if (_categories is EqualUnmodifiableMapView) return _categories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_categories);
}

@override@JsonKey(fromJson: readRequiredBool) final  bool quietModeEnabled;
@override@JsonKey(fromJson: readRequiredText) final  String quietModeStart;
@override@JsonKey(fromJson: readRequiredText) final  String quietModeEnd;

/// Create a copy of NotificationPreferences
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationPreferencesCopyWith<_NotificationPreferences> get copyWith => __$NotificationPreferencesCopyWithImpl<_NotificationPreferences>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationPreferencesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationPreferences&&const DeepCollectionEquality().equals(other._categories, _categories)&&(identical(other.quietModeEnabled, quietModeEnabled) || other.quietModeEnabled == quietModeEnabled)&&(identical(other.quietModeStart, quietModeStart) || other.quietModeStart == quietModeStart)&&(identical(other.quietModeEnd, quietModeEnd) || other.quietModeEnd == quietModeEnd));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_categories),quietModeEnabled,quietModeStart,quietModeEnd);

@override
String toString() {
  return 'NotificationPreferences(categories: $categories, quietModeEnabled: $quietModeEnabled, quietModeStart: $quietModeStart, quietModeEnd: $quietModeEnd)';
}


}

/// @nodoc
abstract mixin class _$NotificationPreferencesCopyWith<$Res> implements $NotificationPreferencesCopyWith<$Res> {
  factory _$NotificationPreferencesCopyWith(_NotificationPreferences value, $Res Function(_NotificationPreferences) _then) = __$NotificationPreferencesCopyWithImpl;
@override @useResult
$Res call({
@NotificationCategoryConverter() Map<String, bool> categories,@JsonKey(fromJson: readRequiredBool) bool quietModeEnabled,@JsonKey(fromJson: readRequiredText) String quietModeStart,@JsonKey(fromJson: readRequiredText) String quietModeEnd
});




}
/// @nodoc
class __$NotificationPreferencesCopyWithImpl<$Res>
    implements _$NotificationPreferencesCopyWith<$Res> {
  __$NotificationPreferencesCopyWithImpl(this._self, this._then);

  final _NotificationPreferences _self;
  final $Res Function(_NotificationPreferences) _then;

/// Create a copy of NotificationPreferences
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? categories = null,Object? quietModeEnabled = null,Object? quietModeStart = null,Object? quietModeEnd = null,}) {
  return _then(_NotificationPreferences(
categories: null == categories ? _self._categories : categories // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,quietModeEnabled: null == quietModeEnabled ? _self.quietModeEnabled : quietModeEnabled // ignore: cast_nullable_to_non_nullable
as bool,quietModeStart: null == quietModeStart ? _self.quietModeStart : quietModeStart // ignore: cast_nullable_to_non_nullable
as String,quietModeEnd: null == quietModeEnd ? _self.quietModeEnd : quietModeEnd // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
