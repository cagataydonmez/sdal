// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'messenger_repository.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

MessengerContact _$MessengerContactFromJson(Map<String, dynamic> json) {
  return _MessengerContact.fromJson(json);
}

/// @nodoc
mixin _$MessengerContact {
  @JsonKey(fromJson: readRequiredInt)
  int get id => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get name => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get handle => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get photo => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredBool)
  bool get verified => throw _privateConstructorUsedError;

  /// Serializes this MessengerContact to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MessengerContact
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MessengerContactCopyWith<MessengerContact> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MessengerContactCopyWith<$Res> {
  factory $MessengerContactCopyWith(
    MessengerContact value,
    $Res Function(MessengerContact) then,
  ) = _$MessengerContactCopyWithImpl<$Res, MessengerContact>;
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredInt) int id,
    @JsonKey(fromJson: readRequiredText) String name,
    @JsonKey(fromJson: readRequiredText) String handle,
    @JsonKey(fromJson: readRequiredText) String photo,
    @JsonKey(fromJson: readRequiredBool) bool verified,
  });
}

/// @nodoc
class _$MessengerContactCopyWithImpl<$Res, $Val extends MessengerContact>
    implements $MessengerContactCopyWith<$Res> {
  _$MessengerContactCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MessengerContact
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? handle = null,
    Object? photo = null,
    Object? verified = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            handle: null == handle
                ? _value.handle
                : handle // ignore: cast_nullable_to_non_nullable
                      as String,
            photo: null == photo
                ? _value.photo
                : photo // ignore: cast_nullable_to_non_nullable
                      as String,
            verified: null == verified
                ? _value.verified
                : verified // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MessengerContactImplCopyWith<$Res>
    implements $MessengerContactCopyWith<$Res> {
  factory _$$MessengerContactImplCopyWith(
    _$MessengerContactImpl value,
    $Res Function(_$MessengerContactImpl) then,
  ) = __$$MessengerContactImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredInt) int id,
    @JsonKey(fromJson: readRequiredText) String name,
    @JsonKey(fromJson: readRequiredText) String handle,
    @JsonKey(fromJson: readRequiredText) String photo,
    @JsonKey(fromJson: readRequiredBool) bool verified,
  });
}

/// @nodoc
class __$$MessengerContactImplCopyWithImpl<$Res>
    extends _$MessengerContactCopyWithImpl<$Res, _$MessengerContactImpl>
    implements _$$MessengerContactImplCopyWith<$Res> {
  __$$MessengerContactImplCopyWithImpl(
    _$MessengerContactImpl _value,
    $Res Function(_$MessengerContactImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessengerContact
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? handle = null,
    Object? photo = null,
    Object? verified = null,
  }) {
    return _then(
      _$MessengerContactImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        handle: null == handle
            ? _value.handle
            : handle // ignore: cast_nullable_to_non_nullable
                  as String,
        photo: null == photo
            ? _value.photo
            : photo // ignore: cast_nullable_to_non_nullable
                  as String,
        verified: null == verified
            ? _value.verified
            : verified // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MessengerContactImpl extends _MessengerContact {
  const _$MessengerContactImpl({
    @JsonKey(fromJson: readRequiredInt) required this.id,
    @JsonKey(fromJson: readRequiredText) required this.name,
    @JsonKey(fromJson: readRequiredText) required this.handle,
    @JsonKey(fromJson: readRequiredText) required this.photo,
    @JsonKey(fromJson: readRequiredBool) required this.verified,
  }) : super._();

  factory _$MessengerContactImpl.fromJson(Map<String, dynamic> json) =>
      _$$MessengerContactImplFromJson(json);

  @override
  @JsonKey(fromJson: readRequiredInt)
  final int id;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String name;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String handle;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String photo;
  @override
  @JsonKey(fromJson: readRequiredBool)
  final bool verified;

  @override
  String toString() {
    return 'MessengerContact(id: $id, name: $name, handle: $handle, photo: $photo, verified: $verified)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessengerContactImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.handle, handle) || other.handle == handle) &&
            (identical(other.photo, photo) || other.photo == photo) &&
            (identical(other.verified, verified) ||
                other.verified == verified));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, handle, photo, verified);

  /// Create a copy of MessengerContact
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessengerContactImplCopyWith<_$MessengerContactImpl> get copyWith =>
      __$$MessengerContactImplCopyWithImpl<_$MessengerContactImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$MessengerContactImplToJson(this);
  }
}

