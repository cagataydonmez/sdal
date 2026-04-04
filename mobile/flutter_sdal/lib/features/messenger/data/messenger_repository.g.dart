// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'messenger_repository.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MessengerContactImpl _$$MessengerContactImplFromJson(
  Map<String, dynamic> json,
) => _$MessengerContactImpl(
  id: readRequiredInt(json['id']),
  name: readRequiredText(json['name']),
  handle: readRequiredText(json['handle']),
  photo: readRequiredText(json['photo']),
  verified: readRequiredBool(json['verified']),
);

Map<String, dynamic> _$$MessengerContactImplToJson(
  _$MessengerContactImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'handle': instance.handle,
  'photo': instance.photo,
  'verified': instance.verified,
};

_$MessengerMessageImpl _$$MessengerMessageImplFromJson(
  Map<String, dynamic> json,
) => _$MessengerMessageImpl(
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

Map<String, dynamic> _$$MessengerMessageImplToJson(
  _$MessengerMessageImpl instance,
) => <String, dynamic>{
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

_$MessengerThreadSummaryImpl _$$MessengerThreadSummaryImplFromJson(
  Map<String, dynamic> json,
) => _$MessengerThreadSummaryImpl(
  id: readRequiredInt(json['id']),
  peer: MessengerContact.fromJson(json['peer'] as Map<String, dynamic>),
  unreadCount: readRequiredInt(json['unreadCount']),
  lastMessage: json['lastMessage'] == null
      ? null
      : MessengerMessage.fromJson(json['lastMessage'] as Map<String, dynamic>),
);

Map<String, dynamic> _$$MessengerThreadSummaryImplToJson(
  _$MessengerThreadSummaryImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'peer': instance.peer,
  'unreadCount': instance.unreadCount,
  'lastMessage': instance.lastMessage,
};

_$MessengerRealtimeEventImpl _$$MessengerRealtimeEventImplFromJson(
  Map<String, dynamic> json,
) => _$MessengerRealtimeEventImpl(
  type: readRequiredText(json['type']),
  threadId: readRequiredInt(json['threadId']),
  byUserId: readOptionalInt(json['byUserId']),
  item: json['item'] == null
      ? null
      : MessengerMessage.fromJson(json['item'] as Map<String, dynamic>),
);

Map<String, dynamic> _$$MessengerRealtimeEventImplToJson(
  _$MessengerRealtimeEventImpl instance,
) => <String, dynamic>{
  'type': instance.type,
  'threadId': instance.threadId,
  'byUserId': instance.byUserId,
  'item': instance.item,
};
