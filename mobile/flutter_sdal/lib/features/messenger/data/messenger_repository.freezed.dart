// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'messenger_repository.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MessengerContact implements DiagnosticableTreeMixin {

@JsonKey(fromJson: readRequiredInt) int get id;@JsonKey(fromJson: readRequiredText) String get name;@JsonKey(fromJson: readRequiredText) String get handle;@JsonKey(fromJson: readRequiredText) String get photo;@JsonKey(fromJson: readRequiredBool) bool get verified;
/// Create a copy of MessengerContact
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessengerContactCopyWith<MessengerContact> get copyWith => _$MessengerContactCopyWithImpl<MessengerContact>(this as MessengerContact, _$identity);

  /// Serializes this MessengerContact to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'MessengerContact'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('name', name))..add(DiagnosticsProperty('handle', handle))..add(DiagnosticsProperty('photo', photo))..add(DiagnosticsProperty('verified', verified));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessengerContact&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.handle, handle) || other.handle == handle)&&(identical(other.photo, photo) || other.photo == photo)&&(identical(other.verified, verified) || other.verified == verified));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,handle,photo,verified);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'MessengerContact(id: $id, name: $name, handle: $handle, photo: $photo, verified: $verified)';
}


}

/// @nodoc
abstract mixin class $MessengerContactCopyWith<$Res>  {
  factory $MessengerContactCopyWith(MessengerContact value, $Res Function(MessengerContact) _then) = _$MessengerContactCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: readRequiredInt) int id,@JsonKey(fromJson: readRequiredText) String name,@JsonKey(fromJson: readRequiredText) String handle,@JsonKey(fromJson: readRequiredText) String photo,@JsonKey(fromJson: readRequiredBool) bool verified
});




}
/// @nodoc
class _$MessengerContactCopyWithImpl<$Res>
    implements $MessengerContactCopyWith<$Res> {
  _$MessengerContactCopyWithImpl(this._self, this._then);

  final MessengerContact _self;
  final $Res Function(MessengerContact) _then;

/// Create a copy of MessengerContact
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? handle = null,Object? photo = null,Object? verified = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,handle: null == handle ? _self.handle : handle // ignore: cast_nullable_to_non_nullable
as String,photo: null == photo ? _self.photo : photo // ignore: cast_nullable_to_non_nullable
as String,verified: null == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [MessengerContact].
extension MessengerContactPatterns on MessengerContact {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessengerContact value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessengerContact() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessengerContact value)  $default,){
final _that = this;
switch (_that) {
case _MessengerContact():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessengerContact value)?  $default,){
final _that = this;
switch (_that) {
case _MessengerContact() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredInt)  int id, @JsonKey(fromJson: readRequiredText)  String name, @JsonKey(fromJson: readRequiredText)  String handle, @JsonKey(fromJson: readRequiredText)  String photo, @JsonKey(fromJson: readRequiredBool)  bool verified)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessengerContact() when $default != null:
return $default(_that.id,_that.name,_that.handle,_that.photo,_that.verified);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredInt)  int id, @JsonKey(fromJson: readRequiredText)  String name, @JsonKey(fromJson: readRequiredText)  String handle, @JsonKey(fromJson: readRequiredText)  String photo, @JsonKey(fromJson: readRequiredBool)  bool verified)  $default,) {final _that = this;
switch (_that) {
case _MessengerContact():
return $default(_that.id,_that.name,_that.handle,_that.photo,_that.verified);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: readRequiredInt)  int id, @JsonKey(fromJson: readRequiredText)  String name, @JsonKey(fromJson: readRequiredText)  String handle, @JsonKey(fromJson: readRequiredText)  String photo, @JsonKey(fromJson: readRequiredBool)  bool verified)?  $default,) {final _that = this;
switch (_that) {
case _MessengerContact() when $default != null:
return $default(_that.id,_that.name,_that.handle,_that.photo,_that.verified);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessengerContact extends MessengerContact with DiagnosticableTreeMixin {
  const _MessengerContact({@JsonKey(fromJson: readRequiredInt) required this.id, @JsonKey(fromJson: readRequiredText) required this.name, @JsonKey(fromJson: readRequiredText) required this.handle, @JsonKey(fromJson: readRequiredText) required this.photo, @JsonKey(fromJson: readRequiredBool) required this.verified}): super._();
  factory _MessengerContact.fromJson(Map<String, dynamic> json) => _$MessengerContactFromJson(json);

@override@JsonKey(fromJson: readRequiredInt) final  int id;
@override@JsonKey(fromJson: readRequiredText) final  String name;
@override@JsonKey(fromJson: readRequiredText) final  String handle;
@override@JsonKey(fromJson: readRequiredText) final  String photo;
@override@JsonKey(fromJson: readRequiredBool) final  bool verified;

/// Create a copy of MessengerContact
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessengerContactCopyWith<_MessengerContact> get copyWith => __$MessengerContactCopyWithImpl<_MessengerContact>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessengerContactToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'MessengerContact'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('name', name))..add(DiagnosticsProperty('handle', handle))..add(DiagnosticsProperty('photo', photo))..add(DiagnosticsProperty('verified', verified));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessengerContact&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.handle, handle) || other.handle == handle)&&(identical(other.photo, photo) || other.photo == photo)&&(identical(other.verified, verified) || other.verified == verified));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,handle,photo,verified);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'MessengerContact(id: $id, name: $name, handle: $handle, photo: $photo, verified: $verified)';
}


}