abstract class _MessengerContact extends MessengerContact {
  const factory _MessengerContact({
    @JsonKey(fromJson: readRequiredInt) required final int id,
    @JsonKey(fromJson: readRequiredText) required final String name,
    @JsonKey(fromJson: readRequiredText) required final String handle,
    @JsonKey(fromJson: readRequiredText) required final String photo,
    @JsonKey(fromJson: readRequiredBool) required final bool verified,
  }) = _$MessengerContactImpl;
  const _MessengerContact._() : super._();

  factory _MessengerContact.fromJson(Map<String, dynamic> json) =
      _$MessengerContactImpl.fromJson;

  @override
  @JsonKey(fromJson: readRequiredInt)
  int get id;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get name;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get handle;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get photo;
  @override
  @JsonKey(fromJson: readRequiredBool)
  bool get verified;

  /// Create a copy of MessengerContact
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessengerContactImplCopyWith<_$MessengerContactImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MessengerMessage _$MessengerMessageFromJson(Map<String, dynamic> json) {
  return _MessengerMessage.fromJson(json);
}

/// @nodoc
mixin _$MessengerMessage {
  @JsonKey(fromJson: readRequiredInt)
  int get id => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredInt)
  int get threadId => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredInt)
  int get senderId => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredInt)
  int get receiverId => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get body => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get createdAt => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get clientWrittenAt => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get serverReceivedAt => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get deliveredAt => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get readAt => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredBool)
  bool get isMine => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredText)
  String get senderName => throw _privateConstructorUsedError;

  /// Serializes this MessengerMessage to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MessengerMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MessengerMessageCopyWith<MessengerMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MessengerMessageCopyWith<$Res> {
  factory $MessengerMessageCopyWith(
    MessengerMessage value,
    $Res Function(MessengerMessage) then,
  ) = _$MessengerMessageCopyWithImpl<$Res, MessengerMessage>;
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredInt) int id,
    @JsonKey(fromJson: readRequiredInt) int threadId,
    @JsonKey(fromJson: readRequiredInt) int senderId,
    @JsonKey(fromJson: readRequiredInt) int receiverId,
    @JsonKey(fromJson: readRequiredText) String body,
    @JsonKey(fromJson: readRequiredText) String createdAt,
    @JsonKey(fromJson: readRequiredText) String clientWrittenAt,
    @JsonKey(fromJson: readRequiredText) String serverReceivedAt,
    @JsonKey(fromJson: readRequiredText) String deliveredAt,
    @JsonKey(fromJson: readRequiredText) String readAt,
    @JsonKey(fromJson: readRequiredBool) bool isMine,
    @JsonKey(fromJson: readRequiredText) String senderName,
  });
}

