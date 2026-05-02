// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'messenger_repository.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MessengerContact _$MessengerContactFromJson(Map<String, dynamic> json) =>
    _MessengerContact(
      id: readRequiredInt(json['id']),
      name: readRequiredText(json['name']),
      handle: readRequiredText(json['handle']),
      photo: readRequiredText(json['photo']),
      verified: readRequiredBool(json['verified']),
    );

Map<String, dynamic> _$MessengerContactToJson(_MessengerContact instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'handle': instance.handle,
      'photo': instance.photo,
      'verified': instance.verified,
    };

_MessengerMessage _$MessengerMessageFromJson(Map<String, dynamic> json) =>
    _MessengerMessage(
      id: readRequiredInt(json['id']),
      threadId: readRequiredInt(json['threadId']),
      senderId: readRequiredInt(json['senderId']),
      receiverId: readRequiredInt(json['receiverId']),
      body: readRequiredText(json['body']),
      createdAt: readRequiredText(json['createdAt']),
      clientWrittenAt: readRequiredText(json['clientWrittenAt']),
      serverReceivedAt: readRequiredText(json['serverReceivedAt']),
      deliveredAt: readRequiredText(json['deliveredAt']),
      readAt: readRequiredText(json['readAt']),
      isMine: readRequiredBool(json['isMine']),
      senderName: readRequiredText(json['senderName']),
    );

Map<String, dynamic> _$MessengerMessageToJson(_MessengerMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'threadId': instance.threadId,
      'senderId': instance.senderId,
      'receiverId': instance.receiverId,
      'body': instance.body,
      'createdAt': instance.createdAt,
      'clientWrittenAt': instance.clientWrittenAt,
      'serverReceivedAt': instance.serverReceivedAt,
      'deliveredAt': instance.deliveredAt,
      'readAt': instance.readAt,
      'isMine': instance.isMine,
      'senderName': instance.senderName,
    };

_MessengerThreadSummary _$MessengerThreadSummaryFromJson(
  Map<String, dynamic> json,
) => _MessengerThreadSummary(
  id: readRequiredInt(json['id']),
  peer: MessengerContact.fromJson(json['peer'] as Map<String, dynamic>),
  unreadCount: readRequiredInt(json['unreadCount']),
  lastMessage: json['lastMessage'] == null
      ? null
      : MessengerMessage.fromJson(json['lastMessage'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MessengerThreadSummaryToJson(
  _MessengerThreadSummary instance,
) => <String, dynamic>{
  'id': instance.id,
  'peer': instance.peer,
  'unreadCount': instance.unreadCount,
  'lastMessage': instance.lastMessage,
};

_MessengerRealtimeEvent _$MessengerRealtimeEventFromJson(
  Map<String, dynamic> json,
) => _MessengerRealtimeEvent(
  type: readRequiredText(json['type']),
  threadId: readRequiredInt(json['threadId']),
  byUserId: readOptionalInt(json['byUserId']),
  item: json['item'] == null
      ? null
      : MessengerMessage.fromJson(json['item'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MessengerRealtimeEventToJson(
  _MessengerRealtimeEvent instance,
) => <String, dynamic>{
  'type': instance.type,
  'threadId': instance.threadId,
  'byUserId': instance.byUserId,
  'item': instance.item,
};