/// @nodoc
abstract mixin class _$MessengerContactCopyWith<$Res> implements $MessengerContactCopyWith<$Res> {
  factory _$MessengerContactCopyWith(_MessengerContact value, $Res Function(_MessengerContact) _then) = __$MessengerContactCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: readRequiredInt) int id,@JsonKey(fromJson: readRequiredText) String name,@JsonKey(fromJson: readRequiredText) String handle,@JsonKey(fromJson: readRequiredText) String photo,@JsonKey(fromJson: readRequiredBool) bool verified
});




}
/// @nodoc
class __$MessengerContactCopyWithImpl<$Res>
    implements _$MessengerContactCopyWith<$Res> {
  __$MessengerContactCopyWithImpl(this._self, this._then);

  final _MessengerContact _self;
  final $Res Function(_MessengerContact) _then;

/// Create a copy of MessengerContact
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? handle = null,Object? photo = null,Object? verified = null,}) {
  return _then(_MessengerContact(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,handle: null == handle ? _self.handle : handle // ignore: cast_nullable_to_non_nullable
as String,photo: null == photo ? _self.photo : photo // ignore: cast_nullable_to_non_nullable
as String,verified: null == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$MessengerMessage implements DiagnosticableTreeMixin {

@JsonKey(fromJson: readRequiredInt) int get id;@JsonKey(fromJson: readRequiredInt) int get threadId;@JsonKey(fromJson: readRequiredInt) int get senderId;@JsonKey(fromJson: readRequiredInt) int get receiverId;@JsonKey(fromJson: readRequiredText) String get body;@JsonKey(fromJson: readOptionalText) String? get imageUrl;@JsonKey(fromJson: readOptionalText) String? get imageExpiresAt;@JsonKey(fromJson: readRequiredText) String get createdAt;@JsonKey(fromJson: readRequiredText) String get clientWrittenAt;@JsonKey(fromJson: readRequiredText) String get serverReceivedAt;@JsonKey(fromJson: readRequiredText) String get deliveredAt;@JsonKey(fromJson: readRequiredText) String get readAt;@JsonKey(fromJson: readRequiredBool) bool get isMine;@JsonKey(fromJson: readRequiredText) String get senderName;
/// Create a copy of MessengerMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessengerMessageCopyWith<MessengerMessage> get copyWith => _$MessengerMessageCopyWithImpl<MessengerMessage>(this as MessengerMessage, _$identity);

  /// Serializes this MessengerMessage to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'MessengerMessage'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('threadId', threadId))..add(DiagnosticsProperty('senderId', senderId))..add(DiagnosticsProperty('receiverId', receiverId))..add(DiagnosticsProperty('body', body))..add(DiagnosticsProperty('imageUrl', imageUrl))..add(DiagnosticsProperty('imageExpiresAt', imageExpiresAt))..add(DiagnosticsProperty('createdAt', createdAt))..add(DiagnosticsProperty('clientWrittenAt', clientWrittenAt))..add(DiagnosticsProperty('serverReceivedAt', serverReceivedAt))..add(DiagnosticsProperty('deliveredAt', deliveredAt))..add(DiagnosticsProperty('readAt', readAt))..add(DiagnosticsProperty('isMine', isMine))..add(DiagnosticsProperty('senderName', senderName));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessengerMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.receiverId, receiverId) || other.receiverId == receiverId)&&(identical(other.body, body) || other.body == body)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.imageExpiresAt, imageExpiresAt) || other.imageExpiresAt == imageExpiresAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.clientWrittenAt, clientWrittenAt) || other.clientWrittenAt == clientWrittenAt)&&(identical(other.serverReceivedAt, serverReceivedAt) || other.serverReceivedAt == serverReceivedAt)&&(identical(other.deliveredAt, deliveredAt) || other.deliveredAt == deliveredAt)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&(identical(other.isMine, isMine) || other.isMine == isMine)&&(identical(other.senderName, senderName) || other.senderName == senderName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,threadId,senderId,receiverId,body,imageUrl,imageExpiresAt,createdAt,clientWrittenAt,serverReceivedAt,deliveredAt,readAt,isMine,senderName);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'MessengerMessage(id: $id, threadId: $threadId, senderId: $senderId, receiverId: $receiverId, body: $body, imageUrl: $imageUrl, imageExpiresAt: $imageExpiresAt, createdAt: $createdAt, clientWrittenAt: $clientWrittenAt, serverReceivedAt: $serverReceivedAt, deliveredAt: $deliveredAt, readAt: $readAt, isMine: $isMine, senderName: $senderName)';
}


}

/// @nodoc
abstract mixin class $MessengerMessageCopyWith<$Res>  {
  factory $MessengerMessageCopyWith(MessengerMessage value, $Res Function(MessengerMessage) _then) = _$MessengerMessageCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: readRequiredInt) int id,@JsonKey(fromJson: readRequiredInt) int threadId,@JsonKey(fromJson: readRequiredInt) int senderId,@JsonKey(fromJson: readRequiredInt) int receiverId,@JsonKey(fromJson: readRequiredText) String body,@JsonKey(fromJson: readOptionalText) String? imageUrl,@JsonKey(fromJson: readOptionalText) String? imageExpiresAt,@JsonKey(fromJson: readRequiredText) String createdAt,@JsonKey(fromJson: readRequiredText) String clientWrittenAt,@JsonKey(fromJson: readRequiredText) String serverReceivedAt,@JsonKey(fromJson: readRequiredText) String deliveredAt,@JsonKey(fromJson: readRequiredText) String readAt,@JsonKey(fromJson: readRequiredBool) bool isMine,@JsonKey(fromJson: readRequiredText) String senderName
});




}
/// @nodoc
class _$MessengerMessageCopyWithImpl<$Res>
    implements $MessengerMessageCopyWith<$Res> {
  _$MessengerMessageCopyWithImpl(this._self, this._then);

  final MessengerMessage _self;
  final $Res Function(MessengerMessage) _then;

/// Create a copy of MessengerMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? threadId = null,Object? senderId = null,Object? receiverId = null,Object? body = null,Object? imageUrl = freezed,Object? imageExpiresAt = freezed,Object? createdAt = null,Object? clientWrittenAt = null,Object? serverReceivedAt = null,Object? deliveredAt = null,Object? readAt = null,Object? isMine = null,Object? senderName = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,threadId: null == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as int,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as int,receiverId: null == receiverId ? _self.receiverId : receiverId // ignore: cast_nullable_to_non_nullable
as int,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,imageExpiresAt: freezed == imageExpiresAt ? _self.imageExpiresAt : imageExpiresAt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,clientWrittenAt: null == clientWrittenAt ? _self.clientWrittenAt : clientWrittenAt // ignore: cast_nullable_to_non_nullable
as String,serverReceivedAt: null == serverReceivedAt ? _self.serverReceivedAt : serverReceivedAt // ignore: cast_nullable_to_non_nullable
as String,deliveredAt: null == deliveredAt ? _self.deliveredAt : deliveredAt // ignore: cast_nullable_to_non_nullable
as String,readAt: null == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as String,isMine: null == isMine ? _self.isMine : isMine // ignore: cast_nullable_to_non_nullable
as bool,senderName: null == senderName ? _self.senderName : senderName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MessengerMessage].
extension MessengerMessagePatterns on MessengerMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessengerMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessengerMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessengerMessage value)  $default,){
final _that = this;
switch (_that) {
case _MessengerMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessengerMessage value)?  $default,){
final _that = this;
switch (_that) {
case _MessengerMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredInt)  int id, @JsonKey(fromJson: readRequiredInt)  int threadId, @JsonKey(fromJson: readRequiredInt)  int senderId, @JsonKey(fromJson: readRequiredInt)  int receiverId, @JsonKey(fromJson: readRequiredText)  String body, @JsonKey(fromJson: readOptionalText)  String? imageUrl, @JsonKey(fromJson: readOptionalText)  String? imageExpiresAt, @JsonKey(fromJson: readRequiredText)  String createdAt, @JsonKey(fromJson: readRequiredText)  String clientWrittenAt, @JsonKey(fromJson: readRequiredText)  String serverReceivedAt, @JsonKey(fromJson: readRequiredText)  String deliveredAt, @JsonKey(fromJson: readRequiredText)  String readAt, @JsonKey(fromJson: readRequiredBool)  bool isMine, @JsonKey(fromJson: readRequiredText)  String senderName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessengerMessage() when $default != null:
return $default(_that.id,_that.threadId,_that.senderId,_that.receiverId,_that.body,_that.imageUrl,_that.imageExpiresAt,_that.createdAt,_that.clientWrittenAt,_that.serverReceivedAt,_that.deliveredAt,_that.readAt,_that.isMine,_that.senderName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredInt)  int id, @JsonKey(fromJson: readRequiredInt)  int threadId, @JsonKey(fromJson: readRequiredInt)  int senderId, @JsonKey(fromJson: readRequiredInt)  int receiverId, @JsonKey(fromJson: readRequiredText)  String body, @JsonKey(fromJson: readOptionalText)  String? imageUrl, @JsonKey(fromJson: readOptionalText)  String? imageExpiresAt, @JsonKey(fromJson: readRequiredText)  String createdAt, @JsonKey(fromJson: readRequiredText)  String clientWrittenAt, @JsonKey(fromJson: readRequiredText)  String serverReceivedAt, @JsonKey(fromJson: readRequiredText)  String deliveredAt, @JsonKey(fromJson: readRequiredText)  String readAt, @JsonKey(fromJson: readRequiredBool)  bool isMine, @JsonKey(fromJson: readRequiredText)  String senderName)  $default,) {final _that = this;
switch (_that) {
case _MessengerMessage():
return $default(_that.id,_that.threadId,_that.senderId,_that.receiverId,_that.body,_that.imageUrl,_that.imageExpiresAt,_that.createdAt,_that.clientWrittenAt,_that.serverReceivedAt,_that.deliveredAt,_that.readAt,_that.isMine,_that.senderName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: readRequiredInt)  int id, @JsonKey(fromJson: readRequiredInt)  int threadId, @JsonKey(fromJson: readRequiredInt)  int senderId, @JsonKey(fromJson: readRequiredInt)  int receiverId, @JsonKey(fromJson: readRequiredText)  String body, @JsonKey(fromJson: readOptionalText)  String? imageUrl, @JsonKey(fromJson: readOptionalText)  String? imageExpiresAt, @JsonKey(fromJson: readRequiredText)  String createdAt, @JsonKey(fromJson: readRequiredText)  String clientWrittenAt, @JsonKey(fromJson: readRequiredText)  String serverReceivedAt, @JsonKey(fromJson: readRequiredText)  String deliveredAt, @JsonKey(fromJson: readRequiredText)  String readAt, @JsonKey(fromJson: readRequiredBool)  bool isMine, @JsonKey(fromJson: readRequiredText)  String senderName)?  $default,) {final _that = this;
switch (_that) {
case _MessengerMessage() when $default != null:
return $default(_that.id,_that.threadId,_that.senderId,_that.receiverId,_that.body,_that.imageUrl,_that.imageExpiresAt,_that.createdAt,_that.clientWrittenAt,_that.serverReceivedAt,_that.deliveredAt,_that.readAt,_that.isMine,_that.senderName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessengerMessage extends MessengerMessage with DiagnosticableTreeMixin {
  const _MessengerMessage({@JsonKey(fromJson: readRequiredInt) required this.id, @JsonKey(fromJson: readRequiredInt) required this.threadId, @JsonKey(fromJson: readRequiredInt) required this.senderId, @JsonKey(fromJson: readRequiredInt) required this.receiverId, @JsonKey(fromJson: readRequiredText) required this.body, @JsonKey(fromJson: readOptionalText) this.imageUrl, @JsonKey(fromJson: readOptionalText) this.imageExpiresAt, @JsonKey(fromJson: readRequiredText) required this.createdAt, @JsonKey(fromJson: readRequiredText) required this.clientWrittenAt, @JsonKey(fromJson: readRequiredText) required this.serverReceivedAt, @JsonKey(fromJson: readRequiredText) required this.deliveredAt, @JsonKey(fromJson: readRequiredText) required this.readAt, @JsonKey(fromJson: readRequiredBool) required this.isMine, @JsonKey(fromJson: readRequiredText) required this.senderName}): super._();
  factory _MessengerMessage.fromJson(Map<String, dynamic> json) => _$MessengerMessageFromJson(json);

@override@JsonKey(fromJson: readRequiredInt) final  int id;
@override@JsonKey(fromJson: readRequiredInt) final  int threadId;
@override@JsonKey(fromJson: readRequiredInt) final  int senderId;
@override@JsonKey(fromJson: readRequiredInt) final  int receiverId;
@override@JsonKey(fromJson: readRequiredText) final  String body;
@override@JsonKey(fromJson: readOptionalText) final  String? imageUrl;
@override@JsonKey(fromJson: readOptionalText) final  String? imageExpiresAt;
@override@JsonKey(fromJson: readRequiredText) final  String createdAt;
@override@JsonKey(fromJson: readRequiredText) final  String clientWrittenAt;
@override@JsonKey(fromJson: readRequiredText) final  String serverReceivedAt;
@override@JsonKey(fromJson: readRequiredText) final  String deliveredAt;
@override@JsonKey(fromJson: readRequiredText) final  String readAt;
@override@JsonKey(fromJson: readRequiredBool) final  bool isMine;
@override@JsonKey(fromJson: readRequiredText) final  String senderName;

/// Create a copy of MessengerMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessengerMessageCopyWith<_MessengerMessage> get copyWith => __$MessengerMessageCopyWithImpl<_MessengerMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessengerMessageToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'MessengerMessage'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('threadId', threadId))..add(DiagnosticsProperty('senderId', senderId))..add(DiagnosticsProperty('receiverId', receiverId))..add(DiagnosticsProperty('body', body))..add(DiagnosticsProperty('imageUrl', imageUrl))..add(DiagnosticsProperty('imageExpiresAt', imageExpiresAt))..add(DiagnosticsProperty('createdAt', createdAt))..add(DiagnosticsProperty('clientWrittenAt', clientWrittenAt))..add(DiagnosticsProperty('serverReceivedAt', serverReceivedAt))..add(DiagnosticsProperty('deliveredAt', deliveredAt))..add(DiagnosticsProperty('readAt', readAt))..add(DiagnosticsProperty('isMine', isMine))..add(DiagnosticsProperty('senderName', senderName));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessengerMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.senderId, senderId) || other.senderId == senderId)&&(identical(other.receiverId, receiverId) || other.receiverId == receiverId)&&(identical(other.body, body) || other.body == body)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.imageExpiresAt, imageExpiresAt) || other.imageExpiresAt == imageExpiresAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.clientWrittenAt, clientWrittenAt) || other.clientWrittenAt == clientWrittenAt)&&(identical(other.serverReceivedAt, serverReceivedAt) || other.serverReceivedAt == serverReceivedAt)&&(identical(other.deliveredAt, deliveredAt) || other.deliveredAt == deliveredAt)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&(identical(other.isMine, isMine) || other.isMine == isMine)&&(identical(other.senderName, senderName) || other.senderName == senderName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,threadId,senderId,receiverId,body,imageUrl,imageExpiresAt,createdAt,clientWrittenAt,serverReceivedAt,deliveredAt,readAt,isMine,senderName);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'MessengerMessage(id: $id, threadId: $threadId, senderId: $senderId, receiverId: $receiverId, body: $body, imageUrl: $imageUrl, imageExpiresAt: $imageExpiresAt, createdAt: $createdAt, clientWrittenAt: $clientWrittenAt, serverReceivedAt: $serverReceivedAt, deliveredAt: $deliveredAt, readAt: $readAt, isMine: $isMine, senderName: $senderName)';
}


}

/// @nodoc
abstract mixin class _$MessengerMessageCopyWith<$Res> implements $MessengerMessageCopyWith<$Res> {
  factory _$MessengerMessageCopyWith(_MessengerMessage value, $Res Function(_MessengerMessage) _then) = __$MessengerMessageCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: readRequiredInt) int id,@JsonKey(fromJson: readRequiredInt) int threadId,@JsonKey(fromJson: readRequiredInt) int senderId,@JsonKey(fromJson: readRequiredInt) int receiverId,@JsonKey(fromJson: readRequiredText) String body,@JsonKey(fromJson: readOptionalText) String? imageUrl,@JsonKey(fromJson: readOptionalText) String? imageExpiresAt,@JsonKey(fromJson: readRequiredText) String createdAt,@JsonKey(fromJson: readRequiredText) String clientWrittenAt,@JsonKey(fromJson: readRequiredText) String serverReceivedAt,@JsonKey(fromJson: readRequiredText) String deliveredAt,@JsonKey(fromJson: readRequiredText) String readAt,@JsonKey(fromJson: readRequiredBool) bool isMine,@JsonKey(fromJson: readRequiredText) String senderName
});




}
/// @nodoc
class __$MessengerMessageCopyWithImpl<$Res>
    implements _$MessengerMessageCopyWith<$Res> {
  __$MessengerMessageCopyWithImpl(this._self, this._then);

  final _MessengerMessage _self;
  final $Res Function(_MessengerMessage) _then;

/// Create a copy of MessengerMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? threadId = null,Object? senderId = null,Object? receiverId = null,Object? body = null,Object? imageUrl = freezed,Object? imageExpiresAt = freezed,Object? createdAt = null,Object? clientWrittenAt = null,Object? serverReceivedAt = null,Object? deliveredAt = null,Object? readAt = null,Object? isMine = null,Object? senderName = null,}) {
  return _then(_MessengerMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,threadId: null == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as int,senderId: null == senderId ? _self.senderId : senderId // ignore: cast_nullable_to_non_nullable
as int,receiverId: null == receiverId ? _self.receiverId : receiverId // ignore: cast_nullable_to_non_nullable
as int,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,imageExpiresAt: freezed == imageExpiresAt ? _self.imageExpiresAt : imageExpiresAt // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,clientWrittenAt: null == clientWrittenAt ? _self.clientWrittenAt : clientWrittenAt // ignore: cast_nullable_to_non_nullable
as String,serverReceivedAt: null == serverReceivedAt ? _self.serverReceivedAt : serverReceivedAt // ignore: cast_nullable_to_non_nullable
as String,deliveredAt: null == deliveredAt ? _self.deliveredAt : deliveredAt // ignore: cast_nullable_to_non_nullable
as String,readAt: null == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as String,isMine: null == isMine ? _self.isMine : isMine // ignore: cast_nullable_to_non_nullable
as bool,senderName: null == senderName ? _self.senderName : senderName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$MessengerThreadSummary implements DiagnosticableTreeMixin {

@JsonKey(fromJson: readRequiredInt) int get id; MessengerContact get peer;@JsonKey(fromJson: readRequiredInt) int get unreadCount; MessengerMessage? get lastMessage;
/// Create a copy of MessengerThreadSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessengerThreadSummaryCopyWith<MessengerThreadSummary> get copyWith => _$MessengerThreadSummaryCopyWithImpl<MessengerThreadSummary>(this as MessengerThreadSummary, _$identity);

  /// Serializes this MessengerThreadSummary to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'MessengerThreadSummary'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('peer', peer))..add(DiagnosticsProperty('unreadCount', unreadCount))..add(DiagnosticsProperty('lastMessage', lastMessage));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessengerThreadSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.peer, peer) || other.peer == peer)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.lastMessage, lastMessage) || other.lastMessage == lastMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,peer,unreadCount,lastMessage);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'MessengerThreadSummary(id: $id, peer: $peer, unreadCount: $unreadCount, lastMessage: $lastMessage)';
}


}

/// @nodoc
abstract mixin class $MessengerThreadSummaryCopyWith<$Res>  {
  factory $MessengerThreadSummaryCopyWith(MessengerThreadSummary value, $Res Function(MessengerThreadSummary) _then) = _$MessengerThreadSummaryCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: readRequiredInt) int id, MessengerContact peer,@JsonKey(fromJson: readRequiredInt) int unreadCount, MessengerMessage? lastMessage
});