/// @nodoc
class _$MessengerMessageCopyWithImpl<$Res, $Val extends MessengerMessage>
    implements $MessengerMessageCopyWith<$Res> {
  _$MessengerMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MessengerMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? threadId = null,
    Object? senderId = null,
    Object? receiverId = null,
    Object? body = null,
    Object? createdAt = null,
    Object? clientWrittenAt = null,
    Object? serverReceivedAt = null,
    Object? deliveredAt = null,
    Object? readAt = null,
    Object? isMine = null,
    Object? senderName = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            threadId: null == threadId
                ? _value.threadId
                : threadId // ignore: cast_nullable_to_non_nullable
                      as int,
            senderId: null == senderId
                ? _value.senderId
                : senderId // ignore: cast_nullable_to_non_nullable
                      as int,
            receiverId: null == receiverId
                ? _value.receiverId
                : receiverId // ignore: cast_nullable_to_non_nullable
                      as int,
            body: null == body
                ? _value.body
                : body // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as String,
            clientWrittenAt: null == clientWrittenAt
                ? _value.clientWrittenAt
                : clientWrittenAt // ignore: cast_nullable_to_non_nullable
                      as String,
            serverReceivedAt: null == serverReceivedAt
                ? _value.serverReceivedAt
                : serverReceivedAt // ignore: cast_nullable_to_non_nullable
                      as String,
            deliveredAt: null == deliveredAt
                ? _value.deliveredAt
                : deliveredAt // ignore: cast_nullable_to_non_nullable
                      as String,
            readAt: null == readAt
                ? _value.readAt
                : readAt // ignore: cast_nullable_to_non_nullable
                      as String,
            isMine: null == isMine
                ? _value.isMine
                : isMine // ignore: cast_nullable_to_non_nullable
                      as bool,
            senderName: null == senderName
                ? _value.senderName
                : senderName // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MessengerMessageImplCopyWith<$Res>
    implements $MessengerMessageCopyWith<$Res> {
  factory _$$MessengerMessageImplCopyWith(
    _$MessengerMessageImpl value,
    $Res Function(_$MessengerMessageImpl) then,
  ) = __$$MessengerMessageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredInt) int id,
    @JsonKey(fromJson: readRequiredInt) int threadId,
    @JsonKey(fromJson: readRequiredInt) int senderId,
    @JsonKey(fromJson: readRequiredInt) int receiverId,
    @JsonKey(fromJson: readRequiredText) String body,
    @JsonKey(fromJson: readRequiredText) String createdAt,
    @JsonKey(fromJson: readRequiredText) String clientWrittenAt,
    @JsonKey(fromJson: readRequiredText) String serverReceivedAt,
    @JsonKey(fromJson: readRequiredText) String deliveredAt,
    @JsonKey(fromJson: readRequiredText) String readAt,
    @JsonKey(fromJson: readRequiredBool) bool isMine,
    @JsonKey(fromJson: readRequiredText) String senderName,
  });
}

