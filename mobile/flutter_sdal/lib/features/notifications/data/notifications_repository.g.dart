// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifications_repository.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NotificationTargetImpl _$$NotificationTargetImplFromJson(
  Map<String, dynamic> json,
) => _$NotificationTargetImpl(
  route: readRequiredText(json['route']),
  href: readRequiredText(json['href']),
  label: readRequiredText(json['label']),
);

Map<String, dynamic> _$$NotificationTargetImplToJson(
  _$NotificationTargetImpl instance,
) => <String, dynamic>{
  'route': instance.route,
  'href': instance.href,
  'label': instance.label,
};

_$NotificationActionItemImpl _$$NotificationActionItemImplFromJson(
  Map<String, dynamic> json,
) => _$NotificationActionItemImpl(
  kind: readRequiredText(json['kind']),
  label: _readActionLabel(json['label']),
  endpoint: readRequiredText(json['endpoint']),
  method: _readActionMethod(json['method']),
);

Map<String, dynamic> _$$NotificationActionItemImplToJson(
  _$NotificationActionItemImpl instance,
) => <String, dynamic>{
  'kind': instance.kind,
  'label': instance.label,
  'endpoint': instance.endpoint,
  'method': instance.method,
};

_$AppNotificationImpl _$$AppNotificationImplFromJson(
  Map<String, dynamic> json,
) => _$AppNotificationImpl(
  id: readRequiredInt(json['id']),
  type: readRequiredText(json['type']),
  message: readRequiredText(json['message']),
  createdAt: readRequiredText(json['createdAt']),
  readAt: readRequiredText(json['readAt']),
  category: readRequiredText(json['category']),
  priority: readRequiredText(json['priority']),
  target: json['target'] == null
      ? null
      : NotificationTarget.fromJson(json['target'] as Map<String, dynamic>),
  actions:
      (json['actions'] as List<dynamic>?)
          ?.map(
            (e) => NotificationActionItem.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const <NotificationActionItem>[],
  sourceName: readRequiredText(json['sourceName']),
);

Map<String, dynamic> _$$AppNotificationImplToJson(
  _$AppNotificationImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': instance.type,
  'message': instance.message,
  'createdAt': instance.createdAt,
  'readAt': instance.readAt,
  'category': instance.category,
  'priority': instance.priority,
  'target': instance.target,
  'actions': instance.actions,
  'sourceName': instance.sourceName,
};

_$NotificationPreferencesImpl _$$NotificationPreferencesImplFromJson(
  Map<String, dynamic> json,
) => _$NotificationPreferencesImpl(
  categories: const NotificationCategoryConverter().fromJson(
    json['categories'] as Map<String, dynamic>?,
  ),
  quietModeEnabled: readRequiredBool(json['quietModeEnabled']),
  quietModeStart: readRequiredText(json['quietModeStart']),
  quietModeEnd: readRequiredText(json['quietModeEnd']),
);

Map<String, dynamic> _$$NotificationPreferencesImplToJson(
  _$NotificationPreferencesImpl instance,
) => <String, dynamic>{
  'categories': const NotificationCategoryConverter().toJson(
    instance.categories,
  ),
  'quietModeEnabled': instance.quietModeEnabled,
  'quietModeStart': instance.quietModeStart,
  'quietModeEnd': instance.quietModeEnd,
};