$MessengerContactCopyWith<$Res> get peer;$MessengerMessageCopyWith<$Res>? get lastMessage;

}
/// @nodoc
class _$MessengerThreadSummaryCopyWithImpl<$Res>
    implements $MessengerThreadSummaryCopyWith<$Res> {
  _$MessengerThreadSummaryCopyWithImpl(this._self, this._then);

  final MessengerThreadSummary _self;
  final $Res Function(MessengerThreadSummary) _then;

/// Create a copy of MessengerThreadSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? peer = null,Object? unreadCount = null,Object? lastMessage = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,peer: null == peer ? _self.peer : peer // ignore: cast_nullable_to_non_nullable
as MessengerContact,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,lastMessage: freezed == lastMessage ? _self.lastMessage : lastMessage // ignore: cast_nullable_to_non_nullable
as MessengerMessage?,
  ));
}
/// Create a copy of MessengerThreadSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessengerContactCopyWith<$Res> get peer {
  
  return $MessengerContactCopyWith<$Res>(_self.peer, (value) {
    return _then(_self.copyWith(peer: value));
  });
}/// Create a copy of MessengerThreadSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessengerMessageCopyWith<$Res>? get lastMessage {
    if (_self.lastMessage == null) {
    return null;
  }

  return $MessengerMessageCopyWith<$Res>(_self.lastMessage!, (value) {
    return _then(_self.copyWith(lastMessage: value));
  });
}
}