/// @nodoc
class __$$MessengerMessageImplCopyWithImpl<$Res>
    extends _$MessengerMessageCopyWithImpl<$Res, _$MessengerMessageImpl>
    implements _$$MessengerMessageImplCopyWith<$Res> {
  __$$MessengerMessageImplCopyWithImpl(
    _$MessengerMessageImpl _value,
    $Res Function(_$MessengerMessageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessengerMessage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? threadId = null,
    Object? senderId = null,
    Object? receiverId = null,
    Object? body = null,
    Object? createdAt = null,
    Object? clientWrittenAt = null,
    Object? serverReceivedAt = null,
    Object? deliveredAt = null,
    Object? readAt = null,
    Object? isMine = null,
    Object? senderName = null,
  }) {
    return _then(
      _$MessengerMessageImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        threadId: null == threadId
            ? _value.threadId
            : threadId // ignore: cast_nullable_to_non_nullable
                  as int,
        senderId: null == senderId
            ? _value.senderId
            : senderId // ignore: cast_nullable_to_non_nullable
                  as int,
        receiverId: null == receiverId
            ? _value.receiverId
            : receiverId // ignore: cast_nullable_to_non_nullable
                  as int,
        body: null == body
            ? _value.body
            : body // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as String,
        clientWrittenAt: null == clientWrittenAt
            ? _value.clientWrittenAt
            : clientWrittenAt // ignore: cast_nullable_to_non_nullable
                  as String,
        serverReceivedAt: null == serverReceivedAt
            ? _value.serverReceivedAt
            : serverReceivedAt // ignore: cast_nullable_to_non_nullable
                  as String,
        deliveredAt: null == deliveredAt
            ? _value.deliveredAt
            : deliveredAt // ignore: cast_nullable_to_non_nullable
                  as String,
        readAt: null == readAt
            ? _value.readAt
            : readAt // ignore: cast_nullable_to_non_nullable
                  as String,
        isMine: null == isMine
            ? _value.isMine
            : isMine // ignore: cast_nullable_to_non_nullable
                  as bool,
        senderName: null == senderName
            ? _value.senderName
            : senderName // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MessengerMessageImpl extends _MessengerMessage {
  const _$MessengerMessageImpl({
    @JsonKey(fromJson: readRequiredInt) required this.id,
    @JsonKey(fromJson: readRequiredInt) required this.threadId,
    @JsonKey(fromJson: readRequiredInt) required this.senderId,
    @JsonKey(fromJson: readRequiredInt) required this.receiverId,
    @JsonKey(fromJson: readRequiredText) required this.body,
    @JsonKey(fromJson: readRequiredText) required this.createdAt,
    @JsonKey(fromJson: readRequiredText) required this.clientWrittenAt,
    @JsonKey(fromJson: readRequiredText) required this.serverReceivedAt,
    @JsonKey(fromJson: readRequiredText) required this.deliveredAt,
    @JsonKey(fromJson: readRequiredText) required this.readAt,
    @JsonKey(fromJson: readRequiredBool) required this.isMine,
    @JsonKey(fromJson: readRequiredText) required this.senderName,
  }) : super._();

  factory _$MessengerMessageImpl.fromJson(Map<String, dynamic> json) =>
      _$$MessengerMessageImplFromJson(json);

  @override
  @JsonKey(fromJson: readRequiredInt)
  final int id;
  @override
  @JsonKey(fromJson: readRequiredInt)
  final int threadId;
  @override
  @JsonKey(fromJson: readRequiredInt)
  final int senderId;
  @override
  @JsonKey(fromJson: readRequiredInt)
  final int receiverId;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String body;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String createdAt;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String clientWrittenAt;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String serverReceivedAt;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String deliveredAt;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String readAt;
  @override
  @JsonKey(fromJson: readRequiredBool)
  final bool isMine;
  @override
  @JsonKey(fromJson: readRequiredText)
  final String senderName;

  @override
  String toString() {
    return 'MessengerMessage(id: $id, threadId: $threadId, senderId: $senderId, receiverId: $receiverId, body: $body, createdAt: $createdAt, clientWrittenAt: $clientWrittenAt, serverReceivedAt: $serverReceivedAt, deliveredAt: $deliveredAt, readAt: $readAt, isMine: $isMine, senderName: $senderName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessengerMessageImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.threadId, threadId) ||
                other.threadId == threadId) &&
            (identical(other.senderId, senderId) ||
                other.senderId == senderId) &&
            (identical(other.receiverId, receiverId) ||
                other.receiverId == receiverId) &&
            (identical(other.body, body) || other.body == body) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.clientWrittenAt, clientWrittenAt) ||
                other.clientWrittenAt == clientWrittenAt) &&
            (identical(other.serverReceivedAt, serverReceivedAt) ||
                other.serverReceivedAt == serverReceivedAt) &&
            (identical(other.deliveredAt, deliveredAt) ||
                other.deliveredAt == deliveredAt) &&
            (identical(other.readAt, readAt) || other.readAt == readAt) &&
            (identical(other.isMine, isMine) || other.isMine == isMine) &&
            (identical(other.senderName, senderName) ||
                other.senderName == senderName));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    threadId,
    senderId,
    receiverId,
    body,
    createdAt,
    clientWrittenAt,
    serverReceivedAt,
    deliveredAt,
    readAt,
    isMine,
    senderName,
  );

  /// Create a copy of MessengerMessage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessengerMessageImplCopyWith<_$MessengerMessageImpl> get copyWith =>
      __$$MessengerMessageImplCopyWithImpl<_$MessengerMessageImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$MessengerMessageImplToJson(this);
  }
}

abstract class _MessengerMessage extends MessengerMessage {
  const factory _MessengerMessage({
    @JsonKey(fromJson: readRequiredInt) required final int id,
    @JsonKey(fromJson: readRequiredInt) required final int threadId,
    @JsonKey(fromJson: readRequiredInt) required final int senderId,
    @JsonKey(fromJson: readRequiredInt) required final int receiverId,
    @JsonKey(fromJson: readRequiredText) required final String body,
    @JsonKey(fromJson: readRequiredText) required final String createdAt,
    @JsonKey(fromJson: readRequiredText) required final String clientWrittenAt,
    @JsonKey(fromJson: readRequiredText) required final String serverReceivedAt,
    @JsonKey(fromJson: readRequiredText) required final String deliveredAt,
    @JsonKey(fromJson: readRequiredText) required final String readAt,
    @JsonKey(fromJson: readRequiredBool) required final bool isMine,
    @JsonKey(fromJson: readRequiredText) required final String senderName,
  }) = _$MessengerMessageImpl;
  const _MessengerMessage._() : super._();

  factory _MessengerMessage.fromJson(Map<String, dynamic> json) =
      _$MessengerMessageImpl.fromJson;

  @override
  @JsonKey(fromJson: readRequiredInt)
  int get id;
  @override
  @JsonKey(fromJson: readRequiredInt)
  int get threadId;
  @override
  @JsonKey(fromJson: readRequiredInt)
  int get senderId;
  @override
  @JsonKey(fromJson: readRequiredInt)
  int get receiverId;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get body;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get createdAt;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get clientWrittenAt;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get serverReceivedAt;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get deliveredAt;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get readAt;
  @override
  @JsonKey(fromJson: readRequiredBool)
  bool get isMine;
  @override
  @JsonKey(fromJson: readRequiredText)
  String get senderName;

  /// Create a copy of MessengerMessage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessengerMessageImplCopyWith<_$MessengerMessageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

MessengerThreadSummary _$MessengerThreadSummaryFromJson(
  Map<String, dynamic> json,
) {
  return _MessengerThreadSummary.fromJson(json);
}

/// @nodoc
mixin _$MessengerThreadSummary {
  @JsonKey(fromJson: readRequiredInt)
  int get id => throw _privateConstructorUsedError;
  MessengerContact get peer => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredInt)
  int get unreadCount => throw _privateConstructorUsedError;
  MessengerMessage? get lastMessage => throw _privateConstructorUsedError;

  /// Serializes this MessengerThreadSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MessengerThreadSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MessengerThreadSummaryCopyWith<MessengerThreadSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MessengerThreadSummaryCopyWith<$Res> {
  factory $MessengerThreadSummaryCopyWith(
    MessengerThreadSummary value,
    $Res Function(MessengerThreadSummary) then,
  ) = _$MessengerThreadSummaryCopyWithImpl<$Res, MessengerThreadSummary>;
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredInt) int id,
    MessengerContact peer,
    @JsonKey(fromJson: readRequiredInt) int unreadCount,
    MessengerMessage? lastMessage,
  });

  $MessengerContactCopyWith<$Res> get peer;
  $MessengerMessageCopyWith<$Res>? get lastMessage;
}

/// @nodoc
class _$MessengerThreadSummaryCopyWithImpl<
  $Res,
  $Val extends MessengerThreadSummary