/// Adds pattern-matching-related methods to [MessengerThreadSummary].
extension MessengerThreadSummaryPatterns on MessengerThreadSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessengerThreadSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessengerThreadSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessengerThreadSummary value)  $default,){
final _that = this;
switch (_that) {
case _MessengerThreadSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessengerThreadSummary value)?  $default,){
final _that = this;
switch (_that) {
case _MessengerThreadSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredInt)  int id,  MessengerContact peer, @JsonKey(fromJson: readRequiredInt)  int unreadCount,  MessengerMessage? lastMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessengerThreadSummary() when $default != null:
return $default(_that.id,_that.peer,_that.unreadCount,_that.lastMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredInt)  int id,  MessengerContact peer, @JsonKey(fromJson: readRequiredInt)  int unreadCount,  MessengerMessage? lastMessage)  $default,) {final _that = this;
switch (_that) {
case _MessengerThreadSummary():
return $default(_that.id,_that.peer,_that.unreadCount,_that.lastMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: readRequiredInt)  int id,  MessengerContact peer, @JsonKey(fromJson: readRequiredInt)  int unreadCount,  MessengerMessage? lastMessage)?  $default,) {final _that = this;
switch (_that) {
case _MessengerThreadSummary() when $default != null:
return $default(_that.id,_that.peer,_that.unreadCount,_that.lastMessage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessengerThreadSummary with DiagnosticableTreeMixin implements MessengerThreadSummary {
  const _MessengerThreadSummary({@JsonKey(fromJson: readRequiredInt) required this.id, required this.peer, @JsonKey(fromJson: readRequiredInt) required this.unreadCount, this.lastMessage});
  factory _MessengerThreadSummary.fromJson(Map<String, dynamic> json) => _$MessengerThreadSummaryFromJson(json);

@override@JsonKey(fromJson: readRequiredInt) final  int id;
@override final  MessengerContact peer;
@override@JsonKey(fromJson: readRequiredInt) final  int unreadCount;
@override final  MessengerMessage? lastMessage;

/// Create a copy of MessengerThreadSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessengerThreadSummaryCopyWith<_MessengerThreadSummary> get copyWith => __$MessengerThreadSummaryCopyWithImpl<_MessengerThreadSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessengerThreadSummaryToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'MessengerThreadSummary'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('peer', peer))..add(DiagnosticsProperty('unreadCount', unreadCount))..add(DiagnosticsProperty('lastMessage', lastMessage));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessengerThreadSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.peer, peer) || other.peer == peer)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.lastMessage, lastMessage) || other.lastMessage == lastMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,peer,unreadCount,lastMessage);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'MessengerThreadSummary(id: $id, peer: $peer, unreadCount: $unreadCount, lastMessage: $lastMessage)';
}


}

/// @nodoc
abstract mixin class _$MessengerThreadSummaryCopyWith<$Res> implements $MessengerThreadSummaryCopyWith<$Res> {
  factory _$MessengerThreadSummaryCopyWith(_MessengerThreadSummary value, $Res Function(_MessengerThreadSummary) _then) = __$MessengerThreadSummaryCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: readRequiredInt) int id, MessengerContact peer,@JsonKey(fromJson: readRequiredInt) int unreadCount, MessengerMessage? lastMessage
});