>
    implements $MessengerThreadSummaryCopyWith<$Res> {
  _$MessengerThreadSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MessengerThreadSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? peer = null,
    Object? unreadCount = null,
    Object? lastMessage = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            peer: null == peer
                ? _value.peer
                : peer // ignore: cast_nullable_to_non_nullable
                      as MessengerContact,
            unreadCount: null == unreadCount
                ? _value.unreadCount
                : unreadCount // ignore: cast_nullable_to_non_nullable
                      as int,
            lastMessage: freezed == lastMessage
                ? _value.lastMessage
                : lastMessage // ignore: cast_nullable_to_non_nullable
                      as MessengerMessage?,
          )
          as $Val,
    );
  }

  /// Create a copy of MessengerThreadSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MessengerContactCopyWith<$Res> get peer {
    return $MessengerContactCopyWith<$Res>(_value.peer, (value) {
      return _then(_value.copyWith(peer: value) as $Val);
    });
  }

  /// Create a copy of MessengerThreadSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MessengerMessageCopyWith<$Res>? get lastMessage {
    if (_value.lastMessage == null) {
      return null;
    }

    return $MessengerMessageCopyWith<$Res>(_value.lastMessage!, (value) {
      return _then(_value.copyWith(lastMessage: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$MessengerThreadSummaryImplCopyWith<$Res>
    implements $MessengerThreadSummaryCopyWith<$Res> {
  factory _$$MessengerThreadSummaryImplCopyWith(
    _$MessengerThreadSummaryImpl value,
    $Res Function(_$MessengerThreadSummaryImpl) then,
  ) = __$$MessengerThreadSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredInt) int id,
    MessengerContact peer,
    @JsonKey(fromJson: readRequiredInt) int unreadCount,
    MessengerMessage? lastMessage,
  });

  @override
  $MessengerContactCopyWith<$Res> get peer;
  @override
  $MessengerMessageCopyWith<$Res>? get lastMessage;
}

/// @nodoc
class __$$MessengerThreadSummaryImplCopyWithImpl<$Res>
    extends
        _$MessengerThreadSummaryCopyWithImpl<$Res, _$MessengerThreadSummaryImpl>
    implements _$$MessengerThreadSummaryImplCopyWith<$Res> {
  __$$MessengerThreadSummaryImplCopyWithImpl(
    _$MessengerThreadSummaryImpl _value,
    $Res Function(_$MessengerThreadSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessengerThreadSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? peer = null,
    Object? unreadCount = null,
    Object? lastMessage = freezed,
  }) {
    return _then(
      _$MessengerThreadSummaryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        peer: null == peer
            ? _value.peer
            : peer // ignore: cast_nullable_to_non_nullable
                  as MessengerContact,
        unreadCount: null == unreadCount
            ? _value.unreadCount
            : unreadCount // ignore: cast_nullable_to_non_nullable
                  as int,
        lastMessage: freezed == lastMessage
            ? _value.lastMessage
            : lastMessage // ignore: cast_nullable_to_non_nullable
                  as MessengerMessage?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MessengerThreadSummaryImpl implements _MessengerThreadSummary {
  const _$MessengerThreadSummaryImpl({
    @JsonKey(fromJson: readRequiredInt) required this.id,
    required this.peer,
    @JsonKey(fromJson: readRequiredInt) required this.unreadCount,
    this.lastMessage,
  });

  factory _$MessengerThreadSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$MessengerThreadSummaryImplFromJson(json);

  @override
  @JsonKey(fromJson: readRequiredInt)
  final int id;
  @override
  final MessengerContact peer;
  @override
  @JsonKey(fromJson: readRequiredInt)
  final int unreadCount;
  @override
  final MessengerMessage? lastMessage;

  @override
  String toString() {
    return 'MessengerThreadSummary(id: $id, peer: $peer, unreadCount: $unreadCount, lastMessage: $lastMessage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessengerThreadSummaryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.peer, peer) || other.peer == peer) &&
            (identical(other.unreadCount, unreadCount) ||
                other.unreadCount == unreadCount) &&
            (identical(other.lastMessage, lastMessage) ||
                other.lastMessage == lastMessage));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, peer, unreadCount, lastMessage);

  /// Create a copy of MessengerThreadSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessengerThreadSummaryImplCopyWith<_$MessengerThreadSummaryImpl>
  get copyWith =>
      __$$MessengerThreadSummaryImplCopyWithImpl<_$MessengerThreadSummaryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$MessengerThreadSummaryImplToJson(this);
  }
}

abstract class _MessengerThreadSummary implements MessengerThreadSummary {
  const factory _MessengerThreadSummary({
    @JsonKey(fromJson: readRequiredInt) required final int id,
    required final MessengerContact peer,
    @JsonKey(fromJson: readRequiredInt) required final int unreadCount,
    final MessengerMessage? lastMessage,
  }) = _$MessengerThreadSummaryImpl;

  factory _MessengerThreadSummary.fromJson(Map<String, dynamic> json) =
      _$MessengerThreadSummaryImpl.fromJson;

  @override
  @JsonKey(fromJson: readRequiredInt)
  int get id;
  @override
  MessengerContact get peer;
  @override
  @JsonKey(fromJson: readRequiredInt)
  int get unreadCount;
  @override
  MessengerMessage? get lastMessage;

  /// Create a copy of MessengerThreadSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessengerThreadSummaryImplCopyWith<_$MessengerThreadSummaryImpl>
  get copyWith => throw _privateConstructorUsedError;
}

MessengerRealtimeEvent _$MessengerRealtimeEventFromJson(
  Map<String, dynamic> json,
) {
  return _MessengerRealtimeEvent.fromJson(json);
}

/// @nodoc
mixin _$MessengerRealtimeEvent {
  @JsonKey(fromJson: readRequiredText)
  String get type => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readRequiredInt)
  int get threadId => throw _privateConstructorUsedError;
  @JsonKey(fromJson: readOptionalInt)
  int? get byUserId => throw _privateConstructorUsedError;
  MessengerMessage? get item => throw _privateConstructorUsedError;

  /// Serializes this MessengerRealtimeEvent to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MessengerRealtimeEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MessengerRealtimeEventCopyWith<MessengerRealtimeEvent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MessengerRealtimeEventCopyWith<$Res> {
  factory $MessengerRealtimeEventCopyWith(
    MessengerRealtimeEvent value,
    $Res Function(MessengerRealtimeEvent) then,
  ) = _$MessengerRealtimeEventCopyWithImpl<$Res, MessengerRealtimeEvent>;
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredText) String type,
    @JsonKey(fromJson: readRequiredInt) int threadId,
    @JsonKey(fromJson: readOptionalInt) int? byUserId,
    MessengerMessage? item,
  });

  $MessengerMessageCopyWith<$Res>? get item;
}