@override $MessengerContactCopyWith<$Res> get peer;@override $MessengerMessageCopyWith<$Res>? get lastMessage;

}
/// @nodoc
class __$MessengerThreadSummaryCopyWithImpl<$Res>
    implements _$MessengerThreadSummaryCopyWith<$Res> {
  __$MessengerThreadSummaryCopyWithImpl(this._self, this._then);

  final _MessengerThreadSummary _self;
  final $Res Function(_MessengerThreadSummary) _then;

/// Create a copy of MessengerThreadSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? peer = null,Object? unreadCount = null,Object? lastMessage = freezed,}) {
  return _then(_MessengerThreadSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,peer: null == peer ? _self.peer : peer // ignore: cast_nullable_to_non_nullable
as MessengerContact,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,lastMessage: freezed == lastMessage ? _self.lastMessage : lastMessage // ignore: cast_nullable_to_non_nullable
as MessengerMessage?,
  ));
}

/// Create a copy of MessengerThreadSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessengerContactCopyWith<$Res> get peer {
  
  return $MessengerContactCopyWith<$Res>(_self.peer, (value) {
    return _then(_self.copyWith(peer: value));
  });
}/// Create a copy of MessengerThreadSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessengerMessageCopyWith<$Res>? get lastMessage {
    if (_self.lastMessage == null) {
    return null;
  }

  return $MessengerMessageCopyWith<$Res>(_self.lastMessage!, (value) {
    return _then(_self.copyWith(lastMessage: value));
  });
}
}


/// @nodoc
mixin _$MessengerRealtimeEvent implements DiagnosticableTreeMixin {

@JsonKey(fromJson: readRequiredText) String get type;@JsonKey(fromJson: readRequiredInt) int get threadId;@JsonKey(fromJson: readOptionalInt) int? get byUserId; MessengerMessage? get item;
/// Create a copy of MessengerRealtimeEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessengerRealtimeEventCopyWith<MessengerRealtimeEvent> get copyWith => _$MessengerRealtimeEventCopyWithImpl<MessengerRealtimeEvent>(this as MessengerRealtimeEvent, _$identity);

  /// Serializes this MessengerRealtimeEvent to a JSON map.
  Map<String, dynamic> toJson();

@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'MessengerRealtimeEvent'))
    ..add(DiagnosticsProperty('type', type))..add(DiagnosticsProperty('threadId', threadId))..add(DiagnosticsProperty('byUserId', byUserId))..add(DiagnosticsProperty('item', item));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessengerRealtimeEvent&&(identical(other.type, type) || other.type == type)&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.byUserId, byUserId) || other.byUserId == byUserId)&&(identical(other.item, item) || other.item == item));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,threadId,byUserId,item);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'MessengerRealtimeEvent(type: $type, threadId: $threadId, byUserId: $byUserId, item: $item)';
}


}