/// @nodoc
class _$MessengerRealtimeEventCopyWithImpl<
  $Res,
  $Val extends MessengerRealtimeEvent
>
    implements $MessengerRealtimeEventCopyWith<$Res> {
  _$MessengerRealtimeEventCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MessengerRealtimeEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? threadId = null,
    Object? byUserId = freezed,
    Object? item = freezed,
  }) {
    return _then(
      _value.copyWith(
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String,
            threadId: null == threadId
                ? _value.threadId
                : threadId // ignore: cast_nullable_to_non_nullable
                      as int,
            byUserId: freezed == byUserId
                ? _value.byUserId
                : byUserId // ignore: cast_nullable_to_non_nullable
                      as int?,
            item: freezed == item
                ? _value.item
                : item // ignore: cast_nullable_to_non_nullable
                      as MessengerMessage?,
          )
          as $Val,
    );
  }

  /// Create a copy of MessengerRealtimeEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MessengerMessageCopyWith<$Res>? get item {
    if (_value.item == null) {
      return null;
    }

    return $MessengerMessageCopyWith<$Res>(_value.item!, (value) {
      return _then(_value.copyWith(item: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$MessengerRealtimeEventImplCopyWith<$Res>
    implements $MessengerRealtimeEventCopyWith<$Res> {
  factory _$$MessengerRealtimeEventImplCopyWith(
    _$MessengerRealtimeEventImpl value,
    $Res Function(_$MessengerRealtimeEventImpl) then,
  ) = __$$MessengerRealtimeEventImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(fromJson: readRequiredText) String type,
    @JsonKey(fromJson: readRequiredInt) int threadId,
    @JsonKey(fromJson: readOptionalInt) int? byUserId,
    MessengerMessage? item,
  });

  @override
  $MessengerMessageCopyWith<$Res>? get item;
}

/// @nodoc
class __$$MessengerRealtimeEventImplCopyWithImpl<$Res>
    extends
        _$MessengerRealtimeEventCopyWithImpl<$Res, _$MessengerRealtimeEventImpl>
    implements _$$MessengerRealtimeEventImplCopyWith<$Res> {
  __$$MessengerRealtimeEventImplCopyWithImpl(
    _$MessengerRealtimeEventImpl _value,
    $Res Function(_$MessengerRealtimeEventImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MessengerRealtimeEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? threadId = null,
    Object? byUserId = freezed,
    Object? item = freezed,
  }) {
    return _then(
      _$MessengerRealtimeEventImpl(
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String,
        threadId: null == threadId
            ? _value.threadId
            : threadId // ignore: cast_nullable_to_non_nullable
                  as int,
        byUserId: freezed == byUserId
            ? _value.byUserId
            : byUserId // ignore: cast_nullable_to_non_nullable
                  as int?,
        item: freezed == item
            ? _value.item
            : item // ignore: cast_nullable_to_non_nullable
                  as MessengerMessage?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$MessengerRealtimeEventImpl implements _MessengerRealtimeEvent {
  const _$MessengerRealtimeEventImpl({
    @JsonKey(fromJson: readRequiredText) required this.type,
    @JsonKey(fromJson: readRequiredInt) required this.threadId,
    @JsonKey(fromJson: readOptionalInt) this.byUserId,
    this.item,
  });

  factory _$MessengerRealtimeEventImpl.fromJson(Map<String, dynamic> json) =>
      _$$MessengerRealtimeEventImplFromJson(json);

  @override
  @JsonKey(fromJson: readRequiredText)
  final String type;
  @override
  @JsonKey(fromJson: readRequiredInt)
  final int threadId;
  @override
  @JsonKey(fromJson: readOptionalInt)
  final int? byUserId;
  @override
  final MessengerMessage? item;

  @override
  String toString() {
    return 'MessengerRealtimeEvent(type: $type, threadId: $threadId, byUserId: $byUserId, item: $item)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MessengerRealtimeEventImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.threadId, threadId) ||
                other.threadId == threadId) &&
            (identical(other.byUserId, byUserId) ||
                other.byUserId == byUserId) &&
            (identical(other.item, item) || other.item == item));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, threadId, byUserId, item);

  /// Create a copy of MessengerRealtimeEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MessengerRealtimeEventImplCopyWith<_$MessengerRealtimeEventImpl>
  get copyWith =>
      __$$MessengerRealtimeEventImplCopyWithImpl<_$MessengerRealtimeEventImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$MessengerRealtimeEventImplToJson(this);
  }
}

abstract class _MessengerRealtimeEvent implements MessengerRealtimeEvent {
  const factory _MessengerRealtimeEvent({
    @JsonKey(fromJson: readRequiredText) required final String type,
    @JsonKey(fromJson: readRequiredInt) required final int threadId,
    @JsonKey(fromJson: readOptionalInt) final int? byUserId,
    final MessengerMessage? item,
  }) = _$MessengerRealtimeEventImpl;

  factory _MessengerRealtimeEvent.fromJson(Map<String, dynamic> json) =
      _$MessengerRealtimeEventImpl.fromJson;

  @override
  @JsonKey(fromJson: readRequiredText)
  String get type;
  @override
  @JsonKey(fromJson: readRequiredInt)
  int get threadId;
  @override
  @JsonKey(fromJson: readOptionalInt)
  int? get byUserId;
  @override
  MessengerMessage? get item;

  /// Create a copy of MessengerRealtimeEvent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MessengerRealtimeEventImplCopyWith<_$MessengerRealtimeEventImpl>
  get copyWith => throw _privateConstructorUsedError;
}