/// @nodoc
abstract mixin class $MessengerRealtimeEventCopyWith<$Res>  {
  factory $MessengerRealtimeEventCopyWith(MessengerRealtimeEvent value, $Res Function(MessengerRealtimeEvent) _then) = _$MessengerRealtimeEventCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: readRequiredText) String type,@JsonKey(fromJson: readRequiredInt) int threadId,@JsonKey(fromJson: readOptionalInt) int? byUserId, MessengerMessage? item
});


$MessengerMessageCopyWith<$Res>? get item;

}
/// @nodoc
class _$MessengerRealtimeEventCopyWithImpl<$Res>
    implements $MessengerRealtimeEventCopyWith<$Res> {
  _$MessengerRealtimeEventCopyWithImpl(this._self, this._then);

  final MessengerRealtimeEvent _self;
  final $Res Function(MessengerRealtimeEvent) _then;

/// Create a copy of MessengerRealtimeEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? threadId = null,Object? byUserId = freezed,Object? item = freezed,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,threadId: null == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as int,byUserId: freezed == byUserId ? _self.byUserId : byUserId // ignore: cast_nullable_to_non_nullable
as int?,item: freezed == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as MessengerMessage?,
  ));
}
/// Create a copy of MessengerRealtimeEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessengerMessageCopyWith<$Res>? get item {
    if (_self.item == null) {
    return null;
  }

  return $MessengerMessageCopyWith<$Res>(_self.item!, (value) {
    return _then(_self.copyWith(item: value));
  });
}
}


/// Adds pattern-matching-related methods to [MessengerRealtimeEvent].
extension MessengerRealtimeEventPatterns on MessengerRealtimeEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessengerRealtimeEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessengerRealtimeEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessengerRealtimeEvent value)  $default,){
final _that = this;
switch (_that) {
case _MessengerRealtimeEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessengerRealtimeEvent value)?  $default,){
final _that = this;
switch (_that) {
case _MessengerRealtimeEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredText)  String type, @JsonKey(fromJson: readRequiredInt)  int threadId, @JsonKey(fromJson: readOptionalInt)  int? byUserId,  MessengerMessage? item)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessengerRealtimeEvent() when $default != null:
return $default(_that.type,_that.threadId,_that.byUserId,_that.item);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: readRequiredText)  String type, @JsonKey(fromJson: readRequiredInt)  int threadId, @JsonKey(fromJson: readOptionalInt)  int? byUserId,  MessengerMessage? item)  $default,) {final _that = this;
switch (_that) {
case _MessengerRealtimeEvent():
return $default(_that.type,_that.threadId,_that.byUserId,_that.item);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: readRequiredText)  String type, @JsonKey(fromJson: readRequiredInt)  int threadId, @JsonKey(fromJson: readOptionalInt)  int? byUserId,  MessengerMessage? item)?  $default,) {final _that = this;
switch (_that) {
case _MessengerRealtimeEvent() when $default != null:
return $default(_that.type,_that.threadId,_that.byUserId,_that.item);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessengerRealtimeEvent with DiagnosticableTreeMixin implements MessengerRealtimeEvent {
  const _MessengerRealtimeEvent({@JsonKey(fromJson: readRequiredText) required this.type, @JsonKey(fromJson: readRequiredInt) required this.threadId, @JsonKey(fromJson: readOptionalInt) this.byUserId, this.item});
  factory _MessengerRealtimeEvent.fromJson(Map<String, dynamic> json) => _$MessengerRealtimeEventFromJson(json);

@override@JsonKey(fromJson: readRequiredText) final  String type;
@override@JsonKey(fromJson: readRequiredInt) final  int threadId;
@override@JsonKey(fromJson: readOptionalInt) final  int? byUserId;
@override final  MessengerMessage? item;

/// Create a copy of MessengerRealtimeEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessengerRealtimeEventCopyWith<_MessengerRealtimeEvent> get copyWith => __$MessengerRealtimeEventCopyWithImpl<_MessengerRealtimeEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessengerRealtimeEventToJson(this, );
}
@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'MessengerRealtimeEvent'))
    ..add(DiagnosticsProperty('type', type))..add(DiagnosticsProperty('threadId', threadId))..add(DiagnosticsProperty('byUserId', byUserId))..add(DiagnosticsProperty('item', item));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessengerRealtimeEvent&&(identical(other.type, type) || other.type == type)&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.byUserId, byUserId) || other.byUserId == byUserId)&&(identical(other.item, item) || other.item == item));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,type,threadId,byUserId,item);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'MessengerRealtimeEvent(type: $type, threadId: $threadId, byUserId: $byUserId, item: $item)';
}


}

/// @nodoc
abstract mixin class _$MessengerRealtimeEventCopyWith<$Res> implements $MessengerRealtimeEventCopyWith<$Res> {
  factory _$MessengerRealtimeEventCopyWith(_MessengerRealtimeEvent value, $Res Function(_MessengerRealtimeEvent) _then) = __$MessengerRealtimeEventCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: readRequiredText) String type,@JsonKey(fromJson: readRequiredInt) int threadId,@JsonKey(fromJson: readOptionalInt) int? byUserId, MessengerMessage? item
});


@override $MessengerMessageCopyWith<$Res>? get item;

}
/// @nodoc
class __$MessengerRealtimeEventCopyWithImpl<$Res>
    implements _$MessengerRealtimeEventCopyWith<$Res> {
  __$MessengerRealtimeEventCopyWithImpl(this._self, this._then);

  final _MessengerRealtimeEvent _self;
  final $Res Function(_MessengerRealtimeEvent) _then;

/// Create a copy of MessengerRealtimeEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? threadId = null,Object? byUserId = freezed,Object? item = freezed,}) {
  return _then(_MessengerRealtimeEvent(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,threadId: null == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as int,byUserId: freezed == byUserId ? _self.byUserId : byUserId // ignore: cast_nullable_to_non_nullable
as int?,item: freezed == item ? _self.item : item // ignore: cast_nullable_to_non_nullable
as MessengerMessage?,
  ));
}

/// Create a copy of MessengerRealtimeEvent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessengerMessageCopyWith<$Res>? get item {
    if (_self.item == null) {
    return null;
  }

  return $MessengerMessageCopyWith<$Res>(_self.item!, (value) {
    return _then(_self.copyWith(item: value));
  });
}
}

// dart format on
